cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

use "results/gravity/diag_gravity_1841.dta", clear

collapse (sum) totvalue nbrflows , by(year status valueGeneratedBy step)



drop if strmatch(status,"ignore*")
gen aggreg_VGB      = valueGeneratedBy
**takes care of source, aggregation, imputed zeros***
replace aggreg_VGB  = "split" if valueGeneratedBy=="split_by_years_ratio"
replace aggreg_VGB  = "mixed with gravity" if strmatch(valueGeneratedBy,"*|gravity*")
replace aggreg_VGB  = "mixed without gravity" if strmatch(valueGeneratedBy,"*|*") & strmatch(valueGeneratedBy,"*|gravity*") ==0
replace aggreg_VGB  = "error" if status=="split_failed_error"
replace aggreg_VGB  = "failed" if status=="failed_gravity" | status=="failed_PG_aggregation"

drop if step=="before gravity" & status=="ok"
drop if (status=="split_failed_no_ratio" | status == "split_only_partial") & step =="before gravity"

***Depending on the order of entities, the value (and nbr of flows--I think) of "failed_PG_aggregation" might be in that category or in failed_split.
***See 1055<-200 (old id : 1048 & 1055 & 1063<-200 and 1055<-200) if 1841 caf
