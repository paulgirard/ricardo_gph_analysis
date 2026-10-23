library(dplyr); library(tidyr)
setwd("~/Desktop/ricardo_gph_analysis")

year    <- 1833
methode <- "blockAN"
serie   <- "fob_source"

# ============================================================
# 1. Les blocs de l annee
# ============================================================
b <- read.csv(file.path("results/communities/gph_blocks_by_year", paste0(year, ".csv")),
              stringsAsFactors = FALSE)
b$id <- as.character(b$id)

# completer blockAN depuis la table Anderson-Norheim
BlocselonAN <- read.csv("external data/BlocselonAN.csv", stringsAsFactors = FALSE)
region_map  <- BlocselonAN[, c("GPH_code", "region_AndersonNorheim")]
region_map$GPH_code <- as.character(region_map$GPH_code)

b <- b %>%
  left_join(region_map, by = c("id" = "GPH_code")) %>%
  mutate(blockAN = ifelse(is.na(blockAN) | blockAN == "",
                          region_AndersonNorheim, as.character(blockAN))) %>%
  select(-region_AndersonNorheim)

nrow(b)                          # nombre d entites
sum(is.na(b$blockAN))            # entites sans region AN

# ============================================================
# 2. Les flux, ventiles en 4 series
# ============================================================
g <- read.csv(file.path("results/gravity", paste0("gravity_", year, ".csv")),
              stringsAsFactors = FALSE)
g <- g[g$status == "ok" & !is.na(g$value), ]
g$exporterId <- as.character(g$exporterId)
g$importerId <- as.character(g$importerId)

# cle non orientee : a est le code le plus petit
g$a <- pmin(g$exporterId, g$importerId)
g$b <- pmax(g$exporterId, g$importerId)

g$serie <- case_when(
  g$exporterId == g$a & g$CafFob == "fob" ~ "fob_source",
  g$exporterId == g$a & g$CafFob == "caf" ~ "caf_target",
  g$exporterId == g$b & g$CafFob == "fob" ~ "fob_target",
  g$exporterId == g$b & g$CafFob == "caf" ~ "caf_source"
)

table(g$serie, useNA = "ifany")

flux <- g %>%
  select(a, b, serie, value) %>%
  pivot_wider(names_from = serie, values_from = value)

head(flux)

# ============================================================
# 3. Toutes les paires non orientees
# ============================================================
p <- as.data.frame(t(combn(sort(b$id), 2)), stringsAsFactors = FALSE)
names(p) <- c("a", "b")

p <- p %>%
  left_join(b %>% select(a = id, bloc_a = all_of(methode)), by = "a") %>%
  left_join(b %>% select(b = id, bloc_b = all_of(methode)), by = "b") %>%
  left_join(flux, by = c("a", "b"))

nrow(p)                     # paires possibles
sum(!is.na(p[[serie]]))     # paires avec un flux dans cette serie

# ============================================================
# 4. Matrice bloc-bloc
# ============================================================
dd <- p[!is.na(p[[serie]]) & !is.na(p$bloc_a) & !is.na(p$bloc_b), ]

# le sens de la serie decide qui est exportateur
sens_ab <- serie %in% c("fob_source", "caf_target")
type    <- if (grepl("^fob", serie)) "fob" else "caf"

mat <- data.frame(
  i     = if (sens_ab) dd$bloc_a else dd$bloc_b,   # bloc exportateur
  j     = if (sens_ab) dd$bloc_b else dd$bloc_a,   # bloc importateur
  value = dd[[serie]], stringsAsFactors = FALSE)

Xij <- aggregate(value ~ i + j, data = mat, FUN = sum)
names(Xij)[3] <- "Xij"

blocs  <- sort(unique(c(mat$i, mat$j)))
grille <- expand.grid(i = blocs, j = blocs, stringsAsFactors = FALSE)
grille <- merge(grille, Xij, by = c("i", "j"), all.x = TRUE)
grille$Xij[is.na(grille$Xij)] <- 0

# marges
X_tot <- sum(grille$Xij)
Xi <- tapply(grille$Xij, grille$i, sum)   # exports du bloc i
Xj <- tapply(grille$Xij, grille$j, sum)   # imports du bloc j
grille$Xi <- Xi[as.character(grille$i)]
grille$Xj <- Xj[as.character(grille$j)]

# ============================================================
# 5. TIBI
# ============================================================
if (type == "fob") {
  grille$base <- grille$Xi                                        # on raisonne en part des exports de i
  grille$s1   <- grille$Xij / grille$Xi                           # part de i allant vers j
  grille$s2   <- (grille$Xj - grille$Xij) / (X_tot - grille$Xi)    # meme part pour le reste du monde
} else {
  grille$base <- grille$Xj                                        # on raisonne en part des imports de j
  grille$s1   <- grille$Xij / grille$Xj                           # part de j venant de i
  grille$s2   <- (grille$Xi - grille$Xij) / (X_tot - grille$Xj)
}

I1 <- grille$s1 / grille$s2
I3 <- (1 - grille$s1) / (1 - grille$s2)
grille$TIBI <- (I1/I3 - 1) / (I1/I3 + 1)

# cas limites
grille$TIBI[grille$base == 0] <- NA_real_
grille$TIBI[grille$base > 0 & grille$Xij == grille$base] <- 1
grille$TIBI[grille$base > 0 & grille$Xij == 0] <- -1

# ============================================================
# 6. Diagonale, singletons, moyenne ponderee
# ============================================================
pb <- unique(rbind(
  data.frame(id = dd$a, bloc = dd$bloc_a),
  data.frame(id = dd$b, bloc = dd$bloc_b)
))
taille     <- table(pb$bloc)
singletons <- names(taille)[taille == 1]
singletons

g2 <- grille[!(grille$i %in% singletons) & !(grille$j %in% singletons), ]

diag_df <- g2[g2$i == g2$j & is.finite(g2$TIBI), c("i", "TIBI", "base")]
diag_df$w <- diag_df$base / X_tot
diag_df

sum(diag_df$w * diag_df$TIBI)   # le TIBI intra-bloc moyen pondere
nrow(diag_df)                   # nombre de blocs retenus