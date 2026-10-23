rm(list = ls(all = TRUE))
gc()
library(dplyr)
options(max.print=10000000)
library(tidyverse)
library(readxl)
library(ggplot2)
library(writexl)
library(igraph)
library(here)

annees_ric <- 1833:1938
annees_imf <- 1948:2025
annees_all <- c(annees_ric, annees_imf)

traiter_annee <- function(year, dossier, seuil = 0.10) {
  
  fichier <- file.path(dossier, paste0("gravity_", year, ".csv"))
  if (!file.exists(fichier)) { message("  fichier absent : ", year); return(NULL) }
  
  # ---- chargement, moyenne des declarations par paire ----
  Net <- read.csv(fichier)
  Net$exporterId <- as.character(Net$exporterId)
  Net$importerId <- as.character(Net$importerId)
  Net <- Net[Net$status == "ok", ]
  exclure <- c("Rest Of The World")
  Net <- Net[!(Net$exporterLabel %in% exclure | Net$importerLabel %in% exclure), ]
  
  df <- Net[!is.na(Net$exporterId) & !is.na(Net$importerId) & !is.na(Net$value), ]
  if (nrow(df) == 0) { message("  aucune donnee : ", year); return(NULL) }
  
  df$a <- pmin(df$exporterId, df$importerId)
  df$b <- pmax(df$exporterId, df$importerId)
  
  moy <- df %>%
    group_by(a, b) %>%
    summarise(value  = mean(value),
              n_flux = n(),
              n_fob  = sum(CafFob == "fob"),
              n_caf  = sum(CafFob == "caf"),
              .groups = "drop")
  
  # ---- matrice symetrique ----
  pays <- sort(unique(c(moy$a, moy$b)))
  M <- matrix(NA_real_, length(pays), length(pays), dimnames = list(pays, pays))
  M[cbind(match(moy$a, pays), match(moy$b, pays))] <- moy$value
  M[cbind(match(moy$b, pays), match(moy$a, pays))] <- moy$value
  
  garde <- rowSums(!is.na(M)) > 0 | colSums(!is.na(M)) > 0
  M <- M[garde, garde]
  M <- M / sum(M, na.rm = TRUE)
  
  # ---- intramax ----
  historique <- data.frame(etape = integer(), flux_interne = numeric())
  etats <- list(); etape <- 0
  
  while (nrow(M) > 1) {
    etape <- etape + 1
    etats[[etape]] <- rownames(M)
    tl <- rowSums(M, na.rm = TRUE); tc <- colSums(M, na.rm = TRUE); tot <- sum(M, na.rm = TRUE)
    E <- outer(tl, tc) / tot
    Dd <- M / E - 1
    Dd[!is.finite(Dd) & !is.na(M)] <- 0
    D  <- pmax(Dd, t(Dd), na.rm = TRUE)
    D[lower.tri(D, diag = TRUE)] <- NA
    if (all(is.na(D))) break
    g <- which(D == max(D, na.rm = TRUE), arr.ind = TRUE)[1, ]
    i <- g[1]; j <- g[2]
    flux_interne <- sum(M[i, j], M[j, i], na.rm = TRUE)
    historique <- rbind(historique, data.frame(etape = etape, flux_interne = flux_interne))
    M[i, ] <- colSums(M[c(i, j), ], na.rm = TRUE)
    M[, i] <- rowSums(M[, c(i, j)], na.rm = TRUE)
    M[i, i] <- NA
    M <- M[-j, -j, drop = FALSE]
    rownames(M)[i] <- colnames(M)[i] <- paste(etats[[etape]][i], etats[[etape]][j], sep = "+")
  }
  
  # ---- cutoff a seuil ----
  rupture <- which(historique$flux_interne >= seuil)[1]
  if (is.na(rupture)) { message("  aucun saut >= ", seuil, " : ", year); return(NULL) }
  
  groupes   <- strsplit(etats[[rupture]], "+", fixed = TRUE)
  pays_bloc <- data.frame(id = unlist(groupes),
                          bloc = rep(seq_along(groupes), lengths(groupes)),
                          stringsAsFactors = FALSE)
  
  # ---- paires non orientees ----
  paires <- as.data.frame(t(combn(pays_bloc$id, 2)), stringsAsFactors = FALSE) # produit qu'une valeur par pair
  names(paires) <- c("a", "b")
  paires$bloc_a    <- pays_bloc$bloc[match(paires$a, pays_bloc$id)]
  paires$bloc_b    <- pays_bloc$bloc[match(paires$b, pays_bloc$id)]
  paires$meme_bloc <- as.integer(paires$bloc_a == paires$bloc_b)
  paires$year      <- year
  
  paires <- left_join(paires, moy, by = c("a", "b"))
  
  # ---- libelles ----
  lab <- bind_rows(
    Net %>% select(id = exporterId, label = exporterLabel),
    Net %>% select(id = importerId, label = importerLabel)
  ) %>% filter(!is.na(id)) %>% distinct(id, .keep_all = TRUE)
  
  paires <- paires %>%
    left_join(lab %>% rename(label_a = label), by = c("a" = "id")) %>%
    left_join(lab %>% rename(label_b = label), by = c("b" = "id"))
  
  # ---- export ----
  out <- file.path(here("results","communities","Intramax"), paste0("paires_blocs_", year, ".csv"))
  write.csv(paires, out, row.names = FALSE)
  message("  OK ", year, " : ", nrow(paires), " paires -> ", basename(out))
  return(paires)
}

# ================= BOUCLE =================
setwd("~/Desktop/ricardo_gph_analysis")
dossier <- "results/gravity"


for (year in annees_all) {
  message("Annee ", year)
  res <- tryCatch(traiter_annee(year, dossier),
                  error = function(e) { message("  ERREUR ", year, " : ", conditionMessage(e)); NULL })
}

