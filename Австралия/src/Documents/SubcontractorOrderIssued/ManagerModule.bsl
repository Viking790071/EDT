#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSubcontractorOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	SubcontractorOrderIssued.Ref AS Ref,
	|	SubcontractorOrderIssued.Closed AS Closed,
	|	SubcontractorOrderIssued.OrderState AS OrderState,
	|	SubcontractorOrderIssued.Date AS Date,
	|	SubcontractorOrderIssued.Company AS Company,
	|	SubcontractorOrderIssued.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderIssued.ReceiptDate AS ReceiptDate,
	|	SubcontractorOrderIssued.Counterparty AS Counterparty,
	|	SubcontractorOrderIssued.ExchangeRate AS ExchangeRate,
	|	SubcontractorOrderIssued.Multiplicity AS Multiplicity,
	|	SubcontractorOrderIssued.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorOrderIssued.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorOrderIssued.DocumentAmount AS DocumentAmount,
	|	SubcontractorOrderIssued.BasisDocument AS BasisDocument,
	|	SubcontractorOrderIssued.SalesOrder AS SalesOrder
	|INTO SubcontractorOrderTable
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	SubcontractorOrderIssued.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderTable.Ref AS Ref,
	|	SubcontractorOrderTable.Closed AS Closed,
	|	SubcontractorOrderTable.Date AS Date,
	|	SubcontractorOrderTable.Company AS Company,
	|	SubcontractorOrderTable.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderTable.ReceiptDate AS ReceiptDate,
	|	SubcontractorOrderIssuedStatuses.OrderStatus AS OrderStatus,
	|	SubcontractorOrderTable.Counterparty AS Counterparty,
	|	SubcontractorOrderTable.ExchangeRate AS ExchangeRate,
	|	SubcontractorOrderTable.Multiplicity AS Multiplicity,
	|	SubcontractorOrderTable.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorOrderTable.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorOrderTable.DocumentAmount AS DocumentAmount,
	|	SubcontractorOrderTable.BasisDocument AS BasisDocument,
	|	SubcontractorOrderTable.SalesOrder AS SalesOrder,
	|	SubcontractorOrderTable.OrderState AS OrderState
	|INTO SubcontractorOrderHeaderPre
	|FROM
	|	SubcontractorOrderTable AS SubcontractorOrderTable
	|		LEFT JOIN Catalog.SubcontractorOrderIssuedStatuses AS SubcontractorOrderIssuedStatuses
	|		ON SubcontractorOrderTable.OrderState = SubcontractorOrderIssuedStatuses.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderTable.Ref AS Ref,
	|	SubcontractorOrderTable.Closed AS Closed,
	|	SubcontractorOrderTable.Date AS Date,
	|	SubcontractorOrderTable.Company AS Company,
	|	SubcontractorOrderTable.StructuralUnit AS StructuralUnit,
	|	SubcontractorOrderTable.ReceiptDate AS ReceiptDate,
	|	SubcontractorOrderTable.OrderStatus AS OrderStatus,
	|	SubcontractorOrderTable.Counterparty AS Counterparty,
	|	SubcontractorOrderTable.ExchangeRate AS ExchangeRate,
	|	SubcontractorOrderTable.Multiplicity AS Multiplicity,
	|	SubcontractorOrderTable.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorOrderTable.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorOrderTable.DocumentAmount AS DocumentAmount,
	|	SubcontractorOrderTable.BasisDocument AS BasisDocument,
	|	SubcontractorOrderTable.SalesOrder AS SalesOrder,
	|	VALUETYPE(SubcontractorOrderTable.BasisDocument) = TYPE(Document.ManufacturingOperation)
	|		AND SubcontractorOrderTable.BasisDocument <> VALUE(Document.ManufacturingOperation.EmptyRef) AS BaseWIP,
	|	SubcontractorOrderTable.OrderState AS OrderState
	|INTO SubcontractorOrderHeader
	|FROM
	|	SubcontractorOrderHeaderPre AS SubcontractorOrderTable
	|WHERE
	|	(SubcontractorOrderTable.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND SubcontractorOrderTable.Closed = FALSE
	|			OR SubcontractorOrderTable.OrderStatus = VALUE(Enum.OrderStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderProducts.Ref AS Ref,
	|	SubcontractorOrderProducts.Products AS Products,
	|	SubcontractorOrderProducts.Characteristic AS Characteristic,
	|	SubcontractorOrderProducts.Quantity AS Quantity,
	|	SubcontractorOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderProducts.Specification AS Specification
	|INTO SubcontractorOrderProducts
	|FROM
	|	Document.SubcontractorOrderIssued.Products AS SubcontractorOrderProducts
	|WHERE
	|	SubcontractorOrderProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	MAX(BillsOfMaterialsContent.ManufacturedInProcess) AS ManufacturedInProcess
	|INTO BOM
	|FROM
	|	SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		LEFT JOIN Catalog.BillsOfMaterials AS BillsOfMaterials
	|		ON SubcontractorOrderProducts.Specification = BillsOfMaterials.Ref
	|			AND SubcontractorOrderProducts.Products = BillsOfMaterials.Owner
	|			AND SubcontractorOrderProducts.Characteristic = BillsOfMaterials.ProductCharacteristic
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON (BillsOfMaterialsContent.Ref = BillsOfMaterials.Ref)
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	MIN(SubcontractorOrderProducts.LineNumber) AS LineNumber,
	|	SubcontractorOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	SubcontractorOrderHeader.Ref AS SubcontractorOrder,
	|	SubcontractorOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN SubcontractorOrderProducts.Quantity
	|			ELSE SubcontractorOrderProducts.Quantity * ISNULL(UOM.Factor, 1)
	|		END) AS Quantity,
	|	SubcontractorOrderHeader.ReceiptDate AS ReceiptDate,
	|	VALUE(Enum.FinishedProductTypes.FinishedProduct) AS FinishedProductType
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderProducts.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	SubcontractorOrderHeader.ReceiptDate,
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SubcontractorOrderHeader.Date
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(SubcontractorOrderByProducts.LineNumber),
	|	SubcontractorOrderHeader.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	&Company,
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderByProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorOrderByProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN SubcontractorOrderByProducts.Quantity
	|			ELSE SubcontractorOrderByProducts.Quantity * ISNULL(UOM.Factor, 1)
	|		END),
	|	SubcontractorOrderHeader.ReceiptDate,
	|	VALUE(Enum.FinishedProductTypes.ByProduct)
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.ByProducts AS SubcontractorOrderByProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderByProducts.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	SubcontractorOrderHeader.Date,
	|	SubcontractorOrderByProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderHeader.ReceiptDate
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	SubcontractorOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderInventory.Quantity
	|		ELSE SubcontractorOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity,
	|	SubcontractorOrderHeader.Ref AS ProductionDocument
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOM.Ref)
	|		LEFT JOIN BOM AS BOM
	|		ON (SubcontractorOrderInventory.Products = BOM.Products)
	|			AND (SubcontractorOrderInventory.Characteristic = BOM.Characteristic)
	|WHERE
	|	(NOT SubcontractorOrderHeader.BaseWIP
	|			OR NOT ISNULL(BOM.ManufacturedInProcess, FALSE))
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	MIN(SubcontractorOrderProducts.LineNumber) AS LineNumber,
	|	SubcontractorOrderHeader.ReceiptDate AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt) AS MovementType,
	|	SubcontractorOrderHeader.Ref AS Order,
	|	SubcontractorOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorOrderProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN SubcontractorOrderProducts.Quantity
	|			ELSE SubcontractorOrderProducts.Quantity * ISNULL(UOM.Factor, 1)
	|		END) AS Quantity
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderProducts.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	SubcontractorOrderHeader.ReceiptDate,
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	MIN(SubcontractorOrderByProducts.LineNumber),
	|	SubcontractorOrderHeader.ReceiptDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Receipt),
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderByProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorOrderByProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN SubcontractorOrderByProducts.Quantity
	|			ELSE SubcontractorOrderByProducts.Quantity * ISNULL(UOM.Factor, 1)
	|		END)
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.ByProducts AS SubcontractorOrderByProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderByProducts.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SubcontractorOrderHeader.ReceiptDate,
	|	SubcontractorOrderByProducts.Products,
	|	SubcontractorOrderHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	MIN(SubcontractorOrderInventory.LineNumber),
	|	SubcontractorOrderHeader.ReceiptDate,
	|	&Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderInventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SUM(CASE
	|			WHEN VALUETYPE(SubcontractorOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN SubcontractorOrderInventory.Quantity
	|			ELSE SubcontractorOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|		END)
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SubcontractorOrderInventory.Products,
	|	SubcontractorOrderHeader.ReceiptDate,
	|	SubcontractorOrderHeader.Ref
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrderHeader.Ref AS SubcontractorOrder,
	|	SubcontractorOrderInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SubcontractorOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SubcontractorOrderInventory.Quantity
	|		ELSE SubcontractorOrderInventory.Quantity * ISNULL(UOM.Factor, 1)
	|	END AS Quantity
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOM.Ref)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderHeader.Ref AS Quote,
	|	&Company AS Company,
	|	SubcontractorOrderHeader.Date AS Period,
	|	CAST(SubcontractorOrderHeader.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorOrderHeader.ExchangeRate * SubcontractorOrderHeader.ContractCurrencyMultiplicity / (SubcontractorOrderHeader.ContractCurrencyExchangeRate * SubcontractorOrderHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (SubcontractorOrderHeader.ExchangeRate * SubcontractorOrderHeader.ContractCurrencyMultiplicity / (SubcontractorOrderHeader.ContractCurrencyExchangeRate * SubcontractorOrderHeader.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	SubcontractorOrderHeader.Counterparty AS Counterparty
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON SubcontractorOrderHeader.Counterparty = Counterparties.Ref
	|WHERE
	|	Counterparties.DoOperationsByOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorOrderHeader.Company AS Company,
	|	SubcontractorOrderHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SubcontractorOrderHeader.BasisDocument AS WorkInProgress,
	|	SubcontractorOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SubcontractorOrderProducts.Quantity AS Quantity
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderProducts.Ref
	|WHERE
	|	SubcontractorOrderHeader.BaseWIP
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorOrderHeader.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorOrderHeader.SalesOrder AS SalesOrder,
	|	SubcontractorOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SubcontractorOrderHeader.Ref AS SupplySource,
	|	SubcontractorOrderProducts.Quantity * ISNULL(UOM.Factor, 1) AS Quantity
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderProducts.MeasurementUnit = UOM.Ref)
	|		LEFT JOIN Catalog.Products AS AllProducts
	|		ON (SubcontractorOrderProducts.Products = AllProducts.Ref)
	|WHERE
	|	SubcontractorOrderHeader.Ref = &Ref
	|	AND SubcontractorOrderHeader.SalesOrder <> UNDEFINED
	|	AND SubcontractorOrderHeader.SalesOrder <>  VALUE(Document.SalesOrder.EmptyRef)
	|	AND AllProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(SubcontractorOrderProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SubcontractorOrderHeader.Date AS Period,
	|	SubcontractorOrderHeader.Ref AS Ref,
	|	SubcontractorOrderHeader.Company AS Company,
	|	ManufacturingOperation.BasisDocument AS ProductionOrder,
	|	SubcontractorOrderProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SubcontractorOrderProducts.Specification AS Specification,
	|	SUM(SubcontractorOrderProducts.Quantity) AS Quantity
	|FROM
	|	SubcontractorOrderHeader AS SubcontractorOrderHeader
	|		INNER JOIN SubcontractorOrderProducts AS SubcontractorOrderProducts
	|		ON SubcontractorOrderHeader.Ref = SubcontractorOrderProducts.Ref
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON SubcontractorOrderHeader.BasisDocument = ManufacturingOperation.Ref
	|WHERE
	|	SubcontractorOrderHeader.OrderState = &Completed
	|
	|GROUP BY
	|	SubcontractorOrderHeader.Date,
	|	SubcontractorOrderHeader.Ref,
	|	SubcontractorOrderHeader.Company,
	|	ManufacturingOperation.BasisDocument,
	|	SubcontractorOrderProducts.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorOrderProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	SubcontractorOrderProducts.Specification";
	
	Query.SetParameter("Ref", DocumentRefSubcontractorOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("Completed", DriveReUse.GetOrderStatus("SubcontractorOrderIssuedStatuses", "Completed"));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorOrdersIssued", ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[6].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[7].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractComponents", ResultsArray[8].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", ResultsArray[9].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorPlanning", ResultsArray[10].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", ResultsArray[11].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgressStatement", ResultsArray[12].Unload());
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefSubcontractorOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsSubcontractorOrdersIssuedChange
		Or StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractComponentsChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractorPlanningChange
		Or StructureTemporaryTables.RegisterRecordsBackordersChange Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	RegisterRecordsInventoryDemandChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryDemandChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryDemandChange.MovementType AS MovementTypePresentation,
		|	RegisterRecordsInventoryDemandChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsInventoryDemandChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryDemandChange.Characteristic AS CharacteristicPresentation,
		|	InventoryDemandBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryDemandChange.QuantityChange, 0) + ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS BalanceInventoryDemand,
		|	ISNULL(InventoryDemandBalances.QuantityBalance, 0) AS QuantityBalanceInventoryDemand
		|FROM
		|	RegisterRecordsInventoryDemandChange AS RegisterRecordsInventoryDemandChange
		|		INNER JOIN AccumulationRegister.InventoryDemand.Balance(&ControlTime, ) AS InventoryDemandBalances
		|		ON RegisterRecordsInventoryDemandChange.Company = InventoryDemandBalances.Company
		|			AND RegisterRecordsInventoryDemandChange.MovementType = InventoryDemandBalances.MovementType
		|			AND RegisterRecordsInventoryDemandChange.SalesOrder = InventoryDemandBalances.SalesOrder
		|			AND RegisterRecordsInventoryDemandChange.Products = InventoryDemandBalances.Products
		|			AND RegisterRecordsInventoryDemandChange.Characteristic = InventoryDemandBalances.Characteristic
		|			AND (ISNULL(InventoryDemandBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractorOrdersIssued.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractComponents.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.Backorders.BalancesControlQueryText();
		
		// begin Drive.FullVersion
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractorPlanning.BalancesControlQueryText();
		// end Drive.FullVersion
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty() Then
			DocumentObjectSubcontractorOrder = DocumentRefSubcontractorOrder.GetObject()
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorOrdersIssuedRegisterErrors(
				DocumentRefSubcontractorOrder,
				QueryResultSelection,
				Cancel);
		ElsIf Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractComponentsRegisterErrors(
				DocumentRefSubcontractorOrder,
				QueryResultSelection,
				Cancel);
		// begin Drive.FullVersion
		ElsIf Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorPlanningRegisterErrors(
				DocumentRefSubcontractorOrder,
				DocumentRefSubcontractorOrder.BasisDocument,
				QueryResultSelection,
				Cancel);
		// end Drive.FullVersion
		ElsIf Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(
				DocumentRefSubcontractorOrder,
				QueryResultSelection,
				Cancel);
		ElsIf Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(
				DocumentRefSubcontractorOrder,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		DriveServer.CheckOrderedMinusBackorderedBalance(DocumentRefSubcontractorOrder, AdditionalProperties, Cancel);
		
	EndIf;
	
EndProcedure

Procedure CheckEnterBasedOnSubcontractorOrder(AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			Raise NStr("en = 'Please select a posted document.'; ru = 'Ввод на основании непроведенного документа запрещен.';pl = 'Wybierz zatwierdzony dokument.';es_ES = 'Por favor, seleccione un documento enviado.';es_CO = 'Por favor, seleccione un documento enviado.';tr = 'Lütfen, kaydedilmiş bir belge seçin.';it = 'Si prega di selezionare un documento pubblicato.';de = 'Bitte wählen Sie ein gebuchtes Dokument aus.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If AttributeValues.Closed Then
			Raise NStr("en = 'Please select an order that is not completed.'; ru = 'Ввод на основании закрытого заказа запрещен.';pl = 'Wybierz zamówienie, które nie zostało zakończone.';es_ES = 'Por favor, seleccione un orden que no esté finalizado.';es_CO = 'Por favor, seleccione un orden que no esté finalizado.';tr = 'Lütfen, tamamlanmamış bir sipariş seçin.';it = 'Si prega di selezionare un ordine che non è stato completato.';de = 'Bitte wählen Sie einen noch nicht abgeschlossenen Auftrag aus.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			Raise NStr("en = 'Cannot generate documents from orders with status ""Open"".'; ru = 'Не удалось сформировать документы из заказов с статусом ""Открыт"".';pl = 'Nie można wygenerować dokumentów z zamówień ze statusem ""Otwarte"".';es_ES = 'No se pueden generar documentos de las órdenes con estado ""Abierto"".';es_CO = 'No se pueden generar documentos de las órdenes con estado ""Abierto"".';tr = 'Durumu ""Açık"" olan siparişlerden belge oluşturulamaz.';it = 'Impossibile generare documenti da ordini con stato ""Aperto"".';de = 'Dokumente können nicht aus Aufträgen mit dem Status ""Öffnen"" generiert werden.'");
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Order") And AttributeValues.Property("Ref") Then
		
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	SubcontractorInvoiceReceived.Ref AS Ref
		|FROM
		|	Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceived
		|WHERE
		|	SubcontractorInvoiceReceived.BasisDocument = &Order
		|	AND SubcontractorInvoiceReceived.Ref <> &Ref
		|	AND NOT SubcontractorInvoiceReceived.DeletionMark";
		
		Query.SetParameter("Order", AttributeValues.Order);
		Query.SetParameter("Ref", AttributeValues.Ref);
		
		Result = Query.Execute();
		If Not Result.IsEmpty() Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The document ""Subcontractor invoice received"" based on %1 already exists.'; ru = 'Документ ""Полученный инвойс переработчика"" на основании %1 уже существует.';pl = 'Dokument ""Otrzymano fakturę podwykonawcy” na podstawie %1 już istnieje.';es_ES = 'El documento ""Factura del subcontratista recibida"" basado en el %1 ya existe.';es_CO = 'El documento ""Factura del subcontratista recibida"" basado en el %1 ya existe.';tr = '%1 baz alınan ""Alınan alt yüklenici faturası"" belgesi zaten mevcut.';it = 'Il documento ""Fattura subfornitura ricevuta"" basata su %1 esiste già.';de = 'Das Dokument ""Subunternehmerrechnung erhalten"" basierend auf %1 existiert bereits.'"),
				AttributeValues.Order);
		EndIf;
		
	EndIf;
	
EndProcedure

Function GetAvailableBOM(StuctureProduct, Date, StructureData, CharacteristicForBOM) Export
	
	Specification = Undefined;
	
	If StuctureProduct.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Assembly
		Or StuctureProduct.ProductsType = Enums.ProductsTypes.Work Then
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			Date, 
			CharacteristicForBOM,
			Enums.OperationTypesProductionOrder.Assembly);
	EndIf;
	If StuctureProduct.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Production
		Or StuctureProduct.ProductsType = Enums.ProductsTypes.Work
		And Not ValueIsFilled(Specification) Then
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			Date, 
			CharacteristicForBOM,
			Enums.OperationTypesProductionOrder.Production);
	EndIf;
	If StuctureProduct.ReplenishmentMethod = Enums.InventoryReplenishmentMethods.Processing
		And Not ValueIsFilled(Specification) Then
		
		ArrayMethods = New Array;
		ArrayMethods.Add(Enums.OperationTypesProductionOrder.Production);
		ArrayMethods.Add(Enums.OperationTypesProductionOrder.Assembly);
		
		Specification = Catalogs.BillsOfMaterials.GetAvailableBOM(StructureData.Products,
			Date, 
			CharacteristicForBOM,
			ArrayMethods);
	EndIf;
	
	Return Specification;
	
EndFunction
	
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

#EndRegion

#Region InfobaseUpdate

Procedure FillWorkInProgressStatementRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SubcontractorOrderIssued.Ref AS Ref
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON SubcontractorOrderIssued.BasisDocument = ManufacturingOperation.Ref
	|			AND (ManufacturingOperation.Posted)
	|		LEFT JOIN AccumulationRegister.WorkInProgressStatement AS WorkInProgressStatement
	|		ON SubcontractorOrderIssued.Ref = WorkInProgressStatement.Recorder
	|WHERE
	|	SubcontractorOrderIssued.Posted
	|	AND WorkInProgressStatement.Recorder IS NULL
	|	AND SubcontractorOrderIssued.OrderState = &Completed";
	
	Query.SetParameter("Completed", DriveReUse.GetOrderStatus("SubcontractorOrderIssuedStatuses", "Completed"));
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			
			AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(DocObject.Ref, DocObject.AdditionalProperties, False);
			If DocObject.AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
				
				RollbackTransaction();
				
				MessageText = NStr("en = 'Cannot post document ""%1"". 
					|The applicable Accounting transaction template is required.
					|Details: %2'; 
					|ru = 'Не удалось провести документ ""%1"". 
					|Требуется соответствующий шаблон бухгалтерских операций.
					|Подробнее: %2';
					|pl = 'Nie można zatwierdzić dokumentu ""%1"". 
					|Wymagany jest odpowiedni szablon transakcji księgowej.
					|Szczegóły: %2';
					|es_ES = 'No se ha podido contabilizar el documento ""%1"". 
					|Se requiere la plantilla de transacción contable aplicable. 
					|Detalles: %2';
					|es_CO = 'No se ha podido contabilizar el documento ""%1"". 
					|Se requiere la plantilla de transacción contable aplicable. 
					|Detalles: %2';
					|tr = '""%1"" belgesi kaydedilemiyor.
					|Uygulanabilir Muhasebe işlemi şablonu gerekli.
					|Ayrıntılar: %2';
					|it = 'Impossibile pubblicare il documento ""%1"". 
					|È richiesto il modello di transazione contabile applicabile.
					|Dettagli: %2';
					|de = 'Fehler beim Buchen des Dokuments ""%1"". 
					|Die verwendbare Buchhaltungstransaktionsvorlage ist erforderlich. 
					|Details: %2'", CommonClientServer.DefaultLanguageCode());
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					MessageText,
					DocObject.Ref,
					BriefErrorDescription(ErrorInfo()));
				
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.Documents.SubcontractorOrderIssued,
					,
					ErrorDescription);
					
				Continue;
				
			EndIf;
			
			Documents.SubcontractorOrderIssued.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			TableWorkInProgressStatement = DocObject.AdditionalProperties.TableForRegisterRecords.TableWorkInProgressStatement;
			
			DocObject.RegisterRecords.WorkInProgressStatement.Write = True;
			DocObject.RegisterRecords.WorkInProgressStatement.Load(TableWorkInProgressStatement);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.WorkInProgressStatement, True);
			
			DocObject.AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				DocObject.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.SubcontractorOrderIssued,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Internal

Function GetSubcontractorOrderStringStatuses() Export
	
	StatusesStructure = DriveServer.GetOrderStringStatuses();
	
	Return StatusesStructure;
	
EndFunction

#EndRegion

#EndIf
