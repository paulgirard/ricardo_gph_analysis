import delimited "/Users/guillaumedaudin/Répertoires Git/GeoPolHist/data/GeoPolHist_entities.csv", clear
tempfile GPH_entities
save `GPH_entities'

import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_data/data/RICentities.csv", clear
 
gen str460 gph_name=ricname
merge 1:1 gph_name using `GPH_entities'

***Problème 1 : "GPH_entity" dans Ricardo qui ne sont pas dans GeoPolHist
tab type if _merge==1
tab ricname if _merge==1 & type=="GPH_entity"

***Problème 2 : "locality" dans Ricardo qui sont dans GeoPolHist
tab type if _merge==3
tab ricname if _merge==3 & type=="locality"