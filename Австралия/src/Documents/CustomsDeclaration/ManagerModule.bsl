#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	OperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
	IsBroker = (OperationKind = Enums.OperationTypesCustomsDeclaration.Broker);
	StructureAdditionalProperties.ForPosting.Insert("IsBroker", IsBroker);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	CatalogCounterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	CatalogCounterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.ExpenseItem AS ExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	CatalogCounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Supplier AS Supplier,
	|	Header.SupplierContract AS SupplierContract,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.VATIsDue AS VATIsDue,
	|	Header.OtherDutyToExpenses AS OtherDutyToExpenses,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.OtherDutyGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS OtherDutyGLAccount,
	|	Header.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO TT_Header
	|FROM
	|	Document.CustomsDeclaration AS Header
	|		LEFT JOIN Catalog.Counterparties AS CatalogCounterparties
	|		ON Header.Counterparty = CatalogCounterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CatalogCounterpartyContracts
	|		ON Header.Contract = CatalogCounterpartyContracts.Ref
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomsDeclarationInventory.LineNumber AS LineNumber,
	|	CustomsDeclarationInventory.Ref AS Document,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.ExpenseItem AS IncomeAndExpenseItem,
	|	Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Supplier AS Supplier,
	|	Header.SupplierContract AS SupplierContract,
	|	Header.VATIsDue AS VATIsDue,
	|	Header.OtherDutyToExpenses AS OtherDutyToExpenses,
	|	Header.OtherDutyGLAccount AS OtherDutyGLAccount,
	|	CustomsDeclarationInventory.Products AS Products,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CustomsDeclarationInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CustomsDeclarationInventory.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	CatalogProducts.ProductsType AS ProductsType,
	|	CatalogProducts.BusinessLine AS BusinessLine,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CustomsDeclarationInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|				OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN CustomsDeclarationInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CustomsDeclarationInventory.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CustomsDeclarationInventory.Invoice AS Invoice,
	|	CustomsDeclarationInventory.Order AS Order,
	|	CustomsDeclarationInventory.StructuralUnit AS StructuralUnit,
	|	CustomsDeclarationInventory.AdvanceInvoicing AS AdvanceInvoicing,
	|	CatalogBusinessUnits.RetailPriceKind AS RetailPriceKind,
	|	CatalogPriceTypes.PriceCurrency AS PriceCurrency,
	|	CustomsDeclarationInventory.Quantity AS Quantity,
	|	CustomsDeclarationCommodityGroups.VATRate AS VATRate,
	|	CAST(CustomsDeclarationInventory.CustomsValue * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS CustomsValue,
	|	CAST(CustomsDeclarationInventory.CustomsValue * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS CustomsValueCur,
	|	CAST(CustomsDeclarationInventory.DutyAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS DutyAmount,
	|	CAST(CustomsDeclarationInventory.DutyAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS DutyAmountCur,
	|	CAST(CustomsDeclarationInventory.OtherDutyAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS OtherDutyAmount,
	|	CAST(CustomsDeclarationInventory.OtherDutyAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS OtherDutyAmountCur,
	|	CAST(CustomsDeclarationInventory.ExciseAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS ExciseAmount,
	|	CAST(CustomsDeclarationInventory.ExciseAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS ExciseAmountCur,
	|	CAST(CustomsDeclarationInventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CustomsDeclarationInventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CustomsDeclarationInventory.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CustomsDeclarationInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	TT_Header AS Header
	|		INNER JOIN Document.CustomsDeclaration.CommodityGroups AS CustomsDeclarationCommodityGroups
	|		ON Header.Ref = CustomsDeclarationCommodityGroups.Ref
	|		INNER JOIN Document.CustomsDeclaration.Inventory AS CustomsDeclarationInventory
	|		ON Header.Ref = CustomsDeclarationInventory.Ref
	|			AND (CustomsDeclarationCommodityGroups.CommodityGroup = CustomsDeclarationInventory.CommodityGroup)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (CustomsDeclarationInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.LinesOfBusiness AS CatalogLinesOfBusiness
	|		ON (CatalogProducts.BusinessLine = CatalogLinesOfBusiness.Ref)
	|		LEFT JOIN Catalog.BusinessUnits AS CatalogBusinessUnits
	|		ON (CustomsDeclarationInventory.StructuralUnit = CatalogBusinessUnits.Ref)
	|		LEFT JOIN Catalog.PriceTypes AS CatalogPriceTypes
	|		ON (CatalogBusinessUnits.RetailPriceKind = CatalogPriceTypes.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON CustomsDeclarationInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.CompanyVATNumber AS CompanyVATNumber,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Supplier AS Supplier,
	|	TableInventory.SupplierContract AS SupplierContract,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.AdvanceInvoicing AS AdvanceInvoicing,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.VATRate AS VATRate,
	|	TableInventory.Invoice AS Invoice,
	|	TableInventory.Order AS Order,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	SUM(TableInventory.DutyAmount + TableInventory.ExciseAmount + CASE
	|			WHEN TableInventory.OtherDutyToExpenses
	|				THEN 0
	|			ELSE TableInventory.OtherDutyAmount
	|		END + CASE
	|			WHEN &RegisteredForVAT
	|				THEN 0
	|			ELSE TableInventory.VATAmount
	|		END) AS Amount
	|INTO TemporaryTableGroupedInventory
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.CompanyVATNumber,
	|	TableInventory.Supplier,
	|	TableInventory.SupplierContract,
	|	TableInventory.StructuralUnit,
	|	TableInventory.AdvanceInvoicing,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.VATRate,
	|	TableInventory.Invoice,
	|	TableInventory.Order,
	|	TableInventory.PresentationCurrency";
	
	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.SetParameter("RegisteredForVAT",		StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	GenerateTableGoodsAwaitingCustomsClearance(DocumentRef, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRef, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotReceived(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRef, StructureAdditionalProperties);
	GenerateTableMiscellaneousPayable(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	// Accounting
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
		
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsGoodsAwaitingCustomsClearanceChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange Then
		
		Query = New Query(
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.PresentationCurrency) AS PresentationCurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Counterparty) AS CounterpartyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract) AS ContractPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency) AS CurrencyPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Document) AS DocumentPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(RegisterRecordsSuppliersSettlementsChange.SettlementsType) AS CalculationsTypesPresentation,
		|	FALSE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsSuppliersSettlementsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.AmountChange AS AmountChange,
		|	RegisterRecordsSuppliersSettlementsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountOfOutstandingDebt,
		|	ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange
		|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT
		|						RegisterRecordsSuppliersSettlementsChange.Company AS Company,
		|						RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrency,
		|						RegisterRecordsSuppliersSettlementsChange.Counterparty AS Counterparty,
		|						RegisterRecordsSuppliersSettlementsChange.Contract AS Contract,
		|						RegisterRecordsSuppliersSettlementsChange.Document AS Document,
		|						RegisterRecordsSuppliersSettlementsChange.Order AS Order,
		|						RegisterRecordsSuppliersSettlementsChange.SettlementsType AS SettlementsType
		|					FROM
		|						RegisterRecordsSuppliersSettlementsChange AS RegisterRecordsSuppliersSettlementsChange)) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsAwaitingCustomsClearance.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectSupplierInvoice = DocumentRef.GetObject()
		EndIf;
		
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
				
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Return Catalogs.VATRates.Exempt;
	
EndFunction

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Header" Then
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Header" Then
		Result.Insert("OtherDutyGLAccount", "ExpenseItem");
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.AccountsPayableGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.AdvanceInvoicing Then
			GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount", StructureData.GoodsInvoicedNotDeliveredGLAccount);
		Else
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		
		If ObjectParameters.VATIsDue = Enums.VATDueOnCustomsClearance.InTheVATReturn Then
			GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
		EndIf;
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

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
	WarehouseData.Insert("Warehouse", "StructuralUnit");
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

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

#EndRegion

#Region Private

#Region TableGeneration

Procedure GenerateTableGoodsAwaitingCustomsClearance(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Supplier AS Counterparty,
	|	TemporaryTableInventory.SupplierContract AS Contract,
	|	TemporaryTableInventory.Invoice AS SupplierInvoice,
	|	TemporaryTableInventory.Order AS PurchaseOrder,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	SUM(TemporaryTableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.SupplierContract,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Invoice,
	|	TemporaryTableInventory.Order,
	|	TemporaryTableInventory.Supplier,
	|	TemporaryTableInventory.Products";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	UNDEFINED AS CorrOrganization,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS CorrInventoryAccountType,
	|	TableInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	UNDEFINED AS OwnershipCorr,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.VATRate AS VATRate,
	|	UNDEFINED AS Responsible,
	|	TableInventory.Invoice AS SalesDocument,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	UNDEFINED AS SupplySource,
	|	UNDEFINED AS CustomerCorrOrder,
	|	CAST(&InventoryIncrease AS STRING(100)) AS ContentOfAccountingRecord,
	|	TRUE AS FixedCost,
	|	0 AS Quantity,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TemporaryTableGroupedInventory AS TableInventory
	|WHERE
	|	TableInventory.Amount > 0
	|	AND NOT TableInventory.AdvanceInvoicing";
	
	Query.SetParameter("RegisteredForVAT", StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("InventoryIncrease", NStr("en = 'Customs fees'; ru = 'Таможенный сбор';pl = 'Opłaty celne';es_ES = 'Comisiones aduaneras';es_CO = 'Comisiones aduaneras';tr = 'Gümrük ücretleri';it = 'Dazi doganali';de = 'Zollgebühren'", StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotReceived(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.Invoice AS SupplierInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Supplier AS Counterparty,
	|	TableProducts.SupplierContract AS Contract,
	|	TableProducts.Order AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	VALUE(Catalog.VATRates.ZeroRate) AS VATRate,
	|	0 AS Quantity,
	|	SUM(TableProducts.Amount) AS Amount,
	|	0 AS VATAmount
	|FROM
	|	TemporaryTableGroupedInventory AS TableProducts
	|WHERE
	|	TableProducts.AdvanceInvoicing
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Invoice,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Supplier,
	|	TableProducts.SupplierContract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	MIN(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.OtherDutyGLAccount AS GLAccount,
	|	0 AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.OtherDutyAmount) AS AmountExpense,
	|	SUM(TableIncomeAndExpenses.OtherDutyAmount) AS Amount,
	|	CAST(&OtherDutyExpenses AS STRING(100)) AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableInventory AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.OtherDutyToExpenses
	|	AND TableIncomeAndExpenses.OtherDutyAmount > 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.OtherDutyGLAccount,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	UNDEFINED,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN 0
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
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
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
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
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	Query.SetParameter("FXIncomeItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("OtherDutyExpenses",
		NStr("en = 'Other duty expenses'; ru = 'Сумма прочих сборов';pl = 'Inne rozchody celne';es_ES = 'Otros gastos de misión';es_CO = 'Otros gastos de misión';tr = 'Diğer vergi giderleri';it = 'Altre spese doganali';de = 'Andere Abgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
			
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountsPayable(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PostingContent"				, NStr("en = 'Payment to customs broker'; ru = 'Платеж брокеру';pl = 'Płatność agentowi celnemu';es_ES = 'Pago al agente aduanero';es_CO = 'Pago al agente aduanero';tr = 'Gümrük komisyoncusuna ödeme';it = 'Pagamento al broker doganale';de = 'Zahlung an Zollagenten'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("Ref"						, DocumentRef);
	Query.SetParameter("PointInTime"				, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"				, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference"		, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("ExchangeDifference"			, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("RegisteredForVAT"			, StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("ExchangeRateMethod"			, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("IsBroker"					, StructureAdditionalProperties.ForPosting.IsBroker);
	Query.SetParameter("UseDefaultTypeOfAccounting"	, GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	TemporaryTablePaymentDetails.DutyAmount + TemporaryTablePaymentDetails.OtherDutyAmount + TemporaryTablePaymentDetails.ExciseAmount AS Amount,
	|	TemporaryTablePaymentDetails.DutyAmountCur + TemporaryTablePaymentDetails.OtherDutyAmountCur + TemporaryTablePaymentDetails.ExciseAmountCur AS AmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableAccountsPayablePre
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.VATAmount,
	|	TemporaryTablePaymentDetails.VATAmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.Period
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			OR NOT &RegisteredForVAT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTablePaymentDetails.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Currency AS Currency,
	|	TemporaryTablePaymentDetails.Document AS Document,
	|	UNDEFINED AS Order,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	TemporaryTablePaymentDetails.Period AS Date,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountForPaymentCur,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCurForBalance,
	|	&PostingContent AS ContentOfAccountingRecord,
	|	TemporaryTablePaymentDetails.GLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableAccountsPayablePre AS TemporaryTablePaymentDetails
	|WHERE
	|	&IsBroker
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Currency,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.GLAccount,
	|	TemporaryTablePaymentDetails.Period,
	|	TemporaryTablePaymentDetails.Period";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order
	|FROM
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	DataLock 			= New DataLock;
	LockItem 			= DataLock.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableMiscellaneousPayable(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AccountingForOtherOperations",	NStr("en = 'Miscellaneous payables'; ru = 'Учет расчетов по прочим операциям';pl = 'Różne zobowiązania';es_ES = 'Cuentas a pagar varias';es_CO = 'Cuentas a pagar varias';tr = 'Çeşitli borçlar';it = 'Debiti vari';de = 'Andere Verbindlichkeiten'",	StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("Comment",						NStr("en = 'Payment to other accounts'; ru = 'Увеличение долга контрагента';pl = 'Płatność na inne konta';es_ES = 'Pago a otras cuentas';es_CO = 'Pago a otras cuentas';tr = 'Diğer hesaplara ödeme';it = 'Pagamento ad altri conti';de = 'Zahlung an andere Konten'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("Ref",							DocumentRef);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",					StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("ExchangeRateDifference",		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("IsBroker",						StructureAdditionalProperties.ForPosting.IsBroker);
	
	Query.Text =
	"SELECT
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.DutyAmount + TemporaryTablePaymentDetails.OtherDutyAmount + TemporaryTablePaymentDetails.ExciseAmount AS Amount,
	|	TemporaryTablePaymentDetails.DutyAmountCur + TemporaryTablePaymentDetails.OtherDutyAmountCur + TemporaryTablePaymentDetails.ExciseAmountCur AS AmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableOtherSettlementsPre
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.VATAmount,
	|	TemporaryTablePaymentDetails.VATAmountCur,
	|	TemporaryTablePaymentDetails.GLAccountVendorSettlements,
	|	TemporaryTablePaymentDetails.Period
	|FROM
	|	TemporaryTableInventory AS TemporaryTablePaymentDetails
	|WHERE
	|	(TemporaryTablePaymentDetails.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			OR NOT &RegisteredForVAT)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TemporaryTablePaymentDetails.LineNumber) AS LineNumber,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.Currency AS Currency,
	|	TemporaryTablePaymentDetails.Period AS Date,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCur,
	|	SUM(TemporaryTablePaymentDetails.Amount) AS AmountForBalance,
	|	SUM(TemporaryTablePaymentDetails.AmountCur) AS AmountCurForBalance,
	|	&AccountingForOtherOperations AS PostingContent,
	|	&Comment AS Comment,
	|	TemporaryTablePaymentDetails.GLAccount AS GLAccount,
	|	TemporaryTablePaymentDetails.Period AS Period
	|INTO TemporaryTableOtherSettlements
	|FROM
	|	TemporaryTableOtherSettlementsPre AS TemporaryTablePaymentDetails
	|WHERE
	|	NOT &IsBroker
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.Currency,
	|	TemporaryTablePaymentDetails.GLAccount,
	|	TemporaryTablePaymentDetails.Period,
	|	TemporaryTablePaymentDetails.Period";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableOtherSettlements.Company AS Company,
	|	TemporaryTableOtherSettlements.PresentationCurrency AS PresentationCurrency, 
	|	TemporaryTableOtherSettlements.Counterparty AS Counterparty,
	|	TemporaryTableOtherSettlements.Contract AS Contract
	|FROM
	|	TemporaryTableOtherSettlements AS TemporaryTableOtherSettlements";
	
	QueryResult = Query.Execute();
	
	DataLock 			= New DataLock;
	LockItem 			= DataLock.Add("AccumulationRegister.MiscellaneousPayable");
	LockItem.Mode 		= DataLockMode.Exclusive;
	LockItem.DataSource	= QueryResult;
	
	For Each QueryResultColumn In QueryResult.Columns Do
		LockItem.UseFromDataSource(QueryResultColumn.Name, QueryResultColumn.Name);
	EndDo;
	
	DataLock.Lock();
	
	QueryNumber = 0;
	
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableMiscellaneousPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventory.Counterparty AS Supplier,
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	TemporaryTableInventory.VATInputGLAccount AS GLAccount,
	|	SUM(TemporaryTableInventory.CustomsValue + TemporaryTableInventory.DutyAmount + TemporaryTableInventory.OtherDutyAmount + TemporaryTableInventory.ExciseAmount) AS AmountExcludesVAT,
	|	SUM(TemporaryTableInventory.VATAmount) AS VATAmount,
	|	CASE
	|		WHEN TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			THEN VALUE(Enum.VATOperationTypes.Import)
	|		ELSE VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|	END AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	CASE
	|		WHEN TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|			THEN VALUE(Enum.VATOperationTypes.Import)
	|		ELSE VALUE(Enum.VATOperationTypes.ReverseChargeApplied)
	|	END,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.CompanyVATNumber,
	|	TemporaryTableInventory.PresentationCurrency,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.VATInputGLAccount";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableInventory.Counterparty AS Customer,
	|	TemporaryTableInventory.Document AS ShipmentDocument,
	|	TemporaryTableInventory.VATRate AS VATRate,
	|	TemporaryTableInventory.VATOutputGLAccount AS GLAccount,
	|	SUM(TemporaryTableInventory.CustomsValue + TemporaryTableInventory.DutyAmount + TemporaryTableInventory.OtherDutyAmount + TemporaryTableInventory.ExciseAmount) AS AmountExcludesVAT,
	|	SUM(TemporaryTableInventory.VATAmount) AS VATAmount,
	|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
	|	TemporaryTableInventory.ProductsType AS ProductType
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	TemporaryTableInventory.VATisDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|
	|GROUP BY
	|	TemporaryTableInventory.VATRate,
	|	TemporaryTableInventory.ProductsType,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.CompanyVATNumber,
	|	TemporaryTableInventory.PresentationCurrency,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.VATOutputGLAccount";
		
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(TemporaryTable.VATAmount), 0) AS VATAmount,
	|	ISNULL(SUM(TemporaryTable.VATAmountCur), 0) AS VATAmountCur,
	|	ISNULL(SUM(TemporaryTable.OtherDutyAmount), 0) AS OtherDutyAmount,
	|	ISNULL(SUM(TemporaryTable.OtherDutyAmountCur), 0) AS OtherDutyAmountCur
	|FROM
	|	TemporaryTableInventory AS TemporaryTable";
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	VATAmount			= Selection.VATAmount;
	VATAmountCur		= Selection.VATAmountCur;
	OtherDutyAmount		= Selection.OtherDutyAmount;
	OtherDutyAmountCur	= Selection.OtherDutyAmountCur;

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	CASE
	|		WHEN TableAccountingJournalEntries.AdvanceInvoicing
	|			THEN TableAccountingJournalEntries.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.OtherDutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.OtherDutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.OtherDutyAmount + TableAccountingJournalEntries.ExciseAmount AS Amount,
	|	&LandedCostsAccrued AS Content
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.OtherDutyAmount + TableAccountingJournalEntries.ExciseAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AdvanceInvoicing
	|			THEN TableAccountingJournalEntries.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.DutyAmountCur + TableAccountingJournalEntries.ExciseAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.ExciseAmount,
	|	&LandedCostsAccrued
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND TableAccountingJournalEntries.DutyAmount + TableAccountingJournalEntries.ExciseAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AdvanceInvoicing
	|			THEN TableAccountingJournalEntries.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE TableAccountingJournalEntries.GLAccount
	|	END,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.VATAmount,
	|	&VATIncludedInCost
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT &RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.OtherDutyGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OtherDutyGLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.OtherDutyGLAccount.Currency
	|			THEN &OtherDutyAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN &OtherDutyAmountCur
	|		ELSE 0
	|	END,
	|	&OtherDutyAmount,
	|	&ExpensesAccrued
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.OtherDutyToExpenses
	|	AND &OtherDutyAmount > 0
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&VATDue
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.OnTheSupply)
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&ReverseChargeVAT
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|	AND &VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	7,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&ReverseChargeVATReclaimed
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.VATIsDue = VALUE(Enum.VATDueOnCustomsClearance.InTheVATReturn)
	|	AND &VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.VATInputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	&ExchangeDifference
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|ORDER BY
	|	Ordering";
	
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("GLAccountVATReverseCharge",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATReverseCharge"));
	Query.SetParameter("VATAmount",					VATAmount);
	Query.SetParameter("VATAmountCur",				VATAmountCur);
	Query.SetParameter("OtherDutyAmount",			OtherDutyAmount);
	Query.SetParameter("OtherDutyAmountCur",		OtherDutyAmountCur);
	Query.SetParameter("RegisteredForVAT",			StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	
	Query.SetParameter("LandedCostsAccrued",
		NStr("en = 'Landed costs accrued'; ru = 'Начислено дополнительных расходов';pl = 'Wydatki naliczone koszt własny';es_ES = 'Costes de entrega acumulados';es_CO = 'Costes en destino acumulados';tr = 'Tahakkuk eden varış yeri maliyetleri';it = 'Costi di scarico cumulati';de = 'Wareneinstandspreise angefallen'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("VATIncludedInCost",
		NStr("en = 'VAT included in cost'; ru = 'НДС включен в стоимость';pl = 'Włącz VAT do kosztów własnych';es_ES = 'IVA incluido en el coste';es_CO = 'IVA incluido en el coste';tr = 'Maliyete KDV dahildir';it = 'IVA inclusa nel costo';de = 'USt. enthalten in den Kosten'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExpensesAccrued",
		NStr("en = 'Expenses accrued'; ru = 'Отражение расходов';pl = 'Naliczone rozchody';es_ES = 'Gastos acumulados';es_CO = 'Gastos acumulados';tr = 'Tahakkuk eden harcamalar';it = 'Spese maturate';de = 'Angelaufene Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("VATDue",
		NStr("en = 'VAT due'; ru = 'НДС';pl = 'VAT należny';es_ES = 'IVA pendiente';es_CO = 'IVA pendiente';tr = 'Ödenecek KDV';it = 'IVA dovuta';de = 'USt. fällig'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'; ru = 'Реверсивный НДС';pl = 'Odwrotne obciążenie VAT';es_ES = 'IVA de la inversión impositiva';es_CO = 'IVA de la inversión impositiva';tr = 'Sorumlu sıfatıyla KDV';it = 'Reverse charge IVA';de = 'Steuerschuldumkehr'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVATReclaimed",
		NStr("en = 'Reverse charge VAT reclaimed'; ru = 'Реверсивный НДС отозван';pl = 'Odzyskana kwota podatku VAT';es_ES = 'Inversión impositiva IVA reclamado';es_CO = 'Inversión impositiva IVA reclamado';tr = 'Karşı ödemeli KDV iadesi';it = 'Reclamata l''inversione caricamento IVA';de = 'Steuerschuldumkehr zurückgewonnen'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableLandedCosts(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Products AS Products,
	|	CASE
	|		WHEN TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableInventory.Invoice AS CostLayer,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.Amount AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableGroupedInventory AS TableInventory
	|WHERE
	|	TableInventory.Amount > 0
	|	AND NOT &FillAmount
	|	AND NOT TableInventory.AdvanceInvoicing";
	
	FillAmount = (StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage);
	Query.SetParameter("FillAmount", FillAmount);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#EndIf