--The goal of this project is to analyze data from a sales records database for scale model cars and extract information for decision-making.
--This is a personal project
 
-- Step 1 is to gain an understanding of the Database and its tables. 
-- The Database Structure tab shows we have 8 tables. Below are QUERYs that share the meta data of each table.
--Comments underneath Query are for quick reference of attribute names.  


PRAGMA table_info(customers); 
-- customerNumber
-- customerName
-- contactLastName
-- contactFirstName
-- phone
-- addressLine1
-- addressLine2
-- city
-- state
-- postalCode
-- country
-- salesRepEmployeeNumber
-- creditLimit


PRAGMA table_info(employees);
-- employeeNumber
-- lastName
-- firstName
-- extension
-- email
-- officeCode
-- reportsTo
-- jobTitle
PRAGMA table_info(offices) ;
-- officeCode
-- city
-- phone
-- addressLine1
-- addressLine2
-- state
-- country
-- postalCode
-- territory

PRAGMA table_info(orderdetails);
-- orderNumber
-- productCode
-- quantityOrdered
-- priceEach
-- orderLineNumber
PRAGMA table_info(orders) ;
-- orderNumber
-- orderDate
-- requiredDate
-- shippedDate
-- status
-- comments
-- customerNumber
PRAGMA table_info(payments);
-- customerNumber
-- checkNumber
-- paymentDate
-- amount
PRAGMA table_info(productlines) ;
-- productLine
-- textDescription
-- htmlDescription
-- image
PRAGMA table_info(products);
-- productCode
-- productName
-- productLine
-- productScale
-- productVendor
-- productDescription
-- quantityInStock
-- buyPrice
-- MSRP


--An aggregrate view of what we have in each table.  
-- To my understanding in SQL Lite we can't use recusrive queries to target table names unless I made a new table so I opt for a UNION all method. 

-- Table will show Table Name, Number of Atrrinutes , Number of Rows
SELECT  'customers' as table_name,(SELECT COUNT(*) FROM pragma_table_info('customers')) AS number_of_attributes, count(*) as number_of_rows
FROM customers

UNION ALL
SELECT  'products' as table_name,(SELECT COUNT(*) FROM pragma_table_info('products')) AS number_of_attributes, count(*) as number_of_rows
FROM products

UNION ALL
SELECT  'ProductLines' as table_name,(SELECT COUNT(*) FROM pragma_table_info('ProductLines')) AS number_of_attributes, count(*) as number_of_rows
FROM ProductLines

UNION ALL
SELECT  'Orders' as table_name,(SELECT COUNT(*) FROM pragma_table_info('Orders')) AS number_of_attributes, count(*) as number_of_rows
FROM Orders

UNION ALL
SELECT  'OrderDetails' as table_name,(SELECT COUNT(*) FROM pragma_table_info('OrderDetails')) AS number_of_attributes, count(*) as number_of_rows
FROM OrderDetails

UNION ALL
SELECT  'Payments' as table_name,(SELECT COUNT(*) FROM pragma_table_info('Payments')) AS number_of_attributes, count(*) as number_of_rows
FROM Payments

UNION ALL
SELECT  'Employees' as table_name,(SELECT COUNT(*) FROM pragma_table_info('Employees')) AS number_of_attributes, count(*) as number_of_rows
FROM Employees

UNION ALL
SELECT  'Offices' as table_name,(SELECT COUNT(*) FROM pragma_table_info('Offices')) AS number_of_attributes, count(*) as number_of_rows
FROM Offices

--In this QUERY we describe the tables in the database and how they link to each other. Below the results are copy and pasted
--One way to do this is to use MYSQL WorkBench to reverse engineer the databse and read the ERD Diagram but I will perform this with Query.    

SELECT name, sql FROM sqlite_master WHERE type = 'table';


-- customers
--   PRIMARY KEY (customerNumber),
--   FOREIGN KEY (salesRepEmployeeNumber) REFERENCES employees (employeeNumber)

-- employees
--  PRIMARY KEY (employeeNumber),
--   FOREIGN KEY (reportsTo) REFERENCES employees (employeeNumber),
--   FOREIGN KEY (officeCode) REFERENCES offices (officeCode)

-- offices
--   PRIMARY KEY (officeCode)

-- orderdetails
-- PRIMARY KEY (orderNumber,productCode),
--   FOREIGN KEY (orderNumber) REFERENCES orders (orderNumber),
--   FOREIGN KEY (productCode) REFERENCES products (productCode)

-- orders
--  PRIMARY KEY (orderNumber),
--   FOREIGN KEY (customerNumber) REFERENCES customers (customerNumber)

-- payments
-- PRIMARY KEY (customerNumber,checkNumber),
--   FOREIGN KEY (customerNumber) REFERENCES customers (customerNumber)

-- productlines
--  PRIMARY KEY (productLine)

-- products
-- PRIMARY KEY (productCode),
--   FOREIGN KEY (productLine) REFERENCES productlines (productLine)




--Step 2 will be to explore products in the sales DATABASE to gain insights  
-- This Query will answer what we are low on stock on by looking at the quantityOrdered compared to the quantityInStock across using a coreelated Subquery

SELECT productCode, 
       ROUND(SUM(quantityOrdered) * 1.0 / (SELECT quantityInStock
                                             FROM products p
                                            WHERE od.productCode = p.productCode), 2) AS low_stock
  FROM orderdetails od
 GROUP BY productCode
 ORDER BY low_stock DESC
 LIMIT 10;
 
 
--This Query will compute the product perfornace for keep product but only show the top 10. 

SELECT productCode, 
       SUM(quantityOrdered * priceEach) AS prod_perf
  FROM orderdetails od
 GROUP BY productCode 
 ORDER BY prod_perf DESC
 LIMIT 10;

-- This Query will combine the previous two queries into a Common Table Expression (CTE)

WITH 

low_stock_table AS (
SELECT productCode, 
       ROUND(SUM(quantityOrdered) * 1.0/(SELECT quantityInStock
                                           FROM products p
                                          WHERE od.productCode = p.productCode), 2) AS low_stock
  FROM orderdetails od
 GROUP BY productCode
 ORDER BY low_stock DESC
 LIMIT 10
)

SELECT productCode, 
       SUM(quantityOrdered * priceEach) AS prod_perf
  FROM orderdetails od
 WHERE productCode IN (SELECT productCode
                         FROM low_stock_table)
 GROUP BY productCode 
 ORDER BY prod_perf DESC
 LIMIT 10;

 
--Step 3 will be to explore cutomser information in hopes of better undserstanding ways to increase sales. 
--Below I made a CTE called Customer_by_Profit and used that to query the top 5 customers for the company.  


WITH 
Customer_by_profit AS(
SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice))  as Profit
FROM products as p
JOIN orderdetails as od
  on p.productCode=od.productCode
JOIN orders as o
  on od.orderNumber=o.orderNumber
  GROUP by o.customerNumber
)

-- Finding information on top 5 VIP customers in the database. 

SELECT c.contactLastName,c.contactFirstName,c.city,c.country,cp.profit
FROM customers as c
JOIN Customer_by_profit as cp
ON cp.customerNumber=c.customerNumber
ORDER by cp.profit DESC
LIMIT 5;
  
-- Using the same CTE we also look at a table of the 5 least engaged customers 
SELECT c.contactLastName,c.contactFirstName,c.city,c.country,cp.profit
FROM customers as c
JOIN Customer_by_profit as cp
ON cp.customerNumber=c.customerNumber
ORDER by cp.profit 
LIMIT 5;
 
--Next we will look at how many new customers are arriving each month to determine to if its worth spending money to procure more customers
-- The Query below is built from multiple CTEs and it shows the number of new customers each month and it is decreaseing. 

WITH 

payment_with_year_month_table AS (
SELECT *, 
       CAST(SUBSTR(paymentDate, 1,4) AS INTEGER)*100 + CAST(SUBSTR(paymentDate, 6,7) AS INTEGER) AS year_month
  FROM payments p
),

customers_by_month_table AS (
SELECT p1.year_month, COUNT(*) AS number_of_customers, SUM(p1.amount) AS total
  FROM payment_with_year_month_table p1
 GROUP BY p1.year_month
),

new_customers_by_month_table AS (
SELECT p1.year_month, 
       COUNT(*) AS number_of_new_customers,
       SUM(p1.amount) AS new_customer_total,
       (SELECT number_of_customers
          FROM customers_by_month_table c
        WHERE c.year_month = p1.year_month) AS number_of_customers,
       (SELECT total
          FROM customers_by_month_table c
         WHERE c.year_month = p1.year_month) AS total
  FROM payment_with_year_month_table p1
 WHERE p1.customerNumber NOT IN (SELECT customerNumber
                                   FROM payment_with_year_month_table p2
                                  WHERE p2.year_month < p1.year_month)
 GROUP BY p1.year_month
)

SELECT year_month, 
       ROUND(number_of_new_customers*100/number_of_customers,1) AS number_of_new_customers_props,
       ROUND(new_customer_total*100/total,1) AS new_customers_total_props
  FROM new_customers_by_month_table; 
 
 

--In the final step we will determine how much the average life time value of a customer (LTV) is which can help us set a marketing budget 

WITH 
Customer_by_profit AS(
SELECT o.customerNumber, SUM(quantityOrdered * (priceEach - buyPrice))  as Profit
FROM products as p
JOIN orderdetails as od
  on p.productCode=od.productCode
JOIN orders as o
  on od.orderNumber=o.orderNumber
  GROUP by o.customerNumber
)

SELECT AVG(Profit) as LTV
FROM Customer_by_profit;
 