
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If NOT Parameters.Property("OpenByScenario") Then
		Raise NStr("ru='Обработка не предназначена для непосредственного использования.'; en = 'The data processor is not intended for direct usage.'; pl = 'Opracowanie nie jest przeznaczone do bezpośredniego użycia.';es_ES = 'Procesador de datos no está destinado al uso directo.';es_CO = 'Procesador de datos no está destinado al uso directo.';tr = 'Veri işlemcisi doğrudan kullanıma yönelik değil.';it = 'L''elaboratore dati non è inteso per un uso diretto.';de = 'Der Datenprozessor ist nicht für den direkten Gebrauch bestimmt.'");
	EndIf;
	
	ThisDataProcessor = ThisObject();
	If IsBlankString(Parameters.ObjectAddress) Then
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.ObjectSettings) );
	Else
		ThisObject( ThisDataProcessor.InitializeThisObject(Parameters.ObjectAddress) );
	EndIf;
	
	If Not ValueIsFilled(Object.InfobaseNode) Then
		Text = NStr("ru='Настройка обмена данными не найдена.'; en = 'Data exchange settings item not found.'; pl = 'Ustawienia wymiany danych nie zostały znalezione.';es_ES = 'Configuración del intercambio de datos no se ha encontrado.';es_CO = 'Configuración del intercambio de datos no se ha encontrado.';tr = 'Veri değişimi ayarı bulunmadı.';it = 'Impostazioni scambio dati elemento non trovate.';de = 'Datenaustauscheinstellung wurde nicht gefunden.'");
		DataExchangeServer.ReportError(Text, Cancel);
		Return;
	EndIf;
	
	Title = Title + " (" + Object.InfobaseNode + ")";
	BaseNameForForm = ThisDataProcessor.BaseNameForForm();
	
	CurrentSettingsItemPresentation = "";
	Items.FiltersSettings.Visible = AccessRight("SaveUserData", Metadata);
	
	ResetTableCountLabel();
	UpdateTotalCountLabel();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	If Exit Then
		Return;
	EndIf;
	StopCountCalcultion();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AdditionalRegistrationChoice(Item, RowSelected, Field, StandardProcessing)
	
	If Field <> Items.AdditionalRegistrationFilterAsString Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	CurrentData = Items.AdditionalRegistration.CurrentData;
	
	NameOfFormToOpen = BaseNameForForm + "Form.PeriodAndFilterEdit";
	FormParameters = New Structure;
	FormParameters.Insert("Title",           CurrentData.Presentation);
	FormParameters.Insert("ChoiceAction",      - Items.AdditionalRegistration.CurrentRow);
	FormParameters.Insert("SelectPeriod",        CurrentData.SelectPeriod);
	FormParameters.Insert("SettingsComposer", SettingsComposerByTableName(CurrentData.FullMetadataName, CurrentData.Presentation, CurrentData.Filter));
	FormParameters.Insert("DataPeriod",        CurrentData.Period);
	
	FormParameters.Insert("FromStorageAddress", UUID);
	
	OpenForm(NameOfFormToOpen, FormParameters, Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	Cancel = True;
	If Clone Then
		Return;
	EndIf;
	
	OpenForm(BaseNameForForm + "Form.SelectNodeCompositionObjectKind",
		New Structure("InfobaseNode", Object.InfobaseNode),
		Items.AdditionalRegistration);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDelete(Item, Cancel)
	Selected = Items.AdditionalRegistration.SelectedRows;
	Count = Selected.Count();
	If Count>1 Then
		PresentationText = NStr("ru='выбранные строки'; en = 'the selected rows'; pl = 'Wybór i ustawienia';es_ES = 'Líneas seleccionadas';es_CO = 'Líneas seleccionadas';tr = 'Seçilen satırlar';it = 'le righe selezionati';de = 'Ausgewählte Zeilen'");
	ElsIf Count=1 Then
		PresentationText = Items.AdditionalRegistration.CurrentData.Presentation;
	Else
		Return;
	EndIf;
	
	// The AdditionalRegistrationBeforeDeleteEnd procedure is called from the user confirmation dialog.
	Cancel = True;
	
	QuestionText = NStr("ru='Удалить из дополнительных данных %1 ?'; en = 'Delete %1 from additional data?'; pl = 'Usunąć z dodatkowych danych %1 ?';es_ES = '¿Borrar de los datos adicionales %1 ?';es_CO = '¿Borrar de los datos adicionales %1 ?';tr = 'Ek verilerden %1 silinsin mi?';it = 'Eliminare %1 dai dati aggiuntivi?';de = 'Löschen von zusätzlichen Daten %1?'");    
	QuestionText = StrReplace(QuestionText, "%1", PresentationText);
	
	QuestionTitle = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
	
	Notification = New NotifyDescription("AdditionalRegistrationBeforeDeleteEnd", ThisObject, New Structure);
	Notification.AdditionalParameters.Insert("SelectedRows", Selected);
	
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , ,QuestionTitle);
EndProcedure

&AtClient
Procedure AdditionalRegistrationChoiceProcessing(Item, ValueSelected, StandardProcessing)
	StandardProcessing = False;
	
	SelectedValueType = TypeOf(ValueSelected);
	If SelectedValueType=Type("Array") Then
		// Adding new row
		Items.AdditionalRegistration.CurrentRow = AddingRowToAdditionalCompositionServer(ValueSelected);
		
	ElsIf SelectedValueType= Type("Structure") Then
		If ValueSelected.ChoiceAction=3 Then
			// Restoring settings
			SettingPresentation = ValueSelected.SettingPresentation;
			If Not IsBlankString(CurrentSettingsItemPresentation) AND SettingPresentation<>CurrentSettingsItemPresentation Then
				QuestionText  = NStr("ru='Восстановить настройки ""%1""?'; en = 'Restore """"%1"""" settings?'; pl = 'Przywróć ustawienia ""%1""?';es_ES = '¿Restablecer las configuraciones ""%1""?';es_CO = '¿Restablecer las configuraciones ""%1""?';tr = 'Ayarları eski haline getir ""%1""?';it = 'Ripristina impostazioni """"%1""""?';de = 'Einstellungen wiederherstellen ""%1""?'");
				QuestionText  = StrReplace(QuestionText, "%1", SettingPresentation);
				TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
				
				Notification = New NotifyDescription("AdditionalRegistrationChoiceProcessingEnd", ThisObject, New Structure);
				Notification.AdditionalParameters.Insert("SettingPresentation", SettingPresentation);
				
				ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , TitleText);
			Else
				CurrentSettingsItemPresentation = SettingPresentation;
			EndIf;
		Else
			// Editing filter condition, negative line number.
			Items.AdditionalRegistration.CurrentRow = FilterStringEditingAdditionalCompositionServer(ValueSelected);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AdditionalRegistrationAfterDeleteLine(Item)
	UpdateTotalCountLabel();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ConfirmSelection(Command)
	NotifyChoice( ChoiseResultServer() );
EndProcedure

&AtClient
Procedure ShowCommonParametersText(Command)
	OpenForm(BaseNameForForm +  "Form.CommonSynchronizationSettings",
		New Structure("InfobaseNode", Object.InfobaseNode));
EndProcedure

&AtClient
Procedure ExportComposition(Command)
	OpenForm(BaseNameForForm + "Form.ExportComposition",
		New Structure("ObjectAddress", AdditionalExportObjectAddress() ));
EndProcedure

&AtClient
Procedure RefreshCountClient(Command)
	
	Result = UpdateCountServer();
	
	If Result.Status = "Running" Then
		
		Items.CountCalculationPicture.Visible = True;
		
		IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
		IdleParameters.OutputIdleWindow  = False;
		IdleParameters.OutputMessages     = True;
		
		CompletionNotification = New NotifyDescription("BackgroundJobCompletion", ThisObject);
		TimeConsumingOperationsClient.WaitForCompletion(Result, CompletionNotification, IdleParameters);
		
	Else
		AttachIdleHandler("ImportQuantityValuesCLient", 1, True);
	EndIf;
	
EndProcedure

&AtClient
Procedure FiltersSettings(Command)
	
	// Select from the list menu
	VariantList = ReadSettingsVariantListServer();
	
	Text = NStr("ru='Сохранить текущую настройку...'; en = 'Save current settings...'; pl = 'Zapisuję bieżącą konfigurację...';es_ES = 'Guardando la configuración actual...';es_CO = 'Guardando la configuración actual...';tr = 'Mevcut ayarlar kaydediliyor...';it = 'Salva le impostazioni correnti...';de = 'Die aktuelle Konfiguration speichern...'");
	VariantList.Add(1, Text, , PictureLib.SaveReportSettings);
	
	Notification = New NotifyDescription("FiltersSettingsOptionSelectionCompletion", ThisObject);
	
	ShowChooseFromMenu(Notification, VariantList, Items.FiltersSettings);
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ImportQuantityValuesCLient()
	Items.CountCalculationPicture.Visible = False;
	ImportCountsValuesServer();
EndProcedure

&AtClient
Procedure BackgroundJobCompletion(Result, AdditionalParameters) Export
	ImportQuantityValuesCLient();
EndProcedure

&AtClient
Procedure FiltersSettingsOptionSelectionCompletion(Val SelectedItem, Val AdditionalParameters) Export
	If SelectedItem = Undefined Then
		Return;
	EndIf;
		
	SettingPresentation = SelectedItem.Value;
	If TypeOf(SettingPresentation)=Type("String") Then
		TitleText = NStr("ru='Подтверждение'; en = 'Confirm operation'; pl = 'Potwierdzenie';es_ES = 'Confirmación';es_CO = 'Confirmación';tr = 'Onay';it = 'Conferma l''operazione';de = 'Bestätigung der Operation'");
		QuestionText   = NStr("ru='Восстановить настройки ""%1""?'; en = 'Restore """"%1"""" settings?'; pl = 'Przywróć ustawienia ""%1""?';es_ES = '¿Restablecer las configuraciones ""%1""?';es_CO = '¿Restablecer las configuraciones ""%1""?';tr = 'Ayarları eski haline getir ""%1""?';it = 'Ripristina impostazioni """"%1""""?';de = 'Einstellungen wiederherstellen ""%1""?'");
		QuestionText   = StrReplace(QuestionText, "%1", SettingPresentation);
		
		Notification = New NotifyDescription("FilterSettingsCompletion", ThisObject, New Structure);
		Notification.AdditionalParameters.Insert("SettingPresentation", SettingPresentation);
		
		ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , , TitleText);
		
	ElsIf SettingPresentation=1 Then
		
		// Form that displays all settings.
		
		SettingsFormParameters = New Structure;
		SettingsFormParameters.Insert("CloseOnChoice", True);
		SettingsFormParameters.Insert("ChoiceAction", 3);
		SettingsFormParameters.Insert("Object", Object);
		SettingsFormParameters.Insert("CurrentSettingsItemPresentation", CurrentSettingsItemPresentation);
		
		SettingFormName = BaseNameForForm + "Form.SettingsCompositionEdit";
		
		OpenForm(SettingFormName, SettingsFormParameters, Items.AdditionalRegistration);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FilterSettingsCompletion(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingPresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationChoiceProcessingEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SetSettingsServer(AdditionalParameters.SettingPresentation);
EndProcedure

&AtClient
Procedure AdditionalRegistrationBeforeDeleteEnd(Val QuestionResult, Val AdditionalParameters) Export
	If QuestionResult <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	DeletionTable = Object.AdditionalRegistration;
	SubjectToDeletion = New Array;
	For Each RowID In AdditionalParameters.SelectedRows Do
		RowToDelete = DeletionTable.FindByID(RowID);
		If RowToDelete<>Undefined Then
			SubjectToDeletion.Add(RowToDelete);
		EndIf;
	EndDo;
	For Each RowToDelete In SubjectToDeletion Do
		DeletionTable.Delete(RowToDelete);
	EndDo;
	
	UpdateTotalCountLabel();
EndProcedure

&AtServer
Function ChoiseResultServer()
	ObjectResult = New Structure("InfobaseNode, ExportOption, AllDocumentsFilterComposer, AllDocumentsFilterPeriod");
	FillPropertyValues(ObjectResult, Object);
	
	ObjectResult.Insert("AdditionalRegistration", 
		TableIntoStrucrureArray( FormAttributeToValue("Object.AdditionalRegistration")) );
	
	Return New Structure("ChoiceAction, ObjectAddress", 
		Parameters.ChoiceAction, PutToTempStorage(ObjectResult, UUID));
EndFunction

&AtServer
Function TableIntoStrucrureArray(Val ValueTable)
	Result = New Array;
	
	ColumnNames = "";
	For Each Column In ValueTable.Columns Do
		ColumnNames = ColumnNames + "," + Column.Name;
	EndDo;
	ColumnNames = Mid(ColumnNames, 2);
	
	For Each Row In ValueTable Do
		StringStructure = New Structure(ColumnNames);
		FillPropertyValues(StringStructure, Row);
		Result.Add(StringStructure);
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function ThisObject(NewObject = Undefined)
	If NewObject=Undefined Then
		Return FormAttributeToValue("Object");
	EndIf;
	ValueToFormAttribute(NewObject, "Object");
	Return Undefined;
EndFunction

&AtServer
Function AddingRowToAdditionalCompositionServer(ChoiseArray)
	
	If ChoiseArray.Count()=1 Then
		Row = AddToAdditionalExportComposition(ChoiseArray[0]);
	Else
		Row = Undefined;
		For Each ChoiceItem In ChoiseArray Do
			TestRow = AddToAdditionalExportComposition(ChoiceItem);
			If Row=Undefined Then
				Row = TestRow;
			EndIf;
		EndDo;
	EndIf;
	
	Return Row;
EndFunction

&AtServer 
Function FilterStringEditingAdditionalCompositionServer(ChoiceStructure)
	
	CurrentData = Object.AdditionalRegistration.FindByID(-ChoiceStructure.ChoiceAction);
	If CurrentData=Undefined Then
		Return Undefined
	EndIf;
	
	CurrentData.Period       = ChoiceStructure.DataPeriod;
	CurrentData.Filter        = ChoiceStructure.SettingsComposer.Settings.Filter;
	CurrentData.FilterString = FilterPresentation(CurrentData.Period, CurrentData.Filter);
	CurrentData.Count   = NStr("ru='Не рассчитано'; en = 'Not calculated'; pl = 'Nie obliczone';es_ES = 'No calculado';es_CO = 'No calculado';tr = 'Hesaplanmadı';it = 'Non calcolato';de = 'Nicht berechnet'");
	
	UpdateTotalCountLabel();
	
	Return ChoiceStructure.ChoiceAction;
EndFunction

&AtServer
Function AddToAdditionalExportComposition(Item)
	
	ExistingRows = Object.AdditionalRegistration.FindRows( 
		New Structure("FullMetadataName", Item.FullMetadataName));
	If ExistingRows.Count()>0 Then
		Row = ExistingRows[0];
	Else
		Row = Object.AdditionalRegistration.Add();
		FillPropertyValues(Row, Item,,"Presentation");
		
		Row.Presentation = Item.ListPresentation;
		Row.FilterString  = FilterPresentation(Row.Period, Row.Filter);
		Object.AdditionalRegistration.Sort("Presentation");
		
		Row.Count = NStr("ru='Не рассчитано'; en = 'Not calculated'; pl = 'Nie obliczone';es_ES = 'No calculado';es_CO = 'No calculado';tr = 'Hesaplanmadı';it = 'Non calcolato';de = 'Nicht berechnet'");
		UpdateTotalCountLabel();
	EndIf;
	
	Return Row.GetID();
EndFunction

&AtServer
Function FilterPresentation(Period, Filter)
	Return ThisObject().FilterPresentation(Period, Filter);
EndFunction

&AtServer
Function SettingsComposerByTableName(TableName, Presentation, Filter)
	Return ThisObject().SettingsComposerByTableName(TableName, Presentation, Filter, UUID);
EndFunction

&AtServer
Procedure StopCountCalcultion()
	
	TimeConsumingOperations.CancelJobExecution(BackgroundJobID);
	If Not IsBlankString(BackgroundJobResultAddress) Then
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	
	BackgroundJobResultAddress = "";
	BackgroundJobID   = Undefined;
	
EndProcedure

&AtServer
Function UpdateCountServer()
	
	StopCountCalcultion();
	
	JobParameters = New Structure;
	JobParameters.Insert("DataProcessorStructure", ThisObject().ThisObjectInStructureForBackgroundJob());
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	ExecutionParameters.BackgroundJobDescription = 
		NStr("ru='Расчет количества объектов для отправки при синхронизации'; en = 'Calculating the number of objects to be sent during the synchronization'; pl = 'Obliczenie liczby obiektów do wysłania podczas synchronizacji';es_ES = 'Calculando el número de objetos para enviar durante la sincronización';es_CO = 'Calculando el número de objetos para enviar durante la sincronización';tr = 'Senkronizasyon sırasında gönderilecek nesnelerin sayısının hesaplanması';it = 'Calcolare il numero di oggetti da inviare durante la sincronizzazione';de = 'Berechnen der Anzahl der Objekte, die während der Synchronisation gesendet werden sollen'");

	BackgroundJobStartResult = TimeConsumingOperations.ExecuteInBackground(
		"DataExchangeServer.InteractiveExportModification_GenerateValueTree",
		JobParameters,
		ExecutionParameters);
		
	BackgroundJobID   = BackgroundJobStartResult.JobID;
	BackgroundJobResultAddress = BackgroundJobStartResult.ResultAddress;
	
	Return BackgroundJobStartResult;
	
EndFunction

&AtServer
Procedure ImportCountsValuesServer()
	
	CountTree = Undefined;
	If Not IsBlankString(BackgroundJobResultAddress) Then
		CountTree = GetFromTempStorage(BackgroundJobResultAddress);
		DeleteFromTempStorage(BackgroundJobResultAddress);
	EndIf;
	If TypeOf(CountTree) <> Type("ValueTree") Then
		CountTree = New ValueTree;
	EndIf;
	
	If CountTree.Rows.Count() = 0 Then
		UpdateTotalCountLabel(Undefined);
		Return;
	EndIf;
	
	ThisDataProcessor = ThisObject();
	
	CountRows = CountTree.Rows;
	For Each Row In Object.AdditionalRegistration Do
		
		TotalQuantity = 0;
		CountExport = 0;
		StringComposition = ThisDataProcessor.EnlargedMetadataGroupComposition(Row.FullMetadataName);
		For Each TableName In StringComposition Do
			DataString = CountRows.Find(TableName, "FullMetadataName", False);
			If DataString <> Undefined Then
				CountExport = CountExport + DataString.ToExportCount;
				TotalQuantity     = TotalQuantity     + DataString.CommonCount;
			EndIf;
		EndDo;
		
		Row.Count = Format(CountExport, "NZ=") + " / " + Format(TotalQuantity, "NZ=");
	EndDo;
	
	// Grand totals
	DataString = CountRows.Find(Undefined, "FullMetadataName", False);
	UpdateTotalCountLabel(?(DataString = Undefined, Undefined, DataString.ToExportCount));
	
EndProcedure

&AtServer
Procedure UpdateTotalCountLabel(Count = Undefined) 
	
	StopCountCalcultion();
	
	If Count = Undefined Then
		CountText = NStr("ru='<не рассчитано>'; en = '<not calculated>'; pl = '<nie obliczone>';es_ES = '<no calculado>';es_CO = '<not calculated>';tr = '<hesaplanmadı>';it = '<non calcolato>';de = '<nicht berechnet>'");
	Else
		CountText = NStr("ru = 'Объектов: %1'; en = 'Objects: %1'; pl = 'Obiekty: %1';es_ES = 'Objetos: %1';es_CO = 'Objetos: %1';tr = 'Nesneler: %1';it = 'Oggetti: %1';de = 'Objekte: %1'");
		CountText = StrReplace(CountText, "%1", Format(Count, "NZ="));
	EndIf;
	
	Items.UpdateCount.Title  = CountText;
EndProcedure

&AtServer
Procedure ResetTableCountLabel()
	CountsText = NStr("ru='Не рассчитано'; en = 'Not calculated'; pl = 'Nie obliczone';es_ES = 'No calculado';es_CO = 'No calculado';tr = 'Hesaplanmadı';it = 'Non calcolato';de = 'Nicht berechnet'");
	For Each Row In Object.AdditionalRegistration Do
		Row.Count = CountsText;
	EndDo;
	Items.CountCalculationPicture.Visible = False;
EndProcedure

&AtServer
Function ReadSettingsVariantListServer()
	VariantFilter = New Array;
	VariantFilter.Add(Object.ExportOption);
	
	Return ThisObject().ReadSettingsListPresentations(Object.InfobaseNode, VariantFilter);
EndFunction

&AtServer
Procedure SetSettingsServer(SettingPresentation)
	
	ConstantData = New Structure("InfobaseNode, ExportOption, AllDocumentsFilterComposer, AllDocumentsFilterPeriod");
	FillPropertyValues(ConstantData, Object);
	
	ThisDataProcessor = ThisObject();
	ThisDataProcessor.RestoreCurrentAttributesFromSettings(SettingPresentation);
	ThisObject(ThisDataProcessor);
	
	FillPropertyValues(Object, ConstantData);
	ExportAdditionSettingPresentation = SettingPresentation;
	
	ResetTableCountLabel();
	UpdateTotalCountLabel();
EndProcedure

&AtServer
Function AdditionalExportObjectAddress()
	Return ThisObject().SaveThisObject(UUID);
EndFunction

#EndRegion
