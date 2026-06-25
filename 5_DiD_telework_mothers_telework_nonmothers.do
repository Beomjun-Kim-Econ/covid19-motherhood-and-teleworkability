*******************************************************
* 5_DiD_telework_mothers_telework_nonmothers.do
*
* 주 분석 (Main result)
* 여성 내부에서 어머니와 비어머니를 비교한다.
*
* 모든 분석에서 다음 세 결과변수를 같은 순서로 사용한다.
* 1. 로그 시간당 임금
* 2. 로그 주당 근로시간
* 3. 로그 주간 근로소득
*
* 처리집단: 2019년에 재택가능 직종에서 일한 어머니
* 비교집단: 2019년에 재택가능 직종에서 일한 비어머니 여성
* 공통표본: 2020-2022년 매년 취업 상태를 유지한 사람
*******************************************************

version 17.0
clear all
set more off
set scheme s2color

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/S_F5_DiD_telework_mothers_telework_nonmothers"

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

* 근로시간은 주당 정규근로시간이 양수인 경우에만 로그를 취한다.
gen double ln_hours = ln(regular_hours_week) ///
    if regular_hours_week > 0 & regular_hours_week < .

* 주간 근로소득이 양수인 경우에만 로그를 취한다.
gen double ln_weekly_income = ln(weekly_labor_income) ///
    if weekly_labor_income > 0 & weekly_labor_income < .

* 시간당 임금은 주간 근로소득을 주당 정규근로시간으로 나누어 만든다.
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

    save "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_employed_2020_2022.dta", replace
restore

merge m:1 pid using ///
    "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_employed_2020_2022.dta", ///
    keep(3) nogen

*******************************************************
* 3. 2019년 기준 분석집단 만들기
*******************************************************

* 여성만 사용한다.
* 코로나 이후 자녀 상태나 직업이 바뀌어도 집단이 바뀌지 않도록
* 부모 여부, 재택가능성, 직종, 산업, 지역을 2019년에 고정한다.
preserve
    keep if survey_year == 2019
    keep if sex == 0
    keep if if_remote_possible == 1
    keep if inlist(if_child, 0, 1)

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

    save "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_baseline_2019.dta", replace
restore

merge m:1 pid using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_baseline_2019.dta", ///
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

* 모든 분석 관측치가 계속 취업자 표본이고 분석기간 안에 있는지 확인한다.
assert employed_all_2020_2022 == 1
assert inrange(survey_year, 2016, 2022)

capture log close
log using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_01_main_tests.log", text replace

*******************************************************
* 5. 분석 1: 근로시간 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 사전기간 대비 사후기간의 로그 주당 근로시간 변화 차이
* 먼저 가중치를 사용하지 않은 회귀를 돌린다.
reghdfe ln_hours i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hours_did_u

* 다음으로 동일한 회귀에 2019년 개인가중치를 적용한다.
reghdfe ln_hours i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hours_did_w

esttab S_F5_hours_did_u S_F5_hours_did_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_02_hours_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 "어머니 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("비가중" "가중") ///
    title("재택가능 여성의 어머니-비어머니 근로시간 DiD")

coefplot ///
    (S_F5_hours_did_u, label("비가중")) ///
    (S_F5_hours_did_w, label("가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 여성의 어머니-비어머니 근로시간 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") ///
    legend(rows(1))

graph export "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_03_hours_did.png", ///
    width(2000) replace

*******************************************************
* 6. 분석 1: 근로시간 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 근로시간 변화 차이
*
* 먼저 가중치를 사용하지 않은 event study를 돌린다.
reghdfe ln_hours i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hours_event_u

display as text "비가중 어머니-비어머니 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

* 다음으로 동일한 event study에 2019년 개인가중치를 적용한다.
reghdfe ln_hours i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hours_event_w

display as text "가중 어머니-비어머니 근로시간 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

esttab S_F5_hours_event_u S_F5_hours_event_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_04_hours_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("비가중" "가중") ///
    title("재택가능 여성의 어머니-비어머니 근로시간 event study")

coefplot ///
    (S_F5_hours_event_u, label("비가중")) ///
    (S_F5_hours_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-비어머니 로그 근로시간 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 근로시간 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_05_hours_event_study.png", ///
    width(2000) replace

*******************************************************
* 7. 분석 2: 시간당 임금 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 사전기간 대비 사후기간의 로그 시간당 임금 변화 차이
* 먼저 가중치를 사용하지 않은 회귀를 돌린다.
reghdfe ln_hourly_wage i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hourly_wage_did_u

* 다음으로 동일한 회귀에 2019년 개인가중치를 적용한다.
reghdfe ln_hourly_wage i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_hourly_wage_did_w

esttab S_F5_hourly_wage_did_u S_F5_hourly_wage_did_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_06_hourly_wage_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 "어머니 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("비가중" "가중") ///
    title("재택가능 여성의 어머니-비어머니 시간당 임금 DiD")

coefplot ///
    (S_F5_hourly_wage_did_u, label("비가중")) ///
    (S_F5_hourly_wage_did_w, label("가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 여성의 어머니-비어머니 시간당 임금 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") ///
    legend(rows(1))

graph export "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_07_hourly_wage_did.png", ///
    width(2000) replace

*******************************************************
* 8. 분석 2: 시간당 임금 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 시간당 임금 변화 차이
*
* 먼저 가중치를 사용하지 않은 event study를 돌린다.
reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_wage_event_u

display as text "비가중 어머니-비어머니 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

* 다음으로 동일한 event study에 2019년 개인가중치를 적용한다.
reghdfe ln_hourly_wage i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_wage_event_w

display as text "가중 어머니-비어머니 시간당 임금 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

esttab S_F5_wage_event_u S_F5_wage_event_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_08_hourly_wage_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("비가중" "가중") ///
    title("재택가능 여성의 어머니-비어머니 시간당 임금 event study")

coefplot ///
    (S_F5_wage_event_u, label("비가중")) ///
    (S_F5_wage_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-비어머니 로그 시간당 임금 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 시간당 임금 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export ///
    "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_09_hourly_wage_event_study.png", ///
    width(2000) replace

*******************************************************
* 9. 분석 3: 주간 근로소득 event study
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.mother2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_week_event_u

display as text "비가중 주간 근로소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

reghdfe ln_weekly_income i.mother2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_week_event_w

display as text "가중 주간 근로소득 사전추세 공동검정"
test 1.mother2019#2016.survey_year ///
     1.mother2019#2017.survey_year ///
     1.mother2019#2018.survey_year

coefplot ///
    (S_F5_week_event_u, label("비가중")) ///
    (S_F5_week_event_w, label("가중")), ///
    keep(1.mother2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.mother2019#2016.survey_year = "2016" ///
        1.mother2019#2017.survey_year = "2017" ///
        1.mother2019#2018.survey_year = "2018" ///
        1.mother2019#2020.survey_year = "2020" ///
        1.mother2019#2021.survey_year = "2021" ///
        1.mother2019#2022.survey_year = "2022") ///
    ytitle("어머니-비어머니 로그 주간소득 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 여성의 주간 근로소득 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export ///
    "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_10_weekly_income_event_study.png", ///
    width(2000) replace

*******************************************************
* 10. 분석 3: 주간 근로소득 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 어머니
* 비교대상 2: 2019년 재택가능 직종에서 일한 비어머니 여성
* 추정내용: 사전기간 대비 사후기간의 로그 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_week_did_u

reghdfe ln_weekly_income i.mother2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F5_week_did_w

*******************************************************
* 11. 세 결과변수를 같은 순서로 정리
*******************************************************

* 순서: 시간당 임금, 근로시간, 주간 근로소득
esttab S_F5_hourly_wage_did_u S_F5_hourly_wage_did_w ///
    S_F5_hours_did_u S_F5_hours_did_w ///
    S_F5_week_did_u S_F5_week_did_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_11_did_all_outcomes.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 "어머니 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("재택가능 어머니-비어머니 평균 DiD")

esttab S_F5_wage_event_u S_F5_wage_event_w ///
    S_F5_hours_event_u S_F5_hours_event_w ///
    S_F5_week_event_u S_F5_week_event_w ///
    using "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_12_event_study_all_outcomes.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.mother2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("재택가능 어머니-비어머니 event study")

coefplot ///
    (S_F5_hourly_wage_did_u, label("시간당 임금 비가중")) ///
    (S_F5_hourly_wage_did_w, label("시간당 임금 가중")) ///
    (S_F5_hours_did_u, label("근로시간 비가중")) ///
    (S_F5_hours_did_w, label("근로시간 가중")) ///
    (S_F5_week_did_u, label("주간소득 비가중")) ///
    (S_F5_week_did_w, label("주간소득 가중")), ///
    keep(1.mother2019#1.post2021_2022) ///
    coeflabels(1.mother2019#1.post2021_2022 = "어머니 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 어머니-비어머니 평균 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("어머니의 상대적 변화") ///
    legend(rows(2))

graph export ///
    "output/S_F5_DiD_telework_mothers_telework_nonmothers/S_F5_13_did_coefficients_all_outcomes.png", ///
    width(2000) replace

log close
display as result "S_F5 세 결과변수 주 분석이 완성되었습니다."
