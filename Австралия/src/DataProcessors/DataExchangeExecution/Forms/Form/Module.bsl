
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	AccountPasswordRecoveryAddress = Parameters.AccountPasswordRecoveryAddress;
	CloseOnSynchronizationDone           = Parameters.CloseOnSynchronizationDone;
	InfobaseNode                    = Parameters.InfobaseNode;
	Exit                   = Parameters.Exit;
	
	Parameters.Property("IsExchangeWithApplicationInService", ExchangeBetweenSaaSApplications);
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	If Not ValueIsFilled(InfobaseNode) Then
		
		If DataExchangeServer.IsSubordinateDIBNode() Then
			InfobaseNode = DataExchangeServer.MasterNode();
		Else
			DataExchangeServer.ReportError(NStr("ru = 'Не заданы параметры формы. Форма не может быть открыта.'; en = 'Form parameters are not specified. Cannot open the form.'; pl = 'Parametry formularza nie zostały określone. Nie można otworzyć formularza.';es_ES = 'Parámetros de formulario no están especificados. No se puede abrir el formulario.';es_CO = 'Parámetros de formulario no están especificados. No se puede abrir el formulario.';tr = 'Form parametreleri belirtilmemiş. Form açılamıyor.';it = 'I parametri del modulo non sono impostati. Il modulo non può essere aperto.';de = 'Formularparameter sind nicht angegeben. Das Formular kann nicht geöffnet werden.'"), Cancel);
			Return;
		EndIf;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	CorrespondentDescription = Common.ObjectAttributeValue(InfobaseNode, "Description");
	MessagesTransportKind     = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(InfobaseNode);
	ExecuteDataSending    = InformationRegisters.CommonInfobasesNodesSettings.ExecuteDataSending(InfobaseNode);
	
	SetPrivilegedMode(False);
	
	// Initializing user roles.
	DataExchangeAdministrationRoleAssigned = DataExchangeServer.HasRightsToAdministerExchanges();
	RoleAvailableFullAccess                     = Users.IsFullUser();
	
	NoLongSynchronizationPrompt = True;
	CheckVersionDifference       = Not ExchangeBetweenSaaSApplications;
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS")
		AND DataExchangeServer.IsStandaloneWorkplace() Then
		
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		
		NoLongSynchronizationPrompt = Not ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag();
		CheckVersionDifference       = False;
		
	EndIf;
	
	// Setting form title.
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Синхронизация данных с ""%1""'; en = 'Data synchronization with %1'; pl = 'Synchronizacja danych z %1';es_ES = 'Sincronización de datos con %1';es_CO = 'Sincronización de datos con %1';tr = '%1 ile veri senkronizasyonu';it = 'La sincronizzazione dei dati con il %1';de = 'Datensynchronisation mit %1'"), CorrespondentDescription);
	
	// In "DIB exchange over a web service" scenario authentication parameters (user name and password) 
	// stored in the infobase are redefined.
	// In "non-DIB exchange over a web service" scenario authentication parameters are only redefined 
	// (requested) if the infobase does not store the password.
	UseCurrentUserForAuthentication = False;
	UseSavedAuthenticationParameters    = False;
	SynchronizationPasswordSpecified                          = False;
	SyncPasswordSaved                       = False; // Password is saved in a safe storage (available in the background job)
	WSPassword                                          = "";
	
	If MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		If DataExchangeCached.IsDistributedInfobaseNode(InfobaseNode) Then
			
			// It is DIB and exchange by WS, using the current user and password from the session.
			UseCurrentUserForAuthentication = True;
			SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
			If SynchronizationPasswordSpecified Then
				WSPassword = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
			EndIf;
			
		Else
			
			// If the current infobase is not a DIB node, reading the transport settings from the infobase.
			TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(InfobaseNode);
			SynchronizationPasswordSpecified = TransportSettings.WSRememberPassword;
			If SynchronizationPasswordSpecified Then
				SyncPasswordSaved = True;
				UseSavedAuthenticationParameters = True;
				WSPassword = TransportSettings.WSPassword;
			Else
				// If user name and password are not available in the register, using the session user name and password.
				SynchronizationPasswordSpecified = DataExchangeServer.DataSynchronizationPasswordSpecified(InfobaseNode);
				If SynchronizationPasswordSpecified Then
					UseSavedAuthenticationParameters = True;
					WSPassword = DataExchangeServer.DataSynchronizationPassword(InfobaseNode);
				EndIf;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	HasErrors = ((DataExchangeServer.MasterNode() = InfobaseNode) AND ConfigurationChanged());
	
	BackgroundJobUseProgress = Not ExchangeBetweenSaaSApplications
		AND Not (MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS);
		
	ActivePasswordPromptPage = Not HasErrors
		AND (MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS)
		AND Not (SynchronizationPasswordSpecified AND NoLongSynchronizationPrompt);
		
	Items.LongSyncWarningGroup.Visible = ActivePasswordPromptPage AND Not NoLongSynchronizationPrompt;
	Items.PromptForPasswordGroup.Visible                     = ActivePasswordPromptPage AND Not SynchronizationPasswordSpecified;
		
	WindowOptionsKey = ?(SynchronizationPasswordSpecified AND NoLongSynchronizationPrompt,
		"SynchronizationPasswordSpecified", "") + "/" + ?(NoLongSynchronizationPrompt, "NoLongSynchronizationPrompt", "");
		
	FillGoToTable();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If TimeConsumingOperation Then
		EndExecutingTimeConsumingOperation(BackgroundJobID);
	EndIf;
	
	If ValueIsFilled(FormReopeningParameters)
		AND FormReopeningParameters.Property("NewDataSynchronizationSetting") Then
		
		NewDataSynchronizationSetting = FormReopeningParameters.NewDataSynchronizationSetting;
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode",                    NewDataSynchronizationSetting);
		FormParameters.Insert("AccountPasswordRecoveryAddress", AccountPasswordRecoveryAddress);
		
		OpeningParameters = New Structure;
		OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
		
		DataExchangeClient.OpenFormAfterClosingCurrentOne(ThisObject,
			"DataProcessor.DataExchangeExecution.Form.Form", FormParameters, OpeningParameters);
		
	Else
		SaveLongSynchronizationRequestFlag();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure GoToEventLog(Command)
	
	FormParameters = EventLogFilterData(InfobaseNode);
	OpenForm("DataProcessor.EventLog.Form", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	Close();
	DataExchangeClient.InstallConfigurationUpdate(Exit);
	
EndProcedure

&AtClient
Procedure ForgotPassword(Command)
	
	DataExchangeClient.OpenInstructionHowToChangeDataSynchronizationPassword(AccountPasswordRecoveryAddress);
	
EndProcedure

&AtClient
Procedure RunExchange(Command)
	
	GoNextExecute();
	
EndProcedure

&AtClient
Procedure ContinueSync(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// PART TO SUPPLY
////////////////////////////////////////////////////////////////////////////////

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

&AtClient
Procedure GoNextExecute()
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure ChangeGoToNumber(Iterator)
	
	ClearMessages();
	SetGoToNumber(GoToNumber + Iterator);
	
EndProcedure

&AtClient
Procedure SetGoToNumber(Val Value)
	
	IsMoveNext = (Value > GoToNumber);
	
	GoToNumber = Value;
	
	If GoToNumber < 0 Then
		GoToNumber = 0;
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
	
	Items.DataExchangeExecution.CurrentPage = Items[GoToRowCurrent.MainPageName];
	
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
				
				CalculationResult = Eval(ProcedureName);
				
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
				
				CalculationResult = Eval(ProcedureName);
				
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
		
		CalculationResult = Eval(ProcedureName);
		
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
		
		CalculationResult = Eval(ProcedureName);
		
		If Cancel Then
			
			If VersionMismatchErrorOnGetData <> Undefined AND VersionMismatchErrorOnGetData.HasError Then
				
				ProcessVersionDifferenceError();
				Return;
				
			EndIf;
			
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

// Adds a new row to the end of the current navigation table.
//
// Parameters:
//
//  MainPageName (mandatory) - String. Name of the MainPanel panel page that matches the current 
//  step number.
//  OnOpenHandlerName (optional) - String. Name of the "open current wizard page" event handler.
//  
//  TimeConsumingOperation (optional) - Boolean. flag that shows whether a time-consuming operation page is displayed.
//  True - a time-consuming operation page is displayed; False - a standard page is displayed. Default value -
//  False.
// 
&AtServer
Function GoToTableNewRow(MainPageName,
		OnOpenHandlerName = "",
		TimeConsumingOperation = False,
		TimeConsumingOperationHandlerName = "")
		
	NewRow = NavigationTable.Add();
	
	NewRow.GoToNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	
	NewRow.GoNextHandlerName = "";
	NewRow.GoBackHandlerName = "";
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = TimeConsumingOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
	Return NewRow;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// OVERRIDABLE PART
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS SECTION

&AtClient
Procedure ExecuteGoNext()
	
	GoToNext      = True;
	GoNextExecute();
	
EndProcedure

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.DataExchangeExecution.CurrentPage = Items.ExchangeCompletion;
	Items.ExchangeCompletionStatus.CurrentPage = Items.VersionsDifferenceError;
	Items.ActionsPanel.CurrentPage = Items.ActionsContinueCancel;
	Items.ContinueSync.DefaultButton = True;
	Items.VersionsDifferenceErrorDecoration.Title = VersionMismatchErrorOnGetData.ErrorText;
	
	CheckVersionDifference = False;
	
EndProcedure

&AtClient
Procedure SaveLongSynchronizationRequestFlag()
	
	Settings = Undefined;
	If SaveLongSynchronizationRequestFlagServer(Not NoLongSynchronizationPrompt, Settings) Then
		ChangedSettings = New Array;
		ChangedSettings.Add(Settings);
		Notify("UserSettingsChanged", ChangedSettings, ThisObject);
	EndIf;
	
EndProcedure

&AtClient
Procedure InitializeDataProcessorVariables()
	
	// Initialization of data processor variables
	ProgressPercent                   = 0;
	MessageFileIDInService = "";
	TimeConsumingOperationID     = "";
	ProgressAdditionalInformation             = "";
	TimeConsumingOperation                  = False;
	TimeConsumingOperationCompleted         = False;
	TimeConsumingOperationCompletedWithError = False;
	HasVersionDifferenceError         = False;
	
EndProcedure

&AtServer
Procedure CheckWhetherTransferToNewExchangeIsRequired()
	
	MessagesArray = GetUserMessages(True);
	
	If MessagesArray = Undefined Then
		Return;
	EndIf;
	
	Count = MessagesArray.Count();
	If Count = 0 Then
		Return;
	EndIf;
	
	Message      = MessagesArray[Count-1];
	MessageText = Message.Text;
	
	// A subsystem ID is deleted from the message if necessary.
	If StrStartsWith(MessageText, "{MigrationToNewExchangeDone}") Then
		
		MessageData = Common.ValueFromXMLString(MessageText);
		
		If MessageData <> Undefined
			AND TypeOf(MessageData) = Type("Structure") Then
			
			ExchangePlanName                    = MessageData.ExchangePlanNameToMigrateToNewExchange;
			ExchangePlanNodeCode                = MessageData.Code;
			NewDataSynchronizationSetting = ExchangePlans[ExchangePlanName].FindByCode(ExchangePlanNodeCode);
			
			BackgroundJobExecutionResult.AdditionalResultData.Insert("FormReopeningParameters",
				New Structure("NewDataSynchronizationSetting", NewDataSynchronizationSetting));
				
			BackgroundJobExecutionResult.AdditionalResultData.Insert("ForceCloseForm", True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure TestConnection()
	
	SetPrivilegedMode(True);
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser, Password",
			UseCurrentUserForAuthentication, ?(SynchronizationPasswordSpecified, Undefined, WSPassword)));
	
	ConnectionParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(InfobaseNode, AuthenticationParameters);
	
	DataSyncDisabled = False;
	UserErrorMessage = "";
	If Not DataExchangeServer.CorrespondentConnectionEstablished(InfobaseNode, ConnectionParameters, UserErrorMessage) Then
		ErrorMessage = NStr("ru = 'Не удалось подключиться к приложению в Интернете, по причине ""%1"".
			|Убедитесь, что:
			|- введен правильный пароль;
			|- указан корректный адрес для подключения;
			|- приложение доступно по указанному в настройках адресу;
			|- настройка синхронизации не была удалена в приложении в Интернете.
			|Повторите попытку синхронизации.'; 
			|en = 'Cannot connect to the online application due to ""%1"".
			|Make sure that:
			|- The password is correct.
			|- The address for connection is correct.
			|- The application is available at the address specified in the settings.
			| - The synchronization setting was not deleted in the online application.
			|Retry the synchronization.'; 
			|pl = 'Nie można połączyć się z aplikacją przez Internet z powodu ""%1"". 
			|Upewnij się, że:
			|- zostało wpisane poprawne hasło;
			|- podano poprawny adres połączenia;
			|- aplikacja jest dostępna pod adresem określonym w ustawieniach;
			|- ustawienie synchronizacji nie zostało usunięte w aplikacji w Internecie.
			|Ponów próbę synchronizacji.';
			|es_ES = 'No se ha podido conectarse con la aplicación en Internet a causa de ""%1"".
			|Asegúrese de que:
			|- se ha introducido una contraseña correcta;
			|- se ha indicado una dirección correcta para conectar;
			|- la aplicación está disponible por la dirección indicada en los ajustes;
			|- el ajuste de sincronización no se ha eliminado en la aplicación en Internet.
			|Vuelva a probar la sincronización.';
			|es_CO = 'No se ha podido conectarse con la aplicación en Internet a causa de ""%1"".
			|Asegúrese de que:
			|- se ha introducido una contraseña correcta;
			|- se ha indicado una dirección correcta para conectar;
			|- la aplicación está disponible por la dirección indicada en los ajustes;
			|- el ajuste de sincronización no se ha eliminado en la aplicación en Internet.
			|Vuelva a probar la sincronización.';
			|tr = '""%1"" nedeniyle çevrimiçi uygulamaya bağlanılamıyor.
			|Şunları kontrol edin:
			|- Şifre doğru.
			|- Bağlantı adresi doğru.
			|- Ayarlarda belirtilen adreste uygulamaya erişilebiliyor.
			|- Senkronizasyon ayarı çevrimiçi uygulamada silinmedi.
			|Yeniden senkronize etmeyi deneyin.';
			|it = 'Impossibile connettersi all''applicazione online a causa di ""%1"".
			|Assicurati che:
			|- La password è corretta.
			|- L''indirizzo della connessione è corretto.
			|- L''applicazione è disponibile all''indirizzo specificato nelle impostazioni.
			|- Le impostazioni di sincronizzazione non sono state cancellate nell''applicazione online.
			| Riprova la sincronizzazione.';
			|de = 'Die Verbindung zur Anwendung im Internet konnte wegen ""%1"" nicht hergestellt werden.
			|Stellen Sie sicher, dass:
			|- das richtige Passwort eingegeben wird;
			|- die richtige Adresse für die Verbindung angegeben wird;
			|- die Anwendung an der in den Einstellungen angegebenen Adresse verfügbar ist;
			|- die Synchronisationseinstellung nicht aus der Anwendung im Internet entfernt wurde.
			|Wiederholen Sie den Synchronisationsversuch.'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, UserErrorMessage);
		If ActivePasswordPromptPage Then
			CommonClientServer.MessageToUser(ErrorMessage);
		EndIf;
		DataSyncDisabled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure RecordExchangeCompletionWithError()
	
	DataExchangeServerCall.RecordExchangeCompletionWithError(
		InfobaseNode,
		?(BackgroundJobCurrentAction = 1, "DataImport", "DataExport"),
		OperationStartDate,
		ErrorMessage);
	
EndProcedure

&AtServerNoContext
Function EventLogFilterData(InfobaseNode)
	
	SelectedEvents = New Array;
	SelectedEvents.Add(DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataImport));
	SelectedEvents.Add(DataExchangeServer.EventLogMessageKey(InfobaseNode, Enums.ActionsOnExchange.DataExport));
	
	DataExchangeStatesImport = DataExchangeServer.DataExchangesStates(InfobaseNode, Enums.ActionsOnExchange.DataImport);
	DataExchangeStatesExport = DataExchangeServer.DataExchangesStates(InfobaseNode, Enums.ActionsOnExchange.DataExport);
	
	Result = New Structure;
	Result.Insert("EventLogEvent", SelectedEvents);
	Result.Insert("StartDate",    Min(DataExchangeStatesImport.StartDate, DataExchangeStatesExport.StartDate));
	Result.Insert("EndDate", Max(DataExchangeStatesImport.EndDate, DataExchangeStatesExport.EndDate));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function SaveLongSynchronizationRequestFlagServer(Val Flag, Settings = Undefined)
	
	If Common.SubsystemExists("CloudTechnology.SaaS.DataExchangeSaaS")
		AND DataExchangeServer.IsStandaloneWorkplace() Then
		
		ModuleStandaloneMode = Common.CommonModule("StandaloneMode");
		MustSave = Flag <> ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag();
		
		If MustSave Then
			ModuleStandaloneMode.LongSynchronizationQuestionSetupFlag(Flag, Settings);
		EndIf;
		
	Else
		MustSave = False;
	EndIf;
	
	Return MustSave;
EndFunction

&AtServerNoContext
Procedure EndExecutingTimeConsumingOperation(JobID)
	TimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF STEP CHANGE HANDLERS

////////////////////////////////////////////////////////////////////////////////
// Common exchange pages

&AtClient
Function Attachable_DataImport_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If DataSyncDisabled Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImport_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If DataSyncDisabled Then
		GoToNext = True;
	Else
		GoToNext = False;
		
		BackgroundJobCurrentAction = 1;
		BackgroundJobStartClient(BackgroundJobCurrentAction,
			"DataProcessors.DataExchangeExecution.StartDataExchangeExecution",
			Cancel);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImport_TimeConsumingOperationProcessing_End(Cancel, GoToNext)
	
	If HasErrors Or TimeConsumingOperationCompletedWithError Then
		RecordExchangeCompletionWithError();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If DataSyncDisabled Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If DataSyncDisabled Then
		GoToNext = True;
	Else
		GoToNext = False;
		OnStartExportData(Cancel);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataExport_TimeConsumingOperationProcessing_End(Cancel, GoToNext)
	
	If HasErrors Or TimeConsumingOperationCompletedWithError Then
		RecordExchangeCompletionWithError();
	Else
		If TimeConsumingOperationCompleted Then
			DataExchangeServerCall.RecordDataExportInTimeConsumingOperationMode(
				InfobaseNode,
				OperationStartDate);
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Procedure OnStartExportData(Cancel)
	
	If ExchangeBetweenSaaSApplications Then
		ContinueWait = True;
		OnStartExportDataAtServer(ContinueWait);
		
		If ContinueWait Then
			TimeConsumingOperationsClient.InitIdleHandlerParameters(
				DataExportIdleHandlerParameters);
				
			AttachIdleHandler("OnWaitForExportData",
				DataExportIdleHandlerParameters.CurrentInterval, True);
		Else
			OnCompleteDataExport();
		EndIf;
	Else
		BackgroundJobCurrentAction = 2;
		BackgroundJobStartClient(BackgroundJobCurrentAction,
			"DataProcessors.DataExchangeExecution.StartDataExchangeExecution", Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForExportData()
	
	ContinueWait = False;
	OnWaitForExportDataAtServer(DataExportHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(DataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForExportData",
			DataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteDataExport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataExport()
	
	DataExported = False;
	ErrorMessage = "";
	
	OnCompleteDataUnloadAtServer(DataExportHandlerParameters, DataExported, ErrorMessage);
	
	TimeConsumingOperationCompleted = True;
	TimeConsumingOperationCompletedWithError = Not DataExported;
	HasErrors = Not DataExported;
	OutputErrorDescriptionToUser = True;
	UserErrorMessage = ErrorMessage;
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtServer
Procedure OnStartExportDataAtServer(ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ExportSettings = New Structure;
	ExportSettings.Insert("Correspondent",               InfobaseNode);
	ExportSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
	
	DataExportHandlerParameters = Undefined;
	ModuleInteractiveExchangeWizard.OnStartExportData(ExportSettings,
		DataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForExportDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnWaitForExportData(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteDataUnloadAtServer(HandlerParameters, DataExported, ErrorMessage)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		DataExported = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard.OnCompleteExportData(HandlerParameters, CompletionStatus);
	HandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		DataExported = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		DataExported = CompletionStatus.Result.DataExported;
		
		If Not DataExported Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
			Return;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_ExchangeCompletion_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.ActionsPanel.CurrentPage = Items.ActionsClose;
	Items.FormClose.DefaultButton = True;
	
	ExchangeCompletedWithErrorPage = ?(DataExchangeAdministrationRoleAssigned,
		Items.ExchangeCompletedWithErrorForAdministrator,
		Items.ExchangeCompletedWithError);
	
	If DataSyncDisabled Then
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedWithConnectionError;
		
	ElsIf HasErrors Then
		
		If UpdateRequired Or DataExchangeServerCall.UpdateInstallationRequired() Then
			
			If RoleAvailableFullAccess Then 
				Items.ActionsPanel.CurrentPage = Items.ActionsInstallClose;
				Items.InstallUpdate.DefaultButton = True;
			EndIf;
			
			Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeCompletedWithErrorUpdateRequired;
			
			Items.PanelUpdateRequired.CurrentPage = ?(RoleAvailableFullAccess, 
				Items.UpdateRequiredFullAccess, Items.UpdateRequiredRestrictedAccess);
				
			Items.UpdateRequiredTextFullAccess.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Items.UpdateRequiredTextFullAccess.Title, CorrespondentDescription);
				
			Items.UpdateRequiredTextRestrictedAccess.Title = StringFunctionsClientServer.SubstituteParametersToString(
				Items.UpdateRequiredTextRestrictedAccess.Title, CorrespondentDescription);
			
		Else
				
			Items.ExchangeCompletionStatus.CurrentPage = ExchangeCompletedWithErrorPage;
			
			If OutputErrorDescriptionToUser Then
				CommonClientServer.MessageToUser(UserErrorMessage);
			EndIf;
			
		EndIf;
		
	Else
		
		Items.ExchangeCompletionStatus.CurrentPage = Items.ExchangeSucceeded;
		
	EndIf;
	
	// Updating all opened dynamic lists.
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
EndFunction

&AtClient
Function Attachable_ExchangeCompletion_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	
	Notify("DataExchangeCompleted");
	
	If CloseOnSynchronizationDone
		AND Not DataSyncDisabled
		AND Not HasErrors Then
		
		Close();
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Pages of exchange over a web service

&AtClient
Function Attachable_UserPasswordRequest_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.ForgotPassword.Visible = Not IsBlankString(AccountPasswordRecoveryAddress);
	
	Items.RunExchange.DefaultButton = True;
	
EndFunction

&AtClient
Function Attachable_UserPasswordRequest_OnGoNext(Cancel)
	
	If IsBlankString(WSPassword) Then
		NString = NStr("ru = 'Не указан пароль.'; en = 'No password specified.'; pl = 'Hasło nie zostało określone.';es_ES = 'Contraseña no está especificada.';es_CO = 'Contraseña no está especificada.';tr = 'Şifre belirtilmemiş.';it = 'Nessuna password specificata.';de = 'Passwort ist nicht angegeben.'");
		CommonClientServer.MessageToUser(NString,, "WSPassword",, Cancel);
		Return Undefined;
	EndIf;
	
	SaveLongSynchronizationRequestFlag();
	
EndFunction

&AtClient
Function Attachable_ConnectionCheckWait_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	TestConnection();
	If DataSyncDisabled
		AND ActivePasswordPromptPage Then
		Cancel = True;
	EndIf;
	GoToNext = Not Cancel;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// SECTION OF PROCESSING BACKGROUND JOBS

&AtClient
Procedure BackgroundJobStartClient(Action, JobName, Cancel)
	
	// If the password is not saved to the base, it must be passed from the form, because of the fact that the session parameters are not available in the background job.
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser, Password",
			UseCurrentUserForAuthentication, ?(SyncPasswordSaved, Undefined, WSPassword)));
	
	JobParameters = New Structure;
	JobParameters.Insert("JobName",                          JobName);
	JobParameters.Insert("Cancel",                               Cancel);
	JobParameters.Insert("InfobaseNode",              InfobaseNode);
	JobParameters.Insert("ExecuteImport",                   BackgroundJobCurrentAction = 1);
	JobParameters.Insert("ExecuteExport",                   BackgroundJobCurrentAction = 2);
	JobParameters.Insert("ExchangeMessagesTransportKind",        MessagesTransportKind);
	JobParameters.Insert("TimeConsumingOperation",                  TimeConsumingOperation);
	JobParameters.Insert("TimeConsumingOperationID",     TimeConsumingOperationID);
	JobParameters.Insert("MessageFileIDInService", MessageFileIDInService);
	JobParameters.Insert("AuthenticationParameters",             AuthenticationParameters);
	
	Result = ScheduledJobStartAtServer(JobParameters, VersionMismatchErrorOnGetData, CheckVersionDifference);
	
	If Result = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	If Result.Status = "Running" Then
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		If BackgroundJobUseProgress Then
			IdleParameters.OutputProgressBar     = True;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("BackgroundJobExecutionProgress", ThisObject);
			IdleParameters.Interval                       = 1;
		EndIf;
		
		CompletionNotification = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitForCompletion(Result, CompletionNotification, IdleParameters);
		
	Else
		BackgroundJobExecutionResult = Result;
		AttachIdleHandler("BackgroundJobExecutionResult", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	
	BackgroundJobExecutionResult = Result;
	BackgroundJobExecutionResult();
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	If Progress.Progress <> Undefined Then
		ProgressStructure      = Progress.Progress;
		ProgressPercent       = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtClient
Procedure BackgroundJobExecutionResult()
	
	BackgroundJobGetResultAtServer();
	
	// If data exchange is performed with the application on the Internet, then you need to wait until 
	// the synchronization is completed on the correspondent side.
	If TimeConsumingOperation Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 1, True);
	Else
		AttachIdleHandler("TimeConsumingOperationCompletion", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationIdleHandler()
	
	TimeConsumingOperationCompletedWithError = False;
	ErrorMessage                   = "";
	
	AuthenticationParameters = ?(UseSavedAuthenticationParameters,
		Undefined,
		New Structure("UseCurrentUser, Password",
			UseCurrentUserForAuthentication, ?(SynchronizationPasswordSpecified, Undefined, WSPassword)));
	
	ActionState = DataExchangeServerCall.TimeConsumingOperationStateForInfobaseNode(
		TimeConsumingOperationID,
		InfobaseNode,
		AuthenticationParameters,
		ErrorMessage);
	
	If ActionState = "Active" Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		
		If ActionState <> "Completed" Then
			TimeConsumingOperationCompletedWithError = True;
			HasErrors                          = True;
		EndIf;
		
		TimeConsumingOperation              = False;
		TimeConsumingOperationCompleted     = True;
		TimeConsumingOperationID = "";
		
		AttachIdleHandler("TimeConsumingOperationCompletion", 1, True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TimeConsumingOperationCompletion()
	
	If BackgroundJobUseProgress Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	If TimeConsumingOperationCompletedWithError Then
		MessageFileIDInService = "";
	Else
		
		// If a long-term data acquisition from an application on the Internet was performed, then it is 
		// necessary to import the received file with data to the base.
		If BackgroundJobCurrentAction = 1 
			AND ValueIsFilled(MessageFileIDInService) Then
				
			BackgroundJobStartClient(BackgroundJobCurrentAction,
				"DataProcessors.DataExchangeExecution.ImportFileDownloadedFromInternet",
				False);
				
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(MessageFileIDInService) Then
		AfterCompleteBackgroundJob();
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCompleteBackgroundJob()
	
	// Migration to new exchange is completed. Close the form and open it again with other parameters.
	If BackgroundJobExecutionResult.AdditionalResultData.Property("ForceCloseForm") 
		AND BackgroundJobExecutionResult.AdditionalResultData.ForceCloseForm Then
		FormReopeningParameters = BackgroundJobExecutionResult.AdditionalResultData.FormReopeningParameters;
		ThisObject.Close();
	EndIf;
	
	// Go further with a one second delay to display the progress bar 100%.
	AttachIdleHandler("ExecuteGoNext", 1, True);
	
EndProcedure

&AtServer
Function ScheduledJobStartAtServer(JobParameters, VersionDifferenceErrorOnGetData, CheckVersionDifference)
	
	If JobParameters.ExecuteImport Then
		
		If CheckVersionDifference Then
			DataExchangeServer.InitializeVersionDifferenceCheckParameters(CheckVersionDifference);
		EndIf;
		
		DescriptionTemplate = NStr("ru = 'Выполняется загрузка данных из %1'; en = 'Importing data from %1'; pl = 'Importowanie danych z %1';es_ES = 'Se están descargando los datos de %1';es_CO = 'Se están descargando los datos de %1';tr = '%1''den veriler içe aktarılıyor';it = 'Importazione dati da %1';de = 'Die Daten werden heruntergeladen aus %1'");
		
	Else
		DescriptionTemplate = NStr("ru = 'Выполняется выгрузка данных в %1'; en = 'Exporting data to %1'; pl = 'Jest wykonywane przesyłanie danych do %1';es_ES = 'Se están subiendo los datos a %1';es_CO = 'Se están subiendo los datos a %1';tr = 'Veriler %1''e aktarılıyor';it = 'Esportazione dati a %1';de = 'Die Daten werden hochgeladen zu %1'");
	EndIf;
	
	JobDescription = StringFunctionsClientServer.SubstituteParametersToString(
		DescriptionTemplate, JobParameters.InfobaseNode);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobDescription;
	
	OperationStartDate = CurrentSessionDate();
	JobParameters.Insert("OperationStartDate", OperationStartDate);
	
	// Run the background job
	Result = TimeConsumingOperations.ExecuteInBackground(
		JobParameters.JobName,
		JobParameters,
		ExecutionParameters);
		
	BackgroundJobID  = Result.JobID;
	BackgroundJobStorageAddress = Result.ResultAddress;
	
	Return Result;
	
EndFunction

&AtServer
Procedure BackgroundJobGetResultAtServer()
	
	If BackgroundJobExecutionResult = Undefined Then
		BackgroundJobExecutionResult = New Structure;
		BackgroundJobExecutionResult.Insert("Status", Undefined);
	EndIf;
	
	BackgroundJobExecutionResult.Insert("AdditionalResultData", New Structure());
	
	ErrorMessage = "";
	
	StandardErrorPresentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Не удалось выполнить %1. Подробности см. в журнале регистрации'; en = 'Cannot complete %1. For more information, see the Event log'; pl = 'Nie udało się wykonać %1. Szczegóły zobacz w dzienniku rejestracji';es_ES = 'No se ha podido realizar %1. Véase más en el registro';es_CO = 'No se ha podido realizar %1. Véase más en el registro';tr = '""%1"" çalıştırılamadı. Ayrıntılar için olay günlüğüne bakın.';it = 'Impossibile completare %1. Per ulteriori informazioni consultare il Registro eventi';de = 'Der Vorgang konnte nicht abgeschlossen werden %1. Weitere Informationen finden Sie im Ereignisprotokoll'"),
		?(BackgroundJobCurrentAction = 1, NStr("ru = 'получение данных'; en = 'getting data'; pl = 'pobieranie danych';es_ES = 'recepción de datos';es_CO = 'recepción de datos';tr = 'veri alınıyor';it = 'ricevimento dati';de = 'Daten empfangen'"), NStr("ru = 'отправку данных'; en = 'data sending'; pl = 'wysyłanie danych';es_ES = 'envío de datos';es_CO = 'envío de datos';tr = 'veriyi gönder';it = 'invio dati';de = 'Daten senden'")));
	
	If BackgroundJobExecutionResult.Status = "Error" Then
		ErrorMessage = BackgroundJobExecutionResult.DetailedErrorPresentation;
	Else
		
		BackgroundExecutionResult = GetFromTempStorage(BackgroundJobStorageAddress);
		
		If BackgroundExecutionResult = Undefined Then
			ErrorMessage = StandardErrorPresentation;
		Else
			
			If BackgroundExecutionResult.ExecuteImport Then
				
				// Data on exchange rule version difference.
				VersionMismatchErrorOnGetData = DataExchangeServer.VersionMismatchErrorOnGetData();
				
				If VersionMismatchErrorOnGetData <> Undefined
					AND VersionMismatchErrorOnGetData.HasError = True Then
					ErrorMessage = VersionMismatchErrorOnGetData.ErrorText;
				EndIf;
				
				// Checking the transition to a new data exchange.
				CheckWhetherTransferToNewExchangeIsRequired();
				
				If BackgroundJobExecutionResult.AdditionalResultData.Property("FormReopeningParameters") Then
					Return;
				EndIf;
				
			EndIf;
			
			If BackgroundExecutionResult.Cancel AND Not ValueIsFilled(ErrorMessage) Then
				ErrorMessage = StandardErrorPresentation;
			EndIf;
			
			FillPropertyValues(
				ThisObject,
				BackgroundExecutionResult,
				"TimeConsumingOperation, TimeConsumingOperationID, MessageFileIDInService");
			
			DeleteFromTempStorage(BackgroundJobStorageAddress);
			
		EndIf;
		
		BackgroundJobStorageAddress = Undefined;
		BackgroundJobID  = Undefined;
		
	EndIf;
	
	// Check for possible errors when performing a background job.
	HasErrors = ValueIsFilled(ErrorMessage);
	
	// If errors occurred during data synchronization, record them.
	If HasErrors Then
		
		// If a time-consuming operation was started in the correspondent base, it must be completed.
		If Not TimeConsumingOperationCompleted Then
			EndExecutingTimeConsumingOperation(TimeConsumingOperationID);
		EndIf;
		
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// FILLING WIZARD NAVIGATION TABLE SECTION

&AtServer
Procedure FillGoToTable()
	
	NavigationTable.Clear();
	
	// Initializing the current exchange scenario.
	If HasErrors Then
		
		GoToTableNewRow("ExchangeCompletion", "ExchangeCompletion_OnOpen");
		
	Else
		
		If BackgroundJobUseProgress Then
			PageNameSynchronizationImport = "DataSynchronizationWaitProgressBarImport";
			PageNameSynchronizationExport = "DataSynchronizationWaitProgressBarExport";
		Else
			PageNameSynchronizationImport = "DataSynchronizationWait";
			PageNameSynchronizationExport = "DataSynchronizationWait";
		EndIf;
		
		If ExchangeBetweenSaaSApplications Then
			// Getting and sending.
			GoToTableNewRow(PageNameSynchronizationExport, "DataExport_OnOpen", True, "DataExport_TimeConsumingOperationProcessing");
			GoToTableNewRow(PageNameSynchronizationExport, , True, "DataExport_TimeConsumingOperationProcessing_Completion");
		Else
			
			If ActivePasswordPromptPage Then
				NavigationString = GoToTableNewRow("UserPasswordRequest", "UserPasswordRequest_OnOpen");
				NavigationString.GoNextHandlerName = "UserPasswordRequest_OnGoNext";
			EndIf;
			
			If MessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
				GoToTableNewRow("DataSynchronizationWait", , True, "ConnectionTestWaiting_TimeConsumingOperationProcessing");
			EndIf;
			
			If ExecuteDataSending Then
				// Sending
				GoToTableNewRow(PageNameSynchronizationExport, "DataExport_OnOpen", True, "DataExport_TimeConsumingOperationProcessing");
				GoToTableNewRow(PageNameSynchronizationExport, , True, "DataExport_TimeConsumingOperationProcessing_End");
			EndIf;
			
			// Receipt
			GoToTableNewRow(PageNameSynchronizationImport, "DataImport_OnOpen", True, "DataImport_TimeConsumingOperationProcessing");
			GoToTableNewRow(PageNameSynchronizationImport, , True, "DataImport_TimeConsumingOperationProcessing_End");
			// Sending
			GoToTableNewRow(PageNameSynchronizationExport, "DataExport_OnOpen", True, "DataExport_TimeConsumingOperationProcessing");
			GoToTableNewRow(PageNameSynchronizationExport, , True, "DataExport_TimeConsumingOperationProcessing_End");
			
		EndIf;
		
		// Completing
		GoToTableNewRow("ExchangeCompletion", "ExchangeCompletion_OnOpen", True, "ExchangeCompletion_TimeConsumingOperationProcessing");
		
	EndIf;
	
EndProcedure

#EndRegion