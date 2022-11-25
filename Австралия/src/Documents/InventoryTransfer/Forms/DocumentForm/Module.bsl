
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure EditOwnership(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("TempStorageAddress", PutEditOwnershipDataToTempStorage());
	
	OpenForm("CommonForm.InventoryOwnership", FormParameters, ThisObject);
	
EndProcedure

#Region WorkWithSelection

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)),
		CurBarcode, NStr("en = 'Enter barcode'; ru = 'Введите штрихкод';pl = 'Wprowadź kod kreskowy';es_ES = 'Introducir el código de barras';es_CO = 'Introducir el código de barras';tr = 'Barkod girin';it = 'Inserisci codice a barre';de = 'Geben Sie den Barcode ein'"));
	
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
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
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

#EndRegion

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInInventoryTransfer", 	Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 							False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInInventoryTransfer;
		
		If Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If Object.Inventory.Count() Then
				Object.SalesOrder = Object.Inventory[0].SalesOrder;
			EndIf;
			
		ElsIf Object.SalesOrderPosition = PredefinedValue("Enum.AttributeStationing.InTabularSection") Then
			
			If ValueIsFilled(Object.SalesOrder) Then
				
				For Each InventoryRow In Object.Inventory Do
					If Not ValueIsFilled(InventoryRow.SalesOrder) Then
						InventoryRow.SalesOrder = Object.SalesOrder;
					EndIf;
				EndDo;
				
				Object.SalesOrder = Undefined;
				
			EndIf;
			
		EndIf;
		
		SetVisibleAndEnabled();
		
		Modified = True;
		
	EndIf;
	
EndProcedure

#Region ProcedureActionsOfTheFormCommandPanels

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		MessagesToUserClient.ShowMessageSelectBaseDocument();
		Return;
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject),
		NStr("en = 'Do you want to refill the inventory transfer?'; ru = 'Документ будет полностью перезаполнен по основанию. Продолжить?';pl = 'Chcesz ponownie wypełnić przesunięcie międzymagazynowe?';es_ES = '¿Quiere volver a rellenar el traslado del inventario?';es_CO = '¿Quiere volver a rellenar el traslado de inventario?';tr = 'Stok transferini yeniden doldurmak istiyor musunuz?';it = 'Volete ricompilare il trasferimento di inventario?';de = 'Möchten Sie die Bestandsumlagerung auffüllen?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		FillByDocument(Object.BasisDocument);
	EndIf;

EndProcedure

// FillInByBalance command event handler procedure
//
&AtClient
Procedure FillByBalanceAtWarehouse(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillByBalanceOnWarehouseEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'; ru = 'Табличная часть будет очищена! Продолжить выполнение операции?';pl = 'Sekcja tabelaryczna zostanie wyczyszczona. Kontynuować?';es_ES = 'Sección tabular se vaciará. ¿Continuar?';es_CO = 'Sección tabular se vaciará. ¿Continuar?';tr = 'Tablo bölümü silinecek. Devam edilsin mi?';it = 'La sezione tabellare sarà annullata. Proseguire?';de = 'Der Tabellenabschnitt wird gelöscht. Fortsetzen?'"), QuestionDialogMode.YesNo, 0);
		Return; 
	EndIf;
	
	FillByBalanceOnWarehouseEndFragment();
EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response <> DialogReturnCode.Yes Then
		Return;
	EndIf; 
	
	FillByBalanceOnWarehouseEndFragment();

EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEndFragment()
    
    FillInventoryByWarehouseBalancesAtServer();

EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'; ru = 'Табличная часть ""Запасы"" не заполнена!';pl = 'Nie wypełniono sekcji tabelarycznej ""Zapasy"".';es_ES = 'La sección tabular ""Inventario"" no está rellenada.';es_CO = 'La sección tabular ""Inventario"" no está rellenada.';tr = '""Stok"" tablo bölümü doldurulmadı.';it = 'La sezione tabellare ""Scorte"" non è compilata!';de = 'Der Tabellenabschnitt ""Bestand"" ist nicht ausgefüllt.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'; ru = 'Табличная часть ""Запасы"" не заполнена!';pl = 'Nie wypełniono sekcji tabelarycznej ""Zapasy"".';es_ES = 'La sección tabular ""Inventario"" no está rellenada.';es_CO = 'La sección tabular ""Inventario"" no está rellenada.';tr = '""Stok"" tablo bölümü doldurulmadı.';it = 'La sezione tabellare ""Scorte"" non è compilata!';de = 'Der Tabellenabschnitt ""Bestand"" ist nicht ausgefüllt.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtClient
Procedure InventoryBatchOnChangeAtClient()
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData.Insert("Products", TabRow.Products);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_Selected()
	
	Params = New Structure;
	Params.Insert("TableName", "Inventory");
	Params.Insert("BatchOnChangeHandler", True);
	Params.Insert("QuantityOnChangeHandler", True);
	
	BatchesClient.FillBatchesByFEFO_Selected(ThisObject, Params);
	
EndProcedure

&AtClient
Procedure Attachable_FillBatchesByFEFO_All()
	
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
	
	CalculateAmountInTabularSectionLine(RowData);
	
EndProcedure

&AtClient
Function Attachable_FillByFEFOData(TableName, ShowMessages) Export
	
	Return FillByFEFOData(ShowMessages);
	
EndFunction

&AtServer
Function FillByFEFOData(ShowMessages)
	
	Params = New Structure;
	Params.Insert("CurrentRow", Object.Inventory.FindByID(Items.Inventory.CurrentRow));
	If Object.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		Params.Insert("StructuralUnit", Object.StructuralUnitPayee);
		Params.Insert("Cell", Object.CellPayee);
	Else
		Params.Insert("StructuralUnit", Object.StructuralUnit);
		Params.Insert("Cell", Object.Cell);
	EndIf;
	Params.Insert("ShowMessages", ShowMessages);
	
	If Not BatchesServer.FillByFEFOApplicable(Params) Then
		Return Undefined;
	EndIf;
	
	Params.Insert("Object", Object);
	Params.Insert("Company", Object.Company);
	If Object.SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		Params.Insert("SalesOrder", Object.SalesOrder);
	Else
		Params.Insert("SalesOrder", "SalesOrder");
	EndIf;
	
	Return BatchesServer.FillByFEFOData(Params);
	
EndFunction

&AtServer
Procedure EditOwnershipProcessingAtServer(TempStorageAddress)
	
	OwnershipTable = GetFromTempStorage(TempStorageAddress);
	
	Object.InventoryOwnership.Load(OwnershipTable);
	
EndProcedure

&AtClient
Procedure EditOwnershipProcessingAtClient(TempStorageAddress)
	
	EditOwnershipProcessingAtServer(TempStorageAddress);
	
EndProcedure

&AtServer
Function PutEditOwnershipDataToTempStorage()
	
	DocObject = FormAttributeToValue("Object");
	DataForOwnershipForm = InventoryOwnershipServer.GetDataForInventoryOwnershipForm(DocObject);
	TempStorageAddress = PutToTempStorage(DataForOwnershipForm, UUID);
	Return TempStorageAddress;
	
EndFunction

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	StructuralUnitType = Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType");
	StructuralUnitPayeeType = Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType");
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	NewArray.Add(Enums.BusinessUnitsTypes.Retail);
	NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
	If Constants.UseProductionSubsystem.Get() Or Constants.UseKitProcessing.Get() Then
		NewArray.Add(Enums.BusinessUnitsTypes.Department);
	EndIf;
	ArrayWarehouseSubdepartmentRetail = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Department);
	ArrayUnit = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	ArrayWarehouse = New FixedArray(NewArray);
	
	If Object.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		Items.InventoryBusinessLine.Visible = False;
		Items.InventoryBusinessUnit.Visible = False;
		Items.InventoryPick.Visible = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		SetVisibleAndEnabledReservationItems(StructuralUnitType, StructuralUnitPayeeType);
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		
		OrderInHeader = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
		
		If OrderInHeader Then
			Items.SalesOrder.InputHint = "";
		Else
			Items.SalesOrder.InputHint = MultipleOrdersHint();
		EndIf;
		
		Items.InventoryBusinessLine.Visible = True;
		Items.InventoryBusinessUnit.Visible = True;
		Items.SalesOrder.Visible = True;
		Items.SalesOrder.Enabled = OrderInHeader;
		Items.InventorySalesOrder.Visible = Not OrderInHeader;
		Items.InventoryReserve.Visible = True;
		Items.InventoryChangeReserve.Visible = True;
		Items.InventoryPick.Visible = True;
		ReservationUsed = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			Items.StructuralUnit.Visible = False;
		Else
			Items.StructuralUnit.Visible = True;
		EndIf;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			Items.StructuralUnitPayee.Visible = False;
		Else
			Items.StructuralUnitPayee.Visible = True;
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		
		Items.InventoryBusinessLine.Visible = True;
		Items.InventoryBusinessUnit.Visible = True;
		Items.SalesOrder.Visible = False;
		Items.InventorySalesOrder.Visible = False;
		Items.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = True;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each Row In Object.Inventory Do
			Row.Reserve = 0;
		EndDo;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			Items.StructuralUnit.Visible = False;
		Else
			Items.StructuralUnit.Visible = True;
		EndIf;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			Items.StructuralUnitPayee.Visible = False;
		Else
			Items.StructuralUnitPayee.Visible = True;
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		
		Items.InventoryBusinessLine.Visible = False;
		Items.InventoryBusinessUnit.Visible = False;
		Items.SalesOrder.Visible = False;
		Items.InventorySalesOrder.Visible = False;
		Items.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = False;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each Row In Object.Inventory Do
			Row.Reserve = 0;
		EndDo;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			Items.StructuralUnit.Visible = False;
		Else
			Items.StructuralUnit.Visible = True;
		EndIf;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			Items.StructuralUnitPayee.Visible = False;
		Else
			Items.StructuralUnitPayee.Visible = True;
		EndIf;
		
	Else
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	EndIf;
	
	Items.InventoryCostPrice.Visible = (StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
	Items.InventoryAmount.Visible = (StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
	
	Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
	
	Items.InventoryGLAccounts.Visible = UseDefaultTypeOfAccounting;
	
	SetCellVisible("Cell", Object.StructuralUnit);
	SetCellVisible("CellPayee", Object.StructuralUnitPayee);
	SetWorkVisible();
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabledReservationItems(StructuralUnitType, StructuralUnitPayeeType)
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		
		Items.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		ReservationUsed = False;
		
	Else
		
		Items.InventoryReserve.Visible = True;
		Items.InventoryChangeReserve.Visible = True;
		ReservationUsed = True;
		
	EndIf;
	
	If (StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting)
		And (StructuralUnitPayeeType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitPayeeType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
		
		Items.SalesOrder.Visible = False;
		Items.InventorySalesOrder.Visible = False;
		
	Else
		
		OrderInHeader = (Object.SalesOrderPosition = Enums.AttributeStationing.InHeader);
		
		If OrderInHeader Then
			Items.SalesOrder.InputHint = "";
		Else
			Items.SalesOrder.InputHint = MultipleOrdersHint();
		EndIf;
		
		Items.SalesOrder.Visible = True;
		Items.SalesOrder.Enabled = OrderInHeader;
		Items.InventorySalesOrder.Visible = Not OrderInHeader;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure SetCellVisible(CellName, Warehouse)
	
	If Not ValueIsFilled(Warehouse)
		Or Warehouse.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or Warehouse.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items[CellName].Visible = False;
	Else
		Items[CellName].Visible = True;
	EndIf;
	
EndProcedure

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			And Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.ListChoiceMode = True;
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			
			Items.StructuralUnitPayee.ListChoiceMode = True;
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			
		EndIf;
		
	EndIf;
	
	If Constants.UseProductionSubsystem.Get()
		Or Constants.UseSeveralWarehouses.Get() Then
		
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.Transfer);
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		
		Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses;
		
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.WriteOffToExpenses);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.TransferToOperation);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.ReturnFromExploitation);
	
EndProcedure

&AtClient
Procedure SetAppearanceForOperationType()
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.Transfer") Then
		
		Items.InventoryOwnership.Visible				= False;
		Items.InventoryEditOwnership.Visible			= True;
		Items.InventoryProject.Visible					= False;
		Items.InventoryIncomeAndExpenseItems.Visible	= False;
		
	ElsIf Object.OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.WriteOffToExpenses") Then
		
		Items.InventoryOwnership.Visible				= True;
		Items.InventoryEditOwnership.Visible			= False;
		Items.InventoryProject.Visible					= True;
		Items.InventoryIncomeAndExpenseItems.Visible	= True;
		
	Else
		
		Items.InventoryOwnership.Visible				= True;
		Items.InventoryEditOwnership.Visible			= False;
		Items.InventoryProject.Visible					= False;
		Items.InventoryIncomeAndExpenseItems.Visible	= False;
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function MultipleOrdersHint()
	
	Return NStr("en = '<Multiple orders mode>'; ru = '<Режим нескольких заказов>';pl = '<Tryb wielu zamówień>';es_ES = '< Modo de órdenes múltiples>';es_CO = '< Modo de órdenes múltiples>';tr = '<Birden fazla emir modu>';it = '<Modalità ordini multipli>';de = '<Mehrfach-Bestellungen Modus>'");
	
EndFunction

&AtServer
Procedure SetWorkVisible()
	
	WorkOrderType = Type("DocumentRef.WorkOrder");
	IsWriteOffToExpenses = (Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses);
	
	IsBasisDocumentWorkOrder = (ValueIsFilled(Object.BasisDocument) And TypeOf(Object.BasisDocument) = WorkOrderType);
	IsSalesOrderWorkOrder = (ValueIsFilled(Object.SalesOrder) And TypeOf(Object.SalesOrder) = WorkOrderType);
	
	Items.InventoryWork.Visible = IsWriteOffToExpenses And (IsBasisDocumentWorkOrder Or IsSalesOrderWorkOrder);
	Items.InventoryWorkCharacteristic.Visible = Items.InventoryWork.Visible;
	
EndProcedure

#EndRegion

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns();
	
	Modified = True;
	
EndProcedure

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company, DocumentDate)
	
	StructureData = New Structure();
	StructureData.Insert("Company", DriveServer.GetCompany(Company));
	
	ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(Company, DocumentDate);
	
	StructureData.Insert("ChiefAccountant", ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released", ResponsiblePersons.WarehouseSupervisor);
	StructureData.Insert("ReleasedPosition", ResponsiblePersons.WarehouseSupervisorPositionRef);
	
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductStructure = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, BusinessLine"); 
	StructureData.Insert("BusinessLine", ProductStructure.BusinessLine);
	StructureData.Insert("MeasurementUnit", ProductStructure.MeasurementUnit);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Shows the flag showing the activity direction visible.
//
&AtServerNoContext
Function GetLinesOfBusinessVisible(OperationKind)
	
	Return OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.WriteOffToExpenses")
		Or OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.TransferToOperation");
	
EndFunction

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	StructuralUnitType = Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType");
	StructuralUnitPayeeType = Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType");
	
	IsRetail = (StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitPayeeType = Enums.BusinessUnitsTypes.Retail);
	IsRetailEarningAccounting = (StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
		Or StructuralUnitPayeeType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
	
	If StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.TransferRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.TransferRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting",
			StructureData.Source.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
		
		SetVisibleAndEnabledReservationItems(StructuralUnitType, StructuralUnitPayeeType);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.WriteOffToExpensesRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.WriteOffToExpensesRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.PassToOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.PassToOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.ReturnFromOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.ReturnFromOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	EndIf;
	
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

// Receives the data set from server for the StructuralUnitReceiverOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitPayeeOnChange(StructureData)
	
	StructuralUnitType = Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType");
	StructuralUnitPayeeType = Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType");
	
	IsRetail = (StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitPayeeType = Enums.BusinessUnitsTypes.Retail);
	IsRetailEarningAccounting = (StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
		Or StructuralUnitPayeeType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
	
	If StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.TransferSource);
		StructureData.Insert("Cell", StructureData.Recipient.TransferSourceCell);
		
		SetVisibleAndEnabledReservationItems(StructuralUnitType, StructuralUnitPayeeType);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.WriteOffToExpensesSource);
		StructureData.Insert("Cell", StructureData.Recipient.WriteOffToExpensesSourceCell);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.PassToOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.PassToOperationSourceCell);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.ReturnFromOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.ReturnFromOperationSourceCell);
		
	EndIf;
	
	ShippingAddress = "";
	ArrayOfOwners = New Array;
	ArrayOfOwners.Add(StructureData.Recipient);
	
	Addresses = ContactsManager.ObjectsContactInformation(ArrayOfOwners,
		,
		Catalogs.ContactInformationKinds.BusinessUnitsActualAddress);
	
	If Addresses.Count() > 0 Then
		
		ShippingAddress = Addresses[0].Presentation;
		
	EndIf;
	
	StructureData.Insert("ShippingAddress", ShippingAddress);
	
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
	
	If StructureData.UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.FillProductGLAccounts(StructureData);
	EndIf;
	
EndProcedure

// The procedure of processing the document operation kind change.
//
&AtServer
Procedure ProcessOperationKindChange()
	
	If ValueIsFilled(Object.OperationKind)
		And Not Object.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		User = Users.CurrentUser();
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
		MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		
		If Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses 
			Or Object.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
			
			If Not Constants.UseSeveralWarehouses.Get() Then
				Object.StructuralUnit = MainWarehouse;
			EndIf;
			
			If Not Constants.UseSeveralDepartments.Get() Then
				Object.StructuralUnitPayee = MainDepartment;
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Warehouse) Then
				Object.StructuralUnit = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Department) Then
				Object.StructuralUnitPayee = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
		ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
			
			If Not Constants.UseSeveralDepartments.Get() Then
				
				Object.StructuralUnit = MainDepartment;
				
			EndIf;
			
			If Not Constants.UseSeveralWarehouses.Get() Then
				
				Object.StructuralUnitPayee = MainWarehouse;
				
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnit, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Department) Then
				Object.StructuralUnit = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
			If (Common.ObjectAttributeValue(Object.StructuralUnitPayee, "StructuralUnitType")
					<> Enums.BusinessUnitsTypes.Warehouse) Then
				Object.StructuralUnitPayee = Catalogs.BusinessUnits.EmptyRef();
			EndIf;
			
		EndIf;
		
	EndIf;

	FillAddedColumns(True);
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure ProcessStructuralUnitOnChange(OperationKindChanging = False)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Source", Object.StructuralUnit);
	
	StructureData = GetDataStructuralUnitOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnitPayee)
		Or OperationKindChanging
		And ValueIsFilled(StructureData.StructuralUnitPayee) Then
		
		Object.StructuralUnitPayee = StructureData.StructuralUnitPayee;
		Object.CellPayee = StructureData.CellPayee;
		
	EndIf;
	
	If StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		
		Items.InventoryCostPrice.Visible = True;
		Items.InventoryAmount.Visible = True;
		
	ElsIf Not StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		
		For Each Row In Object.Inventory Do
			Row.Cost = 0;
			Row.Amount = 0;
		EndDo;
		
		Items.InventoryCostPrice.Visible = False;
		Items.InventoryAmount.Visible = False;
		
	EndIf;
	
	SetCellVisible("Cell", Object.StructuralUnit);
	
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
			StructureProductsData.Insert("UseDefaultTypeOfAccounting", StructureData.UseDefaultTypeOfAccounting);
			
			IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInBarcodeData(
				StructureProductsData, StructureData.Object, "InventoryTransfer");
			
			If StructureData.UseDefaultTypeOfAccounting Then
				GLAccountsInDocuments.FillGLAccountsInBarcodeData(StructureProductsData, StructureData.Object, "InventoryTransfer");
			EndIf;
			
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
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
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
			AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				FillPropertyValues(NewRow, BarcodeData.StructureProductsData);
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Amount = NewRow.Quantity * NewRow.Cost;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				NewRow.Amount = NewRow.Quantity * NewRow.Cost;
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
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

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillInventoryByWarehouseBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInventoryByInventoryBalances();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	
	FillAddedColumns(True);
	
EndProcedure

#EndRegion


#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'traslado del inventario';es_CO = 'transferencia de inventario';tr = 'stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company", ParentCompany);
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
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
		GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	EndIf;
	
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		FillPropertyValues(StructureData, NewRow);
		
		AddTabRowDataToStructure(ThisObject, "Inventory", StructureData, NewRow);
		
		IncomeAndExpenseItemsInDocuments.FillProductIncomeAndExpenseItems(StructureData);
		
		If StructureData.UseDefaultTypeOfAccounting Then
			GLAccountsInDocuments.FillProductGLAccounts(StructureData);
		EndIf;
		
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
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
			
			TabularSectionName	= "Inventory";
			
			// Clear inventory
			Filter = New Structure;
			Filter.Insert("Products", ClosingResult.FilterProducts);
			
			RowsToDelete = Object[TabularSectionName].FindRows(Filter);
			For Each RowToDelete In RowsToDelete Do
				WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, RowToDelete,, UseSerialNumbersBalance);
				Object[TabularSectionName].Delete(RowToDelete);
			EndDo;
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);
			
			RowsToRecalculate = Object[TabularSectionName].FindRows(Filter);
			For Each RowToRecalculate In RowsToRecalculate Do
				CalculateAmountInTabularSectionLine(RowToRecalculate);
			EndDo;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	FillAddedColumns();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("RefreshAccountingTransaction");
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertyManager.FillCheckProcessing(ThisObject, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsInDocumentsClient.GLAccountsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf IncomeAndExpenseItemsInDocumentsClient.IsIncomeAndExpenseItemsChoiceProcessing(ChoiceSource.FormName) Then
		IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsChoiceProcessing(ThisObject, SelectedValue);
	ElsIf ChoiceSource.FormName = "CommonForm.InventoryOwnership" Then
		EditOwnershipProcessingAtClient(SelectedValue.TempStorageInventoryOwnershipAddress);	
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Object.Ref.IsEmpty() And ValueIsFilled(Parameters.Basis) Then
		
		If TypeOf(Parameters.Basis) = Type("DocumentRef.WorkOrder") Then
			
			AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(
				CurrentSessionDate(),
				Common.ObjectAttributeValue(Parameters.Basis, "Company"));
			
			If AccountingPolicy.PostExpensesByWorkOrder Then
				
				MessageToUserText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Inventory consumed in %1 will charge to expenses automatically on work order completion'; ru = 'ТМЦ, потребленные в %1, будут автоматически отнесены на расходы после выполнения заказа-наряда';pl = 'Zapasy zużyte w %1 zostaną naliczone do rozchodów automatycznie po zakończeniu zlecenia pracy';es_ES = 'El inventario consumido %1se cargará a los gastos automáticamente al finalizar la orden de trabajo';es_CO = 'El inventario consumido %1se cargará a los gastos automáticamente al finalizar la orden de trabajo';tr = '%1 için kullanılan envanter, iş emri tamamlandığında masraflara otomatik yansıyacak';it = 'Le scorte consumate in %1 saranno addebitate automaticamente alle spese al completamento della commessa';de = 'Bestand verbraucht in %1 wird nach der Erfüllung des Arbeitsauftrags zu dem Aufwand automatisch zugeordnet'"),
					Parameters.Basis);
					
				CommonClientServer.MessageToUser(
					MessageToUserText,
					,
					,
					,
					Cancel);
				
				Return;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
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
	
	// Filling in responsible persons for new documents
	If Not ValueIsFilled(Object.Ref) Then
		
		ResponsiblePersons		= DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
		
		Object.ChiefAccountant = ResponsiblePersons.ChiefAccountant;
		Object.Released			= ResponsiblePersons.WarehouseSupervisor;
		Object.ReleasedPosition= ResponsiblePersons.WarehouseSupervisorPositionRef;
		
	EndIf;
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
		Or Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
		
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	FillAddedColumns();
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	SetVisibleAndEnabled();
	
	InventoryOwnershipServer.SetMainTableConditionalAppearance(ConditionalAppearance);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.InventoryTransfer.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.AttachableCommands
	AttachableCommands.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// StandardSubsystems.ObjectVersioning
	ObjectsVersioning.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.ObjectVersioning
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// StandardSubsystems.Properties
	AdditionalParameters = New Structure;
	AdditionalParameters.Insert("ItemForPlacementName", "GroupAdditionalAttributes");
	PropertyManager.OnCreateAtServer(ThisObject, AdditionalParameters);
	// End StandardSubsystems.Properties
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
	BatchesServer.AddFillBatchesByFEFOCommands(ThisObject);
	
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
	
	// Change of approved documents
	AccountingApprovalServer.OnReadAtServer(ThisObject, CurrentObject);
	// End Change of approved documents
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	
	FillAddedColumns();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertyManager.BeforeWriteAtServer(ThisObject, CurrentObject);
	// End StandardSubsystems.Properties
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(CurrentObject, Cancel, ThisObject);
	// End Change of approved documents
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// StandardSubsystems.AttachableCommands
	AttachableCommandsClient.StartCommandUpdate(ThisObject);
	// End StandardSubsystems.AttachableCommands
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	// StandardSubsystems.Properties
	PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	// End StandardSubsystems.Properties
	
	SetAppearanceForOperationType();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
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
	
	If EventName = "SerialNumbersSelection"
		And ValueIsFilled(Parameter) 
		// Form owner checkup
		And Source <> New UUID("00000000-0000-0000-0000-000000000000")
		And Source = UUID Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf;
	EndIf;
	
	// StandardSubsystems.Properties
	If PropertyManagerClient.ProcessNofifications(ThisObject, EventName, Parameter) Then
		UpdateAdditionalAttributeItems();
		PropertyManagerClient.AfterImportAdditionalAttributes(ThisObject);
	EndIf;
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

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

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
	StructureData = GetCompanyDataOnChange(Object.Company, Object.Date);
	ParentCompany = StructureData.Company;
	
	Object.ChiefAccountant = StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition= StructureData.ReleasedPosition;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	ProcessStructuralUnitOnChange(True);
	
	SetAppearanceForOperationType();
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	ProcessStructuralUnitOnChange();
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Recipient", Object.StructuralUnitPayee);
	
	StructureData = GetDataStructuralUnitPayeeOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = StructureData.StructuralUnit;
		Object.Cell = StructureData.Cell;
	EndIf;
	
	StructureData.Property("ShippingAddress", Object.ShippingAddress);
	
	SetCellVisible("CellPayee", Object.StructuralUnitPayee);
	
EndProcedure

// Procedure - Opening event handler of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		And Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - Opening event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOpening(Item, StandardProcessing)
	
	If Items.StructuralUnitPayee.ListChoiceMode
		And Not ValueIsFilled(Object.StructuralUnitPayee) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
		
EndProcedure

&AtClient
Procedure BasisDocumentOnChange(Item)
	BasisDocumentOnChangeAtServer();
EndProcedure

&AtClient
Procedure SalesOrderOnChange(Item)
	SetWorkVisible();
EndProcedure

#Region TabularSectionAttributeEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
	StructureData.Insert("IncomeAndExpenseItems",	TabularSectionRow.IncomeAndExpenseItems);
	StructureData.Insert("IncomeAndExpenseItemsFilled", TabularSectionRow.IncomeAndExpenseItemsFilled);
	
	AddTabRowDataToStructure(ThisObject, "Inventory", StructureData);
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryCharacteristicStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.Inventory.CurrentData;
	
	If DriveClient.UseMatrixForm(CurrentRow.Products) Then
		
		StandardProcessing = False;
		
		TabularSectionName	= "Inventory";
		SelectionParameters	= DriveClient.GetMatrixParameters(ThisObject, TabularSectionName, False);
		NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseVariantsSelection", ThisObject);
		OpenForm("Catalog.ProductsCharacteristics.Form.MatrixFormWithAvailableQuantity",
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
Procedure InventoryBatchOnChange(Item)
	
	InventoryBatchOnChangeAtClient();
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow And Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	EndIf;
	
	IncomeAndExpenseItemsInDocumentsClient.TableOnStartEnd(Item, NewRow, Copy);
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	ElsIf Field.Name = "InventoryIncomeAndExpenseItems" Then
		StandardProcessing = False;
		IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
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
		ElsIf TableCurrentColumn.Name = "InventoryIncomeAndExpenseItems"
			And Not CurrentData.IncomeAndExpenseItemsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			IncomeAndExpenseItemsInDocumentsClient.OpenIncomeAndExpenseItemsForm(ThisObject, SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	GLAccountsInDocumentsClient.OpenProductGLAccountsForm(ThisObject, SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - OnChange event handler of the Primecost input field.
//
&AtClient
Procedure InventoryCostPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;

EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Cost = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryIncomeAndExpenseItemsStartChoice(Item, ChoiceData, StandardProcessing)
	
	IncomeAndExpenseItemsInDocumentsClient.IncomeAndExpenseItemsStartChoice(ThisObject, "Inventory", StandardProcessing);
	
EndProcedure

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor",
		ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"InventoryTransfer.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'; ru = 'Загрузка запасов из файла';pl = 'Import zapasów z pliku';es_ES = 'Importar el inventario del archivo';es_CO = 'Importar el inventario del archivo';tr = 'Stoku dosyadan içe aktar';it = 'Importazione delle scorte da file';de = 'Bestand aus Datei importieren'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings,
		NotifyDescription, ThisObject);
	
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

#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	
	CopyRowsTabularPart("Inventory");
	
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	
	PasteRowsTabularPart("Inventory");
	
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
		
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructureData = New Structure;
		StructureData.Insert("Products", Row.Products);
		StructureData.Insert("UseDefaultTypeOfAccounting", UseDefaultTypeOfAccounting);
		
		AddTabRowDataToStructure(ThisObject, TabularPartName, StructureData, Row);
		StructureData = GetDataProductsOnChange(StructureData);
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructureData.MeasurementUnit;
		EndIf;
			
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Procedure AddTabRowDataToStructure(Form, TabName, StructureData, TabRow = Undefined)
	
	If TabRow = Undefined Then
		TabRow = Form.Items[TabName].CurrentData;
	EndIf;
	
	StructureData.Insert("TabName", 			TabName);
	StructureData.Insert("Object",				Form.Object);
	StructureData.Insert("Batch",				TabRow.Batch);
	
	If TabName = "Inventory" Then 
		StructureData.Insert("ExpenseItem", TabRow.ExpenseItem);
	EndIf;
	
	If StructureData.UseDefaultTypeOfAccounting Then
		
		StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
		StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
		
		StructureData.Insert("InventoryGLAccount",			TabRow.InventoryGLAccount);
		StructureData.Insert("InventoryToGLAccount",		TabRow.InventoryToGLAccount);
		StructureData.Insert("InventoryReceivedGLAccount",	TabRow.InventoryReceivedGLAccount);
		StructureData.Insert("ConsumptionGLAccount",		TabRow.ConsumptionGLAccount);
		StructureData.Insert("SignedOutEquipmentGLAccount",	TabRow.SignedOutEquipmentGLAccount);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = IncomeAndExpenseItemsInDocuments.GetObjectParameters(Object);
	
	If UseDefaultTypeOfAccounting Then
		GLAccountsInDocuments.CompleteObjectParameters(Object, ObjectParameters);
	EndIf;
	
	StructureArray = New Array();
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetStructureData(ObjectParameters);
	GLAccountsInDocuments.CompleteStructureData(StructureData, ObjectParameters);
	StructureArray.Add(StructureData);
	
	GLAccountsInDocuments.FillGLAccountsInArray(Object, StructureArray, GetGLAccounts);
	
EndProcedure

&AtServer
Function GetObjectParameters(Val FormObject) Export

	ObjectParameters = New Structure;
	ObjectParameters.Insert("Ref", FormObject.Ref);
	ObjectParameters.Insert("Company", FormObject.Company);
	ObjectParameters.Insert("Date", FormObject.Date);
	ObjectParameters.Insert("StructuralUnit", FormObject.StructuralUnit);
	ObjectParameters.Insert("StructuralUnitPayee", FormObject.StructuralUnitPayee);
	ObjectParameters.Insert("StructuralUnitPayeeType", Common.ObjectAttributeValue(FormObject.StructuralUnitPayee, "StructuralUnitType"));
	ObjectParameters.Insert("OperationKind", FormObject.OperationKind);
	
	Return ObjectParameters;
	
EndFunction

&AtServer
Procedure BasisDocumentOnChangeAtServer()
	
	FillAddedColumns(True);
	SetWorkVisible();
	
EndProcedure

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion