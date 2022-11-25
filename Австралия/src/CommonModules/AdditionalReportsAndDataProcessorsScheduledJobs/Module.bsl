#Region Public

#Region ObsoleteProceduresAndFunctions

// Obsolete. Use ScheduledJobsServer.AddJob().
//
// Parameters:
//   Description - String - a scheduled job description.
//
// Returns:
//   Use ScheduledJobsServer.AddJob().
//
Function CreateNewJob(Val Description) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use ScheduledJobsServer.UUID().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
// Returns:
//   Undefined - use ScheduledJobsServer.UUID().
//
Function GetJobID(Val Job) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use ScheduledJobsServer.ChangeJob().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//   Usage - Boolean - a flag showing whether the scheduled job is used.
//   Description - String - a scheduled job description.
//   Parameters - Array - parameters of the scheduled job.
//   Schedule - JobSchedule - a job schedule.
//
Procedure SetJobParameters(Job, Usage, Description, Parameters, Schedule) Export
	
	Return;
	
EndProcedure

// Obsolete. Use ScheduledJobsServer.FindJobs().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
// Returns:
//   Undefined - use ScheduledJobsServer.FindJobs().
//
Function GetJobParameters(Val Job) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use ScheduledJobsServer.Job().
//
// Parameters:
//   ID - UUID - a job ID.
//
// Returns:
//   Undefined - use ScheduledJobsServer.FindJobs().
//
Function FindJob(Val ID) Export
	
	Return Undefined;
	
EndFunction

// Obsolete. Use ScheduledJobsServer.DeleteJob().
//
// Parameters:
//   Job - ScheduledJob - a scheduled job.
//
Procedure DeleteJob(Val Job) Export
	
	Return;
	
EndProcedure

#EndRegion

#EndRegion
