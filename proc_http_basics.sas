/* SAS PROC HTTP: Elevate Your Web Data Retrieval Skills */


/*********************************************************
SETUP
**********************************************************/

/* REQUIRED: Set path to your main folder */
%let path = C:\Users\pestyl\OneDrive - SAS\github repos\proc_http_elevate_your_web_data_retrieval_skills; /* My local path */
*%let path = %SYSGET(HOME);                                                                               /* My viya path */

/* View path */
%put &=path;


%macro viewData(myData,total=50);
/* 
    The macro previews 50 rows of your table by default.

    Parameters:
        myData - specify the library and table name
        obs - number of rows to preview. Default is 50.
*/

    title height=16pt "TABLE: %upcase(&myData)";
    proc print data=&myData(obs=&total);
    run;
    title;

%mend;


%macro showImage(image);
/* 
    The macro renders images in the SAS notebook or SAS results.

    Parameter:
        image - specify the full path and file name within quotes.
*/

    data _null_;
        declare odsout obj();
        obj.image(file:&image);
    run;

%mend;



/*********************************************************
## 1. Simple GET request
### a. Store the CSV file response on the server. 
- View the output, notice the NOTE: 200 OK indicates the request was successful.
- Vew the data folder, notice that the file has been saved.
**********************************************************/

filename resp "&path/data/01_cars.csv"; /* Create file to save download to */

proc http 
   method="GET" 
   url="https://support.sas.com/documentation/onlinedoc/viya/exampledatasets/cars.csv"
   out=resp;
run;


/* Use traditional SAS methods to import the CSV file into SAS and process the data.*/
proc import datafile=resp      /* Specify the CSV file reference */
            dbms=csv 
            out=work.mycars;   /* Create the SAS table */
run;

/* Preview the data using the user macro */
%viewData(work.mycars, total=10)


/*
### b. Store the JSON file response on the server. 
Using [httpbin.org](https://httpbin.org/) for demonstration purposes. It is a simple HTTP Request & Response Service.
*/
filename resp "&path/data/02_simple_get_request.json";  /* Store JSON response in the new JSON file */

proc http 
   method="GET" 
   url="http://httpbin.org/get"
   out=resp;
run;


/*
### c. Store the response as a temporary file on SAS. 
Use this method if you don't want to download the file permanently, but want to use it for your process.  
*/
filename resp temp;

proc http 
   method="GET" 
   url="http://httpbin.org/get"
   out=resp;
run;

/* View the temporary JSON file using a DATA NULL step with the jsonpp function */
data _NULL_;
    rc = jsonpp('resp','log');  /* JSONPP is JSON pretty print, easier to read */
run;


/*
### d. PROC HTTP Response Status Macro Variables
Beginning with SAS 9.4M5, PROC HTTP sets up macro variables with certain values after it executes each statement. These macro variables can be used inside a macro to test for HTTP errors. An HTTP error is an error that is encountered after a successful host connection has been made and the HTTP request has been successfully parsed by the HTTP procedure. The macro variables do not store values for host connection errors or for PROC HTTP syntax errors. The macro variables are reset on each invocation of PROC HTTP.


SYS_PROCHTTP_STATUS_CODE
stores the status code of the HTTP request.

SYS_PROCHTTP_STATUS_PHRASE
stores the descriptive phrase that is associated with the status code.

[PROC HTTP Response Status Macro Variables](https://go.documentation.sas.com/doc/en/pgmsascdc/9.4_3.5/proc/p0mwmz1upde0tqn1ptt5rnlly0tc.htm)
*/

%put &=SYS_PROCHTTP_STATUS_CODE;
%put &=SYS_PROCHTTP_STATUS_PHRASE;


/*
Create a simple macro program for the PROC HTTP response macro variable for your pipeline if necessary.
*/
%macro check_for_200();
    /* Success note if a response of 200 */
    %if &SYS_PROCHTTP_STATUS_CODE  = 200 %then %do;
        %put NOTE: Yay! Succesful PROC HTTP request! I did it!;
    %end;
    %else %do; /* If not 200, do the following */
        /* Return HTTP response macro variable information */
        %put ERROR: Terrible job. You did something wrong. Failed PROC HTTP request.;
        %put ERROR: ERROR description: &SYS_PROCHTTP_STATUS_CODE &SYS_PROCHTTP_STATUS_PHRASE;
        /*The %RETURN macro causes normal termination of the currently executing macro. */
        %return; 
    %end;
%mend;


/* PRINT MESSAGE THAT CAME BACK AS AN ERROR WITHIN THE ELSE DO */
%check_for_200;


/* Get a an incorrect code check when using an invalid URL. */
filename badreq temp;

proc http 
   method="GET" 
   url="http://httpbin.org/bad_address_adfkad"    /* Invalid URL */
   out=badreq
   timeout=5; /* add timeout to end quicker */
run;

/* Run the macro and view the log. Returns an error and stops processing */
%check_for_200()



/**********************************************************
## 2. Working with a JSON File (JSON LIBNAME ENGINE)
View the JSON response in the log with the DATA step.
**********************************************************/
/* Rerun the code to download the file */
filename resp "&path/data/02_simple_get_request.json";

/* Send request */
proc http 
   method="GET" 
   url="http://httpbin.org/get"
   out=resp;
run;


/* View the file in the JSON file in the log with indentations */
data _null_;
	rc = jsonpp('resp','log');
run;


/*
### a. Create a SAS library to the JSON response file.
Notice that SAS creates 4 tables in the library.
*/

/* Create a library reference to the JSON file using the JSON engine */
libname resp json fileref=resp;

/* View the library and tables that are created */
proc contents data=resp._all_ nods;
run;

/*
Preview each table in the library.
*/
%viewData(resp.alldata)
%viewData(resp.root)
%viewData(resp.args)
%viewData(resp.headers)


/*
### b. Store a value from the response in a macro variable
**Scenario:** Store the  **Host** value from the JSON file dictionary,  "Host": *"httpbin.org"*, in a macro variable to use later.
*/
data _null_;
    set resp.headers;
    call symputx('hostValue', Host);
run;

/* View the macro variable value */
%put &=hostValue;


/*
### c. Join the JSON file objects into a single structured table.
Depending on the JSON response, you might need to join the tables to create the final table for your objectives.
*/
proc sql;
SELECT *
FROM resp.root as r
    INNER JOIN resp.headers as h ON r.ordinal_root = h.ordinal_root;
quit;



/**********************************************************
## 3. Password Authentication
Use user/password authentication with PROC HTTP.

**FOLLOW ALL COMPANY POLICY REGARDING AUTHENTICATION.**

### a. Simple user/password plain text

**Scenario:** Forget to use user/password authentication when it's required.

Notice that it returns a 401 Unauthorized response.
**********************************************************/
filename badpass temp;

proc http 
   method="GET" 
   url="https://httpbin.org/basic-auth/myusername/pAssw0rd"  /*username is myusername, password is pAss0wrd */
   out=badpass;
run;

/* Add 200 checker */
%check_for_200()



/* 
Add the username/password in plain text (DEMO PURPOSES ONLY, DON'T ENTER YOUR USERNAME AND PASSWORD IN PLAIN TEXT EVER!).

Notice that the results return 200 OK.
*/
filename goodpass temp;

proc http 
   method="GET" 
   url="https://httpbin.org/basic-auth/myusername/pAssw0rd"
   webusername="myusername"  /* username */
   webpassword="pAssw0rd"    /* password */
   out=goodpass;
run;

data _NULL_;
   rc = jsonpp('goodpass','log');
run;


/* View the response from the server. */
libname myfile json fileref=goodpass 
                    noalldata;  /* The NOALLDATA option removes the ALLDATA table. This can be more efficienct for large data */

/* View all tables in the library */
proc contents data=myfile._all_ nods;
run;

/* Preview the root table */
%viewData(myfile.root)

/* Clear your library */
libname myfile close;

/*
### b. Store authentication information in macro variables
Add your authentication information within your autoexec or a program.

Please follow all company policy regarding authentication.
*/

/* Execute the program that contains my authorization information */
%include "&path/auth/cred_plain_text.sas";

/* Create a temporary file */
filename goodpass temp;

proc http 
   method="GET" 
   url="https://httpbin.org/basic-auth/myusername/pAssw0rd"
   webusername="&username"
   webpassword="&password"
   out=goodpass;
run;

/* View the response in the log */
data _null_;
   view = jsonpp('goodpass','log');
run;


/*
### c. Encrypt your password
Add your authentication information within your autoexec or a program.

Resources:
- [Five strategies to eliminate passwords from your SAS programs](https://blogs.sas.com/content/sasdummy/2010/11/23/five-strategies-to-eliminate-passwords-from-your-sas-programs/)
- [PWENCODE Procedure Documentation](https://go.documentation.sas.com/doc/en/pgmsascdc/default/proc/n0dc6in0v7nfain1f2whl6f5x66p.htm)
- [Example to Encode SAS Passwords](https://blogs.sas.com/content/sastraining/2008/12/05/example-to-encode-sas-passwords/)

Encode your password.
*/
proc pwencode in="pAssw0rd"
  method=sas002;
run;

/* Specify your encoded pasword in  macro variable */
%let encodedPass = {SAS002}DA9A0A5C07B7C78E1F4B7FFA25F192A4;

filename goodpass temp;

proc http 
   method="GET" 
   url="https://httpbin.org/basic-auth/myusername/pAssw0rd"
   webusername="&username"
   webpassword="&encodedPass"  /* Encoded password */
   out=goodpass;
run;

/* View the response in the log */
data _null_;
   view = jsonpp('goodpass','log');
run;



/**********************************************************
## 4. Bearer Authentication
### a. Forget to provide token
Prompts the user for authorization using bearer authentication. No auth is specified here so it will be unauthorized.
**********************************************************/

filename nobear temp;

proc http 
   method="GET" 
   url="https://httpbin.org/bearer"
   out=nobear;
run;

/* View the response in the log */
data _null_;
   view = jsonpp('nobear','log');
run;


/*
### b. Provide token for authentication
*/
filename goodbear temp;

/* Provide access token */
%let access_token = gakdfdadfkae213913;

proc http 
   method="GET" 
   url="https://httpbin.org/bearer" 
   oauth_bearer="&access_token"       /* Access token */
   out=goodbear;
run;

/* View the response in the log */
data _null_;
   view = jsonpp('goodbear','log');
run;



/***********************************************************
## 5.Debugging options
***********************************************************/
filename resp temp;

proc http 
        method="GET" 
        url="http://httpbin.org/get/adfk/adskfbadaddress"
        out=resp;
    debug level=1; /* More verbose information on how your machines are talking to each other */
run;


filename badpass temp;

proc http 
        method="GET" 
        url="https://httpbin.org/basic-auth/myusername/pAssw0rd"
        out=badpass
        webusername='bad-user-name'
        webpassword='bad-password';
    debug level = 3;
run;



/***********************************************************
## 6. End to End ETL Using JSON Data from the World Bank API
### Using a Rest API
***********************************************************/%showImage("&path/images/01_using_rest_api.jpg")

%showImage("&path/images/02_parts_url_params.jpg")

/*
### Scenario: View the GDP of Greece, Brazil and the United States from 2000 - 2022
### a. JSON Response
Use the API URL from the World Bank.

[About the Indicators API Documentation](https://datahelpdesk.worldbank.org/knowledgebase/articles/889392-about-the-indicators-api-documentation)

[Go to the World Bank API request below directly](https://api.worldbank.org/v2/country/GR;BR;US/indicator/NY.GDP.MKTP.CD/?format=json&per_page=100&date=2000:2022)

#### 1. Get the JSON response.
*/


/* Create temp JSON file for the JSON response */
filename jsonresp "&path/data/03_GR_US_BR_GDP.json";

/*
	Send the GET request to the World Bank 
	Notes: Be careful with special characters so you don't make the & call macro variables.
	Parameters:
	- format = json
	- per_page = 100
	- date = 2000:2022
*/
proc http
	url = 'https://api.worldbank.org/v2/country/GR;BR;US/indicator/NY.GDP.MKTP.CD/?format=json&per_page=100&date=2000:2022'  
	out = jsonresp in='format=json&per_page'
	method='GET';
run;

/* View the JSON contents */
data _null_;
	viewJson = jsonpp('jsonresp', 'log');
run;


/*
The QUERY= option makes adding query parameters to a URL easier. You can still add query parameters to a URL manually as shown above. This will achieve the same results. 
*/

/* Create temp JSON file for the JSON response */
filename jsonresp "&path/data/03_GR_US_BR_GDP.json";

/* Send the GET request to the World Bank */
proc http
	url = 'https://api.worldbank.org/v2/country/GR;BR;US/indicator/NY.GDP.MKTP.CD/'
	out = jsonresp
	method='GET'
    query = ('format'='json'         /* Use the the query option to add parameters */ /* check for viya3.5 */
	         'per_page'='300' 
			 'date'='2000:2022'); 
run;

/* View the JSON contents */
data _null_;
	viewJson = jsonpp('jsonresp', 'log');
run;


/*
#### 2. Create a library to the JSON file.
*/
libname jsonFile JSON fileref=jsonresp noalldata;

/* View tables in the library */
proc contents data=jsonFile._ALL_ nods;
run;

/* Preview 20 rows from each table */
%viewData(jsonFile.root,total=20)
%viewData(jsonFile.country,total=20)
%viewData(jsonFile.indicator,total=20)


/*
#### 3. Store the lastUpdated value in a macro to use later.
*/
data _NULL_;
    set jsonFile.root(obs=1);
    call symputx('LastUpdatedDate',lastUpdated);
run;

/* View the macro value */
%put &=LastUpdatedDate;


/*
#### 4. Prepare the data into a single structured table
*/
proc sql;
CREATE TABLE work.countries_gdp AS 
SELECT r.countryiso3code as COUNTRYISO3CODE, 
	   ctry.value as COUNTRY,
	   input(r.date,8.) as DATE,                 /* Convert char date to a SAS date value */
	   r.value as GDP format=dollar20.,
	   i.value AS GDP_VALUE
FROM jsonFile.root as r 
	INNER JOIN jsonFile.country as ctry ON r.ordinal_root=ctry.ordinal_root
	INNER JOIN jsonFile.indicator as i ON r.ordinal_root=i.ordinal_root
ORDER BY Country, Date;
quit;

footnote "Last Updated: &LastUpdatedDate";

%viewData(work.countries_gdp,total=35)


/*
#### 5. Simple analysis.
*/
proc means data=work.countries_gdp;
    class Country;
run;


/*
#### 6. Visualize the data.
*/
/* Set macro variables with specified HEX colors */
%let brazilColor=CX009739;
%let USColor=CXb22234;
%let greeceColor=CX0d5EAF;
%let textGray=charcoal;


/* Visualization */
title justify=left height=14pt color=&textGray "Comparative Analysis of GDP Trends: United States, Greece, and Brazil (2000-2022)";
footnote justify=left italic height=10pt color=&textGray "Data last updated on &LastUpdatedDate";

ods graphics / width=10in height=5in;
proc sgplot data=work.countries_gdp
			noborder;
	styleattrs datacontrastcolors=(&brazilColor &greeceColor &USColor);
	series x=Date y=GDP / 
		group=Country
		markers markerattrs=(symbol=circleFilled)
		curvelabel;
	xaxis valueattrs=(color=&textGray) 
		  display=(nolabel)
		  values=(2000 to 2022 by 2);
	yaxis valueattrs=(color=&textGray) 
		  labelpos=top labelattrs=(color=&textGray size=11pt) label='GDP (Current US$)';
	styleattrs backcolor=white wallcolor=white;
run;
ods graphics / reset;

title; footnote;



/*
### b. XML Response
Achieves the same results as the JSON file above.

#### 1. Get the XML response, save the file and view the raw XML data.
*/
/* Create temp JSON file for the JSON response */
filename xmlresp "&path/data/03_GR_US_BR_GDP.xml";

/* Send the GET request to the World Bank */
proc http
	url = 'https://api.worldbank.org/v2/country/GR;BR;US/indicator/NY.GDP.MKTP.CD/'
	out = xmlresp
	method='GET'
    query = ('format'='xml'         /* Changed to XML. Use the the query option to add parameters */
	         'per_page'='300' 
			 'date'='2000:2022'); 
run;

/* View the XML contents */
data _null_;
	infile xmlresp;
    input;
    put _infile_;
run;

/* View the XML contents */
data _null_;
    file print;
	infile xmlresp;
    input;
    put _infile_;
run;


/*
#### 2. Read an XML file and create a SAS table
*/
/* Create a library to the XML file */
filename xml_map temp;
libname xmlFile xmlv2 xmlfileref=xmlresp 
                      xmlmap=xml_map 
                      automap=replace;

/* View SAS library */
proc contents data=xmlFile._all_ nods;
run;

/* View data */
/* Preview 20 rows from each table */
%viewData(xmlFile.country,total=20)
%viewData(xmlFile.data,total=20)
%viewData(xmlFile.data1,total=20)
%viewData(xmlFile.indicator,total=20)


/*
#### 3. Get the last updated date in a macro variable.
*/
/* lastupdated column is a SAS date value */
proc contents data=xmlFile.data;
run;

data _null_;
    set xmlFile.DATA;
    str_updated_date = put(data_lastupdated, mmddyy10.);   /* The XML last updated date is a SAS date value (numeric) with a format. Create a string date */
    call symputx ('lastUpdatedDate',str_updated_date);
run;

%put &=lastUpdatedDate;


/*
#### 4. Create a structured table.
*/
proc sql;
create table work.countries_gdp_xml as 
	select r.countryiso3code,
		   ctry.country as Country,
		   r.date,
		   input(r.value,best20.) as GDP format=dollar20.,
		   i.indicator
		from xmlFile.data1 as r 
		inner join xmlFile.country as ctry 
			on r.data1_ORDINAL=ctry.data1_ORDINAL
		inner join xmlFile.indicator as i 
			on r.data1_ORDINAL=i.data1_ORDINAL
		order by Country, Date;
;
quit;

%viewData(work.countries_gdp_xml, total=35)


/*
#### 5. Analyze the structured table.
*/
proc means data=work.countries_gdp_xml;
    class Country;
run;


/*
#### 6. Visualize the data.
*/
/* Set macro variables with specified HEX colors */
%let brazilColor=CX009739;
%let USColor=CXb22234  ;
%let greeceColor=CX0d5EAF;
%let textGray=charcoal;

/* Visualization */
title justify=left height=14pt color=&textGray "Comparative Analysis of GDP Trends: United States, Greece, and Brazil (2000-2022)";
footnote justify=left italic height=10pt color=&textGray "Data last updated on &lastUpdatedDate";

ods graphics / width=10in height=5in;
proc sgplot data=work.countries_gdp_xml
			noborder;
	styleattrs datacontrastcolors=(&brazilColor &greeceColor &USColor);
	series x=Date y=GDP / 
		group=Country
		markers markerattrs=(symbol=circleFilled)
		curvelabel;
	xaxis valueattrs=(color=&textGray) 
		  display=(nolabel)
		  values=(2000 to 2022 by 2);
	yaxis valueattrs=(color=&textGray) 
		  labelpos=top labelattrs=(color=&textGray size=11pt) label='GDP (Current US$)';
	styleattrs backcolor=white wallcolor=white;
run;
ods graphics / reset;

title; footnote;



/***********************************************************
## 7. Web Scraping

Test using the [Web Scraper test site](https://webscraper.io/test-sites).

### a. Start by saving the HTML to a text file.
***********************************************************/
filename scrape "&path/data/04_web_scrape.txt";

/* test site, I saved the HTML file in the data folder. Otherwise the HTML changes. */

/* 
proc http 
        method="GET" 
        url="https://webscraper.io/test-sites/e-commerce/allinone_test_error_url"
        out=scrape;
run;
*/


/*
### b. View the file using the DATA step
You can also programmatically view the file in the log.
*/
data _NULL_;
    infile scrape;
    input;
    put _infile_;
run;


/*
### c. Create a SAS table by parsing the HTML using regular expressions

#### Test HTML web scraping parsing logic
*/
data raw_scrape;
    infile scrape;
    input;

    /* Create regular expressions */
    re_price = prxparse('/\$\d+(\.\d{2})?/'); 
    re_item = prxparse('/title="([^"]+)/'); 
    re_desc = prxparse('/<p class="description card-text">(.*?)<\/p>/');

    /* Read in the entire row of data into SAS in the column row */
    row = _infile_;

    /* 
    Find rows with necessary values 
    - Manual process to find what rows you need.
    */
    findRowPrice = find(row,'price');
    findRowItem = find(row,'title=');
    findRowDesc = find(row,'class="description');

    if findRowPrice > 1 or
       findRowItem > 1 or 
       findRowDesc > 1;

    /*
    If find the specified row, use regex to get the necessary value 
    */

    /* Extract the price */
    if findRowPrice > 1 then do;
        start = prxmatch(re_price, row);
        Price = prxposn(re_price, 0, row);
    end;

    /* Extract item name */
    else if findRowItem > 1 then do;
        start = prxmatch(re_item, row);
        Item = tranwrd(prxposn(re_item, 0, row),'title="','');
    end;

    /* Extract description */
    else if findRowDesc > 1 then do;
        start = prxmatch(re_desc, row);
        Description = prxposn(re_desc, 0, row);
    end;
run;

/* Preview data */
%viewData(work.raw_scrape)

/* View table metadata */
ods select Variables;
proc contents data=work.raw_scrape;
run;


/*
Create the final structured table with the three items by using an array to store the values and output when the description is found.
*/

data raw_scrape;
    infile scrape;
    input;

    /* Create array of new columns to retain values as they are found */
    array itemCols {*} $250 Price Item Description ('' '' '');

    /* Create regular expressions */
    re_price = prxparse('/\$\d+(\.\d{2})?/'); 
    re_item = prxparse('/title="([^"]+)/'); 
    re_desc = prxparse('/<p class="description card-text">(.*?)<\/p>/');

    /* Read in the entire row of data into SAS in the column row */
    row = _infile_;

    /* 
    Find rows with necessary values 
    - Manual process to find what rows you need.
    */
    findRowPrice = find(row,'price');
    findRowItem = find(row,'title=');
    findRowDesc = find(row,'class="description');

    if findRowPrice > 1 or
       findRowItem > 1 or 
       findRowDesc > 1;

    /*
    If find the specified row, use regex to get the necessary value 
    */

    /* Extract the price */
    if findRowPrice > 1 then do;
        start = prxmatch(re_price, row);
        Price = prxposn(re_price, 0, row);
    end;

    /* Extract item name */
    else if findRowItem > 1 then do;
        start = prxmatch(re_item, row);
        Item = tranwrd(prxposn(re_item, 0, row),'title="','');
    end;

    /* Extract description and entire row. Assumption is when this is found, all values have been identified. Output this row */
    else if findRowDesc > 1 then do;
        start = prxmatch(re_desc, row);
        Description = prxposn(re_desc, 0, row);
        output;  /* Once the DESCRIPTION is found, output the entire row since all values were found */
    end;

    /* Drop columns */
    drop re: find: row start;
run;

/* Preview data */
%viewData(work.raw_scrape)

/* View table metadata */
ods select Variables;
proc contents data=work.raw_scrape;
run;



/********************************************************************
## General Notes:
- Sometimes, JSON/XML RestAPI responses translate easily into a single structured table. Other times, it's a bit more complicated and requires joining data, as demonstrated in the World Bank Example. RestAPI responses are based on the design and requirements of their creators, typically optimized for their specific needs. This means that additional engineering may be necessary for our purposes.
- Web scraping should be a last resort. The parsing of raw HTML is a fragile process. If a website changes its layout, it could break your entire pipeline. Always explore raw data sources or APIs to access data directly.
- If possible, test your API responses in another tool like Postman. This will help identify any issues with the response and differentiate between potential problems in your SAS code or issues with the API.
********************************************************************/


/********************************************************************
## Any Questions?
Feel free to connect with me on LinkedIn!
********************************************************************/