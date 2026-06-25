*******************************************************
* 21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control.do
*
* Robustness 2-2
*
* 6번과 같은 비교를 사용하되,
* 2019년에 관측된 배우자의 연간 근로소득을 통제변수로 추가한다.
*
* 배우자 소득을 매년 바뀌는 값으로 통제하면 코로나 이후의
* 가구 내 노동공급 조정까지 통제할 수 있다. 그래서 bad controls
* 문제를 피하기 위해 2019년 값으로 고정한다.
*
* 처리집단: 2019년에 재택가능 직종에서 일한 혼인 어머니
* 비교집단: 2019년에 재택가능 직종에서 일한 혼인 무자녀 여성
* 공통표본: 2020-2022년 매년 취업 상태를 유지한 사람
*
* 결과변수 순서
* 1. 로그 시간당 임금
* 2. 로그 주당 근로시간
* 3. 로그 주간 근로소득
*******************************************************

version 17.0
clear all
set more off
set scheme s2color

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control"

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

    save "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_employed_2020_2022.dta", replace
restore

merge m:1 pid using ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_employed_2020_2022.dta", ///
    keep(3) nogen

*******************************************************
* 3. 2019년 기준 분석집단과 배우자 소득 만들기
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

    * spouse_labor_income의 단위는 만원이다.
    * 회귀계수를 읽기 쉽게 1,000만원 단위로 바꾼다.
    * 이 값은 2019년 기준으로 고정해서 모든 연도에 붙인다.
    gen double spouse_income2019_1000 = spouse_labor_income / 1000 ///
        if spouse_labor_income >= 0 & spouse_labor_income < .

    label variable spouse_income2019_1000 ///
        "2019년 배우자 연간 근로소득(1,000만원)"

    keep pid mother2019 occ2019 ind2019 region2019 ///
        person_wgt2019 spouse_income2019_1000
    duplicates drop pid, force

    save "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_baseline_2019.dta", replace
restore

merge m:1 pid using ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_baseline_2019.dta", ///
    keep(3) nogen

* 최종 분석대상자가 2020-2022년 매년 취업했는지 다시 확인한다.
bysort pid: egen byte check_employed2020 = ///
    max(cond(survey_year == 2020, employed, .))
bysort pid: egen byte check_employed2021 = ///
    max(cond(survey_year == 2021, employed, .))
bysort pid: egen byte check_employed2022 = ///
    max(cond(survey_year == 2022, employed, .))

assert check_employed2020 == 1
assert check_employed2021 == 1
assert check_employed2022 == 1

drop check_employed2020 check_employed2021 check_employed2022

* 2019년 배우자 연소득이 결측이거나 음수 코드인 사람은 분석에서 제외한다.
* 실제 배우자 근로소득이 0인 사람은 그대로 0으로 사용한다.
drop if missing(spouse_income2019_1000)

xtset pid survey_year

*******************************************************
* 4. DiD의 사전기간과 사후기간 만들기
*******************************************************

* 사전기간: 2016-2019년
* 사후기간: 2021-2022년
* 2020년은 코로나19가 시작된 전환기이므로 평균효과 DiD에서 제외한다.
gen byte post2021_2022 = .
replace post2021_2022 = 0 if inrange(survey_year, 2016, 2019)
replace post2021_2022 = 1 if inrange(survey_year, 2021, 2022)

label define post2021_2022_label 0 "2016-2019년" 1 "2021-2022년"
label values post2021_2022 post2021_2022_label

* 개인 고정효과를 넣으면 2019년 배우자 소득의 수준 자체는 흡수된다.
* 그래서 event study에서는 2019년 배우자 소득과 연도 더미의 상호작용을 넣는다.
* 기준연도인 2019년 상호작용은 만들지 않는다.
gen double spouse_income2019_y2016 = spouse_income2019_1000 * ///
    (survey_year == 2016)
gen double spouse_income2019_y2017 = spouse_income2019_1000 * ///
    (survey_year == 2017)
gen double spouse_income2019_y2018 = spouse_income2019_1000 * ///
    (survey_year == 2018)
gen double spouse_income2019_y2020 = spouse_income2019_1000 * ///
    (survey_year == 2020)
gen double spouse_income2019_y2021 = spouse_income2019_1000 * ///
    (survey_year == 2021)
gen double spouse_income2019_y2022 = spouse_income2019_1000 * ///
    (survey_year == 2022)

* 평균 DiD에서는 2019년 배우자 소득과 사후기간의 상호작용을 넣는다.
gen double spouse_income2019_post = spouse_income2019_1000 * ///
    post2021_2022 if !missing(post2021_2022)

label variable spouse_income2019_post ///
    "2019년 배우자 연소득 × 사후기간"

assert employed_all_2020_2022 == 1
assert inrange(survey_year, 2016, 2022)

capture log close
log using ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_01_results.log", ///
    text replace

tabulate mother2019 if survey_year == 2019

*******************************************************
* 5. Event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
* 모든 회귀에서 2019년 배우자 연소득 × 연도 더미를 통제한다.

* 시간당 임금 event study
reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hourly_event_u

display as text "비가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hourly_event_w

display as text "가중 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

* 근로시간 event study
reghdfe ln_hours i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hours_event_u

display as text "비가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_hours i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hours_event_w

display as text "가중 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

* 주간 근로소득 event study
reghdfe ln_weekly_income i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_weekly_event_u

display as text "비가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_weekly_income i.mother2019##ib2019.survey_year ///
    spouse_income2019_y2016 spouse_income2019_y2017 ///
    spouse_income2019_y2018 spouse_income2019_y2020 ///
    spouse_income2019_y2021 spouse_income2019_y2022 ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_weekly_event_w

display as text "가중 주간소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

esttab R22_hourly_event_u R22_hourly_event_w ///
    R22_hours_event_u R22_hours_event_w ///
    R22_weekly_event_u R22_weekly_event_w ///
    using "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_02_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("2019년 배우자소득 통제: 재택가능 혼인 여성 event study")

coefplot ///
    (R22_hourly_event_u, label("비가중")) ///
    (R22_hourly_event_w, label("가중")), ///
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
    title("2019년 배우자소득 통제: 시간당 임금 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_03_hourly_wage_event_study.png", ///
    width(2000) replace

coefplot ///
    (R22_hours_event_u, label("비가중")) ///
    (R22_hours_event_w, label("가중")), ///
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
    title("2019년 배우자소득 통제: 근로시간 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_04_hours_event_study.png", ///
    width(2000) replace

coefplot ///
    (R22_weekly_event_u, label("비가중")) ///
    (R22_weekly_event_w, label("가중")), ///
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
    title("2019년 배우자소득 통제: 주간소득 event study") ///
    note("기준연도: 2019년") legend(rows(1))

graph export ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_05_weekly_income_event_study.png", ///
    width(2000) replace

*******************************************************
* 6. 평균 DiD
*******************************************************

* 평균 DiD에서는 2019년 배우자소득 × 사후기간을 통제한다.

reghdfe ln_hourly_wage ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hourly_did_u

reghdfe ln_hourly_wage ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hourly_did_w

reghdfe ln_hours ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hours_did_u

reghdfe ln_hours ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_hours_did_w

reghdfe ln_weekly_income ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_weekly_did_u

reghdfe ln_weekly_income ///
    i.mother2019##i.post2021_2022 ///
    spouse_income2019_post ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store R22_weekly_did_w

esttab R22_hourly_did_u R22_hourly_did_w ///
    R22_hours_did_u R22_hours_did_w ///
    R22_weekly_did_u R22_weekly_did_w ///
    using "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_06_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022 spouse_income2019_post) ///
    coeflabels(1.mother2019#1.post2021_2022 "어머니 × 사후기간" ///
        spouse_income2019_post "2019년 배우자 연소득 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("2019년 배우자소득 통제: 재택가능 혼인 여성 평균 DiD")

coefplot ///
    (R22_hourly_did_u, label("시간당 임금 비가중")) ///
    (R22_hourly_did_w, label("시간당 임금 가중")) ///
    (R22_hours_did_u, label("근로시간 비가중")) ///
    (R22_hours_did_w, label("근로시간 가중")) ///
    (R22_weekly_did_u, label("주간소득 비가중")) ///
    (R22_weekly_did_w, label("주간소득 가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("2019년 배우자소득 통제: 재택가능 혼인 여성 평균 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") legend(rows(2))

graph export ///
    "output/21_DiD_telework_married_mothers_telework_married_nonmothers_spouse_income2019_control/21_07_did_coefficients.png", ///
    width(2000) replace

log close

display as result "Robustness 2-2 분석이 완성되었습니다."
