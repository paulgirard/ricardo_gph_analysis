rm(list = ls(all = TRUE))
gc()


setwd("/Users/youssef/Desktop/ricardo_gph_analysis")

source("scripts/Ghallada/MergeIMFRIC.R") ##Crée les données à partir du IMF
setwd("/Users/youssef/Desktop/ricardo_gph_analysis")

source("scripts/Ghallada/Network RICardo Year.R") ##Crée les réseaux intramax 
##data/blocks/...
setwd("/Users/youssef/Desktop/ricardo_gph_analysis")

source("scripts/Ghallada/Map year.R") ##Crée les cartes de réseaux intramax / Louvain + fichier louvain_enrichi.csv
setwd("/Users/youssef/Desktop/ricardo_gph_analysis")

source("scripts/Ghallada/RegionalTradeintensityYear.R") ##Crée le graph avec TIBI intra-block + corrélation

setwd("/Users/youssef/Desktop/ricardo_gph_analysis") ##Crée une matrice avec les trois réseaux + variables de contrôle sans colonie
## Crée des variables de contrôle dans "gravity_control" dossier.
source("scripts/Ghallada/Merge in one file all.R")

