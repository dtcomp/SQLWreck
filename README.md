** Caution
	This is NOT recommended in general, it is simply
	a "hard" task which only needs to run once, in our case.
	And, there are other ways it could be done at a slightly
	higher level of abstraction (PHP, etc.). Instead we chose
	to skip the webserver, PHP etc. and code it all in SQL, partly
	just for the experience...
	
** Purpose

1) Merge legacy customer info database (VikBooking) with existing Square customers
   into a form that can be uploaded back to Square customer database.
   
2) Generate reports with merged data (like - top-spending customers, etc.)


** Strategy

1) Prepare Square customer data (in Square Customer UI)
	* Merge identifiable duplicate customers
	* Cleanup obvious data entry errors
	* Export all customers to CSV
	* Import CSV to SQL database for next steps

2) Identify unique customers in VikBooking

	* Run created SQL routines to match existing Vikbooking
	  *orders* to VikBooking *customers*,
          via one or more of: email, phone name(s)
          Then creating a new customer record in
          VB `customers` table and create an entry in
          the join table `customers_orders`, linking
          existing orders to newly-created customer.

	* This is complicated by VikBooking not creating/storing
	  customer data in it's customer table, so we
	  must parse through 'custdata' text fields, *per order*,
	  some of which are "free-form" entries and some are
          formatted by the VB system.
	  Note: VikBooking *now* creates entries in `customers`
                table for new orders (due to corrections by dTC,
                since Square integration - about May, 2017).
	
3) Merge/Create/Update Customer Data with Square DB
 
	* Via created SQL procedures, calculate aggregate sales 
	  totals for each unique Vikbooking customer.
	* For each VikBooking customer:
	    * See if a match exists in Square DB and,
	    If a match is found, update Square customer
	    record with VikBooking customer totals.
	    * If no match is found, create a new customer
	    in Square DB with aggreagate totals for
	    customer.
	* NOTE: This step only has to be performed once,
	  to bring in historical data from VikBooking.
	  Since we added Square integration to website,
	  customer data is automatically persisted in Square.

4) Run Reports
	* SQL procedures...
	* With updated records containing sales totals
	* With desired parameters
	  (Top N, most frequent, bracketed sales, etc.)
        * Export report data to CSV
        * Convert CSV to .xlsx ( Excel Format )


4) Update live Square data
	* Now that we possibly have many additional
	  customers and sales identified from old VikBooking
	  data and that data is merged with Square customer
	  data, we can import our updated records directly to Square.
 
