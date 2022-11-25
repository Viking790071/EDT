#Region Internal

// Called when filling the array of catalogs that can be used to store the queue jobs.
// 
//
// Parameters:
//  ArrayCatalog - Array. You need to add to this parameter any managers of catalogs that can be 
//    used to store the queue jobs to this parameter.
//
Procedure OnFillJobCatalog(CatalogArray) Export
	
	CatalogArray.Add(Catalogs.DataAreaJobQueue);
	
EndProcedure

// Selects a catalog to be used for adding a queue job.
//
// Parameters:
// JobParameters - - Structure - parameters of the job to be added. The following keys can be used:
//   DataArea
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution.
//   MethodName - mandatory.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RestartCountOnFailure,
// Catalog - CatalogManager, event subscription must set a catalog manager to be used for the job as 
//  a value for this parameter.
// StandardProcessing - boolean. Event subscription must set standard processing flag as a value for 
//  this parameter (the DataAreaJobQueue catalog will be selected as catalog for standard 
//  processing).
//
Function OnSelectCatalogForJob(Val JobParameters) Export
	
	If JobParameters.Property("DataArea") AND JobParameters.DataArea <> -1 Then
		
		Return Catalogs.DataAreaJobQueue;
		
	EndIf;
	
EndFunction

// Defines value of DataAreaMainData separator that must be set before launching the job.
//  
//
// Parameters:
//  Job - CatalogRef, queue job.
//
// Returns: Arbitrary.
//
Function DefineDataAreaForJob(Val Job) Export
	
	If TypeOf(Job) = Type("CatalogRef.DataAreaJobQueue") Then
		Return Common.ObjectAttributeValue(Job, "DataAreaAuxiliaryData");
	EndIf;
	
EndFunction

// Adjusts the scheduled job launch time to the data area time zone.
//
// Parameters:
//  JobParameters - Structure - parameters of the job to be added. The following keys can be used:
//   DataArea
//   Usage
//   ScheduledStartTime
//   ExclusiveExecution.
//   MethodName - mandatory.
//   Parameters
//   Key
//   RestartIntervalOnFailure.
//   Schedule
//   RestartCountOnFailure.
//  Result = Date (date and time), scheduled job launch time.
//  StandardProcessing - Boolean. This flag specifies that job launch time must be adjusted to the 
//    server time zone.
//
Procedure OnDefineScheduledStartTime(Val JobParameters, Result, StandardProcessing) Export
	
	DataArea = Undefined;
	If Not JobParameters.Property("DataArea", DataArea) Then
		Return;
	EndIf;
	
	If DataArea <> - 1 Then
		
		// Time adjustment from the area time zone.
		TimeZone = SaaS.GetDataAreaTimeZone(JobParameters.DataArea);
		Result = ToUniversalTime(JobParameters.ScheduledStartTime, TimeZone);
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

/// Updates queue jobs based on templates.
Procedure UpdateQueueJobsByTemplates(Parameters = Undefined) Export
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	If Parameters = Undefined Then
		Parameters = New Structure;
		Parameters.Insert("ExclusiveMode", True);
	EndIf;
	
	LaunchInExclusiveMode = Parameters.ExclusiveMode;
	
	Lock = New DataLock;
	Lock.Add("Catalog.DataAreaJobQueue");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		TemplateChanges = UpdateQueueJobTemplates(Parameters);
		If NOT LaunchInExclusiveMode 
			AND Parameters.ExclusiveMode Then
			
			RollbackTransaction();
			Return;
		EndIf;
		
		If TemplateChanges.Deleted.Count() > 0
			OR TemplateChanges.AddedEdited.Count() > 0 Then
			
			// Deleting jobs based on deleted templates.
			Query = New Query(
			"SELECT
			|	PositionInQueue.Ref
			|FROM
			|	Catalog.DataAreaJobQueue AS PositionInQueue
			|WHERE
			|	PositionInQueue.Template IN(&DeletedTemplates)");
			Query.SetParameter("DeletedTemplates", TemplateChanges.Deleted);
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				Job = Selection.Ref.GetObject();
				Job.DataExchange.Load = True;
				Job.Delete();
				
			EndDo;
			
			// Adding jobs based on added templates.
			AddedEdited = TemplateChanges.AddedEdited;
			
			Query = New Query(
			"SELECT
			|	Areas.DataAreaAuxiliaryData AS DataArea,
			|	PositionInQueue.Ref AS ID,
			|	Templates.Ref AS Template,
			|	ISNULL(PositionInQueue.LastRunStartDate, DATETIME(1, 1, 1)) AS LastRunStartDate,
			|	TimeZones.Value AS TimeZone
			|FROM
			|	InformationRegister.DataAreas AS Areas
			|		INNER JOIN Catalog.QueueJobTemplates AS Templates
			|		ON (Templates.Ref IN (&AddedChangedTemplates))
			|			AND (Areas.Status = VALUE(Enum.DataAreaStatuses.Used))
			|		LEFT JOIN Catalog.DataAreaJobQueue AS PositionInQueue
			|		ON Areas.DataAreaAuxiliaryData = PositionInQueue.DataAreaAuxiliaryData
			|			AND (Templates.Ref = PositionInQueue.Template)
			|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
			|		ON Areas.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData");
			Query.SetParameter("AddedChangedTemplates", AddedEdited.UnloadColumn("Ref"));
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				
				TemplateRow = AddedEdited.Find(Selection.Template, "Ref");
				If TemplateRow = Undefined Then
					MessageTemplate = NStr("ru = 'При обновлении не найден шаблон задания %1'; en = 'Job template %1 not found when updating'; pl = 'Podczas aktualizacji nie znaleziono szablonu zadania %1';es_ES = 'Modelo de la tarea %1 no se ha encontrado al actualizar';es_CO = 'Modelo de la tarea %1 no se ha encontrado al actualizar';tr = 'Güncelleme sırasında iş şablonu %1 bulunamadı';it = 'Modello di task %1 non trovato durante l''aggiornamento';de = 'Die Jobvorlage %1 wurde beim Aktualisieren nicht gefunden'");
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, Selection.Ref);
					Raise(MessageText);
				EndIf;
				
				If ValueIsFilled(Selection.ID) Then
					Job = Selection.ID.GetObject();
				Else
					
					Job = Catalogs.DataAreaJobQueue.CreateItem();
					Job.Template = Selection.Template;
					Job.DataAreaAuxiliaryData = Selection.DataArea;
					
				EndIf;
				
				Job.Use = TemplateRow.Use;
				Job.Key = TemplateRow.Key;
				
				Job.ScheduledStartTime = 
					JobQueueInternal.GetScheduledJobStartTime(
						TemplateRow.Schedule,
						Selection.TimeZone,
						Selection.LastRunStartDate);
						
				If ValueIsFilled(Job.ScheduledStartTime) Then
					Job.JobState = Enums.JobsStates.Scheduled;
				Else
					Job.JobState = Enums.JobsStates.NotScheduled;
				EndIf;
				
				Job.Write();
				
			EndDo;
		
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Update handler, moves jobs from JobQueue information register to DataAreaJobQueue catalog.
Procedure MoveQueueJobsToAuxiliaryData() Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		CatalogLock = Lock.Add("Catalog.DataAreaJobQueue");
		Lock.Lock();
		
		QueryText = 
		"SELECT
		|	DeleteJobQueue.DataArea,
		|	DeleteJobQueue.Use,
		|	DeleteJobQueue.ScheduledStartTime,
		|	DeleteJobQueue.JobState,
		|	DeleteJobQueue.ActiveBackgroundJob,
		|	DeleteJobQueue.ExclusiveExecution,
		|	DeleteJobQueue.Template,
		|	DeleteJobQueue.AttemptNumber,
		|	DeleteJobQueue.DeleteScheduledJob,
		|	DeleteJobQueue.MethodName,
		|	DeleteJobQueue.Parameters,
		|	DeleteJobQueue.LastRunStartDate,
		|	DeleteJobQueue.Key,
		|	DeleteJobQueue.RestartIntervalOnFailure,
		|	DeleteJobQueue.Schedule,
		|	DeleteJobQueue.RestartCountOnFailure,
		|	DeleteJobQueue.ID
		|FROM
		|	InformationRegister.DeleteJobQueue AS DeleteJobQueue
		|WHERE
		|	DeleteJobQueue.DataArea <> -1
		|	AND DeleteJobQueue.DeleteScheduledJob = &BlankID";
		Query = New Query(QueryText);
		Query.SetParameter("BlankID", New UUID("00000000-0000-0000-0000-000000000000"));
		Selection = Query.Execute().Select();
		While Selection.Next() Do
			
			JobRef = Catalogs.DataAreaJobQueue.GetRef(
				New UUID(Selection.ID));
			
			If Common.RefExists(JobRef) Then
				NewJob = JobRef.GetObject();
			Else
				NewJob = Catalogs.DataAreaJobQueue.CreateItem();
			EndIf;
			
			FillPropertyValues(NewJob, Selection);
			NewJob.DataAreaAuxiliaryData = Selection.DataArea;
			NewJob.Write();
			
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Creates jobs by templates in the current data area.
Procedure CreateQueueJobsByTemplatesInCurrentArea() Export
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		Lock.Add("Catalog.DataAreaJobQueue");
		Lock.Lock();
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	PositionInQueue.Ref AS ID,
		|	Templates.Ref AS Template,
		|	ISNULL(PositionInQueue.LastRunStartDate, DATETIME(1, 1, 1)) AS LastRunStartDate,
		|	TimeZones.Value AS TimeZone,
		|	Templates.Schedule AS Schedule,
		|	Templates.Use AS Use,
		|	Templates.Key AS Key
		|FROM
		|	Catalog.QueueJobTemplates AS Templates
		|		LEFT JOIN Catalog.DataAreaJobQueue AS PositionInQueue
		|		ON Templates.Ref = PositionInQueue.Template
		|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
		|		ON (TRUE)";
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			
			If ValueIsFilled(Selection.ID) Then
				Job = Selection.ID.GetObject();
			Else
				Job = Catalogs.DataAreaJobQueue.CreateItem();
				Job.Template = Selection.Template;
			EndIf;
			
			Job.Use = Selection.Use;
			Job.Key = Selection.Key;
			Job.ScheduledStartTime = 
				JobQueueInternal.GetScheduledJobStartTime(Selection.Schedule.Get(), 
					Selection.TimeZone, 
					Selection.LastRunStartDate);
					
			If ValueIsFilled(Job.ScheduledStartTime) Then
				Job.JobState = Enums.JobsStates.Scheduled;
			Else
				Job.JobState = Enums.JobsStates.NotScheduled;
			EndIf;
			
			Job.Write();
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	If Not SaaSCached.IsSeparatedConfiguration() Then
		Return;
	EndIf;
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Procedure = "JobQueueInternalDataSeparation.CreateQueueJobsByTemplatesInCurrentArea";
	Handler.ExclusiveMode = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 98;
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.Procedure = "JobQueueInternalDataSeparation.UpdateQueueJobsByTemplates";
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	Handler.Priority = 63;
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.9";
	Handler.Procedure = "JobQueueInternalDataSeparation.MoveQueueJobsToAuxiliaryData";
	Handler.SharedData = True;
	Handler.ExclusiveMode = True;
	Handler.ExecuteInMandatoryGroup = True;
	Handler.Priority = 80;
	
EndProcedure

// See SaaSOverridable.OnEnableDataSeparation. 
Procedure OnEnableSeparationByDataAreas() Export
	
	UpdateQueueJobsByTemplates();
	
EndProcedure

// See ExportImportDataOverridable.AfterDataImport. 
Procedure AfterImportData(Container) Export
	
	CreateQueueJobsByTemplatesInCurrentArea();
	
	// Determine usage of a scheduled job only after the queue jobs are created.
	If Common.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		
		ModuleScheduledJobsInternal = Common.CommonModule("ScheduledJobsInternal");
		ModuleScheduledJobsInternal.SetScheduledJobsUsageByFunctionalOptions(True);
		
	EndIf;
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.Catalogs.DataAreaJobQueue);
	
EndProcedure

#EndRegion

#Region Private

// Fills the QueueJobTemplates catalog with a list of scheduled jobs used as templates for queue 
// jobs, and clears the Usage flag for these jobs.
// 
//
// Returns:
//  Structure - templates that were added or deleted during update, keys:
//   AddedChanged - ValueTable, columns:
//    Ref - CatalogRef.QueueJobTemplates - template reference.
//      Reference ID is identical to scheduled job ID.
//    Usage - Boolean - job usage flag.
//    Schedule    - JobSchedule - a job schedule.
//
//   Deleted - Value array UUID - added template IDs.
//       
// 
Function UpdateQueueJobTemplates(Parameters)
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return New Structure("Added, Deleted", New Array, New Array);
	EndIf;
	
	Lock = New DataLock;
	Lock.Add("Catalog.QueueJobTemplates");
	
	BeginTransaction();
	Try
		Lock.Lock();
		
		TemplateTable = New ValueTable;
		TemplateTable.Columns.Add("Ref", New TypeDescription("CatalogRef.QueueJobTemplates"));
		TemplateTable.Columns.Add("Use", New TypeDescription("Boolean"));
		TemplateTable.Columns.Add("MethodName", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		TemplateTable.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		TemplateTable.Columns.Add("RestartCountOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TemplateTable.Columns.Add("RestartIntervalOnFailure", New TypeDescription("Number", New NumberQualifiers(10, 0)));
		TemplateTable.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		TemplateTable.Columns.Add("Presentation", New TypeDescription("String", , New StringQualifiers(150, AllowedLength.Variable)));
		TemplateTable.Columns.Add("Name", New TypeDescription("String", , New StringQualifiers(255, AllowedLength.Variable)));
		
		TemplateNames = JobQueue.QueueJobTemplates();
		
		Jobs = ScheduledJobs.GetScheduledJobs();
		For Each Job In Jobs Do
			If TemplateNames.Find(Job.Metadata.Name) <> Undefined Then
				NewRow = TemplateTable.Add();
				NewRow.Ref = Catalogs.QueueJobTemplates.GetRef(Job.UUID);
				NewRow.Use = Job.Metadata.Use;
				NewRow.MethodName = Job.Metadata.MethodName;
				NewRow.Key = Job.Metadata.Key;
				NewRow.RestartCountOnFailure = 
					Job.Metadata.RestartCountOnFailure;
				NewRow.RestartIntervalOnFailure = 
					Job.Metadata.RestartIntervalOnFailure;
				NewRow.Schedule = Job.Schedule;
				NewRow.Presentation = Job.Metadata.Presentation();
				NewRow.Name = Job.Metadata.Name;
				
				If NOT Parameters.ExclusiveMode
					AND Job.Use Then
					
					Parameters.ExclusiveMode = True;
					
					RollbackTransaction();
					
					Return Undefined;
				EndIf;
				
				Job.Use = False;
				Job.Write();
			EndIf;
		EndDo;
		
		DeletedTemplates = New Array;
		AddedChangedTemplates = New ValueTable;
		AddedChangedTemplates.Columns.Add("Ref", New TypeDescription("CatalogRef.QueueJobTemplates"));
		AddedChangedTemplates.Columns.Add("Use", New TypeDescription("Boolean"));
		AddedChangedTemplates.Columns.Add("Key", New TypeDescription("String", , New StringQualifiers(128, AllowedLength.Variable)));
		AddedChangedTemplates.Columns.Add("Schedule", New TypeDescription("JobSchedule"));
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	QueueJobTemplates.Ref AS Ref,
		|	QueueJobTemplates.Use,
		|	QueueJobTemplates.Key,
		|	QueueJobTemplates.Schedule
		|FROM
		|	Catalog.QueueJobTemplates AS QueueJobTemplates";
		InitialTemplateTable = Query.Execute().Unload();
		
		// Managing added / changed templates.
		For each TableRow In TemplateTable Do
			
			TemplateChanged = False;
			
			InitialTemplateString = InitialTemplateTable.Find(TableRow.Ref, "Ref");
			If InitialTemplateString = Undefined
				OR TableRow.Use <> InitialTemplateString.Use
				OR TableRow.Key <> InitialTemplateString.Key
				OR NOT CommonClientServer.SchedulesAreIdentical(TableRow.Schedule, 
					InitialTemplateString.Schedule.Get()) Then
					
				ChangedRow = AddedChangedTemplates.Add();
				ChangedRow.Ref = TableRow.Ref;
				ChangedRow.Use = TableRow.Use;
				ChangedRow.Key = TableRow.Key;
				ChangedRow.Schedule = TableRow.Schedule;
				
				TemplateChanged = True;
				
			EndIf;
			
			If InitialTemplateString = Undefined Then
				Template = Catalogs.QueueJobTemplates.CreateItem();
				Template.SetNewObjectRef(TableRow.Ref);
			Else
				Template = TableRow.Ref.GetObject();
				InitialTemplateTable.Delete(InitialTemplateString);
			EndIf;
			
			If TemplateChanged
				OR Template.Description <> TableRow.Presentation
				OR Template.MethodName <> TableRow.MethodName
				OR Template.RestartCountOnFailure <> TableRow.RestartCountOnFailure
				OR Template.RestartIntervalOnFailure <> TableRow.RestartIntervalOnFailure
				OR Template.Name <> TableRow.Name Then
				
				If NOT Parameters.ExclusiveMode Then
					Parameters.ExclusiveMode = True;
					RollbackTransaction();
					Return Undefined;
				EndIf;
				
				Template.Description = TableRow.Presentation;
				Template.Use = TableRow.Use;
				Template.MethodName = TableRow.MethodName;
				Template.Key = TableRow.Key;
				Template.RestartCountOnFailure = TableRow.RestartCountOnFailure;
				Template.RestartIntervalOnFailure = TableRow.RestartIntervalOnFailure;
				Template.Schedule = New ValueStorage(TableRow.Schedule);
				Template.Name = TableRow.Name;
				Template.Write();
			EndIf;
			
		EndDo;
		
		// Managing deleted templates.
		For each InitialTemplateString In InitialTemplateTable Do
			If NOT Parameters.ExclusiveMode Then
				Parameters.ExclusiveMode = True;
				RollbackTransaction();
				Return Undefined;
			EndIf;
			
			Template = InitialTemplateString.Ref.GetObject();
			Template.DataExchange.Load = True;
			Template.Delete();
			
			DeletedTemplates.Add(InitialTemplateString.Ref);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	Return New Structure("AddedEdited, Deleted", AddedChangedTemplates, DeletedTemplates);
	
EndFunction

#EndRegion
