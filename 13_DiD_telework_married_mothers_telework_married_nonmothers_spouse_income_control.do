*******************************************************
* 13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control.do
*
* Main Result 3 추가 분석
* 2019년 재택가능 혼인 여성 안에서
* 어머니와 혼인 무자녀 여성을 비교한다.
*
* S_F6의 평균 DiD에 배우자의 연간 근로소득을 통제한다.
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
capture mkdir "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control"

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
* 2. 배우자 연간 근로소득 통제변수 만들기
*******************************************************

* spouse_labor_income의 단위는 만원이다.
* 회귀계수를 읽기 쉽게 1,000만원 단위로 바꾼다.
gen double spouse_income_1000 = spouse_labor_income / 1000 ///
    if spouse_labor_income >= 0 & spouse_labor_income < .

label variable spouse_income_1000 ///
    "배우자 연간 근로소득(1,000만원)"

*******************************************************
* 3. 2020-2022년 계속 취업자 표본 만들기
*******************************************************

* 세 해가 모두 관측되고, 세 해 모두 취업한 사람만 남긴다.
* Robustness도 주 분석과 같은 고용유지자 표본으로 맞춘다.
preserve
    keep if inrange(survey_year, 2020, 2022)
    collapse (count) observed_years=survey_year ///
        (sum) employed_years=employed, by(pid)

    keep if observed_years == 3
    keep if employed_years == 3

    gen byte employed_all_2020_2022 = 1
    keep pid employed_all_2020_2022

    save ///
        "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_employed_2020_2022.dta", ///
        replace
restore

merge m:1 pid using ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_employed_2020_2022.dta", ///
    keep(3) nogen

*******************************************************
* 4. 2019년 기준 분석집단 만들기
*******************************************************

* S_F6과 같은 분석집단을 만든다.
* 코로나 이후 혼인상태, 자녀 여부, 직업이 바뀌더라도
* 비교집단이 바뀌지 않도록 집단 특성을 2019년에 고정한다.
preserve
    keep if survey_year == 2019
    keep if sex == 0
    keep if if_remote_possible == 1
    keep if marital_status == 2
    keep if inlist(if_child, 0, 1)

    * 어머니=1, 혼인 무자녀 여성=0이다.
    gen byte mother2019 = if_child

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
        "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_baseline_2019.dta", ///
        replace
restore

merge m:1 pid using ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_baseline_2019.dta", ///
    keep(3) nogen

xtset pid survey_year

*******************************************************
* 5. DiD의 사전기간과 사후기간 만들기
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
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_01_results.log", ///
    text replace

* 2019년 두 집단의 원래 표본 수를 확인한다.
tabulate mother2019 if survey_year == 2019

* 배우자 연소득이 결측이거나 음수 코드인 관측치는 분석에서 제외한다.
* 따라서 실제 배우자 근로소득이 0인 관측치만 0으로 남는다.
drop if missing(spouse_income_1000)

* 배우자소득이 관측되는 최종 2019년 표본 수를 다시 확인한다.
tabulate mother2019 if survey_year == 2019

*******************************************************
* 6. 시간당 임금 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 시간당 임금 변화 차이
* 먼저 가중치를 사용하지 않은 회귀를 돌린다.
reghdfe ln_hourly_wage ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hourly_did_u

* 다음으로 동일한 회귀에 2019년 개인가중치를 적용한다.
reghdfe ln_hourly_wage ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hourly_did_w

*******************************************************
* 6. 근로시간 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 주당 근로시간 변화 차이
reghdfe ln_hours ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hours_did_u

reghdfe ln_hours ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hours_did_w

*******************************************************
* 7. 주간 근로소득 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 주간 근로소득 변화 차이
reghdfe ln_weekly_income ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_weekly_did_u

reghdfe ln_weekly_income ///
    i.mother2019##i.post2021_2022 ///
    c.spouse_income_1000 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_weekly_did_w

*******************************************************
* 8. 결과 저장하기
*******************************************************

* 순서: 시간당 임금, 근로시간, 주간 근로소득
esttab S_F13_hourly_did_u S_F13_hourly_did_w ///
    S_F13_hours_did_u S_F13_hours_did_w ///
    S_F13_weekly_did_u S_F13_weekly_did_w ///
    using ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_02_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022 ///
        spouse_income_1000) ///
    coeflabels( ///
        1.mother2019#1.post2021_2022 "어머니 × 사후기간" ///
        spouse_income_1000 "배우자 연소득(1,000만원)") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("Main Result 3: 배우자 연소득 통제 DiD")

* 여섯 회귀의 관심 DiD 계수만 그림에 표시한다.
coefplot ///
    (S_F13_hourly_did_u, label("시간당 임금 비가중")) ///
    (S_F13_hourly_did_w, label("시간당 임금 가중")) ///
    (S_F13_hours_did_u, label("근로시간 비가중")) ///
    (S_F13_hours_did_w, label("근로시간 가중")) ///
    (S_F13_weekly_did_u, label("주간소득 비가중")) ///
    (S_F13_weekly_did_w, label("주간소득 가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("Main Result 3: 배우자 연소득 통제 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") legend(rows(2))

graph export ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_03_did_coefficients.png", ///
    width(2000) replace

*******************************************************
* 9. 시간당 임금 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 연도별 시간당 임금 변화 차이
* 기준연도는 코로나 직전인 2019년이다.
reghdfe ln_hourly_wage ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hourly_event_u

display as text "비가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hourly_wage ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hourly_event_w

display as text "가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

*******************************************************
* 10. 근로시간 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 연도별 근로시간 변화 차이
reghdfe ln_hours ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hours_event_u

display as text "비가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hours ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_hours_event_w

display as text "가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

*******************************************************
* 11. 주간 근로소득 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 추정내용: 배우자 연소득을 통제한 연도별 주간소득 변화 차이
reghdfe ln_weekly_income ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_weekly_event_u

display as text "비가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_weekly_income ///
    i.mother2019##ib2019.survey_year ///
    c.spouse_income_1000 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F13_weekly_event_w

display as text "가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

*******************************************************
* 12. Event study 결과 저장하기
*******************************************************

* 순서: 시간당 임금, 근로시간, 주간 근로소득
esttab S_F13_hourly_event_u S_F13_hourly_event_w ///
    S_F13_hours_event_u S_F13_hours_event_w ///
    S_F13_weekly_event_u S_F13_weekly_event_w ///
    using ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_04_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year spouse_income_1000) ///
    coeflabels(spouse_income_1000 "배우자 연소득(1,000만원)") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("Main Result 3: 배우자 연소득 통제 event study")

* 시간당 임금 event study 그림
coefplot ///
    (S_F13_hourly_event_u, label("비가중")) ///
    (S_F13_hourly_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니의 상대적 로그 시간당 임금 변화") ///
    xtitle("조사연도") ///
    title("배우자 연소득 통제: 시간당 임금 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_05_hourly_wage_event_study.png", ///
    width(2000) replace

* 근로시간 event study 그림
coefplot ///
    (S_F13_hours_event_u, label("비가중")) ///
    (S_F13_hours_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니의 상대적 로그 근로시간 변화") ///
    xtitle("조사연도") ///
    title("배우자 연소득 통제: 근로시간 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_06_hours_event_study.png", ///
    width(2000) replace

* 주간 근로소득 event study 그림
coefplot ///
    (S_F13_weekly_event_u, label("비가중")) ///
    (S_F13_weekly_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) vertical ///
    yline(0, lcolor(gs8)) xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니의 상대적 로그 주간소득 변화") ///
    xtitle("조사연도") ///
    title("배우자 연소득 통제: 주간소득 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/S_F13_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income_control/S_F13_07_weekly_income_event_study.png", ///
    width(2000) replace

log close
display as result "S_F13 배우자 연소득 통제 DiD와 event study가 완성되었습니다."
