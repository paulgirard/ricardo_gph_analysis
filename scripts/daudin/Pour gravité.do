cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"



capture program drop gravity_trade_estimation
program define gravity_trade_estimation
	args year	

import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/data/tradeFlows.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

format value* %20.0fc


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
regress ln_value i.importer_lbl i.exporter_lbl ///
    if ExportsImports=="FromImporter" & year==`year' & status=="ok"

matrix b = e(b)
local constant= b[1,1]
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


////estimation of the trade

gen pred=exp(`constant' + importer_coef + exporter_coef)
egen sum_pred = total(pred), by(__origid)
gen pred_trade =  value * pred/ sum_pred

by __origid: egen success = max(pred_trade), missing
by __origid: replace status ="ok thanks to gravity" if success!=. & strpos(status,"split")
*br if status=="ok thanks to gravity"
codebook __origid if status=="ok thanks to gravity"
br if status=="ok thanks to gravity"


**en 1833, ce qui marche : Brême / Hambourg ; Norway / Sweden ; île Maurince / Réunion ; Chine / Philippine ; Portugal / Spain ; 
end

gravity_trade_estimation 1870