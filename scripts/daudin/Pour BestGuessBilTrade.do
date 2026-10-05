cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

*****************************************
capture program drop bestguessbiltrade 
program define bestguessbiltrade
	args year CafFob

****Maintenant, j’aimerai créer une base du best guess du commerce

import delimited "data/tradeFlows_`year'_gravity.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/ stringcols(13 15)
***To force newReporters and originalReportedTradeFlowIds to be a string even if empty

generate CafFob=""
replace CafFob="caf" if reportedBy==importerId
replace CafFob="fob" if reportedBy==exporterId

keep if CafFob=="`CafFob'"


bys importerLabel exporterLabel CafFob : assert _N==1

drop if status=="ignore_duplicate" | status=="ignore_internal" | status=="ignore_resolved"

capture noisily assert value!=.
if _rc!=0 {
	di as error "Some ok flows have missing value. This should not happen. Please check the data `year'."
}



save temp.dta, replace
********Création des flux connus non mesurés
use temp.dta,clear
tab status, missing
drop valueToSplit valueGeneratedBy
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

destring(newimporterId), replace
destring(newexporterId), replace

sort originalReportedTradeFlowId
*drop importer_lbl-importer exporter


tostring(newimporterId), replace
tostring(newexporterId), replace

drop if newimporterId==newexporterId

capture drop key
gen key = newimporterId + "-" + newexporterId if newimporterId < newexporterId & real(newimporterId)!=. & real(newexporterId)!=.
replace key = newexporterId + "-" + newimporterId if newimporterId > newexporterId & real(newimporterId)!=. & real(newexporterId)!=.
order key

drop if key=="" & id==""

destring(newimporterId), replace
destring(newexporterId), replace

replace importerId =newimporterId if newimporterId!=.
replace exporterId =newexporterId if newexporterId!=.
drop  new*

bys importerLabel exporterLabel CafFob: keep if _n==1


save temp_failures.dta, replace



use temp.dta, clear
drop if strmatch(status,"split_*")

destring(importerId), replace
destring(exporterId), replace

bys importerId exporterId CafFob: assert _N==1


append using temp_failures.dta
erase temp_failures.dta

drop newReporters partner_no  importerLabel importerType /*
	*/ exporterLabel exporterType reportedBy partial newPartners originalReportedTradeFlowIds /*
	*/ valueGeneratedBy notes


********Création des imputed zeros
bys importerId exporterId CafFob: assert _N==1

fillin exporterId importerId
blif

replace value  = 0 if _fillin ==1
replace status = "imputed zero" if _fillin ==1
replace CafFob = "`CafFob'" if _fillin ==1
replace year=`year' if _fillin ==1
drop _fillin


drop if importerId==exporterId


bys importerId exporterId CafFob: assert _N==1

export delimited using "results/BestGuessBilTrade_`year'_`CafFob'.csv", replace quote
erase temp.dta


end


bestguessbiltrade 1833 fob






/*

foreach year of numlist 1834(1)1938 1948(1)2025 {
	bestguessbiltrade `year' fob
}