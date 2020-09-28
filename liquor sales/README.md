# Iowa Liquor Sales Exploratory Analysis

**This project was done the week of 9/14** with the [Iowa Liquor Sales](https://www.kaggle.com/residentmario/iowa-liquor-sales) Kaggle data set. The data consists of several years of line-item invoices from Iowan liquor stores, with each item including attributes about the alcohol sold, and the store it was sold at. 

Purpose: get familiar with the Julia data environment (CSV, DataFrames, Query, etc.).

Problem statement: Which stores should be targeted for Gin distribution?

I answered this question by finding the stores that sold the most bottles of gin.

![Highest Gin Sales](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/Gin_Sales.png)

## More analysis

**week of 9/21**

Investigation of store sales by price:

![Sales by Price](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/sales_by_price_store.png)

## Clustering!

Problem statement: predict which stores would

I [implemented the k-modes algorithm](https://github.com/snisher/projects/tree/master/kmodes) in Julia, and used it to cluster line item invoices (using the same Kaggle Iowa liquor sales dataset). Then I looked at whether the clusters were useful for predicting which items would be sold at specific stores:

![Sales by Cluster](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/cluster_sales_by_store.png)

Store *#4594* sold almost entirely (~80%) products falling in cluster 1. Over 50% of sales from stores *#2248*, *#5127*, and *#4804*, were from cluster 4. These clusters are clearly useful in predicting which stores will sell a product.

\*Note that the clusters were not based on the store.
