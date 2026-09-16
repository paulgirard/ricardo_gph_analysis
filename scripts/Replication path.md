# Replication path

## Data generation

### Before gravity (Paul) (YYYY < 1939, from 1833)

From data in https://github.com/medialab/GeoPolHist and https://github.com/medialab/GeoPolHist/ricardo_data, Paul creates data/tradeFlows_YYYY_ratios.csv

### Gravity (Guillaume) (YYYY < 1939)
From:
data/tradeFlows_YYY_ratios.csv pour les flux
https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities_status_over_time.csv pour les liens politiques
https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" pour les données de localisation
- Using scripts/daudin/Pour gravité.do (stata), Guillaume creates results/BestGuessBilTrade_YYYY.csv and results/gravity_XXXX.csv

### Post gravity data (Paul) (YYYY < 1939)
- From Pour results/gravity_XXXX.csv, Paul creates data/tradeFlows_YYYY_gravity.csv

### Graphique de diagnostic ?
Qui s’en occupe ?

### IMF data (YYYY > 1947 up to 2025) (Youssef)
From:
- scripts/dataset_2026-09-10T10_46_06.578468509Z_DEFAULT_INTEGRATION_IMF.STA_IMTS_1.0.0.csv.zip (Comtrade data)
- scripts/EXCHANGEPOUND_1948-2026.csv (exchange rates from Lawrence H. Officer, 'Dollar-Pound Exchange Rate From 1791,' MeasuringWorth, 2026.)
- scripts/tablegphdot.xlsx (pour traduction nom FMI vers GPH)

- Youssef uses scripts/Ghallada/MergeIMFRIC.R to create data/tradeFlows_YYYY_gravity.csv


## Block generation
### Intramax and Anderson-Norheim (1993) (Youssef)
Création des blocks intramax : scripts/Ghallada/Network RICardo Year.R"
- donne data/blocks/Intramax/paires_blocs_YYYY.csv

??? Les blocs AN (géographiques) sont faits avec un code + "à la main" pour renseigner data/BlocselonAN.xlsx

"c'était un code qui genere l'excel à compléter, un excel où il y a les gph avec flux existant (provenant de intramax ou gravity flow je pense), ensuite j'ai merge les differentes status over time pour décider (double checker) à quel bloc j'assigne chacun, en restant un max fidèle à AN."

Todo : retrouver le code

### Louvain (Paul)
- Paul does his magic ?????
	- creates data/blocks/louvain/YYYY_caf/fob.csv
Ce fichier comprend en fait tous les types de block (AN, Intramax, Louvain) avec les valeurs avec la métrique
+ fichier avec modularité et nombre de blocks par année.

## Métriques
### Modularité (Paul)
Paul does his magic ???
### TIBI (Youssef)
À partir de "scripts/Ghallada/RegionalTradeintensityYear.R".
- Graphiques : data/blocks/louvain/tibi_intracomm_moyen.png, data/blocks/tibi_comparaison_intramax_louvain.png, data/blocks/tibi_comparaison_avec_diff_nblocs.png

### Divers (Youssef)
- Cartes avec scripts/Ghallada/Map year.R
		-Cela donne cartes/louvainmap/.... et cartes/Intramaxmap/....

- Corrélations avec scripts/Ghallada/RegionalTradeintensityYear.R
	- Cela donne data/blocks/cor_intramax_louvain.csv, corr_intramax_louvain.png

## Variables explicatives (Youssef)
- Et mise de tout dans le même fichier: grâce à scripts/Ghallada/Merge in one file all.R
### Contiguité (Youssef)
De COW :
Correlates of War Project. Direct Contiguity Data, 1816-2016. Version 3.2.

Douglas M. Stinnett, Jaroslav Tir, Philip Schafer, Paul F. Diehl, and Charles Gochman
(2002). "The Correlates of War Project Direct Contiguity Data, Version 3." *Conflict
Management and Peace Science* 19 (2):58-66.

+ script (dans "scripts/Ghallada/Merge in one file all.R")

+ travail à la main pour les xxxx

- produit data/Gravity controls/contiguity_gph.csv

### Distance
De.... https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" pour les données de localisation 
Dans le script "scripts/Ghallada/Merge in one file all.R"

### Conflit
De COW + GPH (deux pays sont en conflit si leurs souverains sont en conflit)
Script ???
- Produit data/Gravity controls/bilateraldisputes_gph.csv

### Alliances
De ATOP 5.1
- Produit data/Gravity controls/alliance_gph.csv

### Base qui rassemble tout
- data/blocks/master_panel_carre.csv.xz
- data/blocks/master_panel_rectangle.csv.xz

## Régressions (Guillaume)

Prendre l’appartenance AN  comme une variable explicative.