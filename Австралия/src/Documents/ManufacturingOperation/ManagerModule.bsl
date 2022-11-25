#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, AdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	#Region InitializeDocumentDataQueryText
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN DocumentHeader.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	DocumentHeader.Products AS Products,
	|	DocumentHeader.Characteristic AS Characteristic,
	|	DocumentHeader.Specification AS Specification,
	|	DocumentHeader.Quantity AS Quantity,
	|	DocumentHeader.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN DocumentHeader.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentHeader.BasisDocument
	|	END AS SupplySource,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	DocumentHeader.CostObject AS CostObjectCorr,
	|	DocumentHeader.Status AS Status,
	|	DocumentHeader.ReleaseRequired AS ReleaseRequired,
	|	DocumentHeader.ProductionMethod AS ProductionMethod
	|INTO TT_DocumentHeaderAll
	|FROM
	|	Document.ManufacturingOperation AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.ReleaseRequired AS ReleaseRequired,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	DocumentHeader.Products AS Products,
	|	DocumentHeader.Characteristic AS Characteristic,
	|	DocumentHeader.Specification AS Specification,
	|	DocumentHeader.MeasurementUnit AS MeasurementUnit,
	|	DocumentHeader.Quantity AS Quantity,
	|	DocumentHeader.Status AS Status
	|INTO TT_DocumentHeaderRef
	|FROM
	|	TT_DocumentHeaderAll AS DocumentHeader
	|WHERE
	|	DocumentHeader.ProductionMethod = VALUE(Enum.ProductionMethods.InHouseProduction)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.PlanningPeriod AS PlanningPeriod,
	|	DocumentHeader.Cell AS Cell,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	DocumentHeader.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	DocumentHeader.DisposalsCell AS DisposalsCell,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	DocumentHeader.Products AS Products,
	|	DocumentHeader.Characteristic AS Characteristic,
	|	DocumentHeader.Specification AS Specification,
	|	DocumentHeader.Quantity AS Quantity,
	|	DocumentHeader.SupplySource AS SupplySource,
	|	DocumentHeader.CostObject AS CostObject,
	|	DocumentHeader.CostObjectCorr AS CostObjectCorr
	|INTO TT_DocumentHeader
	|FROM
	|	TT_DocumentHeaderAll AS DocumentHeader
	|WHERE
	|	(DocumentHeader.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|			OR DocumentHeader.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed))
	|	AND DocumentHeader.ProductionMethod = VALUE(Enum.ProductionMethods.InHouseProduction)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperation.Date AS Period,
	|	ManufacturingOperation.BasisDocument AS Reference,
	|	ManufacturingOperation.Products AS Products,
	|	ManufacturingOperation.Characteristic AS Characteristic,
	|	ManufacturingOperation.Specification AS Specification,
	|	SUM(CASE
	|			WHEN ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)
	|				THEN CASE
	|						WHEN VALUETYPE(ManufacturingOperation.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|							THEN ManufacturingOperation.Quantity
	|						ELSE ManufacturingOperation.Quantity * ManufacturingOperation.MeasurementUnit.Factor
	|					END
	|			ELSE 0
	|		END) AS TransferredToProduction,
	|	SUM(CASE
	|			WHEN ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|				THEN CASE
	|						WHEN VALUETYPE(ManufacturingOperation.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|							THEN ManufacturingOperation.Quantity
	|						ELSE ManufacturingOperation.Quantity * ManufacturingOperation.MeasurementUnit.Factor
	|					END
	|			ELSE 0
	|		END) AS Scheduled,
	|	SUM(CASE
	|			WHEN ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed)
	|				THEN CASE
	|						WHEN VALUETYPE(ManufacturingOperation.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|							THEN ManufacturingOperation.Quantity
	|						ELSE ManufacturingOperation.Quantity * ManufacturingOperation.MeasurementUnit.Factor
	|					END
	|			ELSE 0
	|		END) AS Produced
	|FROM
	|	TT_DocumentHeaderRef AS ManufacturingOperation
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|WHERE
	|	(ManufacturingOperation.ReleaseRequired
	|			OR NOT ProductionOrder.UseProductionPlanning)
	|
	|GROUP BY
	|	ManufacturingOperation.BasisDocument,
	|	ManufacturingOperation.Products,
	|	ManufacturingOperation.Characteristic,
	|	ManufacturingOperation.Specification,
	|	ManufacturingOperation.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	ProductionInventory.Ref AS Ref,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.PlanningPeriod AS PlanningPeriod,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.Cell AS Cell,
	|	TT_DocumentHeader.CostObject AS CostObject,
	|	TT_DocumentHeader.CostObjectCorr AS CostObjectCorr,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|						THEN ProductionInventory.InventoryReceivedGLAccount
	|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|						THEN CASE
	|								WHEN TT_DocumentHeader.Products IN (&ProductsFromFirstPhase)
	|									THEN ProductionInventory.InventoryReceivedGLAccount
	|								ELSE ProductionInventory.ConsumptionGLAccount
	|							END
	|					ELSE ProductionInventory.InventoryGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	CatalogInventoryOwnership.OwnershipType AS OwnershipType,
	|	CatalogInventoryOwnership.Counterparty AS OwnershipCounterparty,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	ProductionInventory.Ownership AS OwnershipCorr,
	|	CASE
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CustomerProvidedInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN VALUE(Enum.InventoryAccountTypes.ThirdPartyInventory)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.WorkInProgress) AS CorrInventoryAccountType,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.Specification AS SpecificationCorr,
	|	UNDEFINED AS IncomeAndExpenseItem,
	|	UNDEFINED AS CorrIncomeAndExpenseItem,
	|	ProductionInventory.Quantity * ISNULL(CatalogUOM.Factor, 1) AS Quantity,
	|	FALSE AS Distributed,
	|	ManufacturingOperationActivities.StartDate AS OperationStartDate,
	|	ProductionInventory.Reserve * ISNULL(CatalogUOM.Factor, 1) AS Reserve
	|INTO TemporaryTableAllInventory
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ProductionInventory
	|		ON TT_DocumentHeader.Ref = ProductionInventory.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ProductionInventory.MeasurementUnit = CatalogUOM.Ref)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (ProductionInventory.Ownership = CatalogInventoryOwnership.Ref)
	|		LEFT JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON (ProductionInventory.Ref = ManufacturingOperationActivities.Ref)
	|			AND (ProductionInventory.ActivityConnectionKey = ManufacturingOperationActivities.ConnectionKey)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (ProductionInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (ProductionInventory.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAllInventory.LineNumber AS LineNumber,
	|	TemporaryTableAllInventory.ConnectionKey AS ConnectionKey,
	|	TemporaryTableAllInventory.Ref AS Ref,
	|	ISNULL(TemporaryTableAllInventory.OperationStartDate, TemporaryTableAllInventory.Period) AS Period,
	|	TemporaryTableAllInventory.Company AS Company,
	|	TemporaryTableAllInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAllInventory.PlanningPeriod AS PlanningPeriod,
	|	TemporaryTableAllInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableAllInventory.Cell AS Cell,
	|	TemporaryTableAllInventory.CostObject AS CostObject,
	|	TemporaryTableAllInventory.CostObjectCorr AS CostObjectCorr,
	|	TemporaryTableAllInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	TemporaryTableAllInventory.CellInventory AS CellInventory,
	|	TemporaryTableAllInventory.InventoryGLAccount AS InventoryGLAccount,
	|	TemporaryTableAllInventory.ConsumptionGLAccount AS ConsumptionGLAccount,
	|	TemporaryTableAllInventory.Products AS Products,
	|	TemporaryTableAllInventory.ProductsCorr AS ProductsCorr,
	|	TemporaryTableAllInventory.Characteristic AS Characteristic,
	|	TemporaryTableAllInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TemporaryTableAllInventory.Batch AS Batch,
	|	TemporaryTableAllInventory.Ownership AS Ownership,
	|	TemporaryTableAllInventory.OwnershipType AS OwnershipType,
	|	TemporaryTableAllInventory.OwnershipCounterparty AS OwnershipCounterparty,
	|	TemporaryTableAllInventory.BatchCorr AS BatchCorr,
	|	TemporaryTableAllInventory.OwnershipCorr AS OwnershipCorr,
	|	TemporaryTableAllInventory.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableAllInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TemporaryTableAllInventory.Specification AS Specification,
	|	TemporaryTableAllInventory.SpecificationCorr AS SpecificationCorr,
	|	TemporaryTableAllInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TemporaryTableAllInventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TemporaryTableAllInventory.Quantity AS Quantity,
	|	TemporaryTableAllInventory.Distributed AS Distributed,
	|	TemporaryTableAllInventory.Reserve AS Reserve
	|INTO TemporaryTableInventory
	|FROM
	|	TemporaryTableAllInventory AS TemporaryTableAllInventory
	|WHERE
	|	(TemporaryTableAllInventory.OperationStartDate IS NULL
	|			OR TemporaryTableAllInventory.OperationStartDate <> DATETIME(1, 1, 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableActivities.FinishDate AS Date,
	|	TT_DocumentHeader.Ref AS Ref,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.PresentationCurrency AS PresentationCurrency,
	|	TT_DocumentHeader.PlanningPeriod AS PlanningPeriod,
	|	TT_DocumentHeader.StructuralUnit AS StructuralUnit,
	|	TT_DocumentHeader.CostObjectCorr AS CostObject,
	|	TableActivities.LineNumber AS LineNumber,
	|	TableActivities.Activity AS Activity,
	|	TableActivities.Quantity AS Quantity,
	|	TableActivities.StandardWorkload AS StandardWorkload,
	|	TableActivities.ActualWorkload AS ActualWorkload,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableActivities.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.WorkInProgress) AS InventoryAccountType
	|INTO TemporaryTableActivities
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Activities AS TableActivities
	|		ON TT_DocumentHeader.Ref = TableActivities.Ref
	|WHERE
	|	TableActivities.Done
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DocumentHeader.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TT_DocumentHeader.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN TableInventory.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	1 AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS TableInventory
	|		ON TT_DocumentHeader.Ref = TableInventory.Ref
	|		INNER JOIN Document.ManufacturingOperation.SerialNumbers AS TableSerialNumbers
	|		ON TT_DocumentHeader.Ref = TableSerialNumbers.Ref
	|			AND (TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey)
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	WorkInProgress.Period AS Period,
	|	WorkInProgress.RecordType AS RecordType,
	|	WorkInProgress.Company AS Company,
	|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
	|	WorkInProgress.StructuralUnit AS StructuralUnit,
	|	WorkInProgress.CostObject AS CostObject,
	|	WorkInProgress.Products AS Products,
	|	WorkInProgress.Characteristic AS Characteristic,
	|	WorkInProgress.Quantity AS Quantity,
	|	WorkInProgress.Amount AS Amount,
	|	WorkInProgress.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkcentersAvailability.Period AS Period,
	|	WorkcentersAvailability.Recorder AS Recorder,
	|	WorkcentersAvailability.LineNumber AS LineNumber,
	|	WorkcentersAvailability.Active AS Active,
	|	WorkcentersAvailability.WorkcenterType AS WorkcenterType,
	|	WorkcentersAvailability.Workcenter AS Workcenter,
	|	WorkcentersAvailability.Used AS Used,
	|	WorkcentersAvailability.UsedFromReservedTime AS UsedFromReservedTime,
	|	WorkcentersAvailability.Available AS Available,
	|	WorkcentersAvailability.AvailableOfReservedTime AS AvailableOfReservedTime,
	|	WorkcentersAvailability.ManualCorrection AS ManualCorrection
	|FROM
	|	AccumulationRegister.WorkcentersAvailability AS WorkcentersAvailability
	|		INNER JOIN TT_DocumentHeaderRef AS ManufacturingOperation
	|		ON WorkcentersAvailability.Recorder = ManufacturingOperation.Ref
	|WHERE
	|	ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Open)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	ManufacturingOperation.Date AS Period,
	|	ManufacturingOperation.Ref AS WorkInProgress,
	|	ManufacturingOperationActivities.Activity AS Operation,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	SUM(ManufacturingOperationActivities.Quantity) AS Quantity,
	|	SUM(ManufacturingOperationActivities.Quantity) AS QuantityProduced,
	|	ManufacturingOperationActivities.FinishDate AS FinishDate,
	|	ManufacturingOperationActivities.Done AS Done
	|INTO TableProductionAccomplishment
	|FROM
	|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		INNER JOIN TT_DocumentHeaderRef AS ManufacturingOperation
	|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
	|WHERE
	|	&UseProductionTask
	|
	|GROUP BY
	|	ManufacturingOperation.Date,
	|	ManufacturingOperation.Ref,
	|	ManufacturingOperationActivities.Activity,
	|	ManufacturingOperationActivities.ConnectionKey,
	|	ManufacturingOperationActivities.FinishDate,
	|	ManufacturingOperationActivities.Done
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductionAccomplishment.RecordType AS RecordType,
	|	TableProductionAccomplishment.Period AS Period,
	|	TableProductionAccomplishment.WorkInProgress AS WorkInProgress,
	|	TableProductionAccomplishment.Operation AS Operation,
	|	TableProductionAccomplishment.Quantity AS Quantity,
	|	TableProductionAccomplishment.QuantityProduced AS QuantityProduced,
	|	TableProductionAccomplishment.ConnectionKey AS ConnectionKey,
	|	TableProductionAccomplishment.Done AS Done
	|FROM
	|	TableProductionAccomplishment AS TableProductionAccomplishment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ManufacturingOperationInventory.LineNumber) AS LineNumber,
	|	BEGINOFPERIOD(ProductionOrder.Start, DAY) AS Period,
	|	&Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	ProductionOrder.SalesOrder AS Order,
	|	ManufacturingOperationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ManufacturingOperationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(ManufacturingOperationInventory.Quantity * ISNULL(CatalogUOM.Factor, 1)) AS Quantity,
	|	ManufacturingOperation.Ref AS ProductionDocument
	|FROM
	|	TT_DocumentHeaderRef AS ManufacturingOperation
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON ManufacturingOperation.Ref = ManufacturingOperationInventory.Ref
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON ManufacturingOperation.BasisDocument = ProductionOrder.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON (ManufacturingOperationInventory.MeasurementUnit = CatalogUOM.Ref)
	|WHERE
	|	VALUETYPE(ProductionOrder.BasisDocument) <> TYPE(Document.SubcontractorOrderReceived)
	|
	|GROUP BY
	|	ProductionOrder.SalesOrder,
	|	BEGINOFPERIOD(ProductionOrder.Start, DAY),
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ManufacturingOperationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	ManufacturingOperation.Ref,
	|	ManufacturingOperationInventory.Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TT_DocumentHeader.Date AS Period,
	|	TT_DocumentHeader.Ref AS Ref,
	|	TT_DocumentHeader.Company AS Company,
	|	TT_DocumentHeader.BasisDocument AS ProductionOrder,
	|	TT_DocumentHeader.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TT_DocumentHeader.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	TT_DocumentHeader.Specification AS Specification,
	|	TT_DocumentHeader.Quantity AS Quantity
	|FROM
	|	TT_DocumentHeader AS TT_DocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON TT_DocumentHeader.Ref = ManufacturingOperationActivities.Ref
	|			AND (ManufacturingOperationActivities.Output)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	1,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TT_DocumentHeaderAll.Date,
	|	TT_DocumentHeaderAll.Ref,
	|	TT_DocumentHeaderAll.Company,
	|	TT_DocumentHeaderAll.BasisDocument,
	|	TT_DocumentHeaderAll.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TT_DocumentHeaderAll.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	TT_DocumentHeaderAll.Specification,
	|	TT_DocumentHeaderAll.Quantity
	|FROM
	|	TT_DocumentHeaderAll AS TT_DocumentHeaderAll
	|WHERE
	|	TT_DocumentHeaderAll.ProductionMethod = VALUE(Enum.ProductionMethods.Subcontracting)
	|	AND (TT_DocumentHeaderAll.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|			OR TT_DocumentHeaderAll.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryCostLayer.Period AS Period,
	|	InventoryCostLayer.Recorder AS Recorder,
	|	InventoryCostLayer.LineNumber AS LineNumber,
	|	InventoryCostLayer.Active AS Active,
	|	InventoryCostLayer.RecordType AS RecordType,
	|	InventoryCostLayer.Company AS Company,
	|	InventoryCostLayer.PresentationCurrency AS PresentationCurrency,
	|	InventoryCostLayer.Products AS Products,
	|	InventoryCostLayer.Characteristic AS Characteristic,
	|	InventoryCostLayer.Batch AS Batch,
	|	InventoryCostLayer.Ownership AS Ownership,
	|	InventoryCostLayer.GLAccount AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.CostObject AS CostObject,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	InventoryCostLayer.CorrGLAccount AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.CorrCostObject AS CorrCostObject,
	|	InventoryCostLayer.CorrProducts AS CorrProducts,
	|	InventoryCostLayer.CorrCharacteristic AS CorrCharacteristic,
	|	InventoryCostLayer.CorrBatch AS CorrBatch,
	|	InventoryCostLayer.CorrOwnership AS CorrOwnership,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	TT_DocumentHeaderRef AS DocumentHeaderAllStatuses
	|		INNER JOIN AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|		ON DocumentHeaderAllStatuses.Ref = InventoryCostLayer.Recorder
	|WHERE
	|	&UseFIFO
	|	AND NOT InventoryCostLayer.SourceRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.Ref AS WorkInProgress,
	|	DocumentHeader.Products AS Products,
	|	DocumentHeader.Characteristic AS Characteristic,
	|	DocumentHeader.Quantity AS Quantity
	|FROM
	|	TT_DocumentHeaderAll AS DocumentHeader
	|WHERE
	|	DocumentHeader.ProductionMethod = VALUE(Enum.ProductionMethods.Subcontracting)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAllInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableAllInventory.Period AS Period,
	|	TemporaryTableAllInventory.Company AS Company,
	|	TemporaryTableAllInventory.Ref AS ProductionDocument,
	|	TemporaryTableAllInventory.Products AS Products,
	|	TemporaryTableAllInventory.Characteristic AS Characteristic,
	|	TemporaryTableAllInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableAllInventory AS TemporaryTableAllInventory
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableInventory.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Ref,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory";

	#EndRegion
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Company", AdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", AdditionalProperties.ForPosting.PresentationCurrency);
	
	AccountingPolicy = AdditionalProperties.AccountingPolicy;
	Query.SetParameter("UseCharacteristics", AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers", AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseProductionTask", Constants.UseProductionTask.Get());
	Query.SetParameter("ProductsFromFirstPhase", GetProductsFromTheFirstPhaseOfManufacturingOperations(DocumentRef));
	Query.SetParameter("UseFIFO", AdditionalProperties.AccountingPolicy.UseFIFO);
	Query.SetParameter("UseDefaultTypeOfAccounting", AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production", NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	DriveServer.GenerateTransactionsTable(DocumentRef, AdditionalProperties);
	AdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgress", ResultsArray[8].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableWorkcentersAvailability", ResultsArray[9].Unload());
	
	GenerateTableInventoryInWarehouses(DocumentRef, AdditionalProperties);
	GenerateTableInventory(DocumentRef, AdditionalProperties);
	
	GenerateTableStockReceivedFromThirdParties(DocumentRef, AdditionalProperties);
	GenerateTableGoodsConsumedToDeclare(DocumentRef, AdditionalProperties);
	GenerateTableInventoryDemand(DocumentRef, AdditionalProperties);
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[14].Unload());
	DataInitializationByActivities(DocumentRef, AdditionalProperties);
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableManufacturingProcessSupply",	ResultsArray[3].Unload());
	
	TableSerialNumbers = ResultsArray[7].Unload();
	AdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", TableSerialNumbers);
	If AccountingPolicy.SerialNumbersBalance Then
		AdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", TableSerialNumbers);
	Else
		AdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableProductionAccomplishment", ResultsArray[11].Unload());
	GenerateTableProductionAccomplishment(DocumentRef, AdditionalProperties);
	GenerateTableReservedProducts(DocumentRef, AdditionalProperties);
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", ResultsArray[12].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableWorkInProgressStatement", ResultsArray[13].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorPlanning", ResultsArray[15].Unload());
	AdditionalProperties.TableForRegisterRecords.Insert("TableProductionComponents", ResultsArray[16].Unload());
	
	GenerateTableAccountingEntriesData(DocumentRef, AdditionalProperties);
	
	// Accounting
	If AdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, AdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsWorkInProgressChange
		Or StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange
		Or StructureTemporaryTables.RegisterRecordsWorkInProgressStatementChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractorPlanningChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Ownership) AS OwnershipPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership, Cell) IN
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Ownership = InventoryInWarehousesOfBalance.Ownership
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.InventoryAccountType) AS InventoryAccountTypePresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Ownership) AS OwnershipPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountType,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.Ownership AS Ownership,
		|						RegisterRecordsInventoryChange.CostObject AS CostObject
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						UNDEFINED AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Ownership AS OwnershipPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.Ownership = SerialNumbersBalance.Ownership
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		DriveClientServer.AddDelimeter(Query.Text);
		Query.Text = Query.Text + AccumulationRegisters.WorkInProgress.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.SubcontractorPlanning.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty()Then
			
			DocumentObjectProduction = DocumentRef.GetObject();
			InventoryStructuralUnitInHeader = (DocumentObjectProduction.InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader);
			
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			If InventoryStructuralUnitInHeader Then
				DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
			Else
				DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocumentObjectProduction, QueryResultSelection, Cancel);
			EndIf;
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			If InventoryStructuralUnitInHeader Then
				DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
			Else
				DriveServer.ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocumentObjectProduction, QueryResultSelection, Cancel);
			EndIf;
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectProduction, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			If InventoryStructuralUnitInHeader Then
				DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
			Else
				DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrorsAsList(DocumentObjectProduction, QueryResultSelection, Cancel);
			EndIf;
		EndIf;
		
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToWorkInProgressRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorPlanningRegisterErrors(DocumentObjectProduction,
				DocumentObjectProduction.Ref,
				QueryResultSelection, Cancel);
		EndIf;
			
		// Negative balance of need for reserved products.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
	
	EndIf;
	
EndProcedure

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringByWorkInProgress(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") And Not AttributeValues.Posted Then
		ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
		Raise ErrorText;
	EndIf;
	
	If AttributeValues.Property("ForSubcontractorOrderIssued") And AttributeValues.ForSubcontractorOrderIssued Then
		
		If AttributeValues.Property("ReleaseRequired") And AttributeValues.ReleaseRequired = True Then
			
			ErrorText = NStr("en = 'Couldn''t perform this action for %1.
				|This action is applicable only to Work-in-progress whose Product is a component required for a finished product.
				|In this Work-in-progress, Product is a finished product.'; 
				|ru = 'Не удалось выполнить это действие для %1.
				|Это действие применимо только к документу ""Незавершенное производство"", номенклатура которого является компонентом, необходим для готовой продукции.
				|В этом ""Незавершенном производстве"" номенклатура является готовой продукцией.';
				|pl = 'Nie udało się wykonać tego działania dla %1.
				|To działanie dotyczy tylko pracy w toku, Produkt której jest potrzebny dla gotowego produktu.
				|W tej pracy w toku, Produkt jest produktem gotowym do sprzedaży.';
				|es_ES = 'No se ha podido realizar esta acción para %1.
				|Esta acción sólo es aplicable a los Trabajos en curso cuyo Producto es un componente necesario para un producto terminado.
				|En este Trabajo en curso, el Producto es un producto terminado.';
				|es_CO = 'No se ha podido realizar esta acción para %1.
				|Esta acción sólo es aplicable a los Trabajos en curso cuyo Producto es un componente necesario para un producto terminado.
				|En este Trabajo en curso, el Producto es un producto terminado.';
				|tr = '%1 için bu işlem gerçekleştirilemedi.
				|Bu işlem sadece, ürünü nihai ürün için gerekli bir malzeme olan İşlem bitişine uygulanabilir.
				|Bu İşlem bitişinde ürün bir nihai üründür.';
				|it = 'Impossibile eseguire questa azione per %1.
				|Questa azione è applicabile soltanto al Lavoro in corso il cui Articolo è una componente richiesta per il prodotto finito.
				|In questo Lavoro in corso, Articolo è un prodotto finito.';
				|de = 'Diese Aktion konnte für %1 nicht ausgeführt werden.
				| Diese Aktion gilt nur für eine in Bearbeitungsprozedur, deren Produkt eine Komponente ist, die für ein fertiges Produkt erforderlich ist.
				| Bearbeitungsprozedur bezieht sich auf ein fertiges Produkt.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
			Raise ErrorText;
			
		ElsIf AttributeValues.Property("Status") And AttributeValues.Status <> Enums.ManufacturingOperationStatuses.Open Then
			
			ErrorText = NStr("en = 'Couldn''t perform this action for %1. Its lifecycle status is %2. To continue, change the status to Open.'; ru = 'Не удалось выполнить это действие для %1. Статус документа – %2.Чтобы продолжить, измените статус на ""Открыто"".';pl = 'Nie udało się wykonać tego działania dla %1. Ma status %2. Aby kontynuować, zmień status na Otwarte.';es_ES = 'No se ha podido realizar esta acción para %1. Su estado del ciclo de vida es %2. Para continuar, cambie el estado a Abierto.';es_CO = 'No se ha podido realizar esta acción para %1. Su estado del ciclo de vida es %2. Para continuar, cambie el estado a Abierto.';tr = '%1 için bu işlem gerçekleştirilemedi. Yaşam döngüsü durumu %2. Devam etmek için durumunu Açık olarak değiştirin.';it = 'Impossibile eseguire questa azione per %1. Lo stato del ciclo di vita è %2. Per continuare, modificare lo stato in Aperto.';de = 'Fehler beim Ausführen dieser Aktion für %1. Der Status %2. Um fortzufahren, ändern Sie den Status zu Abgeschlossen.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData, AttributeValues.Status);
			Raise ErrorText;
			
		ElsIf AttributeValues.Property("ProductionMethod") And AttributeValues.ProductionMethod <> Enums.ProductionMethods.Subcontracting Then
		
			ErrorText = NStr("en = 'Cannot generate ""Subcontractor order issued"" for %1. Its Production method is In-house production. Select a ""Work-in-progress"" whose Production method is Subcontracting. Then try again.'; ru = 'Не удалось сформировать ""Выданный заказ на переработку"" для %1, поскольку его способ производства – ""Собственное производство"". Выберите документ ""Незавершенное производство"" со способом производства ""Собственное производство"" и повторите попытку.';pl = 'Nie można wygenerować ""Wydanego zamówienia wykonawcy"" dla %1. Jego sposób produkcji to Produkcja wewnętrzna. Wybierz ""Praca w toku"", której sposób produkcji to Podwykonawstwo. Następnie spróbuj ponownie.';es_ES = 'No se puede generar la ""Orden emitida del subcontratista"" para %1. Su método de Producción es Producción propia. Seleccione ""Trabajo en progreso"" cuyo método de Producción sea Subcontratación. Inténtelo de nuevo.';es_CO = 'No se puede generar la ""Orden emitida del subcontratista"" para %1. Su método de Producción es Producción propia. Seleccione ""Trabajo en progreso"" cuyo método de Producción sea Subcontratación. Inténtelo de nuevo.';tr = '%1 için ""Düzenlenen alt yüklenici siparişi"" oluşturulamıyor. Üretim yöntemi şirket içi üretim. Üretim yöntemi Taşeronluk olan bir ""İşlem bitişi"" seçip tekrar deneyin.';it = 'Impossibile generare ""Ordine di subfornitura emesso"" per %1. Il suo metodo di produzione è In-house. Selezionare un ""Lavoro in corso"" il cui Metodo di produzione sia Subfornitura, poi riprovare.';de = 'Fehler beim Generieren von ""Subunternehmerauftrag ausgestellt"" für %1. Dessen Produktionsmethode ist Hausinterne Produktion. Wählen Sie eine ""Arbeit in Bearbeitung"" mit der Produktionsmethode Subunternehmerbestellung aus. Dann versuchen Sie erneut.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
			Raise ErrorText;
		EndIf;
		
	ElsIf AttributeValues.Property("ForOrderGeneration") And AttributeValues.ForOrderGeneration Then
		
		If AttributeValues.Property("Status") And AttributeValues.Status = Enums.ManufacturingOperationStatuses.Open Then
			
			ErrorText = NStr("en = 'Couldn''t perform this action for %1. Its lifecycle status is %2. To continue, change the status to In progress.'; ru = 'Не удалось выполнить это действие для %1. Статус документа – %2.Чтобы продолжить, измените статус на ""В работе"".';pl = 'Nie udało się wykonać tego działania dla %1. Ma status %2. Aby kontynuować, zmień status na W toku.';es_ES = 'No se ha podido realizar esta acción para %1. Su estado del ciclo de vida es %22. Para continuar, cambie el estado a En progreso.';es_CO = 'No se ha podido realizar esta acción para %1. Su estado del ciclo de vida es %22. Para continuar, cambie el estado a En progreso.';tr = '%1 için bu işlem gerçekleştirilemedi. Yaşam döngüsü durumu %2. Devam etmek için durumu İşlemde olarak değiştirin.';it = 'Impossibile eseguire questa azione per %1. Lo stato del ciclo di vita è %2. Per continuare, cambiare lo stato a In corso.';de = 'Fehler beim Ausführen dieser Aktion für %1. Der Status des Lebenszyklus ist %2. Um fortzufahren, ändern Sie den Status zu In Bearbeitung.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData, AttributeValues.Status);
			Raise ErrorText;
			
		EndIf;
		
	ElsIf AttributeValues.Property("Status") Then
		
		If AttributeValues.Status <> Enums.ManufacturingOperationStatuses.Completed Then
			ErrorText = NStr("en = 'Couldn''t perform this action for %1. Its status is %2. 
				|To continue, change the status to Completed.'; 
				|ru = 'Не удалось выполнить это действие для %1. Статус – %2.
				|Чтобы продолжить, измените статус на ""Завершено"".';
				|pl = 'Nie udało się wykonać tego działania dla %1. Ma status %2. 
				|Aby kontynuować, zmień status na Zakończono.';
				|es_ES = 'No se ha podido realizar esta acción para %1. Su estado es %2. 
				|Para continuar, cambie el estado a Finalizado.';
				|es_CO = 'No se ha podido realizar esta acción para %1. Su estado es %2. 
				|Para continuar, cambie el estado a Finalizado.';
				|tr = '%1 için bu işlem gerçekleştirilemedi. Durumu %2. 
				|Devam etmek için durumunu Tamamlandı olarak değiştirin.';
				|it = 'Impossibile eseguire questa azione per %1. Il suo stato è %2.
				| Per continuare, modificare lo stato in Completato.';
				|de = 'Fehler beim Ausführen dieser Aktion für %1. Der Status %2. 
				|Um fortzufahren, ändern Sie den Status für Abgeschlossen.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData, AttributeValues.Status);
			Raise ErrorText;
		EndIf;
		
	EndIf;
	
	If AttributeValues.Property("Output") And Not AttributeValues.Output Then
		
		ErrorText = NStr("en = '%1 doesn''t have operations with output mark. It cannot be a base document.'; ru = 'В документе %1 нет операций с пометкой ""выпуск"". Он не может быть документом-основанием.';pl = '%1 nie ma operacji, zaznaczonych jako produkcja. Nie może być dokumentem źródłowym.';es_ES = '%1 no tiene operaciones con marca de salida. No puede ser un documento base.';es_CO = '%1 no tiene operaciones con marca de salida. No puede ser un documento base.';tr = '%1 belgesinde çıktı işaretli işlem yok. Temel belge olamaz.';it = '%1 non ha operazioni con il contrassegno di output. Non può essere un documento di base.';de = '%1 hat keine Operationen mit Markierung von Produktionsmenge. Das kann kein Basisdokument sein.'");
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
		Raise ErrorText;
		
	EndIf;
	
EndProcedure

Function ParentWIP(ChildWIP) Export
	
	ParentWIP = Undefined;
	
	If ValueIsFilled(ChildWIP) Then
		
		ChildWIPAttributes = Common.ObjectAttributesValues(ChildWIP, "BasisDocument, BOMHierarchyItem");
		
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	ManufacturingOperation.Ref AS Ref
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.BasisDocument = &BasisDocument
		|	AND ManufacturingOperation.BOMHierarchyItem = &BOMHierarchyItem
		|	AND NOT ManufacturingOperation.DeletionMark";
		
		Query.SetParameter("BasisDocument", ChildWIPAttributes.BasisDocument);
		Query.SetParameter("BOMHierarchyItem", ChildWIPAttributes.BOMHierarchyItem.Parent);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		If SelectionDetailRecords.Next() Then
			ParentWIP = SelectionDetailRecords.Ref;
		EndIf;
		
	EndIf;
	
	Return ParentWIP;
	
EndFunction

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("OwnershipType") Then 
		OwnershipType = StructureData.OwnershipType;
	Else
		OwnershipType = Common.ObjectAttributeValue(StructureData.Ownership, "OwnershipType");
	EndIf;
	
	If OwnershipType = Enums.InventoryOwnershipTypes.CounterpartysInventory 
		Or OwnershipType = Enums.InventoryOwnershipTypes.CustomerProvidedInventory Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	Else
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	EndIf;
	
	GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	OrderAttributes = Common.ObjectAttributesValues(
		DocObject.BasisDocument, 
		"BasisDocument, BasisDocument.Counterparty, BasisDocument.Contract");
	
	If TypeOf(OrderAttributes.BasisDocument) = Type("DocumentRef.SubcontractorOrderReceived") Then
		
		Parameters = New Structure;
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OrderAttributes.BasisDocumentCounterparty);
		Parameters.Insert("Contract", OrderAttributes.BasisDocumentContract);
		ParametersSet.Add(Parameters);
		
	Else
		
		Parameters = New Structure;
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Disposals");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
	
	EndIf;
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	#Region BatchCheckFillingParameters_Inventory
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Inventory");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	If DocObject.InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader Then
		WarehouseData.Insert("Warehouse", DocObject.InventoryStructuralUnit);
	Else
		WarehouseData.Insert("Warehouse", "InventoryStructuralUnit");
	EndIf;
	WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	#Region BatchCheckFillingParameters_Disposals
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Disposals");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.DisposalsStructuralUnit);
	WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region PrintInterface

// Generate objects printing forms.
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
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
EndProcedure

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure UpdateProductionAccomplishmentRecords() Export
	
	If Constants.UseProductionTask.Get() Then
	
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref,
		|	ManufacturingOperationActivities.Activity AS Activity,
		|	ManufacturingOperationActivities.Quantity AS Quantity,
		|	ManufacturingOperation.Date AS Date
		|FROM
		|	Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
		|		LEFT JOIN Document.ManufacturingOperation AS ManufacturingOperation
		|		ON ManufacturingOperationActivities.Ref = ManufacturingOperation.Ref
		|WHERE
		|	ManufacturingOperation.Posted
		|	AND ManufacturingOperation.Status <> VALUE(Enum.ManufacturingOperationStatuses.Completed)
		|TOTALS
		|	MAX(Date)
		|BY
		|	Ref";
		
		QueryResult = Query.Execute();
		
		SelectionManufacturingOperation = QueryResult.Select(QueryResultIteration.ByGroups);
		
		While SelectionManufacturingOperation.Next() Do
			
			ProductionAccomplishment = AccumulationRegisters.ProductionAccomplishment.CreateRecordSet();
			ProductionAccomplishment.Filter.Recorder.Set(SelectionManufacturingOperation.Ref);
			
			SelectionDetailRecords = SelectionManufacturingOperation.Select();
		
			While SelectionDetailRecords.Next() Do
				
				Record = ProductionAccomplishment.Add();
				Record.Operation = SelectionDetailRecords.Activity;
				Record.Quantity = SelectionDetailRecords.Quantity;
				Record.QuantityProduced = SelectionDetailRecords.Quantity;
				Record.Period = SelectionManufacturingOperation.Date;
				Record.RecordType = AccumulationRecordType.Expense;
				Record.WorkInProgress = SelectionManufacturingOperation.Ref;
				
			EndDo;
			
			Try
				
				InfobaseUpdate.WriteRecordSet(ProductionAccomplishment);
				
			Except
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save register ""Production accomplishment"". Details: %1'; ru = 'Не удалось записать регистр ""Выполнение производства"". Подробнее: %1';pl = 'Nie można zapisać rejestru ""Realizacja produkcji"". Szczegóły: %1';es_ES = 'Ha ocurrido un error al guardar el registro ""Cumplimiento de la producción"". Detalles: %1';es_CO = 'Ha ocurrido un error al guardar el registro ""Cumplimiento de la producción"". Detalles: %1';tr = '""Üretim tamamlanması"" kaydı yapılamıyor. Ayrıntılar: %1';it = 'Impossibile salvare il registro ""Completamento produzione"". Dettagli: %1';de = 'Fehler beim Speichern des Registers ""Produktionsausführung"". Details: %1'", CommonClientServer.DefaultLanguageCode()),
					BriefErrorDescription(ErrorInfo()));
					
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.AccumulationRegisters.ProductionAccomplishment,
					,
					ErrorDescription);
					
			EndTry;
			
		EndDo;
		
	Else
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	ManufacturingOperation.Ref AS Ref
		|FROM
		|	Document.ManufacturingOperation AS ManufacturingOperation
		|WHERE
		|	ManufacturingOperation.Posted";
		
		QueryResult = Query.Execute();
		
		SelectionManufacturingOperation = QueryResult.Select();
		
		While SelectionManufacturingOperation.Next() Do
			
			ProductionAccomplishment = AccumulationRegisters.ProductionAccomplishment.CreateRecordSet();
			ProductionAccomplishment.Filter.Recorder.Set(SelectionManufacturingOperation.Ref);
			
			Try
				
				InfobaseUpdate.WriteRecordSet(ProductionAccomplishment);
				
			Except
				
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save register production accomplishment: %1'; ru = 'Не удалось записать регистр ""Выполнение производства"": %1';pl = 'Ne można zapisać rejestru Realizacja produkcji: %1';es_ES = 'Ha ocurrido un error al guardar el registro del cumplimiento de la producción: %1';es_CO = 'Ha ocurrido un error al guardar el registro del cumplimiento de la producción: %1';tr = 'Üretim tamamlanması kaydı yapılamıyor: %1';it = 'Impossibile salvare il registro completamento produzione: %1';de = 'Fehler beim Speichern des Registers ""Produktionsausführung"": %1'", CommonClientServer.DefaultLanguageCode()),
					BriefErrorDescription(ErrorInfo()));
					
				WriteLogEvent(
					InfobaseUpdate.EventLogEvent(),
					EventLogLevel.Error,
					Metadata.AccumulationRegisters.ProductionAccomplishment,
					,
					ErrorDescription);
					
			EndTry;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillInventoryStructuralUnitPosition() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.InventoryStructuralUnitPosition = VALUE(Enum.AttributeStationing.EmptyRef)";
	
	SelectionWIP = Query.Execute().Select();
	
	InHeader = Enums.AttributeStationing.InHeader;
	
	While SelectionWIP.Next() Do
		
		ManufacturingOperation = SelectionWIP.Ref;
		ManufacturingOperationObject = ManufacturingOperation.GetObject();
		ManufacturingOperationObject.InventoryStructuralUnitPosition = InHeader;
		
		For Each Row In ManufacturingOperationObject.Inventory Do
			Row.InventoryStructuralUnit = ManufacturingOperationObject.InventoryStructuralUnit;
			Row.CellInventory = ManufacturingOperationObject.CellInventory;
		EndDo;
		
		Try
			
			InfobaseUpdate.WriteObject(ManufacturingOperationObject);
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save %1. Details: %2'; ru = 'Не удалось записать %1. Подробнее: %2';pl = 'Nie udało się zapisać %1. Szczegóły: %2';es_ES = 'No se ha podido guardar %1. Detalles: %2';es_CO = 'No se ha podido guardar %1. Detalles: %2';tr = '%1 saklanamadı. Ayrıntılar: %2';it = 'Impossibile salvare %1. Dettagli: %2';de = 'Fehler beim Speichern von ""%1"". Details: %2'", CommonClientServer.DefaultLanguageCode()),
				ManufacturingOperation,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.ManufacturingOperation,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

Procedure FillWorkInProgressStatementRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ManufacturingOperation.Ref AS Ref
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|		LEFT JOIN AccumulationRegister.WorkInProgressStatement AS WorkInProgressStatement
	|		ON ManufacturingOperation.Ref = WorkInProgressStatement.Recorder
	|WHERE
	|	ManufacturingOperation.Posted
	|	AND WorkInProgressStatement.Recorder IS NULL
	|	AND ManufacturingOperation.ProductionMethod = VALUE(Enum.ProductionMethods.Subcontracting)
	|	AND (ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.InProcess)
	|			OR ManufacturingOperation.Status = VALUE(Enum.ManufacturingOperationStatuses.Completed))";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			Documents.ManufacturingOperation.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
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
				Metadata.Documents.ManufacturingOperation,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

Procedure GenerateTableInventoryInWarehouses(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.CellInventory AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.CellInventory,
	|	TableInventory.Characteristic,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Company
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute();
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", Result.Unload());
	
EndProcedure

Procedure GenerateTableInventory(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.ConsumptionGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Ownership AS OwnershipCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.ConsumptionGLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	CAST(&InventoryTransfer AS STRING(50)) AS Content,
	|	CAST(&InventoryTransfer AS STRING(50)) AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	FALSE AS ProductionExpenses,
	|	FALSE AS FixedCost,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.CostObjectCorr AS CostObjectCorr,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem,
	|	TableInventory.ConsumptionGLAccount,
	|	TableInventory.BatchCorr,
	|	TableInventory.CostObject,
	|	TableInventory.CostObjectCorr,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Ownership,
	|	TableInventory.ConsumptionGLAccount,
	|	TableInventory.InventoryGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	VALUE(Catalog.ManufacturingActivities.EmptyRef),
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	NULL,
	|	FALSE
	|WHERE
	|	FALSE
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	
	TableInventory = Query.Execute().Unload();
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.InventoryAccountType AS InventoryAccountType
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.InventoryAccountType";
	
	QueryResult = Query.Execute();
	
	IsWeightedAverage = AdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	UseDefaultTypeOfAccounting = AdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;

	If IsWeightedAverage Then
	
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;
		
		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		TableInventoryBalances = TableInventoryBalances(TableInventory, AdditionalProperties);
		TableInventoryBalances.Indexes.Add(
			"Company, Period, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
		
		TemporaryTableInventory = TableInventory.CopyColumns();
		
		TableAccountingJournalEntries = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		TableWorkInProgress = AdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
		
		UseDefaultTypeOfAccounting = AdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
		
		For n = 0 To TableInventory.Count() - 1 Do
			
			RowTableInventory = TableInventory[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company",				RowTableInventory.Company);
			StructureForSearch.Insert("Period",					RowTableInventory.Period);
			StructureForSearch.Insert("PresentationCurrency",	RowTableInventory.PresentationCurrency);
			StructureForSearch.Insert("StructuralUnit",			RowTableInventory.StructuralUnit);
			StructureForSearch.Insert("InventoryAccountType",	RowTableInventory.InventoryAccountType);
			StructureForSearch.Insert("Products",				RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic",			RowTableInventory.Characteristic);
			StructureForSearch.Insert("Batch",					RowTableInventory.Batch);
			StructureForSearch.Insert("Ownership",				RowTableInventory.Ownership);
			StructureForSearch.Insert("CostObject",				RowTableInventory.CostObject);
			
			QuantityRequired = RowTableInventory.Quantity;
			
			If QuantityRequired > 0 Then
				
				BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
				
				QuantityBalance = 0;
				AmountBalance = 0;
				
				If BalanceRowsArray.Count() > 0 Then
					QuantityBalance = BalanceRowsArray[0].QuantityBalance;
					AmountBalance = BalanceRowsArray[0].AmountBalance;
				EndIf;
				
				If QuantityBalance > QuantityRequired Then
					
					Amount = Round(AmountBalance * QuantityRequired / QuantityBalance , 2, 1);
					
					BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequired;
					BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - Amount;
					
				Else
					
					Amount = AmountBalance;
					
					If QuantityBalance <> 0 Then
						BalanceRowsArray[0].QuantityBalance = 0;
						BalanceRowsArray[0].AmountBalance = 0;
					EndIf;
					
				EndIf;
				
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				TableRowExpense.Amount = Amount;
				TableRowExpense.Quantity = QuantityRequired;
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.CostObject = Undefined;
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,
					"Period, Company, PresentationCurrency, Products, Characteristic, Batch, Ownership, ContentOfAccountingRecord");
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Amount = Amount;
				TableRowReceipt.Quantity = QuantityRequired;
				TableRowReceipt.CostObject = RowTableInventory.CostObjectCorr;
				
				TableWIPRowReceipt = TableWorkInProgress.Add();
				FillPropertyValues(TableWIPRowReceipt, TableRowReceipt);
				
				If UseDefaultTypeOfAccounting And Amount <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
					RowTableAccountingJournalEntries.Amount = Amount;
				EndIf;
				
			EndIf;
		
		EndDo;
		
	Else
		
		TemporaryTableInventory = TableInventory.CopyColumns();
		
		TableAccountingJournalEntries = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		TableWorkInProgress = AdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
		
		For n = 0 To TableInventory.Count() - 1 Do
			
			RowTableInventory = TableInventory[n];
			
			QuantityRequired = RowTableInventory.Quantity;
			
			If QuantityRequired > 0 Then
				
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.CostObject = Undefined;
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory,
					"Period, Company, PresentationCurrency, Products, Characteristic, Batch, Ownership, ContentOfAccountingRecord");
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Amount = Amount;
				TableRowReceipt.Quantity = QuantityRequired;
				TableRowReceipt.CostObject = RowTableInventory.CostObjectCorr;
				
				TableWIPRowReceipt = TableWorkInProgress.Add();
				FillPropertyValues(TableWIPRowReceipt, TableRowReceipt);
				
				If UseDefaultTypeOfAccounting And Amount <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				EndIf;
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventory", TemporaryTableInventory);
	
	AddOfflineRecords(DocumentRef, AdditionalProperties);
	
EndProcedure

Function TableInventoryBalances(TableInventory, AdditionalProperties)
	
	DifPeriods = TableInventory.Copy();
	DifPeriods.GroupBy("Period");
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	QueryMainText =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.Period AS Period,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	ReplaceInventoryBalances AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.Period,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject,
	|	InventoryBalances.InventoryAccountType";
	
	QuerySecondaryText = "(";
	
	QueryTextTemplate =
	"SELECT
	|	TabInventoryBalances.Company AS Company,
	|	&Period0 AS Period,
	|	TabInventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	TabInventoryBalances.StructuralUnit AS StructuralUnit,
	|	TabInventoryBalances.Products AS Products,
	|	TabInventoryBalances.Characteristic AS Characteristic,
	|	TabInventoryBalances.Batch AS Batch,
	|	TabInventoryBalances.Ownership AS Ownership,
	|	TabInventoryBalances.CostObject AS CostObject,
	|	TabInventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	TabInventoryBalances.QuantityBalance AS QuantityBalance,
	|	TabInventoryBalances.AmountBalance AS AmountBalance
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&PointInTime0,
	|			(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|				(SELECT
	|					TableInventory.Company,
	|					TableInventory.PresentationCurrency,
	|					TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|					TableInventory.InventoryAccountType,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch,
	|					TableInventory.Ownership,
	|					TableInventory.CostObject
	|				FROM
	|					TemporaryTableInventory AS TableInventory)) AS TabInventoryBalances";
	
	For Index = 0 To DifPeriods.Count() - 1 Do
		
		PeriodName = "Period" + Format(Index, "NG=0");
		PointInTimeName = "PointInTime" + Format(Index, "NG=0");
		
		QuerySecondaryText = QuerySecondaryText
			+ StrReplace(QueryTextTemplate, "Period0", PeriodName);
		
		QuerySecondaryText = StrReplace(QuerySecondaryText, "PointInTime0", PointInTimeName)
			+ DriveClientServer.GetQueryUnion();
		
		Query.SetParameter(PeriodName, DifPeriods[Index].Period);
		Query.SetParameter(PointInTimeName, New Boundary(DifPeriods[Index].Period, BoundaryType.Including));
		
	EndDo;
	
	QuerySecondaryText = QuerySecondaryText +
	"SELECT
	|	DocumentRegisterRecordsInventory.Company AS Company,
	|	DocumentRegisterRecordsInventory.Period AS Period,
	|	DocumentRegisterRecordsInventory.PresentationCurrency AS PresentationCurrency,
	|	DocumentRegisterRecordsInventory.StructuralUnit AS StructuralUnit,
	|	DocumentRegisterRecordsInventory.Products AS Products,
	|	DocumentRegisterRecordsInventory.Characteristic AS Characteristic,
	|	DocumentRegisterRecordsInventory.Batch AS Batch,
	|	DocumentRegisterRecordsInventory.Ownership AS Ownership,
	|	DocumentRegisterRecordsInventory.CostObject AS CostObject,
	|	DocumentRegisterRecordsInventory.InventoryAccountType AS InventoryAccountType,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN DocumentRegisterRecordsInventory.Quantity
	|		ELSE -DocumentRegisterRecordsInventory.Quantity
	|	END AS QuantityBalance,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN DocumentRegisterRecordsInventory.Amount
	|		ELSE -DocumentRegisterRecordsInventory.Amount
	|	END AS AmountBalance
	|FROM
	|	AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|WHERE
	|	DocumentRegisterRecordsInventory.Recorder = &Ref
	|	AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod";
	
	QuerySecondaryText = QuerySecondaryText + ")";
	
	Query.Text = StrReplace(QueryMainText, "ReplaceInventoryBalances", QuerySecondaryText);
	
	Query.SetParameter("Ref", AdditionalProperties.ForPosting.Ref);
	PostingPointInTime = AdditionalProperties.ForPosting.PointInTime;
	Query.SetParameter("ControlPeriod", PostingPointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	
	Return TableInventoryBalances;
	
EndFunction

Procedure GenerateTableStockReceivedFromThirdParties(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.OwnershipCounterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.OwnershipCounterparty
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", Result.Unload());
	
EndProcedure

Procedure GenerateTableGoodsConsumedToDeclare(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.OwnershipCounterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.OwnershipCounterparty
	|
	|ORDER BY
	|	LineNumber";
	
	Result = Query.Execute();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", Result.Unload());
	
EndProcedure

Procedure GenerateTableInventoryDemand(DocumentRef, AdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref", DocumentRef);
	Query.Text = 
	"SELECT
	|	ManufacturingOperation.Ref AS Ref,
	|	ManufacturingOperation.Date AS Date,
	|	ManufacturingOperation.Company AS Company,
	|	ManufacturingOperation.Status AS Status,
	|	ManufacturingOperation.BasisDocument AS BasisDocument,
	|	ManufacturingOperation.Specification AS Specification,
	|	ManufacturingOperation.ReleaseRequired AS ReleaseRequired
	|INTO DocumentHeader
	|FROM
	|	Document.ManufacturingOperation AS ManufacturingOperation
	|WHERE
	|	ManufacturingOperation.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ManufacturingOperationInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	ManufacturingOperationInventory.Products AS Products,
	|	ManufacturingOperationInventory.Characteristic AS Characteristic,
	|	SUM(ManufacturingOperationInventory.Quantity) AS Quantity,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Company AS Company,
	|	ProductionOrder.SalesOrder AS SalesOrder,
	|	DocumentHeader.Specification AS Specification,
	|	DocumentHeader.ReleaseRequired AS ReleaseRequired,
	|	DocumentHeader.Ref AS ProductionDocument,
	|	ProductionOrder.UseProductionPlanning AS UseProductionPlanning
	|INTO TemporaryTableInventoryDemand
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.ManufacturingOperation.Inventory AS ManufacturingOperationInventory
	|		ON DocumentHeader.Ref = ManufacturingOperationInventory.Ref
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON DocumentHeader.BasisDocument = ProductionOrder.Ref
	|WHERE
	|	VALUETYPE(ProductionOrder.BasisDocument) <> TYPE(Document.SubcontractorOrderReceived)
	|
	|GROUP BY
	|	ManufacturingOperationInventory.Characteristic,
	|	DocumentHeader.Company,
	|	DocumentHeader.ReleaseRequired,
	|	DocumentHeader.Date,
	|	ManufacturingOperationInventory.Products,
	|	ProductionOrder.SalesOrder,
	|	DocumentHeader.Specification,
	|	ManufacturingOperationInventory.LineNumber,
	|	ProductionOrder.UseProductionPlanning,
	|	DocumentHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BillsOfMaterialsContent.Ref AS Ref,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	MAX(BillsOfMaterialsContent.ManufacturedInProcess) AS ManufacturedInProcess
	|INTO BOM
	|FROM
	|	TemporaryTableInventoryDemand AS TemporaryTableInventoryDemand
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TemporaryTableInventoryDemand.Specification = BillsOfMaterialsContent.Ref
	|			AND TemporaryTableInventoryDemand.Products = BillsOfMaterialsContent.Products
	|			AND TemporaryTableInventoryDemand.Characteristic = BillsOfMaterialsContent.Characteristic
	|
	|GROUP BY
	|	BillsOfMaterialsContent.Products,
	|	BillsOfMaterialsContent.Characteristic,
	|	BillsOfMaterialsContent.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTableInventoryDemand.LineNumber) AS LineNumber,
	|	TemporaryTableInventoryDemand.RecordType AS RecordType,
	|	TemporaryTableInventoryDemand.MovementType AS MovementType,
	|	TemporaryTableInventoryDemand.Products AS Products,
	|	TemporaryTableInventoryDemand.Characteristic AS Characteristic,
	|	SUM(TemporaryTableInventoryDemand.Quantity) AS Quantity,
	|	TemporaryTableInventoryDemand.Period AS Period,
	|	TemporaryTableInventoryDemand.Company AS Company,
	|	TemporaryTableInventoryDemand.SalesOrder AS SalesOrder,
	|	TemporaryTableInventoryDemand.ReleaseRequired AS ReleaseRequired,
	|	TemporaryTableInventoryDemand.ProductionDocument AS ProductionDocument,
	|	ISNULL(BOM.ManufacturedInProcess, FALSE) AS Produce
	|FROM
	|	TemporaryTableInventoryDemand AS TemporaryTableInventoryDemand
	|		LEFT JOIN BOM AS BOM
	|		ON TemporaryTableInventoryDemand.Specification = BOM.Ref
	|			AND TemporaryTableInventoryDemand.Products = BOM.Products
	|			AND TemporaryTableInventoryDemand.Characteristic = BOM.Characteristic
	|
	|GROUP BY
	|	TemporaryTableInventoryDemand.Period,
	|	TemporaryTableInventoryDemand.Products,
	|	TemporaryTableInventoryDemand.Company,
	|	TemporaryTableInventoryDemand.RecordType,
	|	TemporaryTableInventoryDemand.Characteristic,
	|	TemporaryTableInventoryDemand.MovementType,
	|	TemporaryTableInventoryDemand.SalesOrder,
	|	ISNULL(BOM.ManufacturedInProcess, FALSE),
	|	TemporaryTableInventoryDemand.ReleaseRequired,
	|	TemporaryTableInventoryDemand.ProductionDocument";
	
	Result = Query.Execute();
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", Result.Unload());
	
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventoryDemand.SalesOrder AS SalesOrder,
	|	TableInventoryDemand.ProductionDocument AS ProductionDocument,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventoryDemand AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance,
	|	InventoryDemandBalances.ProductionDocument AS ProductionDocument
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic, ProductionDocument) IN
	|					(SELECT
	|						TemporaryTableInventoryDemand.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						TemporaryTableInventoryDemand.SalesOrder,
	|						TemporaryTableInventoryDemand.Products AS Products,
	|						TemporaryTableInventoryDemand.Characteristic AS Characteristic,
	|						TemporaryTableInventoryDemand.ProductionDocument AS ProductionDocument
	|					FROM
	|						TemporaryTableInventoryDemand AS TemporaryTableInventoryDemand)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.ProductionDocument,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.ProductionDocument,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE 0
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic,
	|	InventoryDemandBalances.ProductionDocument";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(AdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", AdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic,ProductionDocument");
	
	TemporaryTableInventoryDemand = AdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In AdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		If Not RowTablesForInventory.Produce Then
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
			If DocumentRef.Status <> Enums.ManufacturingOperationStatuses.Open Then
				
				StructureForSearch = New Structure;
				StructureForSearch.Insert("Company", RowTablesForInventory.Company);
				StructureForSearch.Insert("SalesOrder", RowTablesForInventory.SalesOrder);
				StructureForSearch.Insert("Products", RowTablesForInventory.Products);
				StructureForSearch.Insert("Characteristic", RowTablesForInventory.Characteristic);
				StructureForSearch.Insert("ProductionDocument", RowTablesForInventory.ProductionDocument);
				
				BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
				If BalanceRowsArray.Count() > 0 And BalanceRowsArray[0].QuantityBalance > 0 Then
					
					If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
						RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
					EndIf;
					
					TableRowExpense = TemporaryTableInventoryDemand.Add();
					FillPropertyValues(TableRowExpense, RowTablesForInventory);
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
				EndIf;
				
			EndIf;
			
		EndIf;
	
	EndDo;
	
	AdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

Procedure GenerateTableProductionAccomplishment(DocumentRef, AdditionalProperties)
	
	StructureData = Common.ObjectAttributesValues(DocumentRef, "Status, ProductionMethod");
	
	If StructureData.ProductionMethod <> Enums.ProductionMethods.Subcontracting Then
		
		Query = New Query;
		Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text = 
		"SELECT
		|	ProductionAccomplishmentTurnovers.Operation AS Operation,
		|	ProductionAccomplishmentTurnovers.ConnectionKey AS ConnectionKey,
		|	ProductionAccomplishmentTurnovers.QuantityReceipt - ProductionAccomplishmentTurnovers.QuantityExpense AS Quantity,
		|	ProductionAccomplishmentTurnovers.QuantityProducedReceipt - ProductionAccomplishmentTurnovers.QuantityProducedExpense AS QuantityProduced,
		|	DATETIME(1, 1, 1) AS Period
		|INTO TT_Movements
		|FROM
		|	AccumulationRegister.ProductionAccomplishment.Turnovers(
		|			,
		|			,
		|			Recorder,
		|			WorkInProgress = &DocumentRef
		|				AND (Operation, ConnectionKey) IN
		|					(SELECT
		|						Table.Operation,
		|						Table.ConnectionKey
		|					FROM
		|						TableProductionAccomplishment AS Table
		|					WHERE
		|						Table.Done)) AS ProductionAccomplishmentTurnovers
		|WHERE
		|	ProductionAccomplishmentTurnovers.Recorder <> &DocumentRef
		|
		|UNION ALL
		|
		|SELECT
		|	TableProductionAccomplishment.Operation,
		|	TableProductionAccomplishment.ConnectionKey,
		|	CASE
		|		WHEN TableProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Expense)
		|			THEN -TableProductionAccomplishment.Quantity
		|		ELSE TableProductionAccomplishment.Quantity
		|	END,
		|	CASE
		|		WHEN TableProductionAccomplishment.RecordType = VALUE(AccumulationRecordType.Expense)
		|			THEN -TableProductionAccomplishment.QuantityProduced
		|		ELSE TableProductionAccomplishment.QuantityProduced
		|	END,
		|	TableProductionAccomplishment.FinishDate
		|FROM
		|	TableProductionAccomplishment AS TableProductionAccomplishment
		|WHERE
		|	TableProductionAccomplishment.Done
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	MAX(TT_Movements.Period) AS Period,
		|	&DocumentRef AS WorkInProgress,
		|	TT_Movements.Operation AS Operation,
		|	TT_Movements.ConnectionKey AS ConnectionKey,
		|	SUM(-TT_Movements.Quantity) AS Quantity,
		|	SUM(-TT_Movements.QuantityProduced) AS QuantityProduced
		|FROM
		|	TT_Movements AS TT_Movements
		|
		|GROUP BY
		|	TT_Movements.Operation,
		|	TT_Movements.ConnectionKey";
		
		Query.SetParameter("CurrentDate", CurrentSessionDate());
		Query.SetParameter("DocumentRef", DocumentRef);
		
		QueryResult = Query.Execute().Unload();
		
		CommonClientServer.SupplementTable(QueryResult, AdditionalProperties.TableForRegisterRecords.TableProductionAccomplishment);
		
	EndIf;
	
EndProcedure

Procedure DataInitializationByActivities(DocumentRef, AdditionalProperties)

	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TemporaryTableActivities.Activity AS Activity,
	|	CatalogActivities.CostPool AS CostPool
	|INTO TT_Activities
	|FROM
	|	TemporaryTableActivities AS TemporaryTableActivities
	|		LEFT JOIN Catalog.ManufacturingActivities AS CatalogActivities
	|		ON TemporaryTableActivities.Activity = CatalogActivities.Ref";
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text + InformationRegisters.PredeterminedOverheadRates.GetActivitiesOverheadRatesQueryText();
	
	DriveClientServer.AddDelimeter(Query.Text);
	Query.Text = Query.Text +
	"SELECT
	|	TemporaryTableActivities.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableActivities.Company AS Company,
	|	TemporaryTableActivities.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableActivities.PlanningPeriod AS PlanningPeriod,
	|	TemporaryTableActivities.StructuralUnit AS StructuralUnit,
	|	TemporaryTableActivities.CostObject AS CostObject,
	|	TemporaryTableActivities.LineNumber AS LineNumber,
	|	TemporaryTableActivities.Activity AS Activity,
	|	TemporaryTableActivities.GLAccount AS GLAccount,
	|	TemporaryTableActivities.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableActivities.GLAccount AS AccountDr,
	|	OverheadRates.OverheadsGLAccount AS AccountCr,
	|	OverheadRates.ExpenseItem AS ExpenseItem,
	|	OverheadRates.BusinessUnit AS StructuralUnitCorr,
	|	TemporaryTableActivities.Quantity AS Quantity,
	|	CAST(TemporaryTableActivities.ActualWorkload * ISNULL(OverheadRates.Rate, 0) AS NUMBER(15, 2)) AS Amount
	|INTO TT_ActivitiesWithStandardCost
	|FROM
	|	TemporaryTableActivities AS TemporaryTableActivities
	|		LEFT JOIN TT_ActivitiesOverheadRates AS OverheadRates
	|		ON TemporaryTableActivities.Activity = OverheadRates.Activity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesWithStandardCost.Activity AS Activity,
	|	TT_ActivitiesWithStandardCost.GLAccount AS GLAccount,
	|	COUNT(DISTINCT TT_ActivitiesWithStandardCost.AccountCr) + COUNT(DISTINCT TT_ActivitiesWithStandardCost.ExpenseItem) + COUNT(DISTINCT TT_ActivitiesWithStandardCost.StructuralUnitCorr) - 2 AS Count
	|INTO TT_InventoryActivitiesCount
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|
	|GROUP BY
	|	TT_ActivitiesWithStandardCost.Activity,
	|	TT_ActivitiesWithStandardCost.GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesWithStandardCost.Period AS Period,
	|	TT_ActivitiesWithStandardCost.RecordType AS RecordType,
	|	TT_ActivitiesWithStandardCost.Company AS Company,
	|	TT_ActivitiesWithStandardCost.PresentationCurrency AS PresentationCurrency,
	|	TT_ActivitiesWithStandardCost.StructuralUnit AS StructuralUnit,
	|	TT_ActivitiesWithStandardCost.GLAccount AS GLAccount,
	|	TT_ActivitiesWithStandardCost.LineNumber AS LineNumber,
	|	TT_ActivitiesWithStandardCost.InventoryAccountType AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS CorrInventoryAccountType,
	|	TT_ActivitiesWithStandardCost.Activity AS Products,
	|	&OwnInventory AS Ownership,
	|	TT_ActivitiesWithStandardCost.Quantity AS Quantity,
	|	TT_ActivitiesWithStandardCost.Amount AS Amount,
	|	TT_ActivitiesWithStandardCost.AccountCr AS CorrGLAccount,
	|	TT_ActivitiesWithStandardCost.ExpenseItem AS CorrIncomeAndExpenseItem,
	|	TT_ActivitiesWithStandardCost.StructuralUnitCorr AS StructuralUnitCorr,
	|	TT_ActivitiesWithStandardCost.CostObject AS CostObject,
	|	TRUE AS FixedCost,
	|	&Content AS ContentOfAccountingRecord
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|		INNER JOIN TT_InventoryActivitiesCount AS TT_InventoryActivitiesCount
	|		ON TT_ActivitiesWithStandardCost.Activity = TT_InventoryActivitiesCount.Activity
	|			AND TT_ActivitiesWithStandardCost.GLAccount = TT_InventoryActivitiesCount.GLAccount
	|WHERE
	|	TT_InventoryActivitiesCount.Count = 1
	|
	|UNION ALL
	|
	|SELECT
	|	TT_ActivitiesWithStandardCost.Period,
	|	TT_ActivitiesWithStandardCost.RecordType,
	|	TT_ActivitiesWithStandardCost.Company,
	|	TT_ActivitiesWithStandardCost.PresentationCurrency,
	|	TT_ActivitiesWithStandardCost.StructuralUnit,
	|	TT_ActivitiesWithStandardCost.GLAccount,
	|	TT_ActivitiesWithStandardCost.LineNumber,
	|	TT_ActivitiesWithStandardCost.InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads),
	|	TT_ActivitiesWithStandardCost.Activity,
	|	&OwnInventory,
	|	0,
	|	TT_ActivitiesWithStandardCost.Amount,
	|	TT_ActivitiesWithStandardCost.AccountCr,
	|	TT_ActivitiesWithStandardCost.ExpenseItem,
	|	TT_ActivitiesWithStandardCost.StructuralUnitCorr,
	|	TT_ActivitiesWithStandardCost.CostObject,
	|	TRUE,
	|	&Content
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|		INNER JOIN TT_InventoryActivitiesCount AS TT_InventoryActivitiesCount
	|		ON TT_ActivitiesWithStandardCost.Activity = TT_InventoryActivitiesCount.Activity
	|			AND TT_ActivitiesWithStandardCost.GLAccount = TT_InventoryActivitiesCount.GLAccount
	|WHERE
	|	TT_ActivitiesWithStandardCost.Amount <> 0
	|	AND TT_InventoryActivitiesCount.Count <> 1
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	TT_ActivitiesWithStandardCost.Period,
	|	TT_ActivitiesWithStandardCost.RecordType,
	|	TT_ActivitiesWithStandardCost.Company,
	|	TT_ActivitiesWithStandardCost.PresentationCurrency,
	|	TT_ActivitiesWithStandardCost.StructuralUnit,
	|	TT_ActivitiesWithStandardCost.GLAccount,
	|	TT_ActivitiesWithStandardCost.LineNumber,
	|	TT_ActivitiesWithStandardCost.InventoryAccountType,
	|	NULL,
	|	TT_ActivitiesWithStandardCost.Activity,
	|	&OwnInventory,
	|	TT_ActivitiesWithStandardCost.Quantity,
	|	0,
	|	NULL,
	|	NULL,
	|	NULL,
	|	TT_ActivitiesWithStandardCost.CostObject,
	|	TRUE,
	|	&Content
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|		INNER JOIN TT_InventoryActivitiesCount AS TT_InventoryActivitiesCount
	|		ON TT_ActivitiesWithStandardCost.Activity = TT_InventoryActivitiesCount.Activity
	|			AND TT_ActivitiesWithStandardCost.GLAccount = TT_InventoryActivitiesCount.GLAccount
	|WHERE
	|	TT_InventoryActivitiesCount.Count <> 1
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesWithStandardCost.Period AS Period,
	|	TT_ActivitiesWithStandardCost.RecordType AS RecordType,
	|	TT_ActivitiesWithStandardCost.Company AS Company,
	|	TT_ActivitiesWithStandardCost.PlanningPeriod AS PlanningPeriod,
	|	TT_ActivitiesWithStandardCost.AccountDr AS AccountDr,
	|	TT_ActivitiesWithStandardCost.AccountCr AS AccountCr,
	|	TT_ActivitiesWithStandardCost.ExpenseItem AS ExpenseItem,
	|	SUM(TT_ActivitiesWithStandardCost.Amount) AS Amount,
	|	&Content AS Content
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|WHERE
	|	TT_ActivitiesWithStandardCost.Amount <> 0
	|
	|GROUP BY
	|	TT_ActivitiesWithStandardCost.AccountCr,
	|	TT_ActivitiesWithStandardCost.ExpenseItem,
	|	TT_ActivitiesWithStandardCost.Period,
	|	TT_ActivitiesWithStandardCost.RecordType,
	|	TT_ActivitiesWithStandardCost.AccountDr,
	|	TT_ActivitiesWithStandardCost.PlanningPeriod,
	|	TT_ActivitiesWithStandardCost.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_ActivitiesWithStandardCost.Period AS Period,
	|	TT_ActivitiesWithStandardCost.RecordType AS RecordType,
	|	TT_ActivitiesWithStandardCost.Company AS Company,
	|	TT_ActivitiesWithStandardCost.PresentationCurrency AS PresentationCurrency,
	|	TT_ActivitiesWithStandardCost.StructuralUnit AS StructuralUnit,
	|	TT_ActivitiesWithStandardCost.CostObject AS CostObject,
	|	TT_ActivitiesWithStandardCost.Activity AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	SUM(TT_ActivitiesWithStandardCost.Quantity) AS Quantity,
	|	SUM(TT_ActivitiesWithStandardCost.Amount) AS Amount
	|FROM
	|	TT_ActivitiesWithStandardCost AS TT_ActivitiesWithStandardCost
	|
	|GROUP BY
	|	TT_ActivitiesWithStandardCost.Period,
	|	TT_ActivitiesWithStandardCost.RecordType,
	|	TT_ActivitiesWithStandardCost.Company,
	|	TT_ActivitiesWithStandardCost.PresentationCurrency,
	|	TT_ActivitiesWithStandardCost.StructuralUnit,
	|	TT_ActivitiesWithStandardCost.CostObject,
	|	TT_ActivitiesWithStandardCost.Activity";
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRef, "Date, Company, StructuralUnit");
	Query.SetParameter("Date", DocumentAttributes.Date);
	Query.SetParameter("Company", DocumentAttributes.Company);
	Query.SetParameter("PresentationCurrency", AdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("BusinessUnit", DocumentAttributes.StructuralUnit);
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("Content", NStr("en = 'Operation cost'; ru = 'Стоимость эксплуатации';pl = 'Koszt własny operacji';es_ES = 'Coste de la operación';es_CO = 'Coste de la operación';tr = 'İşlem maliyeti';it = 'Costo operazione';de = 'Betriebskosten'", MainLanguageCode));
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	ResultsArray = Query.ExecuteBatchWithIntermediateData();
	
	ResultsCount = ResultsArray.Count();
	
	UseFIFO = AdditionalProperties.AccountingPolicy.UseFIFO;
	
	InventoryTable = ResultsArray[ResultsCount - 3].Unload();
	InventoryRecordsTable = AdditionalProperties.TableForRegisterRecords.TableInventory;
	InventoryCostLayerRecordsTable = AdditionalProperties.TableForRegisterRecords.TableInventoryCostLayer;
	For Each InventoryRow In InventoryTable Do
		FillPropertyValues(InventoryRecordsTable.Add(), InventoryRow);
		If UseFIFO Then
			InventoryCostLayerRecord = InventoryCostLayerRecordsTable.Add();
			FillPropertyValues(InventoryCostLayerRecord, InventoryRow);
			InventoryCostLayerRecord.CostLayer = DocumentRef;
			InventoryCostLayerRecord.SourceRecord = True;
		EndIf;
	EndDo;
	CollapseInventoryCostLayerRecordsTable(InventoryCostLayerRecordsTable);
	
	If AdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		EntriesTable = ResultsArray[ResultsCount - 2].Unload();
		EntriesRecordsTable = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		For Each EntriesRow In EntriesTable Do
			FillPropertyValues(EntriesRecordsTable.Add(), EntriesRow);
		EndDo;
	EndIf;
	
	WIPTable = ResultsArray[ResultsCount - 1].Unload();
	WIPRecordsTable = AdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	For Each WIPRow In WIPTable Do
		FillPropertyValues(WIPRecordsTable.Add(), WIPRow);
	EndDo;
	
EndProcedure

Function GetProductsFromTheFirstPhaseOfManufacturingOperations(DocumentRef) 
	
	If Not GetFunctionalOption("CanProvideSubcontractingServices") Then
		Return New Array;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	ProductionOrderProducts.Products AS Products,
	|	BillsOfMaterialsContent.Products AS Component,
	|	BillsOfMaterialsContent.Specification AS Specification
	|INTO TT_Level1
	|FROM
	|	Document.ProductionOrder.Products AS ProductionOrderProducts
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON ProductionOrderProducts.Specification = BillsOfMaterialsContent.Ref
	|WHERE
	|	ProductionOrderProducts.Ref = &ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.Component AS Products,
	|	ISNULL(BillsOfMaterialsContent.Products, VALUE(Catalog.Products.EmptyRef)) AS Component,
	|	ISNULL(BillsOfMaterialsContent.Specification, VALUE(Catalog.BillsOfMaterials.EmptyRef)) AS Specification
	|INTO TT_Level2
	|FROM
	|	TT_Level1 AS TT_Level1
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TT_Level1.Specification = BillsOfMaterialsContent.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level2.Component AS Products,
	|	ISNULL(BillsOfMaterialsContent.Products, VALUE(Catalog.Products.EmptyRef)) AS Component,
	|	ISNULL(BillsOfMaterialsContent.Specification, VALUE(Catalog.BillsOfMaterials.EmptyRef)) AS Specification
	|INTO TT_Level3
	|FROM
	|	TT_Level2 AS TT_Level2
	|		INNER JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TT_Level2.Specification = BillsOfMaterialsContent.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Level1.Products AS Products
	|FROM
	|	TT_Level1 AS TT_Level1
	|
	|GROUP BY
	|	TT_Level1.Products
	|
	|HAVING
	|	MIN(TT_Level1.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)) = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level2.Products
	|FROM
	|	TT_Level2 AS TT_Level2
	|
	|GROUP BY
	|	TT_Level2.Products
	|
	|HAVING
	|	MIN(TT_Level2.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)) = TRUE
	|
	|UNION ALL
	|
	|SELECT
	|	TT_Level3.Products
	|FROM
	|	TT_Level3 AS TT_Level3
	|
	|GROUP BY
	|	TT_Level3.Products
	|
	|HAVING
	|	MIN(TT_Level3.Specification = VALUE(Catalog.BillsOfMaterials.EmptyRef)) = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_Level1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_Level2
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_Level3";
	
	Query.SetParameter("ProductionOrder", DocumentRef.BasisDocument);
	
	ResultTable = Query.ExecuteBatch()[3].Unload();
	
	Return ResultTable.UnloadColumn("Products");
	
EndFunction

Procedure AddOfflineRecords(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Recorder AS Recorder,
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Active AS Active,
	|	Inventory.RecordType AS RecordType,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.GLAccount AS GLAccount,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.Amount AS Amount,
	|	Inventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	Inventory.CorrGLAccount AS CorrGLAccount,
	|	Inventory.ProductsCorr AS ProductsCorr,
	|	Inventory.CharacteristicCorr AS CharacteristicCorr,
	|	Inventory.BatchCorr AS BatchCorr,
	|	Inventory.OwnershipCorr AS OwnershipCorr,
	|	Inventory.CustomerCorrOrder AS CustomerCorrOrder,
	|	Inventory.Specification AS Specification,
	|	Inventory.SpecificationCorr AS SpecificationCorr,
	|	Inventory.CorrSalesOrder AS CorrSalesOrder,
	|	Inventory.SourceDocument AS SourceDocument,
	|	Inventory.Department AS Department,
	|	Inventory.Responsible AS Responsible,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.FixedCost AS FixedCost,
	|	Inventory.ProductionExpenses AS ProductionExpenses,
	|	Inventory.Return AS Return,
	|	Inventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	Inventory.RetailTransferEarningAccounting AS RetailTransferEarningAccounting,
	|	Inventory.OfflineRecord AS OfflineRecord,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Counterparty AS Counterparty,
	|	Inventory.Currency AS Currency,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.CostObject AS CostObject,
	|	Inventory.CostObjectCorr AS CostObjectCorr,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	Inventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	Inventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND Inventory.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Status AS Status,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Recorder = &Recorder
	|	AND AccountingJournalEntries.OfflineRecord
	|	AND &UseDefaultTypeOfAccounting
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkInProgress.Period AS Period,
	|	WorkInProgress.Recorder AS Recorder,
	|	WorkInProgress.LineNumber AS LineNumber,
	|	WorkInProgress.Active AS Active,
	|	WorkInProgress.RecordType AS RecordType,
	|	WorkInProgress.Company AS Company,
	|	WorkInProgress.PresentationCurrency AS PresentationCurrency,
	|	WorkInProgress.StructuralUnit AS StructuralUnit,
	|	WorkInProgress.CostObject AS CostObject,
	|	WorkInProgress.Products AS Products,
	|	WorkInProgress.Characteristic AS Characteristic,
	|	WorkInProgress.Quantity AS Quantity,
	|	WorkInProgress.Amount AS Amount,
	|	WorkInProgress.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.WorkInProgress AS WorkInProgress
	|WHERE
	|	WorkInProgress.Recorder = &Recorder
	|	AND WorkInProgress.OfflineRecord";
	
	Query.SetParameter("Recorder", DocumentRef);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	QueryResult = Query.ExecuteBatch();
	
	InventoryRecords = QueryResult[0].Unload();
	AccountingJournalEntries = QueryResult[1].Unload();
	WIPRecords = QueryResult[2].Unload();
	
	For Each InventoryRecord In InventoryRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(NewRow, InventoryRecord);
	EndDo;
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		For Each AccountingJournalEntriesRecord In AccountingJournalEntries Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
			FillPropertyValues(NewRow, AccountingJournalEntriesRecord);
		EndDo;
	EndIf;

	For Each WIPRecord In WIPRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableWorkInProgress.Add();
		FillPropertyValues(NewRow, WIPRecord);
	EndDo;
	
EndProcedure

Procedure CollapseInventoryCostLayerRecordsTable(InventoryCostLayerRecordsTable)
	
	ColumnsNames = "";
	
	For Each TableColumn In InventoryCostLayerRecordsTable.Columns Do
		If TableColumn.Name <> "Quantity"
			And TableColumn.Name <> "Amount"
			And TableColumn.Name <> "CorrIncomeAndExpenseItem" 
			And TableColumn.Name <> "CorrGLAccount"
			And TableColumn.Name <> "CorrInventoryAccountType" Then
			ColumnsNames = ColumnsNames + TableColumn.Name + ",";
		EndIf;
	EndDo;
	
	ColumnsNames = Left(ColumnsNames, StrLen(ColumnsNames) - 1);
	
	InventoryCostLayerRecordsTable.GroupBy(ColumnsNames, "Quantity, Amount");
	
EndProcedure

Procedure GenerateTableReservedProducts(DocumentRef, AdditionalProperties)
	
	// Reserve receipt for all components
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref AS SalesOrder,
	|	TableInventory.Reserve AS Quantity
	|FROM
	|	TemporaryTableAllInventory AS TableInventory
	|WHERE
	|	TableInventory.Reserve > 0";
	
	QueryResult = Query.Execute();
	TableReservedProducts = QueryResult.Unload();
	
	// Reserve expense components with started operations (with reserved quantity)
	Query = New Query;
	Query.TempTablesManager = AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.InventoryStructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.Ref AS SalesOrder
	|FROM
	|	TemporaryTableInventory AS ReservedProducts";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.ReservedProducts");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	Query.Text =
	"SELECT
	|	Balance.Company AS Company,
	|	Balance.StructuralUnit AS StructuralUnit,
	|	Balance.Products AS Products,
	|	Balance.Characteristic AS Characteristic,
	|	Balance.Batch AS Batch,
	|	Balance.SalesOrder AS SalesOrder,
	|	SUM(Balance.Quantity) AS Quantity
	|INTO ReservedProductsBalance
	|FROM
	|	(SELECT
	|		Balance.Company AS Company,
	|		Balance.StructuralUnit AS StructuralUnit,
	|		Balance.Products AS Products,
	|		Balance.Characteristic AS Characteristic,
	|		Balance.Batch AS Batch,
	|		Balance.SalesOrder AS SalesOrder,
	|		Balance.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.ReservedProducts.Balance(
	|				,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						ReservedProducts.Company AS Company,
	|						ReservedProducts.InventoryStructuralUnit AS StructuralUnit,
	|						ReservedProducts.Products AS Products,
	|						ReservedProducts.Characteristic AS Characteristic,
	|						ReservedProducts.Batch AS Batch,
	|						ReservedProducts.Ref AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS ReservedProducts)) AS Balance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.InventoryStructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.Ref,
	|		DocumentRegisterRecordsReservedProducts.Reserve
	|	FROM
	|		TemporaryTableAllInventory AS DocumentRegisterRecordsReservedProducts
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsReservedProducts.Company,
	|		DocumentRegisterRecordsReservedProducts.StructuralUnit,
	|		DocumentRegisterRecordsReservedProducts.Products,
	|		DocumentRegisterRecordsReservedProducts.Characteristic,
	|		DocumentRegisterRecordsReservedProducts.Batch,
	|		DocumentRegisterRecordsReservedProducts.SalesOrder,
	|		CASE
	|			WHEN DocumentRegisterRecordsReservedProducts.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsReservedProducts.Quantity
	|			ELSE -DocumentRegisterRecordsReservedProducts.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.ReservedProducts AS DocumentRegisterRecordsReservedProducts
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref) AS Balance
	|
	|GROUP BY
	|	Balance.StructuralUnit,
	|	Balance.Company,
	|	Balance.Batch,
	|	Balance.Characteristic,
	|	Balance.Products,
	|	Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref AS Order,
	|	SUM(TableInventory.Reserve) AS Reserve
	|INTO TemporaryTableInventoryGrouped
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Order AS SalesOrder,
	|	Balance.Quantity AS Quantity
	|INTO AvailableReserve
	|FROM
	|	TemporaryTableInventoryGrouped AS TableInventory
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableInventory.Company = Balance.Company
	|			AND TableInventory.StructuralUnit = Balance.StructuralUnit
	|			AND TableInventory.Products = Balance.Products
	|			AND TableInventory.Characteristic = Balance.Characteristic
	|			AND TableInventory.Batch = Balance.Batch
	|			AND TableInventory.Order = Balance.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Reserve.Period AS Period,
	|	Reserve.Company AS Company,
	|	Reserve.StructuralUnit AS StructuralUnit,
	|	Reserve.GLAccount AS GLAccount,
	|	Reserve.Products AS Products,
	|	Reserve.Characteristic AS Characteristic,
	|	Reserve.Batch AS Batch,
	|	Reserve.SalesOrder AS SalesOrder,
	|	Reserve.Quantity AS Quantity
	|FROM
	|	AvailableReserve AS Reserve
	|WHERE
	|	Reserve.Quantity > 0";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlPeriod", AdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewLine = TableReservedProducts.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	AdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure


#EndRegion

#Region AccountingTemplates

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	Return AccountingFields;
	
EndFunction
#EndRegion

#EndIf
