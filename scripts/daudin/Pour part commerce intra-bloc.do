cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"




capture program drop intra_bloc_share
program define intra_bloc_share
	args year 

****We use the trade

import delimited "results/gravity/gravity_`year'.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
gen undir_pair_key = strofreal(importerId) + "-" + strofreal(exporterId) if strofreal(importerId) < strofreal(exporterId) & importerId!=. & exporterId!=.
replace undir_pair_key = strofreal(exporterId) + "-" + strofreal(importerId) if strofreal(importerId) > strofreal(exporterId) & importerId!=. & exporterId!=.
keep undir_pair_key value
merge m:1 undir_pair_key using "results/communities/intra_bloc_pairs_`year'.dta", keep(3)

*Some pairs do not have any trade

egen tot_trade = total(value)

foreach bloc_type in Tibi LouvainMaxtrade LouvainTibirescale IntraMax AN {
	generate intra_trade_`bloc_type'=value if IntraBloc_`bloc_type' ==1
	egen intra_`bloc_type'_trade = total (intra_trade_`bloc_type')
	generate intra_`bloc_type'_share=intra_`bloc_type'_trade/tot_trade
}

keep if _n==1
generate year=`year'
keep  year intra*share

if `year' !=1833 {
	append using "results/bloc_study/intra_bloc_share.dta"
}

save  "results/bloc_study/intra_bloc_share.dta", replace


end

capture erase "results/bloc_study/intra_bloc_share.dta"

intra_bloc_share 1833 


foreach y of numlist 1834(1)1938 1948(1)2025 {
	intra_bloc_share `y'
}


erase source.dta
erase target.dta


export delimited "results/bloc_study/intra_bloc_share.csv", replace



import delimited "results/bloc_study/intra_bloc_share.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
tsset year
tsfill, full

twoway          ///
 		(line intra_Tibi_share               year, cmissing(n) lcolor("213 94 0")    lpattern(dash))                 ///
 		(line intra_AN_share                 year, cmissing(n) lcolor("0 0 0")       lwidth(medthick))                ///
 		(line intra_LouvainTibirescale_share year, cmissing(n) lcolor("204 121 167")  )             ///
 		(line intra_LouvainMaxtrade_share    year, cmissing(n) lcolor("230 159 0")    lpattern(dotdash) lwidth(med)) ///
		(line intra_IntraMax_share           year, cmissing(n) lcolor("0 114 178")   lwidth(medthick)) /*  
	*/  (line intra_LouvainMaxtrade_share year, cmissing(n)) if year <=2026, /*
	*/  legend(order(2 "AN" 5 "IntraMax" 4 "Louvain-trade" 3 "Louvain-TIBI rescale" 1 "Louvain-TIBI") /*
	*/   position(6) rows(2))  ytitle("Intra-bloc trade share") scheme(s2color) /*
	*/   xscale(range(1830 2030)) xlabel(1830(20)2030)

graph export "results/bloc_study/Intra-bloc trade share.png", replace


