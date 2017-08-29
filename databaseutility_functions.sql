USE [databaseutility]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
create   function scheduler.GetAvailabilityGroupRole
(
	@availabilityGroupName nvarchar(128)
)
returns nvarchar(60)
as
begin
	declare @role nvarchar(60);

	select		@role = ars.role_desc
	from		sys.dm_hadr_availability_replica_states ars
	inner join	sys.availability_groups ag
	on			ars.group_id = ag.group_id
	where		ag.name = @availabilityGroupName
	and			ars.is_local = 1;

	return coalesce(@role,'');
end
GO
