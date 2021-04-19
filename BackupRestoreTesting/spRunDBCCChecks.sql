CREATE OR ALTER Procedure dbo.spRunDBCCChecks
    @dbName sysname,
    @exec BIT = 0 
AS
BEGIN
	DECLARE @dropCmd nvarchar(500),
			@error nvarchar(600),
			@MailMsg nvarchar(500);

	-- DBCC CheckDB will output results that we want to capture to verify if there are errors
	IF OBJECT_ID('tempdb..#tempdbcccheck') IS NOT NULL
		DROP TABLE #tempdbcccheck

	CREATE TABLE #tempdbcccheck
	(
		[Error] [int] NULL,
		[Level] [int] NULL,
		[State] [int] NULL,
		[MessageText] [varchar](7000) NULL,
		[RepairLevel] nvarchar(500) NULL,
		[Status] [int] NULL,
		[DbId] [int] NULL,
		[DbFragId] [int] NULL,
		[ObjectId] [int] NULL,
		[IndexId] [int] NULL,
		[PartitionID] [bigint] NULL,
		[AllocUnitID] [bigint] NULL,
		[RidDbId] [int] NULL,
		[RidPruId] [int] NULL,
		[File] [int] NULL,
		[Page] [int] NULL,
		[Slot] [int] NULL,
		[RefDbId] [int] NULL,
		[RefPruId] [int] NULL,
		[RefFile] [int] NULL,
		[RefPage] [int] NULL,
		[RefSlot] [int] NULL,
		[Allocation] [int] NULL
	);

	PRINT 'Starting DBCC CHECKDB on ' + @dbName

	INSERT INTO #tempdbcccheck
	EXEC ('DBCC CHECKDB(''' + @dbName + ''') with tableresults');

	-- insert the results in the history log table
	INSERT INTO [dbo].[DBCC_History_Log] (DatabaseName, DBCCCheckDate, Error, [Level], [State], MessageText, RepairLevel, [Status], DbId, DbFragId, 
		ObjectId, IndexId, PartitionID, AllocUnitID, RidDbId, RidPruId, [File], Page, Slot, RefDbId, RefPruId, RefFile, RefPage, RefSlot, Allocation)
	SELECT @dbName, GETDATE(), t.*
	FROM #tempdbcccheck t

	-- if the there were no errors in the database check, then we can safely drop the DB
	IF NOT EXISTS (SELECT 1 
					FROM dbo.DBCC_History_Log
					WHERE DatabaseName = @dbName
						AND DBCCCheckDate = cast(getdate() as date)
						AND [Level] > 10 )
		BEGIN
			UPDATE [dbo].[DatabaseRestoreLog]
			SET [PassedDBCCChecks] = 1
			WHERE [RestoredName] = @dbName
				AND [RestoredDate] = cast(getdate() as date)

			PRINT 'Clean DBCCCheck - dropping database [' + @dbName +']';
			SET @dropCmd = 'Alter Database [' + @dbName + '] Set Single_User With Rollback Immediate; Drop Database [' + @dbName + '];';
			PRINT(@dropCmd);

			IF @exec = 1 
			BEGIN
				EXEC(@dropCmd);
			END
		END
	ELSE
		BEGIN
			SET @error = 'DBCC CHECKDB generated errors for database ''' + @dbName + ''' not dropping for further review.' ;
			-- send an email alert to sql-alerts that the DBCC CHECKDB failed for the restored item
			EXEC msdb.dbo.sp_send_dbmail @profile_name = 'Mail', @recipients = 'useyourown@email.com', @subject = @error, @body = @error;
			RAISERROR(@error, 18, 1);
		END

END