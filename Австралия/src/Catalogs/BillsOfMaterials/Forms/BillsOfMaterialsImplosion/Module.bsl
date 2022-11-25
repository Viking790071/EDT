#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Parameters.Property("Products", Products);
	
	If Not ValueIsFilled(Products) Then
		Cancel = True;
		Return;
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'BOM implosion: %1'; ru = 'Компонент в спецификациях: %1';pl = 'Komponent w specyfikacjach materiałowych: %1';es_ES = 'Implosión de BOM: %1';es_CO = 'Implosión de BOM: %1';tr = 'Ürün reçetelerinde malzeme: %1';it = 'Implosione distinta base: %1';de = 'Zusammenbruch der Stückliste: %1'"),
		Products);
	
	SetVisibleAndEnabled();
	FillVariantsChoiseList();
	
	If Not IsProdUseCharacteristics Then
		FillTree();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	ExpandAll(Undefined);
	
EndProcedure

#EndRegion

#Region BOMStructureFormTableItemsEventHandlers

&AtClient
Procedure BOMStructureSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	
	BOMStructureLine = Items.BOMStructure.CurrentData;
	
	If Field.Name = "BOMStructureProduct" Or Not ValueIsFilled(BOMStructureLine.BillOfMaterials) Then
		
		ShowValue(, BOMStructureLine.Product);
		
	Else
		
		ShowValue(, BOMStructureLine.BillOfMaterials);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	
	FillTree();
	
	If BOMStructure.GetItems().Count() = 0 Then
		CommonClientServer.MessageToUser(NStr("en = 'This component is not included in other BOMs.'; ru = 'Этот компонент не включен в другие спецификации.';pl = 'Inne specyfikacje materiałowe nie zawierają tego komponentu.';es_ES = 'Este componente no está incluido en otras BOM.';es_CO = 'Este componente no está incluido en otras BOM.';tr = 'Bu malzeme diğer Ürün reçetelerine dahil değil.';it = 'Questa componente non è inclusa in altre distinte base.';de = 'Diese Komponente ist nicht in anderen Stücklisten enthalten.'"));
	Else
		ExpandAll(Undefined);
	EndIf;
	
EndProcedure

&AtClient
Procedure ExpandAll(Command)
	
	LevelBOMs = BOMStructure.GetItems();
	For Each LevelBOM In LevelBOMs Do
		Items.BOMStructure.Expand(LevelBOM.GetID(), True);
	EndDo;
	
EndProcedure

&AtClient
Procedure CollapseAll(Command)
	
	CollapseRecursively(BOMStructure.GetItems());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisibleAndEnabled()
	
	IsProdUseCharacteristics = Common.ObjectAttributeValue(Products, "UseCharacteristics");
	If Not IsProdUseCharacteristics Then
		Characteristic = Undefined;
	EndIf;
	
	Items.FormGenerate.Visible 		= IsProdUseCharacteristics;
	Items.Characteristic.Visible 	= IsProdUseCharacteristics;
	
EndProcedure

&AtServer
Procedure FillTree()
	
	MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
	
	AllVariants = Not ValueIsFilled(Characteristic);
	
	ParamToFillTree = New Structure;
	ParamToFillTree.Insert("Products", 			Products);
	ParamToFillTree.Insert("Characteristic", 	Characteristic);
	ParamToFillTree.Insert("AllVariants", 		AllVariants);
	
	TableToFillTree = TableToFillTree(ParamToFillTree, MaxNumberOfBOMLevels);
	
	Tree = FormAttributeToValue("BOMStructure");
	
	Tree.Rows.Clear();
	
	ProductFilter	= New Structure("Component", Products);
	Level_0Rows		= TableToFillTree.FindRows(ProductFilter);
	
	For Each Row In Level_0Rows Do
		
		Root					= Tree.Rows.Add();
		Root.Product			= Row.Component;
		Root.Characteristic		= Row.CompCharacteristic;
		Root.BillOfMaterials	= Row.CompBOM;
		
		Node_1 = Root.Rows.Add();
		FillPropertyValues(Node_1, Row);
		Node_1.Count = 1;
		
		ProductFilter	= ProductFilter(Row);
		Level_1Rows		= TableToFillTree.FindRows(ProductFilter);
		
		AddLevelRow(Node_1, Level_1Rows, TableToFillTree, Tree, 1);
		
	EndDo;
	
	For Each Row In Tree.Rows Do
		
		LastRow = Undefined;
		CalcBOMLevel(Row.Rows, LastRow);
		
		Row.BOMLevel = Row.Rows.Total("Count", True);
		
		FillQuantity(LastRow, TableToFillTree);
		
	EndDo;
	
	ValueToFormAttribute(Tree, "BOMStructure");
	
EndProcedure

&AtServer
Procedure CalcBOMLevel(LevelRows, LastRow)
	
	For Each Row In LevelRows Do
		
		If Row.Rows.Count() = 0 Then
			LastRow = Row;
		Else
			CalcBOMLevel(Row.Rows, LastRow);
		EndIf;
		
		Row.BOMLevel = Row.Rows.Total("Count", True);
		
	EndDo;
	
EndProcedure

&AtServer
Procedure AddLevelRow(PrevLevelRow, LevelRows, TableToFillTree, Tree, Val CurLevel)
	
	If CurLevel >= MaxNumberOfBOMLevels Then
		Return;
	EndIf;
	
	For Each Row In LevelRows Do
		
		If Row = LevelRows[0] Then
			NewTreeRow = PrevLevelRow.Rows.Add();
			FillPropertyValues(NewTreeRow, Row);
		Else
			// If it is not first line 
			// need to add new root element with all upper nodes
			NewRoot = AddNewRoot(Tree, PrevLevelRow);
			NewTreeRow = NewRoot.Rows.Add();
			FillPropertyValues(NewTreeRow, Row);
		EndIf;
		
		ProductFilter = ProductFilter(Row);
		NextLevelRows = TableToFillTree.FindRows(ProductFilter);
		
		AddLevelRow(NewTreeRow, NextLevelRows, TableToFillTree, Tree, CurLevel + 1);
		
		NewTreeRow.Count = 1;
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function TableToFillTree(Parameters, Val MaxNumberOfBOMLevels)
	
	TempTablesManager = GetActiveBOMs();
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	BillsOfMaterialsContent.Products AS Component,
	|	BillsOfMaterialsContent.Characteristic AS CompCharacteristic,
	|	CASE
	|		WHEN VALUETYPE(BillsOfMaterialsContent.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN BillsOfMaterialsContent.Quantity
	|		ELSE BillsOfMaterialsContent.Quantity * IsNull(UOM.Factor, 1)
	|	END AS CompQuantity,
	|	TT_BillsOfMaterials.Ref AS BillOfMaterials,
	|	TT_BillsOfMaterials.Product AS Product,
	|	TT_BillsOfMaterials.Characteristic AS Characteristic,
	|	TT_BillsOfMaterials.Quantity AS Quantity
	|INTO LevelTable_0
	|FROM
	|	TT_BillsOfMaterials AS TT_BillsOfMaterials
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TT_BillsOfMaterials.Ref = BillsOfMaterialsContent.Ref
	|			AND (BillsOfMaterialsContent.Products = &Products)
	|			AND &AllVariants
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON BillsOfMaterialsContent.MeasurementUnit = UOM.Ref";
	
	QueryTextFragment1 = "";
	QueryTextFragment2 = DriveClientServer.GetQueryDelimeter() + "
		|SELECT
		|	LevelTable.Component AS Component,
		|	LevelTable.CompCharacteristic AS CompCharacteristic,
		|	LevelTable.CompQuantity AS CompQuantity,
		|	LevelTable.Product AS Product,
		|	LevelTable.Characteristic AS Characteristic,
		|	LevelTable.Quantity AS Quantity,
		|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS CompBOM,
		|	LevelTable.BillOfMaterials AS BillOfMaterials
		|FROM
		|	LevelTable_0 AS LevelTable";
	
	For i = 1 To MaxNumberOfBOMLevels-1 Do
		
		Text1 = DriveClientServer.GetQueryDelimeter() + "
			|SELECT
			|	BillsOfMaterialsContent.Products AS Component,
			|	BillsOfMaterialsContent.Characteristic AS CompCharacteristic,
			|	CASE
			|		WHEN VALUETYPE(BillsOfMaterialsContent.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
			|			THEN BillsOfMaterialsContent.Quantity
			|		ELSE BillsOfMaterialsContent.Quantity * IsNull(UOM.Factor, 1)
			|	END AS CompQuantity,
			|	LevelTable.BillOfMaterials AS CompBOM,
			|	TT_BillsOfMaterials.Ref AS BillOfMaterials,
			|	TT_BillsOfMaterials.Product AS Product,
			|	TT_BillsOfMaterials.Characteristic AS Characteristic,
			|	TT_BillsOfMaterials.Quantity AS Quantity
			|INTO %1
			|FROM
			|	%2 AS LevelTable
			|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
			|			INNER JOIN TT_BillsOfMaterials AS TT_BillsOfMaterials
			|			ON BillsOfMaterialsContent.Ref = TT_BillsOfMaterials.Ref
			|		ON LevelTable.Product = BillsOfMaterialsContent.Products
			|			AND LevelTable.Characteristic = BillsOfMaterialsContent.Characteristic
			|		LEFT JOIN Catalog.UOM AS UOM
			|		ON BillsOfMaterialsContent.MeasurementUnit = UOM.Ref";
		
		QueryTextFragment1 = QueryTextFragment1 + StrTemplate(Text1, "LevelTable_" + String(i), "LevelTable_" + String(i-1));
		
		Text2 = DriveClientServer.GetQueryUnion() + "
			|SELECT
			|	LevelTable.Component,
			|	LevelTable.CompCharacteristic,
			|	LevelTable.CompQuantity,
			|	LevelTable.Product,
			|	LevelTable.Characteristic,
			|	LevelTable.Quantity,
			|	LevelTable.CompBOM,
			|	LevelTable.BillOfMaterials
			|FROM
			|	%1 AS LevelTable";
		
		QueryTextFragment2 = QueryTextFragment2 + StrTemplate(Text2, "LevelTable_" + String(i));
		
	EndDo;
	
	Query.Text = Query.Text + QueryTextFragment1 + QueryTextFragment2;
	
	Query.SetParameter("Products", Parameters.Products);
	
	If Parameters.AllVariants Then
		Query.SetParameter("AllVariants", True);
	Else	
		Query.Text = StrReplace(Query.Text, "&AllVariants", "BillsOfMaterialsContent.Characteristic = &Characteristic");
		
		If TypeOf(Parameters.Characteristic) = Type("String") Then
			Characteristic = PredefinedValue("Catalog.ProductsCharacteristics.EmptyRef");
		Else
			Characteristic = Parameters.Characteristic;
		EndIf;
		
		Query.SetParameter("Characteristic", Characteristic);
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction

&AtServerNoContext
Function GetActiveBOMs()
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = "SELECT
	|	BillsOfMaterials.Ref AS Ref,
	|	BillsOfMaterials.Owner AS Product,
	|	BillsOfMaterials.ProductCharacteristic AS Characteristic,
	|	BillsOfMaterials.Quantity AS Quantity
	|INTO TT_BillsOfMaterials
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|WHERE
	|	NOT BillsOfMaterials.DeletionMark
	|	AND BillsOfMaterials.Status = VALUE(Enum.BOMStatuses.Active)
	|	AND BillsOfMaterials.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Production)
	|	AND BillsOfMaterials.ValidityStartDate <= &CurrentDate
	|	AND BillsOfMaterials.ValidityEndDate = DATETIME(1, 1, 1)
	|
	|UNION ALL
	|
	|SELECT
	|	BillsOfMaterials.Ref,
	|	BillsOfMaterials.Owner,
	|	BillsOfMaterials.ProductCharacteristic,
	|	BillsOfMaterials.Quantity
	|FROM
	|	Catalog.BillsOfMaterials AS BillsOfMaterials
	|WHERE
	|	NOT BillsOfMaterials.DeletionMark
	|	AND BillsOfMaterials.Status = VALUE(Enum.BOMStatuses.Active)
	|	AND BillsOfMaterials.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Production)
	|	AND BillsOfMaterials.ValidityStartDate <= &CurrentDate
	|	AND BillsOfMaterials.ValidityEndDate >= &CurrentDate";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	
	Query.Execute();
	
	Return TempTablesManager;
	
EndFunction

&AtClient
Procedure CollapseRecursively(TreeItems)
	
	For Each TreeItems_Item In TreeItems Do
		
		InTreeItems = TreeItems_Item.GetItems();
		If InTreeItems.Count() > 0 Then
			CollapseRecursively(InTreeItems);
		EndIf;
		Items.BOMStructure.Collapse(TreeItems_Item.GetID());
		
	EndDo;
	
EndProcedure

&AtServerNoContext
Function ProductFilter(Row)
	
	ProductFilter = New Structure;
	ProductFilter.Insert("Component", 			Row.Product);
	ProductFilter.Insert("CompCharacteristic", 	Row.Characteristic);
	ProductFilter.Insert("CompBOM", 			Row.BillOfMaterials);
	
	Return ProductFilter;
	
EndFunction

&AtServerNoContext
Procedure FillQuantity(LastNode, TableToFillTree, ParentProduct = Undefined, ParentQuantity = 0)
	
	If LastNode.BOMLevel = 0 Then
		FillQuantity(LastNode.Parent, TableToFillTree, LastNode.Product, ParentQuantity);
		Return;
	EndIf;
	
	ProductFilter = ProductFilter(LastNode);
	ProductFilter.Insert("Product", ParentProduct);
	Rows = TableToFillTree.FindRows(ProductFilter);
	
	If Rows.Count() Then
		Row = Rows[0];
		If LastNode.BOMLevel = 1 Then
			LastNode.Quantity = Row.CompQuantity;
		Else
			LastNode.Quantity = GetQuantity(Row, ParentQuantity);
		EndIf;
	EndIf;
	
	If LastNode.Parent <> Undefined Then
		ParentQuantity = LastNode.Quantity;
		FillQuantity(LastNode.Parent, TableToFillTree, LastNode.Product, ParentQuantity);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetQuantity(Row, ParentQuantity)
	
	Quantity = Row.CompQuantity;
	
	If Row.Quantity > 1 Then 
		Proportion = ParentQuantity / Row.Quantity;
		StrProportion = Format(Proportion, "ND=15; NFD=0");
		StrProportion = ?(StrProportion = "", "0", StrProportion);
		If Number(StrProportion) <> Proportion Then
			ReduceProportion = Format(Proportion - 0.5, "ND=15; NFD=0");
			If ReduceProportion <> "" Then
				ParentQuantity = (Number(ReduceProportion) + 1) * Row.Quantity;
			Else
				ParentQuantity = Row.Quantity;
			EndIf;
		EndIf;
	EndIf;
	
	Quantity = Quantity / Row.Quantity * ParentQuantity;
	
	Return Quantity;
	
EndFunction

&AtServer
Function AddNewRoot(Tree, TreeRow)
	
	ParentRow = TreeRow;
	RowArray = New Array;
	
	While ValueIsFilled(ParentRow) Do
		RowArray.Add(ParentRow);
		ParentRow = ParentRow.Parent;
	EndDo;
	
	RowArrayCounter = RowArray.Count()-1;
	ParentRow = Tree;
	
	While RowArrayCounter >= 0 Do
		
		NewRow = ParentRow.Rows.Add();
		FillPropertyValues(NewRow, RowArray[RowArrayCounter], "Product, Characteristic, BillOfMaterials, Quantity");
		NewRow.Count = 1;
		
		RowArrayCounter = RowArrayCounter - 1;
		ParentRow = NewRow;
		
	EndDo;
	
	Return ParentRow;
	
EndFunction

&AtServer
Procedure FillVariantsChoiseList()
	
	ChoiceList = Items.Characteristic.ChoiceList;
	ChoiceList.Clear();
	
	ChoiceList.Add(NStr("en = '<empty variant>'; ru = '<пустой вариант>';pl = '<pusty wariant>';es_ES = '<variante vacía>';es_CO = '<variante vacía>';tr = '<boş varyant>';it = '<variante vuota>';de = '<leere Variante>'"));
	
	Query = New Query;
	Query.Text = "SELECT
	|	ProductsCharacteristics.Ref AS Ref
	|FROM
	|	Catalog.ProductsCharacteristics AS ProductsCharacteristics
	|WHERE
	|	ProductsCharacteristics.Owner = &Owner
	|	AND NOT ProductsCharacteristics.DeletionMark
	|
	|ORDER BY
	|	ProductsCharacteristics.Description";
	
	Query.SetParameter("Owner", Products);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ChoiceList.Add(Selection.Ref);
	EndDo;
	
EndProcedure

#EndRegion
