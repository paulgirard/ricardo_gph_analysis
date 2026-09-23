*ssc install geodist
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"


*
****À faire une fois
/*

import delimited "external data/Controls panel/distance.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/Controls panel/distance.dta", replace

import delimited "external data/Controls panel/alliances.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/Controls panel/alliances.dta", replace
**Défini jusqu’en 2018


import delimited "external data/Controls panel/contiguity.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/Controls panel/contiguity.dta", replace

import delimited "external data/Controls panel/disputes.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/Controls panel/disputes.dta", replace
**Défini jusqu’en 2014

import delimited "external data/BlocselonAN.csv", delimiter(";") bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/BlocselonAN.dta", replace


import delimited "data/blocks/panel_blocs_paires.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear
save data/blocks/panel_blocs_paires.dta, replace

foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2025 {
    import delimited "data/blocks/gph_blocks_by_year/`year'_fob.csv" , delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear
    save "data/blocks/gph_blocks_by_year/`year'_fob.dta", replace
  }



*/

capture program drop block_regression
program define block_regression
    args year CafFob NetworkType

use  "data/blocks/panel_blocs_paires.dta", clear
keep if year==`year' 

foreach source_target in source target {
    rename `source_target' id
    merge m:1 id year using "data/blocks/gph_blocks_by_year/`year'_`CafFob'.dta", keep(1 3)
    rename blockLouvain `source_target'_blocklouvain
    rename blockIntraMax `source_target'_blockintramax
    rename id GPH_code
    drop _merge
    merge m:1 GPH_code using "external data/BlocselonAN.dta", keep(1 3)
    rename region_AndersonNorheim `source_target'_blockAN
    replace `source_target'_blockAN = subregion_AndersonNorheim if subregion_AndersonNorheim !=""
    drop continent lat lng subregion_AndersonNorheim Comment period_*
    rename GPH_code `source_target'
    drop _merge
}

generate meme_`NetworkType'=1 if source_block`NetworkType'==target_block`NetworkType'
replace meme_`NetworkType'=0 if meme_`NetworkType'==.



merge 1:1 key using "external data/Controls panel/distance.dta", keep(1 3) nogenerate
merge 1:1 key year using "external data/Controls panel/alliances.dta", keep(1 3) nogenerate
merge 1:1 key year using "external data/Controls panel/contiguity.dta", keep(1 3) nogenerate

merge 1:1 key year using "external data/Controls panel/disputes.dta", keep(1 3) nogenerate


destring(distance_km), replace force
generate ln_dist=ln(distance_km)



***Dans tous ces cas, je considère les manquants comme nul. Peut-être pas malin.
destring(conttype), replace force
generate contig_large=1 if conttype ==1 | conttype==2 
**1 : contiguous by land 2: 12 miles or less of water
*replace contig_large=0 if contig_large==.
destring(mid_herit), replace force
*replace mid_herit=0 if mid_n==.
destring(atop_herit), replace force
*replace atop_herit=0 if atop_allie==.




***Importation des données d’appartenance à empire **************
////Pour rapports de subordination
merge m:1 key year using "external data/dependency_relations.dta", keep(1 3)
replace sub_empire=0 if sub_empire==.
drop _merge GPH_code GPH_status sovereign_GPH_code


tostring(target), replace
rename target GPH_code
merge m:m GPH_code year using "external data/dependency_relations.dta", keep(1 3)
rename sovereign_GPH_code target_sov
drop _merge
rename GPH_code target 

tostring(source), replace
rename source GPH_code
merge m:m GPH_code year using "external data/dependency_relations.dta", keep(1 3)
rename sovereign_GPH_code source_sov
drop _merge
rename GPH_code source


generate common_empire=1 if target_sov==source_sov & target_sov!=""
replace common_empire=0 if common_empire==.
bysort source target : egen max=max(common_empire)
bysort source target : replace common_empire = max
bysort source target : keep if _n==1
drop max
bysort source target : assert  _N==1
***Il y a des cas de GHP qui a plusieurs souverains.  (eg Samoa 1889-1900)
*Cracow dès 1833

replace common_empire=1 if sub_empire==1

******************************




logistic meme_`NetworkType' $liste_var_ex /*, vce(cluster source)*/

display "`year'"

foreach var_ex in $liste_var_ex {
    local coef = _b[`var_ex']
    local lc=_b[`var_ex']-1.96*_se[`var_ex']
    local uc=_b[`var_ex']+1.96*_se[`var_ex']
    local R2=e(r2_p)
    local var_ex_minus = subinstr("$liste_var_ex","`var_ex'","",.)
    logistic meme_`NetworkType' `var_ex_minus', vce(cluster source)
    local add_R2=`R2'-e(r2_p)
    post reg_result_`var_ex' ("`NetworkType'") ("`CafFob'") (`year') ("`var_ex'") (`coef') (`lc') (`uc') (`add_R2')
}

end

*********************************************************************

global liste_var_ex ln_dist common_empire contig_large mid_herit atop_herit

foreach var_ex of global liste_var_ex {
    capture postclose reg_result_`var_ex'
    postfile reg_result_`var_ex' str10(NetworkType) str10(CafFob) year str40(var) coef ci_low ci_high r2p using "results/block_study/regression_results_`var_ex'.dta", replace
    
}

foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2014 {
    block_regression `year' fob intramax
  }

foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2014 {
    block_regression `year' fob louvain
  }

foreach var_ex of global liste_var_ex {
    postclose reg_result_`var_ex'
}



foreach var_ex of global liste_var_ex {

    use "results/block_study/regression_results_`var_ex'.dta", clear
    export delimited using "results/block_study/regression_results_`var_ex'.csv", replace delimiter(",") quote
    replace coef=exp(coef)
    replace ci_low=exp(ci_low)
    replace ci_high=exp(ci_high)
    replace ci_high=5 if ci_high>5
    replace ci_low=5 if ci_low>5
    replace coef=5 if coef>5

  
    foreach NetworkType in intramax louvain {
        preserve
        keep if NetworkType=="`NetworkType'"
        tsset year
        tsfill, full

        
    twoway (rarea ci_low ci_high year , lcolor(gs8) cmissing(n)) ///
           (connected coef year , mcolor(navy) lcolor(navy) msymbol(circle) cmissing(n)) ///
            (connected r2p year , yaxis(2) cmissing(n)), ///
            yline(1, lpattern(dash) lcolor(red)) ///
            xtitle("Year") ytitle("",axis(1) ) ytitle( "",axis(2)) ///
            xscale(range(1830 2020)) ///
            title(""`NetworkType'" Regression results `var_ex' (fob)") ///
            legend(order(2 "Odds Ratio of `var_ex' (left)" 3 "Incremental Pseudo R2 (right)") position(6))

    graph export "results/block_study/`var_ex'_`NetworkType'_fob.png", replace
    restore
    }
}
