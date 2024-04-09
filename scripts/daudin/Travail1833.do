import delimited "/Users/guillaumedaudin/Library/CloudStorage/GoogleDrive-garderie.tapis.saint.michel@gmail.com/.shortcut-targets-by-id/1HMTM4vd6_9bJg2BvSxYkMmx2jxHaiW_2/RICardo_GPH_paper/Flux commerciaux RICardo.csv"
keep if year==1833

drop if strmatch(partner,"*Federico Tena*")==1
drop if strmatch(partner,"*World estimated*")==1
drop if strmatch(partner,"*World_best_guess*")==1
drop if strmatch(partner,"World*")==1

keep partner reporting expimp flow
save "/Users/guillaumedaudin/Library/CloudStorage/GoogleDrive-garderie.tapis.saint.michel@gmail.com/.shortcut-targets-by-id/1HMTM4vd6_9bJg2BvSxYkMmx2jxHaiW_2/RICardo_GPH_paper/1833TradeAllBilateral.dta"
drop if expimp=="Imp"

replace reporting=usubinstr(reporting," ","_",.)
replace reporting=usubinstr(reporting,"&","AND",.)
replace reporting=usubinstr(reporting,"(","_",.)
replace reporting=usubinstr(reporting,".","_",.)
replace reporting=usubinstr(reporting,")","_",.)
replace reporting=usubinstr(reporting,"-","_",.)
replace reporting=usubinstr(reporting,"'","_",.)


replace reporting=usubstr(reporting,1,28)
recast str28 partner, force
reshape wide flow, i(partner) j(reporting) string

export delimited using "/Users/guillaumedaudin/Library/CloudStorage/GoogleDrive-garderie.tapis.saint.michel@gmail.com/.shortcut-targets-by-id/1HMTM4vd6_9bJg2BvSxYkMmx2jxHaiW_2/RICardo_GPH_paper/1833TradeAllBilateralExp.csv", replace

use "/Users/guillaumedaudin/Library/CloudStorage/GoogleDrive-garderie.tapis.saint.michel@gmail.com/.shortcut-targets-by-id/1HMTM4vd6_9bJg2BvSxYkMmx2jxHaiW_2/RICardo_GPH_paper/1833TradeAllBilateral.dta", clear
drop if expimp=="Exp"

replace partner=usubinstr(partner," ","_",.)
replace partner=usubinstr(partner,"&","AND",.)
replace partner=usubinstr(partner,"(","_",.)
replace partner=usubinstr(partner,".","_",.)
replace partner=usubinstr(partner,")","_",.)
replace partner=usubinstr(partner,"-","_",.)
replace partner=usubinstr(partner,"'","_",.)
replace partner=usubstr(partner,1,28)
recast str28 reporting, force
reshape wide flow, i(reporting) j(partner) string

export delimited using "/Users/guillaumedaudin/Library/CloudStorage/GoogleDrive-garderie.tapis.saint.michel@gmail.com/.shortcut-targets-by-id/1HMTM4vd6_9bJg2BvSxYkMmx2jxHaiW_2/RICardo_GPH_paper/1833TradeAllBilateralImp.csv", replace

