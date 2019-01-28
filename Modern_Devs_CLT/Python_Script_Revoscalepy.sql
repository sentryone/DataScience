
/* IMPORTANT NOTE - Environment Setup
	 - Make sure you have imported beers_joined.csv as a new table in the database
	 - You can do this by first creating the Testing database, then right clicking on it and going to Tasks -> Import Flat File
*/

USE Testing;

-- Creating two tables that will store the test data (beer_test_revoscalepy) and the serialized model (beer_dt_storage) for later use by PREDICT

IF OBJECT_ID(N'dbo.[beer_dt_storage]', N'U') IS NOT NULL DROP TABLE [dbo].[beer_dt_storage];
IF OBJECT_ID(N'dbo.[beer_test_revoscalepy]', N'U') IS NOT NULL DROP TABLE [dbo].[beer_test_revoscalepy];

IF OBJECT_ID(N'dbo.[beer_dt_storage]', N'U') IS NULL BEGIN CREATE TABLE [dbo].beer_dt_storage (
	[ID]				INT				IDENTITY (1,1) NOT NULL,
	[InsertDate]		DATETIME        NOT NULL,
	[model_serialized]  VARBINARY(MAX)  NULL
	);
END

IF OBJECT_ID(N'dbo.beer_test_revoscalepy', N'U') IS NULL BEGIN CREATE TABLE [dbo].[beer_test_revoscalepy] (
    [abv]				FLOAT			NULL,
    [ibu]				FLOAT			NULL,
	[class_name]		VARCHAR (100)	NULL
	);
END

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

USE Testing;

DROP PROCEDURE IF EXISTS Revoscalepy_DT;
GO

-- Creating the stored procedure that will run the Python script

CREATE PROCEDURE
	Revoscalepy_DT 
	@model_serialized varbinary(max) OUTPUT
AS

BEGIN

SET STATISTICS TIME ON

-- Inserting the results of the Python script into beer_results_revoscalepy

INSERT INTO Testing.dbo.beer_test_revoscalepy
	
EXEC sp_execute_external_script
	@language = N'Python',
	@script = N'
import pandas as pd
import numpy as np
import sys
import time
import os
from collections import Counter 
from sklearn.model_selection import train_test_split 
from sklearn.metrics import accuracy_score
from imblearn.over_sampling import RandomOverSampler
from sklearn.tree import export_graphviz
from revoscalepy import rx_dtree, rx_import, RxOptions, RxXdfData, rx_predict_rx_dtree, rx_serialize_model

try:
	data = InputData
	data["name"] = data["name"].str.replace(u"\u2019","")
	data["style"] = data["style"].str.replace(u"\u2019","")
	data = data.dropna()
except Error:
	print("Error importing data")
finally:
	print("Successfully imported data")

data = data[data["class_name"] != "Other"]

data = data[["abv", "ibu", "class_name"]]

data["class_name"] = data.class_name.astype("category")

data_train, data_test = train_test_split(data, test_size = .25, random_state = 100)

tree = rx_dtree("class_name ~ abv + ibu", data = data_train, max_depth = 3, min_bucket = 20, min_split = 50)

pred = rx_predict_rx_dtree(tree, data_test, extra_vars_to_write = ["class_name"])

OutputParam1 = rx_serialize_model(tree, realtime_scoring_only = True)

OutputData = data_test

		',

-- input_data_1 is the input query from the beers_joined table
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

		Where
			class_name is not null
	',
	@input_data_1_name = N'InputData',
	@output_data_1_name  = N'OutputData',
	@params = N'@OutputParam1 varbinary(max) OUTPUT',
	@OutputParam1 = @model_serialized OUTPUT

-- after running the insert into beer_results_revoscalepy, this will insert the serialized model along with the current_timestamp into beer_dt_storage
INSERT INTO Testing.dbo.beer_dt_storage Values (
	CURRENT_TIMESTAMP,	
	@model_serialized
)

SET STATISTICS TIME OFF

END;
GO

-- declaring the model_serialized parameter for use by the Revoscalepy_DT proc 

DECLARE 
	@model_serialized varbinary(max);

EXEC dbo.Revoscalepy_DT
	@model_serialized = @model_serialized OUTPUT;
GO

/*
	Checking contents of the new tables
*/

Select * From Testing.dbo.beer_dt_storage

Select * From Testing.dbo.beer_test_revoscalepy


/*
	Using PREDICT() to generate Predicted_Class
*/

DECLARE @decision_tree varbinary(max);

SET @decision_tree = (SELECT TOP 1 [model_serialized] from [Testing].[dbo].[beer_dt_storage] ORDER BY [ID] DESC);

SELECT 
	b.*,
	p.*,
	(SELECT Max(v) From (VALUES (Ale_Pred), (IPA_Pred), (Lager_Pred), (SP_Pred)) as value(v)) as MaxPred,
	CASE
		WHEN Ale_Pred   = (SELECT Max(v) From (VALUES (Ale_Pred), (IPA_Pred), (Lager_Pred), (SP_Pred)) as value(v)) THEN 'Ale'
		WHEN IPA_Pred   = (SELECT Max(v) From (VALUES (Ale_Pred), (IPA_Pred), (Lager_Pred), (SP_Pred)) as value(v)) THEN 'IPA'
		WHEN Lager_Pred = (SELECT Max(v) From (VALUES (Ale_Pred), (IPA_Pred), (Lager_Pred), (SP_Pred)) as value(v)) THEN 'Lager'
		WHEN SP_Pred    = (SELECT Max(v) From (VALUES (Ale_Pred), (IPA_Pred), (Lager_Pred), (SP_Pred)) as value(v)) THEN 'SP'
		ELSE 'Other'
	END as 'Predicted_Class'

FROM PREDICT(MODEL = @decision_tree,
			DATA = [Testing].[dbo].[beer_test_revoscalepy] as b)
			WITH (Ale_Pred float, IPA_Pred float, Lager_Pred float, SP_Pred float) as p

Where
	ibu is not null