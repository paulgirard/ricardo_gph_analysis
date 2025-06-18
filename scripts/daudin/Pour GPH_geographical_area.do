import delimited "/Users/guillaumedaudin/Répertoires Git/GeoPolHist/data/GeoPolHist_entities.csv", clear
tempfile GPH_entities
save `GPH_entities'

import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_data/data/RICentities.csv", clear
tempfile RIC_entities
save `RIC_entities'

use `RIC_entities', clear
keep if type=="geographical_area"
tempfile RIC_geographical_area
keep continent ricname
rename continent geo_continent
rename ricname geo_ricname
save `RIC_geographical_area'



*=Pour repérer des soucis
use `RIC_entities', clear
gen str460 gph_name=ricname
merge 1:1 gph_name using `GPH_entities'

***Problème 1 : "GPH_entity" dans Ricardo qui ne sont pas dans GeoPolHist
tab type if _merge==1
tab ricname if _merge==1 & type=="GPH_entity"

***Problème 2 : "locality" dans Ricardo qui sont dans GeoPolHist
tab type if _merge==3
tab ricname if _merge==3 & type=="locality"
*******************Pour construire le fichier GPH_geographical_area
use `RIC_geographical_area', clear

use `RIC_entities', clear
drop if gph_code==.
merge 1:1 gph_code using `GPH_entities'
keep if _merge==3
drop _merge
keep ricname continent gph_code
tempfile GPH_inter_RIC
save `GPH_inter_RIC'

// On garde les entités de Ricardo qui sont dans GeoPolHist

use `GPH_inter_RIC', clear
cross using `RIC_geographical_area'
