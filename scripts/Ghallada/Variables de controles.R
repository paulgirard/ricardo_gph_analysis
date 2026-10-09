################################################################
#####  MASTER PANEL : Intramax + Louvain + Anderson-Norheim  ####
################################################################

rm(list = ls(all = TRUE))
gc()

library(dplyr)
library(readxl)
library(tidyverse)
user <- Sys.info()["user"]
if (user == "guillaumedaudin") {
  setwd("~/Répertoires Git/ricardo_gph_analysis")
} else {
  setwd("~/Desktop/ricardo_gph_analysis")
}

# --- 1. Mapping Anderson-Norheim ---
BlocselonAN <- read.csv("external data/BlocselonAN.csv")
region_map <- BlocselonAN[, c("GPH_code", "region_AndersonNorheim")]
region_map$GPH_code <- as.character(region_map$GPH_code)

dossier <- "results/communities/gph_blocks_by_year"
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
write.csv(master, "external data/Controls panel/panel_blocs_paires.csv", row.names = FALSE)

# --- Distance entre centroides ----------------------------------------
coord <- read.csv("external data/GeoPolHist_entities.csv", stringsAsFactors = FALSE) %>%
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

write.csv(distance, "external data/Controls panel/distance.csv", row.names = FALSE)

#Verifier d'abord si matrice complete en terme de doublons (càd on a a>b b>a)
raw <- read.csv("external data/DirectContiguity320/contdird.csv", stringsAsFactors = FALSE) %>%
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
contig <- read.csv("external data/DirectContiguity320/contdird.csv", stringsAsFactors = FALSE) %>%
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
manuel <- read.csv2("external data/na_contig_paires complete.csv",
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


write.csv(contiguity, "external data/Controls panel/contiguity.csv", row.names = FALSE)

#Restant à coder
library(dplyr); library(writexl)

noms <- read.csv("external data/GeoPolHist_entities.csv", stringsAsFactors = FALSE) %>%
  transmute(gph = as.character(GPH_code), nom = GPH_name,
            lat = lat, lng = lng)

a_coder <- master %>%
  filter(as.integer(source) > 999 | as.integer(target) > 999) %>%
  anti_join(manuel, by = "key") %>%
  group_by(key, source, target) %>%
  summarise(premiere_annee = min(year),
            derniere_annee = max(year),
            n_annees       = n(), .groups = "drop") %>%
  left_join(noms, by = c("source" = "gph")) %>%
  rename(source_nom = nom, source_lat = lat, source_lng = lng) %>%
  left_join(noms, by = c("target" = "gph")) %>%
  rename(target_nom = nom, target_lat = lat, target_lng = lng) %>%
  left_join(distance %>% select(key, distance_km), by = "key") %>%
  select(key, source, source_nom, source_lat, source_lng,
         target, target_nom, target_lat, target_lng,
         distance_km, premiere_annee, derniere_annee, n_annees) %>%
  mutate(conttype = NA_integer_) %>%
  arrange(distance_km)

write_xlsx(a_coder, "external data/Controls panel/na_contig_a_coder.xlsx")
write.csv(a_coder, "external data/Controls panel/na_contig_a_coder.csv", row.names = FALSE)
nrow(a_coder)
n_distinct(master$key)
#Map
########################################################
#####  Carte interactive                           #####
########################################################
# Au-dela de seuil_km on cartographie pas

library(leaflet); library(leaflet.extras); library(htmlwidgets)
library(rnaturalearth); library(sf)

seuil_km <- 2500

carte_df <- a_coder %>%
  filter(!is.na(source_lat), !is.na(target_lat), distance_km <= seuil_km) %>%
  mutate(
    ent     = if_else(as.integer(source) > 999, source_nom, target_nom),
    ent_lat = if_else(as.integer(source) > 999, source_lat, target_lat),
    ent_lng = if_else(as.integer(source) > 999, source_lng, target_lng),
    popup   = paste0("<b>", source_nom, " &harr; ", target_nom, "</b><br>",
                     "cle : ", key, "<br>",
                     "distance : ", round(distance_km), " km<br>",
                     "annees : ", premiere_annee, "-", derniere_annee,
                     " (", n_annees, ")"))

cat(nrow(carte_df), "paires sous", seuil_km, "km\n")

couleur <- function(d) {
  ifelse(d <=  50, "#CF142B",
         ifelse(d <= 200, "#E07B39",
                ifelse(d <= 500, "#0055A4", "#777777")))
}

# --- fond de carte local (aucun serveur de tuiles) --------------------
monde <- ne_countries(scale = "medium", returnclass = "sf")

m <- leaflet(options = leafletOptions(preferCanvas = TRUE)) %>%
  addPolygons(data = monde, fillColor = "#f0f0ec", fillOpacity = 1,
              color = "#999", weight = 0.6, smoothFactor = 0.5)

# --- une couche par entite hors COW -----------------------------------
entites <- sort(unique(carte_df$ent))

for (e in entites) {
  sub <- carte_df[carte_df$ent == e, ]
  m <- m %>%
    addPolylines(data = sub,
                 lng = ~c(rbind(source_lng, target_lng, NA)),
                 lat = ~c(rbind(source_lat, target_lat, NA)),
                 color = "#0055A4", weight = 2, opacity = 0.7, group = e) %>%
    addCircleMarkers(data = sub,
                     lng = ~target_lng, lat = ~target_lat,
                     radius = 3, stroke = FALSE, fillOpacity = 0.8,
                     fillColor = ~couleur(distance_km),
                     popup = ~popup, group = e)
}

# --- points des entites, cherchables ----------------------------------
pts <- carte_df %>% distinct(ent, ent_lat, ent_lng)

m <- m %>%
  addCircleMarkers(data = pts, lng = ~ent_lng, lat = ~ent_lat,
                   radius = 5, color = "#CF142B", fillOpacity = 0.9,
                   stroke = FALSE, label = ~ent, group = "entites") %>%
  addSearchFeatures(targetGroups = "entites",
                    options = searchFeaturesOptions(zoom = 4, openPopup = TRUE,
                                                    hideMarkerOnCollapse = FALSE)) %>%
  addLayersControl(overlayGroups = c("entites", entites),
                   options = layersControlOptions(collapsed = TRUE)) %>%
  hideGroup(entites) %>%
  addLegend("bottomright",
            colors = c("#CF142B", "#E07B39", "#0055A4", "#777777"),
            labels = c("< 50 km", "50-200 km", "200-500 km", "> 500 km"),
            title = "Distance centroides")

saveWidget(m, "external data/Controls panel/carte_paires_a_coder.html",
           selfcontained = TRUE)


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
BilateralDis <- read.csv("external data/dyadic_mid_4.03_update/dyadic_mid_4.03.csv",
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

sov_brut <- read.csv("external data/GeoPolHist_entities_status_over_time.csv",
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

write.csv(disputes, "external data/Controls panel/disputes.csv", row.names = FALSE)

###########
#Alliances# (for symetry, j'ai pris max des 2 sens)
###########

atop <- read.csv("external data/ATOP 5.1 (.csv)/atop5_1ddyr.csv", stringsAsFactors = FALSE) %>%
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

#write.csv(atop, "external data/Controls panel/alliance_gph.csv", row.names = FALSE)

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

write.csv(alliances, "external data/Controls panel/alliances.csv", row.names = FALSE)


#################
#Trade Agreement# '(Raw Dataset directly given by Pahre)
#################
library(tidyverse)
library(haven)
tad_codes <- read.csv2("external data/Pahre data/TAD country codes.csv",
                       fileEncoding = "UTF-8-BOM", stringsAsFactors = FALSE)
tad_codes <- tad_codes %>% mutate(GPH = na_if(trimws(GPH), "XXX"))

aggregats <- c("sum","esum","asum")
tous <- c(tad_codes$code, aggregats)
c("wld", "trv") %in% tous      # doit donner TRUE TRUE

split_pair <- function(x) {
  s <- sub("^[tz]", "", x)
  if (s %in% tous) return(c(s, NA_character_))      # zngc, zsum : un seul code
  for (i in seq_len(nchar(s) - 1)) {
    a <- substr(s, 1, i); b <- substr(s, i + 1, nchar(s))
    if (a %in% tous && b %in% tous) return(c(a, b))
  }
  c(NA_character_, NA_character_)
}

cles   <- grep("^[tz]", setdiff(names(tad_public), "year"), value = TRUE)
paires <- t(sapply(cles, split_pair))

lookup <- tibble(colonne   = cles,
                 serie     = substr(cles, 1, 1),
                 country_A = paires[, 1],
                 country_B = paires[, 2])

# contrôle : doit renvoyer 0 ligne
lookup %>% filter(is.na(country_A))

tad_long <- tad_public %>%
  select(year, all_of(cles)) %>%
  pivot_longer(-year, names_to = "colonne", values_to = "TA") %>%
  left_join(lookup, by = "colonne") %>%
  left_join(tad_codes %>% select(code, name_A = Name, GPH_A = GPH),
            by = c("country_A" = "code")) %>%
  left_join(tad_codes %>% select(code, name_B = Name, GPH_B = GPH),
            by = c("country_B" = "code")) %>%
  select(serie, country_A, name_A, GPH_A,
         country_B, name_B, GPH_B, year, TA)

tad_bilat <- tad_long %>% filter(!is.na(country_B), !country_B %in% aggregats)
tad_bilat_gph <- tad_bilat %>% filter(!is.na(GPH_A), !is.na(GPH_B))

# --- Cle non orientee, meme convention que master ---------------------
tad_pairs <- tad_bilat_gph %>%
  mutate(key = paste0(pmin(GPH_A, GPH_B), "-", pmax(GPH_A, GPH_B)))

# Controles : self-pairs et collisions après clé
tad_pairs %>% filter(GPH_A == GPH_B) %>% count(country_A, country_B)
tad_pairs %>% count(key, year, serie) %>% filter(n > 1) #Ok juste us-uk mais pas de contradiction (sauf na dans l'un et pas dans l'autre)

# --- Une ligne par cle-annee, une colonne par serie -------------------
tad_key <- tad_pairs %>%
  group_by(key, year) %>%
  summarise(TA = if (all(is.na(TA))) NA_real_ else max(TA, na.rm = TRUE),
            .groups = "drop")

tad_key %>% count(key, year) %>% filter(n > 1)   # 0 ligne ok 48

trade_agreements <- master %>%
  select(key, year, source, target) %>%
  left_join(tad_key, by = c("key", "year")) %>%
  select(key, year, TA)

colSums(is.na(trade_agreements))
table(trade_agreements$TA, useNA = "ifany")

write.csv(trade_agreements, "external data/Controls panel/trade_agreements.csv",
          row.names = FALSE)
