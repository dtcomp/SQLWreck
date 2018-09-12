Customer merge/report ( to find top-spending customers )

Strategy

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
	  must parse through 'custdata' text fields, per order
	  some of which are "free-form" entries and some are
          formatted by system.
	  Note: VikBooking *now* creates entries in `customers`
                table for new orders.
                (since Square integration - about May, 2017).
	
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
	  Since using Square, (instead of old PayPal setup)
	  customer data is automatically logged in Square
	  Customers data.


4) Run Reports
	* SQL procedures...
	* With updated records containing sales totals
	* With desired parameters
	  (Top 100, most frequent, bracketed sales, etc.)
        * Export report data to CSV
        * Convert CSV to .xlsx ( Excel Format )


4) Update live Square data (Optional)
	* Now that we possibly have many additional
	  customers and sales identified from old VikBooking
	  data and that data is merged with Square customer
	  data, we can import our updated records directly to Square.
 
