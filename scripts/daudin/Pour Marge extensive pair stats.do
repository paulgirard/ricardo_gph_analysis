cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"


****************** Exploration des données

use "results/extensive/BestGuessBilTrade.dta", clear






****Cleanup status
replace status="split_failed" if strmatch(status,"*split*") 
replace status=subinstr(status, " ", "", .)

****Looking for splits that give a very small trade
bys year : egen yearly_total_trade=total(value)
gen trade_share = value/yearly_total_trade
gen log10_trade_share=log10(trade_share)
local CafFob fob
label variable log10_trade_share "Trade share (bilateral trade/total trade this year)"
hist log10_trade_share, freq title ("Trade share distribution, `CafFob'") ///
     xlabel(-12 "10{sup:-12}" -11 "10{sup:-11}" -10 "10{sup:-10}" -9 "10{sup:-9}" -8 "10{sup:-8}" -7 "10{sup:-7}" ///
     -6 "10{sup:-6}" -5 "10{sup:-5}" -4 "10{sup:-4}" -3 "10{sup:-3}" -2 "0.01" -1 "0.1")
graph export "results/trade_share_distribution.png", replace

gen vst=1 if trade_share <=10^(-10)
label var vst "Very small trade"
replace vst=0 if trade_share !=. & vst==1


****looking at trading pairs
preserve
replace status = "ok but zero trade" if trade_share <=10^(-10)
replace status=subinstr(status, " ", "", .)
contract key status
rename _freq nbr_of_
reshape wide nbr_of_, i(key) j(status) string

gen flag_ptrade_incl_fs = 1 if nbr_of_ok !=. | nbr_of_split_failed!=. | nbr_of_okbutzerotrade !=.
gen flag_ptrade_n_fs = 1 if nbr_of_ok !=.
label variable flag_ptrade_incl_fs "Trading pairs, including very small flows and failed splits"
label variable flag_ptrade_n_fs "Trading pairs, excluding"
replace flag_ptrade_incl_fs = 0 if flag_ptrade_incl_fs==.
replace flag_ptrade_n_fs = 0 if flag_ptrade_n_fs==.
table flag_ptrade_n_fs flag_ptrade_incl_fs 
collect export "results/extensive/tradingpairs.txt", as(txt) replace 
restore

******flaging trade
generate flag_trade_incl_fs=1 if (status=="ok" | status=="split_failed") & value !=0
generate flag_trade_n_fs=1 if status=="ok" & trade_share >=10^(-10) 

label variable flag_trade_incl_fs "Trading observations, including very small flows and failed splits"
label variable flag_trade_n_fs "Trading observations, excluding"
foreach trade_type in incl_fs n_fs {
     replace flag_trade_`trade_type'=0 if flag_trade_`trade_type'==.
    bys key : egen flag_trade_`trade_type'_key=max(flag_trade_`trade_type')
    replace flag_trade_`trade_type'_key=0 if flag_trade_`trade_type'_key==.
    tab flag_trade_`trade_type'_key
    codebook undir_pair_key if flag_trade_`trade_type'_key==1
    codebook key if flag_trade_`trade_type'_key==1
}

table flag_trade_n_fs flag_trade_incl_fs 
collect export "results/extensive/tradingobservations.txt", as(txt) replace 


sort undir_pair_key key year
br if key=="10<-R100"


******* Entry and exit trade for actors
bys key: egen nbr_year=count(status)
bys key: egen nbr_trade_year_n_fs=total(flag_trade_n_fs)
label variable nbr_trade_year_n_fs "Trading years, excluding"
bys key: egen nbr_trade_year_incl_fs=total(flag_trade_incl_fs)
label variable nbr_trade_year_incl_fs "Trading years, including very small flows and failed splits"


bys exporterId: egen exporter_start_year=min(year)
bys importerId: egen importer_start_year=min(year)
bys importerId: egen importer_end_year=max(year)
bys exporterId: egen exporter_end_year=max(year)

codebook exporter_start_year
codebook exporter_end_year




***** tag zero_entry

generate zero_year_incl_fs = year if value==0
generate zero_year_n_fs = year if trade_share >= 10^(-10) 
foreach trade_type in incl_fs n_fs {
    replace zero_year_`trade_type'= 0 if zero_year_`trade_type'==.
    bys key : egen zero_entry_`trade_type'=min(zero_year_`trade_type')
}
    
save temp.dta, replace
****** tag trade_entry
use temp.dta, clear
sort year

foreach trade_type in incl_fs n_fs {
    generate trade_year_`trade_type' = year if flag_trade_`trade_type'==1
    bys key : egen trade_entry_`trade_type'=min(trade_year_`trade_type')
}

drop if year >trade_entry_n_fs

bys key : egen pair_entry=min(year)

drop if trade_entry_n_fs==pair_entry

sort undir_pair_key key year


generate flag_trade_entry_incl_fs = 1 if year==trade_entry_incl_fs
generate flag_trade_entry_n_fs = 1 if year==trade_entry_n_fs
replace flag_trade_entry_incl_fs=0 if trade_entry_incl_fs ==. | year < trade_entry_incl_fs
replace flag_trade_entry_n_fs=0 if trade_entry_n_fs ==. | year < trade_entry_n_fs



*****work on duration

***Duration 1 : years of directed pair bexistence before first trade
***Duration 2 : time since appearance
***Duration 3 : time since imputedzero (or very small trade in the n_fs case)

sort key year
by key : gen dur1 = _n
by key : gen dur2 = year-max(exporter_start_year,importer_start_year)+1
by key : gen dur3_incl_fs = year-zero_entry_incl_fs+1
by key : gen dur3_n_fs    = year-zero_entry_n_fs+1

br key year *Label value status pair_entry trade_entry* dur*

save temp.dta, replace



**************************** importation des appartenances communes

use temp.dta, clear
merge m:1 undir_pair_key year  using  save "results/extensive/BestGuessBilTrade.dta", replace
drop _merge

***il ne devrait pas y avoir de _merge==1


sort undir_pair_key key year
capture drop nbr_cyears*
foreach classification in LouvainTibi LouvainProximity IntraMax {
    by undir_pair_key key : generate nbr_cyears_`classification' = sum(common_`classification')
    replace nbr_cyears_`classification' = max(0,nbr_cyears_`classification'-common_`classification')
    by undir_pair_key key : generate share_cyears_`classification' = nbr_cyears_`classification'/(_n-1)
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


******Regression !




xi: cloglog flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi, robust

xi: cloglog flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie, robust

xi: cloglog flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year, robust

xi: logit flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year, robust

xi: probit flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year, robust



 egen key_num = group(key)
drop if key_num==.
xtset key_num year

xtlogit flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year

xtlogit flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year, fe


***Ne marche pas
xi: cloglog flag_trade_entry_n_fs dur1 nbr_cyears_LouvainTibi share_cyears_LouvainTibi /*
    */ ln_dist common_empire /*contig12*/ mid_n atop_allie i.year i.exporterId i.importerId, robust








