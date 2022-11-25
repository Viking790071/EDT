#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillTabularSectionBySpecification(NodesTable, CheckActivities) Export
	
	Query = New Query;
	
	If NodesTable = Undefined Then
		
		Inventory.Clear();
		
		NodesTable = Inventory.UnloadColumns("LineNumber, Quantity, MeasurementUnit, Specification");
		
		QN = New NumberQualifiers(10, 0);
		Array = New Array;
		Array.Add(Type("Number"));
		TypeDescriptionN = New TypeDescription(Array, , ,QN);
		NodesTable.Columns.Add("RoundedQuantity", TypeDescriptionN);
		
		NotedTableRow = NodesTable.Add();
		NotedTableRow.LineNumber = 1;
		NotedTableRow.Quantity = Quantity;
		NotedTableRow.RoundedQuantity = Quantity;
		NotedTableRow.MeasurementUnit = MeasurementUnit;
		NotedTableRow.Specification = Specification;
		
		SpecificationQuantity = Common.ObjectAttributeValue(Specification, "Quantity");
		SpecificationQuantity = ?(SpecificationQuantity = Undefined, 0, SpecificationQuantity);
		
		If SpecificationQuantity > 1 
			And Quantity % SpecificationQuantity > 0 Then
			
			NotedTableRow.RoundedQuantity = (Int(Quantity / SpecificationQuantity) + 1) * SpecificationQuantity;
			
		EndIf; 
		
	EndIf;
	
	Query.SetParameter("TableProduction", NodesTable);
	Query.SetParameter("CheckActivities", CheckActivities);
	
	If CheckActivities Then
		TableActivities = Activities.Unload(, "Activity, Quantity, ConnectionKey");
	Else
		TableActivities = Activities.UnloadColumns("Activity, Quantity, ConnectionKey");
	EndIf;
	
	Query.SetParameter("TableActivities", TableActivities);
	Query.SetParameter("BasisDocument", BasisDocument);
	
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
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableActivities.Activity AS Activity,
	|	TableActivities.ConnectionKey AS ConnectionKey,
	|	TableActivities.Quantity AS Quantity
	|INTO TableActivities
	|FROM
	|	&TableActivities AS TableActivities
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN StructuralUnitData.TransferSource = VALUE(Catalog.BusinessUnits.EmptyRef)
	|			THEN ProductionOrder.StructuralUnit
	|		ELSE StructuralUnitData.TransferSource
	|	END AS InventoryStructuralUnit,
	|	StructuralUnitData.TransferSourceCell AS CellInventory
	|INTO TT_InventoryStructuralUnit
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitData
	|		ON ProductionOrder.StructuralUnit = StructuralUnitData.Ref
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
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
	|	TableMaterials.Specification AS Specification,
	|	ISNULL(TableActivities.ConnectionKey, 0) AS ActivityConnectionKey,
	|	TT_InventoryStructuralUnit.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TT_InventoryStructuralUnit.CellInventory AS CellInventory
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS TableOperations
	|		ON TableProduction.Specification = TableOperations.Ref
	|			AND (TableMaterials.ActivityConnectionKey = TableOperations.ConnectionKey)
	|			AND (BillOfMaterials.UseRouting)
	|		LEFT JOIN TableActivities AS TableActivities
	|		ON (TableMaterials.ActivityConnectionKey = TableActivities.ConnectionKey),
	|	Constant.UseCharacteristics AS UseCharacteristics,
	|	TT_InventoryStructuralUnit AS TT_InventoryStructuralUnit
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (NOT &CheckActivities
	|			OR NOT BillOfMaterials.UseRouting
	|			OR NOT TableActivities.Activity IS NULL)
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
	|	END,
	|	ISNULL(TableActivities.ConnectionKey, 0),
	|	TT_InventoryStructuralUnit.InventoryStructuralUnit,
	|	TT_InventoryStructuralUnit.CellInventory
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	SelectionResult = Query.Execute();
	Inventory.Load(SelectionResult.Unload());
	
	Inventory.GroupBy("Products, Characteristic, Batch, MeasurementUnit, Specification, ActivityConnectionKey,
		|InventoryStructuralUnit, CellInventory", "Quantity");
	
EndProcedure

Procedure FillByProductsWithBOM(NodesTable, CheckActivities) Export
	
	Query = New Query;
	
	If NodesTable = Undefined Then
		
		Disposals.Clear();
		
		NodesTable = Inventory.UnloadColumns("LineNumber, Quantity, MeasurementUnit, Specification");
		
		NotedTableRow = NodesTable.Add();
		NotedTableRow.LineNumber = 1;
		NotedTableRow.Quantity = Quantity;
		NotedTableRow.MeasurementUnit = MeasurementUnit;
		NotedTableRow.Specification = Specification;
		
	EndIf;
	
	Query.SetParameter("TableProduction", NodesTable);
	Query.SetParameter("CheckActivities", CheckActivities);
	
	If CheckActivities Then
		TableActivities = Activities.Unload(, "Activity, ActivityNumber, Quantity, ConnectionKey");
	Else
		TableActivities = Activities.UnloadColumns("Activity, ActivityNumber, Quantity, ConnectionKey");
	EndIf;
	
	Query.SetParameter("TableActivities", TableActivities);
	
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
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableActivities.Activity AS Activity,
	|	TableActivities.ActivityNumber AS ActivityNumber,
	|	TableActivities.ConnectionKey AS ConnectionKey,
	|	TableActivities.Quantity AS Quantity
	|INTO TableActivities
	|FROM
	|	&TableActivities AS TableActivities
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsByProducts.Product AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(BillsOfMaterialsByProducts.Quantity / BillOfMaterials.Quantity * ISNULL(ProductUOM.Factor, 1) * TableProduction.Quantity) AS Quantity,
	|	BillsOfMaterialsByProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(TableActivities.ConnectionKey, 0) AS ActivityConnectionKey
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Catalog.BillsOfMaterials AS BillOfMaterials
	|		ON TableProduction.Specification = BillOfMaterials.Ref
	|		LEFT JOIN Catalog.UOM AS ProductUOM
	|		ON TableProduction.MeasurementUnit = ProductUOM.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
	|		ON TableProduction.Specification = BillsOfMaterialsByProducts.Ref
	|		LEFT JOIN Catalog.BillsOfMaterials.Operations AS TableOperations
	|		ON TableProduction.Specification = TableOperations.Ref
	|			AND (BillsOfMaterialsByProducts.Activity = TableOperations.Activity)
	|			AND (BillOfMaterials.UseRouting)
	|		LEFT JOIN TableActivities AS TableActivities
	|		ON (BillsOfMaterialsByProducts.ActivityConnectionKey = TableActivities.ConnectionKey)
	|		LEFT JOIN Constant.UseCharacteristics AS UseCharacteristics
	|		ON (TRUE)
	|WHERE
	|	(NOT &CheckActivities
	|			OR NOT BillOfMaterials.UseRouting
	|			OR NOT TableActivities.Activity IS NULL)
	|
	|GROUP BY
	|	BillsOfMaterialsByProducts.MeasurementUnit,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN BillsOfMaterialsByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	ISNULL(TableActivities.ConnectionKey, 0),
	|	BillsOfMaterialsByProducts.Product";
	
	SelectionResult = Query.Execute();
	Disposals.Load(SelectionResult.Unload());
	
	Disposals.GroupBy("Products, Characteristic, Batch, MeasurementUnit, ActivityConnectionKey", "Quantity");
	
EndProcedure

Procedure FillInActivitiesByBOM(ActivityFilter = Undefined) Export
	
	Query = New Query;
	Query.SetParameter("Specification", Specification);
	SpecificationQuantity = Specification.Quantity;
	
	Query.SetParameter("Quantity", Quantity);
	If Quantity = 0 Or Not ValueIsFilled(SpecificationQuantity) Then
		Query.SetParameter("RoundedQuantity", SpecificationQuantity);
	ElsIf Quantity % SpecificationQuantity = 0 Then
		Query.SetParameter("RoundedQuantity", Quantity);
	Else
		Query.SetParameter("RoundedQuantity", (Int(Quantity / SpecificationQuantity) + 1) * SpecificationQuantity);
	EndIf;
	
	Query.SetParameter("MeasurementUnit", MeasurementUnit);
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("BusinessUnit", StructuralUnit);
	Query.SetParameter("GLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("WorkInProgress"));
	
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
	|SELECT
	|	BillsOfMaterialsOperations.Activity AS Activity,
	|	CatalogActivities.CostPool AS CostPool,
	|	CASE
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Fixed)
	|			THEN BillsOfMaterialsOperations.Quantity
	|		WHEN BillsOfMaterialsOperations.CalculationMethod = VALUE(Enum.BOMOperationCalculationMethod.Multiple)
	|			THEN &RoundedQuantity * ISNULL(CatalogUOM.Factor, 1) * BillsOfMaterialsOperations.Quantity / TT_BillsOfMaterials.Quantity
	|		ELSE &Quantity * ISNULL(CatalogUOM.Factor, 1) * BillsOfMaterialsOperations.Quantity / TT_BillsOfMaterials.Quantity
	|	END AS Quantity,
	|	BillsOfMaterialsOperations.Workload AS Workload,
	|	BillsOfMaterialsOperations.StandardTime AS StandardTime,
	|	BillsOfMaterialsOperations.TimeUOM AS TimeUOM,
	|	BillsOfMaterialsOperations.StandardTimeInUOM AS StandardTimeInUOM,
	|	BillsOfMaterialsOperations.ActivityNumber AS ActivityNumber,
	|	BillsOfMaterialsOperations.ConnectionKey AS ConnectionKey,
	|	BillsOfMaterialsOperations.LineNumber AS LineNumber,
	|	BillsOfMaterialsOperations.NextActivityNumber AS NextActivityNumber
	|INTO TT_Activities
	|FROM
	|	TT_BillsOfMaterials AS TT_BillsOfMaterials
	|		INNER JOIN Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|		ON TT_BillsOfMaterials.Ref = BillsOfMaterialsOperations.Ref
	|		INNER JOIN Catalog.ManufacturingActivities AS CatalogActivities
	|		ON (BillsOfMaterialsOperations.Activity = CatalogActivities.Ref)
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (CatalogUOM.Ref = &MeasurementUnit)";
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text + InformationRegisters.PredeterminedOverheadRates.GetActivitiesOverheadRatesQueryText();
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text +
	"SELECT
	|	TT_ActivitiesOverheadRates.Activity AS Activity,
	|	SUM(TT_ActivitiesOverheadRates.Rate) AS Rate
	|INTO TT_ActivitiesOverheadTotalRates
	|FROM
	|	TT_ActivitiesOverheadRates AS TT_ActivitiesOverheadRates
	|
	|GROUP BY
	|	TT_ActivitiesOverheadRates.Activity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Activities.Activity AS Activity,
	|	TT_Activities.ActivityNumber AS ActivityNumber,
	|	TT_Activities.NextActivityNumber AS NextActivityNumber,
	|	TT_Activities.LineNumber AS BOMLineNumber,
	|	TT_Activities.ConnectionKey AS ConnectionKey,
	|	TT_Activities.Quantity AS Quantity,
	|	TT_Activities.Workload AS StandardWorkload,
	|	TT_Activities.TimeUOM AS TimeUOM,
	|	TT_Activities.StandardTimeInUOM AS StandardTimeInUOM,
	|	TT_Activities.StandardTime AS StandardTime,
	|	ISNULL(ActivitiesOverheadRates.Rate, 0) AS Rate,
	|	TT_Activities.Quantity * TT_Activities.Workload * ISNULL(ActivitiesOverheadRates.Rate, 0) AS Total,
	|	TT_Activities.Quantity * TT_Activities.Workload AS ActualWorkload,
	|	&GLAccount AS GLAccount
	|FROM
	|	TT_Activities AS TT_Activities
	|		LEFT JOIN TT_ActivitiesOverheadTotalRates AS ActivitiesOverheadRates
	|		ON TT_Activities.Activity = ActivitiesOverheadRates.Activity
	|WHERE
	|	&ActivityFilter
	|
	|ORDER BY
	|	TT_Activities.ActivityNumber,
	|	TT_Activities.LineNumber";
	
	If ActivityFilter = Undefined Then
		
		Query.Text = StrReplace(Query.Text, "&ActivityFilter", "TRUE");
		
	Else
		
		Query.Text = StrReplace(Query.Text,
			"&ActivityFilter",
			"TT_Activities.ConnectionKey = &ConnectionKey");
		
		Query.SetParameter("ConnectionKey", ActivityFilter.ConnectionKey);
		
	EndIf;
	
	Activities.Load(Query.Execute().Unload());
	
EndProcedure

Procedure FillByProductionOrder(FillingData) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrder.Ref AS BasisRef,
	|	ProductionOrder.Posted AS BasisPosted,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.OrderState AS OrderState,
	|	ProductionOrder.Ref AS BasisDocument,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	StructuralUnitData.TransferSource AS InventoryStructuralUnit,
	|	StructuralUnitData.TransferSourceCell AS CellInventory,
	|	StructuralUnitData.RecipientOfWastes AS DisposalsStructuralUnit,
	|	StructuralUnitData.DisposalsRecipientCell AS DisposalsCell
	|INTO TT_Header
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.BusinessUnits AS StructuralUnitData
	|		ON ProductionOrder.StructuralUnit = StructuralUnitData.Ref
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ProductionOrderProducts.Products) AS Products,
	|	MIN(ProductionOrderProducts.Characteristic) AS Characteristic,
	|	MIN(ProductionOrderProducts.Quantity) AS Quantity,
	|	MIN(ProductionOrderProducts.MeasurementUnit) AS MeasurementUnit,
	|	MIN(ProductionOrderProducts.Specification) AS Specification,
	|	MAX(ProductionOrderProducts.LineNumber) AS LineNumber,
	|	ProductionOrderProducts.Ref AS Ref
	|INTO TT_Products
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.ProductionOrder.Products AS ProductionOrderProducts
	|		ON TT_Header.BasisDocument = ProductionOrderProducts.Ref
	|
	|GROUP BY
	|	ProductionOrderProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Header.BasisRef AS BasisRef,
	|	TT_Header.BasisPosted AS BasisPosted,
	|	TT_Header.Closed AS Closed,
	|	TT_Header.OrderState AS OrderState,
	|	TT_Header.BasisDocument AS BasisDocument,
	|	TT_Header.Company AS Company,
	|	TT_Header.StructuralUnit AS StructuralUnit,
	|	TT_Header.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TT_Header.CellInventory AS CellInventory,
	|	TT_Header.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	TT_Header.DisposalsCell AS DisposalsCell,
	|	TT_Products.Products AS Products,
	|	TT_Products.Characteristic AS Characteristic,
	|	TT_Products.Quantity AS Quantity,
	|	TT_Products.MeasurementUnit AS MeasurementUnit,
	|	TT_Products.Specification AS Specification
	|FROM
	|	TT_Header AS TT_Header
	|		LEFT JOIN TT_Products AS TT_Products
	|		ON TT_Header.BasisRef = TT_Products.Ref
	|			AND (TT_Products.LineNumber = 1)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure;
		VerifiedAttributesValues.Insert("OrderState", Selection.OrderState);
		VerifiedAttributesValues.Insert("Closed", Selection.Closed);
		VerifiedAttributesValues.Insert("Posted", Selection.BasisPosted);
		Documents.ProductionOrder.VerifyEnteringAbilityByProductionOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	IntermediateStructuralUnit = StructuralUnit;
	FillPropertyValues(ThisObject, Selection);
	
	If ValueIsFilled(StructuralUnit) Then
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
	
EndProcedure

// Procedure sets status completed to document and sets finish date for all operations.
//
Procedure CompleteWorkInProgress(FinishDate) Export
	
	For Each OperationLine In Activities Do
		OperationLine.Done = True;
		OperationLine.StartDate = ?(ValueIsFilled(OperationLine.StartDate), OperationLine.StartDate, FinishDate);
		OperationLine.FinishDate = ?(ValueIsFilled(OperationLine.FinishDate), OperationLine.FinishDate, FinishDate);
	EndDo;
	
	Status = Enums.ManufacturingOperationStatuses.Completed;
	
EndProcedure

// Reservation

Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
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
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.Company,
	|		ReservedProductsBalances.StructuralUnit,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		ReservedProductsBalances.Batch,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch
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
	|		DocumentRegisterRecordsReservedProducts.Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &Period
	|		AND (DocumentRegisterRecordsReservedProducts.Company, DocumentRegisterRecordsReservedProducts.StructuralUnit, DocumentRegisterRecordsReservedProducts.Products, DocumentRegisterRecordsReservedProducts.Characteristic, DocumentRegisterRecordsReservedProducts.Batch) IN
	|				(SELECT
	|					&Company,
	|					&StructuralUnit,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", InventoryStructuralUnit);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
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

Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.ProductionOrder") Then
		FillByProductionOrder(FillingData);
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	Status = Enums.ManufacturingOperationStatuses.Open;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If WriteMode = DocumentWriteMode.Posting Then
		CostObject = Catalogs.CostObjects.GetCostObject(Project, BasisDocument, Products, Characteristic);
		If Not ValueIsFilled(CostObject) Then
			Cancel = True;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Products) Then
		
		FOUseCharacteristics = Constants.UseCharacteristics.Get();
		
		CharacteristicPresentation = "";
		If FOUseCharacteristics And ValueIsFilled(Characteristic) Then
			CharacteristicPresentation = " (" + TrimAll(Characteristic) + ")";
		EndIf;
		
		ProductsList = TrimAll(Products) + CharacteristicPresentation;
		
		If Quantity > 0 Then
			ProductsList = ProductsList + ", " + Quantity + " " + TrimAll(MeasurementUnit);
		EndIf;
		
	Else
		
		ProductsList = TrimAll(CostObject);
		
	EndIf;
	
	// Work center types list
	WorkCenterTypesList = "";
	
	For Each ActivitiesLine In Activities Do
		
		For Each WCT In ActivitiesLine.Activity.WorkCenterTypes Do
			
			WorkCenterTypesList = WorkCenterTypesList + TrimAll(WCT.WorkcenterType) + ", ";
			
		EndDo;
		
	EndDo;
	
	If Not IsBlankString(WorkCenterTypesList) Then
		
		WorkCenterTypesList = Left(WorkCenterTypesList, StrLen(WorkCenterTypesList) - 2);
		
	EndIf;
	
	// Operations list
	OperationsList = "";
	
	For Each ActivitiesLine In Activities Do
		
		If ValueIsFilled(OperationsList) Then
			OperationsList = OperationsList + Chars.LF;
		EndIf;
		OperationsList = OperationsList + ActivitiesLine.ActivityNumber + ", " + TrimAll(ActivitiesLine.Activity);
		
	EndDo;
	
	FillOutputMark();
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);

	SetProManageStatus();
	
	If InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.InventoryStructuralUnit <> InventoryStructuralUnit Then
				TabularSectionRow.InventoryStructuralUnit = InventoryStructuralUnit;
			EndIf;
			If TabularSectionRow.CellInventory <> CellInventory Then
				TabularSectionRow.CellInventory = CellInventory;
			EndIf;
		EndDo;
	EndIf;
	
	If InventoryStructuralUnitPosition = Enums.AttributeStationing.InTabularSection 
		And Inventory.Count() Then
		
		InventoryStructuralUnit = Inventory[0].InventoryStructuralUnit;
		CellInventory = Inventory[0].CellInventory;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Status = Enums.ManufacturingOperationStatuses.InProcess
		Or Status = Enums.ManufacturingOperationStatuses.Completed Then
		
		CheckOverheadRates(Cancel);
		
		BatchesServer.CheckFilling(ThisObject, Cancel);
		
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Activities.Quantity");
		MessageTemplate = NStr("en = 'The ""Quantity"" is required on line %1 of the ""Operations"" list.'; ru = 'В строке %1 списка ""Операции"" необходимо указать ""Количество"".';pl = '""Ilość"" jest wymagana w wierszu %1 listy ""Operacje"".';es_ES = 'La ""Cantidad"" se requiere en la línea%1 de la lista de ""Operaciones"".';es_CO = 'La ""Cantidad"" se requiere en la línea%1 de la lista de ""Operaciones"".';tr = '""İşlemler"" listesinin %1 satırında ""Miktar"" gereklidir.';it = 'La ""Quantità"" è richiesta nella riga %1 dell''elenco ""Operazioni"".';de = 'Die ""Menge"" ist in der Zeile %1 der Liste ""Operationen"" erforderlich.'");
		For Each ActivitiesRow In Activities Do
			
			If ActivitiesRow.Done And ActivitiesRow.Quantity = 0 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageTemplate, ActivitiesRow.LineNumber);
				CommonClientServer.MessageToUser(
					MessageText,
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "Quantity"),
					,
					Cancel);
			EndIf;
			
			If ValueIsFilled(ActivitiesRow.StartDate) And ActivitiesRow.StartDate < Date Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'The operation start date cannot be earlier than the document date.'; ru = 'Дата начала выполнения операции не может быть меньше даты документа.';pl = 'Data początkowa operacji nie może być wcześniejsza niż data dokumentu.';es_ES = 'La fecha de inicio de la operación no puede ser anterior a la fecha del documento.';es_CO = 'La fecha de inicio de la operación no puede ser anterior a la fecha del documento.';tr = 'İşlemin başlangıç tarihi belge tarihinden önce olamaz.';it = 'La data di inizio dell''operazione non può essere precedente alla data del documento.';de = 'Das Startdatum der Operation darf nicht vor dem Belegdatum liegen.'"),
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "StartDate"),
					,
					Cancel);
					
			EndIf;
				
			If ActivitiesRow.Done And Not ValueIsFilled(ActivitiesRow.FinishDate) Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'End dates are required for operations marked as Done.'; ru = 'Для операций, отмеченных как Выполнено, требуется указать даты окончания.';pl = 'Daty końcowe są wymagane dla operacji oznaczone jako Gotowe.';es_ES = 'Se requieren las fechas finales para las operaciones marcadas como Hecho.';es_CO = 'Se requieren las fechas finales para las operaciones marcadas como Hecho.';tr = 'Bitti olarak işaretlenmiş işlemler için bitiş tarihleri gerekli.';it = 'Sono richieste date di fine per le operazioni contrassegnate come Completate.';de = 'Enddaten sind für Operationen erforderlich, die als Fertig gekennzeichnet sind.'"),
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "FinishDate"),
					,
					Cancel);
					
			EndIf;
			
			If ValueIsFilled(ActivitiesRow.FinishDate) And ActivitiesRow.FinishDate < Date Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'The operation end date cannot be earlier than the document date.'; ru = 'Дата выполнения операции не может быть меньше даты документа.';pl = 'Data końcowa operacji nie może być wcześniejsza niż data dokumentu.';es_ES = 'La fecha final de la operación no puede ser anterior a la fecha del documento.';es_CO = 'La fecha final de la operación no puede ser anterior a la fecha del documento.';tr = 'İşlemin bitiş tarihi belge tarihinden önce olamaz.';it = 'La data di fine dell''operazione non può essere precedente alla data del documento.';de = 'Das Enddatum der Operation darf nicht vor dem Belegdatum liegen.'"),
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "FinishDate"),
					,
					Cancel);
				
			EndIf;
				
			If ValueIsFilled(ActivitiesRow.FinishDate) And ActivitiesRow.FinishDate < ActivitiesRow.StartDate Then
				
				CommonClientServer.MessageToUser(
					NStr("en = 'The operation end date cannot be earlier than the start date.'; ru = 'Дата выполнения операции не может быть меньше даты начала.';pl = 'Data końcowa operacji nie może być wcześniejsza niż data początkowa.';es_ES = 'La fecha final de la operación no puede ser anterior a la fecha de inicio.';es_CO = 'La fecha final de la operación no puede ser anterior a la fecha de inicio.';tr = 'İşlemin bitiş tarihi başlangıç tarihinden önce olamaz.';it = 'La data di fine dell''operazione non può essere precedente alla data di inizio.';de = 'Das Enddatum der Operation darf nicht vor dem Startdatum liegen.'"),
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "FinishDate"),
					,
					Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If InventoryStructuralUnitPosition = Enums.AttributeStationing.InTabularSection Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "InventoryStructuralUnit");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.InventoryStructuralUnit");
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.ManufacturingOperation.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectWorkInProgress(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsConsumedToDeclare(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectManufacturingProcessSupply(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkcentersAvailability(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionAccomplishment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkInProgressStatement(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSubcontractorPlanning(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductionComponents(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	Documents.ManufacturingOperation.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	ReflectProductionPlanningData(AdditionalProperties, Cancel);
	ReflectTasksForUpdatingStatuses(Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.ManufacturingOperation.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	ReflectProductionPlanningData(AdditionalProperties, Cancel, True);
	ReflectTasksForUpdatingStatuses(Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Status = Enums.ManufacturingOperationStatuses.Open;
	
	For Each ActivityLine In Activities Do
		
		ActivityLine.Done = False;
		ActivityLine.StartDate = Date(1, 1, 1);
		ActivityLine.FinishDate = Date(1, 1, 1);
		
	EndDo;
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
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

Procedure ReflectProductionPlanningData(AdditionalProperties, Cancel, UndoPosting = False)
	
	If GetFunctionalOption("UseProductionPlanning") Then
		
		If Not Cancel And (Common.ObjectAttributeValue(BasisDocument, "UseProductionPlanning") = True) Then
			
			InformationRegisters.ProductionOrdersStates.ReflectOrdersStates(BasisDocument);
			
			If UndoPosting Or Status = Enums.ManufacturingOperationStatuses.Completed Then
				
				InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(BasisDocument);
				InformationRegisters.WorkcentersSchedule.ClearWIPSchedule(Ref);
				InformationRegisters.ProductionSchedule.ClearWIPSchedule(Ref);
				InformationRegisters.WorkcentersAvailabilityPreliminary.ClearWIPSchedule(Ref);
				
			ElsIf Status <> Enums.ManufacturingOperationStatuses.Open Then
				
				InformationRegisters.JobsForProductionScheduleCalculation.DeleteJobs(BasisDocument);
				
			ElsIf AdditionalProperties.CustomizableNumbering.IsNew Or (AdditionalProperties.Property("NeedRecalculation") And AdditionalProperties.NeedRecalculation) Then
				
				InformationRegisters.JobsForProductionScheduleCalculation.AddAllOperationsOfOrder(BasisDocument);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure CheckOverheadRates(Cancel)
	
	If ProductionMethod = Enums.ProductionMethods.Subcontracting Then
		Return;
	EndIf;
	
	ActivitiesArray = New Array;
	For Each ActivitiesRow In Activities Do
		If ActivitiesRow.Done And ValueIsFilled(ActivitiesRow.Activity) Then
			ActivitiesArray.Add(ActivitiesRow.Activity);
		EndIf;
	EndDo;
	
	If ActivitiesArray.Count() = 0 Then
		Return;
	EndIf;
	
	OverheadsRates = InformationRegisters.PredeterminedOverheadRates.GetActivitiesOverheadRates(
		ActivitiesArray, Date, Company, StructuralUnit);
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	Method = Policy.ManufacturingOverheadsAllocationMethod;
	
	If Method = Enums.ManufacturingOverheadsAllocationMethods.PlantwideAllocation
		And OverheadsRates.Count() = 0 Then
		
		MessageText = NStr("en = 'Overhead rates for ''%1'' company are not set.
			|Set the values with ''Manufacturing overhead rates'' document.'; 
			|ru = 'Ставки накладных расходов для организации ""%1"" не установлены.
			|Установите значения в документе ""Ставки производственных накладных расходов"".';
			|pl = 'Stawki kosztów ogólnych dla ''%1'' firmy nie są ustawione.
			|Ustaw wartości dla dokumentu ''Stawki kosztów ogólnych produkcji''.';
			|es_ES = 'Las tasas de los gastos generales de la ''%1'' empresa no están establecidas. 
			|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
			|es_CO = 'Las tasas de los gastos generales de la ''%1'' empresa no están establecidas. 
			|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
			|tr = '''%1'' şirketi için genel gider oranları belirtilmedi.
			|''Üretim genel gider oranları'' belgesiyle değerleri belirtin.';
			|it = 'I tassi di costi indiretti per l''azienda ''%1'' non sono impostati. 
			|Impostare i valori con il documento ''Tassi di costi indiretti di produzione''.';
			|de = 'Kostensätze für die Firma ""%1"" sind nicht eingegeben.
			|Geben Sie die Werte mit dem ""Fertigungskostensätze""-Dokument.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, Company);
		
		CommonClientServer.MessageToUser(
			MessageText,
			ThisObject,
			"Company",
			,
			Cancel);
		
	ElsIf Method = Enums.ManufacturingOverheadsAllocationMethods.DepartmentalAllocation
		And OverheadsRates.Count() = 0 Then
		
		MessageText = NStr("en = 'Overhead rates for ''%1'' department are not set.
			|Set the values with ''Manufacturing overhead rates'' document.'; 
			|ru = 'Ставки накладных расходов для подразделения ""%1"" не установлены.
			|Установите значения в документе ""Ставки производственных накладных расходов"".';
			|pl = 'Stawki kosztów ogólnych dla''%1'' działu nie są ustawione.
			|Ustaw wartości dla dokumentu ''Stawki kosztów ogólnych produkcji''.';
			|es_ES = 'Las tasas de los gastos generales del ''%1'' departamento no están establecidas. 
			|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
			|es_CO = 'Las tasas de los gastos generales del ''%1'' departamento no están establecidas. 
			|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
			|tr = '''%1'' departmanı için genel gider oranları belirtilmedi.
			|''Üretim genel gider oranları'' belgesiyle değerleri belirtin.';
			|it = 'I tassi di costi indiretti per il reparto ''%1'' non sono impostati. 
			|Impostare i valori con il documento ''Tassi di costi indiretti di produzione''.';
			|de = 'Kostensätze für die Abteilung ""%1"" sind nicht eingegeben.
			|Geben Sie die Werte mit dem ""Fertigungskostensätze""-Dokument.'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, StructuralUnit);
		
		CommonClientServer.MessageToUser(
			MessageText,
			ThisObject,
			"StructuralUnit",
			,
			Cancel);
		
	ElsIf Method = Enums.ManufacturingOverheadsAllocationMethods.ActivityBasedCosting Then
		
		For Each ActivitiesRow In Activities Do
			
			If ActivitiesRow.Done And ValueIsFilled(ActivitiesRow.Activity)
				And OverheadsRates.Find(ActivitiesRow.Activity, "Activity") = Undefined Then
				
				MessageText = NStr("en = 'Overhead rates for ''%1'' operation''s cost pool are not set.
					|Set the values with ''Manufacturing overhead rates'' document.'; 
					|ru = 'Ставки накладных расходов для группы затрат операции ''%1'' не установлены.
					|Установите значения в документе ''Ставки производственных накладных расходов''.';
					|pl = 'Stawki kosztów ogólnych dla ''%1'' puli kosztów własnych nie są ustawione.
					|Ustaw wartości dla dokumentu ''Stawki kosztów ogólnych produkcji''.';
					|es_ES = 'Las tasas de los gastos generales para ''%1''el ""pool"" de costes de la operación no están establecidas. 
					|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
					|es_CO = 'Las tasas de los gastos generales para ''%1''el ""pool"" de costes de la operación no están establecidas. 
					|Establezca los valores con el documento ""Tasas de gastos generales de fabricación"".';
					|tr = '''%1'' operasyonunun maliyet havuzu için genel gider oranları belirtilmedi.
					|''Üretim genel gider oranları'' belgesiyle değerleri belirtin.';
					|it = 'I tassi di costi indiretti per il pool di costi dell''operazione ''%1'' non sono impostati. 
					|Impostare i valori con il documento ''Tassi di costi indiretti di produzione''.';
					|de = 'Kostensätze für die Operationskostenpools ""%1"" sind nicht eingegeben.
					|Geben Sie die Werte mit dem ""Fertigungskostensätze""-Dokument.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, ActivitiesRow.Activity);
				
				CommonClientServer.MessageToUser(
					MessageText,
					ThisObject,
					CommonClientServer.PathToTabularSection("Activities", ActivitiesRow.LineNumber, "Activity"),
					,
					Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillOutputMark()
	
	If ValueIsFilled(Specification) Then
		
		Query = New Query;
		Query.Text = 
			"SELECT TOP 1
			|	BillsOfMaterialsOperations.ActivityNumber AS ActivityNumber,
			|	BillsOfMaterialsOperations.Activity AS Activity
			|FROM
			|	Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
			|WHERE
			|	BillsOfMaterialsOperations.Ref = &Specification
			|
			|ORDER BY
			|	BillsOfMaterialsOperations.ActivityNumber DESC,
			|	BillsOfMaterialsOperations.LineNumber DESC";
		
		Query.SetParameter("Specification", Specification);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			
			Activity = SelectionDetailRecords.Activity;
			ActivityNumber = SelectionDetailRecords.ActivityNumber;
			
			For Each ActivitiesLine In Activities Do
				
				ActivitiesLine.Output = (ActivitiesLine.Activity = Activity AND ActivitiesLine.ActivityNumber = ActivityNumber);
				
			EndDo;
			
		EndIf;
		
	ElsIf Activities.Count() Then
		
		MaxLineNumber = Activities.Count();
		For Each ActivitiesLine In Activities Do
			
			ActivitiesLine.Output = (ActivitiesLine.LineNumber = MaxLineNumber);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure SetProManageStatus()
	
	If GetFunctionalOption("UseDataExchangeWithProManage") Then
		
		ProManageTable = ExchangeWithProManage.GetProManageData(Ref);
		
		If ProManageTable.Count() = 0 Then
			TempStatus = Enums.ManufacturingOperationExchangeStatuses.Open;
		Else
			
			ProManageTable.GroupBy("Activity", "Quantity");
			
			ActivitiesTable = Activities.Unload();
			ActivitiesTable.GroupBy("Activity", "Quantity");
		
			For Each ActivityRow In ActivitiesTable Do
				
				FoundRow = ProManageTable.Find(ActivityRow.Activity, "Activity");
				If FoundRow <> Undefined
					And ActivityRow.Quantity <> FoundRow.Quantity Then
					
					TempStatus = Enums.ManufacturingOperationExchangeStatuses.InProgress;
					Break;
				EndIf;
				
			EndDo;
			
			If Not ValueIsFilled(TempStatus) Then
				TempStatus = Enums.ManufacturingOperationExchangeStatuses.Completed;
			EndIf;
			
		EndIf;
		
		ProManageStatus = TempStatus;
		
	EndIf;
	
EndProcedure

Procedure ReflectTasksForUpdatingStatuses(Cancel)
	
	If AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
		StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
		
		If StructureTemporaryTables.Property("RegisterRecordsProductionAccomplishmentChange")
			And StructureTemporaryTables.RegisterRecordsProductionAccomplishmentChange Then
			
			If ValueIsFilled(BasisDocument) Then
				DriveServer.ReflectTasksForUpdatingStatuses(BasisDocument, Cancel);
				DriveServer.StartUpdateDocumentStatuses();
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
