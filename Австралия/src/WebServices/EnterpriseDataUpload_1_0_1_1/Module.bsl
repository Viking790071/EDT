#Region Private
////////////////////////////////////////////////////////////////////////////////
// Web service operation handlers

Function Ping()
	Return "";
EndFunction

Function ConnectionTest(ErrorMessage)
	
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
	
	Return True;
	
EndFunction

Function GetDataImportResult(BackgroundJobID, ErrorMessage)
	Return DataExchangeInternal.GetDataReceiptExecutionStatus(BackgroundJobID, ErrorMessage);
EndFunction

Function ImportFilePart(FileID, ImportedFilePartNumber, ImportedFilePart, ErrorMessage)
	DataExchangeInternal.ImportFilePart(FileID, ImportedFilePartNumber, ImportedFilePart, ErrorMessage);
EndFunction

Function ImportDataToInfobase(FileID, BackgroundJobID, ErrorMessage)
	
	ErrorMessage = "";
	
	ParametersStructure = DataExchangeInternal.InitializeWebServiceParameters();
	ParametersStructure.TempStorageFileID = DataExchangeInternal.PrepareFileForImport(FileID, ErrorMessage);
	ParametersStructure.WEBServiceName                          = "EnterpriseDataUpload_1_0_1_1";
	
	// Importing to the infobase.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("WebServiceParameters", ParametersStructure);
	ProcedureParameters.Insert("ErrorMessage",   ErrorMessage);

	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = NStr("ru = 'Import data into the infobase through web service ""Enterprise Data Upload""'; en = 'Import data into the infobase through web service ""Enterprise Data Upload""'; pl = 'Import data into the infobase through web service ""Enterprise Data Upload""';es_ES = 'Import data into the infobase through web service ""Enterprise Data Upload""';es_CO = 'Import data into the infobase through web service ""Enterprise Data Upload""';tr = 'Import data into the infobase through web service ""Enterprise Data Upload""';it = 'Import data into the infobase through web service ""Enterprise Data Upload""';de = 'Import data into the infobase through web service ""Enterprise Data Upload""'");
	ExecutionParameters.BackgroundJobKey = String(New UUID);
	
	ExecutionParameters.RunInBackground = True;

	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeInternal.ImportXDTODateToInfobase",
		ProcedureParameters,
		ExecutionParameters);
	BackgroundJobID = String(BackgroundJob.JobID);
	
EndFunction

#EndRegion