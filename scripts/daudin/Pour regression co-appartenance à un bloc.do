*ssc install geodist
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"

global liste_var_ex TA ln_distance common_empire contig12 mid_n atop_allie 
global liste_network Tibi LouvainMaxtrade LouvainTibirescale IntraMax AN



capture program drop bloc_regression_prepar
    program define bloc_regression_prepar
        args year

    use "results/communities/intra_bloc_pairs_`year'.dta", clear


merge m:1 undir_pair_key using "external data/Controls panel/distance.dta", keep(1 3) nogenerate
gen ln_distance=ln(distance_km)
merge m:1 undir_pair_key year using "external data/Controls panel/alliances.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/contiguity.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/disputes.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/commonempire.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/trade_agreements.dta", keep(1 3) nogenerate


***Dans tous ces cas, je considère les manquants comme nul. Peut-être pas malin.
destring(mid_n), replace force
replace mid_n=1 if mid_n>=1 & mid_n!=.
replace mid_n=0 if mid_n==.
destring(atop_allie), replace force
replace atop_allie=1 if atop_allie!=.
replace atop_allie=0 if atop_allie==.
replace common_empire=0 if common_empire==.
replace TA="0" if TA=="" | TA=="NA"
destring(TA), replace
generate contig12=0
replace contig12=1 if conttype=="1" | conttype=="2"

save temp.dta, replace

end






capture program drop bloc_regression
program define bloc_regression
    args year NetworkType

use temp.dta, clear

set seed 4563

local liste_var_ex = "$liste_var_ex"
if `year' >=2015 local liste_var_ex = subinstr("`liste_var_ex'","mid_n","",.)
if `year' >=2019 local liste_var_ex = subinstr("`liste_var_ex'","atop_allie","",.)
if `year' >=1914 local liste_var_ex = subinstr("`liste_var_ex'","TA","",.)
if `year' >=2022 local liste_var_ex = subinstr("`liste_var_ex'","common_empire","",.)



logistic IntraBloc_`NetworkType' `liste_var_ex', robust /*, vce(cluster source)*/
estimates store full
gen byte in_sample=e(sample)

display "`year'"

foreach var_ex in `liste_var_ex' {
    estimates restore full
    local coef = _b[`var_ex']
    local lc=_b[`var_ex']-1.96*_se[`var_ex']
    local uc=_b[`var_ex']+1.96*_se[`var_ex']
    local R2=e(r2_p)
    local ll_full = e(ll)
    local var_ex_minus = subinstr("`liste_var_ex'","`var_ex'","",.)
    logistic IntraBloc_`NetworkType' `var_ex_minus', robust /*vce(cluster source)*/
    local add_R2=`R2'-e(r2_p)
    local add_ll = 2*(`ll_full' - e(ll))
	local add_ll_pct = 2*(`ll_full' - e(ll))/`ll_full'
    post reg_result_`var_ex' ("`NetworkType'") (`year') ("`var_ex'") (`coef') (`lc') (`uc') (`add_R2') (`add_ll')
}

end

*********************************************************************



foreach var_ex of global liste_var_ex {
    capture postclose reg_result_`var_ex'
    postfile reg_result_`var_ex' str40(NetworkType) year str40(var) coef ci_low ci_high r2p llp using "results/bloc_study/shared_bloc_reg_`var_ex'.dta", replace
    
}


foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2025 {
    bloc_regression_prepar `year'
    foreach network of global liste_network {
        bloc_regression `year' `network'
    }
}


foreach var_ex of global liste_var_ex {
    postclose reg_result_`var_ex'
}



foreach var_ex of global liste_var_ex {

    use "results/bloc_study/shared_bloc_reg_`var_ex'.dta", clear
    export delimited using "results/bloc_study/shared_bloc_reg_`var_ex'.csv", replace delimiter(",") quote
    replace coef=exp(coef)
    replace ci_low=exp(ci_low)
    replace ci_high=exp(ci_high)
    replace coef=. if ci_low==.
    replace ci_high=5 if ci_high>5
    replace ci_low=5 if ci_low>5
    replace coef=5 if coef>5

* Okabe-Ito colorblind-safe palette (same as your previous graph)
local c_tibi   "213 94 0"
local c_louv   "230 159 0"
local c_louvr  "204 121 167"
local c_imax   "0 114 178"
local c_an     "0 0 0"

* Vertical position for the annotation text
quietly summ coef if year <= 2025
local ymid = (r(max) + r(min)) / 2

twoway ///
    (connected coef year if NetworkType=="Tibi"               & year<=2025, cmissing(n) ///
        lcolor("`c_tibi'")  mcolor("`c_tibi'")  msymbol(circle)   msize(small) lwidth(medthick) lpattern(dash)) ///
    (connected coef year if NetworkType=="LouvainMaxtrade"    & year<=2025, cmissing(n) ///
        lcolor("`c_louv'")  mcolor("`c_louv'")  msymbol(diamond)  msize(small) lwidth(medthick) lpattern(dash_dot)) ///
    (connected coef year if NetworkType=="LouvainTibirescale" & year<=2025, cmissing(n) ///
        lcolor("`c_louvr'") mcolor("`c_louvr'") msymbol(triangle) msize(small) lwidth(medthick)) ///
    (connected coef year if NetworkType=="IntraMax"           & year<=2025, cmissing(n) ///
        lcolor("`c_imax'")  mcolor("`c_imax'")  msymbol(square)   msize(small) lwidth(medthick)) ///
    (connected coef year if NetworkType=="AN"                 & year<=2025, cmissing(n) ///
        lcolor("`c_an'")    mcolor("`c_an'")    msymbol(X)        msize(small) lwidth(medthick)), ///
    yline(1, lpattern(shortdash) lcolor(gs8) lwidth(thin)) ///
    xline(1913.5 2014.5 2018.5, lpattern(dash) lcolor(gs12) lwidth(thin)) ///
    text(`ymid' 1913.5 "End of TA data",       place(w) orientation(vertical) size(small) color(gs6)) ///
    text(`ymid' 2014.5 "End of dispute data",  place(w) orientation(vertical) size(small) color(gs6)) ///
    text(`ymid' 2018.5 "End of alliance data", place(e) orientation(vertical) size(small) color(gs6)) ///
    xtitle("Year") ytitle("Regression coefficient") ///
    xscale(range(1830 2025)) xlabel(1830(20)2010 2025, labsize(small)) ///
    ylabel(, angle(0) labsize(small) grid glcolor(gs15)) ///
    title("Regression results `var_ex'") ///
    legend(order(1 "Louvain signed TIBI" 2 "Louvain trade" 3 "Louvain rescaled TIBI" ///
                 4 "IntraMax" 5 "AN") rows(2) position(6) size(small) region(lcolor(none))) ///
    scheme(s2color) graphregion(color(white)) plotregion(margin(small))
    
    graph export "results/bloc_study/shared_bloc_reg_`var_ex'.png", replace



  
    foreach NetworkType of global liste_network {
        preserve
        keep if NetworkType=="`NetworkType'"
        tsset year
        tsfill, full

        drop if year >= 2026
    twoway (rarea ci_low ci_high year , lcolor(gs8) cmissing(n)) ///
           (connected coef year , mcolor(navy) lcolor(navy) msymbol(circle) cmissing(n)) ///
            (connected r2p year , yaxis(2) cmissing(n)), ///
            yline(1, lpattern(dash) lcolor(red)) ///
            xline(1913.5, lpattern(dash) lcolor(blue)) text(1 1913.5 "end of TA data", place(e) orientation(vertical)) ///
            xline(2014.5, lpattern(dash) lcolor(blue)) text(1 2014.5 "end of dispute data", place(w) orientation(vertical)) ///
            xline(2018.5, lpattern(dash) lcolor(blue)) text(1 2014.5 "end of alliance data", place(e) orientation(vertical)) ///
            xtitle("Year") ytitle("",axis(1) ) ytitle( "",axis(2)) ///
            xscale(range(1830 2025)) xlabel(1830(20)2010 2025, labsize(small)) ///
            title("`NetworkType' Regression results `var_ex'") ///
            legend(order(2 "Odds Ratio of `var_ex' (left)" 3 "Incremental Pseudo R2 (right)") position(6))

    graph export "results/bloc_study/shared_bloc_reg__`var_ex'_`NetworkType'.png", replace
    restore
    }
}
