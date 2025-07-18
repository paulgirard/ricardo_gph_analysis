cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

import delimited "data/tradeGraphsStats.csv", clear

tempfile tradeGraphStat
save `tradeGraphStat', replace

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
set more on
list if _merge==2

list if _merge==1
set more off