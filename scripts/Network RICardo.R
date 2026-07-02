rm(list = ls(all = TRUE))
gc()
library(dplyr)
options(max.print=10000000)
library(tidyverse)
library(readxl)
library(ggplot2)
# Charger le package
library(writexl)
library(tidyr)


setwd('/Users/Ghallada/Dropbox/Postdoc Track/Project RICardo/Ties that trade/')

Network1833 <- read.csv("~/Dropbox/Postdoc Track/Project RICardo/Ties that trade/tradeFlows_1833_gravity.csv")


Network1833<-Network1833[Network1833$status=="ok",]
Network1833 <- Network1833[Network1833$reportedBy == Network1833$exporterId, ] #je selectionne que les flux tel que rapporté par l'exportateur (FOB)

library(tidyr)
library(tibble)
library(tidyr)
library(tibble)

# 1) MATRICE depuis Network1833 --------------------------------------
df <- Network1833[, c("exporterLabel", "importerLabel", "value")]
df <- df[!is.na(df$exporterLabel) & !is.na(df$importerLabel) & !is.na(df$value), ]

pays <- sort(unique(c(as.character(df$exporterLabel),
                      as.character(df$importerLabel))))
M <- matrix(NA_real_, length(pays), length(pays), dimnames = list(pays, pays))
M[cbind(match(df$exporterLabel, pays), match(df$importerLabel, pays))] <- df$value

# 1) retirer les entites sans commerce, garder carre
garde <- rowSums(M, na.rm = TRUE) > 0 | colSums(M, na.rm = TRUE) > 0 
M <- M[garde, garde]

# 2) normalisation par commerce total
M <- M / sum(M, na.rm = TRUE)
       

# 2-6) INTRAMAX ------------------------------------------------------
historique <- data.frame(etape = integer(), groupe_a = character(), groupe_b = character(),
                         difference = numeric(), flux_interne = numeric(),
                         interne_cumule = numeric(), stringsAsFactors = FALSE)
etats <- list(); interne_cumule <- 0; etape <- 0
detail_etape <- list()   # un data.frame par etape
while (nrow(M) > 1) {
  etape <- etape + 1
  etats[[etape]] <- rownames(M)                 # photo des groupes AVANT la fusion
  
  tot_lignes   <- rowSums(M, na.rm = TRUE)       # 2) totaux
  tot_colonnes <- colSums(M, na.rm = TRUE)
  total        <- sum(M, na.rm = TRUE)
  
  E <- outer(tot_lignes, tot_colonnes) / total   # 3) attendu
  
  # 4) ratio — SOMME des deux sens
  Dd <- M/E-1     #Mettre le ratio
  Dd[!is.finite(Dd)] <- 0
  #D  <- Dd + t(Dd)
  D  <- pmax(Dd, t(Dd))  
  D[lower.tri(D, diag = TRUE)] <- NA
  
  g <- which(D == max(D, na.rm = TRUE), arr.ind = TRUE)[1, ]   # paire gagnante
 
  i <- g[1]; j <- g[2]
  
  flux_interne   <- sum(M[i, j], M[j, i], na.rm = TRUE)        # augmentation intrabloc
  interne_cumule <- interne_cumule + flux_interne
  
  historique <- rbind(historique, data.frame(
    etape = etape, groupe_a = rownames(M)[i], groupe_b = rownames(M)[j],
    difference = D[i, j], flux_interne = flux_interne, interne_cumule = interne_cumule,
    stringsAsFactors = FALSE))
  
  nouveau <- paste(rownames(M)[i], rownames(M)[j], sep = "+")  # 5) fusion
  M[i, ] <- colSums(M[c(i, j), ], na.rm = TRUE)
  M[, i] <- rowSums(M[, c(i, j)], na.rm = TRUE)
  M[i, i] <- NA
  M <- M[-j, -j, drop = FALSE]
  rownames(M)[i] <- colnames(M)[i] <- nouveau
}

# ---- resultats ----
head(historique, 20)                 # les premieres fusions
plot(historique$etape, historique$flux_interne, type = "b",
     xlab = "etape de fusion", ylab = "flux devenu interne (en part du monde)",
     main = "Jump par étape") # Cutoff to 10% valid mais premier jump à 5%

seuil <- 0.1
rupture <- which(historique$flux_interne >= seuil)[1]   # 1er saut >= 10%
if (is.na(rupture)) {
  cat("Aucun saut >= 10% : un seul bloc.\n")
  blocs <- list(rownames(M))
} else {
  cat("Rupture a l'etape", rupture,
      "(flux =", round(historique$flux_interne[rupture], 3), ") -> on coupe juste avant.\n")
  blocs <- strsplit(etats[[rupture]], "+", fixed = TRUE)   # etat AVANT la fusion-rupture
}
blocs #tous les blocs
blocs[sapply(blocs, length) > 1] # juste ceux avec blocs>1

# Cut somewhere between step 40-65
#etape_cut <- 60  
#blocs <- strsplit(etats[[etape_cut]], "+", fixed = TRUE)
#blocs[sapply(blocs, length) > 1]

#Si je veux choisir moi-même nb blocs
# choisis un nombre de blocs et lis la composition :
#k <- 6
#blocs <- strsplit(etats[[nrow(historique) + 1 - k]], "+", fixed = TRUE)
#names(blocs) <- paste0("bloc_", seq_along(blocs))   # noms lisibles
#blocs                                               

library(igraph)


# 1) blocs

groupes   <- strsplit(etats[[rupture]], "+", fixed = TRUE)
pays_bloc <- data.frame(pays = unlist(groupes),
                        bloc = rep(seq_along(groupes), lengths(groupes)),
                        stringsAsFactors = FALSE)
tailles   <- table(pays_bloc$bloc)
#pays_bloc <- pays_bloc[pays_bloc$bloc %in% names(tailles)[tailles > 1], ]
pays_bloc$multi <- tailles[as.character(pays_bloc$bloc)] > 1 

# ---- DATAFRAME DES PAIRES : meme bloc ou non ----
paires <- expand.grid(exportateur = pays_bloc$pays,
                      importateur = pays_bloc$pays,
                      stringsAsFactors = FALSE)
paires <- paires[paires$exportateur != paires$importateur, ]   # enleve i == j

paires$bloc_exp  <- pays_bloc$bloc[match(paires$exportateur, pays_bloc$pays)]
paires$bloc_imp  <- pays_bloc$bloc[match(paires$importateur, pays_bloc$pays)]
paires$meme_bloc <- as.integer(paires$bloc_exp == paires$bloc_imp)

# (optionnel) ajouter la valeur du commerce reel
paires <- merge(paires,
                Network1833,
                by.x = c("exportateur", "importateur"),
                by.y = c("exporterLabel", "importerLabel"),
                all.x = TRUE)
#paires$value[is.na(paires$value)] <- 0

head(paires)

# 2) aretes = flux reels (directed = sens exporter -> importer)
noeuds <- pays_bloc$pays
ar <- df[df$exporterLabel %in% noeuds & df$importerLabel %in% noeuds,
         c("exporterLabel", "importerLabel", "value")]
ar <- ar[ar$value > 0, ]

g <- graph_from_data_frame(ar, vertices = pays_bloc, directed = TRUE)

# 3) COULEUR DES NOEUDS = bloc
ub <- sort(unique(pays_bloc$bloc))
V(g)$color <- ifelse(V(g)$multi,
                     rainbow(length(ub))[match(V(g)$bloc, ub)],  # bloc -> sa couleur
                     "lightgray")       

# 4) epaisseur des aretes = valeur du flux (log)
w <- E(g)$value
E(g)$width <- 0.3 + 3 * (log1p(w) - min(log1p(w))) / (max(log1p(w)) - min(log1p(w)))

# 5) layout
m1 <- V(g)$bloc[match(ar$exporterLabel, V(g)$name)]
m2 <- V(g)$bloc[match(ar$importerLabel, V(g)$name)]
poids <- ifelse(m1 == m2, 8, 1) * log1p(E(g)$value)
set.seed(1)
lay <- layout_with_fr(g, weights = poids, niter = 10000)

# 5b) taille = degre (nombre de connexions)
deg <- degree(g)

# 6) trace
plot(g, layout = lay,
     vertex.color       = V(g)$color,
     vertex.size        = 3 + 6 * (deg / max(deg)),   # <-- taille = degre
     vertex.frame.color = NA,
     vertex.label       = V(g)$name,
     vertex.label.cex   = 0.55,
     vertex.label.color = "black",
     vertex.label.dist  = 0.6,
     edge.color         = adjustcolor("grey40", 0.2),
     edge.arrow.size    = 0.15,
     edge.curved        = 0.1)

legend("topleft",
       legend = "bloc d'un seul pays",
       col    = "lightgray", pch = 19, pt.cex = 1.2, cex = 0.7, bty = "n")


write.csv(paires, "paires_blocs_1833.csv", row.names = FALSE)