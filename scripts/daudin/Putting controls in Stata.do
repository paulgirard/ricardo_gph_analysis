
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"


capture program drop creation_undir_pair_key
program creation_undir_pair_key

tostring(target), replace
tostring(source), replace
keep if source < target
gen undir_pair_key= source+"-"+ target  if source < target
end


import delimited "external data/Controls panel/distance.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 

rename key undir_pair_key

save "external data/Controls panel/distance.dta", replace

import delimited "external data/Controls panel/alliances.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
rename key undir_pair_key
save "external data/Controls panel/alliances.dta", replace
**Défini jusqu’en 2018


import delimited "external data/Controls panel/contiguity.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
rename key undir_pair_key
save "external data/Controls panel/contiguity.dta", replace

import delimited "external data/Controls panel/disputes.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
rename key undir_pair_key
save "external data/Controls panel/disputes.dta", replace
**Défini jusqu’en 2014


import delimited "external data/BlocselonAN.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/BlocselonAN.dta", replace
/*
***BlocsselonAN n’est pas complet mais nous ne l’utilisons pas
*/