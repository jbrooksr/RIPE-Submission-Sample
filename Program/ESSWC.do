// Change row 15 to the local root directory
// =============================================================================
// Author        : Joel Reinecke
// Description   : RIPE submission analysis
// =============================================================================

clear all
set more off
set excelxlsxlargefile on

// =============================================================================
//     FILE PATHS
// =============================================================================

global ROOT		"C:\Users\Joel\Downloads\RIPE Analysis"
global DATA 	"$ROOT\Data"
global OUTPUT	"$ROOT\Output"

global ESS8 		"$DATA\ESS8e02_1_v2.dta"
global GOV_SPEND 	"$DATA\gov_spending.dta"
global FOREIGN 		"$DATA\foreigner.dta"
global REFUGEE 		"$DATA\refugee.dta"
global NET_REPLACE 	"$DATA\net_replacement.dta"
global ALQ 			"$DATA\alq.dta"
global SOCIAL_CONT 	"$DATA\Social_contributions.dta"

// =============================================================================
//		MERGE DATA
// =============================================================================

** Find ESS survey info here: http://nesstar.ess.nsd.uib.no/webview/index.jsp?v=2&submode=abstract&study=http%3A%2F%2F129.177.90.83%3A80%2Fobj%2FfStudy%2FESS8e02.1&mode=documentation&top=yes
use "$ESS8", clear

// Merge macro variables
merge m:m cntry using "$GOV_SPEND", nogen
merge m:m cntry using "$FOREIGN", nogen
merge m:m cntry using "$REFUGEE", nogen
merge m:m cntry using "$NET_REPLACE", nogen
merge m:m cntry using "$ALQ", nogen
merge m:m cntry using "$SOCIAL_CONT", nogen

// =============================================================================
//		CLEAN DATA
// =============================================================================

// % foreigners
gen pforeign = 100*(foreigners_2016/pop_2016)

// Post Communist Dummy
gen post_comm = 0
replace post_comm = 1 if cntry == "CZ" | cntry == "EE" | cntry == "HU" | cntry == "LT" | cntry == "RU" | cntry == "SI"

// Manage macro variables
gen log_gdp = log(gdp_2016)

// Unique country ids for macro regressions
// Make sure that each observation with cntryid == 1 is not missing ubi_chauvcl_pc datum 
encode cntry, gen(cntrynum)

// General welfare preferences PCA
pca sblazy sblwcoa
screeplot
predict pc1, score

gen welpref = .
replace welpref = 1 if pc1 >= 0
replace welpref = 0 if pc1 < 0

gen ubi = .
replace ubi = 1 if basinc == 3 | basinc == 4
replace ubi = 0 if basinc == 1 | basinc == 2

gen ubisb = .
replace ubisb = 1 if ubi == 1 & welpref == 0
replace ubisb = 2 if ubi == 0 & welpref == 0
replace ubisb = 3 if ubi == 0 & welpref == 1
replace ubisb = 4 if ubi == 1 & welpref == 1
label define lbubisb 1 "UBI, not SB" 2 "not UBI, not SB" 3 "not UBI, SB" 4 "UBI, SB"
label values ubisb lbubisb

// Limit sample to UBI supporters; note that this filters out improper merges from above
keep if ubi==1

// Chauvinistic wrt UBI
gen ubi_chauv = .
replace ubi_chauv = 0 if !missing(basinc) & !missing(imsclbn)
replace ubi_chauv = 1 if (basinc == 3 & imsclbn == 4) | (basinc == 3 & imsclbn == 5) | (basinc == 4 & imsclbn == 4) | (basinc == 4 & imsclbn == 5) | (basinc == 3 & imsclbn == 3) | (basinc == 4 & imsclbn == 3)

// Chauvinistic without UBI
gen chauv = .
replace chauv = 0 if !missing(imsclbn)
replace chauv = 1 if imsclbn == 3 | imsclbn == 4 | imsclbn == 5

// Extreme Chauvinism
gen xchauv = . 
replace xchauv = 0 if !missing(imsclbn)
replace xchauv = 1 if imsclbn == 5

// Chauvinistic wrt General Preferences
gen gen_chauv = .
replace gen_chauv = 0 if !missing(welpref) & !missing(imsclbn)
replace gen_chauv = 1 if (welpref == 1 & imsclbn == 4) | (welpref == 1 & imsclbn == 5) | (welpref == 1 & imsclbn == 3) 

// Identify problem cases
gen prob_case = .
replace prob_case = 0 if !missing(ubi_chauv) & !missing(gen_chauv)
replace prob_case = 1 if gen_chauv == 1 & ubi_chauv == 0
replace prob_case = 2 if gen_chauv == 0 & ubi_chauv == 1

// Reciprocity index
gen recipro = .
replace recipro = 0 if !missing(imsclbn) & !missing(basinc)
replace recipro = 1 if imsclbn == 3 & (basinc == 3 | basinc == 4)
 
// Citizenship index
gen citlim = .
replace citlim = 0 if !missing(imsclbn) & !missing(basinc)
replace citlim = 1 if imsclbn == 4 & (basinc == 3 | basinc == 4)

// Hardcore chauvinist index
gen hcchauv = .
replace hcchauv = 0 if !missing(imsclbn) & !missing(basinc)
replace hcchauv = 1 if imsclbn == 5 & (basinc == 3 | basinc == 4)

tab ubi_chauv
tab recipro
tab citlim
tab hcchauv
 
// Recode unintuitive variable scales
// Justice vars
label define agree_scale 1 "Disagree strongly" 2 "Disagree" 3 "Neither agree nor disagree" 4 "Agree" 5 "Agree strongly"
replace smdfslv = 6-smdfslv
label values smdfslv agree_scale
replace dfincac = 6-dfincac
label values dfincac agree_scale
// Feelings about income
label define inc_feel 1 "Very difficult on present income" 2 "Difficult on present income" 3 "Coping on present income" 4 "Living comfortably on present income"
replace hincfel = 5-hincfel
label values hincfel inc_feel
// Feelings about employment 
gen empsec = .
replace empsec = 1 if lkuemp == 4 | lkuemp == 55
replace empsec = 2 if lkuemp == 3
replace empsec = 3 if lkuemp == 2 
replace empsec = 4 if lkuemp == 1 
label define lbempsec 1 "unemployment very likely" 2 "unemployment likely" 3 "unemployment unlikely" 4 "unemployment very unlikely"
label values empsec lbempsec

gen quintile = .
replace quintile = 1 if hinctnta == 1 |  hinctnta == 2 
replace quintile = 2 if hinctnta == 3 |  hinctnta == 4 
replace quintile = 3 if hinctnta == 5 |  hinctnta == 6 
replace quintile = 4 if hinctnta == 7 |  hinctnta == 8 
replace quintile = 5 if hinctnta == 9 |  hinctnta == 10 

gen bildung = .
replace bildung = 0 if eisced == 1 | eisced == 2
replace bildung = 1 if eisced == 3 | eisced == 4
replace bildung = 2 if eisced == 5
replace bildung = 3 if eisced == 6 | eisced == 7
label define lbbildung 0 "primary education" 1 "secondary education" 2 "post-secondary education" 3 "tertiary education"
label values bildung lbbildung

gen erwerb = .
replace erwerb = 0 if mnactic == 1
replace erwerb = 1 if mnactic == 3 | mnactic == 4
replace erwerb = 2 if mnactic == 6
replace erwerb = 3 if mnactic == 2 
replace erwerb = 4 if mnactic == 5 | mnactic == 8 | mnactic == 9
label define lberwerb 0 "Employed" 1 "Unemployed" 2 "Retired" 3 "Student" 4 "Other"
label values erwerb lberwerb

encode cntry, gen(c_id)

gen migr_backgr=0 if facntr==1 & mocntr==1
replace migr_backgr=1 if facntr==2 | mocntr==2
by cntry, sort: egen migrcl = mean(migr_backgr)

// Identify variables to be included in regression
keep if !missing(soc_sec_tax) & !missing(ubi_chauv) & !missing(gndr) & !missing(agea) & !missing(migr_back) & !missing(cntrynum) & !missing(imueclt) & !missing(imbgeco) & !missing(smdfslv) & !missing(dfincac) & !missing(quintile) & !missing(bildung) & !missing(erwerb) & !missing(empsec) & !missing(hincfel) & !missing(log_gdp) & !missing(soc_gdp_2016) & !missing(pforeign) & !missing(post_comm)

sort cntry
by cntry: gen cntryid = 1 if _n == 1 

// Create standardized variables
local stdvars soc_sec_tax imueclt imbgeco smdfslv dfincac quintile bildung erwerb empsec hincfel log_gdp soc_gdp_2016 pforeign
foreach v of local stdvars {
	di "`v'"
	egen std_`v' = std(`v')
}
// Chauvinism Index
by cntry, sort: egen basinccl = mean(basinc)
by cntry, sort: egen imsclbncl = mean(imsclbn)
by cntry, sort: egen ubi_chauvcl = mean(ubi_chauv)

// Country-level chauvinism index without problem cases
gen ubi_chauvcl_pc = .
levelsof cntry, local(countries)
foreach c of local countries {
	summ(ubi_chauv) if prob_case == 0 & cntry == "`c'"
	local val = r(mean) 
	replace ubi_chauvcl_pc = `val' if cntry == "`c'"
}

// Macro variables for Subjective Preferences
// Immigration Preferences
by cntry, sort: egen imsmetncl = mean(imsmetn)
by cntry, sort: egen imdfetncl = mean(imdfetn)
by cntry, sort: egen imuecltcl = mean(imueclt)
by cntry, sort: egen imbgecocl = mean(imbgeco)
by cntry, sort: egen imwbcntcl = mean(imwbcnt)
// Justice Preferences
by cntry, sort: egen ipeqoptcl = mean(ipeqopt)
by cntry, sort: egen dfincaccl = mean(dfincac)
by cntry, sort: egen smdfslvcl = mean(smdfslv)

// =============================================================================
//		DATA EXPLORATION
// =============================================================================

// Reinecke reference
cd "$OUTPUT"
// Scatterplot of index by country
scatter imsclbncl basinccl if cntryid == 1 & cntry != "IT" & cntry != "NL" & cntry != "LT", mlabel(cntry) mcolor(navy) mlabcolor(navy) || scatter imsclbncl basinccl if cntryid == 1 & cntry == "IT", mlabel(cntry) mlabposition(4) mcolor(navy) mlabcolor(navy) ///
|| scatter imsclbncl basinccl if cntryid == 1 & cntry == "LT", mlabel(cntry) mlabposition(9) mcolor(navy) mlabcolor(navy) || scatter imsclbncl basinccl if cntryid == 1 & cntry == "NL", mlabel(cntry) mlabposition(11) mcolor(navy) mlabcolor(navy) xtitle(UBI Preferences) ytitle(Extension to Immigrants) legend(off)
graph export Country_Level_Index_Scatter.png, replace
graph hbar ubi_chauvcl if cntryid == 1, over(cntry, sort(1)) ytitle(UBI Chauvinism Index)
graph export Country_Level_Index_Bar.png, replace

// Label variables
// Individual Level
label variable imwbcnt "Effect of Immigration"
label variable imueclt "Cultural Benefit of Immigration"
label variable imbgeco "Economic Benefit of Immigration"
label variable smdfslv "Egalitarianism"
label variable dfincac "Consequentialism"
label variable quintile "Income"
label variable bildung "Education"
label variable erwerb "Employment"
label variable empsec "Perception of Employment Security"
label variable hincfel "Perception of Income"
label variable migr_backgr "Familial Immigration Status"
label variable agea "Age of Respondent"
label variable gndr "Gender of Respondent (Female)"
// Country Level
label variable imwbcntcl "Effect of Immigration"
label variable dfincaccl "Consequentialism"
label variable smdfslvcl "Egalitarianism"
label variable gdp_2016 "National Income (GDP)"
label variable log_gdp "log(National Income (GDP))"
label variable soc_gdp_2016 "Social Spending (% of GDP)"
label variable foreigners_2016 "Foreign Population"
label variable pforeign "Foreign Population (%)"
label variable migrcl "Immigration"
label variable post_comm "Post Communist Indicator"

// Label Standardized Variables
label variable std_soc_sec_tax "Social Security contributions as % of total taxation, 2016"
label variable std_imueclt "Cultural Benefit of Immigration"
label variable std_imbgeco "Economic Benefit of Immigration"
label variable std_smdfslv "Egalitarianism"
label variable std_dfincac "Consequentialism"
label variable std_quintile "Income"
label variable std_bildung "Education"
label variable std_erwerb "Perception of Employment Security"
label variable std_empsec "Perception of Employment Security"
label variable std_hincfel "Perception of Income"
label variable std_log_gdp "log(National Income (GDP))"
label variable std_soc_gdp_2016 "Social Spending (% of GDP)"
label variable std_pforeign "Foreign Population (%)"

// Summary statistics for relevant variables
eststo clear
estpost summ basinc imsclbn imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung erwerb gndr migr_back post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp, detail
esttab using "$OUTPUT\Welfare Chauvinism Summary Statistics.rtf", cells("mean Var sd min max p50 count") replace
eststo clear

fsum basinc imsclbn imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung erwerb gndr migr_back post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp, stats(mean vari sd min max median n) varname uselabel

// =============================================================================
//		REGRESSIONS
// =============================================================================

// DIFFERENT INDICES
**** USED IN EMPIRICAL SECTION OF PAPER ****

// Regressions with different components of chauvinism index
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDI.xls, excel dec(3) replace label ctitle(Cumulative Index)

// Add column for other index to test reciprocity hypothesis (H2)
logit recipro imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDI.xls, excel dec(3) append label ctitle(Reciprocity Index)

logit citlim imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDI.xls, excel dec(3) append label ctitle(Citizenship Index)

logit hcchauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDI.xls, excel dec(3) append label ctitle(Extreme Chauvinism Index)

// DIFFERENT INDICES STANDARDIZED

// Regressions with different components of chauvinism index
logit ubi_chauv std_imueclt std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDISTD.xls, excel dec(3) replace label ctitle(Cumulative Index)

// Add column for other index to test reciprocity hypothesis (H2)
logit recipro std_imueclt std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDISTD.xls, excel dec(3) append label ctitle(Reciprocity Index)

logit citlim std_imueclt std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDISTD.xls, excel dec(3) append label ctitle(Citizenship Index)

logit hcchauv std_imueclt std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesDISTD.xls, excel dec(3) append label ctitle(Extreme Chauvinism Index)

// CHAUVINISM INDEX

// Individual Level Hypotheses
**** USED IN EMPIRICAL SECTION OF PAPER ****

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypotheses.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypotheses.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypotheses.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypotheses.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypotheses.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// Hypothesis 4
reg ubi_chauvcl soc_gdp_2016 pforeign if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) replace label ctitle(Baseline)
// Post-comm control
reg ubi_chauvcl soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) append label ctitle(Income Effects)
// Country income control
reg ubi_chauvcl dfincaccl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) append label ctitle(Justice Effects)
// Egalitarianism control
reg ubi_chauvcl smdfslvcl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) append label ctitle(Immigration Attitude Effects)
// Consequentialism control
reg ubi_chauvcl dfincaccl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) append label ctitle(Immigration Attitude Effects)
// Immigration control
reg ubi_chauvcl imwbcntcl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypotheses.xls, excel dec(3) append label ctitle(Immigration Attitude Effects)

// CHAUVINISM INDEX WITH STANDARDIZED COEFFICIENTS 
// Note: cannot use pweights with standardized coefficients
// Individual Level Hypotheses

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesSTD.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesSTD.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesSTD.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesSTD.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv std_imueclt std_imbgeco std_smdfslv std_dfincac std_hincfel std_empsec std_quintile std_bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesSTD.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// CHAUVINISM INDEX WITH CONTEXTUAL CONTROLS 
**** USED IN EMPIRICAL SECTION OF PAPER ****

* Baseline
melogit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country) 
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) replace label ctitle(Baseline)
* Effect of national income
melogit ubi_chauv log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) append label ctitle(National Income)

* Control for social spending as a percent of GDP
melogit ubi_chauv soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) append label ctitle(Social Spending)
* Control for social spending as a percent of taxation
melogit ubi_chauv soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) append label ctitle(Taxes spent on Social Spending)

* Control for the foreign population share
melogit ubi_chauv pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) append label ctitle(Foreign Population)

* Control for whether each country is post-communist
melogit ubi_chauv post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCCM.xls, excel dec(3) append label ctitle(Post Communist)

// Individual controls for gender, age, migration background, country

/*
// 1. RECIPROCITY INDEX
* Baseline
melogit recipro imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) replace label ctitle(Reciprocity Index)
* Effect of national income
melogit recipro log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) append label ctitle(National Income)
* Control for social spending as a percent of GDP
melogit recipro soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) append label ctitle(Social Spending)
* Control for social spending as a percent of taxation
melogit recipro soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) append label ctitle(Taxes spent on Social Spending)
* Control for the foreign population share
melogit recipro pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) append label ctitle(Foreign Population)
* Control for whether each country is post-communist
melogit recipro post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesRI.xls, excel dec(3) append label ctitle(Post Communist)

// 2. CITIZENSHIP INDEX
* Baseline
melogit citlim imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) replace label ctitle(Citizenship Index)
* Effect of national income
melogit citlim log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) append label ctitle(National Income)
* Control for social spending as a percent of GDP
melogit citlim soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) append label ctitle(Social Spending)
* Control for social spending as a percent of taxation
melogit citlim soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) append label ctitle(Taxes spent on Social Spending)
* Control for the foreign population share
melogit citlim pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) append label ctitle(Foreign Population)
* Control for whether each country is post-communist
melogit citlim post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCI.xls, excel dec(3) append label ctitle(Post Communist)

// 3. HARDCORE CHAUVINISM INDEX
* Baseline
melogit hcchauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) replace label ctitle(Extreme Chauvinism Index)
* Effect of national income
melogit hcchauv log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) append label ctitle(National Income)
* Control for social spending as a percent of GDP
melogit hcchauv soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) append label ctitle(Social Spending)
* Control for social spending as a percent of taxation
melogit hcchauv soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) append label ctitle(Taxes spent on Social Spending)
* Control for the foreign population share
melogit hcchauv pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) append label ctitle(Foreign Population)
* Control for whether each country is post-communist
melogit hcchauv post_comm pforeign soc_sec_tax soc_gdp_2016 log_gdp imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea log_gdp soc_gdp_2016 soc_sec_tax pforeign || country:, vce(cluster country)
outreg2 using Chauvinism_IndHypothesesHCI.xls, excel dec(3) append label ctitle(Post Communist)
*/

// CHAUVINISM INDEX CONTROL PROBLEM CASES

// Individual Level Hypotheses

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum i.prob_case  [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesPC.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesPC.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesPC.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesPC.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesPC.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// CHAUVINISM INDEX CONTROL PROBLEM CASES and CONTEXTUAL CONTROLS

// Individual Level Hypotheses

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCPC.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCPC.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCPC.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCPC.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm i.prob_case [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCPC.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// CHAUVINISM INDEX without PROBLEM CASES

// Individual Level Hypotheses

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesWOPC.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesWOPC.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesWOPC.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesWOPC.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesWOPC.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// Hypothesis 4
reg ubi_chauvcl_pc soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypothesesWOPC.xls, excel dec(3) replace label ctitle(Baseline)
// Country income controls
reg ubi_chauvcl_pc log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypothesesWOPC.xls, excel dec(3) append label ctitle(Income Effects)
// Country justice controls
reg ubi_chauvcl_pc dfincaccl smdfslvcl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypothesesWOPC.xls, excel dec(3) append label ctitle(Justice Effects)
// Country immigration attitudes controls
reg ubi_chauvcl_pc imwbcntcl dfincaccl smdfslvcl log_gdp soc_gdp_2016 pforeign post_comm if cntryid == 1 [pw=pspwght]
outreg2 using Chauvinism_CntryHypothesesWOPC.xls, excel dec(3) append label ctitle(Immigration Attitude Effects)

// CHAUVINISM INDEX WITH CONTEXTUAL CONTROLS and without PROBLEM CASES

// Individual Level Hypotheses

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCWOPC.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCWOPC.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)

// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCWOPC.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCWOPC.xls, excel dec(3) append label ctitle(Economic Consequences)

// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum log_gdp soc_gdp_2016 c.soc_gdp_2016#c.imbgecocl c.soc_gdp_2016#c.imuecltcl soc_sec_tax pforeign post_comm if prob_case == 0 [pw=pspwght]
outreg2 using Chauvinism_IndHypothesesCCWOPC.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Individual controls for gender, age, migration background, country

// =============================================================================
//		ROBUSTNESS CHECKS
// =============================================================================

// Exclude UBI Supporters

// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi_chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if basinc == 3 | basinc == 4 [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesWOB.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi_chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if basinc == 3 | basinc == 4 [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesWOB.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)
// Hypothesis 2
* Control for justice preferences
logit ubi_chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if basinc == 3 | basinc == 4 [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesWOB.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi_chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if basinc == 3 | basinc == 4 [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesWOB.xls, excel dec(3) append label ctitle(Economic Consequences)
// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi_chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum if basinc == 3 | basinc == 4 [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesWOB.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Run models (2) with components of index as dependent variables

// 1.imsclbn indicator (== 3, 4, or 5) as dependent var
// Individual Level Hypotheses
// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit chauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCHAUV.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit chauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCHAUV.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)
// Hypothesis 2
* Control for justice preferences
logit chauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCHAUV.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit chauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCHAUV.xls, excel dec(3) append label ctitle(Economic Consequences)
// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit chauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesCHAUV.xls, excel dec(3) append label ctitle(Cultural Consequences)

// 2. basinc indicator (== 3 or 4) as dependent var
// Individual Level Hypotheses
// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit ubi quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesUBI.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit ubi hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesUBI.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)
// Hypothesis 2
* Control for justice preferences
logit ubi smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesUBI.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit ubi imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesUBI.xls, excel dec(3) append label ctitle(Economic Consequences)
// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit ubi imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesUBI.xls, excel dec(3) append label ctitle(Cultural Consequences)

// Run models with only extreme chauvinists as dependent variable (don't include basinc in index)
// Individual Level Hypotheses
// Hypothesis 1
* Effect of socioeconomic status without accounting for perception of individual status
logit xchauv quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesX.xls, excel dec(3) replace label ctitle(Socioeconomic Status)
* Effect of socioeconomic status with accounting for perception of individual status
logit xchauv hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesX.xls, excel dec(3) append label ctitle(Perception of Socioeconomic Status)
// Hypothesis 2
* Control for justice preferences
logit xchauv smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesX.xls, excel dec(3) append label ctitle(Justice)
* Effect of preferences regarding economic effect of immigrants
logit xchauv imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesX.xls, excel dec(3) append label ctitle(Economic Consequences)
// Hypothesis 3
* Effect of preferences regarding cultural effect of immigrants
logit xchauv imueclt imbgeco smdfslv dfincac hincfel empsec quintile bildung i.erwerb gndr migr_back c.agea##c.agea i.cntrynum [pw=pspwght], vce(cluster country)
outreg2 using Chauvinism_IndHypothesesX.xls, excel dec(3) append label ctitle(Cultural Consequences)
