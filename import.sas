PROC IMPORT OUT= WORK.TT 
            DATAFILE= "C:\Users\ericy\Documents\METRO\Advanced SAS\proje
ct\Telco Churn Data.csv" 
            DBMS=CSV REPLACE;
     GETNAMES=YES;
     DATAROW=2; 
RUN;
