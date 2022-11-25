#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.1.1";
	Handler.InitialFilling = True;
	Handler.Procedure = "MarkedObjectsDeletionInternal.EnaleDeletingMarkedObjects";
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

// 2.4.1.1 update handler.
//
Procedure EnaleDeletingMarkedObjects() Export
	
	Constants.UseMarkedObjectsDeletion.Set(True);
	
EndProcedure

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add("MarkedItemsDeletion");
	
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobSettings. 
Procedure OnDefineScheduledJobSettings(Dependencies) Export
	
	Dependence = Dependencies.Add();
	Dependence.ScheduledJob = Metadata.ScheduledJobs.MarkedItemsDeletion;
	Dependence.FunctionalOption = Metadata.FunctionalOptions.UseMarkedObjectsDeletion;
	
EndProcedure

#EndRegion

#Region Private

// Scheduled job entry point.
//
Procedure MarkedItemsDeletionOnSchedule() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.MarkedItemsDeletion);
	
	DataProcessors.MarkedObjectsDeletion.DeleteMarkedObjectsFromScheduledJob();
	
EndProcedure

#EndRegion