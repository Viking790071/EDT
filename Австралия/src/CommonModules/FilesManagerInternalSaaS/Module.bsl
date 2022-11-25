#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Text extraction

// Adds and removes records in the TextExtractionQueue information register on change state of file 
// version text extraction.
//
// Parameters:
//	TextSource - CatalogRef.FileVersions, CatalogRef.*AttachedFiles, file with changed text 
//		extraction state.
//	TextExtractionState - EnumRef.FileTextExtractionStatus, new file text extraction status.
//		
//
Procedure UpdateTextExtractionQueueState(TextSource, TextExtractionState) Export
	
	SetPrivilegedMode(True);
	
	RecordSet = InformationRegisters.TextExtractionQueue.CreateRecordSet();
	RecordSet.Filter.DataAreaAuxiliaryData.Set(SaaS.SessionSeparatorValue());
	RecordSet.Filter.TextSource.Set(TextSource);
	
	If TextExtractionState = Enums.FileTextExtractionStatuses.NotExtracted
			OR TextExtractionState = Enums.FileTextExtractionStatuses.EmptyRef() Then
			
		Record = RecordSet.Add();
		Record.DataAreaAuxiliaryData = SaaS.SessionSeparatorValue();
		Record.TextSource = TextSource.Ref;
			
	EndIf;
		
	RecordSet.Write();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See JobQueueOverridable.OnDefineHandlerAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("FilesOperationsInternal.ExtractTextFromFiles");
	NameAndAliasMap.Insert("FilesOperationsInternal.ClearExcessiveFiles");
	NameAndAliasMap.Insert("FilesOperationsInternal.ScheduledFileSynchronizationWebdav");
	
EndProcedure

// See JobQueueOverridable.OnDetermineScheduledJobsUsage. 
Procedure OnDetermineScheduledJobsUsage(UsageTable) Export
	
	NewRow = UsageTable.Add();
	NewRow.ScheduledJob = "TextExtractionPlanningSaaS";
	NewRow.Use       = GetFunctionalOption("UseFullTextSearch");
	
EndProcedure

// See JobQueueOverridable.OnReceiveTemplateList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add("ExcessiveFilesClearing");
	JobTemplates.Add("FileSynchronization");
	
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	Types.Add(Metadata.InformationRegisters.TextExtractionQueue);
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.2.4";
	Handler.Procedure = "FilesManagerInternalSaaS.FillTextExtractionQueue";
	
	Handler = Handlers.Add();
	Handler.Version = "2.1.3.19";
	Handler.Procedure = "FilesManagerInternalSaaS.MoveTextExtractionQueueToAuxiliaryData";
	Handler.SharedData = True;
	
	Handler = Handlers.Add();
	Handler.Version = "2.4.3.89";
	Handler.SharedData = True;
	Handler.Procedure = "FilesManagerInternalSaaS.ClearInformationRegisterDeleteTextExtractionQueue";
	Handler.ExecutionMode = "Seamless";
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Text extraction

// Determines the list of data areas where text extraction is required and plans it using the job 
// queue.
//
Procedure HandleTextExtractionQueue() Export
	
	If NOT SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.TextExtractionPlanningSaaS);
	
	SetPrivilegedMode(True);
	
	SeparatedMethodName = "FilesOperationsInternal.ExtractTextFromFiles";
	
	QueryText = 
	"SELECT DISTINCT
	|	TextExtractionQueue.DataAreaAuxiliaryData AS DataArea,
	|	CASE
	|		WHEN TimeZones.Value = """"
	|			THEN UNDEFINED
	|		ELSE ISNULL(TimeZones.Value, UNDEFINED)
	|	END AS TimeZone
	|FROM
	|	InformationRegister.TextExtractionQueue AS TextExtractionQueue
	|		LEFT JOIN Constant.DataAreaTimeZone AS TimeZones
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = TimeZones.DataAreaAuxiliaryData
	|		LEFT JOIN InformationRegister.DataAreas AS DataAreas
	|		ON TextExtractionQueue.DataAreaAuxiliaryData = DataAreas.DataAreaAuxiliaryData
	|WHERE
	|	NOT TextExtractionQueue.DataAreaAuxiliaryData IN (&DataAreasToProcess)
	|	AND DataAreas.Status = VALUE(Enum.DataAreaStatuses.Used)";
	Query = New Query(QueryText);
	Query.SetParameter("DataAreasToProcess", JobQueue.GetJobs(
		New Structure("MethodName", SeparatedMethodName)));
	
	Selection = SaaS.ExecuteQueryOutsideTransaction(Query).Select();
	While Selection.Next() Do
		// Checking for data area lock.
		If SaaS.DataAreaLocked(Selection.DataArea) Then
			// The area is locked, proceeding to the next record.
			Continue;
		EndIf;
		
		NewJob = New Structure();
		NewJob.Insert("DataArea", Selection.DataArea);
		NewJob.Insert("ScheduledStartTime", ToLocalTime(CurrentUniversalDate(), Selection.TimeZone));
		NewJob.Insert("MethodName", SeparatedMethodName);
		JobQueue.AddJob(NewJob);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Fills text extraction queue for the current data area. Is used for initial filling on refresh.
// 
Procedure FillTextExtractionQueue() Export
	
	If Not SaaSCached.IsSeparatedConfiguration() Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text = FilesOperationsInternal.QueryTextToExtractText(True);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		UpdateTextExtractionQueueState(Selection.Ref,
			Enums.FileTextExtractionStatuses.NotExtracted);
	EndDo;
	
EndProcedure

// Moves the flag indicating the necessity of data area text extraction from the Delete information 
// register to the TextExtractionQueue information register.
//
Procedure MoveTextExtractionQueueToAuxiliaryData() Export
	
	If Not SaaS.DataSeparationEnabled() Then
		Return;
	EndIf;
	
	BeginTransaction();
	
	Try
		
		Lock = New DataLock();
		RegisterLock = Lock.Add("InformationRegister.TextExtractionQueue");
		Lock.Lock();
		
		QueryText =
		"SELECT
		|	ISNULL(TextExtractionQueue.DataAreaAuxiliaryData, DeleteTextExtractionQueue.DataArea) AS DataAreaAuxiliaryData,
		|	ISNULL(TextExtractionQueue.TextSource, DeleteTextExtractionQueue.TextSource) AS TextSource
		|FROM
		|	InformationRegister.DeleteTextExtractionQueue AS DeleteTextExtractionQueue
		|		LEFT JOIN InformationRegister.TextExtractionQueue AS TextExtractionQueue
		|		ON DeleteTextExtractionQueue.DataArea = TextExtractionQueue.DataAreaAuxiliaryData
		|			AND DeleteTextExtractionQueue.TextSource = TextExtractionQueue.TextSource";
		Query = New Query(QueryText);
		
		Set = InformationRegisters.TextExtractionQueue.CreateRecordSet();
		Set.Load(Query.Execute().Unload());
		InfobaseUpdate.WriteData(Set);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

// Deletes records from the DeleteTextExtractionQueue register, if any.
//
Procedure ClearInformationRegisterDeleteTextExtractionQueue() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	DeleteTextExtractionQueue.DataArea
		|FROM
		|	InformationRegister.DeleteTextExtractionQueue AS DeleteTextExtractionQueue";
	
	QueryResult = Query.Execute();
	
	DetailedRecordsSelection = QueryResult.Select();
	
	While DetailedRecordsSelection.Next() Do
		RecordSet = InformationRegisters.DeleteTextExtractionQueue.CreateRecordSet();
		InfobaseUpdate.WriteData(RecordSet);
	EndDo;
	
EndProcedure

#EndRegion
