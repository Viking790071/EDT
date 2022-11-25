#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ExecuteActionsOnCreateOnAtServer();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
		
	CatalogValueTable = FormAttributeToValue("CatalogTable");
	CatalogValueTable.Columns.Add("SettingsStorageCatalog", New TypeDescription("ValueStorage"));
	
	For Each CatalogTableRow In CatalogValueTable Do
		
		If ValueIsFilled(CatalogTableRow.CatalogSettingsAddress) Then
			SettingsCatalog = GetFromTempStorage(CatalogTableRow.CatalogSettingsAddress);
			CatalogTableRow.SettingsStorageCatalog = New ValueStorage(SettingsCatalog);
		EndIf;
		
	EndDo;
	
	If Not CatalogValueTable.Columns.Find("CompositionSettingsAddress") = Undefined Then
		CatalogValueTable.Columns.Delete("CompositionSettingsAddress");
	EndIf;
	
	CatalogValueTable.Columns.Delete("CatalogSettingsAddress");
	CurrentObject.StoredCatalogTable = New ValueStorage(CatalogValueTable);
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.UseAutomaticExchange
		And (JobSchedule = Undefined
		Or (Common.DataSeparationEnabled()
		And Not JobSchedule.RepeatPeriodInDay > 0)) Then
		
		CurrentObject.UseAutomaticExchange = False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentObject.EnableDisableScheduledJob(JobSchedule);
	
	SetPrivilegedMode(False);
	
	If PasswordIsChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		SetPrivilegedMode(False);
	EndIf;
	
	If PasswordWebsiteIsChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, PasswordWebsite, "PasswordWebsite");
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetConnectionPageVisibility();
	
	SetPrivilegedMode(True);
	
	If DataExchangeByWebServiceIsAvailable Then
		PasswordFromStorage = Common.ReadDataFromSecureStorage(Object.Ref, "Password");
	EndIf;
	
	If DataExchangeByFTPIsAvailable Then
		PasswordWebsiteFromStorage = Common.ReadDataFromSecureStorage(Object.Ref, "PasswordWebsite");
	EndIf;
	
	SetPrivilegedMode(False);
	Password = ?(ValueIsFilled(PasswordFromStorage), ThisObject.UUID, "");
	PasswordWebsite = ?(ValueIsFilled(PasswordWebsiteFromStorage), ThisObject.UUID, "");
	
	Job = CurrentObject.CurrentJob();
	
	If Not Job = Undefined Then
		JobSchedule = Job.Schedule;
	EndIf;
	
	SetTitleScheduleExchangeAtServer();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FormManagment();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IntegrationComponentOnChange(Item)
	
	SetConnectionPageVisibility();
	FormManagment();
	
EndProcedure

&AtClient
Procedure ExportProductsOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure PasswordOnChange(Item)
	PasswordIsChanged = True;
EndProcedure

&AtClient
Procedure PasswordWebsiteOnChange(Item)
	PasswordWebsiteIsChanged = True;
EndProcedure

&AtClient
Procedure ExportPricesOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure ExportBalancesOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure ExportChangesRadioButtonOnChange(Item)
	OnChangeExportChangesRadioButton();
EndProcedure

&AtClient
Procedure ImportOrdersOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure DataExchangeByWebServiceOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure DataExchangeByCommonCatalogOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure DataExchangeToWebsiteOnChange(Item)
	FormManagment();
EndProcedure

&AtClient
Procedure CatalogTableGroupsStartChoice(Item, ChoiceData, StandardProcessing)
	
	Groups = Items.CatalogTable.CurrentData.Groups;
	
	If Groups.Count() = 1 Then
		
		If Not ValueIsFilled(Groups[0].Value) Then
			Groups.Clear();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportCustomersOnChange(Item)
	FormManagment();
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableCatalogSetting

&AtClient
Procedure CatalogTableOnStartEdit(Item, NewRow, Clone)
	
	If Clone Then
		
		Item.CurrentData.CatalogID = "";
		
	EndIf;
	
	If (Item.CurrentData.Groups.Count() = 1
		And Not ValueIsFilled(Item.CurrentData.Groups[0].Value))
		Or Item.CurrentData.Groups.Count() = 0 Then
		                            
		NewGroupList = New ValueList;
		Items.CatalogTableGroups.ChoiceFoldersAndItems = FoldersAndItems.Folders;
		
		NewGroupList.ValueType = New TypeDescription("CatalogRef.Products");
		NewGroupList.Add(Undefined, AllListItemsLabel);
		Item.CurrentData.Groups = NewGroupList;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CatalogTableBeforeEditEnd(Item, NewRow, CancelEdit, Cancel)
	
	If Not UniqueUUID() Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure CatalogTableOnEditEnd(Item, NewRow, CancelEdit)
	
	If CancelEdit
		Or Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	FillInCatalogTable(Item.CurrentData);
	Modified = True;
	
EndProcedure

&AtClient
Procedure CatalogTableAfterDeleteRow(Item)
	Modified = True;
EndProcedure

&AtClient
Procedure CatalogTableCatalogSettingsStartChoice(Item, ChoiceData, StandardProcessing)
		
	StandardProcessing = False;
	OpenCatalogFilterForm();
	
EndProcedure

&AtClient
Procedure CatalogTableCatalogSettingsClearing(Item, StandardProcessing)
	
	CurrentData = Items.CatalogTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ValueIsFilled(CurrentData.CatalogSettingsAddress) Then
		DeleteFromTempStorage(CurrentData.CatalogSettingsAddress);
		CurrentData.CatalogSettingsAddress = "";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SetExchangeSchedule(Command)
	
	ExecuteExchangeScheduleSetup();
	
EndProcedure

&AtClient
Procedure CheckConnection(Command)
	
	If IsBlankString(Object.WebsiteAddress)
		Or IsBlankString(Object.UsernameWebsite)
		Or IsBlankString(PasswordWebsite) Then
		
		MessageText = NStr("en = 'Please fill in the fields to connect'; ru = 'Заполните поля для подключения';pl = 'Wypełnij pola do połączenia';es_ES = 'Por favor, complete los campos para conectarse';es_CO = 'Por favor, complete los campos para conectarse';tr = 'Lütfen, bağlanmak için alanları doldurun';it = 'Compilare i campi per connettersi';de = 'Bitte füllen Sie die Felder zur Verbindung aus'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ConnectionSettings = New Structure;
	ConnectionSettings.Insert("Username",				Object.UsernameWebsite);
	ConnectionSettings.Insert("Website",				Object.WebsiteAddress);
	ConnectionSettings.Insert("IntegrationComponent",	Object.IntegrationComponent);
	ConnectionSettings.Insert("IsWebservice",			False);
	
	MessageText = "";
	
	CheckWebSiteConnection(ConnectionSettings, MessageText);
	
	ShowMessageBox(, MessageText);
	
EndProcedure

&AtClient
Procedure CheckConnectionWebService(Command)
	
	If IsBlankString(Object.WebService)
		Or IsBlankString(Object.Username)
		Or IsBlankString(Password) Then
		
		MessageText = NStr("en = 'Please fill in the fields to connect'; ru = 'Заполните поля для подключения';pl = 'Wypełnij pola do połączenia';es_ES = 'Por favor, complete los campos para conectarse';es_CO = 'Por favor, complete los campos para conectarse';tr = 'Lütfen, bağlanmak için alanları doldurun';it = 'Compilare i campi per connettersi';de = 'Bitte füllen Sie die Felder zur Verbindung aus'");
		CommonClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	ConnectionSettings = New Structure;
	ConnectionSettings.Insert("Username",				Object.Username);
	ConnectionSettings.Insert("Website",				Object.WebService);
	ConnectionSettings.Insert("IntegrationComponent",	Object.IntegrationComponent);
	ConnectionSettings.Insert("IsWebservice",			True);
	
	MessageText = "";
	
	CheckWebServiceConnection(ConnectionSettings, MessageText);
	
	ShowMessageBox(, MessageText);
	
EndProcedure

&AtClient
Procedure AdvancedSetting(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("PartSize", Object.PartSize);
	FormParameters.Insert("RepeatCount", Object.RepeatCount);
	FormParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	
	NotifyHandler = New NotifyDescription("AdvancedSettingEnd", ThisObject);
	
	OpenForm("ExchangePlan.Website.Form.FormAdvancedSetting", FormParameters, ThisObject
		,
		,
		,
		,
		NotifyHandler);
		
EndProcedure

&AtClient
Procedure RunSync(Command)
	
	If Modified Or Object.Ref.IsEmpty() Then
		If Not Write() Then
			Return;
		EndIf;
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Data exchange with website started on %1.'; ru = 'Обмен данными с веб-сайтом начался %1.';pl = 'Wymiana danych ze stroną internetową została rozpoczęta %1.';es_ES = 'Intercambio de datos con el sitio web comenzado el %1.';es_CO = 'Intercambio de datos con el sitio web comenzado el %1.';tr = 'Web sitesi ile veri değişimi başlangıcı: %1.';it = 'Lo scambio dati con il sito web è iniziato a %1.';de = 'Datenaustausch mit Webseite, began am: %1.'"),
		Format(CommonClient.SessionDate(), "DLF=DT"));
			
	Explanation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'by exchange node ""%1""...'; ru = 'по узлу обмена ""%1""...';pl = 'według węzła wymiany ""%1""...';es_ES = 'por el nodo de intercambio ""%1""...';es_CO = 'por el nodo de intercambio ""%1""...';tr = '""%1"" değişim düğümü ile...';it = 'per nodo di scambio ""%1""...';de = 'durch Exchange-Knoten ""%1""...'"),
		Object.Ref);
	
	Status(MessageText,	, Explanation);
			
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ExchangeStartMode", NStr("en = 'Interactive exchange'; ru = 'Интерактивный обмен';pl = 'Wymiana interaktywna';es_ES = 'Intercambio interactivo';es_CO = 'Intercambio interactivo';tr = 'İnteraktif değişim';it = 'Scambio interattivo';de = 'Interaktiver Austausch'"));
	
	Result = ExchangeCompletedServer(Object.Ref, ParametersStructure);
	
	If Object.ImportOrders Then
		NotifyChanged(Type("DocumentRef.SalesOrder"));
	EndIf;
		
	If Not Result.JobCompleted Then
		
		JobID = Result.JobID;
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		IdleHandlerParameters.IntervalIncreaseCoefficient = 1.2;
		AttachIdleHandler("Attachable_CheckJobCompletion", 1, True);
		
	Else
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Object.Ref);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with the website is completed.'; ru = 'Обмен данными с веб-сайтом завершен.';pl = 'Wymiana danych ze stroną internetową została zakończona.';es_ES = 'Se completa el intercambio de datos con el sitio web.';es_CO = 'Se completa el intercambio de datos con el sitio web.';tr = 'Web sitesi ile veri değişimi tamamlandı.';it = 'Scambio dati con il sito web completato.';de = 'Datenaustausch mit der Webseite ist abgeschlossen.'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithWebsiteCompleted");
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure FormManagment()
	
	Items.GroupPages.Visible	= Not Object.ThisNode;
	Items.Company.Visible		= Not Object.ThisNode;
	
	Items.PageConnection.Visible	= ValueIsFilled(Object.IntegrationComponent);
	Items.GroupDataExchangeByWebService.Visible	=		DataExchangeByWebServiceIsAvailable;
	Items.GroupDataExchangeByCommonCatalog.Visible =	DataExchangeByCommonCatalogIsAvailable;
	Items.GroupDataExchangeToWebsite.Visible =			DataExchangeByFTPIsAvailable;
	
	Items.GroupWebServiceFields.Enabled	=		Object.DataExchangeByWebService;
	Items.GroupCommonCatalogFields.Enabled =	Object.DataExchangeByCommonCatalog;
	Items.GroupWebsiteFields.Enabled =			Object.DataExchangeToWebsite;
	
	Items.PageProducts.Visible		= Object.ExportProducts And ValueIsFilled(Object.IntegrationComponent);
	Items.PagePriceTypes.Visible	= Object.ExportProducts And Object.ExportPrices;
	Items.PageBalances.Visible		= Object.ExportProducts And Object.ExportBalances;
	
	Items.GroupExportCatalogs.Enabled	= Object.ExportProducts;
	Items.GroupOrdersAttributes.Enabled	= Object.ImportOrders;
	Items.DefaultCustomer.Enabled		= Not Object.ImportCustomers;

	ExportChangesRadioButton = Object.ExportChangesOnly;
	
EndProcedure

&AtClient
Procedure ExecuteExchangeScheduleSetup()

	If JobSchedule = Undefined Then
		JobSchedule = New JobSchedule;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ChangeExchangeSchedule", ThisObject);
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	Dialog.Show(NotifyDescription);

EndProcedure

&AtClient
Procedure ChangeExchangeSchedule(Result, Parameters) Export

	If TypeOf(Result) = Type("JobSchedule") Then
		
		JobSchedule = Result;
		SetTitleScheduleExchange();
		Modified = True;
		
	EndIf;

EndProcedure

&AtClient
Procedure SetTitleScheduleExchange() 

	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.DataSeparationEnabled Then
		
		If JobSchedule = Undefined Then
			TitleText = NStr("en = 'Set the exchange schedule'; ru = 'Установить расписание обмена';pl = 'Ustaw harmonogram wymiany danych';es_ES = 'Establecer el horario de intercambio';es_CO = 'Establecer el horario de intercambio';tr = 'Değişim programını ayarla';it = 'Impostare il grafico di scambio';de = 'Zeitplan für den Austausch festlegen'");
		Else
			TitleText = JobSchedule;
		EndIf;
		
		Items.SetExchangeSchedule.Title = TitleText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			WebsiteExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
			If PeriodValue = 0 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
				
			ElsIf PeriodValue <= 300 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 5 minutes'; ru = 'Каждые 5 минут';pl = 'Co 5 minut';es_ES = 'Cada 5 minutos';es_CO = 'Cada 5 minutos';tr = '5 dakikada bir';it = 'Ogni 5 minuti';de = 'Alle 5 Minuten'");
				
			ElsIf PeriodValue <= 900 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 15 minutes'; ru = 'Каждые 15 минут';pl = 'Co 15 minut';es_ES = 'Cada 15 minutos';es_CO = 'Cada 15 minutos';tr = '15 dakikada bir';it = 'Ogni 15 minuti';de = 'Alle 15 Minuten'");
				
			ElsIf PeriodValue <= 1800 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 30 minutes'; ru = 'Раз в 30 минут';pl = 'Raz na 30 minut';es_ES = 'Una vez cada 30 minutos';es_CO = 'Una vez cada 30 minutos';tr = '30 dakikada bir';it = 'Una volta ogni 30 minuti';de = 'Alle 30 Sekunden'");
				
			ElsIf PeriodValue <= 3600 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once an hour'; ru = 'Раз в час';pl = 'Raz na godzinę';es_ES = 'Una vez cada hora';es_CO = 'Una vez cada hora';tr = 'Saatte bir';it = 'Una volta all''ora';de = 'Jede Stunde'");
				
			ElsIf PeriodValue <= 10800 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 3 hours'; ru = 'Каждые 3 часа';pl = 'Co 3 godziny';es_ES = 'Cada 3 horas';es_CO = 'Cada 3 horas';tr = '3 saatte bir';it = 'Ogni 3 ore';de = 'Alle 3 Stunden'");
				
			ElsIf PeriodValue <= 21600 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 6 hours'; ru = 'Каждые 6 часов';pl = 'Co 6 godzin';es_ES = 'Cada 6 horas';es_CO = 'Cada 6 horas';tr = '6 saatte bir';it = 'Ogni 6 ore';de = 'Alle 6 Stunden'");
				
			ElsIf PeriodValue <= 43200 Then
				
				WebsiteExchangeInterval = NStr("en = 'Every 12 hours'; ru = 'Каждые 12 часов';pl = 'Co 12 godzin';es_ES = 'Cada 12 horas';es_CO = 'Cada 12 horas';tr = '12 saatte bir';it = 'Ogni 12 ore';de = 'Alle 12 Stunden'");
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure SetTitleScheduleExchangeAtServer() 

	If Not Common.DataSeparationEnabled() Then
		
		If JobSchedule = Undefined Then
			TitleText = NStr("en = 'Set the exchange schedule'; ru = 'Установить расписание обмена';pl = 'Ustaw harmonogram wymiany danych';es_ES = 'Establecer el horario de intercambio';es_CO = 'Establecer el horario de intercambio';tr = 'Değişim programını ayarla';it = 'Impostare il grafico di scambio';de = 'Zeitplan für den Austausch festlegen'");
		Else
			TitleText = JobSchedule;
		EndIf;
		
		Items.SetExchangeSchedule.Title = TitleText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			WebsiteExchangeInterval = NStr("en = 'Once every 30 minutes'; ru = 'Раз в 30 минут';pl = 'Raz na 30 minut';es_ES = 'Una vez cada 30 minutos';es_CO = 'Una vez cada 30 minutos';tr = '30 dakikada bir';it = 'Una volta ogni 30 minuti';de = 'Alle 30 Sekunden'");
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
			If PeriodValue = 0 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 30 minutes'; ru = 'Раз в 30 минут';pl = 'Raz na 30 minut';es_ES = 'Una vez cada 30 minutos';es_CO = 'Una vez cada 30 minutos';tr = '30 dakikada bir';it = 'Una volta ogni 30 minuti';de = 'Alle 30 Sekunden'");
				
			ElsIf PeriodValue <= 300 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 5 minutes'; ru = 'Раз в 5 минут';pl = 'Raz na 5 minut';es_ES = 'Una vez cada 5 minutos';es_CO = 'Una vez cada 5 minutos';tr = '5 dakikada bir';it = 'Una volta ogni 5 minuti';de = 'Alle 5 Sekunden'");
				
			ElsIf PeriodValue <= 900 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 15 minutes'; ru = 'Раз в 15 минут';pl = 'Raz na 15 minut';es_ES = 'Una vez cada 15 minutos';es_CO = 'Una vez cada 15 minutos';tr = '15 dakikada bir';it = 'Una volta ogni 15 minuti';de = 'Alle 15 Minuten'");
				
			ElsIf PeriodValue <= 1800 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 30 minutes'; ru = 'Раз в 30 минут';pl = 'Raz na 30 minut';es_ES = 'Una vez cada 30 minutos';es_CO = 'Una vez cada 30 minutos';tr = '30 dakikada bir';it = 'Una volta ogni 30 minuti';de = 'Alle 30 Sekunden'");
				
			ElsIf PeriodValue <= 3600 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once an hour'; ru = 'Раз в час';pl = 'Raz na godzinę';es_ES = 'Una vez cada hora';es_CO = 'Una vez cada hora';tr = 'Saatte bir';it = 'Una volta all''ora';de = 'Jede Stunde'");
				
			ElsIf PeriodValue <= 10800 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once in 3 hours'; ru = 'Раз в 3 часа';pl = 'Raz na 3 godziny';es_ES = 'Una vez en 3 horas';es_CO = 'Una vez en 3 horas';tr = '3 saatte bir';it = 'Una volta ogni 3 ore';de = 'Alle 3 Stunden'");
				
			ElsIf PeriodValue <= 21600 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 6 hours'; ru = 'Раз в 6 часов';pl = 'Raz na 6 godzin';es_ES = 'Una vez cada 6 horas';es_CO = 'Una vez cada 6 horas';tr = '6 saatte bir';it = 'Una volta ogni 6 ore';de = 'Alle 6 Stunden'");
				
			ElsIf PeriodValue <= 43200 Then
				
				WebsiteExchangeInterval = NStr("en = 'Once every 12 hours'; ru = 'Раз в 12 часов';pl = 'Raz na 12 godzin';es_ES = 'Una vez cada 12 horas';es_CO = 'Una vez cada 12 horas';tr = '12 saatte bir';it = 'Una volta ogni 12 ore';de = 'Alle 12 Stunden'");
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure CheckWebSiteConnection(ConnectionSettings, WarningText)
	
	If Object.Ref.IsEmpty() Or PasswordWebsiteIsChanged Then
		PasswordFromStorage = PasswordWebsite;
	Else
		SetPrivilegedMode(True);
		PasswordFromStorage = Common.ReadDataFromSecureStorage(Object.Ref, "PasswordWebsite");
		SetPrivilegedMode(False);
	EndIf;
	
	ConnectionSettings.Insert("Password", PasswordFromStorage);
	ExchangeWithWebsite.TestSiteConnection(ConnectionSettings, WarningText);
	
EndProcedure

&AtServer
Procedure CheckWebServiceConnection(ConnectionSettings, WarningText)
	
	If Object.Ref.IsEmpty() Or PasswordIsChanged Then
		PasswordFromStorage = Password;
	Else
		SetPrivilegedMode(True);
		PasswordFromStorage = Common.ReadDataFromSecureStorage(Object.Ref, "Password");
		SetPrivilegedMode(False);
	EndIf;
	
	ConnectionSettings.Insert("Password", PasswordFromStorage);
	ExchangeWithWebsite.TestSiteConnection(ConnectionSettings, WarningText);
	
EndProcedure

&AtClient
Procedure OpenCatalogFilterForm()
	
	FormParameters = New Structure();
	FormParameters.Insert("CompositionSettingsAddress", Items.CatalogTable.CurrentData.CatalogSettingsAddress);
	FormParameters.Insert("IntegrationComponent", Object.IntegrationComponent);
	
	NotifyDescription = New NotifyDescription("ConfigureComposer", ThisObject);
	OpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	
	FormSettings = "ExchangePlan.Website.Form.FilterSettingsForm";
	OpenForm(FormSettings, FormParameters,,,,, NotifyDescription, OpeningMode)
		
EndProcedure

&AtClient
Procedure ConfigureComposer(CompositionSettings, Parameters) Export
	
	If CompositionSettings = Undefined Then
		Return;
	EndIf;
	
	SetCatalogSettings(CompositionSettings);
	
EndProcedure

&AtClient
Procedure SetCatalogSettings(CompositionSettings)
	
	CurrentData = Items.CatalogTable.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;

	CurrentData.CatalogSettingsAddress	= PutToTempStorage(CompositionSettings, UUID);
	CurrentData.CatalogSettings			= String(CompositionSettings.Filter);

EndProcedure

&AtClient
Function UniqueUUID()
	
	CurrentData = Items.CatalogTable.CurrentData;
	CatalogUUID = CurrentData.CatalogUUID;
	Found = CatalogTable.FindRows(New Structure("CatalogUUID", CatalogUUID));
	UUIDAreUnique = Found.Count() = 1;
	
	If Not UUIDAreUnique Then
		
		ClearMessages();
		
		CommonClientServer.MessageToUser(
			NStr("en = 'The website product catalog UUID must be unique.'; ru = 'Уникальный идентификатор справочника номенклатуры веб-сайта должен быть уникальным.';pl = 'Identyfikator UUID katalogu produktów strony internetowej musi być unikalny.';es_ES = 'El UUID del catálogo de productos del sitio web debe ser único.';es_CO = 'El UUID del catálogo de productos del sitio web debe ser único.';tr = 'Web sitesi ürün kataloğunun UUID''si benzersiz olmalı.';it = 'Il catalogo articoli UUID del sito web deve essere univoco.';de = 'UUID des Produktkatalogs der Webseite muss einzigartig sein.'"),
			Object.Ref,
			CommonClientServer.PathToTabularSection(
				"CatalogTable", CatalogTable.IndexOf(CurrentData) + 1,
				"CatalogUUID"));
	EndIf;
	
	Return UUIDAreUnique;
	
EndFunction

&AtClient
Procedure FillInCatalogTable(CatalogTableRow)
	
	ProcessSelectedGroupsAtServerNoContext(CatalogTableRow.Groups, AllListItemsLabel);
	
	If IsBlankString(CatalogTableRow.CatalogUUID) Then
		CatalogTableRow.CatalogUUID = String(New UUID);
	EndIf;
	
	If IsBlankString(CatalogTableRow.Catalog) Then
		CatalogTableRow.Catalog = NStr("en = 'Default website product catalog'; ru = 'Справочник номенклатуры веб-сайта по умолчанию';pl = 'Katalog produktów domyślnej strony internetowej';es_ES = 'Catálogo de productos del sitio web predeterminado';es_CO = 'Catálogo de productos del sitio web predeterminado';tr = 'Varsayılan web sitesi ürün kataloğu';it = 'Catalogo articoli predefinito del sito web';de = 'Standardprodukttkatalog der Webseite'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure ProcessSelectedGroupsAtServerNoContext(GroupsList, AllListItemsLabel)
	
	GroupsAreSelected = False;
	
	ArrayDelete = New Array;
	
	For Each ValueListItem In GroupsList Do
		
		CurrentGroup = ValueListItem.Value;
		
		If Not ValueIsFilled(CurrentGroup)
			Or (TypeOf(CurrentGroup) = Type("CatalogRef.Products")
				 And Not CurrentGroup.IsFolder) Then
			
			ArrayDelete.Add(ValueListItem);
			
		EndIf;
		
	EndDo;
	
	For Each ArrayDeleteItem In ArrayDelete Do
		GroupsList.Delete(ArrayDeleteItem);
	EndDo;
	
	ArrayDelete = New Array;
	
	For Each ValueListItem In GroupsList Do
		
		If Not ArrayDelete.Find(ValueListItem) = Undefined Then
			Continue;
		EndIf;
		
		CurrentGroup = ValueListItem.Value;
		
		For Each NestedValueListItem In GroupsList Do

			If Not ArrayDelete.Find(NestedValueListItem) = Undefined Then
				Continue;
			EndIf;
			
			If Not NestedValueListItem = ValueListItem
				And NestedValueListItem.Value = CurrentGroup Then
				
				ArrayDelete.Add(NestedValueListItem);
				
			Else
				
				If NestedValueListItem.Value.BelongsToItem(CurrentGroup) Then
					ArrayDelete.Add(NestedValueListItem);
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
	For Each ArrayDeleteItem In ArrayDelete Do
		GroupsList.Delete(ArrayDeleteItem);
	EndDo;
	
	For Each ValueListItem In GroupsList Do
		
		If ValueIsFilled(ValueListItem.Value) Then
			GroupsAreSelected = True;
			Break;
		EndIf;
		
	EndDo;
	
	If Not GroupsAreSelected Then
		GroupsList.Clear();
		GroupsList.Add(Undefined, AllListItemsLabel);
	EndIf;
	
EndProcedure

&AtServer
Procedure ExecuteActionsOnCreateOnAtServer()
	
	FillCatalogTableServer();
	SetCatalogTableParametersServer();
	
EndProcedure

&AtServer
Procedure SetCatalogTableParametersServer()
	
	ChoiceFoldersAndItems = FoldersAndItems.Folders;
	Items.CatalogTableGroups.ChoiceFoldersAndItems = ChoiceFoldersAndItems;
	
EndProcedure

&AtServer
Procedure FillCatalogTableServer()
	
	AllListItemsLabel = "(" + NStr("en = 'All'; ru = 'Все';pl = 'Wszystkie';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'") + ")";
	StoredCatalogTable = FormAttributeToValue("Object").StoredCatalogTable.Get();
	
	If Not TypeOf(StoredCatalogTable) = Type("ValueTable") Then
		
		CreateDefaultCatalogServer();
		
	Else
		
		CatalogTable.Clear();
		For Each SavedCatalogTableRow In StoredCatalogTable Do
			
			NewRow = CatalogTable.Add();
			FillPropertyValues(NewRow, SavedCatalogTableRow);
			
			If Not StoredCatalogTable.Columns.Find("SettingsStorageCatalog") = Undefined Then
				If Not SavedCatalogTableRow.SettingsStorageCatalog = Undefined Then
					
					SettingsStorageCatalog = SavedCatalogTableRow.SettingsStorageCatalog.Get();
					NewRow.CatalogSettingsAddress = PutToTempStorage(SettingsStorageCatalog, UUID);
				EndIf;
			EndIf;
			
		EndDo;
		
		If CatalogTable.Count() = 0 Then
			CreateDefaultCatalogServer();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CreateDefaultCatalogServer()
	
	NewRow = CatalogTable.Add();
	NewRow.Catalog = NStr("en = 'Main products catalog'; ru = 'Основной справочник номенклатуры';pl = 'Główny katalog produktów';es_ES = 'Catálogo de productos principales';es_CO = 'Catálogo de productos principales';tr = 'Ana ürünler kataloğu';it = 'Catalogo articoli principale';de = 'Katalog von Hauptprodukten'");
	NewRow.Groups.Add(Undefined, AllListItemsLabel);
	NewRow.CatalogUUID = String(New UUID);
	
EndProcedure

&AtClient
Procedure OnChangeExportChangesRadioButton()
	
	Object.ExportChangesOnly = (ExportChangesRadioButton = 1);
	
EndProcedure
	
&AtClient
Procedure AdvancedSettingEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Object.PartSize = Result.PartSize;
	Object.RepeatCount = Result.RepeatCount;
	Modified = True;
		
EndProcedure

&AtServer
Procedure SetConnectionPageVisibility()
	
	ConnectionStructure = Common.ObjectAttributesValues(Object.IntegrationComponent,
		"DataExchangeByWebService, DataExchangeByCommonCatalog, DataExchangeToWebsite");
	
	DataExchangeByWebServiceIsAvailable =		ConnectionStructure.DataExchangeByWebService;
	DataExchangeByCommonCatalogIsAvailable =	ConnectionStructure.DataExchangeByCommonCatalog;
	DataExchangeByFTPIsAvailable =				ConnectionStructure.DataExchangeToWebsite;
	
EndProcedure

&AtServer
Function ExchangeCompletedServer(ExchangeNode, Parameters)

	If ExchangeWithWebsiteCached.GetThisExchangePlanNode(ExchangeNode)
		Or ExchangeNode.DeletionMark Then
		Return True;
	EndIf;
	
	Parameters.Insert("ExchangeNode", ExchangeNode);
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	JobDescription = NStr("en = 'Sync with website'; ru = 'Синхронизация с веб-сайтом';pl = 'Synchronizuj ze stroną internetową';es_ES = 'Sincronizar con el sitio web';es_CO = 'Sincronizar con el sitio web';tr = 'Web sitesi ile senkronizasyon';it = 'Sincronizzazione con sito web';de = 'Synchronisieren mit Webseite'");
	
	Result = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		"ExchangeWithWebsiteEvents.ExecuteExchange",
		Parameters,
		JobDescription);
	
	Return Result;
	
EndFunction

&AtClient
Procedure Attachable_CheckJobCompletion()
	
	If JobCompleted(JobID) Then 
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Object.Ref);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Exchange with website is completed'; ru = 'Обмен с веб-сайтом завершен';pl = 'Wymiana danych ze stroną internetową została zakończona';es_ES = 'Se completa el intercambio con el sitio web';es_CO = 'Se completa el intercambio con el sitio web';tr = 'Web sitesi ile değişim tamamlandı';it = 'Scambio con sito web completato';de = 'Austausch mit Webseite ist abgeschlossen'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithWebsiteCompleted");
		
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobCompletion", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServerNoContext 
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

#EndRegion
