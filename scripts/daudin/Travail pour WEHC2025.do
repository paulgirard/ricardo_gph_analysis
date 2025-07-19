cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

/*
unzipfile "data/RICardo_trade_flows_deduplicated.csv.zip", replace
import delimited "RICardo_trade_flows_deduplicated.csv", clear
erase "RICardo_trade_flows_deduplicated.csv"
tempfile RICardo
save `RICardo', replace
save RICardo.dta, replace
*/

use RICardo.dta, clear
tempfile RICardo
save `RICardo', replace


codebook reporting partner
**443 reporting, 2069 partners

collapse (count) flow, by(reporting)
rename flow nbr_flows_reporting
keep reporting nbr_flows_reporting
gen strlen = length(reporting)
summarize strlen, meanonly
generate str`r(max)' blif=reporting
rename blif RIC_entity
keep RIC_entity nbr_flows_reporting
tempfile reporting
save `reporting', replace

use `RICardo', clear
collapse (count) flow, by(partner)
rename flow nbr_flows_partner
keep partner nbr_flows_partner
gen strlen = length(partner)
summarize strlen, meanonly
generate str`r(max)' blif=partner
rename blif RIC_entity
keep RIC_entity nbr_flows_partner

merge 1:1 RIC_entity using `reporting'
**104 reporters are not partners
gsort- _merge -nbr_flows_reporting -nbr_flows_partner
*set more on
list if _merge==2
list if _merge==1
set more off




*************

import delimited "data/tradeGraphsStats.csv", clear delimiters (",") varnames(1)

tempfile tradeGraphStat
save `tradeGraphStat', replace

graph twoway (connected nbgphautonomouscited year, yaxis(1) ) (connected nbreportingft year, yaxis(1))

label variable nbgphautonomouscited "Number of trading entities"
label variable nbreportingft "Number of trading entities in FT"

gen ok_value_ratio = ok_value/worldft
label variable ok_value_ratio "No treatment needed total value"


gen worldbilateral_ratio = worldbilateral/worldft
label variable worldbilateral_ratio "No treatment needed, aggregated and splitted total value"

gen aggregation_value_ratio = aggregation_value/worldft
gen ok_and_aggregatio_ratio= ok_value_ratio+ aggregation_value_ratio
label variable ok_and_aggregatio_ratio "No treatment needed and aggregated total value"


graph twoway (connected nbgphautonomouscited year, yaxis(2) msize(vsmall)) (connected nbreportingft year, yaxis(2) msize(vsmall))   ///
(line ok_value_ratio year, yaxis(1) lpattern(dash)) (line ok_and_aggregatio_ratio year, yaxis(1) lpattern(longdash)) ///
 (line worldbilateral_ratio year, yaxis(1) lwidth(medthick)) ///
 , ///
  yscale(axis(2) range(80 190)) ylabel( 80(20)180, axis(2) angle(horizontal)) ///
  yscale(axis(1) range(0.4 1.3)) ylabel(0.4(0.2)1.2,axis(1) angle(horizontal)) yline(1,axis(1)) ytitle("Ratio to FT World Trade", axis(1)) ///
  scheme(s1color) legend(rows(5))

  graph export "figures/FTComparison.png", replace