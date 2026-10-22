cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

*****************************************
capture program drop bestguessbiltrade 
program define bestguessbiltrade
	args year 

****Maintenant, j’aimerai créer une base du best guess du commerce

import delimited "results/gravity/gravity_`year'.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/ stringcols(3 6 10 13 15)
***To force ReportedBy newReporters and originalReportedTradeFlowIds to be a string even if empty



bys importerLabel exporterLabel CafFob : assert _N==1


capture noisily assert value!=.
if _rc!=0 {
	di as error "Some ok flows have missing value. This should not happen. Please check the data `year' `CafFob'."
}



save temp.dta, replace


***************Création des flux non rapportés

use "temp.dta", clear
keep importerId
bys importerId: keep if _n==1
rename importerId actor

save actor.dta, replace
use "temp.dta", clear
keep exporterId
bys exporterId: keep if _n==1
rename exporterId actor

append using actor.dta
bys actor : keep if _n==1

save actor.dta, replace

use actor.dta, clear
rename actor importerId
gen exporterId=""
save importerId.dta, replace

use actor.dta, clear
rename actor exporterId
cross using ImporterId.dta
gen CafFob = "caf" in 1
replace CafFob="fob" in 2

fillin importerId exporterId CafFob
drop if importerId==exporterId
drop if CafFob==""
drop if importerId==.
drop if exporterId==.
drop _fillin

gen id = strofreal(importerId)+"<-"+strofreal(exporterId) if CafFob=="caf"
replace id = strofreal(exporterId)+"->"+strofreal(importerId) if CafFob=="fob"

merge  1:1 id using temp.dta



blif


fillin exporterId importerId
drop if importerId==exporterId
replace value  = . if _fillin ==1
replace status = "not reported" if _fillin ==1
replace CafFob = "`CafFob'" if _fillin ==1
replace year=`year' if _fillin ==1
drop _fillin






***********Création des clefs



capture drop undir_pair_key
gen undir_pair_key = strofreal(importerId) + "-" + strofreal(exporterId) if strofreal(importerId) < strofreal(exporterId) & importerId!=. & exporterId!=.
		replace undir_pair_key = strofreal(exporterId) + "-" + strofreal(importerId) if strofreal(importerId) > strofreal(exporterId) & importerId!=. & exporterId!=.
order undir_pair_key

drop if undir_pair_key=="" & id==""


capture drop key
	if CafFob=="fob" {
		gen key = strofreal(importerId) + "<-R" + strofreal(exporterId) if strofreal(importerId) < strofreal(exporterId) & importerId!=. & exporterId!=.
		replace key = "R" + strofreal(exporterId) + "->" + strofreal(importerId) if strofreal(importerId) > strofreal(exporterId) & importerId!=. & exporterId!=.
	}
	if CafFob=="caf" {
		gen key = "R" + strofreal(importerId) + "<-" + strofreal(exporterId) if strofreal(importerId) < strofreal(exporterId) & importerId!=. & exporterId!=.
		replace key = strofreal(exporterId) + "->" + "R" + strofreal(importerId) if strofreal(importerId) > strofreal(exporterId) & importerId!=. & exporterId!=.
	}
assert key!=""

order  undir_pair_key key

sort undir_pair_key key


////Nettoyage

capture drop id
capture drop valueToSplit
capture drop reporter_no
capture drop importerLabel importerType exporterLabel exporterType /*
    */ reportedBy partial  newReporters newPartners originalReportedTradeFlowIds notes

export delimited using "results/BestGuessBilTrade_`year'_`CafFob'.csv", replace quote
erase temp.dta
save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace


end


bestguessbiltrade 1841

blif
bestguessbiltrade 1833 fob
bestguessbiltrade 1833 caf




foreach year of numlist 1834(1)1938  {
	bestguessbiltrade `year' fob
	bestguessbiltrade `year' caf
}



foreach year of numlist 1948(1)2025 {
	bestguessbiltrade `year' fob
}
