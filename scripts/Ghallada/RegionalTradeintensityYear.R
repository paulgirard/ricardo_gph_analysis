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
  scale_x_continuous(breaks = seq(1835, 1935, 5)) +
  scale_color_manual(values = c("Intramax" = "#0055A4", "Louvain" = "#CF142B")) +
  labs(x = "année", y = "TIBI intra-bloc moyen (pondéré)",
       title = "Commerce intra-bloc moyen : Intramax vs Louvain",
       color = "Méthode") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))
print(p_combine)
ggsave("data/blocks/tibi_comparaison_intramax_louvain.png",
       plot = p_combine, width = 10, height = 5, dpi = 150)


###Regional blocs (as echoed by Anderson and Norheim)
BlocselonAN <- as.data.frame(read_excel("data/BlocselonAN.xlsx"))
region_map <- BlocselonAN[, c("GPH_code", "region_AndersonNorheim")]
region_map$GPH_code <- as.character(region_map$GPH_code)

resultats_AN <- data.frame(year = integer(), moyenne = numeric(), n_blocs = integer())

for (year in annees) {
  f <- paste0("data/blocks/Intramax/paires_blocs_", year, ".csv")
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  d <- d[!is.na(d$value), ]
  if (nrow(d) == 0) next

  # ---- merger la region AN par code GPH (exportateur + importateur) ----
  d$exporterId <- as.character(d$exporterId)
  d$importerId <- as.character(d$importerId)
  d <- merge(d, region_map, by.x = "exporterId", by.y = "GPH_code", all.x = TRUE)
  names(d)[names(d) == "region_AndersonNorheim"] <- "region_exp"
  d <- merge(d, region_map, by.x = "importerId", by.y = "GPH_code", all.x = TRUE)
  names(d)[names(d) == "region_AndersonNorheim"] <- "region_imp"
  
  d <- d[!is.na(d$region_exp) & !is.na(d$region_imp) &
           d$region_exp != "" & d$region_imp != "", ]
  if (nrow(d) == 0) next
  
  Xij <- aggregate(value ~ region_exp + region_imp, data = d, FUN = sum)
  names(Xij) <- c("i", "j", "Xij")
  blocs <- sort(unique(c(d$region_exp, d$region_imp)))
  
  grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
  grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
  grille$Xij[is.na(grille$Xij)] <- 0

  X_tot <- sum(grille$Xij)
  Xi <- tapply(grille$Xij, grille$i, sum)
  Xj <- tapply(grille$Xij, grille$j, sum)
  grille$Xi <- Xi[as.character(grille$i)]
  grille$Xj <- Xj[as.character(grille$j)]

  
  grille$s_ij <- grille$Xij / grille$Xi
  grille$Xrj  <- grille$Xj - grille$Xij
  grille$Xr   <- X_tot - grille$Xi
  grille$s_rj <- grille$Xrj / grille$Xr
  grille$I1 <- grille$s_ij / grille$s_rj
  grille$I3 <- (1 - grille$s_ij) / (1 - grille$s_rj)
  ratio <- grille$I1 / grille$I3
  grille$TIBI <- (ratio - 1) / (ratio + 1)
  
  tibi <- grille[, c("i", "j", "Xij", "TIBI")]
  
  
  exp <- unique(d[, c("exporterId", "region_exp")]); names(exp) <- c("gph", "bloc")
  imp <- unique(d[, c("importerId", "region_imp")]); names(imp) <- c("gph", "bloc")
  pays_bloc <- unique(rbind(exp, imp))
  taille <- table(pays_bloc$bloc)
  blocs_singletons <- names(taille)[taille == 1]
  
  
  tibi_ss <- tibi[!(tibi$i %in% blocs_singletons) & !(tibi$j %in% blocs_singletons), ]
  diag_df <- tibi_ss[tibi_ss$i == tibi_ss$j & !is.nan(tibi_ss$TIBI) & is.finite(tibi_ss$TIBI),
                     c("i", "TIBI")]
  if (nrow(diag_df) < 1) next
  

  diag_df$poids <- Xi[as.character(diag_df$i)] / X_tot
  diag_df$w <- diag_df$poids   #/ sum(diag_df$poids)
  m <- sum(diag_df$w * diag_df$TIBI)
  
  resultats_AN <- rbind(resultats_AN, data.frame(
    year = year, moyenne = m, n_blocs = nrow(diag_df)))
}


##############################################################
#####  4. SUPERPOSITION DES TROIS COURBES  ###################
##############################################################
resultats_intra$methode   <- "Intramax"
resultats_louvain$methode <- "Louvain"
resultats_AN$methode      <- "Anderson-Norheim"

combine <- rbind(resultats_intra[, c("year", "moyenne", "methode")],
                 resultats_louvain[, c("year", "moyenne", "methode")],
                 resultats_AN[, c("year", "moyenne", "methode")])

p_combine <- ggplot(combine, aes(year, moyenne, color = methode)) +
  geom_line() + geom_point(size = 1) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  coord_cartesian(ylim = c(-1, 1)) +
  scale_x_continuous(breaks = seq(1835, 1935, 5)) +
  scale_color_manual(values = c("Intramax" = "#0055A4",
                                "Louvain" = "#CF142B",
                                "Anderson-Norheim" = "#2E8B57")) +
  labs(x = "année", y = "TIBI intra-bloc moyen (pondéré)",
       title = "Commerce intra-bloc moyen : Intramax vs Louvain vs Anderson-Norheim",
       color = "Méthode") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))

print(p_combine)

ggsave("data/blocks/tibi_comparaison_trois_methodes.png",
       plot = p_combine, width = 10, height = 5, dpi = 150)


##############################################################
#####  5. SUPERPOSITION + NB DE BLOCS EMPILES  ###############
##############################################################

# --- 1. Combiner les 3 objets en un long format avec n_blocs ---
n_blocs_all <- bind_rows(
  resultats_AN       %>% select(year, n_blocs) %>% mutate(methode = "Anderson-Norheim"),
  resultats_intra    %>% select(year, n_blocs) %>% mutate(methode = "Intramax"),
  resultats_louvain  %>% select(year, n_blocs) %>% mutate(methode = "Louvain")
)

# --- 2. Coefficient de rescaling (somme des 3 méthodes par année) ---
# Les barres occupent tout l'espace [-1, 1] : total_max -> 1, 0 -> -1
coef <- n_blocs_all %>%
  group_by(year) %>%
  summarise(total = sum(n_blocs, na.rm = TRUE)) %>%
  pull(total) %>%
  max()

# --- 3. Couleurs communes (identiques à celles des courbes) ---
couleurs_methodes <- c("Intramax"         = "#0055A4",
                       "Louvain"          = "#CF142B",
                       "Anderson-Norheim" = "#2E8B57")

# --- 4. Graphe combiné : courbes TIBI + barres empilées n_blocs ---
p_combine <- ggplot() +
  # 1. Courbes TIBI d'abord (au fond)
  geom_line(data = combine,  aes(year, moyenne, color = methode), linewidth = 0.6) +
  geom_point(data = combine, aes(year, moyenne, color = methode), size = 1) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  
  # 2. Barres n_blocs par-dessus, mais avec bordure pour bien les délimiter
  geom_col(data = n_blocs_all,
           aes(x = year, y = (n_blocs / coef) * 2 - 1, fill = methode),
           position = "stack", alpha = 0.35, width = 1,
           colour = NA) +   # <-- pas de contour blanc entre barres
  
  coord_cartesian(ylim = c(-1, 1)) +
  scale_x_continuous(breaks = seq(1835, 1935, 5)) +
  scale_y_continuous(
    name     = "TIBI intra-bloc moyen (pondéré)",
    breaks   = seq(-1, 1, 0.5),
    sec.axis = sec_axis(~ ((. + 1) / 2) * coef, name = "Nombre de blocs (empilé)")
  ) +
  scale_color_manual(values = couleurs_methodes) +
  scale_fill_manual(values  = couleurs_methodes) +
  labs(x = "année",
       title = "Commerce intra-bloc moyen + nombre de blocs par année",
       color = "Méthode (courbe TIBI)",
       fill  = "Méthode (barres n_blocs)") +
  theme_minimal() +
  theme(legend.position = "bottom",
        axis.text.x = element_text(angle = 45, hjust = 1))

print(p_combine)
ggsave("data/blocks/tibi_comparaison_avec_nblocs.png",
       plot = p_combine, width = 11, height = 6, dpi = 150)
