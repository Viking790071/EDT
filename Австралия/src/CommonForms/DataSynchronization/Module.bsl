#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CheckDataSynchronizationSettingPossibility(Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	URL = "e1cib/app/CommonForm.DataSynchronization";
	
	InitializeFormAttributes();
	
	SetFormItemsRepresentation();
	
	If CommonClientServer.IsMobileClient() Then
		
		Items.Move(Items.ApplicationsListControlGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListChangeAndCompositionGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListDataExchangeExecutionGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListExchangeScheduleGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListEventsGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListStandardGroup, Items.CommandBarForm);
		Items.Move(Items.ApplicationsListRefreshScreen, Items.CommandBarForm);
		Items.Move(Items.FormHelp, Items.CommandBarForm);
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshDashboardDataInteractively();
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If    EventName = "DataExchangeCompleted"
		Or EventName = "Write_DataExchangeScenarios"
		Or EventName = "Write_ExchangePlanNode"
		Or EventName = "ObjectMappingWizardFormClosed"
		Or EventName = "DataExchangeResultFormClosed" Then
		
		RefreshDashboardDataInBackground();
		
	ElsIf EventName = "DataExchangeCreationWizardFormClosed" Then
		
		RefreshDashboardDataInteractively();
		
	EndIf;
	
EndProcedure

#EndRegion

#Region NodesStatesListFormTableItemsEventHandlers

&AtClient
Procedure ApplicationsListSelection(Item, RowSelected, Field, StandardProcessing)
	
	CurrentData = Items.ApplicationsList.CurrentData;
		
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenSynchronizationParametersSettingsForm(CurrentData);
	
EndProcedure

&AtClient
Procedure ApplicationsListOnActivateRow(Item)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	Items.ApplicationsListInitialDataExport.Enabled =
		CurrentData.InteractiveSendingAvailable AND Not CurrentData.StartDataExchangeFromCorrespondent;
		
	Items.ApplicationsListRunSyncWithAdditionalFilters.Enabled =
		CurrentData.InteractiveSendingAvailable AND Not CurrentData.StartDataExchangeFromCorrespondent;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RunSync(Command)
	
	SynchronizationExecutionCommandProcessing();
	
EndProcedure

&AtClient
Procedure RunSyncWithAdditionalFilters(Command)
	
	SynchronizationExecutionCommandProcessing(True);
	
EndProcedure

&AtClient
Procedure ConfigureDataExchangeScenarios(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.SetExchangeExecutionScheduleCommandProcessing(CurrentData.InfobaseNode, ThisObject);
	
EndProcedure

&AtClient
Procedure RefreshScreen(Command)
	
	RefreshDashboardDataInteractively();
	
EndProcedure

&AtClient
Procedure ChangeInfobaseNode(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
		
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	OpenSynchronizationParametersSettingsForm(CurrentData);
	
EndProcedure

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	GoToEventLog("DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	GoToEventLog("DataExport");
	
EndProcedure

&AtClient
Procedure InstallUpdate(Command)
	
	DataExchangeClient.InstallConfigurationUpdate();
	
EndProcedure

&AtClient
Procedure ExchangeInfo(Command)

	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ReferenceToDetails = DetailedInformationAtServer(CurrentData.InfobaseNode);
	
	DataExchangeClient.OpenSynchronizationDetails(ReferenceToDetails);
	
EndProcedure

&AtClient
Procedure OpenDataSyncResults(Command)
	
	DataExchangeClient.OpenDataExchangeResults(UsedNodesArray(ApplicationsList));
	
EndProcedure

&AtClient
Procedure CompositionOfDataToSend(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.OpenCompositionOfDataToSend(CurrentData.InfobaseNode);
	
EndProcedure

&AtClient
Procedure CreateSyncSetting(Command)
	
	DataExchangeClient.OpenNewDataSynchronizationSettingForm(NewDataSyncForm,
		NewDataSyncFormParameters);
	
EndProcedure

&AtClient
Procedure DeleteSynchronizationSetting(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If SaaSModel 
		AND CurrentData.SynchronizationSetupInServiceManager Then
			
		ShowMessageBox(, NStr("ru = '?????? ???????????????? ?????????????????? ?????????????????????????? ???????????? ?????????????????? ?? ???????????????? ??????????????.
			|?? ?????????????????? ?????????????? ???????????????????????????? ???????????????? ""?????????????????????????? ????????????"".'; 
			|en = 'To delete synchronization data settings, go to the service manager.
			|In the service manager, click ""Data synchronization"".'; 
			|pl = 'Aby usun???? ustawienia synchronizacji danych, przejd?? do mened??era serwisu. 
			|W mened??erze serwisu u??yj polecenia ""Synchronizacja danych"".';
			|es_ES = 'Para eliminar el ajuste de sincronizaci??n de datos, pase al gestor de servicio.
			|En el gestor de servicio, utilice el comando ""Sincronizaci??n de datos"".';
			|es_CO = 'Para eliminar el ajuste de sincronizaci??n de datos, pase al gestor de servicio.
			|En el gestor de servicio, utilice el comando ""Sincronizaci??n de datos"".';
			|tr = 'Veri senkronizasyonunu ayarlamak i??in servis y??neticisine gidin. 
			|Servis y??neticisinde ""Veri Senkronizasyonu"" komutunu kullan??n.';
			|it = 'Per cancellare le impostazioni di sincronizzazione dati, andare al Manager di servizio.
			|Nel Manager di servizio, cliccare su ""Sincronizzazione dati"".';
			|de = 'Um die Einstellung f??r die Datensynchronisation zu l??schen, gehen Sie zum Service Manager.
			|Verwenden Sie im Service Manager den Befehl ""Datensynchronisation"".'"));
		
	Else
		
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangeNode",                   CurrentData.InfobaseNode);
		WizardParameters.Insert("ExchangePlanName",               CurrentData.ExchangePlanName);
		WizardParameters.Insert("CorrespondentDataArea",  CurrentData.DataArea);
		WizardParameters.Insert("CorrespondentDescription",   CurrentData.CorrespondentDescription);
		WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.DeleteSyncSetting",
			WizardParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ImportDataSyncRules(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	ExchangePlanInfo = ExchangePlanInfo(CurrentData.ExchangePlanName);
	
	If ExchangePlanInfo.ConversionRulesAreUsed Then
		DataExchangeClient.ImportDataSyncRules(ExchangePlanInfo.ExchangePlanName);
	Else
		RulesKind = PredefinedValue("Enum.DataExchangeRulesTypes.ObjectsRegistrationRules");
		
		Filter              = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, RulesKind);
		FillingValues = New Structure("ExchangePlanName, RulesKind", ExchangePlanInfo.ExchangePlanName, RulesKind);
		DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter, FillingValues, "DataExchangeRules", 
			CurrentData.InfobaseNode, "ObjectsRegistrationRules");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InitialDataExport(Command)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not SynchronizationSetupCompleted(CurrentData.InfobaseNode) Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData", CurrentData);
		
		CompletionNotification = New NotifyDescription("QuestionContinueSynchronizationSetupCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(CompletionNotification,
			NStr("ru = '?????????? ?????????????????? ???????????? ?????? ?????????????????????????? ???????????????????? ?????????????????? ?????????????????? ??????????????????????????.
			|?????????????? ?????????? ?????????????????? ???????????????????'; 
			|en = 'Before exporting data to map, set up synchronization.
			|Open the setup wizard form?'; 
			|pl = 'Przed eksportowaniem danych dla por??wnania nale??y zako??czy?? ustawienie synchronizacji. 
			|Otworzy?? formularz asystenta ustawienia?';
			|es_ES = 'Antes de subir los datos para comparar es necesario terminar el ajuste de sincronizaci??n.
			|??Abrir el formulario del ayudante de ajuste?';
			|es_CO = 'Antes de subir los datos para comparar es necesario terminar el ajuste de sincronizaci??n.
			|??Abrir el formulario del ayudante de ajuste?';
			|tr = 'Verileri kald??rmadan ??nce e??lemek i??in e??itleme ayar??n?? tamamlaman??z gerekir. 
			|Kurulum Asistan?? formunu a??mak istiyor musunuz?';
			|it = 'Prima di esportare i dati da mappare, impostare la sincronizzazione.
			|Aprire il modulo di procedura guidata di configurazione?';
			|de = 'Die Synchronisationseinstellung muss abgeschlossen sein, bevor die Daten zum Vergleich hochgeladen werden.
			|Das Setup-Assistent Formular ??ffnen?'"),
			QuestionDialogMode.YesNo);
	ElsIf Not CurrentData.InteractiveSendingAvailable Then
		ShowMessageBox(, NStr("ru = '?????? ???????????????????? ???????????????? ?????????????????? ?????????????????????????? ???????????????? ???????????? ?????? ?????????????????????????? ???? ????????????????????????????.'; en = 'Synchronization of exporting the data to map is not supported for the selected setting option.'; pl = 'Dla wybranego wariantu ustawienia synchronizacji eksportowanie danych dla por??wnania nie jest obs??ugiwane.';es_ES = 'Para la opci??n seleccionada del ajuste de sincronizaci??n la subida de datos para comparar no se admite.';es_CO = 'Para la opci??n seleccionada del ajuste de sincronizaci??n la subida de datos para comparar no se admite.';tr = 'Se??ilen e??le??tirme ayar?? se??ene??i i??in, e??leme i??in veri y??kleme desteklenmez.';it = 'La sincronizzazione dell''esportazione dei dati da mappare non ?? supportata per l''opzione di impostazione selezionata.';de = 'Der Export von Daten zum Vergleich wird f??r die gew??hlte Synchronisationseinstellung nicht unterst??tzt.'"));
		Return;
	Else
		WizardParameters = New Structure;
		WizardParameters.Insert("ExchangeNode", CurrentData.InfobaseNode);
		WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		WizardParameters.Insert("CorrespondentDataArea", CurrentData.DataArea);
		
		ClosingNotification = New NotifyDescription("InitialDataExportCompletion", ThisObject);
		OpenForm("DataProcessor.InteractiveDataExchangeWizard.Form.ExportMappingData",
			WizardParameters, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Dull font color is used for configured but never run synchronization.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePresentation.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.StatePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = '???? ????????????????????'; en = 'Not started'; pl = 'Nie by??o wykonywane';es_ES = 'No se lanzaba';es_CO = 'No se lanzaba';tr = 'Ba??lat??lmad??';it = 'Non avviato';de = 'Nicht gestartet'");
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	// "N/a" text and a dull font color for the missing prefix of the correspondent application.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListCorrespondentPrefix.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.CorrespondentPrefix");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotFilled;
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", "noncommercial/village");
	
	// Special font color of the synchronization with incomplete setup.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePresentation.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.StatePresentation");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = NStr("ru = '?????????????????? ???? ??????????????????'; en = 'Setup is not complete'; pl = 'Ustawienie nie jest zako??czone';es_ES = 'Ajuste no terminado';es_CO = 'Ajuste no terminado';tr = 'Ayarlar tamamlanmad??';it = 'Le impostazioni non sono complete';de = 'Setup nicht abgeschlossen'");
	Item.Appearance.SetParameterValue("TextColor", WebColors.DarkRed);
	
	// Hiding a blank picture of data synchronization state.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListStatePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.StatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	// Hiding a blank picture of data export state.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListExportStatePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.ExportStatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
	
	// Hiding a blank picture of data import state.
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ApplicationsListImportStatePicture.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ApplicationsList.ImportStatePicture");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("Show", False);
		
EndProcedure

&AtClient
Procedure QuestionContinueSynchronizationSetupCompletion(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		OpenSynchronizationParametersSettingsForm(AdditionalParameters.CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InitialDataExportCompletion(ClosingResult, AdditionalParameters) Export
	
	AttachIdleHandler("RefreshDashboardDataInBackground", 0.1, True);
	
EndProcedure

&AtClient
Procedure OpenSynchronizationParametersSettingsForm(CurrentData)
	
	WizardParameters = New Structure;
	
	ClosingNotification = New NotifyDescription("OpenSynchronizationParametersSettingsFormCompletion", ThisObject);
	
	If SynchronizationSetupCompleted(CurrentData.InfobaseNode) Then
		
		WizardParameters.Insert("Key", CurrentData.InfobaseNode);
		WizardParameters.Insert("WizardFormName", "ExchangePlan.[ExchangePlanName].ObjectForm");
		
		WizardParameters.WizardFormName = StrReplace(WizardParameters.WizardFormName,
			"[ExchangePlanName]", CurrentData.ExchangePlanName);
		
		OpenForm(WizardParameters.WizardFormName,
			WizardParameters, ThisObject, , , , ClosingNotification);
		
	Else
		
		WizardParameters.Insert("ExchangeNode", CurrentData.InfobaseNode);
		
		If SaaSModel Then
			WizardParameters.Insert("CorrespondentDataArea",  CurrentData.DataArea);
			WizardParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		EndIf;
		
		OpenForm("DataProcessor.DataExchangeCreationWizard.Form.SyncSetup",
			WizardParameters, ThisObject, , , , , FormWindowOpeningMode.Independent);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenSynchronizationParametersSettingsFormCompletion(ClosingResult, AdditionalParameters) Export
	
	AttachIdleHandler("RefreshDashboardDataInBackground", 0.1, True);
	
EndProcedure

&AtClient
Procedure SynchronizationExecutionCommandProcessing(UseAdditionalFilters = False)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If Not SynchronizationSetupCompleted(CurrentData.InfobaseNode) Then
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("CurrentData", CurrentData);
		
		CompletionNotification = New NotifyDescription("QuestionContinueSynchronizationSetupCompletion", ThisObject, AdditionalParameters);
		ShowQueryBox(CompletionNotification,
			NStr("ru = '?????????? ???????????????? ?????????????????????????? ???????????? ???????????????????? ?????????????????? ???? ??????????????????.
			|?????????????? ?????????? ?????????????????? ???????????????????'; 
			|en = 'Before starting data synchronization, complete its setup.
			|Open the setup wizard form?'; 
			|pl = 'Przed uruchomieniem synchronizacji nale??y zako??czy?? jej ustawienie. 
			|Otworzy?? formularz asystenta ustawienia?';
			|es_ES = 'Antes de lanzar la sincronizaci??n de datos es necesario terminar su ajuste,
			|??Abrir el formulario del ayudante de ajuste?';
			|es_CO = 'Antes de lanzar la sincronizaci??n de datos es necesario terminar su ajuste,
			|??Abrir el formulario del ayudante de ajuste?';
			|tr = 'Verileri e??le??tirmeye ba??lamadan ??nce, yap??land??rma tamamlanmal??d??r. 
			| Kurulum Asistan?? formunu a??mak istiyor musunuz?';
			|it = 'Prima di avviare la sincronizzazione dati, completare la configuraizone.
			|Aprire il modulo di procedura guidata di configurazione?';
			|de = 'Bevor Sie mit der Datensynchronisation beginnen, m??ssen Sie die Konfiguration abschlie??en.
			|Das Formular Setup Assistent ??ffnen?'"),
			QuestionDialogMode.YesNo);
	ElsIf CurrentData.StartDataExchangeFromCorrespondent
		AND Not CurrentData.EmailReceivedForDataMapping Then
		ShowMessageBox(, StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '???????????? ?????????????????????????? ?? ""%1"" ???? ???????? ?????????????????? ???? ????????????????????????????.
			|?????????????????? ?? ""%1"" ?? ?????????????????? ?????????????????????????? ???? ??????.'; 
			|en = 'Synchronization start with ""%1"" from this application is not supported.
			|Go to ""%1"" and start synchronization from it.'; 
			|pl = 'Uruchomienie synchronizacji z ""%1"" z tego programu nie jest obs??ugiwane. 
			|Przejd?? do ""%1"" i uruchom synchronizacj?? z niego.';
			|es_ES = 'El lanzamiento de sincronizaci??n con ""%1"" de este programa no se admiten.
			|Pase a ""%1"" y lance de all?? la sincronizaci??n.';
			|es_CO = 'El lanzamiento de sincronizaci??n con ""%1"" de este programa no se admiten.
			|Pase a ""%1"" y lance de all?? la sincronizaci??n.';
			|tr = 'Bu uygulamadan ""%1"" ''den e??le??tirmesi ba??lat??lam??yor.
			| ""%1"" ''e ge??in ve e??le??tirmeyi oradan ba??lat??n.';
			|it = 'L''avvio di sincronizzazione con ""%1"" da questa applicazione non ?? supportato.
			|Andare in ""%1"" e avviare da l?? la sincronizzazione.';
			|de = 'Das Starten der Synchronisation mit ""%1"" aus diesem Programm wird nicht unterst??tzt.
			|Gehen Sie zu ""%1"" und starten Sie die Synchronisation daraus.'"), CurrentData.CorrespondentDescription));
	Else
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ExchangeNode",     CurrentData.InfobaseNode);
		AdditionalParameters.Insert("ExchangePlanName", CurrentData.ExchangePlanName);
		
		AdditionalParameters.Insert("IsExchangeWithApplicationInService", CurrentData.IsExchangeWithApplicationInService);
		AdditionalParameters.Insert("CorrespondentDataArea",  CurrentData.DataArea);
		
		AdditionalParameters.Insert("UseAdditionalFilters",                   UseAdditionalFilters);
		AdditionalParameters.Insert("InteractiveSendingAvailable",           CurrentData.InteractiveSendingAvailable);
		AdditionalParameters.Insert("DataExchangeOption",                    CurrentData.DataExchangeOption);
		AdditionalParameters.Insert("EmailReceivedForDataMapping", CurrentData.EmailReceivedForDataMapping);
		AdditionalParameters.Insert("StartDataExchangeFromCorrespondent",            CurrentData.StartDataExchangeFromCorrespondent);
		
		ContinuationDetails = New NotifyDescription("ContinueSynchronizationExecution", ThisObject, AdditionalParameters);
			
		If CurrentData.IsExchangeWithApplicationInService Then
			ExecuteNotifyProcessing(ContinuationDetails);
		Else
			CheckConversionRulesCompatibility(ContinuationDetails);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure CheckDataSynchronizationSettingPossibility(Cancel = False)
	
	MessageText = "";
	If Common.DataSeparationEnabled() Then
		If Common.SeparatedDataUsageAvailable() Then
			ModuleDataExchangeSaaSCashed = Common.CommonModule("DataExchangeSaaSCached");
			If Not ModuleDataExchangeSaaSCashed.DataSynchronizationSupported() Then
		 		MessageText = NStr("ru = '?????????????????????? ?????????????????? ?????????????????????????? ???????????? ?? ???????????? ?????????????????? ???? ??????????????????????????.'; en = 'Data synchronization setup is not supported in this application.'; pl = 'Mo??liwo???? ustawienia synchronizacji danych w tym programie nie jest przewidziana.';es_ES = 'Posibilidad de ajustar la sincronizaci??n de datos en este programa no est?? prevista.';es_CO = 'Posibilidad de ajustar la sincronizaci??n de datos en este programa no est?? prevista.';tr = 'Bu programda veri e??le??mesi ayarlar?? yap??land??r??lamaz.';it = 'L''impostazione della sincronizzazione dati non ?? supportata in questa applicazione.';de = 'Die M??glichkeit, in diesem Programm eine Datensynchronisation einzurichten, ist nicht vorgesehen.'");
				Cancel = True;
			EndIf;
		Else
			MessageText = NStr("ru = '?? ?????????????????????????? ???????????? ?????????????????? ?????????????????????????? ???????????? ?? ?????????????? ?????????????????????? ????????????????????.'; en = 'Setup of data synchronization with other applications in undivided mode is unavailable.'; pl = 'W niepodzielonym trybie ustawienie synchronizacji danych z innymi programami jest niedost??pne.';es_ES = 'En el modo no distribuido el ajuste de sincronizaci??n de datos con otro programa no est?? disponible.';es_CO = 'En el modo no distribuido el ajuste de sincronizaci??n de datos con otro programa no est?? disponible.';tr = 'B??l??nmemi?? modda, di??er programlarla veri e??le??tirmesi ayarlar?? kullan??lamaz.';it = 'L''impostazione della sincronizzazione dati con altre applicazioni in modalit?? non divisa non ?? disponibile.';de = 'Die Einrichtung der Datensynchronisation mit anderen Programmen ist im ungeteilten Modus nicht m??glich.'");
			Cancel = True;
		EndIf;
	Else
		ExchangePlanList = DataExchangeCached.SSLExchangePlans();
		If ExchangePlanList.Count() = 0 Then
			MessageText = NStr("ru = '?????????????????????? ?????????????????? ?????????????????????????? ???????????? ?? ???????????? ?????????????????? ???? ??????????????????????????.'; en = 'Data synchronization setup is not supported in this application.'; pl = 'Mo??liwo???? ustawienia synchronizacji danych w tym programie nie jest przewidziana.';es_ES = 'Posibilidad de ajustar la sincronizaci??n de datos en este programa no est?? prevista.';es_CO = 'Posibilidad de ajustar la sincronizaci??n de datos en este programa no est?? prevista.';tr = 'Bu programda veri e??le??mesi ayarlar?? yap??land??r??lamaz.';it = 'L''impostazione della sincronizzazione dati non ?? supportata in questa applicazione.';de = 'Die M??glichkeit, in diesem Programm eine Datensynchronisation einzurichten, ist nicht vorgesehen.'");
			Cancel = True;
		EndIf;
	EndIf;
	
	If Cancel
		AND Not IsBlankString(MessageText) Then
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function SynchronizationSetupCompleted(ExchangeNode)
	
	Return DataExchangeServer.SynchronizationSetupCompleted(ExchangeNode);
	
EndFunction

&AtServerNoContext
Function ExchangePlanInfo(ExchangePlanName)
	
	Result = New Structure;
	Result.Insert("ExchangePlanName", ExchangePlanName);
	Result.Insert("ConversionRulesAreUsed",
		DataExchangeCached.HasExchangePlanTemplate(ExchangePlanName, "ExchangeRules"));
	
	Return Result;
	
EndFunction

&AtClient
Procedure GoToEventLog(ActionOnExchange)
	
	CurrentData = Items.ApplicationsList.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	DataExchangeClient.GoToDataEventLogModally(CurrentData.InfobaseNode,
		ThisObject, ActionOnExchange);

EndProcedure

&AtClient
Procedure RefreshDashboardDataInteractively()
	
	ApplicationsListLineIndex = GetCurrentRowIndex("ApplicationsList");
	
	If SaaSModel Then
		OnDashboardDataUpdateStart();
	Else
		RefreshApplicationsList();
	EndIf;
	
	ExecuteCursorPositioning("ApplicationsList", ApplicationsListLineIndex);
	
	AttachIdleHandler("RefreshDashboardDataInBackground", 60, True);
	
EndProcedure

&AtClient
Procedure RefreshDashboardDataInBackground()
	
	ApplicationsListLineIndex = GetCurrentRowIndex("ApplicationsList");
	
	RefreshApplicationsList();
	
	ExecuteCursorPositioning("ApplicationsList", ApplicationsListLineIndex);
	
	AttachIdleHandler("RefreshDashboardDataInBackground", 60, True);
	
EndProcedure

&AtClient
Procedure OnDashboardDataUpdateStart()
	
	If Not ParametersOfGetApplicationsListIdleHandler = Undefined Then
		Return;
	EndIf;
	
	ParametersOfGetApplicationsListHandler = Undefined;
	ContinueWait = False;
	
	OnStartGettingApplicationsListAtServer(
		ParametersOfGetApplicationsListHandler, ContinueWait);
		
	If ContinueWait Then
		
		Items.ApplicationsListPanel.CurrentPage = Items.WaitPage;
		Items.CommandBar.Enabled = False;
		
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			ParametersOfGetApplicationsListIdleHandler);
			
		AttachIdleHandler("OnWaitForDashboardDataRefresh",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
		
	Else
		OnCompleteDashboardDataRefresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForDashboardDataRefresh()
	
	ContinueWait = False;
	OnWaitGettingApplicationsListAtServer(ParametersOfGetApplicationsListHandler, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(ParametersOfGetApplicationsListIdleHandler);
		
		AttachIdleHandler("OnWaitForDashboardDataRefresh",
			ParametersOfGetApplicationsListIdleHandler.CurrentInterval, True);
	Else
		ParametersOfGetApplicationsListIdleHandler = Undefined;
		OnCompleteDashboardDataRefresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDashboardDataRefresh()
	
	OnCompleteGettingApplicationsListAtServer();
	
	Items.ApplicationsListPanel.CurrentPage = Items.ApplicationsListPage;
	Items.CommandBar.Enabled = True;
	
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
Procedure OnCompleteGettingApplicationsListAtServer()
	
	SaaSApplications.Clear();
	
	ModuleSetupWizard = DataExchangeServer.ModuleDataSynchronizationBetweenWebApplicationsSetupWizard();
	
	If Not ModuleSetupWizard = Undefined Then
		CompletionStatus = Undefined;
		ModuleSetupWizard.OnCompleteGetApplicationList(
			ParametersOfGetApplicationsListHandler, CompletionStatus);
			
		If Not CompletionStatus.Cancel Then
			ApplicationsTable = CompletionStatus.Result;
			SaaSApplications.Load(CompletionStatus.Result.Copy(, "Correspondent, DataArea, ApplicationDescription"));
		EndIf;
	EndIf;
	
	RefreshApplicationsList();
	
EndProcedure

&AtServer
Procedure RefreshApplicationsList()
	
	Items.ApplicationsListPanel.CurrentPage = Items.ApplicationsListPage;
	Items.CommandBar.Enabled = True;
	
	SSLExchangePlans = DataExchangeCached.SSLExchangePlans();
	
	DashboardTable = DataExchangeServer.DataExchangeMonitorTable(SSLExchangePlans);
	ApplicationsList.Load(DashboardTable);
	
	HasConfiguredExchanges = (ApplicationsList.Count() > 0);
	
	For Each ApplicationRow In ApplicationsList Do
		
		ApplicationRow.CorrespondentDescription = Common.ObjectAttributeValue(
			ApplicationRow.InfobaseNode, "Description");
			
		SaaSApplicationRows = SaaSApplications.FindRows(
			New Structure("Correspondent", ApplicationRow.InfobaseNode));
			
		If SaaSApplicationRows.Count() > 0 Then
			SaaSApplicationRow = SaaSApplicationRows[0];
			
			ApplicationRow.IsExchangeWithApplicationInService = True;
			ApplicationRow.DataArea = SaaSApplicationRow.DataArea;
			ApplicationRow.CorrespondentDescription = SaaSApplicationRow.ApplicationDescription;
		EndIf;
		
		If ApplicationRow.IsExchangeWithApplicationInService Then
			
			ApplicationRow.ApplicationOperationMode = 1;
			ApplicationRow.InteractiveSendingAvailable = True;
			
		Else
			
			TransportKind = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(
				ApplicationRow.InfobaseNode);
			ApplicationRow.ApplicationOperationMode = ?(TransportKind = Enums.ExchangeMessagesTransportTypes.WS,
				1, 0);
				
			If Not ValueIsFilled(TransportKind)
				Or (TransportKind = Enums.ExchangeMessagesTransportTypes.WSPassiveMode) Then
				// Exchange with this infobase is set up via WS.
				ApplicationRow.StartDataExchangeFromCorrespondent = True;
			EndIf;
			
			ApplicationRow.InteractiveSendingAvailable =
				Not DataExchangeCached.IsDistributedInfobaseExchangePlan(ApplicationRow.ExchangePlanName)
				AND Not DataExchangeCached.IsStandardDataExchangeNode(ApplicationRow.ExchangePlanName);
			
		EndIf;
		
		ApplicationRow.InteractiveSendingAvailable = ApplicationRow.InteractiveSendingAvailable
			AND Not (ApplicationRow.DataExchangeOption = "ReceiveOnly");
		
		SettingID = DataExchangeServer.SavedExchangePlanNodeSettingOption(
			ApplicationRow.InfobaseNode);
		
		ApplicationRow.DataSyncSettingsWizardFormName = DataExchangeServer.ExchangePlanSettingValue(ApplicationRow.ExchangePlanName,
			"DataSyncSettingsWizardFormName",
			SettingID,
			ApplicationRow.CorrespondentVersion);
		
		SynchronizationState = DataSynchronizationState(ApplicationRow);
		ApplicationRow.StatePresentation = SynchronizationState.Presentation;
		ApplicationRow.StatePicture      = SynchronizationState.Picture;
		
		If ValueIsFilled(ApplicationRow.LastRunDate) Then
			ApplicationRow.ExportStatePicture = ExecutionResultPicture(ApplicationRow.LastDataExportResult);
			
			If Not ApplicationRow.EmailReceivedForDataMapping Then
				ApplicationRow.ImportStatePicture = ExecutionResultPicture(ApplicationRow.LastDataImportResult);
			EndIf;
		Else
			// The Never label is not shown if synchronization has never run not to overload the interface.
			// 
			ApplicationRow.LastSuccessfulExportDatePresentation = "";
			ApplicationRow.LastSuccessfulImportDatePresentation = "";
		EndIf;
		
		If ApplicationRow.EmailReceivedForDataMapping Then
			// If data for mapping is received, display the message receiving date.
			ApplicationRow.LastSuccessfulImportDatePresentation = ApplicationRow.MessageDatePresentationForDataMapping;
			ApplicationRow.ImportStatePicture = 5;
		EndIf;
		
	EndDo;
	
	UpdateRequired = DataExchangeServerCall.UpdateInstallationRequired();
	
	SetFormItemsRepresentation();
	
	RefreshSynchronizationResultsCommand();
	
EndProcedure

&AtServerNoContext
Function DataSynchronizationState(ApplicationRow)
	
	State = New Structure;
	State.Insert("Presentation", "");
	State.Insert("Picture",      0);
	
	If Not ApplicationRow.SetupCompleted Then
		State.Presentation = NStr("ru = '?????????????????? ???? ??????????????????'; en = 'Setup is not complete'; pl = 'Ustawienie nie jest zako??czone';es_ES = 'Ajuste no terminado';es_CO = 'Ajuste no terminado';tr = 'Ayarlar tamamlanmad??';it = 'Le impostazioni non sono complete';de = 'Setup nicht abgeschlossen'");
		State.Picture = 3;
		
		If ApplicationRow.EmailReceivedForDataMapping Then
			State.Presentation = NStr("ru = '?????????????????? ???? ??????????????????, ???????????????? ???????????? ?????? ??????????????????????????'; en = 'Setup is not complete. Data to map is received.'; pl = 'Ustawienie nie jest zako??czone, odebrane dane do por??wnania';es_ES = 'Ajuste no finalizado, datos recibidos para comparar';es_CO = 'Ajuste no finalizado, datos recibidos para comparar';tr = 'Ayarlar tamamlanmad??, kar????la??t??r??lacak veriler elde edildi';it = 'Configurazione non completata. Dati da mappare ricevuti.';de = 'Konfiguration nicht abgeschlossen, Vergleichsdaten empfangen'");
		EndIf;
	Else
		If ApplicationRow.LastImportStartDate > ApplicationRow.LastImportEndDate Then
			State.Presentation = NStr("ru = '???????????????? ????????????...'; en = 'Importing data...'; pl = 'Import danych...';es_ES = 'Importando los datos...';es_CO = 'Importando los datos...';tr = 'Veriler i??e aktar??l??yor...';it = 'Importazione di dati ...';de = 'Daten importieren...'");
			State.Picture = 4;
		ElsIf ApplicationRow.LastExportStartDate > ApplicationRow.LastExportEndDate Then
			State.Presentation = NStr("ru = '???????????????? ????????????...'; en = 'Exporting data ...'; pl = 'Eksport danych...';es_ES = 'Exportando los datos...';es_CO = 'Exportando los datos...';tr = 'Veriler d????a aktar??l??yor...';it = 'Esportazione dei dati ...';de = 'Daten exportieren...'");
			State.Picture = 4;
		ElsIf Not ValueIsFilled(ApplicationRow.LastRunDate) Then
			State.Presentation = NStr("ru = '???? ????????????????????'; en = 'Not started'; pl = 'Nie by??o wykonywane';es_ES = 'No se lanzaba';es_CO = 'No se lanzaba';tr = 'Ba??lat??lmad??';it = 'Non avviato';de = 'Nicht gestartet'");
			
			If ApplicationRow.EmailReceivedForDataMapping Then
				State.Presentation = NStr("ru = '???????????????? ???????????? ?????? ??????????????????????????'; en = 'Data for mapping was received'; pl = 'Odebrane dane do por??wnania';es_ES = 'Datos recibidos para comparar';es_CO = 'Datos recibidos para comparar';tr = 'Kar????la??t??r??lacak veriler elde edildi';it = 'Dati per la mattatura sono stati ricevuti';de = 'Daten stehen zu Mapping zur Verf??gung'");
			EndIf;
		Else
			State.Presentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????????? ????????????: %1'; en = 'Last start: %1'; pl = 'Poprzednie uruchomienie: %1';es_ES = 'Lanzamiento anterior: %1';es_CO = 'Lanzamiento anterior: %1';tr = 'Ge??mi?? ba??latma: %1';it = 'Ultimo avvio: %1';de = 'Letzter Start: %1'"),
				ApplicationRow.LastStartDatePresentation);
				
			If ApplicationRow.EmailReceivedForDataMapping Then
				State.Presentation = NStr("ru = '???????????????? ???????????? ?????? ??????????????????????????'; en = 'Data for mapping was received'; pl = 'Odebrane dane do por??wnania';es_ES = 'Datos recibidos para comparar';es_CO = 'Datos recibidos para comparar';tr = 'Kar????la??t??r??lacak veriler elde edildi';it = 'Dati per la mattatura sono stati ricevuti';de = 'Daten stehen zu Mapping zur Verf??gung'");
			EndIf;
		EndIf;
	EndIf;
	
	Return State;
	
EndFunction

&AtServerNoContext
Function ExecutionResultPicture(ExecutionResult)
	
	If ExecutionResult = 2 Then
		Return 3; // completed with warnings
	ElsIf ExecutionResult = 1 Then
		Return 2; // error
	ElsIf ExecutionResult = 0 Then
		Return 0; // success
	EndIf;
	
	// without status
	Return 0;
	
EndFunction

&AtServer
Procedure InitializeFormAttributes()
	
	HasExchangeAdministrationRight   = DataExchangeServer.HasRightsToAdministerExchanges();
	
	HasEventLogViewRight = AccessRight("EventLog", Metadata);
	HasRightToUpdate                 = AccessRight("UpdateDataBaseConfiguration", Metadata);
	
	IBPrefix = DataExchangeServer.InfobasePrefix();
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
	
EndProcedure

&AtServer
Procedure SetFormItemsRepresentation()
	
	// Command bar.
	Items.ApplicationsListControlGroup.Visible                 = HasExchangeAdministrationRight;
	Items.ApplicationsListChangeAndCompositionGroup.Visible           = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	Items.ApplicationsListDataExchangeExecutionGroup.Visible    = HasConfiguredExchanges;
	Items.ApplicationsListExchangeScheduleGroup.Visible = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	Items.ApplicationsListEventsGroup.Visible                    = HasEventLogViewRight AND HasConfiguredExchanges;
	Items.ApplicationsListDeleteSyncSetting.Visible    = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	
	// Context menu.
	Items.ApplicationsListContextMenuChangeAndContentGroup.Visible           = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	Items.ApplicationsListContextMenuDataExchangeExecutionGroup.Visible    = HasConfiguredExchanges;
	Items.ApplicationsListContextMenuDataExchangeScheduleGroup.Visible = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	Items.ApplicationsListContextMenuEventsGroup.Visible                    = HasEventLogViewRight AND HasConfiguredExchanges;
	Items.ApplicationsListContextMenuControlGroup.Visible                 = HasExchangeAdministrationRight AND HasConfiguredExchanges;
	
	// Item visibility in the form header.
	Items.InfoPanelUpdateRequired.Visible = UpdateRequired;
	
	// Availability of items in the form header.
	Items.OpenDataSyncResults.Enabled = HasConfiguredExchanges;
	
	// Force disabling of visibility of commands of schedule setup and importing rules in SaaS.
	If SaaSModel Then
		
		// Command bar.
		Items.ApplicationsListImportDataSyncRules.Visible = False;
		Items.ApplicationsListExchangeScheduleGroup.Visible    = False;
		
		// Context menu.
		Items.ApplicationsListContextMenuDataExchangeScheduleGroup.Visible = False;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshSynchronizationResultsCommand()
	
	TitleStructure = DataExchangeServer.IssueMonitorHyperlinkTitleStructure(
		UsedNodesArray(ApplicationsList));
	FillPropertyValues(Items.OpenDataSyncResults, TitleStructure);
	
EndProcedure

&AtClientAtServerNoContext
Function UsedNodesArray(DashboardTable)
	
	Result = New Array;
	
	For Each DashboardRow In DashboardTable Do
		Result.Add(DashboardRow.InfobaseNode);
	EndDo;
	
	Return Result;
	
EndFunction

&AtClient
Function GetCurrentRowIndex(TableName)
	
	// Function return value.
	RowIndex = Undefined;
	
	// Placing a mouse pointer upon refreshing the dashboard.
	CurrentData = Items[TableName].CurrentData;
	
	If CurrentData <> Undefined Then
		
		RowIndex = ThisObject[TableName].IndexOf(CurrentData);
		
	EndIf;
	
	Return RowIndex;
	
EndFunction

&AtClient
Procedure ExecuteCursorPositioning(TableName, RowIndex)
	
	If RowIndex <> Undefined Then
		
		// Checking the mouse pointer position once the new data is received.
		If ThisObject[TableName].Count() <> 0 Then
			
			If RowIndex > ThisObject[TableName].Count() - 1 Then
				
				RowIndex = ThisObject[TableName].Count() - 1;
				
			EndIf;
			
			// placing the mouse pointer
			Items[TableName].CurrentRow = ThisObject[TableName][RowIndex].GetID();
			
		EndIf;
		
	EndIf;
	
	// If the row positioning failed, the first row is set as the current one.
	If Items[TableName].CurrentRow = Undefined
		AND ThisObject[TableName].Count() <> 0 Then
		
		Items[TableName].CurrentRow = ThisObject[TableName][0].GetID();
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function DetailedInformationAtServer(ExchangeNode)
	
	ExchangePlanName = ExchangeNode.Metadata().Name;
	
	ExchangeSettingsOption = DataExchangeServer.SavedExchangePlanNodeSettingOption(ExchangeNode);
	CorrespondentVersion   = DataExchangeServer.CorrespondentVersion(ExchangeNode);
	
	ReferenceToDetails = DataExchangeServer.ExchangePlanSettingValue(
		ExchangePlanName, "ExchangeDetailedInformation", ExchangeSettingsOption, CorrespondentVersion);
	
	Return ReferenceToDetails;
	
EndFunction

&AtClient
Procedure OpenInteractiveSynchronizationWizard(AdditionalParameters)
	
	WizardParameters = New Structure;
	WizardParameters.Insert("IsExchangeWithApplicationInService", AdditionalParameters.IsExchangeWithApplicationInService);
	WizardParameters.Insert("CorrespondentDataArea",  AdditionalParameters.CorrespondentDataArea);
	
	WizardParameters.Insert("SendData", Not AdditionalParameters.StartDataExchangeFromCorrespondent);
	WizardParameters.Insert("ExportAdditionMode",
		AdditionalParameters.UseAdditionalFilters Or AdditionalParameters.DataExchangeOption = "ReceiveAndSend");
	
	WizardParameters.Insert("ScheduleSetup", False);
	
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters", WizardParameters);
	
	DataExchangeClient.OpenObjectsMappingWizardCommandProcessing(AdditionalParameters.ExchangeNode,
		ThisObject, AuxiliaryParameters);
	
EndProcedure

&AtClient
Procedure OpenAutomaticSynchronizationWizard(AdditionalParameters)
	
	WizardParameters = New Structure;	
	WizardParameters.Insert("IsExchangeWithApplicationInService", AdditionalParameters.IsExchangeWithApplicationInService);
	WizardParameters.Insert("CorrespondentDataArea",  AdditionalParameters.CorrespondentDataArea);
		
	AuxiliaryParameters = New Structure;
	AuxiliaryParameters.Insert("WizardParameters", WizardParameters);
		
	DataExchangeClient.ExecuteDataExchangeCommandProcessing(AdditionalParameters.ExchangeNode,
		ThisObject, , True, AuxiliaryParameters);
	
EndProcedure

&AtClient
Procedure ContinueSynchronizationExecution(Result, AdditionalParameters) Export
	
	If AdditionalParameters.EmailReceivedForDataMapping Then
		
		OpenInteractiveSynchronizationWizard(AdditionalParameters);
			
	Else
		
		If Not AdditionalParameters.InteractiveSendingAvailable
			Or (AdditionalParameters.DataExchangeOption = "Synchronization"
				AND Not AdditionalParameters.UseAdditionalFilters) Then
			
			OpenAutomaticSynchronizationWizard(AdditionalParameters);
			
		Else
			
			OpenInteractiveSynchronizationWizard(AdditionalParameters);
				
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckConversionRulesCompatibility(ContinuationHandler)
	
	ErrorDescription = Undefined;
	If ConversionRulesCompatibleWithCurrentVersion(ContinuationHandler.AdditionalParameters.ExchangePlanName, ErrorDescription) Then
		
		ExecuteNotifyProcessing(ContinuationHandler);
		
	Else
		
		Buttons = New ValueList;
		Buttons.Add("GoToRuleImport", NStr("ru = '?????????????????? ??????????????'; en = 'Import rules'; pl = 'Zaimportowa?? regu??y';es_ES = 'Importar las reglas';es_CO = 'Importar las reglas';tr = 'Kurallar?? i??e aktar';it = 'Importare regole';de = 'Regeln importieren'"));
		If ErrorDescription.ErrorKind <> "InvalidConfiguration" Then
			Buttons.Add("Continue", NStr("ru = '????????????????????'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
		EndIf;
		Buttons.Add("Cancel", NStr("ru = '????????????'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = '??ptal et';it = 'Annulla';de = 'Abbrechen'"));
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("ContinuationHandler", ContinuationHandler);
		AdditionalParameters.Insert("ExchangePlanName",       ContinuationHandler.AdditionalParameters.ExchangePlanName);
		
		Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.SuggestDontAskAgain = False;
		If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
			FormParameters.Title = NStr("ru = '?????????????????????????? ???????????? ???? ?????????? ???????? ??????????????????'; en = 'The synchronization cannot be completed.'; pl = 'Synchronizacja danych nie mo??e zosta?? wykonana';es_ES = 'Sincronizaci??n de datos no puede ejecutarse';es_CO = 'Sincronizaci??n de datos no puede ejecutarse';tr = 'Veri senkronizasyonu yap??lam??yor';it = 'La sincronizzazione non pu?? essere completata.';de = 'Die Datensynchronisation kann nicht ausgef??hrt werden'");
		Else
			FormParameters.Title = NStr("ru = '?????????????????????????? ???????????? ?????????? ???????? ?????????????????? ??????????????????????'; en = 'The synchronization may be completed incorrectly.'; pl = 'Synchronizacja danych mo??e by?? wykonana niepoprawnie';es_ES = 'Sincronizaci??n de datos puede ejecutarse de forma incorrecta';es_CO = 'Sincronizaci??n de datos puede ejecutarse de forma incorrecta';tr = 'Senkronizasyon hatal?? tamamlanabilir.';it = 'La sincronizzazione potrebbe essere stata completata non correttamente.';de = 'Datensynchronisierung wird m??glicherweise falsch ausgef??hrt'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		If Result.Value = "Continue" Then
			
			ExecuteNotifyProcessing(AdditionalParameters.ContinuationHandler);
			
		ElsIf Result.Value = "GoToRuleImport" Then
			
			DataExchangeClient.ImportDataSyncRules(AdditionalParameters.ExchangePlanName);
			
		EndIf; // No action is required if the value is "Cancel".
		
	EndIf;
	
EndProcedure

&AtServer
Function ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription)
	
	RulesData = Undefined;
	If Not ConversionRulesImportedFromFile(ExchangePlanName, RulesData) Then
		Return True;
	EndIf;
	
	Return InformationRegisters.DataExchangeRules.ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName,
		ErrorDescription, RulesData);
		
EndFunction

&AtServer
Function ConversionRulesImportedFromFile(ExchangePlanName, RulesInformation)
	
	SetPrivilegedMode(True);
	
	Query = New Query(
	"SELECT
	|	DataExchangeRules.RulesAreRead,
	|	DataExchangeRules.RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		RulesStructure = Selection.RulesAreRead.Get().Conversion;
		
		RulesInformation = New Structure;
		RulesInformation.Insert("ConfigurationName",              RulesStructure.Source);
		RulesInformation.Insert("ConfigurationVersion",           RulesStructure.SourceConfigurationVersion);
		RulesInformation.Insert("ConfigurationSynonymInRules", RulesStructure.SourceConfigurationSynonym);
		
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

#EndRegion