#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.RoundedQuantity AS RoundedQuantity,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	Inventory.Clear();
	TableProduction = Products.Unload();
	NodesTable = TableProduction.CopyColumns("LineNumber, Quantity, MeasurementUnit, Specification");
	
	QN = New NumberQualifiers(10, 0);
	Array = New Array;
	Array.Add(Type("Number"));
	TypeDescriptionN = New TypeDescription(Array, , ,QN);
	TableProduction.Columns.Add("RoundedQuantity", TypeDescriptionN);
	
	For Each ProductLine In TableProduction Do
		
		ProductLine.RoundedQuantity = ProductLine.Quantity;
		
		If ValueIsFilled(ProductLine.Specification) Then
			
			BOM_Quantity = Common.ObjectAttributeValue(ProductLine.Specification, "Quantity");
			
			If BOM_Quantity > 1 
				And ProductLine.Quantity % BOM_Quantity > 0 Then
				
				ProductLine.RoundedQuantity = (Int(ProductLine.Quantity / BOM_Quantity) + 1) * BOM_Quantity;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Query.SetParameter("TableProduction", TableProduction);
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN TableMaterials.CalculationMethod = VALUE(Enum.BOMContentCalculationMethod.Proportional)
	|				THEN TableMaterials.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity
	|			ELSE TableMaterials.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.RoundedQuantity
	|		END) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	SelectionResult = Query.Execute();
	Inventory.Load(SelectionResult.Unload());
	Inventory.GroupBy("Products, Characteristic, Batch, MeasurementUnit, Specification, CostPercentage", "Quantity");
	
EndProcedure

// Procedure for filling the document basing on Production order.
//
Procedure FillByKitOrder(FillingData) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	KitOrder.Ref AS BasisRef,
	|	KitOrder.Posted AS BasisPosted,
	|	KitOrder.Closed AS Closed,
	|	KitOrder.OrderState AS OrderState,
	|	CASE
	|		WHEN KitOrder.OperationKind = VALUE(Enum.OperationTypesKitOrder.Assembly)
	|			THEN VALUE(Enum.OperationTypesProduction.Assembly)
	|		ELSE VALUE(Enum.OperationTypesProduction.Disassembly)
	|	END AS OperationKind,
	|	KitOrder.Start AS Start,
	|	KitOrder.Finish AS Finish,
	|	KitOrder.Ref AS BasisDocument,
	|	KitOrder.SalesOrder AS SalesOrder,
	|	KitOrder.Company AS Company,
	|	KitOrder.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN Recipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR Recipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN BusinessUnits.TransferRecipient
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN Recipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR Recipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN KitOrder.StructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN Source.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR Source.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN KitOrder.StructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN Source.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR Source.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN KitOrder.StructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	KitOrder.StructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	KitOrder.StructuralUnit.DisposalsRecipientCell AS DisposalsCell
	|FROM
	|	Document.KitOrder AS KitOrder
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON KitOrder.StructuralUnit = BusinessUnits.Ref
	|		LEFT JOIN Catalog.BusinessUnits AS Recipient
	|		ON (BusinessUnits.TransferRecipient = Recipient.Ref)
	|		LEFT JOIN Catalog.BusinessUnits AS Source
	|		ON (BusinessUnits.TransferSource = Source.Ref)
	|WHERE
	|	KitOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure(
			"OrderState, Closed, Posted",
			Selection.OrderState,
			Selection.Closed,
			Selection.BasisPosted);
		Documents.KitOrder.VerifyEnteringAbilityByKitOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	IntermediateStructuralUnit = StructuralUnit;
	FillPropertyValues(ThisObject, Selection);
	
	If ValueIsFilled(StructuralUnit) Then
			
		If Not ValueIsFilled(ProductsStructuralUnit) Then
			ProductsStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(InventoryStructuralUnit) Then
			InventoryStructuralUnit = StructuralUnit;
		EndIf;
		
		If Not ValueIsFilled(DisposalsStructuralUnit) Then
			DisposalsStructuralUnit = StructuralUnit;
		EndIf;
		
	EndIf;
	
	If IntermediateStructuralUnit <> StructuralUnit Then
		Cell = Undefined;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance,
	|	OrdersBalance.KitOrder AS KitOrder
	|FROM
	|	(SELECT
	|		KitOrdersBalance.Products AS Products,
	|		KitOrdersBalance.Characteristic AS Characteristic,
	|		KitOrdersBalance.QuantityBalance AS QuantityBalance,
	|		KitOrdersBalance.KitOrder AS KitOrder
	|	FROM
	|		AccumulationRegister.KitOrders.Balance(
	|				,
	|				KitOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS KitOrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		KitOrders.Products,
	|		KitOrders.Characteristic,
	|		CASE
	|			WHEN KitOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(KitOrders.Quantity, 0)
	|			ELSE -ISNULL(KitOrders.Quantity, 0)
	|		END,
	|		KitOrders.KitOrder
	|	FROM
	|		AccumulationRegister.KitOrders AS KitOrders
	|	WHERE
	|		KitOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.KitOrder
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|
	|ORDER BY
	|	Products,
	|	Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	KitOrder.Products.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(KitOrder.Products.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE KitOrder.Products.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	) AS Products,
	|	KitOrder.Inventory.(
	|		Products AS Products,
	|		Products.ProductsType AS ProductsType,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		CASE
	|			WHEN VALUETYPE(KitOrder.Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN 1
	|			ELSE KitOrder.Inventory.MeasurementUnit.Factor
	|		END AS Factor,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification,
	|		1 AS CostPercentage
	|	) AS Inventory
	|FROM
	|	Document.KitOrder AS KitOrder
	|WHERE
	|	KitOrder.Ref = &BasisDocument";
	
	Query.Text = Query.Text + ";";
	
	If FillingData.OperationKind = Enums.OperationTypesKitOrder.Disassembly Then
		
		TabularSectionName = "Inventory";
		Query.Text = Query.Text +
		"SELECT ALLOWED
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		KitOrderProducts.Products AS Products,
		|		KitOrderProducts.Characteristic AS Characteristic,
		|		KitOrderProducts.MeasurementUnit AS MeasurementUnit,
		|		KitOrderProducts.Specification AS Specification,
		|		KitOrderProducts.Quantity AS Quantity
		|	FROM
		|		Document.KitOrder.Products AS KitOrderProducts
		|	WHERE
		|		KitOrderProducts.Ref = &BasisDocument
		|		AND KitOrderProducts.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductionProducts.Products,
		|		ProductionProducts.Characteristic,
		|		ProductionProducts.MeasurementUnit,
		|		ProductionProducts.Specification,
		|		-ProductionProducts.Quantity
		|	FROM
		|		Document.Production.Products AS ProductionProducts
		|	WHERE
		|		ProductionProducts.Ref.Posted
		|		AND ProductionProducts.Ref.BasisDocument = &BasisDocument
		|		AND NOT ProductionProducts.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0
		|
		|ORDER BY
		|	Products,
		|	Characteristic,
		|	Specification";
		
	Else
		
		TabularSectionName = "Products";
		Query.Text = Query.Text +
		"SELECT ALLOWED
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		KitOrderInventory.Products AS Products,
		|		KitOrderInventory.Characteristic AS Characteristic,
		|		KitOrderInventory.MeasurementUnit AS MeasurementUnit,
		|		KitOrderInventory.Specification AS Specification,
		|		KitOrderInventory.Quantity AS Quantity
		|	FROM
		|		Document.KitOrder.Inventory AS KitOrderInventory
		|	WHERE
		|		KitOrderInventory.Ref = &BasisDocument
		|		AND KitOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		ProductionInventory.Products,
		|		ProductionInventory.Characteristic,
		|		ProductionInventory.MeasurementUnit,
		|		ProductionInventory.Specification,
		|		-ProductionInventory.Quantity
		|	FROM
		|		Document.Production.Inventory AS ProductionInventory
		|	WHERE
		|		ProductionInventory.Ref.Posted
		|		AND ProductionInventory.Ref.BasisDocument = &BasisDocument
		|		AND NOT ProductionInventory.Ref = &Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0
		|
		|ORDER BY
		|	Products,
		|	Characteristic,
		|	Specification";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("KitOrder,Products,Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		Selection.Next();
		For Each SelectionProducts In Selection[TabularSectionName].Unload() Do
			
			If SelectionProducts.ProductsType <> Enums.ProductsTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("KitOrder", FillingData);
			StructureForSearch.Insert("Products", SelectionProducts.Products);
			StructureForSearch.Insert("Characteristic", SelectionProducts.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = ThisObject[TabularSectionName].Add();
			FillPropertyValues(NewRow, SelectionProducts);
			
			QuantityToWriteOff = SelectionProducts.Quantity * SelectionProducts.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / SelectionProducts.Factor;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If Products.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	ElsIf Inventory.Count() > 0 Then
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
	// Fill out according to specification.
	If Products.Count() > 0 AND FillingData.Inventory.Count() = 0 Then
		FillTabularSectionBySpecification();
	EndIf;
	
	If Products.Count() > 0 Then
		FillByProductsWithBOM();
	EndIf;
	
EndProcedure

// Procedure for filling the document basing on Sales order.
//
Procedure FillUsingSalesOrder(FillingData) Export
	
	If OperationKind = Enums.OperationTypesProduction.Disassembly Then
		TabularSectionName = "Inventory";
	Else
		TabularSectionName = "Products";
	EndIf;
	
	Query = New Query( 
	"SELECT ALLOWED
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	DATEADD(SalesOrderInventory.ShipmentDate, DAY, -SalesOrderInventory.Products.ReplenishmentDeadline) AS Start,
	|	SalesOrderInventory.ShipmentDate AS Finish,
	|	SalesOrderInventory.Ref.Company AS Company,
	|	SalesOrderInventory.Ref.SalesStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipient.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferRecipientCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource
	|		ELSE VALUE(Catalog.BusinessUnits.EmptyRef)
	|	END AS InventoryStructuralUnit,
	|	CASE
	|		WHEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				OR SalesOrderInventory.Ref.SalesStructuralUnit.TransferSource.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Department)
	|			THEN SalesOrderInventory.Ref.SalesStructuralUnit.TransferSourceCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	SalesOrderInventory.Ref.SalesStructuralUnit.RecipientOfWastes AS DisposalsStructuralUnit,
	|	SalesOrderInventory.Ref.SalesStructuralUnit.DisposalsRecipientCell AS DisposalsCell,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Specification AS Specification
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|	AND (SalesOrderInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|			OR SalesOrderInventory.Products.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Assembly)
	|			OR &OperationKind = VALUE(Enum.OperationTypesProduction.Disassembly))");
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("OperationKind", OperationKind);
	
	Products.Clear();
	Inventory.Clear();
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		QueryResultSelection = QueryResult.Select();
		QueryResultSelection.Next();
		FillPropertyValues(ThisObject, QueryResultSelection);
		
		If ValueIsFilled(StructuralUnit) Then
			
			If Not ValueIsFilled(ProductsStructuralUnit) Then
				ProductsStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(InventoryStructuralUnit) Then
				InventoryStructuralUnit = StructuralUnit;
			EndIf;
			
			If Not ValueIsFilled(DisposalsStructuralUnit) Then
				DisposalsStructuralUnit = StructuralUnit;
			EndIf;
			
		EndIf;
		
		QueryResultSelection.Reset();
		While QueryResultSelection.Next() Do
		
			If ValueIsFilled(QueryResultSelection.Products) Then
			
				If QueryResultSelection.ProductsType <> Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				NewRow = ThisObject[TabularSectionName].Add();
				FillPropertyValues(NewRow, QueryResultSelection);
				
			EndIf;
		
		EndDo;
		
		If Products.Count() > 0 Then
			FillTabularSectionBySpecification();
		EndIf;
		
	Else
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 does not contain items that require production.'; ru = '%1 не содержит элементов, требующих производства.';pl = '%1 nie zawiera pozycji wymagających produkcji.';es_ES = '%1no contiene artículos que requieran producción.';es_CO = '%1no contiene artículos que requieran producción.';tr = '%1 üretim gerektiren öğe içermiyor.';it = '%1 non contiene elementi che richiedono la produzione.';de = '%1 enthält keine Positionen die Produktion bedürfen.'"),
			FillingData);
			
		Raise ErrorText;
		
	EndIf;
	
EndProcedure

Procedure FillByProductsWithBOM() Export
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	Disposals.Clear();
	TableProduction = Products.Unload();
	NodesTable = TableProduction.CopyColumns("LineNumber, Quantity, MeasurementUnit, Specification");
	
	Query.SetParameter("TableProduction", TableProduction);
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	BillsOfMaterialsByProducts.Product AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(BillsOfMaterialsByProducts.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity) AS Quantity,
	|	BillsOfMaterialsByProducts.MeasurementUnit AS MeasurementUnit
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		INNER JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON TableProduction.Specification = BillsOfMaterialsByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref
	|		LEFT JOIN Constant.UseCharacteristics AS UseCharacteristics
	|		ON (TRUE)
	|
	|GROUP BY
	|	BillsOfMaterialsByProducts.MeasurementUnit,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsByProducts.Product";
	
	Selection = Query.Execute().Unload();
	Disposals.Load(Selection);
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillUsingSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.KitOrder") Then
		FillByKitOrder(FillingData);
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	ProductsList = "";
	FOUseCharacteristics = Constants.UseCharacteristics.Get();
	For Each StringProducts In Products Do
		
		If Not ValueIsFilled(StringProducts.Products) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics AND ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsList) Then
			ProductsList = ProductsList + Chars.LF;
		EndIf;
		ProductsList = ProductsList + TrimAll(StringProducts.Products) + CharacteristicPresentation + ", " + StringProducts.Quantity + " " + TrimAll(StringProducts.MeasurementUnit);
		
	EndDo;
	
	If NOT ValueIsFilled(ProductsStructuralUnit)
		OR Common.ObjectAttributeValue(ProductsStructuralUnit, "StructuralUnitType") <> Enums.BusinessUnitsTypes.Warehouse Then
		
		SalesOrder = Documents.SalesOrder.EmptyRef();
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If Not AdjustedReserved Then
		InventoryReservationServer.FillReservationTable(ThisObject, WriteMode, Cancel);
	EndIf;

EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbersProducts, StructuralUnit, ThisObject);
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.Production.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsConsumedToDeclare(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectKitOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control
	Documents.Production.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Production.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	InventoryReservationServer.ClearReserves(ThisObject);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	If SerialNumbersProducts.Count() Then
		
		For Each ProductsLine In Products Do
			ProductsLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbersProducts.Clear();
		
	EndIf;
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf
