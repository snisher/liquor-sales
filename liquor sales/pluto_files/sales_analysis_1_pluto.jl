### A Pluto.jl notebook ###
# v0.11.14

using Markdown
using InteractiveUtils

# ╔═╡ 023387fa-050b-11eb-3cf0-f333c71a65c9
begin
	using Pkg
	Pkg.activate("/Users/fisher/Documents/coding/projects/liquor sales/")
	using CSV, DataFrames, Dates, Query, Plots
end

# ╔═╡ 1fd9c10e-0509-11eb-299f-15a070d09bbc
md"# Liquor Sales Analysis 1"

# ╔═╡ 497803f4-0504-11eb-36ed-377d7f6347ea
# import and format data
begin
	sales = CSV.File("../Iowa_Liquor_Sales.csv", select=[2, 3, 4, 6, 11, 12, 13, 14, 15, 21]) |> DataFrame |> dropmissing;
	
	rename!(sales, Dict("Vendor Number"=>"Vendor", "Vendor Name"=>"Vendor_name", "Store Name"=>"Store_name", "Bottles Sold"=>"Quantity", "Store Number"=>"Store", "Item Number"=>"Item", "Category Name"=>"Category_name"))
	
	# lowercase names
	sales.Category_name = lowercase.(sales.Category_name)
	sales.Store_name = lowercase.(sales.Store_name)

	# Convert dates to Date type
	format = DateFormat("m/d/y")
	dates = Date.(sales.Date, format)

	sales = hcat(dates, sales[:, 2:end])
	rename!(sales, Dict("x1"=>"Date"))

	sales["Month"] = month.(sales.Date)
	sales["Year"] = year.(sales.Date)
end

# ╔═╡ f9b130d6-0506-11eb-3925-5b6a029533c8
md"### Lets look at gin sales over time"

# ╔═╡ a7cce620-0506-11eb-1f53-4befddac86ce
begin
	# get gin
	category_df = unique(sales[[:Category, :Category_name]])
	gin_categories_df = category_df |> @filter(occursin(" gin", _.Category_name)) |> 	DataFrame
	gin_categories = Set(gin_categories_df.Category)
	
	# a function that returns whether its argument is in the gin_categories array
	gin_bool = in(gin_categories)
	gs = findall(gin_bool.(sales.Category)) # indices of gins
	gin_df = sales[gs, :]
end

# ╔═╡ c8f81c9c-0507-11eb-3c86-a32d0ad1fae3
begin
	sales_by_date = combine(groupby(gin_df, [:Date]), :Quantity=>sum)
	sort!(sales_by_date, :Date)
	plot(sales_by_date.Date, sales_by_date.Quantity_sum, legend=false, title="Iowa Gin Sales", ylabel="Bottles Sold", xlabel="Date")
end

# ╔═╡ 55d8439e-0508-11eb-107e-01808f096a6c
md"There is an odd drop in sales in the second half of 2016... this is probably due to a change in the record keeping process because the change is drastic.

Sales from Oct 2016 onward look much more reliable, so I'll focus on those.

**Let's look at the gin sales from the store that sells the most gin.**"

# ╔═╡ 67ec9102-0508-11eb-1746-cbdefe76a424
begin
	# find a store with lots of sales
	gin_2016 = gin_df[findall(gin_df.Date .> Date(2016,10)), :] # @filter was too slow...
	sales_by_store = combine(groupby(gin_2016, :Store), :Quantity=>sum)
	store_num = sort!(sales_by_store, :Quantity_sum)[end-1, :Store] # a store with lots of sales

	# get data for just that one store
	store = gin_2016 |> @filter(_.Store == store_num) |> DataFrame
	store = combine(groupby(store, :Date), :Quantity=>sum)
	sort!(store, :Date)
	plot(store.Date, store.Quantity_sum, legend=false, title="Gin Sales in Store #$(store_num)", ylabel="Bottles Sold", xlabel="Date")
end

# ╔═╡ 8c8d514e-0509-11eb-2c1e-47856688138c
begin
	# sales by day of week
	store[:Day] = dayofweek.(store.Date)
	days = combine(groupby(store, :Day), :Quantity_sum=>sum)
	sort!(days, :Day)
	rename!(days, Dict(:Quantity_sum_sum=>:Quantity))
	bar(["Mon", "Tues", "Wed", "Thurs", "Fri"], days.Quantity, legend=false, title="Gin Sales in Store #$(store_num) by Day", ylabel="Bottles Sold")
end

# ╔═╡ d73b603c-0509-11eb-2fe2-4ff86af4f636
md"looks like most sales in this store are on Mon and Thurs. This probably reflects reporting rather than real sales..."

# ╔═╡ e263cbf2-0509-11eb-23d0-e9d40870b6d0
begin
	sort!(sales_by_store, :Quantity_sum, rev=true)
	store_names = "Store #".*string.(sales_by_store.Store[1:10])
	bar(store_names, sales_by_store.Quantity_sum[1:10], legend=false, xrotation=30, title="Stores with Highest Gin Sales (Oct 2016 - Oct 2017)", ylabel="Bottles Sold")
end

# ╔═╡ Cell order:
# ╟─1fd9c10e-0509-11eb-299f-15a070d09bbc
# ╠═023387fa-050b-11eb-3cf0-f333c71a65c9
# ╠═497803f4-0504-11eb-36ed-377d7f6347ea
# ╟─f9b130d6-0506-11eb-3925-5b6a029533c8
# ╠═a7cce620-0506-11eb-1f53-4befddac86ce
# ╠═c8f81c9c-0507-11eb-3c86-a32d0ad1fae3
# ╟─55d8439e-0508-11eb-107e-01808f096a6c
# ╠═67ec9102-0508-11eb-1746-cbdefe76a424
# ╠═8c8d514e-0509-11eb-2c1e-47856688138c
# ╟─d73b603c-0509-11eb-2fe2-4ff86af4f636
# ╠═e263cbf2-0509-11eb-23d0-e9d40870b6d0
