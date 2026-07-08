library(here)
library(ggplot2)
library(maps)

monde <- map_data("world")
coord <- read.csv(here("data", "GeoPolHist_entities.csv"), stringsAsFactors = FALSE)
coord <- coord[, c("GPH_code", "lat", "lng")]
coord$GPH_code <- as.character(coord$GPH_code)


annees <- 1833:1938

# ---- couleur fixe par pays ----
tous_pays <- c()
for (year in annees) {
  f <- here("data", "blocks", "Intramax", paste0("paires_blocs_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  tous_pays <- c(tous_pays, d$exportateur, d$importateur)
}
tous_pays <- sort(unique(tous_pays))
# ================= COULEURS =================

# 1) Couleurs définies soi-même
couleurs_top20 <- c(
  "France"                                   = "#0055A4",
  "United Kingdom"                           = "#CF142B",
  "Russia (USSR)"                            = "deepskyblue",
  "United States of America"                 = "#0A3161",
  "Italy"                                    = "#008C45",
  "Belgium"                                  = "#FFFF00",
  "Spain"                                    = "#f6b511",
  "Netherlands"                              = "#FF8C00",
  "Mexico"                                   = "#006847",
  "Brazil"                                   = "gold",
  "Portugal"                                 = "#717910",
  "Turkey (Ottoman Empire)"                  = "#A91101",
  "Germany (Zollverein)"                     = "#000000",
  "Argentina (La Plata)"                     = "#6CACE4",
  "Colombia (New Granada) (Gran Colombia)"   = "darkslategray1",
  "Hamburg"                                  = "gray33",
  "India"                                    = "#CD5C5C",
  "Austria-Hungary (Austrian Empire)"        = "coral",
  "Chile"                                    = "purple",
  "Canada (Province of Canada)"              = "#A38E6F"
)

# 2) LES AUTRES PAYS : palette bien separee automatiquement
autres <- setdiff(tous_pays, names(couleurs_top20))
n <- length(autres)
# rainbow "espace" : on prend des teintes reparties + on melange pour eviter les voisins proches
set.seed(1)
couleurs_autres <- setNames(sample(grDevices::rainbow(n, s = 0.5, v = 0.9)), autres)

# 3) fusion des deux
couleur_pays <- c(couleurs_top20, couleurs_autres)
# ---- cartes ----
for (year in annees) {
  f <- here("data", "blocks", "Intramax", paste0("paires_blocs_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  d <- d[!is.na(d$value), ]
  
  exp <- unique(d[, c("exportateur", "exporterId", "bloc_exp")]); names(exp) <- c("pays","gph","bloc")
  imp <- unique(d[, c("importateur", "importerId", "bloc_imp")]); names(imp) <- c("pays","gph","bloc")
  pays_bloc <- unique(rbind(exp, imp)); pays_bloc$gph <- as.character(pays_bloc$gph)
  
  vol_exp <- aggregate(value ~ exportateur, d, sum, na.rm=TRUE); names(vol_exp) <- c("pays","v1")
  vol_imp <- aggregate(value ~ importateur, d, sum, na.rm=TRUE); names(vol_imp) <- c("pays","v2")
  vol <- merge(vol_exp, vol_imp, by="pays", all=TRUE)
  vol$v1[is.na(vol$v1)] <- 0; vol$v2[is.na(vol$v2)] <- 0
  vol$total <- vol$v1 + vol$v2
  
  pays_bloc <- merge(pays_bloc, vol[,c("pays","total")], by="pays", all.x=TRUE)
  pays_bloc$total[is.na(pays_bloc$total)] <- 0
  

  # gros_pays = plus gros pays du bloc
  gros_pays <- do.call(rbind, lapply(split(pays_bloc, pays_bloc$bloc), function(b)
    data.frame(bloc=b$bloc[1], gros_pays=b$pays[which.max(b$total)], stringsAsFactors=FALSE)))
  pays_bloc <- merge(pays_bloc, gros_pays, by="bloc", all.x=TRUE)
  
  # ---- singletons : meme etiquette ----
  taille_bloc <- table(pays_bloc$bloc)
  pays_bloc$singleton <- as.logical(taille_bloc[as.character(pays_bloc$bloc)] == 1)
  pays_bloc$gros_pays[pays_bloc$singleton] <- "bloc d'un seul pays"
  
  carte <- merge(pays_bloc, coord, by.x="gph", by.y="GPH_code", all.x=TRUE)
  carte <- carte[!is.na(carte$lat) & !is.na(carte$lng), ]
  
  # ---- LEGENDE : on mappe la couleur sur le gros_pays (nom du plus gros pays) ----
  carte$gros_pays <- factor(carte$gros_pays)
  niveaux <- levels(carte$gros_pays)
  couleurs_presentes <- couleur_pays[niveaux]
  names(couleurs_presentes) <- niveaux
  couleurs_presentes["bloc d'un seul pays"] <- "darkgray"
  
  p <- ggplot() +
    geom_polygon(data = monde, aes(long, lat, group = group),
                 fill = "grey93", color = NA) +
    geom_point(data = carte, aes(lng, lat, color = gros_pays), size = 2.5) +
    geom_text(data = carte, aes(lng, lat, label = pays), size = 1.6, vjust = -0.8,
              show.legend = FALSE) +
    scale_color_manual(values = couleurs_presentes, name = "Bloc (plus gros pays (en part de commerce mondial) par bloc)") +
    coord_quickmap() +
    theme_void() +
    theme(legend.position = "right", legend.text = element_text(size = 6),
          legend.title = element_text(size = 7)) +
    labs(title = paste("Blocs commerciaux", year))

  ggsave(here("cartes", "Intramaxmap", paste0("carte_blocs_", year, ".png")),
         plot = p, width = 13, height = 7, dpi = 150)
}


annees <- 1833:1938
annees <- annees[file.exists(sprintf(here("cartes","Intramaxmap","carte_blocs_%d.png"), annees))]

html <- paste0(
  '<html><body style="text-align:center;font-family:sans-serif">',
  '<input type="range" min="', min(annees), '" max="', max(annees),
  '" value="', min(annees), '" id="s" style="width:80%"> <span id="y">', min(annees), '</span><br>',
  '<img id="img" src="carte_blocs_', min(annees), '.png" style="max-width:95%">',
  '<script>var s=document.getElementById("s");s.oninput=function(){',
  'document.getElementById("y").innerText=s.value;',
  'document.getElementById("img").src="carte_blocs_"+s.value+".png";}</script>',
  '</body></html>')

writeLines(html, here("cartes", "Intramaxmap", "diaporama.html"))

# ---- gif ----
library(magick)
fichiers <- sprintf(here("cartes","Intramaxmap","carte_blocs_%d.png"), 1833:1938)
fichiers <- fichiers[file.exists(fichiers)]
img <- image_read(fichiers)
anim <- image_animate(image_join(img), fps = 2)
image_write(anim, here("cartes","Intramaxmap","blocs_animation.gif"))

###Same for Louvain###

##D'abord inclure les flux export et import dans deux colonnes distinctes

annees <- 1833:1938

for (year in annees) {
  f_fob <- here("data", "blocks", "louvain", paste0(year, "_fob.csv"))
  f_tf  <- here("data", paste0("tradeFlows_", year, "_gravity.csv"))
  if (!file.exists(f_fob) || file.info(f_fob)$size == 0) next
  if (!file.exists(f_tf)  || file.info(f_tf)$size  == 0) next
  
  # --- fichier fob (Louvain) ---
  fob <- read.csv(f_fob, stringsAsFactors = FALSE)
  fob$source <- as.character(fob$source)
  fob$target <- as.character(fob$target)
  
  # --- tradeFlows filtre FOB (comme l'intramax) ---
  Net <- read.csv(f_tf, stringsAsFactors = FALSE)
  Net <- Net[Net$status == "ok", ]
  Net <- Net[Net$reportedBy == Net$exporterId, ]
  Net$exporterId <- as.character(Net$exporterId)
  Net$importerId <- as.character(Net$importerId)
  
  # table des flux : cle exportateur_importateur -> value
  flux <- Net[, c("exporterId", "importerId", "value")]
  
  # --- export : flux i->j (source=exporter, target=importer) ---
  fob <- merge(fob, flux,
               by.x = c("source", "target"),
               by.y = c("exporterId", "importerId"),
               all.x = TRUE)
  names(fob)[names(fob) == "value"] <- "export"
  
  # --- import : flux j->i (source=importer, target=exporter) ---
  fob <- merge(fob, flux,
               by.x = c("target", "source"),
               by.y = c("exporterId", "importerId"),
               all.x = TRUE)
  names(fob)[names(fob) == "value"] <- "import"
  
  # sauvegarde du fob enrichi
  write.csv(fob, here("data", "blocks", "louvain", paste0(year, "_fob_enrichi.csv")),
            row.names = FALSE)
}

##Generer les maps


monde <- map_data("world")
coord <- read.csv(here("data", "GeoPolHist_entities.csv"), stringsAsFactors = FALSE)
coord <- coord[, c("GPH_code", "lat", "lng")]
coord$GPH_code <- as.character(coord$GPH_code)

annees <- 1833:1938

# ---- couleur fixe par pays (sur toutes les annees) ----
tous_pays <- c()
for (year in annees) {
  f <- here("data", "blocks", "louvain", paste0(year, "_fob_enrichi.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  tous_pays <- c(tous_pays, d$sourceLabel, d$targetLabel)
}
tous_pays <- sort(unique(tous_pays))

# ================= COULEURS =================
couleurs_top20 <- c(
  "France"                                   = "#0055A4",
  "United Kingdom"                           = "#CF142B",
  "Russia (USSR)"                            = "deepskyblue",
  "United States of America"                 = "#0A3161",
  "Italy"                                    = "#008C45",
  "Belgium"                                  = "#FFFF00",
  "Spain"                                    = "#f6b511",
  "Netherlands"                              = "#FF8C00",
  "Mexico"                                   = "#006847",
  "Brazil"                                   = "gold",
  "Portugal"                                 = "#717910",
  "Turkey (Ottoman Empire)"                  = "#A91101",
  "Germany (Zollverein)"                     = "#000000",
  "Argentina (La Plata)"                     = "#6CACE4",
  "Colombia (New Granada) (Gran Colombia)"   = "darkslategray1",
  "Hamburg"                                  = "gray33",
  "India"                                    = "#CD5C5C",
  "Austria-Hungary (Austrian Empire)"        = "coral",
  "Chile"                                    = "purple",
  "Canada (Province of Canada)"              = "#A38E6F"
)

autres <- setdiff(tous_pays, names(couleurs_top20))
n <- length(autres)
set.seed(1)
couleurs_autres <- setNames(sample(grDevices::rainbow(n, s = 0.5, v = 0.9)), autres)

couleur_pays <- c(couleurs_top20, couleurs_autres)

# ---- cartes ----
for (year in annees) {
  f <- here("data", "blocks", "louvain", paste0(year, "_fob_enrichi.csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  
  # pays -> communaute -> gph, cote SOURCE et TARGET
  src <- unique(d[, c("sourceLabel", "source", "sourceCommunity")])
  names(src) <- c("pays", "gph", "bloc")
  tgt <- unique(d[, c("targetLabel", "target", "targetCommunity")])
  names(tgt) <- c("pays", "gph", "bloc")
  pays_bloc <- unique(rbind(src, tgt))
  pays_bloc$gph <- as.character(pays_bloc$gph)
  
  # volume : export (quand source) + import (quand target)
  vol_exp <- aggregate(export ~ sourceLabel, d, sum, na.rm = TRUE)
  names(vol_exp) <- c("pays", "v1")
  vol_imp <- aggregate(import ~ targetLabel, d, sum, na.rm = TRUE)
  names(vol_imp) <- c("pays", "v2")
  vol <- merge(vol_exp, vol_imp, by = "pays", all = TRUE)
  vol$v1[is.na(vol$v1)] <- 0; vol$v2[is.na(vol$v2)] <- 0
  vol$total <- vol$v1 + vol$v2
  
  pays_bloc <- merge(pays_bloc, vol[, c("pays", "total")], by = "pays", all.x = TRUE)
  pays_bloc$total[is.na(pays_bloc$total)] <- 0
  
  # gros_pays = plus gros pays de la communaute
  gros_pays <- do.call(rbind, lapply(split(pays_bloc, pays_bloc$bloc), function(b)
    data.frame(bloc = b$bloc[1], gros_pays = b$pays[which.max(b$total)], stringsAsFactors = FALSE)))
  pays_bloc <- merge(pays_bloc, gros_pays, by = "bloc", all.x = TRUE)
  
  # singletons : meme etiquette
  taille_bloc <- table(pays_bloc$bloc)
  pays_bloc$singleton <- as.logical(taille_bloc[as.character(pays_bloc$bloc)] == 1)
  pays_bloc$gros_pays[pays_bloc$singleton] <- "bloc d'un seul pays"
  
  carte <- merge(pays_bloc, coord, by.x = "gph", by.y = "GPH_code", all.x = TRUE)
  carte <- carte[!is.na(carte$lat) & !is.na(carte$lng), ]
  
  carte$gros_pays <- factor(carte$gros_pays)
  niveaux <- levels(carte$gros_pays)
  couleurs_presentes <- couleur_pays[niveaux]
  names(couleurs_presentes) <- niveaux
  couleurs_presentes["bloc d'un seul pays"] <- "darkgray"
  
  p <- ggplot() +
    geom_polygon(data = monde, aes(long, lat, group = group),
                 fill = "grey93", color = NA) +
    geom_point(data = carte, aes(lng, lat, color = gros_pays), size = 2.5) +
    geom_text(data = carte, aes(lng, lat, label = pays), size = 1.6, vjust = -0.8,
              show.legend = FALSE) +
    scale_color_manual(values = couleurs_presentes,
                       name = "Communauté (plus gros pays par communauté)") +
    coord_quickmap() +
    theme_void() +
    theme(legend.position = "right", legend.text = element_text(size = 6),
          legend.title = element_text(size = 7)) +
    labs(title = paste("Communautés Louvain", year))
  
  ggsave(here("cartes", "Louvainmap", paste0("carte_comm_", year, ".png")),
         plot = p, width = 13, height = 7, dpi = 150)
}

# ---- diaporama HTML ----
annees <- 1833:1938
annees <- annees[file.exists(sprintf(here("cartes","Louvainmap","carte_comm_%d.png"), annees))]

html <- paste0(
  '<html><body style="text-align:center;font-family:sans-serif">',
  '<input type="range" min="', min(annees), '" max="', max(annees),
  '" value="', min(annees), '" id="s" style="width:80%"> <span id="y">', min(annees), '</span><br>',
  '<img id="img" src="carte_comm_', min(annees), '.png" style="max-width:95%">',
  '<script>var s=document.getElementById("s");s.oninput=function(){',
  'document.getElementById("y").innerText=s.value;',
  'document.getElementById("img").src="carte_comm_"+s.value+".png";}</script>',
  '</body></html>')

writeLines(html, here("cartes", "Louvainmap", "diaporama.html"))

# ---- gif ----
library(magick)
fichiers <- sprintf(here("cartes","Louvainmap","carte_comm_%d.png"), 1833:1938)
fichiers <- fichiers[file.exists(fichiers)]
img <- image_read(fichiers)
anim <- image_animate(image_join(img), fps = 2)
image_write(anim, here("cartes","Louvainmap","blocs_animation.gif"))

