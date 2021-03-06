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
