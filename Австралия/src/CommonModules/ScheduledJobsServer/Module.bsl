#Region Public

// In the local mode of operation, it returns the scheduled jobs machting the filter.
// In SaaS mode - the value table which contains details of the found jobs in the JobQueue catalog 
// (if no separators are set) or the DataAreaJobQueue catalog.
//
// Parameters:
//  Filter - Structure - contains the following properties:
//          1) Common for any operation mode:
//             * UUID - UUID - an ID of scheduled job in the local mode of operation.
//                                            
//                                       - CatalogRef.JobsQueue,
//                                         CatalogRef.DataAreaJobQueue - an ID of a queue job in the 
//                                            SaaS mode.
//             * Metadata - MetadataObject: ScheduledJob - a scheduled job metadata.
//                                       - String- - a name of scheduled job.
//             * Usage - Boolean - if True, a job is enabled.
//             * Key - String - an applied ID of a job.
//          2) Allowed keys only for local mode:
//             * Description - String - scheduled job description.
//             * Predefined - Boolean - if True, scheduled job is defined in the metadata.
//          3)  Allowed keys only for SaaS mode:
//             * MethodName - String - a method name (or alias) of a job queue handler.
//             * DataArea - Number - job data area separator value.
//             * JobState - EnumRef.JobStates - queued job state.
//             * Template - CatalogRef.QueueJobTemplates - a job template used for separated queue 
//                                            jobs only.
//
// Returns:
//     Array - in the local mode of operation, a schedule job array.
//              See description of ScheduledJob method in the Syntax Assistant.
//     ValuesTable - in SaaS mode, a table of values with properties:
//        * RestartIntervalOnFailure - Number - interval between job restart attempts after its 
//                                                     abnormal termination, in seconds.
//        * Usage - Boolean - if True, a job is enabled.
//        * Key - String - an applied ID of a job.
//        * RestartCountOnFailure - Number - a number of retries after job abnormal termination.
//        * Parameters - Array - parameters to be passed to job handler.
//        * Schedule - Schedule - a job schedule.
//        * UUID - UUID - an ID of scheduled job in the local mode of operation.
//                                                     
//                                                - CatalogRef.JobsQueue,
//                                                  CatalogRef.DataAreaJobQueue - an ID of a queue 
//                                                     job in the SaaS mode.
//        * ScheduledStartTime - Date - date and time of scheduled job launch (as adjusted for the 
//                                                     data area time zone).
//        * MethodName - String - a method name (or alias) of a job queue handler.
//        * DataArea - Number - job data area separator value.
//        * JobState - EnumRef.JobStates - queued job state.
//        * Template - CatalogRef.QueueJobTemplates - job template, used for separated queue jobs 
//                                                     only.
//        * ExclusiveExecution - Boolean - if this flag is set, the job will be executed even if 
//                                                     session start is prohibited in the data area.
//                                                      If any jobs with this flag are available in 
//                                                     a data area, they will be executed first.
//
Function FindJobs(Filter) Export
	
	RaiseIfNoAdministrationRights();
	
	FilterCopy = CommonClientServer.CopyStructure(Filter);
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			
			If FilterCopy.Property("UUID") AND NOT FilterCopy.Property("ID") Then
				FilterCopy.Insert("ID", FilterCopy.UUID);
			EndIf;
			
			
			If Common.SeparatedDataUsageAvailable() Then
				DataArea = ModuleSaaS.SessionSeparatorValue();
				FilterCopy.Insert("DataArea", DataArea);
			EndIf;
			
			ModuleJobQueue  = Common.CommonModule("JobQueue");
			QueueJobTemplates = ModuleJobQueue.QueueJobTemplates();
			
			If FilterCopy.Property("Metadata") Then
				If TypeOf(FilterCopy.Metadata) = Type("MetadataObject") Then
					If QueueJobTemplates.Find(FilterCopy.Metadata.Name) <> Undefined Then
						SetPrivilegedMode(True);
						Template = ModuleJobQueue.TemplateByName(FilterCopy.Metadata.Name);
						SetPrivilegedMode(False);
						FilterCopy.Insert("Template", Template);
					Else
						FilterCopy.Insert("MethodName", FilterCopy.Metadata.MethodName);
					EndIf;
				Else
					MetadataScheduledJob = Metadata.ScheduledJobs.Find(FilterCopy.Metadata);
					If MetadataScheduledJob <> Undefined Then
						If QueueJobTemplates.Find(MetadataScheduledJob.Name) <> Undefined Then
							SetPrivilegedMode(True);
							Template = ModuleJobQueue.TemplateByName(MetadataScheduledJob.Name);
							SetPrivilegedMode(False);
							FilterCopy.Insert("Template", Template);
						Else
							FilterCopy.Insert("MethodName", MetadataScheduledJob.MethodName);
						EndIf;
					EndIf;
				EndIf;
			ElsIf FilterCopy.Property("ID") 
				AND (TypeOf(FilterCopy.ID) = Type("UUID")
				OR TypeOf(FilterCopy.ID) = Type("String")) Then
				
				If TypeOf(FilterCopy.ID) = Type("String") Then
					FilterCopy.ID = New UUID(FilterCopy.ID);
				EndIf;
				
				ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
				CatalogForJob = ModuleJobQueueInternal.CatalogJobQueue();
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
				Else
					IsSeparatedConfiguration = False;
				EndIf;
				
				If IsSeparatedConfiguration Then
					ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
					OverriddenCatalog = ModuleJobQueueInternalDataSeparation.OnSelectCatalogForJob(FilterCopy);
					If OverriddenCatalog <> Undefined Then
						CatalogForJob = OverriddenCatalog;
					EndIf;
				EndIf;
				FilterCopy.Insert("ID", CatalogForJob.GetRef(FilterCopy.ID));
			EndIf;
			
			FilterCopy.Delete("Metadata");
			JobsList = ModuleJobQueue.GetJobs(FilterCopy);
			// For backward compatibility the ID field is not removed.
			ListCopy = JobsList.Copy();
			ListCopy.Columns.Add("UUID");
			For Each Row In ListCopy Do
				Row.UUID = Row.ID;
			EndDo;
			
			Return ListCopy;
			
		EndIf;
	Else
		
		JobsList = ScheduledJobs.GetScheduledJobs(FilterCopy);
		
		Return JobsList;
		
	EndIf;
	
EndFunction

// Returns ScheduledJob from the infobase.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the predefined scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a string of schedule job UUID or metadata name of a predefined schedule 
//                           job.
//                - ScheduledJob - a scheduled job from which you need to get the unique ID for 
//                  getting a fresh copy of the scheduled job.
// 
// Returns:
//  ScheduledJob - read from the database.
//
Function Job(Val ID) Export
	
	RaiseIfNoAdministrationRights();
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			
			JobParameters = New Structure;
			If Common.SeparatedDataUsageAvailable() Then
				DataArea = ModuleSaaS.SessionSeparatorValue();
				JobParameters.Insert("DataArea", DataArea);
			EndIf;
			
			ModuleJobQueue = Common.CommonModule("JobQueue");
			
			If TypeOf(ID) = Type("MetadataObject") Then
				If ID.Predefined Then
					SetPrivilegedMode(True);
					JobParameters.Insert("Template", ModuleJobQueue.TemplateByName(ID.Name));
					SetPrivilegedMode(False);
				Else
					JobParameters.Insert("MethodName", ID.MethodName);
				EndIf; 
			ElsIf TypeOf(ID) = Type("UUID") Then
				ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
				CatalogForJob = ModuleJobQueueInternal.CatalogJobQueue();
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
				Else
					IsSeparatedConfiguration = False;
				EndIf;
				
				If IsSeparatedConfiguration Then
					ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
					OverriddenCatalog = ModuleJobQueueInternalDataSeparation.OnSelectCatalogForJob(JobParameters);
					If OverriddenCatalog <> Undefined Then
						CatalogForJob = OverriddenCatalog;
					EndIf;
				EndIf;
				JobParameters.Insert("ID", CatalogForJob.GetRef(ID));
				
			ElsIf TypeOf(ID) = Type("ValueTableRow") Then
				Return ID;
			Else
				JobParameters.Insert("ID", ID);
			EndIf;
			
			JobsList = ModuleJobQueue.GetJobs(JobParameters);
			For Each Job In JobsList Do
				ScheduledJob = Job;
				Break;
			EndDo;
		EndIf;
	Else
		
		If TypeOf(ID) = Type("MetadataObject") Then
			If ID.Predefined Then
				ScheduledJob = ScheduledJobs.FindPredefined(ID);
			Else
				JobsList = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ID));
				If JobsList.Count() > 0 Then
					ScheduledJob = JobsList[0];
				EndIf;
			EndIf; 
		Else
			ScheduledJob = ScheduledJobs.FindByUUID(ID);
		EndIf;
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

// Adds a new job to a queue or as a scheduled one.
// 
// Parameters:
//  Parameters - Structure - parameters of the job to be added. The following keys can be used:
//   Usage
//   Metadata - mandatory.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RestartCountOnFailure.
//
// Returns:
//  ScheduledJob, CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue - an added job ID.
//  
// 
Function AddJob(Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	JobParameters = CommonClientServer.CopyStructure(Parameters);
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			
			If Common.SeparatedDataUsageAvailable() Then
				DataArea = ModuleSaaS.SessionSeparatorValue();
				JobParameters.Insert("DataArea", DataArea);
			EndIf;
			
			JobMetadata = JobParameters.Metadata;
			MethodName = JobMetadata.MethodName;
			JobParameters.Insert("MethodName", MethodName);
			
			JobParameters.Delete("Metadata");
			JobParameters.Delete("Description");
			
			ModuleJobQueue = Common.CommonModule("JobQueue");
			Job = ModuleJobQueue.AddJob(JobParameters);
			JobsList = ModuleJobQueue.GetJobs(New Structure("ID", Job));
			For Each Job In JobsList Do
				Return Job;
			EndDo;
			
		EndIf;
		
	Else
		
		JobMetadata = JobParameters.Metadata;
		Job = ScheduledJobs.CreateScheduledJob(JobMetadata);
		
		If JobParameters.Property("Description") Then
			Job.Description = JobParameters.Description;
		Else
			Job.Description = JobMetadata.Description;
		EndIf;
		
		If JobParameters.Property("Use") Then
			Job.Use = JobParameters.Use;
		Else
			Job.Use = JobMetadata.Use;
		EndIf;
		
		If JobParameters.Property("Key") Then
			Job.Key = JobParameters.Key;
		Else
			Job.Key = JobMetadata.Key;
		EndIf;
		
		If JobParameters.Property("UserName") Then
			Job.UserName = JobParameters.UserName;
		EndIf;
		
		If JobParameters.Property("RestartIntervalOnFailure") Then
			Job.RestartIntervalOnFailure = JobParameters.RestartIntervalOnFailure;
		Else
			Job.RestartIntervalOnFailure = JobMetadata.RestartIntervalOnFailure;
		EndIf;
		
		If JobParameters.Property("RestartCountOnFailure") Then
			Job.RestartCountOnFailure = JobParameters.RestartCountOnFailure;
		Else
			Job.RestartCountOnFailure = JobMetadata.RestartCountOnFailure;
		EndIf;
		
		If JobParameters.Property("Parameters") Then
			Job.Parameters = JobParameters.Parameters;
		EndIf;
		
		If JobParameters.Property("Schedule") Then
			Job.Schedule = JobParameters.Schedule;
		EndIf;
		
		Job.Write();
		
	EndIf;
	
	Return Job;
	
EndFunction

// Deletes ScheduledJob from the infobase.
//
// Parameters:
//  ID - MetadataObject - a metadata object of a scheduled job to search for not predefined 
//                  scheduled job.
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job from which you need to get the unique ID for 
//                  getting a fresh copy of the scheduled job.
//
Procedure DeleteJob(Val ID) Export
	
	RaiseIfNoAdministrationRights();
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			
			JobParameters = New Structure;
			If Common.SeparatedDataUsageAvailable() Then
				DataArea = ModuleSaaS.SessionSeparatorValue();
				JobParameters.Insert("DataArea", DataArea);
			EndIf;
			
			If TypeOf(ID) = Type("MetadataObject") Then
				MethodName = ID.MethodName;
				JobParameters.Insert("MethodName", MethodName);
			ElsIf TypeOf(ID) = Type("UUID") Then
				ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
				CatalogForJob = ModuleJobQueueInternal.CatalogJobQueue();
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
				Else
					IsSeparatedConfiguration = False;
				EndIf;
				
				If IsSeparatedConfiguration Then
					ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
					OverriddenCatalog = ModuleJobQueueInternalDataSeparation.OnSelectCatalogForJob(JobParameters);
					If OverriddenCatalog <> Undefined Then
						CatalogForJob = OverriddenCatalog;
					EndIf;
				EndIf;
				
				JobParameters.Insert("ID", CatalogForJob.GetRef(ID));
				
			ElsIf TypeOf(ID) = Type("ValueTableRow") Then
				
				ModuleJobQueue = Common.CommonModule("JobQueue");
				ModuleJobQueue.DeleteJob(ID.ID);
				Return;
				
			Else
				JobParameters.Insert("ID", ID);
			EndIf;
			
			ModuleJobQueue = Common.CommonModule("JobQueue");
			JobsList = ModuleJobQueue.GetJobs(JobParameters);
			For Each Job In JobsList Do
				ModuleJobQueue.DeleteJob(Job.ID);
			EndDo;
		EndIf;
	Else
		If TypeOf(ID) = Type("MetadataObject") AND ID.Predefined Then
			Raise( NStr("ru = 'Предопределенное регламентное задание удалить невозможно.'; en = 'Cannot delete a predefined scheduled job.'; pl = 'Usunąć wstępnie zdefiniowane planowe zadanie nie jest możliwie.';es_ES = 'Es imposible eliminar la tarea programada predeterminada.';es_CO = 'Es imposible eliminar la tarea programada predeterminada.';tr = 'Önceden tanımlanmış bir rutin görev silinemez.';it = 'Impossibile annullare task programmato predefinito.';de = 'Die vordefinierte geplante Aufgabe kann nicht gelöscht werden.'") );
		ElsIf TypeOf(ID) = Type("MetadataObject") AND NOT ID.Predefined Then
			JobsList = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ID));
			For each ScheduledJob In JobsList Do
				ScheduledJob.Delete();
			EndDo; 
		Else
			ScheduledJob = ScheduledJobs.FindByUUID(ID);
			If ScheduledJob <> Undefined Then
				ScheduledJob.Delete();
			EndIf;
		EndIf;
	EndIf;
	
EndProcedure

// Changes the job with the specified attribute.
// If called from within a transaction, object lock is set for the job.
// 
// Parameters:
//  ID - CatalogRef.JobQueue, CatalogRef.DataAreaJobQueue - job ID
//  Parameters - Structure - parameters that should be set to the job, allowed keys:
//   
//   Usage
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RestartCountOnFailure.
//   
//   If the job is created based on a template or a predefined one, only the following keys can be 
//   specified: Use.
// 
Procedure ChangeJob(Val ID, Val Parameters) Export
	
	RaiseIfNoAdministrationRights();
	
	JobParameters = CommonClientServer.CopyStructure(Parameters);
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			
			SearchParameters = New Structure;
			
			JobParameters.Delete("Description");
			If JobParameters.Count() = 0 Then
				Return;
			EndIf; 
			
			If Common.SeparatedDataUsageAvailable() Then
				DataArea = ModuleSaaS.SessionSeparatorValue();
				SearchParameters.Insert("DataArea", DataArea);
			EndIf;
			
			If TypeOf(ID) = Type("MetadataObject") Then
				MethodName = ID.MethodName;
				SearchParameters.Insert("MethodName", MethodName);
				
				// If the schedule job is predefined and there is a queue template, you can only change "Usage".
				If ID.Predefined Then
					
					ModuleJobQueue = Common.CommonModule("JobQueue");
					Templates = ModuleJobQueue.QueueJobTemplates();
					
					If Templates.Find(ID.Name) <> Undefined 
						AND (JobParameters.Count() > 1 
						OR NOT JobParameters.Property("Use")) Then
						
						For each JobParameter In CommonClientServer.CopyStructure(JobParameters) Do
							
							If JobParameter.Key = "Use" Then
								Continue;
							EndIf;
							
							JobParameters.Delete(JobParameter.Key);
						EndDo;
					EndIf;
				EndIf;
				
			ElsIf TypeOf(ID) = Type("UUID") Then
				ModuleJobQueueInternal = Common.CommonModule("JobQueueInternal");
				CatalogForJob = ModuleJobQueueInternal.CatalogJobQueue();
				
				If Common.SubsystemExists("StandardSubsystems.SaaS") Then
					ModuleSaaS = Common.CommonModule("SaaS");
					IsSeparatedConfiguration = ModuleSaaS.IsSeparatedConfiguration();
				Else
					IsSeparatedConfiguration = False;
				EndIf;
				
				If IsSeparatedConfiguration Then
					ModuleJobQueueInternalDataSeparation = Common.CommonModule("JobQueueInternalDataSeparation");
					OverriddenCatalog = ModuleJobQueueInternalDataSeparation.OnSelectCatalogForJob(SearchParameters);
					If OverriddenCatalog <> Undefined Then
						CatalogForJob = OverriddenCatalog;
					EndIf;
				EndIf;
				
				SearchParameters.Insert("ID", CatalogForJob.GetRef(ID));
				
			ElsIf TypeOf(ID) = Type("ValueTableRow") Then
				
				If ValueIsFilled(ID.Template)
					AND (JobParameters.Count() > 1 
					OR NOT JobParameters.Property("Use")) Then
					
					For Each JobParameter In CommonClientServer.CopyStructure(JobParameters) Do
						
						If JobParameter.Key = "Use" Then
							Continue;
						EndIf;
						
						JobParameters.Delete(JobParameter.Key);
					EndDo;
				EndIf;
				
				If JobParameters.Count() = 0 Then
					Return;
				EndIf;
				
				ModuleJobQueue = Common.CommonModule("JobQueue");
				ModuleJobQueue.ChangeJob(ID.ID, JobParameters);
				Return;
				
			Else
				SearchParameters.Insert("ID", ID);
			EndIf;
			
			If JobParameters.Count() = 0 Then
				Return;
			EndIf;
			
			ModuleJobQueue = Common.CommonModule("JobQueue");
			JobsList = ModuleJobQueue.GetJobs(SearchParameters);
			For Each Job In JobsList Do
				ModuleJobQueue.ChangeJob(Job.ID, JobParameters);
			EndDo;
		EndIf;
		
	Else
		
		Job = ScheduledJobs.FindByUUID(ID);
		If Job <> Undefined Then
			
			If JobParameters.Property("Description") Then
				Job.Description = JobParameters.Description;
			EndIf;
			
			If JobParameters.Property("Use") Then
				Job.Use = JobParameters.Use;
			EndIf;
			
			If JobParameters.Property("Key") Then
				Job.Key = JobParameters.Key;
			EndIf;
			
			If JobParameters.Property("UserName") Then
				Job.UserName = JobParameters.UserName;
			EndIf;
			
			If JobParameters.Property("RestartIntervalOnFailure") Then
				Job.RestartIntervalOnFailure = JobParameters.RestartIntervalOnFailure;
			EndIf;
			
			If JobParameters.Property("RestartCountOnFailure") Then
				Job.RestartCountOnFailure = JobParameters.RestartCountOnFailure;
			EndIf;
			
			If JobParameters.Property("Parameters") Then
				Job.Parameters = JobParameters.Parameters;
			EndIf;
			
			If JobParameters.Property("Schedule") Then
				Job.Schedule = JobParameters.Schedule;
			EndIf;
			
			Job.Write();
		
		EndIf; 
		
	EndIf;
	
EndProcedure

// Returns a scheduled job UUID.
//  Before calling, it is required to have the right to Administer or SetPrivilegedMode.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
// Returns:
//  UUID - a scheduled job object UUID.
// 
Function UUID(Val ID) Export
	
	If TypeOf(ID) = Type("UUID") Then
		Return ID;
	EndIf;
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		Return ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		Return New UUID(ID);
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		
		JobParameters = New Structure;
		
		TypeOfID = TypeOf(ID);
		
		If TypeOfID = Type("MetadataObject") Then
			MethodName = ID.MethodName;
			JobParameters.Insert("MethodName", MethodName);
		ElsIf TypeOfID = Type("ValueTableRow") Then
			Return ID.ID.UUID();
		ElsIf Common.IsReference(TypeOfID) Then
			Return ID.UUID();
		Else
			Return Undefined;
		EndIf;
		
		ModuleSaaS = Common.CommonModule("SaaS");
		DataArea = ModuleSaaS.SessionSeparatorValue();
		JobParameters.Insert("DataArea", DataArea);
		
		If Common.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
			ModuleJobQueue = Common.CommonModule("JobQueue");
			JobsList = ModuleJobQueue.GetJobs(JobParameters);
			For Each Job In JobsList Do
				Return Job.ID.UUID();
			EndDo;
		EndIf;
	Else
		If TypeOf(ID) = Type("MetadataObject") AND ID.Predefined Then
			Return ScheduledJobs.FindPredefined(ID).UUID;
		ElsIf TypeOf(ID) = Type("MetadataObject") AND NOT ID.Predefined Then
			JobsList = ScheduledJobs.GetScheduledJobs(New Structure("Metadata", ID));
			For each ScheduledJob In JobsList Do
				Return ScheduledJob.UUID;
			EndDo; 
		EndIf;
	EndIf;
	
	Return Undefined;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Procedures and functions without SaaS support.

// Returns the scheduled job use.
// Before calling, it is required to have the right to Administer or SetPrivilegedMode.
// Cannot be used in SaaS mode.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the predefined scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
// Returns:
//  Boolean - if True, scheduled job is used.
// 
Function ScheduledJobUsed(Val ID) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(ID);
	
	Return Job.Use;
	
EndFunction

// Returns the scheduled job schedule.
// Before calling, it is required to have the right to Administer or SetPrivilegedMode.
// Cannot be used in SaaS mode.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the predefined scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
//  InStructure - Boolean - if True, the schedule will be transformed into a structure that you can 
//                  pass to the client.
// 
// Returns:
//  JobSchedule, Structure - the structure contains the same properties as the schedule.
// 
Function JobSchedule(Val ID, Val InStructure = False) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(ID);
	
	If InStructure Then
		Return CommonClientServer.ScheduleToStructure(Job.Schedule);
	EndIf;
	
	Return Job.Schedule;
	
EndFunction

// Sets the use of the scheduled job.
// Before calling, it is required to have the right to Administer or SetPrivilegedMode.
// Cannot be used in SaaS mode.
//
// Parameters:
//  ID - MetadataObject - a metadata object of a scheduled job to search for the predefined 
//                                            scheduled job.
//                - UUID - an ID of the scheduled job.
//                - String - a string of a schedule job UUID.
//                - ScheduledJob - a scheduled job.
//  Usage - Boolean - a usage value to be set.
//
Procedure SetScheduledJobUsage(Val ID, Val Usage) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(ID);
	
	If Job.Use <> Usage Then
		Job.Use = Usage;
	EndIf;
	
	Job.Write();
	
EndProcedure

// Sets the scheduled job schedule.
// Before calling, it is required to have the right to Administer or SetPrivilegedMode.
// Cannot be used in SaaS mode.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the predefined scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job.
//
//  Schedule    - JobSchedule - a schedule.
//                - Structure - the value returned by the ScheduleToStructure function of the 
//                  CommonClientServer common module.
// 
Procedure SetJobSchedule(Val ID, Val Schedule) Export
	
	RaiseIfNoAdministrationRights();
	
	Job = GetScheduledJob(ID);
	
	If TypeOf(Schedule) = Type("JobSchedule") Then
		Job.Schedule = Schedule;
	Else
		Job.Schedule = CommonClientServer.StructureToSchedule(Schedule);
	EndIf;
	
	Job.Write();
	
EndProcedure

// Returns ScheduledJob from the infobase.
// Cannot be used in SaaS mode.
//
// Parameters:
//  ID - MetadataObject - metadata object of a scheduled job to search the predefined scheduled job.
//                  
//                - UUID - an ID of the scheduled job.
//                - String - a scheduled job UUID string.
//                - ScheduledJob - a scheduled job from which you need to get the unique ID for 
//                  getting a fresh copy of the scheduled job.
// 
// Returns:
//  ScheduledJob - read from the database.
//
Function GetScheduledJob(Val ID) Export
	
	RaiseIfNoAdministrationRights();
	
	If TypeOf(ID) = Type("ScheduledJob") Then
		ID = ID.UUID;
	EndIf;
	
	If TypeOf(ID) = Type("String") Then
		ID = New UUID(ID);
	EndIf;
	
	If TypeOf(ID) = Type("MetadataObject") Then
		ScheduledJob = ScheduledJobs.FindPredefined(ID);
	Else
		ScheduledJob = ScheduledJobs.FindByUUID(ID);
	EndIf;
	
	If ScheduledJob = Undefined Then
		Raise( NStr("ru = 'Регламентное задание не найдено.
		                              |Возможно, оно удалено другим пользователем.'; 
		                              |en = 'The scheduled job is not found.
		                              |Probably it was deleted by another user.'; 
		                              |pl = 'Nie znaleziono zaplanowanego zadania.
		                              |Być może zostało ono usunięte przez innego użytkownika.';
		                              |es_ES = 'Tarea programada no encontrada.
		                              |Probablemente, se ha eliminado por otro usuario.';
		                              |es_CO = 'Tarea programada no encontrada.
		                              |Probablemente, se ha eliminado por otro usuario.';
		                              |tr = 'Zamanlanmış iş bulunamadı. 
		                              |Başka bir kullanıcı tarafından silinmiş olabilir.';
		                              |it = 'Task programmato non trovato.
		                              |Probabilmente è stato eliminato da un altro utente.';
		                              |de = 'Geplanter Job wurde nicht gefunden.
		                              |Vielleicht wurde er von einem anderen Benutzer gelöscht.'") );
	EndIf;
	
	Return ScheduledJob;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other procedures and functions.

// Returns a flag showing that operations with external resources are locked.
//
// Returns:
//   Boolean - True if operations with external resources are locked.
//
Function OperationsWithExternalResourcesLocked() Export
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		Return ModuleScheduledJobsInternal.OperationsWithExternalResourcesLocked();
	EndIf;
	
	Return False;
EndFunction

// Allows operating with external resources.
//
Procedure UnlockOperationsWithExternalResources() Export
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.AllowOperationsWithExternalResources();
	EndIf;
EndProcedure

// Denies operations with external resources.
//
Procedure LockOperationsWithExternalResources() Export
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.DenyOperationsWithExternalResources();
	EndIf;
EndProcedure

#EndRegion

#Region Internal

// Sets the required values of scheduled job parameters.
// In SaaS mode, for a job created based on a job queue template, only the value of the Usage 
// property can be changed.
//
// Parameters:
//  ScheduledJob - MetadataObject: ScheduledJob - a job whose properties need to be changed.
//                        
//  ParametersToChange - Structure - properties of the scheduled job that need to be changed.
//                        Structure key - a parameter name, and value - a form parameter value. 
//  Filter - Structure - see the parameter details of the FindJobs function filter.
//
Procedure SetScheduledJobParameters(ScheduledJob, ParametersToChange, Filter = Undefined) Export
	
	If Filter = Undefined Then
		Filter = New Structure;
	EndIf;
	Filter.Insert("Metadata", ScheduledJob);
	
	JobsList = FindJobs(Filter);
	If JobsList.Count() = 0 Then
		ParametersToChange.Insert("Metadata", ScheduledJob);
		AddJob(ParametersToChange);
	Else
		For Each Job In JobsList Do
			ChangeJob(Job, ParametersToChange);
		EndDo;
	EndIf;
EndProcedure

// Defines whether a predefined scheduled job is used.
//
// Parameters:
//  MetadataJob - MetadataObject - predefined scheduled job metadata.
//  Usage - Boolean - True if the job must be activated, False otherwise.
//
Procedure SetPredefinedScheduledJobUsage(MetadataJob, Usage) Export
	
	If Common.DataSeparationEnabled() Then
		If Common.SubsystemExists("StandardSubsystems.SaaS.CoreSaaS") Then
			ModuleSaaS = Common.CommonModule("SaaS");
			ModuleSaaS.SetPredefinedScheduledJobUsage(MetadataJob, Usage);
		EndIf;
	Else
		Job = ScheduledJobs.FindPredefined(MetadataJob);
		
		If Job.Use <> Usage Then
			Job.Use = Usage;
			Job.Write();
		EndIf;
	EndIf;
	
EndProcedure


#EndRegion

#Region Private

// Throws an exception if the user does not have the administration right.
Procedure RaiseIfNoAdministrationRights()
	
	CheckSystemAdministrationRights = True;
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		CheckSystemAdministrationRights = False;
	EndIf;
	
	If NOT Users.IsFullUser(, CheckSystemAdministrationRights) Then
		Raise NStr("ru = 'Нарушение прав доступа.'; en = 'Access right violation.'; pl = 'Naruszenie praw dostępu.';es_ES = 'Violación del derecho de acceso.';es_CO = 'Violación del derecho de acceso.';tr = 'Erişim hakkı ihlali.';it = 'Violazione permessi di accesso.';de = 'Verletzung von Zugriffsrechten.'");
	EndIf;
	
EndProcedure

#EndRegion