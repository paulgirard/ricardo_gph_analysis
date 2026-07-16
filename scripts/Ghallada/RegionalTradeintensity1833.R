
rm(list = ls(all = TRUE))
gc()

library(dplyr)
library(readxl)
library(tidyverse)

setwd("/Users/youssef/Desktop/ricardo_gph_analysis")


d <- read.csv("data/blocks/Intramax/paires_blocs_1833.csv",
              stringsAsFactors = FALSE)
d <- d[!is.na(d$value), ]

# ---- flux agrege par paire de blocs (i -> j), y compris i == j (intra-bloc) ----
Xij <- aggregate(value ~ bloc_exp + bloc_imp, data = d, FUN = sum)
names(Xij) <- c("i", "j", "Xij")

blocs <- sort(unique(c(d$bloc_exp, d$bloc_imp)))

# grille complete de TOUTES les paires (i, j), diagonale INCLUSE
grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
grille$Xij[is.na(grille$Xij)] <- 0

# ---- totaux ----
X_tot <- sum(grille$Xij)                          # total mondial (intra + inter)
Xi <- tapply(grille$Xij, grille$i, sum)           # X_i. : exports totaux du bloc i (vers tous, i inclus)
Xj <- tapply(grille$Xij, grille$j, sum)           # X_.j : exports totaux vers le bloc j

# ---- TIBI pour chaque paire (i, j) ----
grille$Xi   <- Xi[as.character(grille$i)]
grille$Xj   <- Xj[as.character(grille$j)]
grille$s_ij <- grille$Xij / grille$Xi             # X_ij/X_i the share of exports to region j in the total exports of region i

grille$Xrj  <- grille$Xj  - grille$Xij            # X_rj is the amount of exports to region j in exports from
                                                  # from the row excluding exports from region i
grille$Xr   <- X_tot      - grille$Xi             # X_r. is the total exports excluding export of region i
grille$s_rj <- grille$Xrj / grille$Xr

grille$I1 <- grille$s_ij / grille$s_rj                     # A2 in Daudin et al.(2011, p. 1434)
grille$I3 <- (1 - grille$s_ij) / (1 - grille$s_rj)        # A4
ratio <- grille$I1 / grille$I3
grille$TIBI <- (ratio - 1) / (ratio + 1)                  # A5

# ---- resultat ----
tibi <- grille[, c("i", "j", "Xij", "TIBI")]
tibi <- tibi[order(tibi$i, tibi$j), ]

# rassembler chaque entite avec son bloc (les deux cotes)
exp <- unique(d[, c("exportateur", "bloc_exp")]); names(exp) <- c("pays", "bloc")
imp <- unique(d[, c("importateur", "bloc_imp")]); names(imp) <- c("pays", "bloc")
pays_bloc <- unique(rbind(exp, imp))

# taille de chaque bloc
taille <- table(pays_bloc$bloc)

# les blocs singletons (un seul pays)
blocs_singletons <- as.integer(names(taille)[taille == 1])

# filtrer le data.frame tibi
tibi_sans_singletons <- tibi[!(tibi$i %in% blocs_singletons) &
                               !(tibi$j %in% blocs_singletons), ]

# matrice propre
mat <- xtabs(TIBI ~ i + j, data = tibi_sans_singletons)
df_final <- round(as.data.frame.matrix(mat), 3)

diag_tibi <- tibi_sans_singletons[tibi_sans_singletons$i == tibi_sans_singletons$j & !is.nan(tibi_sans_singletons$TIBI), c("i", "TIBI")]


library(dplyr)
setwd("~/Desktop/ricardo_gph_analysis")

d <- read.csv("data/blocks/louvain/1833_fob_enrichi.csv", stringsAsFactors = FALSE)

# ---- construire les flux orientes bloc->bloc a partir de export et import (fob), reporter de import est l'export du flux inverse ----
# sens 1 : source -> target, flux = export, blocs (sourceCommunity -> targetCommunity)
f1 <- data.frame(i = d$sourceCommunity, j = d$targetCommunity, value = d$export)
# sens 2 : target -> source, flux = import, blocs (targetCommunity -> sourceCommunity)
f2 <- data.frame(i = d$targetCommunity, j = d$sourceCommunity, value = d$import)

flux <- rbind(f1, f2)
flux <- flux[!is.na(flux$value), ]        # garder les flux observes

# ---- flux agrege par paire de blocs (i -> j) ----
Xij <- aggregate(value ~ i + j, data = flux, FUN = sum)

blocs <- sort(unique(c(flux$i, flux$j)))

grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
names(grille)[names(grille) == "value"] <- "Xij"
grille$Xij[is.na(grille$Xij)] <- 0

# ---- totaux (commerce mondial complet) ----
X_tot <- sum(grille$Xij)
Xi <- tapply(grille$Xij, grille$i, sum)
Xj <- tapply(grille$Xij, grille$j, sum)
grille$Xi <- Xi[as.character(grille$i)]
grille$Xj <- Xj[as.character(grille$j)]

# ---- TIBI ----
grille$s_ij <- grille$Xij / grille$Xi
grille$Xrj  <- grille$Xj - grille$Xij
grille$Xr   <- X_tot - grille$Xi
grille$s_rj <- grille$Xrj / grille$Xr
grille$I1 <- grille$s_ij / grille$s_rj
grille$I3 <- (1 - grille$s_ij) / (1 - grille$s_rj)
ratio <- grille$I1 / grille$I3
grille$TIBI <- (ratio - 1) / (ratio + 1)

tibi <- grille[, c("i", "j", "Xij", "TIBI")]

# ---- identifier les singletons (communautes a un seul pays) , normalement il n'y en a pas----
src <- unique(d[, c("sourceLabel", "sourceCommunity")]); names(src) <- c("pays", "bloc")
tgt <- unique(d[, c("targetLabel", "targetCommunity")]); names(tgt) <- c("pays", "bloc")
pays_bloc <- unique(rbind(src, tgt))
taille <- table(pays_bloc$bloc)
blocs_singletons <- as.integer(names(taille)[taille == 1])

# ---- diagonale sans singletons + poids ----
tibi_ss <- tibi[!(tibi$i %in% blocs_singletons) & !(tibi$j %in% blocs_singletons), ]
diag_df <- tibi_ss[tibi_ss$i == tibi_ss$j & !is.nan(tibi_ss$TIBI) & is.finite(tibi_ss$TIBI),
                   c("i", "TIBI")]
diag_df$poids <- Xi[as.character(diag_df$i)] / X_tot
diag_df$w <- diag_df$poids #/ sum(diag_df$poids)

