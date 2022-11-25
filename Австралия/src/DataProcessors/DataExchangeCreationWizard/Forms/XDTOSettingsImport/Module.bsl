
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ExchangeNode = Parameters.ExchangeNode;
	
	CorrespondentDescription = Common.ObjectAttributeValue(ExchangeNode, "Description");
	
	Items.WaitLabelDecoration.Title = StrReplace(Items.WaitLabelDecoration.Title,
		"%CorrespondentDescription%", CorrespondentDescription);
	Items.ErrorLabelDecoration.Title = StrReplace(Items.ErrorLabelDecoration.Title,
		"%CorrespondentDescription%", CorrespondentDescription);
	
	Title = NStr("ru = 'Загрузка параметров обмена данными'; en = 'Import data exchange parameters'; pl = 'Pobieranie parametrów wymiany danych';es_ES = 'Carga de parámetros de intercambio de datos';es_CO = 'Carga de parámetros de intercambio de datos';tr = 'Veri alışverişi parametrelerin içe aktarılması';it = 'Importare parametri di scambio dati';de = 'Laden von Datenaustauschoptionen'");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	Items.MainPanel.CurrentPage = Items.TimeConsumingOperationPage;
	Items.DoneCommandForm.DefaultButton = False;
	Items.DoneCommandForm.Enabled = False;
	
	AttachIdleHandler("OnStartImportXDTOSettings", 1, True);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DoneCommand(Command)
	
	Result = New Structure;
	Result.Insert("ContinueSetup",            False);
	Result.Insert("DataReceivedForMapping", False);
	
	Close(Result);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnStartImportXDTOSettings()
	
	ContinueWait = True;
	OnStartImportXDTOSettingsAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			IdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForImportXDTOSettings",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		OnCompleteXDTOSettingsImport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForImportXDTOSettings()
	
	ContinueWait = False;
	OnWaitImportXDTOSettingsAtServer(HandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForImportXDTOSettings",
			IdleHandlerParameters.CurrentInterval, True);
	Else
		IdleHandlerParameters = Undefined;
		OnCompleteXDTOSettingsImport();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteXDTOSettingsImport()
	
	ErrorMessage = "";
	SettingsImported = False;
	DataReceivedForMapping = False;
	OnCompleteImportXDTOSettingsAtServer(HandlerParameters, SettingsImported, DataReceivedForMapping, ErrorMessage);
	
	If SettingsImported Then
		
		Result = New Structure;
		Result.Insert("ContinueSetup",            True);
		Result.Insert("DataReceivedForMapping", DataReceivedForMapping);
		
		Close(Result);
	Else
		Items.MainPanel.CurrentPage = Items.ErrorPage;
		Items.DoneCommandForm.DefaultButton = True;
		Items.DoneCommandForm.Enabled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartImportXDTOSettingsAtServer(ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ImportSettings = New Structure;
	ImportSettings.Insert("ExchangeNode", ExchangeNode);
	
	ModuleSetupWizard.OnStartImportXDTOSettings(ImportSettings, HandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitImportXDTOSettingsAtServer(HandlerParameters, ContinueWait)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	ContinueWait = False;
	ModuleSetupWizard.OnWaitForImportXDTOSettings(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteImportXDTOSettingsAtServer(HandlerParameters, SettingsImported, DataReceivedForMapping, ErrorMessage)
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	CompletionStatus = Undefined;
	ModuleSetupWizard.OnCompleteImportXDTOSettings(HandlerParameters, CompletionStatus);
		
	If CompletionStatus.Cancel Then
		SettingsImported = False;
		DataReceivedForMapping = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		SettingsImported = CompletionStatus.Result.SettingsImported;
			
		If Not SettingsImported Then
			DataReceivedForMapping = False;
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		Else
			DataReceivedForMapping = CompletionStatus.Result.DataReceivedForMapping;
		EndIf;
	EndIf;
	
EndProcedure 

#EndRegion
