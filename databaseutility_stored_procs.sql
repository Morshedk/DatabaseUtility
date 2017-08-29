USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE procedure [dbo].[ErrorHandler]
(
	@NoLog int					= 0,
	@RaiseError int				= 1,
	@ExtraInfo nvarchar(max)	= null
)
as 

set lock_timeout 2000 /*Wait 2 secs*/
set deadlock_priority low

declare @ErrorMessage	nvarchar(2000),
        @Severity		tinyint,
        @State			tinyint,
        @ErrorID		int,
        @ProcedureName	sysname,
        @LineNumber		int,
		@LineNumberVarchar varchar(128),
		@SystemUser		varchar(128),
		@AppName		varchar(128),
		@Schemaname varchar(100),
		@ContextInfo varbinary(1000),
		@XactState int
		
		          
select	@ErrorMessage	= error_message(),
		@Severity		= error_severity(),
		@State			= error_state(),
		@ErrorID		= error_number(),
		@ProcedureName	= isnull(error_procedure(),'***Manual Script***'),
		@LineNumber		= error_line(),
		@LineNumberVarchar	= error_line(),
		@SystemUser		=system_user,
		@AppName		=app_name()
        --@schemaName		= object_schema_name(object_id(error_procedure())) /*Not reliable */

select	@XactState		= xact_state() /*Needs to be in its own select statement or just returns one all the time*/

select	 @ContextInfo = context_info 
from	sys.dm_exec_sessions dec
where	dec.session_id = @@SPID



if @NoLog = 0
	begin

		insert	Exception
				(
				ErrorMessage
				,ErrorID
				,ProcedureName
				,LineNumber
				,ExtraInfo
				,SystemUser
				,AppName
				,schemaName
				,IsErrorRaised
				,ContextInfo
				,XactState
				)
		select	@ErrorMessage
				,@ErrorID
				,@ProcedureName
				,@LineNumber
				,try_cast(@ExtraInfo as xml)
				,@SystemUser
				,@AppName
				,@schemaName
				,@RaiseError
				,@ContextInfo
				,@XactState
	end

if @RaiseError = 1

begin

	if	@ErrorID <= 50000
		begin
			raiserror(@ErrorMessage, 13, 1)
			
		end
	if	@ErrorID > 50000
		begin
			raiserror(@ErrorID,	13, 1)
		end

	raiserror(N'Error in Procedure: %s.%s, Line number: %s, SystemUser: %s , Application: %s',13,1,@schemaName,@ProcedureName,@LineNumberVarchar, @SystemUser, @AppName)
end 


GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [dbo].[KillCmd] 
@Spid varchar(10),
@recipients  varchar(500) ='dbalerts@viagogo.com;PPCAlerts@viagogo.com',
@Subject varchar(255) =null,
@Message nvarchar(4000) =null,
@IsEmailOnly bit = 0

as

set xact_abort on
begin try
	
	if @Subject is null
	begin
		select @Subject = 'Your session ('+@Spid+') has been terminated'
	end

	select top 1
			@Message =  
isnull(@Message,'') + 
'
========================================
Login: ' + isnull(t.login_name,'') +'
DurationMins: ' +CAST(ISNULL(t.total_elapsed_time_in_mins,'') AS VARCHAR(10)) +'
MB_Used: ' +isnull(cast(t.MB_CurrentAllocation as varchar(20)),'') +'
SqlText sample:
========================================
' +isnull(substring( t.Sqltext  ,0,2000),'')
+'
========================================',
			@Spid = t.session_id,
			@recipients =@recipients + ';'+ replace(t.login_name,'viagogo\','') +'@viagogo.com'
	from    all_query_usage t
	where	t.session_id = @SPID



	select @Subject= coalesce(@Subject,'Your Session (' +@spid + ') has been killed')

	select @recipients = replace(@recipients,'product.user','adam.nassr@viagogo.com')


	if @IsEmailOnly = 0
	begin
		declare	@sql varchar(10)

		select  @sql = 'kill ' + @spid

		exec ( @sql)

	end

	exec msdb..sp_send_dbmail	@recipients = @recipients, -- varchar(max) 
		@Subject = @Subject ,
		@body = @Message


end try

begin catch
	if @@Trancount > 0
		begin
			rollback transaction
		end
		
		exec dbo.ErrorHandler @NoLog = 0, @RaiseError = 1
	return
end catch


GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE proc [ED209].[KillLongRunningQueries]

AS

declare @Spid INT , @TimeLimitMins int, @Subject varchar(255), @Message nvarchar(4000), @IsEmailOnly bit = 0

drop table if exists #spids
select		*, (1.0*s.timeinminutes/s.UserLimitMinutes) -1 AS PecentOverlimit 
into #spids
from	    monitor.LongRunningQueries s
left join	ED209.SpidHallPass shp
on			s.session_id = shp.Spid
and			shp.Expires<getutcdate()
where		s.timeinminutes > s.UserLimitMinutes
and			shp.Spid is null




while exists (SELECT * FROM #spids s)
begin

	select @Spid = s.session_id  from #spids s

	IF (SELECT s.PecentOverlimit FROM #spids s WHERE s.session_id = @Spid)BETWEEN 0 AND 0.5
		begin

			SELECT @TimeLimitMins = s.UserLimitMinutes*1.5-s.timeinminutes  FROM #spids s WHERE s.session_id = @Spid 

			

			select 
			@Subject = 'You have ' +cast(@TimeLimitMins as varchar(10)) + ' MINS to respond. Your session ('+cast(@Spid as varchar(5))+') is violating policy- [DURATION TOO LONG]. [Sent by ED209]' + case when @IsEmailOnly = 1 then '[NonKillMode]' else '' end,
			@Message =  'Either kill your session or request hallpass with DatabaseUtility.ED209.RequestHallPass proc'

			exec dbo.KillCmd @Spid = @Spid          -- varchar(10)
			               , @Subject = @Subject       -- varchar(255)
			               , @Message = @Message      -- nvarchar(4000)
			               , @IsEmailOnly = 1 -- bit
			

		END
    
	ELSE
    
		begin
				select 
				@Subject = 'Your session ('+cast(@Spid as varchar(5))+') has been terminated violating policy- [DURATION TOO LONG]. [Sent by ED209]' + case when @IsEmailOnly = 1 then '[NonKillMode]' else '' end,
				@Message =  'This service was brought to you by ED209.

Have a nice day
'

							exec dbo.KillCmd @Spid = @Spid          -- varchar(10)
			               , @Subject = @Subject       -- varchar(255)
			               , @Message = @Message      -- nvarchar(4000)
			               , @IsEmailOnly = @IsEmailOnly -- bit
		end


	delete from #spids where session_id = @Spid
	
end	







GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [ED209].[RequestHallPass] @Spid INT, @DurationMins int
as

if @DurationMins>360
begin
	throw 500001,'Max Duration 360 mins',1;
end

IF EXISTS (SELECT * FROM ED209.SpidHallPass shp WHERE shp.Spid = @Spid)
BEGIN
	
	UPDATE ED209.SpidHallPass SET InsertedBy = SYSTEM_USER, Expires =DATEADD(MINUTE,@DurationMins, GETUTCDATE()) WHERE Spid = @Spid

end

ELSE

begin
	INSERT INTO ED209.SpidHallPass
			( Spid, Expires, InsertedBy )
	SELECT @Spid , DATEADD(MINUTE,@DurationMins, GETUTCDATE()), SYSTEM_USER

end

GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.CreateAgentJob
	@jobName nvarchar(128)
	,@stepName sysname
	,@command nvarchar(max)
	,@frequencyType varchar(6)
	,@frequencyInterval tinyint /* Ignored for day, every N for Hour/Minute */
	,@startTime time
	,@notifyOperator nvarchar(128)
	,@overwriteExisting bit = 0
	,@description nvarchar(max) = null
as
begin
	set xact_abort on;
	set nocount on;

	declare @FREQUENCY_DAY varchar(6) = 'day'
		,@FREQUENCY_HOUR varchar(6) = 'hour'
		,@FREQUENCY_MINUTE varchar(6) = 'minute'
		,@FREQUENCY_SECOND varchar(6) = 'second'
		,@ACTIVE_START_DATE int = 20160101;

	/* Validate parameters for basic correctness */
	if @jobName is null
	begin
		;throw 50000, '@jobName must be specified', 1;
	end

	if @command is null
	begin
		;throw 50000, '@command must be specified', 1;
	end

	if @frequencyType is null
	begin
		;throw 50000, '@frequencyType must be specified', 1;
	end

	if @frequencyInterval is null
	begin
		;throw 50000, '@frequencyInterval must be specified', 1;
	end

	if @startTime is null
	begin
		;throw 50000, '@startTime must be specified', 1;
	end

	if @notifyOperator is null
	begin
		;throw 50000, '@notifyOperator must be specified', 1;
	end

	/* Extended validation */
	if @frequencyType not in (@FREQUENCY_DAY, @FREQUENCY_HOUR, @FREQUENCY_MINUTE, @FREQUENCY_SECOND)
	begin
		;throw 50000, '@frequencyType must be one of: day, hour, minute, second',1;
	end

	if @frequencyType = @FREQUENCY_DAY and @frequencyInterval <> 0
	begin
		;throw 50000, 'Daily frequency only supports an interval of 0 (once per day)', 1;
	end

	if @frequencyType = @FREQUENCY_HOUR and @frequencyInterval > 23
	begin
		;throw 50000, 'Hourly frequency with an interval of 24 hours or more are not supported', 1;
	end

	if @frequencyType = @FREQUENCY_HOUR and not @frequencyInterval between 1 and 23
	begin
		;throw 50000, 'Hourly frequency requires an interval between 1 and 23', 1;
	end

	if @frequencyType = @FREQUENCY_MINUTE and not @frequencyInterval between 1 and 3599
	begin
		;throw 50000, 'Minute frequency requires an interval between 1 and 3599 (1 minute to 1 day)', 1;
	end

	if @frequencyType = @FREQUENCY_SECOND and not @frequencyInterval between 1 and 3599
	begin
		;throw 50000, 'Second frequency requires an interval between 1 and 3599 (1 second to 1 hour)', 1;
	end

	/* Validate job does not already exist (if overwrite is not specified)
	   Validate operator exists 
	*/

	declare @existingJobId uniqueidentifier;
	select @existingJobId = s.job_id
	from msdb.dbo.sysjobs as s
	where s.name = @jobName;

	if @existingJobId is not null and @overwriteExisting = 0
	begin
		;throw 50000, 'Specified job name already exists', 1;
	end

	if not exists (
		select 1
		from msdb.dbo.sysoperators as o
		where o.name = @notifyOperator
	)
	begin
		;throw 50000, 'Specified @notifyOperator does not exist', 1;
	end
	

	/* Perform job management in a transaction (don't leave behind half-complete work)
		- Let xact_abort 'handle' our errors for now
	*/
	begin tran
		/* Delete existing job if we need to */
		if @existingJobId is not null and @overwriteExisting = 1
		begin
			exec msdb.dbo.sp_delete_job @job_id = @existingJobId;
		end
		
		/* MSDN docs for job creation: https://msdn.microsoft.com/en-gb/library/ms187320.aspx */

		/* Create the job 
			- Set owner to SA
			- Disable logging of failure to the windows event log
			- Set failure notification on email
			- Add audit information to description
		*/

		declare @currentUser nvarchar(128) = suser_name()
				,@currentHost nvarchar(128) = host_name()
				,@currentApplication nvarchar(128) = app_name()
				,@currentDate nvarchar(128) = convert(nvarchar(128),getutcdate(), 20)
				,@crlf char(2) = char(13) + char(10);

		declare @jobDescription nvarchar(max) = formatmessage('Created with CreateAgentJob%sUser:%s%sHost:%s%sApplication:%s%sTime:%s', @crlf, @currentUser, @crlf, @currentHost, @crlf, @currentApplication, @crlf, @currentDate);

		if @description is not null
		begin
			set @jobDescription = @jobDescription + @crlf + 'Info:' + @description
		end

		exec  msdb.dbo.sp_add_job 
				@job_name = @jobName
				,@notify_level_eventlog = 0
				,@notify_level_email = 2
				,@owner_login_name = N'sa'
				,@notify_email_operator_name = @notifyOperator
				,@description = @jobDescription;

		/* Add a job server (specifies this job should execute on this server) */
		EXEC msdb.dbo.sp_add_jobserver @job_name=@jobName;

		/* Add the TSQL job step, homed in the master database */
		EXEC msdb.dbo.sp_add_jobstep 
				@job_name = @jobName
				,@step_name= @stepName
				,@subsystem = N'TSQL'
				,@command = @command
				,@database_name = N'master';

		/* Add a schedule with the same name as the job 
			sp_add_jobschedule: https://msdn.microsoft.com/en-gb/library/ms187320.aspx
			Frequency is always daily, how often per-day is based on parameters
		*/

		declare @freq_subday_type int
				,@active_start_time int;

		set @freq_subday_type = case @frequencyType
									when @FREQUENCY_DAY then 1
									when @FREQUENCY_SECOND then 2
									when @FREQUENCY_HOUR then 8
									when @FREQUENCY_MINUTE then 4
								end;
		
		/* Convert start time into msdb format */
		set @active_start_time = (datepart(hour,@startTime) * 10000) + (datepart(minute, @startTime) * 100) + datepart(second, @startTime);
		
		exec msdb.dbo.sp_add_jobschedule 
				@job_name=@jobName
				,@name=@jobName
				,@freq_type=4	/* Daily */
				,@freq_interval=1
				,@freq_subday_type=@freq_subday_type
				,@freq_subday_interval = @frequencyInterval
				,@active_start_date=@ACTIVE_START_DATE
				,@active_end_date=99991231
				,@active_start_time=@active_start_time
				,@active_end_time=235959;

	commit tran
end
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.CreateJobFromTask
	@taskId int = null
	,@identifier nvarchar(128) = null
	,@overwriteExisting bit = 0
as
begin
	set xact_abort on;
	set nocount on;

	if (@taskId is null and @identifier is null) or (@taskId is not null and @identifier is not null)
	begin
		;throw 50000, 'Only one of @taskId or @identifier must be specified', 1;
	end

	if @overwriteExisting is null
	begin
		;throw 50000, '@overwriteExisting cannot be null', 1;
	end

	if @taskId is null
	begin
		select @taskId = t.TaskId
		from scheduler.Task as t
		where t.Identifier = @identifier;
	end

	if not exists (
		select 1
		from scheduler.Task as t
		where t.TaskId = @taskId
	)
	begin
		;throw 50000, 'Specified Task does not exist', 1;
	end

	declare @jobName nvarchar(128)
			,@command nvarchar(max)
			,@frequencyType varchar(6)
			,@frequencyInterval tinyint
			,@startTime time
			,@notifyOperator nvarchar(128)
			,@description nvarchar(max)
	declare @db nvarchar(max) = db_name(db_id());

	set @description = 'Created from task ' + cast(@taskId as varchar(12)) + ' in database ' + @db;
	
	select	@jobName = t.Identifier
			,@frequencyType = t.FrequencyTypeDesc
			,@frequencyInterval = t.FrequencyInterval
			,@startTime = t.StartTime
			,@notifyOperator = t.NotifyOnFailureOperator
	from	scheduler.Task as t
	where	t.TaskId = @taskId;
	
	set @command = 'exec ' + @db + '.scheduler.ExecuteTask @taskId = ' + cast(@taskId as varchar(12)) + ';';

	exec scheduler.CreateAgentJob
			@jobName = @jobName
			,@stepName = @jobName
			,@command = @command
			,@frequencyType = @frequencyType
			,@frequencyInterval = @frequencyInterval
			,@startTime = @startTime
			,@notifyOperator = @notifyOperator
			,@overwriteExisting = @overwriteExisting
			,@description = @description;
end
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.DeleteAgentJob
	@jobName nvarchar(128)
	
as
begin
	set xact_abort on;
	set nocount on;

	
	/* Validate parameters for basic correctness */
	if @jobName is null
	begin
		;throw 50000, '@jobName must be specified', 1;
	end

	declare @existingJobId uniqueidentifier;

    declare @schedule_Id int;

    select @existingJobId = s.job_id
    from msdb.dbo.sysjobs as s
    where s.name = @jobName;
       
    if @existingJobId is null 
    begin
          ;throw 50000, 'Specified job name does not exists', 1;
          RETURN;
    end

    select @schedule_Id=s.schedule_id 
    from  msdb.dbo.sysschedules s 
    join  msdb.dbo.sysjobschedules sj
    on    s.schedule_id=sj.schedule_id
	where sj.job_id=@existingJobId

    /* Delete schedule if exists*/
    IF @schedule_Id is not null
    begin
          EXEC msdb.dbo.sp_delete_schedule @schedule_id=@schedule_id, @force_delete = 1
    end

	/* Delete Job*/
	exec msdb.dbo.sp_delete_job @job_id = @existingJobId;
end
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.ExecuteTask
	@taskId int = null
	,@identifier nvarchar(128) = null
as
begin
	set xact_abort on;
	set nocount on;

	if (@taskId is null and @identifier is null) or (@taskId is not null and @identifier is not null)
	begin
		;throw 50000, 'Only one of @taskId or @identifier must be specified', 1;
	end

	if @taskId is null
	begin
		select @taskId = t.TaskId
		from scheduler.Task as t
		where t.Identifier = @identifier;
	end

	if not exists (
		select 1
		from scheduler.Task as t
		where t.TaskId = @taskId
	)
	begin
		;throw 50000, 'Specified Task does not exist', 1;
	end

	declare @executionId int
			,@command nvarchar(max)
			,@isEnabled bit
			,@isNotifyOnFailure bit
			,@availabilityGroupName nvarchar(128);

	select	@command = t.TSQLCommand
			,@isEnabled = t.IsEnabled
			,@isNotifyOnFailure = t.IsNotifyOnFailure
			,@availabilityGroupName = t.AvailabilityGroup
			,@identifier = t.Identifier

	from	scheduler.Task as t
	where	t.TaskId = @taskId;

	/* Run the task only if it is enabled and we're on the right replica (or no AG specified) */
	if @isEnabled = 0
	begin
		return;
	end
    
	if @availabilityGroupName is not null and scheduler.GetAvailabilityGroupRole(@availabilityGroupName) <> N'PRIMARY'
	begin
  		return;
	end

	insert into scheduler.TaskExecution
	( TaskId )
	values
	( @taskId );

	select @executionId = scope_identity();

	declare @errorNumber int
			,@resultMessage nvarchar(max)
			,@isError bit = 0;

	begin try
		exec sp_executesql @command;
	end try
	begin catch
		set @isError = 1;
		set @errorNumber = error_number();
		set @resultMessage = cast(@errorNumber as varchar(10)) + ' - ' + error_message();

		if xact_state() in (-1,1)
		begin
			rollback transaction;
		end
	end catch

	update scheduler.TaskExecution
		set IsError = @isError
			,ResultMessage = @resultMessage
			,EndDateTime = getutcdate()
	where ExecutionId = @executionId;

	/* Throw here to allow agent to message the failure operator */
	if @isError = 1 and @isNotifyOnFailure = 1
	begin
		;throw 50000, @resultMessage, 1;
	end
end
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.RemoveJobFromTask
	@taskId int = null
	,@identifier nvarchar(128) = null
as
begin
	set xact_abort on;
	set nocount on;

	if (@taskId is null and @identifier is null) or (@taskId is not null and @identifier is not null)
	begin
		;throw 50000, 'Only one of @taskId or @identifier must be specified', 1;
	end

	if @taskId is null
	begin
		select @taskId = t.TaskId
		from scheduler.Task as t
		where t.Identifier = @identifier;
	end

	if not exists (
		select 1
		from scheduler.Task as t
		where t.TaskId = @taskId
		and t.Isdeleted=1
	)
	begin
		;throw 50000, 'Specified task does not exists or it has not been marked for deletion ', 1;
	end

	declare @jobName nvarchar(128)
			
	select	@jobName = t.Identifier
	from	scheduler.Task as t
	where	t.TaskId = @taskId;
	
	exec scheduler.DeleteAgentJob
			@jobName = @jobName;
			
end
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   procedure scheduler.UpsertJobsForAllTasks
as
begin
	set xact_abort on;
	set nocount on;

	declare @id int
			,@maxId int
			,@taskId int;

	/*Update Existing and Create New Jobs*/
	drop table if exists #UpdateCreateWork;
	create table #UpdateCreateWork
	(
		Id	int not null identity(1, 1) primary key,
		TaskId int not null
	);

	insert into		#UpdateCreateWork
					(TaskId)
	select			t.TaskId 
	from			scheduler.Task as t
	where			t.IsDeleted = 0
	and not exists (
		select	1 
		from 	msdb.dbo.sysjobs j 
		where 	j.name = t.Identifier 
		and		j.date_modified >= t.sysStartTime
	);

	set @maxId = scope_identity();
	set @id = 1;

	while @id <= @maxId
	begin
		select @taskId = w.TaskId
		from #UpdateCreateWork as w
		where w.Id = @id;
		
		begin try
			exec scheduler.CreateJobFromTask @taskId = @taskId, @overwriteExisting = 1;
		end try
		begin catch
			/* Swallow error - we don't want to take out the whole run if a single task fails to create */
		end catch
		set @id += 1;
	end

    /* Delete existing jobs marked for deletion */
	drop table if exists #DeleteWork;
	create table #DeleteWork
	(
		Id	int not null identity(1, 1) primary key,
		TaskId int not null
	);

	insert into		#DeleteWork
					(TaskId)
	select			t.TaskId 
	from			scheduler.Task as t
	where			t.IsDeleted = 1
	and exists		(
		select	1 
		from	msdb.dbo.sysjobs j 
		where	j.name = t.Identifier 
	);

	set @maxId = scope_identity();
	set @id = 1;

	while @id <= @maxId
	begin
		select @taskId = w.TaskId
		from #DeleteWork as w
		where w.Id = @id;
		
		begin try
			exec scheduler.RemoveJobFromTask @taskId = @taskId;
		end try
		begin catch
			/* Swallow error - we don't want to take out the whole run if a single task fails to create */
		end catch
		set @id += 1;
	END
end
GO
