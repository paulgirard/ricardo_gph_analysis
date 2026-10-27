
*ssc install ppmlhdfe, replace
*ssc install ftools, replace
*ssc install reghdfe, replace
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

global classification_types Tibi LouvainMaxtrade LouvainTibirescale IntraMax AN

***************Gravity trade estimation program ***************
capture program drop postclass_gravity
program define postclass_gravity
	args year CafFob


import delimited "results/gravity/gravity_`year'.csv", ///
    delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 

keep if CafFob=="`CafFob'"

*****Usual control variables


merge m:1 undir_pair_key using "external data/Controls panel/distance.dta", keep(1 3) nogenerate
gen ln_distance=ln(distance_km)
merge m:1 undir_pair_key year using "external data/Controls panel/alliances.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/contiguity.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/disputes.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/commonempire.dta", keep(1 3) nogenerate
merge m:1 undir_pair_key year using "external data/Controls panel/trade_agreements.dta", keep(1 3) nogenerate

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

codebook value ln_distance contig12 common_empire mid_n atop_allie TA

*******classification

merge m:1 undir_pair_key using "results/communities/intra_bloc_pairs_`year'.dta", keep(3)

*****Régression de gravité

destring importerId exporterId, replace



foreach classification of global classification_types {

set seed 4563

local liste_var_ex = "$liste_var_ex"
if `year' >=2015 local liste_var_ex = subinstr("`liste_var_ex'","mid_n","",.)
if `year' >=2019 local liste_var_ex = subinstr("`liste_var_ex'","atop_allie","",.)
if `year' >=1914 local liste_var_ex = subinstr("`liste_var_ex'","TA","",.)
if `year' >=2022 local liste_var_ex = subinstr("`liste_var_ex'","common_empire","",.)

display "`year'"

ppmlhdfe value IntraBloc_`classification' `liste_var_ex', absorb(importerId exporterId, savefe)
estimates store full
gen byte in_sample=e(sample)



local coef = _b[IntraBloc_`classification']
local lc=_b[IntraBloc_`classification']-1.96*_se[IntraBloc_`classification']
local uc=_b[IntraBloc_`classification']+1.96*_se[IntraBloc_`classification']
local R2=e(r2_p)
local ll_full = e(ll)
ppmlhdfe value `liste_var_ex' if in_sample, absorb(importerId exporterId)
local add_R2=`R2'-e(r2_p)
local add_ll = 2*(`ll_full' - e(ll))
local add_ll_pct = 2*(`ll_full' - e(ll))/`ll_full'
post reg_postclass_gravity  ("`CafFob'") (`year') ("`classification'") ("with") (`coef') (`lc') (`uc') (`add_R2') (`add_ll')
drop in_sample

****Sans contrôles
ppmlhdfe value IntraBloc_`classification', absorb(importerId exporterId, savefe)
estimates store full
gen byte in_sample=e(sample)



local coef = _b[IntraBloc_`classification']
local lc=_b[IntraBloc_`classification']-1.96*_se[IntraBloc_`classification']
local uc=_b[IntraBloc_`classification']+1.96*_se[IntraBloc_`classification']
local R2=e(r2_p)
local ll_full = e(ll)
ppmlhdfe value if in_sample, absorb(importerId exporterId)
local add_R2=`R2'-e(r2_p)
local add_ll = 2*(`ll_full' - e(ll))
local add_ll_pct = 2*(`ll_full' - e(ll))/`ll_full'
post reg_postclass_gravity  ("`CafFob'") (`year') ("`classification'") ("without") (`coef') (`lc') (`uc') (`add_R2') (`add_ll')
drop in_sample





}
end



************************
global liste_var_ex TA ln_distance common_empire contig12 mid_n atop_allie 


capture postclose reg_postclass_gravity
postfile reg_postclass_gravity str10(CafFob) year str40(classification) str40(controls) ////
        coef ci_low ci_high r2p llp using "results/gravity_post_classification/reg_postclass_gravity.dta", replace


postclass_gravity 1841 caf
postclass_gravity 1841 fob




foreach year of numlist 1833(1)1840 1842(1)1938 1948(1)2025 {
	postclass_gravity `year' caf
	postclass_gravity `year' fob
}


postutil dir



postclose reg_postclass_gravity






use "results/gravity_post_classification/reg_postclass_gravity.dta", clear
sort year CafFob classification
save "results/gravity_post_classification/reg_postclass_gravity.dta", replace
	
export delimited using "results/gravity_post_classification/reg_postclass_gravity.csv", replace delimiter(",") quote
replace coef=. if ci_low==.

egen id = group(classification CafFob controls)
tsset id year
sort id year
tsfill
fillin classification year CafFob controls



foreach withcontrols in without with {
    
    foreach CafFob in caf fob {   
 


    drop if year >= 2026
    twoway ///
        (line coef year if classification == "Tibi" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
        ,               lcolor(navy)         lpattern(solid)        lwidth(medthick) cmissing(n)) ///
        (line coef year if classification == "LouvainMaxtrade" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
        ,    lcolor(maroon)       lpattern(dash)         lwidth(medthick) cmissing(n)) ///
        (line coef year if classification == "LouvainTibirescale" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
        , lcolor(forest_green) lpattern(shortdash_dot) lwidth(medthick) cmissing(n)) ///
        (line coef year if classification == "IntraMax" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
        ,           lcolor(orange)       lpattern(longdash_dot) lwidth(medthick) cmissing(n)) ///
        (line coef year if classification == "AN" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
        ,                 lcolor(purple)       lpattern(dot)          lwidth(thick)    cmissing(n)), ///
        yline(0, lpattern(solid) lcolor(red) lwidth(thin)) ///
        xtitle("Year") ytitle("") ///
        title("Gravity coefficients (`CafFob') -- `withcontrols' controls") ///
        legend(order(5 "AN" 4 "IntraMax" 2 "Louvain trade" 3 "Louvain rescaled TIBI" 1 "Louvain TIBI") ///
            position(6) rows(2) size(small) keygap(1) symxsize(10)) ///
        xscale(range(1830 2025)) xlabel(1830(20)2010 2025, labsize(small)) ///
        graphregion(color(white)) plotregion(margin(small)) ///
        scheme(s2color)        

    graph export "results/gravity_post_classification/Classification_`withcontrols'controls_`CafFob'.png", replace

    foreach class of global classification_types {

            twoway (rarea ci_low ci_high year if classification == "`class'" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
                    , lcolor(gs8) cmissing(n)) ///
            (connected coef year if classification == "`class'" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
                    , mcolor(navy) lcolor(navy) msymbol(circle) cmissing(n)) ///
            (connected r2p year if classification == "`class'" & CafFob=="`CafFob'" & controls=="`withcontrols'" ///
                    , yaxis(2) cmissing(n)), ///
			yline(0, lpattern(dash) lcolor(red)) ///
            xtitle("Year") ytitle("",axis(1) ) ytitle( "",axis(2)) ///
            xscale(range(1830 2025)) xlabel(1830(20)2010 2025, labsize(small)) ///
            title("Gravity coefficients `class' -- `CafFob' -- `withcontrols' controls") ///
            legend(order(2 "Coefficient of `class' (left)" 3 "Incremental R{sup:2} (right)") position(6) rows(1))

    graph export "results/gravity_post_classification/Classification_`class'_`withcontrols'controls_`CafFob'.png", replace

    }



    

    }

}


