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
	
	ApplicationTimeZone = GetInfoBaseTimeZone();
	If IsBlankString(ApplicationTimeZone) Then
		ApplicationTimeZone = TimeZone();
	EndIf;
	Items.ApplicationTimeZone.ChoiceList.LoadValues(GetAvailableTimeZones());
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		
		Items.ConfigureSecurityProfilesUsageGroup.Visible =
			  Users.IsFullUser(, True)
			AND ModuleSafeModeManagerInternal.CanSetUpSecurityProfiles();
	Else
		Items.ConfigureSecurityProfilesUsageGroup.Visible = False;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.GetFilesFromInternet") Then
		Items.OpenProxyServerParametersGroup.Visible =
			  Users.IsFullUser(, True)
			AND Not Common.FileInfobase();
	Else
		Items.OpenProxyServerParametersGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Items.DigitalSignatureAndEncryptionGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.Properties") Then
		Items.AdditionalAttributesAndDataGroup.Visible = False;
	EndIf;
	
	If Not Common.SubsystemExists("StandardSubsystems.ObjectsVersioning") Then
		Items.VersioningGroup.Visible = False;
	EndIf;
	
	Items.InfobasePublishingGroup.Visible = Not (Common.DataSeparationEnabled() 
		Or Common.IsStandaloneWorkplace());
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		Items.FullTextSearchAndTextExtractionManagementGroup.Visible =
			Users.IsFullUser(, True);
	Else
		Items.FullTextSearchAndTextExtractionManagementGroup.Visible = False;
	EndIf;
	
	SetAvailability();
	
	ApplicationSettingsOverridable.CommonSettingsOnCreateAtServer(ThisObject);
	
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
Procedure ApplicationTitleOnChange(Item)
	Attachable_OnChangeAttribute(Item);
	StandardSubsystemsClient.SetAdvancedApplicationCaption();
EndProcedure

&AtClient
Procedure ApplicationTimeZoneOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseAdditionalAttributesAndInfoOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

&AtClient
Procedure UseFullTextSearchOnChange(Item)
	
	If UseFullTextSearch = 0 Then // The previous value is 2 (3rd mode).
		UseFullTextSearch = 1;
	ElsIf UseFullTextSearch = 2 Then // The previous value is 1 (True).
		UseFullTextSearch = 0;
	EndIf;
	
	OnChangeFullTextSearchMode(Item, True);
	
EndProcedure

&AtClient
Procedure InfobasePublicationURLOnChange(Item)
	
	Attachable_OnChangeAttribute(Item);
	
EndProcedure

&AtClient
Procedure InfobasePublicationURLStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("InfobasePublicationURLStartChoiceFollowUp", 0.1, True);
	
EndProcedure

&AtClient
Procedure LocalInfobasePublicationURLStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	AttachIdleHandler("LocalInfobasePublicationURLStartChoiceFollowUp", 0.1, True);
	
EndProcedure

&AtClient
Procedure UseObjectVersioningOnChange(Item)
	Attachable_OnChangeAttribute(Item);
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SecurityProfilesUsage(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.OpenSecurityProfileSetupDialog();
	EndIf;
	
EndProcedure

&AtClient
Procedure FullTextSearchAndTextExtractionControl(Command)
	
	If CommonClient.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		ModuleFullTextSearchClient = CommonClient.CommonModule("FullTextSearchClient");
		ModuleFullTextSearchClient.ShowFullTextSearchAndTextExtractionManagement();
	EndIf;
	
EndProcedure

&AtClient
Procedure RegionalSettings(Command)
	FormParameters = New Structure("Source", "SSLAdministrationPanel");
	OpenForm("CommonForm.RegionalSettings", FormParameters);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure InfobasePublicationURLStartChoiceFollowUp()
	
	InfobasePublicationURLStartChoiceCompletion("InfobasePublicationURL");
	
EndProcedure

&AtClient
Procedure LocalInfobasePublicationURLStartChoiceFollowUp()
	
	InfobasePublicationURLStartChoiceCompletion("LocalInfobasePublishingURL");
	
EndProcedure

&AtClient
Procedure InfobasePublicationURLStartChoiceCompletion(AttributeName)
	
	If CommonClientServer.ClientConnectedOverWebServer() Then
		InfobasePublicationURLStartChoiceAtServer(AttributeName, InfoBaseConnectionString());
		Attachable_OnChangeAttribute(Items[AttributeName]);
	Else
		ShowMessageBox(, NStr("ru = 'Не удалось автоматически заполнить поле, т.к. клиентское приложение не подключено через веб-сервер.'; en = 'Cannot fill in the field automatically as the client application is not connected via web server.'; pl = 'Nie można automatycznie wypełnić pola, ponieważ aplikacja kliencka nie jest podłączona przez serwer internetowy.';es_ES = 'No se ha podido rellenar automáticamente el campo porque la aplicación de cliente no está activado a través del servidor web.';es_CO = 'No se ha podido rellenar automáticamente el campo porque la aplicación de cliente no está activado a través del servidor web.';tr = 'İstemci uygulaması Web sunucusu üzerinden bağlı olmadığından alan otomatik olarak doldurulamadı.';it = 'Impossibile compilare automaticamente il campo perché l''applicazione client non è connessa via web server.';de = 'Es war nicht möglich, das Feld automatisch auszufüllen, da die Client-Anwendung nicht über den Webserver verbunden ist.'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure InfobasePublicationURLStartChoiceAtServer(AttributeName, ConnectionString)
	
	ConnectionParameters = StringFunctionsClientServer.ParametersFromString(ConnectionString);
	If ConnectionParameters.Property("WS") Then
		ConstantsSet[AttributeName] = ConnectionParameters.WS;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure OnChangeAttributeAfterAnswerToQuestion(Response, ExecutionParameters) Export
	If Response = "ActiveUsers" Then
		StandardSubsystemsClient.OpenActiveUserList();
	EndIf;
EndProcedure

&AtClient
Procedure Attachable_OnChangeAttribute(Item, UpdateInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	RefreshReusableValues();
	
	If UpdateInterface Then
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
Procedure OnChangeFullTextSearchMode(Item, UpdateInterface = True)
	
	ConstantName = OnChangeAttributeServer(Item.Name);
	
	If ConstantName = "CannotEnableFullTextSearchMode" Then
		// Display a warning message.
		QuestionText = NStr("ru = 'Для изменения режима полнотекстового поиска требуется завершение сеансов всех пользователей, кроме текущего.'; en = 'To change the full-text search mode, close sessions of all users except for the current one.'; pl = 'Aby zmienić tryb wyszukiwania pełnotekstowego należy zakończyć sesje wszystkich użytkowników, oprócz bieżącego.';es_ES = 'Para cambiar el modo de texto completo se requiere terminar todas las sesiones de todos los usuarios a excepción de la actual.';es_CO = 'Para cambiar el modo de texto completo se requiere terminar todas las sesiones de todos los usuarios a excepción de la actual.';tr = 'Tam metin arama modunu değiştirmek için mevcut kullanıcı dışındaki tüm kullanıcı oturumlarını kapatın.';it = 'Per modificare la modalità di ricerca full-text, chiudi le sessioni di tutti gli utenti tranne il corrente.';de = 'Um den Volltextsuchmodus zu ändern, müssen alle Benutzer außer dem aktuellen Benutzer abgemeldet werden.'");
		
		Buttons = New ValueList;
		Buttons.Add("ActiveUsers", NStr("ru = 'Активные пользователи'; en = 'Active users'; pl = 'Aktualni użytkownicy';es_ES = 'Usuarios activos';es_CO = 'Usuarios activos';tr = 'Aktif kullanıcılar';it = 'Utenti attivi';de = 'Active Users'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("OnChangeAttributeAfterAnswerToQuestion", ThisObject);
		ShowQueryBox(Handler, QuestionText, Buttons, , "ActiveUsers");
		Return;
	EndIf;
	
	If UpdateInterface Then
		RefreshInterface = True;
		AttachIdleHandler("UpdateApplicationInterface", 2, True);
	EndIf;
	
	If ConstantName <> "" Then
		Notify("Write_ConstantsSet", New Structure, ConstantName);
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server call

&AtServer
Function OnChangeAttributeServer(ItemName)
	
	DataPathAttribute = Items[ItemName].DataPath;
	
	ConstantName = SaveAttributeValue(DataPathAttribute);
	
	SetAvailability(DataPathAttribute);
	
	RefreshReusableValues();
	
	Return ConstantName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Function SaveAttributeValue(DataPathAttribute)
	
	// Save values of attributes not directly related to constants (in ratio one to one).
	If DataPathAttribute = "ApplicationTimeZone" Then
		If ApplicationTimeZone <> GetInfoBaseTimeZone() Then 
			SetPrivilegedMode(True);
			Try
				SetExclusiveMode(True);
				SetInfoBaseTimeZone(ApplicationTimeZone);
				SetExclusiveMode(False);
			Except
				SetExclusiveMode(False);
				Raise;
			EndTry;
			SetPrivilegedMode(False);
			SetSessionTimeZone(ApplicationTimeZone);
		EndIf;
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
		If DataPathAttribute = "UseFullTextSearch" Then
			Try
				If UseFullTextSearch Then
					FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Enable);
				Else
					FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Disable);
				EndIf;
			Except
				WriteLogEvent(
					NStr("ru = 'Полнотекстовый поиск'; en = 'Full-text search'; pl = 'Wyszukiwanie pełnotekstowe';es_ES = 'Búsqueda de texto completo';es_CO = 'Búsqueda de texto completo';tr = 'Tam metin arama';it = 'Ricerca Full-text';de = 'Volltextsuche'", CommonClientServer.DefaultLanguageCode()),
					EventLogLevel.Error,
					,
					,
					DetailErrorDescription(ErrorInfo()));
				Return "CannotEnableFullTextSearchMode";
			EndTry;
			ConstantName = "UseFullTextSearch";
			ConstantsSet.UseFullTextSearch = UseFullTextSearch;
			// Enable or disable dependent scheduled jobs.
			Changes = New Structure("Use", ConstantsSet.UseFullTextSearch);
			Job = ScheduledJobsFindPredefinedItem("FullTextSearchIndexUpdate");
			If Job <> Undefined Then
				ScheduledJobsServer.ChangeJob(Job, Changes);
			EndIf;
			Job = ScheduledJobsFindPredefinedItem("FullTextSearchMergeIndex");
			If Job <> Undefined Then
				ScheduledJobsServer.ChangeJob(Job, Changes);
			EndIf;
			If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
				Changes.Use = Changes.Use AND ConstantsSet.ExtractTextFilesOnServer;
				Job = ScheduledJobsFindPredefinedItem("TextExtraction");
				If Job <> Undefined Then
					ScheduledJobsServer.ChangeJob(Job, Changes);
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	// Save the constant value.
	If ConstantName <> "" Or DataPathAttribute = "UseFullTextSearch" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		If ConstantName = "UseAdditionalAttributesAndInfo" AND ConstantValue = False Then
			ThisObject.Read();
		EndIf;
	EndIf;
	
	Return ConstantName;
	
EndFunction

&AtServer
Procedure SetAvailability(DataPathAttribute = "")
	
	If (DataPathAttribute = "ConstantsSet.UseAdditionalAttributesAndInfo" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.Properties") Then
		
		CommonClientServer.SetFormItemProperty(
			Items, "AdditionalAttributesAndInfoOtherSettingsGroup",
			"Enabled", ConstantsSet.UseAdditionalAttributesAndInfo);
		
		CommonClientServer.SetFormItemProperty(
			Items, "AdditioinalAttributesAndInfoGroup",
			"Enabled", ConstantsSet.UseAdditionalAttributesAndInfo);
	EndIf;
	
	If (DataPathAttribute = "ConstantsSet.UseDigitalSignature"
		Or DataPathAttribute = "ConstantsSet.UseEncryption" Or DataPathAttribute = "")
		AND Common.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		
		Items.DigitalSignatureAndEncryptionSettingsGroup.Enabled =
			ConstantsSet.UseDigitalSignature Or ConstantsSet.UseEncryption;
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If DataPathAttribute = "" Then
		ProxySettingAvailabilityAtServer = Not UseSecurityProfiles;
		
		CommonClientServer.SetFormItemProperty(
			Items, "OpenProxyServerParametersGroup",
			"Enabled", ProxySettingAvailabilityAtServer);
		CommonClientServer.SetFormItemProperty(
			Items, "ConfigureProxyServerAtServerGroupUnavailableWhenUsingSecurityProfiles",
			"Visible", Not ProxySettingAvailabilityAtServer);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.ObjectsVersioning")
		AND (DataPathAttribute = "ConstantsSet.UseObjectsVersioning"
		Or DataPathAttribute = "") Then
		
		CommonClientServer.SetFormItemProperty(
			Items,
			"InformationRegisterObjectVersioningSettings",
			"Enabled",
			ConstantsSet.UseObjectsVersioning);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FullTextSearch") Then
		If DataPathAttribute = "" Or DataPathAttribute = "UseFullTextSearch" Then
			ModuleFullTextSearchServer = Common.CommonModule("FullTextSearchServer");
			If ConstantsSet.UseFullTextSearch <> ModuleFullTextSearchServer.OperationsAllowed() Then
				UseFullTextSearch = 2;
			Else
				UseFullTextSearch = ConstantsSet.UseFullTextSearch;
			EndIf;
			Items.FullTextSearchAndTextExtractionManagementSettingsGroup.Enabled = (UseFullTextSearch = 1);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function ScheduledJobsFindPredefinedItem(PredefinedItemName)
	Filter = New Structure("Metadata", PredefinedItemName);
	FoundItems = ScheduledJobsServer.FindJobs(Filter);
	Job = ?(FoundItems.Count() = 0, Undefined, FoundItems[0]);
	Return Job;
EndFunction

#EndRegion
