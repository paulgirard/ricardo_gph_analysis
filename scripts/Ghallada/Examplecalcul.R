rm(list = ls(all = TRUE))
library(dplyr); library(tidyr)
library(here)
here::i_am("scripts/Ghallada/Examplecalcul.R")   # adapter au chemin reel du script

year <- 1938
options(digits = 4)

# ============================================================================
# MESURES DE PROXIMITE ENTRE PAIRES DE PAYS, 1938
#
# Toutes les mesures sont calculees au niveau pays-pays, avant tout
# regroupement. Les totaux ne portent que sur le sous-echantillon.
#
#   Intramax travaille sur une matrice SYMETRIQUE : une valeur par paire,
#   moyenne des declarations, puis ecart a l attendu.
#   TIBI travaille sur une matrice ORIENTEE : exportateur en ligne,
#   importateur en colonne, et un indice par sens.
# ============================================================================

g <- read.csv(here("results", "gravity", paste0("gravity_", year, ".csv")),
              stringsAsFactors = FALSE)
g <- g[g$status == "ok" & !is.na(g$value) & g$CafFob == "fob", ]
g$exporterId <- as.character(g$exporterId)
g$importerId <- as.character(g$importerId)

ech <- c("2", "20",            # Etats-Unis, Canada
         "200", "750",         # Royaume-Uni, Inde
         "220", "211", "210")  # France, Belgique, Pays-Bas

G <- g %>% filter(exporterId %in% ech, importerId %in% ech) %>%
  select(exporterId, exporterLabel, importerId, importerLabel, value)

cat("\n=== 0. Les flux FOB de l echantillon ===\n")
print(as.data.frame(G))

noms <- bind_rows(
  G %>% transmute(gph = exporterId, lab = exporterLabel),
  G %>% transmute(gph = importerId, lab = importerLabel)
) %>% distinct(gph, .keep_all = TRUE)
lab <- setNames(noms$lab, noms$gph)


# ============================================================================
# PARTIE A : la proximite utilisee par Intramax, paire par paire
# ============================================================================
cat("\n\n########## A. PROXIMITE INTRAMAX (matrice symetrique) ##########\n")

G$a <- pmin(G$exporterId, G$importerId)
G$b <- pmax(G$exporterId, G$importerId)

moy <- G %>% group_by(a, b) %>%
  summarise(value = mean(value), n_flux = n(), .groups = "drop")

pays <- sort(unique(c(moy$a, moy$b)))
M <- matrix(NA_real_, length(pays), length(pays), dimnames = list(pays, pays))
M[cbind(match(moy$a, pays), match(moy$b, pays))] <- moy$value
M[cbind(match(moy$b, pays), match(moy$a, pays))] <- moy$value
M <- M / sum(M, na.rm = TRUE)

tl  <- rowSums(M, na.rm = TRUE)
tot <- sum(M, na.rm = TRUE)
E   <- outer(tl, tl) / tot
Dd  <- M / E - 1

prox_im <- moy %>%
  mutate(pays_a = lab[a], pays_b = lab[b],
         M      = M[cbind(match(a, pays), match(b, pays))],
         E      = E[cbind(match(a, pays), match(b, pays))],
         Dd     = M / E - 1) %>%     # symetrique : pmax ne change rien
  select(a, pays_a, b, pays_b, n_flux, value, M, E, Dd) %>%
  arrange(desc(Dd))

cat("\n=== A1. Une ligne par paire non orientee ===\n")
cat("  value : moyenne des declarations\n")
cat("  M     : la meme, normalisee (somme de la matrice = 1)\n")
cat("  E     : attendu = marge(a) x marge(b) / total\n")
cat("  Dd    : ecart relatif M/E - 1, le critere de fusion d Intramax\n\n")
print(as.data.frame(prox_im %>% mutate(across(c(M, E, Dd), ~ round(.x, 4)))))


# ============================================================================
# PARTIE B : les mesures du TIBI, paire orientee par paire orientee
# ============================================================================
cat("\n\n########## B. MESURES TIBI (matrice orientee) ##########\n")

Xij <- aggregate(value ~ exporterId + importerId, data = G, FUN = sum)
names(Xij)[3] <- "Xij"

grille <- merge(expand.grid(exporterId = pays, importerId = pays,
                            stringsAsFactors = FALSE),
                Xij, by = c("exporterId", "importerId"), all.x = TRUE)
grille$Xij[is.na(grille$Xij)] <- 0

X_tot <- sum(grille$Xij)
Xi <- tapply(grille$Xij, grille$exporterId, sum)   # exports du pays i
Xj <- tapply(grille$Xij, grille$importerId, sum)   # imports du pays j
grille$Xi <- Xi[grille$exporterId]
grille$Xj <- Xj[grille$importerId]

cat("\n=== B0. Marges ===\n")
cat("Xi, exports :\n");  print(Xi)
cat("Xj, imports :\n");  print(Xj)
cat("X_tot =", format(X_tot, big.mark = " "), "\n")

prox_tibi <- grille %>%
  mutate(
    # --- Balassa / Poon : observe rapporte a l attendu ---
    Xprime = Xi * Xj / X_tot,
    I0     = Xij / Xprime,
    
    # --- I1 : part de i vers j, rapportee a la meme part du reste du monde ---
    s1 = Xij / Xi,
    s2 = (Xj - Xij) / (X_tot - Xi),
    I1 = s1 / s2,
    
    # --- I2 : I1 borne dans [-1, 1] ---
    I2 = (I1 - 1) / (I1 + 1),
    
    # --- I3 : le meme rapport sur le complement ---
    I3 = (1 - s1) / (1 - s2),
    
    # --- TIBI : I1 corrige par I3, puis borne ---
    ratio = I1 / I3,
    TIBI  = (ratio - 1) / (ratio + 1)
  ) %>%
  filter(exporterId != importerId) %>%
  mutate(pays_exp = lab[exporterId], pays_imp = lab[importerId])

# cas limites, comme dans le calcul reel
prox_tibi$TIBI[prox_tibi$Xi == 0] <- NA_real_
prox_tibi$TIBI[prox_tibi$Xi > 0 & prox_tibi$Xij == prox_tibi$Xi] <- 1
prox_tibi$TIBI[prox_tibi$Xi > 0 & prox_tibi$Xij == 0] <- -1

cat("\n=== B1. Une ligne par paire orientee ===\n")
cat("  I0   : Xij / (Xi x Xj / X), l indice de Balassa\n")
cat("  s1   : part des exports de i allant vers j\n")
cat("  s2   : la meme part, pour le reste du monde\n")
cat("  I1   : s1 / s2, corrige la variabilite de l intervalle\n")
cat("  I2   : I1 borne dans [-1, 1]\n")
cat("  I3   : le meme rapport sur le complement\n")
cat("  TIBI : I1/I3 borne, corrige l ambiguite dynamique\n\n")

print(prox_tibi %>%
        select(pays_exp, pays_imp, Xij, Xi, Xj, I0, s1, s2, I1, I2, I3, TIBI) %>%
        arrange(desc(TIBI)) %>%
        mutate(across(where(is.numeric), ~ round(.x, 3))) %>%
        as.data.frame())


# # ============================================================================
# # PARTIE C : les deux approches cote a cote, sur la paire non orientee
# # ============================================================================
# cat("\n\n########## C. COMPARAISON ##########\n")
# 
# comp <- prox_tibi %>%
#   mutate(a = pmin(exporterId, importerId), b = pmax(exporterId, importerId)) %>%
#   group_by(a, b) %>%
#   summarise(I0_moy   = mean(I0, na.rm = TRUE),
#             TIBI_moy = mean(TIBI, na.rm = TRUE),
#             TIBI_max = max(TIBI, na.rm = TRUE),
#             .groups = "drop") %>%
#   left_join(prox_im %>% select(a, b, pays_a, pays_b, Dd), by = c("a", "b")) %>%
#   select(pays_a, pays_b, Dd, I0_moy, TIBI_moy, TIBI_max) %>%
#   arrange(desc(Dd))
# 
# cat("\n  Dd       : critere Intramax, sur la matrice symetrique\n")
# cat("  I0_moy   : Balassa moyen des deux sens\n")
# cat("  TIBI_moy : TIBI moyen des deux sens\n")
# cat("  TIBI_max : TIBI du sens le plus intense\n\n")
# print(comp %>% mutate(across(where(is.numeric), ~ round(.x, 3))) %>% as.data.frame())
# 
# write.csv(prox_im,   "results/bloc_study/proximites_intramax_1938.csv", row.names = FALSE)
# write.csv(prox_tibi, "results/bloc_study/proximites_tibi_1938.csv", row.names = FALSE)
# write.csv(comp,      "results/bloc_study/proximites_comparaison_1938.csv", row.names = FALSE)