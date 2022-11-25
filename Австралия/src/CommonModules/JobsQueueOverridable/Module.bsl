#Region Public

// Generates a list of templates for queued jobs.
//
// Parameters:
//  JobTemplates - Array - the parameter should include names of predefined shared scheduled jobs to 
//   be used as queue job templates.
//   
//
Procedure OnGetTemplateList(JobTemplates) Export
	
EndProcedure

// Fills a map of method names and their aliases for calling from a job queue.
//
// Parameters:
//  NameAndAliasMap - Map -
//    * Key - method alias, example: ClearDataArea.
//    * Value - method name to be called, example: SaaS.ClearDataArea.
//        You can specify Undefined as the value, in this case the name is assumed to be the same as 
//        the alias.
//
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
EndProcedure

// Sets a mapping between error handler methods and aliases of methods where errors occur.
// 
//
// Parameters:
//  ErrorHandlers - Map -
//    * Key - method alias, example: ClearDataArea.
//    * Value - Method name - error handler, called upon error.
//        The error handler is called whenever a job execution fails.
//         The error handler is always called in the data area of the failed job.
//        The error handler method can be called by the queue mechanisms.
//        Error handler parameters:
//          JobParameters - Structure - queue job parameters.
//          Parameters
//          AttemptNumber
//          RestartCountOnFailure
//          LastRunStartDate.
//
Procedure OnDefineErrorHandlers(ErrorHandlers) Export
	
EndProcedure

// Generates a scheduled job table with flags that show whether a job is used in SaaS mode.
//
// Parameters:
//  UsageTable - ValueTable - value table with the following columns:
//    * ScheduledJob - String - name of the predefined scheduled job,
//    * Usage - Boolean - True if the scheduled job must be executed in the SaaS mode, False if it 
//       must not.
//
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
EndProcedure

#EndRegion
