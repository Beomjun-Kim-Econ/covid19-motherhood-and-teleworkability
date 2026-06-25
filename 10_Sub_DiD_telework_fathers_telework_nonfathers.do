*******************************************************
* 10_Sub_DiD_telework_fathers_telework_nonfathers.do
*
* 보조 분석
* 2019년 재택가능 직종에서 일한 남성 중
* 아버지와 비아버지를 비교한다.
*
* 모든 표와 그림의 결과변수 순서
* 1. 로그 시간당 임금
* 2. 로그 주당 근로시간
* 3. 로그 주간 근로소득
*
* 각 결과변수에 대해 비가중 회귀와 가중 회귀를 모두 실행한다.
*******************************************************

version 17.0
clear all
set more off
set scheme s2color

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers"

* 이전 형식으로 만든 산출물이 남아 있으면 삭제한다.
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_02_hours_event_study.rtf"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_03_event_study_outcomes.rtf"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_04_did.rtf"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_05_did_coefficients.png"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_06_hours_event_study.png"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_07_weekly_income_event_study.png"
capture erase "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_08_hourly_income_event_study.png"

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

gen double ln_hours = ln(regular_hours_week) ///
    if regular_hours_week > 0 & regular_hours_week < .

gen double ln_weekly_income = ln(weekly_labor_income) ///
    if weekly_labor_income > 0 & weekly_labor_income < .

gen double hourly_wage = weekly_labor_income / regular_hours_week ///
    if weekly_labor_income > 0 & regular_hours_week > 0

gen double ln_hourly_wage = ln(hourly_wage) ///
    if hourly_wage > 0 & hourly_wage < .

*******************************************************
* 2. 2019년 기준 분석집단 만들기
*******************************************************

* 코로나 이후 자녀 여부나 직업이 바뀌어도 비교집단이 바뀌지 않도록
* 부모 여부, 직종, 산업, 지역, 가중치를 2019년에 고정한다.
preserve
    keep if survey_year == 2019
    keep if sex == 1
    keep if if_remote_possible == 1
    keep if inlist(if_child, 0, 1)

    gen byte father2019 = if_child
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

    keep pid father2019 occ2019 ind2019 region2019 person_wgt2019
    duplicates drop pid, force

    save "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_baseline_2019.dta", replace
restore

merge m:1 pid using ///
    "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_baseline_2019.dta", ///
    keep(3) nogen

xtset pid survey_year

*******************************************************
* 3. DiD의 사전기간과 사후기간 만들기
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
log using "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_01_tests.log", ///
    text replace

*******************************************************
* 4. Event study: 시간당 임금
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 아버지
* 비교대상 2: 2019년 재택가능 직종에서 일한 비아버지 남성
* 추정내용: 2019년 대비 연도별 로그 시간당 임금 변화 차이
reghdfe ln_hourly_wage i.father2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hourly_event_u

display as text "비가중 시간당 임금 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

reghdfe ln_hourly_wage i.father2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hourly_event_w

display as text "가중 시간당 임금 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

*******************************************************
* 5. Event study: 근로시간
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 아버지
* 비교대상 2: 2019년 재택가능 직종에서 일한 비아버지 남성
* 추정내용: 2019년 대비 연도별 로그 주당 근로시간 변화 차이
reghdfe ln_hours i.father2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hours_event_u

display as text "비가중 근로시간 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

reghdfe ln_hours i.father2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hours_event_w

display as text "가중 근로시간 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

*******************************************************
* 6. Event study: 주간 근로소득
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 아버지
* 비교대상 2: 2019년 재택가능 직종에서 일한 비아버지 남성
* 추정내용: 2019년 대비 연도별 로그 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.father2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_weekly_event_u

display as text "비가중 주간소득 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

reghdfe ln_weekly_income i.father2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_weekly_event_w

display as text "가중 주간소득 사전추세 공동검정"
test 1.father2019#2016.survey_year ///
     1.father2019#2017.survey_year ///
     1.father2019#2018.survey_year

* 세 결과변수의 event study를 한 표에 정리한다.
esttab S_F10_hourly_event_u S_F10_hourly_event_w ///
    S_F10_hours_event_u S_F10_hours_event_w ///
    S_F10_weekly_event_u S_F10_weekly_event_w ///
    using "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_02_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.father2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("보조 분석: 재택가능 남성의 아버지-비아버지 event study")

* 시간당 임금 event study 그림
coefplot ///
    (S_F10_hourly_event_u, label("비가중")) ///
    (S_F10_hourly_event_w, label("가중")), ///
    keep(1.father2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.father2019#2016.survey_year = "2016" ///
        1.father2019#2017.survey_year = "2017" ///
        1.father2019#2018.survey_year = "2018" ///
        1.father2019#2020.survey_year = "2020" ///
        1.father2019#2021.survey_year = "2021" ///
        1.father2019#2022.survey_year = "2022") ///
    ytitle("아버지-비아버지 로그 시간당 임금 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 남성의 시간당 임금 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_03_hourly_wage_event_study.png", ///
    width(2000) replace

* 근로시간 event study 그림
coefplot ///
    (S_F10_hours_event_u, label("비가중")) ///
    (S_F10_hours_event_w, label("가중")), ///
    keep(1.father2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.father2019#2016.survey_year = "2016" ///
        1.father2019#2017.survey_year = "2017" ///
        1.father2019#2018.survey_year = "2018" ///
        1.father2019#2020.survey_year = "2020" ///
        1.father2019#2021.survey_year = "2021" ///
        1.father2019#2022.survey_year = "2022") ///
    ytitle("아버지-비아버지 로그 근로시간 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 남성의 근로시간 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_04_hours_event_study.png", ///
    width(2000) replace

* 주간 근로소득 event study 그림
coefplot ///
    (S_F10_weekly_event_u, label("비가중")) ///
    (S_F10_weekly_event_w, label("가중")), ///
    keep(1.father2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.father2019#2016.survey_year = "2016" ///
        1.father2019#2017.survey_year = "2017" ///
        1.father2019#2018.survey_year = "2018" ///
        1.father2019#2020.survey_year = "2020" ///
        1.father2019#2021.survey_year = "2021" ///
        1.father2019#2022.survey_year = "2022") ///
    ytitle("아버지-비아버지 로그 주간소득 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 남성의 주간소득 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_05_weekly_income_event_study.png", ///
    width(2000) replace

*******************************************************
* 7. 평균 DiD: 세 결과변수 × 비가중/가중
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 아버지
* 비교대상 2: 2019년 재택가능 직종에서 일한 비아버지 남성
* 추정내용: 2016-2019년 대비 2021-2022년의 시간당 임금 변화 차이
reghdfe ln_hourly_wage i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hourly_did_u

reghdfe ln_hourly_wage i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hourly_did_w

* 비교대상은 같고 결과변수만 로그 주당 근로시간으로 바꾼다.
reghdfe ln_hours i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hours_did_u

reghdfe ln_hours i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_hours_did_w

* 비교대상은 같고 결과변수만 로그 주간 근로소득으로 바꾼다.
reghdfe ln_weekly_income i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_weekly_did_u

reghdfe ln_weekly_income i.father2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F10_weekly_did_w

esttab S_F10_hourly_did_u S_F10_hourly_did_w ///
    S_F10_hours_did_u S_F10_hours_did_w ///
    S_F10_weekly_did_u S_F10_weekly_did_w ///
    using "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_06_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.father2019#1.post2021_2022) ///
    coeflabels(1.father2019#1.post2021_2022 "아버지 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("보조 분석: 재택가능 남성의 아버지-비아버지 평균 DiD")

coefplot ///
    (S_F10_hourly_did_u, label("시간당 임금 비가중")) ///
    (S_F10_hourly_did_w, label("시간당 임금 가중")) ///
    (S_F10_hours_did_u, label("근로시간 비가중")) ///
    (S_F10_hours_did_w, label("근로시간 가중")) ///
    (S_F10_weekly_did_u, label("주간소득 비가중")) ///
    (S_F10_weekly_did_w, label("주간소득 가중")), ///
    keep(1.father2019#1.post2021_2022) ///
    coeflabels(1.father2019#1.post2021_2022 = "아버지 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 남성의 아버지-비아버지 평균 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("아버지의 상대적 변화") legend(rows(2))

graph export ///
    "output/S_F10_Sub_DiD_telework_fathers_telework_nonfathers/S_F10_07_did_coefficients.png", ///
    width(2000) replace

log close
display as result "S_F10 보조 분석이 완성되었습니다."
