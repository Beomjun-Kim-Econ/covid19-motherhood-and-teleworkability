*******************************************************
* 12_DiD_telework_married_mothers_telework_unmarried_childless_women.do
*
* 추가 분석
* 2019년 재택가능 직종에서 일한 여성 중
* 혼인 어머니와 미혼 무자녀 여성을 비교한다.
*
* 모든 표와 그림의 결과변수 순서
* 1. 로그 시간당 임금
* 2. 로그 주당 근로시간
* 3. 로그 주간 근로소득
*
* 각 결과변수에 대해 비가중 회귀와 가중 회귀를 모두 실행한다.
*
* marital_status의 코드
* 1: 미혼
* 2: 유배우
*******************************************************

version 17.0
clear all
set more off
set scheme s2color

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women"

capture which reghdfe
if _rc != 0 {
    display as error "reghdfe가 필요합니다. Stata에서 ssc install reghdfe를 먼저 실행하세요."
    exit 199
}

capture which esttab
if _rc != 0 {
    display as error "esttab이 필요합니다. Stata에서 ssc install estout을 먼저 실행하세요."
    exit 199
}

capture which coefplot
if _rc != 0 {
    display as error "coefplot이 필요합니다. Stata에서 ssc install coefplot을 먼저 실행하세요."
    exit 199
}

use "output/F2_clean_panel/F2_klips_panel_19_27_clean.dta", clear

*******************************************************
* 1. 결과변수 만들기
*******************************************************

* 취업 여부는 주당 정규근로시간이 양수인지로 판단한다.
gen byte employed = regular_hours_week > 0 & regular_hours_week < .

gen double ln_hours = ln(regular_hours_week) ///
    if regular_hours_week > 0 & regular_hours_week < .

gen double ln_weekly_income = ln(weekly_labor_income) ///
    if weekly_labor_income > 0 & weekly_labor_income < .

gen double hourly_wage = weekly_labor_income / regular_hours_week ///
    if weekly_labor_income > 0 & regular_hours_week > 0

gen double ln_hourly_wage = ln(hourly_wage) ///
    if hourly_wage > 0 & hourly_wage < .

*******************************************************
* 2. 2020-2022년 계속 취업자 표본 만들기
*******************************************************

* 세 해가 모두 관측되고, 세 해 모두 취업한 사람만 남긴다.
* 이렇게 만든 동일한 개인 표본을 사전기간과 사후기간에 모두 사용한다.
preserve
    keep if inrange(survey_year, 2020, 2022)
    collapse (count) observed_years=survey_year ///
        (sum) employed_years=employed, by(pid)

    keep if observed_years == 3
    keep if employed_years == 3

    gen byte employed_all_2020_2022 = 1
    keep pid employed_all_2020_2022

    save ///
        "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_employed_2020_2022.dta", ///
        replace
restore

merge m:1 pid using ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_employed_2020_2022.dta", ///
    keep(3) nogen

*******************************************************
* 3. 2019년 기준 분석집단 만들기
*******************************************************

* 코로나 이후 혼인상태, 자녀 여부, 직업이 바뀌어도
* 비교집단이 바뀌지 않도록 모든 집단 특성을 2019년에 고정한다.
preserve
    keep if survey_year == 2019
    keep if sex == 0
    keep if if_remote_possible == 1

    * 비교집단은 미혼이면서 자녀가 없는 여성이다.
    gen byte comparison_group2019 = ///
        marital_status == 1 & if_child == 0

    * 처리집단은 혼인상태이고 자녀가 있는 여성이다.
    gen byte treatment_group2019 = ///
        marital_status == 2 & if_child == 1

    * 두 비교집단 중 하나에 해당하는 여성만 남긴다.
    keep if comparison_group2019 == 1 | treatment_group2019 == 1

    * 어머니=1, 미혼 무자녀 여성=0인 분석용 변수를 만든다.
    gen byte mother2019 = treatment_group2019

    gen long occ2019 = occupation_ksco7
    gen long ind2019 = industry_ksic10
    gen int region2019 = region

    replace occ2019 = . if occ2019 < 0
    replace ind2019 = . if ind2019 < 0
    replace region2019 = . if region2019 < 0

    gen double person_wgt2019 = person_wgt_cross_18
    replace person_wgt2019 = person_wgt_cross_09 if missing(person_wgt2019)
    replace person_wgt2019 = person_wgt_cross_98 if missing(person_wgt2019)
    replace person_wgt2019 = 1 if missing(person_wgt2019) | person_wgt2019 <= 0

    keep pid mother2019 occ2019 ind2019 region2019 person_wgt2019
    duplicates drop pid, force

    save ///
        "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_baseline_2019.dta", ///
        replace
restore

merge m:1 pid using ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_baseline_2019.dta", ///
    keep(3) nogen

xtset pid survey_year

*******************************************************
* 4. DiD의 사전기간과 사후기간 만들기
*******************************************************

* 사전기간은 2016-2019년, 사후기간은 2021-2022년이다.
* 코로나19가 처음 시작된 2020년은 평균 DiD에서 제외한다.
gen byte post2021_2022 = .
replace post2021_2022 = 0 if inrange(survey_year, 2016, 2019)
replace post2021_2022 = 1 if inrange(survey_year, 2021, 2022)

label define post2021_2022_label 0 "2016-2019년" 1 "2021-2022년"
label values post2021_2022 post2021_2022_label

assert inrange(survey_year, 2016, 2022)

capture log close
log using ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_01_tests.log", ///
    text replace

tabulate mother2019 if survey_year == 2019

*******************************************************
* 5. Event study: 시간당 임금
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
* 추정내용: 2019년 대비 연도별 로그 시간당 임금 변화 차이
reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hourly_event_u

display as text "비가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hourly_event_w

display as text "가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

*******************************************************
* 5. Event study: 근로시간
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
* 추정내용: 2019년 대비 연도별 로그 주당 근로시간 변화 차이
reghdfe ln_hours i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hours_event_u

display as text "비가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hours i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hours_event_w

display as text "가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

*******************************************************
* 6. Event study: 주간 근로소득
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
* 추정내용: 2019년 대비 연도별 로그 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_weekly_event_u

display as text "비가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_weekly_income i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_weekly_event_w

display as text "가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

* 세 결과변수의 event study를 한 표에 정리한다.
esttab S_F12_hourly_event_u S_F12_hourly_event_w ///
    S_F12_hours_event_u S_F12_hours_event_w ///
    S_F12_weekly_event_u S_F12_weekly_event_w ///
    using ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_02_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("재택가능 혼인 어머니-미혼 무자녀 여성 event study")

* 시간당 임금 event study 그림
coefplot ///
    (S_F12_hourly_event_u, label("비가중")) ///
    (S_F12_hourly_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-미혼 여성 로그 시간당 임금 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 시간당 임금 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_03_hourly_wage_event_study.png", ///
    width(2000) replace

* 근로시간 event study 그림
coefplot ///
    (S_F12_hours_event_u, label("비가중")) ///
    (S_F12_hours_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-미혼 여성 로그 근로시간 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 근로시간 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_04_hours_event_study.png", ///
    width(2000) replace

* 주간 근로소득 event study 그림
coefplot ///
    (S_F12_weekly_event_u, label("비가중")) ///
    (S_F12_weekly_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-미혼 여성 로그 주간소득 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 주간소득 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_05_weekly_income_event_study.png", ///
    width(2000) replace

*******************************************************
* 7. 평균 DiD: 세 결과변수 × 비가중/가중
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
* 추정내용: 2016-2019년 대비 2021-2022년의 시간당 임금 변화 차이
reghdfe ln_hourly_wage i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hourly_did_u

reghdfe ln_hourly_wage i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hourly_did_w

* 비교대상은 같고 결과변수만 로그 주당 근로시간으로 바꾼다.
reghdfe ln_hours i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hours_did_u

reghdfe ln_hours i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_hours_did_w

* 비교대상은 같고 결과변수만 로그 주간 근로소득으로 바꾼다.
reghdfe ln_weekly_income i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_weekly_did_u

reghdfe ln_weekly_income i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F12_weekly_did_w

esttab S_F12_hourly_did_u S_F12_hourly_did_w ///
    S_F12_hours_did_u S_F12_hours_did_w ///
    S_F12_weekly_did_u S_F12_weekly_did_w ///
    using ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_06_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 "어머니 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("재택가능 혼인 어머니-미혼 무자녀 여성 평균 DiD")

coefplot ///
    (S_F12_hourly_did_u, label("시간당 임금 비가중")) ///
    (S_F12_hourly_did_w, label("시간당 임금 가중")) ///
    (S_F12_hours_did_u, label("근로시간 비가중")) ///
    (S_F12_hours_did_w, label("근로시간 가중")) ///
    (S_F12_weekly_did_u, label("주간소득 비가중")) ///
    (S_F12_weekly_did_w, label("주간소득 가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 혼인 어머니-미혼 무자녀 여성 평균 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") legend(rows(2))

graph export ///
    "output/S_F12_DiD_telework_married_mothers_telework_unmarried_childless_women/S_F12_07_did_coefficients.png", ///
    width(2000) replace

log close
display as result "S_F12 추가 DiD 분석이 완성되었습니다."
