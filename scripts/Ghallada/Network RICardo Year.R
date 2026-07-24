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
#setwd("set the right path")
#set_here() so that here function understand you are there (need to restart perhaps after)

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
  
  #garde <- rowSums(M, na.rm = TRUE) > 0 | colSums(M, na.rm = TRUE) > 0 #enlève les vrais flux nuls
  garde <- rowSums(!is.na(M)) > 0 | colSums(!is.na(M)) > 0 #garde les vrais flux nuls
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
  paires$year <- year                                    
  
  # merge avec toutes les variables gravitaires
  paires <- merge(paires, Net,
                  by.x = c("exportateur", "importateur"),
                  by.y = c("exporterLabel", "importerLabel"), all.x = TRUE)
  
  # ---- export ----
  out <- file.path(here("data", "blocks", "Intramax"), paste0("paires_blocs_", year, ".csv"))
  write.csv(paires, out, row.names = FALSE)
  message("  OK ", year, " : ", nrow(paires), " paires -> ", basename(out))
  return(paires)
}

# ================= BOUCLE =================
dossier <- here("data")

for (year in 1833:1938) {
  message("Annee ", year)
  res <- tryCatch(traiter_annee(year, dossier),
                  error = function(e) { message("  ERREUR ", year, " : ", conditionMessage(e)); NULL })
}

# ================= Recupérere les corrélations =================
dossier <- here("data", "blocks", "Intramax")
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
  ct <- cor.test(d$meme_bloc, log1p(d$value))
  
  n_valide <- sum(!is.na(d$meme_bloc) & !is.na(d$value))   # <-- ICI, juste avant le rbind
  
  cor_par_annee <- rbind(cor_par_annee, data.frame(
    year = year, cor = ct$estimate,
    ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2], n = n_valide))
}




# ---- graphe : annee en x, correlation en y ----
p <-ggplot(cor_par_annee, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  labs(x = "année", y = "corrélation même_bloc / log(value)",
       title = "Corrélation même_bloc ↔ commerce (IC 95%)") +
  theme_minimal()

# ---- SAUVEGARDES ----
# le graphe en PNG
ggsave(here("data", "blocks", "Intramax", "correlation_meme_bloc.png"),
       plot = p, width = 9, height = 5, dpi = 150)

# le fichier des correlations en CSV
write.csv(cor_par_annee,
          here("data", "blocks", "Intramax", "cor_par_annee.csv"),
          row.names = FALSE)

# ================= Avec Louvain=================


dossier <- here("data", "blocks", "louvain")  
annees  <- 1833:1938

cor_comm <- data.frame(year = integer(), cor = numeric(),
                       ic_bas = numeric(), ic_haut = numeric())

for (year in annees) {
  f <- file.path(dossier, paste0(year, "_fob.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) { 
    message("Annee ", year, " : fichier absent ou vide -> sautee")
    next 
  }
  
  d <- tryCatch(read.csv(f, stringsAsFactors = FALSE),
                error = function(e) NULL)
  if (is.null(d) || nrow(d) == 0) {
    message("Annee ", year, " : lecture impossible -> sautee")
    next
  }
  
  d$same_community <- as.integer(d$sourceCommunity == d$targetCommunity)
  
  ct <- tryCatch(cor.test(d$same_community, log1p(d$maxObservedTradeValue)),
                 error = function(e) NULL)
  if (is.null(ct)) { message("Annee ", year, " : cor.test impossible -> sautee"); next }
  
  cor_comm <- rbind(cor_comm, data.frame(
    year = year, cor = ct$estimate,
    ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2]))
}

# graphe : annee en x, correlation en y, avec IC
p_louvain <- ggplot(cor_comm, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  labs(x = "année", y = "corrélation same_community / log(maxObservedTradeValue)",
       title = "Corrélation même communauté ↔ commerce (IC 95%)") +
  theme_minimal()

ggsave(here("data", "blocks", "louvain", "correlation_louvain.png"),
       plot = p_louvain, width = 9, height = 5, dpi = 150)
write.csv(cor_comm, here("data", "blocks", "louvain", "cor_comm.csv"), row.names = FALSE)



#Correlation Louvain mais avec les flux i==>j et j==>i

dossier <- here("data", "blocks", "louvain")
annees  <- 1833:1938
cor_comm <- data.frame(year = integer(), cor = numeric(),
                       ic_bas = numeric(), ic_haut = numeric())
for (year in annees) {
  f <- file.path(dossier, paste0(year, "_fob_enrichi.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) {
    message("Annee ", year, " : fichier absent ou vide -> sautee")
    next
  }
  
  d <- tryCatch(read.csv(f, stringsAsFactors = FALSE),
                error = function(e) NULL)
  if (is.null(d) || nrow(d) == 0) {
    message("Annee ", year, " : lecture impossible -> sautee")
    next
  }
  
  d$same_community <- as.integer(d$sourceCommunity == d$targetCommunity)
  
  # ---- empiler les deux sens comme observations distinctes (comme intramax) ----
  # sens i->j : flux = export
  obs_ij <- data.frame(same_community = d$same_community, value = d$export)
  # sens j->i : flux = import (meme same_community, car symetrique)
  obs_ji <- data.frame(same_community = d$same_community, value = d$import)
  
  obs <- rbind(obs_ij, obs_ji)
  obs <- obs[!is.na(obs$value), ]          # on garde les flux observes (comme intramax ignore les NA, ici pas de flux non obs anyway)
  
  ct <- tryCatch(cor.test(obs$same_community, log1p(obs$value)),
                 error = function(e) NULL)
  if (is.null(ct)) { message("Annee ", year, " : cor.test impossible -> sautee"); next }
  
  cor_comm <- rbind(cor_comm, data.frame(
    year = year, cor = ct$estimate,
    ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2]))
}

# graphe
p_louvain <- ggplot(cor_comm, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  labs(x = "année", y = "corrélation same_community / log(flux oriente)",
       title = "Corrélation même communauté ↔ commerce (flux orientés, IC 95%)") +
  theme_minimal()

print(p_louvain)

ggsave(here("data", "blocks", "louvain", "correlation_louvain_oriente.png"),
       plot = p_louvain, width = 9, height = 5, dpi = 150)
write.csv(cor_comm, here("data", "blocks", "louvain", "cor_comm_oriente.csv"), row.names = FALSE)



#Corrélation entre Louvain et Intramax same blocs


dossier_intra   <- here("data", "blocks", "Intramax")
dossier_louvain <- here("data", "blocks", "louvain")
annees <- 1833:1938

cor_methodes <- data.frame(year = integer(), cor = numeric(),
                           ic_bas = numeric(), ic_haut = numeric(), n = integer())

for (year in annees) {
  f_intra   <- file.path(dossier_intra,   paste0("paires_blocs_", year, ".csv"))
  f_louvain <- file.path(dossier_louvain, paste0(year, "_fob.csv"))
  if (!file.exists(f_intra) || !file.exists(f_louvain)) next
  if (file.info(f_intra)$size == 0 || file.info(f_louvain)$size == 0) next
  
  # --- intramax : couple NON-ORIENTE + meme_bloc, deduplique ---
  di <- read.csv(f_intra, stringsAsFactors = FALSE)
  di$couple <- apply(di[, c("exporterId", "importerId")], 1,
                     function(x) paste(sort(as.character(x)), collapse = "_"))
  di <- unique(di[, c("couple", "meme_bloc")])
  
  # --- louvain : couple NON-ORIENTE + same_community, dedupliqué ---
  dl <- read.csv(f_louvain, stringsAsFactors = FALSE)
  dl$same_community <- as.integer(dl$sourceCommunity == dl$targetCommunity)
  dl$couple <- apply(dl[, c("source", "target")], 1,
                     function(x) paste(sort(as.character(x)), collapse = "_"))
  dl <- unique(dl[, c("couple", "same_community")])
  
  # --- jointure sur les couples communs ---
  m <- merge(di, dl, by = "couple")
  if (nrow(m) < 4) next
  
  ct <- tryCatch(cor.test(m$meme_bloc, m$same_community), error = function(e) NULL)
  if (is.null(ct)) next
  
  cor_methodes <- rbind(cor_methodes, data.frame(
    year = year, cor = ct$estimate,
    ic_bas = ct$conf.int[1], ic_haut = ct$conf.int[2], n = nrow(m)))
  
  cat(year, ": communs =", nrow(m), "\n")   # controle du nb de paires appariees
}

# --- graph ---
p <- ggplot(cor_methodes, aes(year, cor)) +
  geom_ribbon(aes(ymin = ic_bas, ymax = ic_haut), fill = "grey80", alpha = 0.5) +
  geom_line() + geom_point() +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  labs(x = "année",
       y = "corrélation même_bloc (intramax) ↔ même_communauté (Louvain)",
       title = "Similarité entre intramax et Louvain par année (IC 95%)") +
  theme_minimal()

print(p)

# --- sauvegardes ---
ggsave(here("data", "blocks", "corr_intramax_louvain.png"),
       plot = p, width = 9, height = 5, dpi = 150)
write.csv(cor_methodes, here("data", "blocks", "cor_intramax_louvain.csv"),
          row.names = FALSE)

# ================= Corrélation + Nombre de blocs par méthode (empilé) =================

# --- 1. Combiner les 3 objets en un long format ---
n_blocs_all <- bind_rows(
  resultats_AN      %>% select(year, n_blocs) %>% mutate(methode = "Anderson-Norheim"),
  resultats_Intra   %>% select(year, n_blocs) %>% mutate(methode = "Intramax"),
  resultats_Louvain %>% select(year, n_blocs) %>% mutate(methode = "Louvain")
)

# --- 2. Coefficient de rescaling (somme des 3 méthodes par année) ---
coef <- n_blocs_all %>%
  group_by(year) %>%
  summarise(total = sum(n_blocs, na.rm = TRUE)) %>%
  pull(total) %>%
  max()

# --- 3. Couleurs communes aux 3 méthodes ---
couleurs_methodes <- c("Anderson-Norheim" = "#E41A1C",  # rouge
                       "Intramax"         = "#377EB8",  # bleu
                       "Louvain"          = "#4DAF4A")  # vert

# --- 4. Graphe combiné ---
p_combined <- ggplot() +
  # Barres n_blocs empilées (une barre par année, 3 segments)
  geom_col(data = n_blocs_all,
           aes(x = year, y = n_blocs / coef, fill = methode),
           position = "stack", alpha = 0.7, width = 0.9) +
  # Corrélation Intramax vs Louvain (existant)
  geom_ribbon(data = cor_methodes,
              aes(x = year, ymin = ic_bas, ymax = ic_haut),
              fill = "grey70", alpha = 0.4) +
  geom_line(data = cor_methodes,  aes(x = year, y = cor), linewidth = 0.7) +
  geom_point(data = cor_methodes, aes(x = year, y = cor), size = 1.3) +
  geom_hline(yintercept = 0, linetype = 3, colour = "grey60") +
  # Axe Y gauche = corrélation, axe Y droit = nb blocs
  scale_y_continuous(
    name     = "corrélation même_bloc (Intramax) ↔ même_communauté (Louvain)",
    sec.axis = sec_axis(~ . * coef, name = "Nombre de blocs (empilé)")
  ) +
  scale_fill_manual(values = couleurs_methodes) +
  labs(x = "année",
       title = "Corrélation entre méthodes + Nombre de blocs par méthode et année",
       fill  = "Méthode") +
  theme_minimal() +
  theme(legend.position = "bottom")

print(p_combined)

# --- 5. Sauvegarde ---
ggsave(here("data", "blocks", "corr_intramax_louvain_avec_nblocs.png"),
       plot = p_combined, width = 11, height = 6, dpi = 150)


