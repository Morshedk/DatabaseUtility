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
