
/* IMPORTANT NOTE - Environment Setup
	 - Make sure you have imported beers_joined.csv as a new table in the database
	 - You can do this by first creating the Testing database, then right clicking on it and going to Tasks -> Import Flat File
*/

USE Testing;

IF OBJECT_ID(N'dbo.beer_results', N'U') IS NULL BEGIN CREATE TABLE [dbo].[beer_results] (
    [index]				INT             NOT NULL,
    [abv]				FLOAT			NULL,
    [ibu]				FLOAT			NULL,
    [id]				INT				NULL,
    [name]				VARCHAR (100)	NULL,
    [style]				VARCHAR (100)	NULL,
	[brewery_id]		INT				NULL,
	[ounces]			FLOAT			NULL,
	[beer_group]		INT				NULL,
	[group_name]		VARCHAR (100)   NULL,
	[group_abbrev]		VARCHAR (100)	NULL,
	[super_class_id]	INT				NULL,
	[class_name]		VARCHAR (100)	NULL,
	[predV]				VARCHAR (100)   NULL
	);
END

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET STATISTICS time on

USE Testing;
INSERT INTO Testing.dbo.beer_results

EXEC sp_execute_external_script
	@language = N'R',
	@script = N'
library(sampling)
library(caret)
library(e1071)

dfBeer <- InputData
dfBeer <- dfBeer[!(dfBeer$class_name == ""),]
dfBeer$class_name <- as.factor(dfBeer$class_name)          
          
dfBeer <- dfBeer[complete.cases(dfBeer),]
dfBeer <- dfBeer[dfBeer$class_name != "Other",]

dfBeer <- dfBeer[order(dfBeer$class_name),]

set.seed(52)
st <- strata(dfBeer,stratanames = "class_name", rep(200,4), method = "srswr")
dfBeer.upsampled <- getdata(dfBeer, st)

dfTrain <- dfBeer.upsampled[sample(nrow(dfBeer.upsampled), as.integer(nrow(dfBeer.upsampled)*.75), replace = FALSE),]
dfTest <-  dfBeer.upsampled[!(dfBeer.upsampled$ID_unit %in% dfTrain$ID_unit),1:13] 

dfBeer.tree.up <- rpart(class_name ~ abv + ibu, dfTrain, method = "class", minsplit = 50, minbucket = 20, parms = list(split = "information"))

#pred <- predict(dfBeer.tree.up, type = "prob", newdata = dfTest)
predV <- predict(dfBeer.tree.up, type = "class", newdata = dfTest)

OutputData <- cbind(dfTest, predV)

',

	@input_data_1 = N'
		Select
			   [index]
			  ,[abv]
			  ,[ibu]
			  ,[id]
			  ,cast([name] as nvarchar(100)) as [name]
			  ,cast([style] as nvarchar(100)) as [style]
			  ,[brewery_id]
			  ,[ounces]
			  ,[beer_group]
			  ,[group_name]
			  ,[group_abbrev]
			  ,[super_class_id]
			  ,[class_name]

		From
			Testing.dbo.beers_joined

	',
	@input_data_1_name = N'InputData',
	@output_data_1_name  = N'OutputData'

SET STATISTICS time off;