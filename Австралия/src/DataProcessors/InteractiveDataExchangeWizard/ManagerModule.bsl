#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// For internal use.
//
Procedure ExecuteAutomaticDataMapping(Parameters, TempStorageAddress) Export
	
	Result = AutomaticDataMappingResult(
		Parameters.InfobaseNode,
		Parameters.ExchangeMessageFileName,
		Parameters.TempExchangeMessageCatalogName,
		Parameters.CheckVersionDifference);
	
	PutToTempStorage(Result, TempStorageAddress);
		
EndProcedure

// For internal use.
// Imports an exchange message from the external source (ftp, email, network directory) to the 
//  temporary directory of the operational system user.
//
Procedure GetExchangeMessageToTemporaryDirectory(Parameters, TempStorageAddress) Export
	
	Cancel = False;
	SetPrivilegedMode(True);
	
	DataStructure = New Structure;
	DataStructure.Insert("TempExchangeMessageCatalogName", "");
	DataStructure.Insert("DataPackageFileID",       Undefined);
	DataStructure.Insert("ExchangeMessageFileName",              "");
	
	If Parameters.EmailReceivedForDataMapping Then
		
		Filter = New Structure("InfobaseNode", Parameters.InfobaseNode);
		CommonSettings = InformationRegisters.CommonInfobasesNodesSettings.Get(Filter);
		
		If ValueIsFilled(CommonSettings.MessageForDataMapping) Then
			TempFileName = DataExchangeServer.GetFileFromStorage(CommonSettings.MessageForDataMapping);
			
			File = New File(TempFileName);
			If File.Exist() AND File.IsFile() Then
				// Placing message information to be mapped back to the storage, in case the data analysis crashes, 
				// to be able to work with the message again.
				DataExchangeServer.PutFileInStorage(TempFileName, CommonSettings.MessageForDataMapping);
				
				DataPackageFileID = File.GetModificationTime();
				
				TempDirectoryNameForExchange = DataExchangeServer.CreateTempExchangeMessageDirectory();
				TempFileNameForExchange    = CommonClientServer.GetFullFileName(
					TempDirectoryNameForExchange, DataExchangeServer.UniqueExchangeMessageFileName());
				
				FileCopy(TempFileName, TempFileNameForExchange);
				
				DataStructure.TempExchangeMessageCatalogName = TempDirectoryNameForExchange;
				DataStructure.DataPackageFileID       = DataPackageFileID;
				DataStructure.ExchangeMessageFileName              = TempFileNameForExchange;
				
			EndIf;
			
		EndIf;
		
	ElsIf Parameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageFromCorrespondentInfobaseToTempDirectory(Cancel, Parameters.InfobaseNode, False);
		
	ElsIf Parameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebService(
			Cancel,
			Parameters.InfobaseNode,
			Parameters.FileID,
			Parameters.TimeConsumingOperation,
			Parameters.OperationID,
			Parameters.WSPassword);
		
	Else // FILE, FTP, EMAIL
		
		DataStructure = DataExchangeServer.GetExchangeMessageToTemporaryDirectory(Cancel, Parameters.InfobaseNode, Parameters.ExchangeMessagesTransportKind, False);
		
	EndIf;
	
	Parameters.Cancel                                = Cancel;
	Parameters.TempExchangeMessageCatalogName = DataStructure.TempExchangeMessageCatalogName;
	Parameters.DataPackageFileID       = DataStructure.DataPackageFileID;
	Parameters.ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
	
	PutToTempStorage(Parameters, TempStorageAddress);
	
EndProcedure

// For internal use.
// Gets an exchange message from the correspondent infobase via web service to the temporary directory of OS user.
//
Procedure GetExchangeMessageFromCorrespondentToTemporaryDirectory(Parameters, TempStorageAddress) Export
	
	Cancel = False;
	
	SetPrivilegedMode(True);
	
	DataStructure = DataExchangeServer.GetExchangeMessageToTempDirectoryFromCorrespondentInfobaseOverWebServiceTimeConsumingOperationCompletion(
		Cancel,
		Parameters.InfobaseNode,
		Parameters.FileID,
		Parameters.WSPassword);
	
	Parameters.Cancel                                = Cancel;
	Parameters.TempExchangeMessageCatalogName = DataStructure.TempExchangeMessageCatalogName;
	Parameters.DataPackageFileID       = DataStructure.DataPackageFileID;
	Parameters.ExchangeMessageFileName              = DataStructure.ExchangeMessageFileName;
	
	PutToTempStorage(Parameters, TempStorageAddress);
	
EndProcedure

// For internal use.
//
Procedure RunDataImport(Parameters, TempStorageAddress) Export
	
	DataExchangeParameters = DataExchangeServer.DataExchangeParametersThroughFileOrString();
	
	DataExchangeParameters.InfobaseNode        = Parameters.InfobaseNode;
	DataExchangeParameters.FullNameOfExchangeMessageFile = Parameters.ExchangeMessageFileName;
	DataExchangeParameters.ActionOnExchange             = Enums.ActionsOnExchange.DataImport;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeOverFileOrString(DataExchangeParameters);
	
EndProcedure

// For internal use.
// It exports data and is called by a background job.
// Parameters - a structure with parameters to pass.
Procedure RunDataExport(Parameters, TempStorageAddress) Export
	
	Cancel = False;
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport            = False;
	ExchangeParameters.ExecuteExport            = True;
	ExchangeParameters.TimeConsumingOperationAllowed  = True;
	ExchangeParameters.ExchangeMessagesTransportKind = Parameters.ExchangeMessagesTransportKind;
	ExchangeParameters.TimeConsumingOperation           = Parameters.TimeConsumingOperation;
	ExchangeParameters.OperationID        = Parameters.OperationID;
	ExchangeParameters.FileID           = Parameters.FileID;
	ExchangeParameters.AuthenticationParameters      = Parameters.WSPassword;
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Parameters.InfobaseNode, ExchangeParameters, Cancel);
	
	Parameters.TimeConsumingOperation      = ExchangeParameters.TimeConsumingOperation;
	Parameters.OperationID   = ExchangeParameters.OperationID;
	Parameters.FileID      = ExchangeParameters.FileID;
	Parameters.WSPassword                = ExchangeParameters.AuthenticationParameters;
	Parameters.Cancel                   = Cancel;
	
	PutToTempStorage(Parameters, TempStorageAddress);
	
EndProcedure

// For internal use.
//
Function AllDataMapped(StatisticsInformation) Export
	
	Return (StatisticsInformation.FindRows(New Structure("PictureIndex", 1)).Count() = 0);
	
EndFunction

// For internal use.
//
Function HasUnmappedMasterData(StatisticsInformation) Export
	Return (StatisticsInformation.FindRows(New Structure("PictureIndex, IsMasterData", 1, True)).Count() > 0);
EndFunction

#Region DataRegistration

Procedure OnStartRecordData(RegistrationSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Регистрация данных для выгрузки (%1)'; en = 'Register data for export (%1)'; pl = 'Rejestracja danych do pobierania (%1)';es_ES = 'Registro de datos para subir (%1)';es_CO = 'Registro de datos para subir (%1)';tr = 'Dışa aktarılacak verilerin kaydı (%1)';it = 'Registra dati per l''esportazione (%1)';de = 'Datenregistrierung für den Upload (%1)'"),
		RegistrationSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Регистрация данных для начальной выгрузки для ""%1"" уже выполняется.'; en = 'Data for initial export for ""%1"" is already being registered.'; pl = 'Rejestracja danych dla początkowego ładowania dla ""%1"" jest już wykonywane.';es_ES = 'Registro de datos para subida inicial para ""%1"" ya se está ejecutando.';es_CO = 'Registro de datos para subida inicial para ""%1"" ya se está ejecutando.';tr = '""%1"" için dışa aktarılacak ilk veriler zaten kaydediliyor.';it = 'i dati per l''esportazione iniziale per ""%1"" sono già stati registrati.';de = 'Die Datenregistrierung für den ersten Upload für ""%1"" ist bereits in Bearbeitung.'"),
			RegistrationSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("RegistrationSettings", RegistrationSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Регистрация данных для выгрузки (%1).'; en = 'Register data for export (%1).'; pl = 'Rejestracja danych do pobierania (%1).';es_ES = 'Registro de datos para subir (%1).';es_CO = 'Registro de datos para subir (%1).';tr = 'Dışa aktarılacak verilerin kaydı (%1).';it = 'Registra dati per l''esportazione (%1).';de = 'Datenregistrierung für den Upload (%1).'"),
		RegistrationSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.InteractiveDataExchangeWizard.RegisterDataforExport",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnWaitForRecordData(HandlerParameters, ContinueWait = True) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnCompleteDataRecording(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region ExportMappingData

// For internal use.
//
Procedure OnStartExportDataForMapping(ExportSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Выгрузка данных для сопоставления (%1)'; en = 'Data export for mapping (%1)'; pl = 'Pobieranie danych do porównania (%1)';es_ES = 'Subida de datos para comparar (%1)';es_CO = 'Subida de datos para comparar (%1)';tr = 'Karşılaştırılacak verileri dışa aktarma (%1)';it = 'Esportazione dati per la mappatura (%1)';de = 'Datenexport zum Mapping (%1)'"),
		ExportSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выгрузка данных для сопоставления для ""%1"" уже выполняется.'; en = 'Data export for mapping for ""%1"" is already in progress.'; pl = 'Ładowanie danych dla dopasowania dla ""%1"" jest już wykonywane.';es_ES = 'La subida de datos para comparar para ""%1"" se está ejecutando ya.';es_CO = 'La subida de datos para comparar para ""%1"" se está ejecutando ya.';tr = '""%1"" karşılaştırılacak veriler zaten dışa aktarılıyor.';it = 'L''esportazione dati per la mappatura ""%1"" è ancora in lavorazione.';de = 'Die Daten zum Mapping von ""%1"" werden bereits hochgeladen.'"),
			ExportSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ExportSettings", ExportSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Выгрузка данных для сопоставления (%1).'; en = 'Data export for mapping (%1).'; pl = 'Pobieranie danych do porówniania (%1).';es_ES = 'Subida de datos para comparar (%1).';es_CO = 'Subida de datos para comparar (%1).';tr = 'Karşılaştırılacak verileri dışa aktarma (%1).';it = 'Esportazione dati per la mappatura (%1).';de = 'Hochladen von Daten zum Mapping (%1).'"),
		ExportSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.InteractiveDataExchangeWizard.ExportDataForMapping",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteExportDataForMapping(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure RegisterDataforExport(Parameters, ResultAddress) Export
	
	RegistrationSettings = Undefined;
	Parameters.Property("RegistrationSettings", RegistrationSettings);
	
	Result = New Structure;
	Result.Insert("DataRegistered", True);
	Result.Insert("ErrorMessage",      "");
	
	StructureAddition = RegistrationSettings.ExportAddition;
	
	ExportAddition = DataProcessors.InteractiveExportModification.Create();
	FillPropertyValues(ExportAddition, StructureAddition, , "AdditionalRegistration, AdditionalNodeScenarioRegistration");
	
	ExportAddition.AllDocumentsFilterComposer.LoadSettings(StructureAddition.AllDocumentsSettingFilterComposer);
		
	DataExchangeServer.FillValueTable(ExportAddition.AdditionalRegistration, StructureAddition.AdditionalRegistration);
	DataExchangeServer.FillValueTable(ExportAddition.AdditionalNodeScenarioRegistration, StructureAddition.AdditionalNodeScenarioRegistration);
	
	If Not StructureAddition.AllDocumentsComposer = Undefined Then
		ExportAddition.AllDocumentsComposerAddress = PutToTempStorage(StructureAddition.AllDocumentsComposer);
	EndIf;
	
	// Saving export addition settings.
	DataExchangeServer.InteractiveExportModificationSaveSettings(ExportAddition, 
		DataExchangeServer.ExportAdditionSettingsAutoSavingName());
	
	// Registering additional data.
	Try
		DataExchangeServer.InteractiveExportModificationRegisterAdditionalData(ExportAddition);
	Except
		Result.DataRegistered = False;
		
		Information = ErrorInfo();
		
		Result.ErrorMessage = NStr("ru = 'Возникла проблема при добавлении данных к выгрузке:'; en = 'Issue occurred while adding data for export:'; pl = 'Wystąpił problem podczas dodawania danych do ładowania:';es_ES = 'Se ha producido un error al añadir los datos en la subida:';es_CO = 'Se ha producido un error al añadir los datos en la subida:';tr = 'Veriler dışa aktarmaya eklendiğinde bir sorun oluştu:';it = 'Un problema si è registrato durante l''aggiunta dati per esportazione:';de = 'Beim Hinzufügen von Daten zum Upload ist ein Problem aufgetreten:'") 
			+ Chars.LF + BriefErrorDescription(Information)
			+ Chars.LF + NStr("ru = 'Необходимо изменить условия отбора.'; en = 'Change filter conditions.'; pl = 'Należy zmienić warunki doboru.';es_ES = 'Es necesario cambiar las condiciones de selección.';es_CO = 'Es necesario cambiar las condiciones de selección.';tr = 'Seçim koşulları değiştirilmelidir.';it = 'Modifica condizioni di filtro.';de = 'Es ist notwendig, die Auswahlbedingungen zu ändern.'");
			
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , DetailErrorDescription(Information));
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure ExportDataForMapping(Parameters, ResultAddress) Export
	
	ExportSettings = Undefined;
	Parameters.Property("ExportSettings", ExportSettings);
	
	Result = New Structure;
	Result.Insert("DataExported",   True);
	Result.Insert("ErrorMessage", "");
	
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport = False;
	ExchangeParameters.ExecuteExport = True;
	ExchangeParameters.ExchangeMessagesTransportKind = ExportSettings.TransportKind;
	ExchangeParameters.MessageForDataMapping = True;
	
	If ExportSettings.Property("WSPassword") Then
		ExchangeParameters.Insert("AuthenticationParameters", ExportSettings.WSPassword);
	EndIf;
	
	Cancel = False;
	Try
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
			ExportSettings.ExchangeNode, ExchangeParameters, Cancel);
	Except
		Result.DataExported = False;
		Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataImportToMapEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
		
	Result.DataExported = Result.DataExported AND Not Cancel;
	
	If Not Result.DataExported
		AND IsBlankString(Result.ErrorMessage) Then
		Result.ErrorMessage = NStr("ru = 'При выполнении выгрузки данных для сопоставления возникли ошибки (см. Журнал регистрации).'; en = 'Errors occurred while exporting data for mapping (see the Event log).'; pl = 'Podczas wykonywania ładowania danych dla dopasowania wynikły błędy (patrz Dziennik rejestracji).';es_ES = 'Al subir los datos para comparar se ha producido errores (véase el Registro).';es_CO = 'Al subir los datos para comparar se ha producido errores (véase el Registro).';tr = 'Karşılaştırılacak veri dışa aktarma işlemi sırasında hatalar oluştu (bkz. Kayıt günlüğü).';it = 'Errori si sono registrati durante l''esportazione dati per la mappatura (vedere il registro Eventi).';de = 'Beim Hochladen der Daten zum Mapping sind Fehler aufgetreten (siehe Ereignisprotokoll).'");
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

#Region TimeConsumingOperations

// For internal use.
//
Procedure OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait = True)
	
	InitializeTimeConsumingOperationHandlerParameters(HandlerParameters, BackgroundJob);
	
	If BackgroundJob.Status = "Running" Then
		HandlerParameters.ResultAddress       = BackgroundJob.ResultAddress;
		HandlerParameters.OperationID = BackgroundJob.JobID;
		HandlerParameters.TimeConsumingOperation    = True;
		
		ContinueWait = True;
		Return;
	ElsIf BackgroundJob.Status = "Completed" Then
		HandlerParameters.ResultAddress    = BackgroundJob.ResultAddress;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	Else
		HandlerParameters.ErrorMessage = BackgroundJob.BriefErrorPresentation;
		If ValueIsFilled(BackgroundJob.DetailedErrorPresentation) Then
			HandlerParameters.ErrorMessage = BackgroundJob.DetailedErrorPresentation;
		EndIf;
		
		HandlerParameters.Cancel = True;
		HandlerParameters.TimeConsumingOperation = False;
		
		ContinueWait = False;
		Return;
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait = True)
	
	If HandlerParameters.Cancel
		Or Not HandlerParameters.TimeConsumingOperation Then
		ContinueWait = False;
		Return;
	EndIf;
	
	JobCompleted = False;
	Try
		JobCompleted = TimeConsumingOperations.JobCompleted(HandlerParameters.OperationID);
	Except
		HandlerParameters.Cancel             = True;
		HandlerParameters.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , HandlerParameters.ErrorMessage);
	EndTry;
		
	If HandlerParameters.Cancel Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = Not JobCompleted;
	
EndProcedure

// For internal use.
//
Procedure OnCompleteTimeConsumingOperation(HandlerParameters,
		CompletionStatus = Undefined)
	
	CompletionStatus = New Structure;
	CompletionStatus.Insert("Cancel",             False);
	CompletionStatus.Insert("ErrorMessage", "");
	CompletionStatus.Insert("Result",         Undefined);
	
	If HandlerParameters.Cancel Then
		FillPropertyValues(CompletionStatus, HandlerParameters, "Cancel, ErrorMessage");
	Else
		CompletionStatus.Result = GetFromTempStorage(HandlerParameters.ResultAddress);
	EndIf;
	
	HandlerParameters = Undefined;
		
EndProcedure

Procedure InitializeTimeConsumingOperationHandlerParameters(HandlerParameters, BackgroundJob)
	
	HandlerParameters = New Structure;
	HandlerParameters.Insert("BackgroundJob",          BackgroundJob);
	HandlerParameters.Insert("Cancel",                   False);
	HandlerParameters.Insert("ErrorMessage",       "");
	HandlerParameters.Insert("TimeConsumingOperation",      False);
	HandlerParameters.Insert("OperationID",   Undefined);
	HandlerParameters.Insert("ResultAddress",         Undefined);
	HandlerParameters.Insert("AdditionalParameters", New Structure);
	
EndProcedure

Function HasActiveBackgroundJobs(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key",      BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

#EndRegion

// Analyses the incoming exchange message. Fills in the Statistics table with data.
//
// Parameters:
//   Parameters - Structure
//   Cancel - Boolean - a cancellation flag. It is set to True if errors occur during the procedure execution.
//   ExchangeExecutionResult - EnumRef.ExchangeExecutionResults - the result of data exchange execution.
//
Function StatisticsTableExchangeMessages(Parameters,
		Cancel, ExchangeExecutionResult = Undefined, ErrorMessage = "")
		
	StatisticsInformation = Undefined;	
	InitializeStatisticsTable(StatisticsInformation);
	
	TempExchangeMessageCatalogName = Parameters.TempExchangeMessageCatalogName;
	InfobaseNode               = Parameters.InfobaseNode;
	ExchangeMessageFileName              = Parameters.ExchangeMessageFileName;
	
	If IsBlankString(TempExchangeMessageCatalogName) Then
		// Data from the correspondent infobase cannot be received.
		Cancel = True;
		Return StatisticsInformation;
	EndIf;
	
	SetPrivilegedMode(True);
	
	ExchangeSettingsStructure = DataExchangeServer.ExchangeSettingsStructureForInteractiveImportSession(
		InfobaseNode, ExchangeMessageFileName);
	
	If ExchangeSettingsStructure.Cancel Then
		Return StatisticsInformation;
	EndIf;
	
	DataExchangeDataProcessor = ExchangeSettingsStructure.DataExchangeDataProcessor;
	
	AnalysisParameters = New Structure("CollectClassifiersStatistics", True);	
	DataExchangeDataProcessor.ExecuteExchangeMessageAnalysis(AnalysisParameters);
	
	ExchangeExecutionResult = DataExchangeDataProcessor.ExchangeExecutionResult();
	
	If DataExchangeDataProcessor.ErrorFlag() Then
		Cancel = True;
		ErrorMessage = DataExchangeDataProcessor.ErrorMessageString();
		Return StatisticsInformation;
	EndIf;
	
	PackageHeaderDataTable = DataExchangeDataProcessor.PackageHeaderDataTable();
	For Each BatchTitleDataLine In PackageHeaderDataTable Do
		StatisticsInformationString = StatisticsInformation.Add();
		FillPropertyValues(StatisticsInformationString, BatchTitleDataLine);
	EndDo;
	
	// Supplying the statistic table with utility data
	ErrorMessage = "";
	SupplementStatisticTable(StatisticsInformation, Cancel, ErrorMessage);
	
	// Determining table strings with the OneToMany flag
	TempStatistics = StatisticsInformation.Copy(, "DestinationTableName, IsObjectDeletion");
	
	AddColumnWithValueToTable(TempStatistics, 1, "Iterator");
	
	TempStatistics.GroupBy("DestinationTableName, IsObjectDeletion", "Iterator");
	
	For Each TableRow In TempStatistics Do
		
		If TableRow.Iterator > 1 AND Not TableRow.IsObjectDeletion Then
			
			StatisticsInformationRows = StatisticsInformation.FindRows(New Structure("DestinationTableName, IsObjectDeletion",
				TableRow.DestinationTableName, TableRow.IsObjectDeletion));
			
			For Each StatisticsInformationString In StatisticsInformationRows Do
				
				StatisticsInformationString["OneToMany"] = True;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return StatisticsInformation;
	
EndFunction

// For internal use.
//
Function AutomaticDataMappingResult(Val Correspondent,
		Val ExchangeMessageFileName, Val TempExchangeMessageCatalogName, CheckVersionDifference)
		
	Result = New Structure;
	Result.Insert("StatisticsInformation",      Undefined);
	Result.Insert("AllDataMapped",     True);
	Result.Insert("HasUnmappedMasterData",   False);
	Result.Insert("StatisticsBlank",          True);
	Result.Insert("Cancel",                     False);
	Result.Insert("ErrorMessage",         "");
	Result.Insert("ExchangeExecutionResult", Undefined);
	
	// Mapping data received from a correspondent.
	// Getting mapping statistics.
	SetPrivilegedMode(True);
	
	DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
	
	// Analyzing exchange messages.
	AnalysisParameters = New Structure;
	AnalysisParameters.Insert("TempExchangeMessageCatalogName", TempExchangeMessageCatalogName);
	AnalysisParameters.Insert("InfobaseNode",               Correspondent);
	AnalysisParameters.Insert("ExchangeMessageFileName",              ExchangeMessageFileName);
	
	StatisticsInformation = StatisticsTableExchangeMessages(AnalysisParameters,
		Result.Cancel, Result.ExchangeExecutionResult, Result.ErrorMessage);
	
	If Result.Cancel Then
		If SessionParameters.VersionMismatchErrorOnGetData.HasError Then
			Return SessionParameters.VersionMismatchErrorOnGetData;
		EndIf;
		
		Return Result;
	EndIf;
	
	InteractiveDataExchangeWizard = Create();
	InteractiveDataExchangeWizard.InfobaseNode = Correspondent;
	InteractiveDataExchangeWizard.ExchangeMessageFileName = ExchangeMessageFileName;
	InteractiveDataExchangeWizard.TempExchangeMessageCatalogName = TempExchangeMessageCatalogName;
	InteractiveDataExchangeWizard.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Correspondent);
	InteractiveDataExchangeWizard.ExchangeMessagesTransportKind = Undefined;
	
	InteractiveDataExchangeWizard.StatisticsInformation.Load(StatisticsInformation);
	
	// Mapping data and getting statistics.
	InteractiveDataExchangeWizard.ExecuteDefaultAutomaticMappingAndGetMappingStatistics(Result.Cancel);
	
	If Result.Cancel Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось загрузить данные из ""%1"" (этап автоматического сопоставления данных).'; en = 'Cannot import data from ""%1"" (automatic data mapping step).'; pl = 'Nie można importować danych z ""%1"" (krok automatycznego mapowania danych)';es_ES = 'No se puede importar los datos de ""%1"" (paso de mapeo automático de datos).';es_CO = 'No se puede importar los datos de ""%1"" (paso de mapeo automático de datos).';tr = 'Veriler ""%1"" (otomatik veri eşlenme adımı) ''dan içe aktarılamıyor.';it = 'Impossibile caricare i dati da ''%1'' (passaggio di corrispondenza automatica dei dati).';de = 'Daten von ""%1"" (automatischer Datenmappingschritt) können nicht importiert werden.'"),
			Common.ObjectAttributeValue(Correspondent, "Description"));
	EndIf;
	
	StatisticsTable = InteractiveDataExchangeWizard.StatisticsTable();
	
	Result.StatisticsInformation    = StatisticsTable;
	Result.AllDataMapped   = AllDataMapped(StatisticsTable);
	Result.StatisticsBlank        = (StatisticsTable.Count() = 0);
	Result.HasUnmappedMasterData = HasUnmappedMasterData(StatisticsTable);
	
	Return Result;
	
EndFunction

Procedure InitializeStatisticsTable(StatisticsTable)
	
	StatisticsTable = New ValueTable;
	StatisticsTable.Columns.Add("DataImportedSuccessfully", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("DestinationTableName", New TypeDescription("String"));
	StatisticsTable.Columns.Add("PictureIndex", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("UsePreview", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("Key", New TypeDescription("String"));
	StatisticsTable.Columns.Add("ObjectCountInSource", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("ObjectCountInDestination", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("UnmappedObjectCount", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("MappedObjectCount", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("OneToMany", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("SearchFields", New TypeDescription("String"));
	StatisticsTable.Columns.Add("TableFields", New TypeDescription("String"));
	StatisticsTable.Columns.Add("Presentation", New TypeDescription("String"));
	StatisticsTable.Columns.Add("MappedObjectPercentage", New TypeDescription("Number"));
	StatisticsTable.Columns.Add("SynchronizeByID", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("SourceTypeString", New TypeDescription("String"));
	StatisticsTable.Columns.Add("ObjectTypeString", New TypeDescription("String"));
	StatisticsTable.Columns.Add("DestinationTypeString", New TypeDescription("String"));
	StatisticsTable.Columns.Add("IsClassifier", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("IsObjectDeletion", New TypeDescription("Boolean"));
	StatisticsTable.Columns.Add("IsMasterData", New TypeDescription("Boolean"));
	
EndProcedure

Procedure SupplementStatisticTable(StatisticsInformation, Cancel, ErrorMessage = "")
	
	For Each TableRow In StatisticsInformation Do
		
		Try
			Type = Type(TableRow.ObjectTypeString);
		Except
			Cancel = True;
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Ошибка: тип ""%1"" не определен.'; en = 'Error: the %1 type is not defined.'; pl = 'Błąd: typ ""%1"" nie jest zdefiniowany.';es_ES = 'Error: el tipo ""%1"" no está definido.';es_CO = 'Error: el tipo ""%1"" no está definido.';tr = 'Hata: ""%1"" tipi tanımlanmamış.';it = 'Errore il tipo %1 non è definito.';de = 'Fehler: Der Typ ""%1"" ist nicht definiert.'"), TableRow.ObjectTypeString);
			Break;
		EndTry;
		
		ObjectMetadata = Metadata.FindByType(Type);
		
		TableRow.DestinationTableName = ObjectMetadata.FullName();
		TableRow.Presentation       = ObjectMetadata.Presentation();
		
		TableRow.Key = String(New UUID);
		
	EndDo;
	
EndProcedure

Procedure AddColumnWithValueToTable(Table, IteratorValue, IteratorFieldName)
	
	Table.Columns.Add(IteratorFieldName);
	
	Table.FillValues(IteratorValue, IteratorFieldName);
	
EndProcedure

#EndRegion

#EndIf