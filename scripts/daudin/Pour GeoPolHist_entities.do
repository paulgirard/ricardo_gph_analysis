clear

cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"



import delimited "$dirGeoPolHist/data/GeoPolHist_entities.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear 

    keep GPH_code GPH_name
save "external data/GeoPolHist_entities.dta", replace