cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

****First, we adapt BlocselonAN

import delimited "external data/BlocselonAN.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 
save "external data/BlocselonAN.dta", replace
rename GPH_code id
rename region_AndersonNorheim blockAN
keep id blockAN
save BlocselonAN_temp.dta, replace


capture program drop intra_bloc_pairs
program define intra_bloc_pairs
	args year

****We import the relevant blocs for the year
import delimited "results/communities/gph_blocks_by_year/`year'.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 


rename blockLouvainMaxobservedtradevalu blockLouvainMaxtrade
drop label
drop blockAN
merge 1:1 id using BlocselonAN_temp.dta, keep(1 3)
assert _merge==3
drop _merge


**We create the undi_pairs

foreach dir in source target {
	preserve
	rename id `dir'
	rename block* `dir'_block*
	save `dir'.dta, replace
	restore
}

use source.dta, clear
cross using target.dta



drop if source==target
gen undir_pair_key = strofreal(source) + "-" + strofreal(target) if strofreal(source) < strofreal(target) & source!=. & target!=.
replace undir_pair_key = strofreal(target) + "-" + strofreal(source) if strofreal(source) > strofreal(target) & source!=. & target!=.
order undir_pair_key

bys undir_pair_key : drop if _n>=2

**We identify the intra-bloc ones

foreach part in Tibi LouvainMaxtrade LouvainTibirescale IntraMax AN {
	gen IntraBloc_`part'= 0
	replace IntraBloc_`part'= 1 if source_block`part'== target_block`part'

}

save "results/communities/intra_bloc_pairs_`year'.dta", replace

end 

intra_bloc_pairs 1833

foreach y of numlist 1834(1)1938 1948(1)2025 {
	intra_bloc_pairs `y'
}


global yearlist "1833(1)1938 1948(1)2025"

capture erase "results/extensive/BestGuessBilTrade.dta"

foreach year of numlist $yearlist {
    
    use "results/communities/intra_bloc_pairs_`year'.dta"
    if year !=1833 append using "results/communities/intra_bloc_pairs.dta"
    save "results/communities/intra_bloc_pairs.dta", replace

}

sort year 
save "results/communities/intra_bloc_pairs.dta", replace
