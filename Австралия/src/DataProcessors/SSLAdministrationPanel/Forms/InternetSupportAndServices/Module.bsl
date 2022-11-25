#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	IsSystemAdministrator   = Users.IsFullUser(, True);
	DataSeparationEnabled        = Common.DataSeparationEnabled();
	IsStandaloneWorkplace = Common.IsStandaloneWorkplace();
	
	If Common.SubsystemExists("StandardSubsystems.AddressClassifier") Then
		SettingsGroupVisibility = Not DataSeparationEnabled;
		If SettingsGroupVisibility Then
			CommandsGroupVisibility = True;
			If Common.SubsystemExists("OnlineUserSupport") Then
				ModuleOnlineUserSupport = Common.CommonModule("OnlineUserSupport");
				Items.AddressClassifierRightColumnGroup.Visible = False;
				
			Else
				SettingsGroupVisibility = False;
			EndIf;
			
			ModuleAddressClassifierInternal = Common.CommonModule("AddressClassifierInternal");
			AddressInfoAvailabilityInfo = ModuleAddressClassifierInternal.AddressInfoAvailabilityInfo();
			AddessClassifierContainsImportedInfo = AddressInfoAvailabilityInfo.Get("UseImportedItems") = True;
			Items.InformationRegisterInformationRegisterClearAddressClassifier.Enabled = AddessClassifierContainsImportedInfo;
			
		Else
			CommandsGroupVisibility = False;
		EndIf;
		Items.AddressClassifierSettingsGroup.Visible = SettingsGroupVisibility;
	Else
		Items.AddressClassifierSettingsGroup.Visible = False;
	EndIf;
	
	Items.ClassifiersGroup.Visible = Not DataSeparationEnabled;
	
	If Common.SubsystemExists("StandardSubsystems.Banks")Then
		DataProcessorName = "ImportBankClassifier";
		Items.ImportBankClassifierGroup.Visible =
			  Not DataSeparationEnabled
			AND Not IsStandaloneWorkplace
			AND IsSystemAdministrator
			AND Metadata.DataProcessors.Find(DataProcessorName) <> Undefined;
	Else
		Items.ImportBankClassifierGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.Currencies") Then
		Items.ExchangeRatesProcessingImportGroup.Visible =
			  Not DataSeparationEnabled
			AND Not IsStandaloneWorkplace;
	Else
		Items.ExchangeRatesProcessingImportGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		Items.DeclensionsGroup.Visible =
			  Not DataSeparationEnabled
			AND Not IsStandaloneWorkplace
			AND IsSystemAdministrator;
	Else
		Items.DeclensionsGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ContactOnlineSupport") Then
		Items.IntegrationOnlineSupportCallGroup.Visible =
			CommonClientServer.IsWindowsClient();
	Else
		Items.IntegrationOnlineSupportCallGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.MonitoringCenter") Then
		Items.MonitoringCenterGroup.Visible = IsSystemAdministrator;
		If IsSystemAdministrator Then
			MonitoringCenterParameters = GetMonitoringCenterParameters();
			MonitoringCenterAllowSendingData = GetDataSendingRadioButton(MonitoringCenterParameters.EnableMonitoringCenter, MonitoringCenterParameters.ApplicationInformationProcessingCenter);
			
			ServiceParameters = New Structure("Server, ResourceAddress, Port");
			If MonitoringCenterAllowSendingData = 0 Then
				ServiceParameters.Server = MonitoringCenterParameters.Server;
				ServiceParameters.ResourceAddress = MonitoringCenterParameters.ResourceAddress;
				ServiceParameters.Port = MonitoringCenterParameters.Port;
			ElsIf MonitoringCenterAllowSendingData = 2 Then
				ServiceParameters = Undefined;
			EndIf;
			
			If ServiceParameters <> Undefined Then
				If ServiceParameters.Port = 80 Then
					Schema = "http://";
					Port = "";
				ElsIf ServiceParameters.Port = 443 Then
					Schema = "https://";
					Port = "";
				Else
					Schema = "http://";
					Port = ":" + Format(ServiceParameters.Port, "NZ=0; NG=");
				EndIf;
				
				MonitoringCenterServiceAddress = Schema + ServiceParameters.Server + Port + "/" + ServiceParameters.ResourceAddress;
			Else
				MonitoringCenterServiceAddress = "";
			EndIf;
			
			Items.MonitoringCenterServiceAddress.Enabled = (MonitoringCenterAllowSendingData <> 2);
			Items.MonitoringCenterSettings.Enabled = (MonitoringCenterAllowSendingData <> 2);
			Items.SendContactInformationGroup.Visible = MonitoringCenterParameters.ContactInformationRequest <> 2;
		EndIf;
	Else
		Items.MonitoringCenterGroup.Visible = False;
	EndIf;
	
	AddInsGroupVisibility = False;
	
	If Common.SubsystemExists("StandardSubsystems.AddIns") Then 
		
		ModuleAddInsInternal = Common.CommonModule("AddInsInternal");
		AddInsGroupVisibility = ModuleAddInsInternal.ImportFromPortalIsAvailable();
		
	EndIf;
	
	Items.AddInsGroup.Visible = AddInsGroupVisibility;
	
	// Update items states.
	SetAvailability();
	
	ProcessISLSettings = False;
	If Common.SubsystemExists("OnlineUserSupport") Then
		ModuleUserOnlineSupportClientServer =
			Common.CommonModule("OnlineUserSupportClientServer");
		ISLVersion = ModuleUserOnlineSupportClientServer.LibraryVersion();
		ProcessISLSettings = (CommonClientServer.CompareVersions(ISLVersion, "2.2.1.1") >= 0);
	EndIf;
	
	If ProcessISLSettings Then
		ModuleOnlineUserSupport = Common.CommonModule("OnlineUserSupport");
		ModuleOnlineUserSupport.InternetSupportAndServices_OnCreateAtServer(ThisObject);
	Else
		Items.ISLSettingsGroup.Visible                 = False;
		Items.ISLNewsGroup.Visible                   = False;
		Items.ISLApplicationUpdateGroup.Visible       = False;
		Items.ISLClassifiersUpdateGroup.Visible = False;
		Items.ISLCounterpartiesCheckGroup.Visible      = False;
		Items.ISL1CSPARKRisksGroup.Visible                = False;
	EndIf;
	
	ApplicationSettingsOverridable.OnlineSupportAndServicesOnCreateAtServer(ThisObject);
	
	Items.ConversationsGroup.Visible = Common.SubsystemExists("StandardSubsystems.Conversations");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnChangeConversationsEnabledState();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "AddressClassifierCleared" Or EventName = "AddressClassifierImported" Then
		Items.InformationRegisterInformationRegisterClearAddressClassifier.Enabled = (Parameter = True);
	EndIf;
	
	If ProcessISLSettings Then
		If CommonClient.SubsystemExists("OnlineUserSupport.CoreISL") Then
			ModuleOnlineUserSupportClient = CommonClient.CommonModule("OnlineUserSupportClient");
			ModuleOnlineUserSupportClient.OnlineSupportAndServices_NotificationProcessing(
				ThisObject,
				EventName,
				Parameter,
				Source);
		EndIf;
	EndIf;
	
	If EventName = "ConversationsEnabled" Then 
		OnChangeConversationsEnabledState(Parameter);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	UpdateApplicationInterface();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AllowSendDataOnChange(Item)
	
	Var RunResult;
	
	Items.MonitoringCenterServiceAddress.Enabled = (MonitoringCenterAllowSendingData = 0);
	Items.MonitoringCenterSettings.Enabled = (MonitoringCenterAllowSendingData <> 2);
	If MonitoringCenterAllowSendingData = 2 Then
		MonitoringCenterParametersRecord = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", False, False);
	ElsIf MonitoringCenterAllowSendingData = 0 Then
		MonitoringCenterParametersRecord = New Structure("EnableMonitoringCenter, ApplicationInformationProcessingCenter", True, False);
	EndIf;
	
	MonitoringCenterServiceAddress = GetServiceAddress();
	AllowSendDataOnChangeAtServer(MonitoringCenterParametersRecord, RunResult);
	If RunResult <> Undefined Then
		MonitoringCenterJobID = RunResult.JobID;
		MonitoringCenterJobResultAddress = RunResult.ResultAddress;
		ModuleMonitoringCenterClient = CommonClient.CommonModule("MonitoringCenterClient");
		Notification = New NotifyDescription("AfterUpdateID", ModuleMonitoringCenterClient);
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow = False;
		TimeConsumingOperationsClient.WaitForCompletion(RunResult, Notification, IdleParameters); 
	EndIf;
	
EndProcedure

&AtClient
Procedure MonitoringCenterServiceAddressOnChange(Item)
	Try
		AddressStructure = CommonClientServer.URIStructure(MonitoringCenterServiceAddress);
		
		If AddressStructure.Schema = "http" Then
			AddressStructure.Insert("SecureConnection", False);
		ElsIf AddressStructure.Schema = "https" Then
			AddressStructure.Insert("SecureConnection", True);
        Else
            AddressStructure.Insert("SecureConnection", False);
		EndIf;
		
		If NOT ValueIsFilled(AddressStructure.Port) Then
			If AddressStructure.Schema = "http" Then
				AddressStructure.Port = 80;
			ElsIf AddressStructure.Schema = "https" Then
				AddressStructure.Port = 443;
            Else
                AddressStructure.Port = 80;
			EndIf;
		EndIf;
	Except
		// Warning, the address format needs to comply with RFC 3986. See the description of the 
		// CommonClientServer.URIStructure function .
		ErrorDescription = NStr("ru = 'Адрес сервиса'; en = 'Service address'; pl = 'Adres serwisu';es_ES = 'Dirección del servicio';es_CO = 'Dirección del servicio';tr = 'Servis adı';it = 'Indirizzo servizio';de = 'Service-Adresse'") + " "
			+ MonitoringCenterServiceAddress + " "
			+ NStr("ru = 'не является допустимым адресом веб-сервиса для отправки отчетов об использовании программы.'; en = 'not allowable address of the web service for sending the application usage reports.'; pl = 'nie jest prawidłowym adresem serwisu internetowego do wysyłania raportów na temat korzystania z programu.';es_ES = 'no es dirección admitida del servicio web para enviar los informes del uso del programa.';es_CO = 'no es dirección admitida del servicio web para enviar los informes del uso del programa.';tr = 'program kullanım raporları göndermek için geçerli bir Web hizmeti adresi değildir.';it = 'indirizzo non consentito del web service per l''invio dei report d''uso dell''applicazione.';de = 'ist keine gültige Webserviceadresse zum Senden von Berichten zur Verwendung des Programms.'"); 
		Raise(ErrorDescription);
	EndTry;
	
	MonitoringCenterServiceAddressOnChangeAtServer(AddressStructure);
EndProcedure

&AtClient
Procedure IntegrationCallOnlineSupportOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure APIUsernameURLProcessingDecoration(Item, FormattedStringURL, StandardProcessing)
	
	ModuleOnlineUserSupportClient =
		CommonClient.CommonModule("OnlineUserSupportClient");
	ModuleOnlineUserSupportClient.OnlineSupportAndServices_URLProcessingDecoration(
		ThisObject,
		Item,
		FormattedStringURL,
		StandardProcessing);
	
EndProcedure

&AtClient
Procedure ISLEnableWorkWithNewsOnChange(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.News") Then
		ModuleNewsProcessingClient = CommonClient.CommonModule("NewsProcessingClient");
		ModuleNewsProcessingClient.OnlineSupportAndServices_EnableNewsOperationsOnChange(
			ThisObject,
			Item);
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLUse1CSPARKRisksServiceOnChange(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.SPARKRisks") Then
		Module1CSPARKRisksClient = CommonClient.CommonModule("SPARKRisksClient");
		Module1CSPARKRisksClient.OnlineSupportAndServices_RunSPARKRisksServiceOnCHange(
			ThisObject,
			Item);
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure AutomaticUpdateCheckOnChange(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		ModuleGetApplicationUpdatesClient =
			CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.OnlineSupportAndServices_AutomaticUpdatesCheckOnChange(
			ThisObject,
			Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure DecorationUpdateCheckScheduleClick(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		ModuleGetApplicationUpdatesClient =
			CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.OnlineSupportAndServices_DecorationUpdatesCheckScheduleClick(
			ThisObject,
			Item);
	EndIf;
	
EndProcedure

&AtClient
Procedure DistributionDirectoryPlatformsClick(Item, StandardProcessing)
	
	ModuleGetApplicationUpdatesClient =
		CommonClient.CommonModule("GetApplicationUpdatesClient");
	ModuleGetApplicationUpdatesClient.OnlineSupportAndServices_PlatformDistributionDirectoryClick(
		ThisObject,
		Item,
		StandardProcessing);
	
EndProcedure

&AtClient
Procedure ItemizeIBUpdateInEventLogOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#EndRegion

#Region FormCommandHandlers

// StandardSubsystems.IBVersionUpdate
&AtClient
Procedure DeferredDataProcessing(Command)
	
	FormParameters = New Structure("OpenedFromAdministrationPanel", True);
	OpenForm(
		"DataProcessor.ApplicationUpdateResult.Form.DeferredIBUpdateProgressIndicator",
		FormParameters);
	
EndProcedure
// End StandardSubsystems.IBVersionUpdate

&AtClient
Procedure ISLSignInOrSignOut(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CoreISL") Then
		ModuleOnlineUserSupportClient =
			CommonClient.CommonModule("OnlineUserSupportClient");
		ModuleOnlineUserSupportClient.OnlineSupportAndServices_SignInOtSignOutISL(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLMessageToTechnicalSupport(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CoreISL") Then
		ModuleOnlineUserSupportClient = CommonClient.CommonModule("OnlineUserSupportClient");
		ModuleOnlineUserSupportClient.OnlineSupportAndServices_MessageToTechnicalSupport(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLOnlineSupportDashboard(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.1CITSPortalDashboard") Then
		Module1CITSKPortalMonitorClient = CommonClient.CommonModule("1CITSPortalDashboardClient");
		Module1CITSKPortalMonitorClient.OnlineSupportAndServices_1CITSPortalDashboard(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLNewsManagement(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.News") Then
		ModuleNewsProcessingClient = CommonClient.CommonModule("NewsProcessingClient");
		ModuleNewsProcessingClient.OnlineSupportAndServices_NewsManagement(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLApplicationUpdate(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.GetApplicationUpdates") Then
		ModuleGetApplicationUpdatesClient = CommonClient.CommonModule("GetApplicationUpdatesClient");
		ModuleGetApplicationUpdatesClient.OnlineSupportAndServices_ApplicationUpdate(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLClassifiersUpdate(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.ClassifiersOperations") Then
		ModuleGetClassifiersOperationsClient = CommonClient.CommonModule("ClassifiersOperationsClient");
		ModuleGetClassifiersOperationsClient.OnlineSupportAndServices_ClassifiersUpdate(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLUseCounterpartyCheckOnChange(Item)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CounterpartyFunctions") Then
		ModuleCounterpartyFunctionsClient =
			CommonClient.CommonModule("CounterpartyFunctionsClient");
		ModuleCounterpartyFunctionsClient.OnlineSupportAndServices_UseCounterpartiesCheckOnChange(
			ThisObject,
			Item);
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ISLCounterpartiesCheckCheckAccessToWebService(Command)
	
	If CommonClient.SubsystemExists("OnlineUserSupport.CounterpartyFunctions") Then
		ModuleCounterpartyFunctionsClient = CommonClient.CommonModule("CounterpartyFunctionsClient");
		ModuleCounterpartyFunctionsClient.OnlineSupportAndServices_ISLCounterpartiesCheckWebServiceAccessCheck(
			ThisObject,
			Command);
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableDisableConversations(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Conversations") Then
		
		ModuleConversationsServiceClient = CommonClient.CommonModule("ConversationsServiceClient");
		
		If ModuleConversationsServiceClient.Connected() Then
			ModuleConversationsServiceClient.ShowDisconnection();
		Else 
			ModuleConversationsServiceClient.ShowConnection();
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region PrivateEventHandlers

&AtClient
Procedure OnChangeConversationsEnabledState(ConversationsEnabled = Undefined)
	
	If CommonClient.SubsystemExists("StandardSubsystems.Conversations") Then
		
		If ConversationsEnabled = Undefined Then 
			ModuleConversationsServiceClient = CommonClient.CommonModule("ConversationsServiceClient");
			ConversationsEnabled = ModuleConversationsServiceClient.Connected();
		EndIf;
		
		If ConversationsEnabled Then 
			Items.EnableDisableConversations.Title = NStr("ru = 'Отключить'; en = 'Disable'; pl = 'Wyłącz';es_ES = 'Desactivar';es_CO = 'Desactivar';tr = 'Devre dışı bırak';it = 'Disabilitare';de = 'Deaktivieren'");
			Items.ConversationsEnabledState.Title = NStr("ru = 'Обсуждения подключены.'; en = 'Conversations enabled.'; pl = 'Dyskusje są podłączone.';es_ES = 'Conversaciones activadas.';es_CO = 'Conversaciones activadas.';tr = 'Tartışmalar bağlı.';it = 'Conversazioni attivate.';de = 'Diskussionen sind verbunden.'");
		Else 
			Items.EnableDisableConversations.Title = NStr("ru = 'Подключить'; en = 'Enable'; pl = 'Włącz';es_ES = 'Activar';es_CO = 'Activar';tr = 'Etkinleştir';it = 'Abilitare';de = 'Aktivieren'");
			Items.ConversationsEnabledState.Title = NStr("ru = 'Подключение обсуждений не выполнено.'; en = 'Conversations are disabled.'; pl = 'Konwersacje są wyłączone.';es_ES = 'Conversaciones deshabilitadas.';es_CO = 'Conversaciones deshabilitadas.';tr = 'Konuşmalar devre dışı.';it = 'Conversazioni disattivate.';de = 'Gespräche sind deaktiviert.'");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure Attachable_OnChangeAttribute(Item, NeedToRefreshInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If NeedToRefreshInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		CommonClient.RefreshApplicationInterface();
	EndIf;
	
EndProcedure

&AtClient
Function GetServiceAddress()
	
	MonitoringCenterParameters = GetMonitoringCenterParameters();
			
	ServiceParameters = New Structure("Server, ResourceAddress, Port");
	
	If MonitoringCenterAllowSendingData = 0 Then
		ServiceParameters.Server = MonitoringCenterParameters.Server;
		ServiceParameters.ResourceAddress = MonitoringCenterParameters.ResourceAddress;
		ServiceParameters.Port = MonitoringCenterParameters.Port;
	ElsIf MonitoringCenterAllowSendingData = 2 Then
		ServiceParameters = Undefined;
	EndIf;
	
	If ServiceParameters <> Undefined Then
		If ServiceParameters.Port = 80 Then
			Schema = "http://";
			Port = "";
		ElsIf ServiceParameters.Port = 443 Then
			Schema = "https://";
			Port = "";
		Else
			Schema = "http://";
			Port = ":" + Format(ServiceParameters.Port, "NZ=0; NG=");
		EndIf;
		
		ServiceAddress = Schema + ServiceParameters.Server + Port + "/" + ServiceParameters.ResourceAddress;
	Else
		ServiceAddress = "";
	EndIf;
	
	Return ServiceAddress;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	If ItemName = "UseMorpherDeclinationService"
		AND Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		ModuleObjectPresentationDeclension = Common.CommonModule("ObjectPresentationDeclension");
		ModuleObjectPresentationDeclension.SetDeclensionServiceAvailability(True);
	EndIf;
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If Not Users.IsFullUser(, True) Then
		Return;
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseOnlineSupport" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.ContactOnlineSupport") Then
		Items.OnlineSupportSettingGroup.Enabled = ConstantsSet.UseOnlineSupport;
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseMorpherDeclinationService" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.ObjectPresentationDeclension") Then
		
		CommonClientServer.SetFormItemProperty(
			Items, "InflectionSettingsGroup", "Enabled",
			ConstantsSet.UseMorpherDeclinationService);
			
	EndIf;
	
EndProcedure

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Saving attribute values not directly related to constants.
	If DataPathAttribute = "" Then
		Return "";
	EndIf;
	
	// Define the constant name.
	ConstantName = "";
	Position = StrFind(DataPathAttribute, "ConstantsSet.");
	If Position > 0 Then
		ConstantName = StrReplace(DataPathAttribute, "ConstantsSet.", "");
	Else
		// Define the name and record the attribute value in the constant from the ConstantsSet.
		// It is used for those form attributes that are directly related to constants (in ratio one to one).
	EndIf;
	
	// Save the constant value.
	If Lower(Left(DataPathAttribute, 14)) = Lower("ConstantsSet.") Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		ConstantManager.Set(ConstantValue);
		
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServerNoContext
Function GetDataSendingRadioButton(EnableMonitoringCenter, DataProcessingCenterAboutApplication)
	State = ?(EnableMonitoringCenter, "1", "0") + ?(DataProcessingCenterAboutApplication, "1", "0");
	
	If State = "00" Then
		Result = 2;
	ElsIf State = "01" Then
		Result = 1;
	ElsIf State = "10" Then
		Result = 0;
	ElsIf State = "11" Then
		// But this cannot happen...
	EndIf;
	
	Return Result;
EndFunction

&AtServerNoContext
Function GetMonitoringCenterParameters()
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	MonitoringCenterParameters = ModuleMonitoringCenterInternal.GetMonitoringCenterParametersExternalCall();
	
	Return MonitoringCenterParameters;
EndFunction

&AtServerNoContext
Procedure AllowSendDataOnChangeAtServer(MonitoringCenterParameters, RunResult)
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	ModuleMonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
	
	EnableMonitoringCenter = MonitoringCenterParameters.EnableMonitoringCenter;
	DataProcessingCenterAboutApplication = MonitoringCenterParameters.ApplicationInformationProcessingCenter;
	
	Result = GetDataSendingRadioButton(EnableMonitoringCenter, DataProcessingCenterAboutApplication);
	
	If Result = 0 Or Result = 1 Then
		// Send a discovery package.
		RunResult = ModuleMonitoringCenterInternal.StartDiscoveryPackageSending();
	EndIf;
	
	If Result = 0 Then
		// Enable job of collecting and sending statistics.
		ScheduledJob = ModuleMonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
		ModuleMonitoringCenterInternal.SetDefaultScheduleExternalCall(ScheduledJob);
	ElsIf Result = 1 Then
		ScheduledJob = ModuleMonitoringCenterInternal.GetScheduledJobExternalCall("StatisticsDataCollectionAndSending", True);
		ModuleMonitoringCenterInternal.SetDefaultScheduleExternalCall(ScheduledJob);
	ElsIf Result = 2 Then
		ModuleMonitoringCenterInternal.DeleteScheduledJobExternalCall("StatisticsDataCollectionAndSending");
	EndIf;
EndProcedure

&AtServerNoContext
Procedure MonitoringCenterServiceAddressOnChangeAtServer(AddressStructure)
	MonitoringCenterParameters = New Structure();
	MonitoringCenterParameters.Insert("Server", AddressStructure.Host);
	MonitoringCenterParameters.Insert("ResourceAddress", AddressStructure.PathAtServer);
	MonitoringCenterParameters.Insert("Port", AddressStructure.Port);
	MonitoringCenterParameters.Insert("SecureConnection", AddressStructure.SecureConnection);
	
	ModuleMonitoringCenterInternal = Common.CommonModule("MonitoringCenterInternal");
	ModuleMonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(MonitoringCenterParameters);
EndProcedure

#EndRegion
