# ============================================================================
# EXEMPLE PEDAGOGIQUE : Intramax puis TIBI, sur un petit echantillon de 1938
#
# Objet : derouler les deux calculs etape par etape, en affichant chaque
#         matrice intermediaire, pour pouvoir les expliquer.
#
# Echantillon : neuf entites, declarations FOB uniquement. Toutes les
#         valeurs ci-dessous decrivent donc le commerce A L INTERIEUR du
#         sous-echantillon, pas le commerce mondial. Chaque entite y perd
#         la quasi-totalite de ses partenaires reels.
#
# PARTIE A - INTRAMAX
#   A1  une valeur par paire : moyenne des declarations disponibles
#   A2  matrice symetrique, normalisee (la somme des cases vaut 1)
#   A3  la boucle : a chaque etape on calcule l attendu E = ligne x colonne
#       / total, l ecart Dd = M/E - 1, on fusionne la paire au plus fort
#       ecart et on neutralise la diagonale. Le "flux interne" mesure ce que
#       cette fusion seule internalise, pas le cumul.
#   A4  on retient la partition obtenue juste avant la premiere fusion qui
#       internalise plus de 10 % du commerce.
#
# PARTIE B - TIBI, sur la partition issue de A
#   B1  les flux, avec le bloc de l exportateur et celui de l importateur
#   B2  matrice bloc-bloc : ligne = exportateur, colonne = importateur
#   B3  marges : Xi = exports du bloc i, Xj = imports du bloc j
#   B3b indice de Balassa : observe rapporte a l attendu Xi x Xj / X
#   B4  s1 = part des exports de i allant vers j ; s2 = meme part pour le
#       reste du monde ; I1 = s1/s2 corrige la variabilite de l intervalle ;
#       la transformation (I1/I3 - 1)/(I1/I3 + 1) borne l indice dans [-1,1]
#   B5  trois cas limites : base nulle -> NA, concentration totale -> 1,
#       aucun commerce -> -1
#   B6  diagonale : intensite interne de chaque bloc, et son poids
#   B7  moyenne ponderee par la part de chaque bloc dans les exports
# ============================================================================


rm(list = ls(all = TRUE))
library(dplyr); library(tidyr)
setwd("~/Desktop/ricardo_gph_analysis")

year <- 1938
options(digits = 4)

g <- read.csv(file.path("results/gravity", paste0("gravity_", year, ".csv")),
              stringsAsFactors = FALSE)
g <- g[g$status == "ok" & !is.na(g$value) & g$CafFob == "fob", ]
g$exporterId <- as.character(g$exporterId)
g$importerId <- as.character(g$importerId)

# ============================================================
# 0. Choix de l echantillon
# ============================================================

# --- les gros declarants ---
gros <- bind_rows(
  g %>% filter(CafFob == "fob") %>% transmute(gph = exporterId, lab = exporterLabel, v = value),
  g %>% filter(CafFob == "caf") %>% transmute(gph = importerId, lab = importerLabel, v = value)
) %>% group_by(gph, lab) %>% summarise(t = sum(v), .groups = "drop") %>%
  arrange(desc(t))
cat("\n=== Les 10 plus gros ===\n"); print(as.data.frame(head(gros, 10)))

# --- les entites dont tous les flux sont nuls ---
nuls <- bind_rows(
  g %>% transmute(gph = exporterId, lab = exporterLabel, v = value),
  g %>% transmute(gph = importerId, lab = importerLabel, v = value)
) %>% group_by(gph, lab) %>%
  summarise(n = n(), n_pos = sum(v > 0), .groups = "drop") %>%
  filter(n_pos == 0, n >= 3) %>% arrange(desc(n))
cat("\n=== Entites a flux tous nuls ===\n"); print(as.data.frame(head(nuls, 10)))

# --- les entites a un seul partenaire (flux positifs) ---
gp <- g[g$value > 0, ]
solo <- bind_rows(
  gp %>% transmute(gph = exporterId, lab = exporterLabel, part = importerId),
  gp %>% transmute(gph = importerId, lab = importerLabel, part = exporterId)
) %>% group_by(gph, lab) %>%
  summarise(n_part = n_distinct(part), .groups = "drop") %>%
  filter(n_part == 1)
cat("\n=== Entites a un seul partenaire ===\n"); print(as.data.frame(head(solo, 10)))

#Je choisis l'échantillon
# ech <- c("2", "20", "70",        # Etats-Unis, Canada, Mexique
#          "200", "900", "750",    # Royaume-Uni, Australie, Inde
#          "220", "211", "210")    # France, Belgique, Pays-Bas
ech <- c("2", "20",            # Etats-Unis, Canada
         "200", "750",   # Royaume-Uni, Inde
         "220", "211", "210")  # France, Belgique, Pays-Bas

G <- g %>% filter(exporterId %in% ech, importerId %in% ech) %>%
  select(exporterId, exporterLabel, importerId, importerLabel, value)
as.data.frame(G)


noms <- bind_rows(
  G %>% transmute(gph = exporterId, lab = exporterLabel),
  G %>% transmute(gph = importerId, lab = importerLabel)
) %>% distinct(gph, .keep_all = TRUE)
lab <- setNames(noms$lab, noms$gph)


# ============================================================
# PARTIE A : INTRAMAX
# ============================================================
cat("\n\n##################### INTRAMAX #####################\n")

# --- A1. une valeur par paire non orientee ---
G$a <- pmin(G$exporterId, G$importerId)
G$b <- pmax(G$exporterId, G$importerId)

moy <- G %>% group_by(a, b) %>%
  summarise(value = mean(value), n_flux = n(), .groups = "drop")

cat("\n=== A1. Moyenne des declarations, par paire ===\n")
print(as.data.frame(moy))

# --- A2. matrice symetrique, normalisee ---
pays <- sort(unique(c(moy$a, moy$b)))
M <- matrix(NA_real_, length(pays), length(pays), dimnames = list(pays, pays))
M[cbind(match(moy$a, pays), match(moy$b, pays))] <- moy$value
M[cbind(match(moy$b, pays), match(moy$a, pays))] <- moy$value

garde <- rowSums(!is.na(M)) > 0 | colSums(!is.na(M)) > 0
M <- M[garde, garde]
M <- M / sum(M, na.rm = TRUE)

cat("\n=== A2. Matrice M, symetrique, normalisee (somme = 1) ===\n")
print(round(M, 5))

# --- A3. la boucle, pas a pas ---
historique <- data.frame(etape = integer(), fusion = character(),
                         flux_interne = numeric(), stringsAsFactors = FALSE)
etats <- list(); etape <- 0

while (nrow(M) > 1) {
  etape <- etape + 1
  etats[[etape]] <- rownames(M)
  
  tl <- rowSums(M, na.rm = TRUE)
  tc <- colSums(M, na.rm = TRUE)
  tot <- sum(M, na.rm = TRUE)
  E <- outer(tl, tc) / tot
  
  Dd <- M / E - 1
  Dd[!is.finite(Dd) & !is.na(M)] <- 0
  D <- pmax(Dd, t(Dd), na.rm = TRUE)
  D[lower.tri(D, diag = TRUE)] <- NA
  if (all(is.na(D))) { cat("\nPlus aucune paire comparable : arret\n"); break }
  
  cat("\n--------- Etape", etape, ":", paste(rownames(M), collapse = " | "), "---------\n")
  cat("\nMarges tl (total par ligne) :\n");        print(round(tl, 5))
  cat("\nAttendu E = tl x tc / total :\n");        print(round(E, 5))
  cat("\nEcart Dd = M / E - 1 :\n");               print(round(Dd, 3))
  cat("\nD = max(Dd, transposee), triangle sup :\n"); print(round(D, 3))
  
  gs <- which(D == max(D, na.rm = TRUE), arr.ind = TRUE)[1, ]
  i <- gs[1]; j <- gs[2]
  fi <- sum(M[i, j], M[j, i], na.rm = TRUE)
  
  cat("\n>>> Fusion :", rownames(M)[i], "+", rownames(M)[j],
      "  (ecart max =", round(D[i, j], 3), ")\n")
  cat(">>> Flux devenu interne :", round(fi, 5),
      "soit", round(100 * fi, 1), "% du total\n")
  
  historique <- rbind(historique, data.frame(
    etape = etape,
    fusion = paste(rownames(M)[i], rownames(M)[j], sep = "+"),
    flux_interne = fi, stringsAsFactors = FALSE))
  
  M[i, ] <- colSums(M[c(i, j), ], na.rm = TRUE)
  M[, i] <- rowSums(M[, c(i, j)], na.rm = TRUE)
  M[i, i] <- NA
  M <- M[-j, -j, drop = FALSE]
  rownames(M)[i] <- colnames(M)[i] <-
    paste(etats[[etape]][i], etats[[etape]][j], sep = "+")
}

cat("\n=== A3. Historique des fusions ===\n")
print(historique)

# --- A4. partition retenue ---
#Avec threshold, on retient la partition obtenue juste avant la premiere fusion qui
#       internalise plus de 10 % du commerce.
seuil <- 0.10
etape_choisie <- which(historique$flux_interne >= seuil)[1]
if (is.na(etape_choisie)) etape_choisie <- nrow(historique)

cat("\n=== Seuil de", seuil, "franchi a l etape", etape_choisie,
    "(flux interne =", round(historique$flux_interne[etape_choisie], 4), ") ===\n")

cat("\n=== A4. Partition a l etape", etape_choisie, "===\n")
groupes <- strsplit(etats[[etape_choisie]], "+", fixed = TRUE)
blocs_im <- data.frame(id = unlist(groupes),
                       bloc = rep(seq_along(groupes), lengths(groupes)),
                       stringsAsFactors = FALSE)
blocs_im$pays <- lab[blocs_im$id]
print(blocs_im)


# ============================================================
# PARTIE B : TIBI
# ============================================================
cat("\n\n##################### TIBI #####################\n")
cat("univers : fob (declare par l exportateur)\n")
cat("normalisation : exports du bloc i\n")

bloc <- setNames(as.character(blocs_im$bloc), blocs_im$id)

gg <- G
gg$i <- bloc[gg$exporterId]
gg$j <- bloc[gg$importerId]
gg <- gg[!is.na(gg$i) & !is.na(gg$j), ]

cat("\n=== B1. Flux avec le bloc de chaque cote ===\n")
print(as.data.frame(gg[, c("exporterLabel", "importerLabel", "value", "i", "j")]))

Xij <- aggregate(value ~ i + j, data = gg, FUN = sum)
names(Xij)[3] <- "Xij"
blocs <- sort(unique(c(gg$i, gg$j)))
grille <- merge(expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE),
                Xij, by = c("i", "j"), all.x = TRUE)
grille$Xij[is.na(grille$Xij)] <- 0

cat("\n=== B2. Matrice bloc-bloc (ligne = exportateur, colonne = importateur) ===\n")
print(xtabs(Xij ~ i + j, data = grille))

X_tot <- sum(grille$Xij)
Xi <- tapply(grille$Xij, grille$i, sum)
Xj <- tapply(grille$Xij, grille$j, sum)
grille$Xi <- Xi[as.character(grille$i)]
grille$Xj <- Xj[as.character(grille$j)]

cat("\n=== B3. Marges ===\n")
cat("Xi, exports de chaque bloc :\n"); print(Xi)
cat("Xj, imports de chaque bloc :\n"); print(Xj)
cat("X_tot =", X_tot, "\n")

# --- B3b. Indice de Balassa : observe sur attendu ---
grille$Xprime <- grille$Xi * grille$Xj / X_tot
grille$I0     <- grille$Xij / grille$Xprime

cat("\n=== B3b. Attendu X'_ij = Xi x Xj / X ===\n")
print(xtabs(round(Xprime) ~ i + j, data = grille))

cat("\n=== B3b. Indice Xij / X'_ij ===\n")
print(xtabs(round(I0, 3) ~ i + j, data = grille))

#Retour
grille$base  <- grille$Xi
grille$s1    <- grille$Xij / grille$Xi
grille$s2    <- (grille$Xj - grille$Xij) / (X_tot - grille$Xi)
grille$I1    <- grille$s1 / grille$s2
grille$I3    <- (1 - grille$s1) / (1 - grille$s2)
grille$ratio <- grille$I1 / grille$I3
grille$TIBI  <- (grille$ratio - 1) / (grille$ratio + 1)

cat("\n=== B4. Detail avant traitement des cas limites ===\n")
print(grille %>% select(i, j, Xij, Xprime, I0, base, s1, s2, I1, I3, ratio, TIBI) %>%
        mutate(across(where(is.numeric), ~ round(.x, 3))))


grille$TIBI[grille$base == 0] <- NA_real_
grille$TIBI[grille$base > 0 & grille$Xij == grille$base] <- 1
grille$TIBI[grille$base > 0 & grille$Xij == 0] <- -1

cat("\n=== B5. Apres traitement des cas limites ===\n")
print(grille %>% select(i, j, Xij, base, s1, s2, TIBI) %>%
        mutate(across(where(is.numeric), ~ round(.x, 3))))

diag_df <- grille[grille$i == grille$j & is.finite(grille$TIBI), c("i", "TIBI", "base")]
diag_df$w <- diag_df$base / X_tot

cat("\n=== B6. Diagonale : TIBI intra-bloc et poids ===\n")
print(diag_df %>% mutate(across(where(is.numeric), ~ round(.x, 4))))

cat("\n=== B7. TIBI intra-bloc moyen pondere =",
    round(sum(diag_df$w * diag_df$TIBI), 4), "===\n")