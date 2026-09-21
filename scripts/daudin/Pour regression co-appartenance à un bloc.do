*ssc install geodist
cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"



/*
*****Importation des données de co-appartenance à un bloc (si on repart de zéro -- pas utile)

capture program drop block_importation
program define block_importation
	args year CafFob NetworkType
*exemple : block_importation 1833 caf louvain

if "`NetworkType'"=="IntraMax" {
    *importation des données de co-appartenance à un bloc
    import delimited using "data/blocks/intramax/paires_blocs_`year'.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear
}


drop year* bloc_exp bloc_imp id *Type value new* original*


end
*/

***Importation des données travaillées par Youssef (du temps du gros fichier)
/*
capture program drop master_panel_importation
program define master_panel_importation
    args   shape
***exemple : master_panel_importation rectangle


*** -d = décompresser, -k = garder l'original, -f = forcer l'écrasement si le fichier existe déjà
    ! /opt/homebrew/bin/xz -dkf data/blocks/master_panel_`shape'.csv.xz    


    import delimited using "data/blocks/master_panel_`shape'.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

    drop intramax_exp intramax_imp id importerType exporterType export_intramax
    drop reportedBy partial valueToSplit newReporters newPartners originalReportedTradeFlowIds
    drop status notes louvain_exp louvain_imp export_louvain proximity coMembershipScore 
    drop bridgeNessEdgeScore ambiguityScore sourceCommunityId exp_Cited exp_Reporting exp_GphStatus 
    drop exp_MeanAmbiguityScore imp_Cited imp_Reporting imp_GphStatus imp_MeanAmbiguityScore 
    drop region_AN_exp region_AN_imp lat_exp lng_exp lat_imp lng_imp

    keep if exportateur < importateur 
    rename exportateur target
    rename importateur source

    

    save data/blocks/master_panel.dta, replace

    foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2025 {
        preserve
        keep if year==`year'
        gen key= string(exporterId) +  "-" + string(importerId) if string(exporterId) < string(importerId)
        replace key= string(importerId) +  "-" + string(exporterId) if string(exporterId) > string(importerId)
        assert key !=""
        sort key
        order key
        drop importerId exporterId
        save data/blocks/master_`year'_fob.dta, replace
        export delimited using data/blocks/master_`year'_fob.csv, replace delimiter(",") quote
        restore
    }


end
*jamais utile
*master_panel_importation rectangle 
* à rétablir quand les données changent
*master_panel_importation carre 

//En fait, la rectangle ne me sert pas à ce niveau : je prends la carré, puis je fixe l’ordre target/source


*/


import delimited "data/blocks/Controls panel/distance.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/distance.dta", replace

capture program drop block_regression
program define block_regression
    args year CafFob NetworkType

import delimited "data/blocks/master_`year'_fob.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 

destring(distance_km), replace force
generate ln_dist=ln(distance_km)


***Importation des données d’appartenance à empire **************
////Pour rapports de subordination
merge m:1 key year using "external data/dependency_relations.dta", keep(1 3)
replace sub_empire=0 if sub_empire==.
drop _merge GPH_code GPH_status sovereign_GPH_code


recast str2045 target
rename target GPH_code
merge m:m GPH_code year using "external data/dependency_relations.dta", keep(1 3)
rename sovereign_GPH_code target_sov
drop _merge
rename GPH_code target 

recast str2045 source
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





logistic meme_`NetworkType' ln_dist common_empire, vce(cluster source)
display "`year'"

foreach var_ex in ln_dist common_empire {
    post reg_result_`var_ex' ("`NetworkType'") ("`CafFob'") (`year') ("`var_ex'") (_b[`var_ex']) (_b[`var_ex']-1.96*_se[`var_ex']) (_b[`var_ex']+1.96*_se[`var_ex']) (e(r2_p))
}

end

*********************************************************************

foreach var_ex in ln_dist common_empire {
    capture postclose reg_result_`var_ex'
    postfile reg_result_`var_ex' str10(NetworkType) str10(CafFob) year str40(var) coef ci_low ci_high r2p using "results/block_study/regression_results_`var_ex'.dta", replace
    
}

foreach year of numlist 1833(1)1938 1948(1)2008 2010(1)2025 {
    block_regression `year' fob intramax
  }

foreach var_ex in ln_dist common_empire {
    postclose reg_result_`var_ex'
}


foreach var_ex in ln_dist common_empire {

    use "results/block_study/regression_results_`var_ex'.dta", clear
    export delimited using "results/block_study/regression_results_`var_ex'.csv", replace delimiter(",") quote

    replace coef=exp(coef)
    replace ci_low=exp(ci_low)
    replace ci_high=exp(ci_high)

    tsset year
    tsfill, full
    twoway (rcap ci_low ci_high year, lcolor(gs8)) ///
           (connected coef year, mcolor(navy) lcolor(navy) msymbol(circle) cmissing(n)) ///
            (connected r2p year, yaxis(2) cmissing(n)), ///
            yline(1, lpattern(dash) lcolor(red)) ///
            xtitle("Year") ytitle("",axis(1) ) ytitle( "",axis(2)) ///
            title("Regression results (fob)") ///
            legend(order(2 "Odds Ratio of `var_ex' (left)" 3 "Pseudo R2 (right)") position(6))

    graph export "results/block_study/`var_ex'_intramax_fob.png", replace
}
