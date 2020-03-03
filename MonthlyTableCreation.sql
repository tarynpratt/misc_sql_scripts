-- originally written by Nick Craver
Declare @month datetime = '2019-06-01';
Declare @endmonth datetime = '2021-01-01'

WHILE @month < @endmonth
BEGIN

	Set NoCount On;
	Declare @prevMonth datetime = DateAdd(Month, -1, @month);
	Declare @nextMonth datetime = DateAdd(Month, 1, @month);
	Declare @monthTable sysname = 'Logs_' + Cast(DatePart(Year, @month) as varchar) + '_' + Right('0' + Cast(DatePart(Month, @month) as varchar), 2);

	Begin Try
		If Object_Id(@monthTable, 'U') Is Not Null
		Begin
			Declare @error nvarchar(400) = 'Month ' + Convert(varchar(10), @month, 120) + ' has already been moved to ' + @monthTable + ', aborting.';
			Throw 501337, @error, 1;
			Return;
		End

		-- Table Creation
		Declare @tableTemplate nvarchar(4000) = '
			Create Table {Name} (
			[CreationDate] datetime Not Null,
			<insert all the columns>,
			Constraint CK_{Name}_Low Check (CreationDate >= ''{LowerDate}''),
			Constraint CK_{Name}_High Check (CreationDate < ''{UpperDate}'')
		) On {Filegroup};
        
		Create Clustered Columnstore Index CCI_{Name} On {Name} With (Data_Compression = {Compression}) On {Filegroup};';
	
		-- Constraints exist for metadata swap
		Declare @table nvarchar(4000) = @tableTemplate;
		Set @table = Replace(@table, '{Name}', @monthTable);
		Set @table = Replace(@table, '{Filegroup}', 'Logs_Archive');
		Set @table = Replace(@table, '{LowerDate}', Convert(varchar(20), @month, 120));
		Set @table = Replace(@table, '{UpperDate}', Convert(varchar(20), @nextMonth, 120));
		Set @table = Replace(@table, '{Compression}', 'ColumnStore_Archive');
		Print @table;
	    Exec sp_executesql @table;
	  
   
		Declare @moveSql nvarchar(4000) = 'Create Clustered Columnstore Index CCI_{Name} On {Name} With (Drop_Existing = On, Data_Compression = Columnstore_Archive) On Logs_Archive;';
		Set @moveSql = Replace(@moveSql, '{Name}', @monthTable);
		Print @moveSql;
		Exec sp_executesql @moveSql;

	End Try
	Begin Catch
		Select Error_Number() ErrorNumber,
			   Error_Severity() ErrorSeverity,
			   Error_State() ErrorState,
			   Error_Procedure() ErrorProcedure,
			   Error_Line() ErrorLine,
			   Error_Message() ErrorMessage;
		Throw;
	End Catch

	set @month = dateadd(month, 1, @month)

END
GO