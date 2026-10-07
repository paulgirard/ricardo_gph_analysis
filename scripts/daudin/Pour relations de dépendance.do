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


gen sub_empire=1

save GeoPolHist_entities_status_over_time_temp.dta, replace

tostring(GPH_code), replace
tostring(sovereign_GPH_code), replace
gen undir_pair_key= GPH_code+"-"+ sovereign_GPH_code if GPH_code < sovereign_GPH_code
replace undir_pair_key =sovereign_GPH_code+"-"+ GPH_code if GPH_code > sovereign_GPH_code
order undir_pair_key
sort undir_pair_key
gen nyears = end_year - start_year + 1
expand nyears
bysort undir_pair_key GPH_status start_year end_year : gen year = start_year + _n - 1

drop nyears
drop start_year end_year GPH_name 

bysort undir_pair_key year: egen max=max(sub_empire)
bysort undir_pair_key year: egen min=min(sub_empire)
assert max==min
drop max min
bysort undir_pair_key year: keep if _n==1

export delimited using "external data/Controls panel/dependency_relations.csv", replace delimiter(",") quote
save  "external data/Controls panel/dependency_relations.dta", replace




*******Pour common empire
capture erase "external data/Controls panel/commonempire.dta"

foreach year of numlist 1833(1)1938 1948(1)2022 {
  use  "external data/Controls panel/dependency_relations.dta", clear
  keep if year==`year'
  rename sovereign_GPH_code importerId
  rename GPH_code exporterId
  keep importerId exporterId
  save temp.dat, replace
  use  "external data/Controls panel/dependency_relations.dta", clear
  keep if year==`year'
  rename sovereign_GPH_code exporterId
  rename GPH_code importerId
  keep  exporterId importerId
  append using temp.dat
  fillin exporterId importerId
  drop if exporterId==importerId
  gen year = `year'

  gen undir_pair_key= exporterId+"-"+ importerId  if exporterId < importerId
  replace undir_pair_key=importerId+"-"+ exporterId if importerId < exporterId
  bys undir_pair_key : keep if _n==1
  
  merge m:1 undir_pair_key year using "external data/Controls panel/dependency_relations.dta", keep(1 3)
  replace sub_empire=0 if sub_empire==.
  drop _merge GPH_code GPH_status sovereign_GPH_code

  recast str2045 importerId
  rename importerId GPH_code
  merge m:m GPH_code year using "external data/Controls panel/dependency_relations.dta", keep(1 3)
  rename sovereign_GPH_code importerId_sov
  drop _merge
  rename GPH_code importerId 

  recast str2045 exporterId
  rename exporterId GPH_code
  merge m:m GPH_code year using "external data/Controls panel/dependency_relations.dta", keep(1 3)
  rename sovereign_GPH_code exporterId_sov
  drop _merge
  rename GPH_code exporterId


  generate common_empire=1 if importerId_sov==exporterId_sov & importerId_sov!=""
  replace common_empire=0 if common_empire==.
  bysort importerId exporterId : egen max=max(common_empire)
  bysort importerId exporterId : replace common_empire = max
  bysort importerId exporterId : keep if _n==1
  drop max
  bysort importerId exporterId : assert  _N==1
  ***Il y a des cas de GHP qui a plusieurs souverains.  (eg Samoa 1889-1900)
  *Cracow dès 1833

  replace common_empire=1 if sub_empire==1
  drop if common_empire !=1
  keep year undir_pair_key common_empire
  capture append using "external data/Controls panel/commonempire.dta"
  save "external data/Controls panel/commonempire.dta", replace
}

export delimited "external data/Controls panel/commonempire.csv", replace