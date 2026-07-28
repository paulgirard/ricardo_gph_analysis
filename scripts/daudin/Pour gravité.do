*ssc install geodist
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"


************Importation des relations géopolitiques
import delimited "$dirGeoPolHist/data/GeoPolHist_entities_status_over_time.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

replace start_year="1800" if start_year=="?"
destring(start_year), gen(start_year_num)
drop start_year
rename start_year_num start_year

///We keep only dependency relations, excluding those that lead to an aggregation in the network


/////Mieux faire la jointure avec les statuts


keep if GPH_status=="Associated state of" | GPH_status=="Colony of" | GPH_status=="Dependency of" ///
		| GPH_status=="Protectorate of" | GPH_status=="Vassal of"


gen dependency=1

save GeoPolHist_entities_status_over_time_temp.dta, replace


*************Importation des données de localisation

import delimited "$dirGeoPolHist/data/GeoPolHist_entities.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save GeoPolHist_entities_temp.dta, replace

/***************************************************************************************/
*************Importation des flux commerciaux

capture program drop trade_importation
program define trade_importation
	args year

import delimited "data/tradeFlows_`year'_ratios.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear /*
	*/stringcols(13)
***To force newReporters to be a string even in empty



format value* %20.0fc

capture noisily tostring(reportedBy), replace

/* Plus nécessaire avec le nouveau format des données (1 ligne par flux)
keep if year==`year'
tempfile tradeFlows
save `tradeFlows', replace
replace valueFromImporter=valueToSplit if valueFromImporter!=. & valueToSplit!=.
replace valueFromExporter=valueToSplit if valueFromExporter!=. & valueToSplit!=.
drop valueToSplit
 
reshape long value, i(year status notes importerLabel importerId exporterLabel exporterId  splitToGPHCodes importerType exporterType) j(ExportsImports) string
*/
drop importerType exporterType
drop if value==. & status !="to_impute"
drop if status =="ignore_internal" | status=="ignore_resolved"
drop if status=="ignore_duplicate"
drop if status=="split_failed_error"

gen ln_value=ln(value)

encode importerLabel, gen(importer_lbl)
encode exporterLabel, gen(exporter_lbl)

generate CafFob="FromUnknown"
replace CafFob="FromImporter" if reportedBy==importerId 
replace CafFob="FromExporter" if reportedBy==exporterId 
assert CafFob!=""
tab CafFob

/*gen reportedByIX = "I" if reportedBy== importerId | reportedBy== importerLabel
replace reportedByIX = "X" if reportedBy== exporterId | reportedBy== exporterLabel
assert reportedByIX!=""
*/
tab status, missing
count if status !="ok"
gen totreat_flows=r(N)

save tradeFlows_`year'_temp.dta, replace
*'


end
***************Gravity trade estimation program ***************
capture program drop gravity_trade_estimation
program define gravity_trade_estimation
	args year CafFob

use tradeFlows_`year'_temp, clear
*'
keep if status=="ok"
keep if CafFob=="`CafFob'"


*****Calcul de la distance

keep if exporterId!="restOfTheWorld" & importerId!="restOfTheWorld"
destring exporterId importerId, replace

foreach trader in importer exporter {
	rename `trader'Id GPH_code
	merge m:1 GPH_code using GeoPolHist_entities_temp.dta, keep(1 3)
	assert _merge==3
	drop _merge GPH_name continent wikidata wikidata_alt1 wikidata_alt2 wikidata_alt3
	rename GPH_code `trader'Id
	rename lat `trader'_lat
	rename lng `trader'_lng
}

geodist importer_lat importer_lng exporter_lat exporter_lng, gen(distance_km)
gen ln_distance=ln(distance_km)

save tradeFlows_`year'_`CafFob'ok_temp, replace

*****Calcul de le relation géopolitique

use GeoPolHist_entities_status_over_time_temp.dta, clear

keep if start_year<=`year' & end_year>=`year'

keep GPH_code sovereign_GPH_code dependency

////Pour rapports de subordination
save GeoPolHist_dependency_`year'.dta, replace
rename GPH_code importerId
rename sovereign_GPH_code exporterId
save GeoPolHist_dependency_`year'A.dta, replace
rename importerId bibe
rename exporterId importerId
rename bibe exporterId
save GeoPolHist_dependency_`year'B.dta, replace

///Pour présence dans le même empire (ie partage du souverain)
use GeoPolHist_dependency_`year'.dta, clear
rename GPH_code importerId
joinby sovereign_GPH_code using GeoPolHist_dependency_`year'.dta
drop if GPH_code==importerId
drop sovereign_GPH_code
rename dependency common_empire
rename GPH_code exporterId


append using GeoPolHist_dependency_`year'A.dta
append using GeoPolHist_dependency_`year'B.dta


replace common_empire=0 if common_empire==.
replace dependency =0 if dependency ==.


replace common_empire=0 if common_empire==.
replace dependency =0 if dependency ==.
gen empire =1 if common_empire==1 | dependency==1
replace empire=0 if empire==.
collapse (max) common_empire dependency empire, by(importerId exporterId)


gen newimporterId=importerId
gen newexporterId=exporterId
save GeoPolHist_dependency_`year'.dta, replace
erase GeoPolHist_dependency_`year'A.dta
erase GeoPolHist_dependency_`year'B.dta

*******************************************

use tradeFlows_`year'_`CafFob'ok_temp, clear
merge 1:1 importerId exporterId using GeoPolHist_dependency_`year'.dta, keep(1 3)
replace common_empire=0 if common_empire==.
replace dependency=0 if dependency==.
replace empire=0 if empire==.

******

*****Régression de gravité



regress ln_value ln_distance empire i.importerId i.exporterId



matrix b = e(b)
local constant= b[1,1]
local coef_empire= b[1,2]
local coef_distance= b[1,3]
local cnames : colnames b

display "cenames: `cnames'"

////Create coefficient files for importer and exporter

foreach trader in exporter importer  {
	tempfile `trader'_coefs
	capture postclose handle
	postfile handle /*str200 `trader'_part*/ int new`trader'Id double coefficient str15 CafFob using ``trader'_coefs', replace
	*'
	local i = 1
	foreach var_name of local cnames {
    	if strpos("`var_name'","`trader'Id") {
        	local coef = b[1,`i']
			if regexm("`var_name'", "^([0-9]+)") {
    			local code = regexs(1)
			}
			*display "`code'"
			label dir
			*local lbl :  label `trader'Id  `code'
        	post handle /*("`lbl'")*/ (`code')  (`coef') ("`CafFob'")
    	}
    	local ++i
	}
	postclose handle
	*use ``trader'_coefs', clear
	*'
	*list
}

////Exporter les coefficient et les diagnostics de la régression pour chaque année et chaque CafFob

/*
foreach trader in exporter importer  {
	use ``trader'_coefs', clear
	list
}
*/

use tradeFlows_`year'_temp, clear
*****'
tab status, missing
keep if strmatch(status,"split_*") | status==""
drop if strpos(newPartners,"restOfTheWorld")!=0
keep if CafFob=="`CafFob'"

/// New method : we split first Partners and Reporters
split newPartners, parse("|") gen(newPartnerId)
reshape long newPartnerId, i(id CafFob newReporters) j(partner_no)
drop if (newPartnerId=="" & newReporters=="") | (partner_no!=1 & newReporters!="" & newPartners =="") 
destring(newPartnerId), replace

//à faire seulement s’il y a des reporters à splitter
capture assert missing(newReporters)
	if _rc!=0 {
		split newReporters,parse ("|") gen(newReportersId)
		reshape long newReportersId, i(id partner_no CafFob ) j(reporter_no)
		drop if newReportersId=="" & reporter_no !=1
		destring(newReportersId), replace
		
	}

gen newimporterId=newPartnerId if CafFob=="FromExporter"
capture assert missing(newReporters)
if _rc!=0 replace newimporterId=newReportersId if CafFob=="FromImporter"

gen newexporterId=newPartnerId if CafFob=="FromImporter"
capture assert missing(newReporters)
if _rc!=0  replace newexporterId=newReportersId if CafFob=="FromExporter"  


///Putting importer and exporterId to newimporterId and newexporterId if no treatment is necessary.

destring(importerId), replace force
destring(exporterId), replace force
replace newimporterId=importerId if newimporterId==.
replace newexporterId=exporterId if newexporterId==.

destring(newimporterId), replace
destring(newexporterId), replace

merge m:1 newimporterId CafFob using `importer_coefs'
rename coefficient importer_coef
drop _merge
merge m:1 newexporterId CafFob using `exporter_coefs'
rename coefficient exporter_coef
drop _merge

sort originalReportedTradeFlowId
*drop importer_lbl-importer exporter



/*
***On vérifie que par originalReportedTradeFlowId on a bien les coeffcients pour toutes les parties
bysort id: egen ok_exp = min(!missing(exporter_coef))
bysort id: egen ok_imp = min(!missing(importer_coef))

drop if ok_exp==0 | ok_imp==0
drop ok_exp ok_imp

*/

/////intégration de la distance
foreach trader in importer exporter {
	rename new`trader'Id GPH_code
	merge m:1 GPH_code using GeoPolHist_entities_temp.dta, keep(1 3)
	drop if _merge!=3
	drop _merge GPH_name continent wikidata wikidata_alt1 wikidata_alt2 wikidata_alt3
	rename GPH_code new`trader'Id
	rename lat `trader'_lat
	rename lng `trader'_lng
}

geodist importer_lat importer_lng exporter_lat exporter_lng, gen(distance_km)
gen ln_distance=ln(distance_km)


////intégration de la relation géopolitique

merge m:1 newimporterId newexporterId using GeoPolHist_dependency_`year'.dta, keepusing(common_empire dependency empire) keep(1 3)
replace common_empire=0 if common_empire==.
replace dependency=0 if dependency==.
replace empire=0 if empire==.
drop _merge

////estimation of the trade

gen pred=exp(`constant' + `coef_empire'*empire + `coef_distance'*ln_distance + importer_coef + exporter_coef)
sort id
egen sum_pred = total(pred), by(id)
gen pred_trade =  valueToSplit * pred/ sum_pred
format pred_trade %20.0fc

by id: egen success = max(pred_trade), missing

drop pred sum_pred

by id: replace status ="ok thanks to gravity" if success!=.
by id: replace status ="unknown despite gravity" if success==.

//// Some of the failed observations are because the reporter needs to be aggregated and the partner desagregated
////eg in 1833 : Bilbao->Hanover & Hanse Towns


*br if status=="ok thanks to gravity"
drop success
codebook id if status=="ok thanks to gravity"
///Récupération des labels
rename newimporterId GPH_code
merge m:1 GPH_code using GeoPolHist_entities_temp.dta, keep(3)
drop _merge
rename GPH_code newimporterId 
rename GPH_name newimporterLabel

rename newexporterId GPH_code
merge m:1 GPH_code using GeoPolHist_entities_temp.dta, keep(3)
drop _merge
rename GPH_code newexporterId 
rename GPH_name newexporterLabel

keep id year  CafFob newimporterId newexporterId pred_trade valueToSplit importerLabel exporterLabel newimporterLabel newexporterLabel totreat_flows status
order year id importerLabel exporterLabel  CafFob newimporterId newimporterLabel newexporterId newexporterLabel valueToSplit 

save "results/BestGuessBilTrade_`year'_`CafFob'.dta", replace


////exportation des résultats gravity
keep if status=="ok thanks to gravity"
sort id pred_trade newimporterId newexporterId 
format value pred_trade %20.0fc



save "results/gravity_`year'_`CafFob'.dta", replace 

**en 1833, ce qui marche : Brême / Hambourg ; Norway / Sweden ; île Maurince / Réunion ; Chine / Philippine ; Portugal / Spain ; 

end


*****************************************
capture program drop bestguessbiltrade 
program define bestguessbiltrade
	args year

****Maintenant, j’aimerai créer une base du best guess du commerce
use "results/BestGuessBilTrade_`year'_FromExporter.dta", clear
append using "results/BestGuessBilTrade_`year'_FromImporter.dta"

generate value = pred_trade if status=="ok thanks to gravity"
replace importerLabel=newimporterLabel if newimporterLabel!=""
replace exporterLabel=newexporterLabel if newexporterLabel!=""

////eg in 1833 : Bilbao->Hanover & Hanse Towns. I need to agregate by reporter
replace value=. if status=="unknown despite gravity"

bys importerLabel exporterLabel CafFob : gen blif =_N
egen blouf = max(blif), by(importerLabel exporterLabel CafFob)
replace status ="both ok and not ok" if blouf!=1
replace value =. if status=="both ok and not ok"

bys importerLabel exporterLabel CafFob: assert status==status[1]
bys importerLabel exporterLabel CafFob: assert value==value[1]
collapse (first) value status year, by(importerLabel exporterLabel CafFob)

append using "tradeFlows_`year'_FromImporterok_temp.dta"
append using "tradeFlows_`year'_FromExporterok_temp.dta"

//// Some of the flows are both ok and unknown ???
bys importerLabel exporterLabel CafFob : gen blif =_N
egen blouf = max(blif), by(importerLabel exporterLabel CafFob)
replace status ="both ok and not ok" if blouf!=1
replace value =. if status=="both ok and not ok"


bys importerLabel exporterLabel CafFob: assert status==status[1]
bys importerLabel exporterLabel CafFob: assert value==value[1]
collapse (first) value status year, by(importerLabel exporterLabel CafFob)


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

export delimited using "results/BestGuessBilTrade_`year'.csv", replace
erase temp.dta
erase "results/BestGuessBilTrade_`year'_FromImporter.dta"
erase "results/BestGuessBilTrade_`year'_FromExporter.dta"

end

**************************
capture program drop gravity_cleanup
program define gravity_cleanup
	args year

use "results/gravity_`year'_FromImporter.dta", clear
append using "results/gravity_`year'_FromExporter.dta"

gen full_id=id+CafFob

codebook full_id
levelsof full_id
generate treated_flows=r(r)
order year id full_id
export delimited using "results/gravity_`year'.csv", replace 

erase "results/gravity_`year'_FromImporter.dta"
erase "results/gravity_`year'_FromExporter.dta"

erase  tradeFlows_`year'_temp.dta
erase  tradeFlows_`year'_FromImporterok_temp.dta
erase  tradeFlows_`year'_FromExporterok_temp.dta
erase GeoPolHist_dependency_`year'.dta

end


************************


trade_importation 1833
gravity_trade_estimation 1833 FromImporter
gravity_trade_estimation 1833 FromExporter
bestguessbiltrade 1833
gravity_cleanup 1833




foreach year of numlist 1834(1)1938 {
	trade_importation `year'
	gravity_trade_estimation `year' FromImporter
	gravity_trade_estimation `year' FromExporter
	bestguessbiltrade `year'
	gravity_cleanup `year'
	
}

erase GeoPolHist_entities_temp.dta
erase GeoPolHist_entities_status_over_time_temp.dta
