filename resp "&path\data\01_simple_get_request.json";

proc http 
   method="GET" 
   url="http://httpbin.org/get"
   out=resp;
run;

data _null_;
	rc = jsonpp('resp','log');
run;

