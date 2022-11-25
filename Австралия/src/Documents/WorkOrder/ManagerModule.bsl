#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefWorkOrder, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.ExchangeRate AS ExchangeRate,
	|	WorkOrder.Multiplicity AS Multiplicity,
	|	WorkOrder.Date AS Date,
	|	WorkOrder.Start AS Start,
	|	WorkOrder.Finish AS Finish,
	|	WorkOrder.SalesStructuralUnit AS SalesStructuralUnit,
	|	WorkOrder.Responsible AS Responsible,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Counterparties.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrderStatuses.OrderStatus AS OrderStatus,
	|	WorkOrder.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	WorkOrder.InventoryWarehouse AS InventoryWarehouse,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Counterparties.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	WorkOrder.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	WorkOrder.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	WorkOrder.SalesRep AS SalesRep
	|INTO WorkOrderHeader
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON WorkOrder.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON WorkOrder.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|WHERE
	|	WorkOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	WorkOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	WorkOrderHeader.Responsible AS Responsible,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	WorkOrderWorks.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderWorks.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	WorkOrderWorks.Ref AS WorkOrder,
	|	WorkOrderWorks.Ref AS Document,
	|	WorkOrderHeader.Counterparty AS Counterparty,
	|	WorkOrderHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	WorkOrderHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	WorkOrderHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	WorkOrderHeader.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrderHeader.Contract AS Contract,
	|	WorkOrderHeader.SalesStructuralUnit AS DepartmentSales,
	|	WorkOrderWorks.Products.ProductsType AS ProductsType,
	|	WorkOrderWorks.Quantity AS Quantity,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN WorkOrderWorks.VATAmount * WorkOrderHeader.Multiplicity / WorkOrderHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN WorkOrderWorks.VATAmount * WorkOrderHeader.ExchangeRate / WorkOrderHeader.Multiplicity
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN WorkOrderWorks.Total * WorkOrderHeader.Multiplicity / WorkOrderHeader.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN WorkOrderWorks.Total * WorkOrderHeader.ExchangeRate / WorkOrderHeader.Multiplicity
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN WorkOrderWorks.VATAmount * WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN WorkOrderWorks.VATAmount * WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity / (WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN WorkOrderWorks.Total * WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN WorkOrderWorks.Total * WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity / (WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN WorkOrderHeader.IncludeVATInPrice
	|			THEN 0
	|		ELSE WorkOrderWorks.VATAmount
	|	END AS VATAmountDocCur,
	|	WorkOrderWorks.Total AS AmountDocCur,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN WorkOrderWorks.SalesTaxAmount * WorkOrderHeader.Multiplicity / WorkOrderHeader.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN WorkOrderWorks.SalesTaxAmount * WorkOrderHeader.ExchangeRate / WorkOrderHeader.Multiplicity
	|		END AS NUMBER(15, 2)) AS SalesTaxAmount,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN WorkOrderWorks.SalesTaxAmount * WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN WorkOrderWorks.SalesTaxAmount * WorkOrderHeader.ExchangeRate * WorkOrderHeader.ContractCurrencyMultiplicity / (WorkOrderHeader.ContractCurrencyExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS SalesTaxAmountCur,
	|	WorkOrderWorks.Quantity AS QuantityPlan,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderWorks.Ref.Closed AS Closed,
	|	WorkOrderWorks.Specification AS Specification,
	|	WorkOrderWorks.ConnectionKeyForMarkupsDiscounts AS ConnectionKeyForMarkupsDiscounts,
	|	WorkOrderHeader.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrderHeader.Start AS Start,
	|	WorkOrderWorks.StandardHours AS StandardHours,
	|	WorkOrderWorks.ConnectionKey AS ConnectionKey,
	|	WorkOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	WorkOrderHeader.SalesRep AS SalesRep
	|INTO TemporaryTableWorks
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderWorks.Ref = WorkOrderHeader.Ref
	|WHERE
	|	NOT WorkOrderWorks.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderWorks.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderWorks.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Ref AS Document,
	|	WorkOrderHeader.Counterparty AS Counterparty,
	|	WorkOrderHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	WorkOrderHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	WorkOrderHeader.Contract AS Contract,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	WorkOrderHeader.Start AS Start,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	WorkOrderHeader.SalesStructuralUnit AS DepartmentSales,
	|	WorkOrderHeader.Responsible AS Responsible,
	|	WorkOrderInventory.Products.ProductsType AS ProductsType,
	|	WorkOrderHeader.StructuralUnitReserve AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderInventory.StorageBin
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN WorkOrderInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	WorkOrderInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN WorkOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	WorkOrderInventory.Ref AS WorkOrder,
	|	UNDEFINED AS CorrOrder,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderInventory.Quantity
	|		ELSE WorkOrderInventory.Quantity * WorkOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderInventory.Reserve
	|		ELSE WorkOrderInventory.Reserve * WorkOrderInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	CAST(WorkOrderInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN WorkOrderHeader.ExchangeRate / WorkOrderHeader.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN WorkOrderHeader.Multiplicity / WorkOrderHeader.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	WorkOrderHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	WorkOrderHeader.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	WorkOrderHeader.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderInventory.ConnectionKey AS ConnectionKey,
	|	WorkOrderHeader.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTableProducts
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderInventory.Ref = WorkOrderHeader.Ref
	|WHERE
	|	NOT WorkOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderInventory.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderMaterials.LineNumber AS LineNumber,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	WorkOrderHeader.Start AS Start,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	WorkOrderMaterials.Ref AS Order,
	|	WorkOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderMaterials.StorageBin
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	WorkOrderHeader.InventoryWarehouse AS InventoryStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderMaterials.StorageBin
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN WorkOrderMaterials.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN CatalogInventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|						THEN WorkOrderMaterials.InventoryReceivedGLAccount
	|					ELSE WorkOrderMaterials.InventoryGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	WorkOrderMaterials.Products AS Products,
	|	WorkOrderWorks.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderWorks.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN WorkOrderMaterials.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	WorkOrderMaterials.Ownership AS Ownership,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS OwnershipCorr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS CorrInventoryAccountType,
	|	WorkOrderMaterials.RegisterExpense AS RegisterExpense,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	WorkOrderMaterials.ExpenseItem AS CorrIncomeAndExpenseItem,
	|	WorkOrderWorks.Specification AS SpecificationCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	WorkOrderMaterials.Ref AS WorkOrder,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderMaterials.Quantity
	|		ELSE WorkOrderMaterials.Quantity * WorkOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderMaterials.Reserve
	|		ELSE WorkOrderMaterials.Reserve * WorkOrderMaterials.MeasurementUnit.Factor
	|	END AS Reserve,
	|	0 AS Amount,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content,
	|	WorkOrderMaterials.Products.ProductsType AS ProductsType,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderMaterials.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
	|	WorkOrderMaterials.Products.BusinessLine AS BusinessLine,
	|	WorkOrderMaterials.ConnectionKey AS ConnectionKey
	|INTO TemporaryTableConsumables
	|FROM
	|	WorkOrderHeader AS WorkOrderHeader
	|		INNER JOIN Document.WorkOrder.Materials AS WorkOrderMaterials
	|		ON WorkOrderHeader.Ref = WorkOrderMaterials.Ref
	|		LEFT JOIN Document.WorkOrder.Works AS WorkOrderWorks
	|		ON WorkOrderHeader.Ref = WorkOrderWorks.Ref
	|			AND (WorkOrderMaterials.ConnectionKey = WorkOrderWorks.ConnectionKey)
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON (WorkOrderMaterials.Ownership = CatalogInventoryOwnership.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (WorkOrderMaterials.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON WorkOrderHeader.InventoryWarehouse = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	NOT WorkOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderMaterials.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderSerialNumbersMaterials.ConnectionKey AS ConnectionKey,
	|	WorkOrderSerialNumbersMaterials.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.WorkOrder.SerialNumbersMaterials AS WorkOrderSerialNumbersMaterials
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderSerialNumbersMaterials.Ref = WorkOrderHeader.Ref
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP WorkOrderHeader";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefWorkOrder);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("InventoryDistribution",	NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode));
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.ExecuteBatch();
	
	DriveServer.GenerateTransactionsTable(DocumentRefWorkOrder, StructureAdditionalProperties);
	
	GenerateTableInventoryInWarehouses(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableInventoryFlowCalendar(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableWorkOrders(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableSales(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableReservedProducts(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableReservedProductsExpense(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableTimesheet(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefWorkOrder, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefWorkOrder, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableSerialNumbers(DocumentRefWorkOrder, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefWorkOrder, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefWorkOrder, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefWorkOrder, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentObjectWorkOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryInWarehousesChange",
	// " " "RegisterRecordsWorkOrdersChange",
	// "RegisterRecordsInventoryDemandChange", "RegisterRecordsAccountsReceivableChange" contain records, execute
	// the control of balances.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsWorkOrdersChange 
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query;
		Query.Text = GenerateQueryTextBalancesInventory()
			+ GenerateQueryTextBalancesWorkOrders()
			+ GenerateQueryTextBalancesInventoryInWarehouses()
			+ GenerateQueryTextBalancesSerialNumbers()
			+ GenerateQueryTextBalancesReservedProducts();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		// Negative balance of inventory in the warehouse.
		ElsIf Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectWorkOrder, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance on work order.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Calculates earning amount for assignee row
//
//
Function ComputeEarningValueByRowAtServer(WorkCoefficients, WorkAmount, LPF, AmountLPF, EarningAndDeductionType, Size) Export
	
	If EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayFixedAmount Then
		
		Return Size;
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePay Then
		
		Return WorkCoefficients * Size * (LPF / AmountLPF);
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayPercent Then
		
		Return (WorkAmount / 100 * Size) * (LPF / AmountLPF);
		
	EndIf;
	
EndFunction

// Returns the row from TS Work to specified key
//
// TabularSectionWorks - TS of Work, wob order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function GetRowWorksByConnectionKey(TabularSectionWorks, ConnectionKey) Export
	
	ArrayFoundStrings = TabularSectionWorks.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
	Return ?(ArrayFoundStrings.Count() <> 1, Undefined, ArrayFoundStrings[0]);
	
EndFunction

// Returns the rows of Performers TS by received connection key
//
// Parameters:
//	TabularSectionPerformers - TS Performers of Work order document;
//	ConnectionKey - ConnectionKey attribute value.
//
Function GetRowsPerformersByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	Return TabularSectionPerformers.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
EndFunction

// Returns the amount of Performers LPC included in the Earning for specified work
// 
// Parameters:
//	TabularSectionPerformers - TS Performers of Work order document;
//	ConnectionKey - ConnectionKey attribute value.
//
Function ComputeLPFSumByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	If Not ValueIsFilled(ConnectionKey) Then
		
		Return 1;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT *
	|INTO CWT_Performers
	|FROM
	|	&TabularSection AS SalesOrderPerformers
	| WHERE SalesOrderPerformers.ConnectionKey = &ConnectionKey";
	
	Query.SetParameter("ConnectionKey", ConnectionKey);
	Query.SetParameter("TabularSection", TabularSectionPerformers.Unload());
	Query.Execute();
	
	Query.Text = 
	"SELECT
	|	SUM(CWT_Performers.LPR) AS AmountLPR
	|FROM
	|	CWT_Performers AS CWT_Performers";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then 
		
		Return 1;
		
	EndIf;
		
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return ?(Selection.AmountLPR = 0, 1, Selection.AmountLPR);
	
EndFunction

Function ArePerformersWithEmptyEarningSum(LaborAssignment) Export
	
	Var Errors;
	MessageTextTemplate = NStr("en = 'Hours worked of %1 in line %2 are incorrect.'; ru = 'Неправильно указаны часы отработки %1 в строке %2.';pl = 'Godziny przepracowane w %1 wierszu %2 są nieprawidłowe.';es_ES = 'Horas trabajadas de %1 en la línea %2 son incorrectas.';es_CO = 'Horas trabajadas de %1 en la línea %2 son incorrectas.';tr = '%2 satırındaki %1 için çalışılan saatler yanlış.';it = 'Le ore lavorate di %1 nella linea %2 non sono corrette.';de = 'Die Arbeitsstunden von %1 in der Zeile %2 sind falsch.'");
	
	For Each Performer In LaborAssignment Do
		
		If Performer.HoursWorked = 0 Then
			
			SingleErrorText = 
				StringFunctionsClientServer.SubstituteParametersToString(MessageTextTemplate, Performer.Employee.Description, Performer.LineNumber);
			
			CommonClientServer.AddUserError(
				Errors, 
				"Object.LaborAssignment[%1].HoursWorked", 
				SingleErrorText, 
				Undefined, 
				Performer.LineNumber - 1);
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(Errors) Then
		
		CommonClientServer.ReportErrorsToUser(Errors);
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringByWorkOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If (AttributeValues.Property("WorkOrderReturn") AND Constants.UseWorkOrderStatuses.Get())
			Or Not AttributeValues.Property("WorkOrderReturn") Then
			If AttributeValues.Closed Then
				ErrorText = NStr("en = '%1 is completed. Cannot use a completed order as a base document.'; ru = '%1 закрыт (выполнен). Ввод на основании закрытого заказа запрещен.';pl = '%1 jest zamknięty. Nie można użyć zamkniętego zamówienia jako dokumentu źródłowego.';es_ES = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';es_CO = '%1 se ha finalizado. No se puede utilizarlo un orden finalizado como un documento de base.';tr = '%1 tamamlandı. Tamamlanmış bir siparişi temel belge olarak kullanamazsınız.';it = '%1 è completato. Non è possibile usare un ordine completato come documento base.';de = '%1 ist abgeschlossen. Ein abgeschlossener Auftrag kann nicht als Basisdokument verwendet werden.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
				Raise ErrorText;
			EndIf;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document.'; ru = 'Документ %1 в состоянии %2. Ввод на основании запрещен.';pl = 'Ma %1 status %2. Nie można użyć go, jako dokumentu źródłowego.';es_ES = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';es_CO = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';tr = '%1 öğesinin durumu: %2. Temel belge olarak kullanılamaz.';it = 'Lo stato di %1 è %2. Non è possibile usarlo come documento di base.';de = 'Der Status von %1 ist %2. Kann nicht als Basisdokument verwendet werden.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData, AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
		If AttributeValues.Property("WorkOrderReturn") Then
			If AttributeValues.OrderState.OrderStatus <> Enums.OrderStatuses.Completed Then
				ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document for a return.'; ru = 'Документ %1 в состоянии %2. Ввод возврата от покупателя на основании запрещен.';pl = 'Ma %1 status %2. Nie można użyć go, jako dokumentu źródłowego dla zwrotu.';es_ES = 'El estado del %1 es %2. No se puede usarlo como el documento básico para la devolución.';es_CO = 'El estado del %1 es %2. No se puede usarlo como el documento básico para la devolución.';tr = '%1 durumu %2 şeklindedir. Bir iade için temel belge olarak kullanamıyor.';it = 'Lo stato di %1 è %2. Non è possibile usarlo come documento di base per una restituzione.';de = 'Der Status von %1 ist %2. Es kann nicht als Basisdokument für eine Reklamation verwendet werden.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
					FillingData,
					AttributeValues.OrderState);
				Raise ErrorText;
			EndIf;
		ElsIf AttributeValues.OrderState.OrderStatus <> Enums.OrderStatuses.InProcess Then
			ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document.'; ru = 'Документ %1 в состоянии %2. Ввод на основании запрещен.';pl = 'Ma %1 status %2. Nie można użyć go, jako dokumentu źródłowego.';es_ES = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';es_CO = 'El estado de %1 es %2. No se puede utilizarlo como un documento de base.';tr = '%1 öğesinin durumu: %2. Temel belge olarak kullanılamaz.';it = 'Lo stato di %1 è %2. Non è possibile usarlo come documento di base.';de = 'Der Status von %1 ist %2. Kann nicht als Basisdokument verwendet werden.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
				FillingData,
				AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
	EndIf;
	
EndProcedure

Function CanceledStatus() Export
	Return "Canceled";
EndFunction

Function InProcessStatus() Export
	Return "In process";
EndFunction

Function CompletedStatus() Export
	Return "Completed";
EndFunction

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Materials" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export
	
	Result = New Structure;
	If StructureData.TabName = "Materials" Then
		Result.Insert("ConsumptionGLAccount", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	If StructureData.TabName = "ConsumersInventory" Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	EndIf;
	If StructureData.TabName = "Materials" Then
		OwnershipType = Common.ObjectAttributeValue(StructureData.Ownership, "OwnershipType");
		If OwnershipType = Enums.InventoryOwnershipTypes.CounterpartysInventory Then
			GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
		EndIf;
	EndIf;
	If StructureData.TabName = "Materials" Or StructureData.TabName = "Inventory" Then
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		If StructureData.TabName = "Materials" Then
			GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
		EndIf;
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Materials");
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
	ParametersSet.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "ConsumersInventory");
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CounterpartysInventory);
	Parameters.Insert("Counterparty", DocObject.Counterparty);
	Parameters.Insert("Contract", DocObject.Contract);
	ParametersSet.Add(Parameters);
	
	Return ParametersSet;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Materials");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnitReserve);
	WarehouseData.Insert("TrackingArea", "Outbound_SalesToCustomer");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "WorkOrder") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection,
            "WorkOrder", 
            NStr("en = 'Work order'; ru = 'Заказ-наряд';pl = 'Zlecenie pracy';es_ES = 'Orden de trabajo';es_CO = 'Orden de trabajo';tr = 'İş emri';it = 'Commessa';de = 'Arbeitsauftrag'"), 
            PrintForm(ObjectsArray, PrintObjects, "WorkOrder", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WorkOrder";
	PrintCommand.Presentation				= NStr("en = 'Work order'; ru = 'Заказ-наряд';pl = 'Rozliczenie montażu';es_ES = 'Orden de trabajo';es_CO = 'Orden de trabajo';tr = 'İş emri';it = 'Commessa';de = 'Arbeitsauftrag'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.Order						= 1;
	
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
	
	If Not AccessRight("Edit", Metadata.Documents.WorkOrder) Then
		Return;
	EndIf;
	
	ResponsibleStructure = DriveServer.ResponsibleStructure();
	DocumentsCount = DocumentsCount(ResponsibleStructure.List);
	DocumentsID = "WorkOrder";
	
	// Work orders
	ToDo				= ToDoList.Add();
	ToDo.ID				= DocumentsID;
	ToDo.HasUserTasks	= (DocumentsCount.AllWorkOrders > 0);
	ToDo.Presentation	= NStr("en = 'Work orders'; ru = 'Заказы-наряды';pl = 'Zlecenia pracy';es_ES = 'Órdenes de trabajo';es_CO = 'Órdenes de trabajo';tr = 'İş emirleri';it = 'Commesse';de = 'Arbeitsaufträge'");
	ToDo.Owner			= Metadata.Subsystems.Services;
	
	// Fulfillment is expired
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "WorkOrdersExecutionExpired";
	ToDo.HasUserTasks	= (DocumentsCount.WorkOrdersExecutionExpired > 0);
	ToDo.Important		= True;
	ToDo.Presentation	= NStr("en = 'Fulfillment is expired'; ru = 'Срок исполнения заказа истек';pl = 'Wykonanie wygasło';es_ES = 'Se ha vencido el plazo de cumplimiento';es_CO = 'Se ha vencido el plazo de cumplimiento';tr = 'Yerine getirme süresi doldu';it = 'L''adempimento è in ritardo';de = 'Ausfüllung ist abgelaufen'");
	ToDo.Count			= DocumentsCount.WorkOrdersExecutionExpired;
	ToDo.Form			= "Document.WorkOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// In progress
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "WorkOrdersInWork";
	ToDo.HasUserTasks	= (DocumentsCount.WorkOrdersInWork > 0);
	ToDo.Presentation	= NStr("en = 'In progress'; ru = 'В работе';pl = 'W toku';es_ES = 'En progreso';es_CO = 'En progreso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'");
	ToDo.Count			= DocumentsCount.WorkOrdersInWork;
	ToDo.Form			= "Document.WorkOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
	// New
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("AreNew");
	OpenParameters.Insert("Responsible", ResponsibleStructure);
	
	ToDo				= ToDoList.Add();
	ToDo.ID				= "WorkNewOrders";
	ToDo.HasUserTasks	= (DocumentsCount.WorkNewOrders > 0);
	ToDo.Presentation	= NStr("en = 'New'; ru = 'Новый';pl = 'Nowy';es_ES = 'Nuevo';es_CO = 'Nuevo';tr = 'Yeni';it = 'Nuovo';de = 'Neu'");
	ToDo.Count			= DocumentsCount.WorkNewOrders;
	ToDo.Form			= "Document.WorkOrder.ListForm";
	ToDo.FormParameters	= OpenParameters;
	ToDo.Owner			= DocumentsID;
	
EndProcedure

// End StandardSubsystems.ToDoList

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure RefillSalesRecords() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Posted
	|
	|GROUP BY
	|	WorkOrder.Ref";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		DocObject = Selection.Ref.GetObject();
		
		BeginTransaction();
		
		Try
			
			DriveServer.InitializeAdditionalPropertiesForPosting(DocObject.Ref, DocObject.AdditionalProperties);
			Documents.WorkOrder.InitializeDocumentData(DocObject.Ref, DocObject.AdditionalProperties);
			
			TableSales = DocObject.AdditionalProperties.TableForRegisterRecords.TableSales;
			
			If Not DocObject.RegisterRecords.Sales.AdditionalProperties.Property("AllowEmptyRecords") Then
				DocObject.RegisterRecords.Sales.AdditionalProperties.Insert("AllowEmptyRecords", DocObject.AdditionalProperties.ForPosting.AllowEmptyRecords);
			EndIf;
			
			DocObject.RegisterRecords.Sales.Write = True;
			DocObject.RegisterRecords.Sales.Load(TableSales);
			InfobaseUpdate.WriteRecordSet(DocObject.RegisterRecords.Sales, True);
			
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
				Metadata.Documents.WorkOrder,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("OperationKind");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If Data.Number = Null Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If Data.Posted Then
		State = "";
	Else
		If Data.DeletionMark Then
			State = NStr("en = '(deleted)'; ru = '(удален)';pl = '(usunięty)';es_ES = '(borrado)';es_CO = '(borrado)';tr = '(silindi)';it = '(eliminato)';de = '(gelöscht)'");
		ElsIf Data.Property("Posted") AND Not Data.Posted Then
			State = NStr("en = '(not posted)'; ru = '(не проведен)';pl = '(niezaksięgowany)';es_ES = '(no enviado)';es_CO = '(no enviado)';tr = '(onaylanmadı)';it = '(non pubblicato)';de = '(nicht gebucht)'");
		EndIf;
	EndIf;
	
	TitlePresentation = NStr("en = 'Work order'; ru = 'Заказ-наряд';pl = 'Zlecenie pracy';es_ES = 'Orden de trabajo';es_CO = 'Orden de trabajo';tr = 'İş emri';it = 'Commessa';de = 'Arbeitsauftrag'");
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 dated %3 %4'; ru = '%1 %2 от %3 %4';pl = '%1 %2 z dn. %3 %4';es_ES = '%1 %2 fechado %3 %4';es_CO = '%1 %2 fechado %3 %4';tr = '%1 %2 tarihli %3 %4';it = '%1 %2 con data %3 %4';de = '%1 %2 datiert %3 %4'"),
		TitlePresentation,
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		State);
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

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

#Region TableGeneration

Procedure GenerateTableReservedProducts(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableProducts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.StructuralUnit AS StructuralUnit,
	|	TemporaryTableProducts.GLAccount AS GLAccount,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	TemporaryTableProducts.Batch AS Batch,
	|	TemporaryTableProducts.WorkOrder AS SalesOrder,
	|	TemporaryTableProducts.Reserve AS Quantity
	|INTO ProductsAndConsumablesTable
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|WHERE
	|	TemporaryTableProducts.Reserve > 0
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTableConsumables.LineNumber,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTableConsumables.Period,
	|	TemporaryTableConsumables.Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.WorkOrder,
	|	TemporaryTableConsumables.Reserve
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|WHERE
	|	(NOT &PostExpensesByWorkOrder
	|			OR TemporaryTableConsumables.OrderStatus <> VALUE(Enum.OrderStatuses.Completed))
	|	AND TemporaryTableConsumables.Reserve > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ProductsAndConsumablesTable.LineNumber) AS LineNumber,
	|	ProductsAndConsumablesTable.RecordType AS RecordType,
	|	ProductsAndConsumablesTable.Period AS Period,
	|	ProductsAndConsumablesTable.Company AS Company,
	|	ProductsAndConsumablesTable.StructuralUnit AS StructuralUnit,
	|	ProductsAndConsumablesTable.GLAccount AS GLAccount,
	|	ProductsAndConsumablesTable.Products AS Products,
	|	ProductsAndConsumablesTable.Characteristic AS Characteristic,
	|	ProductsAndConsumablesTable.Batch AS Batch,
	|	ProductsAndConsumablesTable.SalesOrder AS SalesOrder,
	|	SUM(ProductsAndConsumablesTable.Quantity) AS Quantity
	|FROM
	|	ProductsAndConsumablesTable AS ProductsAndConsumablesTable
	|
	|GROUP BY
	|	ProductsAndConsumablesTable.SalesOrder,
	|	ProductsAndConsumablesTable.StructuralUnit,
	|	ProductsAndConsumablesTable.Company,
	|	ProductsAndConsumablesTable.GLAccount,
	|	ProductsAndConsumablesTable.Characteristic,
	|	ProductsAndConsumablesTable.Batch,
	|	ProductsAndConsumablesTable.LineNumber,
	|	ProductsAndConsumablesTable.Period,
	|	ProductsAndConsumablesTable.Products,
	|	ProductsAndConsumablesTable.RecordType";
	
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableReservedProductsExpense(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.Text =
	"SELECT DISTINCT
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableConsumables.WorkOrder AS SalesOrder
	|INTO ReservedProductsTable
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|WHERE
	|	&PostExpensesByWorkOrder
	|	AND TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReservedProductsTable.Company AS Company,
	|	ReservedProductsTable.StructuralUnit AS StructuralUnit,
	|	ReservedProductsTable.Products AS Products,
	|	ReservedProductsTable.Characteristic AS Characteristic,
	|	ReservedProductsTable.Batch AS Batch,
	|	ReservedProductsTable.SalesOrder AS SalesOrder
	|FROM
	|	ReservedProductsTable AS ReservedProductsTable";
	
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
	|				&ControlTime,
	|				(Company, StructuralUnit, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						ReservedProductsTable.Company AS Company,
	|						ReservedProductsTable.StructuralUnit AS StructuralUnit,
	|						ReservedProductsTable.Products AS Products,
	|						ReservedProductsTable.Characteristic AS Characteristic,
	|						ReservedProductsTable.Batch AS Batch,
	|						ReservedProductsTable.SalesOrder AS SalesOrder
	|					FROM
	|						ReservedProductsTable AS ReservedProductsTable)) AS Balance
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
	|			INNER JOIN ReservedProductsTable AS ReservedProductsTable
	|			ON DocumentRegisterRecordsReservedProducts.Company = ReservedProductsTable.Company
	|				AND DocumentRegisterRecordsReservedProducts.StructuralUnit = ReservedProductsTable.StructuralUnit
	|				AND DocumentRegisterRecordsReservedProducts.Products = ReservedProductsTable.Products
	|				AND DocumentRegisterRecordsReservedProducts.Characteristic = ReservedProductsTable.Characteristic
	|				AND DocumentRegisterRecordsReservedProducts.Batch = ReservedProductsTable.Batch
	|				AND DocumentRegisterRecordsReservedProducts.SalesOrder = ReservedProductsTable.SalesOrder
	|	WHERE
	|		DocumentRegisterRecordsReservedProducts.Recorder = &Ref
	|		AND DocumentRegisterRecordsReservedProducts.Period <= &ControlPeriod) AS Balance
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
	|	TableConsumables.Period AS Period,
	|	TableConsumables.Company AS Company,
	|	TableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TableConsumables.GLAccount AS GLAccount,
	|	TableConsumables.Products AS Products,
	|	TableConsumables.Characteristic AS Characteristic,
	|	TableConsumables.Batch AS Batch,
	|	TableConsumables.WorkOrder AS SalesOrder,
	|	SUM(TableConsumables.Quantity) AS Quantity
	|INTO TemporaryTableConsumablesGrouped
	|FROM
	|	TemporaryTableConsumables AS TableConsumables
	|WHERE
	|	&PostExpensesByWorkOrder
	|	AND TableConsumables.Quantity > 0
	|	AND TableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|
	|GROUP BY
	|	TableConsumables.Period,
	|	TableConsumables.Company,
	|	TableConsumables.InventoryStructuralUnit,
	|	TableConsumables.GLAccount,
	|	TableConsumables.Products,
	|	TableConsumables.Characteristic,
	|	TableConsumables.Batch,
	|	TableConsumables.WorkOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableConsumables.Period AS Period,
	|	TableConsumables.Company AS Company,
	|	TableConsumables.StructuralUnit AS StructuralUnit,
	|	TableConsumables.GLAccount AS GLAccount,
	|	TableConsumables.Products AS Products,
	|	TableConsumables.Characteristic AS Characteristic,
	|	TableConsumables.Batch AS Batch,
	|	TableConsumables.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN Balance.Quantity > TableConsumables.Quantity
	|			THEN TableConsumables.Quantity
	|		ELSE Balance.Quantity
	|	END AS Quantity
	|INTO AvailableReserve
	|FROM
	|	TemporaryTableConsumablesGrouped AS TableConsumables
	|		INNER JOIN ReservedProductsBalance AS Balance
	|		ON TableConsumables.Company = Balance.Company
	|			AND TableConsumables.StructuralUnit = Balance.StructuralUnit
	|			AND TableConsumables.Products = Balance.Products
	|			AND TableConsumables.Characteristic = Balance.Characteristic
	|			AND TableConsumables.Batch = Balance.Batch
	|			AND TableConsumables.SalesOrder = Balance.SalesOrder
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
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableReservedProducts.Add();
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableConsumables.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableConsumables.Period AS Period,
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TemporaryTableConsumables.Cell AS Cell,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableConsumables.Ownership AS Ownership,
	|	TemporaryTableConsumables.Quantity AS Quantity
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|WHERE
	|	&PostExpensesByWorkOrder
	|	AND TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	MIN(TemporaryTableConsumables.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableConsumables.Period AS Period,
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnitCorr,
	|	TemporaryTableConsumables.GLAccount AS GLAccount,
	|	TemporaryTableConsumables.ConsumptionGLAccount AS CorrGLAccount,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableWorks.Products AS ProductsCorr,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableWorks.Characteristic AS CharacteristicCorr,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableWorks.Batch AS BatchCorr,
	|	TemporaryTableConsumables.Ownership AS Ownership,
	|	&OwnInventory AS OwnershipCorr,
	|	TemporaryTableConsumables.CostObject AS CostObject,
	|	TemporaryTableConsumables.InventoryAccountType AS InventoryAccountType,
	|	TemporaryTableConsumables.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TemporaryTableConsumables.RegisterExpense AS RegisterExpense,
	|	TemporaryTableConsumables.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TemporaryTableConsumables.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	TemporaryTableConsumables.BusinessLine AS BusinessLine,
	|	TemporaryTableConsumables.StructuralUnit AS Department,
	|	CASE
	|		WHEN TemporaryTableConsumables.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableConsumables.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableConsumables.WorkOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TemporaryTableConsumables.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableConsumables.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableConsumables.WorkOrder
	|	END AS CustomerCorrOrder,
	|	&InventoryConsumption AS ContentOfAccountingRecord,
	|	SUM(TemporaryTableConsumables.Quantity) AS Quantity,
	|	0 AS Amount,
	|	TemporaryTableWorks.Counterparty AS Counterparty,
	|	TemporaryTableWorks.DocumentCurrency AS Currency,
	|	TemporaryTableWorks.Responsible AS Responsible,
	|	TemporaryTableWorks.SalesRep AS SalesRep,
	|	FALSE AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|		LEFT JOIN TemporaryTableWorks AS TemporaryTableWorks
	|		ON TemporaryTableConsumables.ConnectionKey = TemporaryTableWorks.ConnectionKey
	|WHERE
	|	&PostExpensesByWorkOrder
	|	AND TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|
	|GROUP BY
	|	TemporaryTableConsumables.Period,
	|	TemporaryTableConsumables.Company,
	|	TemporaryTableConsumables.PresentationCurrency,
	|	TemporaryTableConsumables.StructuralUnit,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.Ownership,
	|	TemporaryTableConsumables.CostObject,
	|	TemporaryTableConsumables.InventoryAccountType,
	|	TemporaryTableConsumables.CorrInventoryAccountType,
	|	TemporaryTableConsumables.RegisterExpense,
	|	TemporaryTableConsumables.IncomeAndExpenseItem,
	|	TemporaryTableConsumables.CorrIncomeAndExpenseItem,
	|	TemporaryTableConsumables.WorkOrder,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.BusinessLine,
	|	TemporaryTableConsumables.ConsumptionGLAccount,
	|	TemporaryTableWorks.Products,
	|	TemporaryTableWorks.Characteristic,
	|	TemporaryTableWorks.Batch,
	|	TemporaryTableWorks.Counterparty,
	|	TemporaryTableWorks.DocumentCurrency,
	|	TemporaryTableWorks.Responsible,
	|	TemporaryTableWorks.SalesRep,
	|	TemporaryTableConsumables.InventoryStructuralUnit
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.StructuralUnitCorr,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.ProductsCorr,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.CharacteristicCorr,
	|	OfflineRecords.Batch,
	|	OfflineRecords.BatchCorr,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.OwnershipCorr,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	TRUE,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.CorrSalesOrder,
	|	UNDEFINED,
	|	OfflineRecords.Department,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.SalesRep,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableConsumables.Period AS Period,
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TemporaryTableConsumables.GLAccount AS GLAccount,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableConsumables.Ownership AS Ownership,
	|	TemporaryTableConsumables.CostObject AS CostObject,
	|	TemporaryTableConsumables.ConnectionKey AS ConnectionKey,
	|	SUM(TemporaryTableConsumables.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|WHERE
	|	&PostExpensesByWorkOrder
	|	AND TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|
	|GROUP BY
	|	TemporaryTableConsumables.Period,
	|	TemporaryTableConsumables.Company,
	|	TemporaryTableConsumables.PresentationCurrency,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.Ownership,
	|	TemporaryTableConsumables.CostObject,
	|	TemporaryTableConsumables.WorkOrder,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.ConnectionKey";
	
	Query.SetParameter("InventoryConsumption", NStr("en = 'Inventory consumption'; ru = 'Материалы';pl = 'Zużycie zapasów';es_ES = 'Consumación del inventario';es_CO = 'Consumación del inventario';tr = 'Stok tüketimi';it = 'Consumo di scorte';de = 'Bestandsverbrauch'", CommonClientServer.DefaultLanguageCode()));
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());

	Result = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", Result[0].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableConsumersInventoryForSales", Result[1].Unload());
	
	GenerateTableRowsInventory(DocumentRefWorkOrder, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableRowsInventory(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	TableIncomeAndExpenses = DriveServer.EmptyIncomeAndExpensesTable();
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableConsumables.Company AS Company,
	|	TableConsumables.PresentationCurrency AS PresentationCurrency,
	|	TableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TableConsumables.Products AS Products,
	|	TableConsumables.Characteristic AS Characteristic,
	|	TableConsumables.Batch AS Batch,
	|	TableConsumables.Ownership AS Ownership,
	|	TableConsumables.CostObject AS CostObject
	|FROM
	|	TemporaryTableConsumables AS TableConsumables";
	
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
	|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableConsumables.Company,
	|						TableConsumables.PresentationCurrency,
	|						TableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|						TableConsumables.Products,
	|						TableConsumables.Characteristic,
	|						TableConsumables.Batch,
	|						TableConsumables.Ownership,
	|						TableConsumables.CostObject
	|					FROM
	|						TemporaryTableConsumables AS TableConsumables)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.PresentationCurrency,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.CostObject,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsInventory.Quantity
	|			ELSE -DocumentRegisterRecordsInventory.Quantity
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsInventory.Amount
	|			ELSE -DocumentRegisterRecordsInventory.Amount
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		If RowTableInventory.OfflineRecord Then
			
			TableRowOffline = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowOffline, RowTableInventory);
			
		Else
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company", RowTableInventory.Company);
			StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
			StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
			StructureForSearch.Insert("Products", RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventory.Batch);
			StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
			StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
			
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
				
				// Expense.
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				If FillAmount Then
					TableRowExpense.Amount = AmountToBeWrittenOff;
				EndIf;
				
				TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
				TableRowExpense.SalesOrder = Undefined;
				TableRowExpense.StructuralUnitCorr = Undefined;
				TableRowExpense.Department = RowTableInventory.Department;
				TableRowExpense.SourceDocument = DocumentRefWorkOrder;
				TableRowExpense.CorrSalesOrder = RowTableInventory.SalesOrder;
				
				// Generate postings.
				If FillAmount And UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
					RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
					RowTableAccountingJournalEntries.AccountDr = RowTableInventory.CorrGLAccount;
					RowTableAccountingJournalEntries.AccountCr = RowTableInventory.GLAccount;
					RowTableAccountingJournalEntries.PlanningPeriod = Catalogs.PlanningPeriods.Actual;
					RowTableAccountingJournalEntries.Content = RowTableInventory.ContentOfAccountingRecord;
					
				EndIf;
				
				If FillAmount And RowTableInventory.RegisterExpense
					And (Round(AmountToBeWrittenOff, 2, 1) <> 0 Or QuantityRequiredAvailableBalance > 0) Then
					
					RowIncomeAndExpenses = TableIncomeAndExpenses.Add();
					FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
					RowIncomeAndExpenses.StructuralUnit = RowTableInventory.Department;
					RowIncomeAndExpenses.BusinessLine = RowTableInventory.BusinessLine;
					RowIncomeAndExpenses.SalesOrder = DocumentRefWorkOrder;
					RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
					RowIncomeAndExpenses.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
					RowIncomeAndExpenses.GLAccount = RowTableInventory.CorrGLAccount;
					
				EndIf;
				
				// Fill TableConsumersInventoryForSales
				If FillAmount Then
					ConsumersInventoryForSalesArray =
						StructureAdditionalProperties.TableForRegisterRecords.TableConsumersInventoryForSales.FindRows(StructureForSearch);
					For Each ConsumersInventoryForSalesLine In ConsumersInventoryForSalesArray Do
						
						If QuantityBalance > 0 And QuantityBalance > ConsumersInventoryForSalesLine.Quantity Then
							
							ConsumersInventoryForSalesLine.Amount = Round(AmountBalance * ConsumersInventoryForSalesLine.Quantity / QuantityBalance , 2, 1);
							
						ElsIf QuantityBalance = ConsumersInventoryForSalesLine.Quantity Then
							
							ConsumersInventoryForSalesLine.Amount = AmountBalance;
							
						Else
							
							ConsumersInventoryForSalesLine.Amount = 0;
							
						EndIf;
						
					EndDo;
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", TableIncomeAndExpenses);
	
EndProcedure

Procedure GenerateTableSales(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableConsumersInventoryForSales.Products AS Products,
	|	TableConsumersInventoryForSales.Characteristic AS Characteristic,
	|	TableConsumersInventoryForSales.Batch AS Batch,
	|	TableConsumersInventoryForSales.Ownership AS Ownership,
	|	TableConsumersInventoryForSales.CostObject AS CostObject,
	|	TableConsumersInventoryForSales.ConnectionKey AS ConnectionKey,
	|	TableConsumersInventoryForSales.Quantity AS Quantity,
	|	TableConsumersInventoryForSales.Amount AS Amount
	|INTO TableConsumersInventoryForSales
	|FROM
	|	&TableConsumersInventoryForSales AS TableConsumersInventoryForSales
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableWorks.Period AS Period,
	|	TemporaryTableWorks.Company AS Company,
	|	TemporaryTableWorks.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableWorks.Counterparty AS Counterparty,
	|	TemporaryTableWorks.DocumentCurrency AS Currency,
	|	TemporaryTableWorks.Products AS Products,
	|	TemporaryTableWorks.Characteristic AS Characteristic,
	|	TemporaryTableWorks.Batch AS Batch,
	|	&OwnInventory AS Ownership,
	|	TemporaryTableWorks.WorkOrder AS SalesOrder,
	|	TemporaryTableWorks.WorkOrder AS Document,
	|	TemporaryTableWorks.VATRate AS VATRate,
	|	TemporaryTableWorks.StructuralUnit AS Department,
	|	TemporaryTableWorks.Responsible AS Responsible,
	|	0 AS Quantity,
	|	0 AS VATAmount,
	|	0 AS Amount,
	|	0 AS VATAmountCur,
	|	0 AS AmountCur,
	|	0 AS SalesTaxAmount,
	|	0 AS SalesTaxAmountCur,
	|	SUM(TableConsumersInventoryForSales.Amount) AS Cost,
	|	FALSE AS OfflineRecord,
	|	TemporaryTableWorks.SalesRep AS SalesRep,
	|	NULL AS BundleProduct,
	|	NULL AS BundleCharacteristic,
	|	TemporaryTableWorks.Start AS DeliveryStartDate,
	|	TemporaryTableWorks.Finish AS DeliveryEndDate,
	|	FALSE AS ZeroInvoice
	|FROM
	|	TemporaryTableWorks AS TemporaryTableWorks
	|		INNER JOIN TableConsumersInventoryForSales AS TableConsumersInventoryForSales
	|		ON (TemporaryTableWorks.ConnectionKey = TableConsumersInventoryForSales.ConnectionKey AND &FillAmount AND &PostExpensesByWorkOrder)
	|
	|GROUP BY
	|	TemporaryTableWorks.Period,
	|	TemporaryTableWorks.Company,
	|	TemporaryTableWorks.PresentationCurrency,
	|	TemporaryTableWorks.Counterparty,
	|	TemporaryTableWorks.DocumentCurrency,
	|	TemporaryTableWorks.Products,
	|	TemporaryTableWorks.Characteristic,
	|	TemporaryTableWorks.Batch,
	|	TemporaryTableWorks.WorkOrder,
	|	TemporaryTableWorks.VATRate,
	|	TemporaryTableWorks.StructuralUnit,
	|	TemporaryTableWorks.Responsible,
	|	TemporaryTableWorks.SalesRep,
	|	TemporaryTableWorks.Start,
	|	TemporaryTableWorks.Finish,
	|	TemporaryTableWorks.WorkOrder
	|
	|UNION ALL
	|
	|SELECT
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.Currency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Batch,
	|	TableSales.Ownership,
	|	TableSales.SalesOrder,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible,
	|	TableSales.Quantity,
	|	TableSales.VATAmount,
	|	TableSales.Amount,
	|	TableSales.VATAmountCur,
	|	TableSales.AmountCur,
	|	TableSales.SalesTaxAmount,
	|	TableSales.SalesTaxAmountCur,
	|	TableSales.Cost,
	|	TableSales.OfflineRecord,
	|	TableSales.SalesRep,
	|	TableSales.BundleProduct,
	|	TableSales.BundleCharacteristic,
	|	TableSales.DeliveryStartDate,
	|	TableSales.DeliveryEndDate,
	|	TableSales.ZeroInvoice
	|FROM
	|	AccumulationRegister.Sales AS TableSales
	|WHERE
	|	TableSales.Recorder = &Ref
	|	AND TableSales.OfflineRecord";
	
	Query.SetParameter("TableConsumersInventoryForSales", StructureAdditionalProperties.TableForRegisterRecords.TableConsumersInventoryForSales);
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("FillAmount", StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableWorkOrders(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("PostExpensesByWorkOrder", StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder);
	Query.Text =
	"SELECT
	|	MIN(TableWorkOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableWorkOrders.Period AS Period,
	|	TableWorkOrders.Company AS Company,
	|	TableWorkOrders.Products AS Products,
	|	TableWorkOrders.Characteristic AS Characteristic,
	|	TableWorkOrders.WorkOrder AS WorkOrder,
	|	SUM(TableWorkOrders.QuantityPlan) AS Quantity,
	|	TableWorkOrders.Start AS ShipmentDate
	|FROM
	|	TemporaryTableWorks AS TableWorkOrders
	|
	|GROUP BY
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	TableWorkOrders.Start
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableWorkOrders.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	SUM(TableWorkOrders.Quantity),
	|	TableWorkOrders.Start
	|FROM
	|	(SELECT
	|		TableProducts.LineNumber AS LineNumber,
	|		TableProducts.Period AS Period,
	|		TableProducts.Company AS Company,
	|		TableProducts.Products AS Products,
	|		TableProducts.Characteristic AS Characteristic,
	|		TableProducts.WorkOrder AS WorkOrder,
	|		TableProducts.Quantity AS Quantity,
	|		TableProducts.Start AS Start
	|	FROM
	|		TemporaryTableProducts AS TableProducts
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableMaterials.LineNumber,
	|		TableMaterials.Period,
	|		TableMaterials.Company,
	|		TableMaterials.Products,
	|		TableMaterials.Characteristic,
	|		TableMaterials.Order,
	|		TableMaterials.Quantity,
	|		TableMaterials.Start
	|	FROM
	|		TemporaryTableConsumables AS TableMaterials
	|	WHERE
	|		(NOT &PostExpensesByWorkOrder
	|				OR TableMaterials.OrderStatus <> VALUE(Enum.OrderStatuses.Completed))) AS TableWorkOrders
	|
	|GROUP BY
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	TableWorkOrders.Start";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", 					DocumentRefWorkOrder);
	Query.SetParameter("PointInTime", 			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", 				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", 	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("AdvanceDates",			PaymentTermsServer.PaymentInAdvanceDates());
	
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Start AS ShipmentDate,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.PaymentMethod AS PaymentMethod,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.PettyCash AS PettyCash,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.BankAccount AS BankAccount,
	|	WorkOrder.Closed AS Closed,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrder.ExchangeRate AS ExchangeRate,
	|	WorkOrder.Multiplicity AS Multiplicity,
	|	WorkOrder.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	WorkOrder.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	WorkOrder.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref = &Ref
	|	AND WorkOrder.SetPaymentTerms
	|	AND NOT WorkOrder.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderPaymentCalendar.PaymentDate AS Period,
	|	Document.PaymentMethod AS PaymentMethod,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN WorkOrderPaymentCalendar.PaymentAmount
	|		ELSE WorkOrderPaymentCalendar.PaymentAmount + WorkOrderPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON Document.OrderState = WorkOrderStatuses.Ref
	|			AND (WorkOrderStatuses.OrderStatus IN (VALUE(Enum.OrderStatuses.InProcess), VALUE(Enum.OrderStatuses.Completed)))
	|		INNER JOIN Document.WorkOrder.PaymentCalendar AS WorkOrderPaymentCalendar
	|		ON Document.Ref = WorkOrderPaymentCalendar.Ref
	|			AND WorkOrderPaymentCalendar.PaymentBaselineDate IN (&AdvanceDates)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableTimesheet(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Date AS Period,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.SalesStructuralUnit AS StructuralUnit,
	|	WorkOrderLaborAssignment.Employee AS Employee,
	|	WorkOrderLaborAssignment.PayCode AS TimeKind,
	|	WorkOrderLaborAssignment.HoursWorked AS Hours,
	|	WorkOrderLaborAssignment.Position AS Position
	|FROM
	|	Document.WorkOrder.LaborAssignment AS WorkOrderLaborAssignment
	|		INNER JOIN Document.WorkOrder AS WorkOrder
	|			INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|			ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|		ON WorkOrderLaborAssignment.Ref = WorkOrder.Ref
	|WHERE
	|	WorkOrderLaborAssignment.Ref = &Ref
	|	AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTimesheet", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	WorkOrders.Finish AS Period,
	|	MIN(WorkOrderConsumersInventory.LineNumber) AS LineNumber,
	|	WorkOrders.Company AS Company,
	|	WorkOrderConsumersInventory.Products AS Products,
	|	WorkOrderConsumersInventory.Characteristic AS Characteristic,
	|	WorkOrderConsumersInventory.Batch AS Batch,
	|	WorkOrders.Counterparty AS Counterparty,
	|	SUM(WorkOrderConsumersInventory.Quantity) AS Quantity,
	|	CAST(&InventoryIncreaseProductsOnCommission AS STRING(100)) AS ContentOfAccountingRecord,
	|	WorkOrderConsumersInventory.Ref AS Order
	|FROM
	|	Document.WorkOrder.ConsumersInventory AS WorkOrderConsumersInventory
	|		INNER JOIN Document.WorkOrder AS WorkOrders
	|			INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|			ON WorkOrders.OrderState = WorkOrderStatuses.Ref
	|		ON WorkOrderConsumersInventory.Ref = WorkOrders.Ref
	|WHERE
	|	WorkOrderConsumersInventory.Ref = &Ref
	|	AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|	AND WorkOrders.WriteOffCustomersInventory
	|
	|GROUP BY
	|	WorkOrders.Finish,
	|	WorkOrders.Company,
	|	WorkOrderConsumersInventory.Products,
	|	WorkOrderConsumersInventory.Characteristic,
	|	WorkOrderConsumersInventory.Batch,
	|	WorkOrders.Counterparty,
	|	WorkOrderConsumersInventory.Ref";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("InventoryIncreaseProductsOnCommission", NStr("en = 'Customer''s inventory'; ru = 'Материалы заказчика';pl = 'Zapasy nabywcy';es_ES = 'Inventario del cliente';es_CO = 'Inventario del cliente';tr = 'Müşteri stoku';it = 'Scorte del cliente';de = 'Kundenbestand'", CommonClientServer.DefaultLanguageCode()));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryFlowCalendar(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableProducts.LineNumber AS LineNumber,
	|	BEGINOFPERIOD(TableProducts.Start, Day) AS Period,
	|	TableProducts.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableProducts.WorkOrder AS Order,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Quantity AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableMaterials.LineNumber,
	|	BEGINOFPERIOD(TableMaterials.Start, Day),
	|	TableMaterials.Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	TableMaterials.Order,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.Quantity
	|FROM
	|	TemporaryTableConsumables AS TableMaterials
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.PostExpensesByWorkOrder
		Or DocumentRefWorkOrder.SerialNumbersMaterials.Count() = 0 Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableConsumables.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableConsumables.Ownership AS Ownership,
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS StructuralUnit,
	|	TemporaryTableConsumables.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableConsumables.ConnectionKeySerialNumbers = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TemporaryTableConsumables.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableConsumables.ConnectionKeySerialNumbers = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultsArray[1].Unload());
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", ResultsArray[0].Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", New ValueTable);

EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion 

// Function returns query text by the balance of Inventory register.
//
Function GenerateQueryTextBalancesInventory()
	
	QueryText =
	"SELECT
	|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
	|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
	|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrencyPresentation,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsInventoryChange.InventoryAccountType AS InventoryAccountTypePresentation,
	|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
	|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
	|	RegisterRecordsInventoryChange.Ownership AS OwnershipPresentation,
	|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
	|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
	|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
	|FROM
	|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
	|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
	|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
	|			AND RegisterRecordsInventoryChange.PresentationCurrency = InventoryBalances.PresentationCurrency
	|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
	|			AND RegisterRecordsInventoryChange.InventoryAccountType = InventoryBalances.InventoryAccountType
	|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
	|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
	|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
	|			AND RegisterRecordsInventoryChange.Ownership = InventoryBalances.Ownership
	|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
	|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Function returns query text by the balance of WorkOrders register.
//
Function GenerateQueryTextBalancesWorkOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsWorkOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsWorkOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsWorkOrdersChange.WorkOrder AS OrderPresentation,
	|	RegisterRecordsWorkOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsWorkOrdersChange.Characteristic AS CharacteristicPresentation,
	|	WorkOrdersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsWorkOrdersChange.QuantityChange, 0) + ISNULL(WorkOrdersBalance.QuantityBalance, 0) AS BalanceWorkOrders,
	|	ISNULL(WorkOrdersBalance.QuantityBalance, 0) AS QuantityBalanceWorkOrders
	|FROM
	|	RegisterRecordsWorkOrdersChange AS RegisterRecordsWorkOrdersChange
	|		INNER JOIN AccumulationRegister.WorkOrders.Balance(&ControlTime, ) AS WorkOrdersBalance
	|		ON RegisterRecordsWorkOrdersChange.Company = WorkOrdersBalance.Company
	|			AND RegisterRecordsWorkOrdersChange.Products = WorkOrdersBalance.Products
	|			AND RegisterRecordsWorkOrdersChange.Characteristic = WorkOrdersBalance.Characteristic
	|			AND (ISNULL(WorkOrdersBalance.QuantityBalance, 0) < 0)
	|			AND RegisterRecordsWorkOrdersChange.WorkOrder = WorkOrdersBalance.WorkOrder
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Function returns query text by the balance of InventoryInWarehouses register.
//
Function GenerateQueryTextBalancesInventoryInWarehouses()
	
	QueryText =
	"SELECT
	|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
	|	RegisterRecordsInventoryInWarehousesChange.Company AS CompanyPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.Products AS ProductsPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.Batch AS BatchPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.Ownership AS OwnershipPresentation,
	|	RegisterRecordsInventoryInWarehousesChange.Cell AS PresentationCell,
	|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	InventoryInWarehousesOfBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
	|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
	|FROM
	|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
	|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(
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
	|			AND (ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Function returns query text by the balance of SerialNumbers register.
//
Function GenerateQueryTextBalancesSerialNumbers()
	
	QueryText =
	"SELECT
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
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

// Function returns query text by the balance of ReservedProducts register.
//
Function GenerateQueryTextBalancesReservedProducts()
	
	QueryText =
	"SELECT
	|	RegisterRecordsReservedProductsChange.LineNumber AS LineNumber,
	|	RegisterRecordsReservedProductsChange.Company AS CompanyPresentation,
	|	RegisterRecordsReservedProductsChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsReservedProductsChange.Products AS ProductsPresentation,
	|	RegisterRecordsReservedProductsChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsReservedProductsChange.Batch AS BatchPresentation,
	|	RegisterRecordsReservedProductsChange.SalesOrder AS SalesOrderPresentation,
	|	RegisterRecordsReservedProductsChange.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	RegisterRecordsReservedProductsChange.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsReservedProductsChange.QuantityChange, 0) + ISNULL(ReservedProductsBalances.QuantityBalance, 0) AS BalanceInventory,
	|	ISNULL(ReservedProductsBalances.QuantityBalance, 0) AS QuantityBalanceInventory
	|FROM
	|	RegisterRecordsReservedProductsChange AS RegisterRecordsReservedProductsChange
	|		INNER JOIN AccumulationRegister.ReservedProducts.Balance(&ControlTime, ) AS ReservedProductsBalances
	|		ON RegisterRecordsReservedProductsChange.Company = ReservedProductsBalances.Company
	|			AND RegisterRecordsReservedProductsChange.StructuralUnit = ReservedProductsBalances.StructuralUnit
	|			AND RegisterRecordsReservedProductsChange.Products = ReservedProductsBalances.Products
	|			AND RegisterRecordsReservedProductsChange.Characteristic = ReservedProductsBalances.Characteristic
	|			AND RegisterRecordsReservedProductsChange.Batch = ReservedProductsBalances.Batch
	|			AND RegisterRecordsReservedProductsChange.SalesOrder = ReservedProductsBalances.SalesOrder
	|			AND (ISNULL(ReservedProductsBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + DriveClientServer.GetQueryDelimeter();
	
EndFunction

#Region ToDoList

Function DocumentsCount(EmployeesList)
	
	Result = New Structure;
	Result.Insert("WorkOrdersExecutionExpired",	0);
	Result.Insert("WorkNewOrders",				0);
	Result.Insert("WorkOrdersInWork",			0);
	Result.Insert("AllWorkOrders",				0);

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrder.Posted
	|					AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND NOT RunSchedule.Order IS NULL
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN WorkOrder.Ref
	|		END) AS WorkOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN UseWorkOrderStatuses.Value
	|				THEN CASE
	|						WHEN WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|							THEN WorkOrder.Ref
	|					END
	|			ELSE CASE
	|					WHEN NOT WorkOrder.Posted
	|							AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|						THEN WorkOrder.Ref
	|				END
	|		END) AS WorkNewOrders,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrder.Posted
	|					AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN WorkOrder.Ref
	|		END) AS WorkOrdersInWork,
	|	COUNT(DISTINCT WorkOrder.Ref) AS AllWorkOrders
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON WorkOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref,
	|	Constant.UseWorkOrderStatuses AS UseWorkOrderStatuses
	|WHERE
	|	NOT WorkOrder.Closed
	|	AND WorkOrder.Responsible IN(&EmployeesList)
	|	AND NOT WorkOrder.DeletionMark";
	
	Query.SetParameter("EmployeesList",							EmployeesList);
	Query.SetParameter("StartOfDayIfCurrentDateTimeSession",	BegOfDay(CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		FillPropertyValues(Result, SelectionDetailRecords);
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function of document printing.
Function GetQueryText()
	
	Result = 
	"SELECT ALLOWED
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Number AS Number,
	|	WorkOrder.Date AS Date,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.CompanyVATNumber AS CompanyVATNumber,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.Start AS ExpectedDate,
	|	CAST(WorkOrder.Comment AS STRING(1024)) AS Comment,
	|	WorkOrder.Location AS ShippingAddress,
	|	WorkOrder.ContactPerson AS ContactPerson,
	|	WorkOrder.Equipment AS Equipment,
	|	CAST(WorkOrder.WorkDescription AS STRING(1024)) AS WorkDescription,
	|	CAST(WorkOrder.Terms AS STRING(1024)) AS Terms,
	|	WorkOrder.SerialNumber AS SerialNumber,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT
	|INTO WorkOrderTable
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderTable.Ref AS Ref,
	|	WorkOrderTable.Number AS DocumentNumber,
	|	WorkOrderTable.Date AS DocumentDate,
	|	WorkOrderTable.Company AS Company,
	|	WorkOrderTable.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	WorkOrderTable.Counterparty AS Counterparty,
	|	WorkOrderTable.Contract AS Contract,
	|	CASE
	|		WHEN WorkOrderTable.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN WorkOrderTable.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	WorkOrderTable.DocumentCurrency AS DocumentCurrency,
	|	WorkOrderTable.ExpectedDate AS ExpectedDate,
	|	WorkOrderTable.Comment AS Comment,
	|	WorkOrderTable.ShippingAddress AS ShippingAddress,
	|	WorkOrderTable.Equipment AS Equipment,
	|	WorkOrderTable.WorkDescription AS WorkDescription,
	|	WorkOrderTable.Terms AS Terms,
	|	WorkOrderTable.SerialNumber AS SerialNumber
	|INTO Header
	|FROM
	|	WorkOrderTable AS WorkOrderTable
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON WorkOrderTable.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON WorkOrderTable.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON WorkOrderTable.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderInventory.Ref AS Ref,
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Products AS Products,
	|	WorkOrderInventory.Characteristic AS Characteristic,
	|	WorkOrderInventory.Batch AS Batch,
	|	WorkOrderInventory.Quantity AS Quantity,
	|	WorkOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN WorkOrderInventory.Quantity = 0
	|			THEN 0
	|		ELSE CASE
	|				WHEN WorkOrderInventory.DiscountMarkupPercent > 0
	|						OR WorkOrderInventory.AutomaticDiscountAmount > 0
	|					THEN (WorkOrderInventory.Price * WorkOrderInventory.Quantity - WorkOrderInventory.AutomaticDiscountAmount - WorkOrderInventory.Price * WorkOrderInventory.Quantity * WorkOrderInventory.DiscountMarkupPercent / 100) / WorkOrderInventory.Quantity
	|				ELSE WorkOrderInventory.Price
	|			END
	|	END AS Price,
	|	WorkOrderInventory.Price AS PurePrice,
	|	WorkOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderInventory.Amount AS Amount,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.VATAmount AS VATAmount,
	|	WorkOrderInventory.Total AS Total,
	|	CAST(WorkOrderInventory.Content AS STRING(1024)) AS Content,
	|	WorkOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderInventory.ConnectionKey AS ConnectionKey,
	|	WorkOrderInventory.BundleProduct AS BundleProduct,
	|	WorkOrderInventory.BundleCharacteristic AS BundleCharacteristic,
	|	VATRates.Rate AS NumberVATRate,
	|	WorkOrderInventory.DiscountMarkupPercent + WorkOrderInventory.AutomaticDiscountsPercent AS DiscountsPercent,
	|	WorkOrderTable.AmountIncludesVAT AS AmountIncludesVAT,
	|	CAST(WorkOrderInventory.Quantity * WorkOrderInventory.Price - WorkOrderInventory.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredInventory
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderInventory.Ref = WorkOrderTable.Ref
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON WorkOrderInventory.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderWorks.Ref AS Ref,
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderWorks.Products AS Products,
	|	WorkOrderWorks.Characteristic AS Characteristic,
	|	CAST(WorkOrderWorks.Content AS STRING(1024)) AS Content,
	|	CAST(WorkOrderWorks.Quantity AS NUMBER(15, 3)) AS Quantity,
	|	CASE
	|		WHEN WorkOrderWorks.Quantity = 0
	|			THEN 0
	|		ELSE WorkOrderWorks.Amount / (CAST(WorkOrderWorks.Quantity AS NUMBER(15, 3)))
	|	END AS Price,
	|	WorkOrderWorks.Price AS PurePrice,
	|	WorkOrderWorks.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderWorks.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderWorks.Amount AS Amount,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	WorkOrderWorks.VATAmount AS VATAmount,
	|	WorkOrderWorks.Total AS Total,
	|	WorkOrderWorks.ConnectionKey AS ConnectionKey,
	|	WorkOrderWorks.DiscountMarkupPercent + WorkOrderWorks.AutomaticDiscountsPercent AS DiscountsPercent,
	|	WorkOrderTable.AmountIncludesVAT AS AmountIncludesVAT,
	|	VATRates.Rate AS NumberVATRate,
	|	CAST(WorkOrderWorks.Quantity * WorkOrderWorks.Price - WorkOrderWorks.Amount AS NUMBER(15, 2)) AS DiscountAmount
	|INTO FilteredWorks
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderWorks.Ref = WorkOrderTable.Ref
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON WorkOrderWorks.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FALSE AS IsWorks,
	|	FilteredInventory.Ref AS Ref,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN FilteredInventory.Content <> """"
	|			THEN FilteredInventory.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	FilteredInventory.Content <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	SUM(CASE
	|			WHEN &IsDiscount
	|				THEN CASE
	|						WHEN FilteredInventory.AmountIncludesVAT
	|							THEN CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|						ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice AS NUMBER(15, 2))
	|					END
	|			ELSE CASE
	|					WHEN FilteredInventory.AmountIncludesVAT
	|						THEN CAST((FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredInventory.Quantity * FilteredInventory.PurePrice - FilteredInventory.DiscountAmount AS NUMBER(15, 2))
	|				END
	|		END * CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE 1
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	CatalogProducts.IsFreightService AS IsFreightService,
	|	FilteredInventory.BundleProduct AS BundleProduct,
	|	FilteredInventory.BundleCharacteristic AS BundleCharacteristic,
	|	FilteredInventory.DiscountsPercent AS DiscountsPercent,
	|	FilteredInventory.PurePrice AS PurePrice,
	|	SUM(CASE
	|			WHEN FilteredInventory.AmountIncludesVAT
	|				THEN CAST(FilteredInventory.DiscountAmount / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.DiscountAmount
	|		END) AS DiscountAmount,
	|	SUM(CASE
	|			WHEN FilteredInventory.AmountIncludesVAT
	|				THEN CAST((FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount) / (1 + FilteredInventory.NumberVATRate / 100) AS NUMBER(15, 2))
	|			ELSE FilteredInventory.PurePrice * FilteredInventory.Quantity - FilteredInventory.DiscountAmount
	|		END) AS NetAmount
	|INTO Tabular
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredInventory.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON FilteredInventory.Batch = CatalogBatches.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON FilteredInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN FilteredInventory.Content <> """"
	|			THEN FilteredInventory.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	FilteredInventory.Content <> """",
	|	FilteredInventory.Ref,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	CatalogProducts.IsFreightService,
	|	FilteredInventory.BundleProduct,
	|	FilteredInventory.BundleCharacteristic,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredInventory.PurePrice
	|		ELSE FilteredInventory.Price
	|	END,
	|	FilteredInventory.Price,
	|	FilteredInventory.DiscountsPercent,
	|	FilteredInventory.PurePrice
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	FilteredWorks.Ref,
	|	FilteredWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN FilteredWorks.Content <> """"
	|			THEN FilteredWorks.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	FilteredWorks.Content <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	FilteredWorks.Quantity,
	|	CASE
	|		WHEN &IsPriceBeforeDiscount
	|			THEN FilteredWorks.PurePrice
	|		ELSE FilteredWorks.Price
	|	END,
	|	FilteredWorks.AutomaticDiscountAmount,
	|	FilteredWorks.DiscountMarkupPercent,
	|	FilteredWorks.Amount,
	|	FilteredWorks.VATRate,
	|	FilteredWorks.VATAmount,
	|	FilteredWorks.Total,
	|	CASE
	|		WHEN &IsDiscount
	|			THEN CASE
	|					WHEN FilteredWorks.AmountIncludesVAT
	|						THEN CAST(FilteredWorks.Quantity * FilteredWorks.PurePrice / (1 + FilteredWorks.NumberVATRate / 100) AS NUMBER(15, 2))
	|					ELSE CAST(FilteredWorks.Quantity * FilteredWorks.PurePrice AS NUMBER(15, 2))
	|				END
	|		ELSE CASE
	|				WHEN FilteredWorks.AmountIncludesVAT
	|					THEN CAST((FilteredWorks.Quantity * FilteredWorks.PurePrice - FilteredWorks.DiscountAmount) / (1 + FilteredWorks.NumberVATRate / 100) AS NUMBER(15, 2))
	|				ELSE CAST(FilteredWorks.Quantity * FilteredWorks.PurePrice - FilteredWorks.DiscountAmount AS NUMBER(15, 2))
	|			END
	|	END * CASE
	|		WHEN CatalogProducts.IsFreightService
	|			THEN 0
	|		ELSE 1
	|	END,
	|	FilteredWorks.Products,
	|	FilteredWorks.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogProducts.MeasurementUnit,
	|	CatalogProducts.IsFreightService,
	|	NULL,
	|	NULL,
	|	FilteredWorks.DiscountsPercent,
	|	FilteredWorks.PurePrice,
	|	CASE
	|		WHEN FilteredWorks.AmountIncludesVAT
	|			THEN CAST((FilteredWorks.Quantity * FilteredWorks.PurePrice - FilteredWorks.Amount) / (1 + FilteredWorks.NumberVATRate / 100) AS NUMBER(15, 2))
	|		ELSE CAST(FilteredWorks.Quantity * FilteredWorks.PurePrice - FilteredWorks.Amount AS NUMBER(15, 2))
	|	END,
	|	CASE
	|		WHEN FilteredWorks.AmountIncludesVAT
	|			THEN CAST((FilteredWorks.PurePrice * FilteredWorks.Quantity - FilteredWorks.DiscountAmount) / (1 + FilteredWorks.NumberVATRate / 100) AS NUMBER(15, 2))
	|		ELSE FilteredWorks.PurePrice * FilteredWorks.Quantity - FilteredWorks.DiscountAmount
	|	END
	|FROM
	|	FilteredWorks AS FilteredWorks
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredWorks.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredWorks.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderConsumersInventory.Products AS Products,
	|	WorkOrderConsumersInventory.Characteristic AS Characteristic,
	|	WorkOrderConsumersInventory.Batch AS Batch,
	|	WorkOrderConsumersInventory.MeasurementUnit AS MeasurementUnit,
	|	WorkOrderConsumersInventory.Quantity AS Quantity,
	|	WorkOrderConsumersInventory.Ref AS Ref
	|INTO FilteredConsumersInventory
	|FROM
	|	Document.WorkOrder.ConsumersInventory AS WorkOrderConsumersInventory
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderConsumersInventory.Ref = WorkOrderTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.IsWorks AS IsWorks,
	|	Tabular.Ref AS Ref,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	Tabular.DiscountsPercent AS DiscountPercent,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.DiscountAmount AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM,
	|	Tabular.BundleProduct AS BundleProduct,
	|	Tabular.BundleCharacteristic AS BundleCharacteristic,
	|	Tabular.Products AS Products,
	|	Tabular.NetAmount AS NetAmount
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Ref,
	|	IsWorks,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ExpectedDate AS ExpectedDate,
	|	Header.Comment AS Comment,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.Equipment AS Equipment,
	|	Header.WorkDescription AS WorkDescription,
	|	Header.Terms AS Terms,
	|	Header.SerialNumber AS SerialNumber
	|FROM
	|	Header AS Header
	|
	|ORDER BY
	|	DocumentNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(DocumentCurrency),
	|	MAX(ExpectedDate),
	|	MAX(Comment),
	|	MAX(ShippingAddress),
	|	MAX(Equipment),
	|	MAX(WorkDescription),
	|	MAX(Terms),
	|	MAX(SerialNumber)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredConsumersInventory.Ref AS Ref,
	|	FilteredConsumersInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS Unit,
	|	FilteredConsumersInventory.Quantity AS Quantity,
	|	FALSE AS ContentUsed,
	|	FilteredConsumersInventory.Products AS Products,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	FilteredConsumersInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	FilteredConsumersInventory.Batch AS Batch,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription
	|FROM
	|	FilteredConsumersInventory AS FilteredConsumersInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredConsumersInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredConsumersInventory.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON FilteredConsumersInventory.Batch = CatalogBatches.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON FilteredConsumersInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON FilteredConsumersInventory.MeasurementUnit = CatalogUOMClassifier.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	WorkOrderLaborAssignment.Employee AS Employee,
	|	WorkOrderLaborAssignment.HoursWorked AS HoursWorked,
	|	WorkOrderLaborAssignment.Ref AS Ref
	|FROM
	|	Document.WorkOrder.LaborAssignment AS WorkOrderLaborAssignment
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderLaborAssignment.Ref = WorkOrderTable.Ref";
	
	Return Result;
	
EndFunction

Function PrintWorkOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams)
	
	DisplayPrintOption = (PrintParams <> Undefined);
	
	StructureFlags			= DriveServer.GetStructureFlags(DisplayPrintOption, PrintParams);
	StructureSecondFlags	= DriveServer.GetStructureSecondFlags(DisplayPrintOption, PrintParams);
	CounterShift			= DriveServer.GetCounterShift(StructureFlags);
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_WorkOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.SetParameter("IsPriceBeforeDiscount", StructureSecondFlags.IsPriceBeforeDiscount);
	Query.SetParameter("IsDiscount", StructureFlags.IsDiscount);
	
	#Region PrintWorkOrderQueryText
	
	Query.Text = GetQueryText();
	
	#EndRegion
	
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
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	InventoryWorks		= ResultArray[6].Unload();
	Header 				= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	ConsumersInventory	= ResultArray[8].Unload();
	LaborAssignment		= ResultArray[9].Unload();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_WorkOrder";
		
		Template = PrintManagement.PrintFormTemplate("Document.WorkOrder.PF_MXL_WorkOrder", LanguageCode);
		
		#Region PrintWorkOrderTitleArea
		
		StringNameLineArea = "Title";
		
		TitleArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		TitleArea.Parameters.Fill(Header);
		
		IsPictureLogo = False;
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
				IsPictureLogo = True;
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		If IsPictureLogo Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
		EndIf;
		
		#EndRegion
		
		#Region PrintWorkOrderCompanyInfoArea
		
		StringNameLineArea = "CompanyInfo";
		
		CompanyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.DocumentDate, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		IsPictureBarcode = GetFunctionalOption("UseBarcodesInPrintForms");	
		If IsPictureBarcode Then
			DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.DocumentBarcode, CounterShift - 1);
		EndIf;
		
		#EndRegion
		
		#Region PrintWorkOrderCounterpartyInfoArea
		
		StringNameLineArea = "CounterpartyInfo";
		
		CounterpartyInfoArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.DocumentDate,
			,
			,
			,
			LanguageCode);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
		InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
		If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
			CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
		EndIf;
		
		If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
			CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
		EndIf;
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitleStagesOfPayment(Header.Ref);
		If ValueIsFilled(CounterpartyInfoArea.Parameters.PaymentTerms) Then
			CounterpartyInfoArea.Parameters.PaymentTermsTitle = PaymentTermsServer.PaymentTermsPrintTitle();
		EndIf;
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintWorkOrderEquipmentSectionArea
		
		StringNameLineArea = "EquipmentSection";
		
		EquipmentSectionArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		EquipmentSectionArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(EquipmentSectionArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintWorkOrderWorkDescriptionSectionArea
		
		StringNameLineArea = "WorkDescriptionSection";
		
		WorkDescriptionSectionArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		WorkDescriptionSectionArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(WorkDescriptionSectionArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintWorkOrderCommentArea
		
		StringNameLineArea = "Comment";
		
		CommentArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
		
		#EndRegion
		
		#Region PrintWorkOrderTermsArea
		
		StringNameLineArea = "Terms";
		
		TermsArea = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
		TermsArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TermsArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			SpreadsheetDocument,
			CounterShift,
			StringNameLineArea,
			"PartAdditional" + StringNameLineArea);
			
		#EndRegion
		
		#Region PrintWorkOrderLinesArea
		
		PageNumber = 0;
		
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		Parameters = New Structure;
		Parameters.Insert("Template",				Template);
		Parameters.Insert("SpreadsheetDocument",	SpreadsheetDocument);
		Parameters.Insert("TitleArea",				TitleArea);
		Parameters.Insert("Header",					Header);
		Parameters.Insert("Tabular",				InventoryWorks.Copy(New Structure("Ref, IsWorks", Header.Ref, False)));
		Parameters.Insert("IsWorks",				False);
		Parameters.Insert("IsLaborAssignment",		False);
		Parameters.Insert("StructureFlags",			StructureFlags);
		Parameters.Insert("StructureSecondFlags",	StructureSecondFlags);
		Parameters.Insert("CounterShift",			CounterShift);
		Parameters.Insert("IsPictureLogo",			IsPictureLogo);
			
		PutTabularIntoSpreadsheetDocument(
			Parameters, 
			PageNumber, 
			DisplayPrintOption, 
			PrintParams);
		
		Parameters.Tabular			= InventoryWorks.Copy(New Structure("Ref, IsWorks", Header.Ref, True));
		Parameters.IsWorks			= True;
		
		PutTabularIntoSpreadsheetDocument(
			Parameters, 
			PageNumber, 
			DisplayPrintOption, 
			PrintParams);
		
		#EndRegion
		
		#Region PrintWorkOrderLaborAssignmentArea
		
		Parameters.Tabular				= LaborAssignment.Copy(New Structure("Ref", Header.Ref));
		Parameters.IsLaborAssignment	= True;
		
		PutAdditionalTabular(Parameters, PageNumber);
		
		#EndRegion
		
		#Region PrintWorkOrderConsumersInventoryArea
		
		Parameters.Tabular				= ConsumersInventory.Copy(New Structure("Ref", Header.Ref));
		Parameters.IsLaborAssignment	= False;
		
		PutAdditionalTabular(Parameters, PageNumber);
		
		#EndRegion
		
		AreasToBeChecked = New Array;
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		#Region PrintAdditionalAttributes
		If DisplayPrintOption And PrintParams.AdditionalAttributes
			And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			StringNameLineArea = "AdditionalAttributesStaticHeader";
			
			AddAttribHeader = Template.GetArea(StringNameLineArea + "|PartStart" + StringNameLineArea);
			SpreadsheetDocument.Put(AddAttribHeader);
			
			DriveServer.AddPartAdditionalToAreaWithShift(
				Template,
				SpreadsheetDocument,
				CounterShift,
				StringNameLineArea,
				"PartAdditional" + StringNameLineArea);
			
			SpreadsheetDocument.Put(EmptyLineArea);
			
			AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
			SpreadsheetDocument.Put(AddAttribHeader);
			
			AddAttribRow = Template.GetArea("AdditionalAttributesRow");
			
			For each Attr In Header.Ref.AdditionalAttributes Do
				AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
				AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
				SpreadsheetDocument.Put(AddAttribRow);
			EndDo;
		EndIf;
		#EndRegion
		
		For i = 1 To 50 Do
			
			If NOT Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Procedure PutTabularIntoSpreadsheetDocument(Parameters, PageNumber, DisplayPrintOption, PrintParams)
	
	Template				= Parameters.Template;
	SpreadsheetDocument		= Parameters.SpreadsheetDocument;
	TitleArea				= Parameters.TitleArea;
	Header					= Parameters.Header;
	Tabular					= Parameters.Tabular;
	IsWorks					= Parameters.IsWorks;
	CounterShift			= Parameters.CounterShift;
	StructureFlags			= Parameters.StructureFlags;
	StructureSecondFlags	= Parameters.StructureSecondFlags;
	IsPictureLogo			= Parameters.IsPictureLogo;
	
	If Tabular.Count() > 0 Then
		
		SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		#Region WorkOrderTotalsAreaPrefill 
		
		TotalsAreasArray = New Array;
		TotalsArea = New SpreadsheetDocument;
		
		StringNameLineTotalArea = ?(StructureFlags.IsDiscount, "LineTotal", "LineTotalWithoutDiscount");
		
		StringNameTotalAreaStart		= ?(StructureFlags.IsDiscount, "PartStartLineTotal", "PartStartLineTotalWithoutDiscount");
		StringNameTotalAreaAdditional	= ?(StructureFlags.IsDiscount, "PartAdditional", "PartAdditionalWithoutDiscount");
		StringNameTotalAreaEnd			= ?(StructureFlags.IsDiscount, "PartEndLineTotal", "PartEndLineTotalWithoutDiscount");
		
		LineTotalArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaStart);
		LineTotalArea.Parameters.Fill(Header);
		
		LineTotalArea.Parameters.Quantity		= Tabular.Total("Quantity");
		LineTotalArea.Parameters.LineNumber		= Tabular.Count(); 
		
		TotalsArea.Put(LineTotalArea);
		
		DriveServer.AddPartAdditionalToAreaWithShift(
			Template,
			TotalsArea,
			CounterShift + 1,
			StringNameLineTotalArea,
			"PartAdditional" + StringNameLineTotalArea);
			
		LineTotalEndArea = Template.GetArea(StringNameLineTotalArea + "|" + StringNameTotalAreaEnd);
		LineTotalEndArea.Parameters.Fill(Header);
		
		LineTotalEndArea.Parameters.Subtotal		= Tabular.Total("Subtotal");
		LineTotalEndArea.Parameters.VATAmount		= Tabular.Total("VATAmount");
		LineTotalEndArea.Parameters.Total			= Tabular.Total("Total");
		
		If StructureFlags.IsDiscount Then
			LineTotalEndArea.Parameters.DiscountAmount	= Tabular.Total("DiscountAmount");
		EndIf;
		
		TotalsArea.Join(LineTotalEndArea);
		
		TotalsAreasArray.Add(TotalsArea);
		
		#EndRegion
		
		TabularHeaderArea = Template.GetArea(?(IsWorks, "WorksHeader", "PartsHeader"));
		
		#Region WorkOrderConfirmationLinesArea
		
		CounterBundle = DriveServer.GetCounterBundle();
		
		If DisplayPrintOption 
			And PrintParams.CodesPosition <> Enums.CodesPositionInPrintForms.SeparateColumn Then
			
			StringNameLineHeader	= "LineHeaderWithoutCode";
			StringNameLineSection	= "LineSectionWithoutCode";
			
			StringPostfix 			= "LineWithoutCode";
			
		Else
			
			StringNameLineHeader	= "LineHeader";
			StringNameLineSection	= "LineSection";
			
			StringPostfix 			= "Line";
			
		EndIf;
		
		StringNameStartPart		= "PartStart"+StringPostfix;
		StringNamePrice			= ?(StructureSecondFlags.IsPriceBeforeDiscount, "PartPriceBefore", "PartPrice")+StringPostfix;
		StringNameVATPart		= "PartVAT"+StringPostfix;
		StringNameDiscount		= "PartDiscount"+StringPostfix;
		StringNameNetAmount		= "PartNetAmount"+StringPostfix;
		StringNameTotalPart		= "PartTotal"+StringPostfix;
		
		// Start
		LineHeaderAreaStart		= Template.GetArea(StringNameLineHeader + "|" + StringNameStartPart);
		LineSectionAreaStart	= Template.GetArea(StringNameLineSection + "|" + StringNameStartPart);
		
		// Price
		LineHeaderAreaPrice = Template.GetArea(StringNameLineHeader + "|" + StringNamePrice);
		LineSectionAreaPrice = Template.GetArea(StringNameLineSection + "|" + StringNamePrice);
		
		// Discount 
		If StructureFlags.IsDiscount Then
			LineHeaderAreaDiscount = Template.GetArea(StringNameLineHeader + "|" + StringNameDiscount);
			LineSectionAreaDiscount = Template.GetArea(StringNameLineSection + "|" + StringNameDiscount);
		EndIf;
		
		// Tax
		If StructureSecondFlags.IsTax Then
			LineHeaderAreaVAT		= Template.GetArea(StringNameLineHeader + "|" + StringNameVATPart);
			LineSectionAreaVAT		= Template.GetArea(StringNameLineSection + "|" + StringNameVATPart);
		EndIf;
		
		// Net amount
		If StructureFlags.IsNetAmount Then
			LineHeaderAreaNetAmount = Template.GetArea(StringNameLineHeader + "|" + StringNameNetAmount);
			LineSectionAreaNetAmount = Template.GetArea(StringNameLineSection + "|" + StringNameNetAmount);
		EndIf;
		
		// Total
		If StructureFlags.IsLineTotal Then
			LineHeaderAreaTotal		= Template.GetArea(StringNameLineHeader + "|" + StringNameTotalPart);
			LineSectionAreaTotal	= Template.GetArea(StringNameLineSection + "|" + StringNameTotalPart);
		EndIf;
		
		// Bundles
		TableColumns = Tabular.Columns;
		Tabular = BundlesServer.AssemblyTableByBundles(Header.Ref, Tabular, TableColumns, LineTotalArea);
		EmptyColor = LineSectionAreaStart.CurrentArea.TextColor;
		// End Bundles
		
		IsFirstLine = True;
		
		PricePrecision = PrecisionAppearancetServer.CompanyPrecision(Header.Company);
		
		For Each Row In Tabular Do
			
			LineSectionAreaStart.Parameters.Fill(Row);
			LineSectionAreaPrice.Parameters.Fill(Row);
			LineSectionAreaPrice.Parameters.Price = Format(Row.Price,
				"NFD= " + PricePrecision);
			
			If StructureFlags.IsDiscount Then
				
				If Not Row.DiscountPercent = Undefined Then
					LineSectionAreaDiscount.Parameters.SignPercent = "%";
				Else
					LineSectionAreaDiscount.Parameters.SignPercent = "";
				EndIf;
				
				LineSectionAreaDiscount.Parameters.Fill(Row);
				
			EndIf;
			
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Parameters.Fill(Row);
			EndIf;
			
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.Parameters.Fill(Row);
			EndIf;
			
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.Parameters.Fill(Row);
			EndIf;
			
			DriveClientServer.ComplimentProductDescription(LineSectionAreaStart.Parameters.ProductDescription, Row);
			
			// Display selected codes if functional option is turned on.
			If DisplayPrintOption Then
				CodesPresentation = PrintManagementServerCallDrive.GetCodesPresentation(PrintParams, Row.Products);
				If PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.SeparateColumn Then
					LineSectionAreaStart.Parameters.SKU = CodesPresentation;
				ElsIf PrintParams.CodesPosition = Enums.CodesPositionInPrintForms.ProductColumn Then
					LineSectionAreaStart.Parameters.ProductDescription = 
						LineSectionAreaStart.Parameters.ProductDescription + Chars.CR + CodesPresentation;
				EndIf;
			EndIf;
			
			// Bundles

			BundleColor =  BundlesServer.GetBundleComponentsColor(Row, EmptyColor);
			
			LineSectionAreaStart.Area(1,1,1,CounterBundle).TextColor = BundleColor;
			LineSectionAreaPrice.CurrentArea.TextColor = BundleColor;
			If StructureFlags.IsDiscount Then
				LineSectionAreaDiscount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureSecondFlags.IsTax Then
				LineSectionAreaVAT.Area(1,1,1,2).TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsNetAmount Then
				LineSectionAreaNetAmount.CurrentArea.TextColor = BundleColor;
			EndIf;
			If StructureFlags.IsLineTotal Then
				LineSectionAreaTotal.CurrentArea.TextColor = BundleColor;
			EndIf;
			
			// End Bundles
			
			AreasToBeChecked = New Array;
			If IsFirstLine Then
				AreasToBeChecked.Add(TabularHeaderArea);
				AreasToBeChecked.Add(LineHeaderAreaStart);
			EndIf;
			AreasToBeChecked.Add(LineSectionAreaStart);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				If IsFirstLine Then
					
					SpreadsheetDocument.Put(TabularHeaderArea);
					
					SpreadsheetDocument.Put(LineHeaderAreaStart);
					SpreadsheetDocument.Join(LineHeaderAreaPrice);
					If StructureFlags.IsDiscount Then
						SpreadsheetDocument.Join(LineHeaderAreaDiscount);
					EndIf;
					If StructureSecondFlags.IsTax Then
						SpreadsheetDocument.Join(LineHeaderAreaVAT);
					EndIf;
					If StructureFlags.IsNetAmount Then
						SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
					EndIf;
					If StructureFlags.IsLineTotal Then
						SpreadsheetDocument.Join(LineHeaderAreaTotal);
					EndIf;
					
				EndIf;
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If NOT Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				
				#Region PrintWorkOrderTitleArea
				
				SpreadsheetDocument.Put(TitleArea);
				
				StringNameLineArea = "Title";
				DriveServer.AddPartAdditionalToAreaWithShift(
					Template,
					SpreadsheetDocument,
					CounterShift,
					StringNameLineArea,
					"PartAdditional" + StringNameLineArea); 
					
				If IsPictureLogo Then
					DriveServer.MakeShiftPictureWithShift(SpreadsheetDocument.Drawings.Logo, CounterShift - 1);
				EndIf;
				
				#EndRegion
				
				// Header
				
				SpreadsheetDocument.Put(TabularHeaderArea);
				
				SpreadsheetDocument.Put(LineHeaderAreaStart);
				SpreadsheetDocument.Join(LineHeaderAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineHeaderAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineHeaderAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineHeaderAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineHeaderAreaTotal);
				EndIf;
				
				// Section
				
				SpreadsheetDocument.Put(LineSectionAreaStart);
				SpreadsheetDocument.Join(LineSectionAreaPrice);
				If StructureFlags.IsDiscount Then
					SpreadsheetDocument.Join(LineSectionAreaDiscount);
				EndIf;
				If StructureSecondFlags.IsTax Then
					SpreadsheetDocument.Join(LineSectionAreaVAT);
				EndIf;
				If StructureFlags.IsNetAmount Then
					SpreadsheetDocument.Join(LineSectionAreaNetAmount);
				EndIf;
				If StructureFlags.IsLineTotal Then
					SpreadsheetDocument.Join(LineSectionAreaTotal);
				EndIf;
				
			EndIf;
			
			If IsFirstLine Then
				IsFirstLine = False;
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure PutAdditionalTabular(Parameters, PageNumber)
	
	Template			= Parameters.Template;
	SpreadsheetDocument	= Parameters.SpreadsheetDocument;
	TitleArea			= Parameters.TitleArea;
	Tabular				= Parameters.Tabular;
	IsLaborAssignment	= Parameters.IsLaborAssignment;
	StructureFlags		= Parameters.StructureFlags;
	CounterShift		= Parameters.CounterShift;
	
	If Tabular.Count() Then
	
		SeeNextPageArea	= DriveServer.GetAreaDocumentFooters(Template, "SeeNextPage", CounterShift);
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= DriveServer.GetAreaDocumentFooters(Template, "PageNumber", CounterShift);
		
		If IsLaborAssignment Then
			SectionArea	= Template.GetArea("LaborSection");
			HeaderArea	= Template.GetArea("LaborHeader");
		Else
			SectionArea	= Template.GetArea("CustomersInventorySection");
			HeaderArea	= Template.GetArea("CustomersInventoryHeader");
		EndIf;
		
		SpreadsheetDocument.Put(HeaderArea);
		
		// Bundles
		TableColumns = Tabular.Columns;
		Tabular = BundlesServer.AssemblyTableByBundles(Parameters.Header.Ref, Tabular, TableColumns);
		// End Bundles
		
		AreasToBeChecked = New Array;
		
		For Each Row In Tabular Do
			
			SectionArea.Parameters.Fill(Row);
			
			If NOT IsLaborAssignment Then
				DriveClientServer.ComplimentProductDescription(SectionArea.Parameters.ProductDescription, Row);
			EndIf;
			
			AreasToBeChecked.Add(SectionArea);
			AreasToBeChecked.Add(SeeNextPageArea);
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(SectionArea);
				AreasToBeChecked.Clear();
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If NOT Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(HeaderArea);
				SpreadsheetDocument.Put(SectionArea);
				
				AreasToBeChecked.Clear();
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "WorkOrder" Then
		
		Return PrintWorkOrder(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

#EndRegion

#EndIf