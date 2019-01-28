
/* IMPORTANT NOTE - Environment Setup
	 - Make sure you have imported beers_joined.csv as a new table in the database
	 - You can do this by first creating the Testing database, then right clicking on it and going to Tasks -> Import Flat File
*/

USE Testing;

IF OBJECT_ID(N'dbo.[beer_results_revoscaleR]', N'U') IS NOT NULL DROP TABLE [dbo].[beer_results_revoscaleR];
IF OBJECT_ID(N'dbo.[beer_dt_storeage]', N'U') IS NOT NULL DROP TABLE [dbo].[beer_dt_storage];

IF OBJECT_ID(N'dbo.[beer_results_revoscaleR]', N'U') IS NULL BEGIN CREATE TABLE [dbo].[beer_results_revoscaleR] (
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
	);
END

IF OBJECT_ID(N'dbo.[beer_dt_storage]', N'U') IS NULL BEGIN CREATE TABLE [dbo].beer_dt_storage (
	[ID]				INT				IDENTITY (1,1) NOT NULL,
	[InsertDate]		DATETIME        NOT NULL,
	[model_serialized]  VARBINARY(MAX)  NULL
	);
END

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

USE Testing;

DROP PROCEDURE IF EXISTS RevoscaleR_DT;
GO

CREATE PROCEDURE
	RevoscaleR_DT 
	@model_serialized varbinary(max) OUTPUT
AS

BEGIN

SET STATISTICS TIME ON

INSERT INTO Testing.dbo.beer_results_revoscaleR
	
EXEC sp_execute_external_script
	@language = N'R',
	@script = N'
library(RevoScaleR)
library(sampling)
library(caret)
library(e1071)

dfBeer <- InputData
dfBeer <- dfBeer[!(dfBeer$class_name == ""),]
dfBeer$class_name <- as.factor(dfBeer$class_name)  
dfBeer <- dfBeer[complete.cases(dfBeer),]
dfBeer <- dfBeer[dfBeer$class_name != "Other",]

set.seed(52)
st <- strata(dfBeer,stratanames = "class_name", rep(200,4), method = "srswr")
dfBeer.upsampled <- getdata(dfBeer, st)

dfTrain <- dfBeer.upsampled[sample(nrow(dfBeer.upsampled), as.integer(nrow(dfBeer.upsampled)*.75), replace = FALSE),]
dfTest <-  dfBeer.upsampled[!(dfBeer.upsampled$ID_unit %in% dfTrain$ID_unit),1:13] 

beerTree <- rxDTree(class_name ~ abv + ibu, data=dfTrain,
        minSplit = 50, minBucket = 20, maxDepth = 3)

OutputParam1 <- serialize(beerTree, NULL)
OutputData <- dfTest
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
	@output_data_1_name  = N'OutputData',
	@params = N'@OutputParam1 varbinary(max) OUTPUT',
	@OutputParam1 = @model_serialized OUTPUT

INSERT INTO Testing.dbo.beer_dt_storage Values (
	CURRENT_TIMESTAMP,	
	@model_serialized
)

SET STATISTICS TIME OFF

END;
GO

DECLARE 
	@model_serialized varbinary(max);

EXEC dbo.RevoscaleR_DT
	@model_serialized = @model_serialized OUTPUT;
GO