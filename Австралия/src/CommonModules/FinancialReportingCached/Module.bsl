#Region Public

Function NonstandardPicture(ItemType, AuxiliaryDataName = Undefined) Export
	
	TempTablesManager = FinancialReportingServer.PicturesIndexesTable();
	
	Query = New Query("SELECT TOP 1 * FROM PicturesIndexesTable WHERE ItemType = &ItemType");
	Query.TempTablesManager = TempTablesManager;
	If Not ValueIsFilled(ItemType) Then
		Query.SetParameter("ItemType", Enums.FinancialReportItemsTypes.EmptyRef());
	Else
		Query.SetParameter("ItemType", ItemType);
	EndIf;
	If ValueIsFilled(AuxiliaryDataName) Then
		Query.Text = Query.Text + " AND AuxiliaryItemName = &AuxiliaryDataName";
		Query.SetParameter("AuxiliaryDataName", AuxiliaryDataName);
	EndIf;
	PicturesIndexesTable = Query.Execute().Unload();
	
	If PicturesIndexesTable.Count() Then
		Return PicturesIndexesTable[0].PictureIndex;
	EndIf;
	
	Return 0;
	
EndFunction

Function ValidReportsItemsCombinations() Export
	
	CombinationsTable = CommonValidItemsCombinations();
	
	// Upper level - (parent is empty)
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("AccountingDataIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("UserDefinedFixedIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("UserDefinedCalculatedIndicator"));
	
	// Table
	Array = New Array;
	Array.Add(ItemType("TableComplex"));
	Array.Add(ItemType("TableIndicatorsInRows"));
	Array.Add(ItemType("TableIndicatorsInColumns"));
	AddCombinationsRow(CombinationsTable, Array, ItemType("Rows"));
	AddCombinationsRow(CombinationsTable, Array, ItemType("Columns"));
	
	// Simple table indicators in rows
	TableType = ItemType("TableIndicatorsInRows");
	// Rows
	RowsColumns = ItemType("Rows");
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("AccountingDataIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("UserDefinedFixedIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("UserDefinedCalculatedIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("AccountingDataIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedFixedIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("AccountingDataIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("UserDefinedFixedIndicator"), RowsColumns, TableType);
	
	// Simple table indicators in columns
	TableType = ItemType("TableIndicatorsInColumns");
	// Columns
	RowsColumns = ItemType("Columns");
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("AccountingDataIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("UserDefinedFixedIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("AccountingDataIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedFixedIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("AccountingDataIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("UserDefinedFixedIndicator"), RowsColumns, TableType);
	
	// Other item interrelations inherent to all items
	// dimensions relevant
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Dimension"));
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Group"));
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("AccountingDataIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("UserDefinedFixedIndicator"));
	
	// groups relevant
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Group"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Dimension"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("GroupTotal"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("AccountingDataIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedFixedIndicator"));
	
	RowsColumnsArray = New Array;
	RowsColumnsArray.Add(ItemType("Rows"));
	RowsColumnsArray.Add(ItemType("Columns"));
	
	TableTypeArray = New Array;
	TableTypeArray.Add(ItemType("TableComplex"));
	TableType = ItemType("TableComplex");
	
	// table item
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("TableItem"), , TableType);
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Group"), , TableType);
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Dimension"), , TableType);
	AddCombinationsRow(CombinationsTable, ItemType("TableItem"), ItemType("TableItem"), RowsColumnsArray, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("TableItem"), RowsColumnsArray, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("GroupTotal"), RowsColumnsArray, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("TableItem"), RowsColumnsArray, TableType);
	
	TableTypeArray = New Array();
	TableTypeArray.Add(ItemType("TableIndicatorsInRows"));
	TableTypeArray.Add(ItemType("TableIndicatorsInColumns"));
	// dimensions, groups and items in any type of table
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Dimension"), , TableTypeArray);
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Group"), , TableTypeArray);
	// groups and dimensions interrelations
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Dimension"), RowsColumnsArray, TableTypeArray);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Group"), RowsColumnsArray, TableTypeArray);
	// groups along themselves interrelations
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Group"), RowsColumnsArray, TableTypeArray);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("GroupTotal"), RowsColumnsArray, TableTypeArray);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Dimension"), RowsColumnsArray, TableTypeArray);
	
	CombinationsTable.Indexes.Add("Item, Parent");
	CombinationsTable.Indexes.Add("Item, Parent, RowsColumns, TableType");
	
	Return CombinationsTable;
	
EndFunction

Function InvalidReportsItemsCombinations() Export

	Type = New TypeDescription("EnumRef.FinancialReportItemsTypes");
	
	CombinationsTable = New ValueTable;
	CombinationsTable.Columns.Add("Item", Type);
	CombinationsTable.Columns.Add("Parent", Type);
	
	AddCombinationsRow(CombinationsTable, ItemType("UserDefinedCalculatedIndicator"), ItemType("UserDefinedCalculatedIndicator"));
	
	CombinationsTable.Indexes.Add("Item");
	
	Return CombinationsTable;

EndFunction

#EndRegion

#Region Private

Function CommonValidItemsCombinations()
	
	Type = New TypeDescription("EnumRef.FinancialReportItemsTypes");
	
	CombinationsTable = New ValueTable;
	CombinationsTable.Columns.Add("Item",		 Type);
	CombinationsTable.Columns.Add("Parent",		 Type);
	CombinationsTable.Columns.Add("RowsColumns", Type);
	CombinationsTable.Columns.Add("TableType",	 Type);
	
	// Upper level (parent is empty)
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("ReportTitle"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("NonEditableText"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("EditableText"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("UserDefinedCalculatedIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("TableComplex"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("TableIndicatorsInRows"));
	AddCombinationsRow(CombinationsTable, ItemType("EmptyRef"), ItemType("TableIndicatorsInColumns"));
	
	// Table
	Array = New Array();
	Array.Add(ItemType("TableComplex"));
	Array.Add(ItemType("TableIndicatorsInRows"));
	Array.Add(ItemType("TableIndicatorsInColumns"));
	AddCombinationsRow(CombinationsTable, Array, ItemType("Rows"));
	AddCombinationsRow(CombinationsTable, Array, ItemType("Columns"));
	
	// Simple table - indicators in rows
	TableType = ItemType("TableIndicatorsInRows");
	// Rows
	RowsColumns = ItemType("Rows");
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("UserDefinedCalculatedIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedCalculatedIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("UserDefinedCalculatedIndicator"), RowsColumns, TableType);
	
	// Simple table - indicators in columns
	TableType = ItemType("TableIndicatorsInColumns");
	// Columns
	RowsColumns = ItemType("Columns");
	AddCombinationsRow(CombinationsTable, RowsColumns, ItemType("UserDefinedCalculatedIndicator"), , TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedCalculatedIndicator"), RowsColumns, TableType);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"),ItemType("UserDefinedCalculatedIndicator"), RowsColumns, TableType);
	
	// Complex table
	TableType = ItemType("TableComplex");
	
	// Other item interrelations inherent to all items
	// dimensions relevant
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Dimension"));
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("UserDefinedCalculatedIndicator"));
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Group"));
	
	// groups relevant
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Group"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Dimension"));
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("UserDefinedCalculatedIndicator"));
		
	TableTypeArray = New Array();
	TableTypeArray.Add(ItemType("TableComplex"));
	
	RowsColumnsArray = New Array();
	RowsColumnsArray.Add(ItemType("Rows"));
	RowsColumnsArray.Add(ItemType("Columns"));
	
	// Items of "all" type
	// dimensions, groups and items in any type of table
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Dimension"),, TableTypeArray);
	AddCombinationsRow(CombinationsTable, RowsColumnsArray, ItemType("Group"),,    TableTypeArray);
	// groups and dimensions interrelations
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Dimension"), RowsColumnsArray, TableTypeArray);
	AddCombinationsRow(CombinationsTable, ItemType("Dimension"), ItemType("Group"), RowsColumnsArray, TableTypeArray);
	// groups along themselves interrelations
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Group"), RowsColumnsArray, TableTypeArray);
	AddCombinationsRow(CombinationsTable, ItemType("Group"), ItemType("Dimension"), RowsColumnsArray, TableTypeArray);
	
	Return CombinationsTable;
	
EndFunction

Procedure AddCombinationsRow(ValidCombinationsTable, Parent, Item, RowsColumns = Undefined, TableType = Undefined)
	
	If TypeOf(Parent) = Type("Array") Then
		For Each ParentItem In Parent Do
			AddCombinationsRow(ValidCombinationsTable, ParentItem, Item, RowsColumns, TableType);
		EndDo;
	ElsIf TypeOf(Item) = Type("Array") Then
		For Each ItemItem In Item Do
			AddCombinationsRow(ValidCombinationsTable, Parent, ItemItem, RowsColumns, TableType);
		EndDo;
	ElsIf TypeOf(RowsColumns) = Type("Array") Then
		For Each RowsColumnsItem In RowsColumns Do
			AddCombinationsRow(ValidCombinationsTable, Parent, Item, RowsColumnsItem, TableType);
		EndDo;
	ElsIf TypeOf(TableType) = Type("Array") Then
		For Each TableTypeItem In TableType Do
			AddCombinationsRow(ValidCombinationsTable, Parent, Item, RowsColumns, TableTypeItem);
		EndDo;
	Else
		
		Structure = New Structure;
		Structure.Insert("Parent", Parent);
		Structure.Insert("Item", Item);
		Structure.Insert("RowsColumns", RowsColumns);
		Structure.Insert("TableType", TableType);
		
		NewRow = ValidCombinationsTable.Add();
		FillPropertyValues(NewRow, Structure);
		
	EndIf;
	
EndProcedure

Function ItemType(ItemTypeName)
	
	Return PredefinedValue("Enum.FinancialReportItemsTypes." + ItemTypeName);
	
EndFunction

#EndRegion
