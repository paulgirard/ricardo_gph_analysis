rm(list = ls(all = TRUE))
gc()
library(here)
library(ggplot2)
library(maps)



library(here)

# coordonnees
coord <- read.csv(here("GeoPolHist_entities.csv"), stringsAsFactors = FALSE)
coord <- coord[, c("GPH_code", "lat", "lng")]
coord$GPH_code <- as.character(coord$GPH_code)

# ---- rassembler TOUTES les entites (nom + gph) sur toutes les annees ----
tous <- data.frame(pays = character(), gph = character(), stringsAsFactors = FALSE)

for (year in 1833:1938) {
  f <- here("Pair_blocs_Intramax", paste0("paires_blocs_", year, ".csv"))
  if (!file.exists(f) || file.info(f)$size == 0) next
  d <- read.csv(f, stringsAsFactors = FALSE)
  exp <- unique(d[, c("exportateur", "exporterId")]); names(exp) <- c("pays", "gph")
  imp <- unique(d[, c("importateur", "importerId")]); names(imp) <- c("pays", "gph")
  tous <- rbind(tous, exp, imp)
}
tous <- unique(tous)
tous$gph <- as.character(tous$gph)

# ---- joindre les coordonnees ----
verif <- merge(tous, coord, by.x = "gph", by.y = "GPH_code", all.x = TRUE)

# ---- les manquants (pas de coordonnees) ----
manquants <- verif[is.na(verif$lat) | is.na(verif$lng), ]
manquants <- manquants[order(manquants$pays), ]
manquants <- manquants[!is.na(manquants$gph), ]

library(sf)
library(rnaturalearth)
install.packages("remotes")
remotes::install_github("ropensci/rnaturalearthhires")

######Aïr, trouver le centroïde avec region actuelle
# frontieres administratives du Niger (niveau region)
niger <- ne_states(country = "Niger", returnclass = "sf")

# la region d'Agadez recouvre a peu pres le territoire historique du sultanat
agadez <- niger[niger$name == "Agadez", ]

# centroide calcule sur le polygone reel
centroide <- st_centroid(st_geometry(agadez))
st_coordinates(centroide)   # lng, lat exacts

#In openstreet map:
#https://www.openstreetmap.org/search?lat=19.508&lon=9.558&zoom=7#map=7/19.508/9.558


#Annam
vietnam <- ne_countries(country = "Vietnam", returnclass = "sf")
centroide <- st_centroid(st_geometry(vietnam))
st_coordinates(centroide)   # X = lng, Y = lat
#In openstreet map:
#https://www.openstreetmap.org/search?lat=16.24&lon=107.84&zoom=6#map=9/16.236/107.842

#Bali
library(sf); library(rnaturalearth)
# Bali n'est pas un pays -> il faut les provinces d'Indonesie (rnaturalearthhires)
indo <- ne_states(country = "Indonesia", returnclass = "sf")
bali <- indo[indo$name == "Bali", ]
st_coordinates(st_centroid(st_geometry(bali)))
#In openstreet map:
#https://www.openstreetmap.org/search?lat=-8.4262&lon=115.0790&zoom=10#map=10/-8.4262/115.0790

#Peru–Bolivian Confederation
library(sf); library(rnaturalearth)
sa <- ne_countries(country = c("Peru", "Bolivia"), returnclass = "sf")
union <- st_union(sa)                          # fusionne les deux pays
st_coordinates(st_point_on_surface(union))     # point central sur les terres

#In openstreet map:
#https://www.openstreetmap.org/search?lat=-12.506&lon=-68.659&zoom=8#map=8/-12.265/-68.659


#British Columbia (déjà sur wikidata, plus ou moins ok)
canada <- ne_states(country = "Canada", returnclass = "sf")
bc <- canada[canada$name == "British Columbia", ]
st_coordinates(st_point_on_surface(st_geometry(bc)))
#https://www.openstreetmap.org/search?lat=54.62&lon=-125.24&zoom=4#map=4/54.62/-125.24


#Captaincy-general of north Africa (no wikipedia page or wikidata)

#Cochin China
#https://www.openstreetmap.org/search?lat=10.553&lon=106.183&zoom=8#map=8/10.553/106.183

#Dutch Posts (Gold Coast)
#https://www.openstreetmap.org/search?lat=5.1121&lon=-1.2511&zoom=11#map=11/5.1121/-1.2511

#French India
#https://www.openstreetmap.org/search?lat=11.9359&lon=79.8061&zoom=10#map=11/11.9359/79.8061

#Kenya Protectorate (I took Mombasa since most important city for both the Colony and Protectorate)
#https://www.openstreetmap.org/search?lat=-4.0437&lon=39.6668&zoom=11#map=11/-4.0437/39.6668

#Kingdom of Sardinia (separate entities, so i take the center of power Turin), impossible d'éditer la wikidata page
#https://www.openstreetmap.org/search?lat=45.087&lon=7.685&zoom=9#map=9/45.087/7.685

#Libya
#https://www.openstreetmap.org/search?lat=26.82&lon=18.15&zoom=5#map=5/26.82/18.15

#	Maldive Islands (déjà updaté par un utilisateur)

#Oil Rivers Protectorate
#https://www.openstreetmap.org/search?lat=5.096&lon=6.312&zoom=8#map=8/5.091/6.317

#Prince Edward Is. (déjà fait dans wikidata)
canada <- ne_states(country = "Canada", returnclass = "sf")
pei <- canada[canada$name == "Prince Edward Island", ]
st_coordinates(st_centroid(st_geometry(pei)))

#Prussia (ils en ont un dans wikidata et je ne peux pas changer anyway)

#Shanghai
#https://www.openstreetmap.org/search?lat=31.24201&lon=121.47326&zoom=13#map=13/31.24201/121.47326

#Togo (French Togoland)
#https://www.openstreetmap.org/search?lat=8.690&lon=1.055&zoom=7#map=7/8.690/1.055