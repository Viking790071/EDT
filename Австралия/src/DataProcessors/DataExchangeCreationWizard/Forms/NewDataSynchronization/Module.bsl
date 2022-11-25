#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	DataExchangeServer.CheckExchangeManagementRights();
	
	CheckDataSynchronizationSettingPossibility(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	AddCreateNewExchangeCommands();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure DataExchangeTransportParametersSettings(Command)
	
	CommandRows = CreateExchangeCommands.FindRows(New Structure("CommandName", Command.Name));
		
	If CommandRows.Count() = 0 Then
		Return;
	EndIf;
	
	WizardParameters = New Structure;
	WizardParameters.Insert("ExchangePlanName",         CommandRows[0].ExchangePlanName);
	WizardParameters.Insert("SettingID", CommandRows[0].SettingID);
	WizardParameters.Insert("NewSYnchronizationSetting");
	
	WizardUniqueKey = WizardParameters.ExchangePlanName + "_" + WizardParameters.SettingID;
	
	OpenForm("DataProcessor.DataExchangeCreationWizard.Form.SyncSetup", WizardParameters, , WizardUniqueKey);
	
	Close();
	
EndProcedure
	
#EndRegion

#Region Private

&AtServer
Procedure AddCreateNewExchangeCommands()
	
	CreateExchangeCommands.Clear();
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataExchangeCreationWizard();
	
	SettingsTable = Undefined;
	ModuleSetupWizard.OnGetAvailableDataSynchronizationSettings(SettingsTable, True);
	
	ConfiurationsDescriptions = New Map;
	For Each SettingsString In SettingsTable Do
		If SettingsString.IsDistributedInfobaseExchangePlan Then
			Continue;
		EndIf;
		
		ConfiurationsDescriptions.Insert(SettingsString.CorrespondentConfigurationName,
			SettingsString.CorrespondentConfigurationDescription);
	EndDo;
	
	SettingsTable.Sort("IsXDTOExchangePlan");
	
	ConfigurationTable = SettingsTable.Copy(,
		"CorrespondentConfigurationName, IsDistributedInfobaseExchangePlan");
	ConfigurationTable.GroupBy("CorrespondentConfigurationName, IsDistributedInfobaseExchangePlan");
	
	ConfigurationNumber = 0;
	For Each ConfigurationString In ConfigurationTable Do
		
		ConfigurationNumber = ConfigurationNumber + 1;
		
		Filter = New Structure("CorrespondentConfigurationName, IsDistributedInfobaseExchangePlan");
		FillPropertyValues(Filter, ConfigurationString);
		
		SetupRows = SettingsTable.FindRows(Filter);
		
		If SetupRows.Count() = 0 Then
			Continue;
		EndIf;
		
		ParentGroup = Undefined;
		
		If ConfigurationString.IsDistributedInfobaseExchangePlan Then
			ParentGroup = Items.DIBExchangeGroup;
		Else
			ParentGroup = Items.OtherApplicationsExchangeGroup;
		EndIf;
		
		SetupNumber = 0;
		For Each SettingsString In SetupRows Do
			
			SetupNumber = SetupNumber + 1;
			
			OptionGroup = Items.Add("GroupConfiguration" + ConfigurationNumber + "Settings" + SetupNumber,
				Type("FormGroup"), ParentGroup);
			OptionGroup.Type                 = FormGroupType.UsualGroup;
			OptionGroup.Representation         = UsualGroupRepresentation.None;
			OptionGroup.Group         = ChildFormItemsGroup.AlwaysHorizontal;
			OptionGroup.ShowTitle = False;
			
			CommandName = "CommandConfiguration" + ConfigurationNumber + "Settings" + SetupNumber;
			
			CreateCommandAndFormItem(CommandName,
				SettingsString.NewDataExchangeCreationCommandTitle,
				OptionGroup,
				SettingsString.ExchangeBriefInfo);
				
			CommandString = CreateExchangeCommands.Add();
			CommandString.CommandName             = CommandName;
			CommandString.SettingID = SettingsString.SettingID;
			CommandString.ExchangePlanName         = SettingsString.ExchangePlanName;
			
		EndDo;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckDataSynchronizationSettingPossibility(Cancel = False)
	
	MessageText = "";
	If Common.DataSeparationEnabled() Then
		If Common.SeparatedDataUsageAvailable() Then
			ModuleDataExchangeSaaSCashed = Common.CommonModule("DataExchangeSaaSCached");
			If Not ModuleDataExchangeSaaSCashed.DataSynchronizationSupported() Then
		 		MessageText = NStr("ru = 'Возможность настройки синхронизации данных в данной программе не предусмотрена.'; en = 'Data synchronization setup is not supported in this application.'; pl = 'Możliwość ustawienia synchronizacji danych w tym programie nie jest przewidziana.';es_ES = 'Posibilidad de ajustar la sincronización de datos en este programa no está prevista.';es_CO = 'Posibilidad de ajustar la sincronización de datos en este programa no está prevista.';tr = 'Bu programda veri eşleşmesi ayarları yapılandırılamaz.';it = 'L''impostazione della sincronizzazione dati non è supportata in questa applicazione.';de = 'Die Möglichkeit, in diesem Programm eine Datensynchronisation einzurichten, ist nicht vorgesehen.'");
				Cancel = True;
			EndIf;
		Else
			MessageText = NStr("ru = 'В неразделенном режиме настройка синхронизации данных с другими программами недоступна.'; en = 'Setup of data synchronization with other applications in undivided mode is unavailable.'; pl = 'W niepodzielonym trybie ustawienie synchronizacji danych z innymi programami jest niedostępne.';es_ES = 'En el modo no distribuido el ajuste de sincronización de datos con otro programa no está disponible.';es_CO = 'En el modo no distribuido el ajuste de sincronización de datos con otro programa no está disponible.';tr = 'Bölünmemiş modda, diğer programlarla veri eşleştirmesi ayarları kullanılamaz.';it = 'L''impostazione della sincronizzazione dati con altre applicazioni in modalità non divisa non è disponibile.';de = 'Die Einrichtung der Datensynchronisation mit anderen Programmen ist im ungeteilten Modus nicht möglich.'");
			Cancel = True;
		EndIf;
	Else
		ExchangePlanList = DataExchangeCached.SSLExchangePlans();
		If ExchangePlanList.Count() = 0 Then
			MessageText = NStr("ru = 'Возможность настройки синхронизации данных в данной программе не предусмотрена.'; en = 'Data synchronization setup is not supported in this application.'; pl = 'Możliwość ustawienia synchronizacji danych w tym programie nie jest przewidziana.';es_ES = 'Posibilidad de ajustar la sincronización de datos en este programa no está prevista.';es_CO = 'Posibilidad de ajustar la sincronización de datos en este programa no está prevista.';tr = 'Bu programda veri eşleşmesi ayarları yapılandırılamaz.';it = 'L''impostazione della sincronizzazione dati non è supportata in questa applicazione.';de = 'Die Möglichkeit, in diesem Programm eine Datensynchronisation einzurichten, ist nicht vorgesehen.'");
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel
		AND Not IsBlankString(MessageText) Then
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateCommandAndFormItem(CommandName, Header, Parent, Tooltip)
	
	Command = Commands.Add(CommandName);
	Command.Title = Header;
	Command.Action  = "DataExchangeTransportParametersSettings";
	Command.ToolTip = Tooltip;
	
	CommandButton = Items.Add(CommandName, Type("FormButton"), Parent);
	CommandButton.CommandName = CommandName;
	CommandButton.Type = FormButtonType.Hyperlink;
	CommandButton.ToolTipRepresentation = ToolTipRepresentation.ShowBottom;
	CommandButton.AutoMaxWidth = False;
	CommandButton.ExtendedTooltip.AutoMaxWidth = False;
	
EndProcedure

#EndRegion