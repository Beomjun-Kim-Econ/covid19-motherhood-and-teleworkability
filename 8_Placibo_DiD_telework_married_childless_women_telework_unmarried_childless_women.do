*******************************************************
* 8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women.do
*
* 플라시보 분석
* 2019년 재택가능 무자녀 여성 안에서
* 혼인 여성과 미혼 여성을 비교한다.
*
* 모든 표와 그림의 결과변수 순서
* 1. 로그 시간당 임금
* 2. 로그 주당 근로시간
* 3. 로그 주간 근로소득
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
capture mkdir "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women"

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

    save "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_employed_2020_2022.dta", replace
restore

merge m:1 pid using ///
    "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_employed_2020_2022.dta", ///
    keep(3) nogen

* 2019년 여성의 혼인상태, 자녀 여부, 재택가능성을 고정한다.
preserve
    keep if survey_year == 2019
    keep if sex == 0

    gen byte female_group2019 = .
    replace female_group2019 = 0 if marital_status == 1 & if_child == 0
    replace female_group2019 = 1 if marital_status == 2 & if_child == 0
    replace female_group2019 = 2 if marital_status == 2 & if_child == 1

    label define female_group_label ///
        0 "미혼 무자녀 여성" ///
        1 "혼인 무자녀 여성" ///
        2 "혼인 어머니"
    label values female_group2019 female_group_label

    gen byte remote2019 = if_remote_possible == 1 if !missing(if_remote_possible)
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

    keep pid female_group2019 remote2019 occ2019 ind2019 region2019 person_wgt2019
    drop if missing(female_group2019) | missing(remote2019)
    duplicates drop pid, force
    save "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_baseline_2019.dta", replace
restore

merge m:1 pid using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_baseline_2019.dta", ///
    keep(3) nogen
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
log using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_01_tests.log", text replace

*******************************************************
* B. 재택가능 무자녀 여성: 혼인과 미혼 비교
*******************************************************

preserve
    keep if remote2019 == 1
    keep if inlist(female_group2019, 0, 1)
    gen byte married2019 = female_group2019 == 1

    * 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
    * 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
    * 추정내용: 2019년 대비 연도별 로그 주당 근로시간 변화 차이
    * 먼저 가중치를 사용하지 않은 event study를 돌린다.
    reghdfe ln_hours i.married2019##ib2019.survey_year, ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_marriage_hours_u

    display as text "비가중 재택가능 무자녀 여성 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    * 다음으로 같은 회귀에 2019년 개인가중치를 적용한다.
    reghdfe ln_hours i.married2019##ib2019.survey_year ///
        [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_marriage_hours_w

    display as text "가중 재택가능 무자녀 여성 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    esttab S_F8_marriage_hours_u S_F8_marriage_hours_w ///
        using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_02_hours_event_study.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(1.married2019#*.survey_year) ///
        stats(N r2, labels("관측치" "R-squared")) ///
        mtitles("비가중" "가중") ///
        title("플라시보: 재택가능 무자녀 여성 내부의 혼인-미혼 차이")

    * 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
    * 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
    * 추정내용: 사전기간 대비 사후기간의 로그 근로시간 변화 차이
    * 먼저 가중치를 사용하지 않은 DiD를 돌린다.
    reghdfe ln_hours i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022), ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hours_did_u

    * 다음으로 같은 회귀에 2019년 개인가중치를 적용한다.
    reghdfe ln_hours i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022) [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hours_did_w

    esttab S_F8_hours_did_u ///
        S_F8_hours_did_w ///
        using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_03_hours_did.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(1.married2019#1.post2021_2022) ///
        coeflabels(1.married2019#1.post2021_2022 "혼인 × 사후기간") ///
        stats(N r2, labels("관측치" "R-squared")) ///
        mtitles("비가중" "가중") ///
        title("플라시보: 재택가능 무자녀 여성의 혼인-미혼 근로시간 DiD")

    coefplot ///
        (S_F8_hours_did_u, label("비가중")) ///
        (S_F8_hours_did_w, label("가중")), ///
        keep(1.married2019#1.post2021_2022) ///
        coeflabels(1.married2019#1.post2021_2022 = "혼인 × 사후기간") ///
        xline(0, lcolor(gs8)) ///
        title("플라시보: 재택가능 무자녀 여성의 혼인-미혼 DiD") ///
        subtitle("2016-2019년 대비 2021-2022년") ///
        xtitle("혼인 여성의 상대적 변화") ///
        legend(rows(1))

    graph export ///
        "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_04_hours_did_coefficient.png", ///
        width(2000) replace

    * 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
    * 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
    * 추정내용: 2019년을 기준으로 두 집단의 연도별 근로시간 변화 차이
    coefplot ///
        (S_F8_marriage_hours_u, label("비가중")) ///
        (S_F8_marriage_hours_w, label("가중")), ///
        keep(1.married2019#*.survey_year) ///
        vertical yline(0, lcolor(gs8)) ///
        xline(3.5, lpattern(dash) lcolor(gs8)) ///
        coeflabels( ///
            1.married2019#2016.survey_year = "2016" ///
            1.married2019#2017.survey_year = "2017" ///
            1.married2019#2018.survey_year = "2018" ///
            1.married2019#2020.survey_year = "2020" ///
            1.married2019#2021.survey_year = "2021" ///
            1.married2019#2022.survey_year = "2022") ///
        ytitle("혼인-미혼 로그 근로시간 변화 차이") ///
        xtitle("조사연도") ///
        title("플라시보: 재택가능 무자녀 여성의 근로시간 event study") ///
        note("기준연도: 2019년") ///
        legend(rows(1))

    graph export ///
        "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_05_hours_event_study.png", ///
        width(2000) replace

    *******************************************************
    * 시간당 임금 event study와 DiD
    *******************************************************

    * 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
    * 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
    * 결과변수: 로그 시간당 임금
    reghdfe ln_hourly_income i.married2019##ib2019.survey_year, ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hourly_event_u

    display as text "비가중 시간당 임금 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    reghdfe ln_hourly_income i.married2019##ib2019.survey_year ///
        [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hourly_event_w

    display as text "가중 시간당 임금 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    reghdfe ln_hourly_income i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022), ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hourly_did_u

    reghdfe ln_hourly_income i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022) [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_hourly_did_w

    coefplot ///
        (S_F8_hourly_event_u, label("비가중")) ///
        (S_F8_hourly_event_w, label("가중")), ///
        keep(1.married2019#*.survey_year) ///
        vertical yline(0, lcolor(gs8)) ///
        xline(3.5, lpattern(dash) lcolor(gs8)) ///
        coeflabels( ///
            1.married2019#2016.survey_year = "2016" ///
            1.married2019#2017.survey_year = "2017" ///
            1.married2019#2018.survey_year = "2018" ///
            1.married2019#2020.survey_year = "2020" ///
            1.married2019#2021.survey_year = "2021" ///
            1.married2019#2022.survey_year = "2022") ///
        ytitle("혼인-미혼 로그 시간당 임금 변화 차이") ///
        xtitle("조사연도") ///
        title("플라시보: 시간당 임금 event study") ///
        note("기준연도: 2019년") ///
        legend(rows(1))

    graph export ///
        "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_06_hourly_wage_event_study.png", ///
        width(2000) replace

    *******************************************************
    * 주간 근로소득 event study와 DiD
    *******************************************************

    * 비교대상 1: 2019년 재택가능 직종에서 일한 혼인 무자녀 여성
    * 비교대상 2: 2019년 재택가능 직종에서 일한 미혼 무자녀 여성
    * 결과변수: 로그 주간 근로소득
    reghdfe ln_weekly_income i.married2019##ib2019.survey_year, ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_weekly_event_u

    display as text "비가중 주간 근로소득 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    reghdfe ln_weekly_income i.married2019##ib2019.survey_year ///
        [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_weekly_event_w

    display as text "가중 주간 근로소득 사전추세 공동검정"
    test 1.married2019#2016.survey_year ///
         1.married2019#2017.survey_year ///
         1.married2019#2018.survey_year

    reghdfe ln_weekly_income i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022), ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_weekly_did_u

    reghdfe ln_weekly_income i.married2019##i.post2021_2022 ///
        if !missing(post2021_2022) [pw=person_wgt2019], ///
        absorb(pid survey_year occ2019#survey_year ind2019#survey_year ///
            region2019#survey_year) vce(cluster pid)
    estimates store S_F8_weekly_did_w

    coefplot ///
        (S_F8_weekly_event_u, label("비가중")) ///
        (S_F8_weekly_event_w, label("가중")), ///
        keep(1.married2019#*.survey_year) ///
        vertical yline(0, lcolor(gs8)) ///
        xline(3.5, lpattern(dash) lcolor(gs8)) ///
        coeflabels( ///
            1.married2019#2016.survey_year = "2016" ///
            1.married2019#2017.survey_year = "2017" ///
            1.married2019#2018.survey_year = "2018" ///
            1.married2019#2020.survey_year = "2020" ///
            1.married2019#2021.survey_year = "2021" ///
            1.married2019#2022.survey_year = "2022") ///
        ytitle("혼인-미혼 로그 주간 근로소득 변화 차이") ///
        xtitle("조사연도") ///
        title("플라시보: 주간 근로소득 event study") ///
        note("기준연도: 2019년") ///
        legend(rows(1))

    graph export ///
        "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_07_weekly_income_event_study.png", ///
        width(2000) replace

    *******************************************************
    * 세 결과변수를 같은 순서로 정리
    *******************************************************

    * 순서: 시간당 임금, 근로시간, 주간 근로소득
    esttab S_F8_hourly_did_u S_F8_hourly_did_w ///
        S_F8_hours_did_u S_F8_hours_did_w ///
        S_F8_weekly_did_u S_F8_weekly_did_w ///
        using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_08_did_all_outcomes.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(1.married2019#1.post2021_2022) ///
        coeflabels(1.married2019#1.post2021_2022 "혼인 × 사후기간") ///
        stats(N r2, labels("관측치" "R-squared")) ///
        mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
            "근로시간 비가중" "근로시간 가중" ///
            "주간소득 비가중" "주간소득 가중") ///
        title("플라시보: 재택가능 무자녀 혼인-미혼 여성 평균 DiD")

    esttab S_F8_hourly_event_u S_F8_hourly_event_w ///
        S_F8_marriage_hours_u S_F8_marriage_hours_w ///
        S_F8_weekly_event_u S_F8_weekly_event_w ///
        using "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_09_event_study_all_outcomes.rtf", ///
        replace se star(* 0.10 ** 0.05 *** 0.01) ///
        keep(1.married2019#*.survey_year) ///
        stats(N r2, labels("관측치" "R-squared")) ///
        mtitles("시간당 임금 비가중" "시간당 임금 가중" ///
            "근로시간 비가중" "근로시간 가중" ///
            "주간소득 비가중" "주간소득 가중") ///
        title("플라시보: 재택가능 무자녀 혼인-미혼 여성 event study")

    coefplot ///
        (S_F8_hourly_did_u, label("시간당 임금 비가중")) ///
        (S_F8_hourly_did_w, label("시간당 임금 가중")) ///
        (S_F8_hours_did_u, label("근로시간 비가중")) ///
        (S_F8_hours_did_w, label("근로시간 가중")) ///
        (S_F8_weekly_did_u, label("주간소득 비가중")) ///
        (S_F8_weekly_did_w, label("주간소득 가중")), ///
        keep(1.married2019#1.post2021_2022) ///
        coeflabels(1.married2019#1.post2021_2022 = "혼인 × 사후기간") ///
        xline(0, lcolor(gs8)) ///
        title("플라시보: 재택가능 무자녀 혼인-미혼 여성 평균 DiD") ///
        subtitle("2016-2019년 대비 2021-2022년") ///
        xtitle("혼인 여성의 상대적 변화") ///
        legend(rows(2))

    graph export ///
        "output/S_F8_Placibo_DiD_telework_married_childless_women_telework_unmarried_childless_women/S_F8_10_did_coefficients_all_outcomes.png", ///
        width(2000) replace
restore

*******************************************************
log close
display as result "S_F8 placebo 세 결과변수 분석이 완성되었습니다."
