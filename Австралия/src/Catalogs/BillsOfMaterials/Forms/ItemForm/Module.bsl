
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Mechanism handler "ObjectVersioning".
	ObjectsVersioning.OnCreateAtServer(ThisForm);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Catalogs.BillsOfMaterials.TabularSections.Content, DataLoadSettings, ThisObject, False);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	If Not Object.Status = Enums.BOMStatuses.Open Then
		// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
		// End StandardSubsystems.ObjectAttributesLock
	EndIf;
	
	If Items.Find("AllowObjectAttributeEdit") <> Undefined Then
		Items.AllowObjectAttributeEdit.Visible = False;
	EndIf;
	
	If Not ValueIsFilled(Object.OperationKind) Then
		Object.OperationKind = Common.CommonSettingsStorageLoad(
			"SettingsOfBOM",
			"OperationKindUserChoice",
			Enums.OperationTypesProductionOrder.EmptyRef());
		Object.UseRouting = (Object.OperationKind = Enums.OperationTypesProductionOrder.Production);
	EndIf;
	
	SetEnabledFromGoodsType();
	
	Items.ContentDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	FillActivitiesValueList();
	FillActivityAliases();
	
	SetConditionalAppearance();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
	DriveTrade = Constants.DriveTrade.Get();
	OperationKind = Object.OperationKind;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	FilesOperationsClient.ShowConfirmationForClosingFormWithFiles(ThisObject, Cancel, Exit, Object.Ref);
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnOpening = True;
	SetVisibleAndEnabledClient(OnOpening);
	SetVisibleOperationsAndActivity();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not CurrentObject.UseRouting Then
		CurrentObject.Operations.Clear();
	EndIf;
	
	If Object.Operations.Count() Then
		
		For Each ContentLine In Object.Content Do
			
			If ContentLine.ActivityConnectionKey = 0 Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'On the Components tab, an operation is required for each component.'; ru = 'Во вкладке Сырье и материалы для каждого материала требуется указать операцию.';pl = 'Na karcie Komponenty, operacja jest wymagana dla każdego materiału.';es_ES = 'En la pestaña Componentes, se requiere una operación para cada componente.';es_CO = 'En la pestaña Componentes, se requiere una operación para cada componente.';tr = 'Malzemeler sekmesinde, her malzeme için bir işlem gerekli.';it = 'Nella scheda Componenti è richiesta una operazione per ciascuna componente.';de = 'Auf der Registerkarte „Nebenprodukte“ ist für jedes Nebenprodukt eine Operation erforderlich.'"),
					"Object.Content",
					ContentLine.LineNumber,
					"ActivityAlias",
					Cancel);
				
			EndIf;
			
		EndDo;
		
		For Each ByProductsLine In Object.ByProducts Do
			
			If ByProductsLine.ActivityConnectionKey = 0 Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					NStr("en = 'On the By-products tab, an operation is required for each by-product.'; ru = 'Во вкладке Побочная продукция для каждой побочной продукции требуется указать операцию.';pl = 'Na karcie ""Produkty uboczne"", operacja jest wymagana dla każdego produktu ubocznego.';es_ES = 'En la pestaña de Trozo y deterioro, se requiere una operación para cada Trozo y deterioro.';es_CO = 'En la pestaña de Trozo y deterioro, se requiere una operación para cada Trozo y deterioro.';tr = 'Yan ürünler sekmesinde, her yan ürün için bir işlem gerekli.';it = 'Nella scheda Scarti e Residui è richiesta una operazione per ciascuno scarto e residuo.';de = 'Auf der Registerkarte „Nebenprodukte“ ist für jedes Nebenprodukt eine Operation erforderlich.'"),
					"Object.ByProducts",
					ByProductsLine.LineNumber,
					"ActivityAlias",
					Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Common.CommonSettingsStorageSave("SettingsOfBOM", "OperationKindUserChoice", OperationKind);
	
	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	If Not Object.Status = Enums.BOMStatuses.Open Then
		// StandardSubsystems.ObjectAttributesLock
		ObjectAttributesLock.LockAttributes(ThisObject);
		// End StandardSubsystems.ObjectAttributesLock
	EndIf;
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
	FillActivityAliases();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If Object.Status = PredefinedValue("Enum.BOMStatuses.Open") 
		And Items.Find("AllowObjectAttributeEdit") <> Undefined Then
		// StandardSubsystems.ObjectAttributesLock
		LockedAttributes = ObjectAttributesLockClient.Attributes(ThisObject, True);
		ObjectAttributesLockClient.SetFormItemEnabled(ThisObject, LockedAttributes);
		// End StandardSubsystems.ObjectAttributesLock
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// begin Drive.FullVersion
	If Object.Status = PredefinedValue("Enum.BOMStatuses.Active") Then
		ProductionPlanningClientServer.CheckTableOfRouting(Object.Operations, Cancel, , "Routing");
	EndIf;
	// end Drive.FullVersion
	
	Return; // This handler is empty in the Trade version
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.BillsOfMaterials.Form.ChoiceForm" Then
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure OwnerOnChange(Item)
	
	SetEnabledFromGoodsType();
	
	If ValueIsFilled(Object.Owner) Then
		
		Items.ProductCharacteristic.Visible = GetProductUseCharacteristics(Object.Owner);
		
	Else 
		
		Items.ProductCharacteristic.Visible = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StatusOnChange(Item)
	
	If Object.Status = PredefinedValue("Enum.BOMStatuses.Closed") 
		And Not ValueIsFilled(Object.ValidityEndDate) Then
		Object.ValidityEndDate = CurrentDate();
	EndIf;
	
	If IsDefaulfBOM(Object.Owner, Object.Ref) 
		And (Object.Status = PredefinedValue("Enum.BOMStatuses.Closed")
		Or Object.Status = PredefinedValue("Enum.BOMStatuses.Open")) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'This is default bill of materials for product %1.'; ru = 'Это спецификация по умолчанию для номенклатуры %1.';pl = 'To jest domyślna specyfikacja materiałowa dla produktu%1.';es_ES = 'Esta es la lista de materiales por defecto para el producto%1.';es_CO = 'Esta es la lista de materiales por defecto para el producto%1.';tr = 'Bu, %1 ürününün varsayılan ürün reçetesidir.';it = 'Questa è la distinta base predefinita per l''articolo %1.';de = 'Dies ist eine Standard-Stückliste für das Produkt %1.'"),
			TrimAll(Object.Owner));
		CommonClientServer.MessageToUser(MessageText);
		
	EndIf;
	
	If Object.Status = PredefinedValue("Enum.BOMStatuses.Open") 
		And Not ObjectRefStatus(Object.Ref) = PredefinedValue("Enum.BOMStatuses.Open") Then
		
		TextMessage = NStr("en = 'If you want to continue editing other details, click Save.'; ru = 'Чтобы продолжить редактировать описание, нажмите Записать.';pl = 'Jeśli chcesz dalej edytować inne szczegóły, kliknij Zapisz.';es_ES = 'Si desea continuar editando otros detalles, haga clic en Guardar.';es_CO = 'Si desea continuar editando otros detalles, haga clic en Guardar.';tr = 'Diğer bilgileri düzenlemeye devam etmek istiyorsanız Kaydet''e tıklayın.';it = 'Per continuare a modificare altri dettagli, cliccare su Salva.';de = 'Klicken Sie auf ""Speichern"" wenn Sie andere Details weiter bearbeiten möchten.'");
		CommonClientServer.MessageToUser(TextMessage);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

&AtClient
Procedure OperationKindOnChange(Item)
	
	If OperationKind <> Object.OperationKind Then
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production") Then
			
			OperationKind = Object.OperationKind;
			Object.UseRouting = True;
			SetVisibleAndEnabledClient();
			SetVisibleOperationsAndActivity();
			
		ElsIf OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production") Then
			
			If Object.Operations.Count() Or Object.ByProducts.Count() Then
				
				QueryText = NStr("en = 'The Routing tab will be cleared. Do you want to continue?'; ru = 'Вкладка ""Маршрут"" будет очищена. Продолжить?';pl = 'Karta Marszruty zostanie wyczyszczona. Czy chcesz kontynuować?';es_ES = 'La pestaña Operaciones se eliminará. ¿Quiere continuar?';es_CO = 'La pestaña Operaciones se eliminará. ¿Quiere continuar?';tr = 'Rota sekmesi temizlenecek. Devam etmek istiyor musunuz?';it = 'La scheda Processo sarà cancellata. Continuare?';de = 'Die Registerkarte Routing wird gelöscht. Möchten Sie fortfahren?'");
				If Object.Operations.Count() = 0 Then
					QueryText = NStr("en = 'The By-products tab will be cleared. Do you want to continue?'; ru = 'Вкладка ""Побочная продукция"" будет очищена. Продолжить?';pl = 'Karta Produkty uboczne zostanie wyczyszczona. Czy chcesz kontynuować?';es_ES = 'La pestaña Trozo y deterioro se eliminará ¿Quiere continuar?';es_CO = 'La pestaña Trozo y deterioro se eliminará ¿Quiere continuar?';tr = 'Yan ürünler sekmesi temizlenecek. Devam etmek istiyor musunuz?';it = 'La scheda Scarti e residui sarà cancellata. Continuare?';de = 'Die Registerkarte Nebenprodukte wird gelöscht. Möchten Sie fortfahren?'");
				ElsIf Object.ByProducts.Count() Then
					QueryText = NStr("en = 'The Routing and By-products tabs will be cleared. Do you want to continue?'; ru = 'Вкладки ""Маршрут"" и ""Побочная продукция"" будут очищены.Продолжить?';pl = 'Karty Marszruty i Produkty uboczne zostaną wyczyszczone. Czy chcesz kontynuować?';es_ES = 'Las pestañas Operaciones y Trozo y deterioro se eliminará ¿Quiere continuar?';es_CO = 'Las pestañas Operaciones y Trozo y deterioro se eliminará ¿Quiere continuar?';tr = 'Rota ve Yan ürünler sekmeleri temizlenecek. Devam etmek istiyor musunuz?';it = 'Le schede Processo e Scarti e residui saranno cancellate. Continuare?';de = 'Die Registerkarte Routing und Nebenprodukte werden gelöscht. Möchten Sie fortfahren?'");
				EndIf;
				
				NotificationDescriptionOnQueryBox = New NotifyDescription("UseRoutingOnChanceFragment", ThisObject);
				ShowQueryBox(NotificationDescriptionOnQueryBox,
					QueryText,
					QuestionDialogMode.YesNo);
				
			Else
				
				UseRoutingOnChanceCheckReplenishmentMethod();
				
			EndIf;
			
		ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly") Then
			
			UseRoutingOnChanceCheckReplenishmentMethod();
			
		Else
			
			OperationKind = Object.OperationKind;
			SetVisibleAndEnabledClient();
			SetVisibleOperationsAndActivity();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SortOperations(Command)
	Object.Operations.Sort("ActivityNumber");
	FillActivityAliases();
EndProcedure

&AtClient
Procedure FillInWithTemplate(Command)
	
	// begin Drive.FullVersion
	
	TabularSectionName = "Operations";
	
	If Object.Operations.Count() Then
		
		NotificationDescriptionOnQueryBox = New NotifyDescription("FillInWithTemplateFragment", ThisObject);
		ShowQueryBox(NotificationDescriptionOnQueryBox,
			NStr("en = 'Do you want to refill the routing table?'; ru = 'Таблица маршрутов будет полностью перезаполнена. Продолжить?';pl = 'Czy chcesz uzupełnić tablicę trasowania?';es_ES = 'Quiere volver a llenar la tabla de rutas?';es_CO = 'Quiere volver a llenar la tabla de rutas?';tr = 'Rota tablosunu yeniden doldurmak istiyor musunuz?';it = 'Ricompilare la tabella di percorso?';de = 'Möchten Sie die Routingtabelle wieder ausfüllen?'"),
			QuestionDialogMode.YesNo);
		
	Else
		
		FillInWithTemplateFragment(DialogReturnCode.Yes, Undefined);
		
	EndIf;
	// end Drive.FullVersion
	
	Return; // This handler is empty in lite version.
	
EndProcedure

#EndRegion

#Region ContentFormTableItemsEventHandlers

&AtClient
// Procedure - event handler OnChange input field ContentRowType.
//
Procedure ContentTypeOfContentRowOnChange(Item)
	
	Row = Items.Content.CurrentData;
	
	If ValueIsFilled(Row.ContentRowType)
		AND ValueIsFilled(Row.Products) Then
		
		StructureData = New Structure();
		StructureData.Insert("ContentRowType", Row.ContentRowType);
		StructureData.Insert("Products", Row.Products);
		
	EndIf;
	
	UpdateControlsDueToContentRowType();
	 
EndProcedure

&AtClient
Procedure ContentOnActivateRow(Item)
	UpdateControlsDueToContentRowType();
EndProcedure

&AtClient
Procedure ContentBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	If Not ValueIsFilled(Object.OperationKind) Then
		CommonClientServer.MessageToUser(NStr("en = 'Choose process type first'; ru = 'Сначала укажите тип процесса';pl = 'Najpierw wybierz typ procesu';es_ES = 'Seleccione primero el tipo de proceso';es_CO = 'Seleccione primero el tipo de proceso';tr = 'Önce işlem türünü seçin';it = 'Selezionare prima il tipo processo';de = 'Wählen Sie einen Prozesstyp erst aus'"), , "Object.OperationKind");
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Items.Content.ReadOnly And (Field = Items.ContentProducts Or Field = Items.ContentSpecification) Then
		
		StandardProcessing = False;
		
		CurrentData = Items.Content.CurrentData;
		If CurrentData = Undefined Then
			Return;
		EndIf;
		
		If Field = Items.ContentProducts And ValueIsFilled(CurrentData.Products) Then
			OpenForm("Catalog.Products.ObjectForm", New Structure("Key", CurrentData.Products));
		ElsIf Field = Items.ContentSpecification And ValueIsFilled(CurrentData.Specification) Then
			OpenForm("Catalog.BillsOfMaterials.ObjectForm", New Structure("Key", CurrentData.Specification));
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ContentProductsOnChange(Item)
	
	Row = Items.Content.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", Row.Products);
	StructureData.Insert("GetSpecification", (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production")));
	StructureData.Insert("OperationTypeOrder", PredefinedValue("Enum.OperationTypesProductionOrder.Production"));
	
	StructureData = GetDataProductsOnChange(StructureData, CurrentDate());
	
	Row.Characteristic = Undefined;
	Row.MeasurementUnit = StructureData.MeasurementUnit;
	Row.Specification = StructureData.Specification;
	Row.ManufacturedInProcess = ValueIsFilled(Row.Specification);
	Row.Cost = StructureData.Cost;
	Row.CalculationMethod = PredefinedValue("Enum.BOMContentCalculationMethod.Proportional");
	
	If Row.ContentRowType = PredefinedValue("Enum.BOMLineType.ThirdPartyMaterial") Then
		Row.CostPercentage = 0;
	Else
		Row.CostPercentage = 1;
	EndIf;
	
	CalculateTotalInContentLine(Row);
	
EndProcedure

// Procedure - event handler StartChoice field Products.
//
&AtClient
Procedure ContentProductsStartChoice(Item, ChoiceData, StandardProcessing)
	
	If ValueIsFilled(Object.OperationKind) Then
	
		// Set selection parameters of products depending on content row type
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.ProductsTypes.InventoryItem"));
		ChoiceParameter = New ChoiceParameter("Filter.ProductsType", New FixedArray(FilterArray));
		
		SelectionParametersArray = New Array();
		SelectionParametersArray.Add(ChoiceParameter);
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly") Then
			FilterArray = New Array;
			FilterArray.Add(PredefinedValue("Enum.InventoryReplenishmentMethods.Purchase"));
			FilterArray.Add(PredefinedValue("Enum.InventoryReplenishmentMethods.EmptyRef"));
			ChoiceParameter = New ChoiceParameter("Filter.ReplenishmentMethod", New FixedArray(FilterArray));
			SelectionParametersArray.Add(ChoiceParameter);
		EndIf;
		
		Item.ChoiceParameters = New FixedArray(SelectionParametersArray);
		
	Else
		
		StandardProcessing = False;
		CommonClientServer.MessageToUser(NStr("en = 'Process type is required.'; ru = 'Требуется указать тип процесса.';pl = 'Wymagany jest typ procesu.';es_ES = 'Se requiere el Tipo de proceso.';es_CO = 'Se requiere el Tipo de proceso.';tr = 'Süreç türü gerekli.';it = 'È richiesto il Tipo Processo.';de = 'Prozesstyp ist erforderlich.'"), , "Object.OperationKind");
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentProductsChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	// Prohibit loop references
	If ValueSelected = Object.Owner Then
		CommonClientServer.MessageToUser(NStr("en = 'Products cannot be included in BOM.'; ru = 'В состав спецификации не может входить продукция.';pl = 'Produktów nie można włączyć do specyfikacji materiałowej.';es_ES = 'Productos no pueden incluirse en el BOM.';es_CO = 'Productos no pueden incluirse en el BOM.';tr = 'Ürünler ürün reçetesine dahil edilemiyor.';it = 'I prodotti non possono essere inclusi nella Distinta Base.';de = 'Produkte können nicht in die Stückliste aufgenommen werden.'"));
		StandardProcessing = False;
	ElsIf Not ValueIsFilled(Object.OperationKind) Then
		StandardProcessing = False;
		CommonClientServer.MessageToUser(NStr("en = 'Choose process type first'; ru = 'Сначала укажите тип процесса';pl = 'Najpierw wybierz typ procesu';es_ES = 'Seleccione primero el tipo de proceso';es_CO = 'Seleccione primero el tipo de proceso';tr = 'Önce süreç türünü seçin';it = 'Selezionare prima il tipo processo';de = 'Wählen Sie einen Prozesstyp erst aus'"), , "Object.OperationKind");
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Characteristic input field.
//
Procedure ContentCharacteristicOnChange(Item)
	
	Row = Items.Content.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", Row.Products);
	StructureData.Insert("Characteristic", Row.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData, CurrentDate());
	
	Row.Specification = StructureData.Specification;
	Row.ManufacturedInProcess = ValueIsFilled(Row.Specification);
	
EndProcedure

&AtClient
Procedure ContentMeasurementUnitOnChange(Item)
	
	Row = Items.Content.CurrentData;
	Row.Cost = GetAverageComponentCost(Row.Products, Row.MeasurementUnit);
	CalculateTotalInContentLine(Row);
	
EndProcedure

&AtClient
Procedure ContentSpecificationCreating(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrentComponent = Item.Parent.CurrentData;
	
	FillingValues = New Structure;
	FillingValues.Insert("Description", Item.EditText);
	FillingValues.Insert("Owner", CurrentComponent.Products);
	FillingValues.Insert("ProductCharacteristic", CurrentComponent.Characteristic);
	FillingValues.Insert("OperationKind", PredefinedValue("Enum.OperationTypesProductionOrder.Production"));
	
	FormParameters = New Structure("FillingValues", FillingValues);
	
	OpenForm("Catalog.BillsOfMaterials.ObjectForm", FormParameters,, True);
	
EndProcedure

&AtClient
Procedure ContentSpecificationStartChoice(Item, ChoiceData, StandardProcessing)

	StandardProcessing = False;
	
	CurrentData = Item.Parent.CurrentData;
	ProductOwner = CurrentData.Products;
	
	StructureFilter = New Structure("Owner, Status, UseRouting",
		ProductOwner,
		PredefinedValue("Enum.BOMStatuses.Active"),
		True);
	
	ParametersFormBOM = New Structure("DateChoice, Filter", 
		CurrentDate(),
		StructureFilter);
		
	If ValueIsFilled(CurrentData.Characteristic) Then
		ParametersFormBOM.Insert("ProductCharacteristic", CurrentData.Characteristic);
	EndIf;
	
	ParametersFormBOM.Insert("OperationKind", PredefinedValue("Enum.OperationTypesProductionOrder.Production"));
	
	ChoiceHandler = New NotifyDescription("ContentSpecificationStartChoiceEnd", 
		ThisObject, 
		New Structure("CurrentData", CurrentData));
	
	OpenForm("Catalog.BillsOfMaterials.ChoiceForm", ParametersFormBOM, ThisObject, , , , ChoiceHandler);
	
EndProcedure

&AtClient
Procedure ContentSpecificationStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	AdditionalParameters.CurrentData.Specification = ResultValue;
	
EndProcedure

&AtClient
Procedure ContentCostOnChange(Item)
	CalculateTotalInContentLine();
EndProcedure

&AtClient
Procedure ContentQuantityOnChange(Item)
	CalculateTotalInContentLine();
EndProcedure

&AtClient
Procedure ContentOnStartEdit(Item, NewRow, Clone)
	
	TabularSectionName = "Content";
	
	If NewRow And Not Clone And Object.UseRouting Then
		
		If Object.Operations.Count() = 1 Then
			UniqueActivity = Object.Operations[0];
			Item.CurrentData.Activity = UniqueActivity.Activity;
			Item.CurrentData.ActivityAlias = ActivityDescription(UniqueActivity.LineNumber, UniqueActivity.Activity);
			Item.CurrentData.ActivityNumber = UniqueActivity.ActivityNumber;
			Item.CurrentData.ActivityConnectionKey = UniqueActivity.ConnectionKey;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentOnEditEnd(Item, NewRow, CancelEdit)
	CalculatePlannedCost();
EndProcedure

&AtClient
Procedure ContentManufacturedInProcessOnChange(Item)
	
	ContentRow = Items.Content.CurrentData;
	If Not ContentRow.ManufacturedInProcess Then
		ContentRow.Specification = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
	EndIf;
	
EndProcedure

&AtClient
Procedure ContentActivityAliasStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = ActivitiesValueList;
	
EndProcedure

&AtClient
Procedure ContentActivityAliasChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	Row = Items.Content.CurrentData;
	If Row <> Undefined Then
		
		SelectedActivity = Object.Operations.FindByID(SelectedValue);
		
		Row.Activity = SelectedActivity.Activity;
		Row.ActivityAlias = ActivityDescription(SelectedActivity.LineNumber, SelectedActivity.Activity);
		Row.ActivityNumber = SelectedActivity.ActivityNumber;
		Row.ActivityConnectionKey = SelectedActivity.ConnectionKey;
		
		Items.Content.CurrentItem = Items.ContentManufacturedInProcess;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region OperationsFormTableItemsEventHandlers

&AtClient
Procedure OperationsAfterDeleteRow(Item)
	
	FillActivitiesValueList();
	
EndProcedure

&AtClient
Procedure OperationsActivityNumberOnChange(Item)
	
	Row = Items.Operations.CurrentData;
	Row.NextActivityNumber = Row.ActivityNumber + 1;
	RefillContentActivities(Row);
	
EndProcedure

&AtClient
Procedure OperationsActivityOnChange(Item)
	
	Row = Items.Operations.CurrentData;
	
	StructureData = GetDataActivityOnChange(Row.Activity);
	
	FillPropertyValues(Row, StructureData);
	If Row.Quantity = 0 Then
		Row.Quantity = 1;
	EndIf;
	
	Row.CalculationMethod = PredefinedValue("Enum.BOMOperationCalculationMethod.Proportional");
	
	CalculateTotalInOperationsLine(Row);
	
	RefillContentActivities(Row);
	FillActivitiesValueList();
	
EndProcedure

&AtClient
Procedure OperationsQuantityOnChange(Item)
	CalculateTotalInOperationsLine();
EndProcedure

&AtClient
Procedure OperationsRateOnChange(Item)
	CalculateTotalInOperationsLine();
EndProcedure

&AtClient
Procedure OperationsTimeInUOMOnChange(Item)
	
	CalculateTotalInOperationsLine(Undefined, True);
	
EndProcedure

&AtClient
Procedure OperationsTimeUOMOnChange(Item)
	
	CalculateTotalInOperationsLine(Undefined, True);
	
EndProcedure

&AtClient
Procedure OperationsWorkloadOnChange(Item)
	
	CalculateTotalInOperationsLine();
	
EndProcedure

&AtClient
Procedure OperationsOnEditEnd(Item, NewRow, CancelEdit)
	CalculatePlannedCost();
EndProcedure

&AtClient
Procedure OperationsOnActivateRow(Item)
	
	Row = Item.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	If Row.ActivityNumber <> 0 Then
		Return;
	EndIf;
	
	For Each Operation In Object.Operations Do
		If Operation.ActivityNumber > Row.ActivityNumber Then
			Row.ActivityNumber = Operation.ActivityNumber;
		EndIf;
	EndDo;
	Row.ActivityNumber = Row.ActivityNumber + 1;
	
	For Each Operation In Object.Operations Do
		If Operation.ActivityNumber = Row.ActivityNumber - 1
			And Operation.NextActivityNumber = 0 Then
			Operation.NextActivityNumber = Row.ActivityNumber;
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Procedure OperationsBeforeDeleteRow(Item, Cancel)
	
	ComponentsWereDeleted = False;
	ByProductsWereDeleted = False;
	
	For Each OperationIndex In Item.SelectedRows Do
		
		ComponentsWereDeleted = ComponentsWereDeleted
			Or ConnectedComponentsWereDeleted(Object.Operations.FindByID(OperationIndex).ConnectionKey, "Content");
		
		ByProductsWereDeleted = ByProductsWereDeleted
			Or ConnectedComponentsWereDeleted(Object.Operations.FindByID(OperationIndex).ConnectionKey, "ByProducts");
		
	EndDo;
	
	If ComponentsWereDeleted Then
		ShowUserNotification(NStr("en = 'The deleted operations were specified for the components on the Components tab. These components were deleted from this tab.'; ru = 'Удаленные операции были определены для компонентов на вкладке ""Сырье и материалы"". Эти компоненты были удалены из этой вкладки.';pl = 'Usunięte operacje zostały wybrane dla komponentów w karcie Komponenty. Te komponenty zostały usunięte z tej karty.';es_ES = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Componentes. Estos componentes fueron eliminados de esta pestaña.';es_CO = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Componentes. Estos componentes fueron eliminados de esta pestaña.';tr = 'Silinen operasyonlar Malzemeler sekmesindeki malzemeler için belirtildi. Bu malzemeler bu sekmeden silindi.';it = 'Le operazioni cancellate sono state specificate per le componenti nella scheda Componenti. Queste componenti sono state cancellate da questa scheda.';de = 'Die gelöschten Operationen wurden für die Komponenten auf der Registerkarte ""Materialbestand"" angegeben. Dieser Materialbestand wurde aus diesem Tab gelöscht.'"));
	EndIf;
	
	If ByProductsWereDeleted Then
		ShowUserNotification(NStr("en = 'The deleted operations were specified for the components on the By-products tab. These components were deleted from this tab.'; ru = 'Удаленные операции были определены для сырья и материалов во вкладке Побочная продукция. Это сырье и материалы были удалены из этой вкладки.';pl = 'Usunięte operacje zostały wybrane dla komponentów na karcie ""Produkty uboczne"". Te komponenty zostały usunięte z tej karty.';es_ES = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Trozo y deterioro. Estos componentes fueron eliminados de esta pestaña.';es_CO = 'Las operaciones eliminadas se han especificado para los componentes en la pestaña Trozo y deterioro. Estos componentes fueron eliminados de esta pestaña.';tr = 'Silinen operasyonlar Yan ürünler sekmesindeki malzemeler için belirtildi. Bu malzemeler bu sekmeden silindi.';it = 'Le operazioni cancellate sono state specificate per le componenti nella scheda Scarti e Residui. Queste componenti sono state cancellate da questa scheda.';de = 'Die gelöschten Operationen wurden für den Materialbestand auf der Registerkarte ""Nebenprodukte"" angegeben. Dieser Materialbestand wurde aus diesem Tab gelöscht.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure OperationsOnStartEdit(Item, NewRow, Clone)
	
	TabularSectionName = "Operations";
	
	If NewRow Then
		Item.CurrentData.Quantity = 1;
		Item.CurrentData.ConnectionKey = NewConnectionKey();
	EndIf;
	
EndProcedure

#EndRegion

#Region ByProductsFormTableItemsEventHandlers

&AtClient
Procedure ByProductsProductOnChange(Item)
	
	Row = Items.ByProducts.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", Row.Product);
	StructureData = GetDataProductsOnChange(StructureData);
	Row.Characteristic = Undefined;
	Row.MeasurementUnit = StructureData.MeasurementUnit;
	Row.Quantity = 0;
	Row.Activity = Undefined;
	
EndProcedure

&AtClient
Procedure ByProductsActivityAliasStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	ChoiceData = ActivitiesValueList;
	
EndProcedure

&AtClient
Procedure ByProductsActivityAliasChoiceProcessing(Item, SelectedValue, StandardProcessing)
	
	StandardProcessing = False;
	
	Row = Items.ByProducts.CurrentData;
	If Row <> Undefined Then
		
		SelectedActivity = Object.Operations.FindByID(SelectedValue);
		
		Row.Activity = SelectedActivity.Activity;
		Row.ActivityAlias = ActivityDescription(SelectedActivity.LineNumber, SelectedActivity.Activity);
		Row.ActivityConnectionKey = SelectedActivity.ConnectionKey;
		
		Items.ByProducts.CurrentItem = Items.ByProductsMeasurementUnit;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ByProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow And Not Clone And Object.UseRouting Then
		
		If Object.Operations.Count() = 1 Then
			UniqueActivity = Object.Operations[0];
			Item.CurrentData.Activity = UniqueActivity.Activity;
			Item.CurrentData.ActivityAlias = ActivityDescription(UniqueActivity.LineNumber, UniqueActivity.Activity);
			Item.CurrentData.ActivityConnectionKey = UniqueActivity.ConnectionKey;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

&AtClient
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate	= Object.ValidityStartDate;
	Dialog.Period.EndDate	= Object.ValidityEndDate;
	
	NotifyDescription = New NotifyDescription("SetIntervalCompleted", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
Procedure SetIntervalCompleted(Result, AdditionalParameters) Export
	
	If Result <> Undefined Then
		
		Object.ValidityStartDate	= Result.StartDate;
		Object.ValidityEndDate		= Result.EndDate;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function IsDefaulfBOM(ProductOwner, CatalogBillOfMaterials)
	
	If CatalogBillOfMaterials = Catalogs.BillsOfMaterials.EmptyRef() Then
		Return False;
	EndIf;
	
	DefaulfBOM = Catalogs.BillsOfMaterials.GetBOMByDefault(ProductOwner);
	Return DefaulfBOM = CatalogBillOfMaterials;
	
EndFunction

#Region GeneralPurposeProceduresAndFunctions

// begin Drive.FullVersion
#Region FillingInWithTemplateCommand

&AtClient
Procedure FillInWithTemplateFragment(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		NotificationDescriptionOnCloseSelection = New NotifyDescription("FillInWithTemplateEnd", ThisObject);
		OpenForm("Catalog.RoutingTemplates.ChoiceForm",
			,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillInWithTemplateEnd(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("CatalogRef.RoutingTemplates") Then
		
		ReFillOperationsWithRoutingTemplate(ClosingResult);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ReFillOperationsWithRoutingTemplate(RoutingTemplate) Export
	
	Object.Operations.Clear();
	Object.Content.Clear();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	RoutingTemplatesOperations.ActivityNumber AS ActivityNumber,
	|	RoutingTemplatesOperations.NextActivityNumber AS NextActivityNumber,
	|	RoutingTemplatesOperations.Activity AS Activity,
	|	ISNULL(ManufacturingActivities.StandardTimeInUOM, 0) AS StandardTimeInUOM,
	|	ISNULL(ManufacturingActivities.StandardTime, 0) AS StandardTime,
	|	ISNULL(ManufacturingActivities.StandardWorkload, 0) AS Workload,
	|	ISNULL(ManufacturingActivities.TimeUOM, VALUE(Catalog.TimeUOM.Minutes)) AS TimeUOM,
	|	1 AS Quantity,
	|	VALUE(Enum.BOMOperationCalculationMethod.Proportional) AS CalculationMethod
	|FROM
	|	Catalog.RoutingTemplates.Operations AS RoutingTemplatesOperations
	|		LEFT JOIN Catalog.ManufacturingActivities AS ManufacturingActivities
	|		ON RoutingTemplatesOperations.Activity = ManufacturingActivities.Ref
	|WHERE
	|	RoutingTemplatesOperations.Ref = &Ref";
	
	Query.SetParameter("Ref", RoutingTemplate);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		
		NewLine = Object.Operations.Add();
		FillPropertyValues(NewLine, Selection);
		NewLine.ConnectionKey = NewConnectionKey();
		
	EndDo;
	
	FillActivitiesValueList();
	
EndProcedure

#EndRegion
// end Drive.FullVersion


&AtClient
Procedure UseRoutingOnChanceFragment(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Assembly") Then
			
			UseRoutingOnChanceCheckReplenishmentMethod();
			
		Else
			
			UseRoutingOnChanceEnd();
			
		EndIf;
		
	Else
		
		Object.OperationKind = OperationKind;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseRoutingOnChanceCheckReplenishmentMethod()
	
	ResultStructure = CheckWrongReplenishmentMethods();
	
	If ResultStructure.RowsToDel.Count() Then
		
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The BOM includes components whose Replenishment method is Production or Assembly. The components: %1. Such components are not applicable if Process type is Assembly.
			|They will be cleared. Do you want to continue?'; 
			|ru = 'Спецификация изделия включает компоненты, способом пополнения которых являются производство или сборка. Компоненты: %1. Такие компоненты не применяются для типа процесса ""Сборка"".
			|Они будут очищены. Продолжить?';
			|pl = 'Specyfikacja materiałowa zawiera komponenty sposobem uzupełniania których jest Produkcja lub Montaż. Komponenty: %1. Takie komponenty nie mają zastosowania, jeśli Typem procesu jest Montaż.
			|Nie zostaną one wyczyszczone. Czy chcesz kontynuować?';
			|es_ES = 'La lista de materiales incluye los componentes cuyo método de reposición del inventario es Producción o Montaje. Los componentes: %1. Estos componentes no son aplicables si el Tipo de proceso es Montaje.
			|Serán eliminados. ¿Quiere continuar?';
			|es_CO = 'La lista de materiales incluye los componentes cuyo método de reposición del inventario es Producción o Montaje. Los componentes: %1. Estos componentes no son aplicables si el Tipo de proceso es Montaje.
			|Serán eliminados. ¿Quiere continuar?';
			|tr = 'Ürün reçetesinde, Stok yenileme yöntemi Üretim veya Montaj olan malzemeler var. Malzemeler: %1. Süreç türü Montaj ise bu tür malzemeler kullanılamaz.
			|Bu malzemeler silinecek. Devam etmek istiyor musunuz?';
			|it = 'La Distinta Base include componenti il cui metodo Rifornimento di scorte è Produzione o Assemblaggio. Componenti: %1. Queste componenti non sono applicabili se il tipo Processo è Assemblaggio.
			| Saranno cancellate. Continuare?';
			|de = 'Die Stückliste enthält Komponenten deren Auffüllungsmethode Produktion oder Montage ist: %1. Diese Komponenten sind nicht verwendbar wenn der Vorgangstyp Montage ist.
			|Sie werden gelöscht. Möchten Sie fortfahren?'"),
			ResultStructure.RowsToDelString);
		
		NotificationDescriptionOnQueryBox = New NotifyDescription("UseRoutingOnChanceCheckReplenishmentMethodFragment", ThisObject, ResultStructure);
			ShowQueryBox(NotificationDescriptionOnQueryBox,
			QueryText,
			QuestionDialogMode.YesNo);
		
	Else
		
		UseRoutingOnChanceEnd();
		
	EndIf;
	
EndProcedure

&AtServer
Function CheckWrongReplenishmentMethods()
	
	ResultStructure = New Structure;
	ResultStructure.Insert("RowsToDel", New Array);
	ResultStructure.Insert("RowsToDelString", "");
	
	For Each ComponentLine In Object.Content Do
		
		ReplenishmentMethod = Common.ObjectAttributeValue(ComponentLine.Products, "ReplenishmentMethod");
		
		If ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
			Or ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			
			ResultStructure.RowsToDel.Add(ComponentLine.GetID());
			
			CharacteristicPresentation = "";
			If ValueIsFilled(ComponentLine.Characteristic) Then
				CharacteristicPresentation = " (" + TrimAll(ComponentLine.Characteristic) + ")";
			EndIf;
			If ValueIsFilled(ResultStructure.RowsToDelString) Then
				ResultStructure.RowsToDelString = ResultStructure.RowsToDelString + ", ";
			EndIf;
			
			ResultStructure.RowsToDelString = ResultStructure.RowsToDelString + TrimAll(ComponentLine.Products) + CharacteristicPresentation;
			
		EndIf;
		
	EndDo;
	
	Return ResultStructure;
	
EndFunction

&AtClient
Procedure UseRoutingOnChanceCheckReplenishmentMethodFragment(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		Index = AdditionalParameters.RowsToDel.Count();
		While Index > 0 Do
			
			Object.Content.Delete(AdditionalParameters.RowsToDel[Index - 1]);
			Index = Index - 1;
			
		EndDo;
		
		
		UseRoutingOnChanceEnd();
		
	Else
		
		Object.OperationKind = OperationKind;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure UseRoutingOnChanceEnd()
	
	OperationKind = Object.OperationKind;
	
	Object.UseRouting = False;
	Object.Operations.Clear();
	Object.ByProducts.Clear();
	
	RefBOMEmpty = PredefinedValue("Catalog.BillsOfMaterials.EmptyRef");
	// begin Drive.FullVersion
	RefActivityEmpty = PredefinedValue("Catalog.ManufacturingActivities.EmptyRef");
	// end Drive.FullVersion
	
	For Each LineContent In Object.Content Do
		
		LineContent.ManufacturedInProcess	= False;
		LineContent.Specification			= RefBOMEmpty;
		// begin Drive.FullVersion
		LineContent.Activity				= RefActivityEmpty;
		LineContent.ActivityNumber			= 0;
		LineContent.ActivityConnectionKey	= 0;
		LineContent.ActivityAlias			= "";
		// end Drive.FullVersion
		
	EndDo;
	
	SetVisibleAndEnabledClient();
	SetVisibleOperationsAndActivity();
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	// If not 'Manufactured in process' then BOM has be empty
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(NewConditionalAppearance.Filter,
		"Object.Content.ManufacturedInProcess",
		False,
		DataCompositionComparisonType.Equal);
	
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "ContentSpecification");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
EndProcedure

&AtServerNoContext
Function GetDataActivityOnChange(Activity)
	
	Result = New Structure;
	Result.Insert("Rate", 0);
	Result.Insert("Workload", 0);
	Result.Insert("TimeUOM", Undefined);
	// begin Drive.FullVersion
	Result.Insert("TimeUOM", Catalogs.TimeUOM.Minutes);
	// end Drive.FullVersion
	Result.Insert("StandardTimeInUOM", 0);
	Result.Insert("StandardTime", 0);
	
	ActivityAttributes = Common.ObjectAttributesValues(Activity, "StandardWorkload, TimeUOM, StandardTimeInUOM, StandardTime");
	
	FillPropertyValues(Result, ActivityAttributes, "TimeUOM, StandardTimeInUOM, StandardTime");
	Result.Workload = ActivityAttributes.StandardWorkload;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Function GetMainCompany()

	MainCompany = DriveReUse.GetValueOfSetting("MainCompany");
	If ValueIsFilled(MainCompany) Then
		Return MainCompany;
	EndIf;
		
	AllCompanies = Catalogs.Companies.AllCompanies();
	If AllCompanies.Count() = 1 Then
		Return AllCompanies[0];
	EndIf;
	
	Return Undefined;

EndFunction

&AtServerNoContext
Function ObjectRefStatus(Ref)
	
	Status = Enums.BOMStatuses.Open;
	
	If ValueIsFilled(Ref) Then
		Status = Common.ObjectAttributeValue(Ref, "Status");
	EndIf;
	
	Return Status;
	
EndFunction

&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(StructureData, ComponentDate = Undefined)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, 
		"MeasurementUnit, TimeNorm, ReplenishmentMethod, Description");
	Characteristic = Undefined;
	StructureData.Property("Characteristic", Characteristic);
	
	Specification = Catalogs.BillsOfMaterials.EmptyRef();
	
	If StructureData.Property("GetSpecification") And StructureData.GetSpecification Then
		
		OperationTypeOrder = Undefined;
		StructureData.Property("OperationTypeOrder", OperationTypeOrder);
		
		Specification = DriveServer.GetDefaultSpecification(StructureData.Products, Characteristic, OperationTypeOrder);
		
		If Not ComponentDate = Undefined 
			And ProductsAttributes.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			
			Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products, ComponentDate, , OperationTypeOrder);
			
		EndIf;
		
	EndIf;
	
	StructureData.Insert("Specification", Specification);
	StructureData.Insert("MeasurementUnit",	ProductsAttributes.MeasurementUnit);
	StructureData.Insert("TimeNorm",		ProductsAttributes.TimeNorm);
	StructureData.Insert("Cost",			GetAverageComponentCost(StructureData.Products));
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData, ComponentDate = Undefined)
	
	Specification = DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic);
	StructureData.Insert("Specification", Specification);
	
	If Not ComponentDate = Undefined Then
		
		StuctureProduct = Common.ObjectAttributesValues(StructureData.Products, "ReplenishmentMethod, Description");
		
		If StuctureProduct.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production Then
			
			SpecificationWithCharacteristic = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
				ComponentDate, 
				StructureData.Characteristic);
			StructureData.Insert("Specification", SpecificationWithCharacteristic);
		
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetAverageComponentCost(Product, MeasurementUnit = Undefined)

	Company = GetMainCompany();
	
	If Company = Undefined Then
		Return 0;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	CASE
		|		WHEN InventoryCostLayerBalance.QuantityBalance = 0
		|			THEN 0
		|		ELSE InventoryCostLayerBalance.AmountBalance / InventoryCostLayerBalance.QuantityBalance
		|	END AS AverageCost
		|INTO TT_BasicCost
		|FROM
		|	AccumulationRegister.InventoryCostLayer.Balance(
		|			&Date,
		|			Company = &Company
		|				AND Products = &Products) AS InventoryCostLayerBalance
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_BasicCost.AverageCost * ISNULL(UOM.Factor, 1) AS AverageCost
		|FROM
		|	TT_BasicCost AS TT_BasicCost
		|		LEFT JOIN Catalog.UOM AS UOM
		|		ON (UOM.Ref = &MeasurementUnit)";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Date", CurrentSessionDate());
	Query.SetParameter("Products", Product);
	Query.SetParameter("MeasurementUnit", MeasurementUnit);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	If Selection.Next() Then 
		Return Selection.AverageCost;
	Else
		Return 0;
	EndIf

EndFunction

&AtServer
Procedure SetEnabledFromGoodsType()
	
	OwnerIsWork = (Object.Owner.ProductsType = Enums.ProductsTypes.Work);
	
	Items.ContentContentRowType.ListChoiceMode = OwnerIsWork;
	
	If OwnerIsWork Then
		ChoiceList = New Array;
		ChoiceList.Add(Enums.BOMLineType.Material);
		Items.ContentContentRowType.ChoiceList.LoadValues(ChoiceList);
	Else
		Items.ContentContentRowType.ChoiceList.Clear();
	EndIf;
	
EndProcedure

&AtClient
Procedure UpdateControlsDueToContentRowType()

	Row = Items.Content.CurrentData;
	If Row = Undefined Then
		Return;
	EndIf;
	
	ThirdPartyMaterial = PredefinedValue("Enum.BOMLineType.ThirdPartyMaterial");
	
	If Row.ContentRowType = ThirdPartyMaterial Then
		Row.CostPercentage = 0;
		Row.Cost = 0;
		Row.Total = 0;
		Items.ContentCostPercentage.ReadOnly = True;
		Items.ContentCost.ReadOnly = True;
		Items.ContentTotal.ReadOnly = True;
	Else
		Items.ContentCostPercentage.ReadOnly = False;
		Items.ContentCost.ReadOnly = False;
		Items.ContentTotal.ReadOnly = False;
	EndIf;
	 
EndProcedure

&AtClient
Procedure CalculatePlannedCost()

	Object.PlannedCost = 
		Object.Content.Total("Total") 
		+ Object.Operations.Total("Total");
	
EndProcedure

&AtClient
Procedure CalculateTotalInOperationsLine(Row = Undefined, NeedToCalculateStandardTime = False)
	
	If Row = Undefined Then
		Row = Items.Operations.CurrentData;
	EndIf;
	
	If NeedToCalculateStandardTime Then
		UOMFactor = TimeUOMFactor(Row.TimeUOM);
		Row.StandardTime = Row.StandardTimeInUOM * UOMFactor;
	EndIf;
	
	Row.Total = Row.Quantity * Row.Workload * Row.Rate;
	
EndProcedure

&AtServerNoContext
Function TimeUOMFactor(TimeUOM);
	
	Result = 0;
	
	If ValueIsFilled(TimeUOM) Then
		Result = Common.ObjectAttributeValue(TimeUOM, "Factor");
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure CalculateTotalInContentLine(Row = Undefined)
	
	If Row = Undefined Then
		Row = Items.Content.CurrentData;
	EndIf;
	
	Row.Total = Row.Quantity * Row.Cost;
	
EndProcedure

&AtServer
Function NewConnectionKey()
	
	Return DriveServer.CreateNewLinkKey(ThisObject);
	
EndFunction

&AtClient
Function ConnectedComponentsWereDeleted(ConnectionKey, TabName)
	
	Result = False;
	
	Filter = New Structure("ActivityConnectionKey", ConnectionKey);
	RowsToDelete = Object[TabName].FindRows(Filter);
	
	For Each RowToDelete In RowsToDelete Do
		Object[TabName].Delete(RowToDelete);
		Result = True;
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Procedure FillActivitiesValueList()
	
	ActivitiesValueList.Clear();
	
	For Each ActivityLine In Object.Operations Do
		ActivitiesValueList.Add(ActivityLine.GetID(), ActivityDescription(ActivityLine.LineNumber, ActivityLine.Activity));
	EndDo;
	
EndProcedure

&AtServer 
Procedure FillActivityAliases()
	
	AliasMap = New Map;
	
	For Each ActivityLine In Object.Operations Do
		AliasMap.Insert(ActivityLine.ConnectionKey, ActivityDescription(ActivityLine.LineNumber, ActivityLine.Activity));
	EndDo;
	
	For Each ContentLine In Object.Content Do
		ContentLine.ActivityAlias = AliasMap.Get(ContentLine.ActivityConnectionKey);
	EndDo;
	
	For Each ByProductsLine In Object.ByProducts Do
		ByProductsLine.ActivityAlias = AliasMap.Get(ByProductsLine.ActivityConnectionKey);
	EndDo;
	
EndProcedure

&AtClient
Procedure RefillContentActivities(ActivityData)
	
	ContentRows = Object.Content.FindRows(New Structure("ActivityConnectionKey", ActivityData.ConnectionKey));
	
	For Each Row In ContentRows Do
		Row.Activity = ActivityData.Activity;
		Row.ActivityNumber = ActivityData.ActivityNumber;
		Row.ActivityAlias = ActivityDescription(ActivityData.LineNumber, ActivityData.Activity);
	EndDo;
	
EndProcedure

#EndRegion

&AtClient
Procedure SetVisibleOperationsAndActivity()
	
	Items.PageOperations.Visible = Object.UseRouting;
	Items.ContentActivityAlias.Visible = Object.UseRouting;
	Items.ByProductsActivityAlias.Visible = Object.UseRouting;
	
EndProcedure

&AtClient
Procedure SetVisibleAndEnabledClient(OnOpening = False)
	
	OperationKindProduction = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Production"));
	OperationKindDisassembly = (Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly"));
	
	Items.ContentManufacturedInProcess.Enabled	= OperationKindProduction;
	Items.ContentSpecification.Enabled			= OperationKindProduction;
	Items.ContentCostPercentage.Visible			= OperationKindDisassembly;
	Items.ContentManufacturedInProcess.Visible	= OperationKindProduction;
	Items.ContentSpecification.Visible			= OperationKindProduction;
	Items.ContentCost.Visible					= OperationKindProduction;
	Items.ContentTotal.Visible					= OperationKindProduction;
	Items.PageByProducts.Visible				= OperationKindProduction Or (OnOpening And Object.ByProducts.Count());
	
	If ValueIsFilled(Object.Owner) Then
		
		Items.ProductCharacteristic.Visible = GetProductUseCharacteristics(Object.Owner);
		
	Else 
		
		Items.ProductCharacteristic.Visible = False;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.DataLoadFromFile
&AtClient
Procedure DataImportFromExternalSources(Command)
	
	TabularSectionName = "Content";
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		Object.Content.Clear();
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

// End StandardSubsystems. DataLoadFromFile

// StandardSubsystems.ObjectAttributesLock

&AtClient
Procedure Attachable_AllowObjectAttributesEditing(Command)
	ObjectAttributesLockClient.AllowObjectAttributeEdit(ThisObject);
EndProcedure

// End StandardSubsystems.ObjectAttributesLock

#EndRegion

&AtServerNoContext
Function GetProductUseCharacteristics(RefProduct)
	
	Return Common.ObjectAttributeValue(RefProduct, "UseCharacteristics");
	
EndFunction

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
