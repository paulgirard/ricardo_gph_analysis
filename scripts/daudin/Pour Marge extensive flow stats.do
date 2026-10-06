cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

capture program drop stat_flows 
program stat_flows
    args  CafFob

capture erase "results/extensive/stat_`CafFob'.dta"


if "`CafFob'"=="fob" local yearlist "1833(1)1938 1948(1)2025"
if "`CafFob'"=="caf" local yearlist "1833(1)1938"
foreach year of numlist `yearlist' {

    use "results/BestGuessBilTrade_`year'_`CafFob'.dta", clear


    replace status="reported zero" if value==0 & status=="ok"
    replace status="split_failed" if strmatch(status,"*split*") 
    if "`CafFob'"=="fob" levelsof exporterId
    if "`CafFob'"=="caf" levelsof importerId
    generate nbr_actors=r(r)

    ***We have 1 reported zero each in 1926, 27 and 28

    if "`CafFob'"=="fob" levelsof exporterId if status!="not reported"
    if "`CafFob'"=="caf" levelsof importerId if status!="not reported"
    generate nbr_reporters=r(r)

    if "`CafFob'"=="fob" levelsof importerId if status=="ok" | status=="split_failed"
    if "`CafFob'"=="caf" levelsof exporterId if status=="ok" | status=="split_failed"
    gen nbr_partners=r(r)

    preserve
    keep nbr_actors nbr_reporters nbr_partners year CafFob
    keep if _n==1
    save temp.dta, replace
    restore

    contract status
    gen id = 1
    replace status=subinstr(status, " ", "", .)
    rename _freq nbrof_
    reshape wide  nbrof_, i(id) j(status) string
    drop id


    merge 1:1 _n using temp.dta
    drop _merge


    capture 
    capture append using "results/extensive/stat_`CafFob'.dta"
    order year CafFob nbrof* nbr*
    save "results/extensive/stat_`CafFob'.dta", replace
}

export delimited  "results/extensive/stat_`CafFob'.csv", replace

use "results/extensive/stat_`CafFob'.dta", replace





egen total_directed_pairs=rowtotal(nbrof_imputedzero nbrof_notreported nbrof_ok nbrof_split_failed)
gen shareof_ok = nbrof_ok/total_directed_pairs
gen shareof_split_failed = nbrof_split_failed/total_directed_pairs
gen shareof_imputedzero = nbrof_imputedzero/total_directed_pairs
gen shareof_notreported = nbrof_notreported/total_directed_pairs

tsset year
tsfill, full
sort year

twoway ///
    (connected nbr_actors   year, lcolor(navy)   mcolor(navy)   msymbol(O) msize(tiny) cmissing(no) ) ///
    (connected nbr_reporters year, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(tiny)  cmissing(no)) ///
    (connected nbr_partners year, lcolor(forest_green) mcolor(forest_green) msymbol(T) msize(tiny) cmissing(no)) ///
    , ///
    title("Evolution of the number of reporters, partners and actors (`CafFob')") ///
    ytitle("Number") ///
    xtitle("Year") ///
    legend(order(1 "Actors" 2 "Reporters" 3 "Partners")) ///
    yscale(range(0(25)250)) xscale(range(1830(20)2030))

graph export "results/extensive/trade_actors_`CafFob'.png", replace


twoway ///
    (line nbrof_ok  year, lpattern(solid)  lcolor(navy)  cmissing(no) ) ///
    (line nbrof_split_failed year, lpattern(dash) lcolor(cranberry)  cmissing(no)) ///
    (line nbrof_imputedzero year, lpattern(shortdash) lcolor(black)   cmissing(no)) ///
    (line nbrof_notreported year, lpattern(dash_dot) lcolor(forest_green)  cmissing(no)) ///
    , ///
    title("Evolution of the number of flows (`CafFob')") ///
    ytitle("Number") ///
    xtitle("Year") ///
    legend(order(1 "Non-zero trade flows" 2 "Unknown non-zero trade flows" 3 "Imputed zeros" 4 "Not reported") position(6) rows(2)) ///
    yscale(log ) xscale(range(1830(20)2030)) ylabel(1 2 5 10 20 50 100 200 500 1000 2000 5000 10000 20000, format(%12.0gc))

graph export "results/extensive/trade_flows_nbr_`CafFob'.png", replace



twoway ///
    (line shareof_ok  year, lpattern(solid) lcolor(navy)  cmissing(no) ) ///
    (line shareof_split_failed year, lpattern(dash) lcolor(cranberry)  cmissing(no)) ///
    (line shareof_imputedzero year, lpattern(shortdash) lcolor(black)   cmissing(no)) ///
    (line shareof_notreported year, lpattern(dash_dot) lcolor(forest_green)  cmissing(no)) ///
    (connected total_directed_pairs year, lpattern(solid)   msize(tiny) cmissing(no) yaxis(2)) ///
    , ///
    title("Evolution of the share of flows (`CafFob')") ///
    ytitle("Share", axis(1) ) ytitle("Number of potential flows",axis(2) ) ///
    xtitle("Year") ///
    legend(order(1 "Non-zero trade flows" 2 "Unknown non-zero trade flows" 3 "Imputed zeros" 4 "Not reported" 5 "Potential flows"  ) position(6) rows(3)) ///
    yscale(axis(1) log ) xscale(range(1830(20)2030)) ylabel( 0.00005 0.0001 0.0002 0.0005 0.001 0.002 0.005 0.001 0.002 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1,axis(1)  format(%12.0gc)) /// 
    yscale(axis(2) range(0(1000)5000 )) ylabel(0(10000)50000, axis(2) format(%12.0gc))

graph export "results/extensive/trade_flows_share_`CafFob'.png", replace

end

stat_flows caf
stat_flows fob