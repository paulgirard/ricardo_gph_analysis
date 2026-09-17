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

for (an in annees) {
  f <- file.path(dossier, paste0(an, "_fob.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  if (nrow(d) == 0) next
  
  ids <- as.character(d$id)
  
  p <- expand.grid(source = ids, target = ids, stringsAsFactors = FALSE)
  p <- p[p$source != p$target, ]
  p$year <- an
  
  liste[[as.character(an)]] <- p
  cat(an, ":", length(ids), "pays ->", nrow(p), "paires\n")
}

master <- bind_rows(liste) %>%
  mutate(key = paste0(pmin(source, target), "-", pmax(source, target))) %>%
  select(key, year, source, target)

cat("\nDimensions :", dim(master), "\n")

# --- Controles ---------------------------------------------------------
# chaque annee doit avoir exactement n*(n-1) paires
master %>% count(year) %>%
  mutate(n_pays = (1 + sqrt(1 + 4 * n)) / 2,
         ok     = n == n_pays * (n_pays - 1)) %>%
  filter(!ok) %>%
  print()

master <- master[!duplicated(master[, c("key", "year")]), ]
write.csv(master, "data/blocks/Controls panel/panel_blocs_paires.csv", row.names = FALSE)

# --- Distance entre centroides ----------------------------------------
coord <- read.csv("data/GeoPolHist_entities.csv", stringsAsFactors = FALSE) %>%
  select(gph = GPH_code, lat, lng) %>%
  mutate(gph = as.character(gph))

distance <- master %>%
  distinct(key, source, target) %>%
  left_join(coord %>% rename(lat_source = lat, lng_source = lng),
            by = c("source" = "gph")) %>%
  left_join(coord %>% rename(lat_target = lat, lng_target = lng),
            by = c("target" = "gph")) %>%
  mutate(distance_km = geosphere::distHaversine(
    cbind(lng_source, lat_source), cbind(lng_target, lat_target)) / 1000) %>%
  select(key, source, target, distance_km)

sum(is.na(distance$distance_km))

write.csv(distance, "data/blocks/Controls panel/distance.csv", row.names = FALSE)

#Verifier d'abord si matrice complete en terme de doublons (càd on a a>b b>a)
raw <- read.csv("data/DirectContiguity320/contdird.csv", stringsAsFactors = FALSE) %>%
  mutate(state1no = if_else(state1no == 510L, 512L, state1no),
         state2no = if_else(state2no == 510L, 512L, state2no)) %>%
  group_by(state1no, state2no, year) %>%
  slice_min(conttype, n = 1, with_ties = FALSE) %>%
  ungroup()

a <- raw %>% select(s1 = state1no, s2 = state2no, year, conttype)
b <- raw %>% select(s1 = state2no, s2 = state1no, year, ct_rev = conttype)

v <- inner_join(a, b, by = c("s1", "s2", "year"))

nrow(a)                          # lignes totales
nrow(v)                          # lignes ayant leur miroir
sum(v$conttype != v$ct_rev)      # divergences de conttype entre les deux sens

# --- Contiguite COW ---------------------------------------------------
contig <- read.csv("data/DirectContiguity320/contdird.csv", stringsAsFactors = FALSE) %>%
  mutate(state1no = if_else(state1no == 510L, 512L, state1no),
         state2no = if_else(state2no == 510L, 512L, state2no)) %>%
  group_by(state1no, state2no, year) %>%
  slice_min(conttype, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  transmute(source = as.character(state1no),
            target = as.character(state2no),
            year, conttype)

# 2017-2025 : on reconduit la situation de 2016
contig <- bind_rows(
  contig,
  contig %>% filter(year == 2016) %>% select(-year) %>% tidyr::crossing(year = 2017:2025)
)

# --- Complement manuel pour les entites hors COW ----------------------
manuel <- read.csv2("data/blocks/Controls panel/na_contig_paires complete.csv",
                    stringsAsFactors = FALSE, fileEncoding = "UTF-8-BOM") %>%
  transmute(a = as.character(exporterId),
            b = as.character(importerId),
            conttype_manuel = as.integer(conttype)) %>%
  mutate(key = paste0(pmin(a, b), "-", pmax(a, b))) %>%
  distinct(key, .keep_all = TRUE) %>%
  select(key, conttype_manuel)

nrow(manuel)
table(manuel$conttype_manuel, useNA = "ifany")

# --- Controle : le complement manuel couvre-t-il tout ? ---------------
master %>%
  filter(as.integer(source) > 999 | as.integer(target) > 999) %>%
  left_join(manuel, by = "key") %>%
  summarise(total = n(), sans_codage = sum(is.na(conttype_manuel)))

# --- Table de controle ------------------------------------------------
contiguity <- master %>%
  select(key, year, source, target) %>%
  left_join(contig, by = c("source", "target", "year")) %>%
  left_join(manuel, by = "key") %>%
  mutate(
    hors_cow = as.integer(source) > 999 | as.integer(target) > 999,
    conttype = if_else(hors_cow, conttype_manuel, as.integer(conttype)),
    conttype = if_else(hors_cow, conttype, coalesce(conttype, 0L))
  ) %>%
  select(key, year, conttype)

table(contiguity$conttype, useNA = "ifany")


write.csv(contiguity, "data/blocks/Controls panel/contiguity.csv", row.names = FALSE)

#Restant à coder
library(writexl)

noms <- read.csv("data/GeoPolHist_entities.csv", stringsAsFactors = FALSE) %>%
  transmute(gph = as.character(GPH_code), nom = GPH_name)

a_coder <- master %>%
  filter(as.integer(source) > 999 | as.integer(target) > 999) %>%
  anti_join(manuel, by = "key") %>%
  group_by(key, source, target) %>%
  summarise(premiere_annee = min(year),
            derniere_annee = max(year),
            n_annees       = n(), .groups = "drop") %>%
  left_join(noms, by = c("source" = "gph")) %>% rename(source_nom = nom) %>%
  left_join(noms, by = c("target" = "gph")) %>% rename(target_nom = nom) %>%
  left_join(distance %>% select(key, distance_km), by = "key") %>%
  select(key, source, source_nom, target, target_nom,
         distance_km, premiere_annee, derniere_annee, n_annees) %>%
  mutate(conttype = NA_integer_) %>%
  arrange(distance_km)

write_xlsx(a_coder, "data/blocks/Controls panel/na_contig_a_coder.xlsx")
write.csv2(a_coder, "data/blocks/Controls panel/na_contig_a_coder.csv", row.names = FALSE)
nrow(a_coder)
n_distinct(master$key)
#Bilateral Disputes
# --- 1. MID agrege ----------------------------------------------------
# =============================================================================
# MID : heritage des conflits de la metropole pour les entites hors COW
#   - souverain unique        -> on herite
#   - souverain multiple      -> NA (ambigu)
#   - souverain a 4 chiffres  -> on remonte d'un cran
# =============================================================================

library(dplyr); library(tidyr)

# --- 1. MID agrege ----------------------------------------------------
BilateralDis <- read.csv("data/dyadic_mid_4.03_update/dyadic_mid_4.03.csv",
                         stringsAsFactors = FALSE)

# Symetrisation : la dyade non orientee prend le maximum des deux sens.
# Chaque differend apparaissant deux fois, on le reduit d'abord au niveau
# disno avant d'agreger par dyade-annee.
mid <- BilateralDis %>%
  mutate(a = as.character(if_else(statea == 510L, 512L, statea)),
         b = as.character(if_else(stateb == 510L, 512L, stateb)),
         key_mid = paste0(pmin(a, b), "-", pmax(a, b))) %>%
  group_by(key_mid, year, disno) %>%
  summarise(hihost   = max(hihost,   na.rm = TRUE),
            war      = max(war,      na.rm = TRUE),
            duration = max(duration, na.rm = TRUE),
            .groups = "drop") %>%
  group_by(key_mid, year) %>%
  summarise(mid_n        = n(),
            mid_hihost   = max(hihost, na.rm = TRUE),
            mid_guerre   = as.integer(any(war == 1, na.rm = TRUE)),
            mid_duration = sum(duration, na.rm = TRUE),
            .groups = "drop")

# --- 2. Souverainete par entite-annee ---------------------------------
statuts_dep <- c("Associated state of", "Colony of", "Dependency of",
                 "Possession of", "Protectorate of", "Leased to",
                 "Mandated to", "Occupied by", "Vassal of")

sov_brut <- read.csv("data/GeoPolHist_entities_status_over_time.csv",
                     stringsAsFactors = FALSE) %>%
  filter(GPH_status %in% statuts_dep, !is.na(sovereign_GPH_code)) %>%
  transmute(gph = as.character(GPH_code),
            sov = as.character(as.integer(sovereign_GPH_code)),
            start_year, end_year) %>%
  rowwise() %>% mutate(year = list(seq(start_year, end_year))) %>% ungroup() %>%
  unnest(year) %>%
  distinct(gph, year, sov)

# Remonter d'un cran quand le souverain est lui-meme une entite dependante
sov_brut <- sov_brut %>%
  left_join(sov_brut %>% rename(sov2 = sov),
            by = c("sov" = "gph", "year"), relationship = "many-to-many") %>%
  mutate(sov = coalesce(sov2, sov)) %>%
  distinct(gph, year, sov)

# Un seul souverain par entite-annee, sinon NA
sov <- sov_brut %>%
  group_by(gph, year) %>%
  summarise(sov = if (n_distinct(sov) == 1) first(sov) else NA_character_,
            .groups = "drop")
# --- 3. Code effectif -------------------------------------------------
disputes <- master %>%
  select(key, year, source, target) %>%
  left_join(sov %>% rename(sov_s = sov), by = c("source" = "gph", "year")) %>%
  left_join(sov %>% rename(sov_t = sov), by = c("target" = "gph", "year")) %>%
  mutate(s_eff = if_else(as.integer(source) > 999, sov_s, source),
         t_eff = if_else(as.integer(target) > 999, sov_t, target))
# --- 4. Jointure MID (sur la cle non orientee des codes effectifs) ----
disputes <- disputes %>%
  mutate(key_mid = paste0(pmin(s_eff, t_eff), "-", pmax(s_eff, t_eff))) %>%
  left_join(mid, by = c("key_mid", "year"))

# --- 5. Zeros vs NA ---------------------------------------------------
# Zero seulement si les deux codes effectifs sont resolus, dans le champ COW
# et l'annee couverte. Deux possessions du meme souverain donnent s_eff ==
# t_eff : la dyade n'a pas de sens, on met NA.
disputes <- disputes %>%
  mutate(
    dans_champ = !is.na(s_eff) & !is.na(t_eff) &
      as.integer(s_eff) <= 999 & as.integer(t_eff) <= 999 &
      s_eff != t_eff & year <= 2014,
    mid_n        = if_else(dans_champ, coalesce(mid_n, 0L),       NA_integer_),
    mid_hihost   = if_else(dans_champ, coalesce(mid_hihost, 0L),  NA_integer_),
    mid_guerre   = if_else(dans_champ, coalesce(mid_guerre, 0L),  NA_integer_),
    mid_duration = if_else(dans_champ, coalesce(mid_duration, 0), NA_real_),
    mid_herite   = as.integer(dans_champ &
                                (as.integer(source) > 999 | as.integer(target) > 999))
  ) %>%
  select(key, year, mid_n, mid_hihost, mid_guerre, mid_duration, mid_herite)
# --- 6. Controles -----------------------------------------------------
colSums(is.na(disputes))
table(disputes$mid_herite, useNA = "ifany")

write.csv(disputes, "data/blocks/Controls panel/disputes.csv", row.names = FALSE)

###########
#Alliances# (for symetry, j'ai pris max des 2 sens)
###########

atop <- read.csv("data/ATOP 5.1 (.csv)/atop5_1ddyr.csv", stringsAsFactors = FALSE) %>%
  mutate(a = as.character(if_else(stateA == 510L, 512L, stateA)),
         b = as.character(if_else(stateB == 510L, 512L, stateB)),
         key_atop = paste0(pmin(a, b), "-", pmax(a, b))) %>%
  select(key_atop, year,
         atop_allie   = atopally,
         atop_defense = defense, atop_offense = offense,
         atop_neutral = neutral, atop_nonagg  = nonagg,
         atop_consul  = consul,  atop_asymm   = asymm) %>%
  group_by(key_atop, year) %>%
  summarise(across(starts_with("atop_"), ~ max(.x, na.rm = TRUE)), .groups = "drop")

#write.csv(atop, "data/blocks/Controls panel/alliance_gph.csv", row.names = FALSE)

alliances <- master %>%
  left_join(sov %>% rename(sov_s = sov), by = c("source" = "gph", "year")) %>%
  left_join(sov %>% rename(sov_t = sov), by = c("target" = "gph", "year")) %>%
  mutate(s_eff = if_else(as.integer(source) > 999, sov_s, source),
         t_eff = if_else(as.integer(target) > 999, sov_t, target),
         key_atop = paste0(pmin(s_eff, t_eff), "-", pmax(s_eff, t_eff))) %>%
  left_join(atop, by = c("key_atop", "year")) %>%
  mutate(
    dans_champ = !is.na(s_eff) & !is.na(t_eff) &
      as.integer(s_eff) <= 999 & as.integer(t_eff) <= 999 &
      s_eff != t_eff & year >= 1815 & year <= 2018,
    across(c(atop_allie, atop_defense, atop_offense, atop_neutral,
             atop_nonagg, atop_consul, atop_asymm),
           ~ if_else(dans_champ, coalesce(as.integer(.x), 0L), NA_integer_)),
    atop_herite = as.integer(dans_champ &
                               (as.integer(source) > 999 | as.integer(target) > 999))
  ) %>%
  select(key, year, starts_with("atop_"))

write.csv(alliances, "data/blocks/Controls panel/alliances.csv", row.names = FALSE)
