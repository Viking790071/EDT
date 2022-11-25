#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Parameters.ChoiceMode Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If Parameters.Property("Title") Then
		AutoTitle = False;
		Title = Parameters.Title;
	EndIf;
	If Parameters.Property("Representation") Then
		Items.List.Representation = TableRepresentation[Parameters.Representation];
	EndIf;
	
	PublicationsChoiceList = Items.PublicationFilter.ChoiceList;
	
	KindUsed = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
	KindDisabled = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	KindDebugMode = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	AvaliablePublicationKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	
	AllPublicationsExceptUnused = New Array;
	AllPublicationsExceptUnused.Add(KindUsed);
	If AvaliablePublicationKinds.Find(KindDebugMode) <> Undefined Then
		AllPublicationsExceptUnused.Add(KindDebugMode);
	EndIf;
	If AllPublicationsExceptUnused.Count() > 1 Then
		ArrayPresentation = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = '%1 или %2'; en = '%1 or %2'; pl = '%1 lub %2';es_ES = '%1 o %2';es_CO = '%1 o %2';tr = '%1 veya %2';it = '%1 o %2';de = '%1 oder %2'"),
			String(AllPublicationsExceptUnused[0]),
			String(AllPublicationsExceptUnused[1]));
		PublicationsChoiceList.Add(1, ArrayPresentation);
	EndIf;
	For Each EnumValue In Enums.AdditionalReportsAndDataProcessorsPublicationOptions Do
		If AvaliablePublicationKinds.Find(EnumValue) <> Undefined Then
			PublicationsChoiceList.Add(EnumValue, String(EnumValue));
		EndIf;
	EndDo;
	
	If Parameters.Filter.Property("Publication") Then
		PublicationFilter = Parameters.Filter.Publication;
		Parameters.Filter.Delete("Publication");
		If PublicationsChoiceList.FindByValue(PublicationFilter) = Undefined Then
			PublicationFilter = Undefined;
		EndIf;
	EndIf;
	
	ChoiceList = Items.KindFilter.ChoiceList;
	ChoiceList.Add(1, NStr("ru = 'Только отчеты'; en = 'Reports only'; pl = 'Tylko sprawozdania';es_ES = 'Solo informes';es_CO = 'Solo informes';tr = 'Yalnızca raporlar';it = 'Solo reports';de = 'Nur Berichte'"));
	ChoiceList.Add(2, NStr("ru = 'Только обработки'; en = 'Data processors only'; pl = 'Tylko opracowania';es_ES = 'Solo procesadores de datos';es_CO = 'Solo procesadores de datos';tr = 'Yalnızca veri işlemcileri';it = 'Solo elaboratori dati';de = 'Nur Datenprozessoren'"));
	For Each EnumValue In Enums.AdditionalReportsAndDataProcessorsKinds Do
		ChoiceList.Add(EnumValue, String(EnumValue));
	EndDo;
	
	AddlReportsKinds = New Array;
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport);
	AddlReportsKinds.Add(Enums.AdditionalReportsAndDataProcessorsKinds.Report);
	
	List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	List.Parameters.SetParameterValue("KindFilter",        KindFilter);
	List.Parameters.SetParameterValue("AddlReportsKinds",  AddlReportsKinds);
	List.Parameters.SetParameterValue("AllPublicationsExceptUnused", AllPublicationsExceptUnused);
	
	InsertRight = AdditionalReportsAndDataProcessors.InsertRight();
	CommonClientServer.SetFormItemProperty(Items, "Create",              "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "CreateMenu",          "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "CreateFolder",        "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "CreateMenuGroup",    "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "Copy",          "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "CopyMenu",      "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "LoadFromFile",     "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "ExportFromMenuFile", "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "ExportToFile",       "Visible", InsertRight);
	CommonClientServer.SetFormItemProperty(Items, "ExportToFileMenu",   "Visible", InsertRight);
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	UseProfiles = Not UseSecurityProfiles;
	
	CommonClientServer.SetFormItemProperty(Items, "ChangeDeletionMarkWithoutProfiles",
		"Visible", Not UseProfiles);
	CommonClientServer.SetFormItemProperty(Items, "ChangeDeletionMarkWithoutProfilesMenu",
		"Visible", Not UseProfiles);
	
	Items.ChangeDeletionMarkWithProfiles.Visible     = UseProfiles;
	Items.ChangeDeletionMarkWithProfilesMenu.Visible = UseProfiles;
	
	If Not Common.SubsystemExists("StandardSubsystems.BatchEditObjects")
		Or Not AccessRight("Update", Metadata.Catalogs.AdditionalReportsAndDataProcessors) Then
		Items.ChangeSelectedItems.Visible = False;
		Items.ChangeSelectedItemsMenu.Visible = False;
	EndIf;
	
	If Parameters.Property("AdditionalReportsAndDataProcessorsCheck") Then
		Items.Create.Visible = False;
		Items.CreateFolder.Visible = False;
	EndIf;
	
	Items.NoteServiceGroup.Visible = Common.DataSeparationEnabled();
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		For each FormItem In Items.CommandBar.ChildItems Do
			
			Items.Move(FormItem, Items.CommandBarForm);
			
		EndDo;
		
		CommonClientServer.SetFormItemProperty(Items, "CommandBar", "Visible", False);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	If Not ValueIsFilled(PublicationFilter) Then
		PublicationFilter = Settings.Get("PublicationFilter");
		List.Parameters.SetParameterValue("PublicationFilter", PublicationFilter);
	EndIf;
	KindFilter = Settings.Get("KindFilter");
	List.Parameters.SetParameterValue("KindFilter", KindFilter);
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PublicationFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("PublicationFilter");
	If DCParameterValue.Value <> PublicationFilter Then
		DCParameterValue.Value = PublicationFilter;
	EndIf;
EndProcedure

&AtClient
Procedure KindFilterOnChange(Item)
	DCParameterValue = List.Parameters.Items.Find("KindFilter");
	If DCParameterValue.Value <> KindFilter Then
		DCParameterValue.Value = KindFilter;
	EndIf;
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	If UseProfiles Then
		Cancel = True;
		ChangeDeletionMarkList();
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ExportToFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	ExportParameters = New Structure;
	ExportParameters.Insert("Ref",   RowData.Ref);
	ExportParameters.Insert("IsReport", RowData.IsReport);
	ExportParameters.Insert("FileName", RowData.FileName);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportParameters);
EndProcedure

&AtClient
Procedure ImportDataProcessorsReportFile(Command)
	RowData = Items.List.CurrentData;
	If RowData = Undefined Or Not ItemSelected(RowData) Then
		Return;
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("Key", RowData.Ref);
	FormParameters.Insert("ShowImportFromFileDialogOnOpen", True);
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.ObjectForm", FormParameters);
EndProcedure

&AtClient
Procedure ChangeSelectedItems(Command)
	ModuleBatchEditObjectsClient = CommonClient.CommonModule("BatchEditObjectsClient");
	ModuleBatchEditObjectsClient.ChangeSelectedItems(Items.List);
EndProcedure

&AtClient
Procedure PublicationUsed(Command)
	ChangePublication("Used");
EndProcedure

&AtClient
Procedure PublishingDisabled(Command)
	ChangePublication("Disabled");
EndProcedure

&AtClient
Procedure PublicationDebugMode(Command)
	ChangePublication("DebugMode");
EndProcedure

&AtClient
Procedure ChangeDeletionMarkWithProfiles(Command)
	ChangeDeletionMarkList();
EndProcedure

#EndRegion

#Region Private

&AtClient
Function ItemSelected(RowData)
	If TypeOf(RowData.Ref) <> Type("CatalogRef.AdditionalReportsAndDataProcessors") Then
		ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для указанного объекта.
			|Выберите дополнительный отчет или обработку.'; 
			|en = 'Command cannot be executed for the specified object.
			|Select an additional report or data processor.'; 
			|pl = 'Nie można uruchomić polecenia dla określonego obiektu.
			|Wybierz dodatkowe sprawozdanie lub przetwarzanie danych.';
			|es_ES = 'El comando no puede lanzarse para el objeto especificado.
			|Seleccionar un informe adicional o un procesador de datos.';
			|es_CO = 'El comando no puede lanzarse para el objeto especificado.
			|Seleccionar un informe adicional o un procesador de datos.';
			|tr = 'Komut, belirtilen nesne için yürütülemiyor.
			|Ek rapor veya veri işlemcisi seçin.';
			|it = 'Il comando non può essere eseguito per l''oggetto specificato.
			|Selezionare un report aggiuntivo o un elaboratore dati.';
			|de = 'Der Befehl kann nicht für das angegebene Objekt ausgeführt werden.
			|Wählen Sie einen zusätzlichen Bericht oder Datenprozessor aus.'"));
		Return False;
	EndIf;
	If RowData.IsFolder Then
		ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для группы.
			|Выберите дополнительный отчет или обработку.'; 
			|en = 'Cannot execute the command for the group.
			|Select an additional report or data processor.'; 
			|pl = 'Nie można uruchomić polecenia dla grupy.
			|Wybierz dodatkowe sprawozdanie lub przetwarzanie danych.';
			|es_ES = 'El comando no puede lanzarse para el grupo.
			|Seleccionar un informe adicional o un procesador de datos.';
			|es_CO = 'El comando no puede lanzarse para el grupo.
			|Seleccionar un informe adicional o un procesador de datos.';
			|tr = 'Komut grup için yürütülemiyor.
			|Ek rapor veya veri işlemcisi seçin.';
			|it = 'Impossibile eseguire il comando per il gruppo.
			|Selezionare un report aggiuntivo o un elaboratore dati.';
			|de = 'Der Befehl kann nicht für die Gruppe ausgeführt werden.
			|Wählen Sie einen zusätzlichen Bericht oder Datenprozessor.'"));
		Return False;
	EndIf;
	Return True;
EndFunction

&AtClient
Procedure ImportDataProcessorsReportFileCompletion(Result, AdditionalParameters) Export
	
	If Result = "FileImported" Then
		ShowValue(,Items.List.CurrentData.Ref);
	EndIf;
	
EndProcedure	

&AtServer
Procedure SetConditionalAppearance()
	
	List.ConditionalAppearance.Items.Clear();
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Publication");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	//
	Item = List.ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Publication");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

&AtClient
Procedure ChangePublication(PublicationOption)
	
	ClearMessages();
	
	SelectedRows = Items.List.SelectedRows;
	StringsCount = SelectedRows.Count();
	If StringsCount = 0 Then
		ShowMessageBox(, NStr("ru = 'Не выбран ни один дополнительный отчет (обработка)'; en = 'No additional report or data processor is selected.'; pl = 'Nie można uruchomić polecenia dla grupy. Wybierz dodatkowe sprawozdanie lub przetwarzanie danych.';es_ES = 'Ningún informe adicional (procesador de datos) se ha seleccionado';es_CO = 'Ningún informe adicional (procesador de datos) se ha seleccionado';tr = 'Ek rapor veya veri işlemcisi seçilmedi.';it = 'Nessun report aggiuntivo o elaboratore dato è stato selezionato.';de = 'Es wurde kein zusätzlicher Bericht (Datenprozessor) ausgewählt'"));
		Return;
	EndIf;
	
	PublicationChanging(PublicationOption);
	
	If StringsCount = 1 Then
		MessageText = NStr("ru = 'Изменена публикация дополнительного отчета (обработки) ""%1""'; en = 'Availability of """"%1"""" additional report or data processor is changed.'; pl = 'Dostępność dodatkowego raportu lub przetwarzania danych """"%1"""" została zmieniona.';es_ES = 'Envío del informe adicional (procesador de datos) ""%1"" se ha cambiado';es_CO = 'Envío del informe adicional (procesador de datos) ""%1"" se ha cambiado';tr = '""%1"" ek raporun (veri işlemcisinin) yayını değiştirildi';it = 'Disponibilità di """"%1"""" report aggiuntivo o elaboratore dati è stata modificata.';de = 'Dir Veröffentlichung eines zusätzlichen Berichts (Datenprozessor) ""%1"" wird geändert'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, String(SelectedRows[0]));
	Else
		MessageText = NStr("ru = 'Изменена публикация у дополнительных отчетов (обработок): %1'; en = 'Publication of additional reports (data processors) is changed: %1'; pl = 'Publikacja dodatkowych sprawozdań (przetwarzania danych) ""%1"" została zmieniona';es_ES = 'Envío de los informes adicionales (procesadores de datos) se ha cambiado: %1';es_CO = 'Envío de los informes adicionales (procesadores de datos) se ha cambiado: %1';tr = '""%1"" ek raporların (veri işlemcilerin) yayını değiştirildi';it = 'Pubblicazione di report aggiuntivi (elaboratori dati) modificata: %1';de = 'Die Veröffentlichung zusätzlicher Berichte (Bearbeitungen) wurde geändert: %1'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, StringsCount);
	EndIf;
	
	ShowUserNotification(NStr("ru = 'Изменена публикация'; en = 'Availability change'; pl = 'Publikacja została zmieniona';es_ES = 'Envío se ha cambiado';es_CO = 'Envío se ha cambiado';tr = 'Yayın değiştirildi';it = 'Disponibilità di modifica';de = 'Die Veröffentlichung wurde geändert'"),, MessageText);
	
EndProcedure

&AtServer
Procedure PublicationChanging(PublicationOption)
	SelectedRows = Items.List.SelectedRows;
	
	BeginTransaction();
	Try
		For Each AdditionalReportOrDataProcessor In SelectedRows Do
			LockDataForEdit(AdditionalReportOrDataProcessor);
			
			Lock = New DataLock;
			LockItem = Lock.Add("Catalog.AdditionalReportsAndDataProcessors");
			LockItem.SetValue("Ref", AdditionalReportOrDataProcessor);
			Lock.Lock();
		EndDo;
		
		For Each AdditionalReportOrDataProcessor In SelectedRows Do
			Object = AdditionalReportOrDataProcessor.GetObject();
			If PublicationOption = "Used" Then
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Used;
			ElsIf PublicationOption = "DebugMode" Then
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.DebugMode;
			Else
				Object.Publication = Enums.AdditionalReportsAndDataProcessorsPublicationOptions.Disabled;
			EndIf;
			
			Object.AdditionalProperties.Insert("ListCheck");
			If Not Object.CheckFilling() Then
				ErrorPresentation = "";
				MessagesArray = GetUserMessages(True);
				For Each UserMessage In MessagesArray Do
					ErrorPresentation = ErrorPresentation + UserMessage.Text + Chars.LF;
				EndDo;
				
				Raise ErrorPresentation;
			EndIf;
			
			Object.Write();
		EndDo;
		
		UnlockDataForEdit();
		CommitTransaction();
	Except
		RollbackTransaction();
		UnlockDataForEdit();
		Raise;
	EndTry;
	Items.List.Refresh();
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkList()
	TableRow = Items.List.CurrentData;
	If TableRow = Undefined Then
		Return;
	EndIf;
	
	Context = New Structure("Ref, DeletionMark");
	FillPropertyValues(Context, TableRow);
	
	If Context.DeletionMark Then
		QuestionText = NStr("ru = 'Снять с ""%1"" пометку на удаление?'; en = 'Do you want to clear a deletion mark for ""%1""?'; pl = 'Czy chcesz oczyścić znacznik usunięcia dla ""%1""?';es_ES = '¿Eliminar la marca para borrar para ""%1""?';es_CO = '¿Eliminar la marca para borrar para ""%1""?';tr = '""%1"" için silme işareti kaldırılsın mı?';it = 'Volete rimuovere il contrassegno per l''eliminazione per ""%1""?';de = 'Löschzeichen für ""%1"" löschen?'");
	Else
		QuestionText = NStr("ru = 'Пометить ""%1"" на удаление?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Czy chcesz zaznaczyć ""%1"" do usunięcia?';es_ES = '¿Marcar ""%1"" para borrar?';es_CO = '¿Marcar ""%1"" para borrar?';tr = '""%1"" silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare %1 per l''eliminazione?';de = 'Markieren Sie ""%1"" zum Löschen?'");
	EndIf;
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(QuestionText, TableRow.Description);
	
	Handler = New NotifyDescription("ChangeDeletionMarkListAfterConfirm", ThisObject, Context);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo);
EndProcedure

&AtClient
Procedure ChangeDeletionMarkListAfterConfirm(Response, Context) Export
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	Context.Insert("Queries", Undefined);
	Context.Insert("FormID", UUID);
	LockObjectsAndGeneratePermissionsQueries(Context);
	
	Handler = New NotifyDescription("ChangeDeletionMarkListAfterConfirmQueries", ThisObject, Context);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Context.Queries, ThisObject, Handler);
	Else
		ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
	EndIf;
EndProcedure

&AtServerNoContext
Procedure LockObjectsAndGeneratePermissionsQueries(Context)
	LockDataForEdit(Context.Ref, , Context.FormID);
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Object = Context.Ref.GetObject();
		
		Context.Queries = AdditionalReportsAndDataProcessorsSafeModeInternal.AdditionalDataProcessorPermissionRequests(
			Object,
			Object.Permissions.Unload(),
			,
			Not Context.DeletionMark);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeDeletionMarkListAfterConfirmQueries(Response, Context) Export
	ModifyMark = (Response = DialogReturnCode.OK);
	UnlockAndChangeObjectsDeletionMark(Context, ModifyMark);
	Items.List.Refresh();
EndProcedure

&AtServerNoContext
Procedure UnlockAndChangeObjectsDeletionMark(Context, ModifyMark)
	If ModifyMark Then
		Object = Context.Ref.GetObject();
		Object.SetDeletionMark(Not Context.DeletionMark);
		Object.Write();
	EndIf;
	UnlockDataForEdit(Context.Ref, Context.FormID);
EndProcedure

#EndRegion
