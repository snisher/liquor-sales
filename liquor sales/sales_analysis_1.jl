"""
Some basic exploratory analysis on Gin sales.
"""

using CSV, DataFrames, Dates, Query, Plots

sales = CSV.File("Iowa_Liquor_Sales.csv", select=[2, 3, 4, 6, 11, 12, 13, 14, 15, 21]) |> DataFrame |> dropmissing
rename!(sales, Dict("Vendor Number"=>"Vendor", "Vendor Name"=>"Vendor_name", "Store Name"=>"Store_name", 
                                "Bottles Sold"=>"Quantity", "Store Number"=>"Store", 
                                "Item Number"=>"Item", "Category Name"=>"Category_name"))

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

# get gin
category_df = unique(sales[[:Category, :Category_name]])
gin_categories_df = category_df |> @filter(occursin(" gin", _.Category_name)) |> DataFrame
gin_categories = Set(gin_categories_df.Category)

# a function that returns whether its argument is in the gin_categories array
gin_bool = in(gin_categories)
gs = findall(gin_bool.(sales.Category)) # indices of gins
gin_df = sales[gs, :]

"""
#####
Lets look at gin sales over Time
#####
"""

sales_by_date = combine(groupby(gin_df, [:Date]), :Quantity=>sum)
sort!(sales_by_date, :Date)
plot(sales_by_date.Date, sales_by_date.Quantity_sum, legend=false, title="Iowa Gin Sales",
            ylabel="Bottles Sold", xlabel="Date")

# There is an odd drop in sales in the second half of 2016... this is probably due to a change in the
#     record keeping process because the change is drastic.


sales_2016 = sales_by_date |> @filter(_.Date > Date(2016, 10)) |> DataFrame
plot(sales_2016.Date, sales_2016.Quantity_sum, legend=false, title="Iowa Gin Sales",
            ylabel="Bottles Sold", xlabel="Date")
# Sales from Oct 2016 onward look much more reliable, so I'll focus on those

"""
#####
Now lets look at the gin sales for the store that sells the largest quantity
#####
"""

# find a store with lots of sales
gin_2016 = gin_df[findall(gin_df.Date .> Date(2016,10)), :] # @filter was too slow...
sales_by_store = combine(groupby(gin_2016, :Store), :Quantity=>sum)
store_num = sort!(sales_by_store, :Quantity_sum)[end-1, :Store] # a store with lots of sales

# get data for just that one store
store = gin_2016 |> @filter(_.Store == store_num) |> DataFrame
store = combine(groupby(store, :Date), :Quantity=>sum)
sort!(store, :Date)
plot(store.Date, store.Quantity_sum, legend=false, title="Gin Sales in Store #$(store_num)",
            ylabel="Bottles Sold", xlabel="Date")

# sales by day of week
store[:Day] = dayofweek.(store.Date)
days = combine(groupby(store, :Day), :Quantity_sum=>sum)
sort!(days, :Day)
rename!(days, Dict(:Quantity_sum_sum=>:Quantity))
bar(["Mon", "Tues", "Wed", "Thurs", "Fri"], days.Quantity, legend=false, 
            title="Gin Sales in Store #$(store_num) by Day", ylabel="Bottles Sold")

# looks like most sales in this store are on Mon and Thurs. This could reflect reporting rather than real sales...


"""
####
Find the stores with the most gin sales since Oct 2016
####
"""

sales_by_store = combine(groupby(gin_2016, :Store_name), :Quantity=>sum)
sort!(sales_by_store, :Quantity_sum, rev=true)
bar(sales_by_store.Store_name[1:10], sales_by_store.Quantity_sum[1:10], legend=false, xrotation=30,
            title="Stores with Highest Gin Sales (Oct 2016 - Oct 2017)", ylabel="Bottles Sold")


"""
####
A more complicated Query just for fun
####
"""

vendors_10_2016 = gin_2016 |> 
    @filter(_.Month == 10) |>
    @filter(_.Year == 2016) |>
    @filter(occursin("hy-vee", _.Store_name)) |>
    @groupby(_.Vendor_name) |>
    @map({Vendor_name=key(_), Quantity=sum(_.Quantity)}) |>
    DataFrame

sort!(vendors_10_2016, :Quantity, rev=true)

# In Hy-Vee stores, PERNOD RICARD USA was the vendor of the most sold Gin in Oct 2016.