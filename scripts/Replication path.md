# Replication path

## External data and controls
### dependency 
`daudin/Pour relations de dépendance.do`
Creates 
`external data/dependency_relations.csv`
From 
https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities_status_over_time.csv 

## Data generation

### Before gravity (Paul) (YYYY < 1939, from 1833)

From data in https://github.com/medialab/GeoPolHist and https://github.com/medialab/GeoPolHist/ricardo_data, Paul creates data/tradeFlows_YYYY_ratios.csv

### Gravity (Guillaume) (YYYY < 1939)
From:
data/tradeFlows_YYY_ratios.csv pour les flux
From
`external data/dependency_relations.csv`
pour les liens politiques
https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" pour les données de localisation
- Using scripts/daudin/Pour gravité.do (stata), Guillaume creates results/BestGuessBilTrade_YYYY.csv and results/gravity_XXXX.csv

### Post gravity data (Paul) (YYYY < 1939)
```
cd scripts

npm i 
De Guillaume ?
npm uninstall sqlite3
npm install sqlite3@latest

```

**installer les dépendances à ne faire qu'une seule fois**

`npm run gravity `

**lit le dossier results et exporte les réseaux au format json et gephi lite**

`npm run quality-gravity`

**exporte au format tradeFlows_{year}.csv** 


From Pour results/gravity_XXXX.csv, Paul creates `data/tradeFlows_YYYY_gravity.csv`

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

??? Les blocs AN (géographiques) sont faits avec un code + "à la main" pour renseigner le fichier `data_BlocselonAN.csv`


### Louvain (Paul)
`npm run louvain-modularity `

**exporte les blocs (il faut avoir recalculé intramax avant) à la fois louvain et gph_by_year**



creates `data/blocks/louvain/YYYY_caf/fob.csv`

Ce fichier comprend en fait tous les types de block (AN, Intramax, Louvain) avec les valeurs avec la métrique
+ fichier avec modularité et nombre de blocks par année.
Attention ! Ce fichier ne comprend que les paires qui commercent -- même si toute l’information utile s’y trouve.

Ce fichier comprend la liste des GPH avec leurs blocs:

`data/blocks/master_YYYY_caf/fob.csv`

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
- Et mise de tout dans le même fichier: grâce à scripts/Ghallada/Variables de controles.R
### Contiguité (Youssef)
De COW :
Correlates of War Project. Direct Contiguity Data, 1816-2016. Version 3.2.

Douglas M. Stinnett, Jaroslav Tir, Philip Schafer, Paul F. Diehl, and Charles Gochman
(2002). "The Correlates of War Project Direct Contiguity Data, Version 3." *Conflict
Management and Peace Science* 19 (2):58-66.

+ script (dans "scripts/Ghallada/Variables de controles.R")

+ travail à la main pour les xxxx

produit `data/blocks/Controls panel/contiguity.csv`


### Distance
De.... https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" pour les données de localisation 
Dans le script "scripts/Ghallada/Variables de controles.R"
- produit data/blocks/Controls panel/distance.csv

### Conflit
De COW + GPH (deux pays sont en conflit si leurs souverains sont en conflit)
Script ???
- Produit data/blocks/Controls panel/disputes.csv

### Alliances
De ATOP 5.1
- Produit data/blocks/Controls panel/alliances.csv
###Contiguity manquant
- Produit data/blocks/Controls panel/na_contig_a_coder.csv

### Base qui rassemble tout
- data/blocks/master_panel_carre.csv.xz
- data/blocks/master_panel_rectangle.csv.xz

## Régressions (Guillaume)

Prendre l’appartenance AN  comme une variable explicative.