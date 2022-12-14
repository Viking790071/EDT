#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// For internal use.
//
Procedure OnGetAvailableDataSynchronizationSettings(SettingsTable,
	UseDataExchangeCreationWizard = True) Export
	
	IsFullUser = Users.IsFullUser(, True);
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
	
	SettingsTable = New ValueTable;
	SettingsTable.Columns.Add("ExchangePlanName",                                 New TypeDescription("String"));
	SettingsTable.Columns.Add("SettingID",                         New TypeDescription("String"));
	SettingsTable.Columns.Add("CorrespondentConfigurationName",                  New TypeDescription("String"));
	SettingsTable.Columns.Add("CorrespondentConfigurationDescription",         New TypeDescription("String"));
	SettingsTable.Columns.Add("UseDataExchangeCreationWizard",      New TypeDescription("Boolean"));
	SettingsTable.Columns.Add("NewDataExchangeCreationCommandTitle", New TypeDescription("String"));
	SettingsTable.Columns.Add("ExchangeBriefInfo",                      New TypeDescription("String"));
	SettingsTable.Columns.Add("IsDistributedInfobaseExchangePlan",  New TypeDescription("Boolean"));
	SettingsTable.Columns.Add("IsXDTOExchangePlan",                              New TypeDescription("Boolean"));
	SettingsTable.Columns.Add("ExchangePlanNameToMigrateToNewExchange",          New TypeDescription("String"));
	
	ExchangePlanList = New Array;
	
	If SaaSModel Then
		ModuleDataExchangeSaaSCashed = Common.CommonModule("DataExchangeSaaSCached");
		ExchangePlanList = ModuleDataExchangeSaaSCashed.DataSynchronizationExchangePlans();
	Else
		ExchangePlanList = DataExchangeCached.SSLExchangePlans();
	EndIf;
	
	For Each ExchangePlanName In ExchangePlanList Do
		ExchangePlanManager = ExchangePlans[ExchangePlanName];
		
		If Not IsFullUser
			AND DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName) Then
			// Creating a DIB exchange requires system administrator rights.
			Continue;
		EndIf;
		
		If Not DataExchangeCached.ExchangePlanUsageAvailable(ExchangePlanName) Then
			Continue;
		EndIf;
		
		ExchangeSettings = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
			"ExchangeSettingsOptions, ExchangePlanNameToMigrateToNewExchange");
		
		For Each SetupOption In ExchangeSettings.ExchangeSettingsOptions Do
			PredefinedSetting = SetupOption.SettingID;
			
			SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
				"UseDataExchangeCreationWizard,
				|CorrespondentConfigurationName,
				|CorrespondentConfigurationDescription,
				|NewDataExchangeCreationCommandTitle,
				|ExchangeBriefInfo",
				PredefinedSetting);
				
			If UseDataExchangeCreationWizard
				AND Not SettingsValuesForOption.UseDataExchangeCreationWizard Then
				Continue;
			EndIf;
			
			SettingsString = SettingsTable.Add();
			FillPropertyValues(SettingsString, SettingsValuesForOption);
			
			SettingsString.ExchangePlanName = ExchangePlanName;
			SettingsString.SettingID = PredefinedSetting;
			SettingsString.IsDistributedInfobaseExchangePlan =
				DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
			SettingsString.IsXDTOExchangePlan = DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName);
			SettingsString.ExchangePlanNameToMigrateToNewExchange = ExchangeSettings.ExchangePlanNameToMigrateToNewExchange;
			
		EndDo;

	EndDo;
	
	// Deleting obsolete options of exchange setup.
	If SaaSModel Then
		XTDOExchangePlans     = New Array;
		ObsoleteSettings = New Array;
		
		For Each SettingsString In SettingsTable Do
			If SettingsString.IsXDTOExchangePlan Then
				If XTDOExchangePlans.Find(SettingsString.ExchangePlanName) = Undefined Then
					XTDOExchangePlans.Add(SettingsString.ExchangePlanName);
				EndIf;
				Continue;
			EndIf;
			If Not ValueIsFilled(SettingsString.ExchangePlanNameToMigrateToNewExchange) Then
				Continue;
			EndIf;
			ObsoleteSettings.Add(SettingsString);
		EndDo;
		
		XDTOSettingsTable = SettingsTable.Copy(New Structure("IsXDTOExchangePlan", True));
		
		SettingsForDelete = New Array;
		For Each SettingsString In ObsoleteSettings Do
			For Each XTDOExchangePlan In XTDOExchangePlans Do
				SetupOption = DataExchangeServer.ExchangeSettingOptionForCorrespondent(
					XTDOExchangePlan, SettingsString.CorrespondentConfigurationName);
				If Not ValueIsFilled(SetupOption) Then
					Continue;
				EndIf;
				XDTOSettings = XDTOSettingsTable.FindRows(New Structure("SettingID", SetupOption));	
				If XDTOSettings.Count() > 0 Then
					SettingsForDelete.Add(SettingsString);
					Break;
				EndIf;
			EndDo;
		EndDo;
		
		For Cnt = 1 To SettingsForDelete.Count() Do
			SettingsTable.Delete(SettingsForDelete[Cnt - 1]);
		EndDo;
		
	EndIf;
	
EndProcedure

// For internal use.
//
Procedure ExportConnectionSettingsForSubordinateDIBNode(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	XMLString = "";
	Try
		XMLString = ConnectionSettingsInXML(ConnectionSettings);
	Except
		Raise;
	EndTry;
		
	Constants.SubordinateDIBNodeSettings.Set(XMLString);
	ExchangePlans.RecordChanges(ConnectionSettings.InfobaseNode,
		Metadata.Constants.SubordinateDIBNodeSettings);
	
EndProcedure

#Region CheckConnectionToCorrespondent

// For internal use.
//
Procedure OnStartTestConnection(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = BackgroundJobKey(ConnectionSettings.ExchangePlanName,			
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????? ?????????????????????? %1'; en = 'Checking connection %1'; pl = 'Weryfikacja po????czenia %1';es_ES = 'Comprobar la conexi??n %1';es_CO = 'Comprobar la conexi??n %1';tr = 'Ba??lant??y?? kontrol et%1';it = 'Controllo connessione %1';de = 'Verbindungspr??fung %1'"), ConnectionSettings.ExchangeMessagesTransportKind));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????? ?????????????????????? %1 ?????? ??????????????????????.'; en = '%1 connection check is already in progress.'; pl = 'Weryfikacja po????czenia %1 jest ju?? w toku.';es_ES = 'Prueba de conectar %1 ya se est?? ejecutando.';es_CO = 'Prueba de conectar %1 ya se est?? ejecutando.';tr = '%1 ba??lant??s??n??n kontrol?? devam ediyor.';it = '%1 controllo connessione ?? gi?? in progresso.';de = 'Die Verbindungspr??fung %1 ist bereits im Gange.'"), ConnectionSettings.ExchangeMessagesTransportKind);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????? ?????????????????????? ?? ????????????????????????????: %1.'; en = 'Check connection to correspondent: %1.'; pl = 'Weryfikacja po????czenia do korespondenta: %1.';es_ES = 'Prueba de conectar al correspondiente: %1.';es_CO = 'Prueba de conectar al correspondiente: %1.';tr = 'Muhabire ba??lant?? kontrol??: %1.';it = 'Controlla connessione al corrispondente: %1.';de = '??berpr??fung der Verbindung zum Korrespondenten: %1.'"), ConnectionSettings.ExchangeMessagesTransportKind);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.TestCorrespondentConnection",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnWaitForTestConnection(HandlerParameters, ContinueWait = True) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

Procedure OnCompleteTestConnection(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region SaveConnectionSettings
// For internal use.
//
Procedure OnStartSaveConnectionSettings(ConnectionSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = BackgroundJobKey(ConnectionSettings.ExchangePlanName,
		NStr("ru = '???????????????????? ???????????????? ??????????????????????'; en = 'Save connection settings'; pl = 'Zapisywanie ustawie?? po????czenia';es_ES = 'Guardar los ajustes de conexi??n';es_CO = 'Guardar los ajustes de conexi??n';tr = 'Ba??lant?? ayarlar??n??n kayd??';it = 'Salva le impostazioni di connessione';de = 'Speichern der Verbindungseinstellungen'"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????????? ???????????????? ?????????????????????? ?????? ""%1"" ?????? ??????????????????????.'; en = 'Connection settings for the ""%1"" are already being saved.'; pl = 'Zapisywanie ustawie?? po????czenia dla ""%1"" jest ju?? w toku.';es_ES = 'Los ajustes de conexi??n para ""%1"" se est??n guardando.';es_CO = 'Los ajustes de conexi??n para ""%1"" se est??n guardando.';tr = '""%1"" i??in ba??lant?? ayarlar?? zaten kaydediliyor.';it = 'Impostazioni di connessione per ""%1"" sono gi?? state salvate.';de = 'Das Speichern der Verbindungseinstellungen f??r ""%1"" wird bereits ausgef??hrt.'"), ConnectionSettings.ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ConnectionSettings", ConnectionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????????? ???????????????? ??????????????????????: %1.'; en = 'Save connection settings: %1.'; pl = 'Zapisywanie ustawie?? po????czenia: %1.';es_ES = 'Guardar los ajustes de conexi??n: %1.';es_CO = 'Guardar los ajustes de conexi??n: %1.';tr = 'Ba??lant?? ayarlar??n??n kayd??: %1.';it = 'Salva le impostazioni di connessione: %1.';de = 'Speichern der Verbindungseinstellungen: %1.'"), ConnectionSettings.ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.SaveConnectionSettings",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForSaveConnectionSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteSaveConnectionSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region SaveSynchronizationSettings

// For internal use.
//
Procedure OnStartSaveSynchronizationSettings(SynchronizationSettings, HandlerParameters, ContinueWait = True) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(SynchronizationSettings.ExchangeNode);
	
	BackgroundJobKey = BackgroundJobKey(ExchangePlanName,
		NStr("ru = '???????????????????? ???????????????? ?????????????????????????? ????????????'; en = 'Save data synchronization settings'; pl = 'Zapisywanie ustawie?? synchronizacji danych';es_ES = 'Guardar los ajustes de sincronizaci??n de datos';es_CO = 'Guardar los ajustes de sincronizaci??n de datos';tr = 'Veri e??le??me ayarlar??n??n kayd??';it = 'Salva le impostazioni di sincronizzazione dati';de = 'Speichern der Datensynchronisierungseinstellungen'"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????????? ???????????????? ?????????????????????????? ???????????? ?????? ""%1"" ?????? ??????????????????????.'; en = 'Data synchronization settings for the ""%1"" are already being saved.'; pl = 'Zapisywanie ustawie?? synchronizacji danych dla ""%1"" jest ju?? w toku.';es_ES = 'Los ajustes de sincronizaci??n de datos para ""%1"" se est??n guardando.';es_CO = 'Los ajustes de sincronizaci??n de datos para ""%1"" se est??n guardando.';tr = '""%1"" i??in veri e??le??me ayarlar?? zaten kaydediliyor.';it = 'Le impostazioni di sincronizzazione dati per ""%1"" sono gi?? state salvate.';de = 'Das Speichern der Datensynchronisationseinstellungen f??r ""%1"" wird bereits ausgef??hrt.'"), ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("SynchronizationSettings", SynchronizationSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????????? ???????????????? ?????????????????????????? ????????????: %1.'; en = 'Save data synchronization settings: %1.'; pl = 'Zapisywanie ustawie?? synchronizacji danych: %1.';es_ES = 'Guardar los ajustes de sincronizaci??n de datos: %1.';es_CO = 'Guardar los ajustes de sincronizaci??n de datos: %1.';tr = 'Veri e??le??me ayarlar??n??n kayd??: %1.';it = 'Salva le impostazioni di sincronizzazione dati: %1.';de = 'Speichern der Datensynchronisierungseinstellungen: %1.'"), ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.SaveSynchronizationSettings",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForSaveSynchronizationSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteSaveSynchronizationSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region DeleteDataSynchronizationSetting

// For internal use.
//
Procedure OnStartDeleteSynchronizationSettings(DeletionSettings, HandlerParameters, ContinueWait = True) Export
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(DeletionSettings.ExchangeNode);
	
	BackgroundJobKey = BackgroundJobKey(ExchangePlanName,
		NStr("ru = '???????????????? ?????????????????? ?????????????????????????? ????????????'; en = 'Delete data synchronization settings'; pl = 'Usuwanie ustawienia synchronizacji danych';es_ES = 'Eliminar los ajustes de sincronizaci??n de datos';es_CO = 'Eliminar los ajustes de sincronizaci??n de datos';tr = 'Veri e??le??me ayar??n?? kald??r';it = 'Elimina le impostazioni sincronizzazione  dati';de = 'L??schen der Datensynchronisierungseinstellung'"));

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????? ?????????????????? ?????????????????????????? ???????????? ?????? ""%1"" ?????? ??????????????????????.'; en = 'Data synchronization settings for the ""%1"" are already being deleted.'; pl = 'Usuwanie ustawienia synchronizacji danych dla ""%1"" jest ju?? w toku.';es_ES = 'Los ajustes de sincronizaci??n de datos para ""%1"" se est??n eliminando ya.';es_CO = 'Los ajustes de sincronizaci??n de datos para ""%1"" se est??n eliminando ya.';tr = '""%1"" i??in veri e??le??me ayarlar?? zaten kald??r??l??yor.';it = 'Le impostazioni di sincronizzazione dati per ""%1"" sono gi?? stati cancellati.';de = 'Das L??schen der Datensynchronisierungseinstellung f??r ""%1"" wird bereits ausgef??hrt.'"), ExchangePlanName);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("DeletionSettings", DeletionSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????? ?????????????????? ?????????????????????????? ????????????: %1.'; en = 'Delete data synchronization settings: %1.'; pl = 'Usuwanie ustawienia synchronizacji danych: %1.';es_ES = 'Eliminar los ajustes de sincronizaci??n de datos: %1';es_CO = 'Eliminar los ajustes de sincronizaci??n de datos: %1';tr = 'Veri e??le??me ayar??n?? kald??r:%1';it = 'Elimina le impostazioni sincronizzazione dati: %1.';de = 'L??schen der Datensynchronisierungseinstellung: %1.'"), ExchangePlanName);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.DeleteSynchronizationSetting",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForDeleteSynchronizationSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteDeleteSynchronizationSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region DataRegistrationForInitialExport

// For internal use.
//
Procedure OnStartRecordDataForInitialExport(RegistrationSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '?????????????????????? ???????????? ?????? ?????????????????? ???????????????? (%1)'; en = 'Register data for initial export (%1)'; pl = 'Rejestracja danych dla pocz??tkowego ??adowania (%1)';es_ES = 'Registro de datos para subida inicial (%1)';es_CO = 'Registro de datos para subida inicial (%1)';tr = 'D????a aktar??lacak ilk verilerin kayd?? (%1)';it = 'Registra dati per l''esportazione iniziale (%1)';de = 'Datenregistrierung f??r den erstmaligen Upload (%1)'"),
		RegistrationSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????????????????????? ???????????? ?????? ?????????????????? ???????????????? ?????? ""%1"" ?????? ??????????????????????.'; en = 'Data for initial export for ""%1"" is already being registered.'; pl = 'Rejestracja danych dla pocz??tkowego ??adowania dla ""%1"" jest ju?? wykonywane.';es_ES = 'Registro de datos para subida inicial para ""%1"" ya se est?? ejecutando.';es_CO = 'Registro de datos para subida inicial para ""%1"" ya se est?? ejecutando.';tr = '""%1"" i??in d????a aktar??lacak ilk veriler zaten kaydediliyor.';it = 'i dati per l''esportazione iniziale per ""%1"" sono gi?? stati registrati.';de = 'Die Datenregistrierung f??r den ersten Upload f??r ""%1"" ist bereits in Bearbeitung.'"),
			RegistrationSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("RegistrationSettings", RegistrationSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '?????????????????????? ???????????? ?????? ?????????????????? ???????????????? (%1).'; en = 'Register data for initial export (%1).'; pl = 'Rejestracja danych dla pocz??tkowego ??adowania (%1).';es_ES = 'Registro de datos para subida inicial (%1).';es_CO = 'Registro de datos para subida inicial (%1).';tr = 'D????a aktar??lacak ilk verilerin kayd?? (%1).';it = 'Registra dati per l''esportazione iniziale (%1).';de = 'Datenregistrierung f??r den erstmaligen Upload (%1).'"),
		RegistrationSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.RegisterDataForInitialExport",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForRecordDataForInitialExport(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteDataRecordingForInitialExport(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

#Region XDTOSettingsImport

// For internal use.
//
Procedure OnStartImportXDTOSettings(ImportSettings, HandlerParameters, ContinueWait = True) Export
	
	BackgroundJobKey = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????? ???????????????? XDTO (%1)'; en = 'Import XDTO settings (%1)'; pl = 'Pobieranie ustawie?? XDTO (%1)';es_ES = 'Carga de ajustes XDTO (%1)';es_CO = 'Carga de ajustes XDTO (%1)';tr = 'XDTO ayarlar??n??n i??e aktar??lmas?? (%1)';it = 'Importa impostazioni XDTO (%1)';de = 'Download von XDTO-Einstellungen (%1)'"),
		ImportSettings.ExchangeNode);

	If HasActiveBackgroundJobs(BackgroundJobKey) Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????????? ???????????????? XDTO ?????? ""%1"" ?????? ??????????????????????.'; en = 'XDTO settings for ""%1"" are already being imported.'; pl = 'Pobieranie ustawie?? XDTO dla ""%1"" jest ju?? w toku.';es_ES = 'Los ajustes XDTO para ""%1"" se est??n cargando ya.';es_CO = 'Los ajustes XDTO para ""%1"" se est??n cargando ya.';tr = '""%1"" i??in XDTO ayarlar?? zaten i??e aktar??l??yor.';it = 'Le impostazioni XDTO per ""%1"" sono gi?? state impostate.';de = 'Der Download der XDTO-Einstellungen f??r ""%1"" wird bereits ausgef??hrt.'"),
			ImportSettings.ExchangeNode);
	EndIf;
		
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("ImportSettings", ImportSettings);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.BackgroundJobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '???????????????? ???????????????? XDTO (%1).'; en = 'Import XDTO settings (%1).'; pl = 'Pobieranie ustawie?? XDTO (%1).';es_ES = 'Cargar los ajustes XDTO (%1).';es_CO = 'Cargar los ajustes XDTO (%1).';tr = 'XDTO ayarlar??n??n i??e aktar??lmas?? (%1).';it = 'Importazione impostazioni XDTO (%1).';de = 'Download von XDTO-Einstellungen (%1).'"),
		ImportSettings.ExchangeNode);
	ExecutionParameters.BackgroundJobKey = BackgroundJobKey;
	ExecutionParameters.RunNotInBackground    = False;
	ExecutionParameters.RunInBackground      = True;
	
	BackgroundJob = TimeConsumingOperations.ExecuteInBackground(
		"DataProcessors.DataExchangeCreationWizard.ImportXDTOCorrespondentSettings",
		ProcedureParameters,
		ExecutionParameters);
		
	OnStartTimeConsumingOperation(BackgroundJob, HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnWaitForImportXDTOSettings(HandlerParameters, ContinueWait) Export
	
	OnWaitTimeConsumingOperation(HandlerParameters, ContinueWait);
	
EndProcedure

// For internal use.
//
Procedure OnCompleteImportXDTOSettings(HandlerParameters, CompletionStatus) Export
	
	OnCompleteTimeConsumingOperation(HandlerParameters, CompletionStatus);
	
EndProcedure

#EndRegion

Function DataExchangeSettingsFormatVersion() Export
	
	Return "1.2";
	
EndFunction

#EndRegion

#Region Private

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

Function BackgroundJobKey(ExchangePlanName, Action)
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = '????????????????????:%1 ????????????????:%2'; en = 'ExchangePlan:%1 Action:%2'; pl = 'ExchangePlan:%1 Dzia??anie:%2';es_ES = 'Plan de intercambio:%1 Acci??n:%2';es_CO = 'Plan de intercambio:%1 Acci??n:%2';tr = 'ExchangePlan: %1 Eylem: %2';it = 'Piano di scambio:%1 Azione: %2';de = 'Austauschplan: %1 Aktion: %2'"), ExchangePlanName, Action);
	
EndFunction

Function HasActiveBackgroundJobs(BackgroundJobKey)
	
	Filter = New Structure;
	Filter.Insert("Key",      BackgroundJobKey);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveBackgroundJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	
	Return (ActiveBackgroundJobs.Count() > 0);
	
EndFunction

#EndRegion

Procedure OnConnectToCorrespondent(Cancel, ExchangePlanName, Val CorrespondentVersion, ErrorMessage = "")
	
	If Not ValueIsFilled(CorrespondentVersion) Then
		CorrespondentVersion = "0.0.0.0";
	EndIf;

	Try
		DataExchangeServer.OnConnectToCorrespondent(ExchangePlanName, CorrespondentVersion);
	Except
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????? ???????????????????? ?????????????????????? OnConnectToCorrespondent ?????????????????? ????????????:%1%2'; en = 'An error occurred during the OnConnectToCorrespondent handler execution:%1%2'; pl = 'Wyst??pi?? b????d podczas wykonywania programu serwisu OnConnectToCorrespondent:%1%2';es_ES = 'Ha ocurrido un error al ejecutar el manipulador OnConnectingToCorrespondent:%1%2';es_CO = 'Ha ocurrido un error al ejecutar el manipulador OnConnectingToCorrespondent:%1%2';tr = 'OnConnectToCorrespondent i??leyicisini y??r??t??rken bir hata olu??tu: %1%2';it = 'Si ?? verificato un errore durante l''esecuzione del gestore OnConnectToCorrespondent:%1%2';de = 'Beim Ausf??hren des Handlers OnConnectToCorrespondent ist ein Fehler aufgetreten: %1%2'"),
				Chars.LF, ErrorMessage));
				
		Cancel = True;
	EndTry;
	
EndProcedure

Procedure TestCorrespondentConnection(Parameters, ResultAddress) Export
	
	ConnectionSettings = Undefined;
	Parameters.Property("ConnectionSettings", ConnectionSettings);
	
	CheckResult = New Structure;
	CheckResult.Insert("ConnectionIsSet", False);
	CheckResult.Insert("ConnectionAllowed",   False);
	CheckResult.Insert("InterfaceVersions",       Undefined);
	CheckResult.Insert("ErrorMessage",      "");
	
	CheckResult.Insert("CorrespondentParametersReceived", False);
	CheckResult.Insert("CorrespondentParameters",         Undefined);
	
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		Result = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
		
		ExternalConnection = Result.Connection;
		If ExternalConnection = Undefined Then
			CheckResult.ErrorMessage = Result.BriefErrorDescription;
			CheckResult.ConnectionIsSet = False;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		CheckResult.InterfaceVersions = DataExchangeServer.InterfaceVersionsThroughExternalConnection(ExternalConnection);
		
		If CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			
			ErrorMessage = "";
			InfobaseParameters = ExternalConnection.DataExchangeExternalConnection.GetInfobaseParameters_2_0_1_6(
				ConnectionSettings.ExchangePlanName, "", ErrorMessage);
				
			CorrespondentParameters = Common.ValueFromXMLString(InfobaseParameters);
			If Not CorrespondentParameters.ExchangePlanExists Then
				CheckResult.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?? ???????????????????????????? ???? ???????????? ???????? ???????????? ""%1"".
					|??????????????????, ??????
					| - ???????????? ???????????????????? ?????? ???????????????????? ?????? ?????????????????? ????????????;
					| - ?????????????????? ?????????????? ???????????????????????? ??????????????????, ?? ?????????????? ?????????????????????? ??????????????????????.'; 
					|en = 'The ""%1"" exchange plan was not found in correspondent.
					|Make sure that:
					|- You selected the correct application kind to set up exchange.
					|- Location of the application to which you are connecting is specified correctly.'; 
					|pl = 'W korespondencie nie znaleziono planu wymiany ""%1"".
					|Przekonaj si??, ??e
					| - wybrano w??a??ciwy rodzaj aplikacji dla ustawienia wymiany;
					| - prawid??owo okre??lono lokalizacj?? programu, do kt??rego wykonywane jest po????czenie.';
					|es_ES = 'En el correspondiente no se ha encontrado un plan de cambio ""%1"".
					|Aseg??rese que
					| - se ha seleccionado un tipo correcto de la aplicaci??n para ajustar el cambio;
					| - se ha indicado correctamente la situaci??n del programa en el que se est?? realizando la conexi??n.';
					|es_CO = 'En el correspondiente no se ha encontrado un plan de cambio ""%1"".
					|Aseg??rese que
					| - se ha seleccionado un tipo correcto de la aplicaci??n para ajustar el cambio;
					| - se ha indicado correctamente la situaci??n del programa en el que se est?? realizando la conexi??n.';
					|tr = 'Muhabirde ""%1"" al????veri?? plan?? bulunamad??. 
					| - 
					|Veri al????veri??ini yap??land??rmak i??in uygulaman??n t??r?? do??ru se??ildi??inden; 
					|- ba??lant??n??n yap??ld?????? program??n konumunun do??ru belirtildi??inden emin olun.';
					|it = 'Il piano di scambio ""%1"" non ?? stato trovato nel corrispondente.
					|Assicurati di:
					|- Aver selezionato il tipo di applicazione corretta per impostare il cambio.
					|- Aver indicato correttamente la posizione dell''applicazione alla quale sei connesso.';
					|de = 'Es gibt keinen Austauschplan im Korrespondenten""%1"".
					|Stellen Sie sicher, dass
					| - die richtige Art der Anwendung f??r die Einrichtung der Vermittlungsstelle ausgew??hlt ist;
					| - der Standort des Programms, zu dem die Verbindung hergestellt wird, korrekt angegeben ist.'"),
					ConnectionSettings.ExchangePlanName);
					
				PutToTempStorage(CheckResult, ResultAddress);
				Return;
			EndIf;
				
			CheckResult.CorrespondentParametersReceived = True;
			CheckResult.CorrespondentParameters =	CorrespondentParameters;
			
		Else
			
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = NStr("ru = '?????????????????????????? ???? ???????????????????????? ???????????? 3.0.1.1 ???????????????????? ""DataExchange"".
			|?????? ?????????????????? ?????????????????????? ???????????????????? ???????????????? ???????????????????????? ????????????????????????????, ?????? ???????????? ?????????????????? ???? ????????.'; 
			|en = 'The correspondent does not support DataExchange interface version 3.0.1.1.
			|To set up connection, update the correspondent configuration or start setting up from it.'; 
			|pl = 'Korespondent nie obs??uguje interfejsu DataExchange w wersji 3.0.1.1.
			|Aby skonfigurowa?? po????czenie, zaktualizuj odpowiedni?? konfiguracj?? lub rozpocznij od niej konfiguracj??.';
			|es_ES = 'El correspondiente no admite la versi??n 3.0.1.1 de la interfaz DataExchange.
			|Para ajustar la conexi??n es necesario actualizar la configuraci??n del correspondiente o empezar a ajustar sin ??l.';
			|es_CO = 'El correspondiente no admite la versi??n 3.0.1.1 de la interfaz DataExchange.
			|Para ajustar la conexi??n es necesario actualizar la configuraci??n del correspondiente o empezar a ajustar sin ??l.';
			|tr = 'Muhabir, DataExchange aray??z?? 3.0.1.1 s??r??m??n?? desteklemiyor.
			|Ba??lant?? kurmak i??in ilgili yap??land??rmay?? g??ncelleyin veya buradan kurmaya ba??lay??n.';
			|it = 'Il corrispondente non supporta la versione dell''interfaccia 3.0.1.1.
			|Per impostare la connessione, aggiorna la configurazione del corrispondente o iniziare la configurazione da esso.';
			|de = 'Der Empf??nger unterst??tzt die DataExchange-Schnittstelle Version 3.0.1.1 nicht.
			|Um eine Verbindung herzustellen, aktualisieren Sie die entsprechende Konfiguration oder starten Sie die Einrichtung von ihr aus.'");
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
			
		EndIf;
		
		Cancel = False;
		ErrorMessage = "";
		
		OnConnectToCorrespondent(Cancel, ConnectionSettings.ExchangePlanName,
			CheckResult.CorrespondentParameters.ConfigurationVersion, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionAllowed = True;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		Correspondent = New Structure("WSWebServiceURL, WSUsername, WSPassword");
		FillPropertyValues(Correspondent, ConnectionSettings);
		
		Try
			CheckResult.InterfaceVersions = DataExchangeCached.CorrespondentVersions(Correspondent);
		Except
			CheckResult.ErrorMessage = DetailErrorDescription(ErrorInfo());
			CheckResult.ConnectionIsSet = False;
			
			WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
				EventLogLevel.Error, , , CheckResult.ErrorMessage);
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndTry;
		
		ErrorMessageString = "";
		WSProxy = Undefined;
		If CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_3_0_1_1(ConnectionSettings, ErrorMessageString);
			
		ElsIf CheckResult.InterfaceVersions.Find("2.1.1.7") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionSettings, ErrorMessageString);
			
		ElsIf CheckResult.InterfaceVersions.Find("2.0.1.6") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionSettings, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(ConnectionSettings, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			CheckResult.ConnectionIsSet = False;
			CheckResult.ErrorMessage = ErrorMessageString;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		
		If CheckResult.InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			
			ErrorMessage = "";
			InfobaseParameters = WSProxy.GetIBParameters(ConnectionSettings.ExchangePlanName, "", ErrorMessage);
			
			CorrespondentParameters = XDTOSerializer.ReadXDTO(InfobaseParameters);
			If Not CorrespondentParameters.ExchangePlanExists Then
				CheckResult.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = '?? ???????????????????????????? ???? ???????????? ???????? ???????????? ""%1"".
					|??????????????????, ??????
					| - ???????????? ???????????????????? ?????? ???????????????????? ?????? ?????????????????? ????????????;
					| - ???????????? ???????????????????? ?????????? ???????????????????? ?? ??????????????????.'; 
					|en = 'The ""%1"" exchange plan was not found in correspondent.
					|Make sure that:
					|- You selected the correct application kind to set up exchange.
					|- Online address of the application to which you are connecting is specified correctly.'; 
					|pl = 'W korespondencie nie znaleziono planu wymiany ""%1"".
					|Przekonaj si??, ??e
					| - wybrano w??a??ciwy rodzaj aplikacji dla ustawienia wymiany;
					| - podano poprawny adres aplikacji w Internecie.';
					|es_ES = 'En el correspondiente no se ha encontrado un plan de cambio ""%1"".
					|Aseg??rese de que
					|- se ha seleccionado un tipo correcto de actualizaci??n para ajustar el cambio;
					| - se ha indicado direcci??n correcta de la aplicaci??n en Internet.';
					|es_CO = 'En el correspondiente no se ha encontrado un plan de cambio ""%1"".
					|Aseg??rese de que
					|- se ha seleccionado un tipo correcto de actualizaci??n para ajustar el cambio;
					| - se ha indicado direcci??n correcta de la aplicaci??n en Internet.';
					|tr = 'Muhabirde ""%1"" al????veri?? plan?? bulunamad??. 
					| - 
					|Veri al????veri??ini yap??land??rmak i??in uygulaman??n t??r?? do??ru se??ildi??inden; 
					|- ba??lant??n??n yap??ld?????? program??n ??nternet''teki konumunun do??ru belirtildi??inden emin olun.';
					|it = 'Il piano di scambio ""%1"" non ?? stato trovato nel corrispondente.
					|Assicurati di:
					|- Aver selezionato il tipo di applicazione corretta per impostare il cambio.
					|- Aver indicato correttamente l''indirizzo online dell''applicazione alla quale sei connesso.';
					|de = 'Es gibt keinen Austauschplan im Korrespondenten ""%1"".
					|Stellen Sie sicher, dass
					| - der richtige Anwendungstyp f??r die Einrichtung der Vermittlungsstelle ausgew??hlt ist;
					| - die richtige Internetadresse der Anwendung angegeben ist.'"),
					ConnectionSettings.ExchangePlanName);
				
				PutToTempStorage(CheckResult, ResultAddress);
				Return;
			EndIf;
			
			CheckResult.CorrespondentParametersReceived = True;
			CheckResult.CorrespondentParameters = CorrespondentParameters;
			
		Else
			
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = NStr("ru = '?????????????????????????? ???? ???????????????????????? ???????????? 3.0.1.1 ???????????????????? ""DataExchange"".
			|?????? ?????????????????? ?????????????????????? ???????????????????? ???????????????? ???????????????????????? ????????????????????????????, ?????? ???????????? ?????????????????? ???? ????????.'; 
			|en = 'The correspondent does not support DataExchange interface version 3.0.1.1.
			|To set up connection, update the correspondent configuration or start setting up from it.'; 
			|pl = 'Korespondent nie obs??uguje interfejsu DataExchange w wersji 3.0.1.1.
			|Aby skonfigurowa?? po????czenie, zaktualizuj odpowiedni?? konfiguracj?? lub rozpocznij od niej konfiguracj??.';
			|es_ES = 'El correspondiente no admite la versi??n 3.0.1.1 de la interfaz DataExchange.
			|Para ajustar la conexi??n es necesario actualizar la configuraci??n del correspondiente o empezar a ajustar sin ??l.';
			|es_CO = 'El correspondiente no admite la versi??n 3.0.1.1 de la interfaz DataExchange.
			|Para ajustar la conexi??n es necesario actualizar la configuraci??n del correspondiente o empezar a ajustar sin ??l.';
			|tr = 'Muhabir, DataExchange aray??z?? 3.0.1.1 s??r??m??n?? desteklemiyor.
			|Ba??lant?? kurmak i??in ilgili yap??land??rmay?? g??ncelleyin veya buradan kurmaya ba??lay??n.';
			|it = 'Il corrispondente non supporta la versione dell''interfaccia 3.0.1.1.
			|Per impostare la connessione, aggiorna la configurazione del corrispondente o iniziare la configurazione da esso.';
			|de = 'Der Empf??nger unterst??tzt die DataExchange-Schnittstelle Version 3.0.1.1 nicht.
			|Um eine Verbindung herzustellen, aktualisieren Sie die entsprechende Konfiguration oder starten Sie die Einrichtung von ihr aus.'");
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
			
		EndIf;
		
		Cancel = False;
		ErrorMessage = "";
		
		OnConnectToCorrespondent(Cancel, ConnectionSettings.ExchangePlanName,
			CheckResult.CorrespondentParameters.ConfigurationVersion, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionAllowed = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionAllowed = True;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		
		Cancel = False;
		ErrorMessage = "";
		
		DataExchangeServer.CheckExchangeMessageTransportDataProcessorAttachment(Cancel,
			ConnectionSettings, ConnectionSettings.ExchangeMessagesTransportKind, ErrorMessage);
			
		If Cancel Then
			CheckResult.ConnectionIsSet = False;
			CheckResult.ErrorMessage = ErrorMessage;
			
			PutToTempStorage(CheckResult, ResultAddress);
			Return;
		EndIf;
		
		CheckResult.ConnectionIsSet = True;
		CheckResult.ConnectionAllowed   = True;
		
	EndIf;
	
	PutToTempStorage(CheckResult, ResultAddress);
	
EndProcedure

Procedure SaveConnectionSettings(Parameters, ResultAddress) Export
	
	ConnectionSettings = Undefined;
	Parameters.Property("ConnectionSettings", ConnectionSettings);
	
	Result = New Structure;
	Result.Insert("ConnectionSettingsSaved", False);
	Result.Insert("HasDataToMap",    False); // For offline transport only.
	Result.Insert("ExchangeNode",                    Undefined);
	Result.Insert("ErrorMessage",             "");
	Result.Insert("XMLConnectionSettingsString",  "");
	
	// 1. Saving the node and connection settings to the infobase.
	Cancel = False;
	Try
		ConfigureDataExchange(ConnectionSettings);
	Except
		Cancel = True;
		Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
	
	If Cancel Then
		PutToTempStorage(Result, ResultAddress);
		Return;
	EndIf;
	
	// 2. Saving connection settings for correspondent.
	If Not ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
		If DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName) Then
			ExportConnectionSettingsForSubordinateDIBNode(ConnectionSettings);
		Else
			Result.XMLConnectionSettingsString = ConnectionSettingsInXML(ConnectionSettings);
		EndIf;
	EndIf;
	
	// 3. Saving connection settings at the correspondent side for online connection, or sending a 
	//    message with XDTO settings for offline connection.
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		Connection = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
		Result.ErrorMessage = Connection.DetailedErrorDescription;
		ExternalConnection           = Connection.Connection;
		
		If ExternalConnection = Undefined Then
			Cancel = True;
		Else
			
			CorrespondentConnectionSettings = ExternalConnection.DataProcessors.DataExchangeCreationWizard.Create();
			
			CorrespondentConnectionSettings.WizardRunOption   = "ContinueDataExchangeSetup";
			CorrespondentConnectionSettings.ExchangeSettingsOption = ConnectionSettings.ExchangeSettingsOption;
			
			CorrespondentConnectionSettings.ExchangePlanName               = ConnectionSettings.CorrespondentExchangePlanName;
			CorrespondentConnectionSettings.CorrespondentExchangePlanName = ConnectionSettings.ExchangePlanName;
			CorrespondentConnectionSettings.ExchangeFormat                 = ConnectionSettings.ExchangeFormat;
			
			CorrespondentConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
				ConnectionSettings.UsePrefixesForExchangeSettings;
				
			CorrespondentConnectionSettings.SourceInfobasePrefix = ConnectionSettings.DestinationInfobasePrefix;
			CorrespondentConnectionSettings.DestinationInfobasePrefix = ConnectionSettings.SourceInfobasePrefix;
			
			Try
			
				ExternalConnection.DataProcessors.DataExchangeCreationWizard.FillConnectionSettingsFromXMLString(
					CorrespondentConnectionSettings, Result.XMLConnectionSettingsString);
					
			Except
				Cancel = True;
				Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
					EventLogLevel.Error, , , Result.ErrorMessage);
			EndTry;
				
			If Not Cancel Then
			
				If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
					CorrespondentConnectionSettings.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
					
					ObjectsTable = DataExchangeXDTOServer.SupportedObjectsInFormat(
						ConnectionSettings.ExchangePlanName, "SendReceive", ConnectionSettings.InfobaseNode);
					
					StorageString = XDTOSerializer.XMLString(
						New ValueStorage(ObjectsTable, New Deflation(9)));
						
					CorrespondentConnectionSettings.SupportedObjectsInFormat = ExternalConnection.XDTOSerializer.XMLValue(
						ExternalConnection.NewObject("TypeDescription", "ValueStorage").Types().Get(0), StorageString);
				EndIf;
					
				Try
					
					ExternalConnection.DataExchangeServer.CheckDataExchangeUsage(True);
					
					ExternalConnection.DataProcessors.DataExchangeCreationWizard.ConfigureDataExchange(
						CorrespondentConnectionSettings);
				Except
					Cancel = True;
					Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
					
			EndIf;
				
		EndIf;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		WSProxy = DataExchangeServer.GetWSProxy_3_0_1_1(ConnectionSettings);
		
		If WSProxy = Undefined Then
			Cancel = True;
		Else
			CorrespondentConnectionSettings = New Structure;
			For Each SettingItem In ConnectionSettings Do
				CorrespondentConnectionSettings.Insert(SettingItem.Key);
			EndDo;
			
			CorrespondentConnectionSettings.WizardRunOption   = "ContinueDataExchangeSetup";
			CorrespondentConnectionSettings.ExchangeSettingsOption = ConnectionSettings.ExchangeSettingsOption;
			
			CorrespondentConnectionSettings.ExchangePlanName               = ConnectionSettings.CorrespondentExchangePlanName;
			CorrespondentConnectionSettings.CorrespondentExchangePlanName = ConnectionSettings.ExchangePlanName;
			CorrespondentConnectionSettings.ExchangeFormat                 = ConnectionSettings.ExchangeFormat;
			
			CorrespondentConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
				ConnectionSettings.UsePrefixesForExchangeSettings;
				
			CorrespondentConnectionSettings.SourceInfobasePrefix = ConnectionSettings.DestinationInfobasePrefix;
			CorrespondentConnectionSettings.DestinationInfobasePrefix = ConnectionSettings.SourceInfobasePrefix;
			
			If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
				CorrespondentConnectionSettings.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
				
				ObjectsTable = DataExchangeXDTOServer.SupportedObjectsInFormat(
						ConnectionSettings.ExchangePlanName, "SendReceive", ConnectionSettings.InfobaseNode);
				
				CorrespondentConnectionSettings.SupportedObjectsInFormat = New ValueStorage(ObjectsTable, New Deflation(9));
			EndIf;
				
			Serializer = New XDTOSerializer(WSProxy.XDTOFactory);
			
			ConnectionParameters = New Structure;
			ConnectionParameters.Insert("ConnectionSettings", CorrespondentConnectionSettings);
			ConnectionParameters.Insert("XMLParametersString",  Result.XMLConnectionSettingsString);
			
			Try
				WSProxy.CreateExchangeNode(Serializer.WriteXDTO(ConnectionParameters));
			Except
				Cancel = True;
				Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
				
				WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
					EventLogLevel.Error, , , Result.ErrorMessage);
			EndTry;
			
		EndIf;
		
	ElsIf ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			
			If ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
				// Getting an exchange message with XDTO settings.
				ExchangeParameters = DataExchangeServer.ExchangeParameters();
				ExchangeParameters.ExecuteImport = True;
				ExchangeParameters.ExecuteExport = False;
				ExchangeParameters.ExchangeMessagesTransportKind = ConnectionSettings.ExchangeMessagesTransportKind;
				
				// To set up synchronization, an error in receiving messages via normal communication channels is 
				// not critical (basically, it is possible to have no exchange message).
				CancelReceipt = False;
				AdditionalParameters = New Structure;
				Try
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
						ConnectionSettings.InfobaseNode, ExchangeParameters, CancelReceipt, AdditionalParameters);
				Except
					// An exception is critical for saving the setting.
					// There must be no exceptions.
					Cancel = True; 
					Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
				
				If AdditionalParameters.Property("DataReceivedForMapping") Then
					Result.HasDataToMap = AdditionalParameters.DataReceivedForMapping;
				EndIf;
			Else
				// Sending an exchange message with XDTO settings.
				ExchangeParameters = DataExchangeServer.ExchangeParameters();
				ExchangeParameters.ExecuteImport = False;
				ExchangeParameters.ExecuteExport = True;
				ExchangeParameters.ExchangeMessagesTransportKind = ConnectionSettings.ExchangeMessagesTransportKind;
				
				Try
					DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
						ConnectionSettings.InfobaseNode, ExchangeParameters, Cancel);
				Except
					Cancel = True;
					Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
					
					WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
						EventLogLevel.Error, , , Result.ErrorMessage);
				EndTry;
			EndIf;
			
		ElsIf Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName)
			AND Not DataExchangeCached.IsStandardDataExchangeNode(ConnectionSettings.ExchangePlanName) Then
			
			ExchangeSettingsStructure = DataExchangeCached.TransportSettingsOfExchangePlanNode(
				ConnectionSettings.InfobaseNode, ConnectionSettings.ExchangeMessagesTransportKind);
				
			ExchangeMessageTransportDataProcessor = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor;
			
			If ExchangeMessageTransportDataProcessor.ConnectionIsSet() Then
				
				Result.HasDataToMap = ExchangeMessageTransportDataProcessor.GetMessage(True);
				
				If Not Result.HasDataToMap Then
					// Probably the file can be received if you apply the virtual code (alias) of the node.
					Transliteration = Undefined;
					If ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FILE Then
						ExchangeSettingsStructure.TransportSettings.Property("FILETransliterateExchangeMessageFileNames", Transliteration);
					ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
						ExchangeSettingsStructure.TransportSettings.Property("EMAILTransliterateExchangeMessageFileNames", Transliteration);
					ElsIf ExchangeSettingsStructure.ExchangeTransportKind = Enums.ExchangeMessagesTransportTypes.FTP Then
						ExchangeSettingsStructure.TransportSettings.Property("FTPTransliterateExchangeMessageFileNames", Transliteration);
					EndIf;
					Transliteration = ?(Transliteration = Undefined, False, Transliteration);
					
					FileNameTemplatePrevious = ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern;
					ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern = DataExchangeServer.MessageFileNamePattern(
						ExchangeSettingsStructure.CurrentExchangePlanNode,
						ExchangeSettingsStructure.InfobaseNode,
						False,
						Transliteration, 
						True);
						
					If FileNameTemplatePrevious <> ExchangeSettingsStructure.ExchangeMessageTransportDataProcessor.MessageFileNamePattern Then
						Result.HasDataToMap = ExchangeMessageTransportDataProcessor.GetMessage(True);
					EndIf;
					
				EndIf;
				
			EndIf;
				
		EndIf;
		
	EndIf;
	
	If Not Cancel Then
		Result.ConnectionSettingsSaved = True;
		Result.ExchangeNode = ConnectionSettings.InfobaseNode;
	Else
		DataExchangeServer.DeleteSynchronizationSetting(ConnectionSettings.InfobaseNode);
		
		Result.ConnectionSettingsSaved = False;
		Result.ExchangeNode = Undefined;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure ImportXDTOCorrespondentSettings(Parameters, ResultAddress) Export
	
	ImportSettings = Undefined;
	Parameters.Property("ImportSettings", ImportSettings);
	
	Result = New Structure;
	Result.Insert("SettingsImported",             True);
	Result.Insert("DataReceivedForMapping", False);
	Result.Insert("ErrorMessage",              "");
	
	// Getting an exchange message with XDTO settings.
	ExchangeParameters = DataExchangeServer.ExchangeParameters();
	ExchangeParameters.ExecuteImport = True;
	ExchangeParameters.ExecuteExport = False;
	ExchangeParameters.ExchangeMessagesTransportKind =
		InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ImportSettings.ExchangeNode);
		
	AdditionalParameters = New Structure;
	
	Cancel = False;
	Try
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(
			ImportSettings.ExchangeNode, ExchangeParameters, Cancel, AdditionalParameters);
	Except
		Cancel = True;
		Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
		
	If Cancel Then
		Result.SettingsImported = False; 
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("ru = '???? ?????????????? ???????????????? ?????????????????? ????????????????????????????.'; en = 'Cannot receive correspondent parameters.'; pl = 'Nie uda??o si?? uzyska?? parametry korespondenta.';es_ES = 'No se ha podido recibir par??metros del correspondiente.';es_CO = 'No se ha podido recibir par??metros del correspondiente.';tr = 'Muhabirin parametreleri al??namad??.';it = 'Impossibile ricevere parametri corrispondenti.';de = 'Die Parameter des Empf??ngers konnten nicht empfangen werden.'");
		EndIf;
	Else
		CorrespondentSettings = DataExchangeXDTOServer.SupportedCorrespondentFormatObjects(
			ImportSettings.ExchangeNode, "SendReceive");
		Result.SettingsImported = (CorrespondentSettings.Count() > 0);
		
		If Result.SettingsImported Then
			If AdditionalParameters.Property("DataReceivedForMapping") Then
				Result.DataReceivedForMapping = AdditionalParameters.DataReceivedForMapping;
			EndIf;
		EndIf;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure SaveSynchronizationSettings(Parameters, ResultAddress) Export
	
	SynchronizationSettings = Undefined;
	Parameters.Property("SynchronizationSettings", SynchronizationSettings);
	
	Result = New Structure;
	Result.Insert("SettingsSaved", True);
	Result.Insert("ErrorMessage",  "");
	
	ExchangePlanName = DataExchangeCached.GetExchangePlanName(SynchronizationSettings.ExchangeNode);
	
	If DataExchangeServer.HasExchangePlanManagerAlgorithm("OnSaveDataSynchronizationSettings", ExchangePlanName) Then
		BeginTransaction();
		Try
			ObjectNode = SynchronizationSettings.ExchangeNode.GetObject();
			ExchangePlans[ExchangePlanName].OnSaveDataSynchronizationSettings(ObjectNode,
				SynchronizationSettings.FillingData);
			ObjectNode.Write();
			
			If Not DataExchangeServer.SynchronizationSetupCompleted(SynchronizationSettings.ExchangeNode) Then
				DataExchangeServer.CompleteDataSynchronizationSetup(SynchronizationSettings.ExchangeNode);
			EndIf;
			
			CommitTransaction();
		Except
			RollbackTransaction();
			
			Result.SettingsSaved = False;
			Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
				EventLogLevel.Error, , , Result.ErrorMessage);
		EndTry;
	Else
		If Not DataExchangeServer.SynchronizationSetupCompleted(SynchronizationSettings.ExchangeNode) Then
			DataExchangeServer.CompleteDataSynchronizationSetup(SynchronizationSettings.ExchangeNode);
		EndIf;
	EndIf;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure ConfigureDataExchange(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating/updating the exchange plan node.
		CreateUpdateExchangePlanNodes(ConnectionSettings);
		
		// Loading message transport settings.
		If ValueIsFilled(ConnectionSettings.ExchangeMessagesTransportKind) Then
			// For online exchange when setting from the box the transport kind will not be filled in and is not required.
			UpdateDataExchangeTransportSettings(ConnectionSettings);
		EndIf;
		
		// Updating the infobase prefix constant value.
		If IsBlankString(GetFunctionalOption("InfobasePrefix"))
			AND Not IsBlankString(ConnectionSettings.SourceInfobasePrefix) Then
			
			DataExchangeServer.SetInfobasePrefix(ConnectionSettings.SourceInfobasePrefix);
			
		EndIf;
		
		If DataExchangeCached.IsDistributedInfobaseExchangePlan(ConnectionSettings.ExchangePlanName)
			AND ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
			
			Constants.SubordinateDIBNodeSetupCompleted.Set(True);
			Constants.UseDataSynchronization.Set(True);
			Constants.DoNotUseSeparationByDataAreas.Set(True);
			
			// Importing rules because exchange rules are not migrated to DIB.
			DataExchangeServer.UpdateDataExchangeRules();
			
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

Procedure DeleteSynchronizationSetting(Parameters, ResultAddress) Export
	
	DeletionSettings = Undefined;
	Parameters.Property("DeletionSettings", DeletionSettings);
	
	Result = New Structure;
	Result.Insert("SettingDeleted",                 True);
	Result.Insert("SettingDeletedInCorrespondent",  DeletionSettings.DeleteSettingItemInCorrespondent);
	Result.Insert("ErrorMessage",                "");
	Result.Insert("ErrorMessageInCorrespondent", "");
	
	// 1. Deleting the synchronization setup in the correspondent application (optional).
	If DeletionSettings.DeleteSettingItemInCorrespondent Then
		DeleteSynchronizationSettingInCorrespondent(DeletionSettings, Result);
	EndIf;
	
	// 2. Deleting the synchronization settings in this application.
	Try
		DataExchangeServer.DeleteSynchronizationSetting(DeletionSettings.ExchangeNode);
	Except
		Result.SettingDeleted = False;
		Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Procedure DeleteSynchronizationSettingInCorrespondent(DeletionSettings, Result)
	
	ExchangePlanName    = DataExchangeCached.GetExchangePlanName(DeletionSettings.ExchangeNode);
	NodeID = DataExchangeServer.NodeIDForExchange(DeletionSettings.ExchangeNode);
		
	TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(
		DeletionSettings.ExchangeNode);
		
	If TransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(
			DeletionSettings.ExchangeNode, TransportKind);
		ConnectionResult = DataExchangeServer.EstablishExternalConnectionWithInfobase(ConnectionSettings);
	
		ExternalConnection = ConnectionResult.Connection;
		If ExternalConnection = Undefined Then
			Result.ErrorMessageInCorrespondent = ConnectionResult.DetailedErrorDescription;
			Result.SettingDeletedInCorrespondent = False;
			Return;
		EndIf;
		
		CorrespondentNode = ExternalConnection.DataExchangeServer.ExchangePlanNodeByCode(ExchangePlanName,
			NodeID);
			
		If CorrespondentNode = Undefined Then
			Result.ErrorMessageInCorrespondent = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?? ??????????????????-???????????????????????????? ???? ???????????? ???????? ?????????? ???????????? ""%1"" ???? ???????? ""%2"".'; en = 'The ""%1"" exchange plan node is not found in the correspondent application by the ""%2"" code.'; pl = 'W programie-korespondencie nie znaleziono w??z??a planu wymiany ""%1"" wed??ug kodu ""%2""-';es_ES = 'En el programa-correspondiente no se ha encontrado un nodo del plan de cambio ""%1"" por el c??digo ""%2"".';es_CO = 'En el programa-correspondiente no se ha encontrado un nodo del plan de cambio ""%1"" por el c??digo ""%2"".';tr = 'Muhabir program??nda ""%1"" kodu ile ""%2"" al????veri?? plan??n ??nitesi bulunamad??.';it = 'Il nodo del piano di scambio ""%1"" non ?? stato trovato nell''applicazione corrispondente con il codice ""%2"".';de = 'Im korrespondierenden Programm ist kein Austauschplanknoten ""%1"" nach Code ""%2"" zu finden.'"),
				ExchangePlanName, NodeID);
			Result.SettingDeletedInCorrespondent = False;
			Return;
		EndIf;
		
		Try
			ExternalConnection.DataExchangeServer.DeleteSynchronizationSetting(CorrespondentNode);
		Except
			Result.SettingDeletedInCorrespondent = False;
			Result.ErrorMessageInCorrespondent = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
		EndTry;
		
	ElsIf TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(
			DeletionSettings.ExchangeNode);
		
		InterfaceVersions = Undefined;
		Try
			InterfaceVersions = DataExchangeCached.CorrespondentVersions(ConnectionSettings);
		Except
			Result.ErrorMessageInCorrespondent = DetailErrorDescription(ErrorInfo());
			Result.SettingDeletedInCorrespondent = False;
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
			Return;
		EndTry;
		
		WSProxy = Undefined;
		If InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			WSProxy = DataExchangeServer.GetWSProxy_3_0_1_1(ConnectionSettings);
		Else
			Result.ErrorMessageInCorrespondent = NStr("ru = '???????????????? ?????????????????? ?????????????????????????? ???? ?????????????? ??????????????????-???????????????????????????? ???? ???????? ?????????????????? ???? ????????????????????????????.'; en = 'Deletion of synchronisation settings on the correspondent application side from this application is not supported.'; pl = 'Usuwanie ustawienia synchronizacji na stronie programu-korespondenta z tego programu nie jest obs??ugiwane.';es_ES = 'No se admite la eliminaci??n del ajuste de sincronizaci??n en el lado del programa-correspondiente de este programa.';es_CO = 'No se admite la eliminaci??n del ajuste de sincronizaci??n en el lado del programa-correspondiente de este programa.';tr = 'Bu programdan muhabir program taraf??nda senkronizasyon ayar?? kald??r??lamaz.';it = 'La cancellazione delle impostazioni di sincronizzazione nell''applicazione corrispondente da questa applicazione non ?? supportata.';de = 'Das L??schen der Synchronisationseinstellung auf der korrespondierenden Seite dieses Programms wird nicht unterst??tzt.'");
			Result.SettingDeletedInCorrespondent = False;
			Return;
		EndIf;
		
		If WSProxy = Undefined Then
			Cancel = True;
			Return;
		EndIf;
		
		Try
			WSProxy.RemoveExchangeNode(ExchangePlanName, NodeID);
		Except
			Result.SettingDeletedInCorrespondent = False;
			Result.ErrorMessageInCorrespondent = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.DataExchangeDeletionEventLogEvent(),
				EventLogLevel.Error, , , Result.ErrorMessageInCorrespondent);
		EndTry;
		
	Else
		Result.SettingDeletedInCorrespondent = False;
		Result.ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '?????? ???????? ?????????????????????? ""%1"" ???? ???????????????????????????? ???????????????? ?????????????????? ?????????????????????????? ???? ?????????????? ??????????????????-????????????????????????????.'; en = 'Deletion of synchronisation settings on the correspondent application side is not supported for the ""%1"" connection kind.'; pl = 'Dla rodzaju po????czenia ""%1"" nie jest obs??ugiwane usuwanie ustawienia synchronizacji na stronie programu-korespondenta.';es_ES = 'Para el tipo de conexi??n ""%1"" no se admite la eliminaci??n del ajuste de sincronizaci??n en el lado del programa-correspondiente.';es_CO = 'Para el tipo de conexi??n ""%1"" no se admite la eliminaci??n del ajuste de sincronizaci??n en el lado del programa-correspondiente.';tr = '""%1"" Ba??lant?? t??r?? i??in, muhabir program taraf??nda senkronizasyon ayar?? kald??r??lmaz.';it = 'La cancellazione delle impostazioni di sincronizzazione nell''applicazione corrispondente da questa applicazione non ?? supportata per il tipo ""%1"" di connessione.';de = 'F??r den Verbindungstyp ""%1"" wird das Entfernen von Synchronisationseinstellungen auf der Seite des korrespondierenden Programms nicht unterst??tzt.'"),
			TransportKind);
	EndIf;
	
EndProcedure

Procedure RegisterDataForInitialExport(Parameters, ResultAddress) Export
	
	RegistrationSettings = Undefined;
	Parameters.Property("RegistrationSettings", RegistrationSettings);
	
	Result = New Structure;
	Result.Insert("DataRegistered", True);
	Result.Insert("ErrorMessage",      "");
	
	Try
		DataExchangeServer.RegisterDataForInitialExport(RegistrationSettings.ExchangeNode);
	Except
		Result.DataRegistered = False;
		Result.ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.RegisterDataForInitialExportEventLogEvent(),
			EventLogLevel.Error, , , Result.ErrorMessage);
	EndTry;
	
	PutToTempStorage(Result, ResultAddress);
	
EndProcedure

Function PredefinedScheduleEveryHour() Export
	
	Months = New Array;
	Months.Add(1);
	Months.Add(2);
	Months.Add(3);
	Months.Add(4);
	Months.Add(5);
	Months.Add(6);
	Months.Add(7);
	Months.Add(8);
	Months.Add(9);
	Months.Add(10);
	Months.Add(11);
	Months.Add(12);
	
	WeekDays = New Array;
	WeekDays.Add(1);
	WeekDays.Add(2);
	WeekDays.Add(3);
	WeekDays.Add(4);
	WeekDays.Add(5);
	WeekDays.Add(6);
	WeekDays.Add(7);
	
	Schedule = New JobSchedule;
	Schedule.Months                   = Months;
	Schedule.WeekDays                = WeekDays;
	Schedule.RepeatPeriodInDay = 60 * 60; // 60 minutes
	Schedule.DaysRepeatPeriod        = 1;       // every day
	
	Return Schedule;
	
EndFunction

Function NodeCode(ConnectionSettings)
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		Return ConnectionSettings.SourceInfobasePrefix;
			
	Else
		
		Return ConnectionSettings.SourceInfobaseID;
		
	EndIf;
	
EndFunction

Function CorrespondentNodeCode(ConnectionSettings)
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		Return ConnectionSettings.DestinationInfobasePrefix;
			
	Else
		
		Return ConnectionSettings.DestinationInfobaseID;
		
	EndIf;
	
EndFunction

Procedure CreateUpdateExchangePlanNodes(ConnectionSettings)
	
	ThisNodeCode  = NodeCode(ConnectionSettings);
	NewNodeCode = CorrespondentNodeCode(ConnectionSettings);
	
	ExchangePlanManager = ExchangePlans[ConnectionSettings.ExchangePlanName];
	
	// Refreshing predefined node code of this base if it is not filled in.
	ThisNode = ExchangePlanManager.ThisNode();
	
	ThisNodeCodeInDatabase = Common.ObjectAttributeValue(ThisNode, "Code");
	IsDIBExchangePlan  = DataExchangeCached.IsDistributedInfobaseExchangePlan(
		ConnectionSettings.ExchangePlanName);
	
	If IsBlankString(ThisNodeCodeInDatabase) Then
		
		ThisNodeObject = ThisNode.GetObject();
		ThisNodeObject.Code = ThisNodeCode;
		ThisNodeObject.Description = ConnectionSettings.ThisInfobaseDescription;
		ThisNodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		ThisNodeObject.Write();
		
		ThisNodeCodeInDatabase = ThisNodeCode;
		
	EndIf;
	
	CreateNewNode = False;
	
	// Receiving the correspondent node.
	If IsDIBExchangePlan
		AND ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup" Then
		
		MasterNode = DataExchangeServer.MasterNode();
		
		If MasterNode = Undefined Then
			
			Raise NStr("ru = '?????????????? ???????? ?????? ?????????????? ???????????????????????????? ???????? ???? ??????????????????.
							|????????????????, ???????????????????????????? ???????? ???? ???????????????? ?????????????????????? ?????????? ?? ??????.'; 
							|en = 'Master node is not determined for the current infobase.
							|The infobase might not be a DIB subnode.'; 
							|pl = 'G????wny w??ze?? bie????cej bazy informacyjnej nie zosta?? okre??lony.
							|By?? mo??e baza informacyjna nie jest podrz??dnym w??z??em w RIB.';
							|es_ES = 'El nodo principal para la infobase actual no est?? determinado.
							|Probablemente, la infobase no es un nodo subordinado en el RIB.';
							|es_CO = 'El nodo principal para la infobase actual no est?? determinado.
							|Probablemente, la infobase no es un nodo subordinado en el RIB.';
							|tr = 'Ge??erli veritaban?? i??in ana ??nite tan??mlanmam????t??r.
							| Veritaban?? R??B''deki alt ??nitesi olmayabilir.';
							|it = 'Il nodo principale non ?? determinato per l''infobase corrente.
							|L''infobase potrebbe non essere un nodo DIB subordinato.';
							|de = 'Der Hauptknoten f??r die aktuelle Infobase ist nicht festgelegt.
							|Vielleicht ist die Infobase kein untergeordneter Knoten im RIB.'");
		EndIf;
		
		NewNode = MasterNode.GetObject();
		
		// Transferring common data from the predefined node.
		ThisNodeObject = ThisNode.GetObject();
		
		ExchangePlanMetadata = NewNode.Metadata();
		SharedDataString = DataExchangeServer.ExchangePlanSettingValue(ConnectionSettings.ExchangePlanName,
			"CommonNodeData", ConnectionSettings.ExchangeSettingsOption);
		
		SharedData = StrSplit(SharedDataString, ", ", False);
		For Each ItemCommonData In SharedData Do
			If ExchangePlanMetadata.TabularSections.Find(ItemCommonData) = Undefined Then
				FillPropertyValues(NewNode, ThisNodeObject, ItemCommonData);
			Else
				NewNode[ItemCommonData].Load(ThisNodeObject[ItemCommonData].Unload());
			EndIf;
		EndDo;
	Else
		// Creating or updating the node.
		NewNodeRef = ExchangePlanManager.FindByCode(NewNodeCode);
		
		CreateNewNode = NewNodeRef.IsEmpty();
		
		If CreateNewNode Then
			NewNode = ExchangePlanManager.CreateNode();
			NewNode.Code = NewNodeCode;
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '???????????????? ???????????????? ?????????????????? ""%1"" ???? ?????????????????? (""%2""). ?????? ???????????????????? ?????????????????? ?????????????????????????? ?? ?????????? ???? ??????????????????.
				|?????? ?????????????????????? ???????????????????? ?????????????????? ?? ?????????????????? ""%1"" ???????????????????? ?????????????? ???????????????????????????? ????????, ???????????????? ???? ????????????????.'; 
				|en = 'Prefix value of the ""%1"" application is not unique (""%2""). Synchronization setting with the specified prefix already exists.
				|To continue, assign a unique infobase prefix different from the current one in the ""%1"" application.'; 
				|pl = 'Warto???? przedrostka programu ""%1"" nie jest unikalna (""%2""). Istnieje ju?? konfigurowanie synchronizacji z tym samym przedrostkiem.
				|Aby kontynuowa??, nale??y przypisa?? w programie ""%1"" unikalny przedrostek bazy informacyjnej, odmienny od aktualnego.';
				|es_ES = 'El valor del prefijo del programa ""%1"" no es ??nico (""%2""). Ya existe un ajuste de sincronizaci??n con el mismo prefijo.
				|Para la aplicaci??n es necesario establecer en el programa ""%1"" un prefijo ??nico de la base de informaci??n que es distinta de la actual.';
				|es_CO = 'El valor del prefijo del programa ""%1"" no es ??nico (""%2""). Ya existe un ajuste de sincronizaci??n con el mismo prefijo.
				|Para la aplicaci??n es necesario establecer en el programa ""%1"" un prefijo ??nico de la base de informaci??n que es distinta de la actual.';
				|tr = '""%1""Program??n ??nek de??eri benzersiz de??il (""%2""). Ayn?? ??nek ile e??itleme ayar?? zaten mevcut. 
				|Devam etmek i??in, ""%1"" program??nda, mevcut ile ayn?? olmayan, benzersiz bir veri taban?? ??neki atanmal??d??r.';
				|it = 'Il valore prefisso dell''applicazione ""%1"" non ?? univoco (""%2""). Esistono gi?? le impostazioni di sincronizzazione con il prefisso specificato.
				|Per continuare, assegna un prefisso infobase univoco differente da quello attuale nell''applicazione ""%1"".';
				|de = 'Der Wert des Programmpr??fix ""%1"" ist nicht eindeutig (""%2""). Es gibt bereits eine Synchronisationseinstellung mit dem gleichen Pr??fix.
				|Um fortzufahren, m??ssen Sie im Programm ""%1"" ein eindeutiges Informationsbasispr??fix vergeben, das sich vom aktuellen Pr??fix unterscheidet.'"),
				ConnectionSettings.SecondInfobaseDescription, NewNodeCode);
		EndIf;
		
		NewNode.Description = ConnectionSettings.SecondInfobaseDescription;
		
		If Common.HasObjectAttribute("SettingsMode", Metadata.ExchangePlans[ConnectionSettings.ExchangePlanName]) Then
			NewNode.SettingsMode = ConnectionSettings.ExchangeSettingsOption;
		EndIf;
		
		If CreateNewNode Then
			NewNode.Fill(Undefined);
		EndIf;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			If ValueIsFilled(ConnectionSettings.ExchangeFormatVersion) Then
				NewNode.ExchangeFormatVersion = ConnectionSettings.ExchangeFormatVersion;
			EndIf;
		EndIf;
		
	EndIf;
	
	// Resetting message counters.
	NewNode.SentNo = 0;
	NewNode.ReceivedNo     = 0;
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable()
		AND DataExchangeServer.IsSeparatedSSLExchangePlan(ConnectionSettings.ExchangePlanName) Then
		
		NewNode.RegisterChanges = True;
		
	EndIf;
	
	If ValueIsFilled(ConnectionSettings.NewRef) Then
		NewNode.SetNewObjectRef(ConnectionSettings.NewRef);
	EndIf;
	
	NewNode.DataExchange.Load = True;
	NewNode.Write();
	
	If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
		If ConnectionSettings.SupportedObjectsInFormat <> Undefined Then
			InformationRegisters.XDTODataExchangeSettings.UpdateCorrespondentSettings(NewNode.Ref,
				"SupportedObjects", ConnectionSettings.SupportedObjectsInFormat.Get());
		EndIf;
		
		RecordStructure = New Structure;
		RecordStructure.Insert("InfobaseNode",       NewNode.Ref);
		RecordStructure.Insert("CorrespondentExchangePlanName", ConnectionSettings.CorrespondentExchangePlanName);
		
		DataExchangeServer.UpdateInformationRegisterRecord(RecordStructure, "XDTODataExchangeSettings");
	EndIf;
	
	ConnectionSettings.InfobaseNode = NewNode.Ref;
	
	// Node common data.
	InformationRegisters.CommonInfobasesNodesSettings.UpdatePrefixes(
		ConnectionSettings.InfobaseNode,
		?(ConnectionSettings.UsePrefixesForExchangeSettings, ConnectionSettings.SourceInfobasePrefix, ""),
		ConnectionSettings.DestinationInfobasePrefix);
	
	If CreateNewNode
		AND Not Common.DataSeparationEnabled() Then
		DataExchangeServer.UpdateDataExchangeRules();
	EndIf;
	
	If ThisNodeCode <> ThisNodeCodeInDatabase
		AND DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
		AND (ConnectionSettings.UsePrefixesForExchangeSettings
			Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings) Then
		// Node in the correspondent base needs recoding.
		StructureTemporaryCode = New Structure;
		StructureTemporaryCode.Insert("Correspondent", ConnectionSettings.InfobaseNode);
		StructureTemporaryCode.Insert("NodeCode",       ThisNodeCode);
		
		DataExchangeServer.AddRecordToInformationRegister(StructureTemporaryCode, "PredefinedNodesAliases");
	EndIf;

EndProcedure

Procedure UpdateDataExchangeTransportSettings(ConnectionSettings)
	
	RecordStructure = New Structure;
	RecordStructure.Insert("Correspondent",                           ConnectionSettings.InfobaseNode);
	RecordStructure.Insert("DefaultExchangeMessagesTransportKind", ConnectionSettings.ExchangeMessagesTransportKind);
	
	RecordStructure.Insert("COMOperatingSystemAuthentication");
	RecordStructure.Insert("COMInfobaseOperatingMode");
	RecordStructure.Insert("COM1CEnterpriseServerSideInfobaseName");
	RecordStructure.Insert("COMUsername");
	RecordStructure.Insert("COM1CEnterpriseServerName");
	RecordStructure.Insert("COMInfobaseDirectory");
	RecordStructure.Insert("COMUserPassword");
	
	RecordStructure.Insert("EMAILMaxMessageSize");
	RecordStructure.Insert("EMAILCompressOutgoingMessageFile");
	RecordStructure.Insert("EMAILUserAccount");
	RecordStructure.Insert("EMAILTransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("FILEInformationExchangeDirectory");
	RecordStructure.Insert("FILECompressOutgoingMessageFile");
	RecordStructure.Insert("FILETransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("FTPCompressOutgoingMessageFile");
	RecordStructure.Insert("FTPConnectionMaxMessageSize");
	RecordStructure.Insert("FTPConnectionPassword");
	RecordStructure.Insert("FTPConnectionPassiveConnection");
	RecordStructure.Insert("FTPConnectionUser");
	RecordStructure.Insert("FTPConnectionPort");
	RecordStructure.Insert("FTPConnectionPath");
	RecordStructure.Insert("FTPTransliterateExchangeMessageFileNames");
	
	RecordStructure.Insert("WSWebServiceURL");
	RecordStructure.Insert("WSUsername");
	RecordStructure.Insert("WSPassword");
	RecordStructure.Insert("WSRememberPassword");
	
	RecordStructure.Insert("WSUseHighVolumeDataTransfer", True);
	
	RecordStructure.Insert("ArchivePasswordExchangeMessages");
	
	FillPropertyValues(RecordStructure, ConnectionSettings);
	
	InformationRegisters.DataExchangeTransportSettings.AddRecord(RecordStructure);
	
EndProcedure

#Region SettingsInXMLFormat

Procedure FillConnectionSettingsFromConstant(ConnectionSettings) Export
	
	SetPrivilegedMode(True);
	StringForConnection = Constants.SubordinateDIBNodeSettings.Get();
	
	FillConnectionSettingsFromXMLString(ConnectionSettings, StringForConnection);
	
EndProcedure

Procedure FillConnectionSettingsFromXMLString(ConnectionSettings, FileNameXMLString, IsFile = False) Export
	
	SettingsStructure = Undefined;
	Try
		ReadConnectionSettingsFromXMLToStructure(SettingsStructure, FileNameXMLString, IsFile);
	Except
		Raise;
	EndTry;
	
	// Verifying read from the file parameters.
	CorrectSettingsFile = False;
	ExchangePlanNameInSettings = "";
	
	If SettingsStructure.Property("ExchangePlanName", ExchangePlanNameInSettings)
		AND SettingsStructure.ExchangePlanName = ConnectionSettings.ExchangePlanName Then
		CorrectSettingsFile = True;
	Else
		CorrectSettingsFile = False;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			If SettingsStructure.Property("XDTOExchangeParameters")
				AND SettingsStructure.XDTOExchangeParameters.Property("ExchangeFormat")
				AND SettingsStructure.XDTOExchangeParameters.ExchangeFormat = ConnectionSettings.ExchangeFormat Then
				CorrectSettingsFile = True;
			EndIf;
		EndIf;
	EndIf;
	
	If Not CorrectSettingsFile Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????? ???? ???????????????? ???????????????? ?????????????????????? ?????? ???????????????????? ???????????? ??????????????.
			|???????????? ?????????? ""%1"".
			|?? ?????????? ?????????????? ?????????????????? ?????? ???????????? ""%2"".'; 
			|en = 'File does not have connection settings for selected data exchange.
			|The ""%1"" exchange is selected.
			|File has the ""%2"" exchange settings.'; 
			|pl = 'Plik nie zawiera ustawie?? po????czenia dla wybranej wymiany danych.
			|Wybrana wymiana ""%1"".
			|W pliku s?? okre??lone ustawienia do wymiany ""%2"".';
			|es_ES = 'El archivo no contiene ajustes de conexi??n para el cambio de datos seleccionado.
			|Se ha seleccionado el cambio ""%1"".
			|En el archivo se han indicado ajustes para cambiar ""%2"".';
			|es_CO = 'El archivo no contiene ajustes de conexi??n para el cambio de datos seleccionado.
			|Se ha seleccionado el cambio ""%1"".
			|En el archivo se han indicado ajustes para cambiar ""%2"".';
			|tr = 'Dosya se??ilen veri payla????m?? i??in ba??lant?? ayarlar??n?? i??ermez. 
			| ""%1"" veri al????veri??i se??ildi. 
			|Dosyada, ""%2"" payla????m?? i??in ayarlar belirtilmi??tir.';
			|it = 'Il file non ha le impostazioni di connessione per lo scambio dati selezionato.
			|?? stato selezionato lo scambio ""%1"".
			|Il file ha le impostazioni di scambio ""%2"".';
			|de = 'Die Datei enth??lt keine Verbindungseinstellungen f??r den ausgew??hlten Datenaustausch.
			|Der Austausch ""%1"" ist ausgew??hlt.
			|Die Datei enth??lt die Einstellungen f??r den Austausch ""%2"".'"),
			ConnectionSettings.ExchangePlanName, ExchangePlanNameInSettings);
	EndIf;
	
	If Not ValueIsFilled(ConnectionSettings.CorrespondentExchangePlanName) Then
		ConnectionSettings.CorrespondentExchangePlanName = SettingsStructure.ExchangePlanName;
	EndIf;
	
	FillPropertyValues(ConnectionSettings, SettingsStructure, , "ExchangePlanName, SourceInfobasePrefix");
	
	ExchangePlanEmptyRef = ExchangePlans[ConnectionSettings.ExchangePlanName].EmptyRef();
	
	ConnectionSettings.UsePrefixesForExchangeSettings = 
		Not DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
			Or Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(ExchangePlanEmptyRef);
			
	SecondInfobaseNewNodeCode = Undefined;		
	SettingsStructure.Property("SecondInfobaseNewNodeCode", SecondInfobaseNewNodeCode);
	
	ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings =
		ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings
			Or (ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup"
				AND DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName)
				AND ValueIsFilled(SecondInfobaseNewNodeCode)
				AND StrLen(SecondInfobaseNewNodeCode) <> 36);
			
	If Not ConnectionSettings.UsePrefixesForExchangeSettings
		AND Not ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		SettingsStructure.Property("PredefinedNodeCode", ConnectionSettings.SourceInfobaseID);
		SettingsStructure.Property("SecondInfobaseNewNodeCode",  ConnectionSettings.DestinationInfobaseID);
		
	Else
		
		SettingsStructure.Property("SourceInfobasePrefix", ConnectionSettings.SourceInfobasePrefix);
		SettingsStructure.Property("SecondInfobaseNewNodeCode",            ConnectionSettings.DestinationInfobasePrefix);
		
	EndIf;
	
	If ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup"
		AND (ConnectionSettings.UsePrefixesForExchangeSettings
			Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings) Then
		
		IBPrefix = GetFunctionalOption("InfobasePrefix");
		If Not IsBlankString(IBPrefix)
			AND IBPrefix <> ConnectionSettings.SourceInfobasePrefix Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????????? ??????????????????, ?????????????????? ?????? ?????????????????? (""%1""), ???? ?????????????????????????? ???????????????? ?? ???????? ?????????????????? (""%2"").
				|?????? ?????????????????????? ???????????????????? ???????????? ?????????????????? ???????????? ???? ???????????? ??????????????????, ?? ?????????????? ???????????????????? ?????????????? (""%2"").'; 
				|en = 'Application prefix value specified during setup (""%1"") does not match the prefix in this application (""%2"").
				|To continue, start setup again from another application and specify the correct prefix (""%2"").'; 
				|pl = 'Przedrostek programu, podany podczas konfiguracji (""%1""), nie odpowiada przedrostkowi w tym programie (""%2"").
				|Aby kontynuowa??, nale??y rozpocz???? konfiguracj?? od nowa z innego programu i poda?? w??a??ciwy prefiks (""%2"").';
				|es_ES = 'El prefijo del programa indicado al ajustar (""%1"") no corresponde al prefijo en este programa (""%2"").
				|Para continuar es necesario empezar a ajustar de nuevo de otro programa e indicar un prefijo correcto (""%2"").';
				|es_CO = 'El prefijo del programa indicado al ajustar (""%1"") no corresponde al prefijo en este programa (""%2"").
				|Para continuar es necesario empezar a ajustar de nuevo de otro programa e indicar un prefijo correcto (""%2"").';
				|tr = 'Yap??land??r??lma esnas??nda belirtilen program ??neki (""%1""), bu programdaki ( ""%2"" ) ??nek ile e??le??miyor. 
				|Devam etmek i??in ba??ka bir programdan yeniden yap??land??rmaya ba??lamal?? ve do??ru ??nek ( ""%2"" ) belirtilmelidir.';
				|it = 'Il valore prefisso dell''applicazione specificato durante la configurazione (""%1"") non corrisponde al prefisso in questa applicazione (""%2"").
				|Per continuare, inizia di nuovo la configurazione da un''altra applicazione e indica il prefisso corretto (""%2"").';
				|de = 'Das in der Einstellung (""%1"") angegebene Programmpr??fix entspricht nicht dem Pr??fix in diesem Programm (""%2"").
				|Um fortzufahren, m??ssen Sie von einem anderen Programm aus erneut starten und das richtige Pr??fix (""%2"") eingeben.'"),
				ConnectionSettings.SourceInfobasePrefix, IBPrefix);
			
		EndIf;
		
	EndIf;
	
	EmailAccount = Undefined;
	
	If Common.SubsystemExists("StandardSubsystems.EmailOperations")
		AND SettingsStructure.Property("EmailAccount", EmailAccount)
		AND EmailAccount <> Undefined Then
		
		ModuleEmailInternal = Common.CommonModule("EmailOperationsInternal");
		ThisInfobaseAccount = ModuleEmailInternal.ThisInfobaseAccountByCorrespondentAccountData(
			EmailAccount);
		ConnectionSettings.EMAILUserAccount = ThisInfobaseAccount.Ref;
		
	EndIf;
	
	// Supporting the exchange settings file of the 1.0 version format.
	If ConnectionSettings.ExchangeDataSettingsFileFormatVersion = "1.0" Then
		
		ConnectionSettings.ThisInfobaseDescription    = NStr("ru = '?????? ???????????????????????????? ????????'; en = 'This infobase'; pl = 'Ta baza informacyjna';es_ES = 'Es una infobase';es_CO = 'Es una infobase';tr = 'Bu veri taban??';it = 'Questo infobase';de = 'Dies ist eine Infobase'");
		ConnectionSettings.SecondInfobaseDescription  = SettingsStructure.DataExchangeExecutionSettingsDescription;
		ConnectionSettings.SecondInfobaseNewNodeCode = SettingsStructure.NewNodeCode;
		
	EndIf;
	
EndProcedure

Function ConnectionSettingsInXML(ConnectionSettings, FileName = "", EncodingType = "UTF-8") Export
	
	XMLWriter = New XMLWriter;
	
	If IsBlankString(FileName) Then
		XMLWriter.SetString(EncodingType);
	Else
		XMLWriter.OpenFile(FileName, EncodingType);
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	If ConnectionSettings.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		
		CorrespondentNode = ConnectionSettings.InfobaseNode;
		
		HeaderParameters = DataExchangeXDTOServer.ExchangeMessageHeaderParameters();
	
		HeaderParameters.ExchangeFormat            = ConnectionSettings.ExchangeFormat;
		HeaderParameters.IsExchangeViaExchangePlan = True;
		
	 	HeaderParameters.ExchangePlanName = ConnectionSettings.ExchangePlanName;
		HeaderParameters.PredefinedNodeAlias = DataExchangeServer.PredefinedNodeAlias(CorrespondentNode);
		
		HeaderParameters.RecipientID  = DataExchangeServer.CorrespondentNodeIDForExchange(CorrespondentNode);
		HeaderParameters.SenderID = DataExchangeServer.NodeIDForExchange(CorrespondentNode);
		
		FormatVersions = DataExchangeServer.ExchangePlanSettingValue(ConnectionSettings.ExchangePlanName, "ExchangeFormatVersions");
		For Each FormatVersion In FormatVersions Do
			HeaderParameters.SupportedVersions.Add(FormatVersion.Key);
		EndDo;
			
		HeaderParameters.SupportedObjects = DataExchangeXDTOServer.SupportedObjectsInFormat(
			ConnectionSettings.ExchangePlanName, "SendReceive", CorrespondentNode);
		
		HeaderParameters.Prefix = DataExchangeServer.InfobasePrefix();
		
		HeaderParameters.CorrespondentNode = CorrespondentNode;
	
		DataExchangeXDTOServer.WriteExchangeMessageHeader(XMLWriter, HeaderParameters);
		
	Else
		XMLWriter.WriteStartElement("SetupParameters");
		XMLWriter.WriteAttribute("FormatVersion", DataExchangeSettingsFormatVersion());
		
		XMLWriter.WriteNamespaceMapping("xsd", "http://www.w3.org/2001/XMLSchema");
		XMLWriter.WriteNamespaceMapping("xsi", "http://www.w3.org/2001/XMLSchema-instance");
		XMLWriter.WriteNamespaceMapping("v8",  "http://v8.1c.ru/data");
		
		WriteConnectionParameters(XMLWriter, ConnectionSettings);
		
		If ConnectionSettings.UseTransportParametersEMAIL Then
			WriteEmailAccount(XMLWriter, ConnectionSettings);
		EndIf;
		
		If DataExchangeCached.IsXDTOExchangePlan(ConnectionSettings.ExchangePlanName) Then
			WriteXDTOExchangeParameters(XMLWriter, ConnectionSettings.ExchangePlanName);
		EndIf;
		
		XMLWriter.WriteEndElement(); // SetupParameters
	EndIf;
	
	Return XMLWriter.Close();
	
EndFunction

Procedure WriteConnectionParameters(XMLWriter, ConnectionSettings)
	
	XMLWriter.WriteStartElement("MainExchangeParameters");
	
	AddXMLRecord(XMLWriter, ConnectionSettings.ExchangePlanName,         "ExchangePlanName");
	
	AddXMLRecord(XMLWriter, ConnectionSettings.ThisInfobaseDescription,   "SecondInfobaseDescription");
	AddXMLRecord(XMLWriter, ConnectionSettings.SecondInfobaseDescription, "ThisInfobaseDescription");
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.SourceInfobasePrefix, "SecondInfobaseNewNodeCode");
		
	Else
		
		AddXMLRecord(XMLWriter, ConnectionSettings.SourceInfobaseID, "SecondInfobaseNewNodeCode");
		
	EndIf;
	
	AddXMLRecord(XMLWriter, ConnectionSettings.DestinationInfobasePrefix, "SourceInfobasePrefix");
	
	// Exchange message transport settings.
	If ConnectionSettings.ExchangeMessagesTransportKind <> Enums.ExchangeMessagesTransportTypes.WS Then
		AddXMLRecord(XMLWriter, ConnectionSettings.ExchangeMessagesTransportKind, "ExchangeMessagesTransportKind");
	Else
		AddXMLRecord(XMLWriter, Undefined, "ExchangeMessagesTransportKind");
	EndIf;
	AddXMLRecord(XMLWriter, ConnectionSettings.ArchivePasswordExchangeMessages,  "ArchivePasswordExchangeMessages");
	
	If ConnectionSettings.UseTransportParametersEMAIL Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILMaxMessageSize, "EMAILMaxMessageSize");
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILCompressOutgoingMessageFile,        "EMAILCompressOutgoingMessageFile");
		AddXMLRecord(XMLWriter, ConnectionSettings.EMAILUserAccount,                         "EMAILUserAccount");
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersFILE Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.FILEInformationExchangeDirectory,       "FILEInformationExchangeDirectory");
		AddXMLRecord(XMLWriter, ConnectionSettings.FILECompressOutgoingMessageFile, "FILECompressOutgoingMessageFile");
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersFTP Then
		
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPCompressOutgoingMessageFile,                  "FTPCompressOutgoingMessageFile");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionMaxMessageSize, "FTPConnectionMaxMessageSize");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPassword,                                "FTPConnectionPassword");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPassiveConnection,                   "FTPConnectionPassiveConnection");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionUser,                          "FTPConnectionUser");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPort,                                  "FTPConnectionPort");
		AddXMLRecord(XMLWriter, ConnectionSettings.FTPConnectionPath,                                  "FTPConnectionPath");
		
	EndIf;
	
	If ConnectionSettings.UseTransportParametersCOM Then
		
		IBConnectionParameters = CommonClientServer.GetConnectionParametersFromInfobaseConnectionString(
			InfoBaseConnectionString());
		
		InfobaseOperatingMode             = IBConnectionParameters.InfobaseOperatingMode;
		NameOfInfobaseOn1CEnterpriseServer = IBConnectionParameters.NameOfInfobaseOn1CEnterpriseServer;
		NameOf1CEnterpriseServer                     = IBConnectionParameters.NameOf1CEnterpriseServer;
		InfobaseDirectory                   = IBConnectionParameters.InfobaseDirectory;
		
		InfobaseUser   = InfoBaseUsers.CurrentUser();
		OSAuthentication = InfobaseUser.OSAuthentication;
		Username  = InfobaseUser.Name;
		
		AddXMLRecord(XMLWriter, InfobaseOperatingMode,             "COMInfobaseOperatingMode");
		AddXMLRecord(XMLWriter, NameOfInfobaseOn1CEnterpriseServer, "COM1CEnterpriseServerSideInfobaseName");
		AddXMLRecord(XMLWriter, NameOf1CEnterpriseServer,                     "COM1CEnterpriseServerName");
		AddXMLRecord(XMLWriter, InfobaseDirectory,                   "COMInfobaseDirectory");
		AddXMLRecord(XMLWriter, OSAuthentication,                            "COMOperatingSystemAuthentication");
		AddXMLRecord(XMLWriter, Username,                             "COMUsername");
		
	EndIf;
	
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersEMAIL, "UseTransportParametersEMAIL");
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersFILE,  "UseTransportParametersFILE");
	AddXMLRecord(XMLWriter, ConnectionSettings.UseTransportParametersFTP,   "UseTransportParametersFTP");
	
	// Supporting the exchange settings file of the 1.0 version format.
	AddXMLRecord(XMLWriter, ConnectionSettings.ThisInfobaseDescription, "DataExchangeExecutionSettingsDescription");
	
	If ConnectionSettings.UsePrefixesForExchangeSettings
		Or ConnectionSettings.UsePrefixesForCorrespondentExchangeSettings Then
		AddXMLRecord(XMLWriter, ConnectionSettings.SourceInfobasePrefix, "NewNodeCode");
	Else
		AddXMLRecord(XMLWriter, ConnectionSettings.SourceInfobaseID, "NewNodeCode");
	EndIf;
	
	IBNodeCode = Common.ObjectAttributeValue(ConnectionSettings.InfobaseNode, "Code");
	
	AddXMLRecord(XMLWriter, IBNodeCode, "PredefinedNodeCode");
	
	XMLWriter.WriteEndElement(); // MainExchangeParameters
	
EndProcedure

Procedure WriteEmailAccount(XMLWriter, ConnectionSettings)
	
	EMAILUserAccount = Undefined;
	If ValueIsFilled(ConnectionSettings.EMAILUserAccount) Then
		EMAILUserAccount = ConnectionSettings.EMAILUserAccount.GetObject();
	EndIf;
	
	XMLWriter.WriteStartElement("EmailAccount");
	WriteXML(XMLWriter, EMAILUserAccount);
	XMLWriter.WriteEndElement(); // EmailAccount
	
EndProcedure

Procedure WriteXDTOExchangeParameters(XMLWriter, ExchangePlanName)
	
	XMLWriter.WriteStartElement("XDTOExchangeParameters");
	
	ExchangeFormat = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "ExchangeFormat");
	
	WriteXML(XMLWriter, ExchangeFormat, "ExchangeFormat", XMLTypeAssignment.Explicit);
	
	XMLWriter.WriteEndElement(); // XDTOExchangeParameters
	
EndProcedure

Procedure AddXMLRecord(XMLWriter, Value, FullName)
	
	WriteXML(XMLWriter, Value, FullName, XMLTypeAssignment.Explicit);
	
EndProcedure

Procedure ReadConnectionSettingsFromXMLToStructure(SettingsStructure, FileNameXMLString, IsFile)
	
	SettingsStructure = New Structure;
	
	XMLReader = New XMLReader;
	If IsFile Then
		XMLReader.OpenFile(FileNameXMLString);
	Else
		XMLReader.SetString(FileNameXMLString);
	EndIf;
	
	XMLReader.Read(); // SetupParameters
	
	FormatVersion = XMLReader.GetAttribute("FormatVersion");
	SettingsStructure.Insert("ExchangeDataSettingsFileFormatVersion",
		?(FormatVersion = Undefined, "1.0", FormatVersion));
	
	XMLReader.Read(); // MainExchangeParameters
	
	// Reading the MainExchangeParameters node.
	ReadDataToStructure(SettingsStructure, XMLReader);
	
	If SettingsStructure.Property("UseTransportParametersEMAIL")
		AND SettingsStructure.UseTransportParametersEMAIL Then
		
		// Reading the EmailAccount node.
		XMLReader.Read(); // EmailAccount {ItemStart}
		
		SettingsStructure.Insert("EmailAccount", ReadXML(XMLReader));
		
		XMLReader.Read(); // EmailAccount {ItemEnd}
		
	EndIf;
		
	XMLReader.Close();
	
EndProcedure

Procedure ReadDataToStructure(SettingsStructure, XMLReader)
	
	If XMLReader.NodeType <> XMLNodeType.StartElement Then
		Raise NStr("ru = '???????????? ?????????????? XML.'; en = 'XML parsing error.'; pl = 'B????d analizy XML.';es_ES = 'Error de analizar XML.';es_CO = 'Error de analizar XML.';tr = 'XML ayr????t??rma hatas??.';it = 'Errore di analisi XML.';de = 'XML-Analysefehler.'");
	EndIf;
	
	XMLReader.Read();
	
	While XMLReader.NodeType <> XMLNodeType.EndElement Do
		
		NodeName = XMLReader.Name;
		SettingsStructure.Insert(NodeName, ReadXML(XMLReader));
		
	EndDo;
	
	XMLReader.Read();
	
EndProcedure

Function XDTOCorrespondentSettingsFromXML(FileNameXMLString, IsFile, ExchangeNode) Export
	
	XMLReader = New XMLReader;
	If IsFile Then
		XMLReader.OpenFile(FileNameXMLString);
	Else
		XMLReader.SetString(FileNameXMLString);
	EndIf;
	
	XMLReader.Read(); // Message
	XMLReader.Read(); // Header
	
	Header = XDTOFactory.ReadXML(XMLReader,
		XDTOFactory.Type("http://www.1c.ru/SSL/Exchange/Message", XMLReader.LocalName));
		
	SettingsStructure = New Structure;
	DataExchangeXDTOServer.FillCorrespondentXDTOSettingsStructure(SettingsStructure, Header, , ExchangeNode);
	
	// Checking if the sender UID corresponds to the format.
	Try
		UID = New UUID(Header.Confirmation.From);
	Except
		Raise NStr("ru = '?????????????????????????? ?????????????????????? ?? ?????????? ?? ?????????????????????? EnterpriseData ???? ?????????????????????????? ??????????????.'; en = 'Sender ID in the EnterpriseData settings file does not match the format.'; pl = 'Identyfikator nadawcy w pliku z ustawieniami EnterpriseData nie odpowiada formatu.';es_ES = 'El identificador del remitente en el archivo con ajustes EnterpriseData no corresponde al formato.';es_CO = 'El identificador del remitente en el archivo con ajustes EnterpriseData no corresponde al formato.';tr = 'EnterpriseData ayarlar??na sahip bir dosyadaki g??nderenin kimli??i bi??imle e??le??miyor.';it = 'L''ID del mittente nel file di impostazioni EnterpriseData non corrisponde al formato.';de = 'Die Absender-Kennung in der EnterpriseData-Einstellungsdatei stimmt nicht mit dem Format ??berein.'");
	EndTry;
	
	SettingsStructure.Insert("SenderID", Header.Confirmation.From);
		
	XMLReader.Close();
	
	Return SettingsStructure;
	
EndFunction

#EndRegion

#EndRegion

#EndIf