USE [master]
GO

IF OBJECT_ID('DatabasesToRestore') IS NOT NULL
	DROP TABLE dbo.DatabasesToRestore

CREATE TABLE [dbo].DatabasesToRestore(
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [sysname] NOT NULL,
	[AvailabilityGroup] nvarchar(100) NULL,
	IsActive bit NOT NULL DEFAULT(1)
	CONSTRAINT [PK_DatabasesToRestore] PRIMARY KEY CLUSTERED ([Id] ASC)
) ON [PRIMARY]
GO

IF OBJECT_ID('DatabaseRestoreLog') IS NOT NULL
	DROP TABLE dbo.DatabaseRestoreLog

CREATE TABLE dbo.DatabaseRestoreLog
(
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[DatabaseId] [int] NOT NULL,
	[RestoredName] [sysname] NULL,
	[RestoredDate] [date] NOT NULL,
	[RestoreStartTime] datetime NULL,
	[RestoreEndTime] datetime NULL,
	[DBCCStartTime] datetime NULL,
	[DBCCEndTime] datetime NULL,
	[PassedDBCCChecks] [bit] NOT NULL DEFAULT (0)
	CONSTRAINT [PK_DatabaseRestoreLog] PRIMARY KEY CLUSTERED ([ID] ASC),
	CONSTRAINT [FK_DatabaseRestoreLog_DatabasesToRestore] FOREIGN KEY ([DatabaseId]) REFERENCES dbo.DatabasesToRestore ([Id])
);

IF OBJECT_ID('DBCC_History_Log') IS NOT NULL
	DROP TABLE dbo.DBCC_History_Log

CREATE TABLE dbo.DBCC_History_Log
(
	[ID] [int] IDENTITY(1,1) NOT NULL CONSTRAINT PK_DBCC_History_Log PRIMARY KEY,
	[DatabaseName] [sysname] NULL,
	[DBCCCheckDate] [date] NOT NULL,
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
	[Allocation] [int] NULL,
	[TimeStamp] [datetime] NULL CONSTRAINT [DF_dbcc_history_TimeStamp] DEFAULT (GETDATE())
);