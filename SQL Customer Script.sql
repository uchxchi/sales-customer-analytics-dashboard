/*=========================================================
   1. Preview Data
=========================================================*/
SELECT TOP (1000) 
      [InvoiceDate],
      [InvoiceNo],
      [StockCode],
      [Description],
      [Quantity],
      [UnitPrice],
      [CustomerID],
      [Age],
      [Gender],
      [Income],
      [Country],
      [TransactionType]
FROM [Customer].[dbo].[customertable];


/*=========================================================
   2. Data Quality Checks
=========================================================*/

/* 2.1 Check for NULLs */
SELECT
	SUM(CASE WHEN InvoiceDate IS NULL THEN 1 ELSE 0 END) AS invoicedate_nulls,
	SUM(CASE WHEN InvoiceNo IS NULL THEN 1 ELSE 0 END) AS invoiceNo_nulls,
	SUM(CASE WHEN StockCode IS NULL THEN 1 ELSE 0 END) AS stockcode_nulls,
	SUM(CASE WHEN Description IS NULL THEN 1 ELSE 0 END) AS description_nulls,
	SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS quantity_nulls,
	SUM(CASE WHEN UnitPrice IS NULL THEN 1 ELSE 0 END) AS unitprice_nulls,
	SUM(CASE WHEN CustomerID IS NULL THEN 1 ELSE 0 END) AS customerId_nulls,
	SUM(CASE WHEN Age IS NULL THEN 1 ELSE 0 END) AS age_nulls,
	SUM(CASE WHEN Gender IS NULL THEN 1 ELSE 0 END) AS gender_nulls,
	SUM(CASE WHEN Income IS NULL THEN 1 ELSE 0 END) AS income_nulls,
	SUM(CASE WHEN Country IS NULL THEN 1 ELSE 0 END) AS country_nulls
FROM dbo.customertable;


/* 2.2 Check for zeros, negatives, impossible values */
SELECT
	SUM(CASE WHEN Quantity = 0 THEN 1 ELSE 0 END) AS quantity_zeros,
	SUM(CASE WHEN Quantity < 0 THEN 1 ELSE 0 END) AS quantity_negatives,
	SUM(CASE WHEN UnitPrice = 0 THEN 1 ELSE 0 END) AS unitprice_zeros,
	SUM(CASE WHEN UnitPrice < 0 THEN 1 ELSE 0 END) AS unitprice_negatives,
	SUM(CASE WHEN Age < 0 OR Age > 120 THEN 1 ELSE 0 END) AS age_impossible_num
FROM dbo.customertable;


/* 2.3 Inspect zeros and negatives */
SELECT TOP (50) * 
FROM dbo.customertable 
WHERE Quantity < 0 OR UnitPrice <= 0
ORDER BY InvoiceDate DESC;


/* 2.4 Handle Transaction Types (Refund / Adjustment / Sale) And Discount */
ALTER TABLE dbo.customertable
ADD TransactionType VARCHAR(10);

ALTER TABLE dbo.customertable
ALTER COLUMN TransactionType VARCHAR(20);

UPDATE dbo.customertable
SET TransactionType = CASE 
	WHEN StockCode IN ('D') THEN 'Discount'
    WHEN Quantity < 0 AND StockCode NOT IN ('POST', 'AMAZONFEE', 'B', 'M', 'DOT', 'CRUK', 'D', 'BANK CHARGES') THEN 'Refund' 
    WHEN StockCode IN ('POST', 'AMAZONFEE', 'B', 'M', 'DOT', 'BANK CHARGES', 'CRUK') THEN 'Adjustment/fee'
    ELSE 'Sale'
END;


/*=========================================================
   3. General Dataset Info
=========================================================*/

/* 3.1 Data Timespan */
SELECT MIN(invoicedate) AS min_date, MAX(invoicedate) AS max_date 
FROM dbo.customertable;

/* 3.2 Total number of customers */
SELECT COUNT(DISTINCT CustomerID) AS total_customers
FROM dbo.customertable;

/* 3.3 Age summary */
SELECT MIN(Age) AS min_age, MAX(Age) AS max_age, AVG(Age) AS avg_age
FROM dbo.customertable;

/* 3.4 UnitPrice summary */
SELECT MIN(UnitPrice) AS min_unitprice, MAX(UnitPrice) AS max_unitprice, ROUND(AVG(UnitPrice), 1) AS avg_unitprice
FROM dbo.customertable
WHERE UnitPrice > 0.3;


/*=========================================================
   4. Outlier Detection
=========================================================*/

/* 4.1 UnitPrice stats & IQR method */
WITH stats AS (
  SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY UnitPrice) OVER () AS Q1,
    PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY UnitPrice) OVER () AS Median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY UnitPrice) OVER () AS Q3
  FROM dbo.customertable
)
SELECT TOP (1)
  Q1, Median, Q3,
  Q3 - Q1 AS IQR,
  Q3 + 1.5 * (Q3 - Q1) AS UpperBound,
  Q1 - 1.5 * (Q3 - Q1) AS LowerBound
FROM stats;

/* 4.2 Count extreme UnitPrice outliers */
SELECT COUNT(*) AS outlier_count
FROM dbo.customertable
WHERE UnitPrice > 8.45;


/*=========================================================
   5. Demographics
=========================================================*/

/* 5.1 Countries */
SELECT COUNT(DISTINCT Country) AS num_countries FROM dbo.customertable;

/* 5.2 Gender */
SELECT Gender, COUNT(*) AS total_per_gender FROM dbo.customertable GROUP BY Gender;

/* 5.3 Income distribution & median */
SELECT ROUND(MIN(Income), 0) AS min_income, ROUND(MAX(Income), 0) AS max_income, ROUND(AVG(Income), 0) AS avg_income
FROM dbo.customertable;

SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY income) OVER() AS median_income
FROM CustomerTable;


/*=========================================================
   6. Placeholder Handling
=========================================================*/

/* 6.1 Flag placeholders (Age=25 or CustomerID=NULL) */
ALTER TABLE dbo.customertable
ADD IsPlaceholder BIT;

UPDATE dbo.customertable
SET IsPlaceholder = CASE 
    WHEN CustomerID IS NULL OR Age = 25 THEN 1
    ELSE 0
END;


/*=========================================================
   7. Age & Income Brackets
=========================================================*/

/* 7.1 Add bracket columns */
ALTER TABLE dbo.customertable
ADD AgeBracket VARCHAR(30),
    IncomeBracket VARCHAR(30);

/* 7.2 Update AgeBracket */
UPDATE dbo.customertable
SET AgeBracket = CASE 
		WHEN Age < 20 THEN 'Teenagers' 
		WHEN Age BETWEEN 20 AND 24 THEN 'Early 20s'
		WHEN Age = 25 THEN 'Placeholder'
		WHEN Age BETWEEN 26 AND 29 THEN 'Mid/late 20s'
		WHEN Age BETWEEN 30 AND 34 THEN 'Early 30s'
		WHEN Age BETWEEN 35 AND 39 THEN 'Mid/Late 30s'
		WHEN Age BETWEEN 40 AND 44 THEN 'Early 40s'
		WHEN Age BETWEEN 45 AND 49 THEN 'Mid/late 40s'
		WHEN Age BETWEEN 50 AND 54 THEN 'Early 50s'
		WHEN Age BETWEEN 55 AND 59 THEN 'Mid/Late 50s'
	ELSE 'Seniors'
	END;

/* 7.3 Update IncomeBracket */
UPDATE dbo.customertable
SET IncomeBracket =  CASE
    WHEN Income < 20000 THEN '<20k'
    WHEN Income BETWEEN 20000 AND 30000 THEN '20-30k'
    WHEN Income BETWEEN 30001 AND 40000 THEN '30-40k'
    ELSE '40k+'
END;

/*=========================================================
   8. Grain Assessment and Normalization
=========================================================*/
CREATE TABLE dbo.Customer (
	CustomerID INT PRIMARY KEY,
	Age INT,
	Gender VARCHAR(10),
	Income DECIMAL(12,2),
	Country VARCHAR(50),
	AgeBracket VARCHAR(30),
	IncomeBracket VARCHAR(30)
)
INSERT INTO dbo.Customer (customerID, age, gender, income, country, AgeBracket, IncomeBracket)
SELECT
	CustomerID,
	MAX(Age) AS Age,
	MAX(Gender) AS Gender,
	MAX(Income) AS Income,
	MAX(Country) AS Country,
	MAX(AgeBracket) AS AgeBracket,
	MAX(IncomeBracket) AS IncomeBracket
FROM dbo.customertable
WHERE IsPlaceholder = 0
GROUP BY CustomerID;

CREATE TABLE dbo.Invoice (
	InvoiceNo VARCHAR(20) PRIMARY KEY, 
	InvoiceDate DATE,
	CustomerID INT
)
INSERT INTO dbo.Invoice (InvoiceNo, InvoiceDate, CustomerID)
SELECT DISTINCT
	InvoiceNo,
	CAST(MIN(InvoiceDate) AS DATE) AS InvoiceDate,
	CustomerID
FROM dbo.customertable
WHERE IsPlaceholder = 0 
GROUP BY InvoiceNo, CustomerID

CREATE TABLE dbo.OrderLine (
    InvoiceNo VARCHAR(20) NOT NULL,
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    UnitPrice DECIMAL(10,2),
    Quantity INT,
	PRIMARY KEY (InvoiceNo, StockCode)
)
INSERT INTO dbo.OrderLine (InvoiceNo, StockCode, Description, UnitPrice, Quantity)
SELECT
    InvoiceNo,
    StockCode,
    MAX(Description),
    MAX(UnitPrice),
    SUM(Quantity) AS Quantity
FROM dbo.customertable
WHERE IsPlaceholder = 0
  AND TransactionType IN ('Sale', 'Refund')
  AND UnitPrice > 0
GROUP BY InvoiceNo, StockCode

CREATE TABLE dbo.InvoiceDiscount (
    InvoiceNo VARCHAR(20),
    DiscountAmount DECIMAL(10,2)
);

INSERT INTO dbo.InvoiceDiscount (InvoiceNo, DiscountAmount)
SELECT
    InvoiceNo,
    SUM(DiscountAmount) AS DiscountAmount
FROM dbo.customertable
WHERE IsDiscount = 1
GROUP BY InvoiceNo;

/*=========================================================
   9. Analytics
=========================================================*/

--Total Sales
SELECT
	SUM(UnitPrice * Quantity) AS TotalSales
FROM dbo.OrderLine
--$8,090,970.11

--Total Orders
SELECT
	COUNT(DISTINCT i.InvoiceNo) AS TotalOrders
FROM dbo.Invoice i
WHERE EXISTS (
	SELECT 1
	FROM dbo.OrderLine o
	WHERE o.InvoiceNo = i.InvoiceNo AND Quantity > 0      
)
--17,893, Quantity < 0 are refunds and so are excluded from total orders 


--Customer Count
SELECT 
	COUNT(DISTINCT CustomerID)
FROM Customer
--4,236

--How many customers are in each AgeBracket and IncomeBracket?
SELECT
	AgeBracket,
	COUNT(DISTINCT CustomerID) AS TotalCustomers,
	ROUND(
	CAST(100.0 * COUNT(DISTINCT CustomerID) AS FLOAT) / 
	SUM(COUNT(DISTINCT CustomerID)) OVER(), 0) AS PercentageTotal
FROM Customer
GROUP BY AgeBracket
ORDER BY TotalCustomers DESC
/*Customers in their early 30s form the largest age segment, accounting for approximately 17% of the total customer base.
This suggests a strong concentration of customers in early working-age demographics, which may influence product positioning and marketing tone.*/

SELECT
	IncomeBracket,
	COUNT(DISTINCT CustomerID) AS TotalCustomers,
	ROUND(
	CAST(100.0 * COUNT(DISTINCT CustomerID) AS fLOAT) /
	SUM(COUNT(DISTINCT CustomerID)) OVER(), 0) AS PercentageTotal
FROM dbo.Customer
GROUP BY IncomeBracket
ORDER BY TotalCustomers DESC
/*The $30k–$40k income bracket represents the majority of customers at roughly 59%, indicating a predominantly mid-income customer base.
Pricing, promotions, and value-based messaging should be optimized for price-sensitive but stable earners.*/

--Top Customers By Revenue
SELECT TOP 10
	i.CustomerID,
	SUM(o.Quantity * o.UnitPrice) AS TotalRevenue,
	ROUND(
	CAST(SUM(o.Quantity * o.UnitPrice) AS FLOAT) / 
	SUM(SUM(o.Quantity * o.UnitPrice)) OVER() * 100, 2) AS PercentageOfTotalRevenue
FROM dbo.Invoice i
JOIN dbo.OrderLine o
ON i.InvoiceNo = o.InvoiceNo
GROUP BY i.CustomerID
ORDER BY TotalRevenue DESC
/*The top 10 customers contribute roughly 20% of total revenue, with the highest individual customer accounting for about 3.5%. 
This indicates moderate revenue concentration, suggesting that retaining top customers is important, but overall revenue risk is diversified
across the customer base.*/

--Customer Segmentation Trends: Which AgeBracket + IncomeBracket groups buy the most?
SELECT
	c.AgeBracket,
	c.IncomeBracket,
	COUNT(DISTINCT c.CustomerID) AS CustomersInSegment,
	SUM(o.Quantity * o.UnitPrice) AS TotalRevenue,
	ROUND(
	CAST(SUM(o.Quantity * o.UnitPrice) AS FLOAT) /
	SUM(SUM(o.Quantity * o.UnitPrice)) OVER() * 100.0, 2) AS PercentageTotal
FROM dbo.Customer c
JOIN dbo.Invoice i
ON c.CustomerID = i.CustomerID
JOIN dbo.OrderLine o
ON o.InvoiceNo = i.InvoiceNo
GROUP BY c.AgeBracket, c.IncomeBracket
ORDER BY TotalRevenue DESC
-/*Customers in the early 40s age bracket with incomes between $30k–$40k generate the highest revenue,
contributing approximately 18% of total sales.*/

--Repeat Customers: Which customers have made more than 1 invoice? How much do they contribute to total revenue?
SELECT
	CustomerID,
	COUNT(DISTINCT i.InvoiceNo) AS InvoiceCount,
	SUM(o.Quantity * o.UnitPrice) AS TotalRevenue,
	ROUND(
	CAST(SUM(o.Quantity * o.UnitPrice) AS FLOAT) /
	SUM(SUM(o.Quantity * o.UnitPrice)) OVER() * 100.0, 2) AS PercentageTotal
FROM dbo.Invoice i
JOIN dbo.OrderLine o
ON i.InvoiceNo = o.InvoiceNo
GROUP BY CustomerID
HAVING COUNT(DISTINCT i.InvoiceNo) > 1
ORDER BY TotalRevenue DESC;
/*The top repeat customers contribute a disproportionate share of total revenue.
Customer 14646, with 74 invoices, accounts for 3.64% of total revenue, while high-frequency customers like 14911 have many orders but 
lower revenue, highlighting differences in order size. Retaining top repeat customers is critical for revenue stability.*/

--Monthly revenue trends: What is the total sales per month and month-over-month % change?
WITH MonthlySalesCte AS (
    SELECT
        DATETRUNC(MONTH, i.InvoiceDate) AS InvoiceMonth,
        SUM(o.Quantity * o.UnitPrice) AS MonthlySalesTotal
    FROM dbo.Invoice i
    JOIN dbo.OrderLine o
        ON i.InvoiceNo = o.InvoiceNo
    GROUP BY DATETRUNC(MONTH, i.InvoiceDate)
)
SELECT
    InvoiceMonth,
    MonthlySalesTotal,
    CONCAT(
        ROUND(
            CAST(MonthlySalesTotal - LAG(MonthlySalesTotal) OVER(ORDER BY InvoiceMonth) AS FLOAT)
            / NULLIF(LAG(MonthlySalesTotal) OVER(ORDER BY InvoiceMonth), 0) * 100
        , 2), '%'
    ) AS MoMpercentChange
FROM MonthlySalesCte
ORDER BY InvoiceMonth
/*Monthly revenue is volatile, with notable peaks in March, May, September, and November 2011, and sharp declines in April and December 2011.
The largest drop (-69.96%) occurs in December 2011, which may indicate seasonal trends or an outlier. MoM percent change helps identify months
with unusually high or low performance, useful for forecasting and planning promotions.*/

--Product insights: What are the top 10 products by revenue?
SELECT TOP 10
	StockCode,
	SUM(Quantity * UnitPrice) AS TotalRevenu,
	 SUM(Quantity * UnitPrice) AS TotalRevenue,
    ROUND(
        CAST(SUM(Quantity * UnitPrice) AS FLOAT)
        / SUM(SUM(Quantity * UnitPrice)) OVER() * 100
    , 2) AS PercentageOfTotalRevenue
FROM dbo.OrderLine
GROUP BY StockCode
ORDER BY TotalRevenue DESC
/*The top 10 products generate approximately 8–9% of total revenue, with the leading product contributing 1.6%. 
Revenue is fairly diversified across these products, suggesting the business does not rely heavily on a single SKU for revenue. 
This insight can inform inventory planning, promotion strategies, and product prioritization.*/

--Cohort analysis: Track first purchase month per customer and see total revenue by cohort
WITH CustomerCohortCTE AS (
SELECT
	CustomerID, 
	MIN(DATETRUNC(MONTH, InvoiceDate)) AS FirstPurchaseMonth
FROM dbo.Invoice 
GROUP BY CustomerID
),
CohortRevenue AS(
SELECT 
	cc.FirstPurchaseMonth,
	SUM(O.Quantity * O.UnitPrice) AS TotalRevenue
FROM CustomerCohortCTE cc
JOIN dbo.Invoice i
ON cc.CustomerID = i.CustomerID
JOIN dbo.OrderLine o
ON i.InvoiceNo = o.InvoiceNo
GROUP BY cc.FirstPurchaseMonth
)
SELECT
	FirstPurchaseMonth,
	TotalRevenue
FROM CohortRevenue
ORDER BY FirstPurchaseMonth
/*Cohort analysis shows that customers who made their first purchase in December 2010 contributed the largest total revenue (~4.3M), 
followed by January 2011 (~966k). Subsequent cohorts generated progressively lower revenue, suggesting that early acquisition months brought 
in high-value customers, while later months had smaller or lower-spending customer groups. 
This insight can guide marketing spend and acquisitionstrategies.*/