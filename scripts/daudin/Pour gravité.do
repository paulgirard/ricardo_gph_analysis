cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"


import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/data/tradeFlows.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

tempfile tradeFlows
save `tradeFlows', replace

reshape long value, i(year status notes importerLabel importerId exporterLabel exporterId   importerType exporterType) j(ExportsImports) string

drop importerType exporterType
drop if value==.
drop if status =="ignore_internal" | status=="ignore_resolved"

gen ln_value=ln(value)

encode importerLabel, gen(importer_lbl)
encode exporterLabel, gen(exporter_lbl)

regress ln_value i.importer_lbl i.exporter_lbl ///
    if ExportsImports=="FromImporter" & year==1833 & status=="ok"

matrix b = e(b)
local cnames : colnames b


////Create coefficient files for importer and exporter

foreach trader in exporter importer  {
	tempfile `trader'_coefs
	capture postclose handle
	postfile handle str200 `trader'_lbl int `trader' double coefficient using ``trader'_coefs', replace
	local i = 1
	foreach var_name of local cnames {
    	if strpos("`var_name'","`trader'_lbl") {
        	local coef = b[1,`i']
			if regexm("`var_name'", "^([0-9]+)") {
    			local code = regexs(1)
			}
			display "`code'"
			label dir
			local lbl :  label `trader'_lbl  `code'
        	post handle ("`lbl'") (`code')  (`coef')
    	}
    	local ++i
	}
	postclose handle

}

foreach trader in exporter importer  {
	use ``trader'_coefs', clear
	list
}
