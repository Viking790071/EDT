#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryWriteOff, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	Header.Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Cell AS Cell,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.Correspondence
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS Correspondence,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PrimaryChartOfAccounts.TypeOfAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrespondenceTypeOfAccount,
	|	Header.RetireInventoryFromOperation AS RetireInventoryFromOperation
	|INTO Header
	|FROM
	|	Document.InventoryWriteOff AS Header
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON Header.Correspondence = PrimaryChartOfAccounts.Ref
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryWriteOffInventory.LineNumber AS LineNumber,
	|	InventoryWriteOffInventory.ConnectionKey AS ConnectionKey,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	Header.Ref AS Ref,
	|	Header.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.Cell AS Cell,
	|	Header.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryWriteOffInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	InventoryWriteOffInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryWriteOffInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN InventoryWriteOffInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN VALUETYPE(InventoryWriteOffInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryWriteOffInventory.Quantity
	|		ELSE InventoryWriteOffInventory.Quantity * InventoryWriteOffInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	Header.Correspondence AS AccountDr,
	|	Header.Correspondence AS Correspondence,
	|	Header.CorrespondenceTypeOfAccount AS CorrespondenceTypeOfAccount,
	|	CASE
	|		WHEN Header.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|			THEN VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN InventoryWriteOffInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	&InventoryWriteOff AS ContentOfAccountingRecord,
	|	InventoryWriteOffInventory.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|INTO TemporaryTableInventory
	|FROM
	|	Document.InventoryWriteOff.Inventory AS InventoryWriteOffInventory
	|		INNER JOIN Header AS Header
	|		ON InventoryWriteOffInventory.Ref = Header.Ref
	|		INNER JOIN Catalog.BusinessUnits AS StructuralUnitRef
	|		ON (Header.StructuralUnit = StructuralUnitRef.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON InventoryWriteOffInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (Header.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	TableInventory.ExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS SalesOrder,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount) AS Amount,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Ref AS SourceDocument,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.Correspondence AS CorrGLAccount,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	FALSE AS ProductionExpenses,
	|	FALSE AS OfflineRecord,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ExpenseItem,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Ref,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.Correspondence,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.ContentOfAccountingRecord
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
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.CorrGLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.ProductionExpenses,
	|	OfflineRecords.OfflineRecord,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Ownership AS Ownership
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Expense) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Cell AS Cell,
	|	TableInventory.Ownership AS Ownership,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN Document.InventoryWriteOff.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS Ref,
	|	SUM(Inventory.Amount) AS Amount
	|INTO AmountOfExpenses
	|FROM
	|	TemporaryTableInventory AS Inventory
	|
	|GROUP BY
	|	Inventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	Header.ExpenseItem AS IncomeAndExpenseItem,
	|	Header.Correspondence AS GLAccount,
	|	0 AS AmountIncome,
	|	Expenses.Amount AS AmountExpense,
	|	&ReceiptExpenses AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	AmountOfExpenses AS Expenses
	|		INNER JOIN Header AS Header
	|		ON (Header.Ref = Expenses.Ref)
	|		INNER JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|		ON (Header.ExpenseItem = IncomeAndExpenseItems.Ref)
	|WHERE
	|	Expenses.Amount > 0
	|	AND IncomeAndExpenseItems.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	AccountingPolicy = StructureAdditionalProperties.AccountingPolicy;
	
	Query.SetParameter("Ref"    , DocumentRefInventoryWriteOff);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("UseCharacteristics"        , AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseStorageBins"            , AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseBatches"                , AccountingPolicy.UseBatches);
	Query.SetParameter("PresentationCurrency"      , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseSerialNumbers"          , AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseDefaultTypeOfAccounting", AccountingPolicy.UseDefaultTypeOfAccounting);
	
	FillAmount = (AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryWriteOff", NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'", MainLanguageCode));
	Query.SetParameter("ReceiptExpenses"  , NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'"     , MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[3].Unload());
	
	// Serial numbers
	QueryResult4 = ResultsArray[4].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult4);
	If AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult4);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[6].Unload());
	
	// Generate an empty table of postings.
	DriveServer.GenerateTransactionsTable(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	
	If FillAmount Then
		// Calculation of the inventory write-off cost.
		GenerateTableInventory(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
		GenerateTableIncomeAndExpenses(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		If Not FillAmount Then
			TableAccountingJournalEntries = AccountingOfflineRecords(DocumentRefInventoryWriteOff);
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
		EndIf;
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefInventoryWriteOff, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryWriteOff, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
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
		|	REFPRESENTATION(Product.MeasurementUnit) AS MeasurementUnitPresentation,
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
		|		LEFT JOIN Catalog.Products AS Product
		|			ON RegisterRecordsInventoryChange.Products = Product.Ref
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
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
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS QuantityBalanceSerialNumbers
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
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR NOT ResultsArray[2].IsEmpty() Then
			DocumentObjectInventoryWriteOff = DocumentRefInventoryWriteOff.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		// Negative balance of inventory and cost accounting.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectInventoryWriteOff, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region InventoryOwnership

Function InventoryOwnershipParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);

	Return Parameters;
	
EndFunction

#EndRegion

#Region Batches

Function BatchCheckFillingParameters(DocObject) Export
	
	Parameters = New Structure;
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "InventoryWriteOff");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region IncomeAndExpenseItems

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("Correspondence", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Procedure GenerateMerchandiseFillingForm(SpreadsheetDocument, CurrentDocument, PrintParams)
	
	Query = New Query();
	Query.SetParameter("CurrentDocument", CurrentDocument);
	Query.Text = 
	"SELECT ALLOWED
	|	InventoryWriteOff.Date AS DocumentDate,
	|	InventoryWriteOff.Number AS Number,
	|	InventoryWriteOff.Company.Prefix AS Prefix,
	|	InventoryWriteOff.StructuralUnit AS WarehousePresentation,
	|	InventoryWriteOff.Cell AS CellPresentation,
	|	InventoryWriteOff.Inventory.(
	|		LineNumber AS LineNumber,
	|		Products.Warehouse AS Warehouse,
	|		Products.Cell AS Cell,
	|		CASE
	|			WHEN (CAST(InventoryWriteOff.Inventory.Products.DescriptionFull AS String(100))) = """"
	|				THEN InventoryWriteOff.Inventory.Products.Description
	|			ELSE InventoryWriteOff.Inventory.Products.DescriptionFull
	|		END AS InventoryItem,
	|		Products.SKU AS SKU,
	|		Products.Code AS Code,
	|		MeasurementUnit.Description AS MeasurementUnit,
	|		Quantity AS Quantity,
	|		Characteristic,
	|		Products.ProductsType AS ProductsType,
	|		ConnectionKey
	|	),
	|	InventoryWriteOff.SerialNumbers.(
	|		SerialNumber,
	|		ConnectionKey
	|	)
	|FROM
	|	Document.InventoryWriteOff AS InventoryWriteOff
	|WHERE
	|	InventoryWriteOff.Ref = &CurrentDocument
	|
	|ORDER BY
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
	
	Header = Query.Execute().Select();
	Header.Next();
	
	LinesSelectionInventory = Header.Inventory.Select();
	LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
	
	SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_InventoryWriteOff_MerchandiseFillingForm";
	
	Template = PrintManagement.PrintFormTemplate("Document.InventoryWriteOff.PF_MXL_MerchandiseFillingForm", LanguageCode);
	
	If Header.DocumentDate < Date('20110101') Then
		DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
	Else
		DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
	EndIf;		
	
	TemplateArea = Template.GetArea("Title");
	TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Inventory write-off #%1 dated %2.'; ru = 'Списание запасов №%1 от %2.';pl = 'Rozchód zapasów nr %1 z dn. %2.';es_ES = 'Amortización del inventario #%1 fechado %2.';es_CO = 'Amortización del inventario #%1 fechado %2.';tr = '%1 sayılı %2 tarihli stok azaltma.';it = 'Cancellazione di scorte #%1 con data %2.';de = 'Bestandsabschreibung Nr %1 datiert auf %2.'"),
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
		NStr("en = 'Date and time of printing: %1. User: %2.'; ru = 'Дата и время печати: %1. Пользователь: %2.';pl = 'Data i godzina wydruku: %1. Użytkownik: %2.';es_ES = 'Fecha y hora de la impresión: %1. Usuario: %2.';es_CO = 'Fecha y hora de la impresión: %1. Usuario: %2.';tr = 'Yazdırma tarihi ve saati: %1. Kullanıcı: %2.';it = 'Data e orario della stampa: %1. Utente: %2';de = 'Datum und Uhrzeit des Drucks: %1. Benutzer: %2.'"),
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
		TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(LinesSelectionInventory.InventoryItem, 
																LinesSelectionInventory.Characteristic, LinesSelectionInventory.SKU, StringSerialNumbers);
								
		SpreadsheetDocument.Put(TemplateArea);
						
	EndDo;

	TemplateArea = Template.GetArea("Total");
	SpreadsheetDocument.Put(TemplateArea);

	
EndProcedure

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_InventoryWriteOff";

	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			GenerateMerchandiseFillingForm(SpreadsheetDocument, CurrentDocument, PrintParams);
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames   - String    - Names of layouts separated by commas
//   ObjectsArray    - Array     - Array of refs to objects that need to be printed 
//   PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated table documents 
//   OutputParameters     - Structure    - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"MerchandiseFillingForm", 
			NStr("en = 'Merchandise filling form'; ru = 'Форма заполнения сопутствующих товаров';pl = 'Formularz wypełnienia towaru';es_ES = 'Formulario para rellenar las mercancías';es_CO = 'Formulario para rellenar las mercancías';tr = 'Mamul formu';it = 'Modulo di compilazione merce';de = 'Handelswarenformular'"),
			PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm", PrintParameters.Result));
		
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Requisition") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"Requisition",
															NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'"),
															DataProcessors.PrintRequisition.PrintForm(ObjectsArray, PrintObjects, "Requisition", PrintParameters.Result));
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
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "MerchandiseFillingForm";
	PrintCommand.Presentation				= NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Requisition";
	PrintCommand.Presentation				= NStr("en = 'Requisition'; ru = 'Требование';pl = 'Zapotrzebowanie';es_ES = 'Solicitud';es_CO = 'Solicitud';tr = 'Talep formu';it = 'Requisizione';de = 'Anforderung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 2;
	
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

Function ClearIncomeAndExpensesRecordsForMOHExpenseItem() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	IncomeAndExpenses.Recorder AS Ref
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|		INNER JOIN Document.InventoryWriteOff AS InventoryWriteOff
	|		ON IncomeAndExpenses.Recorder = InventoryWriteOff.Ref
	|WHERE
	|	InventoryWriteOff.ExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)";
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		InventoryWriteOff = SelectionDetailRecords.Ref;
		
		Try
			
			RecordSet = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
			RecordSet.Filter.Recorder.Set(InventoryWriteOff);
			RecordSet.Write();
			
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
				InventoryWriteOff,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
				InfobaseUpdate.EventLogEvent(),
				EventLogLevel.Error,
				Metadata.Documents.InventoryWriteOff,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndFunction

#EndRegion

#EndRegion

#Region Private

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefInventoryWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CostObject AS CostObject
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
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
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
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
	|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|		InventoryBalances.CostObject AS CostObject,
	|		InventoryBalances.QuantityBalance AS QuantityBalance,
	|		InventoryBalances.AmountBalance AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, InventoryAccountType, CostObject) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.PresentationCurrency,
	|						TableInventory.StructuralUnit,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.Ownership,
	|						TableInventory.InventoryAccountType,
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
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		DocumentRegisterRecordsInventory.Ownership,
	|		DocumentRegisterRecordsInventory.InventoryAccountType,
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
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.InventoryAccountType,
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRefInventoryWriteOff);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, InventoryAccountType, CostObject");
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For n = 0 To TableInventory.Count() - 1 Do
		
		RowTableInventory = TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("InventoryAccountType", RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
		QuantityWanted = RowTableInventory.Quantity;
		
		If QuantityWanted > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityWanted Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
	
			RowTableInventory.Amount = AmountToBeWrittenOff;
			RowTableInventory.Quantity = QuantityWanted;
			
		EndIf;
		
		// Generate postings.
		If UseDefaultTypeOfAccounting And Round(RowTableInventory.Amount, 2, 1) <> 0 Then
			RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
			FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
		EndIf;
		
	EndDo;
	
	If TableInventory.Count() > 0 Then
		RowTableInventory = TableInventory[0];
		If RowTableInventory.CorrIncomeAndExpenseItem.IncomeAndExpenseType = 
			Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads Then
			
			AmountMOH = TableInventory.Total("Amount");
			If AmountMOH <> 0 Then
				
				RowMOH = TableInventory.Add();
				FillPropertyValues(RowMOH, RowTableInventory,
					"Period, Company, PresentationCurrency, StructuralUnit, Ownership, CostObject");
				RowMOH.RecordType = AccumulationRecordType.Receipt;
				RowMOH.Products = Undefined;
				RowMOH.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
				RowMOH.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
				RowMOH.GLAccount = RowTableInventory.CorrGLAccount;
				RowMOH.Amount = AmountMOH;
				RowMOH.ProductionExpenses = True;
				
			EndIf;
			
		EndIf;
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefInventoryWriteOff);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefInventoryWriteOff, StructureAdditionalProperties)
	
	Query = New Query;
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	
	Query.Text = 
	"SELECT
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	TableInventory.CorrGLAccount AS GLAccount,
	|	TableInventory.Amount AS AmountExpense,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|INTO TT_BasicTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	&ExpenseItemType <> VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Period AS Period,
	|	InventoryWriteOff.Ref AS Recorder,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.BusinessLine AS BusinessLine,
	|	InventoryWriteOff.ExpenseItem AS ExpenseItem,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.AmountExpense AS AmountExpense,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|INTO TT_TableInventory
	|FROM
	|	TT_BasicTableInventory AS TableInventory
	|		INNER JOIN Document.InventoryWriteOff AS InventoryWriteOff
	|		ON (InventoryWriteOff.Ref = &Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_TableInventory.Period AS Period,
	|	TT_TableInventory.Recorder AS Recorder,
	|	TT_TableInventory.Company AS Company,
	|	TT_TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TT_TableInventory.StructuralUnit AS StructuralUnit,
	|	TT_TableInventory.BusinessLine AS BusinessLine,
	|	TT_TableInventory.ExpenseItem AS IncomeAndExpenseItem,
	|	TT_TableInventory.GLAccount AS GLAccount,
	|	TT_TableInventory.AmountExpense AS AmountExpense,
	|	TT_TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord
	|FROM
	|	TT_TableInventory AS TT_TableInventory";
	
	Query.SetParameter("Ref", DocumentRefInventoryWriteOff);
	Query.SetParameter("TableInventory", TableInventory);
	Query.SetParameter("ExpenseItemType", DocumentRefInventoryWriteOff.ExpenseItem.IncomeAndExpenseType);
	
	StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses = Query.Execute().Unload();
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefInventoryWriteOff, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

Function AccountingOfflineRecords(DocumentRef)
	
	Query = New Query(
	"SELECT ALLOWED
	|	OfflineRecords.Period AS Period,
	|	OfflineRecords.AccountDr AS AccountDr,
	|	OfflineRecords.AccountCr AS AccountCr,
	|	OfflineRecords.Company AS Company,
	|	OfflineRecords.PlanningPeriod AS PlanningPeriod,
	|	OfflineRecords.CurrencyDr AS CurrencyDr,
	|	OfflineRecords.CurrencyCr AS CurrencyCr,
	|	OfflineRecords.Amount AS Amount,
	|	OfflineRecords.AmountCurDr AS AmountCurDr,
	|	OfflineRecords.AmountCurCr AS AmountCurCr,
	|	OfflineRecords.Content AS Content,
	|	OfflineRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|");
	
	Query.SetParameter("Ref", DocumentRef);
	
	Return Query.Execute().Unload();
	
EndFunction

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

#EndIf