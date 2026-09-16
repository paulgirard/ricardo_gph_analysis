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
    import delimited using "data/blocks/intramax/paires_blocs_`year'.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear
}


drop year* bloc_exp bloc_imp id *Type value new* original*


end
*/

***Importation des données travaillées par Youssef

capture program drop master_panel_importation
program define master_panel_importation
    args   shape
***exemple : master_panel_importation rectangle


*** -d = décompresser, -k = garder l'original, -f = forcer l'écrasement si le fichier existe déjà
    ! /opt/homebrew/bin/xz -dkf data/blocks/master_panel_`shape'.csv.xz    


    import delimited using "data/blocks/master_panel_`shape'.csv", /*
        */delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

    drop intramax_exp intramax_imp id importerType exporterType export_intramax
    drop reportedBy partial valueToSplit newReporters newPartners originalReportedTradeFlowIds
    drop status notes louvain_exp louvain_imp export_louvain proximity coMembershipScore 
    drop bridgeNessEdgeScore ambiguityScore sourceCommunityId exp_Cited exp_Reporting exp_GphStatus 
    drop exp_MeanAmbiguityScore imp_Cited imp_Reporting imp_GphStatus imp_MeanAmbiguityScore 
    drop region_AN_exp region_AN_imp lat_exp lng_exp lat_imp lng_imp

    save data/blocks/master_panel_`shape'.dta, replace

    foreach year of numlist 1833(1)1938 1947(1)2008 2010(1)2025 {
        preserve
        keep if year==`year'
        save data/blocks/master_panel_`shape'_`year'_caf.dta, replace
        export delimited using data/blocks/master_panel_`shape'_`year'_caf.csv, replace delimiter(",") quote
        restore
    }


end

master_panel_importation rectangle
master_panel_importation carre

*block_importation 1833 caf IntraMax