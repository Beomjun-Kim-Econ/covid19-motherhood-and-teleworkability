*******************************************************
* 2_clean_klips_panel.do
* 1번 패널자료를 분석 가능한 형태로 정리하기
*
* 이 파일에서 하는 일
* 1. 직종 대분류와 재택 가능 직종을 만든다.
* 2. 자녀 변수를 0/1로 바꾸고 if_child를 만든다.
* 3. 전년도 소득을 실제 소득연도에 맞게 한 해 이동한다.
* 4. 주간소득을 만들고 분석기간을 2016-2022년으로 제한한다.
*******************************************************

version 18.0
clear all
set more off

local project "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
local input "`project'/output/F1_build_panel/F1_klips_panel_19_27.dta"
local output "`project'/output/F2_clean_panel"

capture mkdir "`project'/output"
capture mkdir "`output'"

* 이전 F2 코드가 output 폴더에 남긴 로그가 있으면 정리한다.
capture erase "`output'/F2_clean_klips_panel.log"

use "`input'", clear

isid pid wave
xtset pid wave

*******************************************************
* 1. 직종 대분류와 재택 가능 여부
*******************************************************

generate occ_major = floor(occupation_ksco7 / 100)

generate byte if_remote_possible = .
replace if_remote_possible = 1 if inlist(occ_major, 1, 2, 3)
replace if_remote_possible = 0 if inlist(occ_major, 4, 5, 6, 7, 8, 9)

label variable occ_major "직업분류 대분류"
label variable if_remote_possible "직업 대분류 기준 재택 가능 여부"

*******************************************************
* 2. 자녀 변수 정리
*******************************************************

* 원자료는 1=있다, 2=없다이므로 2를 0으로 바꾼다.
recode child_schoolage child_collegeplus (2 = 0)

label define child_binary 0 "없다" 1 "있다"
label values child_schoolage child_binary
label values child_collegeplus child_binary

* 두 자녀 변수 가운데 하나라도 1이면 자녀가 있는 가구이다.
generate byte if_child = .
replace if_child = 1 if child_schoolage == 1 | child_collegeplus == 1
replace if_child = 0 if child_schoolage == 0 & child_collegeplus == 0

label values if_child child_binary
label variable if_child "자녀 유무"

*******************************************************
* 3. 소득연도 맞추기
*******************************************************

* 조사 t년의 소득 질문은 t-1년 소득이다.
* 따라서 다음 조사에서 보고한 값을 현재 연도로 한 칸 당겨온다.
* 예: 2020년 조사에서 보고한 2019년 소득을 2019년 관측치에 붙인다.

rename annual_labor_income annual_labor_income_reported

generate long annual_labor_income = F.annual_labor_income_reported
generate long spouse_labor_income = F.spouse_labor_income_reported
generate double hh_financial_income = F.hh_fin_income_reported
generate double hh_realestate_income = F.hh_realestate_income_reported

replace income_year = survey_year

label variable annual_labor_income_reported ///
    "조사 당시 보고된 전년도 세전 근로소득(만원)"
label variable annual_labor_income ///
    "조사연도 기준 세전 근로소득(만원)"
label variable spouse_labor_income ///
    "조사연도 기준 배우자 세전 근로소득(만원)"
label variable hh_financial_income ///
    "조사연도 기준 가구 금융소득(만원)"
label variable hh_realestate_income ///
    "조사연도 기준 가구 부동산소득(만원)"

*******************************************************
* 4. 주간소득 만들기
*******************************************************

* 연간소득을 52주로 나누어 주간소득을 만든다.
generate double weekly_labor_income = annual_labor_income / 52 ///
    if !missing(annual_labor_income) & annual_labor_income >= 0

label variable weekly_labor_income "조사연도 기준 주간 근로소득(만원)"

*******************************************************
* 5. 값 확인
*******************************************************

assert inlist(child_schoolage, 0, 1)
assert inlist(child_collegeplus, 0, 1)
assert inlist(if_child, 0, 1)

assert annual_labor_income == F.annual_labor_income_reported ///
    if !missing(F.annual_labor_income_reported)
assert spouse_labor_income == F.spouse_labor_income_reported ///
    if !missing(F.spouse_labor_income_reported)
assert hh_financial_income == F.hh_fin_income_reported ///
    if !missing(F.hh_fin_income_reported)
assert hh_realestate_income == F.hh_realestate_income_reported ///
    if !missing(F.hh_realestate_income_reported)

assert abs(weekly_labor_income - annual_labor_income / 52) < 1e-10 ///
    if !missing(annual_labor_income) & annual_labor_income >= 0

*******************************************************
* 6. 분석기간 정리
*******************************************************

* 2023년 이후 관측치는 앞 단계에서 소득연도를 맞추는 데 사용했다.
* 소득을 옮긴 뒤 최종 분석자료는 2016-2022년만 사용한다.
drop if survey_year >= 2023

assert inrange(survey_year, 2016, 2022)

* 성별은 분석에서 0=여성, 1=남성으로 사용한다.
replace sex = 0 if sex == 2
label variable sex "여성=0, 남성=1"

* 확률가중치는 양수만 사용할 수 있다.
* 원자료에서 0 이하로 기록된 가중치는 분석에서 제외하도록 결측치로 바꾼다.
replace person_wgt_cross_98 = . if person_wgt_cross_98 <= 0
replace person_wgt_long_98 = . if person_wgt_long_98 <= 0
replace person_wgt_cross_09 = . if person_wgt_cross_09 <= 0
replace person_wgt_long_09 = . if person_wgt_long_09 <= 0
replace person_wgt_cross_18 = . if person_wgt_cross_18 <= 0
replace person_wgt_long_18 = . if person_wgt_long_18 <= 0
replace household_wgt_98 = . if household_wgt_98 <= 0
replace household_wgt_09 = . if household_wgt_09 <= 0
replace household_wgt_18 = . if household_wgt_18 <= 0

* 분석에 사용할 09통합표본 가중치가 양수인지 확인한다.
assert person_wgt_cross_09 > 0 if !missing(person_wgt_cross_09)
assert person_wgt_long_09 > 0 if !missing(person_wgt_long_09)

isid pid wave
xtset pid survey_year

compress
save "`output'/F2_klips_panel_19_27_clean.dta", replace

describe
tabulate survey_year

display as result "F2 완료: `output'/F2_klips_panel_19_27_clean.dta"
