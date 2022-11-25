#Region Variables

&AtClient
Var ClientCache;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		AND Not Common.SubsystemExists("StandardSubsystems.Print") Then
		Cancel = True;
		CommonClientServer.MessageToUser(NStr("ru = 'Работа с печатными формами не поддерживается.'; en = 'Print forms are not supported.'; pl = 'Praca z formularzami wydruku nie jest obsługiwana.';es_ES = 'No se admite el uso de los formularios de impresión.';es_CO = 'No se admite el uso de los formularios de impresión.';tr = 'Yazdırma formları desteklenmiyor.';it = 'I moduli di stampa non sono supportati';de = 'Die Arbeit mit Druckformularen wird nicht unterstützt.'"));
		Return;
	EndIf;
	
	// Checking if new data processors can be imported into the infobase.
	IsNew = Object.Ref.IsEmpty();
	InsertRight = AdditionalReportsAndDataProcessors.InsertRight();
	If Not InsertRight Then
		If IsNew Then
			Raise NStr("ru = 'Недостаточно прав доступа для добавления дополнительных отчетов или обработок.'; en = 'Insufficient access rights for adding additional reports or data processors. .'; pl = 'Niewystarczające prawa dostępu do dodatkowych sprawozdań lub przetwarzania danych.';es_ES = 'Derechos insuficientes de acceso para añadir informes adicionales y procesadores de datos.';es_CO = 'Derechos insuficientes de acceso para añadir informes adicionales y procesadores de datos.';tr = 'Ek raporlar veya veri işlemcileri eklemek için yetersiz erişim hakları.';it = 'Permessi di accesso non sufficienti per aggiungere report aggiuntivi o elaboratori dati.';de = 'Unzureichende Zugriffsrechte zum Hinzufügen zusätzlicher Berichte und Datenprozessoren.'");
		Else
			Items.LoadFromFile.Visible = False;
			Items.ExportToFile.Visible = False;
		EndIf;
	EndIf;
	
	// Restricting publication kind selection depending on the infobase settings.
	Items.Publication.ChoiceList.Clear();
	AvaliablePublicationKinds = AdditionalReportsAndDataProcessorsCached.AvaliablePublicationKinds();
	For Each PublicationKind In AvaliablePublicationKinds Do
		Items.Publication.ChoiceList.Add(PublicationKind);
	EndDo;
	
	// Restricting detailed information display.
	ExtendedInformationDisplaying = AdditionalReportsAndDataProcessors.DisplayExtendedInformation(Object.Ref);
	Items.AdditionalInfoPage.Visible = ExtendedInformationDisplaying;
	
	// Restricting data processor import from / export to a file.
	If Not AdditionalReportsAndDataProcessors.CanImportDataProcessorFromFile(Object.Ref) Then
		Items.LoadFromFile.Visible = False;
	EndIf;
	If Not AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Object.Ref) Then
		Items.ExportToFile.Visible = False;
	EndIf;
	
	KindAdditionalDataProcessor = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalDataProcessor;
	KindAdditionalReport     = Enums.AdditionalReportsAndDataProcessorsKinds.AdditionalReport;
	ReportKind                   = Enums.AdditionalReportsAndDataProcessorsKinds.Report;
	
	Parameters.Property("ShowImportFromFileDialogOnOpen", ShowImportFromFileDialogOnOpen);
	
	If IsNew Then
		Object.UseForObjectForm = True;
		Object.UseForListForm  = True;
		ShowImportFromFileDialogOnOpen = True;
	EndIf;
	
	If ShowImportFromFileDialogOnOpen AND Not Items.LoadFromFile.Visible Then
		Raise NStr("ru = 'Недостаточно прав для загрузки дополнительных отчетов и обработок'; en = 'Insufficient rights to import additional report or data processor'; pl = 'Niewystarczające uprawnienia do importowania dodatkowych sprawozdań lub przetwarzania danych';es_ES = 'Derechos insuficientes para importar informes adicionales y procesadores de datos';es_CO = 'Derechos insuficientes para importar informes adicionales y procesadores de datos';tr = 'Ek raporları veya veri işlemcilerini içe aktarmak için yetersiz yetki';it = 'Permessi insufficienti per importare report aggiuntivi o elaboratori dati';de = 'Unzureichende Rechte zum Importieren zusätzlicher Berichte und Datenprozessoren'");
	EndIf;
	
	FillInCommands();
	
	PermissionsAddress = PutToTempStorage(
		FormAttributeToValue("Object").Permissions.Unload(),
		ThisObject.UUID);
	
	SetVisibilityAvailability();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ClientCache = New Structure;
	
	If ShowImportFromFileDialogOnOpen Then
		AttachIdleHandler("UpdateFromFileStart", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.PlacementInSections") Then
		
		If TypeOf(SelectedValue) <> Type("ValueList") Then
			Return;
		EndIf;
		
		Object.Sections.Clear();
		For Each ListItem In SelectedValue Do
			NewRow = Object.Sections.Add();
			NewRow.Section = ListItem.Value;
		EndDo;
		
		Modified = True;
		SetVisibilityAvailability();
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors") Then
		
		If TypeOf(SelectedValue) <> Type("ValueList") Then
			Return;
		EndIf;
		
		ItemCommand = Object.Commands.FindByID(ClientCache.CommandRowID);
		If ItemCommand = Undefined Then
			Return;
		EndIf;
		
		FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
		For Each TableRow In FoundItems Do
			QuickAccess.Delete(TableRow);
		EndDo;
		
		For Each ListItem In SelectedValue Do
			TableRow = QuickAccess.Add();
			TableRow.CommandID = ItemCommand.ID;
			TableRow.User = ListItem.Value;
		EndDo;
		
		ItemCommand.QuickAccessPresentation = UserQuickAccessPresentation(SelectedValue.Count());
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SelectMetadataObjects" Then
		
		ImportSelectedMetadataObjects(Parameter);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If AdditionalReportsAndDataProcessors.CanExportDataProcessorToFile(Object.Ref) Then
		
		DataProcessorDataAddress = PutToTempStorage(
			CurrentObject.DataProcessorStorage.Get(),
			UUID);
		
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", CurrentObject.Ref);
	Query.Text =
	"SELECT ALLOWED
	|	RegisterData.CommandID,
	|	RegisterData.User
	|FROM
	|	InformationRegister.DataProcessorAccessUserSettings AS RegisterData
	|WHERE
	|	RegisterData.AdditionalReportOrDataProcessor = &Ref
	|	AND RegisterData.Available = TRUE
	|	AND NOT RegisterData.User.DeletionMark
	|	AND NOT RegisterData.User.Invalid";
	QuickAccess.Load(Query.Execute().Unload());
	
	// StandardSubsystems.AccessManagement
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.OnReadAtServer(ThisObject, CurrentObject);
	EndIf;
	// End StandardSubsystems.AccessManagement

EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	If DataProcessorRegistration AND AdditionalReportsAndDataProcessors.CanImportDataProcessorFromFile(Object.Ref) Then
		DataProcessorBinaryData = GetFromTempStorage(DataProcessorDataAddress);
		CurrentObject.DataProcessorStorage = New ValueStorage(DataProcessorBinaryData, New Deflation(9));
	EndIf;
	
	If Object.Kind = KindAdditionalDataProcessor OR Object.Kind = KindAdditionalReport Then
		CurrentObject.AdditionalProperties.Insert("RelevantCommands", Object.Commands.Unload());
	Else
		QuickAccess.Clear();
	EndIf;
	
	CurrentObject.AdditionalProperties.Insert("QuickAccess", QuickAccess.Unload());
	
	CurrentObject.Permissions.Load(GetFromTempStorage(PermissionsAddress));
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	If CurrentObject.AdditionalProperties.Property("ConnectionError") Then
		MessageText = CurrentObject.AdditionalProperties.ConnectionError;
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	IsNew = False;
	If DataProcessorRegistration Then
		RefreshReusableValues();
		DataProcessorRegistration = False;
	EndIf;
	FillInCommands();
	SetVisibilityAvailability();
	
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		AND Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ModulePrintManager.DisablePrintCommands(SelectedRelatedObjects().UnloadValues(), CommandsToDisable().UnloadValues());
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AdditionalReportOptionBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure AdditionalReportOptionBeforeRowChange(Item, Cancel)
	Cancel = True;
	OpenOption();
EndProcedure

&AtClient
Procedure AdditionalReportOptionsBeforeDelete(Item, Cancel)
	Cancel = True;
	Option = Items.AdditionalReportOptions.CurrentData;
	If Option = Undefined Then
		Return;
	EndIf;
	
	If NOT Option.Custom Then
		ShowMessageBox(, NStr("ru = 'Пометка на удаление предопределенного варианта отчета запрещена.'; en = 'Cannot mark a predefined report option for deletion.'; pl = 'Nie można zaznaczyć predefiniowanej opcji sprawozdania do usunięcia.';es_ES = 'No se puede marcar la opción del informe predefinido para borrar.';es_CO = 'No se puede marcar la opción del informe predefinido para borrar.';tr = 'Silinmek üzere önceden tanımlanmış rapor seçeneği işaretlenemez.';it = 'Non è possibile contrassegnare per l''eliminazione un variante di report predefinita.';de = 'Die vordefinierte Berichtsoption kann nicht zum Löschen markiert werden.'"));
		Return;
	EndIf;
	
	QuestionText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Пометить ""%1"" на удаление?'; en = 'Do you want to mark %1 for deletion?'; pl = 'Czy chcesz zaznaczyć ""%1"" do usunięcia?';es_ES = '¿Marcar ""%1"" para borrar?';es_CO = '¿Marcar ""%1"" para borrar?';tr = '%1 silinmek üzere işaretlensin mi?';it = 'Volete contrassegnare %1 per l''eliminazione?';de = 'Markieren Sie ""%1"" zum Löschen?'"), Option.Description);
	
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("Variant", Option);
	Handler = New NotifyDescription("AdditionalReportOptionsBeforeDeleteCompletion", ThisObject, AdditionalParameters);
	ShowQueryBox(Handler, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.Yes);
EndProcedure

&AtClient
Procedure UseForListFormOnChange(Item)
	If NOT Object.UseForObjectForm AND NOT Object.UseForListForm Then
		Object.UseForObjectForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure UseForObjectFormOnChange(Item)
	If NOT Object.UseForObjectForm AND NOT Object.UseForListForm Then
		Object.UseForListForm = True;
	EndIf;
EndProcedure

&AtClient
Procedure DecorationSecurityProfileEnablingLabelURLProcessing(Item, FormattedStringURL, StandardProcessing)
	
	If FormattedStringURL = "int://sp-on" Then
		
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.OpenSecurityProfileSetupDialog();
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandsPlacementClick(Item, StandardProcessing)
	StandardProcessing = False;
	If Object.Kind = KindAdditionalReport OR Object.Kind = KindAdditionalDataProcessor Then
		// Selecting sections
		Sections = New ValueList;
		For Each TableRow In Object.Sections Do
			Sections.Add(TableRow.Section);
		EndDo;
		
		FormParameters = New Structure;
		FormParameters.Insert("Sections",      Sections);
		FormParameters.Insert("DataProcessorKind", Object.Kind);
		
		OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.PlacementInSections", FormParameters, ThisObject);
	Else
		// Select metadata objects
		FormParameters = PrepareMetadataObjectSelectionFormParameters();
		OpenForm("CommonForm.SelectMetadataObjects", FormParameters);
	EndIf;
EndProcedure

#EndRegion

#Region ObjectCommandsFormTableItemEventHandlers

&AtClient
Procedure ObjectCommandsQuickAccessPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChangeQuickAccess();
EndProcedure

&AtClient
Procedure ObjectCommandsQuickAccessPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobUsageOnChange(Item)
	EditScheduledJob(False, True);
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobPresentationStartChoice(Item, ChoiceData, StandardProcessing)
	EditScheduledJob(True, False);
EndProcedure

&AtClient
Procedure ObjectCommandsScheduledJobPresentationClearing(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

&AtClient
Procedure ObjectCommandsSetQuickAccess(Command)
	ChangeQuickAccess();
EndProcedure

&AtClient
Procedure ObjectCommandsSetSchedule(Command)
	EditScheduledJob(True, False);
EndProcedure

&AtClient
Procedure ObjectCommandsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
EndProcedure

&AtClient
Procedure ObjectCommandsBeforeDelete(Item, Cancel)
	Cancel = True;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure CommandWriteAndClose(Command)
	WriteAtClient(True);
EndProcedure

&AtClient
Procedure CommandWrite(Command)
	WriteAtClient(False);
EndProcedure

&AtClient
Procedure LoadFromFile(Command)
	UpdateFromFileStart();
EndProcedure

&AtClient
Procedure ExportToFile(Command)
	ExportParameters = New Structure;
	ExportParameters.Insert("IsReport", Object.Kind = ReportKind Or Object.Kind = KindAdditionalReport);
	ExportParameters.Insert("FileName", Object.FileName);
	ExportParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	AdditionalReportsAndDataProcessorsClient.ExportToFile(ExportParameters);
EndProcedure

&AtClient
Procedure AdditionalReportOptionsOpen(Command)
	Option = ThisObject.Items.AdditionalReportOptions.CurrentData;
	If Option = Undefined Then
		ShowMessageBox(, NStr("ru = 'Выберите вариант отчета.'; en = 'Select report option.'; pl = 'Wybierz wariant raportu.';es_ES = 'Seleccionar la opción de informe.';es_CO = 'Seleccionar la opción de informe.';tr = 'Rapor seçeneğini seçin.';it = 'Selezionate la variante di report.';de = 'Wählen Sie die Berichtsoption.'"));
		Return;
	EndIf;
	
	AdditionalReportsAndDataProcessorsClient.OpenAdditionalReportOption(Object.Ref, Option.VariantKey);
EndProcedure

&AtClient
Procedure PlaceInSections(Command)
	OptionsArray = New Array;
	For Each RowID In Items.AdditionalReportOptions.SelectedRows Do
		Option = AdditionalReportOptions.FindByID(RowID);
		If ValueIsFilled(Option.Ref) Then
			OptionsArray.Add(Option.Ref);
		EndIf;
	EndDo;
	
	// Opening a dialog for assigning multiple report options to command interface sections
	If CommonClient.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
		ModuleReportOptionsClient.OpenOptionArrangeInSectionsDialog(OptionsArray);
	EndIf;
EndProcedure

&AtClient
Procedure SetVisibility(Command)
	If Modified Then
		NotifyDescription = New NotifyDescription("SetUpVisibilityCompletion", ThisObject);
		QuestionText = NStr("ru = 'Для настройки видимости команд печати обработку необходимо записать. Продолжить?'; en = 'To set the print command visibility, write the data processor. Continue?'; pl = 'Aby ustawić widoczność poleceń wydruku przetwarzanie należy zapisać. Kontynuować?';es_ES = 'Para ajustar la visibilidad de los comandos de impresión hay que guardar el procesamiento. ¿Continuar?';es_CO = 'Para ajustar la visibilidad de los comandos de impresión hay que guardar el procesamiento. ¿Continuar?';tr = 'Yazdırma komutlarının görünürlüğünü ayarlamak için işleme yazılmalıdır. Devam etmek istiyor musunuz?';it = 'Per impostare la visibilità del comando di stampa serve registrare l''elaboratore dati. Continuare?';de = 'Um die Sichtbarkeit von Druckbefehlen anzupassen, muss die Verarbeitung aufgezeichnet werden. Fortsetzen?'");
		Buttons = New ValueList;
		Buttons.Add("Continue", NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QuestionText, Buttons);
	Else
		OpenPrintSubmenuSettingsForm();
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteCommand(Command)
	CommandTableRow = Items.ObjectCommands.CurrentData;
	If CommandTableRow = Undefined Then
		Return;
	EndIf;
	If Not CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm")
		AND Not CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall")
		AND Not CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		AND Not CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode") Then
		Return;
	EndIf;
	
	Context = New Structure;
	Context.Insert("CommandToExecuteID", CommandTableRow.ID);
	Handler = New NotifyDescription("ExecuteCommandAfterWriteConfirmed", ThisObject, Context);
	
	If Object.Ref.IsEmpty() Or Modified Then
		QuestionText = NStr("ru = 'Для выполнения команды необходимо записать данные.'; en = 'Write data to execute the command.'; pl = 'Aby uruchomić polecenie zapisz dane.';es_ES = 'Para lanzar el comando, grabar los datos.';es_CO = 'Para lanzar el comando, grabar los datos.';tr = 'Komutunu çalıştırmak için verileri yazın.';it = 'Registra i dati per eseguire il comando.';de = 'Um den Befehl auszuführen, ist es notwendig, die Daten aufzuschreiben.'");
		Buttons = New ValueList;
		Buttons.Add("WriteAndContinue", NStr("ru = 'Записать и продолжить'; en = 'Save and continue'; pl = 'Zapisz i kontynuuj';es_ES = 'Grabar y continuar';es_CO = 'Grabar y continuar';tr = 'Kaydet ve devam et';it = 'Salva e continua';de = 'Schreibe und fahre fort'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(Handler, QuestionText, Buttons);
	Else
		ExecuteNotifyProcessing(Handler, "ContinueWithoutWriting");
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobUsage.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Commands.ScheduledJobAllowed");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("ReadOnly", True);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ObjectCommandsScheduledJobPresentation.Name);

	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.Commands.ScheduledJobUsage");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;

	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client

&AtClient
Procedure WriteAtClient(CloseAfterWrite)
	
	Handler = New NotifyDescription("ContinueWriteAtClient", ThisObject, CloseAfterWrite);
	If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		Queries = PermissionUpdateRequests();
		ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
		ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, Handler);
	Else
		ExecuteNotifyProcessing(Handler, DialogReturnCode.OK);
	EndIf;
	
EndProcedure

&AtClient
Procedure ContinueWriteAtClient(Result, CloseAfterWrite)  Export
	
	WriteParameters = New Structure;
	WriteParameters.Insert("DataProcessorRegistration", DataProcessorRegistration);
	WriteParameters.Insert("CloseAfterWrite", CloseAfterWrite);
	
	Success = Write(WriteParameters);
	If Not Success Then
		Return;
	EndIf;
	
	If WriteParameters.DataProcessorRegistration Then
		RefreshReusableValues();
		NotificationText = NStr("ru = 'Для применения изменений в открытых окнах необходимо их закрыть и открыть заново.'; en = 'To apply the changes to the open windows, close and reopen them.'; pl = 'Aby zastosować zmiany w oknach otwartych, należy je zamknąć i ponownie otworzyć.';es_ES = 'Para aplicar los cambios en las ventanas abiertas es necesario cerrarlas y abrirlas de nuevo.';es_CO = 'Para aplicar los cambios en las ventanas abiertas es necesario cerrarlas y abrirlas de nuevo.';tr = 'Açık pencerelerde değişiklikleri uygulamak için bunları kapatın ve yeniden açın.';it = 'Per applicare le modifiche alle finestre aperte, chiuderle e riaprirle.';de = 'Um Änderungen in den geöffneten Fenstern zu übernehmen, sollten Sie diese schließen und neu öffnen.'");
		ShowUserNotification(, , NotificationText);
	EndIf;
	WriteAtClientEnd(WriteParameters);
	
EndProcedure

&AtServer
Function PermissionUpdateRequests()
	
	Return AdditionalReportsAndDataProcessorsSafeModeInternal.AdditionalDataProcessorPermissionRequests(
		Object, SecurityProfilePermissions());
	
EndFunction

&AtClient
Procedure WriteAtClientEnd(WriteParameters)
	If WriteParameters.CloseAfterWrite AND IsOpen() Then
		Close();
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileStart()
	Notification = New NotifyDescription("UpdateFromFileAfterConfirm", ThisObject);
	FormParameters = New Structure("Key", "BeforeAddExternalReportOrDataProcessor");
	OpenForm("CommonForm.SecurityWarning", FormParameters, , , , , Notification);
EndProcedure

&AtClient
Procedure UpdateFromFileAfterConfirm(Response, RegistrationParameters) Export
	If Response <> "Continue" Then
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		Return;
	EndIf;
	
	RegistrationParameters = New Structure;
	RegistrationParameters.Insert("Success", False);
	RegistrationParameters.Insert("DataProcessorDataAddress", DataProcessorDataAddress);
	Handler = New NotifyDescription("UpdateFromFileAfterFileChoice", ThisObject, RegistrationParameters);
	
	DialogParameters = New Structure("Mode, Filter, FilterIndex, Title");
	DialogParameters.Mode  = FileDialogMode.Open;
	DialogParameters.Filter = AdditionalReportsAndDataProcessorsClientServer.SelectingAndSavingDialogFilter();
	If Object.Ref.IsEmpty() Then
		DialogParameters.FilterIndex = 0;
		DialogParameters.Title = NStr("ru = 'Выберите файл внешнего отчета или обработки'; en = 'Select a file of external report or data processor'; pl = 'Wybierz plik raportu zewnętrznego lub procesora danych';es_ES = 'Seleccionar un archivo del informe externo o el procesador de datos.';es_CO = 'Seleccionar un archivo del informe externo o el procesador de datos.';tr = 'Harici rapor veya veri işlemcisi seçin';it = 'Seleziona il file di report esterno o il file di elaborazione';de = 'Wählen Sie eine Datei mit einem externen Bericht oder Datenprozessor aus'");
	ElsIf Object.Kind = KindAdditionalReport Or Object.Kind = ReportKind Then
		DialogParameters.FilterIndex = 1;
		DialogParameters.Title = NStr("ru = 'Выберите файл внешнего отчета'; en = 'Select external report file'; pl = 'Wybierz plik zewnętrznego sprawozdania';es_ES = 'Seleccionar un archivo del informe externo';es_CO = 'Seleccionar un archivo del informe externo';tr = 'Harici rapor dosyası seçin';it = 'Seleziona un file di report esterno';de = 'Wählen Sie eine externe Berichtsdatei'");
	Else
		DialogParameters.FilterIndex = 2;
		DialogParameters.Title = NStr("ru = 'Выберите файл внешней обработки'; en = 'Select external data processor file'; pl = 'Wybierz plik zewnętrznego przetwarzania danych';es_ES = 'Seleccionar un archivo del procesador de datos externo';es_CO = 'Seleccionar un archivo del procesador de datos externo';tr = 'Harici veri işlemcisi dosyası seçin';it = 'Seleziona un file di elaboratore esterno';de = 'Wählen Sie eine externe Datenprozessordatei aus'");
	EndIf;
	
	StandardSubsystemsClient.ShowPutFile(Handler, UUID, Object.FileName, DialogParameters);
EndProcedure

&AtClient
Procedure UpdateFromFileAfterFileChoice(FilesThatWerePut, RegistrationParameters) Export
	If FilesThatWerePut = Undefined Or FilesThatWerePut.Count() = 0 Then
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		Return;
	EndIf;
	
	FileDetails = FilesThatWerePut[0];
	
	Keys = New Structure("FileName, IsReport, DisablePublication, DisableConflicts, Conflicting");
	CommonClientServer.SupplementStructure(RegistrationParameters, Keys, False);
	
	RegistrationParameters.DisablePublication = False;
	RegistrationParameters.DisableConflicts = False;
	RegistrationParameters.Conflicting = New ValueList;
	
	SubstringsArray = StrSplit(FileDetails.Name, "\", False);
	RegistrationParameters.FileName = SubstringsArray.Get(SubstringsArray.UBound());
	FileExtention = Upper(Right(RegistrationParameters.FileName, 3));
	
	If FileExtention = "ERF" Then
		RegistrationParameters.IsReport = True;
	ElsIf FileExtention = "EPF" Then
		RegistrationParameters.IsReport = False;
	Else
		RegistrationParameters.Success = False;
		ResultHandler = New NotifyDescription("UpdateFromFileCompletion", ThisObject, RegistrationParameters);
		WarningText = NStr("ru = 'Расширение файла не соответствует расширению внешнего отчета (ERF) или обработки (EPF).'; en = 'The file extension does not match external report extension (ERF) or external data processor extension (EPF).'; pl = 'Rozszerzenie pliku nie jest zgodne ze sprawozdaniem zewnętrznym (ERF) lub procesorem przetwarzania danych (EPF).';es_ES = 'Extensión del archivo no coincide con aquellas del informe externo (FER) o el procesador de datos (EPF).';es_CO = 'Extensión del archivo no coincide con aquellas del informe externo (FER) o el procesador de datos (EPF).';tr = 'Dosya uzantısı harici rapor uzantısı (ERF) veya harici veri işlemcisi uzantısı (EPF) ile uyuşmuyor.';it = 'L''estensione del file non corrisponde all''estensione del report (ERF) o dell''elaborazione (EPF) esterna.';de = 'Die Dateierweiterung stimmt nicht mit der des externen Berichts (ERF) oder Datenprozessors (EPF) überein.'");
		ReturnParameters = New Structure;
		ReturnParameters.Insert("Handler", ResultHandler);
		ReturnParameters.Insert("Result",  Undefined);
		SimpleDialogHandler = New NotifyDescription("ReturnResultAfterCloseSimpleDialog", ThisObject, ReturnParameters);
		ShowMessageBox(SimpleDialogHandler, WarningText);
		Return;
	EndIf;
	
	RegistrationParameters.DataProcessorDataAddress = FileDetails.Location;
	
	UpdateFromFileClientMechanics(RegistrationParameters);
EndProcedure

&AtClient
Procedure ReturnResultAfterCloseSimpleDialog(HandlerParameters) Export
	If TypeOf(HandlerParameters.Handler) = Type("NotifyDescription") Then
		ExecuteNotifyProcessing(HandlerParameters.Handler, HandlerParameters.Result);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileClientMechanics(RegistrationParameters)
	// Server call.
	UpdateFromFileServerMechanics(RegistrationParameters);
	
	If RegistrationParameters.DisableConflicts Then
		// Multiple objects are disabled, which requires dynamic list refresh.
		NotifyChanged(Type("CatalogRef.AdditionalReportsAndDataProcessors"));
	EndIf;
	
	// Processing server execution result.
	If RegistrationParameters.Success Then
		NotificationTitle = ?(RegistrationParameters.IsReport, NStr("ru = 'Файл внешнего отчета загружен'; en = 'External report file is imported'; pl = 'Plik raportu zewnętrznego jest importowany';es_ES = 'Archivo del informe externo se ha importado';es_CO = 'Archivo del informe externo se ha importado';tr = 'Harici rapor dosyası içe aktarıldı';it = 'Il file di report esterno è stato importato';de = 'Externe Berichtsdatei wird importiert'"), NStr("ru = 'Файл внешней обработки загружен'; en = 'External data processor file is imported'; pl = 'Plik zewnętrznego procesora danych jest importowany';es_ES = 'Archivo del procesador de datos externo se ha importado';es_CO = 'Archivo del procesador de datos externo se ha importado';tr = 'Harici veri işlemcisi dosyası içe aktarıldı';it = 'Il file esterno dell''elaboratore dati è stato importato';de = 'Externe Datenprozessordatei wird importiert'"));
		NotificationRef    = ?(IsNew, "", GetURL(Object.Ref));
		NotificationText     = RegistrationParameters.FileName;
		ShowUserNotification(NotificationTitle, NotificationRef, NotificationText);
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	Else
		// Checking the reason of canceling data processor import and displaying the reason to the user.
		If RegistrationParameters.ObjectNameUsed Then
			UpdateFromFileShowConflicts(RegistrationParameters);
		Else
			ResultHandler = New NotifyDescription("UpdateFromFileCompletion", ThisObject, RegistrationParameters);
			QuestionParameters = StandardSubsystemsClient.QuestionToUserParameters();
			QuestionParameters.SuggestDontAskAgain = False;
			StandardSubsystemsClient.ShowQuestionToUser(ResultHandler, RegistrationParameters.ErrorText, 
				QuestionDialogMode.OK, QuestionParameters);
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileShowConflicts(RegistrationParameters)
	If RegistrationParameters.ConflictsCount > 1 Then
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("ru = 'Конфликты при загрузке внешнего отчета'; en = 'Conflicts during external report import'; pl = 'Konflikty podczas importu zewnętrznego sprawozdania';es_ES = 'Conflictos durante la importación del informe externo';es_CO = 'Conflictos durante la importación del informe externo';tr = 'Harici rapor içe aktarılırken oluşan çakışmalar';it = 'Conflitti durante il caricamento di un report esterno';de = 'Konflikte beim externen Berichtsimport'");
			QuestionText = NStr("ru = 'Внутреннее имя отчета ""[Name]""
			|уже занято существующими дополнительными отчетами ([Count]): 
			|[List].
			|
			|Выберите:
			|1. ""[Continue]"" - загрузить новый отчет в режиме отладки.
			|2. ""[Disable]"" - загрузить новый отчет, отключив публикацию всех конфликтующих отчетов.
			|3. ""[Open]"" - отменить загрузку и показать список конфликтующих отчетов.'; 
			|en = 'Internal report name ""[Name]"" 
			|is already used by the existing additional reports ([Count]): 
			|[List].
			|
			|Select:
			|1. ""[Continue]"" - import a new report in the debug mode.
			|2. ""[Disable]"" - disable publication of all conflicting reports and import a new report.
			|3. ""[Open]"" - cancel import and show  the list of conflicting reports.'; 
			|pl = 'Nazwa wewnętrzna sprawozdania ""[Name]""
			|jest już zajęta przez istniejące dodatkowe raporty ([Count]): 
			|[List].
			|
			|Wybierz:
			|1. ""[Continue]"" - pobierz nowy raport w trybie debugowania.
			|2. ""[Disable]"" - pobierz nowy raport z wyłączeniem publikacji wszystkich konfliktujących raportów.
			|3. ""[Open]"" - anuluj pobieranie i pokaż listę konfliktujących raportów.';
			|es_ES = 'El nombre interno del informe ""[Name]""
			|ya está ocupado por los informes adicionales existentes ([Count]): 
			|[List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el informe nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el informe nuevo desactivando la publicación de todos los informes enfrentados.
			|3. ""[Open]"" - cancelar la carga y mostrar la lista de los informes enfrentados.';
			|es_CO = 'El nombre interno del informe ""[Name]""
			|ya está ocupado por los informes adicionales existentes ([Count]): 
			|[List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el informe nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el informe nuevo desactivando la publicación de todos los informes enfrentados.
			|3. ""[Open]"" - cancelar la carga y mostrar la lista de los informes enfrentados.';
			|tr = '""[Name]"" raporunun 
			|dahili adı zaten mevcut ek raporlar tarafından alınmış ([Count]): 
			|[List]. 
			|
			|Seçin: 
			|1. ""[Continue]"" - hata ayıklama modunda yeni bir rapor indir. 
			|2. ""[Disable]"" - tüm çelişkili raporların yayınlanmasını engelleyen yeni bir rapor indirin. 
			|3. ""[Open]"" - indirmeyi iptal edin ve çakışan raporların bir listesini gösterin.';
			|it = 'Nome report interno ""[Name]""
			|già autorizzato dai report aggiuntivi esistenti ([Count]): 
			|[List].
			|
			|Selezionare:
			|1. ""[Continue]"" - importare un nuovo report in modalità debug.
			|2. ""[Disable]"" - disabilitare la pubblicazione di tutti i report in conflitto e importare un nuovo report.
			|3. ""[Open]"" - annullare importazione e mostrare elenco dei report in conflitto.';
			|de = 'Der interne Name des Berichts ""[Name]""
			|ist bereits durch bestehende zusätzliche Berichte belegt ([Count]):
			|[List].
			|
			|Wählen Sie:
			|1. ""[Continue]"" - einen neuen Bericht im Debug-Modus herunterladen.
			|2. ""[Disable]"" - Laden Sie den neuen Bericht herunter, indem Sie die Veröffentlichung aller widersprüchlichen Berichte deaktivieren.
			|3. ""[Open]"" - bricht den Download ab und zeigt die Liste der widersprüchlichen Berichte an.'");
		Else
			QuestionTitle = NStr("ru = 'Конфликты при загрузке внешней обработки'; en = 'Conflicts occurred during import of external data processor'; pl = 'Konflikty podczas importu zewnętrznego procesora przetwarzania danych';es_ES = 'Conflictos ocurridos durante la importación el procesador de datos externo';es_CO = 'Conflictos ocurridos durante la importación el procesador de datos externo';tr = 'Harici veri işlemcisi içe aktarılırken çakışmalar meydana geldi';it = 'Conflitti durante il caricamento dell''elaborazione esterna';de = 'Beim Import des externen Datenprozessors sind Konflikte aufgetreten'");
			QuestionText = NStr("ru = 'Внутреннее имя обработки ""[Name]""
			|уже занято существующими дополнительными обработками ([Count]):
			|[List].
			|
			|Выберите:
			|1. ""[Continue]"" - загрузить новую обработку в режиме отладки.
			|2. ""[Disable]"" - загрузить новую обработку, отключив публикацию всех конфликтующих обработок.
			|3. ""[Open]"" - отменить загрузку и показать список конфликтующих обработок.'; 
			|en = 'Internal name of data processor ""[Name]"" 
			|is already used by the existing additional data processors ([Count]): 
			|[List].
			|
			|Select:
			|1. ""[Continue]"" - import a new data processor in the debug mode.
			|2. ""[Disable]"" - disable publication of all conflicting data processors and import a new data processor.
			|3. ""[Open]"" - cancel import  and show conflicting data processors list.'; 
			|pl = 'Nazwa wewnętrzna przetwarzania ""[Name]""
			|jest już zajęta przez istniejące dodatkowe procedury przetwarzania ([Count]): 
			|[List].
			|
			|Wybierz:
			|1. ""[Continue]"" - pobierz nowe przetwarzanie w trybie debugowania.
			|2. ""[Disable]"" - pobierz nowe przetwarzanie z wyłączeniem publikacji wszystkich konfliktujących procedur przetwarzania
			|3. ""[Open]"" - anuluj pobieranie i pokaż listę konfliktujących procedur przetwarzania.';
			|es_ES = 'El nombre interno del procesamiento ""[Name]""
			|ya está ocupado por los procesamientos adicionales existentes ([Count]): 
			|[List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el procesamiento nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el procesamiento nuevo desactivando la publicación de todos los procesamientos enfrentados.
			|3. ""[Open]"" - cancelar la carga y mostrar la lista de los procesamientos enfrentados.';
			|es_CO = 'El nombre interno del procesamiento ""[Name]""
			|ya está ocupado por los procesamientos adicionales existentes ([Count]): 
			|[List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el procesamiento nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el procesamiento nuevo desactivando la publicación de todos los procesamientos enfrentados.
			|3. ""[Open]"" - cancelar la carga y mostrar la lista de los procesamientos enfrentados.';
			|tr = '""[Name]"" raporunun 
			|dahili adı zaten mevcut ek veri işlemcileri tarafından alınmış ([Count]): 
			|[List]. 
			|
			|Seçin: 
			|1. ""[Continue]"" - hata ayıklama modunda yeni bir veri işlemcisini indir. 
			|2. ""[Disable]"" - tüm çelişkili veri işlemcilerin yayınlanmasını engelleyen yeni bir veri işlemcisini indirin. 
			|3. ""[Open]"" - indirmeyi iptal edin ve çakışan veri işlemcilerin listesini gösterin.';
			|it = 'Nome interno di elaboratore dati ""[Name]"" 
			|già utilizzato dagli elaboratori dati aggiuntivi esistenti ([Count]): 
			|[List].
			|
			|Selezionare:
			|1. ""[Continue]"" - importare un nuovo elaboratore dati in modalità debug. 
			|2. ""[Disable]"" - disattivare la pubblicazione di tutti gli elaboratori dati in conflitto e importare un nuovo elaboratore dati. 
			|3. ""[Open]"" - annullare importazione e mostrare l''elenco degli elaboratori dati in conflitto.';
			|de = 'Der interne Name der Verarbeitung ""[Name]""
			|ist bereits durch die vorhandene Zusatzverarbeitung belegt([Count]:
			|[List].
			|
			|Wählen Sie:
			|1. ""[Continue]"" - lädt eine neue Behandlung im Debug-Modus.
			|2. ""[Disable]"" - laden Sie die neue Behandlung herunter, indem Sie die Veröffentlichung aller widersprüchlichen Behandlungen deaktivieren.
			|3. ""[Open]"" - bricht den Download ab und zeigt die Liste der widersprüchlichen Behandlungen an.'");
		EndIf;
		DisableButtonPresentation = NStr("ru = 'Отключить конфликтующие'; en = 'Disable conflicting'; pl = 'Wyłącz konfliktujące';es_ES = 'Desactivar conflictos';es_CO = 'Desactivar conflictos';tr = 'Çakışmayı devre dışı bırak';it = 'Disabilitare i conflitti';de = 'Konflikte werden deaktiviert'");
		OpenButtonPresentation = NStr("ru = 'Отменить и показать список'; en = 'Cancel and show list'; pl = 'Anuluj i pokaż listę';es_ES = 'Cancelar y mostrar la lista';es_CO = 'Cancelar y mostrar la lista';tr = 'İptal et ve listeyi göster';it = 'Annullare e mostrare elenco';de = 'Abbrechen und Liste anzeigen'");
	Else
		If RegistrationParameters.IsReport Then
			QuestionTitle = NStr("ru = 'Конфликт при загрузке внешнего отчета'; en = 'Conflict during external report import'; pl = 'Konflikt podczas importu sprawozdania zewnętrznego';es_ES = 'Conflicto durante la importación del informe externo';es_CO = 'Conflicto durante la importación del informe externo';tr = 'Harici rapor içe aktarılırken oluşan çakışma';it = 'Conflitto durante il caricamento di un report esterno';de = 'Konflikt beim externen Berichtsimport'");
			QuestionText = NStr("ru = 'Внутреннее имя отчета ""[Name]""
			|уже занято существующим дополнительным отчетом [List].
			|
			|Выберите:
			|1. ""[Continue]"" - загрузить новый отчет в режиме отладки.
			|2. ""[Disable]"" - загрузить новый отчет, отключив публикацию конфликтующего отчета.
			|3. ""[Open]"" - открыть карточку конфликтующего отчета.'; 
			|en = 'Internal report name ""[Name]"" 
			|is already used by the existing additional report [List].
			|
			|Select:
			|1. ""[Continue]"" - import a new report in the debug mode.
			|2. ""[Disable]"" - disable publication of the conflicting report and import a new report.
			|3. ""[Open]"" - open a conflicting report card.'; 
			|pl = 'Nazwa wewnętrzna raportu ""[Name]""
			|jest już zajęta przez istniejące sprawozdanie dodatkowe [List].
			|
			|Wybierz:
			|1. ""[Continue]"" - pobierz nowy raport w trybie debugowania.
			|2. ""[Disable]"" - pobierz nowy raport z wyłączeniem publikacji konfliktującego raportem.
			|3. ""[Open]"" - otwórz kartę konfliktującego raportu.';
			|es_ES = 'El nombre interno del informe ""[Name]""
			|ya está ocupado por el informe adicional existente [List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el informe nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el informe nuevo desactivando la publicación del informe enfrentado.
			|3. ""[Open]"" - abrir la tarjeta del informe enfrentado.';
			|es_CO = 'El nombre interno del informe ""[Name]""
			|ya está ocupado por el informe adicional existente [List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el informe nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el informe nuevo desactivando la publicación del informe enfrentado.
			|3. ""[Open]"" - abrir la tarjeta del informe enfrentado.';
			|tr = '""[Name]"" raporunun 
			|dahili adı zaten mevcut ek raporlar tarafından alınmış [List]. 
			|
			|Seçin: 
			|1. ""[Continue]"" - hata ayıklama modunda yeni bir rapor indir. 
			|2. ""[Disable]"" - tüm çelişkili raporların yayınlanmasını engelleyen yeni bir rapor indirin. 
			|3. ""[Open]"" - indirmeyi iptal edin ve çakışan raporların kartını gösterin.';
			|it = 'Nome report interno ""[Name]"" 
			| già utilizzato dal report aggiuntivo esistente [List].
			|
			|Selezionare:
			|1. ""[Continue]"" - importare un nuovo report in modalità debug.
			|2. ""[Disable]"" - disattivare la pubblicazione dei report in conflitto e importare un nuovo report.
			|3. ""[Open]"" - aprire una scheda report in conflitto.';
			|de = 'Der interne Berichtsname ""[Name]""
			|ist bereits durch den vorhandenen zusätzlichen Bericht [List] belegt.
			|
			|Wählen Sie:
			|1. ""[Continue]"" - einen neuen Bericht im Debug-Modus herunterladen.
			|2. ""[Disable]"" - Laden Sie den neuen Bericht herunter, indem Sie die Veröffentlichung des widersprüchlichen Berichts deaktivieren.
			|3. ""[Open]"" - öffnet das widersprüchliche Zeugnis.'");
			DisableButtonPresentation = NStr("ru = 'Отключить другой отчет'; en = 'Disable another report'; pl = 'Wyłącz inne raport';es_ES = 'Desactivar otro informe';es_CO = 'Desactivar otro informe';tr = 'Diğer raporu devre dışı bırak';it = 'Disabilitare un altro report';de = 'Deaktivieren Sie einen anderen Bericht'");
		Else
			QuestionTitle = NStr("ru = 'Конфликт при загрузке внешней обработки'; en = 'Conflict occurred during import of external data processor'; pl = 'Konflikt podczas importowania zewnętrznego procesora danych';es_ES = 'Conflicto ocurrido durante la importación del procesador de datos externo';es_CO = 'Conflicto ocurrido durante la importación del procesador de datos externo';tr = 'Harici veri işlemcisi içe aktarılırken çakışma meydana geldi';it = 'Conflitto durante il caricamento dell''elaborazione esterna';de = 'Beim Import des externen Datenprozessors ist ein Konflikt aufgetreten'");
			QuestionText = NStr("ru = 'Внутреннее имя обработки ""[Name]""
			|уже занято существующей дополнительной обработкой [List].
			|
			|Выберите:
			|1. ""[Continue]"" - загрузить новую обработку в режиме отладки.
			|2. ""[Disable]"" - загрузить новую обработку, отключив публикацию конфликтующей обработки.
			|3. ""[Open]"" - открыть карточку конфликтующей обработки.'; 
			|en = 'Internal name of data processor ""[Name]"" 
			|is already used by the existing additional data processor [List].
			|
			|Select:
			|1. ""[Continue]"" - import a new data processor in the debug mode.
			|2. ""[Disable]"" - disable publication of the conflicting data processor and import a new data processor.
			|3. ""[Open]"" - open the conflicting data processor card.'; 
			|pl = 'Nazwa wewnętrzna przetwarzania ""[Name]""
			|jest już zajęta przez istniejące dodatkowe procedury przetwarzania[List].
			|
			|Wybierz:
			|1. ""[Continue]"" - pobierz nowe przetwarzanie w trybie debugowania.
			|2. ""[Disable]"" - pobierz nowe przetwarzanie z wyłączeniem publikacji wszystkich konfliktujących procedur przetwarzania
			|3. ""[Open]"" - otwórz kartę konfliktujących procedur przetwarzania.';
			|es_ES = 'El nombre interno del procesamiento ""[Name]""
			|ya está ocupado por el procesamiento adicional existente [List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el procesamiento nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el procesamiento nuevo desactivando la publicación del procesamiento enfrentado.
			|3. ""[Open]"" - abrir la tarjeta del procesamiento enfrentado.';
			|es_CO = 'El nombre interno del procesamiento ""[Name]""
			|ya está ocupado por el procesamiento adicional existente [List].
			|
			|Seleccione:
			|1. ""[Continue]"" - cargar el procesamiento nuevo en el modo de depuración.
			|2. ""[Disable]"" - cargar el procesamiento nuevo desactivando la publicación del procesamiento enfrentado.
			|3. ""[Open]"" - abrir la tarjeta del procesamiento enfrentado.';
			|tr = '""[Name]"" veri işlemcisinin 
			|dahili adı zaten mevcut ek veri işlemcisi tarafından alınmış [List]. 
			|
			|Seçin: 
			|1. ""[Continue]"" - hata ayıklama modunda yeni bir veri işlemcisini indir. 
			|2. ""[Disable]"" - tüm çelişkili veri işlemcisinin yayınlanmasını engelleyen yeni bir veri işlemcisini indirin. 
			|3. ""[Open]"" - çakışan veri işlemcisinin kartını gösterin.';
			|it = 'Nome interno del processore dati ""[Name]"" 
			| già utilizzato dall''elaboratore dati aggiuntivo esistente [List].
			|
			|Selezionare:
			|1. ""[Continue]"" - importare un nuovo elaboratore dati in modalità dbug.
			|2. ""[Disable]"" - disattivare pubblicazione dell''elaboratore dati in conflitto e importare un nuovo elaboratore dati.
			|3. ""[Open]"" - aprire la scheda dell''elaboratore dati in conflitto.';
			|de = 'Der interne Name der Verarbeitung ""[Name]""
			|ist bereits durch die bestehende Zusatzverarbeitung [List] belegt.
			|
			|Wählen Sie:
			|1. ""[Continue]"" - lädt eine neue Behandlung im Debug-Modus.
			|2. ""[Disable]"" - laden Sie die neue Behandlung herunter, indem Sie die Veröffentlichung der widersprüchlichen Behandlung deaktivieren.
			|3. ""[Open]–"" - öffnen Sie die widersprüchliche Verarbeitungskarte.'");
			DisableButtonPresentation = NStr("ru = 'Отключить другую обработку'; en = 'Disable another data processor'; pl = 'Wyłącz inny procesor danych';es_ES = 'Desactivar otro procesador de datos';es_CO = 'Desactivar otro procesador de datos';tr = 'Diğer veri işlemcisini devre dışı bırak';it = 'Disabiltare un altro processore dati';de = 'Deaktivieren Sie einen anderen Datenprozessor'");
		EndIf;
		OpenButtonPresentation = NStr("ru = 'Отменить и открыть'; en = 'Cancel and open'; pl = 'Anuluj i pokaż';es_ES = 'Cancelar y mostrar';es_CO = 'Cancelar y mostrar';tr = 'İptal et ve aç';it = 'Annulla e apri';de = 'Abbrechen und anzeigen'");
	EndIf;
	ContinueButtonPresentation = NStr("ru = 'В режиме отладки'; en = 'In debug mode'; pl = 'W trybie debugowania';es_ES = 'En el modo de depuración';es_CO = 'En el modo de depuración';tr = 'Hata ayıklama modunda';it = 'Nel regime di Debug';de = 'Im Debug-Modus'");
	QuestionText = StrReplace(QuestionText, "[Name]",  RegistrationParameters.ObjectName);
	QuestionText = StrReplace(QuestionText, "[Count]", RegistrationParameters.ConflictsCount);
	QuestionText = StrReplace(QuestionText, "[List]",  RegistrationParameters.LockerPresentation);
	QuestionText = StrReplace(QuestionText, "[Disable]",  DisableButtonPresentation);
	QuestionText = StrReplace(QuestionText, "[Open]",     OpenButtonPresentation);
	QuestionText = StrReplace(QuestionText, "[Continue]", ContinueButtonPresentation);
	
	QuestionButtons = New ValueList;
	QuestionButtons.Add("ContinueWithoutPublishing", ContinueButtonPresentation);
	QuestionButtons.Add("DisableConflictingItems",  DisableButtonPresentation);
	QuestionButtons.Add("CancelAndOpen",        OpenButtonPresentation);
	QuestionButtons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("UpdateFromFileConflictSolution", ThisObject, RegistrationParameters);
	
	ShowQueryBox(Handler, QuestionText, QuestionButtons, , "ContinueWithoutPublishing", QuestionTitle);
EndProcedure

&AtClient
Procedure UpdateFromFileConflictSolution(Response, RegistrationParameters) Export
	If Response = "ContinueWithoutPublishing" Then
		// Repeating server call (publishing in debug mode) and processing the result
		RegistrationParameters.DisablePublication = True;
		UpdateFromFileClientMechanics(RegistrationParameters);
	ElsIf Response = "DisableConflictingItems" Then
		// Repeating server call (switching conflicting items to debug mode) and processing the result
		RegistrationParameters.DisableConflicts = True;
		UpdateFromFileClientMechanics(RegistrationParameters);
	ElsIf Response = "CancelAndOpen" Then
		// Canceling and showing conflicting items.
		// Showing the list if multiple conflicts are found.
		ShowList = (RegistrationParameters.ConflictsCount > 1);
		If RegistrationParameters.OldObjectName = RegistrationParameters.ObjectName AND Not IsNew Then
			// And also when the current item is already recorded with a conflicting name.
			// The list contains two items - the current one and the conflicting one.
			// It allows to decide which item is to be disabled.
			ShowList = True;
		EndIf;
		If ShowList Then // List form with a filter by conflicting items.
			FormName = "Catalog.AdditionalReportsAndDataProcessors.ListForm";
			FormTitle = NStr("ru = 'Дополнительные отчеты и обработки с внутреннем именем ""%1""'; en = 'Additional reports and data processors with ""%1"" internal name'; pl = 'Dodatkowe raporty i procesory danych z wewnętrzną nazwą ""%1""';es_ES = 'Informes adicionales y procesadores de datos con el nombre interno ""%1""';es_CO = 'Informes adicionales y procesadores de datos con el nombre interno ""%1""';tr = 'Dahili adı ""%1"" olan ek raporlar ve veri işlemcileri';it = 'Report aggiuntivi ed elaboratori dati con nome interno ""%1""';de = 'Zusätzliche Berichte und Datenprozessoren mit dem internen Namen ""%1""'");
			FormTitle = StringFunctionsClientServer.SubstituteParametersToString(FormTitle, RegistrationParameters.ObjectName);
			ParametersForm = New Structure;
			ParametersForm.Insert("Filter", New Structure);
			ParametersForm.Filter.Insert("ObjectName", RegistrationParameters.ObjectName);
			ParametersForm.Filter.Insert("IsFolder", False);
			ParametersForm.Insert("Title", FormTitle);
			ParametersForm.Insert("Representation", "List");
		Else // Item form
			FormName = "Catalog.AdditionalReportsAndDataProcessors.ObjectForm";
			ParametersForm = New Structure;
			ParametersForm.Insert("Key", RegistrationParameters.Conflicting[0].Value);
		EndIf;
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
		OpenForm(FormName, ParametersForm, Undefined, True);
	Else // Cancelling.
		UpdateFromFileCompletion(Undefined, RegistrationParameters);
	EndIf;
EndProcedure

&AtClient
Procedure UpdateFromFileCompletion(EmptyResult, RegistrationParameters) Export
	If RegistrationParameters = Undefined Or RegistrationParameters.Success = False Then
		If ShowImportFromFileDialogOnOpen AND IsOpen() Then
			Close();
		EndIf;
	ElsIf RegistrationParameters.Success = True Then
		If Not IsOpen() Then
			Open();
		EndIf;
		Modified = True;
		DataProcessorRegistration = True;
		DataProcessorDataAddress = RegistrationParameters.DataProcessorDataAddress;
	EndIf;
EndProcedure

&AtClient
Procedure OpenOption()
	Option = Items.AdditionalReportOptions.CurrentData;
	If Option = Undefined Then
		Return;
	EndIf;
	
	If NOT ValueIsFilled(Option.Ref) Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Вариант отчета ""%1"" не зарегистрирован.'; en = '""%1"" report option is not registered.'; pl = 'Opcja sprawozdania ""%1"" nie jest zarejestrowana.';es_ES = 'Opción de informe ""%1"" no está registrada.';es_CO = 'Opción de informe ""%1"" no está registrada.';tr = 'Rapor seçeneği ""%1"" kayıtlı değil.';it = '""%1"" la variante di report non è registrata.';de = 'Die Berichtsoption ""%1"" ist nicht registriert.'"), Option.Description);
		ShowMessageBox(, ErrorText);
	Else
		ModuleReportOptionsClient = CommonClient.CommonModule("ReportsOptionsClient");
		ModuleReportOptionsClient.ShowReportSettings(Option.Ref);
	EndIf;
EndProcedure

&AtClient
Procedure EditScheduledJob(ChoiceMode = False, CheckBoxChanged = False)
	
	ItemCommand = Items.ObjectCommands.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	If ItemCommand.StartupOption <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		AND ItemCommand.StartupOption <> PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode") Then
		ErrorText = NStr("ru = 'Команда с вариантом запуска ""%1""
		|не может использоваться в регламентных заданиях.'; 
		|en = 'Cannot use the command with launch option ""%1"" 
		|in scheduled jobs.'; 
		|pl = 'Polecenie z wariantem uruchomienia ""%1""
		|nie może być używane w zadaniach reglamentowanych.';
		|es_ES = 'Comando de la opción de iniciación""%1""
		|no puede utilizarse en las tareas programadas.';
		|es_CO = 'Comando de la opción de iniciación""%1""
		|no puede utilizarse en las tareas programadas.';
		|tr = 'Başlangıç seçeneği komutu 
		|""%1"" planlanan işlerde kullanılamaz.';
		|it = 'Impossibile utilizzare il comando con opzioni di avvio ""%1"" 
		|nei compiti programmati.';
		|de = 'Der Befehl mit der Startoption ""%1""
		|kann nicht in Routineaufgaben verwendet werden.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, String(ItemCommand.StartupOption));
		ShowMessageBox(, ErrorText);
		If CheckBoxChanged Then
			ItemCommand.ScheduledJobUsage = NOT ItemCommand.ScheduledJobUsage;
		EndIf;
		Return;
	EndIf;
	
	If CheckBoxChanged AND Not ItemCommand.ScheduledJobUsage Then
		Return;
	EndIf;
	
	If ItemCommand.ScheduledJobSchedule.Count() > 0 Then
		CommandSchedule = ItemCommand.ScheduledJobSchedule.Get(0).Value;
	Else
		CommandSchedule = Undefined;
	EndIf;
	
	If TypeOf(CommandSchedule) <> Type("JobSchedule") Then
		CommandSchedule = New JobSchedule;
	EndIf;
	
	Context = New Structure;
	Context.Insert("ItemCommand", ItemCommand);
	Context.Insert("DisableFlagOnCancelEdit", CheckBoxChanged);
	Handler = New NotifyDescription("AfterScheduleEditComplete", ThisObject, Context);
	
	EditSchedule = New ScheduledJobDialog(CommandSchedule);
	EditSchedule.Show(Handler);
	
EndProcedure

&AtClient
Procedure AfterScheduleEditComplete(Schedule, Context) Export
	ItemCommand = Context.ItemCommand;
	If Schedule = Undefined Then
		If Context.DisableFlagOnCancelEdit Then
			ItemCommand.ScheduledJobUsage = False;
		EndIf;
	Else
		ItemCommand.ScheduledJobSchedule.Clear();
		ItemCommand.ScheduledJobSchedule.Add(Schedule);
		If AdditionalReportsAndDataProcessorsClientServer.ScheduleSpecified(Schedule) Then
			Modified = True;
			ItemCommand.ScheduledJobUsage = True;
			ItemCommand.ScheduledJobPresentation = StandardSubsystemsClientServer.SchedulePresentation(Schedule);
		Else
			ItemCommand.ScheduledJobPresentation = NStr("ru = 'Не заполнено'; en = 'Blank'; pl = 'Niewypełniony';es_ES = 'Vacía';es_CO = 'Vacía';tr = 'Boş';it = 'Vuoto';de = 'Leer'");
			If ItemCommand.ScheduledJobUsage Then
				ItemCommand.ScheduledJobUsage = False;
				ShowUserNotification(
					NStr("ru = 'Запуск по расписанию отключен'; en = 'Run on schedule is disabled'; pl = 'Uruchomienie według harmonogramu jest wyłączone';es_ES = 'El lanzamiento por horario está desactivado';es_CO = 'El lanzamiento por horario está desactivado';tr = 'Planlanmış başlatma devre dışı bırakıldı';it = 'L''avvio su pianificazione è disabilitato';de = 'Der geplante Start ist deaktiviert'"),
					,
					NStr("ru = 'Расписание не заполнено'; en = 'Schedule is not filled in'; pl = 'Nie wypełniono harmonogramu';es_ES = 'Horario no está rellenado';es_CO = 'Horario no está rellenado';tr = 'Program doldurulmadı';it = 'La pianificazione non è compilata';de = 'Der Zeitplan ist nicht gefüllt'"));
			EndIf;
		EndIf;
	EndIf;
EndProcedure

&AtClient
Procedure ChangeQuickAccess()
	ItemCommand = Items.ObjectCommands.CurrentData;
	If ItemCommand = Undefined Then
		Return;
	EndIf;
	
	FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
	UsersWithQuickAccess = New ValueList;
	For Each TableRow In FoundItems Do
		UsersWithQuickAccess.Add(TableRow.User);
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("UsersWithQuickAccess", UsersWithQuickAccess);
	FormParameters.Insert("CommandPresentation",         ItemCommand.Presentation);
	
	ClientCache.Insert("CommandRowID", ItemCommand.GetID());
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.QuickAccessToAdditionalReportsAndDataProcessors", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure PermissionsOnClick(Item, EventData, StandardProcessing)
	
	StandardProcessing = False;
	
	Transition = EventData.Href;
	If Not IsBlankString(Transition) Then
		AttachIdleHandler("PermissionsOnClick_Attachable", 0.1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure PermissionsOnClick_Attachable()
	
	InternalProcessingKey = "internal:";
	
	If Transition = InternalProcessingKey + "home" Then
		
		GeneratePermissionList();
		
	ElsIf StrStartsWith(Transition, InternalProcessingKey) Then
		
		GeneratePermissionPresentations(Right(Transition, StrLen(Transition) - StrLen(InternalProcessingKey)));
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalReportOptionsBeforeDeleteCompletion(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		Option = AdditionalParameters.Variant;
		DeleteAdditionalReportOption("ExternalReport." + Object.ObjectName, Option.VariantKey);
		AdditionalReportOptions.Delete(Option);
	EndIf;
EndProcedure

&AtClient
Procedure ExecuteCommandAfterWriteConfirmed(Response, Context) Export
	If Response = "WriteAndContinue" Then
		ClearMessages();
		If Not Write() Then
			Return; // Failed to write, the platform shows an error message.
		EndIf;
	ElsIf Response <> "ContinueWithoutWriting" Then
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Or Modified Then
		Return; // Final checking.
	EndIf;
	
	CommandTableRow = Items.ObjectCommands.CurrentData;
	If CommandTableRow = Undefined
		Or CommandTableRow.ID <> Context.CommandToExecuteID Then
		FoundItems = Object.Commands.FindRows(New Structure("ID", Context.CommandToExecuteID));
		If FoundItems.Count() = 0 Then
			Return;
		EndIf;
		CommandTableRow = FoundItems[0];
	EndIf;
	
	CommandToExecute = New Structure(
		"Ref, Presentation,
		|ID, StartupOption, ShowNotification, 
		|Modifier, RelatedObjects, IsReport, Kind");
	FillPropertyValues(CommandToExecute, CommandTableRow);
	CommandToExecute.Ref = Object.Ref;
	CommandToExecute.Kind = Object.Kind;
	CommandToExecute.IsReport = (Object.Kind = KindAdditionalReport Or Object.Kind = ReportKind);
	
	If CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm") Then
		
		AdditionalReportsAndDataProcessorsClient.OpenDataProcessorForm(CommandToExecute, ThisObject, CommandToExecute.RelatedObjects);
		
	ElsIf CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall") Then
		
		AdditionalReportsAndDataProcessorsClient.ExecuteDataProcessorClientMethod(CommandToExecute, ThisObject, CommandToExecute.RelatedObjects);
		
	ElsIf CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
		Or CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode") Then
		
		StateHeader = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Выполняется команда ""%1""'; en = 'Executing the ""%1"" command'; pl = 'Wykonywanie polecenia ""%1""';es_ES = 'Ejecutando el comando ""%1""';es_CO = 'Ejecutando el comando ""%1""';tr = '""%1"" komutu yürütülüyor';it = 'In esecuzione il comando ""%1""';de = 'Der Befehl ""%1"" wird gerade ausgeführt'"),
			CommandTableRow.Presentation);
		ShowUserNotification(StateHeader + "...", , , PictureLib.TimeConsumingOperation48);
		
		TimeConsumingOperation = StartServerCommandExecutionInBackground(CommandToExecute, UUID);
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.MessageText = StateHeader;
		IdleParameters.UserNotification.Show = True;
		IdleParameters.OutputIdleWindow = True;
		
		CompletionNotification = New NotifyDescription("AfterCompleteExecutingServerCommandInBackground", ThisObject, CommandToExecute);
		TimeConsumingOperationsClient.WaitForCompletion(TimeConsumingOperation, CompletionNotification, IdleParameters);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterCompleteExecutingServerCommandInBackground(Job, CommandToExecute) Export
	If Job.Status = "Error" Then
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось выполнить команду по причине:
				|%1.'; 
				|en = 'Failed to execute the command due to:
				|%1.'; 
				|pl = 'Wykonywanie polecenia nie powiodło się z powodu:
				|%1.';
				|es_ES = 'No se ha podido realizar el comando a causa de:
				|%1.';
				|es_CO = 'No se ha podido realizar el comando a causa de:
				|%1.';
				|tr = 'Komutun yürütülememe nedeni:
				|%1.';
				|it = 'Errore nell''esecuzione del comando a causa di:
				|%1.';
				|de = 'Der Befehl konnte nicht ausgeführt werden wegen:
				|%1.'"), Job.BriefErrorPresentation);
	Else
		Result = GetFromTempStorage(Job.ResultAddress);
		NotifyForms = CommonClientServer.StructureProperty(Result, "NotifyForms");
		If NotifyForms <> Undefined Then
			StandardSubsystemsClient.NotifyFormsAboutChange(NotifyForms);
		EndIf;
	EndIf;
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Function UserQuickAccessPresentation(UsersCount)
	
	If UsersCount = 0 Then
		Return NStr("ru = 'Нет'; en = 'None'; pl = 'Żaden';es_ES = 'Ninguno';es_CO = 'Ninguno';tr = 'Hiçbiri';it = 'Nessuno';de = 'Nein'");
	EndIf;
	
	QuickAccessPresentation = StringFunctionsClientServer.StringWithNumberForAnyLanguage(
		NStr("ru = ';%1 пользователь;;%1 пользователя;%1 пользователей;%1 пользователя'; en = ';%1 user;;%1 users;%1 users;%1 users'; pl = ';%1 użytkownik;;%1 użytkownika;%1 użytkowników;%1 użytkownika';es_ES = ';%1 usuario;;%1 de usuario;%1 usuarios;%1 de usuario';es_CO = ';%1 usuario;;%1 de usuario;%1 usuarios;%1 de usuario';tr = ';%1 kullanıcı;;%1 kullanıcı;%1 kullanıcı;%1 kullanıcı';it = ';%1 utente;;%1 utenti;%1 utenti;%1 utenti';de = ';%1 Benutzer;;%1 Benutzer;%1 Benutzer;%1 Benutzer'"), UsersCount);
	
	Return QuickAccessPresentation;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Server call, Server

&AtServerNoContext
Function StartServerCommandExecutionInBackground(CommandToExecute, UUID)
	ProcedureName = "AdditionalReportsAndDataProcessors.ExecuteCommand";
	
	ProcedureParameters = New Structure("AdditionalDataProcessorRef, CommandID, RelatedObjects");
	ProcedureParameters.AdditionalDataProcessorRef = CommandToExecute.Ref;
	ProcedureParameters.CommandID          = CommandToExecute.ID;
	ProcedureParameters.RelatedObjects             = CommandToExecute.RelatedObjects;
	
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("ru = 'Дополнительные отчеты и обработки: Выполнение серверного метода обработки'; en = 'Additional reports and data processors: executing a server method of a data processor.'; pl = 'Dodatkowe raporty i procesory danych: wykonanie metody serwera procesora danych';es_ES = 'Informes adicionales y procesadores de datos: Lanzando el método de servidor del procesador de datos';es_CO = 'Informes adicionales y procesadores de datos: Lanzando el método de servidor del procesador de datos';tr = 'Ek raporlar ve veri işlemcileri: Sunucu işlem yöntemini yürütme';it = 'Report aggiuntivi ed elaboratori dati: esecuzione metodo server di un elaboratore dati.';de = 'Zusätzliche Berichte und Datenprozessoren: Laufende Servermethode des Datenprozessors'");
	
	Return TimeConsumingOperations.ExecuteInBackground(ProcedureName, ProcedureParameters, StartSettings);
EndFunction

&AtServer
Procedure UpdateFromFileServerMechanics(RegistrationParameters)
	CatalogObject = FormAttributeToValue("Object");
	SavedCommands = CatalogObject.Commands.Unload();
	
	RegistrationResult = AdditionalReportsAndDataProcessors.RegisterDataProcessor(CatalogObject, RegistrationParameters);
	
	PermissionsAddress = PutToTempStorage(CatalogObject.Permissions.Unload(), ThisObject.UUID);
	ValueToFormAttribute(CatalogObject, "Object");
	
	CommonClientServer.SupplementStructure(RegistrationParameters, RegistrationResult, True);
	
	If RegistrationParameters.Success Then
		FillInCommands(SavedCommands);
	ElsIf RegistrationParameters.ObjectNameUsed Then
		// Conflicting object presentation.
		LockerPresentation = "";
		For Each ListItem In RegistrationParameters.Conflicting Do
			If StrLen(LockerPresentation) > 80 Then
				LockerPresentation = LockerPresentation + "... ";
				Break;
			EndIf;
			LockerPresentation = LockerPresentation
				+ ?(LockerPresentation = "", "", ", ")
				+ """" + TrimAll(ListItem.Presentation) + """";
		EndDo;
		RegistrationParameters.Insert("LockerPresentation", LockerPresentation);
		// Number of conflicting objects.
		RegistrationParameters.Insert("ConflictsCount", RegistrationParameters.Conflicting.Count());
	EndIf;
	
	SetVisibilityAvailability(RegistrationParameters.Success);
EndProcedure

&AtServer
Function PrepareMetadataObjectSelectionFormParameters()
	MetadataObjectsTable = AdditionalReportsAndDataProcessors.AttachedMetadataObjects(Object.Kind);
	If MetadataObjectsTable = Undefined Then
		Return Undefined;
	EndIf;
	
	FilterByMetadataObjects = New ValueList;
	FilterByMetadataObjects.LoadValues(MetadataObjectsTable.UnloadColumn("FullName"));
	
	SelectedMetadataObjects = New ValueList;
	For Each PurposeItem In Object.Purpose Do
		If MetadataObjectsTable.Find(PurposeItem.RelatedObject, "Ref") <> Undefined Then
			SelectedMetadataObjects.Add(PurposeItem.RelatedObject.FullName);
		EndIf;
	EndDo;
	
	FormParameters = New Structure;
	FormParameters.Insert("FilterByMetadataObjects", FilterByMetadataObjects);
	FormParameters.Insert("SelectedMetadataObjects", SelectedMetadataObjects);
	FormParameters.Insert("Title", NStr("ru = 'Назначение дополнительной обработки'; en = 'Additional data processor purpose'; pl = 'Dodatkowy cel przetwarzania danych';es_ES = 'Propósito del procesador de datos adicional';es_CO = 'Propósito del procesador de datos adicional';tr = 'Ek veri işlemcisinin amacı';it = 'Scopo dell''elaborazione aggiuntiva';de = 'Zusätzlicher Zweck des Datenprozessors'"));
	
	Return FormParameters;
EndFunction

&AtServer
Procedure ImportSelectedMetadataObjects(Parameter)
	Object.Purpose.Clear();
	
	For Each ParameterItem In Parameter Do
		MetadataObject = Metadata.FindByFullName(ParameterItem.Value);
		If MetadataObject = Undefined Then
			Continue;
		EndIf;
		AssignmentRow = Object.Purpose.Add();
		AssignmentRow.RelatedObject = Common.MetadataObjectID(MetadataObject);
	EndDo;
	
	Modified = True;
	SetVisibilityAvailability();
EndProcedure

&AtServerNoContext
Procedure DeleteAdditionalReportOption(ObjectKey, OptionKey)
	SettingsStorages["ReportsVariantsStorage"].Delete(ObjectKey, OptionKey, Undefined);
EndProcedure

&AtServer
Procedure SetVisibilityAvailability(Registration = False)
	
	ThisIsGlobalDataProcessor = (Object.Kind = KindAdditionalDataProcessor OR Object.Kind = KindAdditionalReport);
	IsReport = (Object.Kind = KindAdditionalReport OR Object.Kind = ReportKind);
	
	If Not Registration AND Not IsNew AND IsReport Then
		AdditionalReportOptionsFill();
	Else
		AdditionalReportOptions.Clear();
	EndIf;
	
	OptionsCount = AdditionalReportOptions.Count();
	CommandCount = Object.Commands.Count();
	VisibleTabCount = 1;
	
	If Object.Kind = KindAdditionalReport AND Object.UseOptionStorage Then
		VisibleTabCount = VisibleTabCount + 1;
		
		Items.OptionsPages.Visible = True;
		
		If Registration OR OptionsCount = 0 Then
			Items.OptionsPages.CurrentPage = Items.OptionsHideBeforeWrite;
			Items.OptionsPage.Title = NStr("ru = 'Варианты отчета'; en = 'Report options'; pl = 'Opcje sprawozdania';es_ES = 'Opciones de informe';es_CO = 'Opciones de informe';tr = 'Rapor seçenekleri';it = 'Varianti di report';de = 'Berichtsoptionen'");
		Else
			Items.OptionsPages.CurrentPage = Items.OptionsShow;
			Items.OptionsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Варианты отчета (%1)'; en = '(%1) report option'; pl = 'Opcje sprawozdania (%1)';es_ES = 'Opciones de informe (%1)';es_CO = 'Opciones de informe (%1)';tr = '(%1) rapor seçeneği';it = '(%1) variante di report';de = 'Berichtsoptionen (%1)'"),
				Format(OptionsCount, "NG="));
		EndIf;
	Else
		Items.OptionsPages.Visible = False;
	EndIf;
	
	Items.CommandsPage.Visible = CommandCount > 0;
	If CommandCount = 0 Then
		Items.CommandsPage.Title = CommandsPageName();
	Else
		VisibleTabCount = VisibleTabCount + 1;
		Items.CommandsPage.Title = CommandsPageName() + " (" + Format(CommandCount, "NG=") + ")";
	EndIf;
	
	Items.ExecuteCommand.Visible = False;
	If ThisIsGlobalDataProcessor AND CommandCount > 0 Then
		For Each CommandTableRow In Object.Commands Do
			If CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.OpeningForm")
				Or CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ClientMethodCall")
				Or CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ServerMethodCall")
				Or CommandTableRow.StartupOption = PredefinedValue("Enum.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode") Then
				Items.ExecuteCommand.Visible = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	PermissionCount = SecurityProfilePermissions().Count();
	PermissionCompatibilityMode = Object.PermissionCompatibilityMode;
	
	SafeMode = Object.SafeMode;
	
	If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
		ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
		UseSecurityProfiles = ModuleSafeModeManager.UseSecurityProfiles();
	Else
		UseSecurityProfiles = False;
	EndIf;
	
	If GetFunctionalOption("SaaS") Or UseSecurityProfiles Then
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		If PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3 Then
			If SafeMode AND PermissionCount > 0 AND UseSecurityProfiles Then
				If IsNew Then
					SafeMode = "";
				Else
					SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref);
				EndIf;
			EndIf;
		Else
			If PermissionCount = 0 Then
				SafeMode = True;
			Else
				If UseSecurityProfiles Then
					If IsNew Then
						SafeMode = "";
					Else
						SafeMode = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(Object.Ref);
					EndIf;
				Else
					SafeMode = False;
				EndIf;
			EndIf;
		EndIf;
	EndIf;
	
	If PermissionCount = 0 Then
		
		Items.PermissionsPage.Visible = False;
		Items.SafeModeGlobalGroup.Visible = True;
		Items.SafeModeFalseLabelDecoration.Visible = (SafeMode = False);
		Items.SafeModeTrueLabelDecoration.Visible = (SafeMode = True);
		Items.EnablingSecurityProfilesGroup.Visible = False;
		
	Else
		
		VisibleTabCount = VisibleTabCount + 1;
		
		Items.PermissionsPage.Visible = True;
		Items.PermissionsPage.Title = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Разрешения (%1)'; en = 'Permissions (%1)'; pl = 'Zezwolenia (%1)';es_ES = 'Permisos (%1)';es_CO = 'Permisos (%1)';tr = 'İzinler (%1)';it = 'Autorizzazioni (%1)';de = 'Berechtigungen (%1)'"),
			Format(PermissionCount, "NG="));
		
		Items.SafeModeGlobalGroup.Visible = False;
		
		If PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3 Then
			Items.PermissionCompatibilityModesPagesGroup.CurrentPage = Items.PermissionsPageVersion_2_1_3;
		Else
			Items.PermissionCompatibilityModesPagesGroup.CurrentPage = Items.PermissionsPageVersion_2_2_2;
		EndIf;
		
		If SafeMode = True Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.SafeModeWithPermissionsPage;
		ElsIf SafeMode = False Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.UnsafeModeWithPermissionsPage;
		ElsIf TypeOf(SafeMode) = Type("String") Then
			Items.SafeModeWithPermissionsPages.CurrentPage = Items.PersonalSecurityProfilePage;
			Items.DecorationPersonalSecurityProfileLabel.Title = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Дополнительный отчет или обработка будет подключаться к программе с использованием ""персонального""
					|профиля безопасности %1, в котором будут разрешены только следующие операции:'; 
					|en = 'The report or data processor will be attached to the application with a custom
					|security profile %1 with only the following operations allowed:'; 
					|pl = 'Dodatkowe sprawozdanie lub przetwarzanie będzie łączyć się z programem przy użyciu ""prywatnego""
					| profilu bezpieczeństwa %1, w którym będą dozwolone tylko następujące operacje:';
					|es_ES = 'Informe adicional o el procesador de datos se conectará a la aplicación usando el perfil
					| de seguridad ""personal""%1, que permite solo las siguientes operaciones:';
					|es_CO = 'Informe adicional o el procesador de datos se conectará a la aplicación usando el perfil
					| de seguridad ""personal""%1, que permite solo las siguientes operaciones:';
					|tr = 'Ek rapor veya veri işlemcisi, sadece aşağıdaki işlemlere izin veren ""kişisel"" 
					|güvenlik profilini kullanarak %1 bağlanacaktır:';
					|it = 'Il report o elaboratore dati sarà allegato all''applicazione con un profilo
					|personalizzato di sicurezza %1 con solo le seguenti operazioni concesse:';
					|de = 'Der zusätzliche Bericht oder die Verarbeitung wird über das ""persönliche""
					|Sicherheitsprofil %1mit dem Programm verbunden, in dem nur die folgenden Operationen erlaubt sind:'"),
				SafeMode);
		Else
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '%1 не является корректным режимом подключения для дополнительных отчетов и обработок,
					|требующих разрешений на использование профилей безопасности.'; 
					|en = '%1 is not a valid attachment mode for additional reports or data processors
					| that require permissions to use security profiles.'; 
					|pl = '%1 nie jest prawidłowym trybem połączenia dla dodatkowych sprawozdań i procedur przetwarzania,
					|wymagających zezwoleń na wykorzystywanie profili bezpieczeństwa.';
					|es_ES = '%1 no es un modo de conexión correcto para los informes adicionales y los procesadores de datos,
					|que requieren permisos para el uso de seguridad del perfil.';
					|es_CO = '%1 no es un modo de conexión correcto para los informes adicionales y los procesadores de datos,
					|que requieren permisos para el uso de seguridad del perfil.';
					|tr = 'Güvenlik profili kullanımı için izin gerektiren ek raporlar ve veri işlemcileri için %1 doğru bir 
					|bağlantı modu değil.';
					|it = '%1 non è una modalità valida di allegato per report aggiuntivi o elaboratori dati
					|che richiedono il permesso per l''utilizzo di profili di sicurezza.';
					|de = '%1 ist kein korrekter Verbindungsmodus für zusätzliche Berichte und Verarbeitungen,
					|die Berechtigungen zur Verwendung von Sicherheitsprofilen erfordern.'"),
				SafeMode);
		EndIf;
		
		If Common.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
			CanSetUpSecurityProfiles = ModuleSafeModeManagerInternal.CanSetUpSecurityProfiles();
		Else
			CanSetUpSecurityProfiles = False;
		EndIf;
		
		If SafeMode = False AND Not UseSecurityProfiles AND CanSetUpSecurityProfiles Then
			Items.EnablingSecurityProfilesGroup.Visible = True;
		Else
			Items.EnablingSecurityProfilesGroup.Visible = False;
		EndIf;
		
		GeneratePermissionList();
		
	EndIf;
	
	Items.OptionsCommandsPermissionsPages.PagesRepresentation = FormPagesRepresentation[?(VisibleTabCount > 1, "TabsOnTop", "None")];
	
	PurposePresentation = "";
	If ThisIsGlobalDataProcessor Then
		For Each RowSection In Object.Sections Do
			SectionPresentation = AdditionalReportsAndDataProcessors.SectionPresentation(RowSection.Section);
			If SectionPresentation = Undefined Then
				Continue;
			EndIf;
			If PurposePresentation = "" Then
				PurposePresentation = SectionPresentation;
			Else
				PurposePresentation = PurposePresentation + ", " + SectionPresentation;
			EndIf;
		EndDo;
	Else
		For Each AssignmentRow In Object.Purpose Do
			OHMPresentation = AdditionalReportsAndDataProcessors.MetadataObjectPresentation(AssignmentRow.RelatedObject);
			If PurposePresentation = "" Then
				PurposePresentation = OHMPresentation;
			Else
				PurposePresentation = PurposePresentation + ", " + OHMPresentation;
			EndIf;
		EndDo;
	EndIf;
	If PurposePresentation = "" Then
		PurposePresentation = NStr("ru = 'Не определено'; en = 'Not determined'; pl = 'Nie określono';es_ES = 'No determinado';es_CO = 'No determinado';tr = 'Tanımlanmamış';it = 'Non determinato';de = 'Nicht definiert'");
	EndIf;
	
	Items.ObjectCommandsQuickAccessPresentation.Visible       = ThisIsGlobalDataProcessor;
	Items.ObjectCommandsSetQuickAccess.Visible           = ThisIsGlobalDataProcessor;
	Items.ObjectCommandsScheduledJobPresentation.Visible = ThisIsGlobalDataProcessor;
	Items.ObjectCommandsScheduledJobUsage.Visible = ThisIsGlobalDataProcessor;
	Items.ObjectCommandsSetSchedule.Visible              = ThisIsGlobalDataProcessor;
	
	IsPrintForm = Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm;
	Items.FormsTypes.Visible = Not ThisIsGlobalDataProcessor AND Not IsPrintForm;
	If Not Items.FormsTypes.Visible Then
		Object.UseForObjectForm = True;
		Object.UseForListForm = True;
	EndIf;
	Items.SetVisibility.Visible = IsPrintForm;
	Items.ObjectCommandsComment.Visible = IsPrintForm;
	
	If IsNew Then
		Title = ?(IsReport, NStr("ru = 'Дополнительный отчет (создание)'; en = 'Additional report (Create)'; pl = 'Dodatkowy raport (Tworzenie)';es_ES = 'Informe adicional (crear)';es_CO = 'Informe adicional (crear)';tr = 'Ek rapor (Oluştur)';it = 'Report aggiuntivo (Creazione)';de = 'Zusätzlicher Bericht (Erstellen)'"), NStr("ru = 'Дополнительная обработка (создание)'; en = 'Additional data processor (Create)'; pl = 'Dodatkowy procesor danych (tworzenie)';es_ES = 'Procesador de datos adicional (crear)';es_CO = 'Procesador de datos adicional (crear)';tr = 'Ek veri işlemcisi (Oluştur)';it = 'Elaboratore dati aggiuntivo (Creare)';de = 'Zusätzlicher Datenprozessor (Erstellen)'"));
	Else
		Title = Object.Description + " " + ?(IsReport, NStr("ru = '(Дополнительный отчет)'; en = '(Additional report)'; pl = '(Dodatkowe sprawozdanie)';es_ES = '(Informe adicional)';es_CO = '(Informe adicional)';tr = '(Ek rapor)';it = '(Report supplementare)';de = '(Zusätzlicher Bericht)'"), NStr("ru = '(Дополнительная обработка)'; en = '(Additional data processor)'; pl = '(Dodatkowe opracowanie)';es_ES = '(Procesador de datos adicional)';es_CO = '(Procesador de datos adicional)';tr = '(Ek veri işlemcisi)';it = '(Elaboratore dati aggiuntivo)';de = '(Zusätzlicher Datenprozessor)'"));
	EndIf;
	
	If OptionsCount > 0 Then
		
		OutputTableTitle = VisibleTabCount <= 1 AND Object.Kind = KindAdditionalReport AND Object.UseOptionStorage;
		
		Items.AdditionalReportOptions.TitleLocation = FormItemTitleLocation[?(OutputTableTitle, "Top", "None")];
		Items.AdditionalReportOptions.Header               = NOT OutputTableTitle;
		Items.AdditionalReportOptions.HorizontalLines = NOT OutputTableTitle;
		
	EndIf;
	
	If CommandCount > 0 Then
		
		OutputTableTitle = VisibleTabCount <= 1 AND NOT ThisIsGlobalDataProcessor;
		
		Items.ObjectCommands.TitleLocation = FormItemTitleLocation[?(OutputTableTitle, "Top", "None")];
		Items.ObjectCommands.Header               = NOT OutputTableTitle;
		Items.ObjectCommands.HorizontalLines = NOT OutputTableTitle;
		
	EndIf;
	
	WindowOptionsKey = AdditionalReportsAndDataProcessors.KindToString(Object.Kind);
	
EndProcedure

&AtServer
Procedure GeneratePermissionPresentations(Val PermissionKind)
	
	PermissionTable = SecurityProfilePermissions();
	PermissionRow = PermissionTable.Find(PermissionKind, "PermissionKind");
	If PermissionRow <> Undefined Then
		PermissionParameters = PermissionRow.Parameters.Get();
		PermissionsPresentation_2_1_3 = AdditionalReportsAndDataProcessorsSafeModeInternal.GenerateDetailedPermissionDetails(
			PermissionKind, PermissionParameters);
	EndIf;
	
EndProcedure

&AtServer
Procedure GeneratePermissionList()
	
	PermissionTable = GetFromTempStorage(PermissionsAddress);
	
	If Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_1_3 Then
		
		PermissionsPresentation_2_1_3 = AdditionalReportsAndDataProcessorsSafeModeInternal.GeneratePermissionPresentation(PermissionTable);
		
	ElsIf Object.PermissionCompatibilityMode = Enums.AdditionalReportsAndDataProcessorsPermissionCompatibilityModes.Version_2_2_2 Then
		
		Permissions = New Array();
		
		ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
		
		For Each Row In PermissionTable Do
			Permission = XDTOFactory.Create(XDTOFactory.Type(ModuleSafeModeManagerInternal.Package(), Row.PermissionKind));
			FillPropertyValues(Permission, Row.Parameters.Get());
			Permissions.Add(Permission);
		EndDo;
		
		Properties = ModuleSafeModeManagerInternal.PropertiesForPermissionRegister(Object.Ref);
		
		SetPrivilegedMode(True);
		PermissionsPresentation_2_2_2 = ModuleSafeModeManagerInternal.PermissionsToUseExternalResourcesPresentation(
			Properties.Type, Properties.ID, Properties.Type, Properties.ID, Permissions);
		SetPrivilegedMode(False);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Server

&AtServer
Procedure FillInCommands(SavedCommands = Undefined)
	
	Object.Commands.Sort("Presentation");
	
	ObjectPrintCommands = Undefined;
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm
		AND Object.Purpose.Count() = 1
		AND Common.SubsystemExists("StandardSubsystems.Print") Then
		ModulePrintManager = Common.CommonModule("PrintManagement");
		ObjectPrintCommands = ModulePrintManager.StandardObjectPrintCommands(Object.Purpose[0].RelatedObject);
	EndIf;
	
	For Each ItemCommand In Object.Commands Do
		If Object.Kind = KindAdditionalDataProcessor OR Object.Kind = KindAdditionalReport Then
			FoundItems = QuickAccess.FindRows(New Structure("CommandID", ItemCommand.ID));
			ItemCommand.QuickAccessPresentation = UserQuickAccessPresentation(
				FoundItems.Count());
		EndIf;
		
		ItemCommand.ScheduledJobUsage = False;
		ItemCommand.ScheduledJobAllowed = False;
		
		If Object.Kind = KindAdditionalDataProcessor
			AND (ItemCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods.ServerMethodCall
			OR ItemCommand.StartupOption = Enums.AdditionalDataProcessorsCallMethods.ScenarioInSafeMode) Then
			
			ItemCommand.ScheduledJobAllowed = True;
			
			GUIDScheduledJob = ItemCommand.GUIDScheduledJob;
			If SavedCommands <> Undefined Then
				FoundRow = SavedCommands.Find(ItemCommand.ID, "ID");
				If FoundRow <> Undefined Then
					GUIDScheduledJob = FoundRow.GUIDScheduledJob;
				EndIf;
			EndIf;
			
			If ValueIsFilled(GUIDScheduledJob) Then
				SetPrivilegedMode(True);
				ScheduledJob = ScheduledJobsServer.Job(GUIDScheduledJob);
				If ScheduledJob <> Undefined Then
					ItemCommand.GUIDScheduledJob = GUIDScheduledJob;
					ItemCommand.ScheduledJobPresentation = StandardSubsystemsClientServer.SchedulePresentation(ScheduledJob.Schedule);
					ItemCommand.ScheduledJobUsage = ScheduledJob.Use;
					ItemCommand.ScheduledJobSchedule.Insert(0, ScheduledJob.Schedule);
				EndIf;
				SetPrivilegedMode(False);
			EndIf;
			If Not ValueIsFilled(ItemCommand.ScheduledJobPresentation) Then
				ItemCommand.ScheduledJobPresentation = NStr("ru = 'Не заполнено'; en = 'Blank'; pl = 'Niewypełniony';es_ES = 'Vacía';es_CO = 'Vacía';tr = 'Boş';it = 'Vuoto';de = 'Leer'");
			EndIf;
		ElsIf Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
			If Not IsBlankString(ItemCommand.CommandsToReplace) AND ObjectPrintCommands <> Undefined Then
				ReplacedID = StrSplit(ItemCommand.CommandsToReplace, ",", False);
				ReplacedCommandsPresentation = "";
				ReplacedNumber = 0;
				Filter = New Structure("ID, SaveFormat, SkipPreview", Undefined, Undefined, False);
				For Each IDOfCommandToReplace In ReplacedID Do
					Filter.ID = TrimAll(IDOfCommandToReplace);
					ListOfCommandsToReplace = ObjectPrintCommands.FindRows(Filter);
					// If it is impossible to exactly determine a command to replace, replacement is not performed.
					If ListOfCommandsToReplace.Count() = 1 Then
						ReplacedCommandsPresentation = ReplacedCommandsPresentation + ?(IsBlankString(ReplacedCommandsPresentation), "", ", ") + """" + ListOfCommandsToReplace[0].Presentation + """";
						ReplacedNumber = ReplacedNumber + 1;
					EndIf;
				EndDo;
				If ReplacedNumber > 0 Then
					If ReplacedNumber = 1 Then
						CommentTemplate = NStr("ru = 'Заменяет стандартную команду печати %1'; en = 'Replaces standard print command %1'; pl = 'Zamienia standardowe polecenie wydruku %1';es_ES = 'Reemplaza el comando estándar de la impresión %1';es_CO = 'Reemplaza el comando estándar de la impresión %1';tr = 'Standart yazdırma komutu yerinde kullanılır %1';it = 'Sostituisce il comando di stampa standard %1';de = 'Ersetzt den Standard-Druckbefehl %1'");
					Else
						CommentTemplate = NStr("ru = 'Заменяет стандартные команды печати: %1'; en = 'Replaces standard print commands: %1'; pl = 'Zamienia standardowe polecenia wydruku: %1';es_ES = 'Reemplaza el comando estándar de la impresión: %1';es_CO = 'Reemplaza el comando estándar de la impresión: %1';tr = 'Standart yazdırma komutu yerine kullanılır: %1';it = 'Sostituisce il comando di stampa standard: %1';de = 'Ersetzt den Standard-Druckbefehl: %1'");
					EndIf;
					ItemCommand.Comment = StringFunctionsClientServer.SubstituteParametersToString(CommentTemplate, ReplacedCommandsPresentation);
				EndIf;
			EndIf;
		Else
			ItemCommand.ScheduledJobPresentation = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Неприменимо для команд с вариантом запуска ""%1""'; en = 'Inapplicable for commands with the ""%1"" launch option'; pl = 'Nie dotyczy poleceń z opcją uruchamiania ""%1""';es_ES = 'No aplicado para comandos con la opción de lanzamiento ""%1""';es_CO = 'No aplicado para comandos con la opción de lanzamiento ""%1""';tr = 'Başlatma seçeneği ""%1"" olan komutlar için uygulanmaz';it = 'Non applicabile per comandi con la varianti di avvio ""%1""';de = 'Nicht anwendbar auf Befehle mit Startoption ""%1"".'"),
				String(ItemCommand.StartupOption));
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure AdditionalReportOptionsFill()
	AdditionalReportOptions.Clear();
	
	Try
		ExternalObject = AdditionalReportsAndDataProcessors.ExternalDataProcessorObject(Object.Ref);
	Except
		ErrorText = NStr("ru = 'Не удалось получить список вариантов отчета из-за ошибки, возникшей при подключении этого отчета:'; en = 'Cannot get the list of report options due to report attachment error:'; pl = 'Nie można odebrać listy opcji sprawozdania z powodu błędu, który wystąpił podczas podłączenia tego sprawozdania:';es_ES = 'No se puede recibir una lista de opciones de informe debido al error que ha ocurrido al conectar este informe:';es_CO = 'No se puede recibir una lista de opciones de informe debido al error que ha ocurrido al conectar este informe:';tr = 'Bu raporu bağlarken oluşan hata nedeniyle rapor seçeneklerinin bir listesi alınamıyor:';it = 'Non è stato possibile ottenere l''elenco delle varianti del report a causa di un errore verificatosi durante l''attivazione del report:';de = 'Aufgrund des beim Verbinden dieses Berichts aufgetretenen Fehlers kann keine Liste mit Berichtsoptionen empfangen werden:'");
		MessageText = ErrorText + Chars.LF + DetailErrorDescription(ErrorInfo());
		CommonClientServer.MessageToUser(MessageText);
		Return;
	EndTry;
	
	If Common.SubsystemExists("StandardSubsystems.ReportsOptions") Then
		ModuleReportsOptions = Common.CommonModule("ReportsOptions");
		
		ReportMetadata = ExternalObject.Metadata();
		DCSchemaMetadata = ReportMetadata.MainDataCompositionSchema;
		If DCSchemaMetadata <> Undefined Then
			DCSchema = ExternalObject.GetTemplate(DCSchemaMetadata.Name);
			For Each DCSettingsOption In DCSchema.SettingVariants Do
				OptionKey = DCSettingsOption.Name;
				OptionRef = ModuleReportsOptions.ReportOption(Object.Ref, OptionKey);
				If OptionRef <> Undefined Then
					Option = AdditionalReportOptions.Add();
					Option.VariantKey = OptionKey;
					Option.Description = DCSettingsOption.Presentation;
					Option.Custom = False;
					Option.PictureIndex = 5;
					Option.Ref = OptionRef;
				EndIf;
			EndDo;
		Else
			OptionKey = "";
			OptionRef = ModuleReportsOptions.ReportOption(Object.Ref, OptionKey);
			If OptionRef <> Undefined Then
				Option = AdditionalReportOptions.Add();
				Option.VariantKey = OptionKey;
				Option.Description = ReportMetadata.Presentation();
				Option.Custom = False;
				Option.PictureIndex = 5;
				Option.Ref = OptionRef;
			EndIf;
		EndIf;
	Else
		ModuleReportsOptions = Undefined;
	EndIf;
	
	If Object.UseOptionStorage Then
		Storage = SettingsStorages["ReportsVariantsStorage"];
		ObjectKey = Object.Ref;
		SettingsList = ModuleReportsOptions.ReportOptionsKeys(ObjectKey);
	Else
		Storage = ReportsVariantsStorage;
		ObjectKey = "ExternalReport." + Object.ObjectName;
		SettingsList = Storage.GetList(ObjectKey);
	EndIf;
	
	For Each ListItem In SettingsList Do
		Option = AdditionalReportOptions.Add();
		Option.VariantKey = ListItem.Value;
		Option.Description = ListItem.Presentation;
		Option.Custom = True;
		Option.PictureIndex = 3;
		If ModuleReportsOptions <> Undefined Then
			Option.Ref = ModuleReportsOptions.ReportOption(Object.Ref, Option.VariantKey);
		EndIf;
	EndDo;
EndProcedure

&AtServer
Function SecurityProfilePermissions()
	
	Return GetFromTempStorage(PermissionsAddress);
	
EndFunction

&AtServer
Function SelectedRelatedObjects()
	Result = New ValueList;
	Result.LoadValues(Object.Purpose.Unload(, "RelatedObject").UnloadColumn("RelatedObject"));
	Return Result;
EndFunction

&AtClient
Procedure SetUpVisibilityCompletion(DialogResult, AdditionalParameters) Export
	If DialogResult <> "Continue" Then
		Return;
	EndIf;
	Write();
	OpenPrintSubmenuSettingsForm();
EndProcedure

&AtClient
Procedure OpenPrintSubmenuSettingsForm()
	ModulePrintManagerInternalClient = CommonClient.CommonModule("PrintManagementInternalClient");
	ModulePrintManagerInternalClient.OpenPrintSubmenuSettingsForm(SelectedRelatedObjects());
EndProcedure

&AtServer
Function CommandsToDisable()
	Result = New ValueList;
	For Each Command In Object.Commands Do
		If Not IsBlankString(Command.CommandsToReplace) Then
			ItemsToReplaceList = StrSplit(Command.CommandsToReplace, ",", False);
			For Each CommandToReplace In ItemsToReplaceList Do
				Result.Add(CommandToReplace);
			EndDo;
		EndIf;
	EndDo;
	Return Result;
EndFunction

&AtServer
Function CommandsPageName()
	If Object.Kind = Enums.AdditionalReportsAndDataProcessorsKinds.PrintForm Then
		Return NStr("ru = 'Команды печати'; en = 'Print commands'; pl = 'Polecenia druku';es_ES = 'Comandos de imprenta';es_CO = 'Comandos de imprenta';tr = 'Yazdırma komutları';it = 'Comandi di stampa';de = 'Druckbefehle'");
	Else
		Return NStr("ru = 'Команды'; en = 'Commands'; pl = 'Polecenia';es_ES = 'Comandos';es_CO = 'Comandos';tr = 'Komutlar';it = 'Comandi';de = 'Befehle'");
	EndIf;
EndFunction

#EndRegion
