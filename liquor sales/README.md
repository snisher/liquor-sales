# Iowa Liquor Sales Analysis

**This project was done the week of 9/14** with the [Iowa Liquor Sales](https://www.kaggle.com/residentmario/iowa-liquor-sales) Kaggle data set. The data consists of several years of line-item invoices from Iowan liquor stores, with each item including attributes about the alcohol sold, and the store it was sold at. 

Purpose: get familiar with the Julia data environment (CSV, DataFrames, Query, etc.).

Problem statement: Which stores should be targeted for Gin distribution?

I answered this question by finding the stores that sold the most bottles of gin. The code can be found in 'sales_analysis_1.jl'.

![Highest Gin Sales](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/Gin_Sales.png)

## More analysis

**week of 9/21**

Investigation of store sales by price:

![Sales by Price](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/sales_by_price_store.png)

## Clustering!

First, some assumptions going into this work: The main purpose was to use a categorical clustering algorithm (K-modes) on the data I had. Something like K-prototypes might be more ideal because I wouldn't lose any information by binning continuous variables into categorical ones, but for the sake of using K-modes, that was my approach.

Problem statement: find clusters of products that are overrepresented in some stores (useful for product distribution).

My solution clusters line-item sales invoices. This is similar to clustering on product IDs, but leaves purchases of the same product in the table. This is useful because in the end we can still see the quantity of each product (which would have been abstracted away if we grouped by product ID).

I [implemented the k-modes algorithm](https://github.com/snisher/projects/tree/master/kmodes) in Julia, and used it for clustering. Then I looked at whether the clusters were useful for predicting which items would be sold at specific stores:

![Sales by Cluster](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/cluster_sales_by_store.png)

Store *#4594* sold almost entirely (~80%) products falling in cluster 1. Over 50% of sales from stores *#2248*, *#5127*, and *#4804*, were from cluster 4. These clusters are clearly useful in predicting which stores will sell a product.

\*Note that the clusters were not based on the store.
