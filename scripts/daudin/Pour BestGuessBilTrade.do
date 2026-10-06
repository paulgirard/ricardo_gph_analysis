cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

*****************************************
capture program drop bestguessbiltrade 
program define bestguessbiltrade
	args year CafFob

****Maintenant, j’aimerai créer une base du best guess du commerce

import delimited "data/tradeFlows_`year'_gravity.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/ stringcols(3 6 10 13 15)
***To force ReportedBy newReporters and originalReportedTradeFlowIds to be a string even if empty

generate CafFob=""
replace CafFob="caf" if reportedBy==importerId
replace CafFob="fob" if reportedBy==exporterId

keep if CafFob=="`CafFob'"

capture drop valueToSplit
capture dropvalueGeneratedBy


bys importerLabel exporterLabel CafFob : assert _N==1

drop if status=="ignore_duplicate" | status=="ignore_internal" | status=="ignore_resolved" | status=="ignore_partial_duplicate"

capture noisily assert value!=.
if _rc!=0 {
	di as error "Some ok flows have missing value. This should not happen. Please check the data `year' `CafFob'."
}



save temp.dta, replace
********Création des flux connus non mesurés (only useful for "our" treatment)

if year< 1948 {
use temp.dta,clear

tab status, missing

keep if strmatch(status,"split_*")
drop if strpos(newPartners,"restOfTheWorld")!=0
replace value=.

/// New method : we split first Partners and Reporters
split newPartners, parse("|") gen(newPartnerId)
reshape long newPartnerId, i(id CafFob newReporters) j(partner_no)
drop if (newPartnerId=="" & newReporters=="") | (partner_no!=1 & newReporters!="" & newPartners =="") 
destring(newPartnerId), replace

**RQ A :  This can produce duplicates in newPartnerId & importerId (or expoterId) if there are multiple reporters for a given partner in a split.
** eg in 1833, we have a value to split for "Bilbao<-Hanover & Hanse Towns" & one for "Cadix<-Hanse Towns|Málaga<-Hanse Towns" 
** This can proceed as we can assume that the relevant gravity coefficient are the same



//à faire seulement s’il y a des reporters à splitter
capture assert missing(newReporters)
	if _rc!=0 {
		split newReporters,parse ("|") gen(newReportersId)
		reshape long newReportersId, i(id partner_no CafFob ) j(reporter_no)
		drop if newReportersId=="" & reporter_no !=1
		destring(newReportersId), replace
		
	}

gen newimporterId=newPartnerId if CafFob=="fob"
capture assert missing(newReporters)
if _rc!=0 replace newimporterId=newReportersId if CafFob=="fob"

gen newexporterId=newPartnerId if CafFob=="caf"
capture assert missing(newReporters)
if _rc!=0  replace newexporterId=newReportersId if CafFob=="caf"  


///Putting importer and exporterId to newimporterId and newexporterId if no treatment is necessary.

destring(importerId), replace force
destring(exporterId), replace force
replace newimporterId=importerId if newimporterId==.
replace newexporterId=exporterId if newexporterId==.

*destring(newimporterId), replace
*destring(newexporterId), replace

sort originalReportedTradeFlowId
*drop importer_lbl-importer exporter

drop if newimporterId==newexporterId


replace importerId =newimporterId if newimporterId!=.
replace exporterId =newexporterId if newexporterId!=.
drop  new*

bys importerLabel exporterLabel CafFob: keep if _n==1
bys importerId exporterId CafFob: keep if _n==1


save temp_failures.dta, replace



use temp.dta, clear
drop if strmatch(status,"split_*") | strmatch(status,"ignore_*")

destring(importerId), replace 
destring(exporterId), replace 



bys importerId exporterId CafFob: assert _N==1


append using temp_failures.dta
erase temp_failures.dta

drop newReporters partner_no  importerLabel importerType /*
	*/ exporterLabel exporterType reportedBy partial newPartners originalReportedTradeFlowIds /*
	*/ valueGeneratedBy notes

save temp.dta, replace
}

if year>=1948 {
	use temp.dta, clear
	destring(importerId), replace 
	destring(exporterId), replace 
 	save temp.dta, replace
}
********Création des imputed zeros
use temp.dta, clear
duplicates report importerId exporterId CafFob
if r(unique_values)!=r(N) {
	di as error "Some flows have both missing and existing values. This should not happen. Please check the data `year' `CafFob'."
}

sort importerId exporterId CafFob value
bys importerId exporterId CafFob : keep if _n==1

///Beware. Some reporters are not partners. We must add them to the partner list
save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace
if "`CafFob'"=="fob" {
	keep exporterId
	bys exporterId: keep if _n==1
	rename exporterId importerId
}
if "`CafFob'"=="caf" {
	keep importerId
	bys importerId: keep if _n==1
	rename importerId exporterId
}

append using "results/BestGuessBilTrade_`year'_`CafFob'.dta"
fillin exporterId importerId


replace value  = 0 if _fillin ==1
replace status = "imputed zero" if _fillin ==1
replace CafFob = "`CafFob'" if _fillin ==1
replace year=`year' if _fillin ==1
drop _fillin


drop if importerId==exporterId


bys importerId exporterId CafFob: assert _N==1
save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace

***************Création des flux non rapportés

use "results/BestGuessBilTrade_`year'_`CafFob'.dta", clear
if "`CafFob'"=="fob" {
	keep importerId
	bys importerId: keep if _n==1
	rename importerId exporterId
}
if "`CafFob'"=="caf" {
	keep exporterId
	bys exporterId: keep if _n==1
	rename exporterId importerId
}
append using "results/BestGuessBilTrade_`year'_`CafFob'.dta"
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


bestguessbiltrade 1833 fob
bestguessbiltrade 1833 caf




foreach year of numlist 1834(1)1938  {
	bestguessbiltrade `year' fob
	bestguessbiltrade `year' caf
}

*/

foreach year of numlist 1948(1)2025 {
	bestguessbiltrade `year' fob
}
