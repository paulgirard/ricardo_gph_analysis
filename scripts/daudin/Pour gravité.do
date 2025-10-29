cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"


import delimited "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis/data/tradeFlows.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

tempfile tradeFlows
save `tradeFlows', replace

