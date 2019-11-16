# this way to calculate % of total works when data is aggregated
# my.df$Pct <- my.df$Total.Count / sum(my.df$Total.Count)
# # set the name we want to a column ColumnOldName
# names(df)[names(df) == 'ColumnOldName'] <- 'ColumnNewName'
# # introduce "Manufacturer.Share" column, set values to 0 by default
# df$Manufacturer.Share = 0
# for (i in 1:nrow(df))
# 	df$Manufacturer.Share[i] = df$Manufacturer.Listing.Count[i]/nrow(df)


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
# Pacific Coast: CA, OR, WA
# Great Lakes: MI, WI, IL, IN
# North East: MA, NY, NJ, CT, MD, DE, DC, VA, RI, NH, MD, PA
# South East: FL, GA, SC, NC, AL
# everything else - "Other" (default value as well)
df$Region = "Other"
# loop through df and assign market based on the state value:
for (i in 1:nrow(df))
{
	if ( df$State[i] == "CA" | df$State[i] == "OR" | df$State[i] == "WA" )
		df$Region[i] = "Pacific Coast"
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

# now using data.table method to calculate count for each label in a column
# Seller Listing Count on a Region level
dt[ , Seller.Listing.Count:= .N, by = list(Seller.ID, Region)]
# 
dt[ , Seller.Listing.Count:= .N, by = list(Seller.ID)]
# Manufacture Count on the whole data
dt[ , Manufacturer.Listing.Count:= .N, by = list(Manufacturer)]
# using data.table to Manufacturer's market share %
dt[ , Manufacturer.Market.Share:= .N/nrow(dt), by = list(Manufacturer)]
# in order to calculate Seller share, we need to know how many listings per Region there is:
# dt[ , Region.Listing.Count:= .N, by = list(Region)]
# now we can loop through the data table and calculate % seller in Region (I'm sure there's better way to do it, but this one works okay)
# dt$Seller.Market.Share = 0
# for (i in 1:nrow(dt))
# 	dt$Seller.Market.Share[i] = dt$Seller.Listing.Count[i] / dt$Region.Listing.Count[i]
# we can add "Big Brand" dummy variable now
# manufacturers with more than 5% market share are "Big Brand" = 1, else = 0
dt$Dummy.Big.Brand <- ifelse(dt$Manufacturer.Market.Share>=0.05, 1, 0)
# to define top sellers in Region, I picked the following thresholds per Region (after the data was reviewed):
# Great Lakes > 2.5%, Pacific Coast and Other > 2%, North Atlantic > 1.5%, Florida > 1.2%
# for (i in 1:nrow(dt))
# {
# 	if (dt$Region[i] == "Great Lakes" && dt$Seller.Market.Share[i] >= 0.025)
# 		dt$Dummy.Top.Regional.Seller[i] = 1
# 	else if ((dt$Region[i] == "Pacific Coast" | dt$Region[i] == "Other") && dt$Seller.Market.Share[i] >= 0.02)
# 		dt$Dummy.Top.Regional.Seller[i] = 1
# 	else if (dt$Region[i] == "North Atlantic" && dt$Seller.Market.Share[i] >= 0.015)
# 		dt$Dummy.Top.Regional.Seller[i] = 1
# 	else if (dt$Region[i] == "Florida" && dt$Seller.Market.Share[i] >= 0.012)
# 		dt$Dummy.Top.Regional.Seller[i] = 1
# 	else
# 		dt$Dummy.Top.Regional.Seller[i] = 0
# }

# feed dt back into df
df <- dt


#Export dataframe "df"
write.table(df, file = "boattrader prepped data.csv",append = FALSE, quote = TRUE, sep = ",", row.names = FALSE, col.names = TRUE)


