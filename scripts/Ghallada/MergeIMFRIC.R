#DOT
rm(list = ls(all = TRUE))
gc()
library(readxl); library(dplyr)
DOT<-read.csv("scripts/dataset_2026-09-10T10_46_06.578468509Z_DEFAULT_INTEGRATION_IMF.STA_IMTS_1.0.0.csv")
DOT <- distinct(DOT)
#library(dplyr)
#countries <- bind_rows(
# DOT %>% select(COUNTRY.ID, COUNTRY),
#DOT %>% select(COUNTRY.ID = COUNTERPART_COUNTRY.ID,
#              COUNTRY    = COUNTERPART_COUNTRY)
#) %>%
#  distinct(COUNTRY.ID, COUNTRY) %>%
# arrange(COUNTRY)
#library(openxlsx)
#write.xlsx(countries, "~/Dropbox/Postdoc Track/Project RICardo/IMF Integration/countries.xlsx") I complete it under a new file tablegphdot


# 1. La table de correspondance (colonnes A:C, E et F = légende)
correspondancetable <- read_excel(
  "scripts/tablegphdot.xlsx",
  sheet = "New", range = cell_cols("A:C")
)
names(correspondancetable) <- c("COUNTRY.ID", "COUNTRY", "GPH")
correspondancetable$GPH <- as.integer(correspondancetable$GPH)

# 2. Deux jointures : reporter, puis partner
DOT <- DOT %>%
  left_join(correspondancetable %>%
              select(COUNTRY.ID, GPH_reporter = GPH),
            by = "COUNTRY.ID") %>%
  left_join(correspondancetable %>%
              select(COUNTERPART_COUNTRY.ID = COUNTRY.ID, GPH_partner = GPH),
            by = "COUNTERPART_COUNTRY.ID")
#Delete non-GPH (groups
DOT %>%
  filter(is.na(GPH_reporter) | is.na(GPH_partner)) %>%
  distinct(id   = ifelse(is.na(GPH_reporter), COUNTRY.ID, COUNTERPART_COUNTRY.ID),
           name = ifelse(is.na(GPH_reporter), COUNTRY, COUNTERPART_COUNTRY)) %>%
  arrange(id) %>%
  as.data.frame() #Ok delete
## volume total concerné
DOT %>% summarise(
  total      = n(),
  na_rep     = sum(is.na(GPH_reporter)),
  na_par     = sum(is.na(GPH_partner)),
  na_l_un    = sum(is.na(GPH_reporter) | is.na(GPH_partner)),
  pct        = round(100 * mean(is.na(GPH_reporter) | is.na(GPH_partner)), 1)
)

# détail par code, côté reporter
DOT %>% filter(is.na(GPH_reporter)) %>%
  count(COUNTRY.ID, COUNTRY, sort = TRUE) %>% as.data.frame()

# détail par code, côté partenaire
DOT %>% filter(is.na(GPH_partner)) %>%
  count(COUNTERPART_COUNTRY.ID, COUNTERPART_COUNTRY, sort = TRUE) %>% as.data.frame()
#OK
DOT <- DOT %>% filter(!is.na(GPH_reporter), !is.na(GPH_partner))

n0 <- nrow(DOT)

DOT <- DOT %>%
  group_by(COUNTRY.ID, GPH_partner, INDICATOR.ID, TIME_PERIOD,
           FREQUENCY.ID, UNIT.ID, TRADE_FLOW.ID) %>%
  filter(!(COUNTERPART_COUNTRY.ID == "SUN" &
             TIME_PERIOD > 1991 &
             any(COUNTERPART_COUNTRY.ID == "RUS"))) %>%
  ungroup()

print(n0 - nrow(DOT))  # doit valoir 68
#Same for Serbia (only UK report both in 2005, choose Serbia and Montenegro for consistency)
n1 <- nrow(DOT)

DOT <- DOT %>%
  group_by(COUNTRY.ID, GPH_partner, INDICATOR.ID, TIME_PERIOD,
           FREQUENCY.ID, UNIT.ID, TRADE_FLOW.ID) %>%
  filter(!(COUNTERPART_COUNTRY.ID == "SRB" &
             TIME_PERIOD <= 2005 &
             any(COUNTERPART_COUNTRY.ID == "SCG"))) %>%
  ungroup()

print(n1 - nrow(DOT))   # 1, OK

DOT %>%
  count(GPH_reporter, GPH_partner, INDICATOR.ID, TIME_PERIOD,
        FREQUENCY.ID, UNIT.ID, TRADE_FLOW.ID) %>%
  filter(n > 1) %>%
  count(GPH_partner)
# Zero duplicates

# 3. Vérif : qui n'a pas matché ?
DOT %>% filter(is.na(GPH_reporter)) %>% distinct(COUNTRY.ID, COUNTRY) %>% print(n = 50)
DOT %>% filter(is.na(GPH_partner))  %>% distinct(COUNTERPART_COUNTRY.ID, COUNTERPART_COUNTRY) %>% print(n = 50)
#Aucun parfait
#Enlever les lignes sans années (pas de valeurs anyway)
DOT <- DOT %>% filter(!(is.na(TIME_PERIOD) & is.na(OBS_VALUE)))

#Include Sterling/Dollar rate and convert
fx <- read.csv("scripts/EXCHANGEPOUND_1948-2026.csv", skip = 4)
fx$Unit <- NULL          # constante ("$"), inutile
fx$Year <- as.integer(fx$Year)
fx$Rate <- as.numeric(fx$Rate)

#
fx <- fx[!duplicated(fx$Year), ]   # 2021 est en double dans le fichier


DOT <- DOT %>%
  left_join(fx %>% select(TIME_PERIOD = Year, USD_per_GBP = Rate),
            by = "TIME_PERIOD")

# valeurs en livres (OBS_VALUE est en millions de USD)
DOT <- DOT %>%
  mutate(
    VALUE_USD = if_else(SCALE == "Millions", OBS_VALUE * 1e6, OBS_VALUE),
    VALUE_GBP = VALUE_USD / USD_per_GBP
  )

#write.csv(DOT, "data/IMFdatawithgph.csv",
         # row.names = FALSE)
write.csv(DOT, gzfile("data/DOT_gph.csv.gz"), row.names = FALSE)

# =============================================================================
# Conversion du DOT (FMI) au format tradeFlows_<year>_gravity.csv
## =============================================================================

library(dplyr); library(here); library(data.table)


DOT <- DOT[!is.na(DOT$VALUE_GBP) & !is.na(DOT$TIME_PERIOD), ]

# -----------------------------------------------------------------------------
# 1. Nom canonique par code GPH
# -----------------------------------------------------------------------------
noms <- read.csv("data/GeoPolHist_entities.csv") %>%
  select(gph = GPH_code, nom = GPH_name) %>%
  mutate(gph = as.integer(gph)) %>%
  distinct()


setdiff(unique(c(DOT$GPH_reporter, DOT$GPH_partner)), noms$gph)

# -----------------------------------------------------------------------------
# 2. Mise au format RICardo
# -----------------------------------------------------------------------------

flux <- DOT %>%
  transmute(
    id                           = paste0(GPH_reporter, "->", GPH_partner),
    year                         = TIME_PERIOD,
    importerId                   = as.character(GPH_partner),
    importerLabel                = noms$nom[match(GPH_partner,  noms$gph)],
    importerType                 = "GPH", #to update if autonomous and cited later
    exporterId                   = as.character(GPH_reporter),
    exporterLabel                = noms$nom[match(GPH_reporter, noms$gph)],
    exporterType                 = "GPH",#to update if autonomous and cited later
    value                        = VALUE_GBP,
    reportedBy                   = as.character(GPH_reporter),
    partial                      = NA,
    valueToSplit                 = NA,
    newReporters                 = NA,
    newPartners                  = NA,
    originalReportedTradeFlowIds = NA_character_,
    status                       = "ok",
    notes                        = NA_character_
  )




# -----------------------------------------------------------------------------
# 3. Ecriture d'un fichier par annee
# -----------------------------------------------------------------------------
for (an in sort(unique(flux$year))) {
  d <- flux[flux$year == an, ]
  f <- paste0("data/tradeFlows_", an, "_gravity.csv")
  write.csv(d, f, row.names = FALSE)
  message("  ", an, " : ", nrow(d), " flux, ",
          length(unique(c(d$exporterId, d$importerId))), " pays")
}

