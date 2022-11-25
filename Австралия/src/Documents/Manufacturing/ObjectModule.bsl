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

Procedure FillByProductsWithBOM(NodesTable = Undefined) Export
	
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
	
	If NodesTable = Undefined Then
		
		Disposals.Clear();
		TableProduction = Products.Unload();
		NodesTable = TableProduction.CopyColumns("LineNumber, Quantity, MeasurementUnit, Specification");
		
		Query.SetParameter("TableProduction", TableProduction);
		
	Else
		
		Query.SetParameter("TableProduction", NodesTable);
		
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(BillsOfMaterialsByProducts.LineNumber) AS StructureLineNumber,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(BillsOfMaterialsByProducts.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity) AS Quantity,
	|	BillsOfMaterialsByProducts.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsByProducts.Product AS Products
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
	|	TableProduction.Specification,
	|	BillsOfMaterialsByProducts.MeasurementUnit,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	BillsOfMaterialsByProducts.Product
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	StructureData = New Structure();
	StructureData.Insert("Company", 			Company);
	StructureData.Insert("ProcessingDate",		?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	StructureData.Insert("DocumentCurrency",	Common.ObjectAttributeValue(Company, "PresentationCurrency"));
	StructureData.Insert("PriceKind",			InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).AccountingPrice);
	StructureData.Insert("Products",			Undefined);
	StructureData.Insert("Characteristic",		Undefined);
	StructureData.Insert("Factor",				1);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Disposals.Add();
		FillPropertyValues(NewRow, Selection);
		
		StructureData.Products = Selection.Products;
		StructureData.Characteristic = Selection.Characteristic;
		
		NewRow.Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		NewRow.Amount = NewRow.Price * NewRow.Quantity;
		
	EndDo;
	
	Disposals.GroupBy("Products, Characteristic, Batch, MeasurementUnit, Price", "Quantity, Amount");
	
EndProcedure

Procedure FillInActivitiesByBOM() Export
	
	Query = New Query;

	Query.SetParameter("Production", Products);
	Query.SetParameter("GLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProgress"));
	
	Query.Text =
	"SELECT
	|	Production.Specification AS Specification,
	|	Production.MeasurementUnit AS MeasurementUnit,
	|	Production.Quantity AS Quantity
	|INTO TT_Production
	|FROM
	|	&Production AS Production
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Production.Specification AS Specification,
	|	CASE
	|		WHEN BillsOfMaterials.Quantity = 0
	|			THEN 1
	|		ELSE BillsOfMaterials.Quantity
	|	END AS SpecificationQuantity,
	|	TT_Production.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity
	|INTO TT_PreProductionWithBOM
	|FROM
	|	TT_Production AS TT_Production
	|		INNER JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON TT_Production.Specification = BillsOfMaterials.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TT_Production.MeasurementUnit = CatalogUOM.Ref
	|WHERE
	|	BillsOfMaterials.UseRouting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PreProductionWithBOM.Specification AS Specification,
	|	TT_PreProductionWithBOM.SpecificationQuantity AS SpecificationQuantity,
	|	TT_PreProductionWithBOM.Quantity AS Quantity,
	|	CASE
	|		WHEN TT_PreProductionWithBOM.SpecificationQuantity > 1
	|			THEN CASE
	|					WHEN (CAST(TT_PreProductionWithBOM.Quantity / TT_PreProductionWithBOM.SpecificationQuantity AS NUMBER(15, 0))) = TT_PreProductionWithBOM.Quantity / TT_PreProductionWithBOM.SpecificationQuantity
	|						THEN TT_PreProductionWithBOM.Quantity
	|					ELSE ((CAST(TT_PreProductionWithBOM.Quantity / TT_PreProductionWithBOM.SpecificationQuantity - 0.5 AS NUMBER(15, 0))) + 1) * TT_PreProductionWithBOM.SpecificationQuantity
	|				END
	|		ELSE TT_PreProductionWithBOM.Quantity
	|	END AS RoundedQuantity
	|INTO TT_ProductionWithBOM
	|FROM
	|	TT_PreProductionWithBOM AS TT_PreProductionWithBOM
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsOperations.Activity AS Activity,
	|	CASE
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Fixed)
	|			THEN BillsOfMaterialsOperations.Quantity
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Multiple)
	|			THEN TT_ProductionWithBOM.RoundedQuantity * BillsOfMaterialsOperations.Quantity / TT_ProductionWithBOM.SpecificationQuantity
	|		ELSE TT_ProductionWithBOM.Quantity * BillsOfMaterialsOperations.Quantity / TT_ProductionWithBOM.SpecificationQuantity
	|	END AS Quantity,
	|	BillsOfMaterialsOperations.ActivityNumber AS ActivityNumber,
	|	BillsOfMaterialsOperations.LineNumber AS LineNumber
	|INTO TT_Activities
	|FROM
	|	TT_ProductionWithBOM AS TT_ProductionWithBOM
	|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON TT_ProductionWithBOM.Specification = BillsOfMaterialsOperations.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Activities.Activity AS Activity,
	|	SUM(TT_Activities.Quantity) AS Quantity,
	|	MIN(TT_Activities.ActivityNumber) AS ActivityNumber,
	|	MIN(TT_Activities.LineNumber) AS LineNumber,
	|	&GLAccount AS GLAccount
	|FROM
	|	TT_Activities AS TT_Activities
	|
	|GROUP BY
	|	TT_Activities.Activity
	|
	|ORDER BY
	|	LineNumber,
	|	ActivityNumber";
	
	Activities.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure for filling the document basing on Production order.
//
Procedure FillByProductionOrder(FillingData) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ProductionOrder.Ref AS BasisRef,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState,
	|	CASE
	|		WHEN ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly)
	|			THEN VALUE(Enum.OperationTypesProduction.Assembly)
	|		WHEN ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Production)
	|			THEN VALUE(Enum.OperationTypesProduction.ConvertFromWIP)
	|		ELSE VALUE(Enum.OperationTypesProduction.Disassembly)
	|	END AS OperationKind,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	StructuralUnitData.TransferRecipient AS ProductsStructuralUnit,
	|	StructuralUnitData.TransferRecipientCell AS ProductsCell,
	|	StructuralUnitData.TransferSource AS InventoryStructuralUnit,
	|	StructuralUnitData.TransferSourceCell AS CellInventory,
	|	StructuralUnitData.RecipientOfWastes AS DisposalsStructuralUnit,
	|	StructuralUnitData.DisposalsRecipientCell AS DisposalsCell
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitData
	|		ON ProductionOrder.StructuralUnit = StructuralUnitData.Ref
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("OrderState", Selection.OrderState);
		VerifiedAttributesValues.Insert("Closed", Selection.Closed);
		VerifiedAttributesValues.Insert("Posted", Selection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
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
	
	StructuralUnitReserve = Common.ObjectAttributeValue(FillingData, "StructuralUnitReserve");
	If ValueIsFilled(StructuralUnitReserve) Then
		InventoryStructuralUnit = StructuralUnitReserve;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	
	"SELECT ALLOWED
	|	OrdersBalance.ProductionOrder AS ProductionOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO TT_OrdersBalance
	|FROM
	|	AccumulationRegister.ProductionOrders.Balance(, ProductionOrder = &BasisDocument) AS OrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsProductionOrders.ProductionOrder,
	|	DocumentRegisterRecordsProductionOrders.Products,
	|	DocumentRegisterRecordsProductionOrders.Characteristic,
	|	CASE
	|		WHEN DocumentRegisterRecordsProductionOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsProductionOrders.Quantity, 0)
	|	END
	|FROM
	|	AccumulationRegister.ProductionOrders AS DocumentRegisterRecordsProductionOrders
	|WHERE
	|	DocumentRegisterRecordsProductionOrders.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.ProductionOrder AS ProductionOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO TT_OrdersBalanceGrouped
	|FROM
	|	TT_OrdersBalance AS OrdersBalance
	|		INNER JOIN Catalog.Products AS ProductsData
	|		ON OrdersBalance.Products = ProductsData.Ref
	|			AND (ProductsData.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|GROUP BY
	|	OrdersBalance.ProductionOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.ProductionOrder AS ProductionOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|FROM
	|	TT_OrdersBalanceGrouped AS OrdersBalance
	|WHERE
	|	OrdersBalance.QuantityBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentProduction.Ref AS Ref
	|INTO TT_DocumentProduction
	|FROM
	|	Document.Manufacturing AS DocumentProduction
	|WHERE
	|	DocumentProduction.Posted
	|	AND DocumentProduction.BasisDocument = &BasisDocument
	|	AND NOT DocumentProduction.Ref = &Ref";
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	If FillingData.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		TabularSectionName = "Inventory";
		Query.Text = Query.Text +
		"SELECT ALLOWED
		|	ProductionOrderInventory.Products AS Products,
		|	ProductsData.ProductsType AS ProductsType,
		|	ProductionOrderInventory.Characteristic AS Characteristic,
		|	ProductionOrderInventory.Quantity AS Quantity,
		|	ISNULL(CatalogUOM.Factor, 1) AS Factor,
		|	ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
		|	ProductionOrderInventory.Specification AS Specification,
		|	1 AS CostPercentage
		|FROM
		|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
		|		LEFT JOIN Catalog.Products AS ProductsData
		|		ON ProductionOrderInventory.Products = ProductsData.Ref
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON ProductionOrderInventory.MeasurementUnit = CatalogUOM.Ref
		|WHERE
		|	ProductionOrderInventory.Ref = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		OrderForProductsProduction.Products AS Products,
		|		OrderForProductsProduction.Characteristic AS Characteristic,
		|		OrderForProductsProduction.MeasurementUnit AS MeasurementUnit,
		|		OrderForProductsProduction.Specification AS Specification,
		|		OrderForProductsProduction.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Products AS OrderForProductsProduction
		|			INNER JOIN Catalog.Products AS CatalogProducts
		|			ON OrderForProductsProduction.Products = CatalogProducts.Ref
		|				AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
		|	WHERE
		|		OrderForProductsProduction.Ref = &BasisDocument
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
		|		TT_DocumentProduction AS DocumentProduction
		|			INNER JOIN Document.Manufacturing.Products AS ProductionProducts
		|			ON DocumentProduction.Ref = ProductionProducts.Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	Else
		
		TabularSectionName = "Products";
		Query.Text = Query.Text +
		"SELECT ALLOWED
		|	ProductionOrderProducts.Products AS Products,
		|	ProductsData.ProductsType AS ProductsType,
		|	ProductionOrderProducts.Characteristic AS Characteristic,
		|	ProductionOrderProducts.Quantity AS Quantity,
		|	ISNULL(CatalogUOM.Factor, 1) AS Factor,
		|	ProductionOrderProducts.MeasurementUnit AS MeasurementUnit,
		|	ProductionOrderProducts.Specification AS Specification
		|FROM
		|	Document.ProductionOrder.Products AS ProductionOrderProducts
		|		LEFT JOIN Catalog.Products AS ProductsData
		|		ON ProductionOrderProducts.Products = ProductsData.Ref
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON ProductionOrderProducts.MeasurementUnit = CatalogUOM.Ref
		|WHERE
		|	ProductionOrderProducts.Ref = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
		|	OrdersBalance.Specification AS Specification,
		|	SUM(OrdersBalance.Quantity) AS Quantity
		|FROM
		|	(SELECT
		|		ProductionOrderInventory.Products AS Products,
		|		ProductionOrderInventory.Characteristic AS Characteristic,
		|		ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
		|		ProductionOrderInventory.Specification AS Specification,
		|		ProductionOrderInventory.Quantity AS Quantity
		|	FROM
		|		Document.ProductionOrder.Inventory AS ProductionOrderInventory
		|			INNER JOIN Catalog.Products AS CatalogProducts
		|			ON ProductionOrderInventory.Products = CatalogProducts.Ref
		|				AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
		|	WHERE
		|		ProductionOrderInventory.Ref = &BasisDocument
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
		|		TT_DocumentProduction AS DocumentProduction
		|			INNER JOIN Document.Manufacturing.Inventory AS ProductionInventory
		|			ON DocumentProduction.Ref = ProductionInventory.Ref) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic,
		|	OrdersBalance.MeasurementUnit,
		|	OrdersBalance.Specification
		|
		|HAVING
		|	SUM(OrdersBalance.Quantity) > 0";
		
	EndIf;
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[2].Unload();
	BalanceTable.Indexes.Add("ProductionOrder, Products, Characteristic");
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	
	If BalanceTable.Count() > 0 Then
		
		TableProducts = ResultsArray[4].Unload();
		For Each SelectionProducts In TableProducts Do
			
			If SelectionProducts.ProductsType <> Enums.ProductsTypes.InventoryItem Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("ProductionOrder", FillingData);
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
		Selection = ResultsArray[5].Select();
		While Selection.Next() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	ElsIf Inventory.Count() > 0 Then
		Selection = ResultsArray[5].Select();
		While Selection.Next() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
		EndDo;
	EndIf;
	
	// Fill out according to specification.
	If Products.Count() > 0 Then
		If Inventory.Count() = 0 Then
			FillTabularSectionBySpecification();
		EndIf;
		FillColumnReserveByBalances();
	EndIf;
	
EndProcedure

Procedure FillByWIP(WIP) Export
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ManufacturingOperation.BasisDocument AS BasisDocument,
	|	ManufacturingOperation.Posted AS BasisPosted,
	|	ManufacturingOperation.Status AS BasisStatus,
	|	VALUE(Enum.OperationTypesProduction.ConvertFromWIP) AS OperationKind,
	|	2 AS ConvertFromWIPFillInVariant,
	|	MAX(ISNULL(ManufacturingOperationActivities.Output, TRUE)) AS BasisOutput,
	|	ManufacturingOperation.StructuralUnit AS StructuralUnit,
	|	ManufacturingOperation.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ManufacturingOperation.CellInventory AS CellInventory,
	|	ManufacturingOperation.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	ManufacturingOperation.DisposalsCell AS DisposalsCell,
	|	ManufacturingOperation.Ref AS WorkInProgress,
	|	ManufacturingOperation.Company AS Company,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	BusinessUnits.TransferRecipient AS ProductsStructuralUnit,
	|	BusinessUnits.TransferRecipientCell AS ProductsCell
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|		LEFT JOIN Document.ProductionOrder AS ProductionOrder
	|		ON (ManufacturingOperation.BasisDocument = ProductionOrder.Ref)
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON (ManufacturingOperation.StructuralUnit = BusinessUnits.Ref)
	|WHERE
	|	ManufacturingOperationActivities.Ref = &WIP
	|
	|GROUP BY
	|	ManufacturingOperation.Posted,
	|	ManufacturingOperation.BasisDocument,
	|	ManufacturingOperation.Status,
	|	ManufacturingOperation.CellInventory,
	|	ManufacturingOperation.InventoryStructuralUnit,
	|	ManufacturingOperation.DisposalsStructuralUnit,
	|	ManufacturingOperation.DisposalsCell,
	|	ManufacturingOperation.StructuralUnit,
	|	ManufacturingOperation.Ref,
	|	ManufacturingOperation.Company,
	|	ProductionOrder.SalesOrder,
	|	BusinessUnits.TransferRecipient,
	|	BusinessUnits.TransferRecipientCell";
	
	Query.SetParameter("WIP", WIP);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("Status", Selection.BasisStatus);
		VerifiedAttributesValues.Insert("Posted", Selection.BasisPosted);
		VerifiedAttributesValues.Insert("Output", Selection.BasisOutput);
		Documents.ManufacturingOperation.CheckAbilityOfEnteringByWorkInProgress(WIP, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(Date) Then
		Date = CurrentSessionDate();
	EndIf;
	
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
	
	// Finished products filling
	
	Products.Clear();
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Products AS Products,
	|	ManufacturingOperation.Characteristic AS Characteristic,
	|	ManufacturingOperation.Quantity AS Quantity,
	|	ManufacturingOperation.MeasurementUnit AS MeasurementUnit,
	|	ManufacturingOperation.Specification AS Specification
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &WIP";
	
	Query.SetParameter("WIP", WIP);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		ProductsLine = Products.Add();
		FillPropertyValues(ProductsLine, SelectionDetailRecords);
		
	EndDo;
	
	CostObject = Common.ObjectAttributeValue(WIP, "CostObject");
	
	Query.Text = 
	"SELECT
	|	WorkInProgressBalance.QuantityBalance AS QuantityBalance,
	|	WorkInProgressBalance.AmountBalance AS AmountBalance
	|FROM
	|	AccumulationRegister.WorkInProgress.Balance AS WorkInProgressBalance
	|WHERE
	|	WorkInProgressBalance.CostObject = &CostObject
	|
	|UNION ALL
	|
	|SELECT
	|	WorkInProgress.Quantity,
	|	WorkInProgress.Amount
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress
	|WHERE
	|	WorkInProgress.Recorder = &Ref
	|	AND WorkInProgress.CostObject = &CostObject";
	
	Query.SetParameter("CostObject", CostObject);
	Query.SetParameter("Ref", Ref);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT ALLOWED
		|	ManufacturingOperation.Ref AS Ref
		|INTO TT_WIPs
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.CostObject = &CostObject
		|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed)
		|	AND ManufacturingOperation.Quantity = &WIPQuantity
		|	AND ManufacturingOperation.BOMHierarchyItem = &BOMHierarchyItem
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_WIPs.Ref AS WorkInProgress
		|FROM
		|	TT_WIPs AS TT_WIPs
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOperationInventory.Products AS Products,
		|	ManufacturingOperationInventory.Characteristic AS Characteristic,
		|	ManufacturingOperationInventory.Batch AS Batch,
		|	ManufacturingOperationInventory.Quantity AS Quantity,
		|	ManufacturingOperationInventory.MeasurementUnit AS MeasurementUnit,
		|	ManufacturingOperationInventory.Specification AS Specification,
		|	ManufacturingOperationInventory.SerialNumbers AS SerialNumbers,
		|	ManufacturingOperationInventory.ConnectionKey AS ConnectionKey,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN ManufacturingOperationInventory.InventoryGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS InventoryGLAccount,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN ManufacturingOperationInventory.InventoryReceivedGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS InventoryReceivedGLAccount,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN ManufacturingOperationInventory.ConsumptionGLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS ConsumptionGLAccount,
		|	ManufacturingOperationInventory.Ownership AS Ownership,
		|	ManufacturingOperationInventory.Ref AS Ref
		|FROM
		|	TT_WIPs AS TT_WIPs
		|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
		|		ON TT_WIPs.Ref = ManufacturingOperationInventory.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOperationSerialNumbers.Ref AS Ref,
		|	ManufacturingOperationSerialNumbers.SerialNumber AS SerialNumber,
		|	ManufacturingOperationSerialNumbers.ConnectionKey AS ConnectionKey
		|FROM
		|	TT_WIPs AS TT_WIPs
		|		INNER JOIN Document.ManufacturingOperation.SerialNumbers AS ManufacturingOperationSerialNumbers
		|		ON TT_WIPs.Ref = ManufacturingOperationSerialNumbers.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOperationActivities.Activity AS Activity,
		|	ManufacturingOperationActivities.Quantity AS Quantity,
		|	ManufacturingOperationActivities.StandardWorkload AS StandardWorkload,
		|	ManufacturingOperationActivities.Rate AS Rate,
		|	ManufacturingOperationActivities.Total AS Total,
		|	ManufacturingOperationActivities.ActualWorkload AS ActualWorkload,
		|	CASE
		|		WHEN &UseDefaultTypeOfAccounting
		|			THEN ManufacturingOperationActivities.GLAccount
		|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|	END AS GLAccount
		|FROM
		|	TT_WIPs AS TT_WIPs
		|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		ON TT_WIPs.Ref = ManufacturingOperationActivities.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ManufacturingOperationDisposals.Products AS Products,
		|	ManufacturingOperationDisposals.Characteristic AS Characteristic,
		|	ManufacturingOperationDisposals.Batch AS Batch,
		|	ManufacturingOperationDisposals.Quantity AS Quantity,
		|	ManufacturingOperationDisposals.MeasurementUnit AS MeasurementUnit,
		|	ManufacturingOperationDisposals.Ownership AS Ownership
		|FROM
		|	TT_WIPs AS TT_WIPs
		|		INNER JOIN Document.ManufacturingOperation.Disposals AS ManufacturingOperationDisposals
		|		ON TT_WIPs.Ref = ManufacturingOperationDisposals.Ref";
		
		WIPAttributes = Common.ObjectAttributesValues(WIP, "Quantity, BOMHierarchyItem");
		
		Query.SetParameter("CostObject", CostObject);
		Query.SetParameter("WIPQuantity", WIPAttributes.Quantity);
		Query.SetParameter("BOMHierarchyItem", WIPAttributes.BOMHierarchyItem);
		Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
		
		QueryResult = Query.ExecuteBatch();
		QueryResultQuantity = QueryResult.Count();
		
		// WIPs
		WorksInProgress.Load(QueryResult[QueryResultQuantity - 5].Unload());
		
		// By-products
		DisposalsTable = QueryResult[QueryResultQuantity - 1].Unload();
		Disposals.Clear();
		
		StructureData = New Structure();
		StructureData.Insert("Company", 			Company);
		StructureData.Insert("ProcessingDate",		?(ValueIsFilled(Date), Date, CurrentSessionDate()));
		StructureData.Insert("DocumentCurrency",	Common.ObjectAttributeValue(Company, "PresentationCurrency"));
		StructureData.Insert("PriceKind",			InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company).AccountingPrice);
		StructureData.Insert("Products",			Undefined);
		StructureData.Insert("Characteristic",		Undefined);
		StructureData.Insert("Factor",				1);
		
		Selection = Query.Execute().Select();
		For Each DisposalsTableLine In DisposalsTable Do
			
			DisposalsLine = Disposals.Add();
			FillPropertyValues(DisposalsLine, DisposalsTableLine);
			
			StructureData.Products = DisposalsTableLine.Products;
			StructureData.Characteristic = DisposalsTableLine.Characteristic;
			
			DisposalsLine.Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
			DisposalsLine.Amount = DisposalsLine.Price * DisposalsLine.Quantity;
			
		EndDo;
		
		// Operations
		Activities.Load(QueryResult[QueryResultQuantity - 2].Unload());
		
		// Components
		SerialNumbersTable = QueryResult[QueryResultQuantity - 3].Unload();
		SerialNumbers.Clear();
		
		If SerialNumbersTable.Count() Then
			
			Inventory.Clear();
			InventoryTable = QueryResult[QueryResultQuantity - 4].Unload();
			
			ConnectionKey = 1;
			For Each InventoryTableLine In InventoryTable Do
				
				InventoryLine = Inventory.Add();
				FillPropertyValues(InventoryLine, InventoryTableLine);
				InventoryLine.ConnectionKey = ConnectionKey;
				If ValueIsFilled(InventoryTableLine.ConnectionKey) Then
					
					FilterParameters = New Structure;
					FilterParameters.Insert("ConnectionKey", InventoryTableLine.ConnectionKey);
					FilterParameters.Insert("Ref", InventoryTableLine.Ref);
					
					SerialNumbersTableLines = SerialNumbersTable.FindRows(FilterParameters);
					
					For Each SerialNumbersTableLine In SerialNumbersTableLines Do
						
						SerialNumbersLine = SerialNumbers.Add();
						FillPropertyValues(SerialNumbersLine, SerialNumbersTableLine);
						SerialNumbersLine.ConnectionKey = ConnectionKey;
						
					EndDo;
					
				EndIf;
				
				ConnectionKey = ConnectionKey + 1;
				
			EndDo;
			
			
		Else
			
			Inventory.Load(QueryResult[QueryResultQuantity - 4].Unload());
			
		EndIf;
		
	Else
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For %1, the Production document already exists.'; ru = 'Для %1 документ ""Производство"" уже существует.';pl = 'Dla %1, Dokument produkcyjny już istnieje.';es_ES = 'Para %1, el Documento de producción ya existe.';es_CO = 'Para %1, el Documento de producción ya existe.';tr = '%1 için Üretim belgesi zaten mevcut.';it = 'Per %1, il Documento di Produzione esiste già.';de = 'Für %1 existiert das Produktionsdokument bereits.'"),
			WIP);
		Raise MessageText;
		
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
	|	SalesOrderHeader.Ref AS Ref,
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.SalesStructuralUnit AS SalesStructuralUnit,
	|	BusinessUnitsData.TransferRecipient AS ProductsStructuralUnit,
	|	BusinessUnitsData.TransferRecipientCell AS ProductsCell,
	|	BusinessUnitsData.TransferSource AS InventoryStructuralUnit,
	|	BusinessUnitsData.TransferSourceCell AS CellInventory,
	|	BusinessUnitsData.RecipientOfWastes AS DisposalsStructuralUnit,
	|	BusinessUnitsData.DisposalsRecipientCell AS DisposalsCell
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnitsData
	|		ON SalesOrderHeader.SalesStructuralUnit = BusinessUnitsData.Ref
	|WHERE
	|	SalesOrderHeader.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrderInventory.Ref AS SalesOrder,
	|	DATEADD(SalesOrderInventory.ShipmentDate, DAY, -ProductsData.ReplenishmentDeadline) AS Start,
	|	SalesOrderInventory.ShipmentDate AS Finish,
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	SalesOrderHeader.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	SalesOrderHeader.ProductsCell AS ProductsCell,
	|	SalesOrderHeader.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	SalesOrderHeader.CellInventory AS CellInventory,
	|	SalesOrderHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	SalesOrderHeader.DisposalsCell AS DisposalsCell,
	|	SalesOrderInventory.Products AS Products,
	|	ProductsData.ProductsType AS ProductsType,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.Specification AS Specification
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|		INNER JOIN Document.SalesOrder.Inventory AS SalesOrderInventory
	|			LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|			ON SalesOrderInventory.Specification = BillsOfMaterials.Ref
	|		ON SalesOrderHeader.Ref = SalesOrderInventory.Ref
	|		LEFT JOIN Catalog.Products AS ProductsData
	|		ON (SalesOrderInventory.Products = ProductsData.Ref)
	|WHERE
	|	(&OperationKind = VALUE(Enum.OperationTypesProductionOrder.Disassembly)
	|			OR BillsOfMaterials.Ref IS NULL
	|				AND ProductsData.ReplenishmentMethod = VALUE(Enum.InventoryReplenishmentMethods.Assembly)
	|			OR BillsOfMaterials.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Assembly))");
	
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
				
				If Not ValueIsFilled(NewRow.Specification) Then
					NewRow.Specification = DriveServer.GetDefaultSpecification(NewRow.Products, NewRow.Characteristic);
				EndIf;
				
			EndIf;
		
		EndDo;
		
		If Products.Count() > 0 Then
			FillTabularSectionBySpecification();
			If OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
				FillInActivitiesByBOM();
			EndIf;
		EndIf;
		
	Else
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%1 does not contain items that require production.'; ru = '%1 не содержит элементов, требующих производства.';pl = '%1 nie zawiera pozycji wymagających produkcji.';es_ES = '%1 no contiene artículos que requieran producción.';es_CO = '%1 no contiene artículos que requieran producción.';tr = '%1 üretim gerektiren öğe içermiyor.';it = '%1 non contiene elementi che richiedono la produzione.';de = '%1 enthält keine Positionen die Produktion bedürfen.'"),
			FillingData);
			
		Raise ErrorText;
		
	EndIf;
	
EndProcedure

Procedure Allocate() Export
	
	Cancel = False;
	WriteMode = DocumentWriteMode.Posting;
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If Cancel Then
		Return;
	EndIf;
	
	If OperationKind = Enums.OperationTypesProduction.Assembly Then
		AllocateAssembly();
	ElsIf OperationKind = Enums.OperationTypesProduction.Disassembly Then
		AllocateDisassembly();
	ElsIf OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		AllocateConvertFromWIP();
	EndIf;
	
EndProcedure

Function CheckAllocationCorrectness(DisplaySuccessMessage = False) Export
	
	If Allocation.Count() = 0 Then
		MessageText = NStr("en = 'The allocation hasn''t been performed.
						|Use the ""Allocate automatically"" command and then make the needed manual changes.'; 
						|ru = 'Распределение не выполнено.
						|Нажмите ""Распределить автоматически"", после чего внесите необходимые изменения вручную.';
						|pl = 'Nie wykonano przydzielenia.
						|Użyj polecenia ""Przydziel automatycznie"" i następnie zrób wszystkie wymagane zmiany ręcznie.';
						|es_ES = 'La asignación no se ha realizado.
						| Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
						|es_CO = 'La asignación no se ha realizado.
						| Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
						|tr = 'Tahsis gerçekleştirilemedi.
						|""Otomatik tahsis et"" komutunu seçip gerekli manuel değişiklikleri yapın.';
						|it = 'Non è stata eseguita l''allocazione. 
						| Utilizzare il comando ""Allocare automaticamente"" ed effettuare poi le modifiche manuali necessarie.';
						|de = 'Die Zuordnung wurde nicht ausgeführt
						|Verwenden Sie den ""Automatisch zuordnen""-Befehl und dann machen erforderliche Änderungen manuell.'");
		CommonClientServer.MessageToUser(MessageText, ThisObject, "Allocation");
		Return False;
	EndIf;
	
	Cancel = False;
	
	Query = New Query;
	
	Query.SetParameter("Allocation", Allocation);
	Query.SetParameter("TableProduction", Products);
	Query.SetParameter("TableInventory", Inventory);
	Query.SetParameter("TableActivities", Activities);
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches", GetFunctionalOption("UseBatches"));
	
	Query.SetParameter("ConvertFromWIP", (OperationKind = Enums.OperationTypesProduction.ConvertFromWIP));
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	Query.Text =
	"SELECT
	|	Allocation.LineNumber AS LineNumber,
	|	Allocation.CorrProducts AS CorrProducts,
	|	Allocation.CorrCharacteristic AS CorrCharacteristic,
	|	Allocation.CorrBatch AS CorrBatch,
	|	Allocation.CorrOwnership AS CorrOwnership,
	|	Allocation.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	Allocation.CorrQuantity AS CorrQuantity,
	|	Allocation.CorrGLAccount AS CorrGLAccount,
	|	Allocation.Specification AS Specification,
	|	Allocation.Products AS Products,
	|	Allocation.Characteristic AS Characteristic,
	|	Allocation.Batch AS Batch,
	|	Allocation.Ownership AS Ownership,
	|	Allocation.MeasurementUnit AS MeasurementUnit,
	|	Allocation.Quantity AS Quantity,
	|	Allocation.GLAccount AS GLAccount,
	|	Allocation.ConsumptionGLAccount AS ConsumptionGLAccount
	|INTO TT_Allocation
	|FROM
	|	&Allocation AS Allocation
	|WHERE
	|	NOT Allocation.ByProduct
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableProduction.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.MeasurementUnit AS MeasurementUnit,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.InventoryGLAccount AS InventoryGLAccount,
	|	TableProduction.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
	|	TableProduction.ConsumptionGLAccount AS ConsumptionGLAccount
	|INTO TableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.InventoryGLAccount AS InventoryGLAccount,
	|	TableInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
	|	TableInventory.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity AS Quantity
	|INTO TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableActivities.Activity AS Activity,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	&OwnInventory AS Ownership,
	|	TableActivities.GLAccount AS GLAccount,
	|	VALUE(Catalog.UOMClassifier.EmptyRef) AS MeasurementUnit,
	|	TableActivities.Quantity AS Quantity,
	|	0 AS QuantityAllocated
	|INTO TableActivities
	|FROM
	|	&TableActivities AS TableActivities
	|WHERE
	|	&ConvertFromWIP";
	
	DriveClientServer.AddDelimeter(Query.Text);
	
	If OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		Query.Text = Query.Text +
		"SELECT DISTINCT
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	CASE
		|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|			THEN TableInventory.InventoryReceivedGLAccount
		|		ELSE TableInventory.InventoryGLAccount
		|	END AS GLAccount,
		|	1 AS QuantityConsumed,
		|	0 AS QuantityAllocated
		|INTO TT_InventoryComplete
		|FROM
		|	TableInventory AS TableInventory
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON TableInventory.Ownership = CatalogInventoryOwnership.Ref
		|
		|UNION ALL
		|
		|SELECT DISTINCT
		|	TT_Allocation.Products,
		|	TT_Allocation.Characteristic,
		|	TT_Allocation.Batch,
		|	TT_Allocation.Ownership,
		|	TT_Allocation.GLAccount,
		|	0,
		|	1
		|FROM
		|	TT_Allocation AS TT_Allocation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Complete.Products AS Products,
		|	TT_Complete.Characteristic AS Characteristic,
		|	TT_Complete.Batch AS Batch,
		|	TT_Complete.Ownership AS Ownership,
		|	TT_Complete.GLAccount AS GLAccount,
		|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
		|	SUM(TT_Complete.QuantityAllocated) AS QuantityAllocated
		|INTO TT_InventoryCompleteGrouped
		|FROM
		|	TT_InventoryComplete AS TT_Complete
		|
		|GROUP BY
		|	TT_Complete.GLAccount,
		|	TT_Complete.Characteristic,
		|	TT_Complete.Batch,
		|	TT_Complete.Ownership,
		|	TT_Complete.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	NULL AS LineNumber,
		|	TableProduction.Products AS Products,
		|	TableProduction.Characteristic AS Characteristic,
		|	TableProduction.Batch AS Batch,
		|	TableProduction.Ownership AS Ownership,
		|	CASE
		|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|			THEN TableProduction.InventoryReceivedGLAccount
		|		ELSE TableProduction.InventoryGLAccount
		|	END AS GLAccount,
		|	TableProduction.Specification AS Specification,
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	TableProduction.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	CAST(TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1) AS NUMBER(15, 3)) AS QuantityConsumed,
		|	0 AS QuantityAllocated
		|INTO TT_ProductionComplete
		|FROM
		|	TableProduction AS TableProduction
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON TableProduction.Products = CatalogProducts.Ref
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON TableProduction.Ownership = CatalogInventoryOwnership.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	TT_Allocation.LineNumber,
		|	TT_Allocation.CorrProducts,
		|	TT_Allocation.CorrCharacteristic,
		|	TT_Allocation.CorrBatch,
		|	TT_Allocation.CorrOwnership,
		|	TT_Allocation.CorrGLAccount,
		|	TT_Allocation.Specification,
		|	TT_Allocation.CorrMeasurementUnit,
		|	TT_Allocation.ConsumptionGLAccount,
		|	0,
		|	TT_Allocation.Quantity
		|FROM
		|	TT_Allocation AS TT_Allocation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(TT_Complete.LineNumber) AS LineNumber,
		|	TT_Complete.Products AS Products,
		|	TT_Complete.Characteristic AS Characteristic,
		|	TT_Complete.Batch AS Batch,
		|	TT_Complete.Ownership AS Ownership,
		|	TT_Complete.GLAccount AS GLAccount,
		|	TT_Complete.Specification AS Specification,
		|	TT_Complete.MeasurementUnit AS MeasurementUnit,
		|	TT_Complete.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
		|	SUM(TT_Complete.QuantityAllocated) AS QuantityAllocated
		|INTO TT_ProductionCompleteGrouped
		|FROM
		|	TT_ProductionComplete AS TT_Complete
		|
		|GROUP BY
		|	TT_Complete.GLAccount,
		|	TT_Complete.Specification,
		|	TT_Complete.MeasurementUnit,
		|	TT_Complete.ConsumptionGLAccount,
		|	TT_Complete.Characteristic,
		|	TT_Complete.Batch,
		|	TT_Complete.Ownership,
		|	TT_Complete.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS Field1
		|FROM
		|	TT_InventoryCompleteGrouped AS TT_CompleteGrouped
		|WHERE
		|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_CompleteGrouped.LineNumber AS LineNumber,
		|	TT_CompleteGrouped.Products AS Products,
		|	TT_CompleteGrouped.Characteristic AS Characteristic,
		|	TT_CompleteGrouped.Batch AS Batch,
		|	TT_CompleteGrouped.Ownership AS Ownership,
		|	TT_CompleteGrouped.MeasurementUnit AS MeasurementUnit,
		|	TT_CompleteGrouped.QuantityConsumed AS QuantityConsumed,
		|	TT_CompleteGrouped.QuantityAllocated AS QuantityAllocated
		|FROM
		|	TT_ProductionCompleteGrouped AS TT_CompleteGrouped
		|WHERE
		|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
		|
		|ORDER BY
		|	LineNumber";
		
		MessageTemplate = NStr(
			"en ='Product ""%1"" misallocation. Consumed: %2 %3, allocated: %4 %3, discrepancy: %5 %3'; ru = 'Неправильное разнесение номенклатуры ""%1"". Расход: %2 %3, разнесено: %4 %3, расхождение: %5 %3';pl = 'Produkt ""%1"" jest przydzielony niepoprawnie. Zużyto: %2 %3, przydzielono: %4 %3, rozbieżność: %5 %3';es_ES = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';es_CO = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';tr = 'Ürün ""%1"" yanlış dağıtıldı. Tükenen: %2 %3, dağıtılan: %4 %3, uyuşmazlık: %5 %3';it = 'Errata assegnazione dell''articolo ""%1"". Consumato: %2 %3, assegnato: %4 %3, discrepanza: %5 %3';de = 'Fehlerhafte Zuordnung des Produkts ""%1"". Verbraucht: %2 %3, zugeordnet: %4 %3, Abweichung: %5 %3'");
		MessageAboutSecondTable = NStr(
			"en ='Components table has been modified, allocation table contains irrelevant components data.
			|Use the ""Allocate automatically"" command and then make the needed manual changes.'; 
			|ru = 'Таблица сырья и материалов изменена, таблица разнесения содержит неактуальные данные о сырье и материалах.
			|Используйте команду ""Разнести автоматически"", после чего внесите необходимые изменения вручную.';
			|pl = 'Tabela Komponenty została zmieniona, tabela przydzielenia zawiera niepoprawne dane o komponentach.
			|Użyj polecenia ""Przydziel automatycznie"" i następnie zrób wszystkie niezbędne zmiany ręcznie.';
			|es_ES = 'Se ha modificado la tabla de componentes, la tabla de asignación contiene datos de componentes irrelevantes. 
			|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|es_CO = 'Se ha modificado la tabla de componentes, la tabla de asignación contiene datos de componentes irrelevantes. 
			|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|tr = 'Malzemeler tablosu değiştirildi, tahsis tablosu geçersiz malzeme bilgisi içeriyor.
			|""Otomatik tahsis et"" komutunu kullanın, ardından gerekli manuel değişiklikleri yapın.';
			|it = 'La tabella componenti è stata modificata, la tabella assegnazioni contiene dati irrilevanti di componenti. 
			|Utilizzare il comando ""Alloca automaticamente"" e poi effettuare le modifiche manuali necessarie.';
			|de = 'Die Tabelle des Materialbestands wurde modifiziert, die Zuordnungstabelle enthält unzutreffende Daten des Materialbestands.
			|Verwenden Sie den ""Automatisch zuordnen""-Befehl und dann machen erforderliche Änderungen manuell.'");
		
	Else
		
		Query.Text = Query.Text +
		"SELECT
		|	TableProduction.Products AS Products,
		|	TableProduction.Characteristic AS Characteristic,
		|	TableProduction.Batch AS Batch,
		|	TableProduction.Ownership AS Ownership,
		|	CASE
		|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|			THEN TableProduction.InventoryReceivedGLAccount
		|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
		|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerOwnedInventory)
		|			THEN TableProduction.ConsumptionGLAccount
		|		ELSE TableProduction.InventoryGLAccount
		|	END AS GLAccount,
		|	TableProduction.Specification AS Specification,
		|	CASE
		|		WHEN &ConvertFromWIP
		|			THEN UNDEFINED
		|		ELSE TableProduction.ConsumptionGLAccount
		|	END AS ConsumptionGLAccount,
		|	CAST(TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1) AS NUMBER(15, 3)) AS QuantityConsumed,
		|	NULL AS QuantityAllocated
		|INTO TT_ProductionComplete
		|FROM
		|	TableProduction AS TableProduction
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON TableProduction.Ownership = CatalogInventoryOwnership.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	TT_Allocation.CorrProducts,
		|	TT_Allocation.CorrCharacteristic,
		|	TT_Allocation.CorrBatch,
		|	TT_Allocation.CorrOwnership,
		|	TT_Allocation.CorrGLAccount,
		|	TT_Allocation.Specification,
		|	CASE
		|		WHEN &ConvertFromWIP
		|			THEN UNDEFINED
		|		ELSE TT_Allocation.ConsumptionGLAccount
		|	END,
		|	0,
		|	TT_Allocation.CorrQuantity
		|FROM
		|	TT_Allocation AS TT_Allocation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_Complete.Products AS Products,
		|	TT_Complete.Characteristic AS Characteristic,
		|	TT_Complete.Batch AS Batch,
		|	TT_Complete.Ownership AS Ownership,
		|	TT_Complete.GLAccount AS GLAccount,
		|	TT_Complete.Specification AS Specification,
		|	TT_Complete.ConsumptionGLAccount AS ConsumptionGLAccount,
		|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
		|	MIN(TT_Complete.QuantityAllocated) AS QuantityAllocated
		|INTO TT_ProductionCompleteGrouped
		|FROM
		|	TT_ProductionComplete AS TT_Complete
		|
		|GROUP BY
		|	TT_Complete.GLAccount,
		|	TT_Complete.Specification,
		|	TT_Complete.ConsumptionGLAccount,
		|	TT_Complete.Characteristic,
		|	TT_Complete.Batch,
		|	TT_Complete.Ownership,
		|	TT_Complete.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	NULL AS LineNumber,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	CASE
		|		WHEN &ConvertFromWIP
		|			THEN TableInventory.ConsumptionGLAccount
		|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
		|			THEN TableInventory.InventoryReceivedGLAccount
		|		ELSE TableInventory.InventoryGLAccount
		|	END AS GLAccount,
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	CAST(TableInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS NUMBER(15, 3)) AS QuantityConsumed,
		|	0 AS QuantityAllocated
		|INTO TT_InventoryComplete
		|FROM
		|	TableInventory AS TableInventory
		|		LEFT JOIN Catalog.UOM AS CatalogUOM
		|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
		|		LEFT JOIN Catalog.Products AS CatalogProducts
		|		ON TableInventory.Products = CatalogProducts.Ref
		|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
		|		ON TableInventory.Ownership = CatalogInventoryOwnership.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	NULL,
		|	TableActivities.Activity,
		|	TableActivities.Characteristic,
		|	TableActivities.Batch,
		|	TableActivities.Ownership,
		|	TableActivities.GLAccount,
		|	TableActivities.MeasurementUnit,
		|	TableActivities.Quantity,
		|	0
		|FROM
		|	TableActivities AS TableActivities
		|WHERE
		|	&ConvertFromWIP
		|
		|UNION ALL
		|
		|SELECT
		|	TT_Allocation.LineNumber,
		|	TT_Allocation.Products,
		|	TT_Allocation.Characteristic,
		|	TT_Allocation.Batch,
		|	TT_Allocation.Ownership,
		|	CASE
		|		WHEN &ConvertFromWIP
		|			THEN TT_Allocation.ConsumptionGLAccount
		|		ELSE TT_Allocation.GLAccount
		|	END,
		|	TT_Allocation.MeasurementUnit,
		|	0,
		|	TT_Allocation.Quantity
		|FROM
		|	TT_Allocation AS TT_Allocation
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MIN(TT_Complete.LineNumber) AS LineNumber,
		|	TT_Complete.Products AS Products,
		|	TT_Complete.Characteristic AS Characteristic,
		|	TT_Complete.Batch AS Batch,
		|	TT_Complete.Ownership AS Ownership,
		|	TT_Complete.GLAccount AS GLAccount,
		|	TT_Complete.MeasurementUnit AS MeasurementUnit,
		|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
		|	SUM(TT_Complete.QuantityAllocated) AS QuantityAllocated
		|INTO TT_InventoryCompleteGrouped
		|FROM
		|	TT_InventoryComplete AS TT_Complete
		|
		|GROUP BY
		|	TT_Complete.MeasurementUnit,
		|	TT_Complete.GLAccount,
		|	TT_Complete.Characteristic,
		|	TT_Complete.Batch,
		|	TT_Complete.Ownership,
		|	TT_Complete.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	TRUE AS Field
		|FROM
		|	TT_ProductionCompleteGrouped AS TT_CompleteGrouped
		|WHERE
		|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TT_CompleteGrouped.LineNumber AS LineNumber,
		|	TT_CompleteGrouped.Products AS Products,
		|	TT_CompleteGrouped.Characteristic AS Characteristic,
		|	TT_CompleteGrouped.Batch AS Batch,
		|	TT_CompleteGrouped.Ownership AS Ownership,
		|	TT_CompleteGrouped.MeasurementUnit AS MeasurementUnit,
		|	TT_CompleteGrouped.QuantityConsumed AS QuantityConsumed,
		|	TT_CompleteGrouped.QuantityAllocated AS QuantityAllocated
		|FROM
		|	TT_InventoryCompleteGrouped AS TT_CompleteGrouped
		|WHERE
		|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
		|
		|ORDER BY
		|	LineNumber";
		
		MessageTemplate = NStr("en = 'Component ""%1"" misallocation. Consumed: %2 %3, allocated: %4 %3, discrepancy: %5 %3'; ru = 'Неправильное разнесение сырья и материалов ""%1"". Расход: %2 %3, разнесено: %4 %3, расхождение: %5 %3';pl = 'Komponent ""%1"" jest przydzielony niepoprawnie. Zużyto: %2 %3, przydzielono: %4 %3, rozbieżność: %5 %3';es_ES = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';es_CO = 'Desviación del producto ""%1"". Consumido: %2 %3, asignado: %4 %3, discrepancia: %5 %3';tr = '""%1"" malzemesi yanlış tahsis edildi. Tüketilen: %2 %3, tahsis edilen: %4 %3, uyuşmazlık: %5 %3';it = 'Allocazione errata della componente ""%1"". Consumato: %2 %3, allocato: %4 %3, discrepanza: %5 %3';de = 'Fehlerhafte Zuordnung der Komponente ""%1"". Verbraucht: %2 %3, zugeordnet: %4 %3, Abweichung: %5 %3'");
		MessageAboutSecondTable = NStr("en = 'Products table has been modified, allocation table contains irrelevant products data.
			|Use the ""Allocate automatically"" command and then make the needed manual changes.'; 
			|ru = 'Изменена табличная часть ""Номенклатура"". Табличная часть ""Распределение"" содержит неактуальные данные о номенклатуре.
			|Нажмите ""Распределить автоматически"" и внесите необходимые изменения вручную.';
			|pl = 'Tabela Produkty została zmieniona, tabela przydzielenia zawiera niepoprawne dane o produktach.
			|Użyj polecenia ""Przydziel automatycznie"" a następnie dokonaj wszystkich niezbędnych zmian ręcznie.';
			|es_ES = 'Se ha modificado la tabla de productos, la tabla de asignación contiene datos de productos irrelevantes. 
			|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|es_CO = 'Se ha modificado la tabla de productos, la tabla de asignación contiene datos de productos irrelevantes. 
			|Use el comando ""Asignar automáticamente"" y luego haga los cambios manuales necesarios.';
			|tr = 'Ürünler tablosu değiştirildi; tahsis tablosu geçersiz ürün bilgisi içeriyor.
			|""Otomatik tahsis et"" komutunu seçip gerekli manuel değişiklikleri yapın.';
			|it = 'La tabella Articoli è stata modificata, la tabella allocazioni contiene dati articolo irrilevanti. 
			|Utilizzare il comando ""Allocare automaticamente"" e poi effettuare le modifiche manuali necessarie.';
			|de = 'Die Tabelle von Produkten wurde modifiziert, die Zuordnungstabelle enthält unzutreffende Daten der Produkte.
			|Verwenden Sie den ""Automatisch zuordnen""-Befehl und dann machen erforderliche Änderungen manuell.'");
		
	EndIf;
	
	Results = Query.ExecuteBatch();
	ResultsCount = Results.Count();
	
	If Not Results[ResultsCount - 2].IsEmpty() Then
		CommonClientServer.MessageToUser(MessageAboutSecondTable, ThisObject, "Allocation", , Cancel);
	EndIf;
	
	Sel = Results[ResultsCount - 1].Select();
	While Sel.Next() Do
		
		ProductPresentationArray = New Array;
		ProductPresentationArray.Add(Sel.Products);
		If Not IsBlankString(Sel.Characteristic) Then
			ProductPresentationArray.Add(Sel.Characteristic);
		EndIf;
		If Not IsBlankString(Sel.Batch) Then
			ProductPresentationArray.Add(Sel.Batch);
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate,
			StrConcat(ProductPresentationArray, " "),
			Sel.QuantityConsumed,
			Sel.MeasurementUnit,
			Sel.QuantityAllocated,
			Sel.QuantityAllocated - Sel.QuantityConsumed);
		
		If Sel.LineNumber = Null Then
			MessageField = "Allocation";
		Else
			MessageField = CommonClientServer.PathToTabularSection("Allocation", Sel.LineNumber, "Quantity");
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, , Cancel);
		
	EndDo;
	
	If OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		
		MessageTemplate = NStr("en = 'The ""%1"" is required on line %2 of the ""Allocation"" list.'; ru = 'В строке %2 списка ""Разнесение"" необходимо указать ""%1"".';pl = '""%1"" jest wymagane w wierszu %2 listy ""Przydzielenie"".';es_ES = 'El ""%1"" se requiere en línea %2 de la lista ""Asignación"".';es_CO = 'El ""%1"" se requiere en línea %2 de la lista ""Asignación"".';tr = '""Dağıtım"" listesinin %2 satırında ""%1"" gerekir.';it = '""%1"" è richiesto nella riga %2 dell''elenco ""Assegnazione"".';de = 'Das ""%1"" ist in der Zeile Nr %2 der Liste ""Zuordnung"" erforderlich.'");
		
		EmptyRequiredFieldErrors = New Array;
		
		For Each AllocationRow In Allocation Do
			If Not ValueIsFilled(AllocationRow.StructuralUnit) Then
				EmptyRequiredFieldErrors.Add(
					New Structure("Field, LineNumber", "StructuralUnit", AllocationRow.LineNumber));
			EndIf;
			If Not ValueIsFilled(AllocationRow.CostObject) Then
				EmptyRequiredFieldErrors.Add(
					New Structure("Field, LineNumber", "CostObject", AllocationRow.LineNumber));
			EndIf;
			If AllocationRow.Quantity = 0 And AllocationRow.ByProduct Then
				EmptyRequiredFieldErrors.Add(
					New Structure("Field, LineNumber", "Quantity", AllocationRow.LineNumber));
			EndIf;
		EndDo;
		
		For Each ERFError In EmptyRequiredFieldErrors Do
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTemplate,
				Metadata().TabularSections.Allocation.Attributes[ERFError.Field].Presentation(),
				ERFError.LineNumber);
			CommonClientServer.MessageToUser(
				MessageText,
				ThisObject,
				CommonClientServer.PathToTabularSection("Allocation", ERFError.LineNumber, ERFError.Field),
				,
				Cancel);
		EndDo;
			
		// Use by products accounting starting from
		UseByProductsAccountingStartingFrom = Constants.UseByProductsAccountingStartingFrom.Get();
		UseByProductsAccounting = ?(ValueIsFilled(UseByProductsAccountingStartingFrom),
			UseByProductsAccountingStartingFrom <= Date,
			False);
			
		If UseByProductsAccounting Then
			CheckByProductsAllocationCorrectness(Cancel);
		EndIf;
		
		EndIf;
	
	If DisplaySuccessMessage And Not Cancel Then
		MessageText = NStr("en = 'No allocation errors were found.'; ru = 'Ошибки разнесения не выявлены.';pl = 'Nie znaleziono błędów przydzielenia.';es_ES = 'No se encontraron errores de asignación.';es_CO = 'No se encontraron errores de asignación.';tr = 'Tahsis hatası bulunamadı.';it = 'Nessun errore di allocazione rilevato.';de = 'Keine Zuordnungsfehler gefunden.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return Not Cancel;
	
EndFunction

// Reservation

Procedure FillColumnReserveByBalances() Export
	
	IsDisassembly = (OperationKind = Enums.OperationTypesProduction.Disassembly);
	
	If IsDisassembly Then
		Products.LoadColumn(New Array(Products.Count()), "Reserve");
	Else
		Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ReservedProductsBalances.Company AS Company,
	|	ReservedProductsBalances.StructuralUnit AS StructuralUnit,
	|	ReservedProductsBalances.Products AS Products,
	|	ReservedProductsBalances.Characteristic AS Characteristic,
	|	ReservedProductsBalances.Batch AS Batch,
	|	SUM(ReservedProductsBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		ReservedProductsBalances.Company AS Company,
	|		ReservedProductsBalances.StructuralUnit AS StructuralUnit,
	|		ReservedProductsBalances.Products AS Products,
	|		ReservedProductsBalances.Characteristic AS Characteristic,
	|		ReservedProductsBalances.Batch AS Batch,
	|		ReservedProductsBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						&BasisDocument
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.SalesOrder <> UNDEFINED) AS ReservedProductsBalances
	|
	|GROUP BY
	|	ReservedProductsBalances.Company,
	|	ReservedProductsBalances.StructuralUnit,
	|	ReservedProductsBalances.Products,
	|	ReservedProductsBalances.Characteristic,
	|	ReservedProductsBalances.Batch";
	
	Query.SetParameter("TableInventory", ?(IsDisassembly, Products.Unload(), Inventory.Unload()));
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", InventoryStructuralUnit);
	Query.SetParameter("BasisDocument", BasisDocument);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		
		If IsDisassembly Then
			ArrayOfRowsInventory = Products.FindRows(StructureForSearch);
		Else
			ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		EndIf;
		
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

// End Reservation

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If Not ValueIsFilled(OperationKind) Then
		OperationKind = Enums.OperationTypesProduction.Assembly;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillUsingSalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.ManufacturingOperation") Then
		FillByWIP(FillingData);
	EndIf;
	
	ManualAllocation = (OperationKind = Enums.OperationTypesProduction.ConvertFromWIP);
	Allocation.Clear();
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.ManufacturingOperation") Then
		Allocate();
	EndIf;

EndProcedure

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ManualAllocation And WriteMode = DocumentWriteMode.Posting Then
		Allocate();
	EndIf;
	
	ProductsList = "";
	FOUseCharacteristics = Constants.UseCharacteristics.Get();
	For Each StringProducts In Products Do
		
		If Not ValueIsFilled(StringProducts.Products) Then
			Continue;
		EndIf;
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics And ValueIsFilled(StringProducts.Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(StringProducts.Characteristic) + ")";
		EndIf;
		
		If ValueIsFilled(ProductsList) Then
			ProductsList = ProductsList + Chars.LF;
		EndIf;
		ProductsList = ProductsList + TrimAll(StringProducts.Products) + CharacteristicPresentation + ", "
			+ StringProducts.Quantity + " " + TrimAll(StringProducts.MeasurementUnit);
		
	EndDo;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
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
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbersProducts, StructuralUnit, ThisObject);
	If OperationKind = Enums.OperationTypesProduction.ConvertFromWIP Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "InventoryStructuralUnit");
	Else
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
	EndIf;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Allocation.StructuralUnit");
	DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Allocation.CostObject");
	
	// Use by products accounting starting from
	UseByProductsAccountingStartingFrom = Constants.UseByProductsAccountingStartingFrom.Get();
	UseByProductsAccounting = ?(ValueIsFilled(UseByProductsAccountingStartingFrom),
		UseByProductsAccountingStartingFrom <= Date,
		False);
		
	If Not UseByProductsAccounting Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Disposals.Price");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Disposals.Amount");
	EndIf;

	If ManualAllocation And Not CheckAllocationCorrectness() Then
		Cancel = True;
	EndIf;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.Manufacturing.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkInProgress(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsConsumedToDeclare(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCustomerOwnedInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkInProgressStatement(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionComponents(AdditionalProperties, RegisterRecords, Cancel);
	
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
	Documents.Manufacturing.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Manufacturing.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

Procedure CheckByProductsAllocationCorrectness(Cancel)
	
	Query = New Query;
	
	Query.SetParameter("Allocation", Allocation);
	Query.SetParameter("TableByProducts", Disposals);
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches", GetFunctionalOption("UseBatches"));
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	Allocation.LineNumber AS LineNumber,
	|	Allocation.CorrProducts AS CorrProducts,
	|	Allocation.CorrCharacteristic AS CorrCharacteristic,
	|	Allocation.CorrBatch AS CorrBatch,
	|	Allocation.CorrOwnership AS CorrOwnership,
	|	Allocation.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	Allocation.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Allocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	Allocation.Specification AS Specification,
	|	Allocation.Products AS Products,
	|	Allocation.Characteristic AS Characteristic,
	|	Allocation.Batch AS Batch,
	|	Allocation.Ownership AS Ownership,
	|	Allocation.MeasurementUnit AS MeasurementUnit,
	|	Allocation.Quantity AS Quantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Allocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Allocation.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount
	|INTO TT_Allocation
	|FROM
	|	&Allocation AS Allocation
	|WHERE
	|	Allocation.ByProduct
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableByProducts.LineNumber AS LineNumber,
	|	TableByProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableByProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableByProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	TableByProducts.MeasurementUnit AS MeasurementUnit,
	|	TableByProducts.Quantity AS Quantity
	|INTO TableByProducts
	|FROM
	|	&TableByProducts AS TableByProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NULL AS LineNumber,
	|	TableByProducts.Products AS Products,
	|	TableByProducts.Characteristic AS Characteristic,
	|	TableByProducts.Batch AS Batch,
	|	TableByProducts.Ownership AS Ownership,
	|	TableByProducts.InventoryGLAccount AS GLAccount,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableByProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS QuantityConsumed,
	|	0 AS QuantityAllocated
	|INTO TT_ByProductsComplete
	|FROM
	|	TableByProducts AS TableByProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableByProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableByProducts.Products = CatalogProducts.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Allocation.LineNumber,
	|	TT_Allocation.CorrProducts,
	|	TT_Allocation.CorrCharacteristic,
	|	TT_Allocation.CorrBatch,
	|	TT_Allocation.CorrOwnership,
	|	TT_Allocation.CorrGLAccount,
	|	TT_Allocation.CorrMeasurementUnit,
	|	0,
	|	TT_Allocation.CorrQuantity
	|FROM
	|	TT_Allocation AS TT_Allocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TT_Complete.LineNumber) AS LineNumber,
	|	TT_Complete.Products AS Products,
	|	TT_Complete.Characteristic AS Characteristic,
	|	TT_Complete.Batch AS Batch,
	|	TT_Complete.Ownership AS Ownership,
	|	TT_Complete.GLAccount AS GLAccount,
	|	TT_Complete.MeasurementUnit AS MeasurementUnit,
	|	SUM(TT_Complete.QuantityConsumed) AS QuantityConsumed,
	|	SUM(TT_Complete.QuantityAllocated) AS QuantityAllocated
	|INTO TT_ByProductsCompleteGrouped
	|FROM
	|	TT_ByProductsComplete AS TT_Complete
	|
	|GROUP BY
	|	TT_Complete.MeasurementUnit,
	|	TT_Complete.GLAccount,
	|	TT_Complete.Characteristic,
	|	TT_Complete.Batch,
	|	TT_Complete.Ownership,
	|	TT_Complete.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CompleteGrouped.LineNumber AS LineNumber,
	|	TT_CompleteGrouped.Products AS Products,
	|	TT_CompleteGrouped.Characteristic AS Characteristic,
	|	TT_CompleteGrouped.Batch AS Batch,
	|	TT_CompleteGrouped.Ownership AS Ownership,
	|	TT_CompleteGrouped.MeasurementUnit AS MeasurementUnit,
	|	TT_CompleteGrouped.QuantityConsumed AS QuantityConsumed,
	|	TT_CompleteGrouped.QuantityAllocated AS QuantityAllocated,
	|	TT_CompleteGrouped.GLAccount AS GLAccount
	|FROM
	|	TT_ByProductsCompleteGrouped AS TT_CompleteGrouped
	|WHERE
	|	TT_CompleteGrouped.QuantityConsumed <> TT_CompleteGrouped.QuantityAllocated
	|
	|ORDER BY
	|	LineNumber";
	
	MessageTemplate = NStr(
		"en = 'For by-product ""%1"", the allocated quantity (%2 %3) does not match the produced quantity (%4 %3). Allocate the difference of %5 %3.'; ru = 'Для побочной продукции %1 выделенное количество (%2 %3) не соответствует произведенному количеству (%4 %3). Выделите разницу %5 %3.';pl = 'Dla produktu ubocznego ""%1"", przydzielona ilość (%2 %3) nie odpowiada wyprodukowanej ilości (%4 %3). Przydziel różnicę %5 %3.';es_ES = 'Para el trozo y deterioro ""%1"", la cantidad asignada (%2 %3) no coincide con la cantidad producida (%4 %3). Asignar la diferencia de %5 %3.';es_CO = 'Para el trozo y deterioro ""%1"", la cantidad asignada (%2 %3) no coincide con la cantidad producida (%4 %3). Asignar la diferencia de %5 %3.';tr = '""%1"" yan ürünü için, tahsis edilen miktar (%2 %3) üretilen miktarla (%4 %3) eşleşmiyor. %5 %3 farkını tahsis edin.';it = 'Per lo scarto e residuo ""%1"", la quantità allocata (%2 %3) non corrisponde alla quantità prodotta (%4 %3). Allocare la differenza di %5 %3.';de = 'Bei Nebenprodukt ""%1"", stimmt die zugewiesene Menge (%2 %3) nicht mit der erzeugten Menge (%4 %3) überein. Ordnen Sie die Differenz von %5%3 zu.'");
	
	Result = Query.Execute();
	
	Sel = Result.Select();
	
	While Sel.Next() Do
		
		ProductPresentationArray = New Array;
		ProductPresentationArray.Add(Sel.Products);
		If Not IsBlankString(Sel.Characteristic) Then
			ProductPresentationArray.Add(Sel.Characteristic);
		EndIf;
		If Not IsBlankString(Sel.Batch) Then
			ProductPresentationArray.Add(Sel.Batch);
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessageTemplate,
			StrConcat(ProductPresentationArray, " "),
			Sel.QuantityConsumed,
			Sel.MeasurementUnit,
			Sel.QuantityAllocated,
			Sel.QuantityAllocated - Sel.QuantityConsumed);
		
		If Sel.LineNumber = Null Then
			MessageField = "Allocation";
		Else
			MessageField = CommonClientServer.PathToTabularSection("Allocation", Sel.LineNumber, "CorrQuantity");
		EndIf;
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, MessageField, , Cancel);
		
	EndDo;
	
EndProcedure

Procedure AllocateAssembly(AllocateActivities = False)
	
	Query = New Query;
	
	Query.SetParameter("TableProduction",		 Products);
	Query.SetParameter("TableInventory",		 Inventory);
	query.SetParameter("TableActivities",		 Activities);
	
	Query.SetParameter("UseCharacteristics",	 GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches",			 GetFunctionalOption("UseBatches"));
	
	Query.SetParameter("AllocateActivities",	 AllocateActivities);
	
	Query.SetParameter("OwnInventory",			 Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("Subcontracting",		 TypeOf(SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived"));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CAST(ProductionProducts.Ownership AS Catalog.InventoryOwnership) AS Ownership,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN &AllocateActivities
	|						THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|					ELSE ProductionProducts.ConsumptionGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN &Subcontracting
	|						THEN ProductionProducts.ConsumptionGLAccount
	|					ELSE ProductionProducts.InventoryGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TableProduction
	|FROM
	|	&TableProduction AS ProductionProducts
	|WHERE
	|	ProductionProducts.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.Products AS CorrProducts,
	|	TableProduction.Characteristic AS CorrCharacteristic,
	|	TableProduction.Batch AS CorrBatch,
	|	TableProduction.Ownership AS CorrOwnership,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.CorrGLAccount AS CorrGLAccount,
	|	TableProduction.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	CatalogProducts.MeasurementUnit AS CorrMeasurementUnit,
	|	SUM(TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	TableProduction AS TableProduction
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableProduction.Products = CatalogProducts.Ref
	|
	|GROUP BY
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	CatalogProducts.MeasurementUnit,
	|	TableProduction.Specification,
	|	TableProduction.Characteristic,
	|	TableProduction.CorrGLAccount,
	|	TableProduction.ConsumptionGLAccount,
	|	TableProduction.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableVT.CorrLineNumber AS CorrLineNumber,
	|	TemporaryTableVT.CorrProducts AS CorrProducts,
	|	TemporaryTableVT.CorrCharacteristic AS CorrCharacteristic,
	|	TemporaryTableVT.CorrBatch AS CorrBatch,
	|	TemporaryTableVT.CorrOwnership AS CorrOwnership,
	|	TemporaryTableVT.Specification AS Specification,
	|	TemporaryTableVT.CorrGLAccount AS CorrGLAccount,
	|	TemporaryTableVT.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TemporaryTableVT.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TemporaryTableVT.CorrQuantity AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TemporaryTableVT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.CorrProducts AS CorrProducts,
	|	TableProductsContent.CorrCharacteristic AS CorrCharacteristic,
	|	TableProductsContent.CorrBatch AS CorrBatch,
	|	TableProductsContent.CorrOwnership AS CorrOwnership,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TableProductsContent.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN TableMaterials.Quantity = 0
	|			THEN 1
	|		ELSE TableMaterials.Quantity
	|	END * TableProductsContent.CorrQuantity * ISNULL(CatalogUOM.Factor, 1) / TableBOM.Quantity AS TMQuantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials AS TableBOM
	|		ON TableProductsContent.Specification = TableBOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (TableMaterials.MeasurementUnit = CatalogUOM.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	0,
	|	TableProductsContent.CorrLineNumber,
	|	TableProductsContent.CorrProducts,
	|	TableProductsContent.CorrCharacteristic,
	|	TableProductsContent.CorrBatch,
	|	TableProductsContent.CorrOwnership,
	|	TableProductsContent.Specification,
	|	TableProductsContent.CorrGLAccount,
	|	TableProductsContent.ConsumptionGLAccount,
	|	TableProductsContent.CorrMeasurementUnit,
	|	TableProductsContent.CorrQuantity,
	|	CASE
	|		WHEN TableActivities.Quantity = 0
	|			THEN 1
	|		ELSE TableActivities.Quantity
	|	END * CASE
	|		WHEN TableActivities.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Fixed)
	|			THEN 1
	|		ELSE TableProductsContent.CorrQuantity / TableBOM.Quantity
	|	END,
	|	UNDEFINED,
	|	TableActivities.Activity,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	UNDEFINED,
	|	FALSE
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials AS TableBOM
	|		ON TableProductsContent.Specification = TableBOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS TableActivities
	|		ON TableProductsContent.Specification = TableActivities.Ref
	|WHERE
	|	&AllocateActivities
	|	AND TableBOM.UseRouting
	|
	|ORDER BY
	|	Order,
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity AS Quantity
	|INTO TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableActivities.LineNumber AS LineNumber,
	|	TableActivities.Activity AS Activity,
	|	&OwnInventory AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableActivities.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	TableActivities.Quantity AS Quantity
	|INTO TableActivities
	|FROM
	|	&TableActivities AS TableActivities
	|WHERE
	|	&AllocateActivities
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|				OR CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN TableInventory.InventoryReceivedGLAccount
	|		ELSE TableInventory.InventoryGLAccount
	|	END AS GLAccount,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	TableInventory.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.UOMClassifier.EmptyRef) AS CorrMeasurementUnit,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	0 AS CorrLineNumber,
	|	0 AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TableInventory AS TableInventory
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	0,
	|	TableActivities.LineNumber,
	|	TableActivities.Activity,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	TableActivities.Ownership,
	|	TableActivities.GLAccount,
	|	UNDEFINED,
	|	TableActivities.Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef),
	|	TableActivities.GLAccount,
	|	VALUE(Catalog.Products.EmptyRef),
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef),
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	VALUE(Catalog.InventoryOwnership.EmptyRef),
	|	VALUE(Catalog.UOMClassifier.EmptyRef),
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef),
	|	0,
	|	0,
	|	FALSE
	|FROM
	|	TableActivities AS TableActivities
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProduction = ResultsArray[2].Unload();
	TableProductsContent = ResultsArray[3].Unload();
	MaterialsTable = ResultsArray[6].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.BOMLineType.Node Then
			NodesBillsOfMaterialstack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesBillsOfMaterialstack);
			TableProductsContent.Delete(ProductsRow);
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProduction.GroupBy(
		"ConsumptionGLAccount,
		|CorrBatch,
		|CorrCharacteristic,
		|CorrGLAccount,
		|CorrMeasurementUnit,
		|CorrOwnership,
		|CorrProducts,
		|Distributed,
		|Specification",
		"CorrQuantity");
	TableProduction.Indexes.Add("CorrProducts, CorrCharacteristic");
	
	TableProductsContent.GroupBy(
		"CorrProducts,
		|CorrCharacteristic,
		|CorrBatch,
		|CorrOwnership,
		|Specification,
		|CorrGLAccount,
		|ConsumptionGLAccount,
		|CorrQuantity,
		|CorrMeasurementUnit,
		|TMProducts,
		|TMCharacteristic,
		|Distributed",
		"TMQuantity");
	TableProductsContent.Indexes.Add("TMProducts, TMCharacteristic");
	
	MaterialsTable.GroupBy(
		"Batch,
		|Characteristic,
		|ConsumptionGLAccount,
		|CorrBatch,
		|CorrCharacteristic,
		|CorrGLAccount,
		|CorrMeasurementUnit,
		|CorrOwnership,
		|CorrProducts,
		|Distributed,
		|GLAccount,
		|MeasurementUnit,
		|Order,
		|Ownership,
		|Products,
		|Specification",
		"Quantity,
		|CorrQuantity");
	MaterialsTable.Indexes.Add("Products, Characteristic, CorrProducts, CorrCharacteristic");
	
	DistributedMaterials = 0;
	ProductsCount	 = TableProductsContent.Count();
	MaterialsCount	 = MaterialsTable.Count();
	
	For n = 0 To MaterialsCount - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProducts",		StringMaterials.Products);
		SearchStructure.Insert("TMCharacteristic",	StringMaterials.Characteristic);
		
		SearchResult = TableProductsContent.FindRows(SearchStructure);
		If SearchResult.Count() <> 0 Then
			DistributeMaterialsAccordingToNorms(StringMaterials, SearchResult, MaterialsTable);
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
		
	EndDo;
	
	DistributedProducts = 0;
	For Each ProductsContentRow In TableProductsContent Do
		If ProductsContentRow.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
	EndDo;
	
	If DistributedMaterials < MaterialsCount Then
		If DistributedProducts = ProductsCount Then
			DistributionBase = TableProduction.Total("CorrQuantity");
			DistributeMaterialsByQuantity(TableProduction, MaterialsTable, DistributionBase);
		Else
			DistributeMaterialsByQuantity(TableProductsContent, MaterialsTable);
		EndIf;
	EndIf;
	
	Allocation.Load(MaterialsTable);
	Allocation.GroupBy(
		"CorrProducts,
		|CorrCharacteristic,
		|CorrBatch,
		|CorrOwnership,
		|CorrQuantity,
		|CorrMeasurementUnit,
		|CorrGLAccount,
		|Specification,
		|Products,
		|Characteristic,
		|Batch,
		|Ownership,
		|MeasurementUnit,
		|GLAccount,
		|ConsumptionGLAccount,
		|StructuralUnit,
		|CostObject",
		"Quantity");
	
EndProcedure

Procedure AllocateDisassembly()
	
	Query = New Query;
	
	Query.SetParameter("TableProduction",	 Products);
	Query.SetParameter("TableInventory",	 Inventory);
	
	Query.SetParameter("UseCharacteristics", GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches",		 GetFunctionalOption("UseBatches"));
	
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	ProductionProducts.MeasurementUnit AS MeasurementUnit,
	|	ProductionProducts.Quantity AS Quantity
	|INTO TableProduction
	|FROM
	|	&TableProduction AS ProductionProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.Products AS CorrProducts,
	|	TableProduction.Characteristic AS CorrCharacteristic,
	|	TableProduction.Batch AS CorrBatch,
	|	TableProduction.Ownership AS CorrOwnership,
	|	CatalogInventoryOwnership.OwnershipType AS CorrOwnershipType,
	|	TableProduction.Specification AS Specification,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TableProduction.InventoryReceivedGLAccount
	|		ELSE TableProduction.InventoryGLAccount
	|	END AS CorrGLAccount,
	|	TableProduction.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	CatalogProducts.MeasurementUnit AS CorrMeasurementUnit,
	|	SUM(TableProduction.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	TableProduction AS TableProduction
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableProduction.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableProduction.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON TableProduction.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	CatalogInventoryOwnership.OwnershipType,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TableProduction.InventoryReceivedGLAccount
	|		ELSE TableProduction.InventoryGLAccount
	|	END,
	|	TableProduction.ConsumptionGLAccount,
	|	CatalogProducts.MeasurementUnit,
	|	TableProduction.Specification,
	|	TableProduction.Characteristic,
	|	TableProduction.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableVT.CorrLineNumber AS CorrLineNumber,
	|	TemporaryTableVT.CorrProducts AS CorrProducts,
	|	TemporaryTableVT.CorrCharacteristic AS CorrCharacteristic,
	|	TemporaryTableVT.CorrBatch AS CorrBatch,
	|	TemporaryTableVT.CorrOwnership AS CorrOwnership,
	|	TemporaryTableVT.CorrOwnershipType AS CorrOwnershipType,
	|	TemporaryTableVT.Specification AS Specification,
	|	TemporaryTableVT.CorrGLAccount AS CorrGLAccount,
	|	TemporaryTableVT.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TemporaryTableVT.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TemporaryTableVT.CorrQuantity AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TemporaryTableVT
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.CorrProducts AS CorrProducts,
	|	TableProductsContent.CorrCharacteristic AS CorrCharacteristic,
	|	TableProductsContent.CorrBatch AS CorrBatch,
	|	TableProductsContent.CorrOwnership AS CorrOwnership,
	|	TableProductsContent.CorrOwnershipType AS CorrOwnershipType,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TableProductsContent.CorrMeasurementUnit AS CorrMeasurementUnit,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	1 AS Quantity,
	|	1 AS TMQuantity,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials AS TableBOM
	|		ON TableProductsContent.Specification = TableBOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableInventory.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	TableInventory.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.CostPercentage AS CostPercentage
	|INTO TableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	CatalogInventoryOwnership.OwnershipType AS OwnershipType,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TableInventory.InventoryReceivedGLAccount
	|		ELSE TableInventory.InventoryGLAccount
	|	END AS GLAccount,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ConsumptionGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS CorrProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CorrCharacteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS CorrBatch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS CorrOwnership,
	|	VALUE(Catalog.UOMClassifier.EmptyRef) AS CorrMeasurementUnit,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	0 AS CorrLineNumber,
	|	0 AS CorrQuantity,
	|	TableInventory.CostPercentage AS CostPercentage,
	|	FALSE AS NewRow,
	|	FALSE AS AccountExecuted,
	|	FALSE AS Distributed
	|FROM
	|	TableInventory AS TableInventory
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProduction = ResultsArray[2].Unload();
	TableProductsContent = ResultsArray[3].Unload();
	MaterialsTable = ResultsArray[5].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.BOMLineType.Node Then
			NodesBillsOfMaterialstack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesBillsOfMaterialstack);
			TableProductsContent.Delete(ProductsRow);
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProductsContent.GroupBy(
		"CorrProducts,
		|CorrCharacteristic,
		|CorrBatch,
		|CorrOwnership,
		|CorrOwnershipType,
		|Specification,
		|CorrGLAccount,
		|ConsumptionGLAccount,
		|CorrQuantity,
		|CorrMeasurementUnit,
		|CorrLineNumber,
		|TMProducts,
		|TMCharacteristic");
	TableProductsContent.Indexes.Add("CorrProducts, CorrCharacteristic, CorrBatch, CorrOwnership, Specification");
	
	MaterialsTable.Indexes.Add("CorrProducts, CorrCharacteristic");
	
	DistributedProducts	= 0;
	MaterialsCount		= MaterialsTable.Count();
	
	For Each StringProducts In TableProduction Do
		
		SearchStructureProducts = New Structure;
		SearchStructureProducts.Insert("CorrProducts",		 StringProducts.CorrProducts);
		SearchStructureProducts.Insert("CorrCharacteristic", StringProducts.CorrCharacteristic);
		SearchStructureProducts.Insert("CorrBatch",			 StringProducts.CorrBatch);
		SearchStructureProducts.Insert("CorrOwnership",		 StringProducts.CorrOwnership);
		SearchStructureProducts.Insert("Specification",		 StringProducts.Specification);
		
		BaseCostPercentage = 0;
		SearchResultProducts = TableProductsContent.FindRows(SearchStructureProducts);
		For Each RowSearchProducts In SearchResultProducts Do
			
			SearchStructureMaterials = New Structure;
			SearchStructureMaterials.Insert("NewRow", False);
			SearchStructureMaterials.Insert("Products", RowSearchProducts.TMProducts);
			SearchStructureMaterials.Insert("Characteristic", RowSearchProducts.TMCharacteristic);
			
			SearchResultMaterials		= MaterialsTable.FindRows(SearchStructureMaterials);
			QuantityContentMaterials	= SearchResultMaterials.Count();
			
			For Each RowSearchMaterials In SearchResultMaterials Do
				StringProducts.Distributed			= True;
				RowSearchMaterials.Distributed		= True;
				RowSearchMaterials.AccountExecuted	= True;
				BaseCostPercentage					= BaseCostPercentage + RowSearchMaterials.CostPercentage;
			EndDo;
			
		EndDo;
		
		If BaseCostPercentage > 0 Then
			DistributeProductsAccordingToNorms(StringProducts, MaterialsTable, BaseCostPercentage);
		EndIf;
		
		If StringProducts.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
		
	EndDo;
	
	DistributedMaterials = 0;
	For Each StringMaterials In MaterialsTable Do
		If StringMaterials.Distributed And Not StringMaterials.NewRow Then
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
	EndDo;
	
	If DistributedProducts < TableProduction.Count() Then
		If DistributedMaterials = MaterialsCount Then
			BaseCostPercentage = MaterialsTable.Total("CostPercentage");
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable, BaseCostPercentage, False);
		Else
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable);
		EndIf;
	EndIf;
	
	MaterialsTable.Sort("CorrLineNumber, LineNumber");
	
	Allocation.Load(MaterialsTable);
	
EndProcedure

Procedure AllocateConvertFromWIP()
	
	AllocateAssembly(True);
	
	// Use by products accounting starting from
	UseByProductsAccountingStartingFrom = Constants.UseByProductsAccountingStartingFrom.Get();
	UseByProductsAccounting = ?(ValueIsFilled(UseByProductsAccountingStartingFrom),
		UseByProductsAccountingStartingFrom <= Date,
		False);
		
	If UseByProductsAccounting Then
		AllocateByProducts();
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Allocation", Allocation);
	Query.SetParameter("Company", Company);
	Query.SetParameter("Project", Project);
	Query.SetParameter("Ref", Ref);
	If IsNew() Or ManualAllocation Then
		Query.SetParameter("Period", EndOfDay(Date) + 1);
	Else
		Query.SetParameter("Period", PointInTime());
	EndIf;
	
	Query.Text =
	"SELECT
	|	Allocation.Products AS Products,
	|	Allocation.Characteristic AS Characteristic
	|INTO TT_Allocation
	|FROM
	|	&Allocation AS Allocation
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkInProgressBalance.StructuralUnit AS StructuralUnit,
	|	WorkInProgressBalance.CostObject AS CostObject,
	|	WorkInProgressBalance.Products AS Products,
	|	WorkInProgressBalance.Characteristic AS Characteristic,
	|	WorkInProgressBalance.QuantityBalance AS Quantity
	|INTO TT_Balances
	|FROM
	|	AccumulationRegister.WorkInProgress.Balance(
	|			&Period,
	|			Company = &Company
	|				AND (Products, Characteristic) IN
	|					(SELECT
	|						TT_Allocation.Products,
	|						TT_Allocation.Characteristic
	|					FROM
	|						TT_Allocation AS TT_Allocation)) AS WorkInProgressBalance
	|
	|UNION ALL
	|
	|SELECT
	|	WorkInProgress.StructuralUnit,
	|	WorkInProgress.CostObject,
	|	WorkInProgress.Products,
	|	WorkInProgress.Characteristic,
	|	WorkInProgress.Quantity
	|FROM
	|	TT_Allocation AS TT_Allocation
	|		INNER JOIN AccumulationRegister.WorkInProgress AS WorkInProgress
	|		ON TT_Allocation.Products = WorkInProgress.Products
	|			AND TT_Allocation.Characteristic = WorkInProgress.Characteristic
	|WHERE
	|	WorkInProgress.Recorder = &Ref
	|	AND WorkInProgress.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Balances.StructuralUnit AS StructuralUnit,
	|	TT_Balances.CostObject AS CostObject,
	|	TT_Balances.Products AS Products,
	|	TT_Balances.Characteristic AS Characteristic,
	|	SUM(TT_Balances.Quantity) AS Quantity
	|INTO TT_BalancesGrouped
	|FROM
	|	TT_Balances AS TT_Balances
	|
	|GROUP BY
	|	TT_Balances.StructuralUnit,
	|	TT_Balances.Characteristic,
	|	TT_Balances.CostObject,
	|	TT_Balances.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_BalancesGrouped.Products AS Products,
	|	TT_BalancesGrouped.Characteristic AS Characteristic,
	|	TT_BalancesGrouped.Quantity AS Quantity,
	|	TT_BalancesGrouped.StructuralUnit AS StructuralUnit,
	|	TT_BalancesGrouped.CostObject AS CostObject,
	|	CostObjects.Products AS CorrProducts,
	|	CostObjects.Characteristic AS CorrCharacteristic,
	|	CostObjects.ProductionOrder AS ProductionOrder,
	|	CostObjects.Project AS Project
	|FROM
	|	TT_BalancesGrouped AS TT_BalancesGrouped
	|		INNER JOIN Catalog.CostObjects AS CostObjects
	|		ON TT_BalancesGrouped.CostObject = CostObjects.Ref
	|WHERE
	|	CostObjects.Project = &Project
	|	AND TT_BalancesGrouped.Quantity > 0";
	
	BalancesTable = Query.Execute().Unload();
	
	NewAllocation = Allocation.UnloadColumns();
	
	SearchStructure = New Structure("Products, Characteristic, CorrProducts, CorrCharacteristic");
	SearchStructure.Insert("ProductionOrder", BasisDocument);
	SearchStructure.Insert("Project", Project);
	AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation);
	
	SearchStructure = New Structure("Products, Characteristic");
	SearchStructure.Insert("ProductionOrder", BasisDocument);
	SearchStructure.Insert("Project", Project);
	AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation);
	
	SearchStructure = New Structure("Products, Characteristic");
	SearchStructure.Insert("Project", Project);
	AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation);
	
	SearchStructure = New Structure("CorrProducts, CorrCharacteristic");
	SearchStructure.Insert("ProductionOrder", BasisDocument);
	SearchStructure.Insert("Project", Project);
	AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation, True);
	
	SearchStructure = New Structure("CorrProducts, CorrCharacteristic");
	SearchStructure.Insert("Project", Project);
	AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation, True);
	
	For Each AllocationRow In Allocation Do
		If AllocationRow.Quantity > 0 Then
			FillPropertyValues(NewAllocation.Add(), AllocationRow);
		EndIf;
	EndDo;
	
	Allocation.Load(NewAllocation);
	
EndProcedure

Procedure AllocateConvertFromWIP_FillStructuralUnitAndCostObjects(BalancesTable, SearchStructure, NewAllocation, AllocateByProducts = False)
	
	For Each AllocationRow In Allocation Do
		
		If AllocationRow.Quantity <= 0 Then
			Continue;
		EndIf;
		
		If Not AllocateByProducts And Not AllocationRow.ByProduct Then
			
			FillPropertyValues(SearchStructure, AllocationRow);
			
			BalancesTableRows = BalancesTable.FindRows(SearchStructure);
			For Each BalancesTableRow In BalancesTableRows Do
				
				If BalancesTableRow.Quantity <= 0 Then
					Continue;
				EndIf;
				
				NewAllocationRow = NewAllocation.Add();
				FillPropertyValues(NewAllocationRow, AllocationRow, , "Quantity");
				FillPropertyValues(NewAllocationRow, BalancesTableRow, "StructuralUnit, CostObject");
				
				NewAllocationRow.Quantity = Min(AllocationRow.Quantity, BalancesTableRow.Quantity);
				AllocationRow.Quantity = AllocationRow.Quantity - NewAllocationRow.Quantity;
				BalancesTableRow.Quantity = BalancesTableRow.Quantity - NewAllocationRow.Quantity;
				
				If AllocationRow.Quantity = 0 Then
					Break;
				EndIf;
				
			EndDo;
			
		ElsIf AllocateByProducts And AllocationRow.ByProduct Then
			
			FillPropertyValues(SearchStructure, AllocationRow);
			SearchStructure.CorrProducts = AllocationRow.Products;
			SearchStructure.CorrCharacteristic = AllocationRow.Characteristic;
			
			BalancesTableRows = BalancesTable.FindRows(SearchStructure);
			For Each BalancesTableRow In BalancesTableRows Do
				
				NewAllocationRow = NewAllocation.Add();
				FillPropertyValues(NewAllocationRow, AllocationRow);
				FillPropertyValues(NewAllocationRow, BalancesTableRow, "StructuralUnit, CostObject");
				
				AllocationRow.Quantity = AllocationRow.Quantity - NewAllocationRow.Quantity;
				Break;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CatalogBOM.Ref AS Ref,
	|	CatalogBOM.Quantity AS Quantity
	|INTO TT_CatalogBOM
	|FROM
	|	Catalog.BillsOfMaterials.Content AS CatalogBOM
	|WHERE
	|	CatalogBOM.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN ConstantUseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity * ISNULL(CatalogUOM.Factor, 1) / TT_CatalogBOM.Quantity * &ProductsQuantity) AS ExpenseNorm,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TT_CatalogBOM AS TT_CatalogBOM
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TT_CatalogBOM.Ref = TableMaterials.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableMaterials.Products = CatalogProducts.Ref)
	|			AND (CatalogProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (TableMaterials.MeasurementUnit = CatalogUOM.Ref),
	|	Constant.UseCharacteristics AS ConstantUseCharacteristics
	|
	|GROUP BY
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN ConstantUseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	StructureLineNumber";
	
	Query.SetParameter("Ref", StringProducts.TMSpecification);
	Query.SetParameter("ProductsQuantity", StringProducts.TMQuantity);
	
	NodesBillsOfMaterialstack.Add(StringProducts.TMSpecification);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'Recursive item inclusion is found %1 in BOM %2
					|The operation failed.'; 
					|ru = 'В спецификации %2 найдены рекурсивные ссылки %1
					|Операция не выполнена.';
					|pl = 'Włączenie elementu rekurencyjnego znajduje się %1 w specyfikacji materiałowej %2
					|Operacja nie powiodła się.';
					|es_ES = 'Inclusión del artículo recursivo está encontrada %1 en BOM %2
					|Operación fallada.';
					|es_CO = 'Inclusión del artículo recursivo está encontrada %1 en BOM %2
					|Operación fallada.';
					|tr = '%1 Ürün reçetesinde %2 tekrarlayan bir öğe bulundu
					|Operasyon başarısız oldu.';
					|it = 'Inclusione elemento ricorsivo è stato trovato %1 nella Di.Ba. %2
					|L''operazione è fallita.';
					|de = 'Die rekursive Elementeinbindung befindet sich %1 in der Stückliste %2
					|Die Operation ist fehlgeschlagen.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					Selection.Products,
					StringProducts.Specification);
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			StringProducts.TMQuantity = Selection.ExpenseNorm;
			StringProducts.TMSpecification = Selection.Specification;
			FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack);
		Else
			NewRow = TableProduction.Add();
			FillPropertyValues(NewRow, StringProducts);
			NewRow.TMContentRowType = Selection.ContentRowType;
			NewRow.TMProducts = Selection.Products;
			NewRow.TMCharacteristic = Selection.Characteristic;
			NewRow.TMQuantity = Selection.ExpenseNorm;
			NewRow.TMSpecification = Selection.Specification;
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	
EndProcedure

Procedure DistributeMaterialsAccordingToNorms(StringMaterials, BaseTable, MaterialsTable)
	
	StringMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow In BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure

Procedure DistributeMaterialsByQuantity(BaseTable, MaterialsTable, DistributionBase = 0)
	
	ExcDistributed = False;
	If DistributionBase = 0 Then
		ExcDistributed = True;
		For Each BaseRow In BaseTable Do
			If Not BaseRow.Distributed Then
				DistributionBase = DistributionBase + BaseRow.CorrQuantity;
			EndIf;
		EndDo;
	EndIf;
	
	For n = 0 To MaterialsTable.Count() - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		If Not StringMaterials.Distributed Then
			DistributeTabularSectionStringMaterials(StringMaterials, BaseTable,
				MaterialsTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable,
	DistributionBase, AccordingToNorms, ExcDistributed = False)
	
	InitQuantity = 0;
	QuantityToWriteOff = StringMaterials.Quantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	For Each BasicTableRow In BaseTable Do
		
		If ExcDistributed And BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitQuantity = QuantityToWriteOff Then
			Continue;
		EndIf;
		
		ExcludedFields = ?(ValueIsFilled(BasicTableRow.ConsumptionGLAccount), "", "ConsumptionGLAccount");
		
		If ValueIsFilled(StringMaterials.CorrProducts) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, StringMaterials);
			FillPropertyValues(NewRow, BasicTableRow, , ExcludedFields);
			StringMaterials = NewRow;
		Else
			FillPropertyValues(StringMaterials, BasicTableRow, , ExcludedFields);
		EndIf;
		
		If AccordingToNorms Then
			BasicTableQuantity = BasicTableRow.TMQuantity;
		Else
			BasicTableQuantity = BasicTableRow.CorrQuantity
		EndIf;
		
		StringMaterials.Quantity = Round(
			(QuantityToWriteOff - InitQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1);
		
		If (InitQuantity + StringMaterials.Quantity) > QuantityToWriteOff Then
			StringMaterials.Quantity = QuantityToWriteOff - InitQuantity;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - BasicTableQuantity;
			InitQuantity = InitQuantity + StringMaterials.Quantity;
		EndIf;
		
	EndDo;
	
	If InitQuantity < QuantityToWriteOff Then
		StringMaterials.Quantity = StringMaterials.Quantity + (QuantityToWriteOff - InitQuantity);
	EndIf;
	
EndProcedure

Procedure DistributeProductsAccordingToNorms(StringProducts, BaseTable, DistributionBase)
	
	DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, True);
	
EndProcedure

Procedure DistributeProductsAccordingToQuantity(TableProduction, BaseTable,
	DistributionBase = 0, ExcDistributed = True)
	
	If ExcDistributed Then
		For Each StringMaterials In BaseTable Do
			If Not StringMaterials.NewRow
				And Not StringMaterials.Distributed Then
				DistributionBase = DistributionBase + StringMaterials.CostPercentage;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringProducts In TableProduction Do
		
		If Not StringProducts.Distributed Then
			DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DistributeTabularSectionStringProducts(ProductsRow, BaseTable, DistributionBase,
	AccordingToNorms, ExeptDistribution = False)
	
	InitQuantity = 0;
	QuantityToWriteOff = ProductsRow.CorrQuantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	DistributionRow = Undefined;
	For n = 0 To BaseTable.Count() - 1 Do
		
		StringMaterials = BaseTable[n];
		
		If InitQuantity = QuantityToWriteOff
			Or StringMaterials.NewRow Then
			StringMaterials.AccountExecuted = False;
			Continue;
		EndIf;
		
		If AccordingToNorms And Not StringMaterials.AccountExecuted Then
			Continue;
		EndIf;
		
		StringMaterials.AccountExecuted = False;
		
		If Not AccordingToNorms And ExeptDistribution
			And StringMaterials.Distributed Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(StringMaterials.CorrProducts) Then
			Distributed = StringMaterials.Distributed;
			FillPropertyValues(StringMaterials, ProductsRow);
			DistributionRow = StringMaterials;
			DistributionRow.Distributed = Distributed;
		Else
			DistributionRow = BaseTable.Add();
			FillPropertyValues(DistributionRow, StringMaterials);
			FillPropertyValues(DistributionRow, ProductsRow);
			DistributionRow.NewRow = True;
		EndIf;
		
		DistributionRow.Quantity = Round(
			(QuantityToWriteOff - InitQuantity) * StringMaterials.CostPercentage
			/ ?(DistributionBaseQuantity = 0, 1, DistributionBaseQuantity), 3, 1);
		
		If DistributionRow.Quantity = 0 Then
			DistributionRow.Quantity = QuantityToWriteOff;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - StringMaterials.CostPercentage;
			InitQuantity = InitQuantity + DistributionRow.Quantity;
		EndIf;
		
		If InitQuantity > QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity - (InitQuantity - QuantityToWriteOff);
			InitQuantity = QuantityToWriteOff;
		EndIf;
		
	EndDo;
	
	If DistributionRow <> Undefined Then
		
		If InitQuantity < QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity + (QuantityToWriteOff - InitQuantity);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ByProductsAllocation

Procedure AllocateByProducts()
	
	Query = New Query;
	
	Query.SetParameter("TableByProducts",	Disposals);
	Query.SetParameter("TableProducts",		Products);
	
	Query.SetParameter("UseCharacteristics",GetFunctionalOption("UseCharacteristics"));
	Query.SetParameter("UseBatches",		GetFunctionalOption("UseBatches"));
	
	Query.SetParameter("OwnInventory",		Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	TableByProducts.LineNumber AS LineNumber,
	|	TableByProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableByProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableByProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableByProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	TableByProducts.MeasurementUnit AS MeasurementUnit,
	|	TableByProducts.Quantity AS Quantity
	|INTO TableByProducts
	|FROM
	|	&TableByProducts AS TableByProducts
	|WHERE
	|	TableByProducts.Quantity > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableByProducts.LineNumber) AS CorrLineNumber,
	|	TableByProducts.Products AS CorrProducts,
	|	TableByProducts.Characteristic AS CorrCharacteristic,
	|	TableByProducts.Batch AS CorrBatch,
	|	TableByProducts.Ownership AS CorrOwnership,
	|	TableByProducts.InventoryGLAccount AS CorrGLAccount,
	|	TableByProducts.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	CatalogProducts.MeasurementUnit AS CorrMeasurementUnit,
	|	SUM(TableByProducts.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	TableByProducts AS TableByProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableByProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableByProducts.Products = CatalogProducts.Ref
	|
	|GROUP BY
	|	TableByProducts.Batch,
	|	TableByProducts.Ownership,
	|	TableByProducts.ConsumptionGLAccount,
	|	CatalogProducts.MeasurementUnit,
	|	TableByProducts.Characteristic,
	|	TableByProducts.InventoryGLAccount,
	|	TableByProducts.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN TableProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableProducts.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	TableProducts.MeasurementUnit AS MeasurementUnit,
	|	TableProducts.Quantity AS Quantity
	|INTO TableProducts
	|FROM
	|	&TableProducts AS TableProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsByProducts.Ref AS Ref,
	|	BillsOfMaterialsByProducts.LineNumber AS LineNumber,
	|	BillsOfMaterialsByProducts.Product AS Products,
	|	BillsOfMaterialsByProducts.Characteristic AS Characteristic,
	|	BillsOfMaterialsByProducts.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	BillsOfMaterialsByProducts.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterials.Owner AS FinishedProduct,
	|	BillsOfMaterials.ProductCharacteristic AS FinishedCharacteristic,
	|	BillsOfMaterials.Quantity AS FinishedQuantity
	|INTO TT_ByProducts
	|FROM
	|	TableProducts AS TableProducts
	|		INNER JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|			INNER JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|			ON (BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref)
	|			LEFT JOIN Catalog.UOM AS UOM
	|			ON BillsOfMaterialsByProducts.MeasurementUnit = UOM.Ref
	|		ON (TableProducts.Specification = BillsOfMaterials.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN TableProducts.InventoryReceivedGLAccount
	|		ELSE TableProducts.InventoryGLAccount
	|	END AS GLAccount,
	|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
	|	TableProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	TableProducts.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	FALSE AS Distributed
	|FROM
	|	TableProducts AS TableProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableProducts.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON TableProducts.Ownership = CatalogInventoryOwnership.Ref
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN TT_ByProducts.Quantity IS NULL
	|			THEN 0
	|		ELSE TableProducts.Quantity * ISNULL(TableProductsUOM.Factor, 1) * TT_ByProducts.Quantity / TT_ByProducts.FinishedQuantity
	|	END AS TMQuantity,
	|	TT_ByProducts.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TT_ByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	FALSE AS Distributed,
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.InventoryGLAccount AS ConsumptionGLAccount,
	|	TableProducts.MeasurementUnit AS MeasurementUnit,
	|	TableProducts.Quantity AS Quantity,
	|	TableProducts.Specification AS Specification
	|FROM
	|	TableProducts AS TableProducts
	|		LEFT JOIN TT_ByProducts AS TT_ByProducts
	|		ON TableProducts.Products = TT_ByProducts.FinishedProduct
	|			AND TableProducts.Characteristic = TT_ByProducts.FinishedCharacteristic
	|		LEFT JOIN Catalog.UOM AS TableProductsUOM
	|		ON TableProducts.MeasurementUnit = TableProductsUOM.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	0 AS LineNumber,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS Ownership,
	|	TableByProducts.ConsumptionGLAccount AS GLAccount,
	|	VALUE(Catalog.UOMClassifier.EmptyRef) AS MeasurementUnit,
	|	0 AS Quantity,
	|	TableByProducts.InventoryGLAccount AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ConsumptionGLAccount,
	|	TableByProducts.Products AS CorrProducts,
	|	TableByProducts.Characteristic AS CorrCharacteristic,
	|	TableByProducts.Batch AS CorrBatch,
	|	TableByProducts.Ownership AS CorrOwnership,
	|	CatalogProducts.MeasurementUnit AS CorrMeasurementUnit,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	TableByProducts.LineNumber AS CorrLineNumber,
	|	TableByProducts.Quantity * ISNULL(CatalogUOM.Factor, 1) AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TableByProducts AS TableByProducts
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON TableByProducts.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON TableByProducts.Products = CatalogProducts.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	// Finished products
	TableProduction = ResultsArray[4].Unload();
	// By products content
	TableProductsContent = ResultsArray[5].Unload();
	// By products
	ByProductsTable = ResultsArray[6].Unload();
	
	DistributedByProducts	= 0;
	ProductsCount			= TableProductsContent.Count();
	ByProductsCount			= ByProductsTable.Count();
	
	For n = 0 To ByProductsCount - 1 Do
		
		StringByProducts = ByProductsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProducts",		StringByProducts.CorrProducts);
		SearchStructure.Insert("TMCharacteristic",	StringByProducts.CorrCharacteristic);
		
		SearchResult = TableProductsContent.FindRows(SearchStructure);
		If SearchResult.Count() <> 0 Then
			DistributeByProductsAccordingToNorms(StringByProducts, SearchResult, ByProductsTable, True);
			DistributedByProducts = DistributedByProducts + 1;
		EndIf;
		
	EndDo;
	
	DistributedProducts = 0;
	For Each ProductsContentRow In TableProductsContent Do
		If ProductsContentRow.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
	EndDo;
	
	If DistributedByProducts < ByProductsCount Then
		If DistributedProducts = ProductsCount Then
			DistributionBase = TableProduction.Total("Quantity");
			DistributeByProductsByQuantity(TableProduction, ByProductsTable, DistributionBase);
		Else
			DistributeByProductsByQuantity(TableProductsContent, ByProductsTable);
		EndIf;
	EndIf;
	
	ByProductsTable.Sort("CorrLineNumber, LineNumber");
	
	For Each ByProductsLine In ByProductsTable Do
		
		If ByProductsLine.Quantity > 0 And ByProductsLine.CorrQuantity > 0 Then
			
			AllocationLine = Allocation.Add();
			FillPropertyValues(AllocationLine, ByProductsLine);
			AllocationLine.ByProduct = True;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DistributeByProductsAccordingToNorms(StringMaterials, BaseTable, MaterialsTable, ByProduct = False)
	
	StringMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow In BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionStringByProducts(StringMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure

Procedure DistributeByProductsByQuantity(BaseTable, MaterialsTable, DistributionBase = 0)
	
	ExcDistributed = False;
	If DistributionBase = 0 Then
		ExcDistributed = True;
		For Each BaseRow In BaseTable Do
			If Not BaseRow.Distributed Then
				DistributionBase = DistributionBase + BaseRow.Quantity;
			EndIf;
		EndDo;
	EndIf;
	
	For n = 0 To MaterialsTable.Count() - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		If Not StringMaterials.Distributed Then
			DistributeTabularSectionStringByProducts(
				StringMaterials,
				BaseTable,
				MaterialsTable,
				DistributionBase,
				False,
				ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure DistributeTabularSectionStringByProducts(StringMaterials, BaseTable, MaterialsTable,
	DistributionBase, AccordingToNorms, ExcDistributed = False)
	
	InitCorrQuantity = 0;
	
	CorrQuantityToWriteOff = StringMaterials.CorrQuantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	For Each BasicTableRow In BaseTable Do
		
		If ExcDistributed And BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitCorrQuantity = CorrQuantityToWriteOff Then
			Continue;
		EndIf;
		
		ExcludedFields = ?(ValueIsFilled(BasicTableRow.ConsumptionGLAccount), "", "ConsumptionGLAccount");
		
		If ValueIsFilled(StringMaterials.Products) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, StringMaterials);
			FillPropertyValues(NewRow, BasicTableRow, , ExcludedFields);
			StringMaterials = NewRow;
		Else
			FillPropertyValues(StringMaterials, BasicTableRow, , ExcludedFields);
		EndIf;
		
		BasicTableQuantity = BasicTableRow.TMQuantity;
		
		StringMaterials.CorrQuantity = ?(DistributionBaseQuantity = 0,
			0,
			Round((CorrQuantityToWriteOff - InitCorrQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1));
		
		If (InitCorrQuantity + StringMaterials.CorrQuantity) > CorrQuantityToWriteOff Then
			StringMaterials.CorrQuantity = CorrQuantityToWriteOff - InitCorrQuantity;
			InitCorrQuantity = CorrQuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - BasicTableQuantity;
			InitCorrQuantity = InitCorrQuantity + StringMaterials.CorrQuantity;
		EndIf;
		
	EndDo;
	
	If InitCorrQuantity < CorrQuantityToWriteOff Then
		StringMaterials.CorrQuantity = StringMaterials.CorrQuantity + (CorrQuantityToWriteOff - InitCorrQuantity);
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf