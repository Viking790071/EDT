////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem
//
////////////////////////////////////////////////////////////////////////////////

#Region Public

// Sets the ORMCachedValueUpdateDate constant value.
// The value is set to the current date of the computer (server).
// On changing the value of this constant, cached values become outdated for the data exchange 
// subsystem and require re-initialization.
// 
Procedure ResetObjectsRegistrationMechanismCache() Export
	
	If Common.SeparatedDataUsageAvailable() Then
		
		SetPrivilegedMode(True);
		// Recording date and time of the server computer - CurrentDate(). Do not use the 
		// CurrentSessionDate() method.
		// The current server date is used as a unique key for the object registration mechanism cache.
		// 
		Constants.ORMCachedValuesRefreshDate.Set(CurrentDate());
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Internal

// Returns an error flag at start:
// 1) Exchange message import error:
//    - Metadata object ID import error.
//    - Object ID verification error.
//    - Error of importing exchange message before infobase update.
//    - Error of importing exchange message before infobase update when infobase version is not changed.
// 2) Database update error after successful exchange message import.
//
Function RetryDataExchangeMessageImportBeforeStart() Export
	
	SetPrivilegedMode(True);
	
	Return Constants.RetryDataExchangeMessageImportBeforeStart.Get();
	
EndFunction

// Returns background job state.
// This function is used to implement time-consuming operations.
//
// Parameters:
//  JobID - UUID - ID of the background job to receive state for.
//                                                   
// 
// Returns:
//  String - background job state:
// Active - the job is being executed.
// Completed - the job is executed successfully.
// Failed - the job is terminated due to an error or canceled by a user.
//
Function JobState(Val JobID) Export
	
	Try
		Result = ?(TimeConsumingOperations.JobCompleted(JobID), "Completed", "Active");
	Except
		Result = "Failed";
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
			EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
	EndTry;
	
	Return Result;
EndFunction

#EndRegion

#Region Private

// See CommonOverridable.OnAddSessionParametersSettingHandlers. 
Procedure SessionParametersSetting(ParameterName, SpecifiedParameters) Export
	
	// Session parameters must be initialized without using application parameters.
	
	If ParameterName = "DataExchangeMessageImportModeBeforeStart" Then
		SessionParameters.DataExchangeMessageImportModeBeforeStart = New FixedStructure(New Structure);
		SpecifiedParameters.Add("DataExchangeMessageImportModeBeforeStart");
		Return;
	EndIf;
	
	If Common.SeparatedDataUsageAvailable() Then
		
		// Procedure for updating cached values and session parameters.
		UpdateObjectsRegistrationMechanismCache();
		
		// Registering parameter names set on
		// execution of DataExchangeServerCall.UpdateObjectsRecordMechanismCache.
		SpecifiedParameters.Add("SelectiveObjectsRegistrationRules");
		SpecifiedParameters.Add("ObjectsRegistrationRules");
		SpecifiedParameters.Add("ORMCachedValuesRefreshDate");
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
		SessionParameters.PriorityExchangeData = New FixedArray(New Array);
		SpecifiedParameters.Add("PriorityExchangeData");
		
		SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(New Map);
		SpecifiedParameters.Add("DataSynchronizationSessionParameters");
		
		CheckStructure =New Structure;
		CheckStructure.Insert("CheckVersionDifference", False);
		CheckStructure.Insert("HasError", False);
		CheckStructure.Insert("ErrorText", "");
		
		SessionParameters.VersionMismatchErrorOnGetData = New FixedStructure(CheckStructure);
		SpecifiedParameters.Add("VersionMismatchErrorOnGetData");
		
	Else
		
		SessionParameters.DataSynchronizationPasswords = New FixedMap(New Map);
		SpecifiedParameters.Add("DataSynchronizationPasswords");
		
		SessionParameters.DataSynchronizationSessionParameters = New ValueStorage(New Map);
		SpecifiedParameters.Add("DataSynchronizationSessionParameters");
	EndIf;
	
EndProcedure

// Executes data exchange process separately for each exchange setting line.
// Data exchange process consists of two stages:
// - Exchange initialization - preparation of data exchange subsystem to perform data exchange.
// - Data exchange - a process of reading a message file and then importing this data to infobase or 
//                          exporting changes to the message file.
// The initialization stage is performed once per session and is saved to the session cache at 
// server until the session is restarted or cached values of data exchange subsystem are reset.
// Cached values are reset when data that affects data exchange process is changed (transport 
// settings, exchange settings, filter settings on exchange plan nodes).
//
// The exchange can be executed completely for all scenario lines or can be executed for a single 
// row of the exchange scenario TS.
//
// Parameters:
//  Cancel                     - Boolean - a cancelation flag. It appears when scenario execution errors occur.
//  ExchangeExecutionSettings - CatalogRef.DataExchangeScenarios - a catalog item whose attribute 
//                              values are used to perform data exchange.
//  LineNumber - Number - a number of the line to use for performing data exchange.
//                              If it is not specified, all lines are involved in data exchange.
// 
Procedure ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, RowNumber = Undefined) Export
	
	DataExchangeServer.ExecuteDataExchangeUsingDataExchangeScenario(Cancel, ExchangeExecutionSettings, RowNumber);
	
EndProcedure

// Checks whether object registration cache is up-to-date.
// If the cached data is obsolete, cache gets initialized with new values.
//
// Parameters:
//  No.
// 
Procedure CheckObjectsRegistrationMechanismCache() Export
	
	SetPrivilegedMode(True);
	
	If Common.SeparatedDataUsageAvailable() Then
		
		ActualDate = GetFunctionalOption("ORMCachedValuesLatestUpdate");
		
		If SessionParameters.ORMCachedValuesRefreshDate <> ActualDate Then
			
			UpdateObjectsRegistrationMechanismCache();
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Updates or sets cached values and session parameters for data exchange subsystem.
//
// The following session parameters are set:
//   ObjectsRegistrationRules - ValueStorage - contains an object registration rule value table in 
//                                                    binary format.
//   SelectiveObjectsRegistrationRules -
//   ORMCachedValueRefreshDate - Date (Date and time) - contains the date of the last relevant cache 
//                                                                         for the data exchange subsystem.
//
// Parameters:
//  No.
// 
Procedure UpdateObjectsRegistrationMechanismCache() Export
	
	SetPrivilegedMode(True);
	
	RefreshReusableValues();
	
	If DataExchangeCached.ExchangePlansInUse().Count() > 0 Then
		
		SessionParameters.ObjectsRegistrationRules = New ValueStorage(DataExchangeServer.GetObjectsRegistrationRules());
		
		SessionParameters.SelectiveObjectsRegistrationRules = New ValueStorage(DataExchangeServer.GetSelectiveObjectsRegistrationRules());
		
	Else
		
		SessionParameters.ObjectsRegistrationRules = New ValueStorage(DataExchangeServer.ObjectsRegistrationRulesTableInitialization());
		
		SessionParameters.SelectiveObjectsRegistrationRules = New ValueStorage(DataExchangeServer.SelectiveObjectsRegistrationRulesTableInitialization());
		
	EndIf;
	
	// Getting date value for checking whether cached data is up-to-date.
	SessionParameters.ORMCachedValuesRefreshDate = GetFunctionalOption("ORMCachedValuesLatestUpdate");
	
EndProcedure

// Records that data exchange is completed.
//
Procedure RecordDataExportInTimeConsumingOperationMode(Val InfobaseNode, Val StartDate) Export
	
	SetPrivilegedMode(True);
	
	ActionOnExchange = Enums.ActionsOnExchange.DataExport;
	
	ExchangeSettingsStructure = New Structure;
	ExchangeSettingsStructure.Insert("InfobaseNode", InfobaseNode);
	ExchangeSettingsStructure.Insert("ExchangeExecutionResult", Enums.ExchangeExecutionResults.Completed);
	ExchangeSettingsStructure.Insert("ActionOnExchange", ActionOnExchange);
	ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
	ExchangeSettingsStructure.Insert("EventLogMessageKey", DataExchangeServer.EventLogMessageKey(InfobaseNode, ActionOnExchange));
	ExchangeSettingsStructure.Insert("StartDate", StartDate);
	ExchangeSettingsStructure.Insert("EndDate", CurrentSessionDate());
	ExchangeSettingsStructure.Insert("IsDIBExchange", DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode));
	
	DataExchangeServer.AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

// Records data exchange crash.
//
Procedure RecordExchangeCompletionWithError(Val InfobaseNode,
												Val ActionOnExchange,
												Val StartDate,
												Val ErrorMessageString) Export
	
	SetPrivilegedMode(True);
	
	DataExchangeServer.RecordExchangeCompletionWithError(InfobaseNode,
											ActionOnExchange,
											StartDate,
											ErrorMessageString);
EndProcedure

// Gets exchange message file from a correspondent infobase using web service.
// Imports exchange message file to the current infobase.
//
Procedure ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
															Cancel,
															Val InfobaseNode,
															Val FileID,
															Val OperationStartDate,
															Val AuthenticationParameters = Undefined) Export
	
	DataExchangeServer.ExecuteDataExchangeForInfobaseNodeTimeConsumingOperationCompletion(
															Cancel,
															InfobaseNode,
															FileID,
															OperationStartDate,
															AuthenticationParameters);
EndProcedure

// Attempts to establish an external connection with the specified connection parameters.
// If external connection cannot be established, the cancelation flag is set to True.
//
Procedure ExecuteExternalConnectionTest(Cancel, SettingsStructure, AddInAttachmentError = False) Export
	
	ErrorMessageString = "";
	
	// Attempting to establish external connection.
	Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(SettingsStructure);
	// Displaying error message.
	If Result.Connection = Undefined Then
		CommonClientServer.MessageToUser(Result.BriefErrorDescription,,,, Cancel);
	EndIf;
	AddInAttachmentError = Result.AddInAttachmentError;
	
EndProcedure

// Returns the flag of whether a register record set is empty.
//
Function RegisterRecordSetIsEmpty(RecordStructure, RegisterName) Export
	
	RegisterMetadata = Metadata.InformationRegisters[RegisterName];
	
	// Creating register record set.
	RecordSet = InformationRegisters[RegisterName].CreateRecordSet();
	
	// Setting register dimension filters.
	For Each Dimension In RegisterMetadata.Dimensions Do
		
		// If dimension filter value is specified in a structure, the filter is set.
		If RecordStructure.Property(Dimension.Name) Then
			
			RecordSet.Filter[Dimension.Name].Set(RecordStructure[Dimension.Name]);
			
		EndIf;
		
	EndDo;
	
	RecordSet.Read();
	
	Return RecordSet.Count() = 0;
	
EndFunction

// Returns the event log message key by the specified action string.
//
Function EventLogMessageKeyByActionString(InfobaseNode, ActionOnStringExchange) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange[ActionOnStringExchange]);
	
EndFunction

// Returns the structure that contains event log filter data.
//
Function EventLogFilterData(InfobaseNode, Val ActionOnExchange) Export
	
	If TypeOf(ActionOnExchange) = Type("String") Then
		
		ActionOnExchange = Enums.ActionsOnExchange[ActionOnExchange];
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	DataExchangesStates = DataExchangeServer.DataExchangesStates(InfobaseNode, ActionOnExchange);
	
	Filter = New Structure;
	Filter.Insert("EventLogEvent", DataExchangeServer.EventLogMessageKey(InfobaseNode, ActionOnExchange));
	Filter.Insert("StartDate",                DataExchangesStates.StartDate);
	Filter.Insert("EndDate",             DataExchangesStates.EndDate);
	
	Return Filter;
	
EndFunction

// Returns the array of all reference types available in the configuration.
//
Function AllConfigurationReferenceTypes() Export
	
	Return DataExchangeCached.AllConfigurationReferenceTypes();
	
EndFunction

// Gets the state of a time-consuming operation (background job) being executed in a correspondent 
// infobase for a specific node.
//
Function TimeConsumingOperationStateForInfobaseNode(Val OperationID,
									Val InfobaseNode,
									Val AuthenticationParameters = Undefined,
									ErrorMessageString = "") Export
	
	Try
		SetPrivilegedMode(True);
		
		ConnectionParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(
			InfobaseNode, AuthenticationParameters);
		
		WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetContinuousOperationStatus(OperationID, ErrorMessageString);
		
	Except
		Result = "Failed";
		ErrorMessageString = DetailErrorDescription(ErrorInfo())
			+ ?(ValueIsFilled(ErrorMessageString), Chars.LF + ErrorMessageString, "");
	EndTry;
	
	If Result = "Failed" Then
		MessageString = NStr("ru = 'Ошибка в базе-корреспонденте: %1'; en = 'An error occurred in the correspondent infobase: %1'; pl = 'Błąd w bazie-korespondencie: %1';es_ES = 'Error en la base-correspondiente: %1';es_CO = 'Error en la base-correspondiente: %1';tr = 'Muhabir tabanındaki hata: %1';it = 'Si è registrato un errore nell''infobase corrispondente: %1';de = 'Es liegt ein Fehler in der entsprechenden Datenbank vor: %1'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ErrorMessageString);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the flag that shows whether configuration of subordinate DIB node was changed.
//
Function UpdateInstallationRequired() Export
	
	DataExchangeServer.CheckCanSynchronizeData();
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.UpdateInstallationRequired();
	
EndFunction

// Deletes a record about object writing errors on writing.
//
Procedure RecordIssueResolved(Source, IssueType, Val DeletionMarkNewValue) Export
	
	SetPrivilegedMode(True);
	
	If DataExchangeCached.ExchangePlansInUse().Count() > 0
		AND (SafeMode() = FALSE OR Users.IsFullUser()) Then
		
		ConflictRecordSet = InformationRegisters.DataExchangeResults.CreateRecordSet();
		ConflictRecordSet.Filter.ObjectWithIssue.Set(Source);
		ConflictRecordSet.Filter.IssueType.Set(IssueType);
		
		ConflictRecordSet.Read();
		
		If ConflictRecordSet.Count() = 1 Then
			
			If DeletionMarkNewValue <> Common.ObjectAttributeValue(Source, "DeletionMark") Then
				
				ConflictRecordSet[0].DeletionMark = DeletionMarkNewValue;
				ConflictRecordSet.Write();
				
			Else
				
				ConflictRecordSet.Clear();
				ConflictRecordSet.Write();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Deletes data synchronization settings item.
//
Procedure DeleteSynchronizationSetting(Val InfobaseNode) Export
	
	DataExchangeServer.DeleteSynchronizationSetting(InfobaseNode);
	
EndProcedure

Function DataExchangeOption(Val Correspondent) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.DataExchangeOption(Correspondent);
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange in privileged mode.

// Checks the run mode, sets the privileged mode, and runs the handler.
//
Procedure ExecuteHandlerInPrivilegedMode(Value, Val HandlerRow) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("ru = 'Метод не поддерживается при работе в модели сервиса.'; en = 'Method is not supported in SaaS operations.'; pl = 'Metoda nie jest obsługiwana podczas pracy w modelu serwisu.';es_ES = 'Método no se admite al trabajar en el modelo de servicio.';es_CO = 'Método no se admite al trabajar en el modelo de servicio.';tr = 'Yöntem, servis modelinde çalışırken desteklenmiyor.';it = 'Il metodo non è supportato nelle operazioni SaaS.';de = 'Die Methode wird im Servicemodell nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Execute(HandlerRow);
	
EndProcedure

// Gets a scheduled job by GUID.
//
// Parameters:
//  JobUUID - String - a string with the scheduled job GUID.
// 
// Returns:
//  Undefined        - if scheduled job with the specified GUID is not found or
//  ScheduledJob - a scheduled job found by GUID.
//
Function FindScheduledJobByParameter(Val JobUUID) Export
	
	If IsBlankString(JobUUID) Then
		Return Undefined;
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("UUID", New UUID(JobUUID));
	
	SetPrivilegedMode(True);
	Jobs = ScheduledJobsServer.FindJobs(Filter);
	
	If Jobs.Count() = 0 Then
		Return Undefined;
	EndIf;

	Return Jobs[0];
	
EndFunction

// Returns the structure that stores object property values. The property values are obtained using a query to the infobase.
// StructureKey - a property name. Value - an object property value.
//
// Parameters:
//	Reference - a reference to the infobase object whose property values are being retrieved.
//
// Returns:
//	Structure - a structure with object properties values.
//
Function PropertiesValuesForRef(Ref, ObjectProperties, Val ObjectPropertiesString, Val MetadataObjectName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	If Common.DataSeparationEnabled() Then
		Raise NStr("ru = 'Метод не поддерживается при работе в модели сервиса.'; en = 'Method is not supported in SaaS operations.'; pl = 'Metoda nie jest obsługiwana podczas pracy w modelu serwisu.';es_ES = 'Método no se admite al trabajar en el modelo de servicio.';es_CO = 'Método no se admite al trabajar en el modelo de servicio.';tr = 'Yöntem, servis modelinde çalışırken desteklenmiyor.';it = 'Il metodo non è supportato nelle operazioni SaaS.';de = 'Die Methode wird im Servicemodell nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.PropertiesValuesForRef(Ref, ObjectProperties, ObjectPropertiesString, MetadataObjectName);
EndFunction

// Returns an array of exchange plan nodes under the specified request parameters and request text for the exchange plan table.
//
//
Function NodesArrayByPropertiesValues(PropertiesValues, Val QueryText, Val ExchangePlanName, Val FlagAttributeName, Val DataExported = False) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.NodesArrayByPropertiesValues(PropertiesValues, QueryText, ExchangePlanName, FlagAttributeName, DataExported);
EndFunction

// Returns the value of session parameter ObjectsRegistrationRules obtained in privileged mode.
//
// Returns:
//	ValueStorage - the value of the ObjectsRegistrationRules session parameter.
//
Function SessionParametersObjectsRegistrationRules() Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.ObjectsRegistrationRules;
	
EndFunction

// The function returns a list of all nodes of the specified exchange plan except for the predefined node.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan as it is set in Designer for which the 
//                            list of nodes is being retrieved.
//
//  Returns:
//   Array - a list of all nodes of the specified exchange plan.
//
Function AllExchangePlanNodes(Val ExchangePlanName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeServer.ExchangePlanNodes(ExchangePlanName);
	
EndFunction

// Returns the flag that shows whether any changes are registered for the specified recipient.
//
Function ChangesRegistered(Val Recipient) Export
	
	QueryText =
	"SELECT TOP 1 1
	|FROM
	|	[Table].Changes AS ChangesTable
	|WHERE
	|	ChangesTable.Node = &Node";
	
	Query = New Query;
	Query.SetParameter("Node", Recipient);
	
	SetPrivilegedMode(True);
	
	ExchangePlanComposition = Metadata.ExchangePlans[DataExchangeCached.GetExchangePlanName(Recipient)].Content;
	
	For Each CompositionItem In ExchangePlanComposition Do
		
		Query.Text = StrReplace(QueryText, "[Table]", CompositionItem.Metadata.FullName());
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
EndFunction

// Returns a flag that shows whether an exchange plan is used in data exchange.
// If an exchange plan contains at least one node apart from the predefined one, it is considered 
// being used in data exchange.
//
// Parameters:
//	ExchangePlanName - String - an exchange plan name as it is set in Designer.
//
// Returns:
//	Boolean - True if the exchange plan is being used, False if it is not being used.
//
Function DataExchangeEnabled(Val ExchangePlanName, Val Sender) Export
	
	SetPrivilegedMode(True);
	
	Return DataExchangeCached.DataExchangeEnabled(ExchangePlanName, Sender);
EndFunction

// Receives an array of exchange plan nodes with the "Export always" flag value set to True.
//
// Parameters:
//	ExchangePlanName    - String - a name of the exchange plan as a metadata object used to determine nodes.
//	FlagAttributeName - String - a name of the exchange plan attribute used to set a node selection filter.
//
// Returns:
//	Array - exchange plan nodes with the "Export always" flag value set to True.
//
Function NodesForRegistrationByExportAlwaysCondition(Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.NodesForRegistrationByExportAlwaysCondition(ExchangePlanName, FlagAttributeName);
	
EndFunction

// Receives an array of exchange plan nodes with "Export when needed" flag value set to True.
//
// Parameters:
//	Reference - a reference to the infobase object for which it is required to get the array of nodes the object was exported to earlier.
//	ExchangePlanName    - String - a name of the exchange plan as a metadata object used to determine nodes.
//	FlagAttributeName - String - a name of the exchange plan attribute used to set a node selection filter.
//
// Returns:
//	Array - exchange plan nodes with "Export when needed" flag value set to True.
//
Function NodesForRegistrationByExportIfNecessaryCondition(Ref, Val ExchangePlanName, Val FlagAttributeName) Export
	
	If CurrentRunMode() = ClientRunMode.ManagedApplication Then
		Raise NStr("ru = 'Метод не поддерживается в режиме управляемого приложения.'; en = 'This method is not supported in the managed application mode.'; pl = 'Metoda nie jest obsługiwana w trybie zarządzanej aplikacji.';es_ES = 'Método no admitido en el modo de la aplicación de gestión.';es_CO = 'Método no admitido en el modo de la aplicación de gestión.';tr = 'Yönetilen uygulama modunda yöntem desteklenmez.';it = 'Questo metodo non è supportato in modalità applicazione gestita.';de = 'Die Methode wird im verwalteten Anwendungsmodus nicht unterstützt.'");
	EndIf;
	
	SetPrivilegedMode(True);
	
	Return DataExchangeEvents.NodesForRegistrationByExportIfNecessaryCondition(Ref, ExchangePlanName, FlagAttributeName);
	
EndFunction

// Returns the flag that shows whether application parameters are imported into the infobase from the exchange message.
// This function is used in DIB data exchange when data is imported to a subordinate node.
//
Function DataExchangeMessageImportModeBeforeStart(Property) Export
	
	SetPrivilegedMode(True);
	
	Return SessionParameters.DataExchangeMessageImportModeBeforeStart.Property(Property);
	
EndFunction

// Returns the list of priority exchange data items.
//
// Returns:
//	Array - a collection of references to priority exchange data items.
//
Function PriorityExchangeData() Export
	
	SetPrivilegedMode(True);
	
	Result = New Array;
	
	For Each Item In SessionParameters.PriorityExchangeData Do
		
		Result.Add(Item);
		
	EndDo;
	
	Return Result;
EndFunction

// Adds the passed value to the list of priority exchange data items.
//
Procedure SupplementPriorityExchangeData(Val Data) Export
	
	Result = PriorityExchangeData();
	
	Result.Add(Data);
	
	SetPrivilegedMode(True);
	
	SessionParameters.PriorityExchangeData = New FixedArray(Result);
	
EndProcedure

// Clears the list of priority exchange data items.
//
Procedure ClearPriorityExchangeData() Export
	
	SetPrivilegedMode(True);
	
	SessionParameters.PriorityExchangeData = New FixedArray(New Array);
	
EndProcedure

// Returns a list of metadata objects prohibited to export.
// Export is prohibited if a table is marked as NotExport in the rules of exchange plan objects registration.
//
// Parameters:
//     InfobaseNode - ExchangePlanRef - a reference to the exchange plan node being analyzed.
//
// Returns:
//     Array that contains full names of metadata objects.
//
Function NotExportedNodeObjectsMetadataNames(Val InfobaseNode) Export
	Result = New Array;
	
	NotExportMode = Enums.ExchangeObjectExportModes.DoNotExport;
	ExportModes   = DataExchangeCached.UserExchangePlanComposition(InfobaseNode);
	For Each KeyValue In ExportModes Do
		If KeyValue.Value=NotExportMode Then
			Result.Add(KeyValue.Key);
		EndIf;
	EndDo;
	
	Return Result;
EndFunction

// Checks if the specified exchange node is the master node.
//
// Parameters:
//   InfobaseNode - ExchangePlanRef - a reference to the exchange plan node to be checked if it is 
//       master node.
//
// Returns:
//   Boolean.
//
Function IsMasterNode(Val InfobaseNode) Export
	
	Return ExchangePlans.MasterNode() = InfobaseNode;
	
EndFunction

// Creates a query for clearing node permissions (on deleting).
//
Function RequestToClearPermissionsToUseExternalResources(Val InfobaseNode) Export
	
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	Query = ModuleSafeModeManager.RequestToClearPermissionsToUseExternalResources(InfobaseNode);
	Return CommonClientServer.ValueInArray(Query);
	
EndFunction

#EndRegion