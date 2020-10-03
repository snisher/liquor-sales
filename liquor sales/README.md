# Iowa Liquor Sales Analysis
This project used the [Iowa Liquor Sales](https://www.kaggle.com/residentmario/iowa-liquor-sales) Kaggle data set. The data consists of several years of line-item invoices from Iowan liquor stores. Each line item includes attributes about the alcohol sold and the store it was sold at.

Some assumptions going into this project: The main purpose was to use a categorical clustering algorithm (K-modes) on the data I had. Something like K-prototypes might be more ideal because I wouldn't lose any information by binning continuous variables into categorical ones, but for the sake of using K-modes, I binned continuous variables.

### Problem statement
Are there clusters of products associated with certain stores in a single zip code? 

### Why this project
The purpose is to get familiar with the Julia data environment (CSV, DataFrames, Query, etc.) and the K-modes algorithm.

### Design
Two parts to the project:

**1. Exploratory analysis**: Basic analysis and plotting to make sure the data makes sense and doesn't have errors, as well as confirm that stores specialize in different products. Each product is already assigned to a category, which is a cluster, so investigate if these categories are useful in differentiating stores.

**2. Modeling**: Implement the [K-modes algorithm](https://github.com/snisher/projects/tree/master/kmodes) to create custom clusters of products (cluster on product ID).

Tools/packages to use:

- Julia
- VS Code
- CSV.jl (loading data)
- DataFrames.jl (working with data table)
- Dates.jl (working with dates)
- Query.jl (searching data)
- Plots.jl (graphing data)
- DataStructures.jl (dictionaries with default values)
- ParallelKMeans.jl (K-means clustering)

### Data Structures
Data was loaded into DataFrames and manipulated in that format.

The results from K-modes clustering are returned in a KmodesResult data structure.

### Research and Modeling
- To get a feel for the data, I analyzed gin sales: [sales_analysis_1_pluto.jl](https://github.com/snisher/projects/blob/master/liquor%20sales/pluto_files/sales_analysis_1_pluto.jl).

- Groups of products were investigated to see if the problem statement was reasonable: [sales_analysis_2_pluto.jl](https://github.com/snisher/projects/blob/master/liquor%20sales/pluto_files/sales_analysis_2_pluto.jl).

- Products were then clustered and sales by store analyzed: [sales_clustering_pluto.jl](https://github.com/snisher/projects/blob/master/liquor%20sales/pluto_files/sales_clustering_pluto.jl).

## What worked/ didn't work
**Tools**:

✅ DataFrames works well.

❌ Query can be very slow to filter. Often much faster to manually create a boolean list of rows using standard Julia syntax like this: dataframe.attribute .== val

✅ Use StatsPlots.groupedbar for a bar chart with multiple columns per axis label.

**Methodology**

❌ K-means clustering doesn't work for categorical features (even if using Hamming rather than euclidean distance). Most (often all) points end up in a single cluster. This is probably because K-means calculates the mean of categorical values, which is nonsensical.

✅ K-modes for categorical data works as expected.

## What I learned
**From analysis:**

Several stores in zip code 50312 specialize in selling either cheap or expensive alcohol.
![Sales by Price](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/sales_by_price_store.png)

**From modeling:**

Clustering products divides them into groups that are sold in different quantities at stores in close proximity to each other.
![Sales by Cluster](https://raw.githubusercontent.com/snisher/projects/master/liquor%20sales/cluster_sales_by_store.png)

Store *#4594* sold almost entirely (~80%) products falling in cluster 4. About 50% of sales from stores *#2248*, *#5127*, and *#4804*, were from cluster 2. These clusters are clearly useful in predicting which stores will sell a product.

\*Note that the clusters were not based on the store.

## Future work
- Investigate these clustering trends in other zip codes.
- Try K-prototypes algorithm for clustering on mixed continuous and categorical data.
- Turn K-modes implementation into a Julia package?
