#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Expenses");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
EndFunction

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefAdditionalExpenses, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary tables "RegisterRecordsSuppliersSettlementsChange", "RegisterRecordsPurchaseOrdersChange" contain records, 
	// it is required to execute the implementation products control.
	
	If StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
	 Or StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.PurchaseOrder) AS PurchaseOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsPurchaseOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(PurchaseOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		LEFT JOIN AccumulationRegister.PurchaseOrders.Balance(
		|				&ControlTime,
		|				(Company, PurchaseOrder, Products, Characteristic) In
		|					(SELECT
		|						RegisterRecordsPurchaseOrdersChange.Company AS Company,
		|						RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrder,
		|						RegisterRecordsPurchaseOrdersChange.Products AS Products,
		|						RegisterRecordsPurchaseOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange)) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0
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
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
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
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty() Then
			DocumentObjectAdditionalExpenses = DocumentRefAdditionalExpenses.GetObject()
		EndIf;
		
		// Negative balance by the purchase order.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectAdditionalExpenses, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectAdditionalExpenses, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefAdditionalExpenses, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	AdditionalExpenses.Ref AS Ref,
	|	AdditionalExpenses.Date AS Period,
	|	&Company AS Company,
	|	AdditionalExpenses.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	AdditionalExpenses.Counterparty AS Counterparty,
	|	AdditionalExpenses.Contract AS Contract,
	|	AdditionalExpenses.PurchaseOrder AS PurchaseOrder,
	|	AdditionalExpenses.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpenses.ExchangeRate AS ExchangeRate,
	|	AdditionalExpenses.Multiplicity AS Multiplicity,
	|	AdditionalExpenses.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	AdditionalExpenses.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	AdditionalExpenses.SetPaymentTerms AS SetPaymentTerms,
	|	AdditionalExpenses.IncludeVATInPrice AS IncludeVATInPrice,
	|	AdditionalExpenses.AmountIncludesVAT AS AmountIncludesVAT,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AdditionalExpenses.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AdditionalExpenses.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount
	|INTO TT_HeaderIncomplete
	|FROM
	|	Document.AdditionalExpenses AS AdditionalExpenses
	|WHERE
	|	AdditionalExpenses.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_HeaderIncomplete.Ref AS Ref,
	|	TT_HeaderIncomplete.Period AS Period,
	|	TT_HeaderIncomplete.Company AS Company,
	|	TT_HeaderIncomplete.CompanyVATNumber AS CompanyVATNumber,
	|	TT_HeaderIncomplete.PresentationCurrency AS PresentationCurrency,
	|	TT_HeaderIncomplete.Counterparty AS Counterparty,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_HeaderIncomplete.AccountsPayableGLAccount AS GLAccountVendorSettlements,
	|	TT_HeaderIncomplete.AdvancesPaidGLAccount AS VendorAdvancesGLAccount,
	|	TT_HeaderIncomplete.Contract AS Contract,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	TT_HeaderIncomplete.PurchaseOrder AS PurchaseOrder,
	|	TT_HeaderIncomplete.DocumentCurrency AS DocumentCurrency,
	|	TT_HeaderIncomplete.ExchangeRate AS ExchangeRate,
	|	TT_HeaderIncomplete.Multiplicity AS Multiplicity,
	|	TT_HeaderIncomplete.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TT_HeaderIncomplete.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TT_HeaderIncomplete.SetPaymentTerms AS SetPaymentTerms,
	|	TT_HeaderIncomplete.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_HeaderIncomplete.AmountIncludesVAT AS AmountIncludesVAT
	|INTO TT_Header
	|FROM
	|	TT_HeaderIncomplete AS TT_HeaderIncomplete
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TT_HeaderIncomplete.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TT_HeaderIncomplete.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Table.ReceiptDocument AS SupplierInvoice,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.PurchaseOrder AS PurchaseOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.VATRate AS VATRate
	|INTO ReceiptDocuments
	|FROM
	|	TT_Header AS Header
	|		INNER JOIN Document.AdditionalExpenses.Inventory AS Table
	|		ON Header.Ref = Table.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Table.SupplierInvoice AS SupplierInvoice,
	|	Table.Company AS Company,
	|	Table.PresentationCurrency AS PresentationCurrency,
	|	Table.Counterparty AS Counterparty,
	|	Table.Contract AS Contract,
	|	Table.PurchaseOrder AS PurchaseOrder,
	|	Table.Products AS Products,
	|	Table.Characteristic AS Characteristic,
	|	Table.Batch AS Batch,
	|	Table.VATRate AS VATRate,
	|	Table.QuantityBalance AS Quantity
	|INTO AdvanceInvoices
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived.Balance(
	|			&PointInTime,
	|			(SupplierInvoice, Company, PresentationCurrency, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch, VATRate) IN
	|				(SELECT
	|					Table.SupplierInvoice AS SupplierInvoice,
	|					Table.Company AS Company,
	|					Table.PresentationCurrency AS PresentationCurrency,
	|					Table.Counterparty AS Counterparty,
	|					Table.Contract AS Contract,
	|					Table.PurchaseOrder AS PurchaseOrder,
	|					Table.Products AS Products,
	|					Table.Characteristic AS Characteristic,
	|					Table.Batch AS Batch,
	|					Table.VATRate AS VATRate
	|				FROM
	|					ReceiptDocuments AS Table)) AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesInventory.LineNumber AS LineNumber,
	|	TT_Header.Period AS Period,
	|	TT_Header.Company AS Company,
	|	TT_Header.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Header.PresentationCurrency AS PresentationCurrency,
	|	TT_Header.Counterparty AS Counterparty,
	|	TT_Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TT_Header.Contract AS Contract,
	|	TT_Header.SettlementsCurrency AS SettlementsCurrency,
	|	TT_Header.PurchaseOrder AS PurchaseOrder,
	|	AdditionalExpensesInventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AdditionalExpensesInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AdditionalExpensesInventory.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	AdditionalExpensesInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN AdditionalExpensesInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN AdditionalExpensesInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	AdditionalExpensesInventory.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	AdditionalExpensesInventory.SalesOrder AS SalesOrder,
	|	AdditionalExpensesInventory.PurchaseOrder AS InventoryPurchaseOrder,
	|	AdditionalExpensesInventory.VATRate AS VATRate,
	|	CASE
	|		WHEN VALUETYPE(AdditionalExpensesInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AdditionalExpensesInventory.Quantity
	|		ELSE AdditionalExpensesInventory.Quantity * AdditionalExpensesInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(AdditionalExpensesInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(AdditionalExpensesInventory.AmountExpense * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(AdditionalExpensesInventory.AmountExpense * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountExpenseCur,
	|	TT_Header.SetPaymentTerms AS SetPaymentTerms,
	|	AdditionalExpensesInventory.ReceiptDocument AS ReceiptDocument,
	|	CASE
	|		WHEN AdvanceInvoices.SupplierInvoice IS NULL
	|			THEN FALSE
	|		ELSE TRUE
	|	END AS AdvanceInvoicing,
	|	SupplierInvoiceRef.Counterparty AS Supplier,
	|	SupplierInvoiceRef.Contract AS SupplierContract,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject
	|INTO TemporaryTableInventory
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.AdditionalExpenses.Inventory AS AdditionalExpensesInventory
	|		ON TT_Header.Ref = AdditionalExpensesInventory.Ref
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoiceRef
	|		ON (AdditionalExpensesInventory.ReceiptDocument = SupplierInvoiceRef.Ref)
	|		LEFT JOIN AdvanceInvoices AS AdvanceInvoices
	|		ON (AdditionalExpensesInventory.ReceiptDocument = AdvanceInvoices.SupplierInvoice)
	|			AND TT_Header.Company = AdvanceInvoices.Company
	|			AND TT_Header.PresentationCurrency = AdvanceInvoices.PresentationCurrency
	|			AND TT_Header.Counterparty = AdvanceInvoices.Counterparty
	|			AND TT_Header.Contract = AdvanceInvoices.Contract
	|			AND TT_Header.PurchaseOrder = AdvanceInvoices.PurchaseOrder
	|			AND (AdditionalExpensesInventory.Products = AdvanceInvoices.Products)
	|			AND (AdditionalExpensesInventory.Characteristic = AdvanceInvoices.Characteristic)
	|			AND (AdditionalExpensesInventory.Batch = AdvanceInvoices.Batch)
	|			AND (AdditionalExpensesInventory.VATRate = AdvanceInvoices.VATRate)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (AdditionalExpensesInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (AdditionalExpensesInventory.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesExpenses.LineNumber AS LineNumber,
	|	TT_Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_Header.Period AS Period,
	|	TT_Header.Counterparty AS Counterparty,
	|	TT_Header.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpensesExpenses.Ref AS Document,
	|	AdditionalExpensesExpenses.Products.BusinessLine AS BusinessLine,
	|	TT_Header.Company AS Company,
	|	TT_Header.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Header.PresentationCurrency AS PresentationCurrency,
	|	AdditionalExpensesExpenses.Products AS Products,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	&OwnInventory AS Ownership,
	|	TT_Header.PurchaseOrder AS PurchaseOrder,
	|	AdditionalExpensesExpenses.VATRate AS VATRate,
	|	CASE
	|		WHEN VALUETYPE(AdditionalExpensesExpenses.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN AdditionalExpensesExpenses.Quantity
	|		ELSE AdditionalExpensesExpenses.Quantity * AdditionalExpensesExpenses.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CAST(CASE
	|			WHEN TT_Header.IncludeVATInPrice
	|				THEN 0
	|			ELSE AdditionalExpensesExpenses.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(AdditionalExpensesExpenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS AmountVATPurchase,
	|	CAST(AdditionalExpensesExpenses.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(AdditionalExpensesExpenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(AdditionalExpensesExpenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseCur,
	|	CAST(AdditionalExpensesExpenses.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	AdditionalExpensesExpenses.VATAmount AS AmountVATPurchaseDocCur,
	|	AdditionalExpensesExpenses.Total AS AmountDocCur,
	|	TT_Header.SettlementsCurrency AS SettlementsCurrency,
	|	TT_Header.SetPaymentTerms AS SetPaymentTerms,
	|	TT_Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN AdditionalExpensesExpenses.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount
	|INTO TemporaryTableExpenses
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.AdditionalExpenses.Expenses AS AdditionalExpensesExpenses
	|		ON TT_Header.Ref = AdditionalExpensesExpenses.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	TT_Header.Period AS Period,
	|	TT_Header.Company AS Company,
	|	TT_Header.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Header.PresentationCurrency AS PresentationCurrency,
	|	TT_Header.Counterparty AS Counterparty,
	|	TT_Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TT_Header.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TT_Header.Contract AS Contract,
	|	TT_Header.SettlementsCurrency AS SettlementsCurrency,
	|	TT_Header.PurchaseOrder AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END AS Item,
	|	DocumentTable.Document.Date AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	TT_Header.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.AdditionalExpenses.Prepayment AS DocumentTable
	|		ON TT_Header.Ref = DocumentTable.Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	TT_Header.Period,
	|	TT_Header.Company,
	|	TT_Header.CompanyVATNumber,
	|	TT_Header.PresentationCurrency,
	|	TT_Header.Counterparty,
	|	TT_Header.Contract,
	|	TT_Header.SettlementsCurrency,
	|	TT_Header.GLAccountVendorSettlements,
	|	TT_Header.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE DocumentTable.Document.Item
	|	END,
	|	DocumentTable.Document.Date,
	|	TT_Header.PurchaseOrder,
	|	TT_Header.DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders,
	|	TT_Header.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	TT_Header.Company AS Company,
	|	TT_Header.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Header.PresentationCurrency AS PresentationCurrency,
	|	TT_Header.Counterparty AS Counterparty,
	|	TT_Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TT_Header.Contract AS Contract,
	|	TT_Header.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	VALUE(Document.PurchaseOrder.EmptyRef) AS Order,
	|	CASE
	|		WHEN TT_Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|				END AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN TT_Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|				END AS NUMBER(15, 2))
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.AdditionalExpenses.PaymentCalendar AS Calendar
	|		ON TT_Header.Ref = Calendar.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.CompanyVATNumber AS CompanyVATNumber,
	|	Calendar.PresentationCurrency AS PresentationCurrency,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroupWithHeader AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.CompanyVATNumber,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Calendar.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Period AS Period,
	|	Header.Counterparty AS Customer,
	|	PrepaymentVAT.Document AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	SUM(PrepaymentVAT.VATAmount) AS VATAmount,
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT,
	|	Header.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	Document.AdditionalExpenses.PrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN TT_Header AS Header
	|		ON PrepaymentVAT.Ref = Header.Ref
	|WHERE
	|	NOT PrepaymentVAT.VATRate.NotTaxable
	|
	|GROUP BY
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.PresentationCurrency,
	|	Header.Period,
	|	Header.Counterparty,
	|	PrepaymentVAT.Document,
	|	PrepaymentVAT.VATRate,
	|	Header.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentWithoutInvoice
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentPostBySourceDocuments
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN AccumulationRegister.VATInput AS VATInput
	|		ON PrepaymentVAT.ShipmentDocument = VATInput.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(AdditionalExpensesCustomsDeclaration.LineNumber) AS LineNumber,
	|	TT_Header.Period AS Period,
	|	TT_Header.Company AS Company,
	|	TT_Header.CompanyVATNumber AS CompanyVATNumber,
	|	TT_Header.PresentationCurrency AS PresentationCurrency,
	|	TT_Header.Counterparty AS Counterparty,
	|	TT_Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	TT_Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	TT_Header.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	TT_Header.Contract AS Contract,
	|	TT_Header.SettlementsCurrency AS SettlementsCurrency,
	|	TT_Header.PurchaseOrder AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	&Ref AS DocumentWhere,
	|	AdditionalExpensesCustomsDeclaration.Document AS Document,
	|	TT_Header.SetPaymentTerms AS SetPaymentTerms,
	|	SUM(CAST(AdditionalExpensesCustomsDeclaration.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN TT_Header.ExchangeRate / TT_Header.Multiplicity
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN TT_Header.Multiplicity / TT_Header.ExchangeRate
	|			END AS NUMBER(15, 2))) AS Amount,
	|	SUM(CAST(AdditionalExpensesCustomsDeclaration.Amount * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (TT_Header.ExchangeRate * TT_Header.ContractCurrencyMultiplicity / (TT_Header.ContractCurrencyExchangeRate * TT_Header.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AmountCur,
	|	AdditionalExpensesCustomsDeclaration.IncludeToCurrentInvoice AS IncludeToCurrentInvoice,
	|	CustomsDeclaration.Counterparty AS Broker,
	|	CustomsDeclaration.Contract AS BrokerContract
	|INTO TemporaryTableCustomsDeclaration
	|FROM
	|	TT_Header AS TT_Header
	|		INNER JOIN Document.AdditionalExpenses.CustomsDeclaration AS AdditionalExpensesCustomsDeclaration
	|			INNER JOIN Document.CustomsDeclaration AS CustomsDeclaration
	|			ON AdditionalExpensesCustomsDeclaration.Document = CustomsDeclaration.Ref
	|		ON TT_Header.Ref = AdditionalExpensesCustomsDeclaration.Ref
	|
	|GROUP BY
	|	AdditionalExpensesCustomsDeclaration.Ref,
	|	AdditionalExpensesCustomsDeclaration.Document,
	|	TT_Header.Period,
	|	TT_Header.Company,
	|	TT_Header.CompanyVATNumber,
	|	TT_Header.PresentationCurrency,
	|	TT_Header.SettlementsCurrency,
	|	TT_Header.GLAccountVendorSettlements,
	|	TT_Header.VendorAdvancesGLAccount,
	|	TT_Header.PurchaseOrder,
	|	TT_Header.DoOperationsByContracts,
	|	TT_Header.DoOperationsByOrders,
	|	TT_Header.SetPaymentTerms,
	|	AdditionalExpensesCustomsDeclaration.IncludeToCurrentInvoice,
	|	TT_Header.Counterparty,
	|	TT_Header.Contract,
	|	CustomsDeclaration.Counterparty,
	|	CustomsDeclaration.Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	Query.SetParameter("Ref",							DocumentRefAdditionalExpenses);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",			StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",					StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("DocumentCurrency",				DocumentRefAdditionalExpenses.DocumentCurrency);
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("OwnInventory",					Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting",	StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.ExecuteBatch();
	
	GenerateTableInventory(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableGoodsInvoicedNotReceived(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties);
		
	EndIf;
	
	
EndProcedure

#EndRegion

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CostObject AS CostObject,
	|	CASE
	|		WHEN TableInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.SalesOrder
	|	END AS SalesOrder,
	|	TRUE AS FixedCost,
	|	&InventoryIncrease AS ContentOfAccountingRecord,
	|	0 AS Quantity,
	|	SUM(TableInventory.AmountExpense) AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.AdvanceInvoicing
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CostObject,
	|	TableInventory.SalesOrder,
	|	TableInventory.PresentationCurrency";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("InventoryIncrease", NStr("en = 'Landed costs'; ru = 'Дополнительные расходы';pl = 'Koszty z wyładunkiem';es_ES = 'Costes de entrega';es_CO = 'Costes de entrega';tr = 'Varış yeri maliyetleri';it = 'Costi di scarico';de = 'Wareneinstandspreise'", MainLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotReceived(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.ReceiptDocument AS SupplierInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Supplier AS Counterparty,
	|	TableProducts.SupplierContract AS Contract,
	|	TableProducts.InventoryPurchaseOrder AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.VATRate AS VATRate,
	|	0 AS Quantity,
	|	SUM(TableProducts.AmountExpense) AS Amount,
	|	0 AS VATAmount
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.AdvanceInvoicing
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.ReceiptDocument,
	|	TableProducts.Company,
	|	TableProducts.Supplier,
	|	TableProducts.SupplierContract,
	|	TableProducts.InventoryPurchaseOrder,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.VATRate,
	|	TableProducts.PresentationCurrency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SUM(TemporaryTable.Amount) AS AmountWithVAT,
	|	SUM(TemporaryTable.AmountCur) AS AmountWithVATCur
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable
	|
	|GROUP BY
	|	TemporaryTable.Period,
	|	TemporaryTable.Company";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	AmountWithVAT = 0;
	AmountWithVATCur = 0;
	
	While Selection.Next() Do  
		AmountWithVAT		= Selection.AmountWithVAT;
		AmountWithVATCur	= Selection.AmountWithVATCur;
	EndDo;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"							, DocumentRefAdditionalExpenses);
	Query.SetParameter("PointInTime"					, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"					, StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company"						, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("AppearenceOfLiabilityToVendor"	, NStr("en = 'Accounts payable recognition'; ru = 'Возникновение обязательств перед поставщиком';pl = 'Powstanie zobowiązań wobec dostawcy';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento di debiti';de = 'Aufnahme von Offenen Posten Kreditoren'", MainLanguageCode));
	Query.SetParameter("AdvanceCredit"					, NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pago adelantado';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference"				, NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("CustomsDeclaration"				, NStr("en = 'Customs declaration'; ru = 'Таможенная декларация';pl = 'Deklaracja celna';es_ES = 'Declaración de la aduana';es_CO = 'Declaración de la aduana';tr = 'Gümrük beyannamesi';it = 'Dichiarazione doganale';de = 'Zollanmeldung'", MainLanguageCode));
	Query.SetParameter("AmountWithVAT"					, AmountWithVAT);
	Query.SetParameter("AmountWithVATCur"				, AmountWithVATCur);
	Query.SetParameter("ExpectedPayments"				, NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod"				, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting"		, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	&Ref AS Document,
	|	CASE
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	&AmountWithVAT AS Amount,
	|	&AmountWithVATCur AS AmountCur,
	|	&AmountWithVAT AS AmountForBalance,
	|	&AmountWithVATCur AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVAT
	|	END AS AmountForPayment,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVATCur
	|	END AS AmountForPaymentCur
	|INTO TemporaryTableAccountsPayable
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	CASE
	|		WHEN DocumentTable.PurchaseOrder REFS Document.PurchaseOrder
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVAT
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE &AmountWithVATCur
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
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
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&AdvanceCredit AS STRING(100)),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
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
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlemensTypeWhere
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
	|	Calendar.GLAccountVendorSettlements,
	|	Calendar.Contract,
	|	Calendar.DocumentWhere,
	|	CASE
	|		WHEN Calendar.DoOperationsByOrders
	|				AND Calendar.Order REFS Document.PurchaseOrder
	|				AND Calendar.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN Calendar.Order
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	CAST(&ExpectedPayments AS STRING(100)),
	|	Calendar.Amount,
	|	Calendar.AmountCur
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Broker,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.BrokerContract,
	|	DocumentTable.Document,
	|	UNDEFINED,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	-SUM(DocumentTable.Amount),
	|	-SUM(DocumentTable.AmountCur),
	|	CAST(&CustomsDeclaration AS STRING(100)),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
	|FROM
	|	TemporaryTableCustomsDeclaration AS DocumentTable
	|WHERE
	|	DocumentTable.IncludeToCurrentInvoice
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Broker,
	|	DocumentTable.BrokerContract,
	|	DocumentTable.Document,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	UNDEFINED,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.SettlementsType,
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&CustomsDeclaration AS STRING(100)),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END),
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END)
	|FROM
	|	TemporaryTableCustomsDeclaration AS DocumentTable
	|WHERE
	|	DocumentTable.IncludeToCurrentInvoice
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	DocumentTable.SettlementsType,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.VendorAdvancesGLAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts payable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsPayable.Company AS Company,
	|	TemporaryTableAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsPayable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsPayable.Contract AS Contract,
	|	TemporaryTableAccountsPayable.Document AS Document,
	|	TemporaryTableAccountsPayable.Order AS Order,
	|	TemporaryTableAccountsPayable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsPayable AS TemporaryTableAccountsPayable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsPayable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesAccountsPayable(Query.TempTablesManager, True, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.PresentationCurrency AS PresentationCurrency,
	|	TablePurchases.Counterparty AS Counterparty,
	|	TablePurchases.DocumentCurrency AS Currency,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	CASE
	|		WHEN TablePurchases.PurchaseOrder = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TablePurchases.PurchaseOrder
	|	END AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.AmountVATPurchase) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.AmountVATPurchase) AS Amount,
	|	SUM(TablePurchases.AmountVATPurchaseDocCur) AS VATAmountCur,
	|	SUM(TablePurchases.AmountDocCur - TablePurchases.AmountVATPurchaseDocCur) AS AmountCur
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.DocumentCurrency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TablePurchaseOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TablePurchaseOrders.Period AS Period,
	|	TablePurchaseOrders.Company AS Company,
	|	TablePurchaseOrders.Products AS Products,
	|	TablePurchaseOrders.Characteristic AS Characteristic,
	|	TablePurchaseOrders.PurchaseOrder AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableExpenses AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchaseOrders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	UNDEFINED AS SalesOrder,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXExpenseItem
	|		ELSE &FXIncomeItem
	|	END AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
	|		ELSE &PositiveExchangeDifferenceGLAccount
	|	END AS GLAccount,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.PresentationCurrency AS PresentationCurrency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.PresentationCurrency AS PresentationCurrency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.PresentationCurrency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
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
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",								Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAdditionalExpenses);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
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
	|	DocumentTable.BusinessLine AS BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|ORDER BY
	|	DocumentTable.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.Company AS Company,
	|	SUM(DocumentTable.Amount) AS AmountToBeWrittenOff
	|FROM
	|	TemporaryTablePrepayment AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|
	|GROUP BY
	|	DocumentTable.Company
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
	
	TableInventoryIncomeAndExpensesRetained =  ResultsArray[0].Unload();
	SelectionOfQueryResult = ResultsArray[1].Select();
	
	TablePrepaymentIncomeAndExpensesRetained = TableInventoryIncomeAndExpensesRetained.Copy();
	TablePrepaymentIncomeAndExpensesRetained.Clear();
	
	If SelectionOfQueryResult.Next() Then
		AmountToBeWrittenOff = SelectionOfQueryResult.AmountToBeWrittenOff;
		For Each StringInventoryIncomeAndExpensesRetained In TableInventoryIncomeAndExpensesRetained Do
			If AmountToBeWrittenOff = 0 Then
				Continue
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense <= AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				AmountToBeWrittenOff = AmountToBeWrittenOff - StringInventoryIncomeAndExpensesRetained.AmountExpense;
			ElsIf StringInventoryIncomeAndExpensesRetained.AmountExpense > AmountToBeWrittenOff Then
				StringPrepaymentIncomeAndExpensesRetained = TablePrepaymentIncomeAndExpensesRetained.Add();
				FillPropertyValues(StringPrepaymentIncomeAndExpensesRetained, StringInventoryIncomeAndExpensesRetained);
				StringPrepaymentIncomeAndExpensesRetained.AmountExpense = AmountToBeWrittenOff;
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
		Item = Catalogs.CashFlowItems.PaymentToVendor;
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
	|	Table.AmountExpense AS AmountExpense
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
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
	|	DocumentTable.Amount AS AmountExpense
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefAdditionalExpenses);
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
	|	-DocumentTable.Amount AS AmountExpense
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
	|	Table.AmountExpense
	|FROM
	|	TemporaryTablePrepaidIncomeAndExpensesRetained AS Table";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref"                 , DocumentRefAdditionalExpenses);
	Query.SetParameter("PointInTime"         , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company"             , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod"  , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	
	Query.Text =
	"SELECT
	|	AdditionalExpenses.Ref AS Ref,
	|	AdditionalExpenses.AmountIncludesVAT AS AmountIncludesVAT,
	|	AdditionalExpenses.Date AS Date,
	|	AdditionalExpenses.PaymentMethod AS PaymentMethod,
	|	AdditionalExpenses.Contract AS Contract,
	|	AdditionalExpenses.PettyCash AS PettyCash,
	|	AdditionalExpenses.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpenses.BankAccount AS BankAccount,
	|	AdditionalExpenses.ExchangeRate AS ExchangeRate,
	|	AdditionalExpenses.Multiplicity AS Multiplicity,
	|	AdditionalExpenses.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	AdditionalExpenses.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	AdditionalExpenses.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.AdditionalExpenses AS AdditionalExpenses
	|WHERE
	|	AdditionalExpenses.Ref = &Ref
	|	AND AdditionalExpenses.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AdditionalExpensesPaymentCalendar.PaymentDate AS Period,
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
	|			THEN AdditionalExpensesPaymentCalendar.PaymentAmount
	|		ELSE AdditionalExpensesPaymentCalendar.PaymentAmount + AdditionalExpensesPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.AdditionalExpenses.PaymentCalendar AS AdditionalExpensesPaymentCalendar
	|		ON Document.Ref = AdditionalExpensesPaymentCalendar.Ref
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
	|	PaymentCalendar.Quote AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(-PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount,
	|	PaymentCalendar.CashAssetType AS CashAssetType
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Order,
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
	|			THEN TableAccountingJournalEntries.AmountExpenseCur
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
	|			THEN TableAccountingJournalEntries.AmountExpenseCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.AmountExpense AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.GLAccountVendorSettlementsCurrency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END,
	|	DocumentTable.VendorAdvancesGLAccount,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
	|			THEN DocumentTable.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.VendorAdvancesGLAccountCurrency
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
	|		DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency AS VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency AS GLAccountVendorSettlementsCurrency,
	|		DocumentTable.SettlementsCurrency AS SettlementsCurrency,
	|		SUM(DocumentTable.AmountCur) AS AmountCur,
	|		SUM(DocumentTable.Amount) AS Amount
	|	FROM
	|		(SELECT
	|			DocumentTable.Period AS Period,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|			DocumentTable.VendorAdvancesGLAccount.Currency AS VendorAdvancesGLAccountCurrency,
	|			DocumentTable.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|			DocumentTable.GLAccountVendorSettlements.Currency AS GLAccountVendorSettlementsCurrency,
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
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount,
	|			DocumentTable.Counterparty.VendorAdvancesGLAccount.Currency,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements,
	|			DocumentTable.Counterparty.GLAccountVendorSettlements.Currency,
	|			DocumentTable.Currency,
	|			0,
	|			DocumentTable.AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS DocumentTable
	|	
	|	GROUP BY
	|		DocumentTable.Period,
	|		DocumentTable.Company,
	|		DocumentTable.VendorAdvancesGLAccount,
	|		DocumentTable.VendorAdvancesGLAccountCurrency,
	|		DocumentTable.GLAccountVendorSettlements,
	|		DocumentTable.GLAccountVendorSettlementsCurrency,
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
	|	3,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchangeDifferenceAccountOfAccounting
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
	|			THEN TableAccountingJournalEntries.GLAccount
	|		ELSE &PositiveExchangeDifferenceGLAccount
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
	|			THEN TableAccountingJournalEntries.AmountOfExchangeDifferences
	|		ELSE -TableAccountingJournalEntries.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	(SELECT
	|		TableOfExchangeRateDifferencesAccountsPayable.Date AS Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company AS Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount AS GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency AS GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency AS Currency,
	|		SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences
	|	FROM
	|		(SELECT
	|			DocumentTable.Date AS Date,
	|			DocumentTable.Company AS Company,
	|			DocumentTable.GLAccount AS GLAccount,
	|			DocumentTable.GLAccount.Currency AS GLAccountForeignCurrency,
	|			DocumentTable.Currency AS Currency,
	|			DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
	|		FROM
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
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
	|			TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
	|		WHERE
	|			DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableOfExchangeRateDifferencesAccountsPayable
	|	
	|	GROUP BY
	|		TableOfExchangeRateDifferencesAccountsPayable.Date,
	|		TableOfExchangeRateDifferencesAccountsPayable.Company,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccount,
	|		TableOfExchangeRateDifferencesAccountsPayable.GLAccountForeignCurrency,
	|		TableOfExchangeRateDifferencesAccountsPayable.Currency
	|	
	|	HAVING
	|		(SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) >= 0.005
	|			OR SUM(TableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences) <= -0.005)) AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	4,
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
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount > 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.VATInputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	0,
	|	&VATInput,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
	|	AND PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL
	|	AND &PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	0,
	|	&VATInput,
	|	UNDEFINED,
	|	0,
	|	SUM(PrepaymentVAT.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|		INNER JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|WHERE
	|	&PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
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
	|				THEN TableAccountingJournalEntries.AmountCur
	|			ELSE 0
	|		END),
	|	SUM(TableAccountingJournalEntries.Amount),
	|	&CustomsDeclaration,
	|	FALSE
	|FROM
	|	TemporaryTableCustomsDeclaration AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.IncludeToCurrentInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	8,
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
	|	Order";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("InventoryIncrease",								NStr("en = 'Landed costs allocated to inventory'; ru = 'Дополнительные расходы отнесены на затраты';pl = 'Koszty własne przydzielone zapasom';es_ES = 'Costes de entrega se asignarán al inventario';es_CO = 'Costes en destino se asignarán al inventario';tr = 'Varış yeri maliyetleri stoğa dağıtıldı';it = 'Costi di scarico assegnati alle scorte';de = 'Wareneinstandspreise werden dem Bestand zugewiesen'", MainLanguageCode));
	Query.SetParameter("SetOffAdvancePayment",							NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("CustomsDeclaration",							NStr("en = 'Customs declaration'; ru = 'Таможенная декларация';pl = 'Deklaracja celna';es_ES = 'Declaración de la aduana';es_CO = 'Declaración de la aduana';tr = 'Gümrük beyannamesi';it = 'Dichiarazione doganale';de = 'Zollanmeldung'", MainLanguageCode));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VAT",											NStr("en = 'VAT'; ru = 'НДС';pl = 'Kwota VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRefAdditionalExpenses);
	Query.SetParameter("ContentVATRevenue",								NStr("en = 'Advance VAT clearing'; ru = 'Зачет аванса';pl = 'Zaliczkowe rozliczenie podatku VAT';es_ES = 'Eliminación del IVA de anticipo';es_CO = 'Eliminación del IVA de anticipo';tr = 'Peşin KDV mahsuplaştırılması';it = 'Annullamento dell''anticipo IVA';de = 'USt. -Vorschussverrechnung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",										Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("PostVATEntriesBySourceDocuments",				StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	
	QueryResult = Query.Execute();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableLandedCosts(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
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
	|	TableInventory.ReceiptDocument AS CostLayer,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	SUM(TableInventory.AmountExpense) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	&UseFIFO
	|	AND VALUETYPE(TableInventory.ReceiptDocument) = TYPE(Document.SupplierInvoice)
	|	AND NOT TableInventory.AdvanceInvoicing
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Products,
	|	CASE
	|		WHEN TableInventory.SalesOrder <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableInventory.SalesOrder <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TableInventory.SalesOrder
	|		ELSE UNDEFINED
	|	END,
	|	TableInventory.ReceiptDocument,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount";
	
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableVATIncurred(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or DocumentRefAdditionalExpenses.VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT
		Or DocumentRefAdditionalExpenses.Counterparty = Catalogs.Counterparties.RetailCustomer Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	
	If NOT StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		
		QueryText = 
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TemporaryTableExpenses.Document AS ShipmentDocument,
		|	TemporaryTableExpenses.VATRate AS VATRate,
		|	TemporaryTableExpenses.Period AS Period,
		|	TemporaryTableExpenses.Company AS Company,
		|	TemporaryTableExpenses.CompanyVATNumber AS CompanyVATNumber,
		|	TemporaryTableExpenses.PresentationCurrency AS PresentationCurrency,
		|	TemporaryTableExpenses.Counterparty AS Supplier,
		|	TemporaryTableExpenses.VATInputGLAccount AS GLAccount,
		|	SUM(TemporaryTableExpenses.VATAmount) AS VATAmount,
		|	SUM(TemporaryTableExpenses.Amount - TemporaryTableExpenses.VATAmount) AS AmountExcludesVAT
		|FROM
		|	TemporaryTableExpenses AS TemporaryTableExpenses
		|
		|GROUP BY
		|	TemporaryTableExpenses.VATRate,
		|	TemporaryTableExpenses.Document,
		|	TemporaryTableExpenses.Period,
		|	TemporaryTableExpenses.Company,
		|	TemporaryTableExpenses.CompanyVATNumber,
		|	TemporaryTableExpenses.PresentationCurrency,
		|	TemporaryTableExpenses.Counterparty,
		|	TemporaryTableExpenses.VATInputGLAccount";
		
	EndIf;
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + DriveClientServer.GetQueryUnion();
	EndIf;
	
	QueryText = QueryText +
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	PrepaymentVAT.Period AS Period,
	|	PrepaymentVAT.Company AS Company,
	|	PrepaymentVAT.CompanyVATNumber AS CompanyVATNumber,
	|	PrepaymentVAT.PresentationCurrency AS PresentationCurrency,
	|	PrepaymentVAT.Customer AS Supplier,
	|	&VATAdvancesToSuppliers AS GLAccount,
	|	PrepaymentVAT.VATAmount AS VATAmount,
	|	PrepaymentVAT.AmountExcludesVAT AS AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|WHERE
	|	PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("VATAdvancesToSuppliers", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableVATInput(DocumentRefAdditionalExpenses, StructureAdditionalProperties)
	
	If NOT StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or NOT StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments
		Or DocumentRefAdditionalExpenses.VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT
		Or DocumentRefAdditionalExpenses.Counterparty = Catalogs.Counterparties.RetailCustomer Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableExpenses.Document AS ShipmentDocument,
	|	TemporaryTableExpenses.VATRate AS VATRate,
	|	TemporaryTableExpenses.Period AS Period,
	|	TemporaryTableExpenses.Company AS Company,
	|	TemporaryTableExpenses.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableExpenses.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableExpenses.Counterparty AS Supplier,
	|	TemporaryTableExpenses.VATInputGLAccount AS GLAccount,
	|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
	|	VALUE(Enum.ProductsTypes.Service) AS ProductType,
	|	SUM(TemporaryTableExpenses.VATAmount) AS VATAmount,
	|	SUM(TemporaryTableExpenses.Amount - TemporaryTableExpenses.VATAmount) AS AmountExcludesVAT
	|FROM
	|	TemporaryTableExpenses AS TemporaryTableExpenses
	|
	|GROUP BY
	|	TemporaryTableExpenses.Document,
	|	TemporaryTableExpenses.VATRate,
	|	TemporaryTableExpenses.Company,
	|	TemporaryTableExpenses.CompanyVATNumber,
	|	TemporaryTableExpenses.PresentationCurrency,
	|	TemporaryTableExpenses.Counterparty,
	|	TemporaryTableExpenses.VATInputGLAccount,
	|	TemporaryTableExpenses.Period
	|
	|UNION ALL
	|
	|SELECT
	|	PrepaymentVAT.ShipmentDocument,
	|	PrepaymentVAT.VATRate,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	PrepaymentVAT.CompanyVATNumber,
	|	PrepaymentVAT.PresentationCurrency,
	|	PrepaymentVAT.Customer,
	|	&VATAdvancesToSuppliers,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	-PrepaymentVAT.VATAmount,
	|	-PrepaymentVAT.AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|
	|UNION ALL
	|
	|SELECT
	|	PrepaymentVAT.ShipmentDocument,
	|	PrepaymentVAT.VATRate,
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company,
	|	PrepaymentVAT.CompanyVATNumber,
	|	PrepaymentVAT.PresentationCurrency,
	|	PrepaymentVAT.Customer,
	|	&VATAdvancesToSuppliers,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	-PrepaymentVAT.VATAmount,
	|	-PrepaymentVAT.AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
	|	AND PrepaymentPostBySourceDocuments.ShipmentDocument IS NULL";
	
	Query.SetParameter("VATAdvancesToSuppliers", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.AccountsPayableGLAccount);
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", ObjectParameters.AdvancesPaidGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.TabName = "Inventory" Then
			If StructureData.AdvanceInvoicing Then
				GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount", StructureData.GoodsInvoicedNotDeliveredGLAccount);
			EndIf;
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		ElsIf StructureData.TabName = "Expenses" Then
			GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		EndIf;
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

#EndIf