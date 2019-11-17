# set working directory
setwd("ism6137")

# load the boattrader output .csv file
df <- read.csv("boattrader prepped data.csv", header=T, na.strings=c("","NA"))

# attach df
attach(df)

mod1 <- lm(log(Listed.Price) ~ log(Length), data=df)
summary(mod1)

mod2 <- lm(log(Listed.Price) ~ Boat.Age, data=df)
summary(mod2)

df_hp = df[which(!is.na(df$Engine.Power == 1)),]
mod3 <- lm(log(Listed.Price) ~ Engine.Power)


mod4 <- lm(log(Listed.Price) ~ log(Length) + Engine.Power, data=df_hp)
summary(mod4)

mod5 <- lm(log(Listed.Price) ~ log(Length) + Engine.Power + log(Length)*Engine.Power, data=df_hp)
summary(mod5)


mod6 <- lm(log(Listed.Price) ~ Dummy.Top.Seller, data=df)
summary(mod6)

mod7 <- lm(log(Listed.Price) ~ Dummy.Big.Brand, data=df)
summary(mod7)

mod8 <- lm(log(Listed.Price) ~ log(Length) + Engine.Power + log(Length)*Engine.Power + Dummy.Big.Brand, data=df_hp)
summary(mod8)

mod9 <- lm(log(Listed.Price) ~ Dummy.Region.Pacific + Dummy.Region.GreatLakes + Dummy.Region.NorthEast + Dummy.Region.SouthEast, data=df)
summary(mod9)

mod10 <- lm(log(Listed.Price) ~ log(Length) + Engine.Power + log(Length)*Engine.Power + Dummy.Region.Pacific + Dummy.Region.GreatLakes + Dummy.Region.NorthEast + Dummy.Region.SouthEast, data=df_hp)
summary(mod10)



install.packages("lattice")
install.packages("zipcode")
install.packages("fields")
install.packages("spdep")
install.packages("spatialreg")
library(lattice)
library(fields)
library(zipcode)
library(spdep)
library(spatialreg)
data(zipcode)
nrow(zipcode)
head(zipcode)

df <- merge(df, zipcode,by.x="Zip.Code", by.y="zip")

# two plots for spatial analysis
plot(df$longitude,df$latitude,type="p",pch=9,cex = 1,xlab="Longitude",ylab="Latitude")
quilt.plot(df$longitude,df$latitude,df$Listed.Price)
# Here we take sample of our data, first 1000 rows
set.seed(6137)
random <- sample(nrow(df))
df <- df[random,]
sample<-df[sample(1:nrow(df),1000,replace = FALSE),]
coords <- cbind(sample$longitude,sample$latitude)
knn <- knearneigh(coords, k=5)
# model for spatial analysis, in this case price by boat length
mod11 <- lagsarlm(log(sample$Listed.Price) ~ log(sample$Length),listw =  nb2listw(knn2nb(knn)))
summary(mod11)