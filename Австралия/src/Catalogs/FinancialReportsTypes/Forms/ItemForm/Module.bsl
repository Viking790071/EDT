
#Region Variables

&AtClient
Var ItemsTypesCache;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandartProcessing)
	
	SetConditionalAppearance();
	ReportsSet = Parameters.ReportsSet;
	
	CombinationTable = FinancialReportingCached.ValidReportsItemsCombinations();
	ValidCombinationsCache = CreateCacheFromCombinationTable(CombinationTable);
	
	CombinationTable = FinancialReportingCached.InvalidReportsItemsCombinations();
	InvalidCombinationsCache = CreateCacheFromCombinationTable(CombinationTable);
	
	RefreshNewItemsTreeAtServer();
	RefreshReportTreeAtServer(Parameters.CopyingValue);
	RefreshFormTitle();
	
	If ValueIsFilled(Parameters.CurrentReportItem) Then
		
		ReportItemsRow = FinancialReportingClientServer.ChildItem(
		ReportItems, "ReportItem", Parameters.CurrentReportItem);
		
		If ReportItemsRow <> Undefined Then
			Items.ReportItems.CurrentRow = ReportItemsRow.GetID();
		EndIf;
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandReportTree();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ReportItemsTree = FormAttributeToValue("ReportItems");
	Catalogs.FinancialReportsItems.WriteReportTypeStructure(CurrentObject.Ref, ReportItemsTree, CurrentObject.DeletionMark);
	
	CurrentRow = Items.ReportItems.CurrentRow;
	ReportItemsRow = ReportItems.FindByID(CurrentRow);
	CurrentReportItem = ReportItemsRow.ReportItem;
	
	RefreshReportTreeAtServer();
	
	ReportItemsRow = FinancialReportingClientServer.ChildItem(
		ReportItems, 
		"ReportItem", 
		CurrentReportItem);
	
	If ReportItemsRow <> Undefined Then
		Items.ReportItems.CurrentRow = ReportItemsRow.GetID();
	EndIf;
	
	RefreshFormTitle();

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Items.ReportItems.Expand(ReportItems.GetItems()[0].GetID(), True);
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_UserDefinedFinancialReportIndicator" Then
		
		RefreshNewItemsTreeAtServer();
		ReportItemsRow = FinancialReportingClientServer.ChildItem(
			NewItemsTree, 
			"ReportItem", 
			Source);
		
		If ReportItemsRow <> Undefined Then
			Items.NewItemsTree.CurrentRow = ReportItemsRow.GetID();
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "Catalog.FinancialReportsTypes.Form.ChoiceForm" Then
		If ValueIsFilled(SelectedValue) Then
			ReportTypeFilter = SelectedValue;
			RefreshExistingItemsTree();
			FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure NewItemsQuickSearchOnChange(Item)
	
	RefreshNewItemsTreeAtServer();
	
EndProcedure

&AtClient
Procedure ExistingItemsQuickSearchOnChange(Item)
	
	RefreshExistingItemsTree();
	If ValueIsFilled(ReportTypeFilter) Then
		FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportTypeFilterOnChange(Item)
	
	RefreshExistingItemsTree();
	FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	
EndProcedure

&AtClient
Procedure ReportTypeFilterStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	FormParameters = New Structure("ExcludeReports", Object.Ref);
	OpenForm("Catalog.FinancialReportsTypes.ChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonClient.ShowCommentEditingForm(
		Item.EditText, 
		ThisObject, 
		"Object.Comment");
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersNewItemsTree

&AtClient
Procedure NewItemsTreeSelection(Item, SenderTreeRows, Field, StandardProcessing)
	
	DraggedRowParentTree = "NewItemsTree";
	RowsArray = New Array;
	RowsArray.Add(SenderTreeRows);
	RowID = Items.ReportItems.CurrentRow;
	AddToReportStructure(RowsArray, RowID);
	
EndProcedure

&AtClient
Procedure NewItemsTreeDragStart(Item, DragParameters, Perform)
	
	DraggedRowParentTree = "NewItemsTree";
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersExistingItemsTree

&AtClient
Procedure ExistingItemsTreeSelection(Item, RowSelected, Field, StandardProcessing)
	
	DraggedRowParentTree = "ExistingItemsTree";
	RowID = Items.ReportItems.CurrentRow;
	AddToReportStructure(RowSelected, RowID);
	
EndProcedure

&AtClient
Procedure ExistingItemsTreeDragStart(Item, DragParameters, Perform)
	
	DraggedRowParentTree = "ExistingItemsTree";
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersReportItems

&AtClient
Procedure ReportItemsSelection(Item, RowSelected, Field, StandardProcessing)
	
	StandardProcessing = False;
	EditReportItem();
	
EndProcedure

&AtClient
Procedure ReportItemsDragStart(Item, DragParameters, Perform)
	
	DraggedRowParentTree = "ReportItems";
	
EndProcedure

&AtClient
Procedure ReportItemsDragCheck(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	AddingToStructureIsAllowed = True;
	
	If TypeOf(DragParameters.Value) = Type("Array") Then
		For Each ItemTypeRow In DragParameters.Value Do
			AddingToStructureIsAllowed = DraggingIsAllowed(ItemTypeRow, Row);
			If Not AddingToStructureIsAllowed Then
				Break;
			EndIf;
		EndDo;
	Else
		AddingToStructureIsAllowed = DraggingIsAllowed(DragParameters.Value, Row);
	EndIf;
	
	If AddingToStructureIsAllowed Then
		If DragParameters.Action <> DragAction.Move
			And DragParameters.Action <> DragAction.Copy Then
			DragParameters.Action = DragAction.Move;
		EndIf;
	Else
		DragParameters.Action = DragAction.Cancel;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportItemsDrag(Item, DragParameters, StandardProcessing, Row, Field)
	
	StandardProcessing = False;
	RowsArray = DragParameters.Value;
	If TypeOf(DragParameters.Value) <> Type("Array") Then
		RowsArray = New Array;
		RowsArray.Add(DragParameters.Value);
	EndIf;
	
	If DraggedRowParentTree = Item.Name Then
		For Each DraggedRow In RowsArray Do
			MoveDraggedRow(ReportItems, DraggedRow, Row, DragParameters.Action = DragAction.Copy);
		EndDo;
	Else
		If Row = Undefined Then
			RootRow = FinancialReportingClientServer.RootItem(ReportItems);
			Row = RootRow.GetID();
		EndIf;
		AddToReportStructure(RowsArray, Row);
	EndIf;
	Modified = True;
	
EndProcedure

&AtClient
Procedure ReportItemsBeforeAddRow(Item, Cancel, Clone, Parent, IsFolder)
	
	If (Item.CurrentData.ItemType = ItemType("EmptyRef")
		Or Item.CurrentData.ItemType = ItemType("Columns")
		Or Item.CurrentData.ItemType = ItemType("Rows")
		Or Item.CurrentData.ItemType = ItemType("GroupTotal"))
		And Clone Then
		Cancel = True;
	EndIf;
	
	If Clone And Not Cancel Then
		Cancel = True;
		RowCopy = CopyRow(ReportItems, Item.CurrentData);
		Modified = True;
	EndIf;
	
EndProcedure

&AtClient
Procedure ReportItemsBeforeDeleteRow(Item, Cancel)
	
	ReportItemsRow = Items.ReportItems.CurrentData;
	ItemType = ReportItemsRow.ItemType;
	
	If (ItemType = ItemType("EmptyRef") 
		And ReportItemsRow.GetParent() = Undefined)
		Or ItemType = ItemType("Columns")
		Or ItemType = ItemType("Rows")
		Or ItemType = ItemType("ConfigureCells") Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	If ValueIsFilled(ReportItemsRow.ReportItem)
		And Not ReportItemsRow.IsLinked Then
		
		If FinancialReportingServerCall.HasReferences(ReportItemsRow.ReportItem) Then
			
			FormParameters = New Structure("ReportItem", ReportItemsRow.ReportItem);
			FormParameters.Insert("DeletionMode", True);
			If ItemType = ItemType("TableIndicatorsInRows")
				Or ItemType = ItemType("TableIndicatorsInColumns")
				Or ItemType = ItemType("TableComplex")
				Or ItemType = ItemType("Group")
				Or ItemType = ItemType("GroupTotal") Then
				FormParameters.Insert("DeleteAll", True);
			EndIf;
			
			OpenForm("Catalog.FinancialReportsTypes.Form.LinksListForm",
				FormParameters,
				ThisObject);
			Cancel = True;
			Return;
			
		EndIf;
	EndIf;
	
	Table = FinancialReportingClientServer.RootItem(ReportItemsRow, ItemType("TableComplex"));
	If Table <> Undefined Then
		ConfigureCells = FinancialReportingClientServer.ChildItem(Table, "ItemType", ItemType("ConfigureCells"));
		ClearDeletedReportItems(ConfigureCells.GetID(), ReportItemsRow.GetID());
	EndIf;
	
	PutToTempStorage(Undefined, ReportItemsRow.ItemStructureAddress);
	ReportItemsRow.ItemStructureAddress = "";
	
EndProcedure

&AtClient
Procedure ReportItemsBeforeRowChange(Item, Cancel)
	
	Cancel = True;
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
	
	CurrentType = Item.CurrentData.ItemType;
	If Not ValueIsFilled(CurrentType)
		Or CurrentType = ItemType("Columns")
		Or CurrentType = ItemType("Rows") Then
		Return;
	EndIf;
	
	EditReportItem();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RefreshNewItemsTree(Command)
	
	RefreshNewItemsTreeAtServer();
	
EndProcedure

&AtClient
Procedure RefreshReportItemsTree(Command)
	
	RefreshReportTreeAtServer();
	ExpandReportTree();
	
EndProcedure

&AtClient
Procedure FindNewItem(Command)
	
	RefreshNewItemsTreeAtServer();
	
EndProcedure

&AtClient
Procedure FindExistingItem(Command)
	
	RefreshExistingItemsTree();
	If ValueIsFilled(ReportTypeFilter) Then
		FinancialReportingClient.ExpandExistingItemsTree(ThisObject, ExistingItemsTree);
	EndIf;
	
EndProcedure

&AtClient
Procedure BreakItemLink(Command)
	
	If Items.ReportItems.CurrentRow = Undefined Then
		Return;
	EndIf;
	
	ReportItemsRow = Items.ReportItems.CurrentData;
	
	If Not ReportItemsRow.IsLinked Then
		Return;
	EndIf;
	
	QueryText = NStr("en = 'Break the link?'; ru = 'Разорвать ссылку?';pl = 'Przerwać połączenie?';es_ES = '¿Romper el enlace?';es_CO = '¿Romper el enlace?';tr = 'Bağlantıyı kes?';it = 'Rompere collegamento?';de = 'Die Verbindung abbrechen?'");
	AdditionalParameters = New Structure("CurrentRow", Items.ReportItems.CurrentRow);
	
	If ReportItemsRow.ItemType = ItemType("GroupTotal") Then
		QueryText = NStr("en = 'Delete item?'; ru = 'Удалить элемент?';pl = 'Usunąć pozycję?';es_ES = '¿Borrar el elemento?';es_CO = '¿Borrar el elemento?';tr = 'Öğe silinsin mi?';it = 'Eliminare elemento?';de = 'Element löschen?'");
		AdditionalParameters.Insert("Delete");
	EndIf;
	NotifyDescription = New NotifyDescription("BreakLinkQuestionHandler", ThisObject, AdditionalParameters);
	ShowQueryBox(NotifyDescription, QueryText, QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure MoveUp(Command)
	
	MoveTreeItem(ReportItems);
	
EndProcedure

&AtClient
Procedure MoveDown(Command)
	
	MoveTreeItem(ReportItems, False);
	
EndProcedure

&AtClient
Procedure OpenItemForm(Command)
	
	NewItemsTreeRow = Items.NewItemsTree.CurrentData;
	
	If NewItemsTreeRow = Undefined Or NewItemsTreeRow.IsFolder Then
		Return;
	EndIf;
	
	If NewItemsTreeRow.ItemType = ItemType("UserDefinedFixedIndicator") Then
		FormParameters = New Structure("Key", NewItemsTreeRow.ReportItem);
		OpenForm("Catalog.UserDefinedFinancialReportIndicators.Form.ItemForm", FormParameters, ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

#Region ReportItemAddingCheck

&AtClient
Function DraggingIsAllowed(TreeRow, ReceivingParent)
	
	DraggedItemType = Undefined;
	If DraggedRowParentTree = "ReportItems" Then
		ReportItemsRow = ReportItems.FindByID(TreeRow);
		DraggedItemType = ReportItemsRow.ItemType;
		IsLinked = ReportItemsRow.IsLinked;
	Else
		DraggedItemType = TreeRow.ItemType;
		IsLinked = TreeRow.IsLinked;
	EndIf;
	
	If Not ValueIsFilled(DraggedItemType)
		Or Not AddingToReportStuctureIsAllowed(DraggedItemType, ReceivingParent, IsLinked) Then
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

&AtClient
Function AddingToReportStuctureIsAllowed(Val AddedItemType, WhereToAddParentID, IsLinked)
	
	If AddedItemType = ItemType("GroupTotal") And IsLinked Then
		AddedItemType = ItemType("AccountingDataIndicator");
	EndIf;
	
	SearchStructure = New Array;
	SearchStructure.Add(AddedItemType);
	
	If WhereToAddParentID = Undefined Then
		SearchStructure.Add(ItemType("EmptyRef"));
	Else
		ParentRow = ReportItems.FindByID(WhereToAddParentID);
		SearchStructure.Add(ParentRow.ItemType);
		
		FoundRows = InvalidCombinationsCache.Get(AddedItemType);
		If FoundRows <> Undefined Then
			For Each InvalidCombination In FoundRows Do
				Item = FinancialReportingClientServer.RootItem(ParentRow, InvalidCombination.Key);
				If Item <> Undefined Then
					Return False;
				EndIf;
			EndDo;
		EndIf;
		
		Item1 = Undefined;
		
		If ParentRow.ItemType <> ItemType("Columns")
			And ParentRow.ItemType <> ItemType("Rows") Then
			
			Item1 = GetParentByType(ParentRow, ItemType("Rows"));
			If Item1 = Undefined Then
				Item1 = GetParentByType(ParentRow, ItemType("Columns"));
			EndIf;
			If Item1 <> Undefined Then
				Item1 = Item1.ItemType;
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(Item1) Then
			Item1 = ItemType("EmptyRef");
		EndIf;
		
		SearchStructure.Add(Item1);
		
		Item2 = GetParentByType(ParentRow, ItemType("TableIndicatorsInRows"));
		If Item2 = Undefined Then
			Item2 = GetParentByType(ParentRow, ItemType("TableIndicatorsInColumns"));
		EndIf;
		If Item2 = Undefined Then
			Item2 = GetParentByType(ParentRow, ItemType("TableComplex"));
		EndIf;
		If Item2 <> Undefined Then
			Item2 = Item2.ItemType;
		EndIf;
		If Not ValueIsFilled(Item2) Then
			Item2 = ItemType("EmptyRef");
		EndIf;
		
		SearchStructure.Add(Item2);
		
	EndIf;
	
	SearchPoint = ValidCombinationsCache;
	For Each SearchItem In SearchStructure Do
		
		FoundRows = SearchPoint.Get(SearchItem);
		If FoundRows = True Then
			Return True;
		ElsIf FoundRows = Undefined Then
			Return False;
		ElsIf FoundRows.Count() Then
			SearchPoint = FoundRows;
		Else
			Return False;
		EndIf;
		
	EndDo;
	
	Return True;
	
EndFunction

&AtClient
Function GetParentByType(ItemRow, ItemType)
	
	If ItemRow.ItemType = ItemType Then
		Return ItemRow;
	EndIf;
	
	Return FinancialReportingClientServer.RootItem(ItemRow, ItemType);
	
EndFunction

#EndRegion

#Region ReportItemAdding

&AtClient
Procedure AddToReportStructure(NewItems, ParentID)
	
	If ParentID = Undefined Then
		Parent = FinancialReportingClientServer.RootItem(ReportItems);
		ParentID = Parent.GetID();
	Else
		Parent = ReportItems.FindByID(ParentID);
	EndIf;
	
	For Each NewReportItem In NewItems Do
		
		ItemData = NewReportItem;
		If TypeOf(NewReportItem) = Type("Number") Then
			ItemData = ThisObject[DraggedRowParentTree].FindByID(NewReportItem);
		EndIf;
		
		If ItemData.IsFolder Then
			Continue;
		EndIf;
		
		ItemType = ItemData.ItemType;
		If Not AddingToReportStuctureIsAllowed(ItemType, ParentID, ItemData.IsLinked) Then
			Continue;
		EndIf;
		
		Modified = True;
		
		If ItemType = ItemType("TableComplex") And Not ItemData.IsLinked Then
			
			AdditionalParameters = New Structure("Parent, ItemData", Parent, ItemData);
			NotifyDescription = New NotifyDescription("OnTableTypeSelection", ThisObject, AdditionalParameters);
			OpenForm("Catalog.FinancialReportsItems.Form.TableTypeSelection",,
				ThisObject,
				,,,
				NotifyDescription,
				FormWindowOpeningMode.LockOwnerWindow);
			Continue;
		EndIf;
		
		ReceiverRows = Parent.GetItems();
		Index = FinancialReportingClientServer.NewRowIndex(ReceiverRows);// if there's a group total in the end of the group, the new row should be placed above it
		NewRow = ReceiverRows.Insert(Index);
		
		FillPropertyValues(NewRow, ItemData);
		NewRow.NonstandardPicture = NewRow.NonstandardPicture + ItemData.IsLinked;
		
		FillNewItemData(NewRow, ItemData);
		FillExistingItemData(NewRow, ItemData);
		
	EndDo;
	
	If NewRow <> Undefined Then
		If NewRow.ItemType = ItemType("UserDefinedCalculatedIndicator") And Not NewRow.IsLinked Then
			Items.ReportItems.CurrentRow = NewRow.GetID();
			EditReportItem();
		Else
			Items.ReportItems.CurrentRow = ParentID;
			Items.ReportItems.Expand(ParentID);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnTableTypeSelection(TableType, AdditionalParameters) Export
	
	If TableType = Undefined Then
		Return;
	EndIf;
	
	Parent = AdditionalParameters.Parent;
	ItemData = AdditionalParameters.ItemData;
	
	ReceiverRows = Parent.GetItems();
	NewRow = ReceiverRows.Add();
	
	FillPropertyValues(NewRow, ItemData);
	NewRow.DescriptionForPrinting = ItemData.Description;
	
	If TableType = 0 Then
		NewRow.ItemType = ItemType("TableIndicatorsInRows");
	ElsIf TableType = 1 Then
		NewRow.ItemType = ItemType("TableIndicatorsInColumns");
	ElsIf TableType = 2 Then
		NewRow.ItemType = ItemType("TableComplex");
	EndIf;
	
	ChildRows  = NewRow.GetItems();
	
	ItemType = ItemType("Columns");
	NewTableItem = ChildRows.Add();
	NewTableItem.ItemType = ItemType;
	NewTableItem.DescriptionForPrinting = String(ItemType);
	Postfix = ?(TableType = 1, "Input", "");
	NewTableItem.NonstandardPicture = FinancialReportingServerCall.NonstandardPicture(ItemType, Postfix);
	
	ItemType = ItemType("Rows");
	NewTableItem = ChildRows.Add();
	NewTableItem.ItemType = ItemType;
	NewTableItem.DescriptionForPrinting = String(ItemType);
	Postfix = ?(TableType = 0, "Input", "");
	NewTableItem.NonstandardPicture = FinancialReportingServerCall.NonstandardPicture(ItemType, Postfix);
	
	If TableType = 2 Then
		ItemType = ItemType("ConfigureCells");
		NewTableItem = ChildRows.Add();
		NewTableItem.ItemType = ItemType;
		NewTableItem.DescriptionForPrinting = String(ItemType);
		NewTableItem.NonstandardPicture = FinancialReportingServerCall.NonstandardPicture(ItemType);
	EndIf;
	
	Items.ReportItems.Expand(Parent.GetID());
	Items.ReportItems.Expand(NewRow.GetID(), True);
	Items.ReportItems.CurrentRow = NewRow.GetID();
	
EndProcedure

&AtClient
Procedure FillNewItemData(NewRow, ItemData)
	
	If ItemData.IsLinked Then
		Return;
	EndIf;
	
	ItemType = ItemData.ItemType;
	If ItemType = ItemType("TableItem") Then  
		
		ColumnsType = ItemType("Columns");
		Parent = FinancialReportingClientServer.RootItem(NewRow, ColumnsType);
		If Not Parent = Undefined Then
			NewRow.DescriptionForPrinting = NStr("en = 'Column'; ru = 'колонка';pl = 'Kolumna';es_ES = 'Columna';es_CO = 'Columna';tr = 'Sütun';it = 'Colonna';de = 'Spalte'");
		Else
			NewRow.DescriptionForPrinting = NStr("en = 'Row'; ru = 'Строка';pl = 'Wiersz';es_ES = 'Línea';es_CO = 'Línea';tr = 'Satır';it = 'Riga';de = 'Zeichenkette'");
		EndIf;
		
	ElsIf ItemType = ItemType("AccountingDataIndicator") Then
		
		NewRow.Account = ItemData.ReportItem;
		NewRow.AccountIndicatorDimension = ItemData.ReportItem;
		NewRow.TotalsType = PredefinedValue("Enum.TotalsTypes.BalanceDr");
		
	ElsIf ItemType = ItemType("UserDefinedFixedIndicator")
		Or ItemType = ItemType("Dimension") Then
		
		NewRow.AccountIndicatorDimension = ItemData.ReportItem;
		NewRow.Sort = "ASC";
		NewRow.PeriodPresentation = PredefinedValue("Enum.PeriodPresentation.EndDate");
		
	ElsIf ItemType = ItemType("Group") Then
		NewRow.OutputItemTitle = True;
		
	ElsIf ItemType = ItemType("GroupTotal") Then
		NewRow.OutputItemTitle = True;
		CurrentGroup = GetParentByType(NewRow, ItemType("Group"));
		If CurrentGroup = Undefined Then
			CurrentGroup = GetParentByType(NewRow, ItemType("Dimension"));
		EndIf;
		If CurrentGroup <> Undefined Then
			DescriptionForPrinting = NStr("en = 'Total'; ru = 'Итого';pl = 'Razem';es_ES = 'Total';es_CO = 'Total';tr = 'Toplam';it = 'Totale';de = 'Gesamt'") + " " + Lower(CurrentGroup.DescriptionForPrinting);
			NewRow.DescriptionForPrinting = DescriptionForPrinting;
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure FillExistingItemData(NewRow, ItemData)
	
	If Not ItemData.IsLinked Then
		Return;
	EndIf;
	
	ItemType = ItemData.ItemType;
	If ItemType = ItemType("AccountingDataIndicator") Then
		NewRow.AccountIndicatorDimension = ItemData.Account;
		
	ElsIf ItemType = ItemType("UserDefinedFixedIndicator") Then
		NewRow.AccountIndicatorDimension = ItemData.UserDefinedlReportingIndicator;
		
	ElsIf ItemType = ItemType("Group")
		Or ItemType = ItemType("GroupTotal")
		Or ItemType = ItemType("TableIndicatorsInRows")
		Or ItemType = ItemType("TableIndicatorsInColumns")
		Or ItemType = ItemType("TableComplex") Then
		NewRow.OutputItemTitle = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ReportItemEditing

&AtClient
Procedure EditReportItem()
	
	ReportItemsRow = Items.ReportItems.CurrentData;
	
	If ReportItemsRow.ItemType = ItemType("Columns")
		Or ReportItemsRow.ItemType = ItemType("Rows")
		Or ReportItemsRow.ItemType = ItemType("EmptyRef") Then
		Return;
	EndIf;
	
	IsRows = FinancialReportingClientServer.RootItem(ReportItemsRow, ItemType("Rows")) <> Undefined;
	If IsBlankString(ReportItemsRow.ItemStructureAddress) Then
		ReportItemsRow.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(ReportItemsRow, UUID);
	EndIf;
	If ReportItemsRow.ItemType = ItemType("ConfigureCells") Then
		FillStructureAddressBeforConfiguringCells(ReportItemsRow.GetID(), ReportItemsRow.ItemStructureAddress);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("ReportItemRowID",			ReportItemsRow.GetID());
	FormParameters.Insert("Key",						ReportItemsRow.ReportItem);
	FormParameters.Insert("ItemType", 					ReportItemsRow.ItemType);
	FormParameters.Insert("ItemAddressInTempStorage",	ReportItemsRow.ItemStructureAddress);
	FormParameters.Insert("MainStorageID",				ThisObject.UUID);
	FormParameters.Insert("ReportItems",				ThisObject.ReportItems);
	FormParameters.Insert("FormAdditionalMode",			DefineAdditionalParameters(ReportItemsRow));
	FormParameters.Insert("ShowRowCodeAndNote",			True);
	FormParameters.Insert("IsRows",						IsRows);
	
	NotifyDescription = New NotifyDescription("RefreshReportItemAfterChages", ThisObject, FormParameters);
	
	OpenForm("Catalog.FinancialReportsItems.ObjectForm", 
		FormParameters, ThisObject, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Procedure FillItemStructureAddressForConfigureCells(Rows, ItemStructureAddress, ItemAddressInTempStorageCache)
	
	For Each Item In Rows.GetItems() Do
		
		If Not Item.ItemType = ItemTypeAtServer("Columns")
			And Not Item.ItemType = ItemTypeAtServer("Rows") Then
			
			If Not ValueIsFilled(Item.ItemStructureAddress) Then
				Item.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(Item, UUID);
			EndIf;
			
			SettingsData = GetFromTempStorage(ItemStructureAddress);
			
			FoundRows = SettingsData.TableItems.FindRows(New Structure("Row", Item.ReportItem));
			For Each FoundRow In FoundRows Do
				FoundRow.Row = Item.ItemStructureAddress;
			EndDo;
			FoundRows = SettingsData.TableItems.FindRows(New Structure("Column", Item.ReportItem));
			For Each FoundRow In FoundRows Do
				FoundRow.Column = Item.ItemStructureAddress;
			EndDo;
			
			PutToTempStorage(SettingsData, ItemStructureAddress);
			ItemAddressInTempStorageCache.Insert(Item.ReportItem, Item.ItemStructureAddress);
			
		EndIf;
		
		If Not Item.ItemType = ItemTypeAtServer("ConfigureCells") Then
			FillItemStructureAddressForConfigureCells(Item, ItemStructureAddress, ItemAddressInTempStorageCache);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure FillStructureAddressBeforConfiguringCells(RowID, ItemStructureAddress)
	
	ReportItemRow = ReportItems.FindByID(RowID);
	TableComplex = ItemTypeAtServer("TableComplex");
	Table = FinancialReportingClientServer.RootItem(ReportItemRow, TableComplex);
	
	ItemAddressInTempStorageCache = New Map;
	FillItemStructureAddressForConfigureCells(Table, ItemStructureAddress, ItemAddressInTempStorageCache);
	
	SettingsData = GetFromTempStorage(ItemStructureAddress);
	For Each TableItem In SettingsData.TableItems Do
		
		If TypeOf(TableItem.Item) = Type("CatalogRef.FinancialReportsItems") Then
			TableItem.Item = FinancialReportingServerCall.PutItemToTempStorage(TableItem.Item, UUID);
		EndIf;
		If TypeOf(TableItem.Row) = Type("CatalogRef.FinancialReportsItems") Then
			TableItem.Row = ItemAddressInTempStorageCache[TableItem.Row];
		EndIf;
		If TypeOf(TableItem.Column) = Type("CatalogRef.FinancialReportsItems") Then
			TableItem.Column = ItemAddressInTempStorageCache[TableItem.Column];
		EndIf;
		
		ItemData = GetFromTempStorage(TableItem.Item);
		For Each Operand In ItemData.FormulaOperands Do
			If Not ValueIsFilled(Operand.ItemStructureAddress) Then
				Operand.ItemStructureAddress = FinancialReportingServerCall.PutItemToTempStorage(Operand.Operand, UUID);
			EndIf;
			OperandData = GetFromTempStorage(Operand.ItemStructureAddress);
			If OperandData.ItemType = ItemTypeAtServer("TableCell") Then
				ItemRef = FinancialReportingServerCall.AdditionalAttributeValue(OperandData, "CellRow");
				If TypeOf(ItemRef) = Type("CatalogRef.FinancialReportsItems") Then
					FinancialReportingServerCall.SetAdditionalAttributeValue(
						OperandData,
						"CellRow",
						ItemAddressInTempStorageCache[ItemRef]);
				EndIf;
				ItemRef = FinancialReportingServerCall.AdditionalAttributeValue(OperandData, "CellColumn");
				If TypeOf(ItemRef) = Type("CatalogRef.FinancialReportsItems") Then
					FinancialReportingServerCall.SetAdditionalAttributeValue(
						OperandData,
						"CellColumn",
						ItemAddressInTempStorageCache[ItemRef]);
				EndIf;
				PutToTempStorage(OperandData, Operand.ItemStructureAddress);
			EndIf;
		EndDo;
		PutToTempStorage(ItemData, TableItem.Item);
		
	EndDo;
	
EndProcedure

&AtClient
Function DefineAdditionalParameters(CurrentRow)
	
	AdditionalModesName = "Enum.ReportItemsAdditionalModes.";
	If CurrentRow.IsLinked Then
		Return PredefinedValue(AdditionalModesName + "LinkedItem");
	EndIf;
	If CurrentRow.ItemType = ItemType("ConfigureCells") 
		Or CurrentRow.ItemType = ItemType("UserDefinedCalculatedIndicator")
		Or CurrentRow.ItemType = ItemType("Dimension") Then
		Return PredefinedValue(AdditionalModesName + "ReportType");
	ElsIf CurrentRow.ItemType = ItemType("Group")
		Or CurrentRow.ItemType = ItemType("GroupTotal")
		Or CurrentRow.ItemType = ItemType("TableItem") Then
		Return PredefinedValue(AdditionalModesName + "ShowRowCodeAndNote");
	EndIf;
	
EndFunction

&AtClient
Procedure RefreshReportItemAfterChages(Result, AdditionalParameters) Export
	
	FillingData = FinancialReportingClientServer.NewRowFillingData();
	FillingData.Source = Result;
	FillingData.RowRecipient = AdditionalParameters.ReportItemRowID;
	FillingData.ItemAddressInTempStorage = AdditionalParameters.ItemAddressInTempStorage;
	FillingData.Field = ReportItems;
	
	FinancialReportingClientServer.FillTreeRow(FillingData);
	
	If Result <> Undefined Then
		Modified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region LinkedItemsHandlers

&AtClient
Procedure BreakLinkQuestionHandler(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		
		Modified = True;
		If AdditionalParameters.Property("Delete") Then
			ReportItemRow = ReportItems.FindByID(AdditionalParameters.CurrentRow);
			CurrentRows = ReportItemRow.GetParent().GetItems();
			CurrentRows.Delete(ReportItemRow);
		Else
			BreakLinkAtServer(AdditionalParameters.CurrentRow);
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EditLinks(Command)
	
	If Items.ReportItems.CurrentRow = Undefined Then
		ShowMessageBox(Undefined, NStr("en = 'Please select a report item.'; ru = 'Выберите элемент отчета.';pl = 'Proszę wybrać pozycję raportu.';es_ES = 'Por favor, seleccione un elemento del informe.';es_CO = 'Por favor, seleccione un elemento del informe.';tr = 'Lütfen, rapor öğesi seçin.';it = 'Selezionare un elemento del report.';de = 'Bitte wählen Sie ein Berichtselement aus.'"));
		Return;
	EndIf;
	
	ReportItemsRow = Items.ReportItems.CurrentData;
	CurrentReportItem = ReportItemsRow.ReportItem;
	If Not ValueIsFilled(CurrentReportItem) Then
		Return;
	EndIf;
	
	ItemType = ReportItemsRow.ItemType;
	If FinancialReportingServerCall.HasReferences(CurrentReportItem) Then
		FormParameters = New Structure("ReportItem", CurrentReportItem);
		FormParameters.Insert("Account", ReportItemsRow.Account);
		If ItemType = ItemType("GroupTotal")
			Or ItemType = ItemType("TableIndicatorsInRows") 
			Or ItemType = ItemType("TableIndicatorsInColumns") 
			Or ItemType = ItemType("TableComplex")
			Or ItemType = ItemType("Group") Then
			FormParameters.Insert("DeleteAll", True);
		EndIf;
		NotifyDescription = New NotifyDescription("RefreshRowAfterLinksEditing", ThisObject, FormParameters);
		OpenForm("Catalog.FinancialReportsTypes.Form.LinksListForm", FormParameters, ThisObject, , , , NotifyDescription);
		
	Else
		ShowMessageBox(Undefined, NStr("en = 'No links to the report item were found.'; ru = 'Ссылки на элемент отчета не найдены.';pl = 'Nie znaleziono odnośników do elementu raportu.';es_ES = 'No se han encontrado enlaces al elemento del informe.';es_CO = 'No se han encontrado enlaces al elemento del informe.';tr = 'Rapor ögesine giden hiçbir bağlantı bulunmadı.';it = 'Nessun collegamento all''elemento del report è stato trovato.';de = 'Es wurden keine Verbindungen zum Berichtselement gefunden.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshRowAfterLinksEditing(Result, AdditionalParameters) Export
	
	If Result = True Then
		ReportItemsRow = Items.ReportItems.CurrentData;
		ReportItemsRow.NonstandardPicture = ReportItemsRow.NonstandardPicture - 2;
	EndIf;
	
EndProcedure

#EndRegion

#Region TreeRowsProcessing

&AtClient
Procedure MoveDraggedRow(Tree, WhatID, WhereToID = Undefined, Clone = False)
	
	CurrentRow = Tree.FindByID(WhatID);
	
	If WhereToID = Undefined Then
		NewParent = FinancialReportingClientServer.RootItem(Tree);
	Else
		NewParent = Tree.FindByID(WhereToID);
	EndIf;
	
	// an item should not be moved to its subordinates
	Parent = NewParent.GetParent();
	While Parent <> Undefined Do
		If Parent = CurrentRow Then
			Return;
		EndIf;
		Parent = Parent.GetParent();
	EndDo;
	
	If Not AddingToReportStuctureIsAllowed(CurrentRow.ItemType, WhereToID, CurrentRow.IsLinked) Then
		Return;
	EndIf;
	
	If CheckInvalidItemsAfterDragging(CurrentRow, WhereToID) Then
		MessageText = NStr("en = 'Dragging canceled. Child items of the row being dragged contain invalid values.'; ru = 'Операция перетаскивания отменена. Дочерние элементы перетаскиваемой строки содержат недопустимые значения.';pl = 'Przeciąganie anulowane. Elementy potomne przeciąganego wiersza zawierają nieprawidłowe wartości.';es_ES = 'Arrastre cancelado. Los elementos derivados de la fila que se arrastra contienen valores no válidos.';es_CO = 'Arrastre cancelado. Los elementos derivados de la fila que se arrastra contienen valores no válidos.';tr = 'Sürükleme iptal edildi. Sürüklenen satırın alt ögeleri geçersiz değerler içeriyor.';it = 'Trascinamento cancellato. Gli elementi figli della riga trascinata contengono valori non validi.';de = 'Das Ziehen wurde abgebrochen. Untergeordnete Elemente der zu ziehenden Zeile enthalten ungültige Werte.'");
		ShowMessageBox(, MessageText, 60);
		Return;
	EndIf;
	
	FinancialReportingClientServer.SetNewParent(CurrentRow, NewParent, False, True, UUID, Clone);
	
	Items.ReportItems.Expand(NewParent.GetID(), True);
	
EndProcedure

&AtClient
Function CopyRow(Tree, SourceRow, NewParent = Undefined)
	
	If NewParent = Undefined Then
		NewParent = SourceRow.GetParent();
	EndIf;
	
	NewParentRows = NewParent.GetItems();
	Index = FinancialReportingClientServer.NewRowIndex(NewParentRows);// if there's a group total in the end of the group, the new row should be placed above it
	NewRow = NewParentRows.Insert(Index);
	FillPropertyValues(NewRow, SourceRow, , "ReportItem");
	
	If Not (SourceRow.ItemType = ItemType("Columns")
		Or SourceRow.ItemType = ItemType("Rows")) Then
		If ValueIsFilled(SourceRow.ItemStructureAddress) Then
			NewRow.ItemStructureAddress = CopyStorageData(SourceRow.ItemStructureAddress);
		Else
			NewRow.ItemStructureAddress = FinancialReportingClientServer.PutItemCopyToTempStorage(SourceRow, UUID);
		EndIf;
	EndIf;
	
	CurrentRowRows = SourceRow.GetItems();
	For Each SubRow In CurrentRowRows Do
		CopyRow(Tree, SubRow, NewRow);
	EndDo;
	
	Return NewRow;
	
EndFunction

&AtClient
Function CheckInvalidItemsAfterDragging(Parent, WhereToID)
	
	ParentItems = Parent.GetItems();
	For Each Item In ParentItems Do
		
		If Item.ItemType = ItemType("GroupTotal") Then
			Continue;
		EndIf;
		
		If Not AddingToReportStuctureIsAllowed(Item.ItemType, WhereToID, Item.IsLinked) Then
			Return True;
		EndIf;
		
		If CheckInvalidItemsAfterDragging(Item, WhereToID) Then
			Return True;
		EndIf;
		
	EndDo;
	
	Return False;
	
EndFunction

#EndRegion

#Region Other

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Disable editing of service items
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItems.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	
	ValueList = New ValueList;
	ValueList.Add(Enums.FinancialReportItemsTypes.EmptyRef());
	ValueList.Add(Enums.FinancialReportItemsTypes.Columns);
	ValueList.Add(Enums.FinancialReportItemsTypes.Rows);
	ItemFilter.RightValue = ValueList;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	// Disable editing of other reports items (linked items)
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItems.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.LinkedItem");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("ReadOnly", True);
	
	// Appearance of blank description items
	ItemTypes = Enums.FinancialReportItemsTypes;
	SetBlankDescriptionAppearance(ItemTypes.TableIndicatorsInRows,		NStr("en = 'Table'; ru = 'Таблица';pl = 'Tabela';es_ES = 'Tabla';es_CO = 'Tabla';tr = 'Tablo';it = 'Tabella';de = 'Tabelle'"));
	SetBlankDescriptionAppearance(ItemTypes.TableIndicatorsInColumns,	NStr("en = 'Table'; ru = 'Таблица';pl = 'Tabela';es_ES = 'Tabla';es_CO = 'Tabla';tr = 'Tablo';it = 'Tabella';de = 'Tabelle'"));
	SetBlankDescriptionAppearance(ItemTypes.TableComplex,				NStr("en = 'Table'; ru = 'Таблица';pl = 'Tabela';es_ES = 'Tabla';es_CO = 'Tabla';tr = 'Tablo';it = 'Tabella';de = 'Tabelle'"));
	SetBlankDescriptionAppearance(ItemTypes.Group,						NStr("en = 'Group'; ru = 'Группа';pl = 'Grupa';es_ES = 'Grupo';es_CO = 'Grupo';tr = 'Grup';it = 'Gruppo';de = 'Gruppe'"));
	SetBlankDescriptionAppearance(ItemTypes.GroupTotal,					NStr("en = 'Group total'; ru = 'Группа итого';pl = 'Grupa łącznie';es_ES = 'Total del Grupo';es_CO = 'Total del Grupo';tr = 'Grup toplamı';it = 'Totale gruppo';de = 'Gruppensumme'"));
	
	// Appearance of totals types of accounting data indicators
	TotalsTypes = Enums.TotalsTypes;
	SetTotalsTypeAppearance(TotalsTypes.Balance,	NStr("en = 'Opening balance'; ru = 'Начальный остаток';pl = 'Saldo początkowe';es_ES = 'Saldo de apertura';es_CO = 'Saldo de apertura';tr = 'Açılış bakiyesi';it = 'Saldo iniziale';de = 'Anfangssaldo'"),		True);
	SetTotalsTypeAppearance(TotalsTypes.BalanceDr,	NStr("en = 'Opening balance Dr'; ru = 'Начальный остаток Дт';pl = 'Saldo początkowe Wn';es_ES = 'Saldo de débito inicial';es_CO = 'Saldo de débito inicial';tr = 'Açılış borç bakiyesi';it = 'Saldo iniziale Deb';de = 'Anfangssaldo Soll'"),	True);
	SetTotalsTypeAppearance(TotalsTypes.BalanceCr,	NStr("en = 'Opening balance Cr'; ru = 'Начальный остаток Кт';pl = 'Saldo początkowe Ma';es_ES = 'Saldo de crédito inicial';es_CO = 'Saldo de crédito inicial';tr = 'Açılış alacak bakiyesi';it = 'Saldo iniziale Cred';de = 'Anfangssaldo Haben'"),	True);
	SetTotalsTypeAppearance(TotalsTypes.Balance,	NStr("en = 'Closing balance'; ru = 'Конечный остаток';pl = 'Saldo końcowe';es_ES = 'Saldo final';es_CO = 'Saldo final';tr = 'Kapanış bakiyesi';it = 'Saldo di chiusura';de = 'Abschlusssaldo'"),		False);
	SetTotalsTypeAppearance(TotalsTypes.BalanceDr,	NStr("en = 'Closing balance Dr'; ru = 'Конечный остаток Дт';pl = 'Saldo końcowe Wn';es_ES = 'Saldo de débito final';es_CO = 'Saldo de débito final';tr = 'Kapanış borç bakiyesi';it = 'Saldo di chiusura Deb';de = 'Soll-Abschlusssaldo'"),	False);
	SetTotalsTypeAppearance(TotalsTypes.BalanceCr,	NStr("en = 'Closing balance Cr'; ru = 'Конечный остаток Кт';pl = 'Saldo końcowe Ma';es_ES = 'Saldo de crédito final';es_CO = 'Saldo de crédito final';tr = 'Kapanış alacak bakiyesi';it = 'Saldo di chiusura Cred';de = 'Abschlusssaldo Haben'"),	False);
	
	// Appearance of totals types of other items
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItemsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", "");
	
	// Appearance of reverse sign field for those which have it set
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItemsReverseSign.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ReverseSign");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.InList;
	ValueList = New ValueList;
	ValueList.Add(Enums.FinancialReportItemsTypes.AccountingDataIndicator);
	ValueList.Add(Enums.FinancialReportItemsTypes.UserDefinedFixedIndicator);
	ValueList.Add(Enums.FinancialReportItemsTypes.UserDefinedCalculatedIndicator);
	ValueList.Add(Enums.FinancialReportItemsTypes.GroupTotal);
	ItemFilter.RightValue = ValueList;
	
	Item.Appearance.SetParameterValue("Text", "(-)");
	
	// Appearance of reverse sign field for those which have it unset
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItemsReverseSign.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ReverseSign");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("Text", "");
	
EndProcedure

&AtServer
Procedure SetBlankDescriptionAppearance(ItemType, BlankDescriptionText)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItemsDescriptionForPrinting.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = ItemType;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.OutputItemTitle");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	Item.Appearance.SetParameterValue("Text", BlankDescriptionText);
	
EndProcedure

&AtServer
Procedure SetTotalsTypeAppearance(TotalsType, AppearanceText, OpeningBalance)
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ReportItemsTotalsType.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.OpeningBalance");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = OpeningBalance;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.TotalsType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = TotalsType;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("ReportItems.ItemType");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = Enums.FinancialReportItemsTypes.AccountingDataIndicator;
	
	Item.Appearance.SetParameterValue("Text", AppearanceText);
	
EndProcedure

&AtServer
Procedure RefreshFormTitle()
	
	TypePresentation = NStr("en = 'Financial report template'; ru = 'Шаблон финансового отчета';pl = 'Szablon raportu finansowego';es_ES = 'Modelo de informe financiero';es_CO = 'Modelo de informe financiero';tr = 'Mali rapor şablonu';it = 'Modello report finanziario';de = 'Vorlage des Finanzberichts'");
	If Not ValueIsFilled(Object.Ref) Then
		Title = TypePresentation + " (" + NStr("en = 'creation'; ru = 'создание';pl = 'tworzenie';es_ES = 'creación';es_CO = 'creación';tr = 'oluşturma';it = 'creazione';de = 'Erstellung'") + ")";
	Else
		Title = Object.Description + " (" + TypePresentation + ")";
	EndIf;
	
EndProcedure

&AtServer
Function CreateCacheFromCombinationTable(CombinationTable, Level = 0)
	
	If Level = CombinationTable.Columns.Count() Then
		Return True;
	EndIf;
	
	Values = CombinationTable.Copy();
	CurrentColumnName = Values.Columns[Level].Name;
	Values.GroupBy(CurrentColumnName);
	
	ResultCache = New Map;
	For Each Value In Values Do
		CurrentValue = Value[CurrentColumnName];
		SelectedCombinations = CombinationTable.Copy(New Structure(CurrentColumnName, CurrentValue));
		LowerLevelCache = CreateCacheFromCombinationTable(SelectedCombinations, Level + 1);
		ResultCache.Insert(CurrentValue, LowerLevelCache);
	EndDo;
	
	Return New FixedMap(ResultCache);
	
EndFunction

&AtClient
Function ItemType(ItemTypeName)
	
	If ItemsTypesCache = Undefined Then
		ItemsTypesCache = New Map;
	EndIf;
	
	Value = ItemsTypesCache[ItemTypeName];
	If Value = Undefined Then
		Value = PredefinedValue("Enum.FinancialReportItemsTypes." + ItemTypeName);
		ItemsTypesCache.Insert(ItemTypeName, Value);
	EndIf;
	
	Return Value;
	
EndFunction

&AtServer
Function ItemTypeAtServer(ItemTypeName)
	
	Return Enums.FinancialReportItemsTypes[ItemTypeName];
	
EndFunction

&AtServer 
Procedure RefreshNewItemsTreeAtServer()
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.QuickSearch = NewItemsQuickSearch;
	
	FinancialReportingServer.RefreshNewItemsTree(ThisObject, TreeParameters);
	
EndProcedure

&AtServer 
Procedure RefreshExistingItemsTree()
	
	If Not ValueIsFilled(ExistingItemsQuickSearch)
		And Not ValueIsFilled(ReportTypeFilter) Then
		ExistingItems = ExistingItemsTree.GetItems();
		ExistingItems.Clear();
		Return;
	EndIf;
	
	TreeParameters = FinancialReportingClientServer.ItemsTreeNewParameters();
	TreeParameters.TreeItemName = "ExistingItemsTree";
	TreeParameters.ReportTypeFilter = ReportTypeFilter;
	TreeParameters.CurrentReportType = Object.Ref;
	TreeParameters.QuickSearch = ExistingItemsQuickSearch;
	
	FinancialReportingServer.RefreshExistingItemsTree(ThisObject, TreeParameters);
	
EndProcedure

&AtServer 
Procedure RefreshReportTreeAtServer(CopyingValue = Undefined)
	
	CurrentReportType = Object.Ref;
	FormID = Undefined;
	If ValueIsFilled(CopyingValue) Then
		CurrentReportType = CopyingValue;
		FormID = UUID;
	EndIf;
	
	RootPictureIndex = 100;
	ReportItemsText = NStr("en = 'Report items'; ru = 'Элементы отчета';pl = 'Pozycje raportu';es_ES = 'Elementos del informe';es_CO = 'Elementos del informe';tr = 'Rapor öğeleri';it = 'Elementi report';de = 'Berichtselemente'");
	If Not ValueIsFilled(CurrentReportType) Then
		TreeRows = ReportItems.GetItems();
		RootRow = TreeRows.Add();
		RootRow.DescriptionForPrinting = ReportItemsText;
		RootRow.ItemType = Enums.FinancialReportItemsTypes.EmptyRef();
		RootRow.NonstandardPicture = RootPictureIndex;
		Return;
	EndIf;
	
	ItemsTree = FinancialReportingServer.RefreshReportTree(CurrentReportType);
	
	RootRow = ItemsTree.Rows.Add();
	RootRow.DescriptionForPrinting = ReportItemsText;
	RootRow.ItemType = Enums.FinancialReportItemsTypes.EmptyRef();
	RootRow.NonstandardPicture = RootPictureIndex;
	
	RowNumber = 0;
	While RowNumber < ItemsTree.Rows.Count() Do
		
		Row = ItemsTree.Rows[RowNumber];
		If Row.NonstandardPicture <> RootPictureIndex Then
			FinancialReportingClientServer.SetNewParent(Row, RootRow, True, True);
			ItemsTree.Rows.Delete(Row);
			Continue;
		EndIf;
		RowNumber = RowNumber + 1;
		
	EndDo;
	
	If ValueIsFilled(CopyingValue) Then
		PutTreeIntoTempStorage(ItemsTree);
	EndIf;
	
	ValueToFormAttribute(ItemsTree, "ReportItems");
	
EndProcedure

&AtServer
Procedure ClearDeletedReportItems(ConfigureCellsRowID, CurrentRowID)
	
	ConfigureCellsRow = ReportItems.FindByID(ConfigureCellsRowID);
	CurrentRow = ReportItems.FindByID(CurrentRowID);
	
	If Not ValueIsFilled(ConfigureCellsRow.ItemStructureAddress) Then
		ConfigureCellsRow.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(ConfigureCellsRow, UUID);
	EndIf;
	ItemStructure = GetFromTempStorage(ConfigureCellsRow.ItemStructureAddress);
	FoundRows = ItemStructure.TableItems.FindRows(New Structure("Row", CurrentRow.ReportItem));
	For Each FoundRow In FoundRows Do
		ItemStructure.TableItems.Delete(FoundRow);
	EndDo;
	FoundRows = ItemStructure.TableItems.FindRows(New Structure("Row", CurrentRow.ItemStructureAddress));
	For Each FoundRow In FoundRows Do
		ItemStructure.TableItems.Delete(FoundRow);
	EndDo;
	FoundRows = ItemStructure.TableItems.FindRows(New Structure("Column", CurrentRow.ReportItem));
	For Each FoundRow In FoundRows Do
		ItemStructure.TableItems.Delete(FoundRow);
	EndDo;
	FoundRows = ItemStructure.TableItems.FindRows(New Structure("Column", CurrentRow.ItemStructureAddress));
	For Each FoundRow In FoundRows Do
		ItemStructure.TableItems.Delete(FoundRow);
	EndDo;
	PutToTempStorage(ItemStructure, ConfigureCellsRow.ItemStructureAddress);
	
EndProcedure

&AtClient
Procedure MoveTreeItem(Tree, Up = True)
	
	ItemTypeGroupTotal = ItemType("GroupTotal");
	CurrentRow = Tree.FindByID(Items.ReportItems.CurrentRow);
	Parent = CurrentRow.GetParent();
	If Parent = Undefined Then
		Return;
	EndIf;
	
	CurrentItems = Parent.GetItems();
	If CurrentItems.Count() = 1 Then
		Return;
	EndIf;
	
	CurrentIndex = CurrentItems.IndexOf(CurrentRow);
	FirstIndex = 0;
	LastIndex = CurrentItems.Count() - 1;
	
	If Up And CurrentIndex = 0 Or Not Up And CurrentIndex = LastIndex Then
		Return;
	EndIf;
	
	If CurrentRow.ItemType = ItemType("Columns")
		Or CurrentRow.ItemType = ItemType("Rows") Then
		Return;
	EndIf;
	
	GroupTotalIndex = -1;
	For Each Row In CurrentItems Do
		If Row.ItemType = ItemTypeGroupTotal And Not Row.IsLinked Then
			GroupTotalIndex = CurrentItems.IndexOf(Row);
			Break;
		EndIf;
	EndDo;
	
	If GroupTotalIndex = 0 Then
		FirstIndex = 1;
	ElsIf GroupTotalIndex = LastIndex Then
		LastIndex = LastIndex - 1;
	EndIf;
	
	Direction = ?(Up,-1,1);
	Shift = 1;
	If CurrentRow.ItemType = ItemTypeGroupTotal And Not CurrentRow.IsLinked Then
		Shift = LastIndex + 1;
		If Not Up Then
			Shift = LastIndex;
		EndIf;
	ElsIf CurrentIndex = FirstIndex And Up 
		Or CurrentIndex = LastIndex And Not Up Then
		Return;
	EndIf;
	
	CurrentItems.Move(CurrentIndex, Shift * Direction);
	Modified = True;
	
EndProcedure

&AtServer
Procedure BreakLinkAtServer(CurrentRowID)
	
	CurrentRow = ReportItems.FindByID(CurrentRowID);
	CurrentRow.ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(CurrentRow.LinkedItem, UUID);
	
	LinkedItemData = GetFromTempStorage(CurrentRow.ItemStructureAddress);
	FillPropertyValues(LinkedItemData, CurrentRow, "DescriptionForPrinting, Comment, ReverseSign");
	FinancialReportingServerCall.SetAdditionalAttributeValue(LinkedItemData, "RowCode", CurrentRow.RowCode);
	FinancialReportingServerCall.SetAdditionalAttributeValue(LinkedItemData, "Note", CurrentRow.Note);
	LinkedItemData.Ref = Undefined;
	PutToTempStorage(LinkedItemData, CurrentRow.ItemStructureAddress);
	
	ItemTree = FinancialReportingServer.RefreshReportTree(CurrentRow.LinkedItem.Owner, CurrentRow.LinkedItem);
	If ItemTree.Rows.Count() > 0 Then
		CopyItemsTree(ItemTree.Rows[0], CurrentRow);
	EndIf;
	
	CurrentRow.ReportItem = Undefined;
	CurrentRow.LinkedItem = Undefined;
	CurrentRow.IsLinked = False;
	CurrentRow.NonstandardPicture = CurrentRow.NonstandardPicture - 1;
	
EndProcedure

&AtServer
Procedure CopyItemsTree(SourceTree, Copy = Undefined, ItemsAddresses = Undefined, DeleteSource = False)
	
	CopyCellsSettingToStorage(SourceTree, ItemsAddresses);
	
	SourceRows = FinancialReportingClientServer.ChildItems(SourceTree);
	CopyRows = FinancialReportingClientServer.ChildItems(Copy);
	For Each SourceRow In SourceRows Do
		
		NewRow = CopyRows.Add();
		FillPropertyValues(NewRow, SourceRow, , "ReportItem");
		If Not SourceRow.ItemType.IsEmpty()
			And Not SourceRow.ItemType = ItemTypeAtServer("Columns")
			And Not SourceRow.ItemType = ItemTypeAtServer("Rows")
			And Not SourceRow.ItemType = ItemTypeAtServer("ConfigureCells") Then
			
			NewRow.ItemStructureAddress = PutCopyToStorage(SourceRow.ReportItem, ItemsAddresses);
			
		EndIf;
		
		If SourceRow.Rows.Count() Then
			CopyItemsTree(SourceRow, NewRow, ItemsAddresses);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure PutTreeIntoTempStorage(SourceTree, ItemsAddresses = Undefined)
	
	CopyCellsSettingToStorage(SourceTree, ItemsAddresses);
	
	SourceRows = FinancialReportingClientServer.ChildItems(SourceTree);
	For Each SourceRow In SourceRows Do
		
		If Not SourceRow.ItemType.IsEmpty()
			And Not SourceRow.ItemType = ItemTypeAtServer("Columns")
			And Not SourceRow.ItemType = ItemTypeAtServer("Rows")
			And Not SourceRow.ItemType = ItemTypeAtServer("ConfigureCells") Then
			
			SourceRow.ItemStructureAddress = PutCopyToStorage(SourceRow.ReportItem, ItemsAddresses);
			
		EndIf;
		
		SourceRow.ReportItem = Undefined;
		If SourceRow.Rows.Count() Then
			PutTreeIntoTempStorage(SourceRow, ItemsAddresses);
		EndIf;
		
	EndDo;
	
EndProcedure

&AtServer
Function PutCopyToStorage(SourceItem, ItemsAddresses = Undefined)
	
	If ItemsAddresses = Undefined Then
		ItemsAddresses = New Map;
	EndIf;
	
	ItemStructureAddress = ItemsAddresses[SourceItem];
	If ItemStructureAddress <> Undefined Then
		Return ItemStructureAddress;
	EndIf;
	ItemStructureAddress = FinancialReportingClientServer.PutItemToTempStorage(SourceItem, UUID);
	ItemData = GetFromTempStorage(ItemStructureAddress);
	ItemData.Ref = Undefined;
	ItemsAddresses.Insert(SourceItem, ItemStructureAddress);
	
	For Each Operand In ItemData.FormulaOperands Do
		Operand.ItemStructureAddress = PutCopyToStorage(Operand.Operand, ItemsAddresses);
		ItemsAddresses.Insert(Operand.Operand, Operand.ItemStructureAddress);
		Operand.Operand = Undefined;
	EndDo;
	Fields = New Structure("Row, Column, Item");
	For Each TableItem In ItemData.TableItems Do
		
		For Each Field In Fields Do
			Address = ItemsAddresses[TableItem[Field.Key]];
			If Address = Undefined Then
				Address = PutCopyToStorage(TableItem[Field.Key], ItemsAddresses);
				ItemsAddresses.Insert(TableItem[Field.Key], Address);
			EndIf;
			TableItem[Field.Key] = Address;
		EndDo;
		
	EndDo;
	PutToTempStorage(ItemData, ItemStructureAddress);
	Return ItemStructureAddress;
	
EndFunction

&AtServer
Procedure CopyCellsSettingToStorage(SourceTree, ItemsAddresses)
	
	If ItemsAddresses = Undefined Then
		ItemsAddresses = New Map;
		ItemType = Enums.FinancialReportItemsTypes.ConfigureCells;
		FoundRows = SourceTree.Rows.FindRows(New Structure("ItemType", ItemType), True);
		For Each CellsSetting In FoundRows Do
			CellsSetting.ItemStructureAddress = PutCopyToStorage(CellsSetting.ReportItem, ItemsAddresses);
			CellsSetting.ReportItem = Undefined;
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Function CopyStorageData(SourceDataAddress, ItemsAddresses = Undefined)
	
	If ItemsAddresses = Undefined Then
		ItemsAddresses = New Map;
	EndIf;
	
	SourceData = GetFromTempStorage(SourceDataAddress);
	SourceData.Ref = Undefined;
	
	For Each Operand In SourceData.FormulaOperands Do
		If ValueIsFilled(Operand.ItemStructureAddress) Then
			Operand.ItemStructureAddress = CopyStorageData(Operand.ItemStructureAddress);
		Else
			Operand.ItemStructureAddress = PutCopyToStorage(Operand.Operand, ItemsAddresses);
		EndIf;
		Operand.Operand = Undefined;
	EndDo;
	
	Fields = New Structure("Row, Column, Item");
	For Each TableItem In SourceData.TableItems Do
		
		For Each Field In Fields Do
			If TypeOf(TableItem[Field.Key]) = Type("CatalogRef.FinancialReportsItems") Then
				Address = PutCopyToStorage(TableItem[Field.Key], ItemsAddresses);
			Else
				Address = CopyStorageData(TableItem[Field.Key]);
			EndIf;
			TableItem[Field.Key] = Address;
		EndDo;
		
	EndDo;
	
	Return PutToTempStorage(SourceData, UUID);
	
EndFunction

&AtClient
Procedure ExpandReportTree()
	
	Items.ReportItems.Expand(ReportItems.GetItems()[0].GetID(), True);
	
EndProcedure

#EndRegion

#EndRegion
