
#Region Private

////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

// Matches the Upload web service operation.
Function ExecuteExport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	ExchangeMessage = "";
	
	DataExchangeServer.ExportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessage);
	
	ExchangeMessageStorage = New ValueStorage(ExchangeMessage, New Deflation(9));
	
EndFunction

// Matches the Download web service operation.
Function ExecuteImport(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.ImportForInfobaseNodeViaString(ExchangePlanName, InfobaseNodeCode, ExchangeMessageStorage.Get());
	
EndFunction

// Matches the UploadData web service operation.
Function RunDataExport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID;
	FileIDAsString = String(FileID);
	ExecuteDataExportInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);
	
EndFunction

// Matches the DownloadData web service operation.
Function RunDataImport(ExchangePlanName,
								InfobaseNodeCode,
								FileIDAsString,
								TimeConsumingOperation,
								OperationID,
								TimeConsumingOperationAllowed)
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	FileID = New UUID(FileIDAsString);
	RunImportDataInClientServerMode(ExchangePlanName, InfobaseNodeCode, FileID, TimeConsumingOperation, OperationID, TimeConsumingOperationAllowed);
	
EndFunction

// Matches the GetInfobaseParameters web service operation.
Function GetInfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage)
	
	Result = DataExchangeServer.InfobaseParameters(ExchangePlanName, NodeCode, ErrorMessage);
	Return XDTOSerializer.WriteXDTO(Result);
	
EndFunction

// Matches the CreateExchangeNode web service operation.
Function CreateDataExchangeNode(XDTOParameters)
	
	DataExchangeServer.CheckDataExchangeUsage(True);
	
	Parameters = XDTOSerializer.ReadXDTO(XDTOParameters);
	
	ConnectionSettings = Parameters.ConnectionSettings;
	XMLParametersString  = Parameters.XMLParametersString;
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	Try
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(
			ConnectionSettings, Parameters.XMLParametersString);
			
		ModuleSetupWizard.ConfigureDataExchange(
			ConnectionSettings);
	Except
		ErrorMessage = DetailErrorDescription(ErrorInfo());
			
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , ErrorMessage);
			
		Raise ErrorMessage;
	EndTry;
	
EndFunction

// Matches the RemoveExchangeNode web service operation.
Function DeleteDataExchangeNode(ExchangePlanName, NodeID)
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'; en = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'; pl = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';es_ES = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';es_CO = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';tr = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';it = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';de = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'"),
			ApplicationPresentation, ExchangePlanName, NodeID);
	EndIf;
	
	DataExchangeServer.DeleteSynchronizationSetting(ExchangeNode);
	
EndFunction

// Matches the GetLongActionState web service operation.
Function GetTimeConsumingOperationState(OperationID, ErrorMessageString)
	
	BackgroundJobStates = New Map;
	BackgroundJobStates.Insert(BackgroundJobState.Active,           "Active");
	BackgroundJobStates.Insert(BackgroundJobState.Completed,         "Completed");
	BackgroundJobStates.Insert(BackgroundJobState.Failed, "Failed");
	BackgroundJobStates.Insert(BackgroundJobState.Canceled,          "Canceled");
	
	SetPrivilegedMode(True);
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(OperationID));
	
	If BackgroundJob.ErrorInfo <> Undefined Then
		
		ErrorMessageString = DetailErrorDescription(BackgroundJob.ErrorInfo);
		
	EndIf;
	
	Return BackgroundJobStates.Get(BackgroundJob.State);
EndFunction

// Matches the PrepareGetFile web service operation.
Function PrepareGetFile(FileId, BlockSize, TransferId, PartQuantity)
	
	SetPrivilegedMode(True);
	
	TransferId = New UUID;
	
	InitialFileName = DataExchangeServer.GetFileFromStorage(FileId);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	File = New File(InitialFileName);
	
	SourceFileNameInTemporaryDirectory = CommonClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	CreateDirectory(TemporaryDirectory);
	
	MoveFile(InitialFileName, SourceFileNameInTemporaryDirectory);
	
	If BlockSize <> 0 Then
		// Splitting file into volumes
		FileNames = SplitFile(SourceFileNameInTemporaryDirectory, BlockSize * 1024);
		PartQuantity = FileNames.Count();
		
		DeleteFiles(SourceFileNameInTemporaryDirectory);
	Else
		PartQuantity = 1;
		MoveFile(SourceFileNameInTemporaryDirectory, SourceFileNameInTemporaryDirectory + ".1");
	EndIf;
	
EndFunction

// Matches the GetFilePart web service operation.
Function GetFilePart(TransferId, PartNumber, PartData)
	
	FileNames = FindPartFile(TemporaryExportDirectory(TransferId), PartNumber);
	
	If FileNames.Count() = 0 Then
		
		MessageTemplate = NStr("ru = 'Volume %1 is not found in the transfer session with the following ID: %2'; en = 'Volume %1 is not found in the transfer session with the following ID: %2'; pl = 'Volume %1 is not found in the transfer session with the following ID: %2';es_ES = 'Volume %1 is not found in the transfer session with the following ID: %2';es_CO = 'Volume %1 is not found in the transfer session with the following ID: %2';tr = 'Volume %1 is not found in the transfer session with the following ID: %2';it = 'Volume %1 is not found in the transfer session with the following ID: %2';de = 'Volume %1 is not found in the transfer session with the following ID: %2'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	ElsIf FileNames.Count() > 1 Then
		
		MessageTemplate = NStr("ru = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2'; en = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2'; pl = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2';es_ES = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2';es_CO = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2';tr = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2';it = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2';de = 'Multiple instances of volume %1 are found in the transfer session with the following ID: %2'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
		Raise(MessageText);
		
	EndIf;
	
	FileNamePart = FileNames[0].FullName;
	PartData = New BinaryData(FileNamePart);
	
EndFunction

// Matches the ReleaseFile web service operation.
Function ReleaseFile(TransferId)
	
	Try
		DeleteFiles(TemporaryExportDirectory(TransferId));
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Matches the PutFilePart web service operation.
Function PutFilePart(TransferId, PartNumber, PartData)
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	If PartNumber = 1 Then
		
		CreateDirectory(TemporaryDirectory);
		
	EndIf;
	
	FileName = CommonClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
	
	PartData.Write(FileName);
	
EndFunction

// Matches the SaveFileFromParts web service operation.
Function SaveFileFromParts(TransferId, PartQuantity, FileId)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = TemporaryExportDirectory(TransferId);
	
	PartFilesToMerge = New Array;
	
	For PartNumber = 1 To PartQuantity Do
		
		FileName = CommonClientServer.GetFullFileName(TemporaryDirectory, GetPartFileName(PartNumber));
		
		If FindFiles(FileName).Count() = 0 Then
			MessageTemplate = NStr("ru = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.'; 
					|en = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.'; 
					|pl = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';
					|es_ES = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';
					|es_CO = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';
					|tr = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';
					|it = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.';
					|de = 'Fragment %1 of the transfer session with ID %2 is not found. 
					|Make sure that the ""Directory of temporary files for Linux""
					| and ""Directory of temporary files for Windows"" parameters are specified in the application settings.'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(PartNumber), String(TransferId));
			Raise(MessageText);
		EndIf;
		
		PartFilesToMerge.Add(FileName);
		
	EndDo;
	
	ArchiveName = CommonClientServer.GetFullFileName(TemporaryDirectory, "data.zip");
	
	MergeFiles(PartFilesToMerge, ArchiveName);
	
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		Try
			DeleteFiles(TemporaryDirectory);
		Except
			WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		EndTry;
		Raise(NStr("ru = 'The archive file does not contain data.'; en = 'The archive file does not contain data.'; pl = 'The archive file does not contain data.';es_ES = 'The archive file does not contain data.';es_CO = 'The archive file does not contain data.';tr = 'The archive file does not contain data.';it = 'The archive file does not contain data.';de = 'The archive file does not contain data.'"));
	EndIf;
	
	DumpDirectory = DataExchangeCached.TempFilesStorageDirectory();
	
	FileName = CommonClientServer.GetFullFileName(DumpDirectory, Dearchiver.Items[0].Name);
	
	Dearchiver.Extract(Dearchiver.Items[0], DumpDirectory);
	Dearchiver.Close();
	
	FileId = DataExchangeServer.PutFileInStorage(FileName);
	
	Try
		DeleteFiles(TemporaryDirectory);
	Except
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
EndFunction

// Matches the PutMessageForDataMatching web service operation.
Function PutMessageForDataMatching(ExchangePlanName, NodeID, FileID)
	
	ExchangeNode = DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeID);
		
	If ExchangeNode = Undefined Then
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'; en = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'; pl = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';es_ES = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';es_CO = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';tr = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';it = 'Exchange plan node ""%2"" with ID %3 was not found in %1.';de = 'Exchange plan node ""%2"" with ID %3 was not found in %1.'"),
			ApplicationPresentation, ExchangePlanName, NodeID);
	EndIf;
	
	CheckInfobaseLockForUpdate();
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	DataExchangeInternal.PutMessageForDataMapping(ExchangeNode, FileID);
	
EndFunction

// Matches the Ping web service operation.
Function Ping()
	// Testing connection.
	Return "";
EndFunction

// Matches the TestConnection web service operation.
Function TestConnection(ExchangePlanName, NodeCode, Result)
	
	// Checking whether a user has rights to perform the data exchange.
	Try
		DataExchangeServer.CheckCanSynchronizeData(True);
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Checking whether the infobase is locked for updating.
	Try
		CheckInfobaseLockForUpdate();
	Except
		Result = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	SetPrivilegedMode(True);
	
	// Checking whether the exchange plan node exists (it might be deleted.
	If DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName, NodeCode) = Undefined Then
		
		ApplicationPresentation = ?(Common.DataSeparationEnabled(),
			Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
			
		ExchangePlanPresentation = Metadata.ExchangePlans[ExchangePlanName].Presentation();
			
		Result = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Data synchronization line ""%2"" with ID %3 was not found in %1.'; en = 'Data synchronization line ""%2"" with ID %3 was not found in %1.'; pl = 'Data synchronization line ""%2"" with ID %3 was not found in %1.';es_ES = 'Data synchronization line ""%2"" with ID %3 was not found in %1.';es_CO = 'Data synchronization line ""%2"" with ID %3 was not found in %1.';tr = 'Data synchronization line ""%2"" with ID %3 was not found in %1.';it = 'Data synchronization line ""%2"" with ID %3 was not found in %1.';de = 'Data synchronization line ""%2"" with ID %3 was not found in %1.'"),
			ApplicationPresentation, ExchangePlanPresentation, NodeCode);
		
		Return False;
	EndIf;
	
	Return True;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Procedure CheckInfobaseLockForUpdate()
	
	If ValueIsFilled(InfobaseUpdateInternal.InfobaseLockedForUpdate()) Then
		
		Raise NStr("ru = 'Data synchronization is unavailable for the duration of Internet-based update.'; en = 'Data synchronization is unavailable for the duration of Internet-based update.'; pl = 'Data synchronization is unavailable for the duration of Internet-based update.';es_ES = 'Data synchronization is unavailable for the duration of Internet-based update.';es_CO = 'Data synchronization is unavailable for the duration of Internet-based update.';tr = 'Data synchronization is unavailable for the duration of Internet-based update.';it = 'Data synchronization is unavailable for the duration of Internet-based update.';de = 'Data synchronization is unavailable for the duration of Internet-based update.'");
		
	EndIf;
	
EndProcedure

Procedure ExecuteDataExportInClientServerMode(ExchangePlanName,
														InfobaseNodeCode,
														FileID,
														TimeConsumingOperation,
														OperationID,
														TimeConsumingOperationAllowed)
	
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName,
		InfobaseNodeCode,
		NStr("ru = 'DataExported'; en = 'DataExported'; pl = 'DataExported';es_ES = 'DataExported';es_CO = 'DataExported';tr = 'DataExported';it = 'DataExported';de = 'DataExported'"));
	
	If HasActiveDataSynchronizationBackgroundTasks(BackgroundJobKey) Then
		Raise NStr("ru = 'Data synchronization is already running.'; en = 'Data synchronization is already running.'; pl = 'Data synchronization is already running.';es_ES = 'Data synchronization is already running.';es_CO = 'Data synchronization is already running.';tr = 'Data synchronization is already running.';it = 'Data synchronization is already running.';de = 'Data synchronization is already running.'");
	EndIf;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ExchangePlanName", ExchangePlanName);
	ProcedureParameters.Insert("InfobaseNodeCode", InfobaseNodeCode);
	ProcedureParameters.Insert("FileID", FileID);
	ProcedureParameters.Insert("UseCompression", True);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Export data via web service.'; en = 'Export data via web service.'; pl = 'Export data via web service.';es_ES = 'Export data via web service.';es_CO = 'Export data via web service.';tr = 'Export data via web service.';it = 'Export data via web service.';de = 'Export data via web service.'");
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	
	ExecutionParameters.RunNotInBackground = Not TimeConsumingOperationAllowed;
	ExecutionParameters.RunInBackground   = TimeConsumingOperationAllowed;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeServer.ExportToFileTransferServiceForInfobaseNode",
		ProcedureParameters,
		ExecutionParameters);
		
	If BackgroundJob.Status = "Running" Then
		OperationID = String(BackgroundJob.JobID);
		TimeConsumingOperation = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed" Then
		TimeConsumingOperation = False;
		Return;
	Else
		Message = NStr("ru = 'An error occurred during the data export through the web service.'; en = 'An error occurred during the data export through the web service.'; pl = 'An error occurred during the data export through the web service.';es_ES = 'An error occurred during the data export through the web service.';es_CO = 'An error occurred during the data export through the web service.';tr = 'An error occurred during the data export through the web service.';it = 'An error occurred during the data export through the web service.';de = 'An error occurred during the data export through the web service.'");
		If ValueIsFilled(BackgroundJob.DetailedErrorPresentation) Then
			Message = BackgroundJob.DetailedErrorPresentation;
		EndIf;
		
		WriteLogEvent(DataExchangeServer.EventLogEventExportDataToFilesTransferService(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
EndProcedure

Procedure RunImportDataInClientServerMode(ExchangePlanName,
													InfobaseNodeCode,
													FileID,
													TimeConsumingOperation,
													OperationID,
													TimeConsumingOperationAllowed)
	
													
	BackgroundJobKey = ExportImportDataBackgroundJobKey(ExchangePlanName,
		InfobaseNodeCode,
		NStr("ru = 'Import'; en = 'Import'; pl = 'Import';es_ES = 'Import';es_CO = 'Import';tr = 'Import';it = 'Import';de = 'Import'"));
	
	If HasActiveDataSynchronizationBackgroundTasks(BackgroundJobKey) Then
		Raise NStr("ru = 'Data synchronization is already running.'; en = 'Data synchronization is already running.'; pl = 'Data synchronization is already running.';es_ES = 'Data synchronization is already running.';es_CO = 'Data synchronization is already running.';tr = 'Data synchronization is already running.';it = 'Data synchronization is already running.';de = 'Data synchronization is already running.'");
	EndIf;
	
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ExchangePlanName", ExchangePlanName);
	ProcedureParameters.Insert("InfobaseNodeCode", InfobaseNodeCode);
	ProcedureParameters.Insert("FileID", FileID);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Import data via web service.'; en = 'Import data via web service.'; pl = 'Import data via web service.';es_ES = 'Import data via web service.';es_CO = 'Import data via web service.';tr = 'Import data via web service.';it = 'Import data via web service.';de = 'Import data via web service.'");
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	
	ExecutionParameters.RunNotInBackground = Not TimeConsumingOperationAllowed;
	ExecutionParameters.RunInBackground   = TimeConsumingOperationAllowed;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeServer.ImportFromFileTransferServiceForInfobaseNode",
		ProcedureParameters,
		ExecutionParameters);
		
	If BackgroundJob.Status = "Running" Then
		OperationID = String(BackgroundJob.JobID);
		TimeConsumingOperation = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed" Then
		TimeConsumingOperation = False;
		Return;
	Else
		
		Message = NStr("ru = 'An error occurred during the data import through the web service.'; en = 'An error occurred during the data import through the web service.'; pl = 'An error occurred during the data import through the web service.';es_ES = 'An error occurred during the data import through the web service.';es_CO = 'An error occurred during the data import through the web service.';tr = 'An error occurred during the data import through the web service.';it = 'An error occurred during the data import through the web service.';de = 'An error occurred during the data import through the web service.'");
		If ValueIsFilled(BackgroundJob.DetailedErrorPresentation) Then
			Message = BackgroundJob.DetailedErrorPresentation;
		EndIf;
		
		WriteLogEvent(DataExchangeServer.ExportDataFromFileTransferServiceEventLogEvent(),
			EventLogLevel.Error, , , Message);
		
		Raise Message;
	EndIf;
	
EndProcedure

Function ExportImportDataBackgroundJobKey(ExchangePlan, NodeCode, Action)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'ExchangePlan:%1 NodeCode:%2 Action:%3'; en = 'ExchangePlan:%1 NodeCode:%2 Action:%3'; pl = 'ExchangePlan:%1 NodeCode:%2 Action:%3';es_ES = 'ExchangePlan:%1 NodeCode:%2 Action:%3';es_CO = 'ExchangePlan:%1 NodeCode:%2 Action:%3';tr = 'ExchangePlan:%1 NodeCode:%2 Action:%3';it = 'ExchangePlan:%1 NodeCode:%2 Action:%3';de = 'ExchangePlan:%1 NodeCode:%2 Action:%3'"),
		ExchangePlan,
		NodeCode,
		Action);
	
EndFunction

Function HasActiveDataSynchronizationBackgroundTasks(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key", BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

Function GetPartFileName(PartNumber)
	
	Result = "data.zip.[n]";
	
	Return StrReplace(Result, "[n]", Format(PartNumber, "NG=0"));
EndFunction

Function TemporaryExportDirectory(Val SessionID)
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonClientServer.GetFullFileName(DataExchangeCached.TempFilesStorageDirectory(), TemporaryDirectory);
	
	Return Result;
EndFunction

Function FindPartFile(Val Directory, Val FileNumber)
	
	For DigitCount = NumberDigitsCount(FileNumber) To 5 Do
		
		FormatString = StringFunctionsClientServer.SubstituteParametersToString("ND=%1; NLZ=; NG=0", String(DigitCount));
		
		FileName = StringFunctionsClientServer.SubstituteParametersToString("data.zip.%1", Format(FileNumber, FormatString));
		
		FileNames = FindFiles(Directory, FileName);
		
		If FileNames.Count() > 0 Then
			
			Return FileNames;
			
		EndIf;
		
	EndDo;
	
	Return New Array;
EndFunction

Function NumberDigitsCount(Val Number)
	
	Return StrLen(Format(Number, "NFD=0; NG=0"));
	
EndFunction

#EndRegion
