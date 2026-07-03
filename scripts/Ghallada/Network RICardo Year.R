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

traiter_annee <- function(year, dossier, seuil = 0.10) {
  
  fichier <- file.path(dossier, paste0("tradeFlows_", year, "_gravity.csv"))
  if (!file.exists(fichier)) { message("  fichier absent : ", year); return(NULL) }
  
  # ---- chargement + filtre exportateur (FOB) ----
  Net <- read.csv(fichier)
  Net <- Net[Net$status == "ok", ]
  Net <- Net[Net$reportedBy == Net$exporterId, ]
  
  df <- Net[, c("exporterLabel", "importerLabel", "value")]
  df <- df[!is.na(df$exporterLabel) & !is.na(df$importerLabel) & !is.na(df$value), ]
  if (nrow(df) == 0) { message("  aucune donnee : ", year); return(NULL) }
  
  # ---- matrice ----
  pays <- sort(unique(c(as.character(df$exporterLabel), as.character(df$importerLabel))))
  M <- matrix(NA_real_, length(pays), length(pays), dimnames = list(pays, pays))
  M[cbind(match(df$exporterLabel, pays), match(df$importerLabel, pays))] <- df$value
  
  garde <- rowSums(M, na.rm = TRUE) > 0 | colSums(M, na.rm = TRUE) > 0
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
    Dd[!is.finite(Dd)] <- 0
    D  <- pmax(Dd, t(Dd))
    D[lower.tri(D, diag = TRUE)] <- NA
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
  pays_bloc <- data.frame(pays = unlist(groupes),
                          bloc = rep(seq_along(groupes), lengths(groupes)),
                          stringsAsFactors = FALSE)
  
  # ---- paires ----
  paires <- expand.grid(exportateur = pays_bloc$pays, importateur = pays_bloc$pays,
                        stringsAsFactors = FALSE)
  paires <- paires[paires$exportateur != paires$importateur, ]
  paires$bloc_exp  <- pays_bloc$bloc[match(paires$exportateur, pays_bloc$pays)]
  paires$bloc_imp  <- pays_bloc$bloc[match(paires$importateur, pays_bloc$pays)]
  paires$meme_bloc <- as.integer(paires$bloc_exp == paires$bloc_imp)
  paires$year <- year                                    # <-- colonne annee (utile pour empiler apres)
  
  # merge avec toutes les variables gravitaires
  paires <- merge(paires, Net,
                  by.x = c("exportateur", "importateur"),
                  by.y = c("exporterLabel", "importerLabel"), all.x = TRUE)
  
  # ---- export ----
  out <- file.path(dossier, paste0("paires_blocs_", year, ".csv"))
  write.csv(paires, out, row.names = FALSE)
  message("  OK ", year, " : ", nrow(paires), " paires -> ", basename(out))
  return(paires)
}

# ================= BOUCLE =================
dossier <- here("Pair_blocs_Intramax")

for (year in 1833:1938) {
  message("Annee ", year)
  res <- tryCatch(traiter_annee(year, dossier),
                  error = function(e) { message("  ERREUR ", year, " : ", conditionMessage(e)); NULL })
}

# ================= Recupérere les corrélations =================
dossier <- here("Pair_blocs_Intramax")
annees  <- 1833:1938

cor_par_annee <- data.frame(year = integer(), cor = numeric())

for (year in annees) {
  f <- file.path(dossier, paste0("paires_blocs_", year, ".csv"))
  if (!file.exists(f)) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  lv <- log1p(d$value)                          # log(1+value), garde les zeros
  r  <- cor(d$meme_bloc, lv, use = "complete.obs", method = "pearson")
  cor_par_annee <- rbind(cor_par_annee, data.frame(year = year, cor = r))
}

# ---- graphe : annee en x, correlation en y ----
plot(cor_par_annee$year, cor_par_annee$cor, type = "b", pch = 19,
     xlab = "annee", ylab = "correlation meme_bloc / log(value)",
     main = "Correlation meme_bloc <-> commerce par annee")
abline(h = 0, lty = 3, col = "grey60")           # ligne de reference a 0

# ================= Recupérere les corrélations avec IC =================
cor_par_annee <- data.frame(year = integer(), cor = numeric(),
                            ic_bas = numeric(), ic_haut = numeric(), n = integer())

for (year in annees) {
  f <- file.path(dossier, paste0("paires_blocs_", year, ".csv"))
  if (!file.exists(f)) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  lv <- log1p(d$value)                          # log(1+value), garde les zeros

  ct <- cor.test(d$meme_bloc, log1p(d$value))        # Pearson + IC 95%
  cor_par_annee <- rbind(cor_par_annee, data.frame(
    year = year, cor = ct$estimate,
    ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2], n = sum(ok)))
}

# ---- graphe : annee en x, correlation en y ----
ggplot(cor_par_annee, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  labs(x = "année", y = "corrélation même_bloc / log(value)",
       title = "Corrélation même_bloc ↔ commerce (IC 95%)") +
  theme_minimal()
