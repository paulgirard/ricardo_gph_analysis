
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
	
	import delimited "data/tradeFlows_`year'_gravity_`CafFob'.csv", /*
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
	save errors_`CafFob'_`year'.dta, replace
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
end
***************Gravity trade estimation program ***************
capture program drop gravity_trade_estimation
program define gravity_trade_estimation
	args year CafFob

use tradeFlows_`year'_`CafFob'.dta, clear
*'
keep if status=="ok"
append using Imputed_zeros_`CafFob'_`year'.dta
if `year' <=1938 append using Unknown_to_compute_`CafFob'_`year'.dta
assert CafFob=="`CafFob'"




merge m:1 undir_pair_key using "external data/Controls panel/distance.dta", keep(1 3) nogenerate
gen ln_distance=ln(distance_km)
merge m:1 undir_pair_key year using "external data/Controls panel/alliances.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/contiguity.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/disputes.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/commonempire.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/trade_agreements.dta", keep(1 3) nogenerate

destring(mid_n), replace force
replace mid_n=1 if mid_n>=1 & mid_n!=.
replace mid_n=0 if mid_n==.
destring(atop_allie), replace force
replace atop_allie=1 if atop_allie!=.
replace atop_allie=0 if atop_allie==.
replace common_empire=0 if common_empire==.
replace TA="0" if TA=="" | TA=="NA"
destring(TA), replace
generate contig12=0
replace contig12=1 if conttype=="1" | conttype=="2"

codebook value ln_distance contig12 common_empire mid_n atop_allie TA


*****Régression de gravité

destring importerId exporterId, replace


set seed 4563

local liste_var_ex = "$liste_var_ex"
if `year' >=2015 local liste_var_ex = subinstr("`liste_var_ex'","mid_n","",.)
if `year' >=2019 local liste_var_ex = subinstr("`liste_var_ex'","atop_allie","",.)
if `year' >=1914 local liste_var_ex = subinstr("`liste_var_ex'","TA","",.)
if `year' >=2022 local liste_var_ex = subinstr("`liste_var_ex'","common_empire","",.)

ppmlhdfe value `liste_var_ex', absorb(importerId exporterId, savefe)
estimates store full
gen byte in_sample=e(sample)
predict double xb, xb
bysort importerId: egen double fe_imp = max(__hdfe1__)
bysort exporterId: egen double fe_exp = max(__hdfe2__)

gen double pred = exp(xb + fe_imp + fe_exp)

display "`year'"

foreach var_ex in `liste_var_ex' {
	estimates restore full
    local coef = _b[`var_ex']
    local lc=_b[`var_ex']-1.96*_se[`var_ex']
    local uc=_b[`var_ex']+1.96*_se[`var_ex']
    local R2=e(r2_p)
	local ll_full = e(ll)
    local var_ex_minus = subinstr("`liste_var_ex'","`var_ex'","",.)
    ppmlhdfe value `var_ex_minus' if in_sample, absorb(importerId exporterId)
    local add_R2=`R2'-e(r2_p)
	local add_ll = 2*(`ll_full' - e(ll))
	local add_ll_pct = 2*(`ll_full' - e(ll))/`ll_full'
    post reg_result_`var_ex'  ("`CafFob'") (`year') ("`var_ex'") (`coef') (`lc') (`uc') (`add_R2') (`add_ll')
}

tostring importerId exporterId, replace


gen old_id = id
replace id = exporterId + "->" + importerId if CafFob=="fob" 
replace id = importerId + "<-" + exporterId if CafFob=="caf"

sort id
egen sum_pred = total(pred), by(old_id)
gen pred_trade =  valueToSplit * pred/ sum_pred
format pred_trade %20.0fc


bys old_id: egen success = max(pred_trade), missing



replace value=pred_trade if success!=. & strmatch(status,"*split*")==1
replace valueGeneratedBy = valueGeneratedBy +"|" + "gravity" if valueGeneratedBy!="" & success !=. & strmatch(status,"*split*")==1
replace valueGeneratedBy = "gravity" if valueGeneratedBy=="" & success !=. & strmatch(status,"*split*")==1
replace status ="failed_gravity" if success==. & strmatch(status,"*split*")==1 
bys old_id : replace value=valueToSplit if _n==1 & status=="failed_gravity"
**This is useful for diagnostic


replace status ="ok" if success!=. & strmatch(status,"*split*")==1 



drop pred sum_pred






///////////Traitement des flux à agréger post-aggretation

///at that point, we need to put together the flows of imputed thanks to gravity
///if all are succeses : we aggregate them with the sum of flows
///if any is a failure : it is globally a fabilure



sort id notes
by id : egen nbr_of_successes=count(value)
by id : replace status="failed_PG_aggregation" if nbr_of_successes!=_N & _N>1
by id : egen value_cum=total(value)

by id : gen str str_concatn = notes if _n == 1
by id : replace str_concatn = str_concatn[_n-1] + "&" + notes if _n > 1
by id : replace notes = str_concatn[_N] if _N>1


by id : gen str str_concato = originalReportedTradeFlowIds if _n == 1
by id : replace str_concato = str_concato[_n-1] + "&" + originalReportedTradeFlowIds if _n > 1
by id : replace originalReportedTradeFlowIds = str_concato[_N] if _N>1


by id : replace  valueGeneratedBy = valueGeneratedBy +"-----" + "PG-aggregation" if valueGeneratedBy!="" & _n>1
by id : replace  valueGeneratedBy = "PG-aggregation" if  _n>1

by id  : keep if _n==1

replace value=value_cum
replace valueGeneratedBy = "" if status=="failed_PG_aggregation"
replace value =. if status=="failed_PG_aggregation"


replace status ="ok" if strmatch(valueGeneratedBy,"*gravity*") & status==""



drop  value_cum str_concat* nbr_of_successes 


replace originalReportedTradeFlowIds = "none" if valueGeneratedBy=="imputed zero"
replace originalReportedTradeFlowId = id if originalReportedTradeFlowId==""

*******


*assert originalReportedTradeFlowId==id if strmatch(status,"ok")



by id  : assert _N==1


if "`CafFob'"=="fob" {
	*blif
}




drop success

///Récupération des labels
drop importerLabel exporterLabel
rename importerId GPH_code
destring GPH_code, replace
merge m:1 GPH_code using "external data/GeoPolHist_entities.dta", keep(3)
drop _merge
rename GPH_code importerId
tostring importerId, replace 
rename GPH_name importerLabel

rename exporterId GPH_code
destring GPH_code, replace
merge m:1 GPH_code using "external data/GeoPolHist_entities.dta", keep(3)
drop _merge
rename GPH_code exporterId
tostring importerId, replace 
rename GPH_name exporterLabel

keep id year  CafFob importerId exporterId value pred_trade valueToSplit importerLabel exporterLabel status id notes valueGeneratedBy
order year id importerLabel exporterLabel  value pred_trade CafFob importerId  exporterId  valueToSplit id notes valueGeneratedBy



bys importerLabel exporterLabel CafFob : assert _N==1

*save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace


////exportation des résultats gravity
*keep if status=="ok thanks to gravity"
sort id
format value pred_trade %20.0fc


preserve 
gen yearbis=year
collapse  (sum) totvalue=value  (count) nbrflows=yearbis , by(year CafFob status valueGeneratedBy)
generate step = "after gravity"
save "results/gravity/diag_after_gravity_`year'_`CafFob'.dta", replace
restore




save "results/gravity/gravity_`year'_`CafFob'.dta", replace 

**en 1833, ce qui marche : Brême / Hambourg ; Norway / Sweden ; île Maurince / Réunion ; Chine / Philippine ; Portugal / Spain ; 

end



**************************
capture program drop gravity_cleanup
program define gravity_cleanup
	args year

use "results/gravity/gravity_`year'_caf.dta", clear
append using "results/gravity/gravity_`year'_fob.dta"
capture append using "results/gravity/errors_caf_`year'.dta, replace"
capture append using "results/gravity/errors_fob_`year'.dta, replace"

order year id 
export delimited using "results/gravity/gravity_`year'.csv", replace quote

erase "results/gravity/gravity_`year'_caf.dta"
erase "results/gravity/gravity_`year'_fob.dta"

capture erase  tradeFlows_`year'_caf.dta
erase  tradeFlows_`year'_fob.dta
capture erase Unknown_to_compute_caf_`year'.dta
capture erase Unknown_to_compute_fob_`year'.dta
capture erase "Imputed_zeros_caf_`year'.dta"
erase "Imputed_zeros_fob_`year'.dta"


use "results/gravity/diag_before_gravity_`year'_caf.dta", clear
append using "results/gravity/diag_before_gravity_`year'_fob.dta"
append using "results/gravity/diag_after_gravity_`year'_caf.dta"
append using "results/gravity/diag_after_gravity_`year'_fob.dta"
sort step status valueGeneratedBy CafFob
save "results/gravity/diag_gravity_`year'.dta", replace
export delimited using "results/gravity/diag_gravity_`year'.csv", replace quote

erase "results/gravity/diag_before_gravity_`year'_caf.dta"
erase "results/gravity/diag_before_gravity_`year'_fob.dta"
erase "results/gravity/diag_after_gravity_`year'_caf.dta"
erase "results/gravity/diag_after_gravity_`year'_fob.dta"


end


************************
global liste_var_ex TA ln_distance common_empire contig12 mid_n atop_allie 

foreach var_ex of global liste_var_ex {
    capture postclose reg_result_`var_ex'
    postfile reg_result_`var_ex' str10(CafFob) year str40(var) coef ci_low ci_high r2p llp using "results/gravity/regression_results_`var_ex'.dta", replace
    
}




///1841 est la première année avec des rapporteurs à splitter

trade_importation 1841 caf
gravity_trade_estimation 1841 caf

trade_importation 1841 fob
gravity_trade_estimation 1841 fob
gravity_cleanup 1841



trade_importation 1948 caf
gravity_trade_estimation 1948 caf
trade_importation 1948 fob
gravity_trade_estimation 1948 fob

gravity_cleanup 1948




foreach year of numlist 1833(1)1840 1842(1)1938 {
	trade_importation `year' caf
	gravity_trade_estimation `year' caf
	trade_importation `year' fob
	gravity_trade_estimation `year' fob
	gravity_cleanup `year'
	
}


foreach year of numlist 1949(1)2025 {
	trade_importation `year' caf
	gravity_trade_estimation `year' caf
	trade_importation `year' fob
	gravity_trade_estimation `year' fob
	gravity_cleanup `year'
	
}
*/

postutil dir


foreach var_ex of global liste_var_ex {
    postclose reg_result_`var_ex'
}



foreach var_ex of global liste_var_ex {

    use "results/gravity/regression_results_`var_ex'.dta", clear
	sort year CafFob
	save "results/gravity/regression_results_`var_ex'.dta", replace
	
    export delimited using "results/gravity/regression_results_`var_ex'.csv", replace delimiter(",") quote
    replace coef=. if ci_low==.
    *replace ci_high=5 if ci_high>5
    *replace ci_low=5 if ci_low>5
    *replace coef=5 if coef>5

  
    
    foreach CafFob in caf fob {   
    preserve
	keep if CafFob=="`CafFob'"
	
	tsset year
    tsfill, full

    drop if year >= 2026
    twoway (rarea ci_low ci_high year , lcolor(gs8) cmissing(n)) ///
           (connected coef year , mcolor(navy) lcolor(navy) msymbol(circle) cmissing(n)) ///
            (connected r2p year , yaxis(2) cmissing(n)), ///
			xline(1913.5, lpattern(dash) lcolor(blue)) ///
			text(1 1913.5 "end of TA data", place(e) orientation(vertical)) ///
			yline(0, lpattern(dash) lcolor(red)) ///
            xline(2014.5, lpattern(dash) lcolor(blue)) text(1 2014.5 "end of dispute data", place(w) orientation(vertical)) ///
            xline(2018.5, lpattern(dash) lcolor(blue)) text(1 2018.5 "end of alliance data", place(e) orientation(vertical)) ///
            xtitle("Year") ytitle("",axis(1) ) ytitle( "",axis(2)) ///
            xscale(range(1830 1920)) ///
            title(" Regression results `var_ex' (`CafFob')") ///
            legend(order(2 "Coefficient of `var_ex' (left)" 3 "Incremental R{sup:2} (right)") position(6))

    graph export "results/gravity/`var_ex'_`CafFob'.png", replace
	
    restore
    }
}





