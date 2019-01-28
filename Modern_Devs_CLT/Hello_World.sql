
/*
	R
*/

EXEC sp_execute_external_script  @language =N'R',
@script=N'
OutputDataSet <- InputDataSet
print(R.version)
',
@input_data_1 =N'SELECT 1 AS hello'
WITH RESULT SETS (([hello] int not null));
GO

/*
	Python
*/

EXEC sp_execute_external_script  @language =N'Python',
@script=N'
OutputDataSet = InputDataSet;
',
@input_data_1 =N'SELECT 1 AS hello'
WITH RESULT SETS (([hello] int not null));
GO