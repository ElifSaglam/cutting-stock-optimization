/* Cutting-stock problem solved using the Decomposition algorithm */
cas mySession sessopts=(caslib=CASUSER timeout=1800 locale="en_US");
libname CASUSER cas caslib=CASUSER ;

data CASUSER.cutting_data;
   input items demand size;
   datalines;
		1  4 2302
		2  5 1569
		3  9 2040  
;

%let capacity= 12000;

/* Optimizasyon */
proc optmodel sessref="mySession";
/* declare parameters and sets */
num capacity = &capacity;
set ITEMS;
num demand {ITEMS};
num size {ITEMS};
num num_raws = sum {i in ITEMS} demand[i];
set RAWS = 1..num_raws;

/* read input data */
read data CASUSER.cutting_data into ITEMS= [items] demand size;

/* define problem */
var UseRaw {RAWS} binary;
var NumAssigned {i in ITEMS, j in RAWS} >= 0 <= demand[i] integer;

minimize NumberOfRawsUsed = sum {j in RAWS} UseRaw[j];

/* respect capacity of each raw */
con knapsack_con {j in RAWS}:
sum {i in ITEMS} size[i] * NumAssigned[i,j] <= capacity
suffixes=(block=j);

/* satisfy demand of each item */
con demand_con {i in ITEMS}:
sum {j in RAWS} NumAssigned[i,j] = demand[i];

/* if NumAssigned[i,j] > 0 then UseRaw[j] = 1 */
con ifthen_con {i in ITEMS, j in RAWS}:
NumAssigned[i,j] <= NumAssigned[i,j].ub * UseRaw[j]
suffixes=(block=j);

/* Decomposition: */
solve with milp / decomp varsel=ryanfoster;

/* These two lines will create the datasets that contain the optimal values for the decision variables */
create data CASUSER.CG_data from [i j] NumAssigned;
create data CASUSER.useRaw_data from [j] useRaw;

/* We want to extract the information on the patterns that are useful, that is, we want to know how to cut the raw stocks*/
create data CASUSER.CG_data_nonZero from [i j]={i in ITEMS, j in RAWS: NumAssigned[i,j]>0} patterns=NumAssigned ;
create data CASUSER.useRaw_data_nonZero from [j]={j in RAWS: useRaw[j]>0} use=useRaw;

run;
quit;

/* Solution Matrix */
proc sort data = CASUSER.CG_DATA;
by j i;
run;

data CASUSER.SOLUTION_TMP;
set CASUSER.CG_DATA;
by j i;
length cut_shape $200;
retain cut_shape;
if first.j then call missing(cut_shape);
cut_shape = catx(', ', cut_shape, NumAssigned);
if last.j;
run;

proc sql;
/* create table CASUSER.SOLUTION as */
select cut_shape, count(1) as count
from CASUSER.SOLUTION_TMP
where cut_shape ne ('0, 0, 0')
group by cut_shape;
quit;
