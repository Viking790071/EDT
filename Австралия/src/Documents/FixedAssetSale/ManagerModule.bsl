#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPassWA, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",							DocumentRefPassWA);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("DocumentCurrency",				Common.ObjectAttributeValue(DocumentRefPassWA, "DocumentCurrency"));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CustomerAdvancesGLAccount
	|INTO TemporaryDocumentHeader
	|FROM
	|	Document.FixedAssetSale AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Date,
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	ISNULL(Counterparties.DoOperationsByContracts, FALSE) AS DoOperationsByContracts,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentHeader.GLAccountCustomerSettlements = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			THEN ISNULL(Counterparties.GLAccountCustomerSettlements, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE DocumentHeader.GLAccountCustomerSettlements
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN NOT &UseDefaultTypeOfAccounting
	|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|		WHEN DocumentHeader.CustomerAdvancesGLAccount = VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|			THEN ISNULL(Counterparties.CustomerAdvancesGLAccount, VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef))
	|		ELSE DocumentHeader.CustomerAdvancesGLAccount
	|	END AS CustomerAdvancesGLAccount,
	|	DocumentHeader.Contract AS Contract,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO DocumentHeader
	|FROM
	|	TemporaryDocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON DocumentHeader.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentHeader.Date AS Period,
	|	DocumentHeader.Ref AS Document,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	FixedAssetParametersSliceLast.StructuralUnit AS StructuralUnit,
	|	ISNULL(FixedAssetParametersSliceLast.ExpenseItem, VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)) AS DepreciationItem,
	|	ISNULL(IncomeAndExpenseItems.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) AS DepreciationItemType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN FixedAssetParametersSliceLast.GLExpenseAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountAccountingDepreciation,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN VALUE(Enum.GLAccountsTypes.EmptyRef)
	|		ELSE UNDEFINED
	|	END AS DepreciationAccountType,
	|	FixedAssetParametersSliceLast.BusinessLine AS BusinessLine,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.FixedAsset.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN ISNULL(IncomeAndExpenseItems.IncomeAndExpenseType, VALUE(Catalog.IncomeAndExpenseTypes.EmptyRef)) = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|			THEN VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.FixedAsset.DepreciationAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DepreciationAccount,
	|	DocumentTable.ExpenseItem AS ExpenseItem,
	|	DocumentTable.IncomeItem AS IncomeItem,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.SettlementsCurrency AS SettlementsCurrency,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentTable.Cost AS Cost,
	|	DocumentTable.Depreciation AS Depreciation,
	|	DocumentTable.MonthlyDepreciation AS MonthlyDepreciation,
	|	DocumentTable.DepreciatedCost AS DepreciatedCost,
	|	CAST(CASE
	|			WHEN DocumentTable.Ref.IncludeVATInPrice
	|				THEN 0
	|			ELSE DocumentTable.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DocumentHeader.ExchangeRate / DocumentHeader.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN DocumentHeader.Multiplicity / DocumentHeader.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(DocumentTable.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate / DocumentHeader.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN DocumentHeader.Multiplicity / DocumentHeader.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(DocumentTable.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DocumentHeader.ExchangeRate * DocumentHeader.ContractCurrencyMultiplicity / (DocumentHeader.ContractCurrencyExchangeRate * DocumentHeader.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	TRUE AS FixedCost
	|INTO TemporaryTableFixedAssets
	|FROM
	|	Document.FixedAssetSale.FixedAssets AS DocumentTable
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON DocumentTable.Ref = DocumentHeader.Ref
	|		LEFT JOIN InformationRegister.FixedAssetParameters.SliceLast(&PointInTime, ) AS FixedAssetParametersSliceLast
	|			LEFT JOIN Catalog.IncomeAndExpenseItems AS IncomeAndExpenseItems
	|			ON FixedAssetParametersSliceLast.ExpenseItem = IncomeAndExpenseItems.Ref
	|		ON (FixedAssetParametersSliceLast.Company = &Company)
	|			AND (FixedAssetParametersSliceLast.PresentationCurrency = &PresentationCurrency)
	|			AND DocumentTable.FixedAsset = FixedAssetParametersSliceLast.FixedAsset
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentHeader.Date AS Period,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	DocumentHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	DocumentHeader.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.SettlementsCurrency AS SettlementsCurrency,
	|	VALUE(Document.SalesOrder.EmptyRef) AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	DocumentHeader.Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	DocumentTable.Document.Date AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.FixedAssetSale.Prepayment AS DocumentTable
	|		INNER JOIN DocumentHeader AS DocumentHeader
	|		ON DocumentTable.Ref = DocumentHeader.Ref
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	DocumentTable.Document,
	|	DocumentHeader.Date,
	|	DocumentHeader.Counterparty,
	|	DocumentHeader.GLAccountCustomerSettlements,
	|	DocumentHeader.CustomerAdvancesGLAccount,
	|	DocumentHeader.Contract,
	|	DocumentHeader.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	DocumentTable.Document.Date,
	|	DocumentHeader.DoOperationsByContracts,
	|	DocumentHeader.DoOperationsByOrders";
	
	Query.Execute();
	
	GenerateTableInventory(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableFixedAssets(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableFixedAssetStatuses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPassWA, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefPassWA, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPassWA, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefPassWA, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPassWA, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If there are records in temprorary tables,
	// it is necessary to control the occurrence of negative balances.
	If StructureTemporaryTables.RegisterRecordsFixedAssetsChange
		Or StructureTemporaryTables.RegisterRecordsAccountsReceivableChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsAccountsReceivableChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite - ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AdvanceAmountsReceived,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT
		|						RegisterRecordsAccountsReceivableChange.Company AS Company,
		|						RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsAccountsReceivableChange.Counterparty AS Counterparty,
		|						RegisterRecordsAccountsReceivableChange.Contract AS Contract,
		|						RegisterRecordsAccountsReceivableChange.Document AS Document,
		|						RegisterRecordsAccountsReceivableChange.Order AS Order,
		|						RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange)) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsFixedAssetsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsFixedAssetsChange.FixedAsset) AS FixedAssetPresentation,
		|	ISNULL(FixedAssetsBalance.CostBalance, 0) AS CostBalance,
		|	ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS DepreciationBalance,
		|	RegisterRecordsFixedAssetsChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsFixedAssetsChange.CostChanging AS CostChanging,
		|	RegisterRecordsFixedAssetsChange.CostChanging + ISNULL(FixedAssetsBalance.CostBalance, 0) AS DepreciatedCost,
		|	RegisterRecordsFixedAssetsChange.DepreciationBeforeWrite AS DepreciationBeforeWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationOnWrite AS DepreciationOnWrite,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate AS DepreciationUpdate,
		|	RegisterRecordsFixedAssetsChange.DepreciationUpdate + ISNULL(FixedAssetsBalance.DepreciationBalance, 0) AS AccuredDepreciation
		|FROM
		|	RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange
		|		LEFT JOIN AccumulationRegister.FixedAssets.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, FixedAsset) In
		|					(SELECT
		|						RegisterRecordsFixedAssetsChange.Company AS Company,
		|						RegisterRecordsFixedAssetsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsFixedAssetsChange.FixedAsset AS FixedAsset
		|					FROM
		|						RegisterRecordsFixedAssetsChange AS RegisterRecordsFixedAssetsChange)) AS FixedAssetsBalance
		|		ON (RegisterRecordsFixedAssetsChange.Company = RegisterRecordsFixedAssetsChange.Company)
		|			AND (RegisterRecordsFixedAssetsChange.PresentationCurrency = RegisterRecordsFixedAssetsChange.PresentationCurrency)
		|			AND (RegisterRecordsFixedAssetsChange.FixedAsset = RegisterRecordsFixedAssetsChange.FixedAsset)
		|WHERE
		|	(ISNULL(FixedAssetsBalance.CostBalance, 0) < 0
		|			OR ISNULL(FixedAssetsBalance.DepreciationBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObjectFixedAssetSale = DocumentRefPassWA.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocumentObjectFixedAssetSale, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of fixed assets depriciation.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocumentObjectFixedAssetSale, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region LibrariesHandlers

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//	PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
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

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "FixedAssets" Then
		IncomeAndExpenseStructure.Insert("IncomeItem", StructureData.IncomeItem);
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	If StructureData.Property("CounterpartyGLAccounts") Then
		
		ObjectParameters = StructureData.ObjectParameters;
		GLAccountsForFilling = New Structure;
		
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.AccountsReceivableGLAccount);
		GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", ObjectParameters.AdvancesReceivedGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		GLAccountsForFilling = New Structure("InventoryTransferredGLAccount, VATOutputGLAccount, RevenueGLAccount, COGSGLAccount");
		FillPropertyValues(GLAccountsForFilling, StructureData); 
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#EndRegion

#Region Internal

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "FixedAssets");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
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

#Region Private

#Region TableGeneration
// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation", NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("OtherExpenses", NStr("en = 'Expenses incurred'; ru = 'Прочих затраты (расходы)';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'", MainLanguageCode));
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	DocumentTable.InventoryAccountType AS InventoryAccountType,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	TRUE AS FixedCost,
	|	&AccrueDepreciation AS ContentOfAccountingRecord,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads))
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	DocumentTable.DepreciationItem AS IncomeAndExpenseItem,
	|	DocumentTable.AccountAccountingDepreciation AS GLAccount,
	|	&AccrueDepreciation AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	DocumentTable.MonthlyDepreciation AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|	AND (DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			OR DocumentTable.DepreciationItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses))
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales,
	|	UNDEFINED,
	|	DocumentTable.IncomeItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BusinessLineSales.GLAccountRevenueFromSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	&OtherIncome,
	|	DocumentTable.Amount,
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	DocumentTable.BusinessLineSales,
	|	UNDEFINED,
	|	DocumentTable.ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.BusinessLineSales.GLAccountCostOfSales
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	&OtherExpenses,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.PresentationCurrency AS PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.PresentationCurrency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.BusinessLine,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.AmountIncome,
	|	OfflineRecords.AmountExpense,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation",							NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("OtherIncome",									NStr("en = 'Other income'; ru = 'Прочие доходы';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",									NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",											DocumentRefPassWA);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssets(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation",					NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",					NStr("en = 'Depreciation deduction'; ru = 'Списание амортизации';pl = 'Zapasy działa jako pliki';es_ES = 'Deducción de la depreciación';es_CO = 'Deducción de la depreciación';tr = 'Amortisman indirimi';it = 'Deduzione dell''ammortamento';de = 'Abschreibungsabzug'", MainLanguageCode));
	Query.SetParameter("WriteOffOfFixedAssetFromAccounting",	NStr("en = 'Fixed asset sale'; ru = 'Продажа основных средств';pl = 'Sprzedaż środków trwałych';es_ES = 'Venta del activo fijo';es_CO = 'Venta del activo fijo';tr = 'Sabit kıymet satışı';it = 'Vendita cespite';de = 'Verkauf des Anlagevermögens'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.MonthlyDepreciation AS Depreciation,
	|	0 AS Cost,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	DocumentTable.DepreciationAccount AS GLAccount,
	|	&AccrueDepreciation AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.FixedAsset,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	DocumentTable.DepreciationAccount,
	|	&DepreciationDebiting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.FixedAsset,
	|	0,
	|	DocumentTable.Cost,
	|	DocumentTable.Cost,
	|	DocumentTable.GLAccount,
	|	&WriteOffOfFixedAssetFromAccounting
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost > 0
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssets", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableFixedAssetStatuses(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.FixedAsset AS FixedAsset,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.FixedAssetStatus.RemoveFromAccounting) AS State,
	|	FALSE AS AccrueDepreciation,
	|	FALSE AS AccrueDepreciationInCurrentMonth
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFixedAssetStatus", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableCustomerAccounts(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("Ref",							DocumentRefPassWA);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfCustomerLiability",	NStr("en = 'Accounts receivable recognition'; ru = 'Возникновение обязательств покупателя';pl = 'Należności przyjęcte do ewidencji';es_ES = 'Reconocimientos de las cuentas a cobrar';es_CO = 'Reconocimientos de las cuentas a cobrar';tr = 'Alacak hesapların onaylanması';it = 'Riconoscimento dei crediti';de = 'Offene Posten Debitoren Aufnahme'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit",					NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Document AS Document,
	|	UNDEFINED AS Order,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	SUM(DocumentTable.Amount) AS AmountForPayment,
	|	SUM(DocumentTable.AmountCur) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	UNDEFINED,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.CustomerAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	UNDEFINED,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100))
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable AS TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPassWA);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	&Ref AS Document,
	|	DocumentTable.BusinessLineSales AS BusinessLine,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Item AS Item
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	LineNumber";
	
	ResultsArray = Query.ExecuteBatch();
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountIncome;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountIncome > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountIncome = AmountToBeWrittenOff;
				AmountToBeWrittenOff = 0;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringPrepaymentIncomeAndExpensesRetained In TablePrepaymentIncomeAndExpensesRetained Do
		StringInventoryIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Add();
		FillPropertyValues(StringInventoryIncomeAndExpensesRetained, StringPrepaymentIncomeAndExpensesRetained);
		StringInventoryIncomeAndExpensesRetained.RecordType = AccumulationRecordType.Expense;
	EndDo;
	
	SelectionOfQueryResult = ResultsArray[2].Select();
	
	If SelectionOfQueryResult.Next() Then
		Item = SelectionOfQueryResult.Item;
	Else
		Item = Catalogs.CashFlowItems.PaymentFromCustomers;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Document AS Document,
	|	&Item AS Item,
	|	Table.BusinessLine AS BusinessLine,
	|	Table.AmountIncome AS AmountIncome
	|INTO TemporaryTablePrepaidIncomeAndExpensesRetained
	|FROM
	|	&Table AS Table";
	Query.SetParameter("Table", TablePrepaymentIncomeAndExpensesRetained);
	Query.SetParameter("Item", Item);
	
	Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesRetained", TableInventoryIncomeAndExpensesRetained);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableUnallocatedExpenses(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableUnallocatedExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPassWA, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPassWA);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	DocumentTable.DocumentDate AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS BusinessLine,
	|	DocumentTable.Item AS Item,
	|	-DocumentTable.Amount AS AmountIncome
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Period,
	|	Table.Company,
	|	Table.PresentationCurrency,
	|	Table.BusinessLine,
	|	Table.Item,
	|	Table.AmountIncome
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefPassWA, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
	Query.Text =
	"SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Period AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.AccountAccountingDepreciation AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	DocumentTable.DepreciationAccount AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	DocumentTable.MonthlyDepreciation AS Amount,
	|	CAST(&AccrueDepreciation AS STRING(100)) AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.DepreciationAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation,
	|	&DepreciationDebiting,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.MonthlyDepreciation + DocumentTable.Depreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BusinessLineSales.GLAccountCostOfSales,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.GLAccount,
	|	UNDEFINED,
	|	0,
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Cost - DocumentTable.Depreciation - DocumentTable.MonthlyDepreciation > 0
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlements.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.BusinessLineSales.GLAccountRevenueFromSales,
	|	CASE
	|		WHEN DocumentTable.BusinessLineSales.GLAccountRevenueFromSales.Currency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.BusinessLineSales.GLAccountRevenueFromSales.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&OtherIncome,
	|	FALSE
	|FROM
	|	TemporaryTableFixedAssets AS DocumentTable
	|WHERE
	|	DocumentTable.Amount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	1,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.CustomerAdvancesGLAccountForeignCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountCustomerSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.Amount,
	|	&SetOffAdvancePayment,
	|	FALSE
	|FROM
	|	(SELECT
	|		DocumentTable.Period AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency AS CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency AS GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|			DocumentTable.CustomerAdvancesGLAccount.Currency AS CustomerAdvancesGLAccountForeignCurrency,
	|			DocumentTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|			DocumentTable.GLAccountCustomerSettlements.Currency AS GLAccountCustomerSettlementsCurrency,
	|			DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|			DocumentTable.AmountCur AS AmountCur,
	|			DocumentTable.Amount AS Amount
	|		FROM
	|			TemporaryTablePrepayment AS DocumentTable
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount,
	|			DocumentTable.Counterparty.CustomerAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements,
	|			DocumentTable.Counterparty.GLAccountCustomerSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.CustomerAdvancesGLAccount,
	|		DocumentTable.CustomerAdvancesGLAccountForeignCurrency,
	|		DocumentTable.GLAccountCustomerSettlements,
	|		DocumentTable.GLAccountCustomerSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency
	|	
	|	HAVING
	|		(SUM(DocumentTable.Amount) >= 0.005
	|			OR SUM(DocumentTable.Amount) <= -0.005
	|			OR SUM(DocumentTable.AmountCur) >= 0.005
	|			OR SUM(DocumentTable.AmountCur) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	1,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &NegativeExchangeDifferenceAccountOfAccounting
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &PositiveExchangeDifferenceGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences < 0
	|				AND TableAccountingJournalEntries.GLAccountForeignCurrency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableExchangeRateDifferencesAccountsReceivable.Date AS Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company AS Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount AS GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency AS Currency,
	|		SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|		
	|		UNION ALL
	|		
	|		SELECT
	|			DocumentTable.Date,
	|			DocumentTable.Company,
	|			DocumentTable.GLAccount,
	|			DocumentTable.GLAccount.Currency,
	|			DocumentTable.Currency,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableExchangeRateDifferencesAccountsReceivable
	|	
	|	GROUP BY
	|		TableExchangeRateDifferencesAccountsReceivable.Date,
	|		TableExchangeRateDifferencesAccountsReceivable.Company,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccount,
	|		TableExchangeRateDifferencesAccountsReceivable.GLAccountForeignCurrency,
	|		TableExchangeRateDifferencesAccountsReceivable.Currency
	|	
	|	HAVING
	|		(SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableExchangeRateDifferencesAccountsReceivable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|
	|ORDER BY
	|	Order,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();

	Query.SetParameter("AccrueDepreciation",								NStr("en = 'Accrue depreciation'; ru = 'Начисление амортизации';pl = 'Naliczyć amortyzację';es_ES = 'Amortización de la acumulación';es_CO = 'Amortización de la acumulación';tr = 'Amortismanı tahakkuk et';it = 'Accantonamenti ammortamenti';de = 'Abschreibungsberechnung'", MainLanguageCode));
	Query.SetParameter("DepreciationDebiting",								NStr("en = 'Depreciation write-off'; ru = 'Списание амортизации';pl = 'Spisanie amortyzacji';es_ES = 'Amortización de la depreciación';es_CO = 'Amortización de la depreciación';tr = 'Amortisman silinmesi';it = 'Cancellazione ammortamento (write-off)';de = 'Abschreibung der Abschreibung'", MainLanguageCode));
	Query.SetParameter("OtherExpenses",										NStr("en = 'Other expenses'; ru = 'Прочих затраты (расходы)';pl = 'Pozostałe koszty (wydatki)';es_ES = 'Otros gastos';es_CO = 'Otros gastos';tr = 'Diğer masraflar';it = 'Altre spese';de = 'Sonstige Ausgaben'", MainLanguageCode));
	Query.SetParameter("OtherIncome",										NStr("en = 'Other income'; ru = 'Прочие доходы';pl = 'Inne przychody';es_ES = 'Otros ingresos';es_CO = 'Otros ingresos';tr = 'Diğer gelir';it = 'Altre entrate';de = 'Sonstige Einnahmen'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",								NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",								NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Ref",												DocumentRefPassWA);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#EndIf