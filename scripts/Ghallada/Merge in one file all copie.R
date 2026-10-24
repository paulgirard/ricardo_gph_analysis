################################################################
#####  MASTER PANEL : Intramax + Louvain + Anderson-Norheim  ####
################################################################

rm(list = ls(all = TRUE))
gc()

library(dplyr)
library(readxl)
library(tidyverse)
setwd("~/Desktop/ricardo_gph_analysis")

# --- 1. Mapping Anderson-Norheim ---
BlocselonAN <- as.data.frame(read_excel("data/BlocselonAN.xlsx"))
region_map <- BlocselonAN[, c("GPH_code", "region_AndersonNorheim")]
region_map$GPH_code <- as.character(region_map$GPH_code)


dossier <- "data/blocks/gph_blocks_by_year"
annees  <- c(1833:1938, 1948:2025)

liste <- list()

for (year in annees) {
  f <- file.path(dossier, paste0(year, "_fob.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  if (nrow(d) == 0) next
  d$year <- year
  liste[[as.character(year)]] <- d
  cat(year, ":", nrow(d), "lignes\n")
}

master <- bind_rows(liste)

cat("\nDimensions :", dim(master), "\n")
cat("Annees :", min(master$year), "->", max(master$year), "\n")

#write.csv(master, gzfile("data/blocks/gph_blocks_all_years.csv.gz"), row.names = FALSE)


# --- 6. Sauvegarde ---
#write.csv(master, "data/blocks/master_panel_3methodes.csv", row.names = FALSE)
write.csv(master, gzfile("data/blocks/master_panel_3methodes.csv.gz"), row.names = FALSE)

####Ajout de variables gravitaires avant filtre rectangulaire
coord <- read.csv("data/GeoPolHist_entities.csv", stringsAsFactors = FALSE) %>%
  select(gph = GPH_code, lat, lng) %>%
  mutate(gph = as.character(gph))

master <- master %>%
  left_join(coord %>% rename(lat_exp = lat, lng_exp = lng),
            by = c("exporterId" = "gph")) %>%
  left_join(coord %>% rename(lat_imp = lat, lng_imp = lng),
            by = c("importerId" = "gph")) %>%
  mutate(distance_km = geosphere::distHaversine(
    cbind(lng_exp, lat_exp), cbind(lng_imp, lat_imp)) / 1000)

##Contiguity
contig <- read.csv("data/DirectContiguity320/contdird.csv", stringsAsFactors = FALSE) %>%
  mutate(state1no = if_else(state1no == 510L, 512L, state1no),
         state2no = if_else(state2no == 510L, 512L, state2no)) %>%
  group_by(state1no, state2no, year) %>%
  slice_min(conttype, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(exporterId = as.character(state1no),
            importerId = as.character(state2no),
            year, conttype)
write.csv(contig, "data/Gravity controls/contiguity_gph.csv", row.names = FALSE)
# 2017-2025 : on reconduit la situation de 2016
contig <- bind_rows(
contig,
  contig %>% filter(year == 2016) %>% select(-year) %>%
    tidyr::crossing(year = 2017:2025)
)

master <- master %>%
  left_join(contig, by = c("exporterId", "importerId", "year")) %>%
  mutate(contig_terre = as.integer(!is.na(conttype) & conttype == 1),
         contig_24mi  = as.integer(!is.na(conttype) & conttype <= 3),
         contig_large = as.integer(!is.na(conttype)))
#Need to treat the contiguity of 4 numbers code, as of now considered zero (we can put NA for now)
master <- master %>%
  mutate(
    hors_cow = as.integer(exporterId) > 999 | as.integer(importerId) > 999,
    contig_terre = if_else(hors_cow, NA_integer_, contig_terre),
    contig_24mi  = if_else(hors_cow, NA_integer_, contig_24mi),
    contig_large = if_else(hors_cow, NA_integer_, contig_large)
  ) %>%
  select(-hors_cow)

library(writexl)
master %>%
  filter(!is.na(conttype)) %>%
  group_by(conttype) %>%
  summarise(n = n(),
            median = median(distance_km, na.rm = TRUE),
            p95    = quantile(distance_km, 0.95, na.rm = TRUE),
            max    = max(distance_km, na.rm = TRUE))

# les dyades terrestres les plus éloignées
master %>%
  filter(conttype == 1) %>%
  distinct(exportateur, importateur, distance_km) %>%
  arrange(desc(distance_km)) %>%
  head(15)

# 1. paires-annees
library(writexl)

na_contig_annees <- master %>%
  filter(is.na(contig_terre), !is.na(export_intramax)) %>%
  select(year, exporterId, exportateur, importerId, importateur,
         export_intramax, distance_km) %>%
  arrange(exporterId, importerId, year)

# 2. paires uniques
na_contig_paires <- na_contig_annees %>%
  group_by(exporterId, exportateur, importerId, importateur) %>%
  summarise(distance_km    = first(distance_km),
            premiere_annee = min(year),
            derniere_annee = max(year),
            n_annees       = n(), .groups = "drop") %>%
  arrange(distance_km)

write_xlsx(na_contig_annees, "data/na_contig_paires_annees.xlsx")
write_xlsx(na_contig_paires, "data/na_contig_paires.xlsx")

nrow(na_contig_annees); nrow(na_contig_paires)

#Bilateral Disputes
BilateralDis <- read.csv("~/Desktop/ricardo_gph_analysis/data/dyadic_mid_4.03_update/dyadic_mid_4.03.csv")
library(dplyr); library(writexl)

mid <- BilateralDis %>%
  mutate(exporterId = as.character(if_else(statea == 510L, 512L, statea)),
         importerId = as.character(if_else(stateb == 510L, 512L, stateb))) %>%
  group_by(exporterId, importerId, year) %>%
  summarise(mid_n        = n(),
            mid_hihost   = max(hihost, na.rm = TRUE),
            mid_guerre   = as.integer(any(war == 1, na.rm = TRUE)),
            mid_duration = sum(duration, na.rm = TRUE),
            .groups = "drop")
write.csv(mid, "data/Gravity controls/bilateraldisputes_gph.csv", row.names = FALSE)

master <- master %>%
  left_join(mid, by = c("exporterId", "importerId", "year")) %>%
  mutate(
    hors_champ   = as.integer(exporterId) > 999 | as.integer(importerId) > 999 | year > 2014,
    mid_n        = if_else(hors_champ, NA_integer_, coalesce(mid_n, 0L)),
    mid_hihost   = if_else(hors_champ, NA_integer_, coalesce(mid_hihost, 0L)),
    mid_guerre   = if_else(hors_champ, NA_integer_, coalesce(mid_guerre, 0L)),
    mid_duration = if_else(hors_champ, NA_real_, coalesce(as.numeric(mid_duration), 0))
  ) %>%
  select(-hors_champ)
#Alliances
atop <- read.csv("data/ATOP 5.1 (.csv)/atop5_1ddyr.csv", stringsAsFactors = FALSE) %>%
  mutate(exporterId = as.character(if_else(stateA == 510L, 512L, stateA)),
         importerId = as.character(if_else(stateB == 510L, 512L, stateB))) %>%
  select(exporterId, importerId, year,
         atop_allie   = atopally,
         atop_defense = defense, atop_offense = offense,
         atop_neutral = neutral, atop_nonagg  = nonagg,
         atop_consul  = consul,  atop_asymm   = asymm)

write.csv(atop, "data/Gravity controls/alliance_gph.csv", row.names = FALSE)
master <- master %>%
  left_join(atop, by = c("exporterId", "importerId", "year")) %>%
  mutate(
    hors_champ = as.integer(exporterId) > 999 | as.integer(importerId) > 999 |
      year < 1815 | year > 2018,
    across(c(atop_allie, atop_defense, atop_offense, atop_neutral,
             atop_nonagg, atop_consul, atop_asymm),
           ~ if_else(hors_champ, NA_integer_, coalesce(as.integer(.x), 0L)))
  ) %>%
  select(-hors_champ)
#Treaties 

# Diagnostic année par année : ensemble exportateurs vs importateurs
diag_carre <- master %>%
  group_by(year) %>%
  summarise(
    n_paires        = n(),
    n_exporters     = n_distinct(exportateur),
    n_importers     = n_distinct(importateur),
    n_union         = n_distinct(c(exportateur, importateur)),
    # Pays présents comme exporter mais jamais comme importer
    exp_only        = length(setdiff(unique(exportateur), unique(importateur))),
    # Pays présents comme importer mais jamais comme exporter
    imp_only        = length(setdiff(unique(importateur), unique(exportateur))),
    # Matrice carrée = mêmes pays des deux côtés
    est_carree      = (n_exporters == n_importers) & (exp_only == 0) & (imp_only == 0),
    # Nb paires attendues si carrée : n × (n-1)
    n_paires_attendues = n_union * (n_union - 1),
    # Panel équilibré = matrice pleine ?
    est_pleine      = n_paires == n_paires_attendues
  )

cat("=== Résumé ===\n")
cat("Total années :", nrow(diag_carre), "\n")
cat("Années avec matrice carrée :", sum(diag_carre$est_carree), "\n")
cat("Années avec matrice non-carrée :", sum(!diag_carre$est_carree), "\n")
cat("Années avec matrice pleine (n × (n-1) paires) :", sum(diag_carre$est_pleine), "\n\n")

# Détail des années où la matrice n'est pas carrée
if (any(!diag_carre$est_carree)) {
  cat("=== Années NON-CARRÉES ===\n")
  diag_carre %>%
    filter(!est_carree) %>%
    select(year, n_exporters, n_importers, exp_only, imp_only) %>%
    print(n = Inf)
}

# Vue synoptique
cat("\n=== Aperçu (10 premières et 10 dernières années) ===\n")
diag_carre %>%
  select(year, n_paires, n_exporters, n_importers, exp_only, imp_only,
         est_carree, est_pleine) %>%
  head(10) %>% print()

diag_carre %>%
  select(year, n_paires, n_exporters, n_importers, exp_only, imp_only,
         est_carree, est_pleine) %>%
  tail(10) %>% print()


# --- 6. Sauvegarde ---
#write.csv(master, "data/blocks/master_panelmatricecarré.csv", row.names = FALSE)
write.csv(master, gzfile("data/blocks/master_panel_carre.csv.gz"), row.names = FALSE)
write.csv(master, xzfile("data/blocks/master_panel_carre.csv.xz"), row.names = FALSE)


##Rendre la matrice réctangle

# --- 1. Identifier par année les vrais exportateurs ---
master <- master[master$exportateur != "Rest Of The World" &
                   master$importateur != "Rest Of The World", ]

real_exporters <- master %>%
  filter(!is.na(export_intramax)) %>%
  distinct(year, exporterId) %>%
  mutate(is_real_exporter = TRUE)

# --- 2. Ne garder que les paires où l'exporter est un vrai exportateur cette année ---
master_rect <- master %>%
  left_join(real_exporters, by = c("year", "exporterId")) %>%
  filter(!is.na(is_real_exporter)) %>%
  select(-is_real_exporter)

# --- 3. Vérification structure par année ---
diag_rect <- master_rect %>%
  group_by(year) %>%
  summarise(
    n_paires    = n(),
    n_exp       = n_distinct(exporterId),
    n_imp       = n_distinct(importerId),
    n_avec_flux = sum(!is.na(export_intramax) & export_intramax > 0)
  )


# --- 4. Sauvegarde ---
#write.csv(master_rect, "data/blocks/master_panelmatricerectangle.csv", row.names = FALSE)
write.csv(master_rect, gzfile("data/blocks/master_panel_rectangle.csv.gz"), row.names = FALSE)
write.csv(master_rect, xzfile("data/blocks/master_panel_rectangle.csv.xz"), row.names = FALSE)

#

