
/* IMPORTANT NOTE - Environment Setup
	 - Make sure you have imported beers_joined.csv as a new table in the database
	 - You can do this by first creating the Testing database, then right clicking on it and going to Tasks -> Import Flat File
*/

USE Testing;

IF OBJECT_ID(N'dbo.beer_results_py', N'U') IS NOT NULL DROP TABLE [dbo].[beer_results_py];

IF OBJECT_ID(N'dbo.beer_results_py', N'U') IS NULL BEGIN CREATE TABLE [dbo].[beer_results_py] (
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
	[predicted_class]   VARCHAR (100)   NULL
	);
END

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
SET STATISTICS TIME ON

USE Testing;
INSERT INTO Testing.dbo.beer_results_py

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
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn import tree
from imblearn.over_sampling import RandomOverSampler

start_time = time.time()

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

target = data["class_name"]
features = data[["abv", "ibu"]]

print("Original distribution {}".format(Counter(target)))

ros = RandomOverSampler(random_state = 100, ratio = "auto")

X_resampled, y_resampled = ros.fit_sample(features, target)

print("Resampled distribution {}".format(Counter(y_resampled)))

res_features = pd.DataFrame(data = X_resampled, index = X_resampled[0:,0], columns = ["abv", "ibu"])
res_target = pd.DataFrame(data = y_resampled, index = y_resampled[0:], columns = ["class_name"])

res_features_train, res_features_test, res_target_train, res_target_test = train_test_split(res_features, res_target, test_size = .25, random_state = 100)

tree_entropy = DecisionTreeClassifier(criterion = "entropy", random_state = 100, max_depth = 3, min_samples_leaf = 20, min_samples_split = 50)

tree_entropy.fit(res_features_train, res_target_train)

target_prediction_entropy = tree_entropy.predict(res_features_test)

print("Entropy accuracy: ", round(accuracy_score(res_target_test, target_prediction_entropy) * 100, 2))

print("Total Processing time: %s seconds" % (round(time.time() - start_time,5)))

data["Predicted_Class"] = tree_entropy.predict(features)

OutputData = data
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

		Where
			class_name is not null
	',
	@input_data_1_name = N'InputData',
	@output_data_1_name  = N'OutputData'
	
SET STATISTICS TIME OFF;