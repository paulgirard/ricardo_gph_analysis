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

# --- Helper : extrait des colonnes en remplaçant les absentes par NA ---
safe_cols <- function(df, cols) {
  out <- data.frame(row.names = seq_len(nrow(df)))
  for (c in cols) out[[c]] <- if (c %in% colnames(df)) df[[c]] else NA
  out
}

# --- 2. Boucle par année ---
annees <- c(1833:1938, 1948:2025)
master_panel <- list()

for (year in annees) {
  # === 2a. Intramax : base du panel ===
  f_intra <- paste0("data/blocks/Intramax/paires_blocs_", year, ".csv")
  if (!file.exists(f_intra) || file.info(f_intra)$size == 0) next
  di <- read.csv(f_intra, stringsAsFactors = FALSE)
  if (nrow(di) == 0) next
  
  di$exporterId <- as.character(di$exporterId)
  di$importerId <- as.character(di$importerId)
  
  if ("reportedBy" %in% colnames(di)) di$reportedBy <- as.character(di$reportedBy)
  
  # Renommer Intramax pour cohérence dans le master
  names(di)[names(di) == "bloc_exp"]  <- "intramax_exp"
  names(di)[names(di) == "bloc_imp"]  <- "intramax_imp"
  names(di)[names(di) == "meme_bloc"] <- "meme_intramax"
  names(di)[names(di) == "value"]     <- "export_intramax"
  
  # === 2b. Louvain ===
  f_louvain <- paste0("data/blocks/louvain/", year, "_fob_enrichi.csv")
  if (file.exists(f_louvain) && file.info(f_louvain)$size > 0) {
    dl <- read.csv(f_louvain, stringsAsFactors = FALSE)
    dl$source <- as.character(dl$source)
    dl$target <- as.character(dl$target)
    
    # --- Table pays -> communauté (dédupliquée) ---
    src <- unique(dl[, c("source", "sourceCommunity")])
    tgt <- unique(dl[, c("target", "targetCommunity")])
    names(src) <- c("gph", "louvain_comm")
    names(tgt) <- c("gph", "louvain_comm")
    pays_comm <- unique(rbind(src, tgt))
    
    di <- merge(di, pays_comm, by.x = "exporterId", by.y = "gph", all.x = TRUE)
    names(di)[names(di) == "louvain_comm"] <- "louvain_exp"
    di <- merge(di, pays_comm, by.x = "importerId", by.y = "gph", all.x = TRUE)
    names(di)[names(di) == "louvain_comm"] <- "louvain_imp"
    di$meme_louvain <- as.integer(di$louvain_exp == di$louvain_imp)
    
    # --- Colonnes Louvain à récupérer ---
    cols_edge <- c("proximity", "coMembershipScore",
                   "bridgeNessEdgeScore", "ambiguityScore", "sourceCommunityId")
    cols_source_country <- c("sourceCited", "sourceReporting", "sourceGphStatus",
                             "sourceMeanAmbiguityScore")
    cols_target_country <- c("targetCited", "targetReporting", "targetGphStatus",
                             "targetMeanAmbiguityScore")
    
    # --- CAS 1 : ligne Louvain source=E, target=I  ->  export = flux E→I ---
    flow_case1 <- data.frame(
      from_exporter  = dl$source,
      to_importer    = dl$target,
      export_louvain = if ("export" %in% colnames(dl)) dl$export else NA_real_,
      stringsAsFactors = FALSE
    )
    flow_case1 <- cbind(flow_case1, safe_cols(dl, cols_edge))
    exp_metrics_c1 <- safe_cols(dl, cols_source_country)
    imp_metrics_c1 <- safe_cols(dl, cols_target_country)
    names(exp_metrics_c1) <- c("exp_Cited", "exp_Reporting", "exp_GphStatus", "exp_MeanAmbiguityScore")
    names(imp_metrics_c1) <- c("imp_Cited", "imp_Reporting", "imp_GphStatus", "imp_MeanAmbiguityScore")
    flow_case1 <- cbind(flow_case1, exp_metrics_c1, imp_metrics_c1)
    
    # --- CAS 2 : ligne Louvain source=I, target=E  ->  import = flux E→I ---
    flow_case2 <- data.frame(
      from_exporter  = dl$target,
      to_importer    = dl$source,
      export_louvain = if ("import" %in% colnames(dl)) dl$import else NA_real_,
      stringsAsFactors = FALSE
    )
    flow_case2 <- cbind(flow_case2, safe_cols(dl, cols_edge))
    exp_metrics_c2 <- safe_cols(dl, cols_target_country)
    imp_metrics_c2 <- safe_cols(dl, cols_source_country)
    names(exp_metrics_c2) <- c("exp_Cited", "exp_Reporting", "exp_GphStatus", "exp_MeanAmbiguityScore")
    names(imp_metrics_c2) <- c("imp_Cited", "imp_Reporting", "imp_GphStatus", "imp_MeanAmbiguityScore")
    flow_case2 <- cbind(flow_case2, exp_metrics_c2, imp_metrics_c2)
    
    # --- Combiner les 2 cas ---
    flow_louvain <- rbind(flow_case1, flow_case2)
    flow_louvain <- flow_louvain[!is.na(flow_louvain$export_louvain), ]
    
    di <- merge(di, flow_louvain,
                by.x = c("exporterId", "importerId"),
                by.y = c("from_exporter", "to_importer"),
                all.x = TRUE)
  } else {
    # Placeholders si pas de fichier Louvain
    di$louvain_exp    <- NA
    di$louvain_imp    <- NA
    di$meme_louvain   <- NA
    di$export_louvain <- NA
    for (v in c("proximity", "coMembershipScore",
                "bridgeNessEdgeScore", "ambiguityScore", "sourceCommunityId",
                "exp_Cited", "exp_Reporting", "exp_GphStatus", "exp_MeanAmbiguityScore",
                "imp_Cited", "imp_Reporting", "imp_GphStatus", "imp_MeanAmbiguityScore")) {
      di[[v]] <- NA
    }
  }
  
  # === 2c. Anderson-Norheim ===
  di <- merge(di, region_map, by.x = "exporterId", by.y = "GPH_code", all.x = TRUE)
  names(di)[names(di) == "region_AndersonNorheim"] <- "region_AN_exp"
  di <- merge(di, region_map, by.x = "importerId", by.y = "GPH_code", all.x = TRUE)
  names(di)[names(di) == "region_AndersonNorheim"] <- "region_AN_imp"
  di$meme_AN <- as.integer(di$region_AN_exp == di$region_AN_imp)
  
  # Nettoyer les year en double hérités du merge Intramax↔gravity
  if ("year.x" %in% colnames(di)) {
    di$year <- di$year.x
    di$year.x <- NULL
    di$year.y <- NULL
  }
  
  master_panel[[as.character(year)]] <- di
  cat("Année", year, ":", nrow(di), "paires\n")
}

# --- 3. Assembler ---
master <- bind_rows(master_panel)

cat("\n=== Master panel ===\n")
cat("Dimensions :", dim(master), "\n")
cat("Années couvertes :", min(master$year), "→", max(master$year), "\n")

# --- 4. Sanity check : export_intramax vs export_louvain ---
cat("\n=== Sanity check flux : Intramax vs Louvain ===\n")
comp <- master %>%
  filter(!is.na(export_intramax) & !is.na(export_louvain)) %>%
  summarise(
    n_paires_comparees = n(),
    correlation        = cor(export_intramax, export_louvain),
    diff_moyenne_abs   = mean(abs(export_intramax - export_louvain)),
    diff_relative_mean = mean(abs(export_intramax - export_louvain) /
                                pmax(export_intramax, 1))
  )
print(comp)

n_ecart <- sum(abs(master$export_intramax - master$export_louvain) /
                 pmax(master$export_intramax, 1) > 0.01, na.rm = TRUE)
cat("\nPaires avec écart Intramax vs Louvain > 1% :", n_ecart, "\n")


# --- 6. Sauvegarde ---
#write.csv(master, "data/blocks/master_panel_3methodes.csv", row.names = FALSE)
write.csv(master, gzfile("data/blocks/master_panel_3methodes.csv.gz"), row.names = FALSE)


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

