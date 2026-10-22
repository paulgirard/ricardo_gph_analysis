
*ssc install ppmlhdfe, replace
*ssc install ftools, replace
*ssc install reghdfe, replace
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"



***************Gravity trade estimation program ***************
capture program drop gravity_trade_estimation
program define gravity_trade_estimation
	args year CafFob

use "data/trade_flows_before_gravity_`CafFob'_`year'.dta", clear

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
if year <=1940 {
    predict double xb, xb
    bysort importerId: egen double fe_imp = max(__hdfe1__)
    bysort exporterId: egen double fe_exp = max(__hdfe2__)

    gen double pred = exp(xb + fe_imp + fe_exp)
}   
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

if year <=1940 {
sort id
egen sum_pred = total(pred), by(old_id)
gen pred_trade =  valueToSplit * pred/ sum_pred
format pred_trade %20.0fc


bys old_id: egen success = max(pred_trade), missing



replace value=pred_trade if success!=. & strmatch(status,"*split*")==1
replace valueGeneratedBy = valueGeneratedBy +"|" + "gravity" if valueGeneratedBy!="" & success !=. & strmatch(status,"*split*")==1
replace valueGeneratedBy = "gravity" if valueGeneratedBy=="" & success !=. & strmatch(status,"*split*")==1
replace status ="failed_gravity" if success==. & strmatch(status,"*split*")==1 
sort old_id id
by old_id : replace value=valueToSplit if _n==1 & status=="failed_gravity"
**This is useful for diagnostic


replace status ="ok" if success!=. & strmatch(status,"*split*")==1 



drop pred sum_pred






///////////Traitement des flux à agréger post-aggretation

///at that point, we need to put together the flows of imputed thanks to gravity
///if all are succeses : we aggregate them with the sum of flows
///if any is a failure : it is globally a fabilure



sort id old_id notes
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

sort id old_id notes

by id  : assert _N==1


if "`CafFob'"=="fob" {
	*blif
}



sort id old_id notes
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

sort id old_id notes

keep id year  CafFob importerId exporterId value importerLabel exporterLabel status  old_id notes valueGeneratedBy
order year id importerLabel exporterLabel  value  CafFob importerId  exporterId  old_id notes valueGeneratedBy



bys importerLabel exporterLabel CafFob : assert _N==1

*save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace


////exportation des résultats gravity
*keep if status=="ok thanks to gravity"
sort id old_id notes

}

if year >= 1945 sort id 
format value  %30.0fc



save "results/gravity/gravity_`year'_`CafFob'.dta", replace 

end

capture program drop diag
program define diag
    args year

    foreach CafFob in caf fob {

    use  "results/gravity/gravity_`year'_`CafFob'.dta", clear
    gen yearbis=year
    replace value=round(value)
    collapse  (sum) totvalue=value  (count) nbrflows=yearbis , by(year CafFob status valueGeneratedBy)
    format totvalue %30.0fc
    generate step = "after gravity"
    save "results/gravity/diag_after_gravity_`year'_`CafFob'.dta", replace
    }

use "results/gravity/diag_before_gravity_`year'.dta", clear
append using "results/gravity/diag_after_gravity_`year'_caf.dta"
append using "results/gravity/diag_after_gravity_`year'_fob.dta"
sort step status valueGeneratedBy CafFob
save "results/gravity/diag_gravity_`year'.dta", replace
format totvalue %30.0fc
export delimited using "results/gravity/diag_gravity_`year'.csv", replace quote

**en 1833, ce qui marche : Brême / Hambourg ; Norway / Sweden ; île Maurince / Réunion ; Chine / Philippine ; Portugal / Spain ; 

end



**************************
capture program drop gravity_cleanup
program define gravity_cleanup
	args year

use "results/gravity/gravity_`year'_caf.dta", clear
append using "results/gravity/gravity_`year'_fob.dta"
if `year' <=1938 {
    capture append using "results/gravity/errors_caf_`year'.dta"
    capture append using "results/gravity/errors_fob_`year'.dta"
    capture erase "results/gravity/errors_caf_`year'.dta"
    capture erase "results/gravity/errors_fob_`year'.dta"
}
order year id 
export delimited using "results/gravity/gravity_`year'.csv", replace quote

erase "results/gravity/gravity_`year'_caf.dta"
erase "results/gravity/gravity_`year'_fob.dta"






erase "results/gravity/diag_after_gravity_`year'_caf.dta"
erase "results/gravity/diag_after_gravity_`year'_fob.dta"
erase "results/gravity/diag_before_gravity_`year'.dta"


end


************************
global liste_var_ex TA ln_distance common_empire contig12 mid_n atop_allie 

foreach var_ex of global liste_var_ex {
    capture postclose reg_result_`var_ex'
    postfile reg_result_`var_ex' str10(CafFob) year str40(var) coef ci_low ci_high r2p llp using "results/gravity/regression_results_`var_ex'.dta", replace
    
}




///1841 est la première année avec des rapporteurs à splitter


gravity_trade_estimation 1841 caf
gravity_trade_estimation 1841 fob
diag 1841


gravity_trade_estimation 1948 caf
gravity_trade_estimation 1948 fob
diag 1948




foreach year of numlist 1833(1)1840 1842(1)1938 1949(1)2025 {
	gravity_trade_estimation `year' caf
	gravity_trade_estimation `year' fob
    diag `year'
	
}






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


blif


foreach year of numlist 1833(1)1938 1948(1)2025 {
    gravity_cleanup `year'
}



