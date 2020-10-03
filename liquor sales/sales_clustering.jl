"""
Clustering alcohol product sales from a single zip code.

Problem statement: find clusters of products that are overrepresented in some stores
    (useful for product distribution).
To do this I will cluster line-item sales invoices. This is very similar to clustering
    on product IDs, but leaves purchases of the same product in the table. This is useful
    because in the end we can still see the quantity of each product (which would have
    been abstracted away if we grouped by product ID).

First K-means is tested, then K-modes.
"""

using CSV, DataFrames, Dates, Plots, StatsBase
using ParallelKMeans, Distances
include("../kmodes/kmodes.jl")
include("helper_functions.jl")

sales = CSV.File("Iowa_Liquor_Sales.csv", select=[3,7,11,13,15,17,18,20,22]) |> DataFrame |> dropmissing
rename!(sales, Dict("Vendor Number"=>"Vendor", "Bottle Volume (ml)"=>"Bottle_volume", "Zip Code"=>"Zip",
                    "State Bottle Retail"=>"Retail", "Sale (Dollars)"=>"Dollars",
                    "Store Number"=>"Store","Item Number"=>"Product_id"))

sales = sales[sales.Zip .== "50312", :] # only sales from this zip code
select!(sales, Not(:Zip)) # drop the zip code column

sales.Dollars = parse.(Float32, strip.(sales.Dollars, '$'))
sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))

sales.Store = "#".*string.(sales.Store) 

"""
bin continuous variables into categorical (for the sake of using the KModes algorithm).
We will be using the Hamming distance for clustering, so we don't need one-hot labels:
    Hamming distance = sum(x .!= y). For every feature of x that is not equal to the corresponding
    feature of y, a distance of 1 is added to the hamming distance. This sometimes works with
    categorical data bc it doesn't calculate a euclidean distance between categorical variables
    which is nonsensical.
"""

HelperFunctions.bin_vals!(sales.Dollars)
HelperFunctions.bin_vals!(sales.Retail)
HelperFunctions.bin_vals!(sales.Bottle_volume)

mean_int(x) = round(mean(x)) # round mean to the nearest whole number
# group by product ID so we can cluster products
products = combine(groupby(sales, :Product_id), 
    ["Dollars"=>mean_int, "Retail"=>mean_int, "Bottle_volume"=>mean_int, 
    "Pack"=>mean_int, "Vendor"=>mode, "Category"=>mode]
    )

###
# K means
###

features = collect(Matrix(products)') # transpose bc PKMeans expects features in rows

results = kmeans(features, 4, metric=Hamming()) # hamming distance for categorical features

# print how many points are assigned to each cluster (all get assigned to a single cluster usually)
for center in 1:size(results.centers, 2)
    println("points in cluster $(center): ", sum(results.assignments .== center))
end

# "elbow" method of finding optimal number of clusters (none show greatly improved performance)
costs = [(i=>kmeans(features, i, metric=Hamming(), verbose=false).totalcost) for i in 2:8]


"""
Hamming distance K-means isn't working well. Points are mostly assigned to the same cluster...
This could be due to kmeans using the mean of categorical features (which is nonsensical).

Lets try K-modes.
"""


features = convert.(Int64, features)

costs = [(i=>KModes.kmodes(features, i).cost) for i in 2:5]

results = KModes.kmodes(features, 4) # takes a little while

# For the clusters I got when writing this (they will change if run again), cluster 1 was
# mostly cheap, small bottles, that came in large packs.

# plot the sales of each different cluster across the stores

ps = [
    bar(sort(unique(sales.Store)), HelperFunctions.bars(i, sales, products, results), legend=false,
            title="Cluster $i", ylims=(0,1), ylabel="% Sales")
    for i in 1:4]

l = @layout [a b; c d]
p = plot(ps..., layout=l)