cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

capture program drop stat_flows 
program stat_flows
    args 

capture erase "results/extensive/stat.dta"
capture erase temp.dta

local yearlist "1833(1)1938 1948(1)2025"
foreach year of numlist `yearlist' {

    use "results/extensive/BestGuessBilTrade_`year'.dta", clear

    


    replace status="reported zero" if value==0 & status=="ok" & valueGeneratedBy=="source"
    replace status="imputed zero" if valueGeneratedBy=="imputed zero"

    
    
    ******Compute the number of actors
    
    levelsof importerId
    display "Nbr I actors = " `r(r)'
    levelsof exporterId 
    display "Nbr X actors = " `r(r)'
    generate nbr_actors=r(r)
    ***It is a squared matrix, so as many exporters as importers.
    

    ***We have 1 reported zero each in 1926, 27 and 28

    levelsof exporterId if status!="not reported" & CafFob=="fob"
    display "Nbr X reporters = " `r(r)'
    levelsof importerId if status!="not reported" & CafFob=="caf"
    display "Nbr I reporters = " `r(r)'

    preserve
    replace exporterId=. if status=="not reported" | CafFob=="caf"
    replace importerId=. if status=="not reported" | CafFob=="fob"

    stack exporterId importerId, into(countryId) clear
    levelsof countryId
    restore
    display "Nbr reporters = " `r(r)'
    generate nbr_reporters=r(r)


    *****Compute the number of partners

    levelsof exporterId if  status!="not reported" & CafFob=="caf"
    display "Nbr I partners = " `r(r)'
    levelsof importerId if  status!="not reported" & CafFob=="fob"
    display "Nbr X partners = " `r(r)'

    preserve
    replace exporterId=. if status=="not reported" | CafFob=="fob"
    replace importerId=. if status=="not reported" | CafFob=="caf"
    
    stack exporterId importerId, into(countryId) clear
    levelsof countryId
    restore
    display "Nbr partners = " `r(r)'
    generate nbr_partners=r(r)

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
    capture append using "results/extensive/stat.dta"
    order year CafFob nbrof* nbr*
    save "results/extensive/stat.dta", replace
}

export delimited  "results/extensive/stat.csv", replace

use "results/extensive/stat.dta", replace





egen total_directed_pairs=rowtotal(nbrof_imputedzero nbrof_notreported nbrof_ok nbrof_failed_gravity)
gen shareof_ok = nbrof_ok/total_directed_pairs
gen shareof_failed_gravity = nbrof_failed_gravity/total_directed_pairs
gen shareof_imputedzero = nbrof_imputedzero/total_directed_pairs
gen shareof_notreported = nbrof_notreported/total_directed_pairs

tsset year
tsfill, full
sort year

twoway (connected nbr_reporters year, lcolor(cranberry) mcolor(cranberry) msymbol(S) msize(tiny)  cmissing(no)) ///
    (connected nbr_partners year, lcolor(forest_green) mcolor(forest_green) msymbol(T) msize(tiny) cmissing(no)) ///
    , ///
    title("Evolution of the number of reporters and partners") ///
    ytitle("Number") ///
    xtitle("Year") ///
    legend(order(/*1 "Actors"*/ 1 "Reporters" 2 "Partners") position(6) rows(1)) ///
    yscale(range(0(25)250)) xscale(range(1830(20)2030)) xlabel(1830(20)2030)

graph export "results/extensive/trade_actors.png", replace


twoway ///
    (line nbrof_ok  year, lpattern(solid)  lcolor(navy)  cmissing(no) ) ///
    (line nbrof_failed_gravity year, lpattern(dash) lcolor(cranberry)  cmissing(no)) ///
    (line nbrof_imputedzero year, lpattern(shortdash) lcolor(black)   cmissing(no)) ///
    (line nbrof_notreported year, lpattern(dash_dot) lcolor(forest_green)  cmissing(no)) ///
    , ///
    title("Evolution of the number of flows") ///
    ytitle("Number") ///
    xtitle("Year") ///
    legend(order(1 "Non-zero trade flows" 2 "Unknown non-zero trade flows" 3 "Imputed zeros" 4 "Not reported") position(6) rows(2)) ///
    yscale(log ) xscale(range(1830(20)2030)) xlabel(1830(20)2030) ylabel(500 1000 2000 5000 10000 20000 50000, format(%12.0gc))

graph export "results/extensive/trade_flows_nbr.png", replace



twoway ///
    (line shareof_ok  year, lpattern(solid) lcolor(navy)  cmissing(no) ) ///
    (line shareof_failed_gravity year, lpattern(dash) lcolor(cranberry)  cmissing(no)) ///
    (line shareof_imputedzero year, lpattern(shortdash) lcolor(black)   cmissing(no)) ///
    (line shareof_notreported year, lpattern(dash_dot) lcolor(forest_green)  cmissing(no)) ///
    (connected total_directed_pairs year, lpattern(solid)   msize(tiny) cmissing(no) yaxis(2)) ///
    , ///
    title("Evolution of the share of flows") ///
    ytitle("Share", axis(1) ) ytitle("Number of potential flows",axis(2) ) ///
    xtitle("Year") ///
    legend(order(1 "Non-zero trade flows" 2 "Unknown non-zero trade flows" 3 "Imputed zeros" 4 "Not reported" 5 "Potential flows"  ) position(6) rows(3)) ///
    yscale(axis(1) log ) xscale(range(1830(20)2030)) xlabel(1830(20)2030) ylabel( 0.005 0.01 0.02 0.05 0.1 0.2 0.5 1,axis(1)  format(%12.0gc)) /// 
    yscale(axis(2) range(0 100000 )) ylabel(0(20000)100000, axis(2) format(%12.0gc))

graph export "results/extensive/trade_flows_share.png", replace

end

stat_flows caf
stat_flows fob