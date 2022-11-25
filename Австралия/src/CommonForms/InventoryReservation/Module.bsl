
#Region Variables

&AtClient
Var IsFormClosed;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentDataTempStorageAddress = Parameters.TempStorageAddress;
	AdjustedReserved = Parameters.AdjustedReserved;
	UseAdjustedReserve = Parameters.UseAdjustedReserve;
	
	FillReservationTree();
	
	SetConditionalAppearance();
	SetVisibleItems()
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not IsFormClosed And Not Exit And Modified Then
		
		Cancel = True;
		ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
				NStr("en = 'The inventory reservation details have been changed. Do you want to apply the changes?'; ru = 'Данные резервирования запасов были изменены. Применить изменения?';pl = 'Szczegóły rezerwacji zapasów zostały zmienione. Czy chcesz akceptować zmiany?';es_ES = 'Los detalles de la reserva de stock han sido cambiados. ¿Quiere aplicar los cambios?';es_CO = 'Los detalles de la reserva de stock han sido cambiados. ¿Quiere aplicar los cambios?';tr = 'Stok rezervasyonu bilgileri değiştirildi. Değişiklikler uygulansın mı?';it = 'I dettagli della riserva delle scorte sono stati modificati. Applicare le modifiche?';de = 'Die Details der Bestandsreservierung sind geändert. Möchten Sie Änderungen verwenden?'"),
				QuestionDialogMode.YesNoCancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Document.SalesOrder.Form.EditReservationForm" Then
		ReservationTreeOrderStartChoiceServer(SelectedValue);
	EndIf;
	
EndProcedure

&AtClient
Procedure Apply(Command)
	
	UpdateDocumentReservationTable();
	
EndProcedure

#Region ReservationTreeFormTableItemsEventHandlers

&AtClient
Procedure ReservationTreeOnStartEdit(Item, NewRow, Clone)
	
	RowData = Item.CurrentData;
	
	RowData._KeyTableRowIndex = RowData.GetParent()._KeyTableRowIndex;
	
	If Clone Then
		CheckRowQuantity(RowData);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReservationTreeBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	RowData = Item.CurrentData;
	If RowData = Undefined Or RowData._UpperLevel And Clone Then
		Cancel = True;
	ElsIf Not RowData._UpperLevel And Not Clone Then
		Cancel = True;
		Items.ReservationTree.CurrentRow = RowData.GetParent().GetID();
		Items.ReservationTree.AddRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure ReservationTreeBeforeDeleteRow(Item, Cancel)
	
	RowData = Item.CurrentData;
	If RowData = Undefined Or RowData._UpperLevel Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReservationTreeQuantityOrderedOnChange(Item)
	
	RowData = Items.ReservationTree.CurrentData;
	CheckRowQuantity(RowData);
	
EndProcedure

&AtClient
Procedure ReservationTreeOrderStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	FormParameters = New Structure;
	FormParameters.Insert("DocumentDataTempStorageAddress", DocumentDataTempStorageAddress);
	FormParameters.Insert("CurrentRow", CurrentRowKeyTableRowIndex());
	
	OpenForm("Document.SalesOrder.Form.EditReservationForm", FormParameters, ThisObject);
	
EndProcedure

&AtServer
Procedure ReservationTreeOrderStartChoiceServer(Order)
	
	CurrentRow = Items.ReservationTree.CurrentRow;
	TreeInventoryRow = ReservationTree.FindByID(CurrentRow);
	TreeInventoryRow.Order = Order;
	ParentRow = TreeInventoryRow.GetParent();
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	
	SearchSalesOrder = New Structure(
		"Products,
		|Characteristic,
		|Order,
		|SalesOrder");
	
	FillPropertyValues(SearchSalesOrder, ParentRow);
	SearchSalesOrder.SalesOrder = Order;
	
	Table_Balances = DocumentData.Parameters.Table_Balances;
	BalanceRows = Table_Balances.FindRows(SearchSalesOrder);
			
	If BalanceRows.Count()>0 Then
		TreeInventoryRow.ShipmentDate = BalanceRows[0].ShipmentDate;
	EndIf;
	
EndProcedure

#EndRegion

&AtClient
Procedure AdjustedReservedOnChange(Item)
	
	If Not AdjustedReserved Then
		ShowQueryBox(New NotifyDescription("AdjustedReservedOnChangeClient", ThisObject),
			NStr("en = 'The ""Adjust reserved quantity manually"" checkbox will be cleared. The reserved product quantity will be repopulated. Continue?'; ru = 'Флажок ""Скорректировать зарезервированное количество вручную"" будет снят. Зарезервированное количество номенклатуры будет перезаполнено. Продолжить?';pl = 'Pole wyboru ""Skoryguj zarezerwowaną ilość ręcznie"" zostanie odznaczone. Zarezerwowana ilość zostanie wypełniona ponownie. Kontynuować?';es_ES = 'La casilla ""Ajustar manualmente la cantidad reservada"" estará desmarcada. La cantidad de productos reservados será repoblada. ¿Continuar?';es_CO = 'La casilla ""Ajustar manualmente la cantidad reservada"" estará desmarcada. La cantidad de productos reservados será repoblada. ¿Continuar?';tr = '""Rezerve edilen miktarı manuel olarak düzelt"" onay kutusu temizlenecek. Rezerve edilen ürün miktarı yeniden doldurulacak. Devam edilsin mi?';it = 'La casella di controllo ""Quantità riserva corretta manualmente sarà deselezionata. La quantità di prodotto riservato sarà ricompilata. Continuare?';de = 'Das Kontrollkästchen ""Reservierte Menge manuell anpassen"" wird deaktiviert. Die reservierte Produktmenge wird neu ausgefüllt. Weiter?'"),
			QuestionDialogMode.YesNo);
	Else
		SetVisibleItems();
	EndIf;
		
EndProcedure

&AtClient
Procedure AdjustedReservedOnChangeClient(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		UpdateReservationTable();
	ElsIf QueryResult = DialogReturnCode.No Then
		AdjustedReserved = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisibleItems()

	Items.AdjustedReserved.ReadOnly = UseAdjustedReserve;
	Items.ReservationTree.ReadOnly = Not AdjustedReserved;
 
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	
	Synonym = DocumentData.Parameters.DocMetadata.Synonym;
	
	TextTemplate = NStr("en = 'Quantity in %1'; ru = 'Количество в %1';pl = 'Ilość w %1';es_ES = 'Cantidad en %1';es_CO = 'Cantidad en %1';tr = 'Miktar cinsi %1';it = 'Quantità in %1';de = 'Menge in %1'");
	TitleText = StringFunctionsClientServer.SubstituteParametersToString(
		TextTemplate,
		Synonym);
		
	Items.ReservationTree_BaseQuantity.Title	= TitleText;
	
EndProcedure

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		IsFormClosed = True;
		UpdateDocumentReservationTable();
	ElsIf QueryResult = DialogReturnCode.No Then
		IsFormClosed = True;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure UpdateDocumentReservationTable()
	
	TempStorageInventoryReservationAddress = PutInventoryReservationToTempStorage();
	IsFormClosed = True;
	Close();
	NotifyChoice(New Structure("TempStorageInventoryReservationAddress", TempStorageInventoryReservationAddress));
	
EndProcedure

&AtServer
Function PutInventoryReservationToTempStorage()
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	KeyTable = DocumentData.KeyTable;
	InventoryReservation = DocumentData.DocObject.InventoryReservation;
	
	InventoryReservation.Clear();
	
	UseOrder = DocumentData.Parameters.UseOrder;
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	
	For Each TreeInventoryRow In ReservationTree.GetItems() Do
		
		KeyTableRow = KeyTable.Get(TreeInventoryRow._KeyTableRowIndex);
		
		For Each TreeReservationRow In TreeInventoryRow.GetItems() Do
			
			If TreeReservationRow.Quantity = 0 Then
				Continue;
			EndIf;
			
			InventoryReservationRow = InventoryReservation.Add();
			FillPropertyValues(InventoryReservationRow, KeyTableRow, KeyFieldsString);
			InventoryReservationRow.SalesOrder = TreeReservationRow.Order;
			
			If UseOrder Then
				InventoryReservationRow.Order = TreeInventoryRow.Order;
			EndIf;
			
			InventoryReservationRow.Quantity = TreeReservationRow.Quantity;
		EndDo;
		
	EndDo;
	
	StructureData = New Structure;
	StructureData.Insert("ReservationTable", InventoryReservation);
	StructureData.Insert("AdjustedReserved", AdjustedReserved);
	
	Return PutToTempStorage(StructureData);
	
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"ReservationTree._UpperLevel",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(
		NewConditionalAppearance,
		"ReservationTreeOrder,
		|ReservationTreeQuantityOrdered");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
EndProcedure

&AtServer
Procedure FillReservationTree()
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	
	TreeInventoryRows = ReservationTree.GetItems();
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	KeyFieldsString = KeyFieldsString + ",Order";
	
	Table_Balances = DocumentData.Parameters.Table_Balances;
	
	TableMeasurementUnits = New ValueTable;
	TableMeasurementUnits.Columns.Add("MeasurementUnit", New TypeDescription("String"));
	TableMeasurementUnits.Columns.Add("Quantity", New TypeDescription("Number"));
	
	KeyTable = DocumentData.KeyTable;
	
	Search = New Structure(
		"Products,
		|Characteristic,
		|Order");
	
	SearchSalesOrder = New Structure(
		"Products,
		|Characteristic,
		|Order,
		|SalesOrder");
	
	For Each KeyTableRow In KeyTable Do
		
		If Not ValueIsFilled(KeyTableRow.Order) Then
			Continue;
		EndIf;
		
		TreeInventoryRow = TreeInventoryRows.Add();
		FillPropertyValues(TreeInventoryRow, KeyTableRow);
		
		TreeInventoryRow._UpperLevel = True;
		TreeInventoryRow._KeyTableRowIndex = DocumentData.KeyTable.IndexOf(KeyTableRow);
		
		SearchFilter = New Structure(KeyFieldsString);
		FillPropertyValues(SearchFilter, KeyTableRow);
		
		FillPropertyValues(Search, KeyTableRow);
		
		TreeInventoryRow.Quantity = KeyTableRow.Quantity;
		
		BalanceRows = Table_Balances.FindRows(Search);
		QuantityBalance = 0;
		
		For Each BalanceRow In BalanceRows Do
			
			If Not ValueIsFilled(BalanceRow.SalesOrder) Then
				Continue;
			EndIf;
			
			QuantityBalance = QuantityBalance + BalanceRow.Quantity;
		EndDo;
		
		DocumentRows = DocumentData.DocObject.Inventory.FindRows(SearchFilter);

		If DocumentRows.Count() > 1 Then
			TreeInventoryRow._BaseQuantity = TreeInventoryRow.Quantity;
		EndIf;
		
		LineNumbers = New Array;
		TableMeasurementUnits.Clear();
		
		For Each InventoryRow In DocumentRows Do
			LineNumbers.Add(InventoryRow.LineNumber);
			
			NewRow = TableMeasurementUnits.Add();
			FillPropertyValues(NewRow, InventoryRow);
			
		EndDo;
		
		TableMeasurementUnits.GroupBy("MeasurementUnit", "Quantity");
		
		TreeInventoryRow.LineNumber = StringFunctionsClientServer.StringFromSubstringArray(LineNumbers, ", ");
		TreeInventoryRow._BaseQuantity = StringFromSubstringValueTable(TableMeasurementUnits, ", ");
		
		TreeInventoryRow.QuantityOrder = QuantityBalance;
		TreeReservationRows = TreeInventoryRow.GetItems();
		
		ReservationRows = DocumentData.DocObject.InventoryReservation.FindRows(SearchFilter);
		For Each ReservationRow In ReservationRows Do
			
			If Not ValueIsFilled(ReservationRow.SalesOrder) Then
				Continue;
			EndIf;
			
			TreeReservationRow = TreeReservationRows.Add();
			TreeReservationRow.Order = ReservationRow.SalesOrder;
			
			FillPropertyValues(SearchSalesOrder, ReservationRow);
			SearchSalesOrder.Order = TreeInventoryRow.Order;
			
			BalanceRows = Table_Balances.FindRows(SearchSalesOrder);
			
			If BalanceRows.Count()>0 Then
				TreeReservationRow.ShipmentDate = BalanceRows[0].ShipmentDate;
				TreeReservationRow.QuantityOrder = BalanceRows[0].Quantity;
			EndIf;
			
			TreeReservationRow.Quantity = ReservationRow.Quantity;
			TreeReservationRow._KeyTableRowIndex = TreeInventoryRow._KeyTableRowIndex;
			
		EndDo;
		
		If TreeInventoryRow.Quantity > QuantityBalance Then
			TreeInventoryRow.Quantity = QuantityBalance;
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckRowQuantity(RowData)
	
	ParentRow = RowData.GetParent();
	
	CurrentTotalQuantity = 0;
	For Each ChildRow In ParentRow.GetItems() Do
		CurrentTotalQuantity = CurrentTotalQuantity + ChildRow.Quantity;
	EndDo;
	
	AvailableQuantity = ParentRow.Quantity - CurrentTotalQuantity + RowData.Quantity;
	
	RowData.Quantity = Min(RowData.Quantity, AvailableQuantity);
	
EndProcedure

&AtServer
Procedure UpdateReservationTable()
	
	TreeInventoryRows = ReservationTree.GetItems();
	TreeInventoryRows.Clear();
	
	FillReservationTree();
	
	SetVisibleItems();
	
EndProcedure

&AtServer
Function CurrentRowKeyTableRowIndex()
	
	CurrentRow = Items.ReservationTree.CurrentRow;
	TreeInventoryRow = ReservationTree.FindByID(CurrentRow);
	ParentRow = TreeInventoryRow.GetParent();
	
	CurrentRow = New Structure;
	CurrentRow.Insert("Products",		ParentRow.Products);
	CurrentRow.Insert("Characteristic",	ParentRow.Characteristic);
	CurrentRow.Insert("Order",			ParentRow.Order);
	CurrentRow.Insert("SalesOrder",		TreeInventoryRow.Order);

	Return CurrentRow;
	
EndFunction

&AtServerNoContext
Function StringFromSubstringValueTable(Table, Separator = ",")
	
	Result = "";
	
	For Index = 0 To Table.Count()-1 Do
		Substring = Table[Index];
		
		If TypeOf(Substring) <> Type("String") Then
			Substring = String(Substring.Quantity) + " " + Substring.MeasurementUnit;
		EndIf;
		
		If Index > 0 Then
			Result = Result + Separator;
		EndIf;
		
		Result = Result + Substring;
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion

#Region Initialize

IsFormClosed = False;

#EndRegion