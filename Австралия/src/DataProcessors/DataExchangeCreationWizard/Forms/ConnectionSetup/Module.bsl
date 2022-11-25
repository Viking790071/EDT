#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CheckCanUseForm(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	InitializeFormAttributes();
	
	InitializeFormProperties();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("ru = 'Прервать настройку параметров подключения для синхронизации данных?'; en = 'Abort configuration of connection parameters for data synchronization?'; pl = 'Przerwać ustawienie parametrów połączenia dla synchronizacji danych?';es_ES = '¿Interrumpir los ajustes de parámetros de conexión para sincronizar los datos?';es_CO = '¿Interrumpir los ajustes de parámetros de conexión para sincronizar los datos?';tr = 'Veri eşleşmesi için bağlantı parametrelerin ayarları durdurulsun mu?';it = 'Annullare la configurazione dei parametri di connessione per la sincronizzazione dei dati?';de = 'Verbindungseinstellungen für die Datensynchronisation unterbrechen?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ConnectionSetupMethodOnChange(Item)
	
	OnChangeConnectionSetupMethod();
	
EndProcedure

&AtClient
Procedure ImportConnectionSettingsFromFileOnChange(Item)
	
	OnChangeImportConnectionSettingsFromFile();
	
EndProcedure

&AtClient
Procedure ConnectionSettingsFileNameToImportStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Title", NStr("ru = 'Выберите файл с настройками подключения'; en = 'Select a file with connection settings'; pl = 'Wybierz plik z ustawieniami połączenia';es_ES = 'Seleccione un archivo con ajustes de conexión';es_CO = 'Seleccione un archivo con ajustes de conexión';tr = 'Bağlantı ayarlarına sahip bir dosya seçin';it = 'Selezionare un file con impostazioni di connessione';de = 'Wählen Sie eine Datei mit Verbindungseinstellungen aus'"));
	DialogSettings.Insert("Filter",    NStr("ru = 'Файл настроек подключения (*.xml)'; en = 'Connection setting file (*.xml)'; pl = 'Plik ustawień połączenia *.xml)';es_ES = 'Archivo de ajustes de conexión (*.xml)';es_CO = 'Archivo de ajustes de conexión (*.xml)';tr = 'Bağlantı ayarı dosyası (*.xml)';it = 'File impostazioni connessione (*.xml)';de = 'Verbindungseinstellungsdatei (*.xml)'") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ConnectionSettingsFileNameToImport", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure XDTOCorrespondentSettingsFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Title", NStr("ru = 'Выберите файл с настройками корреспондента'; en = 'Select a file with correspondent settings'; pl = 'Wybierz plik z ustawieniami korespondenta';es_ES = 'Seleccione un archivo con ajustes de correspondiente';es_CO = 'Seleccione un archivo con ajustes de correspondiente';tr = 'Muhabir ayarlarına sahip bir dosya seçin';it = 'Seleziona un file con impostazioni corrispondenti';de = 'Wählen Sie die korrespondierende Einstellungsdatei aus'"));
	DialogSettings.Insert("Filter",    NStr("ru = 'Файл настроек корреспондента (*.xml)'; en = 'Correspondent setting file (*.xml)'; pl = 'Plik ustawień korespondenta (*.xml)';es_ES = 'Archivo de ajustes de correspondiente (*.xml)';es_CO = 'Archivo de ajustes de correspondiente (*.xml)';tr = 'Muhabir ayarları dosyası (*.xml)';it = 'File impostazioni corrispondenti (*.xml)';de = 'Korrespondenzeinstellungsdatei (*.xml)'") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "XDTOCorrespondentSettingsFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ConnectionSettingsFileNameToExportStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Mode",     FileDialogMode.Save);
	DialogSettings.Insert("Title", NStr("ru = 'Укажите файл для сохранения настроек подключения'; en = 'Specify a file to save connection settings'; pl = 'Wybierz plik, aby zapisać ustawienia połączenia';es_ES = 'Indique un archivo para guardar los ajustes de conexión';es_CO = 'Indique un archivo para guardar los ajustes de conexión';tr = 'Bağlantı ayarlarının kaydı için bir dosya belirtin';it = 'Specifica un file dove salvare le impostazioni di connessione';de = 'Geben Sie die Datei an, in der die Verbindungseinstellungen gespeichert werden sollen'"));
	DialogSettings.Insert("Filter",    NStr("ru = 'Файл настроек подключения (*.xml)'; en = 'Connection setting file (*.xml)'; pl = 'Plik ustawień połączenia *.xml)';es_ES = 'Archivo de ajustes de conexión (*.xml)';es_CO = 'Archivo de ajustes de conexión (*.xml)';tr = 'Bağlantı ayarı dosyası (*.xml)';it = 'File impostazioni connessione (*.xml)';de = 'Verbindungseinstellungsdatei (*.xml)'") + "|*.xml");
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ConnectionSettingsFileNameToExport", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalConnectionConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure InternetConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure PassiveModeConnectionKindOnChange(Item)
	
	OnChangeConnectionKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFILEDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(ThisObject, "RegularCommunicationChannelsFILEDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseDirectoryStartChoice(Item, ChoiceData, StandardProcessing)
	
	DataExchangeClient.FileDirectoryChoiceHandler(ThisObject, "ExternalConnectionInfobaseDirectory", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFILEUsingOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFILEUsing();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFTPUsingOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFTPUsing();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsEMAILUsingOnChange(Item)
	
	OnChangeRegularCommunicationChannelsEMAILUsing();
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseOperationModeFileOnChange(Item)
	
	OnChangeExternalConnectionInfobaseOperationMode();
	
EndProcedure

&AtClient
Procedure ExternalConnectionInfobaseOperationModeClientServerOnChange(Item)
	
	OnChangeExternalConnectionInfobaseOperationMode();
	
EndProcedure

&AtClient
Procedure ExternalConnection1CEnterpriseAuthenticationKindOnChange(Item)
	
	OnChangeExternalConnectionAuthenticationKind();
	
EndProcedure

&AtClient
Procedure ExternalConnectionAuthenticationKindOperatingSystemOnChange(Item)
	
	OnChangeExternalConnectionAuthenticationKind();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsArchiveFilesOnChange(Item)
	
	OnChangeRegularCommunicationChannelsArchiveFiles();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsUseArchivePasswordOnChange(Item)
	
	OnChangeRegularCommunicationChannelsUseArchivePassword();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsFTPUseFileSizeLimitOnChange(Item)
	
	OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit();
	
EndProcedure

&AtClient
Procedure RegularCommunicationChannelsEMAILUseAttachmentSizeLimitOnChange(Item)
	
	OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure BackCommand(Command)
	
	ChangeGoToNumber(-1);
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	
	ForceCloseForm = True;
	
	Result = New Structure;
	Result.Insert("ExchangeNode", ExchangeNode);
	Result.Insert("HasDataToMap", HasDataToMap);
	
	If SaaSModel Then
		Result.Insert("CorrespondentDataArea",  CorrespondentDataArea);
		Result.Insert("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
	EndIf;
	
	Result.Insert("PassiveMode", ConnectionKind = "PassiveMode");
	
	Close(Result);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure HelpCommand(Command)
	
	OpenFormHelp();
	
EndProcedure

&AtClient
Procedure RefreshAvailableApplicationsList(Command)
	
	StartGetConnectionsListForConnection();
	
EndProcedure

&AtClient
Procedure InternetAccessParameters(Command)
	
	DataExchangeClient.OpenProxyServerParametersForm();
	
EndProcedure

&AtClient
Procedure DataSyncDetails(Command)
	
	DataExchangeClient.OpenSynchronizationDetails(ExchangeDetailedInformation);
	
EndProcedure

#EndRegion

#Region Private

#Region GetConnectionsListForConnection

&AtClient
Procedure StartGetConnectionsListForConnection()
	
	Items.SaaSApplicationsPanel.Visible = True;
	Items.ApplicationsSaaS.Enabled = False;
	Items.SaaSApplicationsRefreshAvailableApplicationsList.Enabled = False;
	
	Items.SaaSApplicationsPanel.CurrentPage = Items.SaaSApplicationsPanelWaitPage;
	AttachIdleHandler("GetApplicationListForConnectionOnStart", 0.1, True);
	
EndProcedure

&AtClient
Procedure GetApplicationListForConnectionOnStart()
	
	ParametersOfGetApplicationsListHandler = Undefined;
	ContinueWait = False;
	
	OnStartGetConnectionsListForConnection(ContinueWait);
		
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ParametersOfGetApplicationsListIdleHandler);
			
		AttachIdleHandler("OnWaitForGetApplicationListForConnection",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
	Else
		OnCompleteGetConnectionsListForConnection();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForGetApplicationListForConnection()
	
	ContinueWait = False;
	OnWaitGetConnectionsListForConnection(ParametersOfGetApplicationsListHandler, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		
		AttachIdleHandler("OnWaitForGetApplicationListForConnection",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
	Else
		ParametersOfGetApplicationsListIdleHandler = Undefined;
		OnCompleteGetConnectionsListForConnection();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteGetConnectionsListForConnection()
	
	Cancel = False;
	OnCompleteGetConnectionsListForConnectionAtServer(Cancel);
	
	Items.SaaSApplicationsRefreshAvailableApplicationsList.Enabled = True;
	Items.ApplicationsSaaS.Enabled = True;
	
	If Cancel Then
		Items.SaaSApplicationsPanel.CurrentPage = Items.SaaSApplicationsErrorPage;
	Else
		Items.SaaSApplicationsPanel.Visible = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartGetConnectionsListForConnection(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("Mode",                  "NotConfiguredExchanges");
	WizardParameters.Insert("ExchangePlanName",         ExchangePlanName);
	WizardParameters.Insert("SettingID", SettingID);
	
	ModuleSetupWizard.OnStartGetApplicationList(WizardParameters,
		ParametersOfGetApplicationsListHandler, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitGetConnectionsListForConnection(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnWaitForGetApplicationList(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteGetConnectionsListForConnectionAtServer(Cancel = False)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGetApplicationList(
		ParametersOfGetApplicationsListHandler, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		Cancel = True;
		Return;
	EndIf;
	
	ApplicationsTable = CompletionStatus.Result;
	
	ApplicationsTable.Columns.Add("PictureUseMode", New TypeDescription("Number"));
	ApplicationsTable.FillValues(1, "PictureUseMode"); // online application
	ApplicationsSaaS.Load(ApplicationsTable);
	
EndProcedure

#EndRegion

#Region ConnectionParametersCheck

&AtClient
Procedure OnStartCheckConnectionOnline()
	
	ContinueWait = True;
	
	If ConnectionKind = "Internet" Then
		OnStartCheckConnectionAtServer("WS", ContinueWait);
	ElsIf ConnectionKind = "ExternalConnection" Then
		OnStartCheckConnectionAtServer("COM", ContinueWait);
	EndIf;
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckOnline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionCheckOnline();
	EndIf;
	
EndProcedure
	
&AtClient
Procedure OnWaitForConnectionCheckOnline()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForConnectionCheckOnline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionCheckOnline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionCheckOnline()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteConnectionCheckAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		ChangeGoToNumber(+1);
	Else
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не удалось подключиться к программе. Проверьте настройки подключения.'; en = 'Cannot connect to the application. Check connection settings.'; pl = 'Nie udało się połączyć z programem. Sprawdź ustawienia połączenia.';es_ES = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión.';es_CO = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión.';tr = 'Uygulamaya bağlanılamadı. Bağlantı ayarlarını kontrol edin.';it = 'Non è possibile connettersi all''applicazione. Controllare i parametri di connessione.';de = 'Die Verbindung zum Programm konnte nicht hergestellt werden. Überprüfen Sie die Verbindungseinstellungen.'"));
		EndIf;
	EndIf;
		
EndProcedure

&AtClient
Procedure OnStartCheckConnectionOffline()
	
	If RegularCommunicationChannelsConnectionCheckQueue = Undefined Then	
		
		RegularCommunicationChannelsConnectionCheckQueue = New Structure;
		
		If RegularCommunicationChannelsFILEUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("FILE");
		EndIf;
		
		If RegularCommunicationChannelsFTPUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("FTP");
		EndIf;
		
		If RegularCommunicationChannelsEMAILUsage Then
			RegularCommunicationChannelsConnectionCheckQueue.Insert("EMAIL");
		EndIf;
		
	EndIf;
	
	TransportKindToCheck = Undefined;
	For Each CheckItems In RegularCommunicationChannelsConnectionCheckQueue Do
		TransportKindToCheck = CheckItems.Key;
		Break;
	EndDo;
	
	ContinueWait = True;
	OnStartCheckConnectionAtServer(TransportKindToCheck, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckOffline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionCheckOffline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForConnectionCheckOffline()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		AttachIdleHandler("OnWaitForConnectionCheckOffline",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionCheckOffline();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionCheckOffline()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteConnectionCheckAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		
		TransportKindToCheck = Undefined;
		For Each CheckItems In RegularCommunicationChannelsConnectionCheckQueue Do
			TransportKindToCheck = CheckItems.Key;
			Break;
		EndDo;
		RegularCommunicationChannelsConnectionCheckQueue.Delete(TransportKindToCheck);
		
		If RegularCommunicationChannelsConnectionCheckQueue.Count() > 0 Then
			OnStartCheckConnectionOffline();
		Else
			RegularCommunicationChannelsConnectionCheckQueue = Undefined;
			ChangeGoToNumber(+1);
		EndIf;
		
	Else
		
		TransportKindToCheck = Undefined;
		RegularCommunicationChannelsConnectionCheckQueue = Undefined;
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Не удалось подключиться к программе. Проверьте настройки подключения %1.'; en = 'Cannot connect to the application. Check connection settings %1.'; pl = 'Nie udało się połączyć z programem. Sprawdź ustawienia połączenia %1.';es_ES = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión %1.';es_CO = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión %1.';tr = 'Uygulamaya bağlanılamadı. %1 bağlantı ayarlarını kontrol edin.';it = 'Non è possibile connettersi all''applicazione. Controllare i parametri di connessione %1.';de = 'Die Verbindung zum Programm konnte nicht hergestellt werden. Überprüfen Sie die Verbindungseinstellungen %1.'"), TransportKindToCheck));
		EndIf;
				
	EndIf;
	
EndProcedure

&AtClient
Procedure OnStartConnectionCheckInSaaS()
	
	ContinueWait = True;
	OnStartConnectionCheckInSaaSAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForConnectionCheckSaaS",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteSaaSConnectionCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForConnectionCheckSaaS()
	
	ContinueWait = False;
	OnWaitConnectionCheckInSaaSAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForConnectionCheckSaaS",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteSaaSConnectionCheck();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteSaaSConnectionCheck()
	
	ErrorMessage = "";
	ConnectionCheckCompleted = False;
	OnCompleteSaaSConnectionCheckAtServer(ConnectionCheckCompleted, ErrorMessage);
	
	If ConnectionCheckCompleted Then
		ChangeGoToNumber(+1);
	Else
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не удалось подключиться к программе. Проверьте настройки подключения.'; en = 'Cannot connect to the application. Check connection settings.'; pl = 'Nie udało się połączyć z programem. Sprawdź ustawienia połączenia.';es_ES = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión.';es_CO = 'No se ha podido conectarse al programa. Compruebe los ajustes de conexión.';tr = 'Uygulamaya bağlanılamadı. Bağlantı ayarlarını kontrol edin.';it = 'Non è possibile connettersi all''applicazione. Controllare i parametri di connessione.';de = 'Die Verbindung zum Programm konnte nicht hergestellt werden. Überprüfen Sie die Verbindungseinstellungen.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartCheckConnectionAtServer(TransportKind, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	SettingsStructure = New Structure;
	FillWizardConnectionParametersStructure(SettingsStructure);
	SettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes[TransportKind];
	
	ModuleSetupWizard.OnStartTestConnection(
		SettingsStructure, ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForTestConnection(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteConnectionCheckAtServer(ConnectionCheckCompleted, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteTestConnection(ConnectionCheckHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.ConnectionIsSet
			AND CompletionStatus.Result.ConnectionAllowed;
			
		If Not ConnectionCheckCompleted
			AND Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
			
		If ConnectionCheckCompleted
			AND CompletionStatus.Result.CorrespondentParametersReceived Then
			FillCorrespondentParameters(CompletionStatus.Result.CorrespondentParameters);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartConnectionCheckInSaaSAtServer(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ConnectionSettings = New Structure;
	ConnectionSettings.Insert("ExchangePlanName",              ExchangePlanName);
	ConnectionSettings.Insert("CorrespondentDescription",  CorrespondentDescription);
	ConnectionSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
	
	ConnectionCheckHandlerParameters = Undefined;
	ModuleSetupWizard.OnStartGetCommonDataFromCorrespondentNodes(ConnectionSettings,
		ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckInSaaSAtServer(HandlerParameters, ContinueWait)

	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForGetCommonDataFromCorrespondentNodes(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteSaaSConnectionCheckAtServer(ConnectionCheckCompleted, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ConnectionCheckCompleted = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGetCommonDataFromCorrespondentNodes(
		ConnectionCheckHandlerParameters, CompletionStatus);
	ConnectionCheckHandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.CorrespondentParametersReceived;
		
		If Not ConnectionCheckCompleted Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
		
		If ConnectionCheckCompleted Then
			FillCorrespondentParameters(CompletionStatus.Result.CorrespondentParameters, True);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region SaveConnectionSettings

&AtClient
Procedure OnStartSaveConnectionSettings()
	
	ContinueWait = True;
	OnStartSaveConnectionSettingsAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ConnectionSettingsSaveIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForSaveConnectionSettings",
			ConnectionSettingsSaveIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionSettingsSaving();
	EndIf;
	
EndProcedure
	
&AtClient
Procedure OnWaitForSaveConnectionSettings()
	
	ContinueWait = False;
	OnWaitSaveConnectionSettingsAtServer(IsExchangeWithApplicationInService,
		ConnectionSettingsSaveHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ConnectionSettingsSaveIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForSaveConnectionSettings",
			ConnectionSettingsSaveIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionSettingsSaving();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionSettingsSaving()
	
	ConnectionSettingsSaved = False;
	ConnectionSettingsAddressInStorage = "";
	ErrorMessage = "";
	
	OnCompleteSaveConnectionSettingsAtServer(ConnectionSettingsSaved,
		ConnectionSettingsAddressInStorage, ErrorMessage);
		
	Result = New Structure;
	Result.Insert("Cancel",             Not ConnectionSettingsSaved);
	Result.Insert("ErrorMessage", ErrorMessage);
	
	CompletionNotification = New NotifyDescription("SaveConnectionSettingsCompletion", ThisObject);
	
	If ConnectionSettingsSaved Then
		If SaveConnectionParametersToFile
			AND ValueIsFilled(ConnectionSettingsAddressInStorage) Then
			
			AdditionalParameters = New Structure;
			AdditionalParameters.Insert("CompletionNotification", CompletionNotification);
			
			FileReceiptNotification = New NotifyDescription("GetConnectionSettingsFileCompletion",
				ThisObject, AdditionalParameters);
				
			FilesToReceive = New Array;
			FilesToReceive.Add(
				New TransferableFileDescription(ConnectionSettingsFileNameToExport, ConnectionSettingsAddressInStorage));
				
			BeginGettingFiles(FileReceiptNotification, FilesToReceive, , False);
			
		Else
			
			ExecuteNotifyProcessing(CompletionNotification, Result);
			
		EndIf;
	Else
		
		ExecuteNotifyProcessing(CompletionNotification, Result);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetConnectionSettingsFileCompletion(ReceivedFiles, AdditionalParameters) Export
	
	Result = New Structure;
	Result.Insert("Cancel",             False);
	Result.Insert("ErrorMessage", "");
	
	If ReceivedFiles = Undefined Then
		Result.Cancel = True;
		Result.ErrorMessage = NStr("ru = 'Не удалось сохранить настройки подключения в файл.'; en = 'Cannot save connection settings to the file.'; pl = 'Nie udało się zapisać ustawienia połączenia do pliku.';es_ES = 'No se ha podido guardar los ajustes de conexión en el archivo.';es_CO = 'No se ha podido guardar los ajustes de conexión en el archivo.';tr = 'Bağlantı ayarları dosyada kaydedilemedi.';it = 'Non è possibile salvare le impostazioni di connessione nel file.';de = 'Die Verbindungseinstellungen konnten nicht in der Datei gespeichert werden.'");
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.CompletionNotification, Result);
	
EndProcedure

&AtClient
Procedure SaveConnectionSettingsCompletion(Result, AdditionalParameters) Export
	
	If Not Result.Cancel Then
		
		ChangeGoToNumber(+1);
		
		Notify("Write_ExchangePlanNode");
		
	Else
		
		ChangeGoToNumber(-1);
		
		MessageText = Result.ErrorMessage;
		If IsBlankString(MessageText) Then
			MessageText = NStr("ru = 'Не удалось сохранить настройки подключения.'; en = 'Cannot save connection settings.'; pl = 'Nie udało się zapisać ustawienia połączenia.';es_ES = 'No se ha podido guardar los ajustes de conexión.';es_CO = 'No se ha podido guardar los ajustes de conexión.';tr = 'Bağlantı ayarları kaydedilemedi.';it = 'Non è possibile salvare le impostazioni di connessione.';de = 'Die Verbindungseinstellungen konnten nicht gespeichert werden.'");
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartSaveConnectionSettingsAtServer(ContinueWait)
	
	If IsExchangeWithApplicationInService Then
		
		ConnectionSettings = New Structure;
		ConnectionSettings.Insert("ExchangePlanName",               CorrespondentExchangePlanName);
		ConnectionSettings.Insert("CorrespondentExchangePlanName", ExchangePlanName);
		
		ConnectionSettings.Insert("SettingID",       SettingID);
		
		ConnectionSettings.Insert("ExchangeFormat", ExchangeFormat);
		
		ConnectionSettings.Insert("Description", Description);
		ConnectionSettings.Insert("CorrespondentDescription", CorrespondentDescription);
		
		ConnectionSettings.Insert("Prefix", Prefix);
		ConnectionSettings.Insert("CorrespondentPrefix", CorrespondentPrefix);
		
		ConnectionSettings.Insert("SourceInfobaseID", SourceInfobaseID);
		ConnectionSettings.Insert("DestinationInfobaseID", DestinationInfobaseID);
		
		ConnectionSettings.Insert("CorrespondentEndpoint", CorrespondentEndpoint);

		ConnectionSettings.Insert("Correspondent");
		ConnectionSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		If XDTOSetup Then
			ConnectionSettings.Insert("XDTOCorrespondentSettings", New Structure);
			ConnectionSettings.XDTOCorrespondentSettings.Insert("SupportedVersions", New Array);
			ConnectionSettings.XDTOCorrespondentSettings.Insert("SupportedObjects", SupportedCorrespondentFormatObjects);
			
			ConnectionSettings.XDTOCorrespondentSettings.SupportedVersions.Add(ExchangeFormatVersion);
		EndIf;
		
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		
		// Connection settings in the attribute structure format of the data exchange creation wizard.
		ConnectionSettings = New Structure;
		FillWizardConnectionParametersStructure(ConnectionSettings);
		
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
			
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ConnectionSettingsSaveHandlerParameters = Undefined;
	ModuleSetupWizard.OnStartSaveConnectionSettings(ConnectionSettings,
		ConnectionSettingsSaveHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitSaveConnectionSettingsAtServer(IsExchangeWithApplicationInService, HandlerParameters, ContinueWait)
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForSaveConnectionSettings(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteSaveConnectionSettingsAtServer(ConnectionSettingsSaved,
		ConnectionSettingsAddressInStorage, ErrorMessage)
	
	CompletionStatus = Undefined;
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupWizard = Undefined Then
		ConnectionSettingsSaved = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnCompleteSaveConnectionSettings(
		ConnectionSettingsSaveHandlerParameters, CompletionStatus);
	ConnectionSettingsSaveHandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		ConnectionSettingsSaved = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		ConnectionSettingsSaved = CompletionStatus.Result.ConnectionSettingsSaved;
		
		If Not ConnectionSettingsSaved Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
		
		ExchangeNode = CompletionStatus.Result.ExchangeNode;
		
		If SaveConnectionParametersToFile Then
			TempFile = GetTempFileName("xml");
			
			Record = New TextWriter;
			Record.Open(TempFile, "UTF-8");
			Record.Write(CompletionStatus.Result.XMLConnectionSettingsString);
			Record.Close();
			
			ConnectionSettingsAddressInStorage = PutToTempStorage(
				New BinaryData(TempFile), UUID);
				
			DeleteFiles(TempFile);
		EndIf;
		
		If Not SaaSModel Then
			HasDataToMap = CompletionStatus.Result.HasDataToMap;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

&AtServer
Procedure FillWizardConnectionParametersStructure(WizardSettingsStructure)
	
	// Transforming structure of form attributes to structure of wizard attributes.
	WizardSettingsStructure.Insert("ExchangePlanName",               ExchangePlanName);
	WizardSettingsStructure.Insert("CorrespondentExchangePlanName", CorrespondentExchangePlanName);
	
	WizardSettingsStructure.Insert("ExchangeSettingsOption", SettingID);
	
	WizardSettingsStructure.Insert("ExchangeFormat", ExchangeFormat);
	
	If ValueIsFilled(ExchangeNode) Then
		WizardSettingsStructure.Insert("Correspondent", ExchangeNode);
	EndIf;
	
	If ContinueSetupInSubordinateDIBNode
		Or ImportConnectionParametersFromFile Then
		WizardSettingsStructure.Insert("WizardRunOption", "ContinueDataExchangeSetup");
	Else
		WizardSettingsStructure.Insert("WizardRunOption", "SetUpNewDataExchange");
	EndIf;
	
	WizardSettingsStructure.Insert("NewRef", Undefined);
	
	WizardSettingsStructure.Insert("PredefinedNodeCode", SourceInfobaseID);
		
	WizardSettingsStructure.Insert("SecondInfobaseNewNodeCode", DestinationInfobaseID);
	WizardSettingsStructure.Insert("CorrespondentNodeCode",   DestinationInfobaseID);
	
	WizardSettingsStructure.Insert("ThisInfobaseDescription",   Description);
	WizardSettingsStructure.Insert("SecondInfobaseDescription", CorrespondentDescription);
	
	WizardSettingsStructure.Insert("SourceInfobasePrefix", Prefix);
	WizardSettingsStructure.Insert("DestinationInfobasePrefix", CorrespondentPrefix);
	
	WizardSettingsStructure.Insert("InfobaseNode", ExchangeNode);
	
	WizardSettingsStructure.Insert("UsePrefixesForExchangeSettings",               UsePrefixesForExchangeSettings);
	WizardSettingsStructure.Insert("UsePrefixesForCorrespondentExchangeSettings", UsePrefixesForCorrespondentExchangeSettings);
	
	WizardSettingsStructure.Insert("SourceInfobaseID", SourceInfobaseID);
	WizardSettingsStructure.Insert("DestinationInfobaseID", DestinationInfobaseID);
	
	WizardSettingsStructure.Insert("ExchangeDataSettingsFileFormatVersion",
		DataExchangeServer.ModuleDataExchangeCreationWizard().DataExchangeSettingsFormatVersion());
		
	WizardSettingsStructure.Insert("ExchangeFormatVersion", ExchangeFormatVersion);
	WizardSettingsStructure.Insert("SupportedObjectsInFormat", SupportedCorrespondentFormatObjects);
	
	// Transport settings. 	
	WizardSettingsStructure.Insert("COMOperatingSystemAuthentication",
		ExternalConnectionAuthenticationKind = "OperatingSystem");
	WizardSettingsStructure.Insert("COMInfobaseOperatingMode",
		?(ExternalConnectionInfobaseOperationMode = "File", 0, 1));
	WizardSettingsStructure.Insert("COM1CEnterpriseServerSideInfobaseName",
		ExternalConnectionInfobaseName);
	WizardSettingsStructure.Insert("COMUsername",
		ExternalConnectionUsername);
	WizardSettingsStructure.Insert("COM1CEnterpriseServerName",
		ExternalConnectionServerCluster);
	WizardSettingsStructure.Insert("COMInfobaseDirectory",
		ExternalConnectionInfobaseDirectory);
	WizardSettingsStructure.Insert("COMUserPassword",
		ExternalConnectionPassword);
		
	WizardSettingsStructure.Insert("EMAILMaxMessageSize",
		RegularCommunicationChannelsMAILMaxAttachmentSize);
	WizardSettingsStructure.Insert("EMAILCompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("EMAILUserAccount",
		RegularCommunicationChannelsMAILUserAccount);
	WizardSettingsStructure.Insert("EMAILTransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
	
	WizardSettingsStructure.Insert("FILEInformationExchangeDirectory",
		RegularCommunicationChannelsFILEDirectory);
	WizardSettingsStructure.Insert("FILECompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("FILETransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
	
	WizardSettingsStructure.Insert("FTPCompressOutgoingMessageFile",
		RegularCommunicationChannelsArchiveFiles);
	WizardSettingsStructure.Insert("FTPConnectionMaxMessageSize",
		RegularCommunicationChannelsFTPMaxFileSize);
	WizardSettingsStructure.Insert("FTPConnectionPassword",
		RegularCommunicationChannelsFTPPassword);
	WizardSettingsStructure.Insert("FTPConnectionPassiveConnection",
		RegularCommunicationChannelsFTPPassiveMode);
	WizardSettingsStructure.Insert("FTPConnectionUser",
		RegularCommunicationChannelsFTPUser);
	WizardSettingsStructure.Insert("FTPConnectionPort",
		RegularCommunicationChannelsFTPPort);
	WizardSettingsStructure.Insert("FTPConnectionPath",
		RegularCommunicationChannelsFTPPath);
	WizardSettingsStructure.Insert("FTPTransliterateExchangeMessageFileNames",
		RegularCommunicationChannelsTransliterateFileNames);
		
	WizardSettingsStructure.Insert("WSWebServiceURL", InternetWebAddress);
	WizardSettingsStructure.Insert("WSRememberPassword", InternetRememberPassword);
	WizardSettingsStructure.Insert("WSUsername", InternetUsername);
	WizardSettingsStructure.Insert("WSPassword", InternetPassword);
	
	If ConnectionKind = "Internet" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WS);
	ElsIf ConnectionKind = "ExternalConnection" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.COM);
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportType) Then
			If RegularCommunicationChannelsFILEUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FILE);
			ElsIf RegularCommunicationChannelsFTPUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FTP);
			ElsIf RegularCommunicationChannelsEMAILUsage Then
				WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.EMAIL);
			EndIf;
		ElsIf RegularCommunicationChannelsDefaultTransportType = "FILE" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FILE);
		ElsIf RegularCommunicationChannelsDefaultTransportType = "FTP" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.FTP);
		ElsIf RegularCommunicationChannelsDefaultTransportType = "EMAIL" Then
			WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.EMAIL);
		EndIf;
	ElsIf ConnectionKind = "PassiveMode" Then
		WizardSettingsStructure.Insert("ExchangeMessagesTransportKind", Enums.ExchangeMessagesTransportTypes.WSPassiveMode);
	EndIf;
	
	WizardSettingsStructure.Insert("UseTransportParametersCOM",   ConnectionKind = "ExternalConnection");
	
	WizardSettingsStructure.Insert("UseTransportParametersEMAIL", RegularCommunicationChannelsEMAILUsage);
	WizardSettingsStructure.Insert("UseTransportParametersFILE",  RegularCommunicationChannelsFILEUsage);
	WizardSettingsStructure.Insert("UseTransportParametersFTP",   RegularCommunicationChannelsFTPUsage);
	
	WizardSettingsStructure.Insert("ArchivePasswordExchangeMessages", RegularCommunicationChannelsArchivePassword);
	
EndProcedure

&AtServer
Procedure ReadWizardConnectionParametersStructure(WizardSettingsStructure)
	
	// Transforming structure of wizard attributes to structure of form attributes.
	SourceInfobaseID = WizardSettingsStructure.PredefinedNodeCode;
	DestinationInfobaseID = WizardSettingsStructure.SecondInfobaseNewNodeCode;
	
	CorrespondentExchangePlanName = WizardSettingsStructure.CorrespondentExchangePlanName;
	
	UsePrefixesForCorrespondentExchangeSettings =
		Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName)
			Or StrLen(DestinationInfobaseID) <> 36
			Or StrLen(SourceInfobaseID) <> 36;
	
	If DescriptionChangeAvailable Then
		Description = WizardSettingsStructure.ThisInfobaseDescription;
	EndIf;
	
	If CorrespondentDescriptionChangeAvailable Then
		CorrespondentDescription = WizardSettingsStructure.SecondInfobaseDescription;
	EndIf;
	
	If PrefixChangeAvailable Then
		Prefix = WizardSettingsStructure.SourceInfobasePrefix;
		If IsBlankString(Prefix)
			AND (UsePrefixesForExchangeSettings Or UsePrefixesForCorrespondentExchangeSettings) Then
			Prefix = WizardSettingsStructure.PredefinedNodeCode;
		EndIf;
	EndIf;
	
	If CorrespondentPrefixChangeAvailable Then
		CorrespondentPrefix = WizardSettingsStructure.DestinationInfobasePrefix;
		If IsBlankString(CorrespondentPrefix)
			AND (UsePrefixesForExchangeSettings Or UsePrefixesForCorrespondentExchangeSettings) Then
			CorrespondentPrefix = WizardSettingsStructure.SecondInfobaseNewNodeCode;
		EndIf;
	EndIf;
	
	// Transport settings.
	ExternalConnectionAuthenticationKind =
		?(WizardSettingsStructure.COMOperatingSystemAuthentication, "OperatingSystem", "1CEnterprise");
	ExternalConnectionInfobaseOperationMode =
		?(WizardSettingsStructure.COMInfobaseOperatingMode = 0, "File", "ClientServer");
	ExternalConnectionInfobaseName =
		WizardSettingsStructure.COM1CEnterpriseServerSideInfobaseName;
	ExternalConnectionUsername =
		WizardSettingsStructure.COMUsername;
	ExternalConnectionServerCluster =
		WizardSettingsStructure.COM1CEnterpriseServerName;
	ExternalConnectionInfobaseDirectory =
		WizardSettingsStructure.COMInfobaseDirectory;
	ExternalConnectionPassword =
		WizardSettingsStructure.COMUserPassword;
	
	RegularCommunicationChannelsMAILMaxAttachmentSize =
		WizardSettingsStructure.EMAILMaxMessageSize;
	RegularCommunicationChannelsMAILUserAccount =
		WizardSettingsStructure.EMAILUserAccount;
	
	RegularCommunicationChannelsFILEDirectory =
		WizardSettingsStructure.FILEInformationExchangeDirectory;
	
	RegularCommunicationChannelsFTPMaxFileSize =
		WizardSettingsStructure.FTPConnectionMaxMessageSize;
	RegularCommunicationChannelsFTPPassword =
		WizardSettingsStructure.FTPConnectionPassword;
	RegularCommunicationChannelsFTPPassiveMode =
		WizardSettingsStructure.FTPConnectionPassiveConnection;
	RegularCommunicationChannelsFTPUser =
		WizardSettingsStructure.FTPConnectionUser;
	RegularCommunicationChannelsFTPPort =
		WizardSettingsStructure.FTPConnectionPort;
	RegularCommunicationChannelsFTPPath =
		WizardSettingsStructure.FTPConnectionPath;
		
	InternetWebAddress        = WizardSettingsStructure.WSWebServiceURL;
	InternetRememberPassword = WizardSettingsStructure.WSRememberPassword;
	InternetUsername = WizardSettingsStructure.WSUsername;
	InternetPassword          = WizardSettingsStructure.WSPassword;
	
	If WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		ConnectionKind = "Internet";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM Then
		ConnectionKind = "ExternalConnection";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP
		Or WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.EMAIL Then
		ConnectionKind = "RegularCommunicationChannels";
	ElsIf WizardSettingsStructure.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
		ConnectionKind = "PassiveMode";
	EndIf;
	
	RegularCommunicationChannelsEMAILUsage = WizardSettingsStructure.UseTransportParametersEMAIL;
	RegularCommunicationChannelsFILEUsage  = WizardSettingsStructure.UseTransportParametersFILE;
	RegularCommunicationChannelsFTPUsage   = WizardSettingsStructure.UseTransportParametersFTP;
	
	If RegularCommunicationChannelsFILEUsage Then
		RegularCommunicationChannelsDefaultTransportType = "FILE";
	ElsIf RegularCommunicationChannelsFTPUsage Then
		RegularCommunicationChannelsDefaultTransportType = "FTP";
	ElsIf RegularCommunicationChannelsEMAILUsage Then
		RegularCommunicationChannelsDefaultTransportType = "EMAIL";
	EndIf;
	
	RegularCommunicationChannelsTransliterateFileNames =
		WizardSettingsStructure.FILETransliterateExchangeMessageFileNames
		Or WizardSettingsStructure.FTPTransliterateExchangeMessageFileNames
		Or WizardSettingsStructure.EMAILTransliterateExchangeMessageFileNames;
		
	RegularCommunicationChannelsArchiveFiles =
		WizardSettingsStructure.FILECompressOutgoingMessageFile
		Or WizardSettingsStructure.FTPCompressOutgoingMessageFile
		Or WizardSettingsStructure.EMAILCompressOutgoingMessageFile;	
	
	RegularCommunicationChannelsArchivePassword = WizardSettingsStructure.ArchivePasswordExchangeMessages;
	
EndProcedure

&AtServer
Procedure FillCorrespondentParameters(CorrespondentParameters, CorrespondentInSaaS = False)
	
	If ValueIsFilled(CorrespondentParameters.InfobasePrefix) Then
		CorrespondentPrefix = CorrespondentParameters.InfobasePrefix;
	Else
		CorrespondentPrefix = CorrespondentParameters.DefaultInfobasePrefix;
	EndIf;
	
	If Not CorrespondentInSaaS Then
		If ValueIsFilled(CorrespondentParameters.InfobaseDescription) Then
			CorrespondentDescription = CorrespondentParameters.InfobaseDescription;
		Else
			CorrespondentDescription = CorrespondentParameters.DefaultInfobaseDescription;
		EndIf;
	EndIf;
	
	DestinationInfobaseID = CorrespondentParameters.ThisNodeCode;
	
	CorrespondentConfigurationVersion = CorrespondentParameters.ConfigurationVersion;
	
	CorrespondentExchangePlanName = CorrespondentParameters.ExchangePlanName;
	
	If XDTOSetup Then
		UsePrefixesForCorrespondentExchangeSettings = CorrespondentParameters.UsePrefixesForExchangeSettings;
		
		ExchangeFormatVersion = DataExchangeXDTOServer.MaxCommonFormatVersion(
			ExchangePlanName, CorrespondentParameters.ExchangeFormatVersions);
		
		SupportedCorrespondentFormatObjects = New ValueStorage(
			CorrespondentParameters.SupportedObjectsInFormat, New Deflation(9));
	ElsIf ConnectionKind = "Internet"
		AND StrLen(DestinationInfobaseID) = 9 Then
		UsePrefixesForExchangeSettings               = False;
		UsePrefixesForCorrespondentExchangeSettings = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillConnectionParametersFromXMLAtServer(AddressInStorage, Cancel, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	TempFile = GetTempFileName("xml");
		
	FileData = GetFromTempStorage(AddressInStorage);
	FileData.Write(TempFile);
	
	Try
		ConnectionSettings = ModuleSetupWizard.Create();
		ConnectionSettings.ExchangePlanName = ExchangePlanName;
		ConnectionSettings.ExchangeSettingsOption = SettingID;
		ConnectionSettings.WizardRunOption = "ContinueDataExchangeSetup";
		
		ModuleSetupWizard.FillConnectionSettingsFromXMLString(
			ConnectionSettings, TempFile, True);
	Except
		Cancel = True;
		ErrorMessage   = BriefErrorDescription(ErrorInfo());
		ErrorMessageEventLog = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , ErrorMessageEventLog);
	EndTry;
		
	DeleteFiles(TempFile);
	DeleteFromTempStorage(AddressInStorage);
	
	If Not Cancel Then
		ReadWizardConnectionParametersStructure(ConnectionSettings);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillXDTOCorrespondentSettingsFromXMLAtServer(AddressInStorage, Cancel, ErrorMessage = "")
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	TempFile = GetTempFileName("xml");
		
	FileData = GetFromTempStorage(AddressInStorage);
	FileData.Write(TempFile);
	
	Try
		XDTOCorrespondentSettings = ModuleSetupWizard.XDTOCorrespondentSettingsFromXML(
			TempFile, True, ExchangePlans[ExchangePlanName].EmptyRef());
	Except
		Cancel = True;
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		WriteLogEvent(DataExchangeServer.DataExchangeCreationEventLogMessageText(),
			EventLogLevel.Error, , , ErrorMessage);
	EndTry;

	DeleteFiles(TempFile);
	DeleteFromTempStorage(AddressInStorage);
	
	If Not Cancel Then
		ExchangeFormatVersion = DataExchangeXDTOServer.MaxCommonFormatVersion(ExchangePlanName,
			XDTOCorrespondentSettings.SupportedVersions);
			
		SupportedCorrespondentFormatObjects = New ValueStorage(XDTOCorrespondentSettings.SupportedObjects,
			New Deflation(9));
			
		DestinationInfobaseID = XDTOCorrespondentSettings.SenderID;
		
		UsePrefixesForCorrespondentExchangeSettings = (StrLen(DestinationInfobaseID) <> 36);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAvailableTransportKinds()
	
	AvailableTransportKinds = New Structure;
	
	UsedExchangeMessagesTransports = DataExchangeCached.UsedExchangeMessagesTransports(
		ExchangePlans[ExchangePlanName].EmptyRef(), SettingID);
		
	For Each CurrentTransportKind In UsedExchangeMessagesTransports Do
		// The SaaS mode supports exchange only via the Internet and passive Internet connection
		// for XDTO exchange plans.	
		If SaaSModel Then
			If CurrentTransportKind <> Enums.ExchangeMessagesTransportTypes.WS
				AND CurrentTransportKind <> Enums.ExchangeMessagesTransportTypes.WSPassiveMode Then
				Continue;
			EndIf;
			
			If Not XDTOSetup Then
				Continue;
			EndIf;
		EndIf;
			
		AvailableTransportKinds.Insert(Common.EnumValueName(CurrentTransportKind));
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCompletePutConnectionSettingsFileForImport(SelectionResult, Address, SelectedFileName, AdditionalParameters) Export
	
	Result = New Structure;
	Result.Insert("Cancel", False);
	Result.Insert("ErrorMessage", "");
	
	If Not SelectionResult Then
		Result.Cancel = True;
	Else
		FillConnectionParametersFromXMLAtServer(Address, Result.Cancel, Result.ErrorMessage);
	EndIf;
	
	If Result.Cancel Then
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("ru = 'Не удалось загрузить файл с настройками подключения.'; en = 'Cannot import file with connection settings.'; pl = 'Nie udało się pobrać pliku z ustawieniami połączenia.';es_ES = 'No se ha podido descargar el archivo con ajustes de conexión.';es_CO = 'No se ha podido descargar el archivo con ajustes de conexión.';tr = 'Bağlantı ayarlarına sahip dosya içe aktarılamadı.';it = 'Non è possibile importare file con le impostazioni di connessione.';de = 'Die Datei mit den Verbindungseinstellungen konnte nicht heruntergeladen werden.'");
		EndIf;
	Else
		DescriptionChangeAvailable = False;
		PrefixChangeAvailable     = False;
		
		CorrespondentDescriptionChangeAvailable = False;
		CorrespondentPrefixChangeAvailable     = False;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.Notification, Result);
	
EndProcedure

&AtClient
Procedure OnCompletePutXDTOCorrespondentSettingsFile(SelectionResult, Address, SelectedFileName, AdditionalParameters) Export
	
	Result = New Structure;
	Result.Insert("Cancel",             False);
	Result.Insert("ErrorMessage", "");
	
	If Not SelectionResult Then
		Result.Cancel = True;
	Else
		FillXDTOCorrespondentSettingsFromXMLAtServer(Address, Result.Cancel, Result.ErrorMessage);
	EndIf;
	
	If Result.Cancel Then
		If IsBlankString(Result.ErrorMessage) Then
			Result.ErrorMessage = NStr("ru = 'Не удалось загрузить файл с настройками корреспондента.'; en = 'Cannot import file with correspondent settings.'; pl = 'Nie udało się pobrać pliku z ustawieniami korespondenta.';es_ES = 'No se ha podido descargar el archivo con ajustes del correspondiente.';es_CO = 'No se ha podido descargar el archivo con ajustes del correspondiente.';tr = 'Muhabir ayarlarına sahip dosya içe aktarılamadı.';it = 'Non è possibile importare file con le impostazioni corrispondenti.';de = 'Es konnte keine Datei mit den korrespondierenden Einstellungen heruntergeladen werden.'");
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(AdditionalParameters.Notification, Result);
	
EndProcedure

&AtClient
Procedure ConnectionParametersRegularCommunicationChannelsContinueSetting(Result, AdditionalParameters) Export
	
	If Result.Cancel Then
		ChangeGoToNumber(-1);
		CommonClientServer.MessageToUser(Result.ErrorMessage);
		Return;
	EndIf;
	
	Items.InternetAccessParameters.Visible = InternetAccessParametersSetupAvailable;
	
	Items.SyncOverDirectoryGroup.Visible = AvailableTransportKinds.Property("FILE");
	Items.SyncOverFTPGroup.Visible = AvailableTransportKinds.Property("FTP");
	Items.SyncOverEMAILGroup.Visible = AvailableTransportKinds.Property("EMAIL");
	
	If AdditionalParameters.IsMoveNext Then
	
		OnChangeRegularCommunicationChannelsFILEUsing();
		OnChangeRegularCommunicationChannelsFTPUsing();
		OnChangeRegularCommunicationChannelsEMAILUsing();
		
		OnChangeRegularCommunicationChannelsArchiveFiles();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommonSynchronizationSettingsContinueSetting(Result, AdditionalParameters) Export
	
	If Result.Cancel Then
		ChangeGoToNumber(-1);
		CommonClientServer.MessageToUser(Result.ErrorMessage);
		Return;
	EndIf;
	
	If AdditionalParameters.IsMoveNext Then
		Items.RegularCommunicationChannelsDefaultTransportType.ChoiceList.Clear();
		
		If RegularCommunicationChannelsFILEUsage Then
			Items.RegularCommunicationChannelsDefaultTransportType.ChoiceList.Add("FILE");
			RegularCommunicationChannelsDefaultTransportType = "FILE";
		EndIf;
		
		If RegularCommunicationChannelsFTPUsage Then
			Items.RegularCommunicationChannelsDefaultTransportType.ChoiceList.Add("FTP");
			If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportType) Then
				RegularCommunicationChannelsDefaultTransportType = "FTP";
			EndIf;
		EndIf;
		
		If RegularCommunicationChannelsEMAILUsage Then
			Items.RegularCommunicationChannelsDefaultTransportType.ChoiceList.Add("EMAIL");
			If Not ValueIsFilled(RegularCommunicationChannelsDefaultTransportType) Then
				RegularCommunicationChannelsDefaultTransportType = "EMAIL";
			EndIf;
		EndIf;
	EndIf;
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsDefaultTransportType",
		"Visible",
		Items.RegularCommunicationChannelsDefaultTransportType.ChoiceList.Count() > 1);
		
	SaveConnectionParametersToFile = (ConnectionKind = "PassiveMode")
		Or ((ConnectionKind = "RegularCommunicationChannels")
			AND Not DIBSetup AND Not ImportConnectionParametersFromFile);
		
	CommonClientServer.SetFormItemProperty(Items,
		"ConnectionSettingsFileNameToExport", "Visible", SaveConnectionParametersToFile);
			
	If SaveConnectionParametersToFile
		AND (ConnectionKind = "RegularCommunicationChannels")
		AND RegularCommunicationChannelsFILEUsage Then
		ConnectionSettingsFileNameToExport = CommonClientServer.GetFullFileName(
			RegularCommunicationChannelsFILEDirectory, SettingsFileNameForDestination + ".xml");
	EndIf;
		
	CommonClientServer.SetFormItemProperty(Items,
		"ApplicationSettingsGroupPresentation", "Visible", Not (ConnectionKind = "PassiveMode"));
	
	CommonClientServer.SetFormItemProperty(Items,
		"Description", "ReadOnly", Not DescriptionChangeAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"Prefix", "ReadOnly", Not PrefixChangeAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"CorrespondentDescription", "ReadOnly", Not CorrespondentDescriptionChangeAvailable);
	
	CommonClientServer.SetFormItemProperty(Items,
		"CorrespondentPrefix", "ReadOnly", Not CorrespondentPrefixChangeAvailable);
	
EndProcedure

#Region FormInitializationOnCreate

&AtServer
Procedure CheckCanUseForm(Cancel = False)
	
	// Parameters of the data exchange creation wizard must be passed.
	If Not Parameters.Property("ExchangePlanName")
		Or Not Parameters.Property("SettingID") Then
		MessageText = NStr("ru = 'Форма не предназначена для непосредственного использования.'; en = 'Form is not intended for direct usage.'; pl = 'Formularz nie jest przeznaczony dla bezpośredniego użycia.';es_ES = 'El formulario no está destinado para el uso directo.';es_CO = 'El formulario no está destinado para el uso directo.';tr = 'Form doğrudan kullanım için uygun değildir.';it = 'Il modulo non è inteso per un utilizzo diretto.';de = 'Das Formular ist nicht für den direkten Gebrauch bestimmt.'");
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormProperties()
	
	If DIBSetup Then
		Title = NStr("ru = 'Настройка распределенной информационной базы'; en = 'Configure the distributed infobase'; pl = 'Konfiguracja przydzielonej bazy informacyjnej';es_ES = 'Ajuste de la base de información distribuida';es_CO = 'Ajuste de la base de información distribuida';tr = 'Dağıtılmış veri tabanı ayarı';it = 'Configura l''infobase distribuito';de = 'Aufbau einer verteilten Informationsbasis'");
	Else
		Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Настройка подключения к ""%1""'; en = 'Set up connection to ""%1""'; pl = 'Ustawienie połączenia do ""%1""';es_ES = 'Ajuste de conexión a ""%1""';es_CO = 'Ajuste de conexión a ""%1""';tr = '""%1"" bağlantı ayarları';it = 'Imposta connessione a ""%1""';de = 'Verbindungsaufbau zu ""%1"" einstellen'"),
			CorrespondentConfigurationDescription);
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	ExchangePlanName         = Parameters.ExchangePlanName;
	SettingID = Parameters.SettingID;
	
	ContinueSetupInSubordinateDIBNode = Parameters.Property("ContinueSetupInSubordinateDIBNode");
	
	CorrespondentConfigurationVersion = "";
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
		
	InternetAccessParametersSetupAvailable = Not SaaSModel
		AND Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet");
		
	DIBSetup  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
	XDTOSetup = DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName);
	
	FillAvailableTransportKinds();
	
	If AvailableTransportKinds.Property("COM") Then
		ConnectionKind = "ExternalConnection";
	ElsIf AvailableTransportKinds.Property("WS") Then
		ConnectionKind = "Internet";
	ElsIf AvailableTransportKinds.Property("FILE")
		Or AvailableTransportKinds.Property("FTP")
		Or AvailableTransportKinds.Property("EMAIL") Then
		ConnectionKind = "RegularCommunicationChannels";
	ElsIf AvailableTransportKinds.Property("WSPassiveMode") Then
		ConnectionKind = "PassiveMode";
	EndIf;
	
	If AvailableTransportKinds.Property("FILE") Then
		RegularCommunicationChannelsFILEUsage  = True;
	ElsIf AvailableTransportKinds.Property("FTP") Then
		RegularCommunicationChannelsFTPUsage   = True;
	ElsIf AvailableTransportKinds.Property("EMAIL") Then
		RegularCommunicationChannelsEMAILUsage = True;
	EndIf;
	
	If AvailableTransportKinds.Property("FTP") Then
		RegularCommunicationChannelsFTPPort = 21;
		RegularCommunicationChannelsFTPPassiveMode = True;
	EndIf;
	
	ConnectionSetupMethod = ?(SaaSModel, "ApplicationFromList", "ConfigureManually");
	
	SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"CorrespondentConfigurationName,
		|ExchangeFormat,
		|SettingsFileNameForDestination,
		|CorrespondentConfigurationDescription,
		|ExchangeBriefInfo,
		|ExchangeDetailedInformation,
		|DataSyncSettingsWizardFormName",
		SettingID);
	
	FillPropertyValues(ThisObject, SettingsValuesForOption);
	
	CorrespondentExchangePlanName = ExchangePlanName;
	
	DescriptionChangeAvailable = False;
	PrefixChangeAvailable     = False;
	
	CorrespondentDescriptionChangeAvailable = True;
	CorrespondentPrefixChangeAvailable     = True;
	
	If SaaSModel Then
		ModuleDataExchangeSaaS = Common.CommonModule("DataExchangeSaaS");
		Description = ModuleDataExchangeSaaS.GeneratePredefinedNodeDescription();
	Else
		// This infobase presentation.	
		Description = DataExchangeServer.PredefinedExchangePlanNodeDescription(ExchangePlanName);
		If IsBlankString(Description) Then
			DescriptionChangeAvailable = True;
			Description = DataExchangeCached.ThisInfobaseName();
		EndIf;
		
		CorrespondentDescription = CorrespondentConfigurationDescription;
	EndIf;
	
	Prefix = GetFunctionalOption("InfobasePrefix");
	If IsBlankString(Prefix) Then
		PrefixChangeAvailable = True;
		DataExchangeOverridable.OnDetermineDefaultInfobasePrefix(Prefix);
	EndIf;
	
	If DIBSetup Then
		ConnectionKind = "RegularCommunicationChannels";
	EndIf;
	
	If ContinueSetupInSubordinateDIBNode Then
		ExchangeNode = DataExchangeServer.MasterNode();
		
		// Filling parameters from connection settings in the constant.
		ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
		
		ExchangeCreationWizard = ModuleSetupWizard.Create();
		ExchangeCreationWizard.ExchangePlanName = ExchangePlanName;
		ExchangeCreationWizard.ExchangeSettingsOption = SettingID;
		ExchangeCreationWizard.WizardRunOption = "ContinueDataExchangeSetup";
		
		ModuleSetupWizard.FillConnectionSettingsFromConstant(ExchangeCreationWizard);		
		ReadWizardConnectionParametersStructure(ExchangeCreationWizard);
		
		DescriptionChangeAvailable = False;
		PrefixChangeAvailable     = False;
		
		CorrespondentDescriptionChangeAvailable = False;
		CorrespondentPrefixChangeAvailable     = False;
	EndIf;
	
	SourceInfobaseID = DataExchangeServer.CodeOfPredefinedExchangePlanNode(ExchangePlanName);
	
	UsePrefixesForExchangeSettings = Not DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName)
		Or Not DataExchangeXDTOServer.VersionWithDataExchangeIDSupported(ExchangePlans[ExchangePlanName].EmptyRef());
	
	// To get settings from the correspondent, set the default mode.
	UsePrefixesForCorrespondentExchangeSettings = True;
	
	FillGoToTable();
	
EndProcedure

#EndRegion

#Region WizardWorkScenarios

&AtServer
Function AddNavigationTableRow(MainPageName, NavigationPageName, DecorationPageName = "")
	
	NavigationsString = NavigationTable.Add();
	NavigationsString.GoToNumber = NavigationTable.Count();
	NavigationsString.MainPageName = MainPageName;
	NavigationsString.NavigationPageName = NavigationPageName;
	NavigationsString.DecorationPageName = DecorationPageName;
	
	Return NavigationsString;
	
EndFunction

&AtServer
Procedure FillGoToTable()
	
	NavigationTable.Clear();
	
	If DIBSetup Then
		NewMove = AddNavigationTableRow("ConnectionParametersRegularCommunicationChannelsPage", "NavigationStartPage");
		NewMove.OnOpenHandlerName = "CommonCommunicationChannelsConnectionParametersPage_OnOpen";
		NewMove.GoNextHandlerName = "CommonCommunicationChannelsConnectionParametersPage_OnGoNext";
	Else
		NewMove = AddNavigationTableRow("ConnectionSetupMethodPage", "NavigationStartPage");
		NewMove.OnOpenHandlerName = "ConnectionSetupMethodPage_OnOpen";
		NewMove.GoNextHandlerName = "ConnectionSetupMethodPage_OnGoNext";
		
		NewMove = AddNavigationTableRow("ConnectionParametersInternetPage", "PageNavigationFollowUp");
		NewMove.OnOpenHandlerName = "ConnectionParametersInternetPage_OnOpen";
		NewMove.GoNextHandlerName = "ConnectionParametersInternetPage_OnGoNext";
		
		If Not SaaSModel Then
			NewMove = AddNavigationTableRow("ConnectionParametersExternalConnectionPage", "PageNavigationFollowUp");
			NewMove.OnOpenHandlerName = "ConnectionParametersExternalConnectionPage_OnOpen";
			NewMove.GoNextHandlerName = "ConnectionParametersExternalConnectionPage_OnGoNext";
			
			NewMove = AddNavigationTableRow("ConnectionParametersRegularCommunicationChannelsPage", "PageNavigationFollowUp");
			NewMove.OnOpenHandlerName = "CommonCommunicationChannelsConnectionParametersPage_OnOpen";
			NewMove.GoNextHandlerName = "CommonCommunicationChannelsConnectionParametersPage_OnGoNext";
		EndIf;
	EndIf;
	
	NewMove = AddNavigationTableRow("ConnectionCheckPage", "PageNavigationFollowUp");
	NewMove.OnOpenHandlerName = "ConnectionCheckPage_OnOpen";
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "ConnectionCheckPage_TimeConsumingOperation";
	
	NewMove = AddNavigationTableRow("GeneralSynchronizationSettingsPage", "PageNavigationFollowUp");
	NewMove.OnOpenHandlerName = "GeneralSynchronizationSettingsPage_OnOpen";
	NewMove.GoNextHandlerName = "GeneralSynchronizationSettingsPage_OnGoNext";
	
	NewMove = AddNavigationTableRow("SaveConnectionSettingsPage", "PageNavigationFollowUp");
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "SaveConnectionSettingsPage_TimeConsumingOperation";
	
	NewMove = AddNavigationTableRow("EndPage", "NavigationEndPage");
	
EndProcedure

#EndRegion

#Region FormAttributesChangesHandlers

&AtClient
Procedure OnChangeConnectionSetupMethod()
	
	IsExchangeWithApplicationInService = (ConnectionSetupMethod = "ApplicationFromList");
	
	If ConnectionSetupMethod = "ApplicationFromList" Then
		Items.ConnectionSetupMethodsPanel.CurrentPage = Items.MyApplicationsPage;
		
		StartGetConnectionsListForConnection();
	ElsIf ConnectionSetupMethod = "ConfigureManually" Then
		
		Items.ExternalConnectionConnectionKind.Visible  = AvailableTransportKinds.Property("COM");
		Items.InternetConnectionKind.Visible           = AvailableTransportKinds.Property("WS");
		Items.RegularCommunicationChannelsConnectionKind.Visible = AvailableTransportKinds.Property("FILE")
			Or AvailableTransportKinds.Property("FTP")
			Or AvailableTransportKinds.Property("EMAIL");
		Items.PassiveModeConnectionKind.Visible      = AvailableTransportKinds.Property("WSPassiveMode");
		
		Items.SettingsFilePassiveModeGroup.Visible = AvailableTransportKinds.Property("WSPassiveMode");
		Items.SettingsFileRegularCommunicationChannelsGroup.Visible = AvailableTransportKinds.Property("FILE")
			Or AvailableTransportKinds.Property("FTP")
			Or AvailableTransportKinds.Property("EMAIL");
		
		Items.ConnectionSetupMethodsPanel.CurrentPage = Items.ConnectionKindsPage;
		OnChangeConnectionKind();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeImportConnectionSettingsFromFile()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ConnectionSettingsFileNameToImport", "Enabled", ImportConnectionParametersFromFile);
	
EndProcedure

&AtClient
Procedure OnChangeConnectionKind()
	
	CommonClientServer.SetFormItemProperty(Items,
		"SettingsFileRegularCommunicationChannelsGroup", "Enabled", ConnectionKind = "RegularCommunicationChannels");
	
	CommonClientServer.SetFormItemProperty(Items,
		"SettingsFilePassiveModeGroup", "Enabled", ConnectionKind = "PassiveMode");
	
	If ConnectionKind = "RegularCommunicationChannels" Then
		OnChangeImportConnectionSettingsFromFile();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsFILEUsing()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelFILEUsageGroup", "Enabled", RegularCommunicationChannelsFILEUsage);
	
EndProcedure
	
&AtClient
Procedure OnChangeRegularCommunicationChannelsFTPUsing()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelFTPUsageGroup", "Enabled", RegularCommunicationChannelsFTPUsage);
	
	OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit();
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsEMAILUsing()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsEMAILUsageGroup", "Enabled", RegularCommunicationChannelsEMAILUsage);
	
	OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit();
	
EndProcedure

&AtClient
Procedure OnChangeExternalConnectionInfobaseOperationMode()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionInfobaseDirectory",
		"Enabled", ExternalConnectionInfobaseOperationMode = "File");
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionServerCluster",
		"Enabled", ExternalConnectionInfobaseOperationMode = "ClientServer");
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionInfobaseName",
		"Enabled", ExternalConnectionInfobaseOperationMode = "ClientServer");
	
EndProcedure
	
&AtClient
Procedure OnChangeExternalConnectionAuthenticationKind()
	
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionUsername",
		"Enabled", ExternalConnectionAuthenticationKind = "1CEnterprise");
		
	CommonClientServer.SetFormItemProperty(Items,
		"ExternalConnectionPassword",
		"Enabled", ExternalConnectionAuthenticationKind = "1CEnterprise");
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsArchiveFiles()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelArchivePasswordGroup", "Enabled", RegularCommunicationChannelsArchiveFiles);
	
	OnChangeRegularCommunicationChannelsUseArchivePassword();
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsUseArchivePassword()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsArchivePassword", "Enabled", RegularCommunicationChannelsProtectArchiveWithPassword);
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsFTPUseFileSizeLimit()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsFTPMaxFileSize",
		"Enabled",
		RegularCommunicationChannelsFTPEnableFileSizeLimit);
	
EndProcedure

&AtClient
Procedure OnChangeRegularCommunicationChannelsEMAILUseAttachmentSizeLimit()
	
	CommonClientServer.SetFormItemProperty(Items,
		"RegularCommunicationChannelsMAILMaxAttachmentSize",
		"Enabled",
		RegularCommunicationChannelsEMAILEnableAttachmentSizeLimit);
	
EndProcedure

#EndRegion

#Region MoveChangeHandlers

&AtClient
Function Attachable_ConnectionSetupMethodPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.ConnectionSetupMethod.Visible = SaaSModel
		AND (AvailableTransportKinds.Property("WS") Or AvailableTransportKinds.Property("WSPassiveMode"));
		
	If IsMoveNext Then
		OnChangeConnectionSetupMethod();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionSetupMethodPage_OnGoNext(Cancel)
	
	If ConnectionSetupMethod = "ApplicationFromList" Then
		
		CurrentData = Items.ApplicationsSaaS.CurrentData;
		If CurrentData = Undefined Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Выберите приложение из списка для продолжения настройки подключения.'; en = 'Select an application from the list to continue setting up connection.'; pl = 'Wybierz aplikację z listy, aby kontynuować konfigurację połączenia.';es_ES = 'Seleccione una aplicación de la lista para seguir ajustando la conexión.';es_CO = 'Seleccione una aplicación de la lista para seguir ajustando la conexión.';tr = 'Bağlantı ayarlarına devam etmek için listeden bir uygulamayı seçin.';it = 'Seleziona un''applicazione dall''elenco per continuare a impostare la connessione.';de = 'Wählen Sie eine Anwendung aus der Liste aus, um die Konfiguration der Verbindung fortzusetzen.'"),
				, "ApplicationsSaaS", , Cancel);
			Return 0;
		ElsIf CurrentData.SynchronizationSetupInServiceManager Then
			ShowMessageBox(, NStr("ru = 'Для настройки синхронизации данных с выбранным приложением перейдите в менеджер сервиса.
				|В менеджере сервиса воспользуйтесь командой ""Синхронизация данных"".'; 
				|en = 'To set up data synchronization with the selected application, go to the service manager.
				|In the service manager, click ""Data synchronization"".'; 
				|pl = 'Dla ustawienia synchronizacji danych z wybranej aplikacji, przejdź do menedżera serwisu.
				|W menedżerze serwisu należy użyć polecenia ""Synchronizacja danych"".';
				|es_ES = 'Para ajustar la sincronización de datos con la aplicación seleccionada pase al gestor de servicio,
				|En el gestor de servicio use el comando ""Sincronización de datos"".';
				|es_CO = 'Para ajustar la sincronización de datos con la aplicación seleccionada pase al gestor de servicio,
				|En el gestor de servicio use el comando ""Sincronización de datos"".';
				|tr = 'Veri senkronizasyonunu ayarlamak için servis yöneticisine gidin. 
				|Servis yöneticisinde ""Veri Senkronizasyonu"" komutunu kullanın.';
				|it = 'Per impostare la sincronizzazione dati con l''applicazione selezionata, vai al manager di servizio.
				|Nel manager di servizio clicca ""Sincronizzazione dati"".';
				|de = 'Um die Synchronisierung der Daten mit der ausgewählten Anwendung einzurichten, gehen Sie zum Service Manager.
				|Verwenden Sie im Service Manager den Befehl ""Datensynchronisation"".'"));
			Cancel = True;
			Return 0;
		Else
			AreaPrefix = CurrentData.Prefix;
			
			CorrespondentDescription   = CurrentData.ApplicationDescription;
			CorrespondentAreaPrefix = CurrentData.CorrespondentPrefix;
			
			CorrespondentEndpoint = CurrentData.CorrespondentEndpoint;
			CorrespondentDataArea = CurrentData.DataArea;
			
			ConnectionKind = "";
		EndIf;
		
	ElsIf ConnectionSetupMethod = "ConfigureManually" Then
		
		If ConnectionKind = "RegularCommunicationChannels"
			AND ImportConnectionParametersFromFile Then
			If IsBlankString(ConnectionSettingsFileNameToImport) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Выберите файл с настройками подключения.'; en = 'Select a file with connection settings.'; pl = 'Wybierz plik z ustawieniami połączenia.';es_ES = 'Seleccione un archivo con ajustes de conexión.';es_CO = 'Seleccione un archivo con ajustes de conexión.';tr = 'Bağlantı ayarlarına sahip bir dosya seçin.';it = 'Seleziona un file con impostazioni di connessione.';de = 'Wählen Sie eine Datei mit Verbindungseinstellungen aus.'"),
					, "ConnectionSettingsFileNameToImport", , Cancel);
				Return 0;
			EndIf;
		ElsIf ConnectionKind = "PassiveMode" Then
			If IsBlankString(XDTOCorrespondentSettingsFileName) Then
				CommonClientServer.MessageToUser(
					NStr("ru = 'Выберите файл с настройками программы-корреспондента.'; en = 'Select a file with correspondent application  settings'; pl = 'Wybierz plik z ustawieniami programu-korespondenta.';es_ES = 'Seleccione un archivo con ajustes del programa-correspondiente.';es_CO = 'Seleccione un archivo con ajustes del programa-correspondiente.';tr = 'Muhabir program ayarlarına sahip bir dosya seçin.';it = 'Seleziona un file con le impostazioni dell''applicazione corrispondente';de = 'Wählen Sie eine Datei mit den korrespondierenden Programmeinstellungen aus.'"),
					, "XDTOCorrespondentSettingsFileName", , Cancel);
				Return 0;
			EndIf;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersInternetPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ConnectionKind <> "Internet" Then
		SkipPage = True;
		Return 0;
	EndIf;
	
	Items.InternetAccessParameters1.Visible = InternetAccessParametersSetupAvailable;
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersInternetPage_OnGoNext(Cancel)
	
	If ConnectionKind <> "Internet" Then
		Return 0;
	EndIf;
	
	If IsBlankString(InternetWebAddress) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите адрес программы в Интернет.'; en = 'Specify an online application address.'; pl = 'Podaj adres aplikacji online.';es_ES = 'Especificar una dirección online de la aplicación.';es_CO = 'Especificar una dirección online de la aplicación.';tr = 'Çevrimiçi uygulama adresini belirtin.';it = 'Indica l''indirizzo online dell''applicazione.';de = 'Geben Sie eine Online-Anwendungsadresse an.'"),
			, "InternetWebAddress", , Cancel);
		Return 0;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersExternalConnectionPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SaaSModel Then
		SkipPage = True;
	EndIf;
	
	If ConnectionKind <> "ExternalConnection" Then
		SkipPage = True;
	EndIf;
	
	ExternalConnectionInfobaseOperationMode = "File";
	OnChangeExternalConnectionInfobaseOperationMode();
	
	ExternalConnectionAuthenticationKind = "1CEnterprise";
	OnChangeExternalConnectionAuthenticationKind();
	
EndFunction

&AtClient
Function Attachable_ConnectionParametersExternalConnectionPage_OnGoNext(Cancel)
	
	If ConnectionKind <> "ExternalConnection" Then
		Return 0;
	EndIf;
	
	If ExternalConnectionInfobaseOperationMode = "File" Then
		
		If IsBlankString(ExternalConnectionInfobaseDirectory) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Выберите каталог расположения информационной базы.'; en = 'Select an infobase directory.'; pl = 'Wybierz katalog lokalizacji bazy informacyjnej.';es_ES = 'Seleccione un catálogo de situación de la base de información.';es_CO = 'Seleccione un catálogo de situación de la base de información.';tr = 'Veri tabanın konum dizinini seçin.';it = 'Seleziona una directory infobase.';de = 'Wählen Sie das Verzeichnis des Informationsbasisstandortes aus.'"),
				, "ExternalConnectionInfobaseDirectory", , Cancel);
			Return 0;
		EndIf;
		
	ElsIf ExternalConnectionInfobaseOperationMode = "ClientServer" Then
		
		If IsBlankString(ExternalConnectionServerCluster) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите имя кластера серверов 1С:Предприятия.'; en = 'Specify a name of 1C:Enterprise server cluster.'; pl = 'Wprowadź nazwę klastra serwerów 1C:Enterprise.';es_ES = 'Indique el nombre de clúster de servidores de 1C:Enterprise.';es_CO = 'Indique el nombre de clúster de servidores de 1C:Enterprise.';tr = '1C:Enterprise sunucu kümesi adı belirtin.';it = 'Indica il nome di 1C:Enterprise server cluster.';de = 'Geben Sie den Namen des 1C:Enterprise Server-Clusters ein.'"),
				, "ExternalConnectionServerCluster", , Cancel);
			Return 0;
		EndIf;
		
		If IsBlankString(ExternalConnectionInfobaseName) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите имя информационной базы в кластере серверов 1С:Предприятия.'; en = 'Specify an infobase name in 1C:Enterprise server cluster.'; pl = 'Wprowadź nazwę bazy informacyjnej w klastrze serwerów 1C:Enterprise.';es_ES = 'Indique el nombre de la base de información en el clúster de servidores de 1C:Enterprise.';es_CO = 'Indique el nombre de la base de información en el clúster de servidores de 1C:Enterprise.';tr = '1C:Enterprise sunucu kümesinde bir Infobase adı belirtin.';it = 'Indica il nome di un infobase nel 1C:Enterprise server cluster.';de = 'Geben Sie den Namen der Informationsbasis im 1C:Enterprise Server-Cluster ein.'"),
				, "ExternalConnectionInfobaseName", , Cancel);
			Return 0;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_CommonCommunicationChannelsConnectionParametersPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ConnectionKind <> "RegularCommunicationChannels" Then
		SkipPage = True;
		Return 0;
	EndIf;
	
	SetupAdditionalParameters = New Structure;
	SetupAdditionalParameters.Insert("IsMoveNext", IsMoveNext);
	ContinueSetupNotification = New NotifyDescription("ConnectionParametersRegularCommunicationChannelsContinueSetting",
		ThisObject, SetupAdditionalParameters);
	
	If IsMoveNext
		AND ImportConnectionParametersFromFile Then
		// Importing settings from the file.
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Notification", ContinueSetupNotification);
		
		CompletionNotification = New NotifyDescription("OnCompletePutConnectionSettingsFileForImport", ThisObject, AdditionalParameters);
		BeginPutFile(CompletionNotification, , ConnectionSettingsFileNameToImport, False, UUID);
	Else
		Result = New Structure;
		Result.Insert("Cancel", False);
		Result.Insert("ErrorMessage", "");
		
		ExecuteNotifyProcessing(ContinueSetupNotification, Result);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_CommonCommunicationChannelsConnectionParametersPage_OnGoNext(Cancel)
	
	If ConnectionKind <> "RegularCommunicationChannels" Then
		Return 0;
	EndIf;
	
	If Not RegularCommunicationChannelsFILEUsage
		AND Not RegularCommunicationChannelsFTPUsage
		AND Not RegularCommunicationChannelsEMAILUsage Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Выберите хотя бы один способ передачи файлов с данными.'; en = 'Select at least one way to transfer files with data.'; pl = 'Wybierz przynajmniej jeden sposób przesyłania plików z danymi.';es_ES = 'Seleccione aunque sea un modo de pasar los archivos con los datos.';es_CO = 'Seleccione aunque sea un modo de pasar los archivos con los datos.';tr = 'En az bir tane veri dosyasını aktarma yöntemini seçin.';it = 'Seleziona almeno un modo per trasferire file con dati.';de = 'Wählen Sie mindestens eine Möglichkeit zum Übertragen von Datendateien.'"),
			, "RegularCommunicationChannelsFILEUsage", , Cancel);
		Return 0;
	EndIf;
	
	If RegularCommunicationChannelsArchiveFiles
		AND RegularCommunicationChannelsProtectArchiveWithPassword
		AND IsBlankString(RegularCommunicationChannelsArchivePassword) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите пароль для архивации файлов.'; en = 'Enter the password to archive files.'; pl = 'Wprowadź hasło dla archiwizacji plików.';es_ES = 'Indique la contraseña para archivar los archivos.';es_CO = 'Indique la contraseña para archivar los archivos.';tr = 'Dosyaların arşivlenmesi için şifre belirtin.';it = 'Inserisci la password per archiviare i file.';de = 'Geben Sie ein Passwort für die Archivierung von Dateien an.'"),
			, "RegularCommunicationChannelsArchivePassword", , Cancel);
		Return 0;
	EndIf;
	
	If RegularCommunicationChannelsFILEUsage Then
		
		If IsBlankString(RegularCommunicationChannelsFILEDirectory) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Выберите каталог для передачи файлов с данными.'; en = 'Select a directory to transfer files with data.'; pl = 'Wybierz katalog, dla przesyłania plików z danymi.';es_ES = 'Seleccione un catálogo para pasar los archivos con datos.';es_CO = 'Seleccione un catálogo para pasar los archivos con datos.';tr = 'Veri dosyaların aktarımı için bir dizin seçin.';it = 'Seleziona una cartella per trasferire i file con dati.';de = 'Wählen Sie ein Verzeichnis aus, um die Datendateien zu übertragen.'"),
				, "RegularCommunicationChannelsFILEDirectory", , Cancel);
			Return 0;
		EndIf;
		
	EndIf;
	
	If RegularCommunicationChannelsFTPUsage Then
		
		If IsBlankString(RegularCommunicationChannelsFTPPath) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите адрес каталога для передачи файлов с данными.'; en = 'Specify a directory to transfer files with data.'; pl = 'Wprowadź adres katalogu dla przesyłania plików z danymi.';es_ES = 'Indique una dirección del catálogo para pasar los archivos con los datos.';es_CO = 'Indique una dirección del catálogo para pasar los archivos con los datos.';tr = 'Veri dosyaların aktarımı için dizin adresini belirtin.';it = 'Specifica una cartella per trasferire i file con dati.';de = 'Geben Sie die Adresse des Verzeichnisses für die Übertragung von Datendateien an.'"),
				, "RegularCommunicationChannelsFTPPath", , Cancel);
			Return 0;
		EndIf;
		
		If RegularCommunicationChannelsFTPEnableFileSizeLimit
			AND Not ValueIsFilled(RegularCommunicationChannelsFTPMaxFileSize) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите максимальный допустимый размер файлов с данными.'; en = 'Specify the maximum allowed size of files with data.'; pl = 'Wprowadź maksymalnie dopuszczalny rozmiar plików z danymi.';es_ES = 'Indique un tamaño máximo disponible de archivos con los datos.';es_CO = 'Indique un tamaño máximo disponible de archivos con los datos.';tr = 'Maksimum izin verilebilecek veri dosyasını belirtin.';it = 'Specifica la dimensione massima permessa del file con dati.';de = 'Geben Sie die maximal zulässige Größe von Datendateien an.'"),
				, "RegularCommunicationChannelsFTPMaxFileSize", , Cancel);
			Return 0;
		EndIf;

	EndIf;
	
	If RegularCommunicationChannelsEMAILUsage Then
		
		If Not ValueIsFilled(RegularCommunicationChannelsMAILUserAccount) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Выберите учетную запись электронной почты для отправки сообщений с данными.'; en = 'Select an email account to send messages with data.'; pl = 'Wybierz konto e-mail do wysyłania wiadomości z danymi.';es_ES = 'Seleccione una cuenta del correo electrónico para enviar los mensajes de datos.';es_CO = 'Seleccione una cuenta del correo electrónico para enviar los mensajes de datos.';tr = 'Veri mesajların gönderilmesi için e-mail hesabını belirtin.';it = 'Seleziona una account email per inviare messaggi con dati.';de = 'Wählen Sie ein E-Mail-Konto, um Datennachrichten zu senden.'"),
				, "RegularCommunicationChannelsMAILUserAccount", , Cancel);
			Return 0;
		EndIf;
		
		If RegularCommunicationChannelsEMAILEnableAttachmentSizeLimit
			AND Not ValueIsFilled(RegularCommunicationChannelsMAILMaxAttachmentSize) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите максимальный допустимый размер почтового вложения.'; en = 'Specify the maximum allowed size of mail attachment.'; pl = 'Wprowadź maksymalnie dopuszczalny rozmiar załącznika wiadomości e-mail.';es_ES = 'Indique un tamaño máximo del archivo adjunto.';es_CO = 'Indique un tamaño máximo del archivo adjunto.';tr = 'Maksimum izin verilen e-mail ekinin boyutunu belirtin.';it = 'Specificare la dimensione massima dell''allegato email.';de = 'Geben Sie die maximal zulässige Größe des E-Mail-Anhangs an.'"),
				, "RegularCommunicationChannelsMAILMaxAttachmentSize", , Cancel);
			Return 0;
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ConnectionKind = "PassiveMode" Then
		
		SkipPage = True;
		
	ElsIf ConnectionKind = "ExternalConnection"
		Or ConnectionKind = "Internet"
		Or SaaSModel Then
		
		Items.ConnectionCheckPanel.CurrentPage = Items.ConnectionCheckOnlinePage;
		
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		
		Items.ConnectionCheckPanel.CurrentPage = Items.ConnectionCheckOfflinePage;
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	
	If ConnectionKind = "PassiveMode" Then
		
		GoToNext = True;
		
	ElsIf ConnectionKind = "ExternalConnection"
		Or ConnectionKind = "Internet" Then
		
		OnStartCheckConnectionOnline();
		
	ElsIf SaaSModel Then
		
		OnStartConnectionCheckInSaaS();
		
	ElsIf ConnectionKind = "RegularCommunicationChannels" Then
		
		OnStartCheckConnectionOffline();
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_GeneralSynchronizationSettingsPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	SetupAdditionalParameters = New Structure;
	SetupAdditionalParameters.Insert("IsMoveNext", IsMoveNext);
	ContinueSetupNotification = New NotifyDescription("CommonSynchronizationSettingsContinueSetting",
		ThisObject, SetupAdditionalParameters);
	
	If IsMoveNext
		AND ConnectionKind = "PassiveMode" Then
		// Importing correspondent settings from the file.
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("Notification", ContinueSetupNotification);
		
		CompletionNotification = New NotifyDescription("OnCompletePutXDTOCorrespondentSettingsFile", ThisObject, AdditionalParameters);
		BeginPutFile(CompletionNotification, , XDTOCorrespondentSettingsFileName, False, UUID);
	Else
		
		Result = New Structure;
		Result.Insert("Cancel", False);
		Result.Insert("ErrorMessage", "");
		
		ExecuteNotifyProcessing(ContinueSetupNotification, Result);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_GeneralSynchronizationSettingsPage_OnGoNext(Cancel)
	
	If Not ConnectionKind = "PassiveMode" Then
	
		If DescriptionChangeAvailable
			AND IsBlankString(Description) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите имя текущей информационной базы.'; en = 'Specify the name of the current infobase.'; pl = 'Podaj nazwę tej aplikacji.';es_ES = 'Especificar el nombre de esta aplicación.';es_CO = 'Especificar el nombre de esta aplicación.';tr = 'Bu programın adını belirtin.';it = 'Specificare il nome dell''infobase corrente.';de = 'Geben Sie diesen Anwendungsnamen an.'"),
				, "Description", , Cancel);
		EndIf;
			
		If PrefixChangeAvailable
			AND IsBlankString(Prefix) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите префикс этой программы.'; en = 'Specify prefix for this application.'; pl = 'Wprowadź prefiks tego programu.';es_ES = 'Indique el prefijo de este programa.';es_CO = 'Indique el prefijo de este programa.';tr = 'Bu programın önekini belirtin.';it = 'Specifica prefisso per questa applicazione.';de = 'Geben Sie das Präfix dieses Programms an.'"),
				, "Prefix", , Cancel);
		EndIf;
			
	EndIf;
	
	If CorrespondentDescriptionChangeAvailable
		AND IsBlankString(CorrespondentDescription) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите наименование программы-корреспондента.'; en = 'Specify correspondent application name.'; pl = 'Wprowadź nazwę programu-korespondenta.';es_ES = 'Indique el nombre del programa-correspondiente.';es_CO = 'Indique el nombre del programa-correspondiente.';tr = 'Muhabir programın adını belirtin.';it = 'Specifica il nome dell''applicazione corrispondente.';de = 'Geben Sie den Namen des korrespondierenden Programms ein.'"),
			, "CorrespondentDescription", , Cancel);
	EndIf;
		
	If Not ConnectionKind = "PassiveMode" Then
	
		If CorrespondentPrefixChangeAvailable
			AND IsBlankString(CorrespondentPrefix) Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Укажите префикс программы-корреспондента.'; en = 'Specify correspondent application prefix.'; pl = 'Wprowadź prefiks programu-korespondenta.';es_ES = 'Indique el prefijo del programa-correspondiente.';es_CO = 'Indique el prefijo del programa-correspondiente.';tr = 'Muhabir programın önekini belirtin.';it = 'Specifica il prefisso dell''applicazione corrispondente.';de = 'Geben Sie das Präfix des korrespondierenden Programms ein.'"),
				, "CorrespondentPrefix", , Cancel);
		EndIf;
			
	EndIf;
	
	If SaveConnectionParametersToFile
		AND IsBlankString(ConnectionSettingsFileNameToExport) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите путь к файлу для сохранения настроек подключения.'; en = 'Specify a path to file to save connection settings.'; pl = 'Wprowadź ścieżkę do pliku, aby zapisać ustawienia połączenia.';es_ES = 'Indique la ruta al archivo para guardar los ajustes de conexión.';es_CO = 'Indique la ruta al archivo para guardar los ajustes de conexión.';tr = 'Bağlantı ayarlarını kaydetmek için dosya yolunu belirtin.';it = 'Specifica un percorso al file per salvare i parametri di connessione.';de = 'Geben Sie den Pfad zur Datei an, um die Verbindungseinstellungen zu speichern.'"),
			, "ConnectionSettingsFileNameToExport", , Cancel);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_SaveConnectionSettingsPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartSaveConnectionSettings();
	
EndFunction

#EndRegion

#Region AdditionalHandlersOfMoves

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsMoveNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 1 Then
		
		GoToNumber = 1;
		
	EndIf;
	
	GoToNumberOnChange(IsMoveNext);
	
EndProcedure

&AtClient
Procedure GoToNumberOnChange(Val IsMoveNext)
	
	// Executing wizard step change event handlers.
	ExecuteGoToEventHandlers(IsMoveNext);
	
	// Setting page to be displayed.
	GoToRowsCurrent = NavigationTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("ru = 'Не определена страница для отображения.'; en = 'Page to be displayed is not specified.'; pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no se ha definido.';es_CO = 'Página para visualizar no se ha definido.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da mostrare non è specificata.';de = 'Die Seite für die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	Items.MainPanel.CurrentPage  = Items[GoToRowCurrent.MainPageName];
	Items.NavigationPanel.CurrentPage = Items[GoToRowCurrent.NavigationPageName];
	
	Items.NavigationPanel.CurrentPage.Enabled = Not (IsMoveNext AND GoToRowCurrent.TimeConsumingOperation);
	
	// Setting the default button.
	NextButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "NextCommand");
	
	If NextButton <> Undefined Then
		
		NextButton.DefaultButton = True;
		
	Else
		
		DoneButton = GetFormButtonByCommandName(Items.NavigationPanel.CurrentPage, "DoneCommand");
		
		If DoneButton <> Undefined Then
			
			DoneButton.DefaultButton = True;
			
		EndIf;
		
	EndIf;
	
	If IsMoveNext AND GoToRowCurrent.TimeConsumingOperation Then
		
		AttachIdleHandler("ExecuteTimeConsumingOperationHandler", 0.1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteGoToEventHandlers(Val IsMoveNext)
	
	// Step change handlers.
	If IsMoveNext Then
		
		GoToRows = NavigationTable.FindRows(New Structure("GoToNumber", GoToNumber - 1));
		
		If GoToRows.Count() > 0 Then
			NavigationString = GoToRows[0];
		
			// OnGoNext handler.
			If Not IsBlankString(NavigationString.GoNextHandlerName)
				AND Not NavigationString.TimeConsumingOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationString.GoNextHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber - 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	Else
		
		GoToRows = NavigationTable.FindRows(New Structure("GoToNumber", GoToNumber + 1));
		
		If GoToRows.Count() > 0 Then
			NavigationString = GoToRows[0];
		
			// OnGoBack handler.
			If Not IsBlankString(NavigationString.GoBackHandlerName)
				AND Not NavigationString.TimeConsumingOperation Then
				
				ProcedureName = "Attachable_[HandlerName](Cancel)";
				ProcedureName = StrReplace(ProcedureName, "[HandlerName]", NavigationString.GoBackHandlerName);
				
				Cancel = False;
				
				Result = Eval(ProcedureName);
				
				If Cancel Then
					
					SetGoToNumber(GoToNumber + 1);
					
					Return;
					
				EndIf;
				
			EndIf;
		EndIf;
		
	EndIf;
	
	GoToRowsCurrent = NavigationTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("ru = 'Не определена страница для отображения.'; en = 'Page to be displayed is not specified.'; pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no se ha definido.';es_CO = 'Página para visualizar no se ha definido.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da mostrare non è specificata.';de = 'Die Seite für die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	If GoToRowCurrent.TimeConsumingOperation AND Not IsMoveNext Then
		
		SetGoToNumber(GoToNumber - 1);
		Return;
	EndIf;
	
	// OnOpen handler
	If Not IsBlankString(GoToRowCurrent.OnOpenHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, SkipPage, IsMoveNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.OnOpenHandlerName);
		
		Cancel = False;
		SkipPage = False;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf SkipPage Then
			
			If IsMoveNext Then
				
				SetGoToNumber(GoToNumber + 1);
				
				Return;
				
			Else
				
				SetGoToNumber(GoToNumber - 1);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteTimeConsumingOperationHandler()
	
	GoToRowsCurrent = NavigationTable.FindRows(New Structure("GoToNumber", GoToNumber));
	
	If GoToRowsCurrent.Count() = 0 Then
		Raise NStr("ru = 'Не определена страница для отображения.'; en = 'Page to be displayed is not specified.'; pl = 'Strona do wyświetlenia nie jest zdefiniowana.';es_ES = 'Página para visualizar no se ha definido.';es_CO = 'Página para visualizar no se ha definido.';tr = 'Gösterilecek sayfa tanımlanmamış.';it = 'La pagina da mostrare non è specificata.';de = 'Die Seite für die Anzeige ist nicht definiert.'");
	EndIf;
	
	GoToRowCurrent = GoToRowsCurrent[0];
	
	// TimeConsumingOperationProcessing handler.
	If Not IsBlankString(GoToRowCurrent.TimeConsumingOperationHandlerName) Then
		
		ProcedureName = "Attachable_[HandlerName](Cancel, GoToNext)";
		ProcedureName = StrReplace(ProcedureName, "[HandlerName]", GoToRowCurrent.TimeConsumingOperationHandlerName);
		
		Cancel = False;
		GoToNext = True;
		
		Result = Eval(ProcedureName);
		
		If Cancel Then
			
			SetGoToNumber(GoToNumber - 1);
			
			Return;
			
		ElsIf GoToNext Then
			
			SetGoToNumber(GoToNumber + 1);
			
			Return;
			
		EndIf;
		
	Else
		
		SetGoToNumber(GoToNumber + 1);
		
		Return;
		
	EndIf;
	
EndProcedure

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND StrFind(Item.CommandName, CommandName) > 0 Then
			
			Return Item;
			
		Else
			
			Continue;
			
		EndIf;
		
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

#EndRegion