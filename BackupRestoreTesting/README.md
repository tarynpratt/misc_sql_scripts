Backup and Restore Testing
=================================

These scripts can be used to restore backups and then run `DBCC CheckDB` against them. There are a few tables that are used in the process which are stored in the master database, and then a couple of different steps which are outlined below.

### Tables
There are three tables that are used in the entire process:

1. `dbo.DatabasesToRestore` - this contains the list of databases that we want to test the backups on. The table has the name of the database, the Availability Group it is in, and then a column called IsActive which is used to remove databases from the nightly restore process.

2. `dbo.DatabaseRestoreLog` - this is a log table that gets populated as the nightly process is running. It captures the databases, the restored name of the database, the start and end time of the restore process, the start and end time of the DBCC CheckDB process, and then a bit column showing if the database passed the CheckDB test

3. `dbo.DBCC_History_Log` - this tables captures the output of the DBCC CheckDB. This is needed so we can see why a database failed any of the checks.

### Stored Procedures

There are three stored procedures for the restore process:

1. `dbo.spUpdateDatabasesToRestore` - this stored procedure is used to add or remove any databases from the nightly process. It queries the dbo.DatabasesToRestore for a list of the Availability Groups. It then loops through each AG and goes to the directory on \\fileshare\Backups\SQL to get a list of database backups. If it finds a database name that doesn't exist in `dbo.DatabasesToRestore`, then it adds it. If it finds no backup for a database in the previous 7 days for a database in `dbo.DatabasesToRestore`, then it will mark it as `IsActive=0` and it will be dropped from the nightly process.

2. `dbo.spBackupRestoreTesting` - this is the main stored procedure for the nightly restore process. It loops through the list of databases in `dbo.DatabasesToRestore` and `dbo.DatabaseRestoreLog` and looks for the oldest databases that haven't been restored recently. For each of these databases, it grabs the latest backup and restores it to the server. Once restored it calls the final stored procedure `dbo.spRunDBCCChecks` to test for any corruption or issues. This procedure runs based on a `@TimeLimit,` meaning that the process will run for the amount of time in seconds that we allot to it. The default is to run for 12 hours and it will continue to restore and test backups for the entire timeframe, unless it completes all databases, then it will exit until the next scheduled time.

3. `dbo.spRunDBCCChecks` - this procedure accepts the name of the database to check, runs the `DBCC CheckDB`, and inserts the results into the `dbo.DBCC_History_Log`. If any errors are generated during the `CheckDB`, then the newly restored database is not dropped and we are notified there are issues. If there are no errors, then the database is dropped from the server and the process moves to the next one.

To set this up, you can use two SQL Agent jobs running - one to update the list of the `DatabasesToRestore` via `spUpdateDatabasesToRestore` and one that executes the Backup and Restore Testing procedure (`spBackupRestoreTesting`). 