#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefKitOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	KitOrder.Ref AS Ref,
	|	KitOrder.Date AS Date,
	|	KitOrder.Finish AS Finish,
	|	KitOrderStatusesCatalog.OrderStatus AS OrderStatus,
	|	KitOrder.Closed AS Closed,
	|	KitOrder.Start AS Start
	|INTO KitOrderHeader
	|FROM
	|	Document.KitOrder AS KitOrder
	|		LEFT JOIN Catalog.KitOrderStatuses AS KitOrderStatusesCatalog
	|		ON KitOrder.OrderState = KitOrderStatusesCatalog.Ref
	|WHERE
	|	KitOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrderProducts.Products AS Products,
	|	KitOrderProducts.Ref AS Ref,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	KitOrderProducts.Characteristic AS Characteristic,
	|	KitOrderProducts.Quantity AS Quantity,
	|	KitOrderProducts.SalesOrder AS SalesOrder,
	|	KitOrderProducts.Specification AS Specification,
	|	KitOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	KitOrderHeader.Date AS Date,
	|	KitOrderHeader.Finish AS Finish,
	|	KitOrderHeader.OrderStatus AS OrderStatus,
	|	KitOrderHeader.Closed AS Closed
	|INTO KitOrderProducts
	|FROM
	|	Document.KitOrder.Products AS KitOrderProducts
	|		INNER JOIN KitOrderHeader AS KitOrderHeader
	|		ON KitOrderProducts.Ref = KitOrderHeader.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON KitOrderProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON KitOrderProducts.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrderInventory.LineNumber AS LineNumber,
	|	KitOrderInventory.Products AS Products,
	|	KitOrderInventory.Characteristic AS Characteristic,
	|	KitOrderInventory.Quantity AS Quantity,
	|	KitOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	KitOrderHeader.Start AS Start,
	|	KitOrderHeader.Closed AS Closed,
	|	KitOrderHeader.OrderStatus AS OrderStatus,
	|	KitOrderHeader.Ref AS Ref
	|INTO KitOrderInventory
	|FROM
	|	Document.KitOrder.Inventory AS KitOrderInventory
	|		INNER JOIN KitOrderHeader AS KitOrderHeader
	|		ON KitOrderInventory.Ref = KitOrderHeader.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON KitOrderInventory.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(KitOrderProducts.Finish, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	KitOrderProducts.Products AS Products,
	|	KitOrderProducts.Ref AS Order,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderProducts.Quantity
	|		ELSE KitOrderProducts.Quantity * KitOrderProducts.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderProducts AS KitOrderProducts
	|WHERE
	|	(KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderProducts.Closed = FALSE
	|			OR KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	KitOrderInventory.LineNumber,
	|	BEGINOFPERIOD(KitOrderInventory.Start, DAY),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	KitOrderInventory.Products,
	|	UNDEFINED,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(KitOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderInventory.Quantity
	|		ELSE KitOrderInventory.Quantity * KitOrderInventory.Factor
	|	END
	|FROM
	|	KitOrderInventory AS KitOrderInventory
	|WHERE
	|	(KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderInventory.Closed = FALSE
	|			OR KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	KitOrderProducts.Date AS Period,
	|	&Company AS Company,
	|	KitOrderProducts.Ref AS KitOrder,
	|	KitOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderProducts.Quantity
	|		ELSE KitOrderProducts.Quantity * KitOrderProducts.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderProducts AS KitOrderProducts
	|WHERE
	|	KitOrderProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderProducts.Closed = FALSE
	|			OR KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrderInventory.LineNumber AS LineNumber,
	|	BEGINOFPERIOD(KitOrderInventory.Start, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	UNDEFINED AS SalesOrder,
	|	KitOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderInventory.Quantity
	|		ELSE KitOrderInventory.Quantity * KitOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderInventory AS KitOrderInventory
	|WHERE
	|	(KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderInventory.Closed = FALSE
	|			OR KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	KitOrderInventory.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	KitOrderProducts.Date AS Period,
	|	&Company AS Company,
	|	KitOrderProducts.SalesOrder AS SalesOrder,
	|	KitOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	KitOrderProducts.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(KitOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderProducts.Quantity
	|		ELSE KitOrderProducts.Quantity * KitOrderProducts.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderProducts AS KitOrderProducts
	|WHERE
	|	KitOrderProducts.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND KitOrderProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND (KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderProducts.Closed = FALSE
	|			OR KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 					DocumentRefKitOrder);
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", 	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  			StructureAdditionalProperties.AccountingPolicy.UseBatches);

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",		Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableKitOrders", 					Result[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",			Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", 				Result[6].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefKitOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
		"SELECT
	|	KitOrder.Ref AS Ref,
	|	KitOrder.Date AS Date,
	|	KitOrder.Finish AS Finish,
	|	KitOrderStatusesCatalog.OrderStatus AS OrderStatus,
	|	KitOrder.Closed AS Closed,
	|	KitOrder.Start AS Start
	|INTO KitOrderHeader
	|FROM
	|	Document.KitOrder AS KitOrder
	|		LEFT JOIN Catalog.KitOrderStatuses AS KitOrderStatusesCatalog
	|		ON KitOrder.OrderState = KitOrderStatusesCatalog.Ref
	|WHERE
	|	KitOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrderProducts.Products AS Products,
	|	KitOrderProducts.Ref AS Ref,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	KitOrderProducts.Characteristic AS Characteristic,
	|	KitOrderProducts.Quantity AS Quantity,
	|	KitOrderProducts.Specification AS Specification,
	|	KitOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	KitOrderHeader.Start AS Start,
	|	KitOrderHeader.Finish AS Finish,
	|	KitOrderHeader.OrderStatus AS OrderStatus,
	|	KitOrderHeader.Closed AS Closed
	|INTO KitOrderProducts
	|FROM
	|	Document.KitOrder.Products AS KitOrderProducts
	|		INNER JOIN KitOrderHeader AS KitOrderHeader
	|		ON KitOrderProducts.Ref = KitOrderHeader.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON KitOrderProducts.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON KitOrderProducts.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	KitOrderInventory.LineNumber AS LineNumber,
	|	KitOrderInventory.Products AS Products,
	|	KitOrderInventory.Characteristic AS Characteristic,
	|	KitOrderInventory.Quantity AS Quantity,
	|	KitOrderInventory.SalesOrder AS SalesOrder,
	|	KitOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOMCatalog.Factor, 1) AS Factor,
	|	KitOrderHeader.Start AS Start,
	|	KitOrderHeader.Date AS Date,
	|	KitOrderHeader.Closed AS Closed,
	|	KitOrderHeader.OrderStatus AS OrderStatus,
	|	KitOrderHeader.Ref AS Ref
	|INTO KitOrderInventory
	|FROM
	|	Document.KitOrder.Inventory AS KitOrderInventory
	|		INNER JOIN KitOrderHeader AS KitOrderHeader
	|		ON KitOrderInventory.Ref = KitOrderHeader.Ref
	|		LEFT JOIN Catalog.UOM AS UOMCatalog
	|		ON KitOrderInventory.MeasurementUnit = UOMCatalog.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	0 AS LineNumber,
	|	BEGINOFPERIOD(KitOrderProducts.Finish, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	UNDEFINED AS Order,
	|	KitOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderProducts.Quantity
	|		ELSE KitOrderProducts.Quantity * KitOrderProducts.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderProducts AS KitOrderProducts
	|WHERE
	|	(KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderProducts.Closed = FALSE
	|			OR KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	KitOrderInventory.LineNumber,
	|	BEGINOFPERIOD(KitOrderInventory.Start, DAY),
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	KitOrderInventory.Ref,
	|	KitOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN VALUETYPE(KitOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderInventory.Quantity
	|		ELSE KitOrderInventory.Quantity * KitOrderInventory.Factor
	|	END
	|FROM
	|	KitOrderInventory AS KitOrderInventory
	|WHERE
	|	(KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderInventory.Closed = FALSE
	|			OR KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	KitOrderInventory.Date AS Period,
	|	&Company AS Company,
	|	KitOrderInventory.Ref AS KitOrder,
	|	KitOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderInventory.Quantity
	|		ELSE KitOrderInventory.Quantity * KitOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderInventory AS KitOrderInventory
	|WHERE
	|	(KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderInventory.Closed = FALSE
	|			OR KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BEGINOFPERIOD(KitOrderProducts.Start, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	UNDEFINED AS SalesOrder,
	|	KitOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(KitOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderProducts.Quantity
	|		ELSE KitOrderProducts.Quantity * KitOrderProducts.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderProducts AS KitOrderProducts
	|WHERE
	|	(KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderProducts.Closed = FALSE
	|			OR KitOrderProducts.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	KitOrderInventory.Date AS Period,
	|	&Company AS Company,
	|	KitOrderInventory.SalesOrder AS SalesOrder,
	|	KitOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN KitOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	KitOrderInventory.Ref AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(KitOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN KitOrderInventory.Quantity
	|		ELSE KitOrderInventory.Quantity * KitOrderInventory.Factor
	|	END AS Quantity
	|FROM
	|	KitOrderInventory AS KitOrderInventory
	|WHERE
	|	KitOrderInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND (KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND KitOrderInventory.Closed = FALSE
	|			OR KitOrderInventory.OrderStatus = VALUE(Enum.OrderStatuses.Completed))";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefKitOrder);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);

	Result = Query.ExecuteBatch();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar",		Result[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableKitOrders",					Result[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand",			Result[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders",					Result[6].Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefKitOrder, StructureAdditionalProperties) Export
	
	If DocumentRefKitOrder.OperationKind = Enums.OperationTypesKitOrder.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefKitOrder, StructureAdditionalProperties);
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefKitOrder, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefKitOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsKitOrdersChange",
	// "RegisterRecordsBackordersChange", "RegisterRecordsInventoryDemandChange",
	// contain records, control products implementation.
	
	If StructureTemporaryTables.RegisterRecordsKitOrdersChange
		OR StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryDemandChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsKitOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.KitOrder) AS KitOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(KitOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsKitOrdersChange.QuantityChange, 0) + ISNULL(KitOrdersBalances.QuantityBalance, 0) AS BalanceKitOrders,
		|	ISNULL(KitOrdersBalances.QuantityBalance, 0) AS QuantityBalanceKitOrders
		|FROM
		|	RegisterRecordsKitOrdersChange AS RegisterRecordsKitOrdersChange
		|		LEFT JOIN AccumulationRegister.KitOrders.Balance(
		|				&ControlTime,
		|				(Company, KitOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsKitOrdersChange.Company AS Company,
		|						RegisterRecordsKitOrdersChange.KitOrder AS KitOrder,
		|						RegisterRecordsKitOrdersChange.Products AS Products,
		|						RegisterRecordsKitOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsKitOrdersChange AS RegisterRecordsKitOrdersChange)) AS KitOrdersBalances
		|		ON RegisterRecordsKitOrdersChange.Company = KitOrdersBalances.Company
		|			AND RegisterRecordsKitOrdersChange.KitOrder = KitOrdersBalances.KitOrder
		|			AND RegisterRecordsKitOrdersChange.Products = KitOrdersBalances.Products
		|			AND RegisterRecordsKitOrdersChange.Characteristic = KitOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(KitOrdersBalances.QuantityBalance, 0) < 0
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
		|				(Company, MovementType, SalesOrder, Products, Characteristic) IN
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
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) IN
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
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty() Then
			DocumentObjectKitOrder = DocumentRefKitOrder.GetObject()
		EndIf;
		
		// Negative balance by kit orders.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToKitOrdersRegisterErrors(DocumentObjectKitOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory demand.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectKitOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the backorders.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectKitOrder, QueryResultSelection, Cancel);
		EndIf;
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefKitOrder, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

#Region FillingProcedures

// Checks the possibility of input on the basis.
//
Procedure VerifyEnteringAbilityByKitOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = 'Select a posted Kit order.'; ru = 'Выберите проведенный заказ на комплектацию.';pl = 'Wybierz zadekretowane Zamówienie zestawu.';es_ES = 'Seleccione un pedido del kit enviado.';es_CO = 'Seleccione un pedido del kit enviado.';tr = 'Kaydedilmiş bir Set siparişi seçin.';it = 'Selezionare un Ordine kit pubblicato.';de = 'Einen gebuchten Kit-Auftrag auswählen.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			ErrorText = NStr("en = 'Select a Kit order that is not completed.'; ru = 'Выберите незавершенный заказ на комплектацию.';pl = 'Wybierz Zamówienie zestawu, które nie jest zakończone.';es_ES = 'Por favor, seleccione un pedido del kit que no esté finalizado.';es_CO = 'Por favor, seleccione un pedido del kit que no esté finalizado.';tr = 'Tamamlanmamış bir Set siparişi seçin.';it = 'Selezionare un Ordine kit non completato.';de = 'Bitte wählen Sie einen Kit-Auftrag aus, der noch nicht abgeschlossen ist.'");
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'Cannot generate Kit processed. The Kit order status is Open. Set the status to In progress. Then try again.'; ru = 'Не удается создать результат комплектации. Статус заказа на комплектацию - ""Открыт"". Установите статус ""В работе"" и повторите попытку.';pl = 'Nie można wygenerować przetwarzanego zestawu. Zamówienie zestawu ma status Otwarte. Ustaw status na W toku. Następnie spróbuj ponownie.';es_ES = 'No se puede generar el kit procesado. El estado del pedido del kit es Abrir. Establezca el estado a En progreso. Inténtelo de nuevo.';es_CO = 'No se puede generar el kit procesado. El estado del pedido del kit es Abrir. Establezca el estado a En progreso. Inténtelo de nuevo.';tr = 'İşlenen set oluşturulamıyor. Set siparişi durumu Açık. Durumu İşlemde olarak ayarlayıp tekrar deneyin.';it = 'Impossibile generare kit processato. Lo stato dell''Ordine kit è Aperto. Impostare lo stato su In corso. Poi riprovare.';de = 'Kann kein Kit bearbeitet generieren. Der Status von Kit-Auftrag ist ""Offen"". Setzen Sie den Status ""In Bearbeitung"". Dann versuchen Sie erneut.'");
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
	|	KitOrder.Ref AS Ref,
	|	KitOrder.SalesOrder AS SalesOrder,
	|	KitOrder.OperationKind AS OperationKind
	|FROM
	|	Document.KitOrder AS KitOrder
	|WHERE
	|	KitOrder.SalesOrderPosition = VALUE(Enum.AttributeStationing.EmptyRef)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		Try
			KitOrderObject = Selection.Ref.GetObject();
			
			TableName = ?(Selection.OperationKind = Enums.OperationTypesKitOrder.Assembly, "Products", "Inventory");
			
			For Each Row In KitOrderObject[TableName] Do
			
				Row.SalesOrder = Selection.SalesOrder;
			
			EndDo;
			
			KitOrderObject.SalesOrderPosition = Enums.AttributeStationing.InHeader;
			
			InfobaseUpdate.WriteObject(KitOrderObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.KitOrder,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
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
	
	If Not AccessRight("Edit", Metadata.Documents.KitOrder) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "KitOrder";
	
	// Kit orders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForKitProcessingInWork > 0);
	ToDo.Presentation	= NStr("en = 'Kit orders'; ru = 'Заказы на комплектацию';pl = 'Zamówienia zestawów';es_ES = 'Pedidos del Kit';es_CO = 'Pedidos del Kit';tr = 'Set siparişleri';it = 'Ordini kit';de = 'Kit-Aufträge'");
	ToDo.Owner			= Metadata.Subsystems.Warehouse;
	
	// Fulfillment is expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForKitProcessingExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForKitProcessingExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Fulfillment is expired'; ru = 'Срок исполнения заказа истек';pl = 'Wykonanie wygasło';es_ES = 'Se ha vencido el plazo de cumplimiento';es_CO = 'Se ha vencido el plazo de cumplimiento';tr = 'Yerine getirme süresi doldu';it = 'Realizzazione scaduta';de = 'Ausfüllung ist abgelaufen'");
	ToDo.Count			= DocumentsCount.OrdersForKitProcessingExecutionExpired;
	ToDo.Form			= "Document.KitOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// For today
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForKitProcessingForToday";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForKitProcessingForToday > 0);
	ToDo.Presentation	= NStr("en = 'For today'; ru = 'На сегодня';pl = 'Na dzisiaj';es_ES = 'Para hoy';es_CO = 'Para hoy';tr = 'Bugün için';it = 'Odierni';de = 'Für Heute'");
	ToDo.Count			= DocumentsCount.OrdersForKitProcessingForToday;
	ToDo.Form			= "Document.KitOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// In progress
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "OrdersForKitProcessingInWork";
	ToDo.HasUserTasks	= (DocumentsCount.OrdersForKitProcessingInWork > 0);
	ToDo.Presentation	= NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In corso';de = 'In Bearbeitung'");
	ToDo.Count			= DocumentsCount.OrdersForKitProcessingInWork;
	ToDo.Form			= "Document.KitOrder.ListForm";
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
	Result.Insert("OrdersForKitProcessingExecutionExpired",	0);
	Result.Insert("OrdersForKitProcessingForToday",			0);
	Result.Insert("OrdersForKitProcessingInWork",			0);
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocKitOrder.Finish < &CurrentDateTimeSession
	|					AND ISNULL(KitOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocKitOrder.Ref
	|		END) AS OrdersForKitProcessingExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocKitOrder.Start <= &EndOfDayIfCurrentDateTimeSession
	|					AND DocKitOrder.Finish >= &CurrentDateTimeSession
	|					AND ISNULL(KitOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocKitOrder.Ref
	|		END) AS OrdersForKitProcessingForToday,
	|	COUNT(DISTINCT DocKitOrder.Ref) AS OrdersForKitProcessingInWork
	|FROM
	|	Document.KitOrder AS DocKitOrder
	|		{LEFT JOIN AccumulationRegister.KitOrders.Balance(, ) AS KitOrdersBalances
	|		ON DocKitOrder.Ref = KitOrdersBalances.KitOrder}
	|		INNER JOIN Catalog.KitOrderStatuses AS KitOrderStatuses
	|		ON DocKitOrder.OrderState = KitOrderStatuses.Ref
	|WHERE
	|	DocKitOrder.Posted
	|	AND NOT DocKitOrder.Closed
	|	AND KitOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|	AND DocKitOrder.Responsible IN(&EmployeesList)";
	
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

#EndRegion

#EndIf