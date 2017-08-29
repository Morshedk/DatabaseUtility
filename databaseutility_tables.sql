USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Exception](
	[ExceptionID] [int] IDENTITY(1,1) NOT NULL,
	[ErrorMessage] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ErrorID] [int] NULL,
	[ProcedureName] [varchar](1000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[LineNumber] [int] NULL,
	[ExtraInfo] [xml] NULL,
	[ExceptionDateTime] [datetime] NULL,
	[SystemUser] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[AppName] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[SchemaName] [varchar](500) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IsErrorRaised] [int] NULL,
	[ContextInfo] [varbinary](1000) NULL,
	[XactState] [int] NULL,
 CONSTRAINT [PK_Exception_ExceptionID] PRIMARY KEY CLUSTERED 
(
	[ExceptionID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [IX_Exception_Date] ON [dbo].[Exception]
(
	[ExceptionDateTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
ALTER TABLE [dbo].[Exception] ADD  CONSTRAINT [DF_Date]  DEFAULT (getdate()) FOR [ExceptionDateTime]
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [ED209].[SpidHallPass](
	[Spid] [int] NOT NULL,
	[Expires] [datetime2](7) NOT NULL,
	[InsertedBy] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
 CONSTRAINT [PK_SpidHallPass] PRIMARY KEY CLUSTERED 
(
	[Spid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [ED209].[SpidHallPass] ADD  CONSTRAINT [DF_USER]  DEFAULT (suser_sname()) FOR [InsertedBy]
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [scheduler].[Task](
	[TaskId] [int] IDENTITY(1,1) NOT NULL,
	[Identifier] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[TSQLCommand] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[StartTime] [time](7) NOT NULL,
	[FrequencyType] [tinyint] NOT NULL,
	[FrequencyTypeDesc]  AS (case [FrequencyType] when (1) then 'Day' when (2) then 'Hour' when (3) then 'Minute' when (4) then 'Second'  end),
	[FrequencyInterval] [smallint] NOT NULL,
	[NotifyOnFailureOperator] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[IsNotifyOnFailure] [bit] NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[AvailabilityGroup]  AS (CONVERT([nvarchar](128),NULL)),
	[IsDeleted] [bit] NULL,
	[SysStartTime] [datetime2](7) GENERATED ALWAYS AS ROW START NOT NULL,
	[SysEndTime] [datetime2](7) GENERATED ALWAYS AS ROW END NOT NULL,
 CONSTRAINT [PK_Task] PRIMARY KEY CLUSTERED 
(
	[TaskId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION = PAGE) ON [PRIMARY],
 CONSTRAINT [UQ_Task_Name] UNIQUE NONCLUSTERED 
(
	[Identifier] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION = PAGE) ON [PRIMARY],
	PERIOD FOR SYSTEM_TIME ([SysStartTime], [SysEndTime])
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
WITH
(
SYSTEM_VERSIONING = ON ( HISTORY_TABLE = [scheduler].[TaskHistory] )
)
GO
ALTER TABLE [scheduler].[Task] ADD  CONSTRAINT [DF_Task_IsNotifyOnFailure]  DEFAULT ((1)) FOR [IsNotifyOnFailure]
GO
ALTER TABLE [scheduler].[Task] ADD  CONSTRAINT [DF_Task_IsEnabled]  DEFAULT ((1)) FOR [IsEnabled]
GO
ALTER TABLE [scheduler].[Task] ADD  CONSTRAINT [DF_IsDeleted]  DEFAULT ((0)) FOR [IsDeleted]
GO
ALTER TABLE [scheduler].[Task]  WITH CHECK ADD  CONSTRAINT [CK_FrequencyInterval] CHECK  (([FrequencyType]=(1) AND [FrequencyInterval]=(0) OR ([FrequencyType]=(4) OR [FrequencyType]=(3) OR [FrequencyType]=(2)) AND [FrequencyInterval]>(0)))
GO
ALTER TABLE [scheduler].[Task] CHECK CONSTRAINT [CK_FrequencyInterval]
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [scheduler].[TaskExecution](
	[ExecutionId] [int] IDENTITY(1,1) NOT NULL,
	[TaskId] [int] NOT NULL,
	[StartDateTime] [datetime2](3) NOT NULL,
	[EndDateTime] [datetime2](3) NULL,
	[IsError] [bit] NOT NULL,
	[ResultMessage] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
 CONSTRAINT [PK_TaskExecution] PRIMARY KEY CLUSTERED 
(
	[ExecutionId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION = PAGE) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
ALTER TABLE [scheduler].[TaskExecution] ADD  CONSTRAINT [DF_TaskExecution_StartDateTime]  DEFAULT (getutcdate()) FOR [StartDateTime]
GO
ALTER TABLE [scheduler].[TaskExecution] ADD  CONSTRAINT [DF_TaskExecution_IsError]  DEFAULT ((0)) FOR [IsError]
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [scheduler].[TaskHistory](
	[TaskId] [int] NOT NULL,
	[Identifier] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[TSQLCommand] [nvarchar](max) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[StartTime] [time](7) NOT NULL,
	[FrequencyType] [tinyint] NOT NULL,
	[FrequencyTypeDesc] [varchar](6) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[FrequencyInterval] [smallint] NOT NULL,
	[NotifyOnFailureOperator] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[IsNotifyOnFailure] [bit] NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[AvailabilityGroup] [nvarchar](128) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IsDeleted] [bit] NULL,
	[SysStartTime] [datetime2](7) NOT NULL,
	[SysEndTime] [datetime2](7) NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
WITH
(
DATA_COMPRESSION = PAGE
)
GO
CREATE CLUSTERED INDEX [ix_TaskHistory] ON [scheduler].[TaskHistory]
(
	[SysEndTime] ASC,
	[SysStartTime] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, DATA_COMPRESSION = PAGE) ON [PRIMARY]
GO
