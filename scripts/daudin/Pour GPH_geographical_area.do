import delimited "/Users/guillaumedaudin/Répertoires Git/GeoPolHist/data/GeoPolHist_entities.csv", clear
rename continent gph_continent
tempfile GPH_entities
save `GPH_entities'

import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_data/data/RICentities.csv", clear
gen strlen = length(ricname)
summarize strlen, meanonly
generate str`r(max)' blif=ricname
drop ricname str
rename blif ricname
tempfile RIC_entities
save `RIC_entities'

////***On va récupérer les infos dans "RICardo_RICentities + détails.csv"
import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/scripts/daudin/RICardo_RICentities + détails.csv", delimiter(comma) clear 
keep ricname /*totalnbflows nbflowsreporting*/ nbflowspartner /*bilateralperiodsreporting*/ bilateralperiodspartner
**Ils ne sont jamais reporting
gen strlen = length(ricname)
summarize strlen, meanonly
generate str`r(max)' blif=ricname
drop ricname str
rename blif ricname
rename ricname geo_name
tempname RIC_details
save `RIC_details', replace

////On enrichi les RIC_entities avec les infos de RIC_details
use `RIC_entities', clear
keep if type=="geographical_area"
tempfile RIC_geographical_area
keep continent ricname
rename continent geo_continent
rename ricname geo_name
keep geo_name geo_continent
merge 1:1 geo_name using `RIC_details'
drop if _merge==2
drop _merge

save `RIC_geographical_area'



*=Pour repérer des soucis
use `RIC_entities', clear
rename ricname gph_name
merge 1:1 gph_name using `GPH_entities'

***Problème 1 : "GPH_entity" dans Ricardo qui ne sont pas dans GeoPolHist
tab type if _merge==1
tab gph_name if _merge==1 & type=="GPH_entity"

***Problème 2 : "locality" dans Ricardo qui sont dans GeoPolHist
tab type if _merge==3
tab gph_name if _merge==3 & type=="locality"
tab gph_name if _merge==3 & type=="geographical_area"
set more on
more
set more off
*******************Pour construire le fichier GPH_geographical_area
*use `RIC_geographical_area', clear


// On garde les entités GPH qui sont dans Ricardo
use `RIC_entities', clear
drop if gph_code==.
merge 1:1 gph_code using `GPH_entities'
keep if _merge==3
**Pour repérer des problèmes
* assert continent==gph_continent
rename continent ric_continent
disp "Il y a des problèmes de continent entre Ricardo et GPH pour les entités suivantes"
list *continent gph_code ricname if ric_continent!=gph_continent 
set more on
more
set more off
*****
drop _merge
drop ric_continent
rename ricname id_name
keep id_name gph_continent gph_code
tempfile GPH_inter_RIC
save `GPH_inter_RIC'


///On fait le croisement avec les entités GPH qui sont dans Ricardo et les zones géographiques de Ricardo
use `GPH_inter_RIC', clear
cross using `RIC_geographical_area'
tempfile GPHxgeographical_area
save `GPHxgeographical_area'





/// Importation du fichier de travail
import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/scripts/GPH_geographical_area.csv", clear 
rename continent gph_continent
rename ricname geo_name
rename gph_name id_name
capture drop ricnameperiodbeginendyear

merge 1:1 gph_code geo_name using `GPHxgeographical_area'





***On prépare pour ce qu’il y à faire à la main
drop if _merge==1
drop _merge
**Des choses automatiques faciles
drop if strmatch(geo_name,"World*")==1
drop if gph_continent != geo_continent & (geo_continent=="Africa" | geo_continent=="Asia" | geo_continent=="America" | geo_continent=="Europe" | geo_continent=="Oceania") 
tostring gph_code, replace
sort gph_code geo_continent geo_name 
order gph_code id_name gph_continent geo_name geo_continent   included partially_included
replace included=1 if gph_continent==geo_name
gen line_number=_n


export delimited using "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/scripts/GPH_geographical_area_work.csv", replace


