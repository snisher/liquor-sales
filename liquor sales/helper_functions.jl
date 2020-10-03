module HelperFunctions

export bin_vals!, bars, show_sales_by_category

using StatsBase: quantile
using DataFrames, Plots, DataStructures

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

"""
Creates the bar heights for a single bar graph showing the percent of store sales
    from from products in a cluster.

requires results::KmodesResult from the K-modes algorithm.
"""
function bars(clust, sales_df, products, results)
    sales_by_store = []
    for name in sort(unique(sales_df.Store))
        total_sales = sum(sales_df.Store .== name) # total sales for this store

        clust_prod_ids = products.Product_id[results.assignments .== clust] # product IDs in this cluster
        in_prod_ids = in(clust_prod_ids) # function returns whether its argument is in clust_prod_ids

        # sum all purchases which are from the right store, and have a product ID in this cluster
        clust_sales = sum( (sales_df.Store .== name) .& (in_prod_ids.(sales_df.Product_id)) )

        push!(sales_by_store, clust_sales/total_sales)
    end
    return sales_by_store
end

"""
Shows bar graph of the number of sales of a given category for each store.
"""
function show_sales_by_category(df::DataFrame, cat::String)
    row = df[df.Category .== cat, :] # a single category
    stores = names(df)[2:end] # the store numbers
    stores = "Store #".*string.(stores) # store labels
    vals = Array(row[:, 2:end])' # Plots expects a column vector, so transpose
    bar(stores, vals, legend=false, title="$(cat) Sales", ylabel="Bottles Sold")
end

end # module