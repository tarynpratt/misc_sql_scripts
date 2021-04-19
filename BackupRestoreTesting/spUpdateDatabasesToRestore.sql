CREATE OR ALTER Procedure [dbo].[spUpdateDatabasesToRestore] 
AS
BEGIN
  DECLARE @fileSearch nvarchar(500) = '',
        @backupPath NVARCHAR(500) = '',
        @error nvarchar(600);

  DECLARE @ag_name nvarchar(100)

  DECLARE ag_cursor CURSOR FOR
    SELECT DISTINCT AvailabilityGroup
    FROM dbo.DatabasesToRestore
  OPEN ag_cursor
  FETCH NEXT FROM ag_cursor INTO @ag_name
  WHILE @@FETCH_STATUS = 0
  BEGIN

    PRINT 'Getting databases for AG: '+ @ag_name

	-- go through the list of availability groups and their backup path
	-- update the list of databases to restore 
	-- adding new ones and deleting old ones that are no longer active databases

	SET @backupPath = concat('\\fileserver\Backups\SQL\', @ag_name, '\')
	SET @fileSearch = 'DIR /S /b/a-d/od/t:c ' + @backupPath;

	DECLARE @files table (ID int IDENTITY, FileName varchar(max), DBName sysname null, FileDate date null)

	INSERT INTO @files (FileName)
	EXEC master.sys.xp_cmdshell @fileSearch

	UPDATE @files 
	SET DBName = Left(replace(FileName, @backupPath, ''), charindex('\', replace(FileName, @backupPath, ''))-1),
	  FileDate = 
                cast(substring(right(replace(FileName, @backuppath, ''), len(replace(FileName, @backuppath, ''))
                -charindex('\', replace(FileName, @backuppath, ''))), 
                charindex('_FULL_', right(replace(FileName, @backuppath, ''), 
                len(replace(FileName, @backuppath, ''))-charindex('\', replace(FileName, @backuppath, '')))) + 6, 8) as date)
	WHERE FileName like '%.bak%'

	PRINT 'inserting new databases for AG: '+ @ag_name

	-- Insert new databases into the Databases table 
	INSERT INTO DatabasesToRestore (Name, AvailabilityGroup)
	SELECT DBName, AGName = @ag_name
	FROM
	(
		SELECT DBName, 
			rn = row_number() over(partition by DBName order by FileDate desc)
		FROM @files
		WHERE FileDate >= GETDATE()-7
			AND FileName LIKE '%'+@ag_name+'%'
	) f
	WHERE rn = 1
		AND NOT EXISTS (SELECT 1
				FROM dbo.DatabasesToRestore d
				WHERE f.DBName = d.Name
				AND d.AvailabilityGroup = @ag_name
    				AND d.IsActive = 1)

	PRINT 'Removing any old databases for AG: '+ @ag_name

	-- mark any Databases that are no longer producing backups as IsActive = 0
	UPDATE d
	SET d.IsActive = 0
	FROM dbo.DatabasesToRestore d
	LEFT JOIN 
	(
		SELECT DISTINCT DBName, AGName = @ag_name
		FROM @files 
		WHERE FileDate >= GETDATE()-7
			AND DBName IS NOT NULL
			AND FileName LIKE '%'+@ag_name+'%'
	) f
	    ON d.Name = f.DBName
	    AND d.AvailabilityGroup = f.AGName
	WHERE d.IsActive = 1
		AND d.AvailabilityGroup = @ag_name
		AND f.DBName IS NULL

	FETCH NEXT FROM ag_cursor INTO @ag_name
  END
  CLOSE ag_cursor  
  DEALLOCATE ag_cursor 
END