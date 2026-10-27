*ssc install reghdfe
*ssc install ftools
*ssc install require

local explo 0
local share_sample 0.05 
*global model  reghdfe
global model  cloglog


cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"

global classification_types LouvainMaxtrade IntraMax Tibi  LouvainTibirescale  AN

****************** Exploration des données

use "results/extensive/BestGuessBilTrade.dta", clear


if `explo' {

    *Tirage aléatoire de paires (toutes les années d'une paire sont gardées)
    set seed 12345
    tempvar u
    bysort undir_pair_key (year): gen double `u' = runiform() if _n == 1
    bysort undir_pair_key (year): replace `u' = `u'[1]
    keep if `u' <= `share_sample' | undir_pair_key=="200-220" | undir_pair_key== "10-305"
}
else {
    local yearvar "i.year"
}


****Cleanup status
replace status=subinstr(status, " ", "", .)

****Looking for splits that give a very small trade

bys year : egen yearly_total_trade=total(value)
gen trade_share = value/yearly_total_trade
gen log10_trade_share=log10(trade_share)

gen vst=1 if trade_share <=10^(-10)
****c. 5040 US $ in 2025
label var vst "Very small trade"
replace vst=0 if trade_share !=. & vst==.

replace log10_trade_share=-13 if log10_trade_share<=-13



label variable log10_trade_share "Trade share (bilateral trade/total trade this year)"
hist log10_trade_share, percent title("Trade share distribution") ///
     xlabel(-13 `" "10{sup:-13}" "or less" "' -12 "10{sup:-12}" -11 "10{sup:-11}" -10 `""10{sup:-10}" "5040 USD" "in 2025" "' -9 "10{sup:-9}" -8 "10{sup:-8}" -7 "10{sup:-7}" ///
     -6 "10{sup:-6}" -5 "10{sup:-5}" -4 "10{sup:-4}" -3 "10{sup:-3}" -2 "0.01" -1 "0.1") ///
     scheme(s2color)
graph export "results/trade_share_distribution.png", replace




****looking at trading pairs
preserve
replace status = "ok but zero trade" if trade_share <=10^(-10)
replace status=subinstr(status, " ", "", .)
contract id status
rename _freq nbr_of_
reshape wide nbr_of_, i(id) j(status) string

gen flag_ptrade_incl_fs = 1 if nbr_of_ok !=. | nbr_of_failed_gravity!=. | nbr_of_okbutzerotrade !=.
gen flag_ptrade_n_fs = 1 if nbr_of_ok !=.
label variable flag_ptrade_incl_fs "Trading pairs, including very small flows and failed splits"
label variable flag_ptrade_n_fs "Trading pairs, excluding"
replace flag_ptrade_incl_fs = 0 if flag_ptrade_incl_fs==.
replace flag_ptrade_n_fs = 0 if flag_ptrade_n_fs==.
table flag_ptrade_n_fs flag_ptrade_incl_fs 
collect export "results/extensive/tradingpairs.txt", as(txt) replace 
restore

******flaging trade
generate flag_trade_incl_fs=1 if (status=="ok" | status=="failed_gravity") & value !=0
generate flag_trade_n_fs=1 if status=="ok" & trade_share >=10^(-10) 

label variable flag_trade_incl_fs "Trading observations, including very small flows and failed splits"
label variable flag_trade_n_fs "Trading observations, excluding"
foreach trade_type in incl_fs n_fs {
     replace flag_trade_`trade_type'=0 if flag_trade_`trade_type'==.
    bys id : egen flag_trade_`trade_type'_id=max(flag_trade_`trade_type')
    replace flag_trade_`trade_type'_id=0 if flag_trade_`trade_type'_id==.
    tab flag_trade_`trade_type'_id
    *codebook undir_pair_key if flag_trade_`trade_type'_id==1
    *codebook id if flag_trade_`trade_type'_id==1
}

table flag_trade_n_fs flag_trade_incl_fs 
collect export "results/extensive/tradingobservations.txt", as(txt) replace 




sort undir_pair_key id year
*br if id=="10<-100"


******* Entry and exit trade for actors
bys id: egen nbr_year=count(status)
bys id: egen nbr_trade_year_n_fs=total(flag_trade_n_fs)
label variable nbr_trade_year_n_fs "Trading years, excluding"
bys id: egen nbr_trade_year_incl_fs=total(flag_trade_incl_fs)
label variable nbr_trade_year_incl_fs "Trading years, including very small flows and failed splits"


bys exporterId: egen exporter_start_year=min(year)
bys importerId: egen importer_start_year=min(year)
bys importerId: egen importer_end_year=max(year)
bys exporterId: egen exporter_end_year=max(year)

*codebook exporter_start_year
*codebook exporter_end_year




***** tag zero_entry

generate zero_year_incl_fs = year if value==0
generate zero_year_n_fs = year if trade_share <= 10^(-10) 
foreach trade_type in incl_fs n_fs {
    *replace zero_year_`trade_type'= 0 if zero_year_`trade_type'==.
    bys id : egen zero_entry_`trade_type'=min(zero_year_`trade_type')
}


save temp1.dta, replace
****** tag trade_entry
use temp1.dta, clear
sort year

bys id : egen pair_entry=min(year)

foreach trade_type in incl_fs n_fs {
    generate trade_year_`trade_type' = year if flag_trade_`trade_type'==1
    bys id : egen trade_entry_`trade_type'=min(trade_year_`trade_type')
    gen at_risk_`trade_type' = 1
    replace at_risk_`trade_type' = 0 if year >trade_entry_`trade_type'
    replace at_risk_`trade_type' = 0 if trade_entry_`trade_type'==pair_entry
}


sort undir_pair_key id year



generate flag_trade_entry_incl_fs = 1 if year==trade_entry_incl_fs
generate flag_trade_entry_n_fs = 1 if year==trade_entry_n_fs
replace flag_trade_entry_incl_fs=0 if trade_entry_incl_fs ==. | year < trade_entry_incl_fs
replace flag_trade_entry_n_fs=0 if trade_entry_n_fs ==. | year < trade_entry_n_fs



*****work on duration

***Duration 1 : years of directed pair existence before first trade
***Duration 2 : time since appearance of directed pair 
***Duration 3 : time since imputedzero (or very small trade in the n_fs case)

sort id year
by id : gen dur1 = _n
by id : gen dur2 = year-max(exporter_start_year,importer_start_year)
by id : gen dur3_incl_fs = year-zero_entry_incl_fs
by id : gen dur3_n_fs    = year-zero_entry_n_fs


replace  dur3_incl_fs=. if dur3_incl_fs<0
replace  dur3_n_fs=. if dur3_n_fs<0
*br id year *Label value status pair_entry trade_entry* dur*


*br  undir_pair_key id year zero_year_incl_fs-dur3_n_fs in 1/600
*br  undir_pair_key id year zero_year_incl_fs-dur3_n_fs if id=="10->305"


table flag_trade_n_fs flag_trade_incl_fs if at_risk_incl_fs ==1
collect export "results/extensive/tradingobservations_at_risk_incl_fs.txt", as(txt) replace 

table flag_trade_n_fs flag_trade_incl_fs if at_risk_n_fs ==1
collect export "results/extensive/tradingobservations_at_risk_n_fs.txt", as(txt) replace 



save temp2.dta, replace



**************************** importation des appartenances communes

use temp2.dta, clear
merge m:1 undir_pair_key year using "results/communities/intra_bloc_pairs.dta", keep(3)
drop _merge

** merge n’est pas égal à 3 car j’ai déjà droppé les années post-trade (et celles sans trade ?)


sort undir_pair_key id year
capture drop nbr_cyears*
foreach classification of global classification_types  {
    by undir_pair_key id : generate nbr_cyears_`classification' = sum(IntraBloc_`classification')
    replace nbr_cyears_`classification' = max(0,nbr_cyears_`classification'-IntraBloc_`classification')
    by undir_pair_key id : generate share_cyears_`classification' = nbr_cyears_`classification'/(_n-1)
}


*****taking in the controls
merge m:1 undir_pair_key using "external data/Controls panel/distance.dta", keep(1 3) nogenerate
gen ln_dist=ln(distance_km)
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


* --- Préparation du panel ---
capture drop id_num
egen id_num = group(id)


drop if id_num == .
xtset id_num year


save temp3.dta, replace
*------------------------------------------------------------
* Régressions : tableaux avec -collect-
* 1 tableau par définition de Louvain
* 6 colonnes = 2 variables dépendantes x 3 spécifications de durée
*------------------------------------------------------------

use temp3.dta, clear





* --- Listes de la boucle ---
local depvars  flag_trade_entry_n_fs flag_trade_entry_incl_fs


* --- Contrôles communs ---
local controls ln_dist common_empire contig12 mid_n atop_allie TA

* Dossier de sortie (à adapter)
global out "results/extensive"
collect clear

foreach classification of global classification_types {

    

    * Noms communs pour aligner les lignes dans le tableau
    capture drop nbr_c share_c
    gen nbr_c   = nbr_cyears_`classification'
    gen share_c = share_cyears_`classification'

    foreach y of local depvars {

        * Les 3 durées / at risk (dur1, dur2, durée spécifique à la variable dépendante)
        if "`y'" == "flag_trade_entry_n_fs" {
            local durlist dur1 dur2 dur3_n_fs
            local at_risk at_risk_n_fs
        }
        else {
            local durlist dur1 dur2 dur3_incl_fs
            local at_risk at_risk_incl_fs
        }

        local k = 0
        foreach d of local durlist {
            local ++k

            capture drop dur
            capture drop dur_sq
            gen dur = `d'
            gen dur_sq = dur^2

            display  "Estimation $model / `classification' / `y' / d`k'"

            * Estimation + collecte : 2 étiquettes (dépendante, spécification de durée)
            if "$model" =="reghdfe" collect, tag(depvar[`y'] spec[d`k'] classification[`classification']): ///    
            reghdfe `y' dur dur_sq nbr_c share_c `controls' if `at_risk'==1, absorb(year) vce(cluster id_num)
            
            local failure 0
            if "$model" =="cloglog" {
                capture noisily  collect, tag(depvar[`y'] spec[d`k'] classification[`classification']): ///
                cloglog `y' dur dur_sq nbr_c share_c `controls' i.year if `at_risk'==1, ///
                vce(cluster id_num) level(95) iterate(100) eform
            
                if _rc {
                    capture noisily  collect, tag(depvar[`y'] spec[d`k'] classification[`classification']): ///
                    cloglog `y' dur dur_sq nbr_c share_c `controls' i.year if `at_risk'==1, ///
                    vce(cluster id_num) level(95) eform ///
                    difficult technique(nr 5 bhhh 10) iterate(200)
                }

                if _rc {
                    local failed `failed' `classification'/`y'/d`k'
                    display as error "Non-convergence : `classification' / `y' / d`k'"
                    local failure`classification'/`y'/d`k' 1
                }
            }

        }
    }
}


foreach classification of global classification_types { 
   * local classification AN
    local failure 0
    *--------------------------------------------------------
    * Mise en forme
    *--------------------------------------------------------

    collect stars _r_p 0.01 "***" 0.05 "**" 0.10 "*", attach(_r_b) shownote

    if "$model"=="reghdfe" collect style cell result[_r_b _r_ci r2], nformat(%7.3f)
    if "$model"=="cloglog" collect style cell result[_r_b _r_ci r2], nformat(%7.2f)
    collect style cell result[_r_ci], sformat("[%s]") cidelimiter(", ")
    if "$model"=="reghdfe" collect style cell colname[dur dur_sq nbr_c]#result[_r_b _r_ci], nformat(%9.2e)
    if "$model"=="cloglog" {
        collect style cell colname[dur]#result[_r_b _r_ci], nformat(%5.4f)
        collect style cell colname[ dur_sq ]#result[_r_b _r_ci], nformat(%7.6f)
        collect style cell colname[ nbr_c ]#result[_r_b _r_ci], nformat(%6.5f)
    }
    collect style cell result[N N_clust], nformat(%9.0fc)
    collect style cell result[ll], nformat(%9.1f)

    * Libellés des lignes
    collect label levels colname ///
        dur         "Duration (years)" ///
        dur_sq        "Duration²" ///
        nbr_c         "Nb. years in same community" ///
        share_c       "Share years in same community" ///
        ln_dist       "Ln(distance)" ///
        common_empire "Same empire" ///
        contig12      "Contiguity" ///
        mid_n         "Conflict (MID)" ///
        TA            "Trade agreement" ///
        atop_allie    "Alliance (ATOP)", modify

    * Libellés des colonnes
    collect label levels depvar ///
        flag_trade_entry_n_fs    "Start trade (excluding very small flows and failed splits)" ///
        flag_trade_entry_incl_fs "Start trade (including very small flows and failed splits)", modify
    collect label levels spec ///
        d1 "Years of existence" ///
        d2 "Time since appearance" ///
        d3 "Time since appearance with zero trade", modify

    collect label levels result ///
        _r_b  " " ///
        _r_ci " " ///
        N     "Observations" ///
        ll    "Log-likelihood" ///
        N_clust "Pairs" ///
        r2  "R²", modify

    collect style header result, level(label)
    collect style header result[_r_b _r_ci], level(hide)
    collect style column, dups(center) extraspace(1) nodelimiter
    collect style row stack, nobinder spacer
    

    * Disposition : variables en lignes, (dépendante x durée) en colonnes
    if "$model" =="reghdfe"   collect layout ///
        (colname[dur dur_sq nbr_c share_c ln_dist common_empire contig12 mid_n atop_allie TA]#result[_r_b _r_ci] ///
         result[N N_clust r2]) ///
        (depvar#spec[d3 d1 d2]#classification[`classification'])

    if "$model" =="cloglog"   collect layout ///
        (colname[dur dur_sq nbr_c share_c ln_dist common_empire contig12 mid_n atop_allie TA]#result[_r_b _r_ci] ///
         result[N N_clust ll]) ///
        (depvar#spec[d3 d1 d2]#classification[`classification'])

    collect title "Community definition : `classification' (${model}, year fixed effects)"
    collect notes 1: "95 % confidence intervals in brackets."
    collect notes 2: "dur3 = dur_n_fs for flag_trade_entry_n_fs ; dur3_incl_fs for flag_trade_entry_incl_fs."

    * Export : .docx, .tex et .csv
    collect export "$out/ext_reg_${model}_`classification'.docx", replace
    collect export "$out/ext_reg_${model}_`classification'.tex",  replace tableonly
    collect export "$out/ext_reg_${model}_`classification'.txt",  replace



}

 if "$model" =="reghdfe"   collect layout ///
        (colname[dur dur_sq nbr_c share_c ln_dist common_empire contig12 mid_n atop_allie TA]#result[_r_b _r_ci] ///
         result[N N_clust r2]) ///
        (depvar[flag_trade_entry_n_fs]#spec[d3]#classification)

if "$model" =="cloglog"   collect layout ///
       (colname[dur dur_sq nbr_c share_c ln_dist common_empire contig12 mid_n atop_allie TA]#result[_r_b _r_ci] ///
        result[N N_clust ll]) ///
       (depvar[flag_trade_entry_n_fs]#spec[d3]#classification)

   collect title "(${model}, year fixed effects)"
   collect notes 1: "95 % confidence intervals in brackets."
   collect notes 2: "dur3 = dur_n_fs for flag_trade_entry_n_fs"

   * Export : .docx, .tex et .csv
   collect export "$out/ext_reg_${model}.docx", replace
   collect export "$out/ext_reg_${model}.tex",  replace tableonly
   collect export "$out/ext_reg_${model}.txt",  replace




















