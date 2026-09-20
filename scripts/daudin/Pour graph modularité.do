cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"

import delimited using "data/blocks/modularities_by_year.csv", delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 


keep if cafFob=="fob"

tsset year
tsfill, full

twoway (line intramax_modularit year, cmissing(n)) (line louvain_modularity year, cmissing(n)) /*
	*/   (line an_modularity year, cmissing(n)), legend(order(3 "An" 1 "IntraMax" 2 "Louvain") /*
	*/    position(6) rows(1))  ytitle("Modularity")

graph export "results/block_study/Modularity.png", replace

