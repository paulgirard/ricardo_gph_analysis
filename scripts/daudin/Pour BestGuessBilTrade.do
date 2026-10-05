*****************************************
capture program drop bestguessbiltrade 
program define bestguessbiltrade
	args year

****Maintenant, j’aimerai créer une base du best guess du commerce
use "data/tradeFlows_`year'_gravity.csv", clear

bys importerLabel exporterLabel CafFob : assert _N==1


generate value = pred_trade if status=="ok thanks to gravity"
replace importerLabel=newimporterLabel if newimporterLabel!=""
replace exporterLabel=newexporterLabel if newexporterLabel!=""

replace value=. if status=="unknown despite gravity"

egen max = max(value), by(importerLabel exporterLabel CafFob)
egen min = min(value), by(importerLabel exporterLabel CafFob)
replace status ="both ok and not ok" if max!=min
assert status !="both ok and not ok"

drop max min

/*bys importerLabel exporterLabel CafFob: assert status==status[1]
bys importerLabel exporterLabel CafFob: assert value==value[1]
collapse (first) value status year, by(importerLabel exporterLabel CafFob)
*/
bys importerLabel exporterLabel CafFob : assert _N==1

append using "tradeFlows_`year'_FromImporterok_temp.dta"
append using "tradeFlows_`year'_FromExporterok_temp.dta"


***Some flows are both in the "ok" file and in the gravity file.
***if all are ok : we aggregate them with the sum of flows
***if any is "unknown despite gravity" : all are "unknown despite gravity"
**exemple 1833 : id=="200->3349" & id =="200->Ionian Is. & Morea"
generate good_flow =1 if status=="ok thanks to gravity" | status=="ok"
generate gravity_flow =1 if status=="ok thanks to gravity"
replace good_flow =0 if status=="unknown despite gravity"


bys importerLabel exporterLabel CafFob : egen nbr_of_gravity_flows=total(gravity_flow)
bys importerLabel exporterLabel CafFob : egen nbr_of_good_flows=total(good_flow)
bys importerLabel exporterLabel CafFob: egen at_least_one_good_flow= max(good_flow)
bys importerLabel exporterLabel CafFob :replace status="unknown despite partial gravity success" if nbr_of_good_flows!=_N & at_least_one_good_flow==1
bys importerLabel exporterLabel CafFob :replace status="ok thanks partially to gravity" if nbr_of_gravity_flows<_N & nbr_of_gravity_flows>0  & nbr_of_good_flows==_N
bys importerLabel exporterLabel CafFob : egen value_cum=total(value)
bys importerLabel exporterLabel CafFob : replace value=value_cum if nbr_of_good_flows==_N
bys importerLabel exporterLabel CafFob : replace value=. if nbr_of_good_flows!=_N
bys importerLabel exporterLabel CafFob: gen str_concat = id + "&&" + notes if _n == 1
bys importerLabel exporterLabel CafFob: replace str_concat = str_concat[_n-1] + "|" + id + "&&" + notes if _n > 1
bys importerLabel exporterLabel CafFob: replace notes = str_concat[_N] if _N>1
bys importerLabel exporterLabel CafFob : keep if _n==1


drop value_cum str_concat
bys importerLabel exporterLabel CafFob : assert _N==1



keep year value status importerLabel exporterLabel CafFob

gen str256 importerLabel_256 = substr(importerLabel, 1, 256)
gen str256 exporterLabel_256 = substr(exporterLabel, 1, 256)
drop importerLabel exporterLabel
rename *_256 *

preserve
keep if CafFob=="FromImporter"
fillin importerLabel exporterLabel
replace value  = 0 if _fillin ==1
replace status = "imputed zero" if _fillin ==1
replace CafFob = "FromImporter" if _fillin ==1
replace year=`year' if _fillin ==1
drop _fillin

save temp.dta, replace
restore 
keep if CafFob=="FromExporter"
fillin importerLabel exporterLabel
replace value  = 0 if _fillin ==1
replace status = "imputed zero" if _fillin ==1
replace CafFob = "FromExporter" if _fillin ==1
replace year=`year' if _fillin ==1
drop _fillin

append using temp.dta
drop if importerLabel==exporterLabel


bys importerLabel exporterLabel CafFob: assert _N==1

export delimited using "results/BestGuessBilTrade_`year'.csv", replace quote
erase temp.dta
erase "results/BestGuessBilTrade_`year'_FromImporter.dta"
erase "results/BestGuessBilTrade_`year'_FromExporter.dta"

end


bestguessbiltrade 1833








foreach year of numlist 1834(1)1938 1948(1)2025 {
	bestguessbiltrade `year'	
}