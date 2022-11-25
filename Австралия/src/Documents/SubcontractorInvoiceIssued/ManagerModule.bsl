#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsReceivableGLAccount", ObjectParameters.AccountsReceivableGLAccount);
		GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", ObjectParameters.AdvancesReceivedGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.TabName = "Products" Then
			GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
			GLAccountsForFilling.Insert("RevenueGLAccount", StructureData.RevenueGLAccount);
			GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
			GLAccountsForFilling.Insert("CostOfSalesGLAccount", StructureData.CostOfSalesGLAccount);
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	Parameters.Insert("Counterparty", DocObject.Counterparty);
	Parameters.Insert("Contract", DocObject.Contract);
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerOwnedInventory);
	ParametersSet.Add(Parameters);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Inventory");
	Parameters.Insert("Counterparty", DocObject.Counterparty);
	Parameters.Insert("Contract", DocObject.Contract);
	Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
	ParametersSet.Add(Parameters);
	
	Return ParametersSet;
	
EndFunction

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
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
	|	Header.Contract AS Contract,
	|	Header.Order AS Order,
	|	Header.AmountIncludesVAT AS AmountIncludesVAT,
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsReceivableGLAccount,
	|	Header.BasisDocument AS BasisDocument,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.VATTaxation AS VATTaxation,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Header.SetPaymentTerms AS SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesReceivedGLAccount,
	|	Header.Responsible AS Responsible,
	|	Header.Department AS Department,
	|	Header.IncludeVATInPrice AS IncludeVATInPrice
	|INTO SubcontractorInvoiceIssuedHeader
	|FROM
	|	Document.SubcontractorInvoiceIssued AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceIssuedHeader.Ref AS Ref,
	|	SubcontractorInvoiceIssuedHeader.Date AS Date,
	|	SubcontractorInvoiceIssuedHeader.Company AS Company,
	|	SubcontractorInvoiceIssuedHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceIssuedHeader.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceIssuedHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceIssuedHeader.Contract AS Contract,
	|	SubcontractorInvoiceIssuedHeader.Order AS Order,
	|	SubcontractorInvoiceIssuedHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorInvoiceIssuedHeader.ExchangeRate AS ExchangeRate,
	|	SubcontractorInvoiceIssuedHeader.Multiplicity AS Multiplicity,
	|	SubcontractorInvoiceIssuedHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorInvoiceIssuedHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorInvoiceIssuedHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	SubcontractorInvoiceIssuedHeader.BasisDocument AS BasisDocument,
	|	SubcontractorInvoiceIssuedHeader.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoiceIssuedHeader.VATTaxation AS VATTaxation,
	|	SubcontractorInvoiceIssuedHeader.StructuralUnit AS StructuralUnit,
	|	SubcontractorInvoiceIssuedHeader.SetPaymentTerms AS SetPaymentTerms,
	|	SubcontractorInvoiceIssuedHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount,
	|	SubcontractorInvoiceIssuedHeader.Responsible AS Responsible,
	|	SubcontractorInvoiceIssuedHeader.Department AS Department,
	|	SubcontractorInvoiceIssuedHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, VALUE(Catalog.CounterpartyContracts.EmptyRef)) AS SettlementsCurrency,
	|	ISNULL(Counterparties.DoOperationsByContracts, FALSE) AS DoOperationsByContracts,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders
	|INTO SubcontractorInvoiceIssuedTable
	|FROM
	|	SubcontractorInvoiceIssuedHeader AS SubcontractorInvoiceIssuedHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON SubcontractorInvoiceIssuedHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SubcontractorInvoiceIssuedHeader.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceIssuedTable.Ref AS Document,
	|	SubcontractorInvoiceIssuedTable.Date AS Period,
	|	SubcontractorInvoiceIssuedTable.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceIssuedTable.VATTaxation AS VATTaxation,
	|	SubcontractorInvoiceIssuedTable.BasisDocument AS BasisDocument,
	|	SubcontractorInvoiceIssuedTable.Counterparty AS Counterparty,
	|	SubcontractorInvoiceIssuedTable.Contract AS Contract,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorInvoiceIssuedTable.StructuralUnit AS StructuralUnit,
	|	SubcontractorInvoiceIssuedTable.SetPaymentTerms AS SetPaymentTerms,
	|	SubcontractorInvoiceIssuedTable.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoiceIssuedTable.ExchangeRate AS ExchangeRate,
	|	SubcontractorInvoiceIssuedTable.Multiplicity AS Multiplicity,
	|	SubcontractorInvoiceIssuedTable.SettlementsCurrency AS SettlementsCurrency,
	|	SubcontractorInvoiceIssuedProducts.LineNumber AS LineNumber,
	|	CatalogProducts.BusinessLine AS BusinessLineSales,
	|	CatalogProducts.ProductsType AS ProductsType,
	|	SubcontractorInvoiceIssuedProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorInvoiceIssuedProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	SubcontractorInvoiceIssuedProducts.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.CustomerOwnedFinishedProducts) AS CorrInventoryAccountType,
	|	SubcontractorInvoiceIssuedTable.Order AS Order,
	|	SubcontractorInvoiceIssuedTable.Department AS Department,
	|	SubcontractorInvoiceIssuedTable.Responsible AS Responsible,
	|	SubcontractorInvoiceIssuedProducts.Quantity AS Quantity,
	|	SubcontractorInvoiceIssuedProducts.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SubcontractorInvoiceIssuedProducts.Total * SubcontractorInvoiceIssuedTable.Multiplicity / SubcontractorInvoiceIssuedTable.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceIssuedProducts.Total * SubcontractorInvoiceIssuedTable.ExchangeRate / SubcontractorInvoiceIssuedTable.Multiplicity
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SubcontractorInvoiceIssuedTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SubcontractorInvoiceIssuedProducts.VATAmount * SubcontractorInvoiceIssuedTable.Multiplicity / SubcontractorInvoiceIssuedTable.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceIssuedProducts.VATAmount * SubcontractorInvoiceIssuedTable.ExchangeRate / SubcontractorInvoiceIssuedTable.Multiplicity
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorInvoiceIssuedTable.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SubcontractorInvoiceIssuedProducts.VATAmount * SubcontractorInvoiceIssuedTable.ContractCurrencyExchangeRate * SubcontractorInvoiceIssuedTable.Multiplicity / (SubcontractorInvoiceIssuedTable.ExchangeRate * SubcontractorInvoiceIssuedTable.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceIssuedProducts.VATAmount * SubcontractorInvoiceIssuedTable.ExchangeRate * SubcontractorInvoiceIssuedTable.ContractCurrencyMultiplicity / (SubcontractorInvoiceIssuedTable.ContractCurrencyExchangeRate * SubcontractorInvoiceIssuedTable.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SubcontractorInvoiceIssuedProducts.Total * SubcontractorInvoiceIssuedTable.ContractCurrencyExchangeRate * SubcontractorInvoiceIssuedTable.Multiplicity / (SubcontractorInvoiceIssuedTable.ExchangeRate * SubcontractorInvoiceIssuedTable.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceIssuedProducts.Total * SubcontractorInvoiceIssuedTable.ExchangeRate * SubcontractorInvoiceIssuedTable.ContractCurrencyMultiplicity / (SubcontractorInvoiceIssuedTable.ContractCurrencyExchangeRate * SubcontractorInvoiceIssuedTable.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CASE
	|		WHEN SubcontractorInvoiceIssuedTable.IncludeVATInPrice
	|			THEN 0
	|		ELSE SubcontractorInvoiceIssuedProducts.VATAmount
	|	END AS VATAmountDocCur,
	|	SubcontractorInvoiceIssuedProducts.Total AS AmountDocCur,
	|	SubcontractorInvoiceIssuedProducts.RevenueItem AS RevenueItem,
	|	SubcontractorInvoiceIssuedProducts.CostOfSalesItem AS CostOfSalesItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.CostOfSalesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CostOfSalesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS ConsumptionGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountStatementSales,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedTable.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.CostOfSalesGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceIssuedProducts.ConsumptionGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount
	|INTO TemporaryTableProducts
	|FROM
	|	Document.SubcontractorInvoiceIssued.Products AS SubcontractorInvoiceIssuedProducts
	|		INNER JOIN SubcontractorInvoiceIssuedTable AS SubcontractorInvoiceIssuedTable
	|		ON SubcontractorInvoiceIssuedProducts.Ref = SubcontractorInvoiceIssuedTable.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON SubcontractorInvoiceIssuedProducts.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.InventoryOwnership AS CatalogInventoryOwnership
	|		ON SubcontractorInvoiceIssuedProducts.Ownership = CatalogInventoryOwnership.Ref
	|WHERE
	|	SubcontractorInvoiceIssuedProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	SubcontractorInvoiceIssuedTable.Date AS Period,
	|	&Company AS Company,
	|	SubcontractorInvoiceIssuedTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceIssuedTable.Counterparty AS Counterparty,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorInvoiceIssuedTable.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	SubcontractorInvoiceIssuedTable.AdvancesReceivedGLAccount AS CustomerAdvancesGLAccount,
	|	SubcontractorInvoiceIssuedTable.Contract AS Contract,
	|	SubcontractorInvoiceIssuedTable.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	SubcontractorInvoiceIssuedTable.BasisDocument AS BasisDocument,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|	END AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	SubcontractorInvoiceIssuedTable.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SubcontractorInvoiceIssued.Prepayment AS DocumentTable
	|		INNER JOIN SubcontractorInvoiceIssuedTable AS SubcontractorInvoiceIssuedTable
	|		ON DocumentTable.Ref = SubcontractorInvoiceIssuedTable.Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	SubcontractorInvoiceIssuedTable.Date,
	|	SubcontractorInvoiceIssuedTable.Counterparty,
	|	SubcontractorInvoiceIssuedTable.Contract,
	|	DocumentTable.Order,
	|	SubcontractorInvoiceIssuedTable.SettlementsCurrency,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|	END,
	|	SubcontractorInvoiceIssuedTable.BasisDocument,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByContracts,
	|	SubcontractorInvoiceIssuedTable.DoOperationsByOrders,
	|	SubcontractorInvoiceIssuedTable.SetPaymentTerms,
	|	SubcontractorInvoiceIssuedTable.AccountsReceivableGLAccount,
	|	SubcontractorInvoiceIssuedTable.AdvancesReceivedGLAccount,
	|	SubcontractorInvoiceIssuedTable.CompanyVATNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Date AS Period,
	|	Header.Counterparty AS Customer,
	|	PrepaymentVAT.Document AS ShipmentDocument,
	|	PrepaymentVAT.VATRate AS VATRate,
	|	SUM(PrepaymentVAT.VATAmount) AS VATAmount,
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	SubcontractorInvoiceIssuedHeader AS Header
	|		INNER JOIN Document.SubcontractorInvoiceIssued.PrepaymentVAT AS PrepaymentVAT
	|		ON Header.Ref = PrepaymentVAT.Ref
	|WHERE
	|	NOT PrepaymentVAT.VATRate.NotTaxable
	|
	|GROUP BY
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.PresentationCurrency,
	|	Header.Date,
	|	Header.Counterparty,
	|	PrepaymentVAT.Document,
	|	PrepaymentVAT.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableProducts.DoOperationsByOrders AS DoOperationsByOrders,
	|	TemporaryTableProducts.Order AS Order,
	|	SUM(TemporaryTableProducts.AmountDocCur) AS Total
	|INTO TemporaryTableOrdersTotal
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|
	|GROUP BY
	|	TemporaryTableProducts.DoOperationsByOrders,
	|	TemporaryTableProducts.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableOrdersTotal.DoOperationsByOrders AS DoOperationsByOrders,
	|	SUM(TemporaryTableOrdersTotal.Total) AS Total
	|INTO TemporaryTableTotal
	|FROM
	|	TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|
	|GROUP BY
	|	TemporaryTableOrdersTotal.DoOperationsByOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceIssuedTable.Date AS Date,
	|	SubcontractorInvoiceIssuedTable.Company AS Company,
	|	SubcontractorInvoiceIssuedTable.Counterparty AS Counterparty,
	|	SubcontractorInvoiceIssuedTable.Order AS SubcontractorOrder,
	|	SubcontractorInvoiceIssuedInventory.Products AS Products,
	|	SubcontractorInvoiceIssuedInventory.Characteristic AS Characteristic,
	|	SubcontractorInvoiceIssuedInventory.Quantity AS Quantity,
	|	SubcontractorInvoiceIssuedInventory.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorInvoiceIssuedInventory.Ownership AS Ownership
	|INTO TemporaryTableInventory
	|FROM
	|	Document.SubcontractorInvoiceIssued.Inventory AS SubcontractorInvoiceIssuedInventory
	|		INNER JOIN SubcontractorInvoiceIssuedTable AS SubcontractorInvoiceIssuedTable
	|		ON SubcontractorInvoiceIssuedInventory.Ref = SubcontractorInvoiceIssuedTable.Ref
	|WHERE
	|	SubcontractorInvoiceIssuedInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.AccountsReceivableGLAccount AS GLAccountCustomerSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	ISNULL(TemporaryTableOrdersTotal.Order, VALUE(Document.SalesOrder.EmptyRef)) AS Order,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.Multiplicity / Header.ExchangeRate
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate / Header.Multiplicity
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.Multiplicity / Header.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate / Header.Multiplicity
	|				END AS NUMBER(15, 2))
	|	END * CAST(ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS NUMBER(15, 2)) AS Amount,
	|	CASE
	|		WHEN Header.AmountIncludesVAT
	|			THEN CAST(Calendar.PaymentAmount * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN Header.ContractCurrencyExchangeRate * Header.Multiplicity / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|					END AS NUMBER(15, 2))
	|		ELSE CAST((Calendar.PaymentAmount + Calendar.PaymentVATAmount) * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN Header.ContractCurrencyExchangeRate * Header.Multiplicity / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|				END AS NUMBER(15, 2))
	|	END * CAST(ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS NUMBER(15, 2)) AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	SubcontractorInvoiceIssuedTable AS Header
	|		INNER JOIN Document.SubcontractorInvoiceIssued.PaymentCalendar AS Calendar
	|		ON Header.Ref = Calendar.Ref
	|		LEFT JOIN TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|		ON (TemporaryTableOrdersTotal.DoOperationsByOrders)
	|		LEFT JOIN TemporaryTableTotal AS TemporaryTableTotal
	|		ON (TemporaryTableTotal.DoOperationsByOrders)
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
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
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
	|			THEN Calendar.GLAccountCustomerSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("Date", StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	GenerateTableSales(DocumentRef, StructureAdditionalProperties);
	GenerateTableCustomerAccounts(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTableSubcontractComponents(DocumentRef, StructureAdditionalProperties);
	GenerateTableSubcontractorOrdersReceived(DocumentRef, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	// Customer-owned inventory
	GenerateTableCustomerOwnedInventory(DocumentRef, StructureAdditionalProperties);
	
	//VAT
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	ElsIf StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractComponentsChange
		Or StructureTemporaryTables.RegisterRecordsSubcontractorOrdersReceivedChange 
		Or StructureTemporaryTables.RegisterRecordsCustomerOwnedInventoryChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
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
		|		INNER JOIN AccumulationRegister.Inventory.Balance(
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
		|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSubcontractComponentsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractComponentsChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractComponentsChange.Products AS Products,
		|	RegisterRecordsSubcontractComponentsChange.Characteristic AS Characteristic,
		|	SubcontractComponentsBalances.Products.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(RegisterRecordsSubcontractComponentsChange.QuantityChange, 0) + ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) AS Balance,
		|	ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) AS QuantityBalance
		|FROM
		|	RegisterRecordsSubcontractComponentsChange AS RegisterRecordsSubcontractComponentsChange
		|		INNER JOIN AccumulationRegister.SubcontractComponents.Balance(&ControlTime, ) AS SubcontractComponentsBalances
		|		ON RegisterRecordsSubcontractComponentsChange.SubcontractorOrder = SubcontractComponentsBalances.SubcontractorOrder
		|			AND RegisterRecordsSubcontractComponentsChange.Products = SubcontractComponentsBalances.Products
		|			AND RegisterRecordsSubcontractComponentsChange.Characteristic = SubcontractComponentsBalances.Characteristic
		|			AND (ISNULL(SubcontractComponentsBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSubcontractorOrdersReceivedChange.LineNumber AS LineNumber,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Company AS Company,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty AS Counterparty,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder AS SubcontractorOrder,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Products AS Products,
		|	RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic AS Characteristic,
		|	SubcontractorOrdersReceivedBalances.Products.MeasurementUnit AS MeasurementUnit,
		|	ISNULL(RegisterRecordsSubcontractorOrdersReceivedChange.QuantityChange, 0) + ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS Balance,
		|	ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) AS QuantityBalance
		|FROM
		|	RegisterRecordsSubcontractorOrdersReceivedChange AS RegisterRecordsSubcontractorOrdersReceivedChange
		|		INNER JOIN AccumulationRegister.SubcontractorOrdersReceived.Balance(&ControlTime, ) AS SubcontractorOrdersReceivedBalances
		|		ON RegisterRecordsSubcontractorOrdersReceivedChange.Company = SubcontractorOrdersReceivedBalances.Company
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Counterparty = SubcontractorOrdersReceivedBalances.Counterparty
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.SubcontractorOrder = SubcontractorOrdersReceivedBalances.SubcontractorOrder
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Products = SubcontractorOrdersReceivedBalances.Products
		|			AND RegisterRecordsSubcontractorOrdersReceivedChange.Characteristic = SubcontractorOrdersReceivedBalances.Characteristic
		|			AND (ISNULL(SubcontractorOrdersReceivedBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.CustomerOwnedInventory.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() 
			Or Not ResultsArray[1].IsEmpty() 
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty() Then
			
			DocumentObject = DocumentRef.GetObject();
			
		EndIf;
		
		// Negative balance on subcontract components.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on subcontract components.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractComponentsRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on subcontractor orders received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSubcontractorOrdersReceivedRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of customer-owned inventory
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToCustomerOwnedInventoryRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel,
				AdditionalProperties.WriteMode);
		EndIf;
		
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
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

#EndRegion

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Products" Then
		IncomeAndExpenseStructure.Insert("CostOfSalesItem", StructureData.CostOfSalesItem);
		IncomeAndExpenseStructure.Insert("RevenueItem", StructureData.RevenueItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Products" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
		Result.Insert("CostOfSalesGLAccount", "CostOfSalesItem");
	EndIf;
	
	Return Result;
	
EndFunction

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

Procedure GenerateTableSales(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableSales.Period AS Period,
	|	TableSales.Company AS Company,
	|	TableSales.PresentationCurrency AS PresentationCurrency,
	|	TableSales.Counterparty AS Counterparty,
	|	TableSales.DocumentCurrency AS Currency,
	|	TableSales.Products AS Products,
	|	TableSales.Characteristic AS Characteristic,
	|	TableSales.Ownership AS Ownership,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	TableSales.Document AS Document,
	|	TableSales.VATRate AS VATRate,
	|	TableSales.Department AS Department,
	|	TableSales.Responsible AS Responsible,
	|	SUM(TableSales.Quantity) AS Quantity,
	|	SUM(TableSales.VATAmount) AS VATAmount,
	|	SUM(TableSales.Amount - TableSales.VATAmount) AS Amount,
	|	SUM(TableSales.VATAmountDocCur) AS VATAmountCur,
	|	SUM(TableSales.AmountDocCur - TableSales.VATAmountDocCur) AS AmountCur,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord,
	|	FALSE AS ZeroInvoice
	|FROM
	|	TemporaryTableProducts AS TableSales
	|
	|GROUP BY
	|	TableSales.Period,
	|	TableSales.Company,
	|	TableSales.PresentationCurrency,
	|	TableSales.Counterparty,
	|	TableSales.DocumentCurrency,
	|	TableSales.Products,
	|	TableSales.Characteristic,
	|	TableSales.Ownership,
	|	CASE
	|		WHEN TableSales.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|				AND TableSales.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN TableSales.Order
	|		ELSE UNDEFINED
	|	END,
	|	TableSales.Document,
	|	TableSales.VATRate,
	|	TableSales.Department,
	|	TableSales.Responsible
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
	|	TableSales.Cost,
	|	TableSales.OfflineRecord,
	|	TableSales.ZeroInvoice
	|FROM
	|	AccumulationRegister.Sales AS TableSales
	|WHERE
	|	TableSales.Recorder = &Ref
	|	AND TableSales.OfflineRecord";
	
	Query.SetParameter("Ref", DocumentRef);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSales", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableCustomerAccounts(DocumentRef, StructureAdditionalProperties)
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	ExpectedPayments = NStr("en = 'Expected payments'; ru = 'Ожидаемые платежи';pl = 'Oczekiwane płatności';es_ES = 'Pagos esperados';es_CO = 'Pagos esperados';tr = 'Beklenen ödemeler';it = 'Pagamenti previsti';de = 'Erwartete Zahlungen'", DefaultLanguageCode);
	AdvanceCredit = NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Compensazione pagamento anticipo';de = 'Verrechnung der Vorauszahlung'", DefaultLanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("DoOperationsByOrders", Common.ObjectAttributeValue(DocumentRef.Counterparty, "DoOperationsByOrders"));
	Query.SetParameter("AppearenceOfCustomerLiability", NStr("en = 'Accounts receivable recognition'; ru = 'Принятие дебиторской задолженности к учету';pl = 'Przyjęcie należności do ewidencji';es_ES = 'Reconocimientos de las cuentas a cobrar';es_CO = 'Reconocimientos de las cuentas a cobrar';tr = 'Alacak hesaplarının mali tablolara alınması';it = 'Riconoscimento crediti contabili';de = 'Offene Posten Debitoren Aufnahme'", DefaultLanguageCode));
	Query.SetParameter("AppearenceOfCustomerAdvance", NStr("en = 'Advance payment recognition'; ru = 'Принятие авансового платежа к учету';pl = 'Przyjęcie do ewidencji zaliczki';es_ES = 'Reconocimiento de pago adelantado';es_CO = 'Reconocimiento de pago adelantado';tr = 'Avans ödemenin mali tablolara alınması';it = 'Riconoscimento pagamento di anticipo';de = 'Aufnahme von Vorauszahlungen'", DefaultLanguageCode));
	Query.SetParameter("AppearenceOfCustomerAdvanceAllocated", NStr("en = 'Advance payment allocation'; ru = 'Распределение авансового платежа';pl = 'Alokacja zaliczki';es_ES = 'Asignación de pago adelantado';es_CO = 'Asignación de pago adelantado';tr = 'Avans ödeme tahsisi';it = 'Allocazione pagamento di anticipo';de = 'Zuordnung von Vorauszahlungen'", DefaultLanguageCode));
	Query.SetParameter("ThirdPartyPayerLiability", 
		NStr("en = 'Accounts receivable recognition by a third-party payer'; ru = 'Принятие к учету дебиторской задолженности по стороннему плательщику';pl = 'Przyjęcie do ewidencji należności przez płatnika strony trzeciej';es_ES = 'Reconocimiento de cuentas por cobrar por un tercero pagador';es_CO = 'Reconocimiento de cuentas por cobrar por un tercero pagador';tr = 'Üçüncü taraf ödeyen tarafından alacak hesapların onaylanması';it = 'Riconoscimento dei crediti contabili da parte un terzo pagante';de = 'Aufnahme von Offene Posten Debitoren vom Drittzahler'", DefaultLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Pérdidas y ganancias por cambio de moneda extranjera';es_CO = 'Pérdidas y ganancias por cambio de moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", DefaultLanguageCode));
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.SetParameter("ExpectedPayments", ExpectedPayments);
	Query.SetParameter("AdvanceCredit", AdvanceCredit);
	
	// Generate temporary table by accounts payable.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountCustomerSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN &DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountForPaymentCur,
	|	CAST(&AppearenceOfCustomerLiability AS STRING(100)) AS ContentOfAccountingRecord
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTableProducts AS DocumentTable
	|WHERE
	|	DocumentTable.Amount <> 0
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN &DoOperationsByOrders
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountCustomerSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.CustomerAdvancesGLAccount,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
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
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
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
	|	DocumentTable.GLAccountCustomerSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.DocumentWhere,
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
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
	|	CASE
	|		WHEN DocumentTable.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.GLAccountCustomerSettlements,
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
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.DocumentWhere,
	|	CASE
	|		WHEN Calendar.Order <> VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN Calendar.Order
	|		ELSE UNDEFINED
	|	END,
	|	Calendar.SettlementsCurrency,
	|	Calendar.SettlemensTypeWhere,
	|	0,
	|	0,
	|	0,
	|	0,
	|	Calendar.Amount,
	|	Calendar.AmountCur,
	|	CAST(&ExpectedPayments AS STRING(100))
	|FROM
	|	TemporaryTablePaymentCalendar AS Calendar
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
	|	GLAccount,
	|	Currency";
	
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
	|	TemporaryTableAccountsReceivable";
	
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
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableAccountsReceivable = PaymentTermsServer.RecalculateAmountForExpectedPayments(
		StructureAdditionalProperties, 
		ResultsArray[QueryNumber].Unload(), 
		ExpectedPayments);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", TableAccountsReceivable);
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableIncomeAndExpenses.LineNumber AS LineNumber,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.Department AS StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLineSales AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.WorkOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.Order
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.RevenueItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.AccountStatementSales AS GLAccount,
	|	CAST(&Income AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount) AS AmountIncome,
	|	0 AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableIncomeAndExpenses
	|WHERE
	|	TableIncomeAndExpenses.Amount <> 0
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.LineNumber,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.Department,
	|	TableIncomeAndExpenses.BusinessLineSales,
	|	TableIncomeAndExpenses.RevenueItem,
	|	TableIncomeAndExpenses.AccountStatementSales,
	|	TableIncomeAndExpenses.Order
	|
	|UNION ALL
	|
	|SELECT
	|	3,
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
	|	2,
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
	|	Ordering,
	|	LineNumber";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("FXIncomeItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",									Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("Income",										NStr("en = 'Revenue'; ru = 'Выручка';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",							NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("Ref",											DocumentRef);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSubcontractComponents(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Date AS Period,
	|	TemporaryTableInventory.SubcontractorOrder AS SubcontractorOrder,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractComponents", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableSubcontractorOrdersReceived(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.Counterparty AS Counterparty,
	|	TemporaryTableProducts.Order AS SubcontractorOrder,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	TemporaryTableProducts.Quantity AS Quantity
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSubcontractorOrdersReceived", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties)
	
	If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocumentRef.Date, DocumentRef.Company) Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableVATOutput.Document AS ShipmentDocument,
	|	TableVATOutput.Period AS Period,
	|	TableVATOutput.Company AS Company,
	|	TableVATOutput.CompanyVATNumber AS CompanyVATNumber,
	|	TableVATOutput.PresentationCurrency AS PresentationCurrency,
	|	TableVATOutput.Counterparty AS Customer,
	|	TableVATOutput.VATRate AS VATRate,
	|	TableVATOutput.VATOutputGLAccount AS GLAccount,
	|	CASE
	|		WHEN TableVATOutput.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR TableVATOutput.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	TableVATOutput.ProductsType AS ProductType,
	|	SUM(TableVATOutput.VATAmount) AS VATAmount,
	|	SUM(TableVATOutput.Amount - TableVATOutput.VATAmount) AS AmountExcludesVAT
	|FROM
	|	TemporaryTableProducts AS TableVATOutput
	|
	|GROUP BY
	|	TableVATOutput.VATRate,
	|	TableVATOutput.VATOutputGLAccount,
	|	TableVATOutput.VATTaxation,
	|	TableVATOutput.ProductsType,
	|	TableVATOutput.Document,
	|	TableVATOutput.Period,
	|	TableVATOutput.Company,
	|	TableVATOutput.CompanyVATNumber,
	|	TableVATOutput.PresentationCurrency,
	|	TableVATOutput.Counterparty,
	|	TableVATOutput.DocumentCurrency,
	|	TableVATOutput.Multiplicity,
	|	TableVATOutput.ExchangeRate
	|
	|UNION ALL
	|
	|SELECT
	|	Prepayment.ShipmentDocument,
	|	Prepayment.Period,
	|	Prepayment.Company,
	|	Prepayment.CompanyVATNumber,
	|	Prepayment.PresentationCurrency,
	|	Prepayment.Customer,
	|	Prepayment.VATRate,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	-Prepayment.VATAmount,
	|	-Prepayment.AmountExcludesVAT
	|FROM
	|	TemporaryTablePrepaymentVAT AS Prepayment";
	
	Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("NetDates", PaymentTermsServer.NetPaymentDates());
	
	Query.Text =
	"SELECT
	|	SubcontractorInvoiceIssued.Ref AS Ref,
	|	SubcontractorInvoiceIssued.Date AS Date,
	|	SubcontractorInvoiceIssued.AmountIncludesVAT AS AmountIncludesVAT,
	|	SubcontractorInvoiceIssued.PaymentMethod AS PaymentMethod,
	|	SubcontractorInvoiceIssued.Contract AS Contract,
	|	SubcontractorInvoiceIssued.PettyCash AS PettyCash,
	|	SubcontractorInvoiceIssued.BankAccount AS BankAccount,
	|	SubcontractorInvoiceIssued.ExchangeRate AS ExchangeRate,
	|	SubcontractorInvoiceIssued.Multiplicity AS Multiplicity,
	|	SubcontractorInvoiceIssued.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SubcontractorInvoiceIssued.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SubcontractorInvoiceIssued.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.SubcontractorInvoiceIssued AS SubcontractorInvoiceIssued
	|WHERE
	|	SubcontractorInvoiceIssued.Ref = &Ref
	|	AND SubcontractorInvoiceIssued.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
	|	Document.PaymentMethod AS PaymentMethod,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	Document.PettyCash AS PettyCash,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	Document.ExchangeRate AS ExchangeRate,
	|	Document.Multiplicity AS Multiplicity,
	|	Document.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Document.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.SubcontractorInvoiceIssued.PaymentCalendar AS DocumentTable
	|		ON Document.Ref = DocumentTable.Ref
	|			AND DocumentTable.PaymentBaselineDate IN (&NetDates)
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
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInventory(DocumentRefSalesInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.DocumentCurrency AS Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.Document AS Document,
	|	TableProducts.Document AS SourceDocument,
	|	TableProducts.Department AS Department,
	|	TableProducts.Responsible AS Responsible,
	|	TableProducts.CorrGLAccount AS GLAccountCost,
	|	ISNULL(TableProducts.StructuralUnit, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnit,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef) AS IncomeAndExpenseItem,
	|	TableProducts.CostOfSalesItem AS CorrIncomeAndExpenseItem,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	TableProducts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	TableProducts.VATRate AS VATRate,
	|	SUM(TableProducts.VATAmount) AS VATAmount,
	|	SUM(TableProducts.Amount) AS Amount,
	|	0 AS Cost,
	|	FALSE AS FixedCost,
	|	TableProducts.CorrGLAccount AS AccountDr,
	|	TableProducts.GLAccount AS AccountCr,
	|	CAST(&CostOfServicesWriteOff AS STRING(100)) AS Content,
	|	CAST(&CostOfServicesWriteOff AS STRING(100)) AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|INTO SourceProducts
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|		LEFT JOIN Document.SubcontractorInvoiceIssued AS SubcontractorInvoiceIssuedRef
	|		ON TableProducts.Order = SubcontractorInvoiceIssuedRef.Ref
	|WHERE
	|	TableProducts.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.DocumentCurrency,
	|	TableProducts.Document,
	|	TableProducts.Order,
	|	TableProducts.Department,
	|	TableProducts.Responsible,
	|	TableProducts.CostOfSalesItem,
	|	TableProducts.GLAccount,
	|	TableProducts.CorrGLAccount,
	|	TableProducts.StructuralUnit,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.CorrInventoryAccountType,
	|	TableProducts.VATRate,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.SubcontractorOrderReceived.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END,
	|	TableProducts.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProducts.LineNumber AS LineNumber,
	|	TableProducts.Period AS Period,
	|	TableProducts.RecordType AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Currency AS Currency,
	|	TableProducts.PlanningPeriod AS PlanningPeriod,
	|	TableProducts.Document AS Document,
	|	TableProducts.SourceDocument AS SourceDocument,
	|	TableProducts.Department AS Department,
	|	TableProducts.Responsible AS Responsible,
	|	TableProducts.CorrGLAccount AS CorrGLAccount,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	TableProducts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableProducts.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	TableProducts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableProducts.SalesOrder AS SalesOrder,
	|	TableProducts.Quantity AS Quantity,
	|	TableProducts.VATRate AS VATRate,
	|	TableProducts.VATAmount AS VATAmount,
	|	TableProducts.Amount AS Amount,
	|	TableProducts.Cost AS Cost,
	|	TableProducts.AccountDr AS AccountDr,
	|	TableProducts.AccountCr AS AccountCr,
	|	TableProducts.Content AS Content,
	|	TableProducts.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	TableProducts.OfflineRecord AS OfflineRecord
	|FROM
	|	SourceProducts AS TableProducts
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.Period,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	OfflineRecords.Counterparty,
	|	OfflineRecords.Currency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.Department,
	|	OfflineRecords.Responsible,
	|	UNDEFINED,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Ownership,
	|	OfflineRecords.CostObject,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.VATRate,
	|	UNDEFINED,
	|	OfflineRecords.Amount,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("CostOfServicesWriteOff", NStr("en = 'Recognized cost of services'; ru = 'Принятая к учету себестоимость услуг';pl = 'Uznany koszt własny usług';es_ES = 'Coste de los servicios reconocido';es_CO = 'Coste de los servicios reconocido';tr = 'Mali tablolara alınan hizmet maliyeti';it = 'Costi di servizi riconosciuti';de = 'Aufgenommene Kosten der Dienstleistungen'", MainLanguageCode));
	Query.SetParameter("Ref", DocumentRefSalesInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	GenerateTableInventorySale(DocumentRefSalesInvoice, StructureAdditionalProperties);
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurDr,
	|	TableAccountingJournalEntries.AccountStatementSales AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&IncomeReflection AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.Amount <> 0
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|				THEN TableAccountingJournalEntries.VATAmountCur
	|			ELSE 0
	|		END),
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.VATAmount),
	|	&VAT,
	|	FALSE
	|FROM
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount <> 0
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountCustomerSettlements,
	|	TableAccountingJournalEntries.VATAmount,
	|	TableAccountingJournalEntries.Period,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountCustomerSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	3,
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
	|			TemporaryTablePrepayment AS DocumentTable) AS DocumentTable
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
	|	4,
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
	|	Ordering";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	 
	Query.SetParameter("SetOffAdvancePayment",	NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Compensazione pagamento anticipo';de = 'Verrechnung der Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("IncomeReflection",		NStr("en = 'Revenue'; ru = 'Выручка';pl = 'Przychód';es_ES = 'Ingreso';es_CO = 'Ingreso';tr = 'Gelir';it = 'Ricavo';de = 'Erlös'", MainLanguageCode));
	Query.SetParameter("VAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("Ref",					DocumentRef);

	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableInventorySale(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT DISTINCT
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	TableProducts.Products AS Products,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject
	|FROM
	|	TemporaryTableProducts AS TableProducts";
	
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
	|		InventoryBalances.Company,
	|		InventoryBalances.PresentationCurrency,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.Ownership,
	|		InventoryBalances.CostObject,
	|		InventoryBalances.QuantityBalance,
	|		InventoryBalances.AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject) IN
	|					(SELECT
	|						TableProducts.Company,
	|						TableProducts.PresentationCurrency,
	|						TableProducts.StructuralUnit,
	|						TableProducts.Products,
	|						TableProducts.Characteristic,
	|						TableProducts.Batch,
	|						TableProducts.Ownership,
	|						TableProducts.CostObject
	|					FROM
	|						TemporaryTableProducts AS TableProducts)) AS InventoryBalances
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
	|	InventoryBalances.CostObject";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, Products, Characteristic, Batch, Ownership, CostObject");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency", RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership", RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject", RowTableInventory.CostObject);
		
		QuantityRequiredAvailableBalance = ?(ValueIsFilled(RowTableInventory.Quantity), RowTableInventory.Quantity, 0);
		
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
			
			// Expense. Inventory.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				RowTableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move income and expenses.
				RowIncomeAndExpenses = StructureAdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses.Add();
				FillPropertyValues(RowIncomeAndExpenses, RowTableInventory);
				
				RowIncomeAndExpenses.StructuralUnit = RowTableInventory.Department;
				RowIncomeAndExpenses.IncomeAndExpenseItem = RowTableInventory.CorrIncomeAndExpenseItem;
				RowIncomeAndExpenses.GLAccount = RowTableInventory.CorrGLAccount;
				RowIncomeAndExpenses.AmountIncome = 0;
				RowIncomeAndExpenses.AmountExpense = AmountToBeWrittenOff;
				
				RowIncomeAndExpenses.ContentOfAccountingRecord = NStr("en = 'Recognized cost of services'; ru = 'Принятая к учету себестоимость услуг';pl = 'Uznany koszt własny usług';es_ES = 'Coste de los servicios reconocido';es_CO = 'Coste de los servicios reconocido';tr = 'Mali tablolara alınan hizmet maliyeti';it = 'Costi di servizi riconosciuti';de = 'Aufgenommene Kosten der Dienstleistungen'", MainLanguageCode);
				
			EndIf;
			
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				// Move the cost of sales.
				SaleString = StructureAdditionalProperties.TableForRegisterRecords.TableSales.Add();
				FillPropertyValues(SaleString, RowTableInventory);
				SaleString.Quantity = 0;
				SaleString.Amount = 0;
				SaleString.VATAmount = 0;
				SaleString.AmountCur = 0;
				SaleString.VATAmountCur = 0;
				SaleString.Cost = AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

Procedure GenerateTableCustomerOwnedInventory(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled cutomer-owned inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Order AS SubcontractorOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Counterparty,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CustomerOwnedInventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving cutomer-owned inventory balances.
	Query.Text =
	"SELECT
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.Counterparty AS Counterparty,
	|	TemporaryTableProducts.Order AS SubcontractorOrder,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	0 AS QuantityToIssue,
	|	SUM(TemporaryTableProducts.Quantity) AS QuantityToInvoice
	|INTO TT_TemporaryTableProducts
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|
	|GROUP BY
	|	TemporaryTableProducts.Company,
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Counterparty,
	|	TemporaryTableProducts.Order,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CustomerOwnedInventoryBalance.Company AS Company,
	|	CustomerOwnedInventoryBalance.Counterparty AS Counterparty,
	|	CustomerOwnedInventoryBalance.SubcontractorOrder AS SubcontractorOrder,
	|	CustomerOwnedInventoryBalance.Products AS Products,
	|	CustomerOwnedInventoryBalance.Characteristic AS Characteristic,
	|	CustomerOwnedInventoryBalance.ProductionOrder AS ProductionOrder,
	|	0 AS QuantityToIssueBalance,
	|	CustomerOwnedInventoryBalance.QuantityToInvoiceBalance AS QuantityToInvoiceBalance
	|INTO TT_CustomerOwnedInventoryBalance
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory.Balance(
	|			&ControlTime,
	|			(Company, Counterparty, SubcontractorOrder, Products, Characteristic) IN
	|				(SELECT
	|					TT_TemporaryTableProducts.Company AS Company,
	|					TT_TemporaryTableProducts.Counterparty AS Counterparty,
	|					TT_TemporaryTableProducts.SubcontractorOrder AS SubcontractorOrder,
	|					TT_TemporaryTableProducts.Products AS Products,
	|					TT_TemporaryTableProducts.Characteristic AS Characteristic
	|				FROM
	|					TT_TemporaryTableProducts AS TT_TemporaryTableProducts)) AS CustomerOwnedInventoryBalance
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsCustomerOwnedInventory.Company,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Counterparty,
	|	DocumentRegisterRecordsCustomerOwnedInventory.SubcontractorOrder,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Products,
	|	DocumentRegisterRecordsCustomerOwnedInventory.Characteristic,
	|	DocumentRegisterRecordsCustomerOwnedInventory.ProductionOrder,
	|	0,
	|	CASE
	|		WHEN DocumentRegisterRecordsCustomerOwnedInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN ISNULL(DocumentRegisterRecordsCustomerOwnedInventory.QuantityToInvoice, 0)
	|		ELSE -ISNULL(DocumentRegisterRecordsCustomerOwnedInventory.QuantityToInvoice, 0)
	|	END
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory AS DocumentRegisterRecordsCustomerOwnedInventory
	|WHERE
	|	DocumentRegisterRecordsCustomerOwnedInventory.Recorder = &Ref
	|	AND DocumentRegisterRecordsCustomerOwnedInventory.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(TT_TemporaryTableProducts.Period) AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	MAX(TT_TemporaryTableProducts.Company) AS Company,
	|	MAX(TT_TemporaryTableProducts.Counterparty) AS Counterparty,
	|	MAX(TT_TemporaryTableProducts.SubcontractorOrder) AS SubcontractorOrder,
	|	TT_TemporaryTableProducts.Products AS Products,
	|	MAX(TT_TemporaryTableProducts.Characteristic) AS Characteristic,
	|	MAX(TT_TemporaryTableProducts.QuantityToIssue) AS QuantityToIssue,
	|	MAX(TT_TemporaryTableProducts.QuantityToInvoice) AS QuantityToInvoice,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder, VALUE(Document.ProductionOrder.EmptyRef)) AS ProductionOrder,
	|	SUM(ISNULL(TT_CustomerOwnedInventoryBalance.QuantityToIssueBalance, 0)) AS QuantityToIssueBalance,
	|	SUM(ISNULL(TT_CustomerOwnedInventoryBalance.QuantityToInvoiceBalance, 0)) AS QuantityToInvoiceBalance,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder.Date, DATETIME(3999, 12, 31)) AS ProductionOrderDate
	|FROM
	|	TT_TemporaryTableProducts AS TT_TemporaryTableProducts
	|		LEFT JOIN TT_CustomerOwnedInventoryBalance AS TT_CustomerOwnedInventoryBalance
	|		ON TT_TemporaryTableProducts.Company = TT_CustomerOwnedInventoryBalance.Company
	|			AND TT_TemporaryTableProducts.Counterparty = TT_CustomerOwnedInventoryBalance.Counterparty
	|			AND TT_TemporaryTableProducts.SubcontractorOrder = TT_CustomerOwnedInventoryBalance.SubcontractorOrder
	|			AND TT_TemporaryTableProducts.Products = TT_CustomerOwnedInventoryBalance.Products
	|			AND TT_TemporaryTableProducts.Characteristic = TT_CustomerOwnedInventoryBalance.Characteristic
	|
	|GROUP BY
	|	TT_TemporaryTableProducts.Products,
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder, VALUE(Document.ProductionOrder.EmptyRef)),
	|	ISNULL(TT_CustomerOwnedInventoryBalance.ProductionOrder.Date, DATETIME(3999, 12, 31))
	|
	|ORDER BY
	|	Products,
	|	ProductionOrderDate
	|TOTALS BY
	|	Products
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 0
	|	CustomerOwnedInventory.Period AS Period,
	|	CustomerOwnedInventory.RecordType AS RecordType,
	|	CustomerOwnedInventory.Company AS Company,
	|	CustomerOwnedInventory.Counterparty AS Counterparty,
	|	CustomerOwnedInventory.SubcontractorOrder AS SubcontractorOrder,
	|	CustomerOwnedInventory.Products AS Products,
	|	CustomerOwnedInventory.Characteristic AS Characteristic,
	|	CustomerOwnedInventory.ProductionOrder AS ProductionOrder,
	|	CustomerOwnedInventory.QuantityToIssue AS QuantityToIssue,
	|	CustomerOwnedInventory.QuantityToInvoice AS QuantityToInvoice
	|FROM
	|	AccumulationRegister.CustomerOwnedInventory AS CustomerOwnedInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_TemporaryTableProducts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TT_CustomerOwnedInventoryBalance";
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.ExecuteBatch();
	SelectionProducts = QueryResult[2].Select(QueryResultIteration.ByGroups);
	
	TableCustomerOwnedInventory = QueryResult[3].Unload();
	While SelectionProducts.Next() Do
		
		TotalQuantityToInvoice = SelectionProducts.QuantityToInvoice;
		
		Selection = SelectionProducts.Select();
		While Selection.Next() Do
			
			NewRow = TableCustomerOwnedInventory.Add();
			FillPropertyValues(NewRow, Selection, , "QuantityToInvoice");
			
			If Selection.QuantityToInvoiceBalance >= TotalQuantityToInvoice Then
				
				NewRow.QuantityToInvoice = TotalQuantityToInvoice;
				TotalQuantityToInvoice = 0;
				
				Break;
				
			Else
				
				NewRow.QuantityToInvoice = Selection.QuantityToInvoiceBalance;
				TotalQuantityToInvoice = TotalQuantityToInvoice - Selection.QuantityToInvoiceBalance;
				
			EndIf;
			
		EndDo;
		
		If TotalQuantityToInvoice > 0 Then
			
			NewRow = TableCustomerOwnedInventory.Add();
			FillPropertyValues(NewRow, SelectionProducts, , "QuantityToInvoice");
			
			NewRow.RecordType = AccumulationRecordType.Expense;
			NewRow.QuantityToInvoice = TotalQuantityToInvoice;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCustomerOwnedInventory", TableCustomerOwnedInventory);
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

#EndRegion 

#EndRegion

#EndIf
