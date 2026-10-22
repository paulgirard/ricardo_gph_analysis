#DOT
rm(list = ls(all = TRUE))
gc()
library(readxl); library(dplyr)

#install.packages("remotes")
#remotes::install_github("opensdmx/rsdmx")
setwd('~/Desktop/ricardo_gph_analysis/')
library(rsdmx); library(dplyr)

#tele <- function(an, indic, essais = 5) {
  #for (i in seq_len(essais)) {
    #d <- try(as.data.frame(readSDMX(providerId = "IMF_DATA",
        #                            resource   = "data",
       #                             flowRef    = "IMF.STA,IMTS",
      #                              key        = paste0(".", indic, "..A"),
     #                               start      = an, end = an)), silent = TRUE)
    #if (!inherits(d, "try-error")) {
     # message(an, " : ", nrow(d), " lignes")
    #  gc()
     # return(d)
    #}
    #message(an, " : echec ", i, ", nouvelle tentative dans 5s")
   # Sys.sleep(5)
  #}
  #message(an, " : ABANDON")
 # NULL
#}

#res <- list()
#for (an in 1948:2024) {
  #res[[as.character(an)]] <- tele(an, "XG_FOB_USD")
 # saveRDS(res, "external data/IMTS_fob_partiel.rds")
#}

#res[["2025"]] <- tele(2025, "XG_FOB_USD")
#saveRDS(res, "external data/IMTS_fob_partiel.rds")

#fob <- bind_rows(res)
#nrow(fob)
#table(fob$TIME_PERIOD)
#saveRDS(fob, "external data/IMTS_fob.rds")

#res_cif <- list()
#for (an in 1948:2025) {
  #k <- as.character(an)
  #if (!is.null(res_cif[[k]])) next
  #res_cif[[k]] <- tele(an, "MG_CIF_USD")
 # saveRDS(res_cif, "external data/IMTS_cif_partiel.rds")
#}

#cif <- bind_rows(res_cif)
#nrow(cif)
#table(cif$TIME_PERIOD)
#saveRDS(cif, "external data/IMTS_cif.rds")


fob <- readRDS("external data/DoT Direction of Trade (IMF)/IMTS_fob.rds")
cif <- readRDS("external data/DoT Direction of Trade (IMF)/IMTS_cif.rds")
# --- Assemblage des deux indicateurs ---------------------------------
DOT <- bind_rows(fob, cif)

names(DOT)
DOT$TIME_PERIOD <- as.integer(DOT$TIME_PERIOD)
DOT$OBS_VALUE   <- as.numeric(DOT$OBS_VALUE)

DOT <- DOT %>% filter(!is.na(OBS_VALUE), !is.na(TIME_PERIOD))
DOT <- distinct(DOT)
nrow(DOT)

table(DOT$INDICATOR)
table(DOT$FREQUENCY)
table(DOT$SCALE)
table(DOT$DERIVATION_TYPE, useNA = "ifany")
table(DOT$STATUS, useNA = "ifany")
table(DOT$OVERLAP, useNA = "ifany")


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

# --- Correspondance GPH ----------------------------------------------
correspondancetable <- read_excel("scripts/tablegphdot.xlsx",
                                  sheet = "New", range = cell_cols("A:C"))
names(correspondancetable) <- c("CODE", "LIBELLE", "GPH")
correspondancetable$GPH <- as.integer(correspondancetable$GPH)

DOT <- DOT %>%
  left_join(correspondancetable %>% select(COUNTRY = CODE, GPH_reporter = GPH),
            by = "COUNTRY") %>%
  left_join(correspondancetable %>% select(COUNTERPART_COUNTRY = CODE, GPH_partner = GPH),
            by = "COUNTERPART_COUNTRY")

# diagnostics
DOT %>% summarise(total = n(),
                  na_rep = sum(is.na(GPH_reporter)),
                  na_par = sum(is.na(GPH_partner)),
                  pct = round(100 * mean(is.na(GPH_reporter) | is.na(GPH_partner)), 1))

DOT %>% filter(is.na(GPH_reporter)) %>% count(COUNTRY, sort = TRUE) %>% as.data.frame()
DOT %>% filter(is.na(GPH_partner))  %>% count(COUNTERPART_COUNTRY, sort = TRUE) %>% as.data.frame()

DOT <- DOT %>% filter(!is.na(GPH_reporter), !is.na(GPH_partner))


# --- URSS / Russie ----------------------------------------------------
n0 <- nrow(DOT)
DOT <- DOT %>%
  group_by(COUNTRY, GPH_partner, INDICATOR, TIME_PERIOD, FREQUENCY) %>%
  filter(!(COUNTERPART_COUNTRY == "SUN" & TIME_PERIOD > 1991 &
             any(COUNTERPART_COUNTRY == "RUS"))) %>%
  ungroup()
print(n0 - nrow(DOT))  # ok 153 obs toute impliquant SUN
# --- Serbie / Serbie-Montenegro ---------------------------------------
n1 <- nrow(DOT)
DOT <- DOT %>%
  group_by(COUNTRY, GPH_partner, INDICATOR, TIME_PERIOD, FREQUENCY) %>%
  filter(!(COUNTERPART_COUNTRY == "SRB" & TIME_PERIOD <= 2005 &
             any(COUNTERPART_COUNTRY == "SCG"))) %>%
  ungroup()
print(n1 - nrow(DOT))

# doublons residuels
DOT %>% count(GPH_reporter, GPH_partner, INDICATOR, TIME_PERIOD, FREQUENCY) %>%
  filter(n > 1) %>% count(GPH_partner)
# 1, OK



# --- Conversion en livres ---------------------------------------------
fx <- read.csv("external data/EXCHANGEPOUND_1948-2026.csv", skip = 4)
fx$Unit <- NULL
fx$Year <- as.integer(fx$Year)
fx$Rate <- as.numeric(fx$Rate)
fx <- fx[!duplicated(fx$Year), ]  # 2021 est en double dans le fichier


DOT <- DOT %>%
  left_join(fx %>% select(TIME_PERIOD = Year, USD_per_GBP = Rate), by = "TIME_PERIOD") %>%
  mutate(VALUE_USD = OBS_VALUE,
         VALUE_GBP = VALUE_USD / USD_per_GBP)

write.csv(DOT, gzfile("external data/DoT Direction of Trade (IMF)/DOT_gph.csv.gz"), row.names = FALSE)

# =============================================================================
# Conversion du DOT (FMI) au format tradeFlows_<year>_gravity.csv
## =============================================================================

library(dplyr); library(here); library(data.table)


#DOT <- DOT[!is.na(DOT$VALUE_GBP) & !is.na(DOT$TIME_PERIOD), ]
DOT <- DOT[!is.na(DOT$VALUE_USD) & !is.na(DOT$TIME_PERIOD), ]
# -----------------------------------------------------------------------------
# 1. Nom canonique par code GPH
# -----------------------------------------------------------------------------
noms <- read.csv("external data/GeoPolHist_entities.csv") %>%
  select(gph = GPH_code, nom = GPH_name) %>%
  mutate(gph = as.integer(gph)) %>%
  distinct()


setdiff(unique(c(DOT$GPH_reporter, DOT$GPH_partner)), noms$gph)

# -----------------------------------------------------------------------------
# 2. Mise au format RICardo
# -----------------------------------------------------------------------------

mise_au_format <- function(d, sens) {
  exp_gph <- if (sens == "export") d$GPH_reporter else d$GPH_partner
  imp_gph <- if (sens == "export") d$GPH_partner  else d$GPH_reporter
  
  tibble(
    id                           = paste0(exp_gph, "->", imp_gph),
    year                         = d$TIME_PERIOD,
    importerId                   = as.character(imp_gph),
    importerLabel                = noms$nom[match(imp_gph, noms$gph)],
    importerType                 = "GPH",
    exporterId                   = as.character(exp_gph),
    exporterLabel                = noms$nom[match(exp_gph, noms$gph)],
    exporterType                 = "GPH",
    value                        = d$VALUE_USD,
    reportedBy                   = as.character(d$GPH_reporter),
    partial                      = NA,
    valueToSplit                 = NA,
    newReporters                 = NA,
    newPartners                  = NA,
    originalReportedTradeFlowIds = NA_character_,
    status                       = "ok",
    notes                        = NA_character_
  )
}

flux_fob <- DOT %>% filter(INDICATOR == "XG_FOB_USD") %>% mise_au_format("export")
flux_cif <- DOT %>% filter(INDICATOR == "MG_CIF_USD") %>% mise_au_format("import")


nrow(flux_fob); nrow(flux_cif)
# -----------------------------------------------------------------------------
# 3. Ecriture d'un fichier par annee et par base
# -----------------------------------------------------------------------------
ecrire_par_annee <- function(flux, suffixe) {
  for (an in sort(unique(flux$year))) {
    d <- flux[flux$year == an, ]
    f <- paste0("external data/DoT Direction of Trade (IMF)/tradeFlows_", an, "_gravity_", suffixe, ".csv")
    write.csv(d, f, row.names = FALSE)
    message("  ", suffixe, " ", an, " : ", nrow(d), " flux, ",
            length(unique(c(d$exporterId, d$importerId))), " pays")
  }
}

ecrire_par_annee(flux_fob, "fob")
ecrire_par_annee(flux_cif, "caf")
