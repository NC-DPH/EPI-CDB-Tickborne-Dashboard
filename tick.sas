/*LAST MODIFIED DATE: 10/31/23*/
/*LAST MODIFIED BY: Deen Gu*/
/*Purpose: Creates the Data Source for the Tickborne dashboard*/
/*	Internal server workbook name:  */
/*	Tableau workbook location: T:\Tableau\Tickborne */


/*Run these options please*/
options compress=yes;
options nofmterr;


/*Create initial data file from cases list*/
proc sql;
create table zoo as
select owning_jd, type, type_desc, CLASSIFICATION_CLASSIFICATION, CASE_ID,
COUNT(DISTINCT CASE_ID) as Case_Ct label = 'Counts',
input(mmwr_year, 4.) as MMWR_YEAR, MMWR_DATE_BASIS,
YEAR(symptom_onset_date) as SYMPTOM_YEAR label= 'Year of Onset', symptom_onset_date, age, DATE_FOR_REPORTING,
calculated SYMPTOM_YEAR as Year label='Year',
QTR(symptom_onset_date) as Quarter
from Tmp1.case
where 2018 LE calculated SYMPTOM_YEAR LE 2023 
AND CLASSIFICATION_CLASSIFICATION in ("Confirmed", "Probable") 
and type in ("ANTH", "ARB", "BRU", "CHIKV", "CJD", "DENGUE", "EHR", "HGE", "EEE", "HME", 
"LAC", "LEP", "WNI", "LEPTO", "LYME", "MAL", "PSTT","PLAG", "QF", "RMSF", "RAB", "TUL", "TYPHUS", 
"YF", "ZIKA", "VHF")
AND REPORT_TO_CDC = 'Yes' /*use for YTD*/
order by TYPE_DESC, SYMPTOM_YEAR, MMWR_Year, OWNING_JD;
quit;

data zoo;
set zoo;
Reporting_Date_Type='Symptom Onset Date';
Disease_Group='Vector-Borne/Zoonotic';
county=substr(owning_jd,1,length(owning_jd)-7);
/*combine diseases together*/
if type_desc = 'Rocky Mountain Spotted Fever (35) ' then type_desc = 'Spotted Fever Rickettsiosis';
if type_desc = 'Ehrlichiosis, Human Monocytic Ehrlichiosis (572) ' then type_desc = 'Ehrlichiosis';
if type_desc = 'Ehrlichiosis, Human Granulocytic Anaplasmosis (571) ' then type_desc = 'Anaplasmosis';
type_desc = prxchange('s/\(.*\)//', -1, type_desc);
run;


/*frequency table*/
proc freq data=zoo;
tables type_desc*year / nocol norow nopercent;
run;

/*Create first summary table, titled s1*/
proc sql;
create table s1 as
select type_desc, county, year, count(*) as count
from zoo
/*where symptom_year > 2005*/
group by type_desc, county, year;
quit;


/*Import county population data*/
proc import datafile='T:\Tableau\NCD3 2.0\Population Denominators\July 1 2022 Vintage Estimates\County Census Pop_10_22.xlsx'
out=county_pops dbms=xlsx replace; run;

/*Copy 2022 denominator data to year 2023*/
proc sql;
create table temp as
select *
from county_pops
where year=2022;
data temp;
set temp;
year=2023;
run;
data county_pops;
set county_pops temp;
COUNTY = propcase(COUNTY);
run;

/*Combine with population denominator data for final data set*/
proc sql;
create table s2 as
select s.*, a.county_pop as county_pop
from s1 as s
join county_pops as a
on upcase(s.county) = upcase(a.county)
and s.year = a.year;
quit;

proc freq data=s2;
	tables type_desc;
run;

/*export data*/
proc export data=s2
	outfile='C:\Users\dgu\Documents\My SAS Files\tickborne\s2.csv'
	dbms=csv
	replace;
run;


/*data scaffolding for tick ID program*/

proc sort data=tickid2 out=unique_ticks (keep=common_name) nodupkey ;
by common_name;
run;


data unique_years;
do Year=2018 to 2023; output; end;
run;

data unique_months;
  do i = 1 to 12;
	month = intnx('month', today(), i, 'b');
    output;
  end;
  format month monname3.;
  keep month;
run;

proc sort data=county_pops out=unique_counties (keep=COUNTY) nodupkey ;
by COUNTY;
run;

proc sql;
create table unique_table as
select unique_counties.*, unique_ticks.*, unique_years.* , unique_months.*
from unique_counties cross join unique_ticks cross join unique_years cross join unique_months;
quit;
