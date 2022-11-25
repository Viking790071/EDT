#Region Variables

&AtClient
Var FormIsClosing;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentDataTempStorageAddress = Parameters.TempStorageAddress;
	FillOwnershipTree();
	
	SetConditionalAppearance();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	If Not FormIsClosing And Not Exit Then
		
		If Modified Then
			Cancel = True;
			ShowQueryBox(New NotifyDescription("BeforeClosingQueryBoxHandler", ThisObject),
					NStr("en = 'Inventory ownership data has been modified. Do you want to apply the changes?'; ru = 'Данные владения запасов были изменены. Хотите применить изменения?';pl = 'Dane o posiadaniu zapasami zostały zmodyfikowane. Czy chcesz zastosować zmiany?';es_ES = 'Los datos de propiedad del inventario han sido modificados. ¿Quiere aplicar los cambios?';es_CO = 'Los datos de propiedad del inventario han sido modificados. ¿Quiere aplicar los cambios?';tr = 'Stok sahiplik verileri değiştirildi. Değişiklikler uygulansın mı?';it = 'I dati di proprietà delle scorte sono stati modificati. Applicare le modifiche?';de = 'Bestandseigentümerschaftsdaten wurden geändert. Möchten Sie die Änderungen verwenden?'"),
					QuestionDialogMode.YesNoCancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region OwnershipTreeFormTableItemsEventHandlers

&AtClient
Procedure OwnershipTreeOnStartEdit(Item, NewRow, Clone)
	
	RowData = Item.CurrentData;
	
	RowData._KeyTableRowIndex = RowData.GetParent()._KeyTableRowIndex;
	
	If Clone Then
		CheckRowQuantity(RowData);
	EndIf;
	
EndProcedure

&AtClient
Procedure OwnershipTreeBeforeAddRow(Item, Cancel, Clone, Parent, Folder, Parameter)
	
	RowData = Item.CurrentData;
	If RowData = Undefined Or RowData._UseSerialNumbers
		Or RowData._UpperLevel And Clone Then
		Cancel = True;
	ElsIf Not RowData._UpperLevel And Not Clone Then
		Cancel = True;
		Items.OwnershipTree.CurrentRow = RowData.GetParent().GetID();
		Items.OwnershipTree.AddRow();
	EndIf;
	
EndProcedure

&AtClient
Procedure OwnershipTreeBeforeDeleteRow(Item, Cancel)
	
	RowData = Item.CurrentData;
	If RowData = Undefined Or RowData._UseSerialNumbers Or RowData._UpperLevel Then
		Cancel = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure OwnershipTreeBaseQuantityOnChange(Item)
	
	RowData = Items.OwnershipTree.CurrentData;
	CheckRowQuantity(RowData);
	
EndProcedure

&AtClient
Procedure OwnershipTreeOwnershipOnChange(Item)
	
	OwnershipTreeOwnershipOnChangeAtServer()
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure ApplyChanges(Command)
	
	UpdateDocumentOwnershipTable();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure BeforeClosingQueryBoxHandler(QueryResult, AdditionalParameters) Export
	
	If QueryResult = DialogReturnCode.Yes Then
		FormIsClosing = True;
		UpdateDocumentOwnershipTable();
	ElsIf QueryResult = DialogReturnCode.No Then
		FormIsClosing = True;
		Close();
	EndIf;

EndProcedure

&AtClient
Procedure UpdateDocumentOwnershipTable()
	
	TempStorageInventoryOwnershipAddress = PutInventoryOwnershipToTempStorage();
	FormIsClosing = True;
	Close();
	NotifyChoice(New Structure("TempStorageInventoryOwnershipAddress", TempStorageInventoryOwnershipAddress));
	
EndProcedure

&AtServer
Function PutInventoryOwnershipToTempStorage()
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	KeyTable = DocumentData.KeyTable;
	InventoryOwnership = DocumentData.DocObject.InventoryOwnership;
	
	InventoryOwnership.Clear();
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	
	For Each TreeInventoryRow In OwnershipTree.GetItems() Do
		
		KeyTableRow = KeyTable.Get(TreeInventoryRow._KeyTableRowIndex);
		
		For Each TreeOwnershipRow In TreeInventoryRow.GetItems() Do
			
			InventoryOwnershipRow = InventoryOwnership.Add();
			FillPropertyValues(InventoryOwnershipRow, KeyTableRow, KeyFieldsString);
			InventoryOwnershipRow.Ownership = TreeOwnershipRow.Ownership;
			InventoryOwnershipRow.SerialNumber = TreeOwnershipRow.SerialNumber;
			InventoryOwnershipRow.Quantity = TreeOwnershipRow._BaseQuantity;
			
		EndDo;
		
	EndDo;
	
	Return PutToTempStorage(InventoryOwnership);
	
EndFunction

&AtServer
Procedure OwnershipTreeOwnershipOnChangeAtServer()
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	
	CurrentRow = Items.OwnershipTree.CurrentRow;
	TreeInventoryRow = OwnershipTree.FindByID(CurrentRow);
	
	KeyTableRow = DocumentData.KeyTable.Get(TreeInventoryRow._KeyTableRowIndex);
	
	SearchFilter = New Structure(KeyFieldsString);
	FillPropertyValues(SearchFilter, KeyTableRow);
	
	If KeyTableRow._UseSerialNumbers Then
		SearchFilter.Insert("SerialNumber", TreeInventoryRow.SerialNumber);
	EndIf;
	
	TreeInventoryRow._Balance = GetBalance(DocumentData.Parameters, SearchFilter, TreeInventoryRow.Ownership);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UpperLevel",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(
		NewConditionalAppearance,
		"OwnershipTreeSerialNumber,
		|OwnershipTreeOwnership");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UpperLevel",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(
		NewConditionalAppearance, "OwnershipTreeBaseQuantity");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UpperLevel",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(
		NewConditionalAppearance,
		"OwnershipTreeProducts,
		|OwnershipTreeCharacteristic,
		|OwnershipTreeBatch");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UpperLevel",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UseSerialNumbers",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OwnershipTreeSerialNumber");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "Visible", False);
	
	NewConditionalAppearance = ConditionalAppearance.Items.Add();
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UpperLevel",
		False,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddFilterItem(
		NewConditionalAppearance.Filter,
		"OwnershipTree._UseSerialNumbers",
		True,
		DataCompositionComparisonType.Equal);
	WorkWithForm.AddAppearanceField(NewConditionalAppearance, "OwnershipTreeBaseQuantity");
	WorkWithForm.AddConditionalAppearanceItem(NewConditionalAppearance, "ReadOnly", True);
	
EndProcedure

&AtServer
Procedure FillOwnershipTree()
	
	DocumentData = GetFromTempStorage(DocumentDataTempStorageAddress);
	
	TreeInventoryRows = OwnershipTree.GetItems();
	
	KeyFieldsString = StringFunctionsClientServer.StringFromSubstringArray(DocumentData.Parameters.KeyFields);
	
	For Each KeyTableRow In DocumentData.KeyTable Do
		
		TreeInventoryRow = TreeInventoryRows.Add();
		FillPropertyValues(TreeInventoryRow, KeyTableRow);
		TreeInventoryRow._UpperLevel = True;
		TreeInventoryRow._KeyTableRowIndex = DocumentData.KeyTable.IndexOf(KeyTableRow);
		
		SearchFilter = New Structure(KeyFieldsString);
		FillPropertyValues(SearchFilter, KeyTableRow);
		If KeyTableRow._IgnoreBatch And SearchFilter.Property("Batch") Then
			SearchFilter.Delete("Batch");
		EndIf;
		If SearchFilter.Property("BatchCorr") Then
			SearchFilter.Delete("BatchCorr");
		EndIf;
		
		InventoryRows = DocumentData.DocObject.Inventory.FindRows(SearchFilter);
		
		LineNumbers = New Array;
		For Each InventoryRow In InventoryRows Do
			LineNumbers.Add(InventoryRow.LineNumber);
		EndDo;
		TreeInventoryRow.LineNumber = StringFunctionsClientServer.StringFromSubstringArray(LineNumbers, ", ");
		
		TreeOwnershipRows = TreeInventoryRow.GetItems();
		
		If KeyTableRow._UseSerialNumbers Then
			
			For Each InventoryRow In InventoryRows Do
				
				SN_SearchFilter = New Structure("ConnectionKey", InventoryRow[DocumentData.Parameters.ConnectionKeyFieldName]);
				SerialNumbersRows = DocumentData.DocObject.SerialNumbers.FindRows(SN_SearchFilter);
				
				For Each SerialNumbersRow In SerialNumbersRows Do
					
					TreeOwnershipRow = TreeOwnershipRows.Add();
					TreeOwnershipRow.SerialNumber = SerialNumbersRow.SerialNumber;
					TreeOwnershipRow._BaseQuantity = 1;
					TreeOwnershipRow._UseSerialNumbers = True;
					TreeOwnershipRow._KeyTableRowIndex = TreeInventoryRow._KeyTableRowIndex;
					
					SearchFilter.Insert("SerialNumber", SerialNumbersRow.SerialNumber);
					OwnershipRows = DocumentData.DocObject.InventoryOwnership.FindRows(SearchFilter);
					If OwnershipRows.Count() > 0 Then
						TreeOwnershipRow.Ownership = OwnershipRows[0].Ownership;
					EndIf;
					
					TreeOwnershipRow._Balance = GetBalance(DocumentData.Parameters, SearchFilter, TreeOwnershipRow.Ownership);
					
				EndDo;
				
			EndDo;
			
		Else
			
			OwnershipRows = DocumentData.DocObject.InventoryOwnership.FindRows(SearchFilter);
			For Each OwnershipRow In OwnershipRows Do
				
				TreeOwnershipRow = TreeOwnershipRows.Add();
				TreeOwnershipRow.Ownership = OwnershipRow.Ownership;
				TreeOwnershipRow._BaseQuantity = OwnershipRow.Quantity;
				TreeOwnershipRow._KeyTableRowIndex = TreeInventoryRow._KeyTableRowIndex;
				
				TreeOwnershipRow._Balance = GetBalance(DocumentData.Parameters, SearchFilter, TreeOwnershipRow.Ownership);
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	HideUnusedTreeColumns();
	
EndProcedure

&AtServer
Function GetBalance(Parameters, RowKeyData, Ownership)
	
	Return InventoryOwnershipServer.GetBalanceForInventoryOwnershipForm(Parameters, RowKeyData, Ownership);
	
EndFunction

&AtServer
Procedure HideUnusedTreeColumns()
	
	ColumnItems = New Array;
	FillChildItems(Items.OwnershipTree, ColumnItems);
	
	Exceptions = New Array;
	Exceptions.Add("OwnershipTreeLineNumber");
	Exceptions.Add("OwnershipTreeProducts");
	Exceptions.Add("OwnershipTreeSerialNumber");
	Exceptions.Add("OwnershipTreeOwnership");
	Exceptions.Add("OwnershipTreeBaseQuantity");
	Exceptions.Add("OwnershipTreeBalance");
	
	For Each ColumnItem In ColumnItems Do
		
		ColumnName = ColumnItem.Name;
		
		If Exceptions.Find(ColumnName) <> Undefined Then
			Continue;
		EndIf;
		
		ColumnItem.Visible = ColumnIsUsed(ColumnItem);
		
	EndDo;
	
EndProcedure

&AtServer
Function ColumnIsUsed(ColumnItem)
	
	DataColumnName = StrReplace(ColumnItem.DataPath, "OwnershipTree.", "");
	
	For Each TreeRow In OwnershipTree.GetItems() Do
		
		If ValueIsFilled(TreeRow[DataColumnName]) Then
			
			Return True;
			
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

&AtServer
Procedure FillChildItems(ParentItem, Result)
	
	For Each ChildItem In ParentItem.ChildItems Do
		
		If TypeOf(ChildItem) = Type("FormGroup") Then
			
			FillChildItems(ChildItem, Result);
			
		ElsIf TypeOf(ChildItem) = Type("FormField") Then
			
			Result.Add(ChildItem);
			
		EndIf;
		
	EndDo;
	
EndProcedure

&AtClient
Procedure CheckRowQuantity(RowData)
	
	ParentRow = RowData.GetParent();
	
	CurrentTotalQuantity = 0;
	For Each ChildRow In ParentRow.GetItems() Do
		CurrentTotalQuantity = CurrentTotalQuantity + ChildRow._BaseQuantity;
	EndDo;
	
	AvailableQuantity = ParentRow._BaseQuantity - CurrentTotalQuantity + RowData._BaseQuantity;
	
	RowData._BaseQuantity = Min(RowData._BaseQuantity, AvailableQuantity);
	
EndProcedure

#EndRegion

#Region Initialize

FormIsClosing = False;

#EndRegion