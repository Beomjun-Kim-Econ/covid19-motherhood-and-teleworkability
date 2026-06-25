*******************************************************
* 11_Selection_labor_market_attachment.do
*
* 선택 분석
* 2019년에 취업한 사람 중 2020년에도 조사에 응답한 사람을 사용한다.
*
* 2020년 근로시간이 양수이면 고용 유지 집단이다.
* 2020년 근로시간이 0 또는 결측이면 고용 이탈 집단이다.
*
* 두 집단의 2019년 평균을 비교하는 변수
* 1. 시간당 임금
* 2. 주당 근로시간
* 3. 주간 근로소득
* 4. 배우자 연간 근로소득
*
* 여성 집단
* - 어머니
* - 비어머니 여성
* - 혼인 무자녀 여성
* - 미혼 여성
*
* 남성 집단
* - 아버지
* - 비아버지 남성
* - 혼인 무자녀 남성
*******************************************************

version 17.0
clear all
set more off

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/S_F11_Selection_labor_market_attachment"

use "output/F2_clean_panel/F2_klips_panel_19_27_clean.dta", clear

*******************************************************
* 1. 2020년 취업상태 만들기
*******************************************************

* 주당 정규근로시간이 양수이면 취업으로 정의한다.
gen byte employed = regular_hours_week > 0 & regular_hours_week < .

* 2020년의 취업상태만 개인별로 따로 저장한다.
preserve
    keep if survey_year == 2020

    gen byte observed2020 = 1
    gen byte employed2020 = employed

    keep pid observed2020 employed2020
    duplicates drop pid, force

    tempfile status2020
    save `status2020'
restore

*******************************************************
* 2. 2019년 취업자와 2020년 상태 연결하기
*******************************************************

* 비교하는 노동시장 특성은 모두 코로나 직전인 2019년 값이다.
keep if survey_year == 2019
keep if employed == 1

* 2020년 조사에 응답하지 않은 사람은 노동시장 이탈인지
* 단순 패널 탈락인지 구분할 수 없으므로 분석에서 제외한다.
merge 1:1 pid using `status2020', keep(3) nogen

gen byte covid_exit = employed2020 == 0
label define covid_exit_label 0 "2020년 고용 유지" 1 "2020년 고용 이탈"
label values covid_exit covid_exit_label

*******************************************************
* 3. 2019년 노동시장 결속도 변수 만들기
*******************************************************

* 금액의 단위는 원자료와 같이 만원이다.
gen double hourly_wage2019 = weekly_labor_income / regular_hours_week ///
    if weekly_labor_income >= 0 & weekly_labor_income < . ///
    & regular_hours_week > 0 & regular_hours_week < .

gen double hours2019 = regular_hours_week ///
    if regular_hours_week > 0 & regular_hours_week < .

gen double weekly_income2019 = weekly_labor_income ///
    if weekly_labor_income >= 0 & weekly_labor_income < .

gen double spouse_income2019 = spouse_labor_income ///
    if spouse_labor_income >= 0 & spouse_labor_income < .

label variable hourly_wage2019 "2019년 시간당 임금(만원)"
label variable hours2019 "2019년 주당 근로시간"
label variable weekly_income2019 "2019년 주간 근로소득(만원)"
label variable spouse_income2019 "2019년 배우자 연간 근로소득(만원)"

* 2019년 개인가중치를 만든다.
gen double person_wgt2019 = person_wgt_cross_18
replace person_wgt2019 = person_wgt_cross_09 if missing(person_wgt2019)
replace person_wgt2019 = person_wgt_cross_98 if missing(person_wgt2019)
replace person_wgt2019 = 1 if missing(person_wgt2019) | person_wgt2019 <= 0

*******************************************************
* 4. 성별·부모·혼인 집단 만들기
*******************************************************

* 아래 집단은 일부가 서로 겹친다.
* 예를 들어 혼인 무자녀 여성은 비어머니 여성에도 포함된다.
gen byte female_mother = sex == 0 & if_child == 1
gen byte female_nonmother = sex == 0 & if_child == 0
gen byte female_married_nochild = ///
    sex == 0 & marital_status == 2 & if_child == 0
gen byte female_unmarried = sex == 0 & marital_status == 1

gen byte male_father = sex == 1 & if_child == 1
gen byte male_nonfather = sex == 1 & if_child == 0
gen byte male_married_nochild = ///
    sex == 1 & marital_status == 2 & if_child == 0

save "output/S_F11_Selection_labor_market_attachment/S_F11_analysis_sample.dta", replace

capture log close
log using "output/S_F11_Selection_labor_market_attachment/S_F11_01_results.log", ///
    text replace

display as text "2019년 취업자 중 2020년 조사에 응답한 분석표본"
tabulate covid_exit

*******************************************************
* 5. 집단별 고용 이탈률 저장하기
*******************************************************

* 표본 수와 이탈률을 집단별로 한 파일에 모은다.
* 비가중 이탈률과 2019년 개인가중치를 사용한 이탈률을 모두 계산한다.
tempname sample_results
postfile `sample_results' ///
    int group_order str50 group_name str12 weighting ///
    double retained_n exit_n total_n exit_rate ///
    using "output/S_F11_Selection_labor_market_attachment/S_F11_sample_counts.dta", ///
    replace

foreach group in female_mother female_nonmother female_married_nochild ///
    female_unmarried male_father male_nonfather male_married_nochild {

    if "`group'" == "female_mother" {
        local group_order = 1
        local group_name "여성: 어머니"
    }
    if "`group'" == "female_nonmother" {
        local group_order = 2
        local group_name "여성: 비어머니"
    }
    if "`group'" == "female_married_nochild" {
        local group_order = 3
        local group_name "여성: 혼인 무자녀"
    }
    if "`group'" == "female_unmarried" {
        local group_order = 4
        local group_name "여성: 미혼"
    }
    if "`group'" == "male_father" {
        local group_order = 5
        local group_name "남성: 아버지"
    }
    if "`group'" == "male_nonfather" {
        local group_order = 6
        local group_name "남성: 비아버지"
    }
    if "`group'" == "male_married_nochild" {
        local group_order = 7
        local group_name "남성: 혼인 무자녀"
    }

    count if `group' == 1 & covid_exit == 0
    local retained_n = r(N)

    count if `group' == 1 & covid_exit == 1
    local exit_n = r(N)

    count if `group' == 1
    local total_n = r(N)

    summarize covid_exit if `group' == 1
    local exit_rate = r(mean)

    post `sample_results' ///
        (`group_order') ("`group_name'") ("비가중") ///
        (`retained_n') (`exit_n') (`total_n') (`exit_rate')

    summarize covid_exit [aw=person_wgt2019] if `group' == 1
    local weighted_exit_rate = r(mean)

    post `sample_results' ///
        (`group_order') ("`group_name'") ("가중") ///
        (`retained_n') (`exit_n') (`total_n') (`weighted_exit_rate')
}

postclose `sample_results'

preserve
    use "output/S_F11_Selection_labor_market_attachment/S_F11_sample_counts.dta", clear
    sort group_order weighting
    format exit_rate %9.3f

    export excel using ///
        "output/S_F11_Selection_labor_market_attachment/S_F11_02_sample_counts.xlsx", ///
        firstrow(variables) replace

    display as text "집단별 2020년 고용 이탈률"
    list group_name weighting retained_n exit_n total_n exit_rate, ///
        sepby(group_order) noobs
restore

*******************************************************
* 6. 2019년 평균과 이탈-유지 차이 계산하기
*******************************************************

* difference는 '2020년 고용 이탈자 평균 - 고용 유지자 평균'이다.
* 음수이면 이탈자의 2019년 평균이 유지자보다 낮았다는 뜻이다.
tempname mean_results
postfile `mean_results' ///
    int group_order str50 group_name ///
    int outcome_order str50 outcome_name ///
    str12 weighting ///
    double retained_mean exit_mean difference standard_error ///
    p_value ci_lower ci_upper retained_n exit_n ///
    using "output/S_F11_Selection_labor_market_attachment/S_F11_mean_differences.dta", ///
    replace

foreach group in female_mother female_nonmother female_married_nochild ///
    female_unmarried male_father male_nonfather male_married_nochild {

    if "`group'" == "female_mother" {
        local group_order = 1
        local group_name "여성: 어머니"
    }
    if "`group'" == "female_nonmother" {
        local group_order = 2
        local group_name "여성: 비어머니"
    }
    if "`group'" == "female_married_nochild" {
        local group_order = 3
        local group_name "여성: 혼인 무자녀"
    }
    if "`group'" == "female_unmarried" {
        local group_order = 4
        local group_name "여성: 미혼"
    }
    if "`group'" == "male_father" {
        local group_order = 5
        local group_name "남성: 아버지"
    }
    if "`group'" == "male_nonfather" {
        local group_order = 6
        local group_name "남성: 비아버지"
    }
    if "`group'" == "male_married_nochild" {
        local group_order = 7
        local group_name "남성: 혼인 무자녀"
    }

    foreach outcome in hourly_wage2019 hours2019 ///
        weekly_income2019 spouse_income2019 {

        if "`outcome'" == "hourly_wage2019" {
            local outcome_order = 1
            local outcome_name "시간당 임금(만원)"
        }
        if "`outcome'" == "hours2019" {
            local outcome_order = 2
            local outcome_name "주당 근로시간"
        }
        if "`outcome'" == "weekly_income2019" {
            local outcome_order = 3
            local outcome_name "주간 근로소득(만원)"
        }
        if "`outcome'" == "spouse_income2019" {
            local outcome_order = 4
            local outcome_name "배우자 연간 근로소득(만원)"
        }

        ***************************************************
        * 6-1. 비가중 평균과 평균 차이
        ***************************************************

        summarize `outcome' if `group' == 1 & covid_exit == 0
        local retained_mean = r(mean)
        local retained_n = r(N)

        summarize `outcome' if `group' == 1 & covid_exit == 1
        local exit_mean = r(mean)
        local exit_n = r(N)

        local difference = .
        local standard_error = .
        local p_value = .
        local ci_lower = .
        local ci_upper = .

        capture regress `outcome' covid_exit if `group' == 1, vce(robust)
        if _rc == 0 {
            local difference = _b[covid_exit]
            local standard_error = _se[covid_exit]
            local p_value = 2 * ttail(e(df_r), ///
                abs(`difference' / `standard_error'))
            local critical_value = invttail(e(df_r), 0.025)
            local ci_lower = `difference' - ///
                `critical_value' * `standard_error'
            local ci_upper = `difference' + ///
                `critical_value' * `standard_error'
        }

        post `mean_results' ///
            (`group_order') ("`group_name'") ///
            (`outcome_order') ("`outcome_name'") ("비가중") ///
            (`retained_mean') (`exit_mean') (`difference') ///
            (`standard_error') (`p_value') (`ci_lower') (`ci_upper') ///
            (`retained_n') (`exit_n')

        ***************************************************
        * 6-2. 가중 평균과 평균 차이
        ***************************************************

        summarize `outcome' [aw=person_wgt2019] ///
            if `group' == 1 & covid_exit == 0
        local retained_mean = r(mean)

        summarize `outcome' [aw=person_wgt2019] ///
            if `group' == 1 & covid_exit == 1
        local exit_mean = r(mean)

        local difference = .
        local standard_error = .
        local p_value = .
        local ci_lower = .
        local ci_upper = .

        capture regress `outcome' covid_exit if `group' == 1 ///
            [pw=person_wgt2019], vce(robust)
        if _rc == 0 {
            local difference = _b[covid_exit]
            local standard_error = _se[covid_exit]
            local p_value = 2 * ttail(e(df_r), ///
                abs(`difference' / `standard_error'))
            local critical_value = invttail(e(df_r), 0.025)
            local ci_lower = `difference' - ///
                `critical_value' * `standard_error'
            local ci_upper = `difference' + ///
                `critical_value' * `standard_error'
        }

        post `mean_results' ///
            (`group_order') ("`group_name'") ///
            (`outcome_order') ("`outcome_name'") ("가중") ///
            (`retained_mean') (`exit_mean') (`difference') ///
            (`standard_error') (`p_value') (`ci_lower') (`ci_upper') ///
            (`retained_n') (`exit_n')
    }
}

postclose `mean_results'

use "output/S_F11_Selection_labor_market_attachment/S_F11_mean_differences.dta", clear
sort group_order outcome_order weighting

format retained_mean exit_mean difference standard_error ci_lower ci_upper %12.3f
format p_value %9.4f

export excel using ///
    "output/S_F11_Selection_labor_market_attachment/S_F11_03_mean_differences.xlsx", ///
    firstrow(variables) replace

display as text "2019년 노동시장 결속도: 고용 이탈자와 유지자의 평균 차이"
list group_name outcome_name weighting retained_mean exit_mean ///
    difference p_value retained_n exit_n, sepby(group_order) noobs

log close
display as result "S_F11 노동시장 결속도 선택 분석이 완성되었습니다."
