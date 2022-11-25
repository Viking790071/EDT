
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

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
	
	FillUseProductionPlanning();
	SetGroupScheduled(True);
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
		WorkInProgressGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProgress");
		
	EndIf;
	
	Items.ActivitiesGLAccount.Visible = UseDefaultTypeOfAccounting;
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetModeAndChoiceList();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance, "Disposals");
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(
		Metadata.Documents.ManufacturingOperation.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals.
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList(
		"ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	EditActualWorkloadInManufacturingOperation = IsInRole("EditActualWorkloadInManufacturingOperation");
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
	SetByProductsTabVisible();
	SetGroupSubcontractorOrders();
	
	UseDataExchangeWithProManage = GetFunctionalOption("UseDataExchangeWithProManage");
	
	// No reservation for subcontracting
	BasedOnSubcontracting = (TypeOf(Object.BasisDocument.BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived"));
	If BasedOnSubcontracting Then
		CommonClientServer.SetFormItemProperty(Items, "InventoryCommandsChangeReserve", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "InventoryReserve", "Visible", False);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	CalculateActivitiesTotals();
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisObject, "BarCodeScanner");
	// End Peripherals
	
	FormManagement();
	
	FillActivitiesValueList();
	FillAddedColumnActivity(Object);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	Notify("DocumentWIPGenerationVisibility", Object.Ref);
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisObject);
	// End Peripherals
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
		
	ElsIf ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		
		Modified = True;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals" And IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				// Get a barcode from the basic data
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1));
			Else
				// Get a barcode from the additional data
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1));
			EndIf;
			
			BarcodesReceived(Data);
			
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SerialNumbersSelection"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID Then
		
		GetSerialNumbersInventoryFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		
	ElsIf EventName = "RefreshProductionOrderQueue" Then
		
		If ValueIsFilled(Parameter) And Parameter.Find(Object.Ref) <> Undefined Then
			SetGroupScheduled();
		EndIf;
		
	ElsIf EventName = "RefreshGroupSubcontractorOrders" Then
		SetGroupSubcontractorOrders();		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	DocumentDate = CurrentObject.Date;
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClientServer.UpdateCommands(ThisObject, Object);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.EditProhibitionDates
	PeriodClosingDates.ObjectOnReadAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.EditProhibitionDates
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	FillAddedColumnActivity(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.AdditionalProperties.Insert("NeedRecalculation", NeedRecalculation);
	
	If Object.Status = Enums.ManufacturingOperationStatuses.Completed Then
		
		Cancel = CheckActivitiesOnComplitedStatus();
		
		If Cancel Then
			
			TextMessage = NStr("en = 'Cannot set status to Completed. 
				|Set status to In progress, set each operation as Done, and try again.'; 
				|ru = 'Невозможно установить статус ""Завершена"". 
				|Установите статус ""В работе"", для каждой операции укажите статус ""Завершена"" и повторите попытку.';
				|pl = 'Nie można ustawić statusu na Zakończono. 
				|Ustaw status na W toku, ustaw każdą operację na Wykonane i spróbuj ponownie.';
				|es_ES = 'No se puede establecer el estado en Completado. 
				|Establece el estado En progreso, establece cada operación en estado Hecho, e inténtalo de nuevo.';
				|es_CO = 'No se puede establecer el estado en Completado. 
				|Establece el estado En progreso, establece cada operación en estado Hecho, e inténtalo de nuevo.';
				|tr = 'Durum Tamamlandı olarak ayarlanamıyor. 
				|Durumu İşlemde olarak ayarlayın, her bir operasyonu Bitti olarak ayarlayın ve tekrar deneyin.';
				|it = 'Impossibile impostare lo stato su Completato. 
				|Impostare stato su In lavorazione, impostare ciascuna operazione su Fatto e riprovare.';
				|de = 'Der Status kann nicht auf Abgeschlossen festgelegt werden. 
				|Setzen Sie den Status auf In Bearbeitung, legen Sie jede Operation als Fertig fest, und versuchen Sie es erneut.'");
			
			CommonClientServer.MessageToUser(TextMessage);
			
			Return;
			
		EndIf;
		
		If Object.ProductionMethod = Enums.ProductionMethods.Subcontracting Then
			
			Cancel = CheckСompletionSubcontractorOrder(Object.Ref);
			
			If Cancel Then
				
				TextMessage = NStr("en = 'Cannot set the status to Completed. This document is related to the ""Subcontractor order issued"" whose status is other than Completed. Complete the order first. Then try again.'; ru = 'Не удалось установить статус ""Завершена"". Этот документ связан с выданным заказом на переработку, для которого не установлен статус ""Завершен"". Выполните заказ и повторите попытку.';pl = 'Nie można ustawić statusu Zakończono. Ten dokument jest związany z dokumentem ""Wydane zamówienie wykonawcy"", którego status jest inny niż Zakończono. Najpierw zakończ zamówieni. Potem spróbuj ponownie.';es_ES = 'No se ha podido establecer el estado en Finalizado. Este documento está relacionado con la ""Orden emitida del subcontratista"" cuyo estado es distinto de Finalizado. Finaliza primero la orden. Inténtelo de nuevo.';es_CO = 'No se ha podido establecer el estado en Finalizado. Este documento está relacionado con la ""Orden emitida del subcontratista"" cuyo estado es distinto de Finalizado. Finaliza primero la orden. Inténtelo de nuevo.';tr = 'Durum Tamamlandı olarak ayarlanamıyor. Bu belge, durumu Tamamlandı olmayan bir ""Düzenlenen alt yüklenici siparişi"" ile bağlantılı. Önce siparişi tamamlayıp tekrar deneyin.';it = 'Impossibile impostare lo stato Completato. Il documento è relativo a ""Ordine di subfornitura emesso"", il cui stato è diverso da Completato. Completare prima l''ordine, poi riprovare.';de = 'Fehler beim Festlegen des Status Abgeschlossen. Dieses Dokument ist mit ""Subunternehmerauftrag ausgestellt"" mit einem anderen Status als Abgeschlossen verbunden. Zuerst schließen Sie den Auftrag ab. Dann versuchen Sie erneut.'");
				
				CommonClientServer.MessageToUser(TextMessage);
				
				Return;
				
			EndIf;
			
			Cancel = CheckСompletionSubcontractingWIP();
			
			If Cancel Then
				
				CommonClientServer.MessageToUser(TextErrorСompletionSubcontractingWIP(Enums.ManufacturingOperationStatuses.Completed));
				
				Return;
				
			EndIf;

		EndIf;
		
	ElsIf Object.Status = Enums.ManufacturingOperationStatuses.InProcess Then
		
		If Object.ProductionMethod = Enums.ProductionMethods.Subcontracting Then
			
			Cancel = CheckСompletionSubcontractingWIP();
			
			If Cancel Then
				
				CommonClientServer.MessageToUser(TextErrorСompletionSubcontractingWIP(Enums.ManufacturingOperationStatuses.InProcess));
				
				Return;
				
			EndIf;
		EndIf;
	
	EndIf;
	
	If WriteParameters.WriteMode = DocumentWriteMode.Posting And Object.Activities.Count() Then
		
		For Each InventoryLine In Object.Inventory Do
			
			If InventoryLine.ActivityConnectionKey = 0 Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'On the Components tab, an operation is required for each component.'; ru = 'Во вкладке Сырье и материалы для каждого материала требуется указать операцию.';pl = 'Na karcie Komponenty, operacja jest wymagana dla każdego materiału.';es_ES = 'En la pestaña Componentes, se requiere una operación para cada componente.';es_CO = 'En la pestaña Componentes, se requiere una operación para cada componente.';tr = 'Malzemeler sekmesinde, her malzeme için bir işlem gerekli.';it = 'Nella scheda Componenti, è richiesta un''operazione per ciascuna componente.';de = 'Auf der Registerkarte „Nebenprodukte“ ist für jedes Nebenprodukt eine Operation erforderlich.'"),
					"Object.Inventory",
					InventoryLine.LineNumber,
					"ActivityAlias",
					Cancel);
				
			EndIf;
			
		EndDo;
		
		For Each DisposalsLine In Object.Disposals Do
			
			If DisposalsLine.ActivityConnectionKey = 0 Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'On the By-products tab, an operation is required for each by-product.'; ru = 'Во вкладке Побочная продукция для каждой побочной продукции требуется указать операцию.';pl = 'Na karcie Produkty uboczne, operacja jest wymagana według każdego produktu.';es_ES = 'En la pestaña de Trozo y deterioro, se requiere una operación para cada Trozo y deterioro.';es_CO = 'En la pestaña de Trozo y deterioro, se requiere una operación para cada Trozo y deterioro.';tr = 'Yan ürünler sekmesinde her yan ürün için bir işlem gerekli.';it = 'Nella scheda Scarti e Residui è richiesta una operazione per ciascuno scarto e residuo.';de = 'Auf der Registerkarte „Nebenprodukte“ ist für jedes Nebenprodukt eine Operation erforderlich.'"),
					"Object.Disposals",
					DisposalsLine.LineNumber,
					"ActivityAlias",
					Cancel);
				
			EndIf;
			
		EndDo;
		
		If UseProductionPlanning Then
			ProductionPlanningClientServer.CheckTableOfRouting(Object.Activities, Cancel, True);
		EndIf;	
		
	EndIf;
		
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents

EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;

	FillAddedColumnActivity(Object);
	
	SetGroupScheduled(True);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshProductionOrderQueue", CommonClientServer.ValueInArray(Object.BasisDocument));
	Notify("WorkInProgressChanged", Object.Ref);
	Notify("RefreshAccountingTransaction");
	FormManagement();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DateOnChange(Item)
	
	DriveClient.ProcessDateChange(ThisObject, "");
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	ParentCompany = StructureData.Company;
	
EndProcedure

&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("StatusOnChangeWriteDoc", ThisObject),
			NStr("en = 'Cannot change the status. The document is not saved. To save it and change the status, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается изменить статус. Документ не сохранен. Чтобы сохранить его и изменить статус, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można zmienić statusu. Dokument nie jest zapisany. Aby zapisać go i zmienić status, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede cambiar el estado. El documento no está guardado. Para guardarlo y cambiar el estado, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede cambiar el estado. El documento no está guardado. Para guardarlo y cambiar el estado, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'Durum değiştirilemiyor. Belge kaydedilmedi. Kaydetmek için durumu değiştirip Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile modificare status. Il documento non è salvato. Per salvarlo e modificare lo status, cliccare su OK. Per continuare a modificare il documento, cliccare su Annulla.';de = 'Der Status kann nicht geändert werden. Das Dokument wird nicht gespeichert. Um es zu speichern und den Status zu ändern, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		StatusOnChangeAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject);
	
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit) Then
	
		StructureData = New Structure();
		StructureData.Insert("Department", Object.StructuralUnit);
		
		StructureData = GetDataStructuralUnitOnChange(StructureData);
		
		If ValueIsFilled(StructureData.InventoryStructuralUnit) Then
			
			If Object.InventoryStructuralUnitPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
				Object.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
				Object.CellInventory = StructureData.CellInventory;
			Else
				For Each Row In Object.Inventory Do
					Row.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
					Row.CellInventory = StructureData.CellInventory;
				EndDo;
			EndIf;
			
		Else
			
			If Object.InventoryStructuralUnitPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
				Object.InventoryStructuralUnit = Object.StructuralUnit;
				Object.CellInventory = Object.Cell;
			Else
				For Each Row In Object.Inventory Do
					Row.InventoryStructuralUnit = Object.StructuralUnit;
					Row.CellInventory = Object.Cell;
				EndDo;
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(StructureData.DisposalsStructuralUnit) Then
			
			Object.DisposalsStructuralUnit = StructureData.DisposalsStructuralUnit;
			Object.DisposalsCell = StructureData.DisposalsCell;
			
		Else
			
			Object.DisposalsStructuralUnit = Object.StructuralUnit;
			Object.DisposalsCell = Object.Cell;
			
		EndIf;
		
	Else
		
		Items.Cell.Enabled = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.StructuralUnit) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure CellOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("StructuralUnit", Object.StructuralUnit);
	StructureData.Insert("Cell", Object.Cell);
	StructureData.Insert("InventoryStructuralUnit", Object.InventoryStructuralUnit);
	StructureData.Insert("CellInventory", Object.CellInventory);
	StructureData.Insert("DisposalsStructuralUnit", Object.DisposalsStructuralUnit);
	StructureData.Insert("DisposalsCell", Object.DisposalsCell);
	
	StructureData = GetDataCellOnChange(StructureData);
	
	If StructureData.Property("NewCellInventory") Then
		Object.CellInventory = StructureData.NewCellInventory;
	EndIf;
	
	If StructureData.Property("NewCellWastes") Then
		Object.DisposalsCell = StructureData.NewCellWastes;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitOnChange(Item)
	
	Items.CellInventory.Enabled = ValueIsFilled(Object.InventoryStructuralUnit);
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsStructuralUnitOnChange(Item)
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		Items.DisposalsCell.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.DisposalsStructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductionMethodOnChange(Item)
	
	FormManagement();
	
	Object.Inventory.Clear();

EndProcedure

#EndRegion

#Region InventoryFormTableItemsEventHandlers

&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("OwnershipType", OwnershipType);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData,, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(
		Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		If Object.Activities.Count() = 1 Then
			UniqueActivity = Object.Activities[0];
			Item.CurrentData.ActivityAlias = ActivityDescription(UniqueActivity.LineNumber, UniqueActivity.Activity);
			Item.CurrentData.ActivityConnectionKey = UniqueActivity.ConnectionKey;
		EndIf;
		
	ElsIf NewRow And Clone Then
		
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
		
	EndIf;
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	EndIf;
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		
		StandardProcessing = False;
		IsReadOnly = (Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed")
			And Not Modified);			
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory", , IsReadOnly);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	
	ThisIsNewRow = False;
	
EndProcedure

&AtClient
Procedure InventoryActivityStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = ActivitiesValueList;
	
EndProcedure

&AtClient
Procedure InventoryActivityChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	Row = Items.Inventory.CurrentData;
	If Row <> Undefined Then
		
		SelectedActivity = Object.Activities.FindByID(SelectedValue);
		Row.ActivityAlias = ActivityDescription(SelectedActivity.LineNumber, SelectedActivity.Activity);
		Row.ActivityConnectionKey = SelectedActivity.ConnectionKey;
		
		Items.Inventory.CurrentItem = Items.InventoryGLAccounts;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, Object.Date);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

#EndRegion

#Region DisposalsFormTableItemsEventHandlers

&AtClient
Procedure DisposalsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone Then
		
		If Object.Activities.Count() = 1 Then
			UniqueActivity = Object.Activities[0];
			Item.CurrentData.ActivityAlias = ActivityDescription(UniqueActivity.LineNumber, UniqueActivity.Activity);
			Item.CurrentData.ActivityConnectionKey = UniqueActivity.ConnectionKey;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Disposals");
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	StructureData = GetDataProductsOnChange(StructureData, False, Object.Date);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure DisposalsActivityAliasStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = ActivitiesValueList
	
EndProcedure

&AtClient
Procedure DisposalsActivityAliasChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	Row = Items.Disposals.CurrentData;
	If Row <> Undefined Then
		
		SelectedActivity = Object.Activities.FindByID(SelectedValue);
		Row.ActivityAlias = ActivityDescription(SelectedActivity.LineNumber, SelectedActivity.Activity);
		Row.ActivityConnectionKey = SelectedActivity.ConnectionKey;
		Items.Disposals.CurrentItem = Items.DisposalsOwnership;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ActivitiesFormTableItemsEventHandlers

&AtClient
Procedure ActivitiesOnStartEdit(Item, NewRow, Clone)
	
	TabularSectionName = "Activities";
	If NewRow Then
		
		If UseDefaultTypeOfAccounting Then
			Item.CurrentData.GLAccount = WorkInProgressGLAccount;
		EndIf;
		
		If Clone Then
			CalculateActivitiesTotals();
		EndIf;
		
		Item.CurrentData.ConnectionKey = NewConnectionKey();
		FillActivitiesValueList();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivitiesOnEditEnd(Item, NewRow, CancelEdit)
	
	If NewRow And CancelEdit Then
		CalculateActivitiesTotals();
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivitiesBeforeDeleteRow(Item, Cancel)
	
	For Each ActivityIndex In Item.SelectedRows Do
		
		DeleteConnectedComponents(Object.Activities.FindByID(ActivityIndex).ConnectionKey);
		
	EndDo;
	
	ShowUserNotification(NStr("en = 'The deleted operations were specified for the components on the Components tab. These components were deleted from this tab.'; ru = 'Удаленные операции были определены для компонентов на вкладке Компоненты. Эти компоненты были удалены из этой вкладки.';pl = 'Usunięte operacje zostały wybrane dla komponentów w karcie Komponenty. Te komponenty zostały usunięte z tej karty.';es_ES = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Componentes. Estos componentes fueron eliminados de esta pestaña.';es_CO = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Componentes. Estos componentes fueron eliminados de esta pestaña.';tr = 'Silinen operasyonlar Malzemeler sekmesindeki malzemeler için belirtildi. Bu malzemeler bu sekmeden silindi.';it = 'Le operazioni cancellate sono state specificate per le componenti nella scheda Componenti. Queste componenti sono state cancellate da questa scheda.';de = 'Die gelöschten Operationen wurden für den Materialbestand auf der Registerkarte ""Materialbestand"" angegeben. Dieser Materialbestand wurde aus dieser Registerkarte gelöscht.'"));
	
EndProcedure

&AtClient
Procedure ActivitiesAfterDeleteRow(Item)
	
	CalculateActivitiesTotals();
	FillActivitiesValueList();
	
EndProcedure

&AtClient
Procedure ActivitiesDoneOnChange(Item)
	
	CurrentData = Item.Parent.CurrentData;
	
	If CurrentData.Done
		And Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("DoneOnChangeWriteDoc", ThisObject),
			NStr("en = 'Cannot complete the operation. The document is not saved. To save it and complete the operation, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается завершить операцию. Документ не сохранен. Чтобы сохранить его и завершить операцию, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można zakończyć operacji. Dokument nie jest zapisany. Aby zapisać go i zakończyć operację, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'İşlem tamamlanamıyor. Belge kaydedilmedi. Belgeyi kaydedip işlemi tamamlamak için Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile completare l''operazione. Il documento non è salvato. Per salvarlo e completare l''operazione, cliccare su OK. Per continuare a modificare il documento, cliccare su Annulla.';de = 'Die Operation kann nicht abgeschlossen werden. Das Dokument wird nicht gespeichert. Um es zu speichern und die Operation abzuschließen, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
			
	Else
	
		If CurrentData.Done 
			And Not Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess") Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot set Done for the operations. The document status is %1. Change the status to In progress.'; ru = 'Невозможно установить флажок ""Завершена"" для операций. Статус документа - %1. Измените статус на ""В работе"".';pl = 'Nie można ustawić dla działań. Status dokumentu jest %1. Zmień status na W toku.';es_ES = 'No se puede establecer Hecho para operaciones. El estado del documento es %1. Cambie el estado a En progreso.';es_CO = 'No se puede establecer Hecho para operaciones. El estado del documento es %1. Cambie el estado a En progreso.';tr = 'İşlemler için Tamamlandı durumu ayarlanamıyor. Belge durumu %1. Durumu İşlemde olarak değiştirin.';it = 'Impossibile impostare Completato per le operazioni. Lo status del documento è %1. Modificare status in In corso.';de = 'Kann Abgeschlossen für die Operationen nicht eingeben. Der Dokumentstatus ist %1. Ändern Sie den Status für In Bearbeitung.'"),
				TrimAll(Object.Status));
				
			CommonClientServer.MessageToUser(TextMessage);
				
			CurrentData.Done = False;
			
		ElsIf CurrentData.Done Then
			
			FinishOperationFragment();
			
		Else
			
			CurrentData.FinishDate = Date(1, 1, 1);
			
		EndIf;
		
		CalculateActivitiesTotals();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivitiesStartDateOnChange(Item)
	
	CurrentData = Item.Parent.CurrentData;
	
	If ValueIsFilled(CurrentData.StartDate)
		And Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("StartDateOnChangeWriteDoc", ThisObject),
			NStr("en = 'Cannot start the operation. The document is not saved. To save it and start the operation, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается начать операцию. Документ не сохранен. Чтобы сохранить его и начать операцию, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można rozpocząć operacji. Dokument nie jest zapisany. Aby zapisać go i rozpocząć operację, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede iniciar la operación. El documento no se ha guardado. Para guardarlo e iniciar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede iniciar la operación. El documento no se ha guardado. Para guardarlo e iniciar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'İşlem başlatılamıyor. Belge kaydedilmedi. Belgeyi kaydedip işlemi başlatmak için Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile avviare l''operazione. Il documento non è salvato. Per salvarlo e avviare l''operazione, cliccare su OK. Per continuare a modificare il documento, cliccare su Annulla.';de = 'Die Operation kann nicht gestartet werden. Das Dokument wird nicht gespeichert. Um es zu speichern und die Operation zu starten, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		CheckToSetInProgressStatus();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivitiesFinishDateOnChange(Item)
	
	CurrentData = Item.Parent.CurrentData;
	
	If ValueIsFilled(CurrentData.FinishDate)
		And Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("FinishDateOnChangeWriteDoc", ThisObject),
			NStr("en = 'Cannot complete the operation. The document is not saved. To save it and complete the operation, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается завершить операцию. Документ не сохранен. Чтобы сохранить его и завершить операцию, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można zakończyć operacji. Dokument nie jest zapisany. Aby zapisać go i zakończyć operację, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'İşlem tamamlanamıyor. Belge kaydedilmedi. Belgeyi kaydedip işlemi tamamlamak için Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile completare l''operazione. Il documento non è salvato. Per salvarlo e completare l''operazione, cliccare su OK. Per continuare a modificare il documento, cliccare su Annulla.';de = 'Die Operation kann nicht abgeschlossen werden. Das Dokument wird nicht gespeichert. Um es zu speichern und die Operation abzuschließen, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
			
	Else
		
		CurrentData.Done = ValueIsFilled(CurrentData.FinishDate);
		CurrentData.StartDate = ?(ValueIsFilled(CurrentData.StartDate), CurrentData.StartDate, CurrentData.FinishDate);
		CalculateActivitiesTotals();
		CheckToSetInProgressStatus();
		CheckToSetCompletedStatus();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ActivitiesActivityOnChange(Item)
	
	RowData = Items.Activities.CurrentData;
	
	ObjectData = New Structure(
		"Date,
		|Company,
		|StructuralUnit,
		|Specification,
		|Quantity,
		|MeasurementUnit");
	FillPropertyValues(ObjectData, Object);
	
	ActivityData = GetActivityDataOnChange(RowData.Activity, ObjectData);
	
	FillPropertyValues(RowData, ActivityData);
	CalculateActivityTotalAndActualWorkload(RowData);
	
	FillComponentsByBOMOnActivitiesChange();
	
	FillActivitiesValueList();
	FillAddedColumnActivity(Object, RowData.ConnectionKey);
	
EndProcedure

&AtClient
Procedure ActivitiesQuantityOnChange(Item)
	
	RowData = Items.Activities.CurrentData;
	CalculateActivityTotalAndActualWorkload(RowData);
	
	FillComponentsByBOMOnActivitiesChange();
	
EndProcedure

&AtClient
Procedure ActivitiesActualWorkloadOnChange(Item)
	
	RowData = Items.Activities.CurrentData;
	
	RowData.Total = RowData.ActualWorkload * RowData.Rate;
	
	CalculateActivitiesTotals();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Not CheckBOMFilling(True) Then
		Return;
	EndIf;
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
			NStr("en = 'Tabular section ""Components"" will be filled in again. Continue?'; ru = 'Табличная часть ""Сырье и материалы"" будет перезаполнена. Продолжить?';pl = 'Sekcja tabelaryczna ""Komponenty"" zostanie wypełniona ponownie. Kontynuować?';es_ES = 'Sección tabular ""Componentes"" se volverá rellenar. ¿Continuar?';es_CO = 'Sección tabular ""Componentes"" se volverá rellenar. ¿Continuar?';tr = '""Malzemeler"" tablo bölümü tekrar doldurulacak. Devam edilsin mi?';it = 'La sezione tabellare ""Componenti"" sarà ricompilata. Continuare?';de = 'Der tabellarische Abschnitt ""Materialbestand"" wird erneut ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		CommandToFillBySpecificationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInActivitiesByBOM(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Activities.Count() > 0 Then
		
		AddParameters = New Structure("ConnectionKey", Object.Activities[0].ConnectionKey);
		
		ComponentsMessage = "";
		If Object.Inventory.Count() Then
			ComponentsMessage = NStr("en = 'The data on Components tab will be cleared.'; ru = 'Данные на вкладке ""Сырье и материалы"" будут очищены.';pl = 'Dane na karcie Komponenty zostaną wyczyszczone.';es_ES = 'Los datos de la pestaña Componentes se borrarán.';es_CO = 'Los datos de la pestaña Componentes se borrarán.';tr = 'Malzemeler sekmesindeki veriler temizlenecek.';it = 'I dati nella scheda Componenti saranno cancellati.';de = 'Die Daten auf der Registerkarte Materialbestand werden gelöscht.'");
		EndIf;
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The data on Operations tab will be replaced with the data from the bill of materials. %1
				|Do you want to continue?'; 
				|ru = 'Данные на вкладке ""Операции"" будут заменены данными из спецификации. %1
				|Продолжить?';
				|pl = 'Dane na karcie Operacje zostaną zastąpione danymi ze specyfikacji materiałowej.%1
				|Czy chcesz kontynuować?';
				|es_ES = 'Los datos de la pestaña ""Operaciones"" se reemplazarán por los datos de la lista de materiales.%1
				|¿Quiere continuar?';
				|es_CO = 'Los datos de la pestaña ""Operaciones"" se reemplazarán por los datos de la lista de materiales.%1
				|¿Quiere continuar?';
				|tr = 'İşlemler sekmesindeki veriler ürün reçetesindeki verilerle değiştirilecek. %1
				|Devam etmek istiyor musunuz?';
				|it = 'I dati nella scheda Operazioni saranno sostituiti con i dati della Distinta Base. %1
				|Continuare?';
				|de = 'Die Daten auf der Registerkarte Operationen werden durch die Daten aus der ausgewählten Stückliste ersetzt. %1
				|Möchten Sie fortsetzen?'"),
			ComponentsMessage);
		
		ShowQueryBox(
			New NotifyDescription("FillInActivitiesByBOMEnd", ThisObject, AddParameters),
			QueryText,
			QuestionDialogMode.YesNo);
	Else
		AddParameters = New Structure("ConnectionKey", 1);
		FillInActivitiesByBOMFragment(AddParameters);
	EndIf;
	
EndProcedure

&AtClient
Procedure StartOperation(Command)
	
	If Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("StartOperationWriteDoc", ThisObject),
			NStr("en = 'To start operation, you must save your work.
				|Click OK to save and continue, or click Cancel to return.'; 
				|ru = 'Для того, чтобы начать операцию, необходимо сохранить данные.
				|Нажмите ОК, чтобы сохранить данные и продолжить, или Отмена для возврата.';
				|pl = 'Aby rozpocząć operację, musisz swoją pracę.
				|Kliknij OK aby zapisać i kontynuować, lub kliknij Anuluj aby powrócić.';
				|es_ES = 'Para iniciar la operación, debe guardar su trabajo.
				|Haga clic en Aceptar para guardar y continuar, o haga clic en Cancelar para volver.';
				|es_CO = 'Para iniciar la operación, debe guardar su trabajo.
				|Haga clic en Aceptar para guardar y continuar, o haga clic en Cancelar para volver.';
				|tr = 'İşlemi başlatmak için çalışmanızı kaydedin.
				|Kaydedip devam etmek için Tamam''a, geri dönmek için İptal''e tıklayın.';
				|it = 'Per avviare l''operazione è necessario salvare il proprio lavoro.
				|Cliccare su OK per salvare e continuare, o su Annulla per tornare indietro.';
				|de = 'Um die Operation zu starten, müssen Sie Ihre Arbeit speichern.
				|Klicken Sie auf OK um zu speichern und fortzufahren oder klicken Sie auf Abbrechen, um zurückzukehren.'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		StartOperationAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperation(Command)
	
	If Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("FinishOperationWriteDoc", ThisObject),
			NStr("en = 'Cannot complete the operation. The document is not saved. To save it and complete the operation, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается завершить операцию. Документ не сохранен. Чтобы сохранить его и завершить операцию, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można zakończyć operacji. Dokument nie jest zapisany. Aby zapisać go i zakończyć operację, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'İşlem tamamlanamıyor. Belge kaydedilmedi. Belgeyi kaydedip işlemi tamamlamak için Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile completare l''operazione. Il documento non è salvato. Per salvarlo e completare l''operazione, cliccare su OK. Per continuare a modificare il documento, cliccare su Annulla.';de = 'Die Operation kann nicht abgeschlossen werden. Das Dokument wird nicht gespeichert. Um es zu speichern und die Operation abzuschließen, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		FinishOperationAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationsProManage(Command)
	
	If Object.Ref.IsEmpty() Then
		
		ShowQueryBox(
			New NotifyDescription("FinishOperationProManageWriteDoc", ThisObject),
			NStr("en = 'Cannot complete the operation. The document is not saved. To save it and complete the operation, click OK. To continue editing the document, click Cancel.'; ru = 'Не удается завершить операцию. Документ не сохранен. Чтобы сохранить его и завершить операцию, нажмите ОК. Для продолжения редактирования документа нажмите Отмена.';pl = 'Nie można zakończyć operacji. Dokument nie jest zapisany. Aby zapisać go i zakończyć operację, kliknij OK. Aby kontynuować edycję dokumentu, kliknij Anuluj.';es_ES = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';es_CO = 'No se puede finalizar la operación. El documento no se ha guardado. Para guardarlo y finalizar la operación, haga clic en Aceptar. Para continuar editando el documento, haga clic en Cancelar.';tr = 'İşlem tamamlanamıyor. Belge kaydedilmedi. Belgeyi kaydedip işlemi tamamlamak için Tamam''a tıklayın. Belgeyi düzenlemeye devam etmek için İptal''e tıklayın.';it = 'Impossibile completare l''operazione. Il documento non è stato salvato. Per salvarlo e completare l''operazione, cliccare su OK. Per proseguire con la modifica del documento, cliccare Annullare.';de = 'Die Operation kann nicht abgeschlossen werden. Das Dokument wird nicht gespeichert. Um es zu speichern und die Operation abzuschließen, klicken Sie auf OK. Um das Dokument weiter zu bearbeiten, klicken Sie auf Abbrechen.'"),
			QuestionDialogMode.OKCancel);
		
	Else
		
		FinishOperationProManageAtClient();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription(
		"ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName", "ManufacturingOperation.Inventory");
	DataLoadSettings.Insert("Title", NStr("en = 'Import goods from file'; ru = 'Загрузка товаров из файла';pl = 'Import towarów z pliku';es_ES = 'Importar mercancías del archivo';es_CO = 'Importar mercancías del archivo';tr = 'Malları dosyadan içe aktar';it = 'Importa merci da file';de = 'Importieren Sie Waren aus der Datei'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(
		DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	SelectionMarker		= "Disposals";
	
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'Produktion'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(
		ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
		
	SelectionParameters.Insert("Company", ParentCompany);
	
	SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	
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
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'production'; ru = 'производство';pl = 'produkcja';es_ES = 'producción';es_CO = 'producción';tr = 'üretim';it = 'produzione';de = 'Produktion'");
	
	SelectionParameters	= DriveClient.GetSelectionParameters(
		ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	
	SelectionParameters.Insert("Company", ParentCompany);
	
	SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	
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

&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	NotifyDescr = New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode));
	ShowInputValue(NotifyDescr, CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));

EndProcedure

&AtClient
Procedure AllocateWorkHours(Command)
	
	Coeffs = New Array;
	
	For Each LaborRow In Object.LaborAssignment Do
		Coeffs.Add(LaborRow.LPR);
	EndDo;
	
	TotalActualWorkload = 0;
	For Each ActivitiesRow In Object.Activities Do
		If ActivitiesRow.Done Then
			TotalActualWorkload = TotalActualWorkload + ActivitiesRow.ActualWorkload;
		EndIf;
	EndDo;
	
	AllocationResult = CommonClientServer.DistributeAmountInProportionToCoefficients(TotalActualWorkload, Coeffs);
	
	If Not AllocationResult = Undefined Then
		For Index = 0 To Object.LaborAssignment.Count() - 1 Do
			Object.LaborAssignment[Index].HoursWorked = AllocationResult[Index];
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInByTeams(Command)
	
	If Object.LaborAssignment.Count() <> 0 Then
		Response = Undefined;
		
		ShowQueryBox(New NotifyDescription("FillInByTeamsEnd", ThisObject),
			NStr("en = 'This will overwrite the list of assignees. Do you want to continue?'; ru = 'Табличная часть ""Исполнители"" будет перезаполнена! Продолжить выполнение операции?';pl = 'Lista wykonawców zostanie nadpisana. Czy chcesz kontynuować?';es_ES = 'Eso sobrescribirá la lista de beneficiarios. ¿Quiere continuar?';es_CO = 'Eso sobrescribirá la lista de beneficiarios. ¿Quiere continuar?';tr = 'Bu işlem temsilciler listesinin üzerine yazacaktır. Devam etmek istiyor musunuz?';it = 'Questo sovrascriverà l''elenco degli assegnatari per i lavori in corso. Volete continuare?';de = 'Dies überschreibt die Liste der Empfänger. Möchten Sie fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return;
	EndIf;
	
	FillInByTeamsFragment();
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOM(Command)
	
	If Not CheckBOMFilling() Then
		Return;
	EndIf;
	
	If Object.Disposals.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("FillInByProductsWithBOMEnd", ThisObject),
			NStr("en = 'The data on the ""By-products"" tab will be replaced with the data from the bill of materials. Do you want to continue?'; ru = 'Данные во вкладке ""Побочная продукция"" будут заменены данными из спецификации. Продолжить?';pl = 'Dane na karcie ""Produkty uboczne"" zostaną zastąpione danymi ze specyfikacji materiałowej. Czy chcesz kontynuować?';es_ES = 'Los datos de la pestaña ""Trozo y deterioro"" se reemplazarán por los datos de la lista de materiales. ¿Quiere continuar?';es_CO = 'Los datos de la pestaña ""Trozo y deterioro"" se reemplazarán por los datos de la lista de materiales. ¿Quiere continuar?';tr = '""Yan ürünler"" sekmesindeki veriler ürün reçetesindeki verilerle değiştirilecek. Devam etmek istiyor musunuz?';it = 'I dati nella scheda ""Scarti e residui"" saranno sostituiti con i dati della distinta base. Continuare?';de = 'Die Daten auf der Registerkarte ""Nebenprodukte"" werden durch die Daten aus der ausgewählten Stückliste ersetzt. Möchten Sie fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		FillInByProductsWithBOMFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInWithBOM(Command)
	
	If Not ValueIsFilled(Object.Specification) Then
		MessagesToUserClient.ShowMessageSelectBOM();
		Return;
	EndIf;
	
	If Object.Disposals.Count() Or Object.Activities.Count() Or Object.Inventory.Count() Then
		
		ShowQueryBox(
			New NotifyDescription("FillInWithBOMEnd", ThisObject),
			NStr("en = 'All tabular sections will be filled in again. Continue?'; ru = 'Табличные части будут перезаполнены. Продолжить?';pl = 'Wszystkie sekcje tabelaryczne zostaną wypełnione ponownie. Kontynuować?';es_ES = 'Todas las secciones tabulares se volverán a rellenar. ¿Continuar?';es_CO = 'Todas las secciones tabulares se volverán a rellenar. ¿Continuar?';tr = 'Tüm tablo bölümleri tekrar doldurulacak. Devam edilsin mi?';it = 'Tutte le sezioni tabellari saranno ricompilate. Continuare?';de = 'Alle tabellarische Abschnitte werden erneut ausgefüllt. Fortsetzen?'"),
			QuestionDialogMode.YesNo);
	Else
		FillInWithBOMFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure DocumentSetup(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("InventoryStructuralUnitPositionInWIP", Object.InventoryStructuralUnitPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingCompleted", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingCompleted(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") And StructureDocumentSetting.WereMadeChanges Then
		
		Object.InventoryStructuralUnitPosition = StructureDocumentSetting.InventoryStructuralUnitPositionInWIP;
		
		BeforeInventoryStructuralUnitVisible = Items.InventoryStructuralUnit.Visible;
		
		FormManagement();
		
		If BeforeInventoryStructuralUnitVisible = False // It was in TS.
			And Items.InventoryStructuralUnit.Visible = True // It is in the header.
			And Object.Inventory.Count() Then
			
			Object.InventoryStructuralUnit = Object.Inventory[0].InventoryStructuralUnit;
			Object.CellInventory = Object.Inventory[0].CellInventory;
			
		EndIf;
		
		Modified = True;
		
	EndIf;
	
EndProcedure

// Reservation

&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNoProductsToReserve();
		
	Else
		
		FillColumnReserveByBalancesAtServer();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		
		MessagesToUserClient.ShowMessageNothingToClearAtReserve();
		
	Else
		
		For Each TabularSectionRow In Object.Inventory Do
			TabularSectionRow.Reserve = 0;
		EndDo;
		
	EndIf;
	
EndProcedure

// End Reservation

#EndRegion

#Region Private

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

#EndRegion

#Region StartFinishDateOfOperations

&AtClient
Procedure StartOperationAtClient()
	
	OneOperation = (Items.Activities.SelectedRows.Count() = 1);
	
	WasAsked = False;
	For Each ActivityID In Items.Activities.SelectedRows Do
		
		ActivityLine = Object.Activities.FindByID(ActivityID);
		
		If ValueIsFilled(ActivityLine.FinishDate) Then
			
			ShowQueryBox(
				New NotifyDescription("StartOperationEnd", ThisObject),
				?(OneOperation,
					NStr("en = 'The operation has already been completed. It will be restarted. Do you want to continue?'; ru = 'Операция уже завершена. Она будет перезапущена. Продолжить?';pl = 'Operacja jest już zakończona. Zostanie ona wznowiona. Czy chcesz kontynuować?';es_ES = 'La operación ya ha finalizado. Se reiniciará. ¿Quiere continuar?';es_CO = 'La operación ya ha finalizado. Se reiniciará. ¿Quiere continuar?';tr = 'İşlem zaten tamamlandı. İşlem yeniden başlatılacak. Devam etmek istiyor musunuz?';it = 'L''operazione è già stata completata. Sarà riavviata. Continuare?';de = 'Die Operationen ist bereits abgeschlossen. Sie wird neu gestartet. Möchten Sie fortfahren?'"),
					NStr("en = 'Some operations have already been completed. They will be restarted. Do you want to continue?'; ru = 'Некоторые операции уже завершены. Они будут перезапущены. Продолжить?';pl = 'Niektóre operacje zostały już zakończone. Zostaną one wznowione. Czy chcesz kontynuować?';es_ES = 'Algunas operaciones ya han finalizado. Se reiniciarán. ¿Quiere continuar?';es_CO = 'Algunas operaciones ya han finalizado. Se reiniciarán. ¿Quiere continuar?';tr = 'Bazı işlemler zaten tamamlandı. Bunlar yeniden başlatılacak. Devam etmek istiyor musunuz?';it = 'Alcune operazioni sono state già completate. Saranno riavviate. Continuare?';de = 'Einige Operationen sind bereits abgeschlossen. Sie werden neu gestartet. Möchten Sie fortfahren?'")),
				QuestionDialogMode.YesNo);
				
			WasAsked = True;
			Break;
			
		ElsIf ValueIsFilled(ActivityLine.StartDate) Then
			
			ShowQueryBox(
				New NotifyDescription("StartOperationEnd", ThisObject),
				?(OneOperation,
					NStr("en = 'The operation has already been started. Do you want to edit its start date?'; ru = 'Операция уже начата. Изменить дату ее начала?';pl = 'Operacja jest już rozpoczęta. Czy chcesz edytować datę jej rozpoczęcia?';es_ES = 'La operación ya se ha iniciado. ¿Quiere editar su fecha de inicio?';es_CO = 'La operación ya se ha iniciado. ¿Quiere editar su fecha de inicio?';tr = 'İşlem zaten başlatıldı. Başlangıç tarihini değiştirmek ister misiniz?';it = 'L''operazione è già stata avviata. Modificare la sua data di inizio?';de = 'Die Operation ist bereits gestartet. Möchten Sie ihr Startdatum bearbeiten?'"),
					NStr("en = 'Some operations have already been started. Do you want to edit their start dates?'; ru = 'Некоторые операции уже начаты. Изменить дату их начала?';pl = 'Niektóre operacje zostały już rozpoczęte. Czy chcesz edytować daty ich rozpoczęcia?';es_ES = 'Algunas operaciones ya se han iniciado. ¿Quiere editar sus fechas de inicio?';es_CO = 'Algunas operaciones ya se han iniciado. ¿Quiere editar sus fechas de inicio?';tr = 'Bazı işlemler zaten başlatıldı. Başlangıç tarihlerini değiştirmek ister misiniz?';it = 'Alcune operazioni sono già state avviate. Modificare la loro data di inizio?';de = 'Einige Operationen sind bereits gestartet. Möchten Sie ihre Startdaten bearbeiten?'")),
				QuestionDialogMode.YesNo);
				
			WasAsked = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not WasAsked Then
		StartOperationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationAtClient()
	
	OneOperation = (Items.Activities.SelectedRows.Count() = 1);
	
	WasAsked = False;
		
	For Each ActivityID In Items.Activities.SelectedRows Do
		
		ActivityLine = Object.Activities.FindByID(ActivityID);
		
		If ValueIsFilled(ActivityLine.FinishDate) Then
			
			ShowQueryBox(
				New NotifyDescription("FinishOperationEnd", ThisObject),
				?(OneOperation,
					NStr("en = 'The operation has already been completed. Do you want edit its end date?'; ru = 'Операция уже завершена. Изменить дату ее окончания?';pl = 'Operacja jest już zakończona. Czy chcesz edytować datę jej zakończenia?';es_ES = 'La operación ya ha finalizado. ¿Quiere editar su fecha final?';es_CO = 'La operación ya ha finalizado. ¿Quiere editar su fecha final?';tr = 'İşlem zaten tamamlandı. Bitiş tarihini değiştirmek ister misiniz?';it = 'L''operazione è già stata completata. Completare la sua data di fine?';de = 'Die Operation ist bereits abgeschlossen. Möchten Sie ihr Enddatum bearbeiten?'"),
					NStr("en = 'Some operations have already been completed. Do you want to edit their end dates?'; ru = 'Некоторые операции уже завершены. Изменить дату их окончания?';pl = 'Niektóre operacje zostały już zakończone. Czy chcesz edytować daty ich zakończenia?';es_ES = 'Algunas operaciones ya han finalizado. ¿Quiere editar sus fechas finales?';es_CO = 'Algunas operaciones ya han finalizado. ¿Quiere editar sus fechas finales?';tr = 'Bazı işlemler zaten tamamlandı. Bitiş tarihlerini değiştirmek ister misiniz?';it = 'Alcune operazioni sono già state completate. Modificare la loro data di fine?';de = 'Einige Operationen sind bereits abgeschlossen. Möchten Sie ihre Enddaten bearbeiten?'")),
				QuestionDialogMode.YesNo);
				
			WasAsked = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not WasAsked Then
		FinishOperationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationProManageAtClient()
	
	OneOperation = (Items.Activities.SelectedRows.Count() = 1);
	
	WasAsked = False;
		
	For Each ActivityLine In Object.Activities Do
		
		If ValueIsFilled(ActivityLine.FinishDate) Then
			
			ShowQueryBox(
				New NotifyDescription("FinishOperationEnd", ThisObject),
				?(OneOperation,
					NStr("en = 'The operation has already been completed. Do you want edit its end date?'; ru = 'Операция уже завершена. Изменить дату ее окончания?';pl = 'Operacja jest już zakończona. Czy chcesz edytować datę jej zakończenia?';es_ES = 'La operación ya ha finalizado. ¿Quiere editar su fecha final?';es_CO = 'La operación ya ha finalizado. ¿Quiere editar su fecha final?';tr = 'İşlem zaten tamamlandı. Bitiş tarihini değiştirmek ister misiniz?';it = 'L''operazione è già stata completata. Modificare la sua data di fine?';de = 'Die Operation ist bereits abgeschlossen. Möchten Sie ihr Enddatum bearbeiten?'"),
					NStr("en = 'Some operations have already been completed. Do you want to edit their end dates?'; ru = 'Некоторые операции уже завершены. Изменить дату их окончания?';pl = 'Niektóre operacje zostały już zakończone. Czy chcesz edytować daty ich zakończenia?';es_ES = 'Algunas operaciones ya han finalizado. ¿Quiere editar sus fechas finales?';es_CO = 'Algunas operaciones ya han finalizado. ¿Quiere editar sus fechas finales?';tr = 'Bazı işlemler zaten tamamlandı. Bitiş tarihlerini değiştirmek ister misiniz?';it = 'Alcune operazioni sono già state completate. Modificare la loro data di fine?';de = 'Einige Operationen sind bereits abgeschlossen. Möchten Sie ihre Enddaten bearbeiten?'")),
				QuestionDialogMode.YesNo);
				
			WasAsked = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	If Not WasAsked Then
		FinishOperationsProManageAtServer();
		CalculateActivitiesTotals();
		CheckToSetInProgressStatus();
		CheckToSetCompletedStatus();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartOperationWriteDoc(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Write(WriteParameters) Then
			StartOperationAtClient();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationWriteDoc(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Write(WriteParameters) Then
			FinishOperationAtClient();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationProManageWriteDoc(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Write(WriteParameters) Then
			FinishOperationProManageAtClient();
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure StartDateOnChangeWriteDoc(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Not Write(WriteParameters) Then
			CurrentLine = Items.Activities.CurrentData;
			CurrentLine.StartDate = Date(1, 1, 1);
		EndIf;
	Else
		CurrentLine = Items.Activities.CurrentData;
		CurrentLine.StartDate = Date(1, 1, 1);
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishDateOnChangeWriteDoc(Result, AdditionalParameters) Export
	
	CurrentData = Items.Activities.CurrentData;
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Not Write(WriteParameters) Then
			CurrentData.FinishDate = Date(1, 1, 1);
		EndIf;
	Else
		CurrentData.FinishDate = Date(1, 1, 1);
	EndIf;
	
	CurrentData.Done = ValueIsFilled(CurrentData.FinishDate);
	CalculateActivitiesTotals();
	CheckToSetCompletedStatus();
	
EndProcedure


&AtClient
Procedure DoneOnChangeWriteDoc(Result, AdditionalParameters) Export
	
	CurrentData = Items.Activities.CurrentData;
	
	If Result = DialogReturnCode.OK Then
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Write(WriteParameters) Then
			FinishOperationFragment();
		Else
			CurrentData.Done = False;
			CurrentData.FinishDate = Date(1, 1, 1);
		EndIf;
	Else
		CurrentData.Done = False;
		CurrentData.FinishDate = Date(1, 1, 1);
	EndIf;
	
	CalculateActivitiesTotals();
	
EndProcedure

&AtClient
Procedure StartOperationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		StartOperationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure StartOperationFragment()
	
	CurrentDate = CurrentDateAtServer();
	
	ShowInputDate(
		New NotifyDescription("StartOperationFillInDate", ThisObject),
		CurrentDate,
		NStr("en = 'Start date and time'; ru = 'Дата и время начала выполнения';pl = 'Data i czas rozpoczęcia';es_ES = 'Fecha y hora de inicio';es_CO = 'Fecha y hora de inicio';tr = 'Başlangıç tarihi ve saati';it = 'Data e ora di inizio';de = 'Startdatum und -zeit'"),
		DateFractions.DateTime);
	
EndProcedure

&AtClient
Procedure StartOperationFillInDate(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CurrentDate = Result;
		
		If CurrentDate > Object.Date Then
			
			For Each SelectedID In Items.Activities.SelectedRows Do
				
				ActivityLine = Object.Activities.FindByID(SelectedID);
				ActivityLine.StartDate = CurrentDate;
				ActivityLine.FinishDate = Date(1,1,1);
				ActivityLine.Done = False;
				
			EndDo;
			
			CheckToSetInProgressStatus();
			
		Else
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The start date cannot be earlier than the document date. Edit the start date.'; ru = 'Дата начала не может быть раньше, чем дата документа. Измените дату начала.';pl = 'Data rozpoczęcia nie może być wcześniejsza niż data dokumentu. Edytuj datę rozpoczęcia.';es_ES = 'La fecha de inicio no puede ser anterior a la fecha del documento. Edite la fecha de inicio.';es_CO = 'La fecha de inicio no puede ser anterior a la fecha del documento. Edite la fecha de inicio.';tr = 'Başlangıç tarihi belge tarihinden önce olamaz. Başlangıç tarihini değiştirin.';it = 'La data di inizio non può essere precedente alla data del documento. Modificare la data di inizio.';de = 'Das Startdatum darf nicht vor dem Belegdatum liegen. Bearbeiten Sie das Startdatum.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FinishOperationFragment();
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationFragment()
	
	CurrentDate = RecommendedFinishDate();
	
	ShowInputDate(
		New NotifyDescription("FinishOperationFillInDate", ThisObject),
		CurrentDate,
		NStr("en = 'End date and time'; ru = 'Дата и время завершения';pl = 'Data i czas zakończenia';es_ES = 'Fecha y hora final';es_CO = 'Fecha y hora final';tr = 'Bitiş tarihi ve saati';it = 'Data e ora di fine';de = 'Enddatum und -zeit'"),
		DateFractions.DateTime);
	
EndProcedure

&AtClient
Procedure FinishOperationFillInDate(Result, AdditionalParameters) Export
	
	If ValueIsFilled(Result) Then
		
		CurrentDate = Result;
		
		If CurrentDate > Object.Date Then
			
			For Each SelectedID In Items.Activities.SelectedRows Do
				
				ActivityLine = Object.Activities.FindByID(SelectedID);
				ActivityLine.StartDate = ?(ValueIsFilled(ActivityLine.StartDate), ActivityLine.StartDate, CurrentDate);
				ActivityLine.FinishDate = CurrentDate;
				ActivityLine.Done = True;
				
			EndDo;
			
			CalculateActivitiesTotals();
			CheckToSetInProgressStatus();
			CheckToSetCompletedStatus();
			
		Else
			
			CommonClientServer.MessageToUser(
				NStr("en = 'The end date cannot be earlier than the document date. Edit the end date.'; ru = 'Дата окончания не может быть раньше, чем дата документа. Измените дату окончания.';pl = 'Data zakończenia nie może być wcześniejsza niż data dokumentu. Edytuj datę zakończenia.';es_ES = 'La fecha final no puede ser anterior a la fecha del documento. Edite la fecha final.';es_CO = 'La fecha final no puede ser anterior a la fecha del documento. Edite la fecha final.';tr = 'Bitiş tarihi belge tarihinden önce olamaz. Bitiş tarihini değiştirin.';it = 'La data di fine non può essere precedente alla data del documento. Modificare la data di fine.';de = 'Das Enddatum darf nicht vor dem Belegdatum liegen. Bearbeiten Sie das Enddatum.'"));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FinishOperationProManageEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FinishOperationsProManageAtServer();
		CalculateActivitiesTotals();
		CheckToSetInProgressStatus();
		CheckToSetCompletedStatus();
	EndIf;
	
EndProcedure

&AtServer
Procedure FinishOperationsProManageAtServer()
	
	ExchangeWithProManage.FinishOperationsProManage(Object);
	
EndProcedure

&AtClient
Procedure CheckToSetCompletedStatus()
	
	AllOperationsAreFinished = True;
	For Each ActivitiesLine In Object.Activities Do
		If Not ActivitiesLine.Done Then
			AllOperationsAreFinished = False;
			Break;
		EndIf;
	EndDo;
	
	If AllOperationsAreFinished Then
		ShowUserNotification(NStr("en = 'All operations are completed. The document status is automatically set to Completed.'; ru = 'Все операции завершены. Статус документа автоматически установлен на Завершен.';pl = 'Wszystkie działania są zakończone. Status dokumentu jest automatycznie ustawiany na Gotowe.';es_ES = 'Todas las operaciones han finalizado. El estado del documento se establece automáticamente en Finalizado.';es_CO = 'Todas las operaciones han finalizado. El estado del documento se establece automáticamente en Finalizado.';tr = 'Tüm işlemler tamamlandı. Belge durumu otomatik olarak Kapatıldı şeklinde değiştirildi.';it = 'Tutte le operazioni sono completate. Lo status del documento è impostato automaticamente su Completato.';de = 'Alle Operationen sind abgeschlossen. Der Dokumentstatus wird automatisch auf „Abgeschlossen“ gesetzt.'"));
		Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed");
		FormManagement();
		NeedRecalculation = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure CheckToSetInProgressStatus()
	
	If Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Open") Then
		
		SomeOperationsAreStarted = False;
		For Each ActivitiesLine In Object.Activities Do
			If ValueIsFilled(ActivitiesLine.StartDate) Then
				SomeOperationsAreStarted = True;
				Break;
			EndIf;
		EndDo;
		
		If SomeOperationsAreStarted Then
			ShowUserNotification(NStr("en = 'The document status is automatically set to In progress.'; ru = 'Статус документа автоматически установлен на ""В работе"".';pl = 'Status dokumentu jest automatycznie ustawiany na W toku.';es_ES = 'El estado del documento se establece automáticamente en En progreso.';es_CO = 'El estado del documento se establece automáticamente en En progreso.';tr = 'Belge durumu otomatik olarak İşlemde şeklinde ayarlandı.';it = 'Lo status del documento è impostato automaticamente su In corso.';de = 'Der Dokumentstatus wird automatisch auf In Bearbeitung gesetzt.'"));
			Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess");
			FormManagement();
			NeedRecalculation = True;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChangeEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		If Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess") Then
			
			CurrentDate = CurrentDateAtServer();
			
			If CurrentDate > Object.Date Then
				
				If Object.Activities.Count() Then
					
					FirstLineActivityNumber = Object.Activities[0].ActivityNumber;
					
					For Each ActivityLine In Object.Activities Do
						
						If Not ValueIsFilled(ActivityLine.StartDate) And ActivityLine.ActivityNumber = FirstLineActivityNumber Then
							ActivityLine.StartDate = CurrentDate;
							ActivityLine.FinishDate = Date(1,1,1);
							ActivityLine.Done = False;
						EndIf;
						
					EndDo;
					
				EndIf;
				
			Else
				
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot automatically set start dates for the operations. Specify them manually.'; ru = 'Не удается автоматически установить даты начала операций. Укажите их вручную.';pl = 'Nie można automatycznie ustawić dat rozpoczęcia dla operacji. Określ je ręcznie.';es_ES = 'No se pueden establecer automáticamente las fechas de inicio de las operaciones. Especifíquelas manualmente.';es_CO = 'No se pueden establecer automáticamente las fechas de inicio de las operaciones. Especifíquelas manualmente.';tr = 'İşlemler için başlangıç tarihleri otomatik olarak ayarlanamıyor. Tarihleri manuel olarak girin.';it = 'Impossibile impostare automaticamente le date di inizio per le operazioni. Specificarle manualmente.';de = 'Startdaten für die Operationen können nicht automatisch gesetzt werden. Geben Sie diese manuell an.'"));
				
			EndIf;
			
		ElsIf Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed") Then
			
			CurrentDate = RecommendedFinishDate();
			
			If CurrentDate > Object.Date Then
				
				For Each ActivityLine In Object.Activities Do
					
					If Not ValueIsFilled(ActivityLine.FinishDate) Then
						ActivityLine.StartDate = ?(ValueIsFilled(ActivityLine.StartDate), ActivityLine.StartDate, CurrentDate);
						ActivityLine.FinishDate = ?(ValueIsFilled(ActivityLine.FinishDate), ActivityLine.FinishDate, CurrentDate);
						ActivityLine.Done = True;
					EndIf;
					
				EndDo;
				
			Else
				
				Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess");
				CommonClientServer.MessageToUser(
					NStr("en = 'Cannot automatically set end dates for the operations. Specify them manually and try to complete the document again.'; ru = 'Не удается автоматически установить даты окончания операций. Укажите их вручную и попробуйте завершить документ еще раз.';pl = 'Nie można automatycznie ustawić dat zakończenia dla operacji. Określ je ręcznie i spróbuj zakończyć dokument ponownie.';es_ES = 'No se pueden establecer automáticamente las fechas finales de las operaciones. Especifíquelas manualmente e intente finalizar de nuevo el documento.';es_CO = 'No se pueden establecer automáticamente las fechas finales de las operaciones. Especifíquelas manualmente e intente finalizar de nuevo el documento.';tr = 'İşlemler için bitiş tarihleri otomatik olarak ayarlanamıyor. Tarihleri manuel olarak girin ve belgeyi tekrar tamamlamayı deneyin.';it = 'Impossibile impostare automaticamente le date di fine per le operazioni. Specificarle manualmente e provare a completare nuovamente il documento.';de = 'Enddaten für die Operationen können nicht automatisch gesetzt werden. Geben Sie sie manuell an und versuchen Sie erneut, das Dokument abzuschließen.'"));
					
			EndIf;
			
		EndIf;
		
	ElsIf Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed") Then
		
		Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess");
		
	EndIf;
	
	FormManagement();

EndProcedure

&AtServerNoContext
Function CurrentDateAtServer()
	
	Return CurrentSessionDate();
	
EndFunction

&AtServer
Function RecommendedFinishDate()
	
	RecommendedFinishDate = Date(1, 1, 1);
	
	For Each ActivityLine In Object.Activities Do
		
		If ActivityLine.Output And ValueIsFilled(ActivityLine.FinishDate) Then
			RecommendedFinishDate = ActivityLine.FinishDate;
			Break;
		EndIf;
		
	EndDo;
	
	If Not ValueIsFilled(RecommendedFinishDate) Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED TOP 1
		|	ManufacturingOperationActivities.FinishDate AS FinishDate
		|FROM
		|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.Ref <> &Ref
		|	AND ManufacturingOperation.CostObject = &CostObject
		|	AND ManufacturingOperationActivities.Output
		|	AND ManufacturingOperationActivities.FinishDate <> DATETIME(1, 1, 1)
		|	AND ManufacturingOperation.Quantity = &Quantity";
	
		Query.SetParameter("CostObject", Object.CostObject);
		Query.SetParameter("Ref", Object.Ref);
		Query.SetParameter("Quantity", Object.Quantity);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			RecommendedFinishDate = SelectionDetailRecords.FinishDate;
		EndIf;
	
	EndIf;
	
	If Not ValueIsFilled(RecommendedFinishDate) Then
		
		RecommendedFinishDate = CurrentSessionDate();
		
	EndIf;
	
	Return RecommendedFinishDate;
	
EndFunction

#EndRegion

&AtClient
Procedure StatusOnChangeWriteDoc(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ObjectStatus = Object.Status;
		Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
		WriteParameters = New Structure("WriteMode", DocumentWriteMode.Posting);
		If Write(WriteParameters) Then
			Object.Status = ObjectStatus;
			StatusOnChangeAtClient();
		Else
			Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
		EndIf;
	Else
		Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChangeAtClient()
	
	If Object.ProductionMethod = PredefinedValue("Enum.ProductionMethods.Subcontracting") Then
		StatusOnChangeEnd(DialogReturnCode.Yes, Undefined);	
	Else	
		If Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.InProcess") Then
			
			ThereAreEmptyStartDates = False;
			For Each ActivityLine In Object.Activities Do
				If Not ValueIsFilled(ActivityLine.StartDate) Then
					ThereAreEmptyStartDates = True;
					Break;
				EndIf;
			EndDo;
			
			If ThereAreEmptyStartDates Then
				
				ShowQueryBox(
					New NotifyDescription("StatusOnChangeEnd", ThisObject),
					NStr("en = 'Some operations are not started. Do you want to start them?'; ru = 'Некоторые операции не начаты. Вы хотите начать их?';pl = 'Niektóre operacje nie są rozpoczęte. Czy chcesz rozpocząć je?';es_ES = 'Algunas operaciones no se han iniciado. ¿Quiere iniciarlas?';es_CO = 'Algunas operaciones no se han iniciado. ¿Quiere iniciarlas?';tr = 'Bazı işlemler başlatılmadı. Bunları başlatmak ister misiniz?';it = 'Alcune operazioni non sono state avviate. Avviarle?';de = 'Einige Operationen sind nicht gestartet. Möchten Sie diese starten?'"),
					QuestionDialogMode.YesNo);
				
			EndIf;
			
		ElsIf Object.Status = PredefinedValue("Enum.ManufacturingOperationStatuses.Completed") Then
			
			ThereAreEmptyFinishDates = False;
			For Each ActivityLine In Object.Activities Do
				If Not ValueIsFilled(ActivityLine.FinishDate) Then
					ThereAreEmptyFinishDates = True;
					Break;
				EndIf;
			EndDo;
			
			If ThereAreEmptyFinishDates Then
				
				ShowQueryBox(
					New NotifyDescription("StatusOnChangeEnd", ThisObject),
					NStr("en = 'Some operations are not completed. If you continue, they will be automatically completed with end dates set to the current date. Do you want to continue?'; ru = 'Некоторые операции не завершены. Если продолжить, они будут автоматически завершены с конечными датами, установленными на текущую дату. Продолжить?';pl = 'Niektóre operacje nie są zakończone. Jeśli będziesz kontynuować, one zostaną zakończone z datami końcowymi, ustawionymi na bieżącą datę. Czy chcesz kontynuować?';es_ES = 'Algunas operaciones no han finalizado. Si continúa, finalizarán automáticamente con las fechas finales establecidas en la fecha actual. ¿Quiere continuar?';es_CO = 'Algunas operaciones no han finalizado. Si continúa, finalizarán automáticamente con las fechas finales establecidas en la fecha actual. ¿Quiere continuar?';tr = 'Bazı işlemler başlatılmadı. Devam ederseniz, bitiş tarihleri şimdiki tarih olarak ayarlanarak otomatik olarak tamamlanacaklar. Devam etmek istiyor musunuz?';it = 'Alcune operazioni non sono completate. Continuando, saranno completate automaticamente con le date di fine impostate alla data corrente. Continuare?';de = 'Einige Operationen sind nicht abgeschlossen. Wenn Sie fortfahren, werden sie automatisch mit Enddaten abgeschlossen, die auf das aktuelle Datum gesetzt sind. Möchten Sie fortfahren?'"),
					QuestionDialogMode.YesNo);
				
			EndIf;
			
		EndIf;
	EndIf;
	
	FormManagement();
	NeedRecalculation = True;
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChangeAtClient()
	
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Inventory.CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChangeAtClient()
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabRow.Products);
	StructureData.Insert("Batch", TabRow.Batch);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

#Region Batches

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	RowsToClear = RowsToClearOnFillingBatches(True);
	
	If RowsToClear.Count() Then
		
		AddParameters = New Structure;
		AddParameters.Insert("RowsToClear", RowsToClear);
		AddParameters.Insert("OnlySelectedRows", True);
		
		ShowQueryBox(New NotifyDescription("FillBatchesByFEFO_Continue", ThisObject, AddParameters),
			NStr("en = 'The ""Reserved"" column in the highlighted lines will be cleared. Do you want to continue?'; ru = 'Колонка ""Зарезервировано"" будет очищена в выделенных строках. Продолжить?';pl = 'Kolumna ""Zarezerwowano"" w wyróżnionych wierszach zostanie wyczyszczona. Czy chcesz kontynuować?';es_ES = 'La columna ""Reservado"" en las líneas destacadas se eliminará. ¿Quiere continuar?';es_CO = 'La columna ""Reservado"" en las líneas destacadas se eliminará. ¿Quiere continuar?';tr = 'Vurgulanan satırlardaki ""Rezerve"" sütunu temizlenecek. Devam etmek istiyor musunuz?';it = 'La colonna ""Riservato"" nelle righe evidenziate verrà cancellata. Desideri continuare?';de = 'Die Spalte ""Reserviert"" in den markierten Zeilen wird gelöscht. Möchten Sie fortfahren?'"),
			QuestionDialogMode.YesNo);
		
	Else
		
		Attachable_FillBatchesByFEFO_Selected_End();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
	RowsToClear = RowsToClearOnFillingBatches();
	
	If RowsToClear.Count() Then
		
		AddParameters = New Structure;
		AddParameters.Insert("RowsToClear", RowsToClear);
		AddParameters.Insert("OnlySelectedRows", False);
		
		ShowQueryBox(New NotifyDescription("FillBatchesByFEFO_Continue", ThisObject, AddParameters),
			NStr("en = 'The ""Reserved"" column will be cleared. Do you want to continue?'; ru = 'Колонка ""Зарезервировано"" будет очищена. Продолжить?';pl = 'Kolumn ""Zarezerwowano"" zostanie wyczyszczona. Czy chcesz kontynuować?';es_ES = 'La columna ""Reservado"" se eliminará. ¿Quiere continuar?';es_CO = 'La columna ""Reservado"" se eliminará. ¿Quiere continuar?';tr = '""Rezerve"" sütunu temizlenecek. Devam etmek istiyor musunuz?';it = 'La colonna ""Riservato"" verrà cancellata. Desideri continuare?';de = 'Die Spalte ""Reserviert"" wird gelöscht. Möchten Sie fortfahren?'"),
			QuestionDialogMode.YesNo);
		
	Else
		
		Attachable_FillBatchesByFEFO_All_End();
		
	EndIf;
	
EndProcedure

&AtServer
Function RowsToClearOnFillingBatches(OnlySelectedRows = False)
	
	RowsToClear = New Array;
	
	For Each InventoryLine In Object.Inventory Do
		
		If OnlySelectedRows Then
			If Items.Inventory.SelectedRows.Find(InventoryLine.GetID()) = Undefined Then
				Continue;
			EndIf;
		EndIf;
		
		If InventoryLine.Reserve > 0 And (Common.ObjectAttributeValue(InventoryLine.Products, "UseBatches") = True) Then
			
			RowsToClear.Add(InventoryLine.GetID());
			
		EndIf;
		
	EndDo;
	
	Return RowsToClear;
	
EndFunction

&AtClient
Procedure FillBatchesByFEFO_Continue(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		For Each RowIDToClear In AdditionalParameters.RowsToClear Do
			
			InventoryRow = Object.Inventory.Get(RowIDToClear);
			InventoryRow.Reserve = 0;
			
		EndDo;
		
		If AdditionalParameters.OnlySelectedRows = True Then
			
			Attachable_FillBatchesByFEFO_Selected_End();
			
		Else
			
			Attachable_FillBatchesByFEFO_All_End();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected_End()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All_End()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_All(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_BatchOnChange(TableName) Export
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_QuantityOnChange(TableName, RowData) Export
	
	InventoryQuantityOnChangeAtClient();
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	StructuralUnitInHeader = (Object.InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader);
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	Params.Insert("StructuralUnit",
		?(StructuralUnitInHeader, Object.InventoryStructuralUnit, Params.CurrentRow.InventoryStructuralUnit));
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	Params.Insert("Cell", 
		?(StructuralUnitInHeader, Object.CellInventory, Params.CurrentRow.CellInventory));
	Params.Insert("SalesOrder", Object.Ref);
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

#EndRegion

&AtClient
Procedure FormManagement()
	
	CompletedStatus		= PredefinedValue("Enum.ManufacturingOperationStatuses.Completed");
	OpenStatus			= PredefinedValue("Enum.ManufacturingOperationStatuses.Open");
	
	StatusIsComplete	= (Object.Status = CompletedStatus);
	SubcontractVisible	= (Object.ProductionMethod = PredefinedValue("Enum.ProductionMethods.Subcontracting"));
	
	Items.ActivitiesCommandBar.Enabled		= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled		= Not StatusIsComplete;
	Items.DisposalsCommandBar.Enabled		= Not StatusIsComplete;
	Items.LaborAssignmentCommandBar.Enabled	= Not StatusIsComplete;
	Items.FillInWithBOM.Enabled				= Not StatusIsComplete;
	Items.GroupLeft.ReadOnly				= StatusIsComplete;
	Items.RightColumn.ReadOnly				= StatusIsComplete;
	Items.TSActivities.ReadOnly				= StatusIsComplete;
	Items.TSInventory.ReadOnly				= StatusIsComplete;
	Items.TSDisposals.ReadOnly				= StatusIsComplete;
	Items.TSLaborAssignment.ReadOnly		= StatusIsComplete;
	Items.GroupAdditional.ReadOnly			= StatusIsComplete;
	Items.FormDocumentSetup.Enabled 		= Not StatusIsComplete;
	
	Items.ProductionMethod.ReadOnly = Not (Object.Status = OpenStatus);
	
	DriveClient.DocumentWIPGenerationVisibility(Items, SimulateCurrentData(), 
		New Structure("CompletedStatus, OpenStatus", CompletedStatus, OpenStatus));
		
	InventoryStructuralUnitInHeader = (Object.InventoryStructuralUnitPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	Items.InventoryStructuralUnit.Visible			= InventoryStructuralUnitInHeader;
	Items.InventoryInventoryStructuralUnit.Visible	= Not InventoryStructuralUnitInHeader;
	Items.CellInventory.Visible						= InventoryStructuralUnitInHeader;
	Items.InventoryCellInventory.Visible			= Not InventoryStructuralUnitInHeader;
	
	SetSubcontractingVisible();
	
EndProcedure

&AtServer
Procedure SetModeAndChoiceList()
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Items.Cell.Enabled = False;
	EndIf;
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		Items.DisposalsCell.Enabled = False;
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get()
		And Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.InventoryStructuralUnit.ListChoiceMode = True;
		Items.InventoryStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.InventoryStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.DisposalsStructuralUnit.ListChoiceMode = True;
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

&AtServer
Procedure FillInWithBOMAtServer()
	
	FillInActivitiesByBOMAtServer();
	FillByBillsOfMaterialsAtServer();
	FillInByProductsWithBOMAtServer();
	
EndProcedure

&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillTabularSectionBySpecification(Undefined, True);
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillInByProductsWithBOMAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillByProductsWithBOM(Undefined, True);
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

&AtServer
Procedure FillInActivitiesByBOMAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInActivitiesByBOM();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	False);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillComponentsByBOMOnActivitiesChange()
	
	If Object.Inventory.Count() > 0 Then
		ShowQueryBox(
			New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject),
			NStr("en = 'Do you want to refill the ""Components"" according to BOM?'; ru = 'Перезаполнить вкладку ""Сырье и материалы"" по спецификации?';pl = 'Czy chcesz ponownie wypełnić ""Komponenty"" zgodnie ze specyfikacją materiałową?';es_ES = '¿Quieres rellenar los ""Materiales"" según la lista de materiales?';es_CO = '¿Quieres rellenar los ""Materiales"" según la lista de materiales?';tr = '""Malzemeler"" ürün reçetesine göre yeniden doldurulsun mu?';it = 'Ricompilare ""Componenti"" in base alla Distinta Base?';de = 'Möchten Sie den ""Materialbestand"" entsprechend der Stückliste erneut auffüllen?'"),
			QuestionDialogMode.YesNo);
	EndIf;
	
EndProcedure

&AtServer
Function GetCompanyDataOnChange(Company)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataProductsOnChange(StructureData, FillGLAccounts = True, ObjectDate = Undefined)
	
	StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, Description");
	
	StructureData.Insert("MeasurementUnit", StuctureProduct.MeasurementUnit);
	StructureData.Insert("ProductDescription", StuctureProduct.Description);
	StructureData.Insert("Ownership", Catalogs.InventoryOwnership.EmptyRef());
	
	StructureData.Insert("ShowSpecificationMessage", False);
	
	If Not ObjectDate = Undefined Then
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			Catalogs.ProductsCharacteristics.EmptyRef(),
			Enums.OperationTypesProductionOrder.Production);
		StructureData.Insert("Specification", Specification);
		StructureData.Insert("ShowSpecificationMessage", True);
		
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting And FillGLAccounts Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ObjectDate = Undefined)
	
	StructureData.Insert("ShowSpecificationMessage", False);
		
	If Not ObjectDate = Undefined Then
		
		StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "Description");
		
		SpecificationWithCharacteristic = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			ObjectDate, 
			StructureData.Characteristic,
			Enums.OperationTypesProductionOrder.Production);
		StructureData.Insert("Specification", SpecificationWithCharacteristic);
		StructureData.Insert("ShowSpecificationMessage", True);
		StructureData.Insert("ProductDescription", StuctureProduct.Description);
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts",	True);
		ParametersStructure.Insert("FillInventory",	True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	
	DepartmentData = Common.ObjectAttributesValues(
		StructureData.Department,
		"TransferSource,
		|TransferSourceCell,
		|RecipientOfWastes,
		|DisposalsRecipientCell");
	
	StructureData.Insert("InventoryStructuralUnit", DepartmentData.TransferSource);
	StructureData.Insert("CellInventory", DepartmentData.TransferSourceCell);
	
	StructureData.Insert("DisposalsStructuralUnit", DepartmentData.RecipientOfWastes);
	StructureData.Insert("DisposalsCell", DepartmentData.DisposalsRecipientCell);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetDataCellOnChange(StructureData)
	
	StructuralUnitData = Common.ObjectAttributesValues(
		StructureData.StructuralUnit,
		"TransferSource,
		|TransferSourceCell,
		|RecipientOfWastes,
		|DisposalsRecipientCell");
	
	If StructureData.StructuralUnit = StructureData.InventoryStructuralUnit
		And (StructuralUnitData.TransferSource <> StructureData.InventoryStructuralUnit
			Or StructuralUnitData.TransferSourceCell <> StructureData.CellInventory) Then
		StructureData.Insert("NewCellInventory", StructureData.Cell);
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.DisposalsStructuralUnit
		And (StructuralUnitData.RecipientOfWastes <> StructureData.DisposalsStructuralUnit
			Or StructuralUnitData.DisposalsRecipientCell <> StructureData.DisposalsCell) Then
		StructureData.Insert("NewCellWastes", StructureData.Cell);
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	CommandToFillBySpecificationFragment();
	
EndProcedure

&AtClient
Procedure FillInWithBOMEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInWithBOMFragment();
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOMEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInByProductsWithBOMFragment();
	
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
	
	FillByBillsOfMaterialsAtServer();
	FillAddedColumnActivity(Object);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillInWithBOMFragment()
	
	FillInWithBOMAtServer();
	FillActivitiesValueList();
	FillAddedColumnActivity(Object);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillInByProductsWithBOMFragment()
	
	FillInByProductsWithBOMAtServer();
	FillAddedColumnActivity(Object);
	Modified = True;
	
EndProcedure

&AtClient
Procedure FillInActivitiesByBOMEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInActivitiesByBOMFragment(AdditionalParameters);
	
EndProcedure

&AtClient
Procedure FillInActivitiesByBOMFragment(ActivityFilter)
	
	For Each ActivityLine In Object.Activities Do
		
		DeleteConnectedComponents(ActivityLine.ConnectionKey);
		
	EndDo;
	
	FillInActivitiesByBOMAtServer();
	Modified = True;
	FillActivitiesValueList();
	
EndProcedure

&AtClient
Function CheckBOMFilling(ForComponents = False)
	
	If Not ValueIsFilled(Object.Specification) Then
		
		MessageText = NStr("en = 'Bill of materials is required.'; ru = 'Укажите спецификацию.';pl = 'Wymagana jest specyfikacja materiałowa.';es_ES = 'Se requiere una Lista de materiales.';es_CO = 'Se requiere una Lista de materiales.';tr = 'Ürün reçetesi gerekli.';it = 'È richiesta la Distinta base.';de = 'Stückliste ist ein Pflichtfeld.'");
		CommonClientServer.MessageToUser(MessageText);
		Return False;
		
	ElsIf ForComponents And Object.Activities.Count() = 0 Then
		
		If GetUseRouting(Object.Specification) Then
			
			MessageText = NStr("en = 'Cannot populate components from BOM. Specify operations in the document and try again.'; ru = 'Не удалось заполнить компоненты из спецификации. Укажите операции в документе и повторите попытку.';pl = 'Nie można wypełnić komponentów ze specyfikacji materiałowej. Określ operacje w dokumencie i spróbuj ponownie.';es_ES = 'No se pueden rellenar los componentes desde el BOM. Especifique las operaciones en el documento y vuelva a intentarlo.';es_CO = 'No se pueden rellenar los componentes desde el BOM. Especifique las operaciones en el documento y vuelva a intentarlo.';tr = 'Malzemeler ürün reçetesinden doldurulamıyor. Belgede işlemleri belirtip tekrar deneyin.';it = 'Impossibile compilare le componenti dalla Distinta base. Specificare le operazioni nel documento e riprovare.';de = 'Kann Komponenten aus Stückliste nicht auffüllen. Geben Sie Operationen im Dokument ein und versuchen Sie erneut.'");
			CommonClientServer.MessageToUser(MessageText);
			Return False;
			
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function GetUseRouting(BillsOfMaterials)
	
	Return Common.ObjectAttributeValue(BillsOfMaterials, "UseRouting");
	
EndFunction

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
	
	CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
	
	If Not IsBlankString(CurBarcode) Then
		BarcodesReceived(New Structure("Barcode, Quantity", TrimAll(CurBarcode), 1));
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

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") And Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

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
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "ManufacturingOperation");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData,, StructureData.Object.Date));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
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
	StructureData.Insert("Object", Object);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	GetDataByBarCodes(StructureData);
	
	TableName = "Inventory";
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined And BarcodeData.Count() = 0 Then
			
			UnknownBarcodes.Add(CurBarcode);
			
		Else
			
			SearchStructure = New Structure;
			SearchStructure.Insert("Products", BarcodeData.Products);
			SearchStructure.Insert("Characteristic", BarcodeData.Characteristic);
			SearchStructure.Insert("Batch", BarcodeData.Batch);
			SearchStructure.Insert("MeasurementUnit", BarcodeData.MeasurementUnit);
			
			TSRowsArray = Object[TableName].FindRows(SearchStructure);
			If TSRowsArray.Count() = 0 Then
				NewRow = Object[TableName].Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				If ValueIsFilled(BarcodeData.MeasurementUnit) Then
					NewRow.MeasurementUnit = BarcodeData.MeasurementUnit;
				Else
					NewRow.MeasurementUnit = BarcodeData.StructureProductsData.MeasurementUnit;
				EndIf;
				Items[TableName].CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items[TableName].CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber")
				And ValueIsFilled(BarcodeData.SerialNumber)
				And TableName = "Inventory" Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
			
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisObject, UnknownBarcodes);
		
		OpenForm("InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisObject, , , , Notification);
		
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
		
		MessageString = NStr("en = 'Barcode data is not found: %1; quantity: %2'; ru = 'Данные по штрихкоду не найдены: %1; количество: %2';pl = 'Nie znaleziono danych kodu kreskowego: %1; ilość: %2';es_ES = 'Datos del código de barras no encontrados: %1; cantidad: %2';es_CO = 'Datos del código de barras no encontrados: %1; cantidad: %2';tr = 'Barkod verisi bulunamadı: %1; miktar: %2';it = 'Dati del codice a barre non trovati: %1; quantità: %2';de = 'Barcode-Daten wurden nicht gefunden: %1; Menge: %2'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(
			MessageString,
			CurUndefinedBarcode.Barcode,
			CurUndefinedBarcode.Quantity);
		CommonClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OpenSerialNumbersSelection(NameTSInventory, TSNameSerialNumbers)
	
	CurrentData = Items[NameTSInventory].CurrentData;
	
	CurrentDataIdentifier = CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(
		CurrentDataIdentifier, NameTSInventory, TSNameSerialNumbers);
		
	// Using field InventoryStructuralUnit for SN selection
	StructuralUnitInHeader = (Object.InventoryStructuralUnitPosition = PredefinedValue("Enum.AttributeStationing.InHeader"));
	ParametersOfSerialNumbers.Insert("StructuralUnit",
		?(StructuralUnitInHeader, Object.InventoryStructuralUnit, CurrentData.InventoryStructuralUnit));
	ParametersOfSerialNumbers.Insert("Cell",
		?(StructuralUnitInHeader, Object.CellInventory, CurrentData.CellInventory));
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtClient
Procedure SubcontractionOrdersSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.SubcontractorOrdersIssued.CurrentData;
	
	If CurrentData <> Undefined Then
		
		FormParameters = New Structure;
		FormParameters.Insert("Key", CurrentData.SubcontractorOrderIssued);
		
		OpenForm("Document.SubcontractorOrderIssued.ObjectForm", FormParameters, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Function GetSerialNumbersInventoryFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Inventory");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(
		Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier, TSName, TSNameSerialNumbers)
	
	If TSName = "Inventory" Then
		PickMode = True;
	Else
		PickMode = False;
	EndIf;
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(
		Object, ThisObject.UUID, CurrentDataIdentifier, PickMode, TSName, TSNameSerialNumbers);
	
EndFunction

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("Object", Form.Object);
	StructureData.Insert("Batch", TabRow.Batch);
	StructureData.Insert("Ownership", TabRow.Ownership);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts", TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled", TabRow.GLAccountsFilled);
		
		StructureData.Insert("ConsumptionGLAccount", TabRow.ConsumptionGLAccount);
		StructureData.Insert("InventoryGLAccount", TabRow.InventoryGLAccount);
		StructureData.Insert("InventoryReceivedGLAccount", TabRow.InventoryReceivedGLAccount);
		
		If StructureData.TabName = "Inventory" Then
			StructureData.Insert("InventoryReceivedGLAccount", TabRow.InventoryReceivedGLAccount);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(ParametersStructure)

	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	
	StructureArray = New Array();
	
	If ParametersStructure.FillInventory Then
		
		StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
		
		StructureData.Insert("OwnershipType", OwnershipType);
		
		StructureArray.Add(StructureData);
		
	EndIf;
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, ParametersStructure.GetGLAccounts);
	
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

&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then 
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If Object.Activities.Count() = 1 Then
			UniqueActivity = Object.Activities[0];
			NewRow.ActivityAlias = ActivityDescription(UniqueActivity.LineNumber, UniqueActivity.Activity);
			NewRow.ActivityConnectionKey = UniqueActivity.ConnectionKey;
		EndIf;
		
		If UseDefaultTypeOfAccounting And TabularSectionName <> "Disposals" Then
			GLAccountsInDocuments.FillGLAccountsInRow(ObjectParameters, NewRow, TabularSectionName);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, SelectionMarker, True, True);
			
			Modified = True;
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetActivityDataOnChange(Activity, ObjectData)
	
	Result = New Structure;
	
	If Not GetActivityDataFromSpecification(Result, Activity, ObjectData) Then
		
		Result.Insert("Quantity", 1);
		
		ActivityAttributes = Common.ObjectAttributesValues(Activity, "StandardWorkload, StandardTimeInUOM, TimeUOM, StandardTime");
		
		Result.Insert("StandardWorkload", ActivityAttributes.StandardWorkload);
		Result.Insert("StandardTimeInUOM", ActivityAttributes.StandardTimeInUOM);
		Result.Insert("TimeUOM", ActivityAttributes.TimeUOM);
		Result.Insert("StandardTime", ActivityAttributes.StandardTime);
		
	EndIf;
	
	Rate = InformationRegisters.PredeterminedOverheadRates.GetActivityOverheadRate(
		Activity, ObjectData.Date, ObjectData.Company, ObjectData.StructuralUnit);
	Result.Insert("Rate", Rate);
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetActivityDataFromSpecification(Result, Activity, ObjectData)
	
	If Not ValueIsFilled(ObjectData.Specification) Then
		Return False;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BillsOfMaterials.Ref AS Ref,
	|	CASE
	|		WHEN BillsOfMaterials.Quantity = 0
	|			THEN 1
	|		ELSE BillsOfMaterials.Quantity
	|	END AS Quantity
	|INTO TT_BillsOfMaterials
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|WHERE
	|	BillsOfMaterials.Ref = &Specification
	|	AND BillsOfMaterials.UseRouting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	&Quantity * ISNULL(CatalogUOM.Factor, 1) * BillsOfMaterialsOperations.Quantity / TT_BillsOfMaterials.Quantity AS Quantity,
	|	BillsOfMaterialsOperations.Workload AS Workload,
	|	BillsOfMaterialsOperations.TimeUOM AS TimeUOM,
	|	BillsOfMaterialsOperations.StandardTimeInUOM AS StandardTimeInUOM,
	|	BillsOfMaterialsOperations.StandardTime AS StandardTime
	|FROM
	|	TT_BillsOfMaterials AS TT_BillsOfMaterials
	|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON TT_BillsOfMaterials.Ref = BillsOfMaterialsOperations.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (CatalogUOM.Ref = &MeasurementUnit)
	|WHERE
	|	BillsOfMaterialsOperations.Activity = &Activity
	|
	|ORDER BY
	|	BillsOfMaterialsOperations.ActivityNumber,
	|	BillsOfMaterialsOperations.LineNumber";
	
	Query.SetParameter("Specification", ObjectData.Specification);
	Query.SetParameter("Activity", Activity);
	If ObjectData.Quantity = 0 Then
		Query.SetParameter("Quantity", 1);
	Else
		Query.SetParameter("Quantity", ObjectData.Quantity);
	EndIf;
	Query.SetParameter("MeasurementUnit", ObjectData.MeasurementUnit);
	
	Sel = Query.Execute().Select();
	If Sel.Next() Then
		
		Result.Insert("Quantity", Sel.Quantity);
		Result.Insert("StandardWorkload", Sel.Workload);
		Result.Insert("TimeUOM", Sel.TimeUOM);
		Result.Insert("StandardTimeInUOM", Sel.StandardTimeInUOM);
		Result.Insert("StandardTime", Sel.StandardTime);
		Return True;
		
	Else
		
		Return False;
		
	EndIf;
	
EndFunction

&AtClient
Procedure CalculateActivityTotalAndActualWorkload(RowData)
	
	If EditActualWorkloadInManufacturingOperation Then
		RowData.ActualWorkload = RowData.Quantity * RowData.StandardWorkload;
	EndIf;
	RowData.Total = RowData.ActualWorkload * RowData.Rate;
	
	CalculateActivitiesTotals();
	
EndProcedure

&AtClient
Procedure CalculateActivitiesTotals()
	
	ActivitiesTotalTotal = 0;
	ActivitiesTotalActualWorkload = 0;
	For Each ActivitiesRow In Object.Activities Do
		If ActivitiesRow.Done Then
			ActivitiesTotalTotal = ActivitiesTotalTotal + ActivitiesRow.Total;
			ActivitiesTotalActualWorkload = ActivitiesTotalActualWorkload + ActivitiesRow.ActualWorkload;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure FillInByTeamsEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.No Then
		Return;
	EndIf;
	
	FillInByTeamsFragment();
	
EndProcedure

&AtClient
Procedure FillInByTeamsFragment()
	
	OpenParameters = New Structure;
	OpenParameters.Insert("MultiselectList", True);
	
	OpenForm("Catalog.Teams.ChoiceForm", OpenParameters, , , , ,
		New NotifyDescription("FillInByTeamsChoiceEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure FillInByTeamsChoiceEnd(Result, AdditionalParameters) Export
	
	If Result = Undefined Then
		Return;
	EndIf;
	
	Object.LaborAssignment.Clear();
	
	FillInByTeamsAtServer(Result);
	
EndProcedure

&AtServer
Procedure FillInByTeamsAtServer(ArrayOfTeams)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkgroupsContent.Employee AS Employee,
	|	EmployeesSliceLast.Position AS Position,
	|	CASE
	|		WHEN WorkgroupsContent.LPR = 0
	|			THEN 1
	|		ELSE WorkgroupsContent.LPR
	|	END AS LPR,
	|	VALUE(Catalog.PayCodes.Work) AS PayCode
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.Employees.SliceLast(&ToDate, Company = &Company) AS EmployeesSliceLast
	|		ON WorkgroupsContent.Employee = EmployeesSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)";
	
	Query.SetParameter("ToDate", Object.Date);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	
	Object.LaborAssignment.Load(Query.Execute().Unload());
	
EndProcedure

&AtServer
Function CheckActivitiesOnComplitedStatus()
	
	Result = False;
	
	For Each LineOfActivity In Object.Activities Do
		
		If Not LineOfActivity.Done
			Or Not ValueIsFilled(LineOfActivity.StartDate)
			Or Not ValueIsFilled(LineOfActivity.FinishDate) Then
			
			Result = True;
			Break;
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function CheckСompletionSubcontractorOrder(DocumentRef)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SubcontractorOrderIssued.Ref AS Ref
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.BasisDocument = &Ref
	|	AND SubcontractorOrderIssued.OrderState <> &Completed
	|	AND SubcontractorOrderIssued.Posted";
	
	Query.SetParameter("Ref", 		DocumentRef);
	Query.SetParameter("Completed", DriveReUse.GetOrderStatus("SubcontractorOrderIssuedStatuses", "Completed"));
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

&AtServer
Function CheckСompletionSubcontractingWIP()

	Query = New Query;
	Query.SetParameter("Ref", Object.Ref);
	Query.SetParameter("Quantity", Object.Quantity);
	Query.SetParameter("Products", Object.Products);
	Query.SetParameter("Characteristic", Object.Characteristic);
	
	Query.Text =
	"SELECT
	|	&Ref AS Ref,
	|	&Quantity AS Quantity,
	|	&Products AS Products,
	|	&Characteristic AS Characteristic
	|INTO DocumentHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderIssued.Ref AS Ref
	|INTO SubcontractorOrderChildren
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|		ON DocumentHeader.Ref = SubcontractorOrderIssued.BasisDocument
	|WHERE
	|	SubcontractorOrderIssued.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Products AS Products,
	|	DocumentHeader.Characteristic AS Characteristic,
	|	DocumentHeader.Quantity AS QuantityBalance
	|INTO OrdersBalancePre
	|FROM
	|	DocumentHeader AS DocumentHeader
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorOrders.Products,
	|	SubcontractorOrders.Characteristic,
	|	-SubcontractorOrders.Quantity
	|FROM
	|	SubcontractorOrderChildren AS SubcontractorOrderChildren
	|		INNER JOIN AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrders
	|		ON SubcontractorOrderChildren.Ref = SubcontractorOrders.SubcontractorOrder
	|WHERE
	|	SubcontractorOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	OrdersBalancePre AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0";
		
	QueryResult = Query.Execute();
		
	Return Not QueryResult.IsEmpty();

EndFunction

&AtServerNoContext
Function TextErrorСompletionSubcontractingWIP(Status)
	
	TemplateMessage = NStr("en = 'Cannot change the lifecycle status to %1.
		|Product quantity in this Work-in-progress does not match the total product quantity in the related ""Subcontractor orders issued"".
		|Do either of the following:
		|- From this Work-in-progress, generate a ""Subcontractor order issued"" for the product quantity variance, set the order lifecycle status to In progress, and save the order.
		|- For all ""Subcontractor orders issued"" related to this Work-in-progress, set the lifecycle status to In progress.
		|Then try again to change the Work-in-progress lifecycle status.'; 
		|ru = 'Не удалось изменить статус документа на %1.
		|Количество номенклатуры в документе ""Незавершенное производство"" не соответствует общему количеству номенклатуры в связанных выданных заказах на переработку.
		|Выполните одно из следующих действий:
		|- На основании этого ""Незавершенного производства"" создайте выданный заказ на переработку оставшегося количества номенклатуры, установите статус заказа на ""В работе"" и сохраните заказ.
		|- Для всех выданных заказов на переработку, связанных с этим ""Незавершенным производством"", установите статус ""В работе"".
		|Затем попробуйте изменить статус ""Незавершенного производства"".';
		|pl = 'Nie można zmienić statusu dokumentu na %1.
		|Ilość produktu w Pracy w toku nie jest zgodna z ilością w powiązanym ""Wydanym zamówieniu wykonawcy"".
		|Wykonaj jedną z następujących czynności:
		|- Z tej Pracy w toku, wygeneruj ""Wydane zamówienie wykonawcy"" dla odchylenia ilości produktu, ustaw status dokumentu zamówienia na W toku, i zapisz zamówienie.
		|- Dla wszystkich ""Wydanych zamówień wykonawcy"" powizązanycch z tą Pracą w toku, ustaw status dokumentu na W toku.
		|Następnie spróbuj ponownie, aby zmienić status dokumentu Praca w toku.';
		|es_ES = 'No se puede cambiar el estado del ciclo de vida a %1.
		|La cantidad de producto en este Trabajo en progreso no coincide con la cantidad total de producto en los ""Pedidos de subcontratistas emitidos"" relacionados.
		|Haga lo siguiente:
		|-De este Trabajo en progreso, genere un ""Pedido de subcontratista emitido"" para la desviación de la cantidad de producto, establezca el estado del ciclo de vida del pedido como En curso y guarde el pedido. 
		|-Para todos los ""Pedidos de subcontratistas emitidos"" relacionados con este trabajo en ptogreso, establezca el estado del ciclo de vida como En curso.
		|A continuación, intente de nuevo cambiar el estado del ciclo de vida de Trabajo en progreso.';
		|es_CO = 'No se puede cambiar el estado del ciclo de vida a %1.
		|La cantidad de producto en este Trabajo en progreso no coincide con la cantidad total de producto en los ""Pedidos de subcontratistas emitidos"" relacionados.
		|Haga lo siguiente:
		|-De este Trabajo en progreso, genere un ""Pedido de subcontratista emitido"" para la desviación de la cantidad de producto, establezca el estado del ciclo de vida del pedido como En curso y guarde el pedido. 
		|-Para todos los ""Pedidos de subcontratistas emitidos"" relacionados con este trabajo en ptogreso, establezca el estado del ciclo de vida como En curso.
		|A continuación, intente de nuevo cambiar el estado del ciclo de vida de Trabajo en progreso.';
		|tr = 'Yaşam döngüsü durumu %1 olarak değiştirilemiyor.
		|Bu İşlem bitişindeki ürün miktarı ilgili ""Düzenlenen alt yüklenici siparişleri""ndeki toplam ürün miktarıyla uyuşmuyor.
		|Şunlardan birini yapın:
		|- Ürün miktarı farkı için bu İşlem bitişinden bir ""Düzenlenen alt yüklenici siparişi"" oluşturun, yaşam döngüsü durumunu İşlemde olarak ayarlayın ve siparişi kaydedin.
		|- Bu İşlem bitişiyle bağlantılı tüm ""Düzenlenen alt yüklenici siparişleri"" için yaşam döngüsü durumunu İşlemde olarak ayarlayın.
		|Ardından, tekrar İşlem bitişinin yaşam döngüsü durumunu değiştirmeyi deneyin.';
		|it = 'Impossibile modificare lo stato del ciclo di vita in %1.
		|la quantità di articoli in questo Lavoro in corso non corrisponde alla quantità totale di articoli nel relativo ""Ordini subfornitura emessi"".
		|Eseguire una delle seguenti azioni:
		|- Creare da questo Lavoro in corso un ""Ordine subfornitura emesso"" per la variazione di quantità di articoli, impostare lo stato del ciclo di vita dell''ordine su ""In lavorazione"" e salvare l''ordine.
		|- Per tutti gli ""ordini subfornitura emessi"" relativi a questo Lavoro in corso, impostare lo stato del ciclo di vita su In lavorazione,
		|poi riprovare a modificare lo stato del ciclo di vita del Lavoro in corso.';
		|de = 'Fehler beim Ändern des Status von Lebenszyklus auf %1.
		|Produktmenge in dieser Arbeit in Bearbeitung stimmt mit der Gesamtproduktmenge im verbundenen ""Subunternehmerauftrag ausgestellt"" nicht überein.
		|Führen Sie einen der folgenden Schritte durch:
		|- Aus der Arbeit in Bearbeitung generieren Sie einen ""Subunternehmerauftrag ausgestellt"" für die Abweichung der Produktmenge, setzten Sie den Status von Lebenszyklus auf In Bearbeitung fest und speichern den Auftrag.
		|- Für alle ""Subunternehmeraufträge ausgestellt"", verbunden mit dieser Arbeit in Bearbeitung, setzten Sie den Status von Lebenszyklus aus In Bearbeitung.
		|Dann versuchen Sie den Status von Lebenszyklus der Arbeit in Bearbeitung erneut zu ändern.'");
	
	ResultMessage = StringFunctionsClientServer.SubstituteParametersToString(TemplateMessage, Status);
	
	Return ResultMessage;
	
EndFunction

&AtServer
Function FillUseProductionPlanning()
	
	KeyValues = New Structure;
	KeyValues.Insert("ProductionOrder", Object.BasisDocument);
	ProductionScheduleRecordKey = InformationRegisters.ProductionSchedule.CreateRecordKey(KeyValues);
	
	UseProductionPlanning =
		((Common.ObjectAttributeValue(Object.BasisDocument, "UseProductionPlanning") = True)
		And GetFunctionalOption("UseProductionPlanning")
		And AccessManagement.ReadingAllowed(ProductionScheduleRecordKey));
		
	FillDetaultInventoryOwnershipType();
	
	SetByProductsTabVisible();
	
EndFunction

&AtServer
Procedure SetGroupScheduled(FirstLaunch = False)
	
	WorkcentersSchedule.Parameters.SetParameterValue("Ref", Object.Ref);
	NoWCTSchedule.Parameters.SetParameterValue("Ref", Object.Ref);
	NoWCTSchedule.Parameters.SetParameterValue("StringNoWCT", NStr("en = '<no work center type>'; ru = '<без типа рабочего центра>';pl = '<brak gniazda produkcyjnego>';es_ES = '<sin tipo de centro de trabajo>';es_CO = '<no work center type>';tr = '<iş merkezi türü yok>';it = '<nessun tipo di centro di lavoro>';de = '<kein Typ des Arbeitsabschnitts>'"));
	
	Items.GroupScheduled.Visible = False;
	Items.DecorationNotScheduled.Visible = False;
	
	If UseProductionPlanning Then
		
		Scheduled = True;
		
		If Object.Activities.Count() = 0 Then
			
			Scheduled = False;
			
		Else
			
			If FirstLaunch Then
				
				Activity = Object.Activities[0].Activity;
				WCTTable = Common.ObjectAttributeValue(Activity, "WorkCenterTypes");
				
				NoWCT = WCTTable.IsEmpty();
				
				Items.WorkcentersSchedule.Visible = Not NoWCT;
				Items.NoWCTSchedule.Visible = NoWCT;
				
			EndIf;
			
			Query = New Query;
			Query.Text = 
			"SELECT ALLOWED
			|	ProductionSchedule.StartDate AS StartDate,
			|	ProductionSchedule.EndDate AS EndDate
			|FROM
			|	InformationRegister.ProductionSchedule AS ProductionSchedule
			|WHERE
			|	ProductionSchedule.Operation = &Operation
			|	AND ProductionSchedule.ScheduleState = 0";
			
			Query.SetParameter("Operation", Object.Ref);
			
			QueryResult = Query.Execute();
			
			Scheduled = Not QueryResult.IsEmpty();
			
		EndIf;
		
		Items.GroupScheduled.Visible = Scheduled;
		Items.DecorationNotScheduled.Visible = Not Scheduled;
		
		Items.WorkcentersSchedule.Refresh();
		Items.NoWCTSchedule.Refresh();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillDetaultInventoryOwnershipType()
	
	SalesOrder = Common.ObjectAttributeValue(Object.BasisDocument, "SalesOrder");
	If TypeOf(SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived") Then
		OwnershipType = Enums.InventoryOwnershipTypes.CustomerProvidedInventory;
	Else
		OwnershipType = Enums.InventoryOwnershipTypes.OwnInventory;
	EndIf;
	
EndProcedure

&AtServer
Procedure SetByProductsTabVisible()
	
	If GetFunctionalOption("CanProvideSubcontractingServices") Then
		
		SalesOrder = Common.ObjectAttributeValue(Object.BasisDocument, "SalesOrder");
		SubcontractingServices = (TypeOf(SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived"));
		
		If SubcontractingServices Then
			Items.TSDisposals.Visible = False;
			Object.Disposals.Clear();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure SetSubcontractingVisible()
	
	If GetFunctionalOptionCanReceiveSubcontractingServices() Then
		
		SubcontractVisible = Not (Object.ProductionMethod = PredefinedValue("Enum.ProductionMethods.Subcontracting"));
		
		If Object.ReleaseRequired Then
			Items.ProductionMethod.ReadOnly = True;
			Return;
		EndIf;
		
		Items.ActivitiesStartDate.Visible		= SubcontractVisible;
		Items.ActivitiesFinishDate.Visible		= SubcontractVisible;
		Items.ActivitiesActualWorkload.Visible	= SubcontractVisible;
		Items.ActivitiesRate.Visible			= SubcontractVisible;
		Items.ActivitiesTotal.Visible			= SubcontractVisible;
		Items.TSInventory.Visible  				= SubcontractVisible;

	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetFunctionalOptionCanReceiveSubcontractingServices()
	
	Return GetFunctionalOption("CanReceiveSubcontractingServices");
	
EndFunction

&AtServer
Procedure SetGroupSubcontractorOrders()

	Query = New Query;
	Query.Text =
	"SELECT
	|	SubcontractorOrderIssued.Ref AS SubcontractorOrderIssued,
	|	SubcontractorOrderIssued.OrderState AS State
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.BasisDocument = &Ref
	|	AND SubcontractorOrderIssued.Posted
	|
	|ORDER BY
	|	Ref";
	
	Query.SetParameter("Ref", Object.Ref);

	TableSubcontractionOrders.Load(Query.Execute().Unload());
	NumberRowsTable = TableSubcontractionOrders.Count();
	
	Items.GroupSubcontractorOrderIssued.Visible = (NumberRowsTable <> 0);
	Items.LabelFieldSubcontractorOrderIssued.Visible = (NumberRowsTable = 1);
	Items.GroupSubcontractorOrderIssuedList.Visible = (NumberRowsTable <> 1);

	TextOrder = "";
	If NumberRowsTable = 1 Then
		
		ArrayStrings = New Array;
		RefOrder = TableSubcontractionOrders[0].SubcontractorOrderIssued;
		
		TextOrder = Nstr("en = '"+String(RefOrder)+"'");

		RefOrder = GetURL(RefOrder);
		ArrayStrings.Add(New FormattedString(TextOrder,,,, RefOrder));
		
		TextOrder = New FormattedString(ArrayStrings); 
	EndIf;
	
	LabelFieldSubcontractorOrderIssued = New FormattedString(TextOrder);
	
EndProcedure

&AtServer
Function SimulateCurrentData()
	
	StructureData = New Structure("Posted, ProductionMethod, Status, ProductionOrderBasisDocument");
	FillPropertyValues(StructureData, Object);
	StructureData.ProductionOrderBasisDocument = Object.BasisDocument.BasisDocument;
	
	Return New Structure("CurrentData", StructureData);
	
EndFunction

#Region ActivitiesConnectionKey

&AtServer
Function NewConnectionKey()
	
	Return DriveServer.CreateNewLinkKey(ThisObject);
	
EndFunction

&AtClient
Procedure DeleteConnectedComponents(ConnectionKey)
	
	Filter = New Structure("ActivityConnectionKey", ConnectionKey);
	RowsToDelete = Object.Inventory.FindRows(Filter);
	
	For Each RowToDelete In RowsToDelete Do
		Object.Inventory.Delete(RowToDelete);
	EndDo;
	
EndProcedure

&AtClient
Procedure FillActivitiesValueList()
	
	If Object.Activities.Count() < 2 Then
		
		Items.InventoryActivity.Visible = False;
		Items.DisposalsActivityAlias.Visible = False;
		
	Else
		
		Items.InventoryActivity.Visible = True;
		Items.DisposalsActivityAlias.Visible = True;
		ActivitiesValueList.Clear();
		
		For Each ActivityLine In Object.Activities Do
			
			ActivitiesValueList.Add(
				ActivityLine.GetID(),
				ActivityDescription(ActivityLine.LineNumber, ActivityLine.Activity));
			
		EndDo;
		
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure FillAddedColumnActivity(Object, ActivityConnectionKey = 0)
	
	For Each ActivitiesLine In Object.Activities Do
		
		If ActivityConnectionKey = 0 Or ActivitiesLine.ConnectionKey = ActivityConnectionKey Then
			
			If ActivitiesLine.ConnectionKey <> 0 Then
				
				Filter = New Structure("ActivityConnectionKey", ActivitiesLine.ConnectionKey);
				InventoryLines = Object.Inventory.FindRows(Filter);
				
				For Each InventoryLine In InventoryLines Do
					
					InventoryLine.ActivityAlias = ActivityDescription(ActivitiesLine.LineNumber, ActivitiesLine.Activity);
					
				EndDo;
				
				ByProductsLines = Object.Disposals.FindRows(Filter);
				
				For Each ByProductsLine In ByProductsLines Do
					
					ByProductsLine.ActivityAlias = ActivityDescription(ActivitiesLine.LineNumber, ActivitiesLine.Activity);
					
				EndDo;
				
				If ActivityConnectionKey > 0 Then
					
					Break;
					
				EndIf;
			
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClientAtServerNoContext
Function ActivityDescription(LineNumber, Activity)
	
	Presentation = NStr("en = 'line %1 - %2'; ru = 'строка %1 - %2';pl = 'wiersz %1 - %2';es_ES = 'línea %1 - %2';es_CO = 'línea %1 - %2';tr = 'satır %1 - %2';it = 'linea %1 - %2';de = 'Zeile %1 - %2'");
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		Presentation,
		LineNumber,
		Activity);
		
	Return Presentation;
	
EndFunction

#EndRegion

// Reservation

&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
	If UseDefaultTypeOfAccounting Then
		
		ParametersStructure = New Structure;
		ParametersStructure.Insert("GetGLAccounts", False);
		ParametersStructure.Insert("FillInventory", True);
		
		FillAddedColumns(ParametersStructure);
		
	EndIf;
	FillAddedColumnActivity(Object);
	
EndProcedure

// End Reservation

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion