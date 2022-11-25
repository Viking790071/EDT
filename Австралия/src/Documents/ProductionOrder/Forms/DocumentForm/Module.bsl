
#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

#EndRegion

#Region FormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentSessionDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	If Parameters.Basis = Undefined And Object.Ref.IsEmpty() And Not ValueIsFilled(Object.OperationKind) Then
		Settings = GetUserSettings();
		Object.OperationKind = Common.CommonSettingsStorageLoad(Settings.ObjectKey, Settings.SettingsKey, Settings.DefaultOperationKind, , Settings.UserName);
	EndIf;
		
	OperationKind = Object.OperationKind;
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	SetConditionalAppearance();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
	CompletedStatus = Constants.ProductionOrdersCompletionStatus.Get();
	
	If AccessRight("Use", Metadata.DataProcessors.ProductionSchedulePlanning) Then
		HasAccessToPlanning = True;
	EndIf;
	
	If Not Constants.UseProductionOrderStatuses.Get() Then
		
		Items.StateGroup.Visible = False;
		
		Items.Status.ChoiceList.Add("InProcess", NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'"));
		Items.Status.ChoiceList.Add("Completed", NStr("en = 'Completed'; ru = 'Завершенные';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
		Items.Status.ChoiceList.Add("Canceled", NStr("en = 'Canceled'; ru = 'Отменено';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Cancellati';de = 'Abgebrochen'"));
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "InProcess";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Production.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	Items.ProductsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// StandardSubsystems.Properties
	PropertyManager.OnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	FormManagement();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
	Notify("NotificationSubcontractingServicesDocumentsChange"); 
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
	// End StandardSubsystems.Properties
	
	// Peripherals
	If Source = "Peripherals"
		And IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	CurrentObject.AdditionalProperties.Insert("NeedRecalculation", NeedRecalculation);
	NeedRecalculation = False;
	
	OldOperationKind = Common.ObjectAttributeValue(CurrentObject.Ref, "OperationKind");
	If OperationKind <> OldOperationKind Then
		Settings = GetUserSettings();
		Common.CommonSettingsStorageSave(Settings.ObjectKey, Settings.SettingsKey, OperationKind, , Settings.UserName);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
	If Cancel Then
		Return;
	EndIf;
	
	If NotifyWorkCalendar Then
		Notify("ChangedProductionOrder", Object.Responsible);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	If ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived")
		And Object.OperationKind <> PredefinedValue("Enum.OperationTypesProductionOrder.Production") Then
		Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production");
		ProcessOperationKindChange();
	Else
		SetOperationKindVisible();
	EndIf;
	
EndProcedure

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GetProductionOrderStates();
EndProcedure

// Procedure - handler of the ChoiceProcessing of the OperationKind input field.
//
&AtClient
Procedure OperationKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
		
		ProductsTypeInventory = PredefinedValue("Enum.ProductsTypes.InventoryItem");
		For Each StringProducts In Object.Products Do
			
			If ValueIsFilled(StringProducts.Products)
				And StringProducts.ProductsType <> ProductsTypeInventory Then
				
				
				MessageText = NStr("en = 'Disassembling operation is invalid for work and services.
					|The %1 products could be a work(service) in the line #%2 of the tabular section ""Products""'; 
					|ru = 'Операция разборки не выполняется для работ и услуг.
					|В строке #%2 табличной части ""Номенклатура"" номенклатура %1 может быть работой или услугой';
					|pl = 'Operacja demontażu jest nieważna dla pracy i usług.
					|Te %1 produkty mogą być pracą (usługą) w wierszu nr %2 sekcji tabelarycznej ""Produkty""';
					|es_ES = 'La operación de desmontaje no es válida para trabajos y servicios.
					|El %1 productos podrían ser un trabajo (servicio) en la línea #%2 de la sección tabular ""Productos""';
					|es_CO = 'La operación de desmontaje no es válida para trabajos y servicios.
					|El %1 productos podrían ser un trabajo (servicio) en la línea #%2 de la sección tabular ""Productos""';
					|tr = 'Demontaj işlemi iş ve hizmetler için geçersiz.
					|%1 ürünleri, ""Ürünler"" tablo bölümünün #%2 satırındaki bir iş (hizmet) olabilir';
					|it = 'L''operazione di smontaggio non è valida per lavoro e servizio.
					|Gli articoli %1 possono essere un lavoro (servizio) nella riga #%2 della sezione tabellare ""Articoli""';
					|de = 'Operation Demontage ist für Arbeit und Dienstleistungen ungültig.
					|Die Produkte %1 können eine Arbeit (Dienstleistung) in der Zeile Nr. %2 des Tabellenabschnitts ""Produkte"" sein'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					StringProducts.LineNumber,
					String(StringProducts.Products));
					
				DriveClient.ShowMessageAboutError(Object, MessageText);
				StandardProcessing = False;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then
		
		Object.Closed = False;
		
	Else
		
		StructureOrderState = CheckCompletedOrderState();
		
		If Not StructureOrderState.CheckPassed Then
			
			Object.OrderState = StructureOrderState.OldOrderState;
			
			TextMessage = NStr("en = 'Cannot set status to Completed. There are Work-in-progress documents related to the Production order. First, complete and post them.'; ru = 'Невозможно установить статус ""Завершен"". Имеются документы ""Незавершенное производство"", связанные с заказом на производство. Сначала завершите и проведите их.';pl = 'Nie można ustawić statusu na Zakończono. Istnieją dokumenty Praca w toku związane ze zleceniem produkcyjnym. Najpierw zakończ i zatwierdź je.';es_ES = 'No se puede establecer el estado como Finalizado. Hay documentos de Trabajo en progreso relacionados con la orden de Producción. Primero, debe finalizarlos y enviarlos.';es_CO = 'No se puede establecer el estado como Finalizado. Hay documentos de Trabajo en progreso relacionados con la orden de Producción. Primero, debe finalizarlos y enviarlos.';tr = 'Durum Tamamlandı olarak ayarlanamıyor. Üretim emri ile ilgili İşlem bitişi belgeleri mevcut. Önce onları tamamlayın ve kaydedin.';it = 'Impossibile impostare lo stato su Completato. Ci sono documenti di Lavori in corso correlati all''Ordine di produzione. Completarli e pubblicarli.';de = 'Fehler beim Festlegen des Status für Abgeschlossen. Es gibt Arbeit in Bearbeitung - Dokumente verbunden mit dem Produktionsauftrag. Zuerst schließen Sie diese ab und buchen sie.'");
			CommonClientServer.MessageToUser(TextMessage);
			
		EndIf;
		
	EndIf;
	
	FillNeedRecalculation();
	
	FormManagement();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish And ValueIsFilled(Object.Finish) Then
		Object.Start = WhenChangingStart;
		CommonClientServer.MessageToUser(NStr("en = 'Start date cannot be later than Due date.'; ru = 'Дата начала не может быть позже даты окончания.';pl = 'Data rozpoczęcia nie może być późniejsza niż Termin zakończenia.';es_ES = 'La fecha inicial no puede ser posterior a la fecha de vencimiento.';es_CO = 'La fecha inicial no puede ser posterior a la fecha de vencimiento.';tr = 'Başlangıç tarihi bitiş tarihinden sonra olamaz.';it = 'La data di inizio non può essere successiva alla Data di scadenza.';de = 'Das Startdatum darf nicht über dem Fälligkeitstermin liegen.'"));
	Else
		WhenChangingStart = Object.Start;
		FillNeedRecalculation();
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 And Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonClientServer.MessageToUser(NStr("en = 'Due date cannot be earlier than Start date.'; ru = 'Дата окончания не может быть раньше даты начала.';pl = 'Data zakończenia nie może być wcześniejsza niż Termin rozpoczęcia.';es_ES = 'La Fecha de vencimiento no puede ser anterior a la Fecha de inicio.';es_CO = 'La Fecha de vencimiento no puede ser anterior a la Fecha de inicio.';tr = 'Bitiş tarihi, Başlangıç tarihinden önce olamaz.';it = 'La data di scadenza non può essere precedente alla Data di avvio.';de = 'Der Fälligkeitstermin darf nicht vor dem Startdatum liegen.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

&AtClient
Procedure PriorityOnChange(Item)
	FillNeedRecalculation();
EndProcedure

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseProductionPlanningOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
		
		Object.UseProductionPlanning = False;
		
	EndIf;
	
	If Object.UseProductionPlanning Then
		
		OrderWIPsStructure = OrderWIPsStructure(Object.Ref);
		
		If OrderWIPsStructure.HasStartedWIPs Then
			
			Object.UseProductionPlanning = Not Object.UseProductionPlanning;
			CommonClientServer.MessageToUser(OrderWIPsStructure.UserMessage);
			
		Else
			
			NeedRecalculation = True;
			
		EndIf;
		
	ElsIf Not Object.UseProductionPlanning And OrderHasScheduledWIPs(Object.Ref) Then
		
		ShowQueryBox(New NotifyDescription("CleanScheduleEnd", ThisObject),
			NStr("en = 'Some Work-in-progress documents are already scheduled. Clearing Include in production planning checkbox will be clear work schedule for Work-in-progress documents based on the Production order. Do you want to continue?'; ru = 'Некоторые документы ""Незавершенное производство"" уже запланированы. Снятие флажка ""Включить в планирование производства"" очистит график планирования документов ""Незавершенное производство"" на основе данного заказа на производство. Продолжить?';pl = 'Niektóre dokumenty Praca w toku są już zaplanowane. Wyczyszczenie pola Uwzględnij w planowaniu produkcji wyczyści planowanie pracy dla dokumentów Praca w toku na podstawie Zlecenia produkcyjnego. Czy chcesz kontynuować?';es_ES = 'Algunos documentos de Trabajo en progreso ya están programados. Si se desmarca la casilla de verificación Incluir en la planificación de la producción, se borrará el horario de trabajo para los documentos de Trabajo en progreso basados en la Orden de producción. ¿Quiere continuar?';es_CO = 'Algunos documentos de Trabajo en progreso ya están programados. Si se desmarca la casilla de verificación Incluir en la planificación de la producción, se borrará el horario de trabajo para los documentos de Trabajo en progreso basados en la Orden de producción. ¿Quiere continuar?';tr = 'Bazı İşlem bitişi belgeleri zaten programlandı. Üretim planlamasına dahil et onay kutusunu temizlemek Üretim emrine bağlı İşlem bitişi belgelerinin çalışma programını silecek. Devam etmek istiyor musunuz?';it = 'Alcuni documenti di Lavoro in corso sono già stati programmati. Deselezionare la casella di controllo Includere nella pianificazione di produzione eliminerà il grafico di lavoro per i documenti di Lavoro in corso basati sull''Ordine di produzione. Continuare?';de = 'Einige Arbeit-in-Bearbeitung-Dokumente sind bereits geplant. Deaktivierung von Kontrollkästchen In Produktionsplanung einschließen wird die Arbeitsplanung für die Arbeit-in-Bearbeitung-Dokumente basiert auf dem Produktionsauftrag löschen. Möchten Sie fortfahren?'"), 
			QuestionDialogMode.YesNo);
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TOOLTIP EVENTS HANDLERS

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanel.Form.SectionProduction");
	
EndProcedure

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"ProductionOrder.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import goods from file'; ru = 'Загрузка товаров из файла';pl = 'Import towarów z pliku';es_ES = 'Importar mercancías del archivo';es_CO = 'Importar mercancías del archivo';tr = 'Malları dosyadan içe aktar';it = 'Importa merci da file';de = 'Importieren Sie Waren aus der Datei'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
		Modified = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AttachableCommands
&AtClient
Procedure Attachable_ExecuteCommand(Command)
	AttachableCommandsClient.ExecuteCommand(ThisObject, Command, Object);
EndProcedure

&AtServer
Procedure Attachable_ExecuteCommandAtServer(Context, Result)
	AttachableCommands.ExecuteCommand(ThisObject, Context, Object, Result);
EndProcedure

&AtClient
Procedure Attachable_UpdateCommands()
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
EndProcedure
// End StandardSubsystems.AttachableCommands

// StandardSubsystems.Properties

&AtClient
Procedure Attachable_PropertiesExecuteCommand(ItemOrCommand, URL = Undefined, StandardProcessing = Undefined)
	PropertyManagerClient.ExecuteCommand(ThisObject, ItemOrCommand, StandardProcessing);
EndProcedure

&AtClient
Procedure UpdateAdditionalAttributesDependencies()
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtClient
Procedure Attachable_OnChangeAdditionalAttribute(Item)
	PropertyManagerClient.UpdateAdditionalAttributesDependencies(ThisObject);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributeItems()
	PropertyManager.UpdateAdditionalAttributesItems(ThisObject);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#EndRegion

#Region FormTableItemsEventHandlers

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
			NStr("en = 'Tabular section ""Materials"" will be filled in again. Continue?'; ru = 'Табличная часть ""Материалы"" будет перезаполнена! Продолжить?';pl = 'Sekcja tabelaryczna ""Materiały"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular ""Materiales"" se rellenará de nuevo. ¿Continuar?';es_CO = 'Sección tabular ""Materiales"" se rellenará de nuevo. ¿Continuar?';tr = '""Malzemeler"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Materiali"" sarà compilata di nuovo. Continuare?';de = 'Der Tabellenabschnitt ""Materialien"" wird wieder ausgefüllt. Fortsetzen?'"), 
			QuestionDialogMode.YesNo);
		
		Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()

	FillByBillsOfMaterialsAtServer();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PRODUCTS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseProductionPlanning", Object.UseProductionPlanning);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If Not ValueIsFilled(StructureData.Specification)
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puede coincidir una lista de materiales con el producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
			
	EndIf;
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	ProductsSpecificationOnChangeAtClient();
	TabularSectionRow.ProductsType = StructureData.ProductsType;
	
	FormManagement();
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date, Object.OperationKind);
	
	If StructureData.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef") 
		And StructureData.ShowSpecificationMessage Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot match a bill of materials with variant to product ""%1"". You can select a bill of materials manually.'; ru = 'Не удалось сопоставить спецификацию с вариантом с номенклатурой ""%1"". Вы можете выбрать спецификацию вручную.';pl = 'Nie można dopasować specyfikacji materiałowej do produktu ""%1"". Możesz wybrać specyfikację materiałową ręcznie.';es_ES = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';es_CO = 'No puedo coincidir una lista de materiales con la variante del producto ""%1"". Puede seleccionar interactivamente una lista de materiales.';tr = '''''%1'''' ürünü ile varyantlı ürün reçetesi eşleşmiyor. Ürün reçetesini manuel olarak seçebilirsiniz.';it = 'Impossibile abbinare una distinta base con variante all''articolo ""%1"". È possibile selezionare una distinta base manualmente.';de = 'Kann die Stückliste mit einer Variante mit dem Produkt ""%1"" nicht übereinstimmen. Sie können die Stückliste manuell auswählen.'"),
			StructureData.ProductDescription);
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	TabularSectionRow.Specification = StructureData.Specification;
	ProductsSpecificationOnChangeAtClient();
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure ProductsCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Products.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Products";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsSpecificationOnChange(Item)
	ProductsSpecificationOnChangeAtClient();
EndProcedure

&AtClient
Procedure ProductsSpecificationCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentData = Items.Products.CurrentData;
	
	FillingValues = New Structure("Owner, OperationKind", CurrentData.Products, Object.OperationKind);
	
	If ValueIsFilled(CurrentData.Characteristic) Then
		FillingValues.Insert("ProductCharacteristic", CurrentData.Characteristic);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ChoiceMode",		True);
	FormParameters.Insert("FillingValues",	FillingValues);
	
	OpenForm("Catalog.BillsOfMaterials.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ProductsAfterDeleteRow(Item)
	
	If Object.Products.Count() = 0 Then
		Object.Inventory.Clear();
		FormManagement();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseProductionPlanning", Object.UseProductionPlanning);
	
	StructureData = GetDataProductsOnChange(StructureData, Object.Date, Object.OperationKind);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - event handler OnChange of the variant input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date, Object.OperationKind);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixChoiceForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

&AtClient
Procedure Attachable_ReadOnlyFieldStartChoice(Item, ChoiceData, StandardProcessing)
	If Not Item.TextEdit Then
		StandardProcessing = False;
	EndIf;
EndProcedure

#EndRegion 

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'Cannot complete the order. The changes are not saved.
				|Click OK to save the changes.'; 
				|ru = 'Не удалось завершить заказ. Изменения не сохранены.
				|Нажмите ОК, чтобы сохранить изменения.';
				|pl = 'Nie można zakończyć zlecenia. Zmiany nie są zapisane.
				|Kliknij OK aby zapisać zmiany.';
				|es_ES = 'Ha ocurrido un error al finalizar el pedido. Los cambios no se han guardado.
				|Haga clic en OK para guardar los cambios.';
				|es_CO = 'Ha ocurrido un error al finalizar el pedido. Los cambios no se han guardado.
				|Haga clic en OK para guardar los cambios.';
				|tr = 'Emir tamamlanamıyor. Değişiklikler kaydedilmedi.
				|Değişiklikleri kaydetmek için Tamam''a tıklayın.';
				|it = 'Impossibile completare l''ordine. Le modifiche non sono salvate. 
				|Cliccare su OK per salvare le modifiche.';
				|de = 'Der Auftrag kann nicht abgeschlossen werden. Die Änderungen sind nicht gespeichert.
				|Um die Änderungen zu speichern, klicken Sie auf OK.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	FormManagement();
	
EndProcedure

&AtClient
Procedure CloseOrderEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Response = DialogReturnCode.Cancel
		Or Not Write(WriteParameters) Then
		Return;
	EndIf;
	
	CloseOrderFragment();
	FormManagement();
	
EndProcedure

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the production order?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Czy chcesz uzupełnić zlecenie produkcyjne?';es_ES = '¿Quiere volver a rellenar el orden de producción?';es_CO = '¿Quiere volver a rellenar el orden de producción?';tr = 'Üretim emrini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare l''ordine di produzione?';de = 'Möchten Sie den Fertigungsauftrag auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument();
	EndIf;
	
EndProcedure

// Procedure - handler of the  FillUsingSalesOrder click button.
//
&AtClient
Procedure FillUsingSalesOrder(Command)
	
	If Not ValueIsFilled(Object.SalesOrder) Then
		MessagesToUserClient.ShowMessageSelectOrder();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject),
		NStr("en = 'The document will be completely refilled on the ""Sales order."" Continue?'; ru = 'Документ будет полностью перезаполнен по заказу покупателя. Продолжить?';pl = 'Cały dokument zostanie wypełniony ponownie zgodnie z ""Zamówieniem sprzedaży.” Kontynuować?';es_ES = 'El documento se volverá a rellenar completamente en la ""Orden de venta"". ¿Continuar?';es_CO = 'El documento se volverá a rellenar completamente en la ""Orden de venta"". ¿Continuar?';tr = 'Belge ""Satış siparişine"" göre tamamen yeniden doldurulacak. Devam edilsin mi?';it = 'Il documento sarà ricaricato completamente secondo ''""Ordine cliente""! Continuare l''esecuzione?';de = 'Das Dokument wird bei der ""Kundenbestellung"" vollständig aufgefüllt Fortsetzen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument("SalesOrder");
	EndIf;

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMAND ACTIONS OF THE ORDER STATES PANEL

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "InProcess" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = True;
	EndIf;
	
	Modified = True;
	FormManagement();
	FillNeedRecalculation();
	
EndProcedure

// Reservation

&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly")
		And Object.Inventory.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNoProductsToReserve();
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly")
		And Object.Products.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNoProductsToReserve();
		
	ElsIf Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		MessageText = NStr("en = '""Consume from"" is required.'; ru = 'Требуется заполнить поле ""Списать из"".';pl = 'Wymagane jest ""Spożywaj z"".';es_ES = 'Se requiere ""Consumir de"".';es_CO = 'Se requiere ""Consumir de"".';tr = '""Tüketilecek kısım"" gerekli.';it = '""Consuma da"" è necessario.';de = '""Verbrauch von"" ist ein Pflichtfeld.'");
		CommonClientServer.MessageToUser(MessageText,,, "Object.StructuralUnitReserve");
		
	Else
		
		FillColumnReserveByBalancesAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly") Then
		
		If Object.Inventory.Count() = 0 Then
			
			MessagesToUserClient.ShowMessageNothingToClearAtReserve();
			
		Else
			
			For Each TabularSectionRow In Object.Inventory Do
				TabularSectionRow.Reserve = 0;
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
		
		If Object.Products.Count() = 0 Then
			
			MessagesToUserClient.ShowMessageNothingToClearAtReserve();
			
		Else
			
			For Each TabularSectionRow In Object.Products Do
				TabularSectionRow.Reserve = 0;
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// End Reservation

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ProductsSpecificationOnChangeAtClient()
	
	TabularSectionRow = Items.Products.CurrentData;
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production") And ValueIsFilled(TabularSectionRow.Specification) Then
		
		DifferentDepartmentsMessage = CheckBillsOfMaterialsOperationsTable(TabularSectionRow.Specification);
		
		If DifferentDepartmentsMessage <> "" Then
			
			PathToTabularSection = CommonClientServer.PathToTabularSection("Object.Products", TabularSectionRow.LineNumber, "Specification");
			CommonClientServer.MessageToUser(DifferentDepartmentsMessage,, PathToTabularSection);
			
		EndIf;
		
	EndIf;
	
	FormManagement();
	
EndProcedure

&AtServerNoContext
Function CheckBillsOfMaterialsOperationsTable(BillsOfMaterials)
	
	Return Catalogs.BillsOfMaterials.CheckBillsOfMaterialsOperationsTable(BillsOfMaterials);
	
EndFunction

&AtClient
Procedure ProcessOperationKindChange()
	
	SetVisibleAndEnabled();
	
	If OperationKind <> Object.OperationKind Then
		
		If Object.OperationKind <> PredefinedValue("Enum.OperationTypesProductionOrder.Production") Then
			
			Object.UseProductionPlanning = False;
			
		Else
			
			Object.Inventory.Clear();
			
		EndIf;
		
		// cleaning BOM column in Products
		For Each ProductsLine In Object.Products Do
			
			ProductsLine.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
			ProductsLine.Reserve = 0;
			
		EndDo;
		
		// cleaning BOM column in Components
		For Each InventoryLine In Object.Inventory Do
			
			InventoryLine.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
			InventoryLine.Reserve = 0;
			
		EndDo;
		
		ChangeOrderTabularSection();
		
		OperationKind = Object.OperationKind;
		
		FormManagement();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("ProductionOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtClient
Procedure SetOperationKindVisible()
	
	Items.OperationKind.Visible = Not (ValueIsFilled(Object.BasisDocument)
		And TypeOf(Object.BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived"));
	
EndProcedure

&AtClient
Procedure FormManagement()

	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	If GetAccessRightForDocumentPosting() Then
		Items.FormPost.Enabled			= (Not StatusIsComplete Or Not Object.Closed);
		Items.FormPostAndClose.Enabled	= (Not StatusIsComplete Or Not Object.Closed);
	EndIf;
	
	Items.FormWrite.Enabled 					= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 			= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible					= Not Object.Closed;
	Items.CloseOrderStatus.Visible				= Not Object.Closed;
	CloseOrderEnabled = DriveServer.CheckCloseOrderEnabled(Object.Ref);
	Items.CloseOrder.Enabled					= CloseOrderEnabled;
	Items.CloseOrderStatus.Enabled				= CloseOrderEnabled;
	Items.ProductsCommandBar.Enabled			= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled			= Not StatusIsComplete;
	Items.FillByBasis.Enabled					= Not StatusIsComplete;
	Items.FillUsingSalesOrder.Enabled			= Not StatusIsComplete;
	Items.StructuralUnit.ReadOnly				= StatusIsComplete;
	Items.Priority.ReadOnly						= StatusIsComplete;
	Items.StarFinishGroup.ReadOnly				= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly			= StatusIsComplete;
	Items.RightColumn.ReadOnly					= StatusIsComplete;
	Items.Pages.ReadOnly						= StatusIsComplete;
	Items.FormSettings.Enabled					= Not StatusIsComplete;
	
	OperationKindIsProduction = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production"));
	Items.UseProductionPlanning.Visible = OperationKindIsProduction;
	Items.TSInventory.Visible = Not OperationKindIsProduction;
	
	If HasAccessToPlanning Then
		Items.FormDataProcessorProductionSchedulePlanningSchedule.Enabled = OperationKindIsProduction;
	Else
		Items.UseProductionPlanning.Enabled = False;
	EndIf;
	IsAssemblyOperationKind = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly"));
	IsDisassemblyOperationKind = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly"));
	CommonClientServer.SetFormItemProperty(Items, "ProductsCommandsChangeReserve", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "ProductsReserve", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "ProductsBatch", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "ProductsStructuralUnitReserve", "Visible", IsDisassemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryCommandsChangeReserve", "Visible", IsAssemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryReserve", "Visible", IsAssemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryBatch", "Visible", IsAssemblyOperationKind);
	CommonClientServer.SetFormItemProperty(Items, "InventoryStructuralUnitReserve", "Visible", IsAssemblyOperationKind);
	
	SetOperationKindVisible();
	
EndProcedure

&AtServerNoContext
Function GetAccessRightForDocumentPosting()
	
	Return AccessRight("Posting", Metadata.Documents.ProductionOrder);
	
EndFunction

&AtServerNoContext
Function GetProductionOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.ProductionOrderStatuses AS ProductionOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON ProductionOrderStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;
	
EndFunction

&AtServer
Function CheckCompletedOrderState()
	
	Return Documents.ProductionOrder.CheckCompletedOrderState(Object.Ref, True);
	
EndFunction

&AtServer
Procedure FillNeedRecalculation()

	If Object.Ref.OrderState = Catalogs.ProductionOrderStatuses.Open Then
		
		If Object.OrderState <> Catalogs.ProductionOrderStatuses.Open Then
			
			NeedRecalculation = True;
			
		EndIf;
		
	Else
		
		NeedRecalculation = True;
		
	EndIf;
	
EndProcedure

#EndRegion

&AtServerNoContext
Function OrderWIPsStructure(ProductionOrder)
	
	ResultStructure = New Structure("HasStartedWIPs, UserMessage", False, "");
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed)
	|	AND ManufacturingOperation.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|	AND ManufacturingOperation.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND ManufacturingOperation.Posted";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.ExecuteBatch();
	
	If Not QueryResult[0].IsEmpty() Then
		
		UserInfoTemplate =
			NStr("en = 'One or more operations of %1 are in progress and can not be scheduled.'; ru = 'Одна или несколько операций %1 в работе и не могут быть запланированы.';pl = 'Jedna lub więcej operacji %1 są w toku i nie mogą być zaplanowane.';es_ES = 'Una o más operaciones de %1 están en progreso y no se pueden programar.';es_CO = 'Una o más operaciones de %1 están en progreso y no se pueden programar.';tr = 'Bir veya birkaç %1 işlemi devam ettiğinden programlanamaz.';it = 'Una o più operazioni di %1 sono in corso e non possono essere programmate.';de = 'Eine oder mehr Operationen von %1 sind in Bearbeitung und können nicht geplant werden.'");
		
		If QueryResult[0].Unload().Count() = QueryResult[2].Unload().Count() Then
			UserInfoTemplate = NStr("en = 'Operations of %1 are completed and can not be scheduled.'; ru = 'Операции %1 завершены и не могут быть запланированы.';pl = 'Operacje %1 są zakończone i nie mogą być zaplanowane.';es_ES = 'Las operaciones de %1 han finalizado y no se pueden programar.';es_CO = 'Las operaciones de %1 han finalizado y no se pueden programar.';tr = '%1 işlemleri tamamlandığından programlanamaz.';it = 'Le operazioni di %1 sono completate e non possono essere programmate.';de = 'Operationen von %1 sind abgeschlossen und können nicht geplant werden.'");
		EndIf;
		
		ResultStructure.HasStartedWIPs = True;
		ResultStructure.UserMessage = StringFunctionsClientServer.SubstituteParametersToString(UserInfoTemplate, ProductionOrder);
		
	ElsIf Not QueryResult[1].IsEmpty() Then
		
		UserInfoTemplate =
			NStr("en = 'One or more operations of %1 are in progress and can not be scheduled.'; ru = 'Одна или несколько операций %1 в работе и не могут быть запланированы.';pl = 'Jedna lub więcej operacji %1 są w toku i nie mogą być zaplanowane.';es_ES = 'Una o más operaciones de %1 están en progreso y no se pueden programar.';es_CO = 'Una o más operaciones de %1 están en progreso y no se pueden programar.';tr = 'Bir veya birkaç %1 işlemi devam ettiğinden programlanamaz.';it = 'Una o più operazioni di %1 sono in corso e non possono essere programmate.';de = 'Eine oder mehr Operationen von %1 sind in Bearbeitung und können nicht geplant werden.'");
			
		ResultStructure.HasStartedWIPs = True;
		ResultStructure.UserMessage = StringFunctionsClientServer.SubstituteParametersToString(UserInfoTemplate, ProductionOrder);
		
	EndIf;
	
	Return ResultStructure;
	
EndFunction

&AtServerNoContext
Function OrderHasScheduledWIPs(OrderRef)
	
	Result = False;
	
	If ValueIsFilled(OrderRef) Then
		
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	ProductionSchedule.Operation AS Operation
			|FROM
			|	InformationRegister.ProductionSchedule AS ProductionSchedule
			|WHERE
			|	ProductionSchedule.ProductionOrder = &ProductionOrder
			|	AND ProductionSchedule.ScheduleState = 0";
		
		Query.SetParameter("ProductionOrder", OrderRef);
		
		QueryResult = Query.Execute();
		
		Result = Not QueryResult.IsEmpty();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CleanScheduleEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		CleanScheduleFragment(Object.Ref);
	Else
		Object.UseProductionPlanning = Not Object.UseProductionPlanning;
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure CleanScheduleFragment(OrderRef)
	
	If ValueIsFilled(OrderRef) Then
		
		WIPs = Documents.ProductionOrder.OrderOpenWIPs(OrderRef);
		
		InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(OrderRef);
		InformationRegisters.JobsForProductionScheduleCalculation.CheckWIPsQueue(WIPs);
		
		For Each WIP In WIPs Do
			
			InformationRegisters.WorkcentersSchedule.ClearWIPSchedule(WIP);
			InformationRegisters.ProductionSchedule.ClearWIPSchedule(WIP);
			InformationRegisters.WorkcentersAvailabilityPreliminary.ClearWIPSchedule(WIP);
			
			RecordSet = AccumulationRegisters.WorkcentersAvailability.CreateRecordSet();
			RecordSet.Filter.Recorder.Set(WIP);
			RecordSet.Write();
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure fills inventories by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// Gets data set from server.
//
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData, ObjectDate = Undefined, OperationKind = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products,
		"MeasurementUnit, ProductsType, Description");
	
	StructureData.Insert("ProductsType", StuctureProduct.ProductsType);
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	StructureData.Insert("ProductDescription", StuctureProduct.Description);
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		If StructureData.Property("Characteristic") Then
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				StructureData.Characteristic,
				OperationKind);
		Else
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ObjectDate, 
				Catalogs.ProductsCharacteristics.EmptyRef(),
				OperationKind);
		EndIf;
		StructureData.Insert("Specification", Specification);
		StructureData.Insert("ShowSpecificationMessage", True);
		
	EndIf;
	
	If StructureData.UseProductionPlanning Then
		
		If Common.ObjectAttributeValue(StructureData.Specification, "UseRouting") = False Then
			StructureData.Specification = Catalogs.BillsOfMaterials.EmptyRef();
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate, OperationKind)
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "Description");
	
	Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
		ObjectDate, 
		StructureData.Characteristic,
		OperationKind);
	StructureData.Insert("Specification", Specification);
	StructureData.Insert("ShowSpecificationMessage", True);
	StructureData.Insert("ProductDescription", StuctureProduct.Description);
	
	Return StructureData;
	
EndFunction

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Fill(Object[Attribute]);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	VisibleValue = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
	
	Items.GroupSalesOrder.Visible = VisibleValue;
	Items.GroupBasisDocument.Enabled = VisibleValue;
	
	UseDisassembly = Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly");
	
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesOrder", "Visible", Not VisibleValue And UseDisassembly);
	CommonClientServer.SetFormItemProperty(Items, "ProductsSalesOrder", "Visible", Not VisibleValue And Not UseDisassembly);
	CommonClientServer.SetFormItemProperty(Items, "ProductsSalesOrder", "TypeRestriction", New TypeDescription("DocumentRef.SalesOrder"));
	CommonClientServer.SetFormItemProperty(Items, "InventorySalesOrder", "TypeRestriction", New TypeDescription("DocumentRef.SalesOrder"));
	CommonClientServer.SetFormItemProperty(Items, "FormSettings", "Visible", GetFunctionalOption("UseInventoryReservation"));
	
	If Object.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		// Product type.
		NewParameter = New ChoiceParameter("Filter.ProductsType", Enums.ProductsTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	Else
		
		// Product type.
		NewArray = New Array();
		NewArray.Add(Enums.ProductsTypes.InventoryItem);
		NewArray.Add(Enums.ProductsTypes.Work);
		NewArray.Add(Enums.ProductsTypes.Service);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not Constants.UseSeveralDepartments.Get()
		And Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	ColorTextSpecifiedInDocument = StyleColors.TextSpecifiedInDocument;
	
	//ProductsSpecification
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("Object.Products.ProductsType");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Enums.ProductsTypes.Service;
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("Text", NStr("en = '<bills of materials are not used>'; ru = '<спецификации не используются>';pl = '<specyfikacja materiałowa nie jest używana>';es_ES = '<listas de materiales no se utilizan>';es_CO = '<listas de materiales no se utilizan>';tr = '<ürün reçeteleri kullanılmaz>';it = '<specifiche non sono utilizzate>';de = '<Stücklisten werden nicht verwendet>'"));
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorTextSpecifiedInDocument);
	ItemAppearance.Appearance.SetParameterValue("Enabled", False);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("ProductsSpecification");
	FieldAppearance.Use = True;
	
EndProcedure

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			StructureProductsData.Insert("UseProductionPlanning", StructureData.UseProductionPlanning);
			
			BarcodeData.Insert("StructureProductsData",
				GetDataProductsOnChange(StructureProductsData, StructureData.Date, StructureData.OperationKind));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	StructureData.Insert("UseProductionPlanning", Object.UseProductionPlanning);
	StructureData.Insert("Date", Object.Date);
	StructureData.Insert("OperationKind", Object.OperationKind);
	GetDataByBarCodes(StructureData);
	
	If Items.Pages.CurrentPage = Items.TSProducts Then
		TableName = "Products";
	Else
		TableName = "Inventory";
	EndIf;
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			And BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object[TableName].FindRows(New Structure("Products,Characteristic,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object[TableName].Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				If NewRow.Property("ProductsType") Then
					NewRow.ProductsType = BarcodeData.StructureProductsData.ProductsType;
				EndIf;
				Items[TableName].CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				Items[TableName].CurrentRow = FoundString.GetID();
			EndIf;
			
			Modified = True;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'; ru = 'Данные по штрихкоду не найдены: %1%; количество: %2%';pl = 'Nie znaleziono danych kodu kreskowego: %1%; ilość: %2%';es_ES = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';es_CO = 'Datos del código de barras no encontrados: %1%; cantidad: %2%';tr = 'Barkod verisi bulunamadı: %1%; miktar: %2%';it = 'Il codice a barre non è stato trovato: %1%; quantità: %2%';de = 'Barcode-Daten wurden nicht gefunden: %1%; Menge: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - handler of the Action event of the Pick TS Inventory command.
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'production order'; ru = 'заказ на производство';pl = 'Zlecenie produkcyjne';es_ES = 'orden de producción';es_CO = 'orden de producción';tr = 'üretim emri';it = 'ordine di produzione';de = 'Produktionsauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - handler of the Action event of the Pick TS Products command.
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName 	= "Products";
	DocumentPresentaion	= NStr("en = 'production order'; ru = 'заказ на производство';pl = 'Zlecenie produkcyjne';es_ES = 'orden de producción';es_CO = 'orden de producción';tr = 'üretim emri';it = 'ordine di produzione';de = 'Produktionsauftrag'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", ParentCompany);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnit);
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Products" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsType = ImportRow.Products.ProductsType;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
	EndIf;

EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'; ru = 'Необходимо выбрать строку, для которой необходимо получить вес.';pl = 'Wybierz wiersz, dla którego trzeba uzyskać wagę.';es_ES = 'Seleccionar una línea para la cual el peso tienen que recibirse.';es_CO = 'Seleccionar una línea para la cual el peso tienen que recibirse.';tr = 'Ağırlığın alınması gereken bir satır seçin.';it = 'Selezionare una linea dove il peso deve essere ricevuto';de = 'Wählen Sie eine Zeile, für die das Gewicht empfangen werden soll.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'; ru = 'Электронные весы вернули нулевой вес.';pl = 'Waga elektroniczna zwróciła zerową wagę.';es_ES = 'Escalas electrónicas han devuelto el peso cero.';es_CO = 'Escalas electrónicas han devuelto el peso cero.';tr = 'Elektronik tartı sıfır ağırlık gösteriyor.';it = 'Le bilance elettroniche hanno dato peso pari a zero.';de = 'Die elektronische Waagen gaben Nullgewicht zurück.'");
			CommonClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
		And Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesProducts		= (Items.Pages.CurrentPage = Items.TSProducts);
			TabularSectionName			= ?(CurrentPagesProducts, "Products", "Inventory");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
			FormManagement();
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseVariantsSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If ClosingResult.WereMadeChanges And Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesProducts		= (Items.Pages.CurrentPage = Items.TSProducts);
			TabularSectionName			= ?(CurrentPagesProducts, "Products", "Inventory");
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Function GetUserSettings()
	
	Settings = New Structure;
	Settings.Insert("ObjectKey", "ProductionOrder_OperationKind");
	Settings.Insert("SettingsKey", "OperationKindUserChoice");
	Settings.Insert("DefaultOperationKind", PredefinedValue("Enum.OperationTypesProductionOrder.EmptyRef"));
	Settings.Insert("UserName", UserName());
	
	Return Settings;
	
EndFunction

&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInShipmentDocuments", Object.SalesOrderPosition);
	ParametersStructure.Insert("RenameSalesOrderPositionInShipmentDocuments", NStr("en = 'Reserve for position in Production order'; ru = 'Положение строки ""Резерв для"" в заказе на производство';pl = 'Pozycja rezerwa dla w Zleceniu produkcyjnym';es_ES = 'Reserva de posición en la orden de producción';es_CO = 'Reserva de posición en la orden de producción';tr = 'Üretim emrinde ""Rezerve et"" pozisyonu';it = 'Riserva per posizione nell''Ordine di produzione';de = 'Reserve für Position in Produktionsauftrag'"));
	ParametersStructure.Insert("WereMadeChanges", False);
	
	NameTable = ?(Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly"),
		"Inventory", "Products");
	
	TableObject = Object[NameTable];
	
	InvCount = TableObject.Count();
	If InvCount > 1 Then
		
		CurrOrder = TableObject[0].SalesOrder;
		MultipleOrders = False;
		
		For Index = 1 To InvCount - 1 Do
			
			If CurrOrder <> TableObject[Index].SalesOrder Then
				MultipleOrders = True;
				Break;
			EndIf;
			
			CurrOrder = TableObject[Index].SalesOrder;
			
		EndDo;
		
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
		
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("SettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure SettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") And StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInShipmentDocuments;
		NameTable = ?(Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly"),
			"Inventory", "Products");
		TableObject = Object[NameTable];
		
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If TableObject.Count() Then
				Object.SalesOrder = TableObject[0].SalesOrder;
			EndIf;
			
		Else
			
			If ValueIsFilled(Object.SalesOrder) Then
				For Each InventoryRow In TableObject Do
					If Not ValueIsFilled(InventoryRow.SalesOrder) Then
						InventoryRow.SalesOrder = Object.SalesOrder;
					EndIf;
				EndDo;
				
				Object.SalesOrder = Undefined;
				Object.BasisDocument = Undefined;
			EndIf;
			
		EndIf;
		
		SetVisibleAndEnabled();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeOrderTabularSection()
	
	If Object.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		For Each TabularSectionRow In Object.Products Do
			TabularSectionRow.SalesOrder = Undefined;
		EndDo;
	Else
		For Each TabularSectionRow In Object.Inventory Do
			TabularSectionRow.SalesOrder = Documents.SalesOrder.EmptyRef();
		EndDo;
	EndIf;
	
EndProcedure

// Reservation

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

// End Reservation

#EndRegion
