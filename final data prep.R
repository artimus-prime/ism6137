# set working directory
setwd("ism6137")

# load the boattrader output .csv file
df <- read.csv("boattrader output 11.15.2019.csv", header=T, na.strings=c("","NA"))

# first of all, we are going to remove any duplicate record (use Listing ID)
df_listing_dup <- duplicated(df$Listing.ID)
df <- df[!df_listing_dup,]
rm(df_listing_dup)

# next, remove any records where State value is N/A or blank
df <- df[!(is.na(df$State) | df$State==""), ]

# even though Python web scraping script should have removed all Listings without a Price,
# make sure to try to remove records where price is 0, n/a or blank
df <- df[!(is.na(df$Listed.Price) | df$Listed.Price=="" | df$Listed.Price==0), ]

# let's calculate Boat's Age now. Since there's listing with 2020 Built Year, we'll use it as base. Age = 2020 - Year.Built
# introduce a new column, set to 0 by default, then loop through the df and calculate
df$Boat.Age = 0
for (i in 1:nrow(df))
	df$Boat.Age[i] = 2020 - df$Year.Built[i]

# now define Regions using State values
# note that the state values in Python produced output were analyzed first, then decision was made to assign according to rules below
# Pacific: CA, OR, WA
# Great Lakes: MI, WI, IL, IN
# North East: MA, NY, NJ, CT, MD, DE, DC, VA, RI, NH, MD, PA
# South East: FL, GA, SC, NC, AL
# everything else - "Other" (default value as well)
df$Region = "Other"
# loop through df and assign market based on the state value:
for (i in 1:nrow(df))
{
	if ( df$State[i] == "CA" | df$State[i] == "OR" | df$State[i] == "WA" )
		df$Region[i] = "Pacific"
	else if ( df$State[i] == "MI" | df$State[i] == "WI" | df$State[i] == "IL" | df$State[i] == "IN" )
		df$Region[i] = "Great Lakes"
	else if ( df$State[i] == "MA" | df$State[i] == "NY" | df$State[i] == "NJ" | df$State[i] == "CT" | df$State[i] == "MA" | df$State[i] == "VA" | df$State[i] == "DE" | df$State[i] == "RI" | df$State[i] == "DC" | df$State[i] == "NH" | df$State[i] == "MD" | df$State[i] == "PA")
		df$Region[i] = "North East"
	else if ( df$State[i] == "FL" | df$State[i] == "GA" | df$State[i] == "AL" | df$State[i] == "SC" | df$State[i] == "NC" )
		df$Region[i] = "South East"
	else
		df$Region[i] = "Other"
}

# calculate number of listings for each seller and manufacturer, then calculate their %market share
# in case of Seller we will calculate the count and share per Region, while Manufacturer count and share for the whole data set
# use data.table to do that:
# load data.table
library(data.table)

# load the current data frame in a new data.table
dt = data.table(df)

# now we can use data.table methods to calculate count for each label in a column
# Seller Listing Count 
dt[ , Seller.Listing.Count:= .N, by = list(Seller.ID)]
# using data.table to calculate Seller's market share %
dt[ , Seller.Market.Share:= .N/nrow(dt), by = list(Seller.ID)]
# Manufacturer Listing Count
dt[ , Manufacturer.Listing.Count:= .N, by = list(Manufacturer)]
# using data.table to get Manufacturer's market share %
dt[ , Manufacturer.Market.Share:= .N/nrow(dt), by = list(Manufacturer)]

# now we can add "Big Brand" dummy variable
# after analyzing the output data and manufacturer listing count, I've decided to use 3% threshold to define Big Brand (instead of 5%)
# manufacturers with more than 3% market share are "Big Brand" = 1, else = 0
dt$Dummy.Big.Brand <- ifelse(dt$Manufacturer.Market.Share>=0.03, 1, 0)

# I've attemted to calculate Top Seller per Region at first but that proved problematic
# however, after I tweaked the search URLs and the resulting data set has sample sizes that are somewhat equal,
# I decided to determine Top Sellers using all the data, but with a lower threshold = 1%
# define Dummy variable for Top Seller the same way as for the Manufacturer:
dt$Dummy.Top.Seller <- ifelse(dt$Seller.Market.Share>=0.01, 1, 0)

# now let's create dummy variables for the region
# since we have 5 regions, we'll need 4 variables (none will represent "Other" region)
# go through the data table and set to 1 or 0 as needed
dt$Dummy.Region.Pacific <- ifelse(dt$Region == "Pacific", 1, 0)
dt$Dummy.Region.GreatLakes <- ifelse(dt$Region == "Great Lakes", 1, 0)
dt$Dummy.Region.NorthEast <- ifelse(dt$Region == "North East", 1, 0)
dt$Dummy.Region.SouthEast <- ifelse(dt$Region == "South East", 1, 0)

# feed dt back into df
df <- dt

#Export dataframe "df" as .csv and this will be the file used for all analyses and data vizes.
write.table(df, file = "boattrader prepped data.csv",append = FALSE, quote = TRUE, sep = ",", row.names = FALSE, col.names = TRUE)