LIBNAME YEE "C:\Users\ericy\Documents\METRO\Advanced SAS\project";


/********************************************************************************
****** Back-ground: data collections and description of your project data *******
*********************************************************************************/

** IMPORT PROJECT DATA TO SAS (PROC IMPORT) **;
PROC IMPORT OUT= YEE.TT 
            DATAFILE= "C:\Users\ericy\Documents\METRO\Advanced SAS\project\Telco Churn Data.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
	 GUESSINGROWS=1000;
RUN;

** DESCRIBE PROPERTIES OF THE PROJECT DATA (PROC CONTENTS) **;
PROC SQL;
  DESCRIBE TABLE YEE.TT;
QUIT;

PROC CONTENTS DATA=YEE.TT VARNUM SHORT;
RUN;

/**********************************************************
****** Study Framework (diagram) : Y and X variables ******
***********************************************************/

** CATEGORICAL VARIABLES: IncomeGroup, CreditRating, Occupation, MaritalStatus **;
** CONTINUOUS VARIABLES: MonthlyRevenue, MonthlyMinutes, TotalRecurringCharge, 
										OverageMinutes, Handsets, BlockedCalls **;
PROC SQL;
  CREATE TABLE YEE.PROJECT_VARS AS
  SELECT CustomerID,
  		 Churn,
 		 IncomeGroup,
		 CreditRating,
		 Occupation,
		 MaritalStatus,
		 INPUT(MonthlyRevenue,BEST12.) AS MonthlyRevenue,
		 INPUT(MonthlyMinutes,BEST12.) AS MonthlyMinutes,
		 INPUT(TotalRecurringCharge,BEST12.) AS TotalRecurringCharge,
		 INPUT(OverageMinutes,BEST12.) AS OverageMinutes,
		 Handsets,
		 BlockedCalls 
  FROM YEE.TT
  WHERE CHURN NE "NA";
QUIT;

PROC CONTENTS DATA= YEE.PROJECT_VARS;
RUN;


/*********************************************************
****** Data Validation: missing values and outliers ******
**********************************************************/

** MISSING VALUE DETECTION **;

* CATEGORICAL *;

*ORIGINAL WAY*;
PROC FREQ DATA = YEE.PROJECT_VARS;
  TABLES Churn IncomeGroup CreditRating Occupation MaritalStatus/missing;
run;

***MACRO PROGRAM***;
%MACRO MISS_CAT(VARS=, DSN=);
ODS PDF FILE = "C:\Users\ericy\Documents\METRO\Advanced SAS\project\PROJECT_MISSING_CAT.PDF";
TITLE 'DATASET: '&DSN;
TITLE2 'CATEGORICAL VARIABLES';
TITLE3 'MISSING VALUES FOR '&VARS;
	PROC FREQ DATA =&DSN;
	  TABLE &VARS/MISSING;
	RUN;
ODS PDF CLOSE;
%MEND MISS_CAT;

*CALL MACRO PROGRAM;
%MISS_CAT(VARS = Churn IncomeGroup CreditRating Occupation MaritalStatus, DSN = YEE.PROJECT_VARS)




* CONTINUOUS *;

*ORIGINAL*;
PROC MEANS DATA = YEE.PROJECT_VARS MAXDEC=2 N NMISS MIN MEAN STD MAX RANGE;
 VAR MonthlyRevenue MonthlyMinutes TotalRecurringCharge OverageMinutes Handsets BlockedCalls;
RUN;

***MACRO PROGRAM***;
%MACRO MISS_CONT(VARS=, DSN=);
ODS PDF FILE = "C:\Users\ericy\Documents\METRO\Advanced SAS\project\PROJECT_MISSING_CONT.PDF";
TITLE 'DATASET: '&DSN;
TITLE2 'CONTINUOUS VARIABLES'
TITLE3 'MISSING VALUES FOR '&VARS;
	PRO MEANS DATA = &DSN MAXDEC=2 N NMISS MIN MEAN STD MAX RANGE;
	  VAR &VARS;
	RUN;
ODS PDF CLOSE;
%MEND MISS_CONT;

%MISS_CONT(VARS = MonthlyRevenue MonthlyMinutes TotalRecurringCharge OverageMinutes Handsets BlockedCalls, DSN = YEE.PROJECT_VARS)



** MISSING VALUE TREATMENT (MEANS OR MEDIAN)**;

* ONLY FOR CONTINUOUS VARS*;
* REPLACE ALL MISSING VALUES WITH MEAN *;
PROC STDIZE DATA = YEE.PROJECT_VARS OUT=YEE.PROJECT METHOD=MEAN REPONLY;
 VAR MonthlyRevenue MonthlyMinutes TotalRecurringCharge OverageMinutes Handsets BlockedCalls;
RUN;

* CHECK TO MAKE SURE ALL MEANS ARE REPLACED *;
PROC MEANS DATA = YEE.PROJECT MAXDEC=2 N NMISS MIN MEAN STD MAX RANGE;
  VAR MonthlyRevenue MonthlyMinutes TotalRecurringCharge OverageMinutes Handsets BlockedCalls;
RUN;

PROC CONTENTS DATA= YEE.PROJECT;
RUN;



** OUTLIER DETECTION AND TREATMENT **;

** BOXPLOT, WHISKER PLOT **;
PROC SGPLOT DATA = YEE.PROJECT ;
 VBOX TotalRecurringCharge/DATALABEL= TotalRecurringCharge;
RUN; 

* FIND Q1, Q3, IQR *;
PROC MEANS DATA = YEE.PROJECT MAXDEC=2 N P25 P75 QRANGE;
  VAR TotalRecurringCharge;
RUN;
* Q1 = 30 / Q3 = 60 / IQR = 30 *;
* LOWERLIMIT = Q1-(3*IQR) = -60 *;
* UPPERLIMIT = Q3+(3*IQR) = 150 *;

PROC SQL;
  CREATE TABLE YEE.PROJECT_OUTLIER AS 
  SELECT * 
  FROM YEE.PROJECT
  WHERE (TotalRecurringCharge BETWEEN -60 AND 150);
QUIT;

PROC CONTENTS DATA=YEE.PROJECT_OUTLIER;
RUN;
  

/********************************************************************
****** Data Transformation: continuous to categorical variable ******
*********************************************************************/

** TURN MonthlyMinutes FROM CONTINUOUS TO CATEGORICAL **; 
PROC FORMAT;
  VALUE MINGRP LOW - 300 = "NORMAL"
  			   301 - 600 = "MEDIUM"
			   601 - 1000 = "HIGH"
			   1001 - 2000 = "VERY HIGH"
			   2001 - HIGH = "EXTREME";
RUN;

PROC FREQ DATA = YEE.PROJECT_OUTLIER;
  TABLE MonthlyMinutes;
  FORMAT MonthlyMinutes MINGRP.;
RUN;



/****************************************************
****** Univariate Analysis: tabular and graphs ******
*****************************************************/

%MACRO UNIVAR(VARS=, DSN=);
ODS PDF FILE = "C:\Users\ericy\Documents\METRO\Advanced SAS\project\PROJECT_&CONT_VAR._PPT.PDF";
	PROC MEANS DATA = &DSN  MAXDEC= 2 N NMISS MIN MEAN MEDIAN MAX STD CLM STDERR ;
	TITLE " UNIVARIATE ANALYSIS OF " %UPCASE(&VARS) ;
	 VAR &VARS;
	RUN;

	PROC SGPLOT DATA = &DSN;
	TITLE " DISTRIBUTION OF " %UPCASE(&VARS);
	 HISTOGRAM &VARS;
	 DENSITY &VARS;
	RUN;

	PROC SGPLOT DATA = &DSN;
	TITLE " DISTRIBUTION OF " %UPCASE(&VARS);
	 VBOX &VARS;
	RUN;

	PROC UNIVARIATE DATA = &DSN;
	TITLE "COMPREHENSIVE UNIVARIATE ANALYSIS OF " %UPCASE(&VARS);
	 VAR &VARS;
	RUN;
ODS PDF CLOSE;
%MEND UNIVAR;

%UNIVAR(VARS = TotalRecurringCharge, DSN = YEE.PROJECT_OUTLIER)

/***********************************************************************************
****** Bivariate Descriptive Analysis: categorical vs continuous /categorical ******
************************************************************************************/

%LET VAR1 = Occupation;
%LET VAR2 = MonthlyMinutes;

ODS PDF FILE = "C:\Users\ericy\Documents\METRO\Advanced SAS\project\PROJECT_BIVAR_&VAR1._&VAR2._PPT.PDF";
PROC FREQ DATA = &DSN;
  TITLE "RELATIONSHIP BETWEEN BETWEEN &VAR1. AND &VAR2.";
  TABLE &VAR1. * &VAR2. /CHISQ NOROW NOCOL ;
  FORMAT MonthlyMinutes MINGRP.;
RUN;

PROC SGPLOT DATA = &DSN;
  TITLE "RELATIONSHIP BETWEEN BETWEEN &VAR1. AND &VAR2.";
  VBAR &VAR1./ GROUP = &VAR2. ;
  FORMAT MonthlyMinutes MINGRP.;
RUN;

*take out Other*;
PROC SGPLOT DATA = &DSN;
  TITLE "RELATIONSHIP BETWEEN BETWEEN &VAR1. AND &VAR2.";
  TITLE2 "(WITHOUT OTHER)";
  VBAR &VAR1./ GROUP = &VAR2. ;
  WHERE Occupation ne 'Other';
  FORMAT MonthlyMinutes MINGRP.;
RUN;

*take out Other and *;
PROC SGPLOT DATA = &DSN;
  TITLE "RELATIONSHIP BETWEEN BETWEEN &VAR1. AND &VAR2.";
  TITLE2 "(WITHOUT OTHER AND PROFESSIONAL)";
  VBAR &VAR1./ GROUP = &VAR2. ;
  WHERE (Occupation ne 'Other') and (Occupation ne 'Professional');
  FORMAT MonthlyMinutes MINGRP.;
RUN;

QUIT;
ODS PDF CLOSE;


/*******************************
****** Hypothesis testing ******
********************************/

** Convert Churn to numeric first **;
DATA YEE.FINAL;
  SET &DSN;
  IF Churn eq 'Yes' then NUMChurn = 1;
  ELSE NUMChurn = 0;
RUN;

*Y (Churn) = X1(Occupation)+ X2(MonthlyMinutes);
* Churn ~ Occupation;
* Churn ~ MonthlyMinutes;
* PEARSONS;
*H0 : no association/correlation;
*HA : MonthlyRevenue and MonthlyMinutes are associated with Score;
** IF P <= 0.05 THEN REJECT H0;
TITLE "Conducting Pearson Correlation";
PROC CORR DATA = YEE.FINAL;
  VAR MonthlyRevenue MonthlyMinutes;
  WITH NUMChurn;
RUN;

