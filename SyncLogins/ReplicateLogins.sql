-- this script can be used to copy logins from a primary
-- to a secondary replica, it also deletes unused logins from the secondary

DECLARE @name sysname,
    @PWD_varbinary varbinary (256),
    @PWD_string varchar (514),
    @SID_varbinary varbinary (85),
    @SID_string varchar (514),
    @sqlString varchar (1024),
    @is_policy_checked varchar (3),
    @is_expiration_checked varchar (3),
    @defaultdb sysname;

DECLARE @logins TABLE 
(
    SID varbinary(256), 
    Login sysname, 
    SQL varchar (1024), 
    DefaultDB sysname
);

DECLARE login_cursor CURSOR FOR
    SELECT *
    FROM OPENQUERY([SQL-AG], '
        SELECT p.sid, p.name, p.default_database_name,
            sl.password_hash pwd_varbinary,
            CASE sl.is_policy_checked WHEN 1 THEN ''ON'' WHEN 0 THEN ''OFF'' ELSE NULL END is_policy_checked,
            CASE sl.is_expiration_checked WHEN 1 THEN ''ON'' WHEN 0 THEN ''OFF'' ELSE NULL END is_expiration_checked
        FROM sys.server_principals p
            JOIN sys.syslogins l ON l.name = p.name
            JOIN sys.sql_logins sl ON l.name = sl.name
        WHERE p.type = ''S''
        AND p.name <> ''sa''
        AND l.denylogin = 0
        AND l.hasaccess = 1
        AND p.is_disabled = 0
        ORDER BY p.name')
OPEN login_cursor

FETCH NEXT FROM login_cursor 
    INTO @SID_varbinary, @name, @defaultdb, @PWD_varbinary, @is_policy_checked, @is_expiration_checked
WHILE @@fetch_status = 0
BEGIN
    EXEC sp_hexadecimal @PWD_varbinary, @PWD_string OUT
    EXEC sp_hexadecimal @SID_varbinary, @SID_string OUT

    SET @sqlString = 'CREATE LOGIN ' + QUOTENAME(@name) + ' WITH PASSWORD = ' + @PWD_string 
                        + ' HASHED, SID = ' + @SID_string + ', DEFAULT_DATABASE = [' + @defaultdb + ']'
                        + ', CHECK_POLICY = ' + @is_policy_checked
                        + ', CHECK_EXPIRATION = ' + @is_expiration_checked

    INSERT INTO @logins (SID, Login, SQL, DefaultDB) 
    VALUES (@SID_varbinary, @name, @sqlString, @defaultdb);

    FETCH NEXT FROM login_cursor 
        INTO @SID_varbinary, @name, @defaultdb, @PWD_varbinary, @is_policy_checked, @is_expiration_checked
END
CLOSE login_cursor
DEALLOCATE login_cursor

DECLARE @sql varchar (1024), @db sysname, @loginname sysname;
DECLARE login_cursor CURSOR FOR
    SELECT SQL, DefaultDB, Login
    FROM @logins
    WHERE SID NOT IN (SELECT sid 
                        FROM sys.server_principals)
        AND EXISTS (SELECT 1 
                    FROM sys.databases 
                    WHERE name = DefaultDB)
        AND Login NOT IN (SELECT name 
                            FROM sys.server_principals 
                            WHERE name = Login 
                                And type = 'S')
OPEN login_cursor

-- add new logins
FETCH NEXT FROM login_cursor INTO @sql, @db, @loginname
WHILE @@fetch_status = 0
BEGIN
    EXEC(@sql);
    --print @sql
    FETCH NEXT FROM login_cursor 
        INTO @sql, @db, @loginname
END
CLOSE login_cursor
DEALLOCATE login_cursor

-- drop logins that are no longer being used
DECLARE @drop_sqlString nvarchar(max) = '';
DECLARE drop_login_cursor CURSOR FOR
    -- logins on current server that don't exist on the primary
    SELECT p.sid, p.name, p.default_database_name
    FROM sys.server_principals p
    JOIN sys.syslogins l ON l.name = p.name
    JOIN sys.sql_logins sl ON l.name = sl.name
    WHERE p.type = 'S'
       AND p.name <> 'sa'
       AND l.denylogin = 0
       AND l.hasaccess = 1
       AND p.is_disabled = 0
       AND NOT EXISTS (SELECT 1
                        FROM @logins cl
                        WHERE p.sid = cl.sid
                          AND p.name = cl.Login
                          AND p.default_database_name = cl.DefaultDB)
	ORDER BY p.name
OPEN drop_login_cursor
FETCH NEXT FROM drop_login_cursor INTO @SID_varbinary, @name, @defaultdb
WHILE @@fetch_status = 0
BEGIN

    SET @drop_sqlString = 'DROP LOGIN ' + QUOTENAME(@name) + '; '
	--print @drop_sqlString
	EXEC(@drop_sqlString);
	
    FETCH NEXT FROM drop_login_cursor INTO @SID_varbinary, @name, @defaultdb
END
CLOSE drop_login_cursor
DEALLOCATE drop_login_cursor