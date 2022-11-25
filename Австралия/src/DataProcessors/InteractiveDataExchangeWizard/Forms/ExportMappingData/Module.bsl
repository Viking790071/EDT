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
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If InitialExport Then
		WarningText = NStr("ru = 'Отменить начальную выгрузку данных?'; en = 'Cancel initial data export?'; pl = 'Anulować początkowe ładowanie danych?';es_ES = '¿Cancelar la subida inicial de datos?';es_CO = '¿Cancelar la subida inicial de datos?';tr = 'Verilerin ilk dışa aktarımı iptal edilsin mi?';it = 'Eliminare l''esportazione dati iniziale?';de = 'Erstmaliges Hochladen der Daten abbrechen?'");
	Else
		WarningText = NStr("ru = 'Отменить выгрузку данных?'; en = 'Cancel data export?'; pl = 'Anulować ładowanie danych?';es_ES = '¿Cancelar la subida de datos?';es_CO = '¿Cancelar la subida de datos?';tr = 'Verilerin dışa aktarımı iptal edilsin mi?';it = 'Eliminare esportazione dati?';de = 'Den Daten-Upload abbrechen?'");
	EndIf;
	
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		Notify("DataExchangeCompleted");
	EndIf;
	
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
	
	CloseParameter = Undefined;
	If DataExportCompleted Then
		CloseParameter = ExchangeNode;
	EndIf;
	
	ForceCloseForm = True;
	Close(CloseParameter);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

#Region ConnectionParametersCheck

&AtClient
Procedure OnStartTestConnection()
	
	ContinueWait = True;
	
	OnStartCheckConnectionAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ConnectionCheckIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForTestConnection",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteConnectionTest();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForTestConnection()
	
	ContinueWait = False;
	OnWaitConnectionCheckAtServer(ConnectionCheckHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ConnectionCheckIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForTestConnection",
			ConnectionCheckIdleHandlerParameters.CurrentInterval, True);
	Else
		ConnectionCheckIdleHandlerParameters = Undefined;
		OnCompleteConnectionTest();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteConnectionTest()
	
	OnCompleteConnectionCheckAtServer();
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtServer
Procedure OnStartCheckConnectionAtServer(ContinueWait)
	
	If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
		AND PromptForPassword Then
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode, WSPassword);
	Else
		ConnectionSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettings(ExchangeNode, TransportKind);
	EndIf;
	ConnectionSettings.Insert("ExchangeMessagesTransportKind", TransportKind);
	
	ConnectionSettings.Insert("ExchangePlanName", DataExchangeCached.GetExchangePlanName(ExchangeNode));
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ModuleSetupWizard.OnStartTestConnection(
		ConnectionSettings, ConnectionCheckHandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitConnectionCheckAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForTestConnection(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteConnectionCheckAtServer()
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteTestConnection(
		ConnectionCheckHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ConnectionCheckCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		ConnectionCheckCompleted = CompletionStatus.Result.ConnectionIsSet
			AND CompletionStatus.Result.ConnectionAllowed;
			
		If Not ConnectionCheckCompleted
			AND Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ChangeRegistration

&AtClient
Procedure OnStartChangesRegistration()
	
	ContinueWait = True;
	OnStartChangesRegistrationAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			DataRegistrationIdleHandlerParametersForInitialExport);
			
		AttachIdleHandler("OnWaitForChangeRegistration",
			DataRegistrationIdleHandlerParametersForInitialExport.CurrentInterval, True);
	Else
		OnCompleteChangeRegistration();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForChangeRegistration()
	
	ContinueWait = False;
	OnWaitForChangeRegistrationAtServer(DataRegistrationHandlerParametersForInitialExport, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(DataRegistrationIdleHandlerParametersForInitialExport);
		
		AttachIdleHandler("OnWaitForChangeRegistration",
			DataRegistrationIdleHandlerParametersForInitialExport.CurrentInterval, True);
	Else
		DataRegistrationIdleHandlerParametersForInitialExport = Undefined;
		OnCompleteChangeRegistration();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteChangeRegistration()
	
	OnCompleteChangeRegistrationAtServer();
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtServer
Procedure OnStartChangesRegistrationAtServer(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	RegistrationSettings = New Structure;
	RegistrationSettings.Insert("ExchangeNode", ExchangeNode);
	
	ModuleSetupWizard.OnStartRecordDataForInitialExport(
		RegistrationSettings, DataRegistrationHandlerParametersForInitialExport, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitForChangeRegistrationAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForRecordDataForInitialExport(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteChangeRegistrationAtServer()
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteDataRecordingForInitialExport(
		DataRegistrationHandlerParametersForInitialExport, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		ChangesRegistrationCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		ChangesRegistrationCompleted = CompletionStatus.Result.DataRegistered;
			
		If Not ChangesRegistrationCompleted
			AND Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region DataExport

&AtClient
Procedure OnStartExportDataForMapping()
	
	ProgressPercent = 0;
	
	ContinueWait = True;
	OnStartDataExportToMapAtServer(ContinueWait);
	
	If ContinueWait Then
		
		If IsExchangeWithApplicationInService Then
			TimeConsumingOperationsClient.InitIdleHandlerParameters(
				MappingDataExportIdleHandlerParameters);
				
			AttachIdleHandler("OnWaitForExportDataForMapping",
				MappingDataExportIdleHandlerParameters.CurrentInterval, True);
		Else
			CompletionNotification = New NotifyDescription("DataExportForMappingCompletion", ThisObject);
		
			IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
			IdleParameters.OutputIdleWindow = False;
			IdleParameters.OutputProgressBar = UseProgress;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("DataExportForMappingProgress", ThisObject);
			
			TimeConsumingOperationsClient.WaitForCompletion(MappingDataExportHandlerParameters.BackgroundJob,
				CompletionNotification, IdleParameters);
		EndIf;
			
	Else
			
		OnCompleteDataExportForMapping();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForExportDataForMapping()
	
	ContinueWait = False;
	OnWaitDataExportToMapAtServer(MappingDataExportHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(MappingDataExportIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForExportDataForMapping",
			MappingDataExportIdleHandlerParameters.CurrentInterval, True);
	Else
		MappingDataExportIdleHandlerParameters = Undefined;
		OnCompleteDataExportForMapping();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataExportForMapping()
	
	ProgressPercent = 100;
	
	OnCompleteDataExportForMappingAtServer();
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure DataExportForMappingCompletion(Result, AdditionalParameters) Export
	
	OnCompleteDataExportForMapping();
	
EndProcedure

&AtClient
Procedure DataExportForMappingProgress(Progress, AdditionalParameters) Export
	
	If Progress = Undefined Then
		Return;
	EndIf;
	
	ProgressStructure = Progress.Progress;
	If ProgressStructure <> Undefined Then
		ProgressPercent = ProgressStructure.Percent;
		ProgressAdditionalInformation = ProgressStructure.Text;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartDataExportToMapAtServer(ContinueWait)
	
	ExportSettings = New Structure;
	
	If IsExchangeWithApplicationInService Then
		ExportSettings.Insert("Correspondent", ExchangeNode);
		ExportSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	Else
		ExportSettings.Insert("ExchangeNode", ExchangeNode);
		ExportSettings.Insert("TransportKind", TransportKind);
		
		If TransportKind = Enums.ExchangeMessagesTransportTypes.WS
			AND PromptForPassword Then
			ExportSettings.Insert("WSPassword", WSPassword);
		EndIf;
		
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	EndIf;
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnStartExportDataForMapping(
		ExportSettings, MappingDataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitDataExportToMapAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleInteractiveExchangeWizard.OnWaitForExportDataForMapping(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteDataExportForMappingAtServer()
	
	If IsExchangeWithApplicationInService Then
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	Else
		ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	EndIf;
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		DataExportCompleted = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard.OnCompleteExportDataForMapping(
		MappingDataExportHandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		DataExportCompleted = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		DataExportCompleted = CompletionStatus.Result.DataExported;
			
		If Not DataExportCompleted
			AND Not IsBlankString(CompletionStatus.Result.ErrorMessage) Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormInitializationOnCreate

&AtServer
Procedure CheckCanUseForm(Cancel = False)
	
	// It is required to pass the parameters of data export execution.
	If Not Parameters.Property("ExchangeNode") Then
		MessageText = NStr("ru = 'Форма не предназначена для непосредственного использования.'; en = 'Form is not intended for direct usage.'; pl = 'Formularz nie jest przeznaczony dla bezpośredniego użycia.';es_ES = 'El formulario no está destinado para el uso directo.';es_CO = 'El formulario no está destinado para el uso directo.';tr = 'Form doğrudan kullanım için uygun değildir.';it = 'Il modulo non è inteso per un utilizzo diretto.';de = 'Das Formular ist nicht für den direkten Gebrauch bestimmt.'");
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
	If DataExchangeCached.IsDistributedInfobaseNode(Parameters.ExchangeNode) Then
		MessageText = NStr("ru = 'Начальная выгрузка не поддерживается для узлов распределенных информационных баз.'; en = 'Initial export is not supported for distributed infobase nodes.'; pl = 'Początkowe ładowanie nie jest obsługiwane dla węzłów rozprowadzonych baz informacyjnych.';es_ES = 'La subida inicial no se admite para los nodos de las bases de información distribuidas.';es_CO = 'La subida inicial no se admite para los nodos de las bases de información distribuidas.';tr = 'Dağıtılmış veritabanların üniteleri için ilk dışa aktarma desteklenmiyor.';it = 'L''esportazione iniziale non è supportata per i nodi di infobase distribuito.';de = 'Der anfängliche Upload wird für Knoten verteilter Informationsdatenbanken nicht unterstützt.'");
		CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		Return;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	ExchangeNode = Parameters.ExchangeNode;
	
	If Parameters.Property("InitialExport") Then
		DataExportMode = "InitialExport";
		InitialExport = True;
	Else
		DataExportMode = "StandardExport";
	EndIf;
	
	ApplicationDescription = Common.ObjectAttributeValue(ExchangeNode, "Description");
	
	Parameters.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	UseProgress = Not IsExchangeWithApplicationInService;
		
	TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ExchangeNode);
	
	If TransportKind = Enums.ExchangeMessagesTransportTypes.WS Then
		
		UseProgress = False;
		
		TransportSettings = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode);
		
		PromptForPassword = Not (TransportSettings.WSRememberPassword
			Or DataExchangeServer.DataSynchronizationPasswordSpecified(ExchangeNode));
		
	EndIf;
		
	FillGoToTable();
	
	SetApplicationDescriptionInFormLabels();
	
EndProcedure

&AtServer
Procedure SetApplicationDescriptionInFormLabels()
	
	Items.PasswordLabelDecoration.Title = StrReplace(Items.PasswordLabelDecoration.Title,
		"%ApplicationDescription%", ApplicationDescription);
	
	Items.DataExportNoProgressBarLabelDecoration.Title = StrReplace(Items.DataExportNoProgressBarLabelDecoration.Title,
		"%ApplicationDescription%", ApplicationDescription);
	
	Items.DataExportProgressLabelDecoration.Title = StrReplace(Items.DataExportProgressLabelDecoration.Title,
		"%ApplicationDescription%", ApplicationDescription);
	
	Items.ExportCompletedLabelDecoration.Title = StrReplace(Items.ExportCompletedLabelDecoration.Title,
		"%ApplicationDescription%", ApplicationDescription);
	
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
	
	NewMove = AddNavigationTableRow("StartPage", "NavigationStartPage");
	NewMove.OnOpenHandlerName = "StartPage_OnOpen";
	
	If PromptForPassword Then
		NewMove = AddNavigationTableRow("PasswordRequestPage", "PageNavigationFollowUp");
		NewMove.GoNextHandlerName = "PasswordRequestPage_OnGoNext";
	EndIf;
	
	NewMove = AddNavigationTableRow("ConnectionTestPage", "NavigationWaitPage");
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "ConnectionTestPage_TimeConsumingOperation";
	
	NewMove = AddNavigationTableRow("ChangeRecordingPage", "NavigationWaitPage");
	NewMove.OnOpenHandlerName = "ChangeRegistrationPage_OnOpen";
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "ChangeRegistrationPage_TimeConsumingOperation";
	
	If UseProgress Then
		NewMove = AddNavigationTableRow("ExportDataProgressPage", "NavigationWaitPage");
	Else
		NewMove = AddNavigationTableRow("ExportDataWithoutProgressPage", "NavigationWaitPage");
	EndIf;
	NewMove.OnOpenHandlerName = "DataExportPage_OnOpen";
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "DataExportPage_TimeConsumingOperation";
	
	NewMove = AddNavigationTableRow("EndPage", "NavigationEndPage");
	NewMove.OnOpenHandlerName = "EndPage_OnOpen";
	
EndProcedure

#EndRegion

#Region MoveChangeHandlers

&AtClient
Function Attachable_StartPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.DataExportMode.Enabled = Not InitialExport;
	
EndFunction

&AtClient
Function Attachable_PasswordRequestPage_OnGoNext(Cancel)
	
	If Not PromptForPassword Then
		Return 0;
	EndIf;
	
	If IsBlankString(WSPassword) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Укажите пароль.'; en = 'Specify password.'; pl = 'Podaj hasło.';es_ES = 'Indique la contraseña.';es_CO = 'Indique la contraseña.';tr = 'Şifreyi belirtin.';it = 'Specificare password.';de = 'Geben Sie Ihr Passwort ein.'"), , "WSPassword", , Cancel);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionTestPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartTestConnection();
	
EndFunction

&AtClient
Function Attachable_ChangeRegistrationPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If Not ConnectionCheckCompleted Then
		SkipPage = True;
		Return 0;
	Else
		If DataExportMode = "StandardExport" Then
			SkipPage = True;
			ChangesRegistrationCompleted = True;
		EndIf;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ChangeRegistrationPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartChangesRegistration();
	
EndFunction

&AtClient
Function Attachable_DataExportPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	SkipPage = Not ConnectionCheckCompleted
		Or Not ChangesRegistrationCompleted;
	
EndFunction

&AtClient
Function Attachable_DataExportPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartExportDataForMapping();
	
EndFunction

&AtClient
Function Attachable_EndPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If Not ConnectionCheckCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.CompletionPageConnectionCheckError;
	ElsIf Not ChangesRegistrationCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.ChangesRegistrationErrorPage;
	ElsIf Not DataExportCompleted Then
		Items.CompletionStatusPanel.CurrentPage = Items.DataExportErrorPage;
	Else
		Items.CompletionStatusPanel.CurrentPage = Items.SuccessfulCompletionPage;
	EndIf;
	
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
