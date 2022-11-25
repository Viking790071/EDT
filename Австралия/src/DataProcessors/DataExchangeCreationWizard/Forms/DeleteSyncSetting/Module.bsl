#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	InitializeFormAttributes();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("ru = 'Отказаться от удаления настройки синхронизации данных?'; en = 'Refuse to remove data synchronization setting?'; pl = 'Zrezygnować z usuwania danych synchronizacji danych?';es_ES = '¿Renunciar la eliminación del ajuste de sincronización de datos?';es_CO = '¿Renunciar la eliminación del ajuste de sincronización de datos?';tr = 'Veri eşleşmesi ayarını silmekten vazgeç?';it = 'Rifiutare la rimozione dell''impostazione di sincronizzazione dati?';de = 'Einstellungen für die Datensynchronisation nicht löschen?'");
	CommonClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
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
	Close();
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

#Region DeleteSyncSetting

&AtClient
Procedure OnStartDeleteSynchronizationSettings()
	
	ContinueWait = True;
	
	OnStartDeleteOfSynchronizationSettingsAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			IdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForDeleteSynchronizationSettings",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteSynchronizationSettingsDeletion();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForDeleteSynchronizationSettings()
	
	ContinueWait = False;
	OnWaitSynchronizationSetupAtServer(IsExchangeWithApplicationInService,
		HandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForDeleteSynchronizationSettings",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		IdleHandlerParameters = Undefined;
		OnCompleteSynchronizationSettingsDeletion();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteSynchronizationSettingsDeletion()
	
	ErrorMessage = "";
	
	SettingDeleted = True;
	SettingDeletedInCorrespondent = True;
	
	OnCompleteDeleteOfSynchronizationSettingsAtServer(SettingDeleted,
		SettingDeletedInCorrespondent, ErrorMessage);
	
	If SettingDeleted Then
		ChangeGoToNumber(+1);
		
		If DeleteSettingItemInCorrespondent
			AND SettingDeletedInCorrespondent Then
			Items.SyncDeletedLabelDecoration.Title = NStr("ru = 'Настройки синхронизации данных в этой программе
			|и программе-корреспонденте успешно удалены.'; 
			|en = 'Data synchronization settings in this application
			|and the correspondent application are successfully deleted.'; 
			|pl = 'Ustawienia synchronizacji danych w tym programie
			|i programie-korespondencie zostały pomyślnie usunięte.';
			|es_ES = 'Los ajustes de sincronización de datos en este programa
			|y en el programa-correspondiente se han eliminado con éxito.';
			|es_CO = 'Los ajustes de sincronización de datos en este programa
			|y en el programa-correspondiente se han eliminado con éxito.';
			|tr = 'Bu programdaki 
			| ve muhabir programdaki veri eşleşme ayarları başarı ile kaldırıldı.';
			|it = 'Le impostazioni di sincronizzazione dati in questa applicazione
			|e nell''applicazione corrispondente sono state rimosse con successo.';
			|de = 'Die Datensynchronisationseinstellungen in diesem Programm
			|und dem korrespondierenden Programm wurden erfolgreich gelöscht.'");
		EndIf;
		
	Else
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не удалось удалить настройку синхронизации данных.'; en = 'Cannot remove data synchronization setting.'; pl = 'Nie udało się usunąć ustawienia synchronizacji danych.';es_ES = 'No se ha podido eliminar el ajuste de sincronización de datos.';es_CO = 'No se ha podido eliminar el ajuste de sincronización de datos.';tr = 'Veri senkronizasyon ayarları kaldırılamıyor.';it = 'Impossibile rimuovere le impostazioni di sincronizzazione dati.';de = 'Die Einstellung für die Datensynchronisation konnte nicht gelöscht werden.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartDeleteOfSynchronizationSettingsAtServer(ContinueWait)
	
	DeletionSettings = New Structure;
	
	If IsExchangeWithApplicationInService Then
		
		DeletionSettings.Insert("ExchangePlanName", ExchangePlanName);
		DeletionSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
		
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
		
	Else
		
		DeletionSettings.Insert("ExchangeNode", ExchangeNode);
		DeletionSettings.Insert("DeleteSettingItemInCorrespondent", DeleteSettingItemInCorrespondent);
		
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
		
	EndIf;
	
	If ModuleSetupDeletionWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupDeletionWizard.OnStartDeleteSynchronizationSettings(DeletionSettings,
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitSynchronizationSetupAtServer(IsExchangeWithApplicationInService, HandlerParameters, ContinueWait)
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupDeletionWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ContinueWait = False;
	ModuleSetupDeletionWizard.OnWaitForDeleteSynchronizationSettings(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteDeleteOfSynchronizationSettingsAtServer(SettingDeleted, SettingDeletedInCorrespondent, ErrorMessage)
	
	If IsExchangeWithApplicationInService Then
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	Else
		ModuleSetupDeletionWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	EndIf;
	
	If ModuleSetupDeletionWizard = Undefined Then
		SettingDeleted = False;
		SettingDeletedInCorrespondent = False;
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	
	ModuleSetupDeletionWizard.OnCompleteDeleteSynchronizationSettings(
		HandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		SettingDeleted = False;
		
		ErrorMessage = CompletionStatus.ErrorMessage;
		Return;
	Else
		SettingDeleted = CompletionStatus.Result.SettingDeleted;
		SettingDeletedInCorrespondent = CompletionStatus.Result.SettingDeletedInCorrespondent;
		
		ErrorMessage = CompletionStatus.ErrorMessage;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormInitializationOnCreate

&AtServer
Procedure InitializeFormAttributes()
	
	ExchangeNode = Parameters.ExchangeNode;
	
	Parameters.Property("ExchangePlanName", ExchangePlanName);
	If Not ValueIsFilled(ExchangePlanName) Then
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
	EndIf;
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
		
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	Parameters.Property("CorrespondentDescription",   CorrespondentDescription);
	Parameters.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
	
	If Not ValueIsFilled(CorrespondentDescription) Then
		CorrespondentDescription = Common.ObjectAttributeValue(ExchangeNode, "Description");
	EndIf;
	
	TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ExchangeNode);
	OnlineConnection = (TransportKind = Enums.ExchangeMessagesTransportTypes.COM
		Or TransportKind = Enums.ExchangeMessagesTransportTypes.WS);
		
	DeleteSettingItemInCorrespondent = OnlineConnection;
	
	GetCorrespondentParameters = SaaSModel
		AND Not Parameters.Property("IsExchangeWithApplicationInService")
		AND Not TransportKind = Enums.ExchangeMessagesTransportTypes.WS
		AND Not TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode;
	
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
	
	If GetCorrespondentParameters Then
		NewMove = AddNavigationTableRow("GetCorrespondentParametersPage", "NavigationWaitPage");
		NewMove.TimeConsumingOperation = True;
		NewMove.TimeConsumingOperationHandlerName = "GetCorrespondentParametersPage_TimeConsumingOperation";
	EndIf;
	
	NewMove = AddNavigationTableRow("StartPage", "NavigationStartPage");
	NewMove.OnOpenHandlerName = "PageStart_OnOpen";
	
	NewMove = AddNavigationTableRow("WaitPage", "NavigationWaitPage");
	NewMove.OnOpenHandlerName = "WaitPage_OnOpen";
	NewMove.TimeConsumingOperation = True;
	NewMove.TimeConsumingOperationHandlerName = "WaitPage_TimeConsumingOperation";
	
	NewMove = AddNavigationTableRow("EndPage", "NavigationEndPage");
	NewMove.OnOpenHandlerName = "EndPage_OnOpen";
	
EndProcedure

#EndRegion

#Region MoveChangeHandlers

&AtClient
Function Attachable_GetCorrespondentParametersPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartGetApplicationList();
	
EndFunction

&AtClient
Function Attachable_PageStart_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Items.StartSubGroup.Visible = OnlineConnection;
	
EndFunction

&AtClient
Function Attachable_WaitPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	ClosingNotification = New NotifyDescription("AfterPermissionDeletion", ThisObject, ExchangeNode);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = DataExchangeServerCall.RequestToClearPermissionsToUseExternalResources(ExchangeNode);
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, Undefined, ClosingNotification);
	Else
		ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
	EndIf;
	
EndFunction

&AtClient
Function Attachable_WaitPage_TimeConsumingOperation(Cancel, GoToNext)
	
	GoToNext = False;
	
EndFunction

&AtClient
Function Attachable_EndPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	Notify("Write_ExchangePlanNode");
	CloseForms("NodeForm");
	
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

&AtClient
Procedure OnStartGetApplicationList()
	
	HandlerParameters = Undefined;
	ContinueWait = False;
	
	OnStartGettingApplicationsListAtServer(HandlerParameters, ContinueWait);
		
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForGetApplicationList",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteGetApplicationList();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForGetApplicationList()
	
	ContinueWait = False;
	OnWaitGettingApplicationsListAtServer(HandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForGetApplicationList",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		IdleHandlerParameters = Undefined;
		OnCompleteGetApplicationList();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteGetApplicationList()
	
	GoToNext = True;
	OnCompleteGettingApplicationsListAtServer(GoToNext);
	
	If GoToNext Then
		ChangeGoToNumber(+1);
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure OnStartGettingApplicationsListAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	WizardParameters = New Structure("Mode", "ConfiguredExchanges");
	
	ModuleSetupWizard.OnStartGetApplicationList(WizardParameters,
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnWaitGettingApplicationsListAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ModuleSetupWizard.OnWaitForGetApplicationList(
		HandlerParameters, ContinueWait);
	
EndProcedure

&AtServer
Procedure OnCompleteGettingApplicationsListAtServer(GoToNext)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If ModuleSetupWizard = Undefined Then
		Return;
	EndIf;
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteGetApplicationList(HandlerParameters, CompletionStatus);
		
	If Not CompletionStatus.Cancel Then
		ApplicationsTable = CompletionStatus.Result;
		ApplicationRow = ApplicationsTable.Find(ExchangeNode, "Correspondent");
		If Not ApplicationRow = Undefined Then
			IsExchangeWithApplicationInService = True;
			CorrespondentDataArea  = ApplicationRow.DataArea;
			CorrespondentDescription   = ApplicationRow.ApplicationDescription;
		EndIf;
	Else
		CommonClientServer.MessageToUser(CompletionStatus.ErrorMessage);
		GoToNext = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterPermissionDeletion(Result, InfobaseNode) Export
	
	If Result = DialogReturnCode.OK Then
		OnStartDeleteSynchronizationSettings();
	Else
		ChangeGoToNumber(-1);
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseForms(Val FormName)
	
	ApplicationWindows = GetWindows();
	
	If ApplicationWindows = Undefined Then
		Return;
	EndIf;
		
	For Each ApplicationWindow In ApplicationWindows Do
		If ApplicationWindow.IsMain Then
			Continue;
		EndIf;
			
		Form = ApplicationWindow.GetContent();
		
		If TypeOf(Form) = Type("ClientApplicationForm")
			AND Not Form.Modified
			AND StrFind(Form.FormName, FormName) <> 0 Then
			
			Form.Close();
			
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion