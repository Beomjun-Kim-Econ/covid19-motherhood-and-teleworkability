*******************************************************
* 3_description_and_motivation.do
*
* 목적
* 1. 2019년 기준 비교집단의 규모를 확인한다.
* 2. 재택가능 부모의 고용률과 근로시간 추세를 그린다.
* 3. 재택가능 무자녀 남녀의 추세를 함께 그린다.
* 4. 2019년 집단별 고용률 변화를 2018-2022년에 대해 비교한다.
* 5. 주 분석 표본의 요약통계표를 만든다.
*
* 이 파일은 인과효과를 추정하지 않는다.
* 연구의 표본과 동기를 설명하는 그림만 만든다.
*******************************************************

version 17.0
clear all
set more off
set scheme s2color

cd "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
capture mkdir "output"
capture mkdir "output/F3_description"

use "output/F2_clean_panel/F2_klips_panel_19_27_clean.dta", clear

capture which esttab
if _rc != 0 {
    display as error "요약통계표를 만들려면 esttab이 필요합니다."
    display as error "Stata에서 ssc install estout을 먼저 실행하세요."
    exit 199
}

* 취업 여부와 근로시간 변수를 만든다.
gen byte employed = regular_hours_week > 0 & regular_hours_week < .
gen double ln_hours = ln(regular_hours_week) if employed == 1

* 2019년의 성별, 부모 여부, 재택가능성, 가중치를 고정한다.
preserve
    keep if survey_year == 2019

    gen byte female2019 = sex == 0 if !missing(sex)
    gen byte parent2019 = if_child == 1 if !missing(if_child)
    gen byte remote2019 = if_remote_possible == 1 if !missing(if_remote_possible)

    gen byte group2019 = .
    replace group2019 = 1 if remote2019 == 1 & parent2019 == 1 & female2019 == 1
    replace group2019 = 2 if remote2019 == 1 & parent2019 == 1 & female2019 == 0
    replace group2019 = 3 if remote2019 == 1 & parent2019 == 0 & female2019 == 1
    replace group2019 = 4 if remote2019 == 1 & parent2019 == 0 & female2019 == 0

    label define group2019_label ///
        1 "재택가능 어머니" ///
        2 "재택가능 아버지" ///
        3 "재택가능 무자녀 여성" ///
        4 "재택가능 무자녀 남성"
    label values group2019 group2019_label

    gen double person_wgt2019 = person_wgt_cross_18
    replace person_wgt2019 = person_wgt_cross_09 if missing(person_wgt2019)
    replace person_wgt2019 = person_wgt_cross_98 if missing(person_wgt2019)
    replace person_wgt2019 = 1 if missing(person_wgt2019) | person_wgt2019 <= 0

    keep pid female2019 parent2019 remote2019 group2019 person_wgt2019
    duplicates drop pid, force
    save "output/F3_description/F3_baseline_2019.dta", replace
restore

merge m:1 pid using "output/F3_description/F3_baseline_2019.dta", keep(3) nogen

* 표 1: 2019년 기준 네 비교집단의 표본 수와 가중 표본 비중
preserve
    keep if survey_year == 2019 & !missing(group2019)
    collapse (count) sample_n=pid (sum) weighted_n=person_wgt2019, by(group2019)
    egen double total_weighted_n = total(weighted_n)
    gen double weighted_share = weighted_n / total_weighted_n
    format weighted_share %9.3f
    export excel using "output/F3_description/F3_01_baseline_group_size.xlsx", ///
        firstrow(variables) replace
restore

*******************************************************
* 표 2: 주 분석 표본의 요약통계
*******************************************************
*
* sample_slides.pdf 21페이지와 같이
* Mean, SD, Min, Max, N을 한 표에 제시한다.
*
* 표본은 다음 조건을 모두 만족하는 사람이다.
* 1. 2019년에 재택가능 직종에서 일한 사람
* 2. 어머니, 아버지, 무자녀 여성, 무자녀 남성 중 하나인 사람
* 3. 2020년, 2021년, 2022년에 모두 취업한 사람
*
* KLIPS는 조사자료이므로 보통 요약통계에는 개인 가중치를 적용한다.
* 아래 표의 Mean과 SD는 2019년 개인 가중치를 적용한 값이다.
* Min, Max, N은 실제 관측치 기준이다.
preserve
    * 각 사람이 2020-2022년에 매년 취업했는지 확인한다.
    bysort pid: egen byte employed2020 = ///
        max(cond(survey_year == 2020, employed, .))
    bysort pid: egen byte employed2021 = ///
        max(cond(survey_year == 2021, employed, .))
    bysort pid: egen byte employed2022 = ///
        max(cond(survey_year == 2022, employed, .))

    keep if survey_year == 2019
    keep if !missing(group2019)
    keep if employed2020 == 1
    keep if employed2021 == 1
    keep if employed2022 == 1

    * 표에 사용할 변수를 만든다.
    gen double hourly_wage = weekly_labor_income / regular_hours_week ///
        if weekly_labor_income > 0 & regular_hours_week > 0

    gen double ln_hourly_wage = ln(hourly_wage) ///
        if hourly_wage > 0 & hourly_wage < .

    gen double ln_weekly_labor_income = ln(weekly_labor_income) ///
        if weekly_labor_income > 0 & weekly_labor_income < .

    gen byte female_summary = sex == 0 if inlist(sex, 0, 1)
    gen byte married_summary = marital_status == 2 ///
        if inrange(marital_status, 1, 5)
    gen byte child_summary = if_child == 1 if inlist(if_child, 0, 1)

    * KLIPS 학력 코드 6 이상은 전문대학 이상이다.
    gen byte college_summary = edu_level >= 6 ///
        if inrange(edu_level, 2, 9)

    * 표에 표시될 변수 이름을 정한다.
    label variable regular_hours_week ///
        "Weekly regular hours"
    label variable ln_hourly_wage ///
        "Log hourly wage"
    label variable ln_weekly_labor_income ///
        "Log weekly labor income"
    label variable annual_labor_income ///
        "Annual labor income"

    label variable female_summary "Female"
    label variable age "Age"
    label variable married_summary "Married"
    label variable child_summary "Has child"
    label variable college_summary "College or more"

    label variable spouse_labor_income ///
        "Spouse labor income"

    * Mean, SD, Min, Max, N을 계산한다.
    * summarize는 pweight를 허용하지 않으므로 aweight로 가중 평균을 만든다.
    estpost summarize ///
        regular_hours_week ///
        ln_hourly_wage ///
        ln_weekly_labor_income ///
        annual_labor_income ///
        female_summary ///
        age ///
        married_summary ///
        child_summary ///
        college_summary ///
        spouse_labor_income ///
        [aw=person_wgt2019]

    * Word에서 바로 열 수 있는 표를 만든다.
    esttab . using ///
        "output/F3_description/F3_02_summary_statistics.rtf", ///
        replace ///
        cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2)) count(fmt(0))") ///
        collabels("Mean" "SD" "Min" "Max" "N") ///
        label nonumbers nomtitles noobs ///
        title("Summary Statistics: Main Analysis Sample, Weighted") ///
        refcat(regular_hours_week "Panel A: Key Outcomes" ///
               female_summary "Panel B: Demographics" ///
               spouse_labor_income "Panel C: Spouse Income", nolabel) ///
        addnotes("Mean and SD are weighted by 2019 individual weights. Annual and spouse income are measured in 10,000 KRW.")

    * LaTeX 발표자료에 넣을 수 있는 같은 표를 만든다.
    esttab . using ///
        "output/F3_description/F3_02_summary_statistics.tex", ///
        replace fragment booktabs ///
        cells("mean(fmt(2)) sd(fmt(2)) min(fmt(2)) max(fmt(2)) count(fmt(0))") ///
        collabels("Mean" "SD" "Min" "Max" "N") ///
        label nonumbers nomtitles noobs ///
        refcat(regular_hours_week "Panel A: Key Outcomes" ///
               female_summary "Panel B: Demographics" ///
               spouse_labor_income "Panel C: Spouse Income", nolabel) ///
        addnotes("Mean and SD are weighted by 2019 individual weights. Annual and spouse income are measured in 10,000 KRW.")
restore

* 그림 1: 2019년 집단별 가중 고용률 추세
*
* 남성, 비어머니 여성, 어머니를 재택가능 여부에 따라 나눈다.
* 집단은 2019년의 성별, 자녀 여부, 재택가능성을 기준으로 고정한다.
* 각 집단의 2019년 고용률을 100으로 두고 2018-2022년 변화를 비교한다.
preserve
    keep if inrange(survey_year, 2018, 2022)

    gen byte employment_group2019 = .
    replace employment_group2019 = 1 if female2019 == 0 & remote2019 == 0
    replace employment_group2019 = 2 if female2019 == 0 & remote2019 == 1
    replace employment_group2019 = 3 if female2019 == 1 & parent2019 == 0 & remote2019 == 0
    replace employment_group2019 = 4 if female2019 == 1 & parent2019 == 0 & remote2019 == 1
    replace employment_group2019 = 5 if female2019 == 1 & parent2019 == 1 & remote2019 == 0
    replace employment_group2019 = 6 if female2019 == 1 & parent2019 == 1 & remote2019 == 1
    drop if missing(employment_group2019)

    collapse (mean) employed [pw=person_wgt2019], ///
        by(survey_year employment_group2019)

    * 고용률을 퍼센트로 바꾼 뒤, 각 집단의 2019년 값을 100으로 만든다.
    gen double employment_percent = employed * 100
    bysort employment_group2019: egen double employment_percent_2019 = ///
        max(cond(survey_year == 2019, employment_percent, .))
    gen double employment_index = ///
        employment_percent / employment_percent_2019 * 100

    * 선이 반드시 2018년부터 2022년까지 연도순으로 이어지게 정렬한다.
    sort employment_group2019 survey_year

    twoway ///
        (connected employment_index survey_year if employment_group2019 == 1, ///
            lcolor(blue) mcolor(blue) msymbol(circle) sort) ///
        (connected employment_index survey_year if employment_group2019 == 2, ///
            lcolor(cranberry) mcolor(cranberry) msymbol(circle) sort) ///
        (connected employment_index survey_year if employment_group2019 == 3, ///
            lcolor(green) mcolor(green) msymbol(circle) sort) ///
        (connected employment_index survey_year if employment_group2019 == 4, ///
            lcolor(gold) mcolor(gold) msymbol(circle) sort) ///
        (connected employment_index survey_year if employment_group2019 == 5, ///
            lcolor(purple) mcolor(purple) msymbol(circle) sort) ///
        (connected employment_index survey_year if employment_group2019 == 6, ///
            lcolor(orange) mcolor(orange) msymbol(circle) sort), ///
        xline(2020, lpattern(dash) lcolor(gs8)) ///
        xlabel(2018(1)2022, angle(45)) ///
        ylabel(80(5)100, angle(horizontal)) ///
        ytitle("가중 고용률 지수", size(small) margin(r=12)) ///
        xtitle("연도") ///
        title("F3 O: 2019년 집단별 가중 고용률") ///
        note("주: 각 집단의 2019년 고용률을 100으로 표준화") ///
        legend(order(1 "남성/비재택" 2 "남성/재택가능" ///
                     3 "비어머니/비재택" 4 "비어머니/재택가능" ///
                     5 "어머니/비재택" 6 "어머니/재택가능") ///
               cols(2) position(3) region(lcolor(none)))

    graph export "output/F3_description/F3_06_employment_trends_2018_2022.png", ///
        width(2400) replace

restore

* 그림 2: 재택가능 부모의 고용률 추세
preserve
    keep if inlist(group2019, 1, 2)
    collapse (mean) employed [pw=person_wgt2019], by(survey_year group2019)

    twoway ///
        (connected employed survey_year if group2019 == 1, ///
            lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (connected employed survey_year if group2019 == 2, ///
            lcolor(maroon) mcolor(maroon) msymbol(triangle)), ///
        xline(2020, lpattern(dash) lcolor(gs8)) ///
        xlabel(2016(1)2023) ///
        ytitle("고용률") xtitle("조사연도") ///
        title("재택가능 부모의 고용률") ///
        legend(order(1 "어머니" 2 "아버지") rows(1))

    graph export "output/F3_description/F3_02_remote_parent_employment.png", ///
        width(2000) replace
restore

* 그림 3: 재택가능 부모 중 취업자의 주당 근로시간 추세
preserve
    keep if inlist(group2019, 1, 2) & employed == 1
    collapse (mean) regular_hours_week [pw=person_wgt2019], by(survey_year group2019)

    twoway ///
        (connected regular_hours_week survey_year if group2019 == 1, ///
            lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (connected regular_hours_week survey_year if group2019 == 2, ///
            lcolor(maroon) mcolor(maroon) msymbol(triangle)), ///
        xline(2020, lpattern(dash) lcolor(gs8)) ///
        xlabel(2016(1)2023) ///
        ytitle("주당 근로시간") xtitle("조사연도") ///
        title("재택가능 부모의 주당 근로시간") ///
        legend(order(1 "어머니" 2 "아버지") rows(1))

    graph export "output/F3_description/F3_03_remote_parent_hours.png", ///
        width(2000) replace
restore

* 그림 4: 재택가능 무자녀 남녀의 고용률 추세
preserve
    keep if inlist(group2019, 3, 4)
    collapse (mean) employed [pw=person_wgt2019], by(survey_year group2019)

    twoway ///
        (connected employed survey_year if group2019 == 3, ///
            lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (connected employed survey_year if group2019 == 4, ///
            lcolor(maroon) mcolor(maroon) msymbol(triangle)), ///
        xline(2020, lpattern(dash) lcolor(gs8)) ///
        xlabel(2016(1)2023) ///
        ytitle("고용률") xtitle("조사연도") ///
        title("재택가능 무자녀 남녀의 고용률") ///
        legend(order(1 "여성" 2 "남성") rows(1))

    graph export "output/F3_description/F3_04_remote_nonparent_employment.png", ///
        width(2000) replace
restore

* 그림 5: 재택가능 무자녀 취업자의 주당 근로시간 추세
preserve
    keep if inlist(group2019, 3, 4) & employed == 1
    collapse (mean) regular_hours_week [pw=person_wgt2019], by(survey_year group2019)

    twoway ///
        (connected regular_hours_week survey_year if group2019 == 3, ///
            lcolor(navy) mcolor(navy) msymbol(circle)) ///
        (connected regular_hours_week survey_year if group2019 == 4, ///
            lcolor(maroon) mcolor(maroon) msymbol(triangle)), ///
        xline(2020, lpattern(dash) lcolor(gs8)) ///
        xlabel(2016(1)2023) ///
        ytitle("주당 근로시간") xtitle("조사연도") ///
        title("재택가능 무자녀 남녀의 주당 근로시간") ///
        legend(order(1 "여성" 2 "남성") rows(1))

    graph export "output/F3_description/F3_05_remote_nonparent_hours.png", ///
        width(2000) replace
restore

display as result "F3 기술통계와 동기 그림이 완성되었습니다."
