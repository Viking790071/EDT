#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Date AS Date,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrderStatusesCatalog.OrderStatus AS OrderStatus,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.UseProductionPlanning AS UseProductionPlanning,
	|	ProductionOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	ProductionOrder.Company AS Company
	|INTO ProductionOrderHeader
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatusesCatalog
	|		ON ProductionOrder.OrderState = ProductionOrderStatusesCatalog.Ref
	|WHERE
	|	ProductionOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderProducts.Products AS Products,
	|	ProductionOrderProducts.Ref AS Ref,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	ProductionOrderProducts.Characteristic AS Characteristic,
	|	ProductionOrderProducts.Quantity AS Quantity,
	|	ProductionOrderProducts.SalesOrder AS SalesOrder,
	|	ProductionOrderProducts.Specification AS Specification,
	|	ProductionOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	ProductionOrderHeader.Date AS Date,
	|	ProductionOrderHeader.Finish AS Finish,
	|	ProductionOrderHeader.OrderStatus AS OrderStatus,
	|	ProductionOrderHeader.Closed AS Closed,
	|	ProductionOrderHeader.StructuralUnit AS StructuralUnit
	|INTO OrderForProductsProduction
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderProducts.Ref = ProductionOrderHeader.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON ProductionOrderProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON ProductionOrderProducts.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	ProductionOrderInventory.Products AS Products,
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionOrderInventory.Quantity AS Quantity,
	|	ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	ProductionOrderHeader.Start AS Start,
	|	ProductionOrderHeader.Closed AS Closed,
	|	ProductionOrderHeader.OrderStatus AS OrderStatus,
	|	ProductionOrderHeader.Ref AS Ref,
	|	ProductionOrderHeader.UseProductionPlanning AS UseProductionPlanning,
	|	ProductionOrderInventory.Reserve AS Reserve
	|INTO ProductionOrderInventory
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderInventory.Ref = ProductionOrderHeader.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON ProductionOrderInventory.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(OrderForProductsProduction.Finish, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	OrderForProductsProduction.Ref AS Order,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity,
	|	OrderForProductsProduction.Ref AS ProductionDocument
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	(OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	ProductionOrderInventory.LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Start, DAY),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	UNDEFINED,
	|	ProductionOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END,
	|	ProductionOrderInventory.Ref
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	(ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Closed = FALSE
	|			OR ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref AS ProductionOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Start, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	ProductionOrderInventory.Ref AS ProductionDocument,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	(ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Closed = FALSE
	|			OR ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|	AND NOT ProductionOrderInventory.UseProductionPlanning
	|
	|ORDER BY
	|	ProductionOrderInventory.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.SalesOrder AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	OrderForProductsProduction.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.SalesOrder REFS Document.SalesOrder
	|	AND OrderForProductsProduction.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND OrderForProductsProduction.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN OrderForProductsProduction.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OrderForProductsProduction.SalesOrder
	|	END AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	OrderForProductsProduction.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS QuantityPlan
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	NOT OrderForProductsProduction.SalesOrder REFS Document.SubcontractorOrderReceived
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderHeader.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderHeader.StructuralUnitReserve AS StructuralUnit,
	|	ProductionOrderInventory.Products AS Products,
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	ProductionOrderInventory.Batch AS Batch,
	|	ProductionOrderInventory.Ref AS SalesOrder,
	|	ProductionOrderInventory.Reserve * ProductionOrderInventory.Factor AS Quantity
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderInventory.Ref = ProductionOrderHeader.Ref
	|WHERE
	|	(ProductionOrderHeader.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderHeader.Closed = FALSE
	|			OR ProductionOrderHeader.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|	AND ProductionOrderInventory.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderHeader.Date AS Period,
	|	ProductionOrderHeader.Company AS Company,
	|	ProductionOrderHeader.Ref AS ProductionDocument,
	|	ProductionOrderInventory.Products AS Products,
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor AS Quantity
	|FROM
	|	ProductionOrderHeader AS ProductionOrderHeader
	|		INNER JOIN ProductionOrderInventory AS ProductionOrderInventory
	|		ON ProductionOrderHeader.Ref = ProductionOrderInventory.Ref";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefProductionOrder);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",		Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", 			Result[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",			Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", 				Result[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", 			Result[7].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManufacturingProcessSupply",	New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts",			Result[8].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents",		Result[9].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataProduction(DocumentRefProductionOrder, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Date AS Date,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrderStatusesCatalog.OrderStatus AS OrderStatus,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.UseProductionPlanning AS UseProductionPlanning
	|INTO ProductionOrderHeader
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatusesCatalog
	|		ON ProductionOrder.OrderState = ProductionOrderStatusesCatalog.Ref
	|WHERE
	|	ProductionOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderProducts.Products AS Products,
	|	ProductionOrderProducts.Ref AS Ref,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	ProductionOrderProducts.Characteristic AS Characteristic,
	|	ProductionOrderProducts.Quantity AS Quantity,
	|	ProductionOrderProducts.SalesOrder AS SalesOrder,
	|	ProductionOrderProducts.Specification AS Specification,
	|	ProductionOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	ProductionOrderHeader.Date AS Date,
	|	ProductionOrderHeader.Finish AS Finish,
	|	ProductionOrderHeader.OrderStatus AS OrderStatus,
	|	ProductionOrderHeader.Closed AS Closed,
	|	ProductionOrderHeader.StructuralUnit AS StructuralUnit
	|INTO OrderForProductsProduction
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderProducts.Ref = ProductionOrderHeader.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON ProductionOrderProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON ProductionOrderProducts.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(OrderForProductsProduction.Finish, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	OrderForProductsProduction.Ref AS Order,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity,
	|	OrderForProductsProduction.Ref AS ProductionDocument
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	(OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.Ref AS ProductionOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	InventoryDemand.Period AS Period,
	|	InventoryDemand.Recorder AS Recorder,
	|	InventoryDemand.LineNumber AS LineNumber,
	|	InventoryDemand.Active AS Active,
	|	InventoryDemand.RecordType AS RecordType,
	|	InventoryDemand.Company AS Company,
	|	InventoryDemand.MovementType AS MovementType,
	|	InventoryDemand.SalesOrder AS SalesOrder,
	|	InventoryDemand.Products AS Products,
	|	InventoryDemand.Characteristic AS Characteristic,
	|	InventoryDemand.ProductionDocument AS ProductionDocument,
	|	InventoryDemand.Quantity AS Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand AS InventoryDemand
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.SalesOrder AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	OrderForProductsProduction.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.SalesOrder REFS Document.SalesOrder
	|	AND OrderForProductsProduction.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND OrderForProductsProduction.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.Date AS Period,
	|	&Company AS Company,
	|	OrderForProductsProduction.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN OrderForProductsProduction.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE OrderForProductsProduction.SalesOrder
	|	END AS SalesOrder,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	OrderForProductsProduction.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS QuantityPlan
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	NOT OrderForProductsProduction.SalesOrder REFS Document.SubcontractorOrderReceived
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.Date AS Period,
	|	OrderForProductsProduction.Ref AS Reference,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	OrderForProductsProduction.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Required
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	OrderForProductsProduction.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefProductionOrder);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",		Result[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", 			Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",			Result[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", 				Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", 			Result[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManufacturingProcessSupply",	Result[7].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts",			DriveServer.EmptyReservedProductsTable());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents",		DriveServer.EmptyProductionComponentsTable());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
		"SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Date AS Date,
	|	ProductionOrder.Finish AS Finish,
	|	ProductionOrderStatusesCatalog.OrderStatus AS OrderStatus,
	|	ProductionOrder.Closed AS Closed,
	|	ProductionOrder.Start AS Start,
	|	ProductionOrder.StructuralUnit AS StructuralUnit,
	|	ProductionOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	ProductionOrder.UseProductionPlanning AS UseProductionPlanning,
	|	ProductionOrder.Company AS Company
	|INTO ProductionOrderHeader
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|		LEFT JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatusesCatalog
	|		ON ProductionOrder.OrderState = ProductionOrderStatusesCatalog.Ref
	|WHERE
	|	ProductionOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderProducts.LineNumber AS LineNumber,
	|	ProductionOrderProducts.Products AS Products,
	|	ProductionOrderProducts.Ref AS Ref,
	|	ProductionOrderProducts.Characteristic AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionOrderProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionOrderProducts.Quantity AS Quantity,
	|	ProductionOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	ProductionOrderHeader.Start AS Start,
	|	ProductionOrderHeader.Finish AS Finish,
	|	ProductionOrderHeader.OrderStatus AS OrderStatus,
	|	ProductionOrderHeader.Closed AS Closed,
	|	ProductionOrderProducts.Reserve AS Reserve
	|INTO OrderForProductsProduction
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderProducts.Ref = ProductionOrderHeader.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON ProductionOrderProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON ProductionOrderProducts.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.LineNumber AS LineNumber,
	|	ProductionOrderInventory.Products AS Products,
	|	ProductionOrderInventory.Characteristic AS Characteristic,
	|	ProductionOrderInventory.Quantity AS Quantity,
	|	ProductionOrderInventory.Specification AS Specification,
	|	ProductionOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductionOrderInventory.SalesOrder AS SalesOrder,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	ProductionOrderHeader.Date AS Date,
	|	ProductionOrderHeader.Start AS Start,
	|	ProductionOrderHeader.Closed AS Closed,
	|	ProductionOrderHeader.StructuralUnit AS StructuralUnit,
	|	ProductionOrderHeader.OrderStatus AS OrderStatus,
	|	ProductionOrderHeader.Ref AS Ref,
	|	ProductionOrderHeader.UseProductionPlanning AS UseProductionPlanning
	|INTO ProductionOrderInventory
	|FROM
	|	Document.ProductionOrder.Inventory AS ProductionOrderInventory
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON ProductionOrderInventory.Ref = ProductionOrderHeader.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON ProductionOrderInventory.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(OrderForProductsProduction.Finish, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	UNDEFINED AS Order,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity,
	|	OrderForProductsProduction.Ref AS ProductionDocument
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	(OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	ProductionOrderInventory.LineNumber,
	|	BEGINOFPERIOD(ProductionOrderInventory.Start, DAY),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	ProductionOrderInventory.Ref,
	|	ProductionOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END,
	|	ProductionOrderInventory.Ref
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	(ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Closed = FALSE
	|			OR ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderInventory.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.Ref AS ProductionOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	(ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Closed = FALSE
	|			OR ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(OrderForProductsProduction.Start, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	OrderForProductsProduction.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN OrderForProductsProduction.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(OrderForProductsProduction.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN OrderForProductsProduction.Quantity
	|		ELSE OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor
	|	END AS Quantity,
	|	OrderForProductsProduction.Ref AS ProductionDocument
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|WHERE
	|	(OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND OrderForProductsProduction.Closed = FALSE
	|			OR OrderForProductsProduction.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderInventory.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.SalesOrder AS SalesOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	ProductionOrderInventory.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	ProductionOrderInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND (ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Closed = FALSE
	|			OR ProductionOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|	AND ProductionOrderInventory.SalesOrder REFS Document.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderInventory.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN ProductionOrderInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionOrderInventory.SalesOrder
	|	END AS SalesOrder,
	|	ProductionOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	ProductionOrderInventory.Specification AS Specification,
	|	CASE
	|		WHEN VALUETYPE(ProductionOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionOrderInventory.Quantity
	|		ELSE ProductionOrderInventory.Quantity * ProductionOrderInventory.Factor
	|	END AS QuantityPlan
	|FROM
	|	ProductionOrderInventory AS ProductionOrderInventory
	|WHERE
	|	(ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderInventory.Ref.Closed = FALSE
	|			OR ProductionOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderHeader.Date AS Period,
	|	&Company AS Company,
	|	ProductionOrderHeader.StructuralUnitReserve AS StructuralUnit,
	|	OrderForProductsProduction.Products AS Products,
	|	OrderForProductsProduction.Characteristic AS Characteristic,
	|	OrderForProductsProduction.Batch AS Batch,
	|	OrderForProductsProduction.Ref AS SalesOrder,
	|	OrderForProductsProduction.Reserve * OrderForProductsProduction.Factor AS Quantity
	|FROM
	|	OrderForProductsProduction AS OrderForProductsProduction
	|		INNER JOIN ProductionOrderHeader AS ProductionOrderHeader
	|		ON OrderForProductsProduction.Ref = ProductionOrderHeader.Ref
	|WHERE
	|	(ProductionOrderHeader.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND ProductionOrderHeader.Closed = FALSE
	|			OR ProductionOrderHeader.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|	AND OrderForProductsProduction.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrderForProductsProduction.LineNumber AS LineNumber,
	|	ProductionOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrderHeader.Company AS Company,
	|	ProductionOrderHeader.Ref AS ProductionDocument,
	|	OrderForProductsProduction.Products AS Products,
	|	OrderForProductsProduction.Characteristic AS Characteristic,
	|	OrderForProductsProduction.Quantity * OrderForProductsProduction.Factor AS Quantity
	|FROM
	|	ProductionOrderHeader AS ProductionOrderHeader
	|		INNER JOIN OrderForProductsProduction AS OrderForProductsProduction
	|		ON ProductionOrderHeader.Ref = OrderForProductsProduction.Ref";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefProductionOrder);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",		Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders",			Result[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",			Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders",					Result[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease",				Result[7].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableManufacturingProcessSupply",	New ValueTable);
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts",			Result[8].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents",		Result[9].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefProductionOrder, StructureAdditionalProperties) Export
	
	If DocumentRefProductionOrder.OperationKind = Enums.OperationTypesProductionOrder.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefProductionOrder, StructureAdditionalProperties);
		
	ElsIf DocumentRefProductionOrder.OperationKind = Enums.OperationTypesProductionOrder.Production Then
		
		InitializeDocumentDataProduction(DocumentRefProductionOrder, StructureAdditionalProperties);
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefProductionOrder, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefProductionOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsProductionOrdersChange",
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryDemandChange", "RegisterRecordsReservedProductsChange"
	// contain records, control products implementation.
	
	If StructureTemporaryTables.RegisterRecordsProductionOrdersChange
		Or StructureTemporaryTables.RegisterRecordsBackordersChange
		Or StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
		Or StructureTemporaryTables.RegisterRecordsProductionComponentsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductionOrder) AS ProductionOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(ProductionOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsProductionOrdersChange.QuantityChange, 0) + ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS BalanceProductionOrders,
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS QuantityBalanceProductionOrders
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|		LEFT JOIN AccumulationRegister.ProductionOrders.Balance(
		|				&ControlTime,
		|				(Company, ProductionOrder, Products, Characteristic) In
		|					(SELECT
		|						RegisterRecordsProductionOrdersChange.Company AS Company,
		|						RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|						RegisterRecordsProductionOrdersChange.Products AS Products,
		|						RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange)) AS ProductionOrdersBalances
		|		ON RegisterRecordsProductionOrdersChange.Company = ProductionOrdersBalances.Company
		|			AND RegisterRecordsProductionOrdersChange.ProductionOrder = ProductionOrdersBalances.ProductionOrder
		|			AND RegisterRecordsProductionOrdersChange.Products = ProductionOrdersBalances.Products
		|			AND RegisterRecordsProductionOrdersChange.Characteristic = ProductionOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.MovementType) AS MovementTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryDemandChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(InventoryDemandBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		LEFT JOIN AccumulationRegister.InventoryDemand.Balance(
		|				&ControlTime,
		|				(Company, MovementType, SalesOrder, Products, Characteristic) In
		|					(SELECT
		|						RegisterRecordsInventoryDemandChange.Company AS Company,
		|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
		|						RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsInventoryDemandChange.Products AS Products,
		|						RegisterRecordsInventoryDemandChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange)) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|WHERE
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) In
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ProductionComponents.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty() Then
			DocumentObjectProductionOrder = DocumentRefProductionOrder.GetObject()
		EndIf;
		
		// Negative balance by work orders.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of need for reserved products.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectProductionOrder, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectProductionOrder, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance of production components.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToProductionComponentsRegisterErrors(
				DocumentObjectProductionOrder,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefProductionOrder, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

Function OrderOpenWIPs(Order) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ManufacturingOperation.BasisDocument = &Order
	|	AND ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)";
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute().Unload().UnloadColumn("Ref");
	
	Return QueryResult;
	
EndFunction

Function CheckCompletedOrderState(ProductionOrder, GetOldStatus = False) Export
	
	StructureOrderState = New Structure("CheckPassed", False);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	COUNT(DISTINCT ManufacturingOperation.Ref) AS CountWIP
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.BasisDocument = &ProductionOrder
	|	AND NOT ManufacturingOperation.DeletionMark
	|	AND ManufacturingOperation.Posted
	|	AND NOT ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed)";
	
	Query.SetParameter("ProductionOrder", ProductionOrder);
	
	QueryResult = Query.Execute();
	
	SelectionCount = QueryResult.Select();
	
	While SelectionCount.Next() Do
		
		If SelectionCount.CountWIP = 0 Then
			
			StructureOrderState.CheckPassed = True;
			
		Else
			
			If GetOldStatus Then
				
				OldOrderState = Common.ObjectAttributeValue(ProductionOrder, "OrderState");
				
				StructureOrderState.Insert("OldOrderState", OldOrderState);
				
			EndIf;
			
		EndIf;
			
	EndDo;
	
	Return StructureOrderState;
	
EndFunction

Function QueryTextFillBySalesOrder() Export

	Return "SELECT ALLOWED
	|	OrdersBalance.SalesOrder AS SalesOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.SalesOrder AS SalesOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(, SalesOrder IN (&BasisDocument)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ReservedProductsBalances.SalesOrder,
	|		ReservedProductsBalances.Products,
	|		ReservedProductsBalances.Characteristic,
	|		-ReservedProductsBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(, SalesOrder IN (&BasisDocument)) AS ReservedProductsBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.SalesOrder,
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(, SalesOrder IN (&BasisDocument)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|	DocumentRegisterRecordsBackorders.SalesOrder,
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder IN (&BasisDocument)) AS OrdersBalance
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON OrdersBalance.Products = ProductsCatalog.Ref
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	OrdersBalance.SalesOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0"

EndFunction

Function QueryTextFillBySubcontractorOrderIssued() Export 
	
	Return "SELECT ALLOWED
	|	SubcontractorOrder.Ref AS Ref,
	|	SubcontractorOrder.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrder.Company AS Company,
	|	SubcontractorOrder.ReceiptDate AS Start,
	|	SubcontractorOrder.ReceiptDate AS Finish,
	|	SubcontractorOrder.CompanyVATNumber AS CompanyVATNumber
	|INTO SubcontractorOrderHeader
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrder
	|WHERE
	|	SubcontractorOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrdersHeader.Ref AS BasisDocument,
	|	SalesOrdersHeader.StructuralUnit AS StructuralUnit,
	|	SalesOrdersHeader.Company AS Company,
	|	SalesOrdersHeader.Start AS Start,
	|	SalesOrdersHeader.Finish AS Finish,
	|	SalesOrdersHeader.CompanyVATNumber AS CompanyVATNumber
	|FROM
	|	SubcontractorOrderHeader AS SalesOrdersHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderIssued.Ref AS Ref
	|INTO OrderChildren
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderIssued.BasisDocument
	|WHERE
	|	SubcontractorOrderIssued.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrder.Ref
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON SubcontractorOrderHeader.Ref = ProductionOrder.BasisDocument
	|WHERE
	|	ProductionOrder.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO OrdersBalancePre
	|FROM
	|	AccumulationRegister.SubcontractComponents.Balance(, SubcontractorOrder = &BasisDocument) AS OrdersBalance
	|
	|UNION ALL
	|
	|SELECT
	|	SubcontractorOrdersIssued.Products,
	|	SubcontractorOrdersIssued.Characteristic,
	|	-SubcontractorOrdersIssued.Quantity
	|FROM
	|	OrderChildren AS SubcontractorOrderChildren
	|		INNER JOIN AccumulationRegister.SubcontractorOrdersIssued AS SubcontractorOrdersIssued
	|		ON SubcontractorOrderChildren.Ref = SubcontractorOrdersIssued.SubcontractorOrder
	|WHERE
	|	SubcontractorOrdersIssued.RecordType = VALUE(AccumulationRecordType.Receipt)
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrders.Products,
	|	ProductionOrders.Characteristic,
	|	-ProductionOrders.Quantity
	|FROM
	|	OrderChildren AS ProductionOrderChildren
	|		INNER JOIN AccumulationRegister.ProductionOrders AS ProductionOrders
	|		ON ProductionOrderChildren.Ref = ProductionOrders.ProductionOrder
	|WHERE
	|	ProductionOrders.RecordType = VALUE(AccumulationRecordType.Receipt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO OrdersBalance
	|FROM
	|	OrdersBalancePre AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(SubcontractorOrderInventory.LineNumber) AS LineNumber,
	|	SubcontractorOrderInventory.Products AS Products,
	|	SubcontractorOrderInventory.Characteristic AS Characteristic,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	SubcontractorOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	ProductsCatalog.VATRate AS VATRate,
	|	SUM(SubcontractorOrderInventory.Quantity) AS Quantity,
	|	OrdersBalance.QuantityBalance AS QuantityBalance
	|INTO TableProductionPre
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderInventory.Ref
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderInventory.Products = ProductsCatalog.Ref)
	|		INNER JOIN OrdersBalance AS OrdersBalance
	|		ON (SubcontractorOrderInventory.Products = OrdersBalance.Products)
	|			AND (SubcontractorOrderInventory.Characteristic = OrdersBalance.Characteristic)
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOMCatalog.Ref)
	|WHERE
	|	ProductsCatalog.ReplenishmentMethod IN (&ReplenishmentMethod)
	|
	|GROUP BY
	|	SubcontractorOrderInventory.Products,
	|	SubcontractorOrderInventory.Characteristic,
	|	SubcontractorOrderInventory.MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1),
	|	ProductsCatalog.ProductsType,
	|	ProductsCatalog.VATRate,
	|	OrdersBalance.QuantityBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionPre.LineNumber AS LineNumber,
	|	TableProductionPre.Products AS Products,
	|	TableProductionPre.Characteristic AS Characteristic,
	|	TableProductionPre.Factor AS Factor,
	|	TableProductionPre.MeasurementUnit AS MeasurementUnit,
	|	TableProductionPre.ProductsType AS ProductsType,
	|	TableProductionPre.VATRate AS VATRate,
	|	CASE
	|		WHEN TableProductionPre.QuantityBalance - TableProductionPre.Quantity * TableProductionPre.Factor < 0
	|			THEN TableProductionPre.QuantityBalance / TableProductionPre.Factor
	|		ELSE TableProductionPre.Quantity
	|	END AS Quantity
	|FROM
	|	TableProductionPre AS TableProductionPre";

EndFunction

#Region FillingProcedures

// Checks the possibility of input on the basis.
//
Procedure VerifyEnteringAbilityByProductionOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = 'Please select a posted document.'; ru = 'Ввод на основании непроведенного документа запрещен.';pl = 'Wybierz zatwierdzony dokument.';es_ES = 'Por favor, seleccione un documento enviado.';es_CO = 'Por favor, seleccione un documento enviado.';tr = 'Lütfen, kaydedilmiş bir belge seçin.';it = 'Si prega di selezionare un documento pubblicato.';de = 'Bitte wählen Sie ein gebuchtes Dokument aus.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			ErrorText = NStr("en = 'Please select an order that is not completed.'; ru = 'Ввод на основании закрытого заказа запрещен.';pl = 'Wybierz zamówienie, które nie zostało zakończone.';es_ES = 'Por favor, seleccione un orden que no esté finalizado.';es_CO = 'Por favor, seleccione un orden que no esté finalizado.';tr = 'Lütfen, tamamlanmamış bir sipariş seçin.';it = 'Si prega di selezionare un ordine che non è stato completato.';de = 'Bitte wählen Sie eine Bestellung aus, die noch nicht abgeschlossen ist.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'Generation from orders with ""Open"" status is not available.'; ru = 'Ввод на основании заказа в статусе ""Открыт"" запрещен.';pl = 'Generowanie zamówień ze statusem ""Otwarty"" nie jest dostępne.';es_ES = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';es_CO = 'Generación de los órdenes con el estado ""Abierto"" no se encuentra disponible.';tr = 'Durumu ""Açık"" olan siparişlerden üretim yapılamaz.';it = 'La generazione degli ordini con stato ""Aperto"" non è disponibile';de = 'Die Generierung aus Aufträgen mit dem Status ""Offen"" ist nicht verfügbar.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

// Filling a sales order in the tabular section
//
Procedure FillSalesOrderInTabularSections() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text = "SELECT
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	ProductionOrder.OperationKind AS OperationKind
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.SalesOrderPosition = VALUE(Enum.AttributeStationing.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Try
			ProductionOrderObject = Selection.Ref.GetObject();
			
			TableName = ?(Selection.OperationKind = Enums.OperationTypesProductionOrder.AssemblyDisassembly, "Inventory", "Products");
			
			For Each Row In ProductionOrderObject[TableName] Do
			
				Row.SalesOrder = Selection.SalesOrder;
			
			EndDo;
			
			ProductionOrderObject.SalesOrderPosition = Enums.AttributeStationing.InHeader;
			
			InfobaseUpdate.WriteObject(ProductionOrderObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.ProductionOrder,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region WIPsGeneration

Procedure GenerateWIPsInBackground(Parameters, ResultAddress) Export
	
	Operations = New ValueTree;
	
	BeginTransaction();
	If Parameters.IsOperationsShown Then
		Operations = CreateWIPsWithOperations(Parameters);
	Else
		Operations = CreateWIPsWithoutOperations(Parameters);
	EndIf;
	CommitTransaction();
	
	PutToTempStorage(Operations, ResultAddress);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region LibrariesHandlers

#Region PrintInterface

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName = "", PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionOrder";
	
	Query = New Query();
	Query.Text = 
	"SELECT ALLOWED
	|	ProductionOrder.Ref AS Ref,
	|	ProductionOrder.Number AS Number,
	|	ProductionOrder.Date AS DocumentDate,
	|	ProductionOrder.Company AS Company,
	|	ProductionOrder.SalesOrder AS Order,
	|	ProductionOrder.Start AS LaunchDate,
	|	ProductionOrder.Finish AS DateOfIssue,
	|	ProductionOrder.StructuralUnit AS Department,
	|	ProductionOrder.Company.Prefix AS Prefix,
	|	ProductionOrder.Products.(
	|		LineNumber AS LineNumber,
	|		Products.DescriptionFull AS Products,
	|		Products.SKU AS SKU,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity
	|	),
	|	ProductionOrder.Inventory.(
	|		LineNumber AS LineNumber,
	|		Products.DescriptionFull AS Material,
	|		Products.SKU AS SKU,
	|		Characteristic AS Characteristic,
	|		MeasurementUnit AS MeasurementUnit,
	|		Quantity AS Quantity
	|	)
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constants AS Constants
	|WHERE
	|	ProductionOrder.Ref IN(&ObjectsArray)
	|
	|ORDER BY
	|	Ref,
	|	LineNumber";
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;
	
	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	
	DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
	// End MultilingualSupport
	
	Query.SetParameter("ObjectsArray", 		ObjectsArray);
	Query.SetParameter("Characteristic", 	NStr("en = 'Characteristic:'; ru = 'Характеристика:';pl = 'Charakterystyka:';es_ES = 'Característica:';es_CO = 'Característica:';tr = 'Özellik:';it = 'Caratteristica:';de = 'Eigenschaft:'", LanguageCode));
	Header = Query.Execute().Select();
	
	FirstDocument = True;
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_ProductionOrder_TemplateWarehouseRequirement";
		
		Template = PrintManagement.PrintFormTemplate(
			"Document.ProductionOrder.PF_MXL_TemplateRequirementAtWarehouse",
			LanguageCode);
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;
	
		TemplateArea = Template.GetArea("Title");
		TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Request to warehouse #%1 dated %2'; ru = 'Требование на склад №%1 от %2';pl = 'Żądanie do magazynu nr %1z dn. %2';es_ES = 'Solicitud para el almacén #%1 fechado %2';es_CO = 'Solicitud para el almacén #%1 fechado %2';tr = 'No.%1 tarih %2 ile depodan talep et';it = 'Richiesta al magazzino #%1 con data %2';de = 'Anfrage an das Lager Nr %1 datiert %2'", LanguageCode),
			DocumentNumber,
			Format(Header.DocumentDate, "DLF=DD"));
		
		SpreadsheetDocument.Put(TemplateArea);

		// Header.
		TemplateArea = Template.GetArea("Header");
		TemplateArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TemplateArea);
		
		// TS Products.
		StringSelectionProducts = Header.Products.Select();
		
		TemplateArea = Template.GetArea("TableHeaderProduction");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("StringProducts");
		
		While StringSelectionProducts.Next() Do
			TemplateArea.Parameters.Fill(StringSelectionProducts);
			
			TemplateArea.Parameters.Products = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Products,
											StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
			SpreadsheetDocument.Put(TemplateArea);
		EndDo;
		
		TemplateArea = Template.GetArea("TotalProducts");
		SpreadsheetDocument.Put(TemplateArea);
		
		// TS Inventory.
		StringSelectionProducts = Header.Inventory.Select();
		
		TemplateArea = Template.GetArea("TableHeader");
		SpreadsheetDocument.Put(TemplateArea);
		
		TemplateArea = Template.GetArea("String");
		
		While StringSelectionProducts.Next() Do
			TemplateArea.Parameters.Fill(StringSelectionProducts);
			
			TemplateArea.Parameters.Material = DriveServer.GetProductsPresentationForPrinting(StringSelectionProducts.Material, 
											StringSelectionProducts.Characteristic, StringSelectionProducts.SKU);
			SpreadsheetDocument.Put(TemplateArea);
		EndDo;
		
		TemplateArea = Template.GetArea("Total");
		SpreadsheetDocument.Put(TemplateArea);
		
		// Signature.
		TemplateArea = Template.GetArea("Signatures");
		SpreadsheetDocument.Put(TemplateArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "RequestToWarehouse") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "RequestToWarehouse",
			NStr("en = 'Request to warehouse'; ru = 'Требование на склад';pl = 'Żądanie do magazynu';es_ES = 'Solicitud para el almacén';es_CO = 'Solicitud para el almacén';tr = 'Ambar talebi';it = 'Richiesta a magazzino';de = 'Anfrage an Lagerhaus'"),
			PrintForm(ObjectsArray, PrintObjects, , PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand 							= PrintCommands.Add();
	PrintCommand.ID 						= "RequestToWarehouse";
	PrintCommand.Presentation 				= NStr("en = 'Request to warehouse'; ru = 'Требование на склад';pl = 'Żądanie do magazynu';es_ES = 'Solicitud para el almacén';es_CO = 'Solicitud para el almacén';tr = 'Ambar talebi';it = 'Richiesta a magazzino';de = 'Anfrage an Lagerhaus'");
	PrintCommand.CheckPostingBeforePrint 	= False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region ToDoList

// StandardSubsystems.ToDoList

// See ToDoListOverridable.OnDetermineToDoListHandlers. 
Procedure OnFillToDoList(ToDoList) Export
	
	If Not AccessRight("Edit", Metadata.Documents.ProductionOrder) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "ProductionOrder";
	
	// Production orders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForProductionInWork > 0);
	ToDo.Presentation	= NStr("en = 'Production orders'; ru = 'Заказы на производство';pl = 'Zlecenia produkcyjne';es_ES = 'Órdenes de producción';es_CO = 'Órdenes de fabricación';tr = 'Üretim emirleri';it = 'Ordini di produzione';de = 'Produktionsaufträge'");
	ToDo.Owner			= Metadata.Subsystems.Production;
	
	// Fulfillment is expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForProductionExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForProductionExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Fulfillment is expired'; ru = 'Срок исполнения заказа истек';pl = 'Wykonanie wygasło';es_ES = 'Se ha vencido el plazo de cumplimiento';es_CO = 'Se ha vencido el plazo de cumplimiento';tr = 'Yerine getirme süresi doldu';it = 'L''adempimento è in ritardo';de = 'Ausfüllung ist abgelaufen'");
	ToDo.Count			= DocumentsCount.OrdersForProductionExecutionExpired;
	ToDo.Form			= "Document.ProductionOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// For today
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForProductionForToday";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForProductionForToday > 0);
	ToDo.Presentation	= NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün itibarıyla';it = 'Odierni';de = 'Für Heute'");
	ToDo.Count			= DocumentsCount.OrdersForProductionForToday;
	ToDo.Form			= "Document.ProductionOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// In progress
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForProductionInWork";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForProductionInWork > 0);
	ToDo.Presentation	= NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'");
	ToDo.Count			= DocumentsCount.OrdersForProductionInWork;
	ToDo.Form			= "Document.ProductionOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region ToDoList

Function DocumentsCount(EmployeesList)
	
	Result = New Structure;
	Result.Insert("OrdersForProductionExecutionExpired",	0);
	Result.Insert("OrdersForProductionForToday",			0);
	Result.Insert("OrdersForProductionInWork",				0);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Finish < &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Start <= &EndOfDayIfCurrentDateTimeSession
	|					AND DocProductionOrder.Finish >= &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionForToday,
	|	COUNT(DISTINCT DocProductionOrder.Ref) AS OrdersForProductionInWork
	|FROM
	|	Document.ProductionOrder AS DocProductionOrder
	|		{LEFT JOIN AccumulationRegister.ProductionOrders.Balance(, ) AS ProductionOrdersBalances
	|		ON DocProductionOrder.Ref = ProductionOrdersBalances.ProductionOrder}
	|		INNER JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatuses
	|		ON DocProductionOrder.OrderState = ProductionOrderStatuses.Ref
	|WHERE
	|	DocProductionOrder.Posted
	|	AND NOT DocProductionOrder.Closed
	|	AND ProductionOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|	AND DocProductionOrder.Responsible IN(&EmployeesList)";
	
	Query.SetParameter("CurrentDateTimeSession",			CurrentSessionDate());
	Query.SetParameter("EmployeesList",						EmployeesList);
	Query.SetParameter("EndOfDayIfCurrentDateTimeSession",	EndOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region WIPsGeneration

Function CreateWIPsWithoutOperations(Parameters)
	
	Operations = Parameters.Operations;
	
	LevelProducts = Operations.Rows;
	
	For Each LevelProducts_Item In LevelProducts Do
		
		ReleaseRequired = True;
		
		CreateOneWIPWithoutOperations(LevelProducts_Item.Rows, ReleaseRequired, Parameters);
		
		If LevelProducts_Item.Create Then
			
			ParamsToCreateWIP = ParamsToCreateWIP(Parameters, LevelProducts_Item);
			LevelProducts_Item.WIP = CreateWIP(ParamsToCreateWIP, ReleaseRequired);
			LevelProducts_Item.Create = LevelProducts_Item.WIP.IsEmpty();
			
		EndIf;
		
	EndDo;
	
	Return Operations;
	
EndFunction

Function CreateWIPsWithOperations(Parameters)
	
	Operations = Parameters.Operations;
	
	LevelProducts = Operations.Rows;
	
	For Each LevelProducts_Item In LevelProducts Do
		
		ReleaseRequired = True;
		
		Level0 = LevelProducts_Item.Rows;
		
		For Each Level0_Item In Level0 Do
			
			CreateOneWIPWithOperations(Level0_Item.Rows, ReleaseRequired, Parameters);
			
		EndDo;
		
		If LevelProducts_Item.Create Then
			
			ParamsToCreateWIP = ParamsToCreateWIP(Parameters, LevelProducts_Item);
			LevelProducts_Item.WIP = CreateWIP(ParamsToCreateWIP, ReleaseRequired);
			LevelProducts_Item.Create = LevelProducts_Item.WIP.IsEmpty();
			
		EndIf;
		
	EndDo;
	
	FillWIPInLowerLevels(LevelProducts);
	
	Return Operations;
	
EndFunction

Function ParamsToCreateWIP(Parameters, TreeLine)
	
	Result = New Structure;
	
	Result.Insert("ProductionOrder", Parameters.ProductionOrder);
	
	Result.Insert("Products", TreeLine.SemifinishedProducts);
	Result.Insert("Characteristic", TreeLine.SemifinishedCharacteristic);
	Result.Insert("Specification", TreeLine.ActivitySpecification);
	Result.Insert("BOMHierarchyItem", TreeLine.HierarchyItem);
	Result.Insert("Quantity", ?(Parameters.ConsiderAvailableBalance, TreeLine.QuantityToProduce, TreeLine.QuantityInOrder));
	
	Result.Insert("ReleaseRequired",
		TreeLine.SemifinishedProducts = TreeLine.Products
		And TreeLine.SemifinishedCharacteristic = TreeLine.Characteristic);
		
	Result.Insert("ProductionMethod", TreeLine.ProductionMethod);
	
	Return Result;
	
EndFunction

Function CreateWIP(WIPParameters, ReleaseRequired)
	
	DocumentWIP = Documents.ManufacturingOperation.CreateDocument();
	
	DocumentWIP.FillByProductionOrder(WIPParameters.ProductionOrder);
	
	DocumentWIP.Date = CurrentSessionDate();
	DocumentWIP.Status = Enums.ManufacturingOperationStatuses.Open;
	DocumentWIP.Author = Users.CurrentUser();
	FillPropertyValues(DocumentWIP,
		WIPParameters,
		"Products, Characteristic, Quantity, Specification, BOMHierarchyItem, ReleaseRequired, ProductionMethod");
	DocumentWIP.MeasurementUnit = Common.ObjectAttributeValue(WIPParameters.Products, "MeasurementUnit");
	
	If WIPParameters.ReleaseRequired Then
		DocumentWIP.ReleaseRequired = WIPParameters.ReleaseRequired And ReleaseRequired;
		ReleaseRequired = False;
	EndIf;
	
	DocumentWIP.StructuralUnit = BOMDepartment(WIPParameters.Specification);
	If DocumentWIP.StructuralUnit.IsEmpty() Then
		DocumentWIP.StructuralUnit = Common.ObjectAttributeValue(WIPParameters.ProductionOrder, "StructuralUnit");
	EndIf;
	
	RelatedWarehouses = RelatedWarehouses(DocumentWIP.StructuralUnit, DocumentWIP.Products);
	FillPropertyValues(DocumentWIP, RelatedWarehouses);

	DocumentWIP.FillInActivitiesByBOM();
	
	OperationsListToDelete = OperationsListFromCreatedWIPs(WIPParameters);
	FilterWIPActivities(DocumentWIP.Activities, OperationsListToDelete);
	
	InHouseProduction = Enums.ProductionMethods.InHouseProduction;
	
	If Not ValueIsFilled(DocumentWIP.ProductionMethod) Or Not GetFunctionalOption("CanReceiveSubcontractingServices") Then
		DocumentWIP.ProductionMethod = InHouseProduction;
	EndIf;
	
	If DocumentWIP.ProductionMethod = InHouseProduction  Then
		DocumentWIP.FillTabularSectionBySpecification(Undefined, True);
		DocumentWIP.FillByProductsWithBOM(Undefined, True);
	EndIf;
	
	SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "InventoryStructuralUnitPositionInWIP");
	If ValueIsFilled(SettingValue) Then
		DocumentWIP.InventoryStructuralUnitPosition = SettingValue;
	Else
		DocumentWIP.InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(DocumentWIP, WIPParameters.ProductionOrder);
	EndIf;
	
	Try
		DocumentWIP.Write(DocumentWriteMode.Posting);
	Except
		DocumentWIP.Write(DocumentWriteMode.Write);
	EndTry;
	
	Return DocumentWIP.Ref;
	
EndFunction

Procedure FillWIPInLowerLevels(LevelProducts)
	
	For Each LevelProducts_Item In LevelProducts Do
		
		Level_WIP = LevelProducts_Item.WIP;
		
		For Each Level_Item In LevelProducts_Item.Rows Do
			
			If ValueIsFilled(Level_WIP) And Not ValueIsFilled(Level_Item.WIP) Then
				Level_Item.WIP = Level_WIP;
			EndIf;
			
			FillWIPInLowerLevels(Level_Item.Rows);
			
		EndDo;
		
	EndDo;
	
EndProcedure

Function OperationsListFromCreatedWIPs(WIPParameters)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperationActivities.Activity AS Activity
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND ManufacturingOperation.BasisDocument = &BasisDocument
	|	AND ManufacturingOperation.Products = &Products
	|	AND ManufacturingOperation.Characteristic = &Characteristic
	|	AND ManufacturingOperation.Specification = &Specification
	|	AND ManufacturingOperation.BOMHierarchyItem = &BOMHierarchyItem";
	
	Query.SetParameter("BasisDocument", 	WIPParameters.ProductionOrder);
	Query.SetParameter("Products", 			WIPParameters.Products);
	Query.SetParameter("Characteristic", 	WIPParameters.Characteristic);
	Query.SetParameter("Specification", 	WIPParameters.Specification);
	Query.SetParameter("BOMHierarchyItem",	WIPParameters.BOMHierarchyItem);
	
	Result = Query.Execute().Unload();
	
	Return Result.UnloadColumn("Activity");
	
EndFunction

Procedure FilterWIPActivities(TS_Activities, OperationsListToDelete)
	
	RowsToDeleteArray = New Array;
	
	For Each Row In TS_Activities Do
		If OperationsListToDelete.Find(Row.Activity) <> Undefined Then
			RowsToDeleteArray.Add(Row);
		EndIf;	
	EndDo;
	
	For Each Row In RowsToDeleteArray Do
		TS_Activities.Delete(Row);
	EndDo;
	
EndProcedure

Function BOMDepartment(BOM)
	
	Department = Catalogs.BusinessUnits.EmptyRef();
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	BillsOfMaterialsOperations.LineNumber AS LineNumber,
	|	BillsOfMaterialsOperations.Activity AS Activity
	|INTO Activities
	|FROM
	|	Catalog.BillsOfMaterials.Operations AS BillsOfMaterialsOperations
	|WHERE
	|	BillsOfMaterialsOperations.Ref = &BOM
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	Activities.LineNumber AS LineNumber,
	|	Activities.Activity AS Activity,
	|	CompanyResourceTypes.BusinessUnit AS BusinessUnit
	|FROM
	|	Activities AS Activities
	|		INNER JOIN Catalog.ManufacturingActivities.WorkCenterTypes AS ManufacturingActivitiesWorkCenterTypes
	|		ON Activities.Activity = ManufacturingActivitiesWorkCenterTypes.Ref
	|		INNER JOIN Catalog.CompanyResourceTypes AS CompanyResourceTypes
	|		ON (ManufacturingActivitiesWorkCenterTypes.WorkcenterType = CompanyResourceTypes.Ref)
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BOM", BOM);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		RealDepartment = SelectionDetailRecords.BusinessUnit;
	EndIf;
	
	SetPrivilegedMode(False);
	
	If Catalogs.BusinessUnits.DepartmentReadingAllowed(RealDepartment) Then
		Department = RealDepartment;
	Else
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate Work-in-progress for ""%1"". It is required to fill in operations assigned to work center types.
                  |The work center types are related to the departments that you have insufficient access rights for.
                  |Do any of the following:
                  |- To continue generating Work-in-progress for other products, clear the Generate checkbox for ""%1"".
                  |- To be able to generate Work-in-progress for ""%1"", contact the Administrator for the appropriate access rights.'; 
                  |ru = 'Не удалось создать Незавершенное производство для ""%1"".
                  |В документе необходимо указать операции, назначенные типам рабочих центров, связанных с подразделениями, для управления которыми у вас недостаточно прав доступа.
                  |Выполните одно из следующих действий:
                  |- Чтобы создать Незавершенное производство для другой номенклатуры, снимите флажок ""Сформировать"" для ""%1"".
                  |- Чтобы создать Незавершенное производство для ""%1"", обратитесь к администратору за соответствующими правами доступа.';
                  |pl = 'Nie można wygenerować Pracy w toku dla ""%1"". Wymagane jest wypełnienie operacji przydzielonych do typów gniazd produkcyjnych.
                  |Typy gniazd produkcyjnych są powiązane z działami, do których nie masz wystarczających praw dostępu .
                  |Wykonaj jedną z następujących czynności:
                  |- Aby kontynuować generowanie Pracy w toku dla innych produktów, odznacz pole wyboru Wygeneruj dla ""%1"".
                  |- Aby mieć możliwość generowania Pracy w toku dla ""%1"", skontaktuj się z Administratorem dla odpowiednich praw dostępu.';
                  |es_ES = 'No se puede generar Trabajo en progreso para ""%1"". Se requiere para rellenar las operaciones asignadas a los tipos de centro de trabajo.
                  | Los tipos de centros de trabajo están relacionados con los departamentos para los que no tiene suficientes derechos de acceso.
                  |Realice una de las siguientes acciones:
                  |- Para seguir generando Trabajo en progreso para otros productos, desmarque la casilla de verificación Generar para ""%1"".
                  |- Para poder generar Trabajo en progreso para ""%1"", póngase en contacto con el Administrador para obtener los derechos de acceso adecuados.';
                  |es_CO = 'No se puede generar Trabajo en progreso para ""%1"". Se requiere para rellenar las operaciones asignadas a los tipos de centro de trabajo.
                  | Los tipos de centros de trabajo están relacionados con los departamentos para los que no tiene suficientes derechos de acceso.
                  |Realice una de las siguientes acciones:
                  |- Para seguir generando Trabajo en progreso para otros productos, desmarque la casilla de verificación Generar para ""%1"".
                  |- Para poder generar Trabajo en progreso para ""%1"", póngase en contacto con el Administrador para obtener los derechos de acceso adecuados.';
                  |tr = '""%1"" için İşlem bitişi oluşturulamıyor. Bu, iş merkezi türlerine atanan işlemleri doldurmak için gerekli.
                  | İş merkezi türleri, gerekli erişim yetkilerine sahip olmadığınız bölümlerle ilişkili.
                  |Aşağıdakilerden birini yapın:
                  |- Diğer ürünler için İşlem bitişi oluşturmaya devam etmek için ""%1"" için Oluştur onay kutusunu temizleyin.
                  |- ""%1"" için İşlem bitişi oluşturabilmek için, Yönetici ile irtibata geçip gerekli erişim yetkilerini isteyin.';
                  |it = 'Non è possibile generare lavori in corso per ""%1"". È necessario compilare le operazioni assegnate ai tipi di centro di lavoro.
                  |I tipi di centro di lavoro sono correlati ai reparti per i quali non si dispone di diritti di accesso sufficienti.
                  |Per continuare a generare lavori in corso per altri prodotti, deselezionare la casella di controllo Genera per  ""%1"".
                  |- Per poter generare lavori in corso per ""%1"", contatta l''amministratore per ottenere i diritti di accesso appropriati.';
                  |de = 'Fehler beim Generieren der Arbeit in Bearbeitung für ""%1"". Sie ist für Auffüllen von Operationen zugewiesen an Typen des Arbeitsabschnitts erforderlich.
                  |Die Typen der Arbeitsabschnitts sind mit den Abteilungen verbunden, auf die Sie unzureichende Zugriffsrechte haben.
                  |Tun Sie irgendetwas des Folgenden:
                  |- Für weiteres Generieren der Arbeit in Bearbeitung für andere Produkte  deaktivieren Sie das Kontrollkästchen  für ""%1"".
                  |- Um die Arbeit in Bearbeitung für ""%1"" generieren zu können, kontaktieren Sie den Administrator für die jeweiligen Zugriffsrechte.'"),
			BOM.Owner);
		Raise ErrorMessage;
	EndIf;
	
	Return Department;
	
EndFunction

Procedure CreateOneWIPWithoutOperations(LevelProducts, ReleaseRequired, Parameters)
	
	For Each Level_Product In LevelProducts Do
		
		CreateOneWIPWithoutOperations(Level_Product.Rows, ReleaseRequired, Parameters);
		
		If Level_Product.Create Then
			
			ParamsToCreateWIP = ParamsToCreateWIP(Parameters, Level_Product);
			Level_Product.WIP = CreateWIP(ParamsToCreateWIP, ReleaseRequired);
			Level_Product.Create = Level_Product.WIP.IsEmpty();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure CreateOneWIPWithOperations(LevelProducts, ReleaseRequired, Parameters)
	
	For Each Level_Product In LevelProducts Do
		
		Level = Level_Product.Rows;
		
		For Each Level_Item In Level Do
			
			CreateOneWIPWithOperations(Level_Item.Rows, ReleaseRequired, Parameters);
			
		EndDo;
		
		If Level_Product.Create Then
			
			ParamsToCreateWIP = ParamsToCreateWIP(Parameters, Level_Product);
			Level_Product.WIP = CreateWIP(ParamsToCreateWIP, ReleaseRequired);
			Level_Product.Create = Level_Product.WIP.IsEmpty();
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function RelatedWarehouses(StructuralUnit, Product) Export
	
	Result = New Structure("InventoryStructuralUnit, CellInventory, DisposalsStructuralUnit, DisposalsCell");
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	StructuralUnitData.TransferSource AS InventoryStructuralUnit,
	|	StructuralUnitData.TransferSourceCell AS CellInventory,
	|	StructuralUnitData.RecipientOfWastes AS DisposalsStructuralUnit,
	|	StructuralUnitData.DisposalsRecipientCell AS DisposalsCell
	|FROM
	|	Catalog.BusinessUnits AS StructuralUnitData
	|WHERE
	|	StructuralUnitData.Ref = &StructuralUnit";
	
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		FillPropertyValues(Result, Selection);
	EndIf;
	
	If Not ValueIsFilled(Result.InventoryStructuralUnit) Then
		Result.InventoryStructuralUnit = StructuralUnit;
	EndIf;
	If Not ValueIsFilled(Result.DisposalsStructuralUnit) Then
		Result.DisposalsStructuralUnit = StructuralUnit;
	EndIf;
	
	SetPrivilegedMode(False);
	
	If Not Catalogs.BusinessUnits.DepartmentReadingAllowed(Result.InventoryStructuralUnit)
		Or Not Catalogs.BusinessUnits.DepartmentReadingAllowed(Result.DisposalsStructuralUnit) Then
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot generate Work-in-progress for ""%2"". It is required to fill in the related warehouse. Your access rights are insufficient to manage this warehouse and data related to it.
                  |Do any of the following:
                  |- To continue generating Work-in-progress for other products, clear the checkbox for ""%2"".
                  |- To be able to generate Work-in-progress for ""%2"", contact the Administrator for the appropriate access rights or open the Related business units of ""%1"" and select another related warehouse in the ""Consume components from"" or ""Transfer wastes to"" field.'; 
                  |ru = 'Не удалось создать Незавершенное производство для ""%2"". В документе необходимо указать склад, для управления которым у вас недостаточно прав доступа.
                  |Выполните одно из следующих действий:
                  |- Чтобы создать Незавершенное производство для другой номенклатуры, снимите флажок для ""%2"".
                  |- Чтобы создать Незавершенное производство для ""%2"", обратитесь к администратору за соответствующими правами доступа или откройте параметры автоперемещения запасов для ""%1"" и выберите другой склад в поле ""Списывать материалы из"" или ""Перемещать отходы в"".';
                  |pl = 'Nie można wygenerować Pracy w toku dla ""%2"". Nalepy wypełnić powiązany magazyn. Twoje prawa dostępu są niewystarczające do zarządzania tym magazynem i powiązanych z nim danych.
                  |Wykonaj jedną z następujących czynności:
                  |- Aby kontynuować generowanie Pracy w toku dla innych produktów, odznacz pole wyboru dla ""%2"".
                  |- Aby mieć możliwość generowania Pracy w toku dla ""%2"", skontaktuj się z Administratorem dla odpowiednich praw dostępu lub otwórz Powiązane jednostki biznesowe ""%1"" i wybierz inny powiązany magazyn w polu ""Spożyj komponenty z"" lub ""Przesuń odpady do"".';
                  |es_ES = 'No se puede generar Trabajo en progreso para ""%2"". Se requiere para rellenar el almacén relacionado. Sus derechos de acceso son insuficientes para gestionar este almacén y los datos relacionados con él.
                  |Realice una de las siguientes acciones:
                  |- Para seguir generando Trabajo en progreso para otros productos, desmarque la casilla de verificación para ""%2"".
                  |- Para poder generar Trabajo en progreso para ""%2"", póngase en contacto con el administrador para obtener los derechos de acceso adecuados o abra las unidades empresariales relacionadas de ""%1"" y seleccione otro almacén relacionado en el campo ""Consumir materia prima desde"" o ""Transferir residuos a"".';
                  |es_CO = 'No se puede generar Trabajo en progreso para ""%2"". Se requiere para rellenar el almacén relacionado. Sus derechos de acceso son insuficientes para gestionar este almacén y los datos relacionados con él.
                  |Realice una de las siguientes acciones:
                  |- Para seguir generando Trabajo en progreso para otros productos, desmarque la casilla de verificación para ""%2"".
                  |- Para poder generar Trabajo en progreso para ""%2"", póngase en contacto con el administrador para obtener los derechos de acceso adecuados o abra las unidades empresariales relacionadas de ""%1"" y seleccione otro almacén relacionado en el campo ""Consumir materia prima desde"" o ""Transferir residuos a"".';
                  |tr = '""%2"" için İşlem bitişi oluşturulamıyor. Bu, ilgili ambarı doldurmak için gerekli. Bu ambarı ve onunla ilgili verileri yönetmek için gerekli erişim yetkileriniz yok.
                  |Aşağıdakilerden birini yapın:
                  |- Diğer ürünler için İşlem bitişi oluşturmaya devam etmek için ""%2"" için onay kutusunu temizleyin.
                  |- ""%2"" için İşlem bitişi oluşturabilmek için Yönetici ile irtibata geçerek gerekli erişim yetkilerini isteyin veya ilgili ""%1"" departmanlarını açıp ""Malzemelerin tüketileceği yer"" veya ""Atıkların transfer edileceği yer"" alanında başka bir ilgili ambar seçin.';
                  |it = 'Non è possibile generare lavori in corso per ""%2"". È necessario per compilare il relativo magazzino. I diritti di accesso sono insufficienti per gestire questo magazzino e i dati ad esso correlati.
                  |Eseguire una delle seguenti operazioni:
                  |- Per continuare a generare i lavori in corso per altri prodotti, deselezionare la casella di controllo ""%2"".
                  |- Per poter generare lavori in corso per ""%2"", contatta l''Amministratore per ottenere i diritti di accesso appropriati o aprire le unità aziendali correlate di ""%1"" e seleziona un altro magazzino correlato nel campo ""Consuma componenti da"" o ""Trasferisci rifiuti a"".';
                  |de = 'Fehler beim Generieren der Arbeit in Bearbeitung für ""%2"". Sie ist für Auffüllen des verbundenen Lagers erforderlich. Ihre Zugriffsrechte sind für Steuern dieses Lagers und der mit ihm verbundenen Daten unzureichend. 
                  |Tun Sie irgendetwas des Folgenden:
                  |- Für weiteres Generieren der Arbeit in Bearbeitung für andere Produkte  deaktivieren Sie das Kontrollkästchen  für ""%2"".
                  |- Um die Arbeit in Bearbeitung für ""%2"" generieren zu können, kontaktieren Sie den Administrator für die jeweiligen Zugriffsrechte oder öffen Sie die Verbundene Abteilungen von ""%1"" und wählen Sie einen anderen verbundenen Lager im Feld ""Komponente verbrauchen von"" oder ""Rückstände übergeben an"".'"),
			StructuralUnit,
			Product);
		Raise ErrorMessage;
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#EndIf