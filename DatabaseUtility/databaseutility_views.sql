USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE view [dbo].[all_query_usage]
as
  select R1.session_id, R1.request_id, 
	(R1.request_objects_alloc_page_count-R1.request_objects_dealloc_page_count)*8/1024 as MB_CurrentAllocation,
      R1.request_objects_alloc_page_count*8/1024 as MB_allocated,
	  R1.request_objects_dealloc_page_count*8/1024 as MB_deallocated,
      isnull(x.text,y.text) as  Sqltext,
	  r4.login_name,
	  r4.host_name,
	  isnull(r2.start_time, r4.login_time) as start_time,
	  R2.total_elapsed_time/60000 total_elapsed_time_in_mins
  FROM all_request_usage R1
  left JOIN sys.dm_exec_requests R2 ON R1.session_id = R2.session_id and R1.request_id = R2.request_id
  left JOIN sys.dm_exec_connections  R3 ON R1.session_id = R3.session_id 
  left join sys.dm_exec_sessions r4 on r4.session_id = R1.session_id
  outer apply sys.dm_exec_sql_text(R2.plan_handle)x
  outer apply sys.dm_exec_sql_text(R3.most_recent_sql_handle)y



GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[all_request_usage]
AS 
  SELECT session_id, MAX(x.request_id) AS request_id ,
      SUM(internal_objects_alloc_page_count + user_objects_alloc_page_count) AS request_objects_alloc_page_count,
      SUM(internal_objects_dealloc_page_count + user_objects_dealloc_page_count)AS request_objects_dealloc_page_count 
  FROM (
            select  session_id
                   ,request_id
                   ,internal_objects_alloc_page_count
                   ,user_objects_alloc_page_count
                   ,internal_objects_dealloc_page_count
                   ,user_objects_dealloc_page_count
            from    sys.dm_db_task_space_usage
            union
            select  session_id
                   ,null
                   ,internal_objects_alloc_page_count
                   ,user_objects_alloc_page_count
                   ,internal_objects_dealloc_page_count
                   ,user_objects_dealloc_page_count
            from    sys.dm_db_session_space_usage
		) x
  GROUP BY session_id
GO
USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW monitor.LongRunningQueries
as
select  distinct r.session_id
,	s.nt_username AS username
,	COALESCE(sj.JobName,s.program_name) AS program
,   r.start_time AS starttime
,   r.total_elapsed_time/60000 AS timeinminutes
,   r.[status] AS status
,   DB_Name(r.database_id) AS DatabaseName
,r.open_transaction_count AS trancount
,GETUTCDATE() DateValue
,r.reads
,r.writes
,r.cpu_time
,r.sql_handle
,case	s.nt_username					when 'BI.SSRS' then 20
										when '33526-AGENTSVC1' then 180
										when 'database.automations' then 180
										else 60
										end as UserLimitMinutes
FROM
   sys.dm_exec_requests r
   JOIN sys.sysprocesses s
   ON s.spid=r.session_id
   OUTER APPLY
	(
		SELECT CONCAT('Job: ',j.name ) AS JobName
		FROM msdb.dbo.sysjobs j
		WHERE j.job_id=TRY_CONVERT(UNIQUEIDENTIFIER,TRY_CONVERT(VARBINARY(16),(SUBSTRING(s.program_name,CHARINDEX('0x',s.program_name,0),34)),1))
	)
	sj
WHERE r.status IN ('running','runnable','suspended')
and s.spid not in (SELECT shp.Spid FROM DatabaseUtility.ED209.SpidHallPass shp where shp.Spid = s.spid and shp.Expires>getutcdate())
AND r.database_id>5
and (sj.JobName not like '%cdc.%' or sj.JobName is null)
AND r.command IN 
(
'BULK INSERT'
,'DELETE'
,'INSERT'
,'SELECT'
,'SELECT INTO'
,'UPDATE'
,'MERGE'
,'EXECUTE'
)




GO
