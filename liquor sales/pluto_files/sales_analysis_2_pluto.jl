### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ 1de1c63c-050c-11eb-2089-5f09e76e93fd
begin
	using Pkg
	Pkg.activate("/Users/fisher/Documents/coding/projects/liquor sales/")
	using CSV, DataFrames, Dates, Query, Plots
	using StatsPlots: groupedbar
	using DataStructures: DefaultDict
	include("helper_functions.jl")
end

# ╔═╡ ddb3111e-050c-11eb-0052-e94c102f49b5
md"feature names:"

# ╔═╡ cdc568f8-050c-11eb-3295-b7067edc6b86
begin
	sample = CSV.File("Iowa_Liquor_Sales.csv", limit=1) |> DataFrame
	[(idx, name) for (idx, name) in enumerate(names(sample))]
end

# ╔═╡ fe11e4f8-050c-11eb-26d2-ef074b73de96
md"### Some analysis of sale volume by category for stores in a single zip code, 50312 (Des Moines)"

# ╔═╡ 57c8802e-050d-11eb-31db-cf130bea2d02
begin
	sales = CSV.File("Iowa_Liquor_Sales.csv", select=[2,3,4,6,7,11,12,20,21]) |> DataFrame |> dropmissing
	rename!(sales, Dict("Store Number"=>"Store", "Store Name"=>"Store_name", "Zip Code"=>"Zip", "Category Name"=>"Category_name", "Bottles Sold"=>"Bottles_sold", "State Bottle Retail"=>"Retail"))
	
	# convert dates to Date type
	format = DateFormat("m/d/y")
	sales.Date = Date.(sales.Date, format)
	
	# get only rows for stores in zip 50312 with dates later than Oct 2016
	mask = (sales.Zip .== "50312") .& (sales.Date .> Date(2016, 10))
	sales = sales[mask, :]
end

# ╔═╡ cb0fbb4e-050d-11eb-16c1-490f58884bc6
md"group by store and item category:"

# ╔═╡ 7a4c4040-050d-11eb-059f-a5b803d9b84d
groups = combine(groupby(sales, [:Store, :Category_name]), :Bottles_sold=>sum)

# ╔═╡ a8e686fe-050d-11eb-1aa2-9df8a0949536
md"This is the data we want to see: total sales of each category for each store.

But it's hard to look at in this format, so lets make a **table showing sales of each category for each store number**:"

# ╔═╡ ed49c2b6-050d-11eb-17ab-d9d7b0b5a6e6
begin
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
	table
end

# ╔═╡ 3ecd26d2-050e-11eb-1089-452d6dd65df2
# to visualize more easily, this function shows the number of sales of a given category for each stores
HelperFunctions.show_sales_by_category(table, categories[2])

# ╔═╡ 099d377a-050e-11eb-213c-0b16f7dd5bfe
md"## Now I'm going to check whether stores specialize in either cheap or expensive alcohol"

# ╔═╡ 6b99018a-050f-11eb-277c-176c81a2c7fb
# for each store, see how many bottles of each price range were sold
begin
	sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))
	
	HelperFunctions.bin_vals!(sales.Retail) # make retail price categorical (high, med, low)
	
	# for each store, see how many bottles of each price range were sold
	groups2 = combine(groupby(sales, [:Store, :Retail]), :Bottles_sold=>sum)
end

# ╔═╡ 2d71766c-0511-11eb-0ca7-a1da992b7798
md"As you can see below, store 2248 sells more bottles of expensive alcohol than either medium or cheap alcohol, while store 4594 sells almost exclusively cheap alcohol (but lots of it).

This shows that some stores do specialize in alcohols of certain price ranges."

# ╔═╡ b22210b0-050f-11eb-1b37-3f01a1ea8d26
begin
	bs = hcat([sort(groups2[groups2.Store .== store, :], :Retail).Bottles_sold_sum for store in unique(sales.Store)]...)'
	ctg = repeat(["1. cheap", "2. medium", "3. expensive"], 5)
	nams = repeat("Store " .* string.(unique(sales.Store)), 3)
	gb = groupedbar(nams, bs, group=ctg, bar_position=:dodge, title="Bottles Sold by Price Range", ylabel="Bottles Sold", xlabel="Store")
end

# ╔═╡ Cell order:
# ╠═1de1c63c-050c-11eb-2089-5f09e76e93fd
# ╟─ddb3111e-050c-11eb-0052-e94c102f49b5
# ╠═cdc568f8-050c-11eb-3295-b7067edc6b86
# ╟─fe11e4f8-050c-11eb-26d2-ef074b73de96
# ╠═57c8802e-050d-11eb-31db-cf130bea2d02
# ╟─cb0fbb4e-050d-11eb-16c1-490f58884bc6
# ╠═7a4c4040-050d-11eb-059f-a5b803d9b84d
# ╟─a8e686fe-050d-11eb-1aa2-9df8a0949536
# ╠═ed49c2b6-050d-11eb-17ab-d9d7b0b5a6e6
# ╠═3ecd26d2-050e-11eb-1089-452d6dd65df2
# ╟─099d377a-050e-11eb-213c-0b16f7dd5bfe
# ╠═6b99018a-050f-11eb-277c-176c81a2c7fb
# ╟─2d71766c-0511-11eb-0ca7-a1da992b7798
# ╠═b22210b0-050f-11eb-1b37-3f01a1ea8d26
