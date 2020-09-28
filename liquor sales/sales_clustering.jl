"""
In this file I investigate clusters of products (liquors) from stores in a single zip code.
The purpose is to find clusters such that a person could be assigned to a single cluster.

The products are already clustered into categories, so first I look at sales of these 
    categories in the stores of the chosen zip code.

Then I create custom clusters based on the product attributes.
"""

using CSV, DataFrames, Dates, Query, Plots, StatsPlots, CategoricalArrays, DataStructures
using MLJ, ParallelKMeans, StatsBase, Distances

sample = CSV.File("Iowa_Liquor_Sales.csv", limit=1) |> DataFrame
for (idx, name) in enumerate(names(sample)) 
    println(idx, ")  ", (length(digits(idx)) == 1 ? " " : ""),  name)
end

"""
####
First, some analysis of sale volume by category for stores in a single zip code, 50312 (Des Moines)
####
"""

sales = CSV.File("Iowa_Liquor_Sales.csv", select=[2,3,4,6,7,11,12,20,21]) |> DataFrame |> dropmissing
rename!(sales, Dict("Store Number"=>"Store", "Store Name"=>"Store_name", "Zip Code"=>"Zip",
                    "Category Name"=>"Category_name", "Bottles Sold"=>"Bottles_sold",
                    "State Bottle Retail"=>"Retail"))

# convert dates to Date type
format = DateFormat("m/d/y")
sales.Date = Date.(sales.Date, format)

# get only rows for stores in zip 50312 with dates later than Oct 2016
mask = (sales.Zip .== "50312") .& (sales.Date .> Date(2016, 10))
sales = sales[mask, :]
length(unique(sales.Store)) # 5 stores in this zip code

# group by store and item category
groups = combine(groupby(sales, [:Store, :Category_name]), :Bottles_sold=>sum)

###
# This is the data we want to see: total sales of each category for each store.
# But it's hard to look at in this format, so lets make a table with categories as rows and stores as cols.
###

stores = sort(unique(groups.Store))
categories = sort(unique(groups.Category_name))

table_dict = DefaultDict{Int64, DefaultDict{String,Int64,Int64}}(()->DefaultDict{String,Int64,Int64}(0))
for store = stores, cat = categories
    arr = groups[(groups.Store .== store) .& (groups.Category_name .== cat), :Bottles_sold_sum]
    @assert length(arr) < 2
    table_dict[store][cat] = isempty(arr) ? 0 : arr[1]
end

table = DataFrame(:Category=>categories)
for (key, val) in table_dict # key = store number, val = dict of categories => bottles sold
    table[:, string(key)] = values(sort(Dict(val), byvalue=false)) # sort by key (category), then get the values (bottles sold for this store)
end

# to visualize more easily, this function shows the number of sales of a given category for all stores
function show_sales_by_category(df::DataFrame, cat::String)
    row = df[df.Category .== cat, :] # a single category
    stores = names(df)[2:end] # the store numbers
    stores = "Store #".*string.(stores) # store labels
    vals = Array(row[:, 2:end])' # Plots expects a column vector, so transpose
    bar(stores, vals, legend=false, title="$(cat) Sales", ylabel="Bottles Sold")
end

show_sales_by_category(table, unique(table.Category)[29])

"""
These stores probably specialize in either cheap alcohol or expensive alcohol.
I'm going to check this hypothesis.
"""

"""
bins the values in an array into high, medium and low (3, 2, and 1)
"""
function bin_vals!(arr)
    one_third = quantile(arr, .333)
    two_thirds = quantile(arr, .667)
    
    lower_indices = (arr .<= one_third)
    middle_indices = (arr .> one_third) .& (arr .< two_thirds)
    upper_indices = (arr .>= two_thirds)

    arr[lower_indices] .= 1
    arr[middle_indices] .= 2
    arr[upper_indices] .= 3
    return arr
end

sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))

bin_vals!(sales.Retail) # make retail price categorical (high, med, low)

# for each store, see how many bottles of each price range were sold
groups = combine(groupby(sales, [:Store, :Retail]), :Bottles_sold=>sum)

bs = hcat([sort(groups[groups.Store .== store, :], :Retail).Bottles_sold_sum for store in unique(sales.Store)]...)'
ctg = repeat(["1. cheap", "2. medium", "3. expensive"], 5)
nams = repeat("Store " .* string.(unique(sales.Store)), 3)
gb = groupedbar(nams, bs, group=ctg, bar_position=:dodge, title="Bottles Sold by Price Range",
        ylabel="Bottles Sold", xlabel="Store", dpi=250)

##
# Store 2248 sells more bottles of expensive alcohol than either medium or cheap alcohol,
# while store 4594 sells almost exclusively cheap alcohol (but lots of it).
##



"""
Clustering products from a certain location.
Assign preference groups.
Features to cluster on (product features):
    - Category
    - Vendor Number
    - Pack
    - Bottle Volume (mL)
    - State Bottle Retail
    - Sale (Dollars)
[11, 13, 17, 18, 20, 22]
"""

sales = CSV.File("Iowa_Liquor_Sales.csv", select=[3,7,11,13,17,18,20,22]) |> DataFrame |> dropmissing
rename!(sales, Dict("Vendor Number"=>"Vendor", "Bottle Volume (ml)"=>"Bottle_volume", "Zip Code"=>"Zip",
                    "State Bottle Retail"=>"Retail", "Sale (Dollars)"=>"Dollars",
                    "Store Number"=>"Store"))

sales = sales[sales.Zip .== "50312", :] # only sales from this zip code
select!(sales, Not(:Zip)) # drop the zip code column

sales.Dollars = parse.(Float32, strip.(sales.Dollars, '$'))
sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))

sales.Store = "#".*string.(sales.Store) 

"""
bin continuous variables into categorical (for the sake of using the KModes algorithm)
We will be using the Hamming distance for clustering, so we don't need one-hot labels:
    Hamming distance = sum(x .!= y). For every feature of x that is not equal to the corresponding
    feature of y, a distance of 1 is added to the hamming distance. This sometimes works with
    categorical data bc it doesn't calculate a euclidean distance between categorical variables
    which is nonsensical.
"""

bin_vals!(sales.Dollars)
bin_vals!(sales.Retail)
bin_vals!(sales.Bottle_volume)

features = collect(Matrix(select(sales, Not(:Store)))') # transpose bc PKMeans expects features in rows

results = kmeans(features, 4, metric=Hamming()) # hamming distance for categorical features

# print how many points are assigned to each cluster
for center in 1:size(results.centers, 2)
    println("points in cluster $(center): ", sum(results.assignments .== center))
end

# "elbow" method of finding optimal number of clusters
costs = [kmeans(features, i, metric=Hamming(), verbose=false).totalcost for i in 2:8]

"""
Hamming distance isn't working well. Points are mostly assigned to the same cluster...
This could be due to kmeans using the mean of categorical features (which is nonsensical).
I'll try implementing k-modes.
"""

features = convert.(Int64, features)

include("../kmodes/kmodes.jl")

results = KModes.kmodes(features, 5) # takes a little while

# This will be different if run again! 
histogram(sales.Retail[results.assignments .== 1]) # cluster 1 = cheap
histogram(sales.Retail[results.assignments .== 2]) # cluster 2 = expensive
histogram(sales.Retail[results.assignments .== 3]) # cluster 3 = medium
histogram(sales.Retail[results.assignments .== 4]) # mostly cheap and medium
histogram(sales.Retail[results.assignments .== 5]) # medium

histogram(sales.Bottle_volume[results.assignments .== 1]) # small bottles

histogram(sales.Pack[results.assignments .== 1]) # 24 packs are overrepresented in clust 1

# For the clusters I got when writing this (they will change if run again), cluster 1 was
# mostly cheap, small bottles, that came in large packs.

# plot the sales of each different cluster across the stores

function bars(clust)
    sales_by_store = []
    for name in unique(sales.Store)
        total_sales = sum(sales.Store .== name)
        clust_sales = sum(sales.Store[results.assignments .== clust] .== name)
        push!(sales_by_store, clust_sales/total_sales)
    end
    return sales_by_store
end

ps = [
    bar(unique(sales.Store), bars(i), legend=false, title="Cluster $i",
            ylims=(0,1), ylabel="% Sales", dpi=200)
    for i in 1:5]

l = @layout [a b; c d; e]
p = plot(ps..., layout=l, dpi=200)

"""
Some 
"""