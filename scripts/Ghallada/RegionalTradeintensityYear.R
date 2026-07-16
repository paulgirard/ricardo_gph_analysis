
rm(list = ls(all = TRUE))
gc()

library(dplyr)
library(readxl)
library(tidyverse)
library(ggplot2)
setwd("~/Desktop/ricardo_gph_analysis")

annees <- 1833:1938
resultats_intra <- data.frame(year = integer(), moyenne = numeric(), n_blocs = integer())

for (year in annees) {
  f <- paste0("data/blocks/Intramax/paires_blocs_", year, ".csv")
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  d <- d[!is.na(d$value), ]
  if (nrow(d) == 0) next
  
  # ---- flux agrege par paire de blocs (TOUS les blocs, diagonale incluse) ----
  Xij <- aggregate(value ~ bloc_exp + bloc_imp, data = d, FUN = sum)
  names(Xij) <- c("i", "j", "Xij")
  blocs <- sort(unique(c(d$bloc_exp, d$bloc_imp)))
  
  grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
  grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
  grille$Xij[is.na(grille$Xij)] <- 0
  
  # ---- totaux (sur TOUT le commerce mondial) ----
  X_tot <- sum(grille$Xij)
  Xi <- tapply(grille$Xij, grille$i, sum)
  Xj <- tapply(grille$Xij, grille$j, sum)
  grille$Xi   <- Xi[as.character(grille$i)]
  grille$Xj   <- Xj[as.character(grille$j)]
  
  # ---- TIBI ----
  grille$s_ij <- grille$Xij / grille$Xi
  grille$Xrj  <- grille$Xj  - grille$Xij
  grille$Xr   <- X_tot      - grille$Xi
  grille$s_rj <- grille$Xrj / grille$Xr
  grille$I1 <- grille$s_ij / grille$s_rj
  grille$I3 <- (1 - grille$s_ij) / (1 - grille$s_rj)
  ratio <- grille$I1 / grille$I3
  grille$TIBI <- (ratio - 1) / (ratio + 1)
  
  tibi <- grille[, c("i", "j", "Xij", "TIBI")]
  
  # ---- identifier les singletons ----
  exp <- unique(d[, c("exportateur", "bloc_exp")]); names(exp) <- c("pays", "bloc")
  imp <- unique(d[, c("importateur", "bloc_imp")]); names(imp) <- c("pays", "bloc")
  pays_bloc <- unique(rbind(exp, imp))
  taille <- table(pays_bloc$bloc)
  blocs_singletons <- as.integer(names(taille)[taille == 1])
  
  # ---- retirer les singletons APRES le calcul, puis diagonale ----
  tibi_ss <- tibi[!(tibi$i %in% blocs_singletons) & !(tibi$j %in% blocs_singletons), ]
  diag_df <- tibi_ss[tibi_ss$i == tibi_ss$j & !is.nan(tibi_ss$TIBI) & is.finite(tibi_ss$TIBI),
                     c("i", "TIBI")]
  if (nrow(diag_df) < 1) next
  
  # ---- poids = part du bloc dans le commerce mondial ----
  diag_df$poids <- Xi[as.character(diag_df$i)] / X_tot
  diag_df$w <- diag_df$poids #/ sum(diag_df$poids)     # si on veut renormaliser sur les blocs retenus
  
  # ---- moyenne ponderee ----
  m <- sum(diag_df$w * diag_df$TIBI)
  
  resultats_intra <- rbind(resultats_intra, data.frame(
    year = year, moyenne = m, n_blocs = nrow(diag_df)))
}

# ---- graphe ----
p <- ggplot(resultats_intra, aes(year, moyenne)) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  coord_cartesian(ylim = c(-1, 1)) +
  labs(x = "année", y = "TIBI intra-bloc moyen (pondéré)",
       title = "Commerce Intra-bloc (intramax) moyen pondérée par année") +
  theme_minimal()

print(p)


ggsave("data/blocks/Intramax/tibi_intrabloc_moyen.png",
       plot = p, width = 9, height = 5, dpi = 150)
write.csv(resultats_intra, "data/blocks/Intramax/tibi_intrabloc_moyen.csv", row.names = FALSE)

#####Louvain method#####
rm(list = ls(all = TRUE))
gc()
library(dplyr)
library(readxl)
library(tidyverse)
library(ggplot2)
setwd("~/Desktop/ricardo_gph_analysis")
annees <- 1833:1938
resultats_louvain <- data.frame(year = integer(), moyenne = numeric(), n_blocs = integer())
for (year in annees) {
  f <- paste0("data/blocks/louvain/", year, "_fob_enrichi.csv")
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  if (nrow(d) == 0) next
  
  # ---- flux orientes bloc->bloc a partir de export et import ----
  # sens 1 : source -> target = export (sourceCommunity -> targetCommunity)
  f1 <- data.frame(i = d$sourceCommunity, j = d$targetCommunity, value = d$export)
  # sens 2 : target -> source = import (targetCommunity -> sourceCommunity)
  f2 <- data.frame(i = d$targetCommunity, j = d$sourceCommunity, value = d$import)
  flux <- rbind(f1, f2)
  flux <- flux[!is.na(flux$value), ]
  if (nrow(flux) == 0) next
  
  # ---- flux agrege par paire de blocs (TOUS les blocs, diagonale incluse) ----
  Xij <- aggregate(value ~ i + j, data = flux, FUN = sum)
  names(Xij) <- c("i", "j", "Xij")
  blocs <- sort(unique(c(flux$i, flux$j)))
  
  grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
  grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
  grille$Xij[is.na(grille$Xij)] <- 0
  
  # ---- totaux (sur TOUT le commerce mondial) ----
  X_tot <- sum(grille$Xij)
  Xi <- tapply(grille$Xij, grille$i, sum)
  Xj <- tapply(grille$Xij, grille$j, sum)
  grille$Xi   <- Xi[as.character(grille$i)]
  grille$Xj   <- Xj[as.character(grille$j)]
  
  # ---- TIBI ----
  grille$s_ij <- grille$Xij / grille$Xi
  grille$Xrj  <- grille$Xj  - grille$Xij
  grille$Xr   <- X_tot      - grille$Xi
  grille$s_rj <- grille$Xrj / grille$Xr
  grille$I1 <- grille$s_ij / grille$s_rj
  grille$I3 <- (1 - grille$s_ij) / (1 - grille$s_rj)
  ratio <- grille$I1 / grille$I3
  grille$TIBI <- (ratio - 1) / (ratio + 1)
  
  tibi <- grille[, c("i", "j", "Xij", "TIBI")]
  
  # ---- identifier les singletons (communautes a un seul pays) ----
  src <- unique(d[, c("sourceLabel", "sourceCommunity")]); names(src) <- c("pays", "bloc")
  tgt <- unique(d[, c("targetLabel", "targetCommunity")]); names(tgt) <- c("pays", "bloc")
  pays_bloc <- unique(rbind(src, tgt))
  taille <- table(pays_bloc$bloc)
  blocs_singletons <- as.integer(names(taille)[taille == 1])
  
  # ---- retirer les singletons APRES le calcul, puis diagonale ----
  tibi_ss <- tibi[!(tibi$i %in% blocs_singletons) & !(tibi$j %in% blocs_singletons), ]
  diag_df <- tibi_ss[tibi_ss$i == tibi_ss$j & !is.nan(tibi_ss$TIBI) & is.finite(tibi_ss$TIBI),
                     c("i", "TIBI")]
  if (nrow(diag_df) < 1) next
  
  # ---- poids = part du bloc dans le commerce mondial ----
  diag_df$poids <- Xi[as.character(diag_df$i)] / X_tot
  diag_df$w <- diag_df$poids #/ sum(diag_df$poids)     # si on veut renormaliser sur les blocs retenus
  
  # ---- moyenne ponderee ----
  m <- sum(diag_df$w * diag_df$TIBI)
  
  resultats_louvain <- rbind(resultats_louvain, data.frame(
    year = year, moyenne = m, n_blocs = nrow(diag_df)))
}
# ---- graphe ----
p <- ggplot(resultats_louvain, aes(year, moyenne)) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  coord_cartesian(ylim = c(-1, 1)) +
  labs(x = "année", y = "TIBI intra-communauté moyen (pondéré)",
       title = "Commerce Intra-communauté (Louvain) moyen pondéré par année") +
  theme_minimal()
print(p)
ggsave("data/blocks/louvain/tibi_intracomm_moyen.png",
       plot = p, width = 9, height = 5, dpi = 150)
write.csv(resultats_louvain, "data/blocks/louvain/tibi_intracomm_moyen.csv", row.names = FALSE)



#####Superposition des deux courbes#####
resultats_intra$methode   <- "Intramax"
resultats_louvain$methode <- "Louvain"
combine <- rbind(resultats_intra[, c("year", "moyenne", "methode")],
                 resultats_louvain[, c("year", "moyenne", "methode")])

p_combine <- ggplot(combine, aes(year, moyenne, color = methode)) +
  geom_line() + geom_point(size = 1) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  coord_cartesian(ylim = c(-1, 1)) +
  scale_color_manual(values = c("Intramax" = "#0055A4", "Louvain" = "#CF142B")) +
  labs(x = "année", y = "TIBI intra-bloc moyen (pondéré)",
       title = "Commerce intra-bloc moyen : Intramax vs Louvain",
       color = "Méthode") +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p_combine)

ggsave("data/blocks/tibi_comparaison_intramax_louvain.png",
       plot = p_combine, width = 10, height = 5, dpi = 150)