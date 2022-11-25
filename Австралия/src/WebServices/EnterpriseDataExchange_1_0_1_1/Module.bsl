#Region Private
////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

Function Ping()
	Return "";
EndFunction

Function ConnectionTest(ExchangePlanName, ExchangePlanNodeCode, ErrorMessage)
	
	ErrorMessage = "";
	
	// Checking that the infobase is not the file one.
	If Common.FileInfobase() Then
		ErrorMessage = NStr("ru = 'The infobase is the file base,
			|so web service methods are not supported.'; 
			|en = 'The infobase is the file base,
			|so web service methods are not supported.'; 
			|pl = 'The infobase is the file base,
			|so web service methods are not supported.';
			|es_ES = 'The infobase is the file base,
			|so web service methods are not supported.';
			|es_CO = 'The infobase is the file base,
			|so web service methods are not supported.';
			|tr = 'The infobase is the file base,
			|so web service methods are not supported.';
			|it = 'The infobase is the file base,
			|so web service methods are not supported.';
			|de = 'The infobase is the file base,
			|so web service methods are not supported.'");
		Return False;
	EndIf;
	
	// Checking whether a user has rights to perform the data exchange.
	Try
		DataExchangeInternal.CheckCanSynchronizeData();
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	// Checking whether the infobase is locked for updating.
	Try
		DataExchangeInternal.CheckInfobaseLockForUpdate();
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Return False;
	EndTry;
	
	SetPrivilegedMode(True);
	
	// Checking whether the exchange plan node exists (it might be deleted.
	If ExchangePlans[ExchangePlanName].FindByCode(ExchangePlanNodeCode).IsEmpty() Then
		ErrorMessage = NStr("ru = 'Presetting not foung. Please contact with application administrator'; en = 'Presetting not foung. Please contact with application administrator'; pl = 'Presetting not foung. Please contact with application administrator';es_ES = 'Presetting not foung. Please contact with application administrator';es_CO = 'Presetting not foung. Please contact with application administrator';tr = 'Presetting not foung. Please contact with application administrator';it = 'Presetting not foung. Please contact with application administrator';de = 'Presetting not foung. Please contact with application administrator'");
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

Function ConfirmDataExported(FileID, ConfirmFileReceipt, ErrorMessage)
	
	ErrorMessage = "";
	
	Try
		DeleteFiles(DataExchangeInternal.TemporaryExportDirectory(FileID));
	Except
		
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
			
	EndTry;
		
EndFunction

Function GetDataImportResult(BackgroundJobID, ErrorMessage)
	Return DataExchangeInternal.GetDataReceiptExecutionStatus(BackgroundJobID, ErrorMessage);
EndFunction

Function GetPrepareDataToExportResult(BackgroundJobID, ErrorMessage)
	Return DataExchangeInternal.GetExecutionStatusOfPreparingDataForSending(BackgroundJobID, ErrorMessage);
EndFunction

Function ImportFilePart(FileID, ImportedFilePartNumber, ImportedFilePart, ErrorMessage)
	DataExchangeInternal.ImportFilePart(FileID, ImportedFilePartNumber, ImportedFilePart, ErrorMessage);
EndFunction

Function ExportFilePart(FileID, ExportedFilePartNumber, ErrorMessage)
	Return DataExchangeInternal.ExportFilePart(FileID, ExportedFilePartNumber, ErrorMessage);
EndFunction

Function ImportDataToInfobase(ExchangePlanName, ExchangePlanNodeCode, FileID, BackgroundJobID, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.ExchangePlanName                         = ExchangePlanName;
	ParametersStructure.ExchangePlanNodeCode                     = ExchangePlanNodeCode;
	ParametersStructure.TempStorageFileID = DataExchangeInternal.PrepareFileForImport(FileID, ErrorMessage);
	ParametersStructure.WEBServiceName                          = "EnterpriseDataExchange_1_0_1_1";
	
	// Importing data to the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Import data into the infobase through web service ""Enterprise Data Exchange""'; en = 'Import data into the infobase through web service ""Enterprise Data Exchange""'; pl = 'Import data into the infobase through web service ""Enterprise Data Exchange""';es_ES = 'Import data into the infobase through web service ""Enterprise Data Exchange""';es_CO = 'Import data into the infobase through web service ""Enterprise Data Exchange""';tr = 'Import data into the infobase through web service ""Enterprise Data Exchange""';it = 'Import data into the infobase through web service ""Enterprise Data Exchange""';de = 'Import data into the infobase through web service ""Enterprise Data Exchange""'");
	ExecutionParameters.BackgroundJobKey = String(New UUID);
	
	ExecutionParameters.RunInBackground = True;

	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeInternal.ImportXDTODateToInfobase",
		ProcedureParameters,
		ExecutionParameters);
	BackgroundJobID = String(BackgroundJob.JobID);
	
EndFunction

Function PrepareDataToImport(ExchangePlanName, ExchangePlanNodeCode, FilePartSize, BackgroundJobID, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.ExchangePlanName                         = ExchangePlanName;
	ParametersStructure.ExchangePlanNodeCode                     = ExchangePlanNodeCode;
	ParametersStructure.FilePartSize                       = FilePartSize;
	ParametersStructure.TempStorageFileID = New UUID();
	ParametersStructure.WEBServiceName                          = "EnterpriseDataExchange_1_0_1_1";
	
	// Preparing data to export from the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""'; en = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""'; pl = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""';es_ES = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""';es_CO = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""';tr = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""';it = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""';de = 'Preparing data export from infobase via web service ""Enterprise Data Exchange""'");
	ExecutionParameters.BackgroundJobKey = String(New UUID);
	
	ExecutionParameters.RunInBackground = True;

	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeInternal.PrepareDataForExportFromInfobase",
		ProcedureParameters,
		ExecutionParameters);
	BackgroundJobID = String(BackgroundJob.JobID);
	
EndFunction

#EndRegion