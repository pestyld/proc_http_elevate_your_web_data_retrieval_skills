filename resp "s:/test.json";

proc http 
   method="GET" 
   url="http://httpbin.org/get" 
   out=resp;
run;

data null;
	rc = jsonpp('resp','log');
run;