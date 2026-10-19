cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

capture program drop oneline_diag
program define oneline_diag
args year

use "results/gravity/diag_gravity_`year'.dta", clear

collapse (sum) totvalue nbrflows , by(year status valueGeneratedBy step)



drop if strmatch(status,"ignore*")
gen aggreg_VGB      = valueGeneratedBy
label var aggreg_VGB "aggregated valueGeneratedBy"
**takes care of source, aggregation, imputed zeros***
replace aggreg_VGB  = "split" if valueGeneratedBy=="split_by_years_ratio"
replace aggreg_VGB  = "mixed with gravity" if strmatch(valueGeneratedBy,"*|gravity*")
replace aggreg_VGB  = "mixed without gravity" if strmatch(valueGeneratedBy,"*|*") & strmatch(valueGeneratedBy,"*|gravity*") ==0
replace aggreg_VGB  = "error" if status=="split_failed_error" | status=="pre-gravity_error"
replace aggreg_VGB  = "failed" if status=="failed_gravity" | status=="failed_PG_aggregation"

drop if step=="before gravity" & status=="ok"
drop if (status=="split_failed_no_ratio" | status == "split_only_partial") & step =="before gravity"

***Depending on the order of entities, the value (and nbr of flows--I think) of "failed_PG_aggregation" might be in that category or in failed_split.
***See 1055<-200 (old id : 1048 & 1055 & 1063<-200 and 1055<-200) if 1841 caf



collapse (sum) totvalue nbrflows,by (year aggreg_VGB)




preserve
import delimited "results/gravity/gravity_`year'.csv", delimiter(comma) bindquote(strict) clear
keep exporterid
rename exporterid GPH_code
save list.dta, replace
import delimited "results/gravity/gravity_`year'.csv", delimiter(comma) bindquote(strict) clear
keep importerid
rename importerid GPH_code
append using list.dta
levelsof(GPH_code)
global potential_flows=4*(`r(r)'*(`r(r)'-1))
erase list.dta

restore

gen shareflows=nbrflows/$potential_flows
egen yearly_value = sum(totvalue)
gen share_value=totvalue/yearly_value
drop totvalue nbrflows

replace aggreg_VGB = subinstr(aggreg_VGB, " ", "_", .)
reshape wide share_value shareflows, i(year) j(aggreg_VGB) string
gen potential_flows=$potential_flows

capture append using "results/gravity/diag_gravity.dta"
save "results/gravity/diag_gravity.dta", replace


end


erase  "results/gravity/diag_gravity.dta"

foreach y of numlist 1833(1)1938 1948(1)2025 {
    oneline_diag `y'
}
export delimited "results/gravity/diag_gravity.csv", replace

sort year
tsset year
tsfill, full

twoway (line share_valuesource year if year <=1938, cmissing(n) ) (line share_valueaggregation year if year <=1938 , cmissing(n) ) /*
    */(line share_valueerror year if year <=1938, cmissing(n) ) (line share_valuefailed year if year <=1938, cmissing(n) ) /*
    */(line share_valuemixed_with_gravity year if year <=1938 , cmissing(n) ) (line share_valuegravity year if year <=1938, cmissing(n)  ) /*
    */(line share_valuemixed_without_gravity year if year <=1938 , cmissing(n) ) (line share_valuesplit year if year <=1938 , cmissing(n) ) 


preserve

replace share_valueaggregation=share_valuesource + share_valueaggregation
replace share_valuesplit=share_valueaggregation + share_valuesplit
replace share_valuegravity = share_valuesplit + share_valuegravity 
generate share_valuemixed = share_valuegravity + share_valuemixed_with_gravity + share_valuemixed_without_gravity 

twoway (area share_valuemixed  year , cmissing(n) ) (area share_valuegravity year , cmissing(n) ) /*
*/ (area share_valuesplit year  , cmissing(n) ) (area share_valueaggregation year  , cmissing(n) )/*
*/  (area share_valuesource year , cmissing(n) ) if year <=1938, /*
*/ yscale(range (0.5 1))  ytitle("share of reported value") legend(order(1 "Mixed" 2 "Gravity" 3 "Split" 4 "Aggregation" 5 "Sources") position (6) rows(2)) /*
*/ scheme(s2color)

graph export "results/gravity/trade_share_method.png", replace