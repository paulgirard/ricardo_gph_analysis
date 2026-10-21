
**installer les dépendances à ne faire qu'une seule fois**
```
cd scripts

npm i 
De Guillaume ?
npm uninstall sqlite3
npm install sqlite3@latest

```




# Replication path

## External data and controls
Youssef has a general script for « his » controls: `scripts/Ghallada/Variables de controles.R`

### dependency et common empire 
`daudin/Pour relations de dépendance.do`
Creates 
`external data/Controls panel/dependency_relations.csv`
And 
`external data/Controls panel/common_empire.csv`
(And the stata versions)


From 
https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities_status_over_time.csv 

### AN (Youssef)
??? Les blocs AN (géographiques) sont faits avec un code + "à la main" pour renseigner le fichier `data_BlocselonAN.csv`

### Contiguité (Youssef)
De COW :
Correlates of War Project. Direct Contiguity Data, 1816-2016. Version 3.2.

Douglas M. Stinnett, Jaroslav Tir, Philip Schafer, Paul F. Diehl, and Charles Gochman
(2002). "The Correlates of War Project Direct Contiguity Data, Version 3." *Conflict
Management and Peace Science* 19 (2):58-66.

+ script (dans "scripts/Ghallada/Variables de controles.R")

+ travail à la main pour les xxxx

produit `external data/Controls panel/contiguity.csv`


### GeoPolHist_entities in stata
De.... https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" 
`script/daudin/Pour GeoPolHist_entities.do’
Crée
`external data/GeoPolHist_entities.dta’

### Distance
De.... https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities.csv" pour les données de localisation
On peut récupérer les données Wikidata en json. Mais il est affreux. Donc difficile à utiliser pour la contiguité. 
Dans le script "scripts/Ghallada/Variables de controles.R"
Produit `external data/Controls panel/distance.csv’

### Conflit
De COW + GPH (deux pays sont en conflit si leurs souverains sont en conflit)
Script : le même
Produit `external data/Controls panel/disputes.csv`

### Alliances
De ATOP 5.1
Produit `external data/Controls panel/alliances.csv`
### Contiguity manquant
- Produit `external data/Controls panel/na_contig_a_coder.csv`

### Variables explicatives en stata (Guillaume)
`scripts/daudin/Putting controls in Stata.do`
Crée des .dta dans le dossier Controls panel



## Data generation

### IMF data (YYYY >= 1948 up to 2025) (Youssef)
From:
external data/DoT Direction of Trade (IMF)/dataset_2026-09-10T10_46_06.578468509Z_DEFAULT_INTEGRATION_IMF.STA_IMTS_1.0.0.csv.zip (Comtrade data)
- external data/EXCHANGEPOUND_1948-2026.csv (exchange rates from Lawrence H. Officer, 'Dollar-Pound Exchange Rate From 1791,' MeasuringWorth, 2026.)
- scripts/tablegphdot.xlsx (pour traduction nom FMI vers GPH)

- Youssef uses scripts/Ghallada/MergeIMFRIC.R to create external data/DoT Direction of Trade (IMF)/tradeFlows_YYYY_gravity_CafFob.csv

### Before gravity (Paul) (YYYY < 1939, from 1833)

Salut, j'avais zappé que tu as besoin de la base de données SQLite Ricardo... Elle est un peu relou a construire. Je oeux lancer le script ce matin et t'envoyer un lien vers le fichier SQLite. Je te dis quand c'est fait. 
la base sqlite est là : https://nextcloud.ouestware.com/s/sEMXMAn8TYPp2X4

dans scripts/src/configuration.json il ya une variable "parthToRICardoData" qui indique où le script va chercher la base

Le plus simple est de cloner le repo RICardo_data dans un dossier ricardo_data à côté du dossier ricardo_gph_analysis
puis tu bouges la sqlite dnsle dossier sqlite_data


From data in https://github.com/medialab/GeoPolHist and https://github.com/medialab/GeoPolHist/ricardo_data,

Using

`npm run entities
npm run quality_ratio`

Paul creates data/tradeFlows_YYYY_ratios.csv + un fichier de diagnostics ‘tradeGraphsStats_ratios.csv’



### Gravity (Guillaume) (YYYY < 1939)
From:
`data/tradeFlows_YYY_ratios.csv` pour les flux pre-1938
+
Variables de contrôle
+
J’y mets aussi les « external data/DoT Direction of Trade (IMF)/tradeFlows_`year'_gravity_CafFob.csv" venus du FMI pour pouvoir les intégrer dans les graphiques.




Using `scripts/daudin/Pour gravité.do` (stata), Guillaume creates `results/gravity/gravity_XXXX.csv`-- avec les imputed zero et les échecs (mais pas les « ignore ») et `results/gravity/diag_gravity_XXXX.csv’


### Post-gravity diagnostics
From ‘results/gravity/diag_gravity_XXXX.csv’, using ‘scripts/daudin/Pour graphiques de diagnostique post-gravité.do’
Cela donne des graphiques : `results/gravity/value_share_method.png' et `results/gravity/flows_share_method.png’












### Creation of BestGuessBilTrade avec les 0 imputés, les vrais manquants et les non-rapportés
Using `scripts/daudin/Pour BestGuessBilTrade.do` (stata) à partir de data/tradeFlows_YYYY_gravity.csv Guillaume creates `results/BestGuessBilTrade_YYYY_Caf/Fob.csv`

## Bloc generation
### Intramax and Anderson-Norheim (1993) (Youssef)
À partir de `data/tradeFlows_YYYY_gravity.csv`
Création des block intramax : scripts/Ghallada/Intramax.R »
- donne data/blocks/Intramax/paires_blocs_YYYY.csv
### Louvain (Paul)

Utilise `results/gravity/YYYY.csv` et `data/blocks/Intramax/paires_blocs_YYYY.csv`et `external data/data_BlocselonAN.csv`
`npm run louvain-modularity `

Crée `results/communities/gph_blocks_by_year/1833.csv’ (ie index des blocs)
`results/communities/louvain/1833_gephi_lite.json’,
`results/communities/louvain/1833.csv’


Ce fichier comprend en fait tous les types de block (AN, Intramax, Louvain TIBI ajusté, Louvain TIBI signé) avec les valeurs avec la métrique
+ fichier avec modularité et nombre de blocks par année.
Attention ! Ce fichier ne comprend pas toutes les paires qui commercent.


## Métriques
### Modularité (Paul)
Vient aussi de `npm run louvain-modularity `

**Semble mort**
`results/communities/modularities_by_year.csv’
----------------------

### TIBI (Youssef)
À partir de "scripts/Ghallada/RegionalTradeintensityYear.R".
Graphiques : `results/communities/louvain/tibi_intracomm_moyen.png`, `results/communities/tibi_comparaison_intramax_louvain.png`, `results/communities/tibi_comparaison_avec_diff_nblocs.png`
### Commerce intrabloc (Guillaume)
À partir de `data/blocks/louvain/`year'_fob_enrichi.csv`
Avec `Pour part commerce intra-bloc.do`
Produit : `results/block_study/intra_block_share_fob.csv` et
`results/block_study/Intra-block trade share.png`
### Cartes (Youssef)
Cartes avec `scripts/Ghallada/Map year.R`
Cela donne cartes/louvainmap/.... et cartes/Intramaxmap/....
### Corrélation (Youssef)
Corrélations avec `scripts/Ghallada/RegionalTradeintensityYear.R`
Cela donne `results/communities/cor_intramax_louvain.csv, corr_intramax_louvain.png`

## Analyse

### Régressions sur l’appartenance à un bloc (Guillaume)

Prendre l’appartenance AN  comme une variable explicative.

À partir de `results/communities/master_YYYY_fob_.csv` NON PAS LES BONS

Programme : `scripts/daudin/Pour regression co-appartenance à un bloc.do`
Produit :` results/block_study/regression_results.csv`
Et `results/block_study/ln_dist_intramax_fob.png`


### Stat des marge extensive
#### par flows
From : `results/BestGuessBilTrade_YYYY_Caf/Fob.csv`
Script : `/scripts/daudin/Pour Marge extensive flow stats.do`

Results: 
`results/extensive/stat_Caf/Fob.csv`
`results/extensive/trade_actors_Caf/Fob.png’
`results/extensive/trade_flows_nbr_Caf/Fob.png’
`results/extensive/trade_flows_share_Caf/Fob.png’

#### par pair
From : `results/BestGuessBilTrade_YYYY_Caf/Fob.csv` + `https://github.com/medialab/GeoPolHist/data/GeoPolHist_entities`(pour labels) + `results/communities/gph_blocks_by_year/YYYY_Caf/Fob.csv`







