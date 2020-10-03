### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ 6e555524-0512-11eb-168e-8fb383b62d5b
begin
	using Pkg
	Pkg.activate("/Users/fisher/Documents/coding/projects/liquor sales/")
	using CSV, DataFrames, Dates, Plots, StatsBase
	using ParallelKMeans, Distances
	include("../kmodes/kmodes.jl")
	include("helper_functions.jl")
end

# ╔═╡ 9bbc86b6-0512-11eb-330b-7defba80f2c7
begin
	sales = CSV.File("Iowa_Liquor_Sales.csv", select=[3,7,11,13,15,17,18,20,22]) |> DataFrame |> dropmissing
	rename!(sales, Dict("Vendor Number"=>"Vendor", "Bottle Volume (ml)"=>"Bottle_volume", "Zip Code"=>"Zip", "State Bottle Retail"=>"Retail", "Sale (Dollars)"=>"Dollars", "Store Number"=>"Store","Item Number"=>"Product_id"))
	
	sales = sales[sales.Zip .== "50312", :] # only sales from this zip code
	select!(sales, Not(:Zip)) # drop the zip code column
	
	sales.Dollars = parse.(Float32, strip.(sales.Dollars, '$'))
	sales.Retail = parse.(Float32, strip.(sales.Retail, '$'))
	
	sales.Store = "#".*string.(sales.Store)
end

# ╔═╡ 606fc088-0515-11eb-03d9-f72e20a5cbee
md"#### We want to cluster on product ID, so we need a table of the unique products"

# ╔═╡ 48d2c09a-0515-11eb-1da9-2db85935ff58
begin
	HelperFunctions.bin_vals!(sales.Dollars)
	HelperFunctions.bin_vals!(sales.Retail)
	HelperFunctions.bin_vals!(sales.Bottle_volume)
	
	mean_int(x) = round(mean(x))
	
	products = combine(groupby(sales, :Product_id), ["Dollars"=>mean_int, "Retail"=>mean_int, "Bottle_volume"=>mean_int, "Pack"=>mean_int, "Vendor"=>mode, "Category"=>mode])
end

# ╔═╡ c921fed0-0512-11eb-355a-5b464fd699be
md"## Try K-means clustering 

Using Hamming distance metric. Spoilers, it doesn't work well.

Below I **bin continuous variables into categorical** (for the sake of using the KModes algorithm).

We will be using the Hamming distance for clustering so that we don't need one-hot labels. 

Hamming distance = sum(x .!= y)

This sometimes works with categorical data bc it doesn't calculate a euclidean distance between categorical variables which is nonsensical."

# ╔═╡ 3ee2d400-0513-11eb-2c57-4baffa375b3b
begin
	features = collect(Matrix(products)') # transpose bc PKMeans expects features in rows
	
	results = kmeans(features, 4, metric=Hamming()); # hamming distance for categorical features
end

# ╔═╡ 6f48dfd6-0513-11eb-34d8-01397bc3f08d
[(center, sum(results.assignments .== center)) for center in 1:size(results.centers, 2)]

# ╔═╡ a02eeb38-0513-11eb-32ed-e12891f2a317
md"As you can see above, most points get assigned to a single cluster. KMeans doesn't work well for this categorical data. This is probably due to k-means using the mean of categorical features (which is nonsensical)."

# ╔═╡ f474acc6-0513-11eb-2c01-0106e4239270
md"## K-modes"

# ╔═╡ 01096b66-0514-11eb-0d12-dd4abd4f1076
begin
	features_kmodes = convert.(Int64, features)
	
	results_kmodes = KModes.kmodes(features_kmodes, 4) # takes a little while
end

# ╔═╡ c32928fa-0514-11eb-1be2-25219f60f606
md"Below you can see each store's percentage of sales that came from the products of a single cluster."

# ╔═╡ 25011d02-0514-11eb-0294-ff674ebc82be
# note that bars() returns an array corresponding to store names in sorted order
begin
	ps = [
	    bar(sort(unique(sales.Store)), HelperFunctions.bars(i, sales, products, results_kmodes), legend=false, title="Cluster $i", ylims=(0,1), ylabel="% Sales")
	for i in 1:4]
	
	l = @layout [a b; c d]
	p = plot(ps..., layout=l)
end

# ╔═╡ Cell order:
# ╠═6e555524-0512-11eb-168e-8fb383b62d5b
# ╠═9bbc86b6-0512-11eb-330b-7defba80f2c7
# ╠═606fc088-0515-11eb-03d9-f72e20a5cbee
# ╠═48d2c09a-0515-11eb-1da9-2db85935ff58
# ╟─c921fed0-0512-11eb-355a-5b464fd699be
# ╠═3ee2d400-0513-11eb-2c57-4baffa375b3b
# ╠═6f48dfd6-0513-11eb-34d8-01397bc3f08d
# ╟─a02eeb38-0513-11eb-32ed-e12891f2a317
# ╟─f474acc6-0513-11eb-2c01-0106e4239270
# ╠═01096b66-0514-11eb-0d12-dd4abd4f1076
# ╟─c32928fa-0514-11eb-1be2-25219f60f606
# ╠═25011d02-0514-11eb-0294-ff674ebc82be
