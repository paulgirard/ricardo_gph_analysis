cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

/*
***Les blocs en stata
import delimited "data/blocks/gph_blocks_by_year/1833_fob.csv",delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 


generate year = 1833

save temp.dta, replace

*************



import delimited "data/tradeFlows_1833_gravity.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 


gen key = importerId + "-" + exporterId if importerId < exporterId & real(importerId)!=. & real(exporterId)!=.
replace key = exporterId + "-" + importerId if importerId > exporterId & real(importerId)!=. & real(exporterId)!=.
order key

keep if status=="ok"


keep if status=="ok"
generate CafFob="caf" if reportedBy== importerId
replace CafFob="fob" if reportedBy== exporterId
keep if CafFob=="fob"
*/



*merge m:1 key  using temp.dta

capture program drop intra_block_share
program define intra_block_share
	args year CafFob

import delimited "data/blocks/louvain/`year'_fob_enrichi.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 

destring export, replace force
destring import, replace force

*Some GPH hav no IntraMax block, and have "NA" as the block
destring targetBlockIntraMax, replace force
destring sourceBlockIntraMax, replace force

gen pair_trade = export+import
egen tot_trade = total(pair_trade)

foreach block_type in Louvain IntraMax An {
	generate same_`block_type' =1 if sourceBlock`block_type'==targetBlock`block_type'
	replace same_`block_type' = 0 if same_`block_type'==.
	generate intra_trade_`block_type'=pair_trade if same_`block_type' ==1
	egen intra_`block_type'_trade = total (intra_trade_`block_type')
	generate intra_`block_type'_share=intra_`block_type'_trade/tot_trade
}

keep if _n==1
generate CafFob="`CafFob'"
generate year=`year'
keep year CafFob intra_Louvain_share intra_IntraMax_share intra_An_share

if `year' !=1833 {
	append using "results/intra_block_share_`CafFob'.dta"
}

save  "results/intra_block_share_`CafFob'.dta", replace


end

capture erase "results/block_study/intra_block_share_fob.dta"

foreach y of numlist 1833(1)1938 1948(1)2025 {
	intra_block_share `y'  fob
}


export delimited "results/block_study/intra_block_share_fob.csv", replace

tsset year
tsfill, full

twoway (line intra_IntraMax_share year, cmissing(n)) (line intra_Louvain_share year, cmissing(n)) /*
	*/   (line intra_An_share year, cmissing(n)), legend(order(3 "An" 1 "IntraMax" 2 "Louvain") /*
	*/    position(6) rows(1))  ytitle("Intra-block trade share")

graph export "results/block_study/Intra-block trade share.png", replace


