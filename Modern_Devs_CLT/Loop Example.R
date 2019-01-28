# checks whether RODBC and zoo packages can be attached.  If not, install them from CRAN, then attach.

if (require("RODBC") == FALSE) {
  install.packages("RODBC")
  library(RODBC)
}

if (require("zoo") == FALSE) {
  install.packages("zoo")
  library(zoo)
}

if (require("reshape2") == FALSE) {
  install.packages("reshape2")
  library(reshape2)
}

if (require("ggplot2") == FALSE) {
  install.packages("ggplot2")
  library(ggplot2)
}

library(tidyr)

#### Retrieve data from WorldWideImportsDW Microsoft sample database.
#### Downloaded from https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0

#### Using RODBC, open a channel with a previously created ODBC connection in Windows. Mine is called "WWImportsDW"
ch <- odbcConnect("WWImportsDW")
dfSource <- sqlQuery(ch, paste0("select fo.[Order Key]
                                , fo.[Order Date Key]
                                , fo.[Total Excluding Tax]
                                , de.[WWI Employee ID]
                                
                                FROM [Fact].[Order] fo 
                                LEFT JOIN Dimension.Employee de on fo.[Salesperson Key] = de.[Employee Key] "))

odbcClose(ch)
rm(ch)
#### Clean up after ourselves, closing and removing the channel

#### Rename the column names to remove spaces
names(dfSource) <- gsub(" ", "", names(dfSource))

#### Remove and recreate the aggregated dataset, which is grouped and summed by order date
if(exists("dfDateAggregate")){rm(dfDateAggregate)}

dfDateAggregate <- aggregate(TotalExcludingTax ~ OrderDateKey + WWIEmployeeID, dfSource, FUN = sum)  # aggregates sales by date



# Vectorized rolling mean
system.time(dfDateAggregate$rollingVectorized <- rollapply(dfDateAggregate$TotalExcludingTax, 
                                                           FUN = mean,
                                                           width = 30,
                                                           by = 1,
                                                           fill = 0,
                                                           partial = TRUE,
                                                           align = "left"))

# Looping rolling mean
result <- NULL
system.time(
  for (row in 1:nrow(dfDateAggregate)) {
    value = mean(dfDateAggregate$TotalExcludingTax[row:(row+29)])
    result <- c(result,value)
  })

dfDateAggregate$loopingMean <- result[1:10562]
result <- NULL

#### quick plots of each 
plot(dfDateAggregate$TotalExcludingTax)
plot(dfDateAggregate$loopingMean)

