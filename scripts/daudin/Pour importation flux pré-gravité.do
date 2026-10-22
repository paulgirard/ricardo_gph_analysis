
*ssc install ppmlhdfe, replace
*ssc install ftools, replace
*ssc install reghdfe, replace
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"



/***************************************************************************************/
*************Importation des flux commerciaux

capture program drop trade_importation
program define trade_importation
	args year CafFob

*local year 1841
if `year' <=1938 import delimited "data/tradeFlows_`year'_ratios.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/stringcols(13 15)
***To force newReporters and originalReportedTradeFlowIds to be a string even if empty

if `year' >=1948 {
	
	import delimited "external data/DoT Direction of Trade (IMF)/tradeFlows_`year'_gravity_`CafFob'.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/stringcols(3 6 13 15)

	destring valueToSplit, replace force
	gen valueGeneratedBy =""
	capture tostring importerId, replace
	capture tostring exporterId, replace
}
	

replace valueGeneratedBy="source" if status=="ok" & valueGeneratedBy==""

recast str2045 importerId, force
recast str2045 exporterId, force

format value valueToSplit %20.0fc

replace valueToSplit=value if (status =="split_failed_no_ratio") & valueToSplit==. 




capture noisily tostring(reportedBy), replace


drop importerType exporterType

gen ln_value=ln(value)

encode importerLabel, gen(importer_lbl)
encode exporterLabel, gen(exporter_lbl)

generate CafFob=""
replace CafFob="caf" if reportedBy==importerId 
replace CafFob="fob" if reportedBy==exporterId 
assert CafFob!=""
tab CafFob
keep if CafFob=="`CafFob'"

bys exporterId importerId CafFob : assert _N==1

****Flag d’erreurs précédentes
replace status = "pre-gravity_error" if (status =="split_failed_no_ratio" | status =="split_only_partial") & (newReporters=="" & newPartners =="")

/*gen reportedByIX = "I" if reportedBy== importerId | reportedBy== importerLabel
replace reportedByIX = "X" if reportedBy== exporterId | reportedBy== exporterLabel
assert reportedByIX!=""
*/
tab status, missing

preserve 
collapse  (sum) totvalue=value  (count) nbrflows=value , by(year CafFob status valueGeneratedBy)
generate step = "before gravity"
save "results/gravity/diag_before_gravity_`year'_`CafFob'.dta", replace
restore



///Création de la clef pour les paires de GPH
gen undir_pair_key = importerId + "-" + exporterId if importerId < exporterId & real(importerId)!=. & real(exporterId)!=.
replace undir_pair_key = exporterId + "-" + importerId if importerId > exporterId & real(importerId)!=. & real(exporterId)!=.
order undir_pair_key

save tradeFlows_`year'_`CafFob'.dta, replace
assert CafFob=="`CafFob'"
*******Création des erreurs (pas les ignores)
use tradeFlows_`year'_`CafFob'.dta, clear
if `year' <=1938 {

	keep if strmatch(status,"*error*") == 1
	save "results/gravity/errors_`CafFob'_`year'.dta", replace
}



*****
/////Création des flux à mesurer inconnus
use tradeFlows_`year'_`CafFob'.dta, clear
if `year' <=1938 {




tab status, missing

keep if strmatch(status,"split_*")!=0 & strmatch(status,"split_failed_error")==0
drop if strpos(newPartners,"restOfTheWorld")!=0
keep if CafFob=="`CafFob'"
drop value


split newPartners, parse("|") gen(newPartnerId)
egen nbr_new_partners=rownonmiss(newPartnerId*), strok
replace nbr_new_partners = 1 if  nbr_new_partners==0
reshape long newPartnerId, i(id CafFob newReporters nbr_new_partners) j(partner_no)
drop if partner_no>nbr_new_partners
destring(newPartnerId), replace

gen newimporterId=.
gen newexporterId=.
replace newimporterId=newPartnerId if CafFob=="fob"
replace newexporterId=newPartnerId if CafFob=="caf"


//à faire seulement s’il y a des reporters à splitter
capture assert missing(newReporters)
	if _rc!=0 {
		split newReporters,parse ("|") gen(newReportersId)
		egen nbr_new_reporters=rownonmiss(newReportersId*), strok
		replace nbr_new_reporters = 1 if  nbr_new_reporters==0
		reshape long newReportersId, i(id newPartnerId CafFob nbr_new_reporters) j(reporter_no)
		drop if reporter_no>nbr_new_reporters
		destring(newReportersId), replace
		replace newexporterId=newReportersId if CafFob=="fob"
		replace newimporterId=newReportersId if CafFob=="caf"	
	}

tostring(newimporterId), replace
tostring(newexporterId), replace

assert strofreal(real(newimporterId))==newimporterId
assert strofreal(real(newexporterId))==newexporterId


drop importerLabel exporterLabel importer_lbl exporter_lbl




replace importerId = newimporterId if  newimporterId !="."
replace exporterId = newexporterId if  newexporterId !="."




assert strofreal(real(importerId))==importerId
assert strofreal(real(exporterId))==exporterId



drop newimporterId newexporterId newPartnerId newPartners 
capture drop newReportersId newReporters

drop undir_pair_key
gen undir_pair_key = importerId + "-" + exporterId if importerId < exporterId & real(importerId)!=. & real(exporterId)!=.
replace undir_pair_key = exporterId + "-" + importerId if importerId > exporterId & real(importerId)!=. & real(exporterId)!=.
order undir_pair_key

drop if undir_pair_key=="" & id==""

save Unknown_to_compute_`CafFob'_`year'.dta, replace

assert CafFob=="`CafFob'"

}
//////////





///Création des flux nuls imputés
********Création des imputed zeros

use tradeFlows_`year'_`CafFob'.dta, clear
keep if status=="ok"


if `year' <=1938 append using Unknown_to_compute_`CafFob'_`year'.dta

duplicates report importerId exporterId CafFob

if r(unique_values)!=r(N) {
	di as error "Some flows have both missing and existing values. `year' `CafFob'."
}

***In 1833 caf that happens because we have two flows : 300<-200 ; 300<-Gibraltar & Malta & United Kingdom. Both are legit and should b kept

sort importerId exporterId CafFob value
bys importerId exporterId CafFob : keep if _n==1

///Beware. Some reporters are not partners. We must add them to the partner list
save "Imputed_zeros_`CafFob'_`year'.dta", replace
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

append using "Imputed_zeros_`CafFob'_`year'.dta"


fillin exporterId importerId
drop if exporterId=="" | importerId==""
drop if importerId==exporterId

replace value  = 0 if _fillin ==1
replace valueGeneratedBy = "imputed zero" if _fillin ==1
replace status="ok" if _fillin==1
replace CafFob = "`CafFob'" if _fillin ==1
replace year=`year' if _fillin ==1
keep if _fillin==1
drop _fillin

bys importerId exporterId CafFob: assert _N==1




drop undir_pair_key
gen undir_pair_key = importerId + "-" + exporterId if importerId < exporterId & real(importerId)!=. & real(exporterId)!=.
replace undir_pair_key = exporterId + "-" + importerId if importerId > exporterId & real(importerId)!=. & real(exporterId)!=.
order undir_pair_key

save "Imputed_zeros_`CafFob'_`year'.dta", replace
assert CafFob=="`CafFob'"

use tradeFlows_`year'_`CafFob'.dta, clear

keep if status=="ok"
append using Imputed_zeros_`CafFob'_`year'.dta
if `year' <=1938 append using Unknown_to_compute_`CafFob'_`year'.dta
assert CafFob=="`CafFob'"

save "data/trade_flows_before_gravity_`CafFob'_`year'.dta", replace
export delimited "data/trade_flows_before_gravity_`CafFob'_`year'.csv", replace

end



///1841 est la première année avec des rapporteurs à splitter

trade_importation 1841 caf


trade_importation 1841 fob


trade_importation 1948 caf

trade_importation 1948 fob





foreach year of numlist 1833(1)1840 1842(1)1938 {
	trade_importation `year' caf

	trade_importation `year' fob


	
}


foreach year of numlist 1949(1)2025 {
	trade_importation `year' caf

	trade_importation `year' fob


	
}
*/

