"""
More exploratory analysis, focusing on clusters of products.

The products are already clustered into categories, so first I look at sales of these 
    categories in the stores of a chosen zip code.

In 'sales_clustering.jl' custom clusters are created.
"""

using CSV, DataFrames, Dates, Query, Plots
using StatsPlots: groupedbar
using DataStructures: DefaultDict
include("helper_functions.jl")

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

show_sales_by_category(table, categories[2])

"""
These stores probably specialize in either cheap alcohol or expensive alcohol.
I'm going to check this hypothesis.
"""

sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))

HelperFunctions.bin_vals!(sales.Retail) # make retail price categorical (high, med, low)

# for each store, see how many bottles of each price range were sold
groups = combine(groupby(sales, [:Store, :Retail]), :Bottles_sold=>sum)

bs = hcat([sort(groups[groups.Store .== store, :], :Retail).Bottles_sold_sum for store in unique(sales.Store)]...)'
ctg = repeat(["1. cheap", "2. medium", "3. expensive"], 5)
nams = repeat("Store " .* string.(unique(sales.Store)), 3)
gb = groupedbar(nams, bs, group=ctg, bar_position=:dodge, title="Bottles Sold by Price Range",
        ylabel="Bottles Sold", xlabel="Store")

##
# Store 2248 sells more bottles of expensive alcohol than either medium or cheap alcohol,
# while store 4594 sells almost exclusively cheap alcohol (but lots of it).
##
