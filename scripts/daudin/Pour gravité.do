ssc install geodist
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"





***************Gravity trade estimation program ***************
capture program drop gravity_trade_estimation
program define gravity_trade_estimation
	args year


*************Importation des données de localisation

import delimited "/Users/guillaumedaudin/Répertoires Git/GeoPolHist/data/GeoPolHist_entities.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

tempfile GeoPolHist_entities
save `GeoPolHist_entities', replace

*************Importation des flux commerciaux

import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/data/tradeFlows.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

format value* %20.0fc
blif

keep if year==`year'
tempfile tradeFlows
save `tradeFlows', replace

reshape long value, i(year status notes importerLabel importerId exporterLabel exporterId   importerType exporterType) j(ExportsImports) string

drop importerType exporterType
drop if value==.
drop if status =="ignore_internal" | status=="ignore_resolved"

gen ln_value=ln(value)

encode importerLabel, gen(importer_lbl)
encode exporterLabel, gen(exporter_lbl)

tempfile tradeFlows_`year'
save `tradeFlows_`year'', replace


keep if status=="ok"
keep if exporterId!="restOfTheWorld" & importerId!="restOfTheWorld"

*****Calcul de la distance

destring exporterId importerId, replace

foreach trader in importer exporter {
	rename `trader'Id GPH_code
	merge m:1 GPH_code using `GeoPolHist_entities', keep(1 3)
	assert _merge==3
	drop _merge GPH_name continent wikidata wikidata_alt1 wikidata_alt2 wikidata_alt3
	rename GPH_code `trader'Id
	rename lat `trader'_lat
	rename lng `trader'_lng
}

geodist importer_lat importer_lng exporter_lat exporter_lng, gen(distance_km)
gen ln_distance=ln(distance_km)

*****Régression de gravité

regress ln_value ln_distance i.importer_lbl i.exporter_lbl ///
    if ExportsImports=="FromImporter" & year==`year' & status=="ok"

matrix b = e(b)
local constant= b[1,1]
local coef_distance= b[1,2]
local cnames : colnames b


////Create coefficient files for importer and exporter

foreach trader in exporter importer  {
	tempfile `trader'_coefs
	capture postclose handle
	postfile handle str200 `trader'_part int `trader' double coefficient using ``trader'_coefs', replace
	local i = 1
	foreach var_name of local cnames {
    	if strpos("`var_name'","`trader'_lbl") {
        	local coef = b[1,`i']
			if regexm("`var_name'", "^([0-9]+)") {
    			local code = regexs(1)
			}
			*display "`code'"
			*label dir
			local lbl :  label `trader'_lbl  `code'
        	post handle ("`lbl'") (`code')  (`coef')
    	}
    	local ++i
	}
	postclose handle

}
/*
foreach trader in exporter importer  {
	use ``trader'_coefs', clear
	list
}
*/

use `tradeFlows_`year'', clear

*****"
//////All observations that include split in the status variable to be duplicated 
/////for each term between "&" in the importer or exporter variable
* --- expand observations with status containing "split" into parts between & ---
gen long __origid = _n
// split importer into parts (creates importerLabel1 importerLabel2 ...)
split importerLabel, parse(" & ") gen(importer_part)

// reshape long on importer parts (keeps all other vars)
reshape long importer_part, i(__origid) j(ipno) string
drop if missing(importer_part)

// split exporter into parts (creates exporterLabel1 exporterLabel2 ...)
split exporterLabel, parse(" & ") gen(exporter_part)

// reshape long on exporter parts: include ipno so reshape produces cross-product
reshape long exporter_part, i(__origid ipno) j(epno) string
drop if missing(exporter_part)

// replace original label vars with the part values
replace importerLabel = importer_part
replace exporterLabel = exporter_part


///Souci : les groupes ne sont pas réduits à des composants GPH** (ex : flux UK-Barbary Coast en 1833)

merge m:1 importer_part using `importer_coefs'
rename coefficient importer_coef
drop _merge
merge m:1 exporter_part using `exporter_coefs'
rename coefficient exporter_coef
drop _merge
sort __origid

***On vériefie que par __origid on a bien les coeffcients pour toutes les parties
bysort __origid: egen ok_exp = min(!missing(exporter_coef))
bysort __origid: egen ok_imp = min(!missing(importer_coef))
drop if ok_exp==0 | ok_imp==0
drop ok_exp ok_imp


/////intégration de la distance


foreach trader in importer exporter {
	rename `trader'_part GPH_name
	merge m:1 GPH_name using `GeoPolHist_entities', keep(1 3)
	drop if _merge!=3
	drop _merge GPH_code continent wikidata wikidata_alt1 wikidata_alt2 wikidata_alt3
	rename GPH_name `trader'_part
	rename lat `trader'_lat
	rename lng `trader'_lng
}

geodist importer_lat importer_lng exporter_lat exporter_lng, gen(distance_km)
gen ln_distance=ln(distance_km)

////estimation of the trade

gen pred=exp(`constant' + `coef_distance'*ln_distance + importer_coef + exporter_coef)
sort __origid
egen sum_pred = total(pred), by(__origid)
gen pred_trade =  value * pred/ sum_pred

by __origid: egen success = max(pred_trade), missing
by __origid: replace status ="ok thanks to gravity" if success!=. & strpos(status,"split")
*br if status=="ok thanks to gravity"
codebook __origid if status=="ok thanks to gravity"

////exportation des résultats
keep if status=="ok thanks to gravity"
export delimited using "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/results/gravity_`year'.csv", replace

**en 1833, ce qui marche : Brême / Hambourg ; Norway / Sweden ; île Maurince / Réunion ; Chine / Philippine ; Portugal / Spain ; 
end
foreach year of numlist 1833(1)1938 {
	gravity_trade_estimation `year'
}