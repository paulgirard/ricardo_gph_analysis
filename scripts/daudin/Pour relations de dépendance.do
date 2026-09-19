cd "/Users/guillaumedaudin/Répertoires Git/ricardo_gph_analysis"
global dirGeoPolHist "/Users/guillaumedaudin/Répertoires Git/GeoPolHist"


************Importation des relations géopolitiques
import delimited "$dirGeoPolHist/data/GeoPolHist_entities_status_over_time.csv", /*
	*/delimiter(comma) bindquote(strict) varnames(1) case(preserve) encoding(UTF-8) maxquotedrows(100) clear

replace start_year="1800" if start_year=="?"
destring(start_year), gen(start_year_num)
drop start_year
rename start_year_num start_year


///We keep only dependency relations, excluding those that lead to an aggregation in the network


/////Mieux faire la jointure avec les statuts


keep if GPH_status=="Associated state of" | GPH_status=="Colony of" | GPH_status=="Dependency of" ///
		| GPH_status=="Protectorate of" | GPH_status=="Vassal of"


gen common_empire=1

save GeoPolHist_entities_status_over_time_temp.dta, replace

tostring(GPH_code), replace
tostring(sovereign_GPH_code), replace
gen key= GPH_code+"-"+ sovereign_GPH_code if GPH_code < sovereign_GPH_code
replace key =sovereign_GPH_code+"-"+ GPH_code if GPH_code > sovereign_GPH_code
order key
sort key
gen nyears = end_year - start_year + 1
expand nyears
bysort key: gen year = start_year + _n - 1
drop nyears
drop start_year end_year GPH_name sovereign_GPH_code

bysort key year: egen max=max(common_empire)
bysort key year: egen min=min(common_empire)
assert max==min
drop max min
bysort key year: keep if _n==1

drop GPH_code GPH_status

save "external data/dependency_relations.dta", replace
export delimited using "external data/dependency_relations.csv", replace delimiter(",") quote
