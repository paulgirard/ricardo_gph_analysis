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
sort year

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


gen ignored_value_ratio = (ignore_internal_value + discard_collision_value)/worldft
label variable ignored_value_ratio "Non-pertinent value (duplicated and internal)"

gen splitfailedparts_ratio = (splitfailedparts_value + totreat_flows)/worldft
label variable splitfailedparts_ratio "Failed splits value"

gen WB_and_failedsplit_ratio = worldbilateral_ratio + splitfailedparts_ratio
label variable WB_and_failedsplit_ratio "Our bilateral trade and failed splits value"

gen our_data_ratio = worldbilateral_ratio + splitfailedparts_ratio + ignored_value_ratio
label variable our_data_ratio "idem, and internal or redundant value"


graph twoway   (connected nbgphautonomouscited year, yaxis(2) msize(vsmall)) ///
    (connected nbreportingft year, yaxis(2) msize(vsmall)) , ///
     yscale(axis(2) range(80 190)) ylabel( 80(20)180, axis(2) angle(horizontal))  scheme(s1color) legend(rows(2))

graph export "figures/FTComparison_nbr_entities.png", replace



graph twoway  ///
    (line ok_value_ratio year, yaxis(1) lpattern(dash)) (line ok_and_aggregatio_ratio year, yaxis(1) lpattern(longdash)) ///
    (line worldbilateral_ratio year, yaxis(1) lwidth(medthick)) ///
    (line WB_and_failedsplit_ratio year, yaxis(1) lpattern(longdash)) (line our_data_ratio year, yaxis(1) lpattern(longdash)), ///
    yscale(axis(1) range(0.4 1.3)) ylabel(0.4(0.2)1.2,axis(1) angle(horizontal)) yline(1,axis(1)) ytitle("Ratio to FT World Trade", axis(1)) ///
    scheme(s1color) legend(rows(5))

graph export "figures/FTComparison_value.png", replace


label variable ok_flows "No treatment needed"
gen ok_and_aggregatio_flows= ok_flows+ aggregation_flows
label variable ok_and_aggregatio_flows "No treatment needed and aggregated"
gen worldbilateral_flows= ok_flows+ aggregation_flows + split_by_mirror_ratio_flows + split_by_years_ratio_flows + split_to_one_flows
label variable worldbilateral_flows "No treatment needed, aggregated and splitted"

gen WB_and_failedsplit_flows = worldbilateral_flows + splitfailedparts_flows + totreat_flows
label variable WB_and_failedsplit_flows "Our bilateral trade and failed splits"

gen our_data_flows = WB_and_failedsplit_flows + ignore_internal_flows
label variable our_data_flows "idem, and internal or redundant"

graph twoway  ///
    (line ok_flows year, yaxis(1) lpattern(dash)) (line ok_and_aggregatio_flows year, lpattern(longdash)) ///
    (line worldbilateral_flows year, yaxis(1) lwidth(medthick)) ///
    (line WB_and_failedsplit_flows year, yaxis(1) lpattern(longdash)) (line our_data_flows year, lpattern(longdash)), ///
    yscale(log) ylabel(,angle(horizontal)) ytitle("Number of flows") ylabel(500 1000 2000(2000)8000) ///
    scheme(s1color) legend(rows(5))

graph export "figures/FTComparison_nbr_flows.png", replace
