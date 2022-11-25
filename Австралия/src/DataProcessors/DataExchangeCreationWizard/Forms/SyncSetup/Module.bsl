
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	InitializeFormAttributes();
	
	InitializeFormProperties();
	
	SetInitialDisplayOfFormItems();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FillSetupStagesTable();
	UpdateCurrentSettingsStateDisplay();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(ExchangeNode)
		Or Not SynchronizationSetupCompleted(ExchangeNode)
		Or (DIBSetup AND Not ContinueSetupInSubordinateDIBNode AND Not InitialImageCreated(ExchangeNode))Then
		WarningText = NStr("ru = 'Настройка синхронизации данных еще не завершена.
		|Завершить работу с помощником? Настройку можно будет продолжить позже.'; 
		|en = 'Data synchronization is not set up yet.
		|Close the wizard? You can continue setup later.'; 
		|pl = 'Konfigurowanie synchronizacji danych nie zostało jeszcze zakończone.
		|Zakończyć pracę z asystentem? Konfigurację można będzie kontynuować później.';
		|es_ES = 'El ajuste de sincronización de datos no se ha terminado.
		|¿Finalizar el trabajo con ayudante? Se puede seguir ajustando después.';
		|es_CO = 'El ajuste de sincronización de datos no se ha terminado.
		|¿Finalizar el trabajo con ayudante? Se puede seguir ajustando después.';
		|tr = 'Veri senkronizasyonu ayarı henüz tamamlanmadı.
		|Sihirbazdan çıkmak istiyor musunuz? Ayarlara daha sonra devam edilebilir.';
		|it = 'La sincronizzazione dati non è ancora configurata.
		|Chiudere la guida? Puoi continuare la configurazione più tardi.';
		|de = 'Die Einrichtung der Datensynchronisation ist noch nicht abgeschlossen.
		|Den Assistenten abschalten? Die Konfiguration kann später fortgesetzt werden.'");
		CommonClient.ShowArbitraryFormClosingConfirmation(
			ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Not Exit Then
		Notify("DataExchangeCreationWizardFormClosed");
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BackupLabelDecorationURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	StandardProcessing = False;
	If Backup Then
		CommonClient.OpenURL(BackupDataProcessorURL);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DataSyncDetails(Command)
	
	DataExchangeClient.OpenSynchronizationDetails(ExchangeDetailedInformation);
	
EndProcedure

&AtClient
Procedure SetUpConnectionParameters(Command)
	
	If Not NewSYnchronizationSetting Then
		If SaaSModel Then
			WarnString = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Настройка подключения к ""%1"" уже выполнена.
				|Редактирование параметров подключения не предусмотрено.'; 
				|en = 'Connection to ""%1"" is set up.
				|You cannot edit the connection parameters.'; 
				|pl = 'Konfigurowanie połączenia do ""%1"" zostało już wykonane.
				|Edycja ustawień połączenia nie jest przewidziane.';
				|es_ES = 'El ajuste de conexión a ""%1"" se ha ejecutado ya.
				|No está previsto editar los parámetros de conexión.';
				|es_CO = 'El ajuste de conexión a ""%1"" se ha ejecutado ya.
				|No está previsto editar los parámetros de conexión.';
				|tr = '""%1"" ''e bağlantı ayarları zaten yapıldı. 
				| Bağlantı parametreleri düzenlenemez.';
				|it = 'La connessione a ""%1"" è configurata.
				|Non puoi modificare i parametri di connessione.';
				|de = 'Die Verbindung zum ""%1"" ist bereits hergestellt.
				|Die Verbindungsparameter können nicht bearbeitet werden.'"), ExchangeNode);
			ShowMessageBox(, WarnString);
			Return;
		Else
			Filter              = New Structure("Correspondent", ExchangeNode);
			FillingValues = New Structure("Correspondent", ExchangeNode);
			
			DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
				FillingValues, "DataExchangeTransportSettings", ThisObject);
		EndIf;
		Return;
	EndIf;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangePlanName",         ExchangePlanName);
	WizardParameters.Insert("SettingID", SettingID);
	If ContinueSetupInSubordinateDIBNode Then
		WizardParameters.Insert("ContinueSetupInSubordinateDIBNode");
	EndIf;
	
	ClosingNotification = New NotifyDescription("SetUpConnectionParametersCompletion", ThisObject);
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.ConnectionSetup",
		WizardParameters, ThisObject, , , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure ConfigureDataExportImportRules(Command)
	
	ContinuesNotification = New NotifyDescription("SetDataSendingAndReceivingRulesFollowUp", ThisObject);
	
	// Get the correspondent settings for the XDTO exchange plan before setting export and import rules.
	// 
	If XDTOSetup Then
		SetupStatus = SynchronizationSetupStatus(ExchangeNode);
		If Not SetupStatus.SynchronizationSetupCompleted
			AND Not SetupStatus.XDTOCorrespondentSettingsReceived Then
			
			ImportParameters = New Structure;
			ImportParameters.Insert("ExchangeNode", ExchangeNode);
			
			OpenForm("DataProcessor.DataExchangeCreationWizard.Form.XDTOSettingsImport",
				ImportParameters, ThisObject, , , , ContinuesNotification, FormWindowOpeningMode.LockOwnerWindow);
			Return;
		EndIf;
	EndIf;
	
	Result = New Structure;
	Result.Insert("ContinueSetup",            True);
	Result.Insert("DataReceivedForMapping", DataReceivedForMapping);
	
	ExecuteNotifyProcessing(ContinuesNotification, Result);
	
EndProcedure

&AtClient
Procedure CreateInitialDIBImage(Command)
	
	WizardParameters = New Structure("Key, Node", ExchangeNode, ExchangeNode);
			
	ClosingNotification = New NotifyDescription("CreateInitialDIBImageCompletion", ThisObject);
	OpenForm(InitialImageCreationFormName,
		WizardParameters, ThisObject, , , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure MapAndExportData(Command)
	
	ContinuesNotification = New NotifyDescription("MapAndExportDataFollowUp", ThisObject);
	
	WizardParameters = New Structure;
	WizardParameters.Insert("SendData",     False);
	WizardParameters.Insert("ScheduleSetup", False);
	
	If IsExchangeWithApplicationInService Then
		WizardParameters.Insert("CorrespondentDataArea", CorrespondentDataArea);
	EndIf;
	
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters",  WizardParameters);
	AuxiliaryParameters.Insert("ClosingNotification", ContinuesNotification);
	
	DataExchangeClient.OpenObjectsMappingWizardCommandProcessing(ExchangeNode,
		ThisObject, AuxiliaryParameters);
	
EndProcedure

&AtClient
Procedure ExecuteInitialDataExport(Command)
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangeNode", ExchangeNode);
	WizardParameters.Insert("InitialExport");
	
	If SaaSModel Then
		WizardParameters.Insert("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
		WizardParameters.Insert("CorrespondentDataArea",  CorrespondentDataArea);
	EndIf;
	
	ClosingNotification = New NotifyDescription("ExecuteInitialDataExportCompletion", ThisObject);
	OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form.ExportMappingData",
		WizardParameters, ThisObject, , , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SetUpSchedule(Command)
	
	DataExchangeExecutionSchedule = PredefinedScheduleEveryHour();
	
	Dialog = New ScheduledJobDialog(DataExchangeExecutionSchedule);
	NotifyDescription = New NotifyDescription("SetUpScheduleCompletion", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function SynchronizationSetupStatus(ExchangeNode)
	
	Result = New Structure;
	Result.Insert("SynchronizationSetupCompleted",           SynchronizationSetupCompleted(ExchangeNode));
	Result.Insert("InitialImageCreated",                      InitialImageCreated(ExchangeNode));
	Result.Insert("MessageWithDataForMappingReceived", DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode));
	Result.Insert("XDTOCorrespondentSettingsReceived",       XDTOCorrespondentSettingsReceived(ExchangeNode));
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function XDTOCorrespondentSettingsReceived(ExchangeNode)
	
	CorrespondentSettings = DataExchangeXDTOServer.SupportedCorrespondentFormatObjects(ExchangeNode, "SendReceive");
	
	Return CorrespondentSettings.Count() > 0;
	
EndFunction

&AtServerNoContext
Function InitialImageCreated(ExchangeNode)
	
	Return InformationRegisters.CommonInfobasesNodesSettings.InitialImageCreated(ExchangeNode);
	
EndFunction

&AtServerNoContext
Function PredefinedScheduleEveryHour()
	
	Return DataExchangeServer.ModuleDataExchangeCreationWizard().PredefinedScheduleEveryHour();
	
EndFunction

&AtServerNoContext
Procedure CreateDataExchangeScenarioSchedule(ExchangeNode, Schedule)
	
	Catalogs.DataExchangeScenarios.CreateScenario(ExchangeNode, Schedule);
	
EndProcedure

&AtClient
Procedure SetUpConnectionParametersCompletion(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined
		AND TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.Property("ExchangeNode") Then
			ExchangeNode = ClosingResult.ExchangeNode;
		EndIf;
		
		If SaaSModel Then
			ClosingResult.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
			ClosingResult.Property("CorrespondentDataArea",  CorrespondentDataArea);
		EndIf;
		
		If ClosingResult.Property("HasDataToMap")
			AND ClosingResult.HasDataToMap Then
			DataReceivedForMapping = True;
		EndIf;
		
		If ClosingResult.Property("PassiveMode")
			AND ClosingResult.PassiveMode Then
			InteractiveSendingAvailable = False;
		EndIf;
		
		FillSetupStagesTable();
		UpdateCurrentSettingsStateDisplay();
		
		If CurrentSetupStep = "ConnectionSetup" Then
			GoToNextSetupStage();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetDataSendingAndReceivingRulesFollowUp(ClosingResult, AdditionalParameters) Export
	
	If Not ClosingResult.ContinueSetup Then
		Return;
	EndIf;
	
	InteractiveSendingAvailable = InteractiveSendingAvailable
		AND Not (DataExchangeServerCall.DataExchangeOption(ExchangeNode) = "ReceiveOnly");
	
	If ClosingResult.DataReceivedForMapping
		AND Not DataReceivedForMapping Then
		DataReceivedForMapping = ClosingResult.DataReceivedForMapping;
	EndIf;
	
	FillSetupStagesTable();
	UpdateCurrentSettingsStateDisplay();
	
	WizardParameters = New Structure;
	
	If IsBlankString(DataSyncSettingsWizardFormName) Then
		WizardParameters.Insert("Key", ExchangeNode);
		WizardParameters.Insert("WizardFormName", "ExchangePlan.[ExchangePlanName].ObjectForm");
		
		WizardParameters.WizardFormName = StrReplace(WizardParameters.WizardFormName,
			"[ExchangePlanName]", ExchangePlanName);
	Else
		WizardParameters.Insert("ExchangeNode", ExchangeNode);
		WizardParameters.Insert("WizardFormName", DataSyncSettingsWizardFormName);
	EndIf;
	
	ClosingNotification = New NotifyDescription("SetDataSendingAndReceivingRulesCompletion", ThisObject);
	
	OpenForm(WizardParameters.WizardFormName,
		WizardParameters, ThisObject, , , , ClosingNotification, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
Procedure SetDataSendingAndReceivingRulesCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "RulesSetting"
		AND SynchronizationSetupCompleted(ExchangeNode) Then
		Notify("Write_ExchangePlanNode");
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure MapAndExportDataFollowUp(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "MapAndImport"
		AND DataImportCompleted(ExchangeNode) Then
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateInitialDIBImageCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "InitialDIBImage"
		AND InitialImageCreated(ExchangeNode) Then
		GoToNextSetupStage();
	EndIf;
	
	RefreshInterface();
	
EndProcedure

&AtClient
Procedure ExecuteInitialDataExportCompletion(ClosingResult, AdditionalParameters) Export
	
	If CurrentSetupStep = "InitialDataExport"
		AND ClosingResult = ExchangeNode Then
		GoToNextSetupStage();
	EndIf;
	
EndProcedure

&AtClient
Procedure SetUpScheduleCompletion(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		
		CreateDataExchangeScenarioSchedule(ExchangeNode, Schedule);
		
		If CurrentSetupStep = "ScheduleSetup" Then
			GoToNextSetupStage();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateCurrentSettingsStateDisplay()
	
	If IsBlankString(CurrentSetupStep) Then
		// All stages are completed.
		For Each SetupStage In SetupSteps Do
			Items[SetupStage.Name + "Group"].Enabled = True;
			Items[SetupStage.Button].Font = SetupStage.StandardFont;
			
			// Green flag is only for the main setting stages.
			If AllSetupSteps[SetupStage.Name] = "Main" Then
				Items[SetupStage.Name + "Panel"].CurrentPage = Items[SetupStage.Name + "SuccessfulPage"];
			Else
				Items[SetupStage.Name + "Panel"].CurrentPage = Items[SetupStage.Name + "PageEmpty"];
			EndIf;
		EndDo;
	Else
		
		CurrentStageFound = False;
		For Each SetupStage In SetupSteps Do
			If SetupStage.Name = CurrentSetupStep Then
				Items[SetupStage.Name + "Group"].Enabled = True;
				Items[SetupStage.Name + "Panel"].CurrentPage = Items[SetupStage.Name + "PageActive"];
				Items[SetupStage.Button].Font = SetupStage.BoldFont;
				CurrentStageFound = True;
			ElsIf Not CurrentStageFound Then
				Items[SetupStage.Name + "Group"].Enabled = True;
				Items[SetupStage.Name + "Panel"].CurrentPage = Items[SetupStage.Name + "SuccessfulPage"];
				Items[SetupStage.Button].Font = SetupStage.StandardFont;
			Else
				Items[SetupStage.Name + "Group"].Enabled = False;
				Items[SetupStage.Name + "Panel"].CurrentPage = Items[SetupStage.Name + "PageEmpty"];
				Items[SetupStage.Button].Font = SetupStage.StandardFont;
			EndIf;
		EndDo;
		
		For Each SetupStage In AllSetupSteps Do
			RowsStages = SetupSteps.FindRows(New Structure("Name", SetupStage.Key));
			If RowsStages.Count() = 0 Then
				Items[SetupStage.Key + "Group"].Enabled = False;
				Items[SetupStage.Key + "Panel"].CurrentPage = Items[SetupStage.Key + "PageEmpty"];
			EndIf;
		EndDo;
	EndIf;
			
EndProcedure

&AtClient
Procedure GoToNextSetupStage()
	
	NextRow = Undefined;
	CurrentStageFound = False;
	For Each SetupStagesString In SetupSteps Do
		If CurrentStageFound Then
			NextRow = SetupStagesString;
			Break;
		EndIf;
		
		If SetupStagesString.Name = CurrentSetupStep Then
			CurrentStageFound = True;
		EndIf;
	EndDo;
	
	If NextRow <> Undefined Then
		CurrentSetupStep = NextRow.Name;
		If AllSetupSteps[CurrentSetupStep] <> "Main" Then
			CurrentSetupStep = "";
		EndIf;
	Else
		CurrentSetupStep = "";
	EndIf;
	
	AttachIdleHandler("UpdateCurrentSettingsStateDisplay", 0.2, True);
	
EndProcedure

&AtServerNoContext
Function SynchronizationSetupCompleted(ExchangeNode)
	
	Return DataExchangeServer.SynchronizationSetupCompleted(ExchangeNode);
	
EndFunction

&AtServerNoContext
Function DataImportCompleted(ExchangeNode)
	
	Return Common.ObjectAttributeValue(ExchangeNode, "ReceivedNo") > 0;
	
EndFunction

#Region FormInitializationOnCreate

&AtServer
Procedure InitializeFormProperties()
	
	If IsBlankString(ExchangeCreateWizardTitle) Then
		If DIBSetup Then
			Title = NStr("ru = 'Настройка распределенной информационной базы'; en = 'Configure the distributed infobase'; pl = 'Konfiguracja przydzielonej bazy informacyjnej';es_ES = 'Ajuste de la base de información distribuida';es_CO = 'Ajuste de la base de información distribuida';tr = 'Dağıtılmış veri tabanı ayarı';it = 'Configura l''infobase distribuito';de = 'Aufbau einer verteilten Informationsbasis'");
		Else
			Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Настройка синхронизации данных с ""%1""'; en = 'Setup of data synchronization with %1'; pl = 'Ustawianie synchronizacji danych z ""%1""';es_ES = 'Configuración de la sincronización de datos con ""%1""';es_CO = 'Configuración de la sincronización de datos con ""%1""';tr = '%1 ile veri senkronizasyonu ayarı';it = 'Impostazione della sincronizzazione dati con %1';de = 'Einstellung der Datensynchronisation mit ""%1""'"),
				CorrespondentConfigurationDescription);
		EndIf;
	Else
		Title = ExchangeCreateWizardTitle;
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeFormAttributes()
	
	NewSYnchronizationSetting = Parameters.Property("NewSYnchronizationSetting");
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
	
	If NewSYnchronizationSetting Then
		ExchangePlanName         = Parameters.ExchangePlanName;
		SettingID = Parameters.SettingID;
		
		ContinueSetupInSubordinateDIBNode = Parameters.Property("ContinueSetupInSubordinateDIBNode");
		
		If Not ContinueSetupInSubordinateDIBNode Then
			If DataExchangeServer.IsSubordinateDIBNode() Then
				DIBExchangePlanName = DataExchangeServer.MasterNode().Metadata().Name;
				
				ContinueSetupInSubordinateDIBNode = (ExchangePlanName = DIBExchangePlanName)
					AND Not Constants.SubordinateDIBNodeSetupCompleted.Get();
				
			EndIf;
		EndIf;
		
		If ContinueSetupInSubordinateDIBNode Then
			DataExchangeServer.OnContinueSubordinateDIBNodeSetup();
			ExchangeNode = DataExchangeServer.MasterNode();
		EndIf;
	Else
		ExchangeNode = Parameters.ExchangeNode;
		
		ExchangePlanName = DataExchangeCached.GetExchangePlanName(ExchangeNode);
		SettingID = DataExchangeServer.SavedExchangePlanNodeSettingOption(ExchangeNode);
		
		If SaaSModel Then
			Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
			Parameters.Property("IsExchangeWithApplicationInService", IsExchangeWithApplicationInService);
		EndIf;
	EndIf;
	
	TransportKind = Undefined;
	If ValueIsFilled(ExchangeNode) Then
		SetupCompleted = SynchronizationSetupCompleted(ExchangeNode);
		TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(ExchangeNode);
		TransportSettingsAvailable = ValueIsFilled(TransportKind);
	EndIf;
	
	Backup = Not SaaSModel
		AND Not ContinueSetupInSubordinateDIBNode
		AND Common.SubsystemExists("StandardSubsystems.IBBackup");
		
	If Backup Then
		ModuleIBBackupServer = Common.CommonModule("IBBackupServer");
		
		BackupDataProcessorURL =
			ModuleIBBackupServer.BackupDataProcessorURL();
	EndIf;
		
	DIBSetup  = DataExchangeCached.IsDistributedInfobaseExchangePlan(ExchangePlanName);
	XDTOSetup = DataExchangeCached.IsXDTOExchangePlan(ExchangePlanName);
	
	InteractiveSendingAvailable = Not DIBSetup;
	UniversalExchangeSetup = DataExchangeCached.IsStandardDataExchangeNode(ExchangePlanName); // without conversion rules
	
	If NewSYnchronizationSetting
		Or DIBSetup
		Or UniversalExchangeSetup Then
		DataReceivedForMapping = False;
	ElsIf SaaSModel Then
		DataReceivedForMapping = DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode);
	Else
		If TransportKind = Enums.ExchangeMessagesTransportTypes.COM
			Or TransportKind = Enums.ExchangeMessagesTransportTypes.WS
			Or TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode
			Or Not TransportSettingsAvailable Then
			DataReceivedForMapping = DataExchangeServer.MessageWithDataForMappingReceived(ExchangeNode);
		Else
			DataReceivedForMapping = True;
		EndIf;
	EndIf;
	
	SettingsValuesForOption = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName,
		"CorrespondentConfigurationDescription,
		|ExchangeBriefInfo,
		|ExchangeCreateWizardTitle,
		|ExchangeDetailedInformation,
		|InitialImageCreationFormName,
		|DataSyncSettingsWizardFormName",
		SettingID);
	
	FillPropertyValues(ThisObject, SettingsValuesForOption);
	
	If IsBlankString(InitialImageCreationFormName)
		AND Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		InitialImageCreationFormName = "CommonForm.[InitialImageCreationForm]";
		InitialImageCreationFormName = StrReplace(InitialImageCreationFormName,
			"[InitialImageCreationForm]", "CreateInitialImageWithFiles");
	EndIf;
	
	CurrentSetupStep = "";
	If NewSYnchronizationSetting Then
		CurrentSetupStep = "ConnectionSetup";
	Else
		If Not SynchronizationSetupCompleted(ExchangeNode) Then
			CurrentSetupStep = "RulesSetting";
		ElsIf DIBSetup
			AND Not ContinueSetupInSubordinateDIBNode
			AND Not InitialImageCreated(ExchangeNode) Then
			If Not IsBlankString(InitialImageCreationFormName) Then
				CurrentSetupStep = "InitialDIBImage";
			EndIf;
		EndIf;
	EndIf;
	
	AllSetupSteps = New Structure;
	AllSetupSteps.Insert("ConnectionSetup",    "Main");
	AllSetupSteps.Insert("RulesSetting",         "Main");
	AllSetupSteps.Insert("InitialDIBImage",       "Main");
	AllSetupSteps.Insert("MapAndImport",  "Main");
	AllSetupSteps.Insert("InitialDataExport", "Main");
	
EndProcedure

&AtClient
Function AddSetupStage(Name, Button)
	
	StageString = SetupSteps.Add();
	StageString.Name     = Name;
	StageString.Button       = Button;
	StageString.StandardFont = New Font(Items[Button].Font, , , False);
	StageString.BoldFont  = New Font(Items[Button].Font, , , True);
	
	Return StageString;
	
EndFunction

&AtClient
Procedure FillSetupStagesTable()
	
	SetupSteps.Clear();
	
	If TransportSettingsAvailable
		Or NewSYnchronizationSetting Then
		AddSetupStage("ConnectionSetup", "SetUpConnectionParameters");
	EndIf;
	
	AddSetupStage("RulesSetting", "SetSendingAndReceivingRules");
	
	If DIBSetup
		AND Not ContinueSetupInSubordinateDIBNode
		AND Not IsBlankString(InitialImageCreationFormName) Then
		AddSetupStage("InitialDIBImage", "CreateInitialDIBImage");
	EndIf;
	
	If Not DIBSetup
		AND Not UniversalExchangeSetup
		AND DataReceivedForMapping Then
		AddSetupStage("MapAndImport", "MapAndExportData");
	EndIf;
		
	If InteractiveSendingAvailable
		AND (TransportSettingsAvailable
			Or NewSYnchronizationSetting) Then
		AddSetupStage("InitialDataExport", "ExecuteInitialDataExport");
	EndIf;
	
	// Visibility of setup items.
	For Each SetupStage In AllSetupSteps Do
		CommonClientServer.SetFormItemProperty(Items,
			SetupStage.Key + "Group",
			"Visible",
			SetupSteps.FindRows(New Structure("Name", SetupStage.Key)).Count() > 0);
	EndDo;
	
EndProcedure

&AtServer
Procedure SetInitialDisplayOfFormItems()
	
	Items.ExchangeBriefInfoLabelDecoration.Title = ExchangeBriefInfo;
	Items.BackupGroup.Visible = Backup;
	
EndProcedure

#EndRegion

#EndRegion