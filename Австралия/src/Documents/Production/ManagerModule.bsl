#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	Production.Date AS Period,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	ProductionProducts.Ref AS Ref,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Production.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Production.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Production.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsAccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionProducts.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.InventoryGLAccount
	|	END AS ProductsAccountCr,
	|	UNDEFINED AS CustomerCorrOrder,
	|	Production.BasisDocument AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionProducts.Quantity
	|		ELSE ProductionProducts.Quantity * ProductionProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&Production AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&Production AS STRING(100)) AS Content,
	|	Production.BasisDocument AS KitOrder
	|INTO TemporaryTableProduction
	|FROM
	|	Document.Production.Products AS ProductionProducts
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionProducts.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionProducts.Ref.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		LEFT JOIN Document.Production AS Production
	|		ON ProductionProducts.Ref = Production.Ref
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|;
	|SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	Production.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Production.ProductsStructuralUnit AS StructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN ProductionProducts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionProducts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProducts.SalesOrder
	|	END AS SalesOrder,
	|	Production.BasisDocument AS SupplySource,
	|	Production.BasisDocument AS KitOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CAST(&Production AS STRING(100)) AS ContentOfAccountingRecord,
	|	ProductionProducts.Quantity AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableProductionReservation
	|FROM
	|	Document.Production.Reservation AS ProductionProducts
	|		LEFT JOIN Document.Production AS Production
	|		ON ProductionProducts.Ref = Production.Ref
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.InventoryAccountType AS InventoryAccountType,
	|	TableProduction.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.CostObject AS CostObject,
	|	UNDEFINED AS OwnershipCorr,
	|	UNDEFINED AS BatchCorr,
	|	UNDEFINED AS CostObjectCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	UNDEFINED AS SalesOrder,
	|	TableProduction.KitOrder AS KitOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.PresentationCurrency,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.GLAccount,
	|	TableProduction.InventoryAccountType,
	|	TableProduction.CorrInventoryAccountType,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.CostObject,
	|	TableProduction.Specification,
	|	TableProduction.KitOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	TableProduction.KitOrder AS KitOrder
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.KitOrder <> UNDEFINED
	|	AND TableProduction.KitOrder <> VALUE(Document.KitOrder.EmptyRef)
	// begin Drive.FullVersion
	|	AND TableProduction.KitOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	// end Drive.FullVersion
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.KitOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.Products AS ProductsCorr,
	|	TableProduction.Characteristic AS CharacteristicCorr,
	|	TableProduction.Batch AS BatchCorr,
	|	TableProduction.Ownership AS OwnershipCorr,
	|	TableProduction.CostObject AS CostObjectCorr,
	|	TableProduction.Specification AS SpecificationCorr,
	|	TableProduction.GLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	SUM(TableProduction.Quantity) AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.CostObject,
	|	TableProduction.Specification,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.AccountDr,
	|	TableProduction.ProductsAccountDr,
	|	TableProduction.ProductsAccountCr
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersProducts.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Production.SerialNumbersProducts AS TableSerialNumbersProducts
	|		ON TableProduction.Ref = TableSerialNumbersProducts.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbersProducts.ConnectionKey
	|WHERE
	|	TableSerialNumbersProducts.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Ref.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	TableInventory.Ownership,
	|	TableInventory.Ref.InventoryStructuralUnit,
	|	TableInventory.Ref.CellInventory,
	|	1
	|FROM
	|	Document.Production.Inventory AS TableInventory
	|		INNER JOIN Document.Production.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TableInventory.Ref.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
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
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Ref
	|	AND NOT InventoryCostLayer.SourceRecord";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production", NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory",
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableKitOrders", ResultsArray[4].Unload());
	
	// Generate documents posting table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackordersAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[7].Unload();
	GenerateRawMaterialsConsumptionTableAssembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsAssembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	
	// Serial numbers
	QueryResult8 = ResultsArray[8].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult8);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult8);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	QueryResult9 = ResultsArray[9].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult9);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	Production.Date AS Period,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Production.StructuralUnit AS StructuralUnit,
	|	Production.CellInventory AS CellInventory,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Production.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	Production.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	Production.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	ProductionInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Production.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	UNDEFINED AS CustomerCorrOrder,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	CAST(&Production AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&Production AS STRING(100)) AS Content,
	|	Production.BasisDocument AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionInventory.Quantity
	|		ELSE ProductionInventory.Quantity * ProductionInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	Production.BasisDocument AS KitOrder
	|INTO TemporaryTableProduction
	|FROM
	|	Document.Production.Inventory AS ProductionInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionInventory.Ref.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		LEFT JOIN Document.Production AS Production
	|		ON ProductionInventory.Ref = Production.Ref
	|WHERE
	|	ProductionInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	Production.Ref AS Ref,
	|	Production.Date AS Period,
	|	&Company AS Company,
	|	Production.CellInventory AS CellInventory,
	|	Production.Cell AS Cell,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Production.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	Production.ProductsStructuralUnit AS StructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	Production.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsGLAccount,
	|	ProductionProducts.Products AS Products,
	|	ProductionProducts.Characteristic AS Characteristic,
	|	ProductionProducts.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN ProductionProducts.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionProducts.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProducts.SalesOrder
	|	END AS SalesOrder,
	|	Production.BasisDocument AS SupplySource,
	|	Production.BasisDocument AS KitOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	ProductionProducts.Quantity AS Quantity,
	|	0 AS Amount
	|INTO TemporaryTableInventoryReservation
	|FROM
	|	Document.Production.Reservation AS ProductionProducts
	|		LEFT JOIN Document.Production AS Production
	|		ON ProductionProducts.Ref = Production.Ref
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.ProductsStructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsGLAccount AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	TableProduction.InventoryAccountType AS InventoryAccountType,
	|	TableProduction.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProduction.CostObject AS CostObject,
	|	UNDEFINED AS CostObjectCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	UNDEFINED AS SalesOrder,
	|	TableProduction.KitOrder AS KitOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.PresentationCurrency,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.InventoryAccountType,
	|	TableProduction.CorrInventoryAccountType,
	|	TableProduction.CostObject,
	|	TableProduction.Specification,
	|	TableProduction.KitOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	(TableProduction.StructuralUnit <> TableProduction.ProductsStructuralUnitToWarehouse
	|			OR TableProduction.Cell <> TableProduction.ProductsCell)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	UNDEFINED AS SalesOrder,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Ownership,
	|	TableProduction.Specification,
	|	TableProduction.SupplySource
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	TableProduction.KitOrder AS KitOrder
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.KitOrder <> UNDEFINED
	|	AND TableProduction.KitOrder <> VALUE(Document.KitOrder.EmptyRef)
	// begin Drive.FullVersion
	|	AND TableProduction.KitOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	// end Drive.FullVersion
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.KitOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ProductionProducts.LineNumber) AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Ownership AS Ownership,
	|	ProductionProducts.Ownership.OwnershipType AS OwnershipType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionProducts.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryReceivedGLAccount
	|		ELSE ProductionProducts.InventoryGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	ProductionProducts.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(ProductionProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN ProductionProducts.Quantity
	|			ELSE ProductionProducts.Quantity * ProductionProducts.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	FALSE AS Distributed
	|FROM
	|	Document.Production.Products AS ProductionProducts
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionProducts.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionProducts.Ref.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|
	|GROUP BY
	|	ProductionProducts.Products,
	|	ProductionProducts.Specification,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	ProductionProducts.Ownership,
	|	ProductionProducts.Ownership.OwnershipType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionProducts.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryReceivedGLAccount
	|		ELSE ProductionProducts.InventoryGLAccount
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Production.SerialNumbers AS TableSerialNumbers
	|		ON TableProduction.Ref = TableSerialNumbers.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableProduction.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Ref.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.Ref.InventoryStructuralUnit,
	|	TableInventory.Ref.CellInventory,
	|	1
	|FROM
	|	Document.Production.Products AS TableInventory
	|		INNER JOIN Document.Production.SerialNumbersProducts AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TableInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON TableInventory.Ref.InventoryStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
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
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryCostLayer.StructuralUnit AS StructuralUnit,
	|	InventoryCostLayer.CostLayer AS CostLayer,
	|	InventoryCostLayer.Quantity AS Quantity,
	|	InventoryCostLayer.Amount AS Amount,
	|	InventoryCostLayer.SourceRecord AS SourceRecord,
	|	InventoryCostLayer.VATRate AS VATRate,
	|	InventoryCostLayer.Responsible AS Responsible,
	|	InventoryCostLayer.Department AS Department,
	|	InventoryCostLayer.SourceDocument AS SourceDocument,
	|	InventoryCostLayer.CorrSalesOrder AS CorrSalesOrder,
	|	InventoryCostLayer.CorrStructuralUnit AS CorrStructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryCostLayer.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	InventoryCostLayer.RIMTransfer AS RIMTransfer,
	|	InventoryCostLayer.SalesRep AS SalesRep,
	|	InventoryCostLayer.Counterparty AS Counterparty,
	|	InventoryCostLayer.Currency AS Currency,
	|	InventoryCostLayer.SalesOrder AS SalesOrder,
	|	InventoryCostLayer.InventoryAccountType AS InventoryAccountType,
	|	InventoryCostLayer.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	InventoryCostLayer.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	InventoryCostLayer.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer
	|WHERE
	|	InventoryCostLayer.Recorder = &Ref
	|	AND NOT InventoryCostLayer.SourceRecord";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("Production", NStr("en = 'Production'; ru = 'Производство';pl = 'Produkcja';es_ES = 'Producción';es_CO = 'Producción';tr = 'Üretim';it = 'Produzione';de = 'Produktion'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableKitOrders", ResultsArray[5].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", New ValueTable);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackordersDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	GenerateTableProductRelease(ResultsArray[4].Unload(), StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[8].Unload();
	GenerateRawMaterialsConsumptionTableDisassembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	
	// Serial numbers
	If StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count()>0 Then
		QueryResult9 = ResultsArray[9].Unload();
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult9);
		If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult9);
		Else
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		EndIf;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
	QueryResult10 = ResultsArray[10].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult10);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefProduction, StructureAdditionalProperties) Export
	
	If DocumentRefProduction.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties)
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties)
		
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefProduction, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefProduction, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefProduction, StructureAdditionalProperties);
			
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefProduction, StructureAdditionalProperties);
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	ProductionWaste.Ref.Date AS Period,
	|	ProductionWaste.Ref.DisposalsStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionWaste.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionWaste.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(ProductionWaste.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionWaste.Quantity
	|		ELSE ProductionWaste.Quantity * ProductionWaste.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&ReturnWaste AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&ReturnWaste AS STRING(100)) AS Content
	|FROM
	|	Document.Production.Disposals AS ProductionWaste
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionWaste.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionWaste.Ref.DisposalsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	ProductionWaste.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionWaste.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionWaste.Ref.DisposalsStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionWaste.Ref.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionWaste.Ownership AS Ownership,
	|	CASE
	|		WHEN VALUETYPE(ProductionWaste.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionWaste.Quantity
	|		ELSE ProductionWaste.Quantity * ProductionWaste.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.Production.Disposals AS ProductionWaste
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionWaste.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionWaste.Ref.DisposalsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	ProductionWaste.Ref = &Ref";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("ReturnWaste", NStr("en = 'Recyclable waste'; ru = 'Возвратные отходы';pl = 'Odpady wtórne';es_ES = 'Residuos reciclables';es_CO = 'Residuos reciclables';tr = 'Geri dönüştürülebilir atık';it = 'Rifiuti riciclabili';de = 'Wieder-verwertbarer Abfall'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties);

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateRawMaterialsConsumptionTableAssembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.CorrLineNumber AS CorrLineNumber,
	|	TableProduction.ProductsCorr AS ProductsCorr,
	|	TableProduction.CharacteristicCorr AS CharacteristicCorr,
	|	TableProduction.BatchCorr AS BatchCorr,
	|	TableProduction.OwnershipCorr AS OwnershipCorr,
	|	TableProduction.CostObjectCorr AS CostObjectCorr,
	|	TableProduction.SpecificationCorr AS SpecificationCorr,
	|	TableProduction.CorrGLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	TableProduction.CorrQuantity AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.ProductsCorr AS ProductsCorr,
	|	TableProductsContent.CharacteristicCorr AS CharacteristicCorr,
	|	TableProductsContent.BatchCorr AS BatchCorr,
	|	TableProductsContent.OwnershipCorr AS OwnershipCorr,
	|	TableProductsContent.CostObjectCorr AS CostObjectCorr,
	|	TableProductsContent.SpecificationCorr AS SpecificationCorr,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.ProductsGLAccount AS ProductsGLAccount,
	|	TableProductsContent.AccountDr AS AccountDr,
	|	TableProductsContent.ProductsAccountDr AS ProductsAccountDr,
	|	TableProductsContent.ProductsAccountCr AS ProductsAccountCr,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN CASE
	|					WHEN TableMaterials.Quantity = 0
	|						THEN 1
	|					ELSE TableMaterials.Quantity
	|				END / TableMaterials.Ref.Quantity * TableProductsContent.CorrQuantity
	|		ELSE CASE
	|				WHEN TableMaterials.Quantity = 0
	|					THEN 1
	|				ELSE TableMaterials.Quantity
	|			END * TableMaterials.MeasurementUnit.Factor / TableMaterials.Ref.Quantity * TableProductsContent.CorrQuantity
	|	END AS TMQuantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification,
	|	FALSE AS Distributed
	|INTO TT_TableProductsContent
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.SpecificationCorr = TableMaterials.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TT_TableProductsContent.ProductsCorr AS ProductsCorr,
	|	TT_TableProductsContent.CharacteristicCorr AS CharacteristicCorr,
	|	TT_TableProductsContent.BatchCorr AS BatchCorr,
	|	TT_TableProductsContent.OwnershipCorr AS OwnershipCorr,
	|	TT_TableProductsContent.CostObjectCorr AS CostObjectCorr,
	|	TT_TableProductsContent.SpecificationCorr AS SpecificationCorr,
	|	TT_TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TT_TableProductsContent.ProductsGLAccount AS ProductsGLAccount,
	|	TT_TableProductsContent.AccountDr AS AccountDr,
	|	TT_TableProductsContent.ProductsAccountDr AS ProductsAccountDr,
	|	TT_TableProductsContent.ProductsAccountCr AS ProductsAccountCr,
	|	TT_TableProductsContent.CorrQuantity AS CorrQuantity,
	|	TT_TableProductsContent.TMQuantity AS TMQuantity,
	|	TT_TableProductsContent.TMContentRowType AS TMContentRowType,
	|	TT_TableProductsContent.TMProducts AS TMProducts,
	|	TT_TableProductsContent.TMCharacteristic AS TMCharacteristic,
	|	TT_TableProductsContent.TMSpecification AS TMSpecification,
	|	TT_TableProductsContent.Distributed AS Distributed
	|FROM
	|	TT_TableProductsContent AS TT_TableProductsContent
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON TT_TableProductsContent.TMProducts = ProductsCatalog.Ref
	|WHERE
	|	(ProductsCatalog.ProductsType IS NULL
	|			OR ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	CorrLineNumber,
	|	ProductsCorr,
	|	TMProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.Ref.Date AS Period,
	|	ProductionInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProductionInventory.Ref.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.Ref.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.Ref.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE ProductionInventory.InventoryGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE ProductionInventory.InventoryGLAccount
	|	END AS InventoryGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	VALUE(Catalog.Products.EmptyRef) AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.Ownership.OwnershipType AS OwnershipType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObjectCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS OwnershipCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS SpecificationCorr,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN ProductionHead.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionHead.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionHead.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(ProductionInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionInventory.Quantity
	|		ELSE ProductionInventory.Quantity * ProductionInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS AccountDr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountDr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|				AND ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE ProductionInventory.InventoryGLAccount
	|	END AS AccountCr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountCr,
	|	FALSE AS Distributed,
	|	ProductionInventory.Ref.BasisDocument AS KitOrder
	|FROM
	|	Document.Production.Inventory AS ProductionInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionInventory.Ref.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		INNER JOIN Document.Production AS ProductionHead
	|		ON ProductionInventory.Ref = ProductionHead.Ref
	|WHERE
	|	ProductionInventory.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber,
	|	ProductsCorr,
	|	Products";
	
	Query.SetParameter("TableProduction",		TableProduction);
	Query.SetParameter("Ref",					DocumentRefProduction);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent = ResultsArray[2].Unload();
	MaterialsTable = ResultsArray[3].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		Ind = Ind + 1;
	EndDo;
	
	TableProductsContent.GroupBy("ProductsCorr, CharacteristicCorr, BatchCorr, OwnershipCorr, CostObjectCorr, SpecificationCorr,
		|CorrGLAccount, ProductsGLAccount, AccountDr, ProductsAccountDr, ProductsAccountCr, CorrQuantity, TMProducts,
		|TMCharacteristic, Distributed", "TMQuantity");
	TableProductsContent.Indexes.Add("TMProducts, TMCharacteristic");
	
	DistributedMaterials	= 0;
	ProductsQuantity		= TableProductsContent.Count();
	MaterialsAmount			= MaterialsTable.Count();
	
	For n = 0 To MaterialsAmount - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProducts",	StringMaterials.Products);
		SearchStructure.Insert("TMCharacteristic",		StringMaterials.Characteristic);
		
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
	
	If DistributedMaterials < MaterialsAmount Then
		If DistributedProducts = ProductsQuantity Then
			DistributionBase = TableProduction.Total("CorrQuantity");
			DistributeMaterialsByQuantity(TableProduction, MaterialsTable, DistributionBase);
		Else
			DistributeMaterialsByQuantity(TableProductsContent, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction			= Undefined;
	TableProductsContent	= Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRawMaterialsConsumptionAssembly", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.InventoryAccountType AS InventoryAccountType,
	|	ProductionInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.ProductsGLAccount AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.OwnershipType AS OwnershipType,
	|	ProductionInventory.CostObject AS CostObject,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.OwnershipCorr AS OwnershipCorr,
	|	ProductionInventory.CostObjectCorr AS CostObjectCorr,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.SalesOrder
	|	END AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.ProductsAccountDr AS ProductsAccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.ProductsAccountCr AS ProductsAccountCr,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content,
	|	ProductionInventory.KitOrder AS KitOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableRawMaterialsConsumptionAssembly AS ProductionInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.ProductsStructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.CostObjectCorr AS CostObjectCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CostObjectCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.SalesOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber,
	|	ProductsCorr,
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CellInventory AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableInventory.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory))
	|			AND TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CatalogInventoryOwnership.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.KitOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.KitOrder
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableRawMaterialsConsumptionAssembly", StructureAdditionalProperties.TableForRegisterRecords.TableRawMaterialsConsumptionAssembly);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
 
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	GoodsConsumed = ResultsArray[3].Unload();
	GoodsConsumed.FillValues(AccumulationRecordType.Receipt, "RecordType");
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", GoodsConsumed);
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableRawMaterialsConsumptionAssembly");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateRawMaterialsConsumptionTableDisassembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Ownership AS Ownership,
	|	TableProduction.OwnershipType AS OwnershipType,
	|	TableProduction.CostObject AS CostObject,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.InventoryGLAccount AS InventoryGLAccount,
	|	TableProduction.AccountCr AS AccountCr,
	|	TableProduction.Quantity AS Quantity
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.Products AS Products,
	|	TableProductsContent.Characteristic AS Characteristic,
	|	TableProductsContent.Batch AS Batch,
	|	TableProductsContent.Ownership AS Ownership,
	|	TableProductsContent.OwnershipType AS OwnershipType,
	|	TableProductsContent.CostObject AS CostObject,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.GLAccount AS GLAccount,
	|	TableProductsContent.InventoryGLAccount AS InventoryGLAccount,
	|	TableProductsContent.AccountCr AS AccountCr,
	|	TableProductsContent.Quantity AS Quantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	1 AS CorrQuantity,
	|	1 AS TMQuantity,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification
	|INTO TT_TableProductsContent
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableProductsContent.Products AS Products,
	|	TT_TableProductsContent.Characteristic AS Characteristic,
	|	TT_TableProductsContent.Batch AS Batch,
	|	TT_TableProductsContent.Ownership AS Ownership,
	|	TT_TableProductsContent.OwnershipType AS OwnershipType,
	|	TT_TableProductsContent.CostObject AS CostObject,
	|	TT_TableProductsContent.Specification AS Specification,
	|	TT_TableProductsContent.GLAccount AS GLAccount,
	|	TT_TableProductsContent.InventoryGLAccount AS InventoryGLAccount,
	|	TT_TableProductsContent.AccountCr AS AccountCr,
	|	TT_TableProductsContent.Quantity AS Quantity,
	|	TT_TableProductsContent.TMContentRowType AS TMContentRowType,
	|	TT_TableProductsContent.CorrQuantity AS CorrQuantity,
	|	TT_TableProductsContent.TMQuantity AS TMQuantity,
	|	TT_TableProductsContent.TMProducts AS TMProducts,
	|	TT_TableProductsContent.TMCharacteristic AS TMCharacteristic,
	|	TT_TableProductsContent.TMSpecification AS TMSpecification
	|FROM
	|	TT_TableProductsContent AS TT_TableProductsContent
	|		LEFT JOIN Catalog.Products AS ProductsCatalog
	|		ON TT_TableProductsContent.TMProducts = ProductsCatalog.Ref
	|WHERE
	|	(ProductsCatalog.ProductsType IS NULL
	|			OR ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.Period AS Period,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryReceivedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE ProductionInventory.InventoryGLAccount
	|	END AS ProductsGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	ProductionInventory.Products AS ProductsCorr,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS Ownership,
	|	VALUE(Enum.InventoryOwnershipTypes.EmptyRef) AS OwnershipType,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	ProductionInventory.Ownership AS OwnershipCorr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObjectCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	ProductionInventory.Specification AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionHead.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionHead.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionHead.SalesOrder
	|	END AS SalesOrder,
	|	0 AS Quantity,
	|	0 AS Amount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ProductsAccountDr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS AccountCr,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN ProductionInventory.Ownership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		ELSE ProductionInventory.InventoryGLAccount
	|	END AS ProductsAccountCr,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	FALSE AS NewRow,
	|	FALSE AS AccountExecuted,
	|	FALSE AS Distributed,
	|	ProductionInventory.KitOrder AS KitOrder
	|FROM
	|	TemporaryTableProduction AS ProductionInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON ProductionInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON ProductionInventory.ProductsStructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|		INNER JOIN Document.Production AS ProductionHead
	|		ON ProductionInventory.Ref = ProductionHead.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction",		TableProduction);
	Query.SetParameter("Ref",					DocumentRefProduction);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent	= ResultsArray[2].Unload();
	MaterialsTable			= ResultsArray[3].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		Ind = Ind + 1;
	EndDo;
	
	TableProductsContent.GroupBy("Products, Characteristic, Batch, Ownership, CostObject, OwnershipType, Specification, GLAccount,
		|InventoryGLAccount, AccountCr, Quantity, TMProducts, TMCharacteristic");
	TableProductsContent.Indexes.Add("Products, Characteristic, Batch, Specification");
	
	MaterialsTable.Indexes.Add("ProductsCorr,CharacteristicCorr");
	
	DistributedProducts	= 0;
	MaterialsAmount		= MaterialsTable.Count();
	ProductsQuantity	= TableProductsContent.Count();
	
	For Each StringProducts In TableProduction Do
		
		SearchStructureProducts = New Structure;
		SearchStructureProducts.Insert("Products",	StringProducts.Products);
		SearchStructureProducts.Insert("Characteristic",		StringProducts.Characteristic);
		SearchStructureProducts.Insert("Batch",					StringProducts.Batch);
		SearchStructureProducts.Insert("Ownership",				StringProducts.Ownership);
		SearchStructureProducts.Insert("Specification",			StringProducts.Specification);
		
		BaseCostPercentage = 0;
		SearchResultProducts = TableProductsContent.FindRows(SearchStructureProducts);
		For Each RowSearchProducts In SearchResultProducts Do
			
			SearchStructureMaterials = New Structure;
			SearchStructureMaterials.Insert("NewRow", False);
			SearchStructureMaterials.Insert("ProductsCorr", RowSearchProducts.TMProducts);
			SearchStructureMaterials.Insert("CharacteristicCorr", RowSearchProducts.TMCharacteristic);
			
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
		If StringMaterials.Distributed AND Not StringMaterials.NewRow Then
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
	EndDo;
	
	If DistributedProducts < TableProduction.Count() Then
		If DistributedMaterials = MaterialsAmount Then
			BaseCostPercentage = MaterialsTable.Total("CostPercentage");
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable, BaseCostPercentage, False);
		Else
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction			= Undefined;
	TableProductsContent	= Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOfRawMaterialsConsumptionDisassembling", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	ProductionInventory.InventoryReceivedGLAccount AS InventoryReceivedGLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.ProductsGLAccount AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.Ownership AS Ownership,
	|	ProductionInventory.OwnershipType AS OwnershipType,
	|	ProductionInventory.CostObject AS CostObject,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.OwnershipCorr AS OwnershipCorr,
	|	ProductionInventory.InventoryAccountType AS InventoryAccountType,
	|	ProductionInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	ProductionInventory.CostObjectCorr AS CostObjectCorr,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	ProductionInventory.SalesOrder AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.ProductsAccountDr AS ProductsAccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.ProductsAccountCr AS ProductsAccountCr,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content,
	|	ProductionInventory.KitOrder AS KitOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableOfRawMaterialsConsumptionDisassembling AS ProductionInventory
	|WHERE
	|	ProductionInventory.Products <> VALUE(Catalog.Products.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.ProductsStructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.ProductsGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.CostObjectCorr AS CostObjectCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	0 AS Amount,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.CostPercentage AS CostPercentage
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.CostObject,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CostObjectCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CostPercentage,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.SalesOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CellInventory AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	CatalogInventoryOwnership.Counterparty AS Counterparty
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (TableInventory.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory))
	|			AND TableInventory.Ownership = CatalogInventoryOwnership.Ref
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	CatalogInventoryOwnership.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	TableInventory.KitOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.KitOrder
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableOfRawMaterialsConsumptionDisassembling", StructureAdditionalProperties.TableForRegisterRecords.TableOfRawMaterialsConsumptionDisassembling);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode));
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	GenerateTableInventoryInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsConsumedToDeclare", New ValueTable);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefProduction, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary
	// tables "RegisterRecordsKitOrdersChange"
	// "RegisterRecordsBackordersChange" "RegisterRecordsInventoryChange"
	// "RegisterRecordsReservedProductsChange" contain records, control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsKitOrdersChange
		OR StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
		OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange
		OR StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
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
		|	REFPRESENTATION(RegisterRecordsInventoryChange.PresentationCurrency) AS PresentationCurrencyPresentation,
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
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrency,
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
		|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
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
		|	RegisterRecordsKitOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.KitOrder) AS KitOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsKitOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(KitOrdersBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsKitOrdersChange.QuantityChange, 0) + ISNULL(KitOrdersBalance.QuantityBalance, 0) AS BalanceKitOrders,
		|	ISNULL(KitOrdersBalance.QuantityBalance, 0) AS QuantityBalanceKitOrders
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
		|						RegisterRecordsKitOrdersChange AS RegisterRecordsKitOrdersChange)) AS KitOrdersBalance
		|		ON RegisterRecordsKitOrdersChange.Company = KitOrdersBalance.Company
		|			AND RegisterRecordsKitOrdersChange.Products = KitOrdersBalance.Products
		|			AND RegisterRecordsKitOrdersChange.Characteristic = KitOrdersBalance.Characteristic
		|			AND RegisterRecordsKitOrdersChange.KitOrder = KitOrdersBalance.KitOrder
		|WHERE
		|	ISNULL(KitOrdersBalance.QuantityBalance, 0) < 0
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
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty()
			OR Not ResultsArray[5].IsEmpty()
			OR Not ResultsArray[6].IsEmpty() Then
			DocumentObjectProduction = DocumentRefProduction.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectProduction, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by kit orders.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToKitOrdersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

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

#EndRegion

#Region Private

#Region ServiceProceduresAndFunctions

// Procedure distributes materials by the products BillsOfMaterials.
//
Procedure DistributeMaterialsAccordingToNorms(StringMaterials, BaseTable, MaterialsTable)
	
	StringMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow In BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure

// Procedure distributes materials in proportion to the products quantity.
//
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
			DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure allocates materials string.
//
Procedure DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, AccordingToNorms, ExcDistributed = False)
	
	InitQuantity = 0;
	QuantityToWriteOff = StringMaterials.Quantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	For Each BasicTableRow In BaseTable Do
		
		If ExcDistributed AND BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitQuantity = QuantityToWriteOff Then
			Continue;
		EndIf;
		
		If ValueIsFilled(StringMaterials.ProductsCorr) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, StringMaterials);
			FillPropertyValues(NewRow, BasicTableRow);
			StringMaterials = NewRow;
		Else
			FillPropertyValues(StringMaterials, BasicTableRow);
		EndIf;
		
		If AccordingToNorms Then
			BasicTableQuantity = BasicTableRow.TMQuantity;
		Else
			BasicTableQuantity = BasicTableRow.CorrQuantity
		EndIf;
		
		// Quantity.
		StringMaterials.Quantity = Round((QuantityToWriteOff - InitQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1);
		
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

// Procedure distributes materials by the products BillsOfMaterials.
//
Procedure DistributeProductsAccordingToNorms(StringProducts, BaseTable, DistributionBase)
	
	DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, True);
	
EndProcedure

// Procedure distributes materials in proportion to the products quantity.
//
Procedure DistributeProductsAccordingToQuantity(TableProduction, BaseTable, DistributionBase = 0, ExcDistributed = True)
	
	If ExcDistributed Then
		For Each StringMaterials In BaseTable Do
			If Not StringMaterials.NewRow
				AND Not StringMaterials.Distributed Then
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

// Procedure allocates production string.
//
Procedure DistributeTabularSectionStringProducts(ProductsRow, BaseTable, DistributionBase, AccordingToNorms, ExeptDistribution = False)
	
	InitQuantity = 0;
	QuantityToWriteOff = ProductsRow.Quantity;
	
	DistributionBaseQuantity = DistributionBase;
	
	DistributionRow = Undefined;
	For n = 0 To BaseTable.Count() - 1 Do
		
		StringMaterials = BaseTable[n];
		
		If InitQuantity = QuantityToWriteOff
			OR StringMaterials.NewRow Then
			StringMaterials.AccountExecuted = False;
			Continue;
		EndIf;
		
		If AccordingToNorms AND Not StringMaterials.AccountExecuted Then
			Continue;
		EndIf;
		
		StringMaterials.AccountExecuted = False;
		
		If Not AccordingToNorms AND ExeptDistribution
			AND StringMaterials.Distributed Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(StringMaterials.Products) Then
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
		
		// Quantity.
		DistributionRow.Quantity = Round((QuantityToWriteOff - InitQuantity) * StringMaterials.CostPercentage / ?(DistributionBaseQuantity = 0, 1, DistributionBaseQuantity),3,1);
		
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties)
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	If StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
	
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text = 
		"SELECT
		|	TableInventory.Company AS Company,
		|	TableInventory.PresentationCurrency AS PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|	TableInventory.InventoryAccountType AS InventoryAccountType,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	TableInventory.CostObject AS CostObject
		|FROM
		|	TemporaryTableInventory AS TableInventory
		|
		|GROUP BY
		|	TableInventory.Company,
		|	TableInventory.PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit,
		|	TableInventory.InventoryAccountType,
		|	TableInventory.Products,
		|	TableInventory.Characteristic,
		|	TableInventory.Batch,
		|	TableInventory.Ownership,
		|	TableInventory.CostObject";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;

		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receiving inventory balances by cost.
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.Ownership AS Ownership,
		|	InventoryBalances.CostObject AS CostObject,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.Company AS Company,
		|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|		InventoryBalances.StructuralUnit AS StructuralUnit,
		|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|		InventoryBalances.Products AS Products,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.Batch AS Batch,
		|		InventoryBalances.Ownership AS Ownership,
		|		InventoryBalances.CostObject AS CostObject,
		|		InventoryBalances.QuantityBalance AS QuantityBalance,
		|		InventoryBalances.AmountBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.PresentationCurrency,
		|						TableInventory.InventoryStructuralUnit,
		|						TableInventory.InventoryAccountType,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.Ownership,
		|						TableInventory.CostObject
		|					FROM
		|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventory.Company,
		|		DocumentRegisterRecordsInventory.PresentationCurrency,
		|		DocumentRegisterRecordsInventory.StructuralUnit,
		|		DocumentRegisterRecordsInventory.InventoryAccountType,
		|		DocumentRegisterRecordsInventory.Products,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		DocumentRegisterRecordsInventory.Batch,
		|		DocumentRegisterRecordsInventory.Ownership,
		|		DocumentRegisterRecordsInventory.CostObject,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.PresentationCurrency,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.InventoryAccountType,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.Ownership,
		|	InventoryBalances.CostObject";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalances = QueryResult.Unload();
		TableInventoryBalances.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, InventoryAccountType");
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company", RowTableInventory.Company);
			StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
			StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
			StructureForSearch.Insert("Products", RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventory.Batch);
			StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
			StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
			StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
			
			QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
			
			If QuantityRequiredAvailableBalance > 0 Then
				
				BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
				
				QuantityBalance = 0;
				AmountBalance = 0;
				
				If BalanceRowsArray.Count() > 0 Then
					QuantityBalance = BalanceRowsArray[0].QuantityBalance;
					AmountBalance = BalanceRowsArray[0].AmountBalance;
				EndIf;
				
				If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

					AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

					BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
					BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

				ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

					AmountToBeWrittenOff = AmountBalance;

					BalanceRowsArray[0].QuantityBalance = 0;
					BalanceRowsArray[0].AmountBalance = 0;

				Else
					AmountToBeWrittenOff = 0;
				EndIf;
				
				AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
		
				// Expense.
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				TableRowExpense.Amount = AmountToBeWrittenOff;
				TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.SalesOrder = Undefined;
				
				// Receipt
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
						
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
						
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
					TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
					TableRowReceipt.CostObject = RowTableInventory.CostObjectCorr;
					TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
						
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.OwnershipCorr = RowTableInventory.Ownership;
					TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
					TableRowReceipt.CostObjectCorr = RowTableInventory.CostObject;
					TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
					TableRowReceipt.CustomerCorrOrder = Undefined;
						
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					// Generate postings.
					If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
			
			QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
			
			If QuantityRequiredAvailableBalance > 0 Then
				
				// Expense.
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.SalesOrder = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	TablesProductsToBeTransferred = Undefined;
	
	AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN TableInventoryDemand.SalesOrder = UNDEFINED
	|				OR TYPE(Document.SalesOrder) <> VALUETYPE(TableInventoryDemand.SalesOrder)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE TableInventoryDemand.SalesOrder
	|	END AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	TableInventoryDemand.KitOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Balance receipt
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic, ProductionDocument) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						CASE
	|							WHEN TemporaryTableInventory.SalesOrder = UNDEFINED
	|								THEN VALUE(Document.SalesOrder.EmptyRef)
	|							ELSE TemporaryTableInventory.SalesOrder
	|						END,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic,
	|						TemporaryTableInventory.KitOrder AS ProductionDocument
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic,
	|		InventoryDemandBalances.ProductionDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		DocumentRegisterRecordsInventoryDemand.ProductionDocument,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
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
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(DocumentRefProduction.SalesOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 			RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder",
			?(RowTablesForInventory.SalesOrder = Undefined,
				Documents.SalesOrder.EmptyRef(), RowTablesForInventory.SalesOrder));
		StructureForSearch.Insert("Products",			RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic",		RowTablesForInventory.Characteristic);
		StructureForSearch.Insert("ProductionDocument",	RowTablesForInventory.ProductionDocument);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 And BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsAssembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Indexes.Add("RecordType,Company,Products,Characteristic");
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	EmptyInventoryAccountType = Enums.InventoryAccountTypes.EmptyRef();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		TableRowReceipt.CorrInventoryAccountType = EmptyInventoryAccountType;
		
		// If the production order is filled in then check whether there are placed customers orders in the kit order.
		If ValueIsFilled(RowTableInventoryProducts.KitOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);

			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			For Each RowAllocationArray In ArrayPropertiesProducts Do
				
				If RowAllocationArray.Quantity > 0 Then
					
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
					NewRowReservedTable.SalesOrder = RowAllocationArray.SalesOrder;
					NewRowReservedTable.Quantity = RowAllocationArray.Quantity;
					
				EndIf;
				
			EndDo;
			
		ElsIf ValueIsFilled(RowTableInventoryProducts.SalesOrder) Then
			
			NewRowReservedTable = TableReservedProducts.Add();
			FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackordersAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	TableProduction.Quantity AS Quantity
	|FROM
	|	TemporaryTableProductionReservation AS TableProduction
	|WHERE
	|	TableProduction.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableProduction.SalesOrder REFS Document.SalesOrder
	|	AND TableProduction.ProductsStructuralUnitToWarehouse.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	If StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text =
		"SELECT
		|	TableInventory.Company AS Company,
		|	TableInventory.PresentationCurrency AS PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
		|	TableInventory.InventoryAccountType AS InventoryAccountType,
		|	TableInventory.Products AS Products,
		|	TableInventory.Characteristic AS Characteristic,
		|	TableInventory.Batch AS Batch,
		|	TableInventory.Ownership AS Ownership,
		|	TableInventory.CostObject AS CostObject
		|FROM
		|	TemporaryTableInventory AS TableInventory
		|
		|GROUP BY
		|	TableInventory.Company,
		|	TableInventory.PresentationCurrency,
		|	TableInventory.InventoryStructuralUnit,
		|	TableInventory.InventoryAccountType,
		|	TableInventory.Products,
		|	TableInventory.Characteristic,
		|	TableInventory.Batch,
		|	TableInventory.Ownership,
		|	TableInventory.CostObject";
		
		QueryResult = Query.Execute();
		
		Block = New DataLock;
		LockItem = Block.Add("AccumulationRegister.Inventory");
		LockItem.Mode = DataLockMode.Exclusive;
		LockItem.DataSource = QueryResult;
		
		For Each ColumnQueryResult In QueryResult.Columns Do
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
		EndDo;
		Block.Lock();
		
		// Receiving inventory balances by cost.
		Query.Text =
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	InventoryBalances.Ownership AS Ownership,
		|	InventoryBalances.CostObject AS CostObject,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.Company AS Company,
		|		InventoryBalances.PresentationCurrency AS PresentationCurrency,
		|		InventoryBalances.StructuralUnit AS StructuralUnit,
		|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|		InventoryBalances.Products AS Products,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.Batch AS Batch,
		|		InventoryBalances.Ownership AS Ownership,
		|		InventoryBalances.CostObject AS CostObject,
		|		InventoryBalances.QuantityBalance AS QuantityBalance,
		|		InventoryBalances.AmountBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) In
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.PresentationCurrency,
		|						TableInventory.InventoryStructuralUnit,
		|						TableInventory.InventoryAccountType,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						TableInventory.Ownership,
		|						TableInventory.CostObject
		|					FROM
		|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventory.Company,
		|		DocumentRegisterRecordsInventory.PresentationCurrency,
		|		DocumentRegisterRecordsInventory.StructuralUnit,
		|		DocumentRegisterRecordsInventory.InventoryAccountType,
		|		DocumentRegisterRecordsInventory.Products,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		DocumentRegisterRecordsInventory.Batch,
		|		DocumentRegisterRecordsInventory.Ownership,
		|		DocumentRegisterRecordsInventory.CostObject,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.PresentationCurrency,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.InventoryAccountType,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch,
		|	InventoryBalances.Ownership,
		|	InventoryBalances.CostObject";
		
		Query.SetParameter("Ref", DocumentRefProduction);
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalances = QueryResult.Unload();
		TableInventoryBalances.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
		
		MainLanguageCode = CommonClientServer.DefaultLanguageCode();
		UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company", RowTableInventory.Company);
			StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
			StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
			StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
			StructureForSearch.Insert("Products", RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventory.Batch);
			StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
			StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
			
			Required_Quantity = RowTableInventory.Quantity;
			
			If Required_Quantity > 0 Then
				
				BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
				
				QuantityBalance = 0;
				AmountBalance = 0;
				
				If BalanceRowsArray.Count() > 0 Then
					
					QuantityBalance = BalanceRowsArray[0].QuantityBalance;
					AmountBalance = BalanceRowsArray[0].AmountBalance;
					
				EndIf;
				
				If QuantityBalance > 0 AND QuantityBalance > Required_Quantity Then
					
					AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
					
					BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Required_Quantity;
					BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
					
				ElsIf QuantityBalance = Required_Quantity Then
					
					AmountToBeWrittenOff = AmountBalance;
					
				Else
					AmountToBeWrittenOff = 0;
				EndIf;
				
				AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
				
				// Expense.
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				TableRowExpense.Amount = AmountToBeWrittenOff;
				TableRowExpense.Quantity = Required_Quantity;
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.SalesOrder = Undefined;
				
				// Receipt
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
					TableRowReceipt.CostObject = RowTableInventory.CostObjectCorr;
					TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
					TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
					TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventory.Batch;
					TableRowReceipt.OwnershipCorr = RowTableInventory.Ownership;
					TableRowReceipt.CostObjectCorr = RowTableInventory.CostObject;
					TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
					TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
					TableRowReceipt.CustomerCorrOrder = Undefined;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					// Generate postings.
					If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	Else
		
		TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
			
			Required_Quantity = RowTableInventory.Quantity;
			
			If Required_Quantity > 0 Then
				
				// Expense.
				TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				TableRowExpense.ProductionExpenses = True;
				TableRowExpense.SalesOrder = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN TableInventoryDemand.SalesOrder = UNDEFINED
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE TableInventoryDemand.SalesOrder
	|	END AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic,
	|	TableInventoryDemand.KitOrder AS ProductionDocument
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	// Receive balance.
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		InventoryDemandBalances.ProductionDocument AS ProductionDocument,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic, ProductionDocument) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						CASE
	|							WHEN TemporaryTableInventory.SalesOrder = UNDEFINED
	|								THEN VALUE(Document.SalesOrder.EmptyRef)
	|							ELSE TemporaryTableInventory.SalesOrder
	|						END AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic,
	|						TemporaryTableInventory.KitOrder AS ProductionDocument
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic,
	|		InventoryDemandBalances.ProductionDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		DocumentRegisterRecordsInventoryDemand.ProductionDocument,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
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
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(DocumentRefProduction.SalesOrder) Then
		Query.SetParameter("ControlTime",
			StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company, SalesOrder, Products, Characteristic, ProductionDocument");
	
	TemporaryTableInventoryDemand =
		StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder",		?(RowTablesForInventory.SalesOrder = Undefined,
			Documents.SalesOrder.EmptyRef(), RowTablesForInventory.SalesOrder));
		StructureForSearch.Insert("Products",		RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic",	RowTablesForInventory.Characteristic);
		StructureForSearch.Insert("ProductionDocument",	RowTablesForInventory.ProductionDocument);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 And BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Indexes.Add("RecordType,Company,Products,Characteristic");
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		TableRowReceipt.InventoryAccountType = RowTableInventoryProducts.CorrInventoryAccountType;
		TableRowReceipt.CorrInventoryAccountType = RowTableInventoryProducts.InventoryAccountType;
		
		// If the production order is filled in then check whether there are placed customers orders in the production order.
		If ValueIsFilled(RowTableInventoryProducts.KitOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			For Each RowAllocationArray In ArrayPropertiesProducts Do
				
				If RowAllocationArray.Quantity > 0 Then
					
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
					NewRowReservedTable.SalesOrder = RowAllocationArray.SalesOrder;
					NewRowReservedTable.Quantity = RowAllocationArray.Quantity;
					
				EndIf;
				
			EndDo;
			
		ElsIf ValueIsFilled(RowTableInventoryProducts.SalesOrder) Then
			
			NewRowReservedTable = TableReservedProducts.Add();
			FillPropertyValues(NewRowReservedTable, RowTableInventoryProducts);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackordersDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;

	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	TableProduction.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventoryReservation AS TableProduction
	|WHERE
	|	TableProduction.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|	AND TableProduction.SalesOrder REFS Document.SalesOrder
	|	AND TableProduction.ProductsStructuralUnitToWarehouse.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableProductRelease(TableProductReleasePre, StructureAdditionalProperties)
	
	TableProductRelease = DriveServer.EmptyProductReleaseTable();
	
		For n = 0 To TableProductReleasePre.Count() - 1 Do
			
			RowTableInventory = TableProductReleasePre[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SupplySource",	RowTableInventory.SupplySource);
			StructureForSearch.Insert("Products",		RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
			
			PlacedOrdersTable = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Copy(StructureForSearch);
			PlacedOrdersTable.Sort("SalesOrder");
			
			RowTableInventoryQuantity = RowTableInventory.Quantity;
			
			If PlacedOrdersTable.Count() > 0 Then
				
				For Each PlacedOrdersRow In PlacedOrdersTable Do
					
					If RowTableInventoryQuantity > 0 AND PlacedOrdersRow.Quantity >= RowTableInventoryQuantity Then
						
						// Reserve
						NewRowReservedTable = TableProductRelease.Add();
						FillPropertyValues(NewRowReservedTable, RowTableInventory);
						NewRowReservedTable.SalesOrder = PlacedOrdersRow.SalesOrder;
						NewRowReservedTable.Quantity = RowTableInventoryQuantity;
						
						RowTableInventoryQuantity = 0;
						
					ElsIf RowTableInventoryQuantity > 0 AND PlacedOrdersRow.Quantity < RowTableInventoryQuantity Then
						
						// Reserve
						NewRowReservedTable = TableProductRelease.Add();
						FillPropertyValues(NewRowReservedTable, RowTableInventory);
						NewRowReservedTable.SalesOrder = ?(ValueIsFilled(PlacedOrdersRow.SalesOrder), PlacedOrdersRow.SalesOrder, Undefined);
						NewRowReservedTable.Quantity = PlacedOrdersRow.Quantity;
						
						RowTableInventoryQuantity = RowTableInventoryQuantity - PlacedOrdersRow.Quantity;
						
					EndIf;
					
				EndDo;
				
			Else 
				NewRowReservedTable = TableProductRelease.Add();
				FillPropertyValues(NewRowReservedTable, RowTableInventory);
				
				NewRowReservedTable.Quantity = RowTableInventoryQuantity;
			EndIf;
			
		EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", TableProductRelease);
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefProduction, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

Procedure AddOfflineRecords(DocumentRefProduction, StructureAdditionalProperties)
	
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
	|	Inventory.CostObjectCorr AS CostObjectCorr
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND Inventory.OfflineRecord";
	
	Query.SetParameter("Recorder", DocumentRefProduction);
	
	QueryResult = Query.ExecuteBatch();
	
	InventoryRecords = QueryResult[0].Unload();
	
	For Each InventoryRecord In InventoryRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(NewRow, InventoryRecord);
	EndDo;
	
EndProcedure

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	OwnershipType = Common.ObjectAttributeValue(StructureData.Ownership, "OwnershipType");
	If OwnershipType = Enums.InventoryOwnershipTypes.CounterpartysInventory Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	Else
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	ParametersSet.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	ParametersSet.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Disposals");
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	ParametersSet.Add(Parameters);
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	#Region BatchCheckFillingParameters_Products
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	
	Warehouses = New Array;
	
	If DocObject.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.ProductsStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.InventoryStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	#Region BatchCheckFillingParameters_Inventory
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Inventory");
	
	Warehouses = New Array;
	
	If DocObject.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.InventoryStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Outbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	ElsIf DocObject.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		WarehouseData = New Structure;
		WarehouseData.Insert("Warehouse", DocObject.ProductsStructuralUnit);
		WarehouseData.Insert("TrackingArea", "Inbound_Transfer");
		Warehouses.Add(WarehouseData);
		
		Parameters.Insert("Warehouses", Warehouses);
		
	EndIf;
	
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

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function checks if the document is posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	// MultilingualSupport
	If PrintParams = Undefined Then
		LanguageCode = NationalLanguageSupportClientServer.DefaultLanguageCode();
	Else
		LanguageCode = PrintParams.LanguageCode;
	EndIf;

	If LanguageCode <> CurrentLanguage().LanguageCode Then 
		SessionParameters.LanguageCodeForOutput = LanguageCode;
	EndIf;
	// End MultilingualSupport
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionAssembly";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "GoodsContentForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationTypesProduction.Assembly Then
				
				Query.Text =
				"SELECT ALLOWED
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Inventory.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Inventory.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Inventory.Products.Description
				|			ELSE Production.Inventory.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbers.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Production AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				// MultilingualSupport
				DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
				// End MultilingualSupport
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
				
			Else
				
				Query.Text = 
				"SELECT ALLOWED
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Products.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Products.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Products.Products.Description
				|			ELSE Production.Products.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic AS Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbersProducts.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Production AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument";
				
				// MultilingualSupport
				DriveServer.ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
				// End MultilingualSupport
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbersProducts.Select();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Production_GoodsContentForm";
			
			Template = PrintManagement.PrintFormTemplate("Document.Production.PF_MXL_GoodsContentForm", LanguageCode);
			
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Production #%1 dated %2'; ru = 'Производство №%1 от %2';pl = 'Produkcja nr %1 z dn. %2';es_ES = 'Producción #%1 fechado %2';es_CO = 'Producción #%1 fechado %2';tr = '%1 no.''lu %2 tarihli üretim';it = 'Produzione #%1 con data %2';de = 'Produktion Nr %1 datiert %2'", LanguageCode),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=DD"));
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Date and time of printing: %1. User: %2'; ru = 'Дата и время печати: %1. Пользователь: %2';pl = 'Data i godzina wydruku: %1. Użytkownik: %2';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Druckens: %1. Benutzer: %2'", LanguageCode),
				CurrentSessionDate(),
				Users.CurrentUser());
				
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate objects printing forms.
//
// Incoming:
//	TemplateNames	- String	- Names of layouts separated
//	by commas ObjectsArray	- Array	- Array of refs to objects that
//	need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//	PrintFormsCollection - Values table - Generated
//	table documents OutputParameters	- Structure	- Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
		
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsContentForm") Then	
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"GoodsContentForm", 
			NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'"),
			PrintForm(ObjectsArray, PrintObjects, "GoodsContentForm", PrintParameters.Result));		
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote", PrintParameters.Result));
	EndIf;

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//	PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsContentForm";
	PrintCommand.Presentation				= NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
EndProcedure

#EndRegion

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#EndIf