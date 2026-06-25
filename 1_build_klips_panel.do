*******************************************************
* 1_build_klips_panel.do
* KLIPS 19~27차 원자료를 하나의 패널로 합치기
*
* 이 파일에서 하는 일
* 1. 개인 자료에서 인구·일자리·소득·가중치를 가져온다.
* 2. 가구 자료에서 자녀·자산소득·가구가중치를 가져온다.
* 3. 같은 가구의 배우자를 찾아 배우자 근로소득을 붙인다.
* 4. 19~27차 자료를 세로로 합쳐 하나의 패널로 저장한다.
*******************************************************

version 18.0
clear all
set more off

* 프로젝트에서 사용하는 폴더를 지정한다.
local project "/Users/beomjunkim/Programming/empirical_appliedmicro/final_project"
local personnel "`project'/data/klips_personnel"
local household "`project'/data/klips_household_onlyforchild"
local output "`project'/output/F1_build_panel"

capture mkdir "`project'/output"
capture mkdir "`output'"

* 이전 F1 코드가 output 폴더에 남긴 로그가 있으면 정리한다.
capture erase "`output'/F1_build_klips_panel.log"

* 각 차수의 자료를 잠시 모아 둘 임시 파일이다.
tempfile panel
local first_wave = 1

* KLIPS 19차부터 27차까지 같은 작업을 반복한다.
forvalues wave = 19/27 {

    * 예: wave가 19이면 w="19", p="p19", h="h19"가 된다.
    local w : display %02.0f `wave'
    local p "p`w'"
    local h "h`w'"
    local household_id "hhid`w'"

    display as text "현재 처리 중인 KLIPS 차수: `wave'"

    ***************************************************
    * 1. 가구 자료 정리
    ***************************************************

    tempfile household_wave
    use "`household'/klips`w'h.dta", clear

    * 18통합표본 가구가중치(nw)는 21차부터 존재한다.
    if `wave' >= 21 {
        keep `household_id' ///
            `h'1501 `h'2001 ///
            `h'2111-`h'2116 ///
            `h'2121-`h'2126 ///
            w`w'h sw`w'h nw`w'h
    }
    else {
        keep `household_id' ///
            `h'1501 `h'2001 ///
            `h'2111-`h'2116 ///
            `h'2121-`h'2126 ///
            w`w'h sw`w'h
    }

    * 현재 차수에 응답하지 않은 과거 가구는 가구번호가 비어 있다.
    drop if missing(`household_id')
    isid `household_id'

    rename `household_id' hhid
    rename `h'1501 child_schoolage
    rename `h'2001 child_collegeplus

    * 금융소득과 부동산소득은 조사연도의 전년도 금액이다.
    rename `h'2111 hh_fin_income_flag_reported
    rename `h'2112 hh_fin_interest_reported
    rename `h'2113 hh_fin_nonbank_reported
    rename `h'2114 hh_fin_capgain_reported
    rename `h'2115 hh_fin_dividend_reported
    rename `h'2116 hh_fin_other_reported

    rename `h'2121 hh_re_income_flag_reported
    rename `h'2122 hh_re_rent_reported
    rename `h'2123 hh_re_salegain_reported
    rename `h'2124 hh_re_landrent_reported
    rename `h'2125 hh_re_keymoney_reported
    rename `h'2126 hh_re_other_reported

    * KLIPS의 무응답 코드 -1을 Stata 결측치로 바꾼다.
    mvdecode hh_fin_income_flag_reported hh_fin_interest_reported ///
        hh_fin_nonbank_reported hh_fin_capgain_reported ///
        hh_fin_dividend_reported hh_fin_other_reported ///
        hh_re_income_flag_reported hh_re_rent_reported ///
        hh_re_salegain_reported hh_re_landrent_reported ///
        hh_re_keymoney_reported hh_re_other_reported, mv(-1)

    * 금융소득의 세부 항목을 더해 금융소득 합계를 만든다.
    egen double hh_fin_income_reported = rowtotal( ///
        hh_fin_interest_reported hh_fin_nonbank_reported ///
        hh_fin_capgain_reported hh_fin_dividend_reported ///
        hh_fin_other_reported), missing
    replace hh_fin_income_reported = 0 if hh_fin_income_flag_reported == 2

    * 부동산소득의 세부 항목을 더해 부동산소득 합계를 만든다.
    egen double hh_realestate_income_reported = rowtotal( ///
        hh_re_rent_reported hh_re_salegain_reported ///
        hh_re_landrent_reported hh_re_keymoney_reported ///
        hh_re_other_reported), missing
    replace hh_realestate_income_reported = 0 if hh_re_income_flag_reported == 2

    * 가구가중치의 이름을 차수와 관계없이 같게 만든다.
    rename w`w'h household_wgt_98
    rename sw`w'h household_wgt_09

    if `wave' >= 21 {
        rename nw`w'h household_wgt_18
    }
    else {
        generate double household_wgt_18 = .
    }

    keep hhid child_schoolage child_collegeplus ///
        hh_fin_income_flag_reported hh_fin_interest_reported ///
        hh_fin_nonbank_reported hh_fin_capgain_reported ///
        hh_fin_dividend_reported hh_fin_other_reported ///
        hh_fin_income_reported ///
        hh_re_income_flag_reported hh_re_rent_reported ///
        hh_re_salegain_reported hh_re_landrent_reported ///
        hh_re_keymoney_reported hh_re_other_reported ///
        hh_realestate_income_reported ///
        household_wgt_98 household_wgt_09 household_wgt_18

    save `household_wave'

    ***************************************************
    * 2. 개인 자료 정리
    ***************************************************

    use "`personnel'/klips`w'p.dta", clear

    * 21차에는 18통합표본 개인가중치가 하나만 있고,
    * 22차부터는 종단면과 횡단면 가중치가 따로 있다.
    if `wave' == 21 {
        keep pid `household_id' hmem`w' ///
            `p'0101 `p'0102 `p'0107 `p'0342 `p'0352 ///
            `p'1006 `p'1007 `p'1702 `p'5501 ///
            `p'0110 `p'0111 `p'0112 `p'0121 ///
            w`w'p_l w`w'p_c sw`w'p_l sw`w'p_c nw`w'p
    }
    else if `wave' >= 22 {
        keep pid `household_id' hmem`w' ///
            `p'0101 `p'0102 `p'0107 `p'0342 `p'0352 ///
            `p'1006 `p'1007 `p'1702 `p'5501 ///
            `p'0110 `p'0111 `p'0112 `p'0121 ///
            w`w'p_l w`w'p_c sw`w'p_l sw`w'p_c ///
            nw`w'p_l nw`w'p_c
    }
    else {
        keep pid `household_id' hmem`w' ///
            `p'0101 `p'0102 `p'0107 `p'0342 `p'0352 ///
            `p'1006 `p'1007 `p'1702 `p'5501 ///
            `p'0110 `p'0111 `p'0112 `p'0121 ///
            w`w'p_l w`w'p_c sw`w'p_l sw`w'p_c
    }

    * 분석에서 이해하기 쉬운 공통 변수명으로 바꾼다.
    rename `household_id' hhid
    rename hmem`w' hmem
    rename `p'0101 sex
    rename `p'0102 relationship_to_head
    rename `p'0107 age
    rename `p'0342 industry_ksic10
    rename `p'0352 occupation_ksco7
    rename `p'1006 regular_hours_week
    rename `p'1007 regular_days_week
    rename `p'1702 annual_labor_income
    rename `p'5501 marital_status
    rename `p'0110 edu_level
    rename `p'0111 education_completion
    rename `p'0112 education_grade
    rename `p'0121 region

    rename w`w'p_l person_wgt_long_98
    rename w`w'p_c person_wgt_cross_98
    rename sw`w'p_l person_wgt_long_09
    rename sw`w'p_c person_wgt_cross_09

    if `wave' == 21 {
        rename nw`w'p person_wgt_long_18
        clonevar person_wgt_cross_18 = person_wgt_long_18
    }
    else if `wave' >= 22 {
        rename nw`w'p_l person_wgt_long_18
        rename nw`w'p_c person_wgt_cross_18
    }
    else {
        generate double person_wgt_long_18 = .
        generate double person_wgt_cross_18 = .
    }

    ***************************************************
    * 3. 같은 가구에서 배우자 찾기
    ***************************************************

    * relationship_to_head의 배우자 관계 코드를 같은 번호로 묶는다.
    generate int spouse_pair = .
    replace spouse_pair = 10 if inlist(relationship_to_head, 10, 20)
    replace spouse_pair = relationship_to_head if inrange(relationship_to_head, 11, 19)
    replace spouse_pair = relationship_to_head - 10 if inrange(relationship_to_head, 21, 29)
    replace spouse_pair = relationship_to_head if inrange(relationship_to_head, 31, 39)
    replace spouse_pair = relationship_to_head - 20 if inrange(relationship_to_head, 51, 59)
    replace spouse_pair = relationship_to_head if inrange(relationship_to_head, 41, 49)
    replace spouse_pair = relationship_to_head - 20 if inrange(relationship_to_head, 61, 69)
    replace spouse_pair = relationship_to_head if inrange(relationship_to_head, 111, 199)
    replace spouse_pair = relationship_to_head - 100 if inrange(relationship_to_head, 211, 299)
    replace spouse_pair = relationship_to_head if inrange(relationship_to_head, 311, 399)
    replace spouse_pair = relationship_to_head - 100 if inrange(relationship_to_head, 411, 499)

    bysort hhid spouse_pair (hmem): generate byte spouse_pair_size = _N ///
        if !missing(spouse_pair)
    assert spouse_pair_size <= 2 if !missing(spouse_pair_size)

    * 한 쌍에 두 사람이 있으면 상대방의 근로소득을 가져온다.
    generate long spouse_labor_income_reported = .
    bysort hhid spouse_pair (hmem): replace spouse_labor_income_reported = ///
        annual_labor_income[3 - _n] if _N == 2 & !missing(spouse_pair)

    drop spouse_pair spouse_pair_size

    ***************************************************
    * 4. 연도 만들기 및 가구 자료 붙이기
    ***************************************************

    generate byte wave = `wave'
    generate int survey_year = `wave' + 1997
    generate int income_year = survey_year - 1

    merge m:1 hhid using `household_wave', ///
        keep(master match) generate(_merge_household)
    assert _merge_household == 3
    drop _merge_household

    order pid wave survey_year income_year hhid hmem ///
        sex relationship_to_head age marital_status ///
        edu_level education_completion education_grade region ///
        industry_ksic10 occupation_ksco7 ///
        regular_hours_week regular_days_week ///
        annual_labor_income spouse_labor_income_reported ///
        hh_fin_income_reported hh_realestate_income_reported ///
        child_schoolage child_collegeplus ///
        person_wgt_long_98 person_wgt_cross_98 ///
        person_wgt_long_09 person_wgt_cross_09 ///
        person_wgt_long_18 person_wgt_cross_18 ///
        household_wgt_98 household_wgt_09 household_wgt_18

    * 첫 차수는 새 파일로 저장하고, 이후 차수는 아래에 이어 붙인다.
    if `first_wave' == 1 {
        save `panel'
        local first_wave = 0
    }
    else {
        append using `panel'
        save `panel', replace
    }
}

*******************************************************
* 5. 완성된 패널 확인 및 저장
*******************************************************

use `panel', clear
sort pid wave
isid pid wave
xtset pid wave

label variable pid "개인 고유식별자"
label variable wave "KLIPS 조사 차수"
label variable survey_year "조사연도"
label variable income_year "보고된 소득의 기준연도"
label variable hhid "차수별 가구 식별번호"
label variable hmem "차수별 가구원 번호"
label variable sex "성별"
label variable relationship_to_head "가구주와의 관계"
label variable age "만나이"
label variable industry_ksic10 "주된 일자리 업종: KSIC 10차"
label variable occupation_ksco7 "주된 일자리 직종: KSCO 7차"
label variable regular_hours_week "주당 정규근로시간"
label variable regular_days_week "주당 정규근로일수"
label variable annual_labor_income "보고된 전년도 세전 근로소득(만원)"
label variable spouse_labor_income_reported "보고된 배우자의 전년도 근로소득(만원)"
label variable marital_status "혼인상태"
label variable edu_level "학력 수준"
label variable education_completion "학력 이수여부"
label variable education_grade "학년"
label variable region "거주지역"
label variable child_schoolage "고등학생 이하 자녀 유무"
label variable child_collegeplus "대학생 이상 자녀 유무"
label variable hh_fin_income_reported "보고된 전년도 가구 금융소득(만원)"
label variable hh_realestate_income_reported "보고된 전년도 가구 부동산소득(만원)"
label variable person_wgt_long_98 "종단면 개인가중치(98표본)"
label variable person_wgt_cross_98 "횡단면 개인가중치(98표본)"
label variable person_wgt_long_09 "종단면 개인가중치(09통합표본)"
label variable person_wgt_cross_09 "횡단면 개인가중치(09통합표본)"
label variable person_wgt_long_18 "종단면 개인가중치(18통합표본)"
label variable person_wgt_cross_18 "횡단면 개인가중치(18통합표본)"
label variable household_wgt_98 "가구가중치(98표본)"
label variable household_wgt_09 "가구가중치(09통합표본)"
label variable household_wgt_18 "가구가중치(18통합표본)"

label define child_yesno 1 "있다" 2 "없다"
label values child_schoolage child_yesno
label values child_collegeplus child_yesno

compress
save "`output'/F1_klips_panel_19_27.dta", replace

describe
tabulate wave
xtdescribe

display as result "F1 완료: `output'/F1_klips_panel_19_27.dta"
