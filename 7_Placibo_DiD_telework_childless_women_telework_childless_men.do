*******************************************************
* 7_Placibo_DiD_telework_childless_women_telework_childless_men.do
*
* 플라시보 분석
* 2019년 재택가능 직종에서 일한 무자녀 여성과
* 무자녀 남성을 비교한다.
*
* 여기서 차이가 약하면 주 분석이 코로나19의
* 일반적인 여성 충격 때문이라는 설명이 약해진다.
*
* 모든 표와 그림의 결과변수 순서
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
capture mkdir "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men"

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

* 취업 여부는 주당 정규근로시간이 양수인지로 판단한다.
gen byte employed = regular_hours_week > 0 & regular_hours_week < .

gen double ln_hours = ln(regular_hours_week) ///
    if regular_hours_week > 0 & regular_hours_week < .
gen double ln_weekly_income = ln(weekly_labor_income) ///
    if weekly_labor_income > 0 & weekly_labor_income < .
gen double hourly_labor_income = weekly_labor_income / regular_hours_week ///
    if weekly_labor_income > 0 & regular_hours_week > 0
gen double ln_hourly_income = ln(hourly_labor_income) ///
    if hourly_labor_income > 0 & hourly_labor_income < .

* 2020-2022년 세 해가 모두 관측되고, 세 해 모두 취업한 사람만 남긴다.
* 플라시보도 주 분석과 같은 고용유지자 표본으로 맞춘다.
preserve
    keep if inrange(survey_year, 2020, 2022)
    collapse (count) observed_years=survey_year ///
        (sum) employed_years=employed, by(pid)

    keep if observed_years == 3
    keep if employed_years == 3

    gen byte employed_all_2020_2022 = 1
    keep pid employed_all_2020_2022

    save "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_employed_2020_2022.dta", replace
restore

merge m:1 pid using ///
    "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_employed_2020_2022.dta", ///
    keep(3) nogen

* 2019년에 재택가능 직종에서 일한 무자녀 남녀의 특성을 고정한다.
preserve
    keep if survey_year == 2019
    keep if if_child == 0
    keep if if_remote_possible == 1
    keep if inlist(sex, 0, 1)

    gen byte female2019 = sex == 0
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

    keep pid female2019 occ2019 ind2019 region2019 person_wgt2019
    duplicates drop pid, force
    save "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_baseline_2019.dta", replace
restore

merge m:1 pid using "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_baseline_2019.dta", keep(3) nogen
xtset pid survey_year

* 평균 DiD에서 사용할 사전기간과 사후기간을 만든다.
* 사전기간은 2016-2019년, 사후기간은 2021-2022년이다.
* 코로나19가 처음 시작된 2020년은 평균 DiD에서 제외한다.
gen byte post2021_2022 = .
replace post2021_2022 = 0 if inrange(survey_year, 2016, 2019)
replace post2021_2022 = 1 if inrange(survey_year, 2021, 2022)

label define post2021_2022_label 0 "2016-2019년" 1 "2021-2022년"
label values post2021_2022 post2021_2022_label

assert inrange(survey_year, 2016, 2022)

capture log close
log using "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_01_tests.log", text replace

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년 대비 연도별 로그 주당 근로시간 변화 차이
* 먼저 가중치를 사용하지 않은 회귀를 돌린다.
reghdfe ln_hours i.female2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hours_event_u

display as text "비가중 무자녀 남녀 근로시간 사전추세 공동검정"
test 1.female2019#2016.survey_year ///
     1.female2019#2017.survey_year ///
     1.female2019#2018.survey_year

* 다음으로 같은 회귀에 2019년 개인가중치를 적용한다.
reghdfe ln_hours i.female2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hours_event_w

display as text "가중 무자녀 남녀 근로시간 사전추세 공동검정"
test 1.female2019#2016.survey_year ///
     1.female2019#2017.survey_year ///
     1.female2019#2018.survey_year

esttab S_F7_hours_event_u S_F7_hours_event_w ///
    using "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_02_hours_event_study.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.female2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("비가중" "가중") ///
    title("플라시보: 재택가능 무자녀 여성-남성 근로시간 차이")

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년 대비 연도별 로그 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.female2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_weekly_event_u

reghdfe ln_weekly_income i.female2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_weekly_event_w

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년 대비 연도별 로그 시간당 임금 변화 차이
reghdfe ln_hourly_income i.female2019##ib2019.survey_year, ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hourly_event_u

reghdfe ln_hourly_income i.female2019##ib2019.survey_year ///
    [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hourly_event_w

esttab S_F7_hourly_event_u S_F7_hourly_event_w ///
    S_F7_hours_event_u S_F7_hours_event_w ///
    S_F7_weekly_event_u S_F7_weekly_event_w ///
    using "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_03_event_study_outcomes.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.female2019#*.survey_year) ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("플라시보: 재택가능 무자녀 여성-남성 차이")

*******************************************************
* 평균 DiD
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 사전기간 대비 사후기간의 로그 주당 근로시간 변화 차이
*
* 관심 계수는 여성 × 사후기간이다.
* 양수이면 여성의 근로시간이 남성보다 상대적으로 증가한 것이고,
* 음수이면 여성의 근로시간이 남성보다 상대적으로 감소한 것이다.
reghdfe ln_hours i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hours_did_u

reghdfe ln_hours i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hours_did_w

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 사전기간 대비 사후기간의 로그 주간 근로소득 변화 차이
reghdfe ln_weekly_income i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_weekly_did_u

reghdfe ln_weekly_income i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_weekly_did_w

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 사전기간 대비 사후기간의 로그 시간당 임금 변화 차이
reghdfe ln_hourly_income i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022), ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hourly_did_u

reghdfe ln_hourly_income i.female2019##i.post2021_2022 ///
    if !missing(post2021_2022) [pw=person_wgt2019], ///
    absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
        region2019#survey_year) vce(cluster pid)
estimates store S_F7_hourly_did_w

* 비가중 결과와 가중 결과를 하나의 표로 저장한다.
esttab S_F7_hourly_did_u S_F7_hourly_did_w ///
    S_F7_hours_did_u S_F7_hours_did_w ///
    S_F7_weekly_did_u S_F7_weekly_did_w ///
    using "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_04_did.rtf", ///
    replace se star(* 0.10 ** 0.05 *** 0.01) ///
    keep(1.female2019#1.post2021_2022) ///
    coeflabels(1.female2019#1.post2021_2022 "여성 × 사후기간") ///
    stats(N r2, labels("관측치" "R-squared")) ///
    mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
        "근로시간 비가중" "근로시간 가중" ///
        "주간소득 비가중" "주간소득 가중") ///
    title("플라시보: 재택가능 무자녀 여성-남성 평균 DiD")

* 세 평균 DiD 계수와 95% 신뢰구간을 한 그림에 표시한다.
* 0선과 신뢰구간이 겹치면 두 집단의 변화 차이가 뚜렷하지 않다는 뜻이다.
coefplot ///
    (S_F7_hourly_did_u, label("시간당 임금 비가중")) ///
    (S_F7_hourly_did_w, label("시간당 임금 가중")) ///
    (S_F7_hours_did_u, label("근로시간 비가중")) ///
    (S_F7_hours_did_w, label("근로시간 가중")) ///
    (S_F7_weekly_did_u, label("주간소득 비가중")) ///
    (S_F7_weekly_did_w, label("주간소득 가중")), ///
    keep(1.female2019#1.post2021_2022) ///
    coeflabels(1.female2019#1.post2021_2022 = "여성 × 사후기간") ///
    xline(0, lcolor(gs8)) ///
    title("재택가능 무자녀 여성-남성 평균 DiD") ///
    subtitle("2016-2019년 대비 2021-2022년") ///
    xtitle("여성의 상대적 변화") ///
    legend(rows(2))

graph export "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_05_did_coefficients.png", ///
    width(2000) replace

*******************************************************
* Event study 시각화
*******************************************************

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 근로시간 변화 차이
coefplot ///
    (S_F7_hours_event_u, label("비가중")) ///
    (S_F7_hours_event_w, label("가중")), ///
    keep(1.female2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.female2019#2016.survey_year = "2016" ///
        1.female2019#2017.survey_year = "2017" ///
        1.female2019#2018.survey_year = "2018" ///
        1.female2019#2020.survey_year = "2020" ///
        1.female2019#2021.survey_year = "2021" ///
        1.female2019#2022.survey_year = "2022") ///
    ytitle("여성-남성 로그 근로시간 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 무자녀 남녀의 근로시간 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_06_hours_event_study.png", ///
    width(2000) replace

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 주간 근로소득 변화 차이
coefplot ///
    (S_F7_weekly_event_u, label("비가중")) ///
    (S_F7_weekly_event_w, label("가중")), ///
    keep(1.female2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.female2019#2016.survey_year = "2016" ///
        1.female2019#2017.survey_year = "2017" ///
        1.female2019#2018.survey_year = "2018" ///
        1.female2019#2020.survey_year = "2020" ///
        1.female2019#2021.survey_year = "2021" ///
        1.female2019#2022.survey_year = "2022") ///
    ytitle("여성-남성 로그 주간소득 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 무자녀 남녀의 주간소득 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_07_weekly_income_event_study.png", ///
    width(2000) replace

* 비교대상 1: 2019년 재택가능 직종에서 일한 무자녀 여성
* 비교대상 2: 2019년 재택가능 직종에서 일한 무자녀 남성
* 추정내용: 2019년을 기준으로 두 집단의 연도별 시간당 임금 변화 차이
coefplot ///
    (S_F7_hourly_event_u, label("비가중")) ///
    (S_F7_hourly_event_w, label("가중")), ///
    keep(1.female2019#*.survey_year) ///
    vertical yline(0, lcolor(gs8)) ///
    xline(3.5, lpattern(dash) lcolor(gs8)) ///
    coeflabels( ///
        1.female2019#2016.survey_year = "2016" ///
        1.female2019#2017.survey_year = "2017" ///
        1.female2019#2018.survey_year = "2018" ///
        1.female2019#2020.survey_year = "2020" ///
        1.female2019#2021.survey_year = "2021" ///
        1.female2019#2022.survey_year = "2022") ///
    ytitle("여성-남성 로그 시간당 임금 변화 차이") ///
    xtitle("조사연도") ///
    title("재택가능 무자녀 남녀의 시간당 임금 event study") ///
    note("기준연도: 2019년") ///
    legend(rows(1))

graph export "output/S_F7_Placibo_DiD_telework_childless_women_telework_childless_men/S_F7_08_hourly_income_event_study.png", ///
    width(2000) replace

log close
display as result "S_F7 placebo 분석이 완성되었습니다."
