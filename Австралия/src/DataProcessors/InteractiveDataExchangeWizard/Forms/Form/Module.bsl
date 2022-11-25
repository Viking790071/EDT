// There are two ways to parameterize a form:
//
// Option 1
//     Parameters:
//         InfobaseNode - ExchangePlanObject - an exchange plan node for which the wizard is executed.
//         ExportAdditionExtendedMode - Boolean           - a flag that shows whether the export 
//                                                                 addition setup by node scenario is enabled.
//
// Case 2:
//     Parameters:
//         InfobaseNodeCode          - String           - an exchange plan node code, for which the wizard will be opened. 
//         ExchangePlanName                     - String           - a name of an exchange plan to 
//                                                                 use for searching an exchange 
//                                                                 plan node whose code is specified in the InfobaseNodeCode parameter.
//         ExportAdditionExtendedMode - Boolean           - a flag that shows whether the export 
//                                                                 addition setup by node scenario is enabled.
//
#Region Variables

&AtClient
Var SkipCurrentPageCancelControl;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	IsStartedFromAnotherApplication = False;
	
	If Parameters.Property("InfobaseNode", Object.InfobaseNode) Then
		
		Object.ExchangePlanName = DataExchangeCached.GetExchangePlanName(Object.InfobaseNode);
		
	ElsIf Parameters.Property("InfobaseNodeCode") Then
		
		IsStartedFromAnotherApplication = True;
		
		Object.InfobaseNode = DataExchangeServer.ExchangePlanNodeByCode(
			Parameters.ExchangePlanName, Parameters.InfobaseNodeCode);
		
		If Not ValueIsFilled(Object.InfobaseNode) Then
			Raise NStr("ru = 'Настройка обмена данными не найдена.'; en = 'Data exchange settings item not found.'; pl = 'Ustawienia wymiany danych nie zostały znalezione.';es_ES = 'Configuración del intercambio de datos no se ha encontrado.';es_CO = 'Configuración del intercambio de datos no se ha encontrado.';tr = 'Veri değişimi ayarı bulunmadı.';it = 'Impostazioni scambio dati elemento non trovate.';de = 'Datenaustauscheinstellung wurde nicht gefunden.'");
		EndIf;
		
		Object.ExchangePlanName = Parameters.ExchangePlanName;
		
	Else
		
		Raise NStr("ru = 'Непосредственное открытие помощника не предусмотрено.'; en = 'The wizard cannot be opened directly.'; pl = 'Kreatora nie można otworzyć bezpośrednio.';es_ES = 'Asistente no puede abrirse.';es_CO = 'Asistente no puede abrirse.';tr = 'Sihirbaz açılamıyor.';it = 'L''assistente guidato non può essere aperto direttamente.';de = 'Der Assistent kann nicht geöffnet werden.'");
		
	EndIf;
	
	// Interactive data exchange is supported only for universal exchanges.
	If Not DataExchangeCached.IsUniversalDataExchangeNode(Object.InfobaseNode) Then
		Raise NStr("ru = 'Для выбранного узла выполнение обмена данными с настройкой не предусмотрено.'; en = 'Only universal exchanges with conversion rules can be executed interactively.'; pl = 'Wykonanie wymiany danych za pomocą tego ustawienia nie jest wymagane dla wybranego węzła.';es_ES = 'No se requiere la ejecución del intercambio de datos con la configuración para el nodo seleccionado.';es_CO = 'No se requiere la ejecución del intercambio de datos con la configuración para el nodo seleccionado.';tr = 'Seçilen ünite için ayar ile veri değişimi uygulaması gerekli değildir.';it = 'Solo scambi universali con le regole di conversione possono essere eseguiti in modo interattivo.';de = 'Die Ausführung des Datenaustauschs mit der Einstellung ist für den ausgewählten Knoten nicht erforderlich.'");
	EndIf;
	
	// Check whether exchange settings match the filter.
	AllNodes = DataExchangeEvents.AllExchangePlanNodes(Object.ExchangePlanName);
	If AllNodes.Find(Object.InfobaseNode) = Undefined Then
		Raise NStr("ru = 'Для выбранного узла сопоставление данных не предусмотрено.'; en = 'The selected node does not provide data mapping.'; pl = 'Mapowanie danych nie jest wymagane dla wybranego węzła.';es_ES = 'No se requiere el mapeo de datos para el nodo seleccionado.';es_CO = 'No se requiere el mapeo de datos para el nodo seleccionado.';tr = 'Seçilen ünite için ayar ile veri eşlenmesi gerekli değildir.';it = 'Il nodo selezionato non fornisce mappatura dati.';de = 'Für den ausgewählten Knoten ist kein Datenmapping erforderlich.'");
	EndIf;
	
	EmailReceivedForDataMapping = DataExchangeServer.MessageWithDataForMappingReceived(Object.InfobaseNode);
	
	If Not Parameters.Property("GetData", GetData) Then
		GetData = True;
	EndIf;
	
	If Not Parameters.Property("SendData", SendData) Then
		SendData = True;
	EndIf;
	
	If Not GetData AND Not SendData Then
		Raise NStr("ru = 'Заданный сценарий синхронизации данных не поддерживается.'; en = 'The specified data synchronization scenario is not supported.'; pl = 'Podany scenariusz synchronizacji danych nie jest obsługiwany.';es_ES = 'Este escenario de la sincronización de datos no se admite.';es_CO = 'Este escenario de la sincronización de datos no se admite.';tr = 'Bu veri senkronizasyon senaryosu desteklenmiyor.';it = 'Lo scenario di sincronizzazione dati indicato non è supportato.';de = 'Dieses Datensynchronisierungsszenario wird nicht unterstützt.'");
	EndIf;
	
	SaaSModel = Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable();
		
	Parameters.Property("ExchangeMessagesTransportKind", Object.ExchangeMessagesTransportKind);	
	Parameters.Property("CorrespondentDataArea",  CorrespondentDataArea);
	
	Parameters.Property("ExportAdditionMode",            ExportAdditionMode);
	Parameters.Property("AdvancedExportAdditionMode", ExportAdditionExtendedMode);
	
	CheckVersionDifference = True;
	
	CorrespondentDescription = Common.ObjectAttributeValue(Object.InfobaseNode, "Description");
	
	SetFormHeader();
	
	InitializeScheduleSettingWizard(IsStartedFromAnotherApplication);
	
	If ExportAdditionMode Then
		InitializeExportAdditionAttributes();
	EndIf;
	
	InitializeSettingsOfExchangeMessagesTransport();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetGoToNumber(1);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If ForceCloseForm Then
		Return;
	EndIf;

	CommonClient.ShowArbitraryFormClosingConfirmation(ThisObject, Cancel, Exit,
		NStr("ru = 'Выйти из помощника?'; en = 'Quit the wizard?'; pl = 'Wyjść z asystenta?';es_ES = '¿Salir del ayudante?';es_CO = '¿Salir del ayudante?';tr = 'Sihirbazdan çıkmak istiyor musunuz?';it = 'Esci dall''utente guidato?';de = 'Den Assistenten verlassen?'"), "ForceCloseForm");
		
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If TimeConsumingOperation Then
		EndExecutingTimeConsumingOperation(JobID);
	EndIf;
	
	If EmailReceivedForDataMapping Then
		If EndDataMapping Then
			DeleteMessageForDataMapping(Object.InfobaseNode);
		EndIf;
	EndIf;
	
	DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageCatalogName);
	
	If ValueIsFilled(FormReopeningParameters)
		AND FormReopeningParameters.Property("NewDataSynchronizationSetting") Then
		
		NewDataSynchronizationSetting = FormReopeningParameters.NewDataSynchronizationSetting;
		
		FormParameters = New Structure;
		FormParameters.Insert("InfobaseNode", NewDataSynchronizationSetting);
		FormParameters.Insert("AdvancedExportAdditionMode", True);
		
		OpeningParameters = New Structure;
		OpeningParameters.Insert("WindowOpeningMode", FormWindowOpeningMode.LockOwnerWindow);
		
		DataExchangeClient.OpenFormAfterClosingCurrentOne(ThisObject,
			"DataProcessor.InteractiveDataExchangeWizard.Form", FormParameters, OpeningParameters);
		
	Else
		Notify("ObjectMappingWizardFormClosed");
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	// Checking whether the additional export item initialization event occurred.
	If DataExchangeClient.ExportAdditionChoiceProcessing(SelectedValue, ChoiceSource, ExportAddition) Then
		// Event is handled, updating filter details.
		SetExportAdditionFilterDescription();
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "ObjectMappingFormClosing" Then
		
		Cancel = False;
		
		UpdateMappingStatisticsDataAtServer(Cancel, Parameter);
		
		If Cancel Then
			ShowMessageBox(, NStr("ru = 'При получении информации статистики возникли ошибки.'; en = 'Error gathering statistic data.'; pl = 'Podczas pobierania informacji statystycznej wystąpiły błędy.';es_ES = 'Errores ocurridos al recibir la información de estadística.';es_CO = 'Errores ocurridos al recibir la información de estadística.';tr = 'İstatistik bilgisi alınırken hatalar oluştu.';it = 'Errore durante l''ottenimento dei dati statistici.';de = 'Beim Empfang von Statistikinformationen sind Fehler aufgetreten.'"));
		Else
			
			ExpandStatisticsTree(Parameter.UniqueKey);
			
			ShowUserNotification(NStr("ru = 'Сбор информации завершен'; en = 'Information collection is complete'; pl = 'Zbiór informacji został zakończony';es_ES = 'Recopilación de información se ha finalizado';es_CO = 'Recopilación de información se ha finalizado';tr = 'Bilgi toplama tamamlandı';it = 'La raccolta di informazioni è stata completata';de = 'Die Informationssammlung ist abgeschlossen'"));
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page

&AtClient
Procedure ExchangeMessagesTransportKindOnChange(Item)
	
	OnChangeExchangeMessagesTransportKind();
	
EndProcedure

&AtClient
Procedure ExchangeMessageTransportKindClear(Item, StandardProcessing)
	
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DataExchangeDirectoryClick(Item)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// StatisticsPage page

&AtClient
Procedure EndMappingDataOnChange(Item)
	
	OnChangeFlagEndDataMapping();
	
EndProcedure

&AtClient
Procedure LoadMessageAfterMappingOnChange(Item)
	
	OnChangeFlagImportMessageAfterMapping();
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// QuestionAboutExportContentPage page

&AtClient
Procedure ExportAdditionExportVariantOnChange(Item)
	ExportAdditionExportVariantSetVisibility();
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodOnChange(Item)
	ExportAdditionNodeScenarioPeriodChanging();
EndProcedure

&AtClient
Procedure ExportAdditionGeneralDocumentPeriodClearing(Item, StandardProcessing)
	// Prohibiting period clearing
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ExportAdditionNodeScenarioFilterPeriodClearing(Item, StandardProcessing)
	// Prohibiting period clearing
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region StatisticsTreeFormTableItemEventHandlers

&AtClient
Procedure StatisticsTreeChoice(Item, RowSelected, Field, StandardProcessing)
	
	OpenMappingForm(Undefined);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure NextCommand(Command)
	
	ChangeGoToNumber(+1);
	
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	
	Close();
	
EndProcedure

&AtClient
Procedure DoneCommand(Command)
	// Updating all opened dynamic lists.
	DataExchangeClient.RefreshAllOpenDynamicLists();
	
	ForceCloseForm = True;
	Close();
	
EndProcedure

&AtClient
Procedure OpenScheduleSettings(Command)
	FormParameters = New Structure("InfobaseNode", Object.InfobaseNode);
	OpenForm("Catalog.DataExchangeScenarios.ObjectForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure ContinueSync(Command)
	
	GoToNumber = GoToNumber - 1;
	SetGoToNumber(GoToNumber + 1);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// BeginningPage page

&AtClient
Procedure OpenDataExchangeDirectory(Command)
	
	OpenNodeDataExchangeDirectory();
	
EndProcedure

&AtClient
Procedure ConfigureExchangeMessagesTransportParameters(Command)
	
	Filter              = New Structure("Node", Object.InfobaseNode);
	FillingValues = New Structure("Node", Object.InfobaseNode);
	
	Notification = New NotifyDescription("SetUpExchangeMessageTransportParametersCompletion", ThisObject);
	DataExchangeClient.OpenInformationRegisterWriteFormByFilter(Filter,
		FillingValues, "DataExchangeTransportSettings", ThisObject, , , Notification);

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// StatisticsPage page

&AtClient
Procedure RefreshAllMappingInformation(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData <> Undefined Then
		
		CurrentRowKey = CurrentData.Key;
		
	EndIf;
	
	Cancel = False;
	
	RowsKeys = New Array;
	
	GetAllRowKeys(RowsKeys, StatisticsInformationTree.GetItems());
	
	If RowsKeys.Count() > 0 Then
		
		UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys);
		
	EndIf;
	
	If Cancel Then
		ShowMessageBox(, NStr("ru = 'При получении информации статистики возникли ошибки.'; en = 'Error gathering statistic data.'; pl = 'Podczas pobierania informacji statystycznej wystąpiły błędy.';es_ES = 'Errores ocurridos al recibir la información de estadística.';es_CO = 'Errores ocurridos al recibir la información de estadística.';tr = 'İstatistik bilgisi alınırken hatalar oluştu.';it = 'Errore durante l''ottenimento dei dati statistici.';de = 'Beim Empfang von Statistikinformationen sind Fehler aufgetreten.'"));
	Else
		
		ExpandStatisticsTree(CurrentRowKey);
		
		ShowUserNotification(NStr("ru = 'Сбор информации завершен'; en = 'Information collection is complete'; pl = 'Zbiór informacji został zakończony';es_ES = 'Recopilación de información se ha finalizado';es_CO = 'Recopilación de información se ha finalizado';tr = 'Bilgi toplama tamamlandı';it = 'La raccolta di informazioni è stata completata';de = 'Die Informationssammlung ist abgeschlossen'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure RunDataImportForRow(Command)
	
	Cancel = False;
	
	SelectedRows = Items.StatisticsInformationTree.SelectedRows;
	
	If SelectedRows.Count() = 0 Then
		NString = NStr("ru = 'Выберите имя таблицы в поле статистической информации.'; en = 'Select a table name in the statistics field.'; pl = 'Wybierz nazwę tablicy w polu informacji statystycznej.';es_ES = 'Seleccionar un nombre de la tabla en el campo de la información estadística.';es_CO = 'Seleccionar un nombre de la tabla en el campo de la información estadística.';tr = 'İstatistik bilgi alanında bir tablo adı seçin.';it = 'Seleziona un nome tabella nel campo delle statistiche.';de = 'Wählen Sie im Feld für statistische Informationen einen Tabellennamen aus.'");
		CommonClientServer.MessageToUser(NString,,"StatisticsInformationTree",, Cancel);
		Return;
	EndIf;
	
	HasUnmappedObjects = False;
	For Each RowID In SelectedRows Do
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If IsBlankString(TreeRow.Key) Then
			Continue;
		EndIf;
		
		If TreeRow.UnmappedObjectCount <> 0 Then
			HasUnmappedObjects = True;
			Break;
		EndIf;
	EndDo;
	
	If HasUnmappedObjects Then
		NString = NStr("ru = 'Имеются несопоставленные объекты.
		                     |При загрузке данных будут созданы дубли несопоставленных объектов. Продолжить?'; 
		                     |en = 'Unmapped objects were found.
		                     |Duplicates of these objects will be created when importing data. Continue?'; 
		                     |pl = 'Istnieją obiekty niedostosowane.
		                     |Niedostosowane duplikaty obiektów zostaną utworzone podczas importowania danych. Kontynuować?';
		                     |es_ES = 'Hay objetos no emparejados.
		                     |Duplicados de objetos no emparejados se crearán al importar los datos. ¿Continuar?';
		                     |es_CO = 'Hay objetos no emparejados.
		                     |Duplicados de objetos no emparejados se crearán al importar los datos. ¿Continuar?';
		                     |tr = 'Eşsiz nesneler vardır.
		                     | Veri içe aktarılırken eşleştirilmemiş nesne çiftleri oluşturulacak. Devam et?';
		                     |it = 'Sono stati trovati oggetti non mappati.
		                     |Durante l''importazione dei dati verranno creati duplicati di questi oggetti. Continuare?';
		                     |de = 'Es gibt nicht übereinstimmende Objekte.
		                     |Nicht übereinstimmende Objektduplikate werden beim Importieren von Daten erstellt. Fortsetzen?'");
		
		Notification = New NotifyDescription("ExecuteDataImportForRowQuestionUnmapped", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SelectedRows", SelectedRows);
		ShowQueryBox(Notification, NString, QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(SelectedRows);
EndProcedure

&AtClient
Procedure OpenMappingForm(Command)
	
	CurrentData = Items.StatisticsInformationTree.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If IsBlankString(CurrentData.Key) Then
		Return;
	EndIf;
	
	If Not CurrentData.UsePreview Then
		ShowMessageBox(, NStr("ru = 'Для типа данных нельзя выполнить сопоставление объектов.'; en = 'Object mapping cannot be performed for the data type.'; pl = 'Dla typu danych nie można wykonać zestawienie obiektów.';es_ES = 'No se puede mapear los objetos para el tipo de datos.';es_CO = 'No se puede mapear los objetos para el tipo de datos.';tr = 'Veri türü için nesneler eşlenemez.';it = 'La mappatura oggetti non può essere eseguita per il tipo di dati.';de = 'Objekte für den Datentyp können nicht gemappt werden.'"));
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("DestinationTableName",            CurrentData.DestinationTableName);
	FormParameters.Insert("SourceTableObjectTypeName", CurrentData.ObjectTypeString);
	FormParameters.Insert("DestinationTableFields",           CurrentData.TableFields);
	FormParameters.Insert("DestinationTableSearchFields",     CurrentData.SearchFields);
	FormParameters.Insert("SourceTypeString",            CurrentData.SourceTypeString);
	FormParameters.Insert("DestinationTypeString",            CurrentData.DestinationTypeString);
	FormParameters.Insert("IsObjectDeletion",             CurrentData.IsObjectDeletion);
	FormParameters.Insert("DataImportedSuccessfully",         CurrentData.DataImportedSuccessfully);
	FormParameters.Insert("Key",                           CurrentData.Key);
	FormParameters.Insert("Synonym",                        CurrentData.Synonym);
	
	FormParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	FormParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	
	OpenForm("DataProcessor.InfobaseObjectMapping.Form", FormParameters, ThisObject);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// MappingCompletePage page

&AtClient
Procedure GoToDataImportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
	
EndProcedure

&AtClient
Procedure GoToDataExportEventLog(Command)
	
	DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataExport");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// QuestionAboutExportContentPage page

&AtClient
Procedure ExportAdditionGeneralDocumentsFilter(Command)
	DataExchangeClient.OpenExportAdditionFormAllDocuments(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilter(Command)
	DataExchangeClient.OpenExportAdditionFormDetailedFilter(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionFilterByNodeScenario(Command)
	DataExchangeClient.OpenExportAdditionFormNodeScenario(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionExportComposition(Command)
	DataExchangeClient.OpenExportAdditionFormCompositionOfData(ExportAddition, ThisObject);
EndProcedure

&AtClient
Procedure ExportAdditionClearGeneralFilter(Command)
	
	TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	QuestionText   = NStr("ru='Очистить общий отбор?'; en = 'Clear general filter?'; pl = 'Oczyścić wspólny filtr?';es_ES = '¿Borrar el filtro común?';es_CO = '¿Borrar el filtro común?';tr = 'Genel filtreyi temizle?';it = 'Cancellare il filtro generale';de = 'Gemeinsamen Filter löschen?'");
	NotifyDescription = New NotifyDescription("ExportAdditionGeneralFilterClearingCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
	
EndProcedure

&AtClient
Procedure ExportAdditionClearDetailedFilter(Command)
	TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	QuestionText   = NStr("ru='Очистить детальный отбор?'; en = 'Clear detailed filter?'; pl = 'Oczyścić filtr szczegółowy?';es_ES = '¿Borrar el filtro detallado?';es_CO = '¿Borrar el filtro detallado?';tr = 'Ayrıntılı filtreyi temizle?';it = 'Cancellare filtro dettagliato?';de = 'Detaillierten Filter löschen?'");
	NotifyDescription = New NotifyDescription("ExportAdditionDetailedFilterClearingCompletion", ThisObject);
	ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
EndProcedure

&AtClient
Procedure ExportAdditionFiltersHistory(Command)
	// Filling a menu list with all saved settings options.
	VariantList = ExportAdditionServerSettingsHistory();
	
	// Adding the option for saving the current settings.
	Text = NStr("ru='Сохранить текущую настройку...'; en = 'Save current settings...'; pl = 'Zapisuję bieżącą konfigurację...';es_ES = 'Guardando la configuración actual...';es_CO = 'Guardando la configuración actual...';tr = 'Mevcut ayarlar kaydediliyor...';it = 'Salva le impostazioni correnti...';de = 'Die aktuelle Konfiguration speichern...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryMenuSelection", ThisObject);
	ShowChooseFromMenu(NotifyDescription, VariantList, Items.ExportAdditionFiltersHistory);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// PART TO SUPPLY
////////////////////////////////////////////////////////////////////////////////

#Region PartToSupply

&AtClient
Function GetFormButtonByCommandName(FormItem, CommandName)
	
	For Each Item In FormItem.ChildItems Do
		
		If TypeOf(Item) = Type("FormGroup") Then
			
			FormItemByCommandName = GetFormButtonByCommandName(Item, CommandName);
			
			If FormItemByCommandName <> Undefined Then
				
				Return FormItemByCommandName;
				
			EndIf;
			
		ElsIf TypeOf(Item) = Type("FormButton")
			AND Item.CommandName = CommandName Then
			
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
		
		If GoToRows.Count() = 0 Then
			Return;
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
			
			If VersionMismatchErrorOnGetData <> Undefined
				AND VersionMismatchErrorOnGetData.HasError Then
				
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

&AtServer
Procedure GoToTableNewRow(
									MainPageName,
									NavigationPageName,
									OnOpenHandlerName = "",
									GoNextHandlerName = "")
									
	NewRow = NavigationTable.Add();
	
	NewRow.GoToNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = GoNextHandlerName;
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = False;
	NewRow.TimeConsumingOperationHandlerName = "";
	
EndProcedure

&AtServer
Procedure NavigationTableNewRowTimeConsumingOperation(
									MainPageName,
									NavigationPageName,
									TimeConsumingOperation = False,
									TimeConsumingOperationHandlerName = "",
									OnOpenHandlerName = "")
	
	NewRow = NavigationTable.Add();
	
	NewRow.GoToNumber = NavigationTable.Count();
	NewRow.MainPageName     = MainPageName;
	NewRow.NavigationPageName    = NavigationPageName;
	
	NewRow.GoNextHandlerName = "";
	NewRow.OnOpenHandlerName      = OnOpenHandlerName;
	
	NewRow.TimeConsumingOperation = TimeConsumingOperation;
	NewRow.TimeConsumingOperationHandlerName = TimeConsumingOperationHandlerName;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// OVERRIDABLE PART
////////////////////////////////////////////////////////////////////////////////

#Region OverridablePart

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES AND FUNCTIONS SECTION

#Region ProceduresAndFuctionsOfProcessing

#Region ProceduresAndFunctionsClient

&AtClient
Procedure InitializeDataProcessorVariables()
	
	// Initialization of data processor variables
	ProgressPercent                   = 0;
	FileID                  = "";
	ProgressAdditionalInformation             = "";
	TempStorageAddress            = "";
	ErrorMessage                   = "";
	OperationID               = "";
	TimeConsumingOperation                  = False;
	TimeConsumingOperationCompleted         = True;
	TimeConsumingOperationCompletedWithError = False;
	JobID                = Undefined;
	
EndProcedure

&AtClient
Procedure SetUpExchangeMessageTransportParametersCompletion(ClosingResult, AdditionalParameters) Export
	
	InitializeSettingsOfExchangeMessagesTransport();
	
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryCompletion(Response, SettingPresentation) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionSetSettingsServer(SettingPresentation);
		ExportAdditionExportVariantSetVisibility();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionGeneralFilterClearingCompletion(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		ExportAdditionGeneralFilterClearingServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportAdditionDetailedFilterClearingCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		ExportAdditionDetailedFilterClearingServer();
	EndIf;
EndProcedure

&AtClient
Procedure ExportAdditionFilterHistoryMenuSelection(Val SelectedItem, Val AdditionalParameters) Export
	
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingPresentation = SelectedItem.Value;
	If TypeOf(SettingPresentation)=Type("String") Then
		// An option is selected, which is name of the setting saved earlier.
		
		TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru='Восстановить настройки ""%1""?'; en = 'Restore """"%1"""" settings?'; pl = 'Przywróć ustawienia ""%1""?';es_ES = '¿Restablecer las configuraciones ""%1""?';es_CO = '¿Restablecer las configuraciones ""%1""?';tr = 'Ayarları eski haline getir ""%1""?';it = 'Ripristina impostazioni """"%1""""?';de = 'Einstellungen wiederherstellen ""%1""?'"), SettingPresentation);
		
		NotifyDescription = New NotifyDescription("ExportAdditionFilterHistoryCompletion", ThisObject, SettingPresentation);
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo,,,TitleText);
		
	ElsIf SettingPresentation=1 Then
		// A save option is selected, opening the form of all settings.
		DataExchangeClient.OpenExportAdditionFormSaveSettings(ExportAddition, ThisObject);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowQuestionUnmapped(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	ExecuteDataImportForRowContinued(AdditionalParameters.SelectedRows);
EndProcedure

&AtClient
Procedure ExecuteDataImportForRowContinued(Val SelectedRows) 

	RowsKeys = GetSelectedRowKeys(SelectedRows);
	If RowsKeys.Count() = 0 Then
		Return;
	EndIf;
	
	Cancel = False;
	UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys, True);
	
	If Cancel Then
		NString = NStr("ru = 'При загрузке данных возникли ошибки.
		                     |Перейти в журнал регистрации?'; 
		                     |en = 'Errors occurred during data import.
		                     |Go to the event log?'; 
		                     |pl = 'Wystąpiły błędy podczas importowania danych.
		                     |Czy chcesz otworzyć dziennik wydarzeń?';
		                     |es_ES = 'Errores ocurridos al importar los datos.
		                     |¿Quiere abrir el registro de eventos?';
		                     |es_CO = 'Errores ocurridos al importar los datos.
		                     |¿Quiere abrir el registro de eventos?';
		                     |tr = 'Veriler içe aktarılırken hatalar oluştu.
		                     |Olay günlüğünü açmak ister misiniz?';
		                     |it = 'Errore durante l''importazione dati.
		                     |Andare al registro eventi?';
		                     |de = 'Beim Importieren von Daten sind Fehler aufgetreten.
		                     |Möchten Sie das Ereignisprotokoll öffnen?'");
		
		NotifyDescription = New NotifyDescription("GoToEventLog", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
		
	ExpandStatisticsTree(RowsKeys[RowsKeys.UBound()]);
	ShowUserNotification(NStr("ru = 'Загрузка данных завершена.'; en = 'Data import completed.'; pl = 'Pobieranie danych zakończone.';es_ES = 'Importación de datos se ha finalizado.';es_CO = 'Importación de datos se ha finalizado.';tr = 'Veri içe aktarımı tamamlandı.';it = 'Importazione dati completata.';de = 'Der Datenimport ist abgeschlossen.'"));
EndProcedure

&AtClient
Procedure OpenNodeDataExchangeDirectory()
	
	// Server call without context.
	DirectoryName = GetDirectoryNameAtServer(Object.ExchangeMessagesTransportKind, Object.InfobaseNode);
	
	If IsBlankString(DirectoryName) Then
		ShowMessageBox(, NStr("ru = 'Не задан каталог обмена информацией.'; en = 'Data exchange directory is not specified.'; pl = 'Katalog wymiany informacji nie został określony.';es_ES = 'Directorio de intercambio de información no está especificado.';es_CO = 'Directorio de intercambio de información no está especificado.';tr = 'Bilgi değişim dizini belirtilmemiş.';it = 'Directory di scambio dati non specificata.';de = 'Informationsaustauschverzeichnis ist nicht angegeben.'"));
		Return;
	EndIf;
	
	CommonClient.OpenExplorer(DirectoryName);
	
EndProcedure

&AtClient
Procedure GoToEventLog(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		
		DataExchangeClient.GoToDataEventLogModally(Object.InfobaseNode, ThisObject, "DataImport");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProcessVersionDifferenceError()
	
	Items.MainPanel.CurrentPage             = Items.VersionsDifferenceErrorPage;
	Items.NavigationPanel.CurrentPage            = Items.NavigationPageVersionsDifferenceError;
	Items.ContinueSync.DefaultButton  = True;
	Items.VersionsDifferenceErrorDecoration.Title = VersionMismatchErrorOnGetData.ErrorText;
	
	VersionMismatchErrorOnGetData = Undefined;
	
	CheckVersionDifference = False;
	
EndProcedure

&AtClient
Procedure OnChangeFlagEndDataMapping()
	
	Items.LoadMessageAfterMapping.Enabled = EndDataMapping;
	
	UpdateAvailabilityOfStatisticsInformationMoveCommand();
	UpdateTooltipTitleOfStatisticsInformationMove();
	
EndProcedure

&AtClient
Procedure OnChangeFlagImportMessageAfterMapping()
	
	UpdateAvailabilityOfStatisticsInformationMoveCommand();
	UpdateTooltipTitleOfStatisticsInformationMove();
	
EndProcedure

&AtClient
Procedure UpdateTooltipTitleOfStatisticsInformationMove()
	
	If EmailReceivedForDataMapping Then
		If EndDataMapping Then
			If LoadMessageAfterMapping Then
				Items.StatisticsDataNavigationTooltipDecoration.Title =
					NStr("ru = 'Нажмите кнопку ""Далее"" для завершения сопоставления данных и загрузки сообщения обмена.'; en = 'Click Next to finish data mapping and import the exchange message.'; pl = 'Kliknij przycisk ""Dalej"", aby zakończyć dopasowanie danych i pobieranie wiadomości wymiany.';es_ES = 'Pulse el botón ""Seguir"" para terminar de comparar los datos y descargar el mensaje del cambio.';es_CO = 'Pulse el botón ""Seguir"" para terminar de comparar los datos y descargar el mensaje del cambio.';tr = 'Veri eşlemesini tamamlamak ve veri alışverişi mesajını yüklemek için ""İleri"" düğmesini tıklayın.';it = 'Clicca Avanti per completare la mappatura dei dati e importare il messaggio di scambio.';de = 'Klicken Sie auf ""Weiter"", um das Datenmapping abzuschließen und die Austauschnachricht herunterzuladen.'");
			Else
				Items.StatisticsDataNavigationTooltipDecoration.Title =
					NStr("ru = 'Нажмите кнопку ""Записать и закрыть"" для завершения сопоставления данных и выхода из помощника.'; en = 'Click ""Save and close"" to finish data mapping and quit the wizard.'; pl = 'Kliknij przycisk ""Zapisz i zamknij"", aby zakończyć dopasowanie danych i wyjścia z asystenta.';es_ES = 'Pulse el botón ""Guardar y cerrar"" para terminar de comparar los datos y salir del ayudante.';es_CO = 'Pulse el botón ""Guardar y cerrar"" para terminar de comparar los datos y salir del ayudante.';tr = 'Veri eşlemesini tamamlamak ve sihirbazdan çıkmak için ""Kaydet ve kapat"" düğmesini tıklayın.';it = 'Premi ""Salva e Chiudi"" per terminare la mappatura ed uscire dall''assistente guidato.';de = 'Klicken Sie auf die Schaltfläche ""Speichern und Schließen"", um das Mapping abzuschließen und den Assistenten zu verlassen.'");
			EndIf;
		Else
			Items.StatisticsDataNavigationTooltipDecoration.Title =
				NStr("ru = 'Нажмите кнопку ""Записать и закрыть"" для сохранения результатов сопоставления и выхода из помощника.
				|При следующем запуске помощника можно будет продолжить сопоставление данных.'; 
				|en = 'Click ""Save and close"" to save mapping results and quit the wizard.
				|You can continue mapping data when you start the wizard next time.'; 
				|pl = 'Kliknij przycisk ""Zapisz i zamknij"", aby zapisać wyniki dopasowania i wyjścia z asystenta.
				|Przy następnym uruchomieniu asystenta będzie można kontynuować dopasowanie danych.';
				|es_ES = 'Pulse el botón ""Guardar y cerrar"" para guardar los resultados de comparación y salir del ayudante.
				|Al volver a lanzar el ayudante se podrá seguir comparando los datos.';
				|es_CO = 'Pulse el botón ""Guardar y cerrar"" para guardar los resultados de comparación y salir del ayudante.
				|Al volver a lanzar el ayudante se podrá seguir comparando los datos.';
				|tr = 'Veri eşlemesini kaydetmek ve sihirbazdan çıkmak için ""Kaydet ve kapat"" düğmesini tıklayın. 
				| Sihirbaz bir sonraki çalıştırıldığında verilerin eşleşmesine devam edilebilecektir.';
				|it = 'Premi ""Salva e chiudi"" per salvare i risultati della mappature ed uscire dall''assistente guidato.
				|Potete continuare la mappatura dati quando avvierete l''assistente guidato la prossima volta.';
				|de = 'Klicken Sie auf die Schaltfläche ""Speichern und schließen"", um die Mappingergebnisse zu speichern und den Assistenten zu verlassen.
				|Wenn Sie den Assistenten das nächste Mal starten, können Sie das Datenmapping fortsetzen.'");
		EndIf;
	Else
		Items.StatisticsDataNavigationTooltipDecoration.Title =
			NStr("ru = 'Нажмите кнопку ""Далее"" для синхронизации данных.'; en = 'Click Next to synchronize data.'; pl = 'Kliknij Dalej, aby zsynchronizować dane.';es_ES = 'Hacer clic en Siguiente para sincronizar los datos.';es_CO = 'Hacer clic en Siguiente para sincronizar los datos.';tr = 'Verileri senkronize etmek için İleri''ye tıklayın.';it = 'Fare clic su Avanti per sincronizzare i dati.';de = 'Klicken Sie auf Weiter, um die Daten zu synchronisieren.'");
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateAvailabilityOfStatisticsInformationMoveCommand()
	
	Items.DoneCommand.Enabled = Not EndDataMapping Or Not LoadMessageAfterMapping;
	Items.DoneCommand.DefaultButton = EndDataMapping;
	
	Items.StatisticsInformationNextCommand.Enabled = EndDataMapping AND LoadMessageAfterMapping;
	Items.StatisticsInformationNextCommand.DefaultButton = EndDataMapping AND LoadMessageAfterMapping;
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsServer

&AtServer
Procedure UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys, RunDataImport = False)
	
	RowIndexes = GetStatisticsTableRowIndexes(RowsKeys);
	
	DataProcessorObject = FormAttributeToValue("Object");
	
	If RunDataImport Then
		DataProcessorObject.RunDataImport(Cancel, RowIndexes);
	EndIf;
	
	// Getting mapping statistic data.
	DataProcessorObject.GetObjectMappingByRowStats(Cancel, RowIndexes);
	
	ValueToFormAttribute(DataProcessorObject, "Object");
	
	StatisticsInformation(DataProcessorObject.StatisticsTable());
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	
	AllDataMapped   = ModuleInteractiveExchangeWizard.AllDataMapped(DataProcessorObject.StatisticsTable());
	HasUnmappedMasterData = Not AllDataMapped AND ModuleInteractiveExchangeWizard.HasUnmappedMasterData(DataProcessorObject.StatisticsTable());
	
	SetAdditionalInfoGroupVisible();
	
EndProcedure

&AtServer
Procedure UpdateMappingStatisticsDataAtServer(Cancel, NotificationParameters)
	
	TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", NotificationParameters.UniqueKey));
	
	If TableRows.Count() > 0 Then
		FillPropertyValues(TableRows[0], NotificationParameters, "DataImportedSuccessfully");
		
		RowsKeys = New Array;
		RowsKeys.Add(NotificationParameters.UniqueKey);
		
		UpdateMappingByRowDetailsAtServer(Cancel, RowsKeys);
	EndIf;
	
EndProcedure

&AtServer
Procedure StatisticsInformation(StatisticsInformation)
	
	TreeItemsCollection = StatisticsInformationTree.GetItems();
	TreeItemsCollection.Clear();
	
	Common.FillFormDataTreeItemCollection(TreeItemsCollection,
		DataExchangeServer.StatisticsInformation(StatisticsInformation));
	
EndProcedure

&AtServer
Procedure SetAdditionalInfoGroupVisible()
	
	Items.DataMappingStatusPages.CurrentPage = ?(AllDataMapped,
		Items.MappingStatusAllDataMapped,
		Items.MappingStatusUnmappedDataDetected);
	
EndProcedure

&AtServer
Procedure InitializeSettingsOfExchangeMessagesTransport()
	
	DefaultTransportKind  = InformationRegisters.DataExchangeTransportSettings.DefaultExchangeMessagesTransportKind(Object.InfobaseNode);
	ConfiguredTransportTypes = InformationRegisters.DataExchangeTransportSettings.ConfiguredTransportTypes(Object.InfobaseNode);
	
	SkipTransportPage = True;
	
	If ConfiguredTransportTypes.Count() > 1
		AND Not ValueIsFilled(Object.ExchangeMessagesTransportKind) Then
		SkipTransportPage = ExportAdditionExtendedMode;
	EndIf;
	
	If Not ValueIsFilled(Object.ExchangeMessagesTransportKind) Then
		Object.ExchangeMessagesTransportKind = DefaultTransportKind;
	EndIf;
	
	StartDataExchangeFromCorrespondent = Not ValueIsFilled(Object.ExchangeMessagesTransportKind);
		
	ExchangeBetweenSaaSApplications = SaaSModel
		AND (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
			Or Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP);
	
	OnChangeExchangeMessagesTransportKind(True);
	
	If Not SkipTransportPage Then
		
		If DataExchangeServer.HasRightsToAdministerExchanges() Then
			Items.ConfigureExchangeMessagesTransportParameters.Visible = True;
			
			DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfobaseNode,
				Items.ExchangeMessagesTransportKind);
		Else
			Items.ConfigureExchangeMessagesTransportParameters.Visible = False;
			
			DataExchangeServer.FillChoiceListWithAvailableTransportTypes(Object.InfobaseNode,
				Items.ExchangeMessagesTransportKind, ConfiguredTransportTypes);
		EndIf;
		
		TransportChoiceList = Items.ExchangeMessagesTransportKind.ChoiceList;
		
		If TransportChoiceList.Count() = 0 Then
			TransportChoiceList.Add(Undefined, NStr("ru = 'подключение не настроено'; en = 'connection not configured'; pl = 'Połączenie nie zostało skonfigurowane';es_ES = 'Conexión no está configurada';es_CO = 'Conexión no está configurada';tr = 'Bağlantı yapılandırılmadı';it = 'connessione non configurata';de = 'Verbindung ist nicht konfiguriert'"));
			
			Items.ExchangeMessageTransportKindAsString.TextColor = StyleColors.ErrorNoteText
		Else
			Items.ExchangeMessageTransportKindAsString.TextColor = New Color;
		EndIf;
		
		Items.ExchangeMessageTransportKindAsString.Title = TransportChoiceList[0].Presentation;
		Items.ExchangeMessageTransportKindAsString.Visible = (TransportChoiceList.Count() = 1);
		Items.ExchangeMessagesTransportKind.Visible        = Not Items.ExchangeMessageTransportKindAsString.Visible;
		
		Items.WSPassword.Visible          = ExchangeOverWebService AND Not WSRememberPassword;
		Items.WSPasswordLabel.Visible   = ExchangeOverWebService AND Not WSRememberPassword;
        Items.WSRememberPassword.Visible = ExchangeOverWebService AND Not WSRememberPassword;
		
		SetExchangeDirectoryOpeningButtonVisible();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnChangeExchangeMessagesTransportKind(Initializing = False)
	
	ExchangeOverExternalConnection = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.COM);
	ExchangeOverWebService         = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS);
	
	ExchangeOverConnectionToCorrespondent = ExchangeOverExternalConnection Or ExchangeOverWebService;
	
	If ExchangeOverWebService Then
		SettingsStructure = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(Object.InfobaseNode);
		FillPropertyValues(ThisObject, SettingsStructure, "WSRememberPassword");
	EndIf;
	
	UseProgressBar = Not ExchangeOverConnectionToCorrespondent AND Not ExchangeBetweenSaaSApplications;
	
	If Initializing Then
		SkipTransportPage = SkipTransportPage AND (Not ExchangeOverWebService Or WSRememberPassword);
		FillGoToTable();
	EndIf;
	
EndProcedure

&AtServer
Procedure InitializeScheduleSettingWizard(IsStartedFromAnotherApplication)
	
	OpenDataExchangeScenarioCreationWizard = DataExchangeServer.HasRightsToAdministerExchanges();
	
	If IsStartedFromAnotherApplication Then
		OpenDataExchangeScenarioCreationWizard = False;
	ElsIf Parameters.Property("ScheduleSetup") Then
		OpenDataExchangeScenarioCreationWizard = Parameters.ScheduleSetup;
	EndIf;
	
	Items.ScheduleSettingsHelpText.Visible = OpenDataExchangeScenarioCreationWizard;
	
EndProcedure

&AtServer
Function GetStatisticsTableRowIndexes(RowsKeys)
	
	RowIndexes = New Array;
	
	For Each varKey In RowsKeys Do
		
		TableRows = Object.StatisticsInformation.FindRows(New Structure("Key", varKey));
		
		RowIndex = Object.StatisticsInformation.IndexOf(TableRows[0]);
		
		RowIndexes.Add(RowIndex);
		
	EndDo;
	
	Return RowIndexes;
	
EndFunction

&AtServer
Procedure SetExchangeDirectoryOpeningButtonVisible()
	
	ButtonVisibility = (Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FILE
		Or Object.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.FTP);
	
	Items.DataExchangeDirectory.Visible = ButtonVisibility;
	
	If ButtonVisibility Then
		Items.DataExchangeDirectory.Title = GetDirectoryNameAtServer(Object.ExchangeMessagesTransportKind, Object.InfobaseNode);
	EndIf;
	
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
Procedure PrepareExportAdditionStructure(StructureAddition)
	
	StructureAddition = New Structure;
	StructureAddition.Insert("ExportOption", ExportAddition.ExportOption);
	StructureAddition.Insert("AllDocumentsFilterPeriod", ExportAddition.AllDocumentsFilterPeriod);
	
	StructureAddition.Insert("AllDocumentsComposer", Undefined);
	If Not IsBlankString(ExportAddition.AllDocumentsComposerAddress) Then
		AllDocumentsComposer = GetFromTempStorage(ExportAddition.AllDocumentsComposerAddress);
		
		StructureAddition.AllDocumentsComposer = AllDocumentsComposer;
	EndIf;
	
	StructureAddition.Insert("NodeScenarioFilterPeriod", ExportAddition.NodeScenarioFilterPeriod);
	StructureAddition.Insert("NodeScenarioFilterPresentation", ExportAddition.NodeScenarioFilterPresentation);
	StructureAddition.Insert("AdditionScenarioParameters", ExportAddition.AdditionScenarioParameters);
	StructureAddition.Insert("CurrentSettingsItemPresentation", ExportAddition.CurrentSettingsItemPresentation);
	StructureAddition.Insert("InfobaseNode", ExportAddition.InfobaseNode);
	
	StructureAddition.Insert("AllDocumentsSettingFilterComposer", ExportAddition.AllDocumentsFilterComposer.GetSettings());
	
	StructureAddition.Insert("AdditionalNodeScenarioRegistration", ExportAddition.AdditionalNodeScenarioRegistration.Unload());
	StructureAddition.Insert("AdditionalRegistration", ExportAddition.AdditionalRegistration.Unload());
	
EndProcedure

#Region ExportAdditionOperations

&AtServer
Procedure InitializeExportAdditionAttributes()
	
	// Getting settings as a structure, settings will be saved implicitly to the form temporary storage.
	ExportAdditionSettings = DataExchangeServer.InteractiveExportModification(
		Object.InfobaseNode, ThisObject.UUID, ExportAdditionExtendedMode);
		
	// Setting up the form.
	// Converting ThisObject form attribute to a value of DataProcessor type. It is used to simplify data link with the form.
	DataExchangeServer.InteractiveExportModificationAttributeBySettings(ThisObject, ExportAdditionSettings, "ExportAddition");
	
	AdditionScenarioParameters = ExportAddition.AdditionScenarioParameters;
	
	// Configuring interface according to the specified scenario.
	
	// Special cases
	StandardVariantsProhibited = Not AdditionScenarioParameters.OptionDoNotAdd.Use
		AND Not AdditionScenarioParameters.AllDocumentsOption.Use
		AND Not AdditionScenarioParameters.ArbitraryFilterOption.Use;
		
	If StandardVariantsProhibited Then
		If AdditionScenarioParameters.AdditionalOption.Use Then
			// A single node scenario option is available.
			Items.ExportAdditionNodeAsStringExportOption.Visible = True;
			Items.ExportAdditionNodeExportOption.Visible        = False;
			Items.CustomGroupIndentDecoration.Visible           = False;
			ExportAddition.ExportOption = 3;
		Else
			// Nothing is found. Setting the flag showing that the page is skipped and exiting.
			ExportAddition.ExportOption = -1;
			Items.ExportAdditionOptions.Visible = False;
			Return;
		EndIf;
	EndIf;
	
	// Setting typical input fields.
	Items.StandardAdditionOptionNone.Visible = AdditionScenarioParameters.OptionDoNotAdd.Use;
	If Not IsBlankString(AdditionScenarioParameters.OptionDoNotAdd.Title) Then
		Items.ExportAdditionExportOption0.ChoiceList[0].Presentation = AdditionScenarioParameters.OptionDoNotAdd.Title;
	EndIf;
	Items.StandardAdditionOptionNoneNote.Title = AdditionScenarioParameters.OptionDoNotAdd.Explanation;
	If IsBlankString(Items.StandardAdditionOptionNoneNote.Title) Then
		Items.StandardAdditionOptionNoneNote.Visible = False;
	EndIf;
	
	Items.StandardAdditionOptionDocuments.Visible = AdditionScenarioParameters.AllDocumentsOption.Use;
	If Not IsBlankString(AdditionScenarioParameters.AllDocumentsOption.Title) Then
		Items.ExportAdditionExportOption1.ChoiceList[0].Presentation = AdditionScenarioParameters.AllDocumentsOption.Title;
	EndIf;
	Items.StandardAdditionOptionDocumentsNote.Title = AdditionScenarioParameters.AllDocumentsOption.Explanation;
	If IsBlankString(Items.StandardAdditionOptionDocumentsNote.Title) Then
		Items.StandardAdditionOptionDocumentsNote.Visible = False;
	EndIf;
	
	Items.StandardAdditionOptionCustom.Visible = AdditionScenarioParameters.ArbitraryFilterOption.Use;
	If Not IsBlankString(AdditionScenarioParameters.ArbitraryFilterOption.Title) Then
		Items.ExportAdditionExportOption2.ChoiceList[0].Presentation = AdditionScenarioParameters.ArbitraryFilterOption.Title;
	EndIf;
	Items.StandardAdditionOptionCustomNote.Title = AdditionScenarioParameters.ArbitraryFilterOption.Explanation;
	If IsBlankString(Items.StandardAdditionOptionCustomNote.Title) Then
		Items.StandardAdditionOptionCustomNote.Visible = False;
	EndIf;
	
	Items.CustomAdditionOption.Visible           = AdditionScenarioParameters.AdditionalOption.Use;
	Items.ExportPeriodNodeScenarioGroup.Visible         = AdditionScenarioParameters.AdditionalOption.UseFilterPeriod;
	Items.ExportAdditionFilterByNodeScenario.Visible    = Not IsBlankString(AdditionScenarioParameters.AdditionalOption.FilterFormName);
	
	Items.ExportAdditionNodeExportOption.ChoiceList[0].Presentation = AdditionScenarioParameters.AdditionalOption.Title;
	Items.ExportAdditionNodeAsStringExportOption.Title              = AdditionScenarioParameters.AdditionalOption.Title;
	
	Items.CustomAdditionOptionNote.Title = AdditionScenarioParameters.AdditionalOption.Explanation;
	If IsBlankString(Items.CustomAdditionOptionNote.Title) Then
		Items.CustomAdditionOptionNote.Visible = False;
	EndIf;
	
	// Command titles
	If Not IsBlankString(AdditionScenarioParameters.AdditionalOption.FormCommandTitle) Then
		Items.ExportAdditionFilterByNodeScenario.Title = AdditionScenarioParameters.AdditionalOption.FormCommandTitle;
	EndIf;
	
	// Sorting visible items.
	AdditionGroupOrder = New ValueList;
	If Items.StandardAdditionOptionNone.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionNone, 
			Format(AdditionScenarioParameters.OptionDoNotAdd.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionOptionDocuments.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionDocuments, 
			Format(AdditionScenarioParameters.AllDocumentsOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.StandardAdditionOptionCustom.Visible Then
		AdditionGroupOrder.Add(Items.StandardAdditionOptionCustom, 
			Format(AdditionScenarioParameters.ArbitraryFilterOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	If Items.CustomAdditionOption.Visible Then
		AdditionGroupOrder.Add(Items.CustomAdditionOption, 
			Format(AdditionScenarioParameters.AdditionalOption.Order, "ND=10; NZ=; NLZ=; NG="));
	EndIf;
	AdditionGroupOrder.SortByPresentation();
	For Each AdditionGroupItem In AdditionGroupOrder Do
		Items.Move(AdditionGroupItem.Value, Items.ExportAdditionOptions);
	EndDo;
	
	// Editing settings is only allowed if the appropriate rights are granted.
	HasRightsToSetup = AccessRight("SaveUserData", Metadata);
	Items.StandardSettingsOptionsImportGroup.Visible = HasRightsToSetup;
	If HasRightsToSetup Then
		// Restoring predefined settings.
		SetFirstItem = Not ExportAdditionSetSettingsServer(DataExchangeServer.ExportAdditionSettingsAutoSavingName());
		ExportAddition.CurrentSettingsItemPresentation = "";
	Else
		SetFirstItem = True;
	EndIf;
		
	SetFirstItem = SetFirstItem
		Or ExportAddition.ExportOption<0 
		Or ( (ExportAddition.ExportOption=0) AND (Not AdditionScenarioParameters.OptionDoNotAdd.Use) )
		Or ( (ExportAddition.ExportOption=1) AND (Not AdditionScenarioParameters.AllDocumentsOption.Use) )
		Or ( (ExportAddition.ExportOption=2) AND (Not AdditionScenarioParameters.ArbitraryFilterOption.Use) )
		Or ( (ExportAddition.ExportOption=3) AND (Not AdditionScenarioParameters.AdditionalOption.Use) );
	
	If SetFirstItem Then
		For Each AdditionGroupItem In AdditionGroupOrder[0].Value.ChildItems Do
			If TypeOf(AdditionGroupItem)=Type("FormField") AND AdditionGroupItem.Type = FormFieldType.RadioButtonField Then
				ExportAddition.ExportOption = AdditionGroupItem.ChoiceList[0].Value;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	// Initial view, same as ExportAdditionExportVariantSetVisibility client procedure.
	Items.AllDocumentsFilterGroup.Enabled  = ExportAddition.ExportOption=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportOption=2;
	Items.CustomFilterGroup.Enabled = ExportAddition.ExportOption=3;
	
	// Description of standard initial filters.
	SetExportAdditionFilterDescription();
	
EndProcedure

&AtServer
Procedure SetFormHeader()
	
	CaptionPattern = NStr("ru = 'Обмен данными с ""%1""'; en = 'Data exchange with ""%1""'; pl = 'Wymiana danych z ""%1""';es_ES = 'Intercambio de datos con ""%1""';es_CO = 'Intercambio de datos con ""%1""';tr = '""%1"" ile veri alışverişi';it = 'Scambio dati con ""%1""';de = 'Datenaustausch mit ""%1""'");
	
	If EmailReceivedForDataMapping Then
		CaptionPattern = NStr("ru = 'Сопоставление данных ""%1""'; en = 'Mapping the ""%1"" data'; pl = 'Mapowanie danych ""%1"".';es_ES = 'Mapeo de los datos ""%1"".';es_CO = 'Mapeo de los datos ""%1"".';tr = '""%1"" verinin eşleşmesi.';it = 'Mappamento dati ""%1""';de = 'Mapping von Daten ""%1""'");
	ElsIf GetData AND SendData Then
		CaptionPattern = NStr("ru = 'Синхронизация данных с ""%1""'; en = 'Data synchronization with %1'; pl = 'Synchronizacja danych z %1';es_ES = 'Sincronización de datos con %1';es_CO = 'Sincronización de datos con %1';tr = '%1 ile veri senkronizasyonu';it = 'La sincronizzazione dei dati con il %1';de = 'Datensynchronisation mit %1'");
	ElsIf SendData Then
		CaptionPattern = NStr("ru = 'Отправка данных для ""%1""'; en = 'Sending data for ""%1""'; pl = 'Wysyłanie danych dla ""%1""';es_ES = 'Envío de datos para ""%1""';es_CO = 'Envío de datos para ""%1""';tr = '""%1"" için veri gönderiliyor';it = 'Invio dati per ""%1""';de = 'Senden von Daten für ""%1""'");
	ElsIf GetData Then
		CaptionPattern = NStr("ru = 'Получение данных от ""%1""'; en = 'Receiving data from ""%1""'; pl = 'Uzyskiwanie danych od ""%1""';es_ES = 'Recepción de datos de ""%1""';es_CO = 'Recepción de datos de ""%1""';tr = '""%1"" ''dan veri alınıyor';it = 'Ricevendo dati da ""%1""';de = 'Empfangen von Daten von ""%1""'");
	EndIf;
		
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		CaptionPattern, CorrespondentDescription);
	
EndProcedure

&AtClient
Procedure ExportAdditionExportVariantSetVisibility()
	Items.AllDocumentsFilterGroup.Enabled  = ExportAddition.ExportOption=1;
	Items.DetailedFilterGroup.Enabled     = ExportAddition.ExportOption=2;
	Items.CustomFilterGroup.Enabled = ExportAddition.ExportOption=3;
EndProcedure

&AtServer
Procedure ExportAdditionNodeScenarioPeriodChanging()
	DataExchangeServer.InteractiveExportModificationSetNodeScenarioPeriod(ExportAddition);
EndProcedure

&AtServer
Procedure ExportAdditionGeneralFilterClearingServer()
	DataExchangeServer.InteractiveExportModificationGeneralFilterClearing(ExportAddition);
	SetGeneralFilterAdditionDescription();
EndProcedure

&AtServer
Procedure ExportAdditionDetailedFilterClearingServer()
	DataExchangeServer.InteractiveExportModificationDetailsClearing(ExportAddition);
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetExportAdditionFilterDescription()
	SetGeneralFilterAdditionDescription();
	SetAdditionDetailDescription();
EndProcedure

&AtServer
Procedure SetGeneralFilterAdditionDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationGeneralFilterAdditionDescription(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("ru='Все документы'; en = 'All documents'; pl = 'Wszystkie dokumenty';es_ES = 'Todos documentos';es_CO = 'Todos documentos';tr = 'Tüm belgeler';it = 'Tutti i documenti';de = 'Alle Dokumente'");
	EndIf;
	
	Items.ExportAdditionGeneralDocumentsFilter.Title = Text;
	Items.ExportAdditionClearGeneralFilter.Visible = Not NoFilter;
EndProcedure

&AtServer
Procedure SetAdditionDetailDescription()
	
	Text = DataExchangeServer.InteractiveExportModificationDetailedFilterDetails(ExportAddition);
	NoFilter = IsBlankString(Text);
	If NoFilter Then
		Text = NStr("ru='Дополнительные данные не выбраны'; en = 'Additional data is not selected'; pl = 'Dane dodatkowe nie zostały wybrane';es_ES = 'Datos adicionales no seleccionados';es_CO = 'Datos adicionales no seleccionados';tr = 'Ek veri seçilmedi';it = 'Dati aggiuntivi non sono selezionate';de = 'Zusätzliche Daten sind nicht ausgewählt'");
	EndIf;
	
	Items.ExportAdditionDetailedFilter.Title = Text;
	Items.ExportAdditionClearDetailedFilter.Visible = Not NoFilter;
EndProcedure

// Returns boolean - success or failure (setting is not found).
&AtServer 
Function ExportAdditionSetSettingsServer(SettingPresentation)
	Result = DataExchangeServer.InteractiveExportModificationRestoreSettings(ExportAddition, SettingPresentation);
	SetExportAdditionFilterDescription();
	Return Result;
EndFunction

&AtServer 
Function ExportAdditionServerSettingsHistory() 
	Return DataExchangeServer.InteractiveExportModificationSettingsHistory(ExportAddition);
EndFunction

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsServerWIthoutContext

&AtServerNoContext
Procedure GetDataExchangeStates(DataImportResult, DataExportResult, Val InfobaseNode)
	
	DataExchangesStates = DataExchangeServer.ExchangeNodeDataExchangeStates(InfobaseNode);
	
	DataImportResult = DataExchangesStates["DataImportResult"];
	If IsBlankString(DataExportResult) Then
		DataExportResult = DataExchangesStates["DataExportResult"];
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteMessageForDataMapping(ExchangeNode)
	
	SetPrivilegedMode(True);
	
	Filter = New Structure("InfobaseNode", ExchangeNode);
	CommonSettings = InformationRegisters.CommonInfobasesNodesSettings.Get(Filter);
	
	If ValueIsFilled(CommonSettings.MessageForDataMapping) Then
		
		MessageFileNameInStorage = DataExchangeServer.GetFileFromStorage(CommonSettings.MessageForDataMapping);
		
		File = New File(MessageFileNameInStorage);
		If File.Exist() AND File.IsFile() Then
			DeleteFiles(MessageFileNameInStorage);
		EndIf;
		
		InformationRegisters.CommonInfobasesNodesSettings.PutMessageForDataMapping(ExchangeNode, Undefined);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure DeleteTempExchangeMessageDirectory(TempDirectoryName)
	
	If Not IsBlankString(TempDirectoryName) Then
		
		Try
			DeleteFiles(TempDirectoryName);
			TempDirectoryName = "";
		Except
			WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
				EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
		EndTry;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure EndExecutingTimeConsumingOperation(JobID)
	TimeConsumingOperations.CancelJobExecution(JobID);
EndProcedure

&AtServerNoContext
Function GetDirectoryNameAtServer(ExchangeMessagesTransportKind, InfobaseNode)
	
	Return InformationRegisters.DataExchangeTransportSettings.DataExchangeDirectoryName(ExchangeMessagesTransportKind, InfobaseNode);
	
EndFunction

&AtServerNoContext
Function TimeConsumingOperationState(Val OperationID, ExchangeNode)
	
	Try
		
		ConnectionParameters = DataExchangeServer.WSParameterStructure();
		
		SavedParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(ExchangeNode);
		FillPropertyValues(ConnectionParameters, SavedParameters);
		
		InterfaceVersions = DataExchangeCached.CorrespondentVersions(ConnectionParameters);
		
		ErrorMessageString = "";
		
		WSProxy = Undefined;
		If InterfaceVersions.Find("3.0.1.1") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_3_0_1_1(ConnectionParameters, ErrorMessageString);
			
		ElsIf InterfaceVersions.Find("2.1.1.7") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_1_1_7(ConnectionParameters, ErrorMessageString);
			
		ElsIf InterfaceVersions.Find("2.0.1.6") <> Undefined Then
			
			WSProxy = DataExchangeServer.GetWSProxy_2_0_1_6(ConnectionParameters, ErrorMessageString);
			
		Else
			
			WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, ErrorMessageString);
			
		EndIf;
		
		If WSProxy = Undefined Then
			Raise ErrorMessageString;
		EndIf;
		
		Result = WSProxy.GetContinuousOperationStatus(OperationID, ErrorMessageString);
		
	Except
		Result = "Failed";
		ErrorMessageString = DetailErrorDescription(ErrorInfo())
			+ ?(ValueIsFilled(ErrorMessageString), Chars.LF + ErrorMessageString, "");
	EndTry;
	
	If Result = "Failed" Then
		MessageString = NStr("ru = 'Ошибка в базе-корреспонденте: %1'; en = 'An error occurred in the correspondent infobase: %1'; pl = 'Błąd w bazie-korespondencie: %1';es_ES = 'Error en la base-correspondiente: %1';es_CO = 'Error en la base-correspondiente: %1';tr = 'Muhabir tabanındaki hata: %1';it = 'Si è registrato un errore nell''infobase corrispondente: %1';de = 'Es liegt ein Fehler in der entsprechenden Datenbank vor: %1'");
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ErrorMessageString);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Idle handlers

&AtClient
Procedure TimeConsumingOperationIdleHandler()
	
	TimeConsumingOperationCompleted         = False;
	TimeConsumingOperationCompletedWithError = False;
	
	If ExchangeOverWebService Then
		
		ActionState = TimeConsumingOperationState(OperationID, Object.InfobaseNode);
			
	Else
		// Exchange via COM connection.
		ActionState = DataExchangeServerCall.JobState(JobID);
	EndIf;
	
	If ActionState = "Active" Or ActionState = "Active" Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		
		TimeConsumingOperation          = False;
		TimeConsumingOperationCompleted = True;
		
		If ActionState = "Failed" 
			Or ActionState = "Canceled" 
			Or ActionState = "Failed" Then
			TimeConsumingOperationCompletedWithError = True;
		EndIf;
		
		AttachIdleHandler("GoNextExecute", 0.1, True);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Procedures and function of the master.

&AtClient
Function GetSelectedRowKeys(SelectedRows)
	
	// Function return value.
	RowsKeys = New Array;
	
	For Each RowID In SelectedRows Do
		
		TreeRow = StatisticsInformationTree.FindByID(RowID);
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowsKeys.Add(TreeRow.Key);
			
		EndIf;
		
	EndDo;
	
	Return RowsKeys;
EndFunction

&AtClient
Procedure GetAllRowKeys(RowsKeys, TreeItemsCollection)
	
	For Each TreeRow In TreeItemsCollection Do
		
		If Not IsBlankString(TreeRow.Key) Then
			
			RowsKeys.Add(TreeRow.Key);
			
		EndIf;
		
		ItemCollection = TreeRow.GetItems();
		
		If ItemCollection.Count() > 0 Then
			
			GetAllRowKeys(RowsKeys, ItemCollection);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure RefreshDataExchangeStatusItemPresentation()
	
	Items.DataImportGroup.Visible = GetData;
	
	Items.DataImportStatusPages.CurrentPage = Items[DataExchangeClient.DataImportStatusPages()[DataImportResult]];
	If Items.DataImportStatusPages.CurrentPage=Items.ImportStatusUndefined Then
		Items.GoToDataImportEventLog.Title = NStr("ru='Загрузка данных не произведена'; en = 'Data is not imported'; pl = 'Dane nie zostały zaimportowane';es_ES = 'Datos no se han importado';es_CO = 'Datos no se han importado';tr = 'Veri içe aktarılmadı';it = 'I dati non sono importati';de = 'Daten wurden nicht importiert'");
	Else
		Items.GoToDataImportEventLog.Title = DataExchangeClient.DataImportHyperlinksHeaders()[DataImportResult];
	EndIf;
	
	Items.DataExportGroup.Visible = SendData;
	
	Items.DataExportStatusPages.CurrentPage = Items[DataExchangeClient.DataExportStatusPages()[DataExportResult]];
	If Items.DataExportStatusPages.CurrentPage=Items.ExportStatusUndefined Then
		Items.GoToDataExportEventLog.Title = NStr("ru='Выгрузка данных не произведена'; en = 'Data is not exported'; pl = 'Dane nie zostały eksportowane';es_ES = 'Datos no se han exportado';es_CO = 'Datos no se han exportado';tr = 'Veri dışa aktarılmadı';it = 'I dati non vengono esportati';de = 'Daten werden nicht exportiert'");
	Else
		Items.GoToDataExportEventLog.Title = DataExchangeClient.DataExportHyperlinksHeaders()[DataExportResult];
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandStatisticsTree(RowKey = "")
	
	ItemCollection = StatisticsInformationTree.GetItems();
	
	For Each TreeRow In ItemCollection Do
		
		Items.StatisticsInformationTree.Expand(TreeRow.GetID(), True);
		
	EndDo;
	
	// Placing a mouse pointer in the value tree.
	If Not IsBlankString(RowKey) Then
		
		RowID = 0;
		
		CommonClientServer.GetTreeRowIDByFieldValue("Key", RowID, StatisticsInformationTree.GetItems(), RowKey, False);
		
		Items.StatisticsInformationTree.CurrentRow = RowID;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// SECTION OF PROCESSING BACKGROUND JOBS

&AtClient
Function BackgroundJobParameters()
	
	JobParameters = New Structure();
	JobParameters.Insert("MethodBeingExecuted",      "");
	JobParameters.Insert("JobDescription",   "");
	JobParameters.Insert("MethodParameters",       Undefined);
	JobParameters.Insert("CompletionNotification", Undefined);
	JobParameters.Insert("CompletionHandler",  Undefined);
	
	Return JobParameters;
	
EndFunction

&AtClient
Procedure BackgroundJobStartClient(JobParameters, Cancel)
	
	Result = ScheduledJobStartAtServer(JobParameters);
	
	If Result = Undefined Then
		Cancel = True;
		Return;
	EndIf;
	
	If VersionMismatchErrorOnGetData <> Undefined
		AND VersionMismatchErrorOnGetData.HasError Then
		Cancel = True;
		ErrorMessage = VersionMismatchErrorOnGetData.ErrorText;
		Return;
	EndIf;
	
	BackgroundJobExecutionResult = Result;
	BackgroundJobExecutionResult.Insert("CompletionHandler", JobParameters.CompletionHandler);
	
	If Result.Status = "Running" Then
		
		TimeConsumingOperation = True;
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		BackgroundJobCompletionNotification = New NotifyDescription("BackgroundJobCompletionNotification", ThisObject);
		
		If UseProgressBar Then
			IdleParameters.OutputProgressBar     = True;
			IdleParameters.ExecutionProgressNotification = New NotifyDescription("BackgroundJobExecutionProgress", ThisObject);
			IdleParameters.Interval                       = 1;
		EndIf;
		
		TimeConsumingOperationsClient.WaitForCompletion(Result, BackgroundJobCompletionNotification, IdleParameters);
		
	Else
		// Job is completed, canceled, or completed with an error.
		AttachIdleHandler(JobParameters.CompletionHandler, 0.1, True);
	EndIf;
	
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

&AtServer
Function ScheduledJobStartAtServer(JobParameters)
	
	OperationStartDate  = CurrentSessionDate();
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = JobParameters.JobDescription;
	
	Result = TimeConsumingOperations.ExecuteInBackground(
		JobParameters.MethodBeingExecuted,
		JobParameters.MethodParameters,
		ExecutionParameters);
	
	Return Result;
	
EndFunction

&AtClient
Procedure BackgroundJobCompletionNotification(Result, AdditionalParameters) Export
	
	CompletionHandler = BackgroundJobExecutionResult.CompletionHandler;
	BackgroundJobExecutionResult = Result;
	
	// Job is completed, canceled, or completed with an error.
	AttachIdleHandler(CompletionHandler, 0.1, True);
	
EndProcedure

&AtClient
Procedure ProcessBackgroundJobExecutionStatus()
	If BackgroundJobExecutionResult.Status = "Error" Then
		ErrorMessage = BackgroundJobExecutionResult.DetailedErrorPresentation;
	ElsIf BackgroundJobExecutionResult.Status = "Canceled" Then
		ErrorMessage = NStr("ru = 'Действие отменено пользователем.'; en = 'Action was canceled by the user.'; pl = 'Operacja została anulowana przez użytkownika.';es_ES = 'Acción cancelada por usuario.';es_CO = 'Acción cancelada por usuario.';tr = 'Eylem kullanıcı tarafından iptal edildi.';it = 'L''azione è stata cancellata dall''utente.';de = 'Die Aktion wurde vom Benutzer abgebrochen.'");
	EndIf;
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// SECTION OF STEP CHANGE HANDLERS

#Region MoveChangeHandlers

&AtClient
Function Attachable_StartPage_OnGoNext(Cancel)
	
	// Check filling of form attributes.
	If Object.InfobaseNode.IsEmpty() Then
		
		NString = NStr("ru = 'Укажите узел информационной базы'; en = 'Specify the infobase node.'; pl = 'Podaj węzeł bazy informacyjnej';es_ES = 'Especificar un nodo de la infobase';es_CO = 'Especificar un nodo de la infobase';tr = 'Infobase düğümünü belirtin.';it = 'Specificare il nodo infobase.';de = 'Geben Sie einen Infobase-Knoten an'");
		CommonClientServer.MessageToUser(NString, , "Object.InfobaseNode", , Cancel);
		
	ElsIf Object.ExchangeMessagesTransportKind.IsEmpty()
		AND Not EmailReceivedForDataMapping Then
		
		NString = NStr("ru = 'Укажите вариант подключения'; en = 'Specify the exchange message transport kind.'; pl = 'Podaj opcję połączenia';es_ES = 'Especificar la opción de conexión';es_CO = 'Especificar la opción de conexión';tr = 'Bağlantı opsiyonunu belirtin';it = 'Specificare la tipologia di trasporto messaggio di scambio.';de = 'Geben Sie die Verbindungsoption an'");
		CommonClientServer.MessageToUser(NString, , "Object.ExchangeMessagesTransportKind", , Cancel);
		
	ElsIf ExchangeOverWebService AND IsBlankString(WSPassword) Then
		
		NString = NStr("ru = 'Не указан пароль.'; en = 'No password specified.'; pl = 'Hasło nie zostało określone.';es_ES = 'Contraseña no está especificada.';es_CO = 'Contraseña no está especificada.';tr = 'Şifre belirtilmemiş.';it = 'Nessuna password specificata.';de = 'Passwort ist nicht angegeben.'");
		CommonClientServer.MessageToUser(NString, , "WSPassword", , Cancel);
		
	EndIf;
	
EndFunction

&AtClient
Function Attachable_ConnectionWaitPagePage_TimeConsumingOperationHandler(Cancel, GoToNext)
	
	If ExchangeOverWebService Then
		
		TestConnectionAndSaveSettings(Cancel);
		
		If Cancel Then
			
			ShowMessageBox(, NStr("ru = 'Не удалось выполнить операцию.'; en = 'Cannot execute the operation.'; pl = 'Nie można wykonać tej operacji.';es_ES = 'No se puede ejecutar la operación.';es_CO = 'No se puede ejecutar la operación.';tr = 'İşlem yapılamıyor.';it = 'Non è possibile eseguire l''operazione.';de = 'Die Operation kann nicht ausgeführt werden.'"));
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtServer
Procedure TestConnectionAndSaveSettings(Cancel)
	
	ConnectionParameters = DataExchangeServer.WSParameterStructure();
	SavedParameters = InformationRegisters.DataExchangeTransportSettings.TransportSettingsWS(Object.InfobaseNode);
	
	FillPropertyValues(ConnectionParameters, SavedParameters);
	
	If Not SkipTransportPage Then
		ConnectionParameters.WSPassword = WSPassword;
	EndIf;
	
	UserMessage = "";
	WSProxy = DataExchangeServer.GetWSProxy(ConnectionParameters, , UserMessage);
	
	If WSProxy = Undefined Then
		CommonClientServer.MessageToUser(UserMessage, , "WSPassword", , Cancel);
		Return;
	EndIf;
	
	If Not SkipTransportPage
		AND WSRememberPassword Then
		
		Try
			
			SetPrivilegedMode(True);
			
			// Updating record in the information register.
			RecordStructure = New Structure;
			RecordStructure.Insert("Correspondent", Object.InfobaseNode);
			RecordStructure.Insert("WSRememberPassword", True);
			RecordStructure.Insert("WSPassword", WSPassword);
			
			InformationRegisters.DataExchangeTransportSettings.UpdateRecord(RecordStructure);
			
			WSPassword = String(ThisObject.UUID);
			
		Except
			
			ErrorMessage = DetailErrorDescription(ErrorInfo());
			
			WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(),
				EventLogLevel.Error, , , ErrorMessage);
				
			CommonClientServer.MessageToUser(ErrorMessage, , , , Cancel);
			Return;
			
		EndTry;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Pages of data receipt processing (exchange message transport).

&AtClient
Function Attachable_DataAnalysisWaitPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	InitializeDataProcessorVariables();
	
EndFunction

&AtClient
Function Attachable_DataAnalysisWaitPage_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	SkipGettingData = False;
	GoToNext              = False;
	
	MethodParameters = New Structure;
	MethodParameters.Insert("Cancel", False);
	MethodParameters.Insert("TimeConsumingOperation",                   TimeConsumingOperation);
	MethodParameters.Insert("OperationID",                OperationID);
	MethodParameters.Insert("DataPackageFileID",       DataPackageFileID);
	MethodParameters.Insert("FileID",                   FileID);
	MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	MethodParameters.Insert("TempExchangeMessageCatalogName", Object.TempExchangeMessageCatalogName);
	MethodParameters.Insert("ExchangeMessagesTransportKind",         Object.ExchangeMessagesTransportKind);
	MethodParameters.Insert("WSPassword",                             Undefined);
	
	MethodParameters.Insert("EmailReceivedForDataMapping", EmailReceivedForDataMapping);
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodBeingExecuted     = "DataProcessors.InteractiveDataExchangeWizard.GetExchangeMessageToTemporaryDirectory";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("ru = 'Получение сообщения обмена во временный каталог'; en = 'Receive exchange message to the temporary directory'; pl = 'Otrzymanie wiadomości wymiany do katalogu tymczasowego';es_ES = 'Recepción del mensaje de cambio en el catálogo temporal';es_CO = 'Recepción del mensaje de cambio en el catálogo temporal';tr = 'Alışveriş mesajının geçici dizine alınıyor';it = 'Ricevere il messaggio di scambio nella directory temporanea';de = 'Empfangen einer Austauschnachricht in einem temporären Verzeichnis'");
	JobParameters.CompletionHandler = "DataReceiptToTemporaryFolderCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel);
	
EndFunction

&AtClient
Procedure DataReceiptToTemporaryFolderCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	If ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
	Else
		GetDataToTemporaryDirectoryAtServerCompletion();
	EndIf;
	
	If TimeConsumingOperation AND Not SkipGettingData Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		AttachIdleHandler("GoNextExecute", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Function Attachable_DataAnalysisWaitPageTimeConsumingOperationCompletion_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	If TimeConsumingOperationCompleted Then
		
		If TimeConsumingOperationCompletedWithError Then
			SkipGettingData = True;
			DataExchangeServerCall.RecordExchangeCompletionWithError(
				Object.InfobaseNode,
				"DataImport",
				OperationStartDate,
				ErrorMessage);
	
		Else
			// Get the file prepared at the correspondent to the temporary directory.
			If Not ValueIsFilled(Object.ExchangeMessageFileName) Then
				
				GoToNext = False;
				
				MethodParameters = New Structure;
				MethodParameters.Insert("Cancel",                                False);
				MethodParameters.Insert("FileID",                   FileID);
				MethodParameters.Insert("DataPackageFileID",       DataPackageFileID);
				MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
				MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
				MethodParameters.Insert("TempExchangeMessageCatalogName", Object.TempExchangeMessageCatalogName);
				MethodParameters.Insert("WSPassword",                             Undefined);
				
				JobParameters = BackgroundJobParameters();
				JobParameters.MethodBeingExecuted     = "DataProcessors.InteractiveDataExchangeWizard.GetExchangeMessageFromCorrespondentToTemporaryDirectory";
				JobParameters.MethodParameters      = MethodParameters;
				JobParameters.JobDescription  = NStr("ru = 'Получение файла с данными сообщения обмена во временный каталог'; en = 'Receive the file with exchange message data to the temporary directory'; pl = 'Pobieranie pliku z danymi wiadomości wymiany do katalogu tymczasowego';es_ES = 'Recepción de archivo de datos con los datos del mensaje de cambio en el catálogo temporal';es_CO = 'Recepción de archivo de datos con los datos del mensaje de cambio en el catálogo temporal';tr = 'Geçici bir dizine alışveriş mesajı verileri ile bir dosya alma';it = 'Ricevere il file con i dati del messaggio di scambio nella directory temporanea';de = 'Empfangen einer Datei mit Datenaustauschnachrichten in einem temporären Verzeichnis'");
				JobParameters.CompletionHandler = "CorrespondentDataReceiptToTemporaryFolderCompletion";
				
				BackgroundJobStartClient(JobParameters, Cancel);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndFunction

&AtClient
Procedure CorrespondentDataReceiptToTemporaryFolderCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	If ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
	Else
		GetDataToTemporaryDirectoryAtServerCompletion();
	EndIf;
	
	AttachIdleHandler("GoNextExecute", 0.1, True);
	
EndProcedure

&AtServer
Procedure GetDataToTemporaryDirectoryAtServerCompletion();
	
	ErrorMessageTemplate = NStr("ru = 'Не удалось выполнить загрузку данных. Подробности см. в журнале регистрации'; en = 'Cannot import data. For more information, see the Event log'; pl = 'Nie udało się wykonać pobieranie danych. Szczegóły można znaleźć w dzienniku rejestracji';es_ES = 'No se ha podido descargar los datos. Véase más en el registro';es_CO = 'No se ha podido descargar los datos. Véase más en el registro';tr = 'Veriler içe aktarılamadı. Ayrıntılar için olay günlüğüne bakın';it = 'Impossibile importare dati. Per ulteriori informazioni consultare il Registro eventi';de = 'Daten konnten nicht geladen werden. Einzelheiten finden Sie im Ereignisprotokoll'");
	MethodExecutionResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
	
	If MethodExecutionResult = Undefined Then
		If Not ValueIsFilled(ErrorMessage) Then
			ErrorMessage = ErrorMessageTemplate;
		EndIf;
	Else
		
		If MethodExecutionResult.Cancel
			AND Not ValueIsFilled(ErrorMessage) Then
			ErrorMessage = ErrorMessageTemplate;
		Else
			
			FillPropertyValues(ThisObject, MethodExecutionResult);
			
			Object.ExchangeMessageFileName              = MethodExecutionResult.ExchangeMessageFileName;
			Object.TempExchangeMessageCatalogName = MethodExecutionResult.TempExchangeMessageCatalogName;
			
		EndIf;
			
	EndIf;
	
	If ValueIsFilled(ErrorMessage) Then
		
		TimeConsumingOperation                  = False;
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		SkipGettingData           = True;
		
		DataExchangeServerCall.RecordExchangeCompletionWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			ErrorMessage);
			
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data analysis pages (automatic data mapping).

&AtClient
Function Attachable_DataAnalysisPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SkipGettingData Then
		SkipPage = True;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataAnalysis_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		Return Undefined;
	EndIf;
	
	GoToNext = False;
	
	MethodParameters = New Structure;
	MethodParameters.Insert("InfobaseNode",               Object.InfobaseNode);
	MethodParameters.Insert("ExchangeMessageFileName",              Object.ExchangeMessageFileName);
	MethodParameters.Insert("TempExchangeMessageCatalogName", Object.TempExchangeMessageCatalogName);
	MethodParameters.Insert("CheckVersionDifference",           CheckVersionDifference);
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodBeingExecuted     = "DataProcessors.InteractiveDataExchangeWizard.ExecuteAutomaticDataMapping";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("ru = 'Анализ данных сообщения обмена'; en = 'Analyzing exchange message data'; pl = 'Analiza danych wiadomości wymiany';es_ES = 'Análisis de los datos de mensajes de intercambio';es_CO = 'Análisis de los datos de mensajes de intercambio';tr = 'Alışveriş mesajı verilerinin analizi';it = 'Analisi dei dati del messaggio di scambio';de = 'Analyse von Austauschnachrichtendaten'");
	JobParameters.CompletionHandler = "DataAnalysisCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel);
	
EndFunction

&AtClient
Function DataAnalysisCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	If Not SkipGettingData AND ValueIsFilled(ErrorMessage) Then
		SkipGettingData = True;
		DataExchangeServerCall.RecordExchangeCompletionWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			ErrorMessage);
	Else
		AtalyzeDataAtServerCompletion();
	EndIf;
	
	If ForceCloseForm Then
		ThisObject.Close();
	EndIf;

	If Not SkipGettingData Then
		ExpandStatisticsTree();
	EndIf;
	
	AttachIdleHandler("GoNextExecute", 0.1, True);
	
EndFunction

&AtServer
Procedure AtalyzeDataAtServerCompletion()
	
	RecordError = False;
	
	// Checking the transition to a new data exchange.
	CheckWhetherTransferToNewExchangeIsRequired();
	If ForceCloseForm Then
		Return;
	EndIf;
	
	Try
		
		AnalysisResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
		
		If AnalysisResult.Property("ErrorText") Then
			VersionMismatchErrorOnGetData = AnalysisResult;
		ElsIf AnalysisResult.Cancel Then
			
			SkipGettingData = True;
			RecordError       = True;
			
			If AnalysisResult.Property("ExchangeExecutionResult")
				AND AnalysisResult.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Warning_ExchangeMessageAlreadyAccepted Then
				
				ExchangeSettingsStructure = New Structure;
				ExchangeSettingsStructure.Insert("InfobaseNode",       Object.InfobaseNode);
				ExchangeSettingsStructure.Insert("ExchangeExecutionResult",    AnalysisResult.ExchangeExecutionResult);
				ExchangeSettingsStructure.Insert("ActionOnExchange",            "DataImport");
				ExchangeSettingsStructure.Insert("ProcessedObjectsCount", 0);
				ExchangeSettingsStructure.Insert("StartDate",                   OperationStartDate);
				ExchangeSettingsStructure.Insert("EndDate",                CurrentSessionDate());
				ExchangeSettingsStructure.Insert("EventLogMessageKey", 
					DataExchangeServer.EventLogMessageKey(Object.InfobaseNode, "DataImport"));
				ExchangeSettingsStructure.Insert("IsDIBExchange", 
					DataExchangeCached.IsDistributedInfobaseNode(Object.InfobaseNode));
				
				DataExchangeServer.AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
				
			EndIf;
			
		Else
			
			AllDataMapped   = AnalysisResult.AllDataMapped;
			HasUnmappedMasterData = AnalysisResult.HasUnmappedMasterData;
			StatisticsBlank        = AnalysisResult.StatisticsBlank;
			
			Object.StatisticsInformation.Load(AnalysisResult.StatisticsInformation);
			Object.StatisticsInformation.Sort("Presentation");
			
			StatisticsInformation(Object.StatisticsInformation.Unload());
			
			SetAdditionalInfoGroupVisible();
			
		EndIf;
		
	Except
		RecordError = True;
		ErrorMessage   = DetailErrorDescription(ErrorInfo());
	EndTry;
	
	If RecordError Then
		
		SkipGettingData = True;
		MessageText = ?(ValueIsFilled(ErrorMessage), ErrorMessage,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не удалось загрузить данные из ""%1"" (этап анализа данных).'; en = 'Cannot import data from ""%1"" (data analysis step).'; pl = 'Nie można importować danych z ""%1"" (krok analizy danych).';es_ES = 'No se puede importar los datos de ""%1"" (paso del análisis de datos).';es_CO = 'No se puede importar los datos de ""%1"" (paso del análisis de datos).';tr = 'Veriler ""%1"" (veri analizi adımı) ''dan içe aktarılamıyor.';it = 'Impossibile caricare i dati da ""%1"" (fase di analisi dei dati).';de = 'Daten können nicht aus ""%1"" (Datenanalyse-Schritt) importiert werden.'"), Object.InfobaseNode));
		
		DataExchangeServerCall.RecordExchangeCompletionWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			MessageText);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Pages of data mapping processing (interactive data mapping).

&AtClient
Function Attachable_StatisticsInformationPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If StatisticsBlank Or SkipGettingData Then
		SkipPage = True;
		If EmailReceivedForDataMapping Then
			EndDataMapping = True;
		EndIf;
	EndIf;
	
	If Not SkipPage Then
		Items.MappingCompletionGroup.Visible = EmailReceivedForDataMapping;
		OnChangeFlagEndDataMapping();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_StatisticsInformationPage_OnGoNext(Cancel)
	
	If StatisticsBlank Or SkipGettingData Or AllDataMapped Or NOT HasUnmappedMasterData Then
		Return Undefined;
	EndIf;
	
	If SkipCurrentPageCancelControl = True Then
		SkipCurrentPageCancelControl = Undefined;
		Return Undefined;
	EndIf;
	
	// Going to the next page after user confirmation.
	Cancel = True;
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes,  NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continuare';de = 'Weiter'"));
	Buttons.Add(DialogReturnCode.No, NStr("ru = 'Отменить'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annullare';de = 'Abbrechen'"));
	
	Message = NStr("ru = 'Не все данные сопоставлены. Наличие несопоставленных данных
	                       |может привести к появлению одинаковых элементов в списках (дублей).
	                       |Продолжить?'; 
	                       |en = 'Not all data is mapped. Unmapped data 
	                       |may lead to duplication of catalog items.
	                       |Continue?'; 
	                       |pl = 'Nie wszystkie dane są dopasowane. Obecność niedopasowanych danych
	                       |może doprowadzić do pojawienia się identycznych elementów w listach (duplikatów).
	                       |Kontynuować?';
	                       |es_ES = 'No todos los datos se han comparado. Existencia de datos no comparados
	                       |puede causar la aparición de los elementos del catálogo idénticos (duplicados).
	                       |¿Continuar?';
	                       |es_CO = 'No todos los datos se han comparado. Existencia de datos no comparados
	                       |puede causar la aparición de los elementos del catálogo idénticos (duplicados).
	                       |¿Continuar?';
	                       |tr = 'Tüm veriler eşlenmedi. Eşleşmeyen verilerin
	                       | varlığı aynı katalog öğelerine yol açabilir (kopyalar).
	                       |Devam et?';
	                       |it = 'Non tutti i dati sono stati mappati. I dati non mappati 
	                       |possono comportare la duplicazione degli elementi del catalogo.
	                       |Continuare?';
	                       |de = 'Nicht alle Daten stimmen überein. Das Vorhandensein nicht übereinstimmender Daten
	                       |kann dazu führen, dass identische Elemente in den Listen (Duplikate) erscheinen.
	                       |Fortsetzen?'");
	
	Notification = New NotifyDescription("StatisticsPage_OnGoNextQuestionCompletion", ThisObject);
	
	ShowQueryBox(Notification, Message, Buttons,, DialogReturnCode.Yes);
	
EndFunction

// Continuation of the procedure (see above).
&AtClient
Procedure StatisticsPage_OnGoNextQuestionCompletion(Val QuestionResult, Val AdditionalParameters) Export
	
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	AttachIdleHandler("Attachable_GoStepForwardWithDeferredProcessing", 0.1, True);
	
EndProcedure

&AtClient
Procedure Attachable_GoStepForwardWithDeferredProcessing()
	
	// Going a step forward (forced).
	SkipCurrentPageCancelControl = True;
	ChangeGoToNumber( +1 );
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Pages of data import processing

&AtClient
Function Attachable_DataImport_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If SkipGettingData Then
		SkipPage = True;
		If Not EmailReceivedForDataMapping Then
			DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageCatalogName);
		EndIf;
	Else
		InitializeDataProcessorVariables();
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataImport_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If SkipGettingData Then
		DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageCatalogName);
		Return Undefined;
	EndIf;
	
	GoToNext    = False;
	MethodParameters = New Structure;
	MethodParameters.Insert("InfobaseNode",  Object.InfobaseNode);
	MethodParameters.Insert("ExchangeMessageFileName", Object.ExchangeMessageFileName);
	
	JobParameters = BackgroundJobParameters();
	JobParameters.MethodBeingExecuted     = "DataProcessors.InteractiveDataExchangeWizard.RunDataImport";
	JobParameters.MethodParameters      = MethodParameters;
	JobParameters.JobDescription  = NStr("ru = 'Загрузка данных из сообщения обмена'; en = 'Importing data from the exchange message'; pl = 'Import danych z wiadomości wymiany';es_ES = 'Importar los datos del mensaje de intercambio';es_CO = 'Importar los datos del mensaje de intercambio';tr = 'Verileri alışveriş mesajından içe aktar';it = 'Importazione dati dal messaggio di scambio';de = 'Importieren von Daten aus der Austauschnachricht'");
	JobParameters.CompletionHandler = "DataImportCompletion";
	
	BackgroundJobStartClient(JobParameters, Cancel);
	
EndFunction

&AtClient
Procedure DataImportCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	If ValueIsFilled(ErrorMessage) AND Not SkipGettingData Then
		SkipGettingData = True;
	EndIf;
	
	ProgressBarDisplayed = Items.MainPanel.CurrentPage = Items.DataSynchronizationWaitProgressBarImportPage
		Or Items.MainPanel.CurrentPage = Items.DataSynchronizationWaitProgressBarExportPage;
		
	If UseProgressBar AND ProgressBarDisplayed Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	If SkipGettingData Then
		
		DataExchangeServerCall.RecordExchangeCompletionWithError(
			Object.InfobaseNode,
			"DataImport",
			OperationStartDate,
			ErrorMessage);
		
	EndIf;
		
	AttachIdleHandler("GoNextExecute", 0.1, True);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional export pages (registration to additional data export).

&AtClient
Function Attachable_QuestionAboutExportCompositionPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ExportAddition.ExportOption < 0 Then
		// According to the node settings, the addition of export is not performed, go to the next page.
		SkipPage = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataRegistrationPage_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	If ExportAddition.ExportOption < 0 Then
		// According to the node settings, the addition of export is not performed, go to the next page.
		SkipPage = True;
	EndIf;
	
EndFunction

&AtClient
Function Attachable_DataRegistrationPage_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	AttachIdleHandler("OnStartRecordData", 0.1, True);
	
EndFunction

&AtClient
Procedure OnStartRecordData()
	
	ContinueWait = True;
	OnStartRecordDataAtServer(ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.InitIdleHandlerParameters(
			DataRegistrationIdleHandlerParameters);
			
		AttachIdleHandler("OnWaitForRecordData",
			DataRegistrationIdleHandlerParameters.CurrentInterval, True);
	Else
		AttachIdleHandler("OnCompleteDataRecording", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnWaitForRecordData()
	
	ContinueWait = False;
	OnWaitForRecordDataAtServer(DataRegistrationHandlerParameters, ContinueWait);
	
	If ContinueWait Then
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(DataRegistrationIdleHandlerParameters);
		
		AttachIdleHandler("OnWaitForRecordData",
			DataRegistrationIdleHandlerParameters.CurrentInterval, True);
	Else
		AttachIdleHandler("OnCompleteDataRecording", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnCompleteDataRecording()
	
	DataRegistered = False;
	ErrorMessage = "";
	
	OnCompleteDataRecordingAtServer(DataRegistrationHandlerParameters, DataRegistered, ErrorMessage);
	
	If DataRegistered Then
		
		ChangeGoToNumber(+1);
		
	Else
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не удалось зарегистрировать данные для выгрузки.'; en = 'Cannot register data for export.'; pl = 'Nie udało się zarejestrować dane do ładowania.';es_ES = 'No se ha podido registrar los datos para subir.';es_CO = 'No se ha podido registrar los datos para subir.';tr = 'Dışa aktarılacak veriler kaydedilemedi.';it = 'Impossibile registrare i dati per l''esportazione.';de = 'Die Daten konnten nicht für den Upload registriert werden.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartRecordDataAtServer(ContinueWait)
	
	RegistrationSettings = New Structure;
	RegistrationSettings.Insert("ExchangeNode", ExportAddition.InfobaseNode);
	RegistrationSettings.Insert("ExportAddition", Undefined);
	
	PrepareExportAdditionStructure(RegistrationSettings.ExportAddition);
	
	DataRegistrationHandlerParameters = Undefined;
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnStartRecordData(RegistrationSettings,
		DataRegistrationHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForRecordDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnWaitForRecordData(HandlerParameters, ContinueWait);
	
EndProcedure

&AtServerNoContext
Procedure OnCompleteDataRecordingAtServer(HandlerParameters, DataRegistered, ErrorMessage)
	
	CompletionStatus = Undefined;
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizard();
	ModuleInteractiveExchangeWizard.OnCompleteDataRecording(HandlerParameters, CompletionStatus);
	HandlerParameters = Undefined;
		
	If CompletionStatus.Cancel Then
		DataRegistered = False;
		ErrorMessage = CompletionStatus.ErrorMessage;
	Else
		DataRegistered = CompletionStatus.Result.DataRegistered;
		
		If Not DataRegistered Then
			ErrorMessage = CompletionStatus.Result.ErrorMessage;
		EndIf;
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Data export processing pages

&AtClient
Function Attachable_DataExport_OnOpen(Cancel, SkipPage, IsMoveNext)
	
	InitializeDataProcessorVariables();
	
EndFunction

&AtClient
Function Attachable_DataExportWaitPage_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	GoToNext = False;
	OnStartExportData(Cancel);
	
EndFunction

&AtClient
Function Attachable_DataExportWaitPageTimeConsumingOperationCompletion_TimeConsumingOperationProcessing(Cancel, GoToNext)
	
	If TimeConsumingOperationCompleted Then
		
		If TimeConsumingOperationCompletedWithError Then
			
			DataExchangeServerCall.RecordExchangeCompletionWithError(
				Object.InfobaseNode,
				"DataExport",
				OperationStartDate,
				ErrorMessage);
			
		Else
			DataExchangeServerCall.RecordDataExportInTimeConsumingOperationMode(
				Object.InfobaseNode, OperationStartDate);
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
		MethodParameters = New Structure;
		MethodParameters.Insert("InfobaseNode",       Object.InfobaseNode);
		MethodParameters.Insert("ExchangeMessagesTransportKind", Object.ExchangeMessagesTransportKind);
		MethodParameters.Insert("ExchangeMessageFileName",      Object.ExchangeMessageFileName);
		MethodParameters.Insert("TimeConsumingOperation",           TimeConsumingOperation);
		MethodParameters.Insert("OperationID",        OperationID);
		MethodParameters.Insert("FileID",           FileID);
		MethodParameters.Insert("WSPassword",                     Undefined);
		MethodParameters.Insert("Cancel",                        False);
		
		JobParameters = BackgroundJobParameters();
		JobParameters.MethodBeingExecuted     = "DataProcessors.InteractiveDataExchangeWizard.RunDataExport";
		JobParameters.MethodParameters      = MethodParameters;
		JobParameters.JobDescription  = NStr("ru = 'Выгрузка данных в сообщение обмена'; en = 'Export data to the exchange message'; pl = 'Ładowanie danych do wiadomości wymiany';es_ES = 'Subida de datos en mensaje de cambio';es_CO = 'Subida de datos en mensaje de cambio';tr = 'Verilerin alışveriş mesajına dışa aktarma';it = 'Esportazione dati al messaggio di scambio';de = 'Hochladen von Daten in eine Austauschnachricht'");
		JobParameters.CompletionHandler = "DataExportCompletion";
		
		BackgroundJobStartClient(JobParameters, Cancel);
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
	
	If DataExported Then
		ChangeGoToNumber(+1);
	Else
		ChangeGoToNumber(-1);
		
		If Not IsBlankString(ErrorMessage) Then
			CommonClientServer.MessageToUser(ErrorMessage);
		Else
			CommonClientServer.MessageToUser(
				NStr("ru = 'Не удалось выполнить обмен данными.'; en = 'Failed to execute data exchange'; pl = 'Nie udało się wykonać wymianę danych.';es_ES = 'No se ha podido intercambiar los datos.';es_CO = 'No se ha podido intercambiar los datos.';tr = 'Veri alışverişi yapılamadı.';it = 'Fallita l''esecuzione dello scambio dati';de = 'Der Datenaustausch ist fehlgeschlagen.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnStartExportDataAtServer(ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
	EndIf;
	
	ExportSettings = New Structure;
	ExportSettings.Insert("Correspondent", Object.InfobaseNode);
	ExportSettings.Insert("CorrespondentDataArea", CorrespondentDataArea);
	ExportSettings.Insert("ExportAddition", Undefined);
	
	PrepareExportAdditionStructure(ExportSettings.ExportAddition);
	
	DataExportHandlerParameters = Undefined;
	ModuleInteractiveExchangeWizard.OnStartExportData(ExportSettings,
		DataExportHandlerParameters, ContinueWait);
	
EndProcedure
	
&AtServerNoContext
Procedure OnWaitForExportDataAtServer(HandlerParameters, ContinueWait)
	
	ModuleInteractiveExchangeWizard = DataExchangeServer.ModuleInteractiveDataExchangeWizardInSaaS();
	
	If ModuleInteractiveExchangeWizard = Undefined Then
		ContinueWait = False;
		Return;
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
Procedure DataExportCompletion()
	
	ProcessBackgroundJobExecutionStatus();
	
	ProgressBarDisplayed = Items.MainPanel.CurrentPage = Items.DataSynchronizationWaitProgressBarImportPage
		Or Items.MainPanel.CurrentPage = Items.DataSynchronizationWaitProgressBarExportPage;
	
	If UseProgressBar AND ProgressBarDisplayed Then
		ProgressPercent       = 100;
		ProgressAdditionalInformation = "";
	EndIf;
	
	DataExportCompletionAtServer();
	
	If TimeConsumingOperation AND Not ValueIsFilled(ErrorMessage) Then
		AttachIdleHandler("TimeConsumingOperationIdleHandler", 5, True);
	Else
		DeleteTempExchangeMessageDirectory(Object.TempExchangeMessageCatalogName);
		AttachIdleHandler("GoNextExecute", 0.1, True);
	EndIf;
	
EndProcedure

&AtServer
Procedure DataExportCompletionAtServer()
	
	MethodExecutionResult = GetFromTempStorage(BackgroundJobExecutionResult.ResultAddress);
	
	If MethodExecutionResult = Undefined Then
		MethodExecutionResult = New Structure("Cancel", True);
	Else
		FillPropertyValues(ThisObject, MethodExecutionResult, 
			"TimeConsumingOperation, OperationID, FileID");
	EndIf;
	
	If MethodExecutionResult.Cancel
		AND Not ValueIsFilled(ErrorMessage) Then
		ErrorMessage = NStr("ru = 'Не удалось выполнить отправку данных. Подробности см. в журнале регистрации'; en = 'Cannot send data. For more information, see the Event log'; pl = 'Nie udało się wykonać wysyłanie danych. Szczegóły można znaleźć w dzienniku rejestracji';es_ES = 'No se ha podido enviar los datos. Véase más en el registro';es_CO = 'No se ha podido enviar los datos. Véase más en el registro';tr = 'Veriler gönderilemedi. Ayrıntılar için olay günlüğüne bakın';it = 'Impossibile inviare i dati. Per maggiori informazioni, guardare il Registro eventi';de = 'Die Daten konnten nicht gesendet werden. Details im Ereignisprotokoll'");
	EndIf;
	
	If ValueIsFilled(ErrorMessage) Then
		
		TimeConsumingOperation                  = False;
		TimeConsumingOperationCompleted         = True;
		TimeConsumingOperationCompletedWithError = True;
		
		DataExchangeServerCall.RecordExchangeCompletionWithError(
			Object.InfobaseNode,
			"DataExport",
			OperationStartDate,
			ErrorMessage);
			
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Summary information pages

&AtClient
Function Attachable_MappingCompletePage_OnOpen(Cancel, SkipPage, Val IsMoveNext)
	
	GetDataExchangeStates(DataImportResult, DataExportResult, Object.InfobaseNode);
	
	RefreshDataExchangeStatusItemPresentation();
	
	ForceCloseForm = True;
	
	Return Undefined;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// FILLING WIZARD NAVIGATION TABLE SECTION

&AtServer
Procedure FillGoToTable()
	
	If UseProgressBar Then
		PageNameSynchronizationImport = "DataSynchronizationWaitProgressBarImportPage";
		PageNameSynchronizationExport = "DataSynchronizationWaitProgressBarExportPage";
	Else
		PageNameSynchronizationImport = "DataSynchronizationWaitPage";
		PageNameSynchronizationExport = "DataSynchronizationWaitPage";
	EndIf;
	
	NavigationTable.Clear();
	
	If Not SkipTransportPage Then
		GoToTableNewRow("StartPage", "NavigationStartPage", , "BeginningPage_OnGoNext");
	EndIf;
	
	If ExchangeBetweenSaaSApplications Then
		
		If EmailReceivedForDataMapping Then
			// Getting data (exchange message transport.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "DataAnalysisWaitPage_TimeConsumingOperationProcessing", "DataAnalysisWaitPage_OnOpen");
			
			// Data analysis. Automatic data mapping.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "DataAnalysis_TimeConsumingOperationProcessing", "DataAnalysisPage_OnOpen");
			
			// Manual data mapping.
			GoToTableNewRow("StatisticsInformationPage", "StatisticsInformationNavigationPage", "StatisticsInformationPage_OnOpen", "StatisticsInformationPage_OnGoNext");
			
			// Data import.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationImport, "NavigationWaitPage", True, "DataImport_TimeConsumingOperationProcessing", "DataImport_OnOpen");
		EndIf;
		
		If SendData Then
			
			If ExportAdditionMode Then
				DataExportResult = "";
				GoToTableNewRow("QuestionAboutExportCompositionPage", "NavigationPageFollowUp", "QuestionAboutExportCompositionPage_OnOpen");
			EndIf;
			
			// Export and import data.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True, "DataExportWaitPage_TimeConsumingOperationProcessing", "DataExport_OnOpen");
		EndIf;
		
	Else
		
		If ExchangeOverConnectionToCorrespondent Then
			// Testing connection.
			If GetData Then
				NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "ConnectionTestWaitPage_TimeConsumingOperationProcessing");
			Else
				NavigationTableNewRowTimeConsumingOperation("DataSynchronizationWaitPage", "NavigationWaitPage", True, "ConnectionTestWaitPage_TimeConsumingOperationProcessing");
			EndIf;
		EndIf;
		
		If GetData Then
			// Getting data (exchange message transport.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "DataAnalysisWaitPage_TimeConsumingOperationProcessing", "DataAnalysisWaitPage_OnOpen");
			If ExchangeOverConnectionToCorrespondent Then
				NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "DataAnalysisWaitPageTimeConsumingOperationCompletion_TimeConsumingOperationProcessing");
			EndIf;
			
			// Data analysis. Automatic data mapping.
			NavigationTableNewRowTimeConsumingOperation("DataAnalysisWaitPage", "NavigationWaitPage", True, "DataAnalysis_TimeConsumingOperationProcessing", "DataAnalysisPage_OnOpen");
			
			// Manual data mapping.
			If EmailReceivedForDataMapping Then
				GoToTableNewRow("StatisticsInformationPage", "StatisticsInformationNavigationPage", "StatisticsInformationPage_OnOpen", "StatisticsInformationPage_OnGoNext");
			Else
				GoToTableNewRow("StatisticsInformationPage", "NavigationPageFollowUp", "StatisticsInformationPage_OnOpen", "StatisticsInformationPage_OnGoNext");
			EndIf;
			
			// Data import.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationImport, "NavigationWaitPage", True, "DataImport_TimeConsumingOperationProcessing", "DataImport_OnOpen");
		EndIf;
		
		If SendData Then
			If ExportAdditionMode Then
				// Data export setup.
				DataExportResult = "";
				GoToTableNewRow("QuestionAboutExportCompositionPage", "NavigationPageFollowUp", "QuestionAboutExportCompositionPage_OnOpen");
				
				// The time-consuming operation of registering additional data to export.
				NavigationTableNewRowTimeConsumingOperation("DataRegistrationPage", "NavigationWaitPage", True, "DataRegistrationPage_TimeConsumingOperationProcessing", "DataRegistrationPage_OnOpen");
			EndIf;
			
			// Exporting data.
			NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True, "DataExportWaitPage_TimeConsumingOperationProcessing", "DataExport_OnOpen");
			If ExchangeOverConnectionToCorrespondent Then
				NavigationTableNewRowTimeConsumingOperation(PageNameSynchronizationExport, "NavigationWaitPage", True, "DataExportWaitPageTimeConsumingOperationCompletion_TimeConsumingOperationProcessing");
			EndIf;
		EndIf;
		
	EndIf;
	
	// Totals.
	GoToTableNewRow("MappingCompletePage", "NavigationEndPage", "MappingCompletePage_OnOpen");
	
EndProcedure

#EndRegion

#EndRegion