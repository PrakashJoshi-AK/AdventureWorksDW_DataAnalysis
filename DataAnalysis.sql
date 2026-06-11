-- AdventureWorksDW2025
USE AdventureWorksDW2025;

-- -----------------------------------------------------------------
-- *Q1. Revenue trend from Internet Sales over past financial years*
-- -----------------------------------------------------------------
WITH ct1 AS
(
	SELECT d.CalendarYear, 
		ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
	WHERE
		s.OrderDate > '2010-12-31' AND
		s.OrderDate < '2014-01-01'
	GROUP BY d.CalendarYear
)
SELECT curr.CalendarYear AS [Year], curr.Revenue
, (curr.Revenue - prv.Revenue) AS RevenueGrowth
, ROUND(100 * (curr.Revenue - prv.Revenue)/prv.Revenue, 2) AS GrowthPct
FROM ct1 AS curr
	LEFT JOIN ct1 AS prv
		ON curr.CalendarYear = prv.CalendarYear + 1
ORDER BY [Year];



-- ---------------------------------------------------------------------------------------------
-- *Q2. What is the count of products launched during each year in all the product categories?*
-- ---------------------------------------------------------------------------------------------
SELECT
	YEAR(p.StartDate) AS LaunchYear,
	c.EnglishProductCategoryName AS Category,
	COUNT(p.ProductKey) AS CountOfProducts
FROM 
	dbo.DimProduct AS p
	JOIN dbo.DimProductSubcategory AS sc
		ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
	JOIN dbo.DimProductCategory AS c
		ON sc.ProductCategoryKey = c.ProductCategoryKey
GROUP BY
	YEAR(p.StartDate),
	c.EnglishProductCategoryName
ORDER BY
	LaunchYear, Category;


-- -----------------------------------------------------------------
-- *Internet Sales Revenue by Product Category*
-- -----------------------------------------------------------------
SELECT d.CalendarYear, c.EnglishProductCategoryName AS ProductCategory, ROUND(SUM(s.SalesAmount),0) AS Revenue
FROM dbo.FactInternetSales AS s
	JOIN dbo.DimProduct AS p
		ON s.ProductKey = p.ProductKey
	JOIN dbo.DimProductSubcategory AS sc
		ON p.ProductSubcategoryKey = sc.ProductCategoryKey
	JOIN dbo.DimProductCategory AS c
		ON sc.ProductCategoryKey = c.ProductCategoryKey
	JOIN dbo.DimDate AS d
		ON s.OrderDateKey = d.DateKey
GROUP BY d.CalendarYear, c.EnglishProductCategoryName
ORDER BY CalendarYear, Revenue DESC, ProductCategory;



-- -----------------------------------------------------------------
-- *Products whose prices were changed during past years*
-- -----------------------------------------------------------------
WITH ct1 AS
(
	SELECT p.ProductKey, p.EnglishProductName AS ProductName, s.UnitPrice, MIN(s.OrderDate) AS FirstOrderDate
	FROM
		dbo.FactInternetSales AS s
		JOIN dbo.DimProduct AS p
			ON s.ProductKey = p.ProductKey
	GROUP BY
		p.ProductKey,
		p.EnglishProductName,
		s.UnitPrice
)
, ct2 AS
(
	SELECT ProductKey
	FROM ct1
	GROUP BY ProductKey, UnitPrice
	HAVING COUNT(ProductKey) > 1
)
SELECT ProductKey, ProductName, UnitPrice, FirstOrderDate
FROM ct1
WHERE ProductKey IN(SELECT ProductKey FROM ct2);




-- Q4. What percentage of products quantity sold on discount in each category in each fiscal year?
SELECT COUNT(*) AS NumDiscounts 
FROM dbo.FactInternetSales AS s
WHERE DiscountAmount > 0;

SELECT
	d.FiscalYear,
	c.EnglishProductCategoryName AS Category,
	SUM(
		CASE s.UnitPriceDiscountPct
			WHEN 0 THEN s.OrderQuantity
			ELSE 0
		END
	) AS QuantityWithoutDiscount,
	SUM(
		CASE s.UnitPriceDiscountPct
			WHEN 0 THEN 0
			ELSE s.OrderQuantity
		END
	) AS QuantityWithDiscount
FROM
	dbo.FactInternetSales AS s
	JOIN dbo.DimDate AS d
		ON s.OrderDateKey = d.DateKey
	JOIN dbo.DimProduct AS p
		ON s.ProductKey = p.ProductKey
	JOIN dbo.DimProductSubcategory AS sc
		ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
	JOIN dbo.DimProductCategory AS c
		ON sc.ProductCategoryKey = c.ProductCategoryKey
GROUP BY
	d.FiscalYear,
	c.EnglishProductCategoryName;



-- Q5. Are there any seasonal trends in sales?
SELECT
	d.CalendarYear AS [Year],
	d.MonthNumberOfYear AS MonthNumber,
	SUBSTRING(d.EnglishMonthName,1, 3) AS [Month],
	ROUND(SUM(s.SalesAmount),0) AS Revenue
FROM dbo.FactInternetSales AS s
	JOIN dbo.DimDate AS d
		ON s.OrderDateKey = d.DateKey
WHERE
	s.OrderDate > '2010-12-31' AND
	s.OrderDate < '2014-01-01'
GROUP BY
	d.CalendarYear,
	d.MonthNumberOfYear,
	d.EnglishMonthName
ORDER BY
	[Year],
	MonthNumber;



-- Q6. What were the month over month growth rate in the year 2013?
WITH ct1 AS
(
	SELECT
		d.MonthNumberOfYear AS MonthNumber,
		SUBSTRING(d.EnglishMonthName, 1, 3) AS [Month],
		ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM 
		dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
	WHERE
		s.OrderDate > '2012-12-31' AND
		s.OrderDate < '2014-01-01'
	GROUP BY
		d.MonthNumberOfYear,
		d.EnglishMonthName
)
SELECT 
	curr.MonthNumber, 
	curr.[Month], 
	curr.Revenue AS Revenue,
	curr.Revenue - prv.Revenue AS Growth,
	ROUND(100 * (curr.Revenue - prv.Revenue)/prv.Revenue, 2) AS GrowthPct
FROM
	ct1 AS curr
	LEFT JOIN ct1 AS prv
	ON curr.MonthNumber = prv.MonthNumber + 1
ORDER BY
	curr.MonthNumber;



WITH ct1 AS
(
	SELECT
		d.MonthNumberOfYear AS MonthNumber,
		SUBSTRING(d.EnglishMonthName, 1, 3) AS [Month],
		ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM 
		dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
	WHERE
		s.OrderDate > '2012-12-31' AND
		s.OrderDate < '2014-01-01'
	GROUP BY
		d.MonthNumberOfYear,
		d.EnglishMonthName
)
SELECT
	MonthNumber,
	[Month],
	Revenue,
	Revenue - (LAG(Revenue, 1, NULL) OVER(ORDER BY MonthNumber)) AS Growth,
	ROUND(100 * (Revenue - (LAG(Revenue, 1, NULL) OVER(ORDER BY MonthNumber)))/(LAG(Revenue, 1, NULL) OVER(ORDER BY MonthNumber)),2) AS GrowthPct
FROM ct1
ORDER BY MonthNumber;


-- Q7. What is the contribution of different product categories in the total revenue?
WITH ct1 AS
(
	SELECT
		c.EnglishProductCategoryName AS ProductCategory,
		ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM
		dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
		JOIN dbo.DimProduct AS p
			ON s.ProductKey = p.ProductKey
		JOIN dbo.DimProductSubcategory AS sc
			ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
		JOIN dbo.DimProductCategory AS c
			ON sc.ProductCategoryKey = c.ProductCategoryKey
	WHERE
		s.OrderDate > '20101231' AND
		s.OrderDate < '20140101'
	GROUP BY
		c.EnglishProductCategoryName
)
SELECT
	ProductCategory
	, Revenue
	, SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumRevenue
	, ROUND(100 * SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)/(SUM(Revenue) OVER()),2) AS CumContriPct
FROM ct1
ORDER BY Revenue DESC;


-- Q8. Explore contributions by subcategories of Bikes
WITH ct1 AS
(
	SELECT
		sc.EnglishProductSubcategoryName AS ProductSubCategory,
		ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM
		dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
		JOIN dbo.DimProduct AS p
			ON s.ProductKey = p.ProductKey
		JOIN dbo.DimProductSubcategory AS sc
			ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
		JOIN dbo.DimProductCategory AS c
			ON sc.ProductCategoryKey = c.ProductCategoryKey
	WHERE
		s.OrderDate > '20101231' AND
		s.OrderDate < '20140101' AND
		c.EnglishProductCategoryName = 'Bikes'
	GROUP BY
		sc.EnglishProductSubcategoryName
)
SELECT 
	ProductSubCategory
	, Revenue
	, ROUND(100 * Revenue/SUM(Revenue) OVER(), 2) AS Pct
	, SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumRevenue
	, ROUND(100 * SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)/SUM(Revenue) OVER(), 2) AS CumPct
FROM ct1
ORDER BY Revenue DESC;



-- Q9. Find revenue contribution by bike models with in each subcategory
with ct1 AS
(
	SELECT
		sc.EnglishProductSubcategoryName AS ProductSubCategory
		, p.ModelName
		, ROUND(SUM(s.SalesAmount),0) AS Revenue
	FROM
		dbo.FactInternetSales AS s
		JOIN dbo.DimDate AS d
			ON s.OrderDateKey = d.DateKey
		JOIN dbo.DimProduct AS p
			ON s.ProductKey = p.ProductKey
		JOIN dbo.DimProductSubcategory AS sc
			ON p.ProductSubcategoryKey = sc.ProductSubcategoryKey
		JOIN dbo.DimProductCategory AS c
			ON sc.ProductCategoryKey = c.ProductCategoryKey
	WHERE
		s.OrderDate > '20101231' AND
		s.OrderDate < '20140101' AND
		c.EnglishProductCategoryName = 'Bikes'
	GROUP BY
		sc.EnglishProductSubcategoryName
		, p.ModelName
)
SELECT
	ModelName
	, ProductSubCategory
	, Revenue
	, ROUND(100 * Revenue/SUM(Revenue) OVER(), 2) AS Pct
	, SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS CumRevenue
	, ROUND(100 * SUM(Revenue) OVER(ORDER BY Revenue DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)/ SUM(Revenue) OVER(), 2) AS CumPct
FROM ct1
ORDER BY Revenue DESC;