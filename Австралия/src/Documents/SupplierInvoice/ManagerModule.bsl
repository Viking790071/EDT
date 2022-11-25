#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefPurchaseInvoice, StructureAdditionalProperties) Export
	
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
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
	|	Header.ExchangeRate AS ExchangeRate,
	|	Header.Multiplicity AS Multiplicity,
	|	Header.SetPaymentTerms AS SetPaymentTerms,
	|	Header.BasisDocument AS BasisDocument,
	|	Header.Order AS Order,
	|	Header.DocumentCurrency AS Currency,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.ZeroInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ZeroInvoice,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Header.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	Header.VATTaxation AS VATTaxation,
	|	Header.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice) AS AdvanceInvoicing,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.OperationKind AS OperationKind,
	|	Header.IncludeExpensesInCostPrice AS IncludeExpensesInCostPrice,
	|	Header.IncludeVATInPrice AS IncludeVATInPrice,
	|	Header.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	Header.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN Header.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN VALUE(Catalog.BusinessUnits.DropShipping)
	|		ELSE Header.StructuralUnit
	|	END AS StructuralUnit,
	|	Header.Responsible AS Responsible,
	|	Header.Cell AS Cell,
	|	Header.Department AS Department,
	|	AccountingPolicySliceLast.StockTransactionsMethodology AS StockTransactionsMethodology,
	|	AccountingPolicySliceLast.RegisteredForVAT AS RegisteredForVAT,
	|	AccountingPolicySliceLast.RegisteredForSalesTax AS RegisteredForSalesTax,
	|	AccountingPolicySliceLast.PostVATEntriesBySourceDocuments AS PostVATEntriesBySourceDocuments,
	|	Header.Contract.SettlementsCurrency AS SettlementsCurrency
	|INTO SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS Header
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&PointInTime, ) AS AccountingPolicySliceLast
	|		ON Header.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceHeader.Ref AS Document,
	|	SupplierInvoiceHeader.BasisDocument AS BasisDocument,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.DocumentCurrency AS Currency,
	|	SupplierInvoiceHeader.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SupplierInvoiceHeader.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.Responsible AS Responsible,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceHeader.StructuralUnit.MarkupGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS MarkupGLAccount,
	|	SupplierInvoiceHeader.StructuralUnit.RetailPriceKind AS RetailPriceKind,
	|	SupplierInvoiceHeader.StructuralUnit.RetailPriceKind.PriceCurrency AS PriceCurrency,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	CASE
	|		WHEN SupplierInvoiceHeader.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS RetailTransferEarningAccounting,
	|	SupplierInvoiceHeader.Date AS Period,
	|	&Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SupplierInvoiceHeader.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	SupplierInvoiceHeader.InventoryAccountType AS InventoryAccountType,
	|	UNDEFINED AS IncomeAndExpenseItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Products.ProductsType AS ProductsType,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SupplierInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN SupplierInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SupplierInvoiceInventory.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order REFS Document.PurchaseOrder
	|				AND SupplierInvoiceInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN SupplierInvoiceInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	FALSE AS ProductsOnCommission,
	|	CASE
	|		WHEN SupplierInvoiceHeader.BasisDocument REFS Document.SalesInvoice
	|				AND SupplierInvoiceHeader.BasisDocument <> VALUE(Document.SalesInvoice.EmptyRef)
	|			THEN SupplierInvoiceHeader.BasisDocument.Department
	|		ELSE SupplierInvoiceHeader.Department
	|	END AS DepartmentSales,
	|	SupplierInvoiceInventory.Products.BusinessLine AS BusinessLineSales,
	|	CASE
	|		WHEN VALUETYPE(SupplierInvoiceInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN SupplierInvoiceInventory.Quantity
	|		ELSE SupplierInvoiceInventory.Quantity * SupplierInvoiceInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(SupplierInvoiceInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.AmountExpense * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS AmountExpense,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.AmountExpense * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS AmountExpenseCur,
	|	SupplierInvoiceHeader.IncludeExpensesInCostPrice AS IncludeExpensesInCostPrice,
	|	TRUE AS FixedCost,
	|	CAST(&InventoryIncrease AS STRING(100)) AS ContentOfAccountingRecord,
	|	SupplierInvoiceHeader.AccountsPayableGLAccount AS GLAccountVendorSettlements,
	|	SupplierInvoiceHeader.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	CAST(SupplierInvoiceInventory.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	SupplierInvoiceInventory.ConnectionKey AS ConnectionKey,
	|	SupplierInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SupplierInvoiceHeader.Multiplicity AS Multiplicity,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	CASE
	|		WHEN SupplierInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS AdvanceInvoicing,
	|	SupplierInvoiceInventory.ReverseChargeVATRate AS ReverseChargeVATRate,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmount,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCur,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			ELSE SupplierInvoiceInventory.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountForNotRegistered,
	|	CASE
	|		WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|			THEN 0
	|		ELSE SupplierInvoiceInventory.VATAmount
	|	END AS VATAmountDocCur,
	|	SupplierInvoiceInventory.Total AS AmountDocCur,
	|	SupplierInvoiceInventory.GoodsReceipt AS GoodsReceipt,
	|	CASE
	|		WHEN SupplierInvoiceInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SupplierInvoiceHeader.InventoryAccountType
	|	END AS CorrInventoryAccountType,
	|	UNDEFINED AS CorrIncomeAndExpenseItem,
	|	UNDEFINED AS ProductsCorr,
	|	UNDEFINED AS CharacteristicCorr,
	|	UNDEFINED AS BatchCorr,
	|	UNDEFINED AS OwnershipCorr,
	|	UNDEFINED AS CostObjectCorr,
	|	UNDEFINED AS CorrOrder,
	|	UNDEFINED AS CorrOrganization,
	|	UNDEFINED AS CorrPresentationCurrency,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CASE
	|					WHEN SupplierInvoiceInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|						THEN UNDEFINED
	|					ELSE SupplierInvoiceInventory.GoodsReceivedNotInvoicedGLAccount
	|				END
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.GoodsReceivedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsReceivedNotInvoicedGLAccount,
	|	SupplierInvoiceHeader.SetPaymentTerms AS SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceInventory.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	&ContinentalMethod AS ContinentalMethod,
	|	SupplierInvoiceInventory.Specification AS Specification,
	|	CASE
	|		WHEN SupplierInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.ZeroInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ZeroInvoice,
	|	CASE
	|		WHEN SupplierInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS DropShipping,
	|	SupplierInvoiceInventory.Project AS Project
	|INTO TemporaryTableInventory
	|FROM
	|	SupplierInvoiceHeader AS SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON SupplierInvoiceHeader.Ref = SupplierInvoiceInventory.Ref
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (SupplierInvoiceInventory.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON SupplierInvoiceHeader.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoiceInventory.LineNumber AS LineNumber,
	|	SupplierInvoiceHeader.Date AS Period,
	|	&Company AS Company,
	|	SupplierInvoiceInventory.SalesOrder AS SalesOrder,
	|	SupplierInvoiceInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SupplierInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order REFS Document.PurchaseOrder
	|				AND SupplierInvoiceInventory.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN SupplierInvoiceInventory.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	SupplierInvoiceInventory.Quantity AS Quantity
	|INTO TemporaryTableReservation
	|FROM
	|	SupplierInvoiceHeader AS SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Reservation AS SupplierInvoiceInventory
	|		ON SupplierInvoiceHeader.Ref = SupplierInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PurchaseInvoiceExpenses.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SupplierInvoiceHeader.Date AS Period,
	|	PurchaseInvoiceExpenses.Ref AS Document,
	|	&Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PurchaseInvoiceExpenses.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.DocumentCurrency AS Currency,
	|	SupplierInvoiceHeader.InventoryAccountType AS InventoryAccountType,
	|	PurchaseInvoiceExpenses.ExpenseItem AS ExpenseItem,
	|	PurchaseInvoiceExpenses.RegisterExpense AS RegisterExpense,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PurchaseInvoiceExpenses.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	PurchaseInvoiceExpenses.Products AS Products,
	|	PurchaseInvoiceExpenses.Products.ProductsType AS ProductsType,
	|	VALUE(Catalog.Products.EmptyRef) AS InventoryProducts,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	PurchaseInvoiceExpenses.Order AS Order,
	|	PurchaseInvoiceExpenses.PurchaseOrder AS PurchaseOrder,
	|	CASE
	|		WHEN VALUETYPE(PurchaseInvoiceExpenses.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN PurchaseInvoiceExpenses.Quantity
	|		ELSE PurchaseInvoiceExpenses.Quantity * PurchaseInvoiceExpenses.MeasurementUnit.Factor
	|	END AS Quantity,
	|	PurchaseInvoiceExpenses.VATRate AS VATRate,
	|	CAST(PurchaseInvoiceExpenses.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(PurchaseInvoiceExpenses.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE PurchaseInvoiceExpenses.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE PurchaseInvoiceExpenses.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	SupplierInvoiceHeader.IncludeExpensesInCostPrice AS IncludeExpensesInCostPrice,
	|	CASE
	|		WHEN PurchaseInvoiceExpenses.Products.ExpensesGLAccount.TypeOfAccount = VALUE(Enum.GLAccountsTypes.Expenses)
	|				AND NOT SupplierInvoiceHeader.IncludeExpensesInCostPrice
	|			THEN PurchaseInvoiceExpenses.BusinessLine
	|		ELSE PurchaseInvoiceExpenses.Products.BusinessLine
	|	END AS BusinessLine,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	SupplierInvoiceHeader.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SupplierInvoiceHeader.AccountsPayableGLAccount AS GLAccountVendorSettlements,
	|	PurchaseInvoiceExpenses.ExpenseItem.IncomeAndExpenseType AS ExpenseItemType,
	|	SupplierInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SupplierInvoiceHeader.Multiplicity AS Multiplicity,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	PurchaseInvoiceExpenses.ReverseChargeVATRate AS ReverseChargeVATRate,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmount,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|				THEN 0
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity / (SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate * SupplierInvoiceHeader.ContractCurrencyMultiplicity / (SupplierInvoiceHeader.ContractCurrencyExchangeRate * SupplierInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountCur,
	|	CAST(CASE
	|			WHEN NOT SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|					OR &RegisteredForVAT
	|				THEN 0
	|			ELSE PurchaseInvoiceExpenses.ReverseChargeVATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SupplierInvoiceHeader.Multiplicity / SupplierInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SupplierInvoiceHeader.ExchangeRate / SupplierInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS ReverseChargeVATAmountForNotRegistered,
	|	CASE
	|		WHEN SupplierInvoiceHeader.IncludeVATInPrice
	|			THEN 0
	|		ELSE PurchaseInvoiceExpenses.VATAmount
	|	END AS VATAmountDocCur,
	|	PurchaseInvoiceExpenses.Total AS AmountDocCur,
	|	SupplierInvoiceHeader.SetPaymentTerms AS SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PurchaseInvoiceExpenses.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PurchaseInvoiceExpenses.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	CASE
	|		WHEN SupplierInvoiceHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.ZeroInvoice)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ZeroInvoice,
	|	SupplierInvoiceHeader.AdvanceInvoicing AS AdvanceInvoicing,
	|	PurchaseInvoiceExpenses.Project AS Project
	|INTO TemporaryTableExpenses
	|FROM
	|	SupplierInvoiceHeader AS SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Expenses AS PurchaseInvoiceExpenses
	|		ON SupplierInvoiceHeader.Ref = PurchaseInvoiceExpenses.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	DocumentTable.Ref.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Ref.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Ref.Counterparty AS Counterparty,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts AS DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VendorAdvancesGLAccount,
	|	DocumentTable.Ref.Contract AS Contract,
	|	DocumentTable.Ref.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Ref.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.ExpenseReport
	|			THEN CAST(DocumentTable.Document AS Document.ExpenseReport).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|		WHEN DocumentTable.Document REFS Document.DebitNote
	|			THEN CAST(DocumentTable.Document AS Document.DebitNote).Date
	|	END AS DocumentDate,
	|	SUM(DocumentTable.PaymentAmount) AS Amount,
	|	SUM(DocumentTable.SettlementsAmount) AS AmountCur,
	|	DocumentTable.Ref.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	Document.SupplierInvoice.Prepayment AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref
	|
	|GROUP BY
	|	DocumentTable.Ref,
	|	DocumentTable.Document,
	|	DocumentTable.Ref.Date,
	|	DocumentTable.Ref.CompanyVATNumber,
	|	DocumentTable.Ref.Counterparty,
	|	DocumentTable.Ref.Contract,
	|	DocumentTable.Order,
	|	DocumentTable.Ref.Contract.SettlementsCurrency,
	|	DocumentTable.Ref.BasisDocument,
	|	CASE
	|		WHEN VALUETYPE(DocumentTable.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(DocumentTable.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE CASE
	|				WHEN DocumentTable.Document REFS Document.PaymentExpense
	|					THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Item
	|				WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|					THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashReceipt
	|					THEN CAST(DocumentTable.Document AS Document.CashReceipt).Item
	|				WHEN DocumentTable.Document REFS Document.CashVoucher
	|					THEN CAST(DocumentTable.Document AS Document.CashVoucher).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END,
	|	CASE
	|		WHEN DocumentTable.Document REFS Document.PaymentExpense
	|			THEN CAST(DocumentTable.Document AS Document.PaymentExpense).Date
	|		WHEN DocumentTable.Document REFS Document.PaymentReceipt
	|			THEN CAST(DocumentTable.Document AS Document.PaymentReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashReceipt
	|			THEN CAST(DocumentTable.Document AS Document.CashReceipt).Date
	|		WHEN DocumentTable.Document REFS Document.CashVoucher
	|			THEN CAST(DocumentTable.Document AS Document.CashVoucher).Date
	|		WHEN DocumentTable.Document REFS Document.ExpenseReport
	|			THEN CAST(DocumentTable.Document AS Document.ExpenseReport).Date
	|		WHEN DocumentTable.Document REFS Document.ArApAdjustments
	|			THEN CAST(DocumentTable.Document AS Document.ArApAdjustments).Date
	|	END,
	|	DocumentTable.Ref.Counterparty.DoOperationsByContracts,
	|	DocumentTable.Ref.Counterparty.DoOperationsByOrders,
	|	DocumentTable.Ref.SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.Ref.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
	|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	Document.SupplierInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
	|WHERE
	|	SalesInvoiceSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers
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
	|	SUM(PrepaymentVAT.AmountExcludesVAT) AS AmountExcludesVAT,
	|	PrepaymentVAT.Ref.SetPaymentTerms AS SetPaymentTerms,
	|	PrepaymentVAT.LineNumber AS LineNumber,
	|	PrepaymentVAT.Ref AS Ref
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	Document.SupplierInvoice.PrepaymentVAT AS PrepaymentVAT
	|		INNER JOIN SupplierInvoiceHeader AS Header
	|		ON PrepaymentVAT.Ref = Header.Ref
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
	|	PrepaymentVAT.VATRate,
	|	PrepaymentVAT.Ref.SetPaymentTerms,
	|	PrepaymentVAT.Ref,
	|	PrepaymentVAT.LineNumber
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
	|	ISNULL(TemporaryTableInventory.DoOperationsByOrders, TemporaryTableExpenses.DoOperationsByOrders) AS DoOperationsByOrders,
	|	ISNULL(TemporaryTableInventory.Order, TemporaryTableExpenses.Order) AS Order,
	|	SUM(ISNULL(TemporaryTableInventory.AmountDocCur, 0) + ISNULL(TemporaryTableExpenses.AmountDocCur, 0)) AS Total
	|INTO TemporaryTableOrdersTotal
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		FULL JOIN TemporaryTableExpenses AS TemporaryTableExpenses
	|		ON TemporaryTableInventory.Order = TemporaryTableExpenses.Order
	|
	|GROUP BY
	|	ISNULL(TemporaryTableInventory.DoOperationsByOrders, TemporaryTableExpenses.DoOperationsByOrders),
	|	ISNULL(TemporaryTableInventory.Order, TemporaryTableExpenses.Order)
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
	|	SupplierInvoicePaymentCalendar.LineNumber AS LineNumber,
	|	SupplierInvoicePaymentCalendar.Ref AS Ref,
	|	SupplierInvoicePaymentCalendar.PaymentDate AS PaymentDate,
	|	ISNULL(TemporaryTableOrdersTotal.Order, VALUE(Document.PurchaseOrder.EmptyRef)) AS Order,
	|	SupplierInvoicePaymentCalendar.PaymentAmount * ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS PaymentAmount,
	|	SupplierInvoicePaymentCalendar.PaymentVATAmount * ISNULL(TemporaryTableOrdersTotal.Total, 1) / ISNULL(TemporaryTableTotal.Total, 1) AS PaymentVATAmount
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|		LEFT JOIN TemporaryTableOrdersTotal AS TemporaryTableOrdersTotal
	|		ON (TemporaryTableOrdersTotal.DoOperationsByOrders)
	|		LEFT JOIN TemporaryTableTotal AS TemporaryTableTotal
	|		ON (TemporaryTableTotal.DoOperationsByOrders)
	|WHERE
	|	SupplierInvoicePaymentCalendar.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.LineNumber AS LineNumber,
	|	Calendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	CounterpartyRef.DoOperationsByContracts AS DoOperationsByContracts,
	|	CounterpartyRef.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoice.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	SupplierInvoice.Contract AS Contract,
	|	CounterpartyContractsRef.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	CAST(CASE
	|			WHEN SupplierInvoice.AmountIncludesVAT
	|				THEN Calendar.PaymentAmount
	|			ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoice.Multiplicity / SupplierInvoice.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoice.ExchangeRate / SupplierInvoice.Multiplicity
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN SupplierInvoice.AmountIncludesVAT
	|				THEN Calendar.PaymentAmount
	|			ELSE Calendar.PaymentAmount + Calendar.PaymentVATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroupWithHeader
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON (SupplierInvoice.Ref = Calendar.Ref)
	|		LEFT JOIN Catalog.Counterparties AS CounterpartyRef
	|		ON (CounterpartyRef.Ref = SupplierInvoice.Counterparty)
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContractsRef
	|		ON (CounterpartyContractsRef.Ref = SupplierInvoice.Contract)
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
	|			THEN Calendar.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
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
	|			THEN Calendar.AccountsPayableGLAccount
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
	|	SupplierInvoiceHeader.Date AS Period,
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoiceMaterials.Products AS Products,
	|	SupplierInvoiceMaterials.Characteristic AS Characteristic,
	|	SupplierInvoiceMaterials.Batch AS Batch,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceMaterials.Quantity AS Quantity,
	|	SupplierInvoiceHeader.InventoryAccountType AS InventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceMaterials.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceMaterials.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	SupplierInvoiceHeader.Counterparty AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceMaterials.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SupplierInvoiceMaterials.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod
	|INTO TemporaryTableMaterials
	|FROM
	|	SupplierInvoiceHeader AS SupplierInvoiceHeader
	|		INNER JOIN Document.SupplierInvoice.Materials AS SupplierInvoiceMaterials
	|		ON SupplierInvoiceHeader.Ref = SupplierInvoiceMaterials.Ref
	|		LEFT JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON SupplierInvoiceHeader.Order = PurchaseOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroupWithHeader";
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRefPurchaseInvoice, "VATTaxation, Counterparty, DiscountCard");
	SetInStructureOperationKind(DocumentAttributes, DocumentRefPurchaseInvoice);
	
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	Query.SetParameter("Ref"						, DocumentRefPurchaseInvoice);
	Query.SetParameter("Company"					, StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime"				, New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics"			, StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches"					, StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins"				, StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseSerialNumbers"			, StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("ContinentalMethod"			, StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.SetParameter("PresentationCurrency"		, StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod"			, StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("RegisteredForVAT"			, StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("OwnInventory"				, Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting"	, StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("InventoryIncrease",
		NStr("en = 'Inventory receipt'; ru = 'Прием запасов';pl = 'Przyjęcie zapasów';es_ES = 'Recibo del inventario';es_CO = 'Recibo del inventario';tr = 'Stok fişi';it = 'Scorte ricevute';de = 'Bestandszugang'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("InventoryWriteOff",
		NStr("en = 'Inventory write-off'; ru = 'Списание запасов';pl = 'Rozchód zapasów';es_ES = 'Amortización del inventario';es_CO = 'Amortización del inventario';tr = 'Stok azaltma';it = 'Cancellazione di scorte';de = 'Bestandsabschreibung'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTablePurchases(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventoryInWarehouses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableGoodsAwaitingCustomsClearance(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePurchaseOrders(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableBackorders(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTableInventory(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableGoodsReceivedNotInvoiced(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateRawMaterialsConsumptionTable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventoryCostLayer(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableInventoryCost(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTableGoodsInvoicedNotReceived(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesRetained(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableUnallocatedExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePOSSummary(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	EndIf;
	
	// Serial numbers
	GenerateTableSerialNumbers(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	//VAT
	GenerateTableVATIncurred(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	GenerateTableTaxPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	GenerateTableAccountingEntriesData(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	TableForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	If Not TableForRegisterRecords.Property("TableGoodsReceivedNotInvoiced") Then
		TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", New ValueTable);
	EndIf;
	If Not TableForRegisterRecords.Property("TableIncomeAndExpenses") Then
		TableForRegisterRecords.Insert("TableIncomeAndExpenses", New ValueTable);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefPurchaseInvoice, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		Or StructureTemporaryTables.RegisterRecordsBackordersChange
		Or StructureTemporaryTables.RegisterRecordsSalesOrdersChange
		Or StructureTemporaryTables.RegisterRecordsPurchaseOrdersChange
		Or StructureTemporaryTables.RegisterRecordsInventoryDemandChange
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		Or StructureTemporaryTables.RegisterRecordsPOSSummaryChange
		Or StructureTemporaryTables.RegisterRecordsVATIncurredChange
		Or StructureTemporaryTables.RegisterRecordsGoodsInvoicedNotReceivedChange
		Or StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange
		Or StructureTemporaryTables.RegisterRecordsGoodsAwaitingCustomsClearanceChange
		Or StructureTemporaryTables.RegisterRecordsReservedProductsChange
		Or StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
		Query = New Query(
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
		|		INNER JOIN AccumulationRegister.InventoryInWarehouses.Balance(&ControlTime, ) AS InventoryInWarehousesOfBalance
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	RegisterRecordsSalesOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSalesOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsSalesOrdersChange.SalesOrder AS OrderPresentation,
		|	RegisterRecordsSalesOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSalesOrdersChange.Characteristic AS CharacteristicPresentation,
		|	SalesOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSalesOrdersChange.QuantityChange, 0) + ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS BalanceSalesOrders,
		|	ISNULL(SalesOrdersBalances.QuantityBalance, 0) AS QuantityBalanceSalesOrders
		|FROM
		|	RegisterRecordsSalesOrdersChange AS RegisterRecordsSalesOrdersChange
		|		INNER JOIN AccumulationRegister.SalesOrders.Balance(&ControlTime, ) AS SalesOrdersBalances
		|		ON RegisterRecordsSalesOrdersChange.Company = SalesOrdersBalances.Company
		|			AND RegisterRecordsSalesOrdersChange.SalesOrder = SalesOrdersBalances.SalesOrder
		|			AND RegisterRecordsSalesOrdersChange.Products = SalesOrdersBalances.Products
		|			AND RegisterRecordsSalesOrdersChange.Characteristic = SalesOrdersBalances.Characteristic
		|			AND (ISNULL(SalesOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPurchaseOrdersChange.LineNumber AS LineNumber,
		|	RegisterRecordsPurchaseOrdersChange.Company AS CompanyPresentation,
		|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS PurchaseOrderPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Products AS ProductsPresentation,
		|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
		|	PurchaseOrdersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsPurchaseOrdersChange.QuantityChange, 0) + ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS BalancePurchaseOrders,
		|	ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) AS QuantityBalancePurchaseOrders
		|FROM
		|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
		|		INNER JOIN AccumulationRegister.PurchaseOrders.Balance(&ControlTime, ) AS PurchaseOrdersBalances
		|		ON RegisterRecordsPurchaseOrdersChange.Company = PurchaseOrdersBalances.Company
		|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = PurchaseOrdersBalances.PurchaseOrder
		|			AND RegisterRecordsPurchaseOrdersChange.Products = PurchaseOrdersBalances.Products
		|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = PurchaseOrdersBalances.Characteristic
		|			AND (ISNULL(PurchaseOrdersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	RegisterRecordsBackordersChange.Company AS CompanyPresentation,
		|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsBackordersChange.Products AS ProductsPresentation,
		|	RegisterRecordsBackordersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsBackordersChange.SupplySource AS SupplySourcePresentation,
		|	BackordersBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		INNER JOIN AccumulationRegister.Backorders.Balance(&ControlTime, ) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|			AND (ISNULL(BackordersBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSuppliersSettlementsChange.LineNumber AS LineNumber,
		|	RegisterRecordsSuppliersSettlementsChange.Company AS CompanyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract AS ContractPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Document AS DocumentPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.Order AS OrderPresentation,
		|	RegisterRecordsSuppliersSettlementsChange.SettlementsType AS CalculationsTypesPresentation,
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
		|		INNER JOIN AccumulationRegister.AccountsPayable.Balance(&ControlTime, ) AS AccountsPayableBalances
		|		ON RegisterRecordsSuppliersSettlementsChange.Company = AccountsPayableBalances.Company
		|			AND RegisterRecordsSuppliersSettlementsChange.PresentationCurrency = AccountsPayableBalances.PresentationCurrency
		|			AND RegisterRecordsSuppliersSettlementsChange.Counterparty = AccountsPayableBalances.Counterparty
		|			AND RegisterRecordsSuppliersSettlementsChange.Contract = AccountsPayableBalances.Contract
		|			AND RegisterRecordsSuppliersSettlementsChange.Document = AccountsPayableBalances.Document
		|			AND RegisterRecordsSuppliersSettlementsChange.Order = AccountsPayableBalances.Order
		|			AND RegisterRecordsSuppliersSettlementsChange.SettlementsType = AccountsPayableBalances.SettlementsType
		|			AND (CASE
		|				WHEN RegisterRecordsSuppliersSettlementsChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|					THEN ISNULL(AccountsPayableBalances.AmountCurBalance, 0) > 0
		|				ELSE ISNULL(AccountsPayableBalances.AmountCurBalance, 0) < 0
		|			END)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsPOSSummaryChange.LineNumber AS LineNumber,
		|	RegisterRecordsPOSSummaryChange.Company AS CompanyPresentation,
		|	RegisterRecordsPOSSummaryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsPOSSummaryChange.StructuralUnit.RetailPriceKind.PriceCurrency AS CurrencyPresentation,
		|	ISNULL(POSSummaryBalances.AmountBalance, 0) AS AmountBalance,
		|	RegisterRecordsPOSSummaryChange.SumCurChange + ISNULL(POSSummaryBalances.AmountCurBalance, 0) AS BalanceInRetail,
		|	RegisterRecordsPOSSummaryChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsPOSSummaryChange.AmountChange AS AmountChange,
		|	RegisterRecordsPOSSummaryChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsPOSSummaryChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsPOSSummaryChange.CostBeforeWrite AS CostBeforeWrite,
		|	RegisterRecordsPOSSummaryChange.CostOnWrite AS CostOnWrite,
		|	RegisterRecordsPOSSummaryChange.CostUpdate AS CostUpdate
		|FROM
		|	RegisterRecordsPOSSummaryChange AS RegisterRecordsPOSSummaryChange
		|		INNER JOIN AccumulationRegister.POSSummary.Balance(&ControlTime, ) AS POSSummaryBalances
		|		ON RegisterRecordsPOSSummaryChange.Company = POSSummaryBalances.Company
		|			AND RegisterRecordsPOSSummaryChange.PresentationCurrency = POSSummaryBalances.PresentationCurrency
		|			AND RegisterRecordsPOSSummaryChange.StructuralUnit = POSSummaryBalances.StructuralUnit
		|			AND (ISNULL(POSSummaryBalances.AmountCurBalance, 0) < 0)
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
		Query.Text = Query.Text + AccumulationRegisters.GoodsReceivedNotInvoiced.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsAwaitingCustomsClearance.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsInvoicedNotReceived.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.ReservedProducts.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.Inventory.ReturnQuantityControlQueryText(False);
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[3].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty()
			Or Not ResultsArray[6].IsEmpty()
			Or Not ResultsArray[7].IsEmpty()
			Or Not ResultsArray[8].IsEmpty()
			Or Not ResultsArray[9].IsEmpty()
			Or Not ResultsArray[11].IsEmpty()
			Or Not ResultsArray[12].IsEmpty()
			Or Not ResultsArray[13].IsEmpty()
			Or Not ResultsArray[14].IsEmpty()
			Or Not ResultsArray[18].IsEmpty() Then
			DocumentObjectSupplierInvoice = DocumentRefPurchaseInvoice.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		// Negative balance of inventory.
		ElsIf Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		// Negative balance of need for reserved products.
		ElsIf Not ResultsArray[14].IsEmpty() Then
			QueryResultSelection = ResultsArray[14].Select();
			DriveServer.ShowMessageAboutPostingToReservedProductsRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		Else
			DriveServer.CheckAvailableStockBalance(DocumentObjectSupplierInvoice, AdditionalProperties, Cancel);
		EndIf;
		
		// Negative balance on sales order.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by the purchase order.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of needs in inventory.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory placement.
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on accounts payable.
		If Not ResultsArray[6].IsEmpty() Then
			QueryResultSelection = ResultsArray[6].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance according to the amount-based account in retail.
		If Not ResultsArray[7].IsEmpty() Then
			QueryResultSelection = ResultsArray[7].Select();
			DriveServer.ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If Not ResultsArray[8].IsEmpty() Then
			QueryResultSelection = ResultsArray[8].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[9].IsEmpty() Then
			QueryResultSelection = ResultsArray[9].Select();
			DriveServer.ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[11].IsEmpty() Then
			QueryResultSelection = ResultsArray[11].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[12].IsEmpty() Then
			QueryResultSelection = ResultsArray[12].Select();
			DriveServer.ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		If Not ResultsArray[13].IsEmpty() Then
			QueryResultSelection = ResultsArray[13].Select();
			DriveServer.ShowMessageAboutPostingToGoodsInvoicedNotReceivedRegisterErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of return quantity in inventory
		If Not ResultsArray[18].IsEmpty() And ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[18].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocumentObjectSupplierInvoice, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Writes to the Counterparties products prices information register.
//
Procedure RecordVendorPrices(DocumentRefPurchaseInvoice) Export

	If DocumentRefPurchaseInvoice.Posted Then
		DriveServer.DeleteVendorPrices(DocumentRefPurchaseInvoice);
	EndIf;
	
	If Not ValueIsFilled(DocumentRefPurchaseInvoice.SupplierPriceTypes) Then
		Return;
	EndIf; 
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TablePrices.Ref.Date AS Period,
	|	TablePrices.Ref.SupplierPriceTypes AS SupplierPriceTypes,
	|	TablePrices.Products AS Products,
	|	TablePrices.Characteristic AS Characteristic,
	|	MAX(CASE
	|			WHEN TablePrices.Ref.AmountIncludesVAT = TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|						END, 0)
	|			WHEN TablePrices.Ref.AmountIncludesVAT > TablePrices.Ref.SupplierPriceTypes.PriceIncludesVAT
	|				THEN ISNULL(TablePrices.Price * CASE
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|								THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|							WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|								THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|						END * 100 / (100 + TablePrices.VATRate.Rate), 0)
	|			ELSE ISNULL(TablePrices.Price * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|					END * (100 + TablePrices.VATRate.Rate) / 100, 0)
	|		END) AS Price,
	|	TablePrices.MeasurementUnit AS MeasurementUnit,
	|	TRUE AS Actuality,
	|	TablePrices.Ref AS DocumentRecorder,
	|	TablePrices.Ref.Author AS Author,
	|	SupplierInvoice.Counterparty AS Counterparty
	|FROM
	|	Document.SupplierInvoice.Inventory AS TablePrices
	|		LEFT JOIN InformationRegister.CounterpartyPrices AS CounterpartyPrices
	|		ON TablePrices.Ref.SupplierPriceTypes = CounterpartyPrices.SupplierPriceTypes
	|			AND TablePrices.Ref.Counterparty = CounterpartyPrices.Counterparty
	|			AND TablePrices.Products = CounterpartyPrices.Products
	|			AND TablePrices.Characteristic = CounterpartyPrices.Characteristic
	|			AND (BEGINOFPERIOD(TablePrices.Ref.Date, DAY) = CounterpartyPrices.Period)
	|			AND TablePrices.Ref.Date <= CounterpartyPrices.DocumentRecorder.Date
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON TablePrices.Ref.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency
	|		LEFT JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TablePrices.Ref = SupplierInvoice.Ref,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentCurrencyRate

	|WHERE
	|	TablePrices.Ref.RegisterVendorPrices
	|	AND CounterpartyPrices.SupplierPriceTypes IS NULL
	|	AND TablePrices.Ref = &Ref
	|	AND TablePrices.Price <> 0
	|
	|GROUP BY
	|	TablePrices.Products,
	|	TablePrices.Characteristic,
	|	TablePrices.MeasurementUnit,
	|	TablePrices.Ref.Date,
	|	TablePrices.Ref.SupplierPriceTypes,
	|	TablePrices.Ref,
	|	TablePrices.Ref.Author,
	|	SupplierInvoice.Counterparty";
	
	Query.SetParameter("Ref", 					DocumentRefPurchaseInvoice);
	Query.SetParameter("DocumentCurrency", 		DocumentRefPurchaseInvoice.DocumentCurrency);
	Query.SetParameter("ProcessingDate", 		DocumentRefPurchaseInvoice.Date);
	Query.SetParameter("Company", 				DocumentRefPurchaseInvoice.Company);
	Query.SetParameter("ExchangeRateMethod", 	DriveServer.GetExchangeMethod(DocumentRefPurchaseInvoice.Company));
	
	QueryResult = Query.Execute();
	RecordsTable = QueryResult.Unload();
	
	For Each TableRow In RecordsTable Do
		NewRecord = InformationRegisters.CounterpartyPrices.CreateRecordManager();
		FillPropertyValues(NewRecord, TableRow);
		NewRecord.Write();
	EndDo;

EndProcedure

#EndRegion

#Region Internal

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	
	If StructureData.TabName = "Expenses" Then
		IncomeAndExpenseStructure.Insert("RegisterExpense", StructureData.RegisterExpense);
		IncomeAndExpenseStructure.Insert("ExpenseItem", StructureData.ExpenseItem);
	EndIf;
	
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Expenses" Then
		Result.Insert("InventoryGLAccount", "ExpenseItem");
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
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", ObjectParameters.AdvancesPaidGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.TabName = "Inventory"
			And ObjectParameters.AdvanceInvoicing Then
			GLAccountsForFilling.Insert("GoodsInvoicedNotDeliveredGLAccount", StructureData.GoodsInvoicedNotDeliveredGLAccount);
		Else
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		
		If StructureData.TabName = "Inventory"
			And ValueIsFilled(StructureData.GoodsReceipt) Then
			GLAccountsForFilling.Insert("GoodsReceivedNotInvoicedGLAccount", StructureData.GoodsReceivedNotInvoicedGLAccount);
		ElsIf StructureData.TabName = "Materials" Then
			GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
		EndIf;
		
		If StructureData.TabName <> "Materials" Then
			If ObjectParameters.VATTaxation <> PredefinedValue("Enum.VATTaxationTypes.NotSubjectToVAT") Then
				GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
			EndIf;
			
			If ObjectParameters.VATTaxation = PredefinedValue("Enum.VATTaxationTypes.ReverseChargeVAT") Then
				GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
			EndIf;
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
	WarehouseData.Insert("Warehouse", DocObject.StructuralUnit);
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	Return Parameters;
	
EndFunction

#EndRegion

#Region WorkWithSerialNumbers

// Generates a table of values that contains the data for the SerialNumbersInWarranty information register.
// Tables of values saves into the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSerialNumbers(DocumentRef, StructureAdditionalProperties)
	
	If DocumentRef.SerialNumbers.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TemporaryTableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TemporaryTableInventory.Period AS EventDate,
	|	SerialNumbers.SerialNumber AS SerialNumber,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.Ownership AS Ownership,
	|	TemporaryTableInventory.StructuralUnit AS StructuralUnit,
	|	TemporaryTableInventory.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|		INNER JOIN TemporaryTableSerialNumbers AS SerialNumbers
	|		ON TemporaryTableInventory.ConnectionKey = SerialNumbers.ConnectionKey
	|WHERE
	|	TemporaryTableInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TemporaryTableInventory.AdvanceInvoicing
	|	AND NOT TemporaryTableInventory.ZeroInvoice";
	
	QueryResult = Query.Execute().Unload();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", QueryResult);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbers", New ValueTable);
	EndIf;
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Function generates document printing form by specified layout.
//
// Parameters:
// SpreadsheetDocument - TabularDocument in which
// 			   printing form will be displayed.
//  TemplateName    - String, printing form layout name.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_SupplierInvoice";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		
		If TemplateName = "MerchandiseFillingForm" Then
			
			Query.Text = 
			"SELECT ALLOWED
			|	SupplierInvoice.Date AS DocumentDate,
			|	SupplierInvoice.StructuralUnit AS WarehousePresentation,
			|	SupplierInvoice.Cell AS CellPresentation,
			|	SupplierInvoice.Number,
			|	SupplierInvoice.Company.Prefix AS Prefix,
			|	SupplierInvoice.Inventory.(
			|		LineNumber AS LineNumber,
			|		Products.Warehouse AS Warehouse,
			|		Products.Cell AS Cell,
			|		CASE
			|			WHEN (CAST(SupplierInvoice.Inventory.Products.DescriptionFull AS String(100))) = """"
			|				THEN SupplierInvoice.Inventory.Products.Description
			|			ELSE SupplierInvoice.Inventory.Products.DescriptionFull
			|		END AS InventoryItem,
			|		Products.SKU AS SKU,
			|		Products.Code AS Code,
			|		MeasurementUnit.Description AS MeasurementUnit,
			|		Quantity AS Quantity,
			|		Characteristic,
			|		Products.ProductsType AS ProductsType,
			|		ConnectionKey
			|	),
			|	SupplierInvoice.SerialNumbers.(
			|		SerialNumber,
			|		ConnectionKey
			|	)
			|FROM
			|	Document.SupplierInvoice AS SupplierInvoice
			|WHERE
			|	SupplierInvoice.Ref = &CurrentDocument
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
			
			SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_IncomeOrder_FormOfFilling";
			
			Template = PrintManagement.PrintFormTemplate("Document.SupplierInvoice.PF_MXL_MerchandiseFillingForm", LanguageCode);
			
			If Header.DocumentDate < Date('20110101') Then
				DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
			Else
				DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			EndIf;
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText =
				"Supplier invoice #"
			  + DocumentNumber
			  + " dated "
			  + Format(Header.DocumentDate, "DLF=DD");
			
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
			TemplateArea.Parameters.PrintingTime =
				"Date and time of printing: "
			  + CurrentSessionDate()
			  + ". User: "
			  + Users.CurrentUser();
			
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
					StringSerialNumbers
				);
				
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

// Generate printed forms of objects
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
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "MerchandiseFillingForm") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"MerchandiseFillingForm",
			NStr("en = 'Merchandise filling form'; ru = 'Форма заполнения сопутствующих товаров';pl = 'Formularz wypełnienia towaru';es_ES = 'Formulario para rellenar las mercancías';es_CO = 'Formulario para rellenar las mercancías';tr = 'Mamul formu';it = 'Modulo di compilazione merce';de = 'Handelswarenformular'"),
			PrintForm(ObjectsArray, PrintObjects, "MerchandiseFillingForm", PrintParameters.Result));
		
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
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'; ru = 'Уведомление о доставке товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Nota de recepción de productos';es_CO = 'Nota de recepción de productos';tr = 'Teslim alındı belgesi';it = 'Nota di ricezione merci';de = 'Lieferantenlieferschein'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "MerchandiseFillingForm";
	PrintCommand.Presentation = NStr("en = 'Inventory allocation card'; ru = 'Бланк распределения запасов';pl = 'Karta alokacji zapasów';es_ES = 'Tarjeta de asignación de inventario';es_CO = 'Tarjeta de asignación de inventario';tr = 'Stok dağıtım kartı';it = 'Scheda di allocazione scorte';de = 'Bestandszuordnungskarte'");
	PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;
	
	If AccessRight("view", Metadata.DataProcessors.PrintLabelsAndTags) Then
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "LabelsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Labels'; ru = 'Этикетки';pl = 'Etykiety';es_ES = 'Etiquetas';es_CO = 'Etiquetas';tr = 'Marka etiketleri';it = 'Etichette';de = 'Etiketten'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 3;
		
		PrintCommand = PrintCommands.Add();
		PrintCommand.Handler = "DriveClient.PrintLabelsAndPriceTagsFromDocuments";
		PrintCommand.ID = "PriceTagsPrintingFromSupplierInvoice";
		PrintCommand.Presentation = NStr("en = 'Price tags'; ru = 'Ценники';pl = 'Cenniki';es_ES = 'Etiquetas de precio';es_CO = 'Etiquetas de precio';tr = 'Fiyat etiketleri';it = 'Cartellini di prezzo';de = 'Preisschilder'");
		PrintCommand.FormsList = "DocumentForm,ListForm,DocumentsListForm";
		PrintCommand.CheckPostingBeforePrint = False;
		PrintCommand.Order = 4;
		
	EndIf;
	
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

#Region Private

#Region TableGeneration

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	ISNULL(TableInventory.StructuralUnit, VALUE(Catalog.Counterparties.EmptyRef)) AS StructuralUnit,
	|	ISNULL(TableInventory.StructuralUnitCorr, VALUE(Catalog.BusinessUnits.EmptyRef)) AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Ownership AS OwnershipCorr,
	|	TableInventory.CostObject AS CostObject,
	|	UNDEFINED AS CostObjectCorr,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableInventory.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.Specification AS SpecificationCorr,
	|	TableInventory.VATRate AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	FALSE AS Return,
	|	CASE
	|		WHEN TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN TableInventory.GoodsReceipt
	|		ELSE UNDEFINED
	|	END AS SourceDocument,
	|	UNDEFINED AS SalesOrder,
	|	UNDEFINED AS CorrSalesOrder,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	TableInventory.Order AS SupplySource,
	|	UNDEFINED AS CustomerCorrOrder,
	|	FALSE AS ProductionExpenses,
	|	TableInventory.FixedCost AS FixedCost,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN TableInventory.ContinentalMethod
	|					AND TableInventory.ReverseChargeVATAmountForNotRegistered > 0
	|				THEN 0
	|			ELSE TableInventory.Quantity
	|		END) AS Quantity,
	|	0 AS QuantityForCostLayer,
	|	SUM(CASE
	|			WHEN TableInventory.ContinentalMethod
	|					AND TableInventory.ReverseChargeVATAmountForNotRegistered  > 0
	|				THEN TableInventory.ReverseChargeVATAmountForNotRegistered
	|			ELSE TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense + TableInventory.ReverseChargeVATAmountForNotRegistered
	|		END) AS Amount,
	|	0 AS Cost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.RetailTransferEarningAccounting
	|	AND NOT TableInventory.AdvanceInvoicing
	|	AND NOT TableInventory.ZeroInvoice
	|	AND (TableInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|			OR TableInventory.ContinentalMethod
	|				AND TableInventory.ReverseChargeVATAmountForNotRegistered > 0)
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.CorrOrganization,
	|	TableInventory.CorrPresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType,
	|	TableInventory.IncomeAndExpenseItem,
	|	TableInventory.CorrIncomeAndExpenseItem,
	|	VALUE(Catalog.Employees.EmptyRef),
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.VATRate,
	|	TableInventory.FixedCost,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.RecordType,
	|	CASE
	|		WHEN TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|			THEN TableInventory.GoodsReceipt
	|		ELSE UNDEFINED
	|	END,
	|	TableInventory.Order,
	|	TableInventory.Ownership,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.CostObject,
	|	TableInventory.Specification
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
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
	|	OfflineRecords.CostObjectCorr,
	|	OfflineRecords.InventoryAccountType,
	|	OfflineRecords.CorrInventoryAccountType,
	|	OfflineRecords.IncomeAndExpenseItem,
	|	OfflineRecords.CorrIncomeAndExpenseItem,
	|	OfflineRecords.Specification,
	|	OfflineRecords.SpecificationCorr,
	|	OfflineRecords.VATRate,
	|	OfflineRecords.Responsible,
	|	OfflineRecords.Return,
	|	OfflineRecords.SourceDocument,
	|	OfflineRecords.SalesOrder,
	|	OfflineRecords.CorrSalesOrder,
	|	OfflineRecords.Department,
	|	UNDEFINED,
	|	OfflineRecords.CustomerCorrOrder,
	|	OfflineRecords.ProductionExpenses,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.Quantity,
	|	0,
	|	OfflineRecords.Amount,
	|	0,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord";
	
	Query.SetParameter("ContinentalMethod", StructureAdditionalProperties.AccountingPolicy.ContinentalMethod);
	Query.SetParameter("RegisteredForVAT", StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult.Unload());
	
	If Not StructureAdditionalProperties.DocumentAttributes.IsDropShipping Then
		GenerateTableReservedProducts(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	Else
		TableReservedProducts = DriveServer.EmptyReservedProductsTable();
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	EndIf;
	
	GenerateTableSalesInvoices(DocumentRefPurchaseInvoice, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableReservedProducts(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	TableBackorders = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.CopyColumns();
	TableReservedProducts = DriveServer.EmptyReservedProductsTable();
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Total("Quantity") <> 0 Then
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SupplySource",	RowTableInventory.SupplySource);
			StructureForSearch.Insert("Products",		RowTableInventory.Products);
			StructureForSearch.Insert("Characteristic",	RowTableInventory.Characteristic);
			
			PlacedOrdersTable = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			RowTableInventoryQuantity = RowTableInventory.Quantity;
			
			If PlacedOrdersTable.Count() > 0 Then
				
				For Each PlacedOrdersRow In PlacedOrdersTable Do
					
					If PlacedOrdersRow.Quantity <=0 Then
						Continue;
					EndIf;
					
					// Placement
					NewRowTableBackorders = TableBackorders.Add();
					FillPropertyValues(NewRowTableBackorders, PlacedOrdersRow);
					
					// Reserve
					NewRowReservedTable = TableReservedProducts.Add();
					FillPropertyValues(NewRowReservedTable, RowTableInventory);
					NewRowReservedTable.SalesOrder = ?(ValueIsFilled(PlacedOrdersRow.SalesOrder), PlacedOrdersRow.SalesOrder, Undefined);
					
					NewRowTableBackorders.Quantity = Min(RowTableInventoryQuantity, PlacedOrdersRow.Quantity);
					NewRowReservedTable.Quantity = Min(RowTableInventoryQuantity, PlacedOrdersRow.Quantity);
					
					PlacedOrdersRow.Quantity = PlacedOrdersRow.Quantity - NewRowTableBackorders.Quantity;
					RowTableInventoryQuantity = RowTableInventoryQuantity - NewRowTableBackorders.Quantity;
					
					If RowTableInventoryQuantity <= 0 Then
						Break;
					EndIf;
					
				EndDo;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableReservedProducts", TableReservedProducts);
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders = TableBackorders;
	TableBackorders = Undefined;
	
EndProcedure

// Genera tes a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableSalesInvoices(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.RecordType AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	VALUE(Enum.InventoryAccountTypes.ManufacturingOverheads) AS InventoryAccountType,
	|	TableInventory.ExpenseItem AS IncomeAndExpenseItem,
	|	UNDEFINED AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableInventory.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS SalesOrder,
	|	0 AS Quantity,
	|	0 AS QuantityForCostLayer,
	|	SUM(TableInventory.Amount - TableInventory.VATAmount) AS Amount,
	|	TRUE AS FixedCost,
	|	TRUE AS ProductionExpenses,
	|	&OtherExpenses AS ContentOfAccountingRecord
	|FROM
	|	TemporaryTableExpenses AS TableInventory
	|WHERE
	|	NOT TableInventory.IncludeExpensesInCostPrice
	|	AND TableInventory.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.ManufacturingOverheads)
	|	AND TableInventory.RegisterExpense
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.ExpenseItem,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.Order,
	|	TableInventory.RecordType";
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'; ru = 'Прочих затраты (расходы)';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(NewRow, Selection);
		
	EndDo;
	
EndProcedure

Procedure GenerateTableInventoryCost(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.InventoryAccountType AS InventoryAccountType
	|FROM
	|	TemporaryTableMaterials AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryAccountType";
	
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
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.QuantityBalance AS QuantityBalance,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	InventoryBalances.AmountBalance AS AmountBalance
	|INTO InventoryBalances
	|FROM
	|	AccumulationRegister.Inventory.Balance(
	|			&ControlTime,
	|			(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
	|				(SELECT
	|					TableInventory.Company,
	|					TableInventory.PresentationCurrency,
	|					TableInventory.StructuralUnit,
	|					TableInventory.InventoryAccountType,
	|					TableInventory.Products,
	|					TableInventory.Characteristic,
	|					TableInventory.Batch,
	|					TableInventory.Ownership,
	|					TableInventory.CostObject
	|				FROM
	|					TemporaryTableMaterials AS TableInventory)) AS InventoryBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsInventory.Company,
	|	DocumentRegisterRecordsInventory.PresentationCurrency,
	|	DocumentRegisterRecordsInventory.Products,
	|	DocumentRegisterRecordsInventory.Characteristic,
	|	DocumentRegisterRecordsInventory.Batch,
	|	DocumentRegisterRecordsInventory.Ownership,
	|	DocumentRegisterRecordsInventory.CostObject,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN DocumentRegisterRecordsInventory.Quantity
	|		ELSE -DocumentRegisterRecordsInventory.Quantity
	|	END,
	|	DocumentRegisterRecordsInventory.StructuralUnit,
	|	DocumentRegisterRecordsInventory.InventoryAccountType,
	|	CASE
	|		WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|			THEN DocumentRegisterRecordsInventory.Amount
	|		ELSE -DocumentRegisterRecordsInventory.Amount
	|	END
	|FROM
	|	AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|WHERE
	|	DocumentRegisterRecordsInventory.Recorder = &Ref
	|	AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.PresentationCurrency AS PresentationCurrency,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	InventoryBalances.Ownership AS Ownership,
	|	InventoryBalances.CostObject AS CostObject,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	InventoryBalances AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.PresentationCurrency,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch,
	|	InventoryBalances.Ownership,
	|	InventoryBalances.CostObject,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.InventoryAccountType";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add(
		"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
	
	Materials = StructureAdditionalProperties.TableForRegisterRecords.TableRawMaterialsConsumption;
	
	TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
	TemporaryTableInventory = TableInventory.Copy();
	
	StructuralUnitColumn = TemporaryTableInventory.Columns.Find("StructuralUnit");
	StructuralUnitNewColumn = TemporaryTableInventory.Columns.Add("StructuralUnitNew",
		New TypeDescription("CatalogRef.BusinessUnits, CatalogRef.Counterparties"));
	TemporaryTableInventory.LoadColumn(TemporaryTableInventory.UnloadColumn("StructuralUnit"), "StructuralUnitNew");
	TemporaryTableInventory.Columns.Delete(StructuralUnitColumn);
	StructuralUnitNewColumn.Name = "StructuralUnit";
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	TableAccountingJournalEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;

	For n = 0 To Materials.Count() - 1 Do
		
		RowTableInventory = Materials[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company",				RowTableInventory.Company);
		StructureForSearch.Insert("PresentationCurrency",   RowTableInventory.PresentationCurrency);
		StructureForSearch.Insert("StructuralUnit",			RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("InventoryAccountType",	RowTableInventory.InventoryAccountType);
		StructureForSearch.Insert("Products",				RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic",			RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch",					RowTableInventory.Batch);
		StructureForSearch.Insert("Ownership",				RowTableInventory.Ownership);
		StructureForSearch.Insert("CostObject",				RowTableInventory.CostObject);
		
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
			TableRowExpense.QuantityForCostLayer = QuantityRequiredAvailableBalance;
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode);
			
			// Generate postings.
			If UseDefaultTypeOfAccounting And Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, RowTableInventory);
				RowTableAccountingJournalEntries.Amount = AmountToBeWrittenOff;
				RowTableAccountingJournalEntries.Content = NStr("en = 'Inventory allocation'; ru = 'Распределение запасов';pl = 'Alokacja zapasów';es_ES = 'Asignación del inventario';es_CO = 'Asignación del inventario';tr = 'Stok dağıtımı';it = 'Allocazione delle scorte';de = 'Bestandszuordnung'", MainLanguageCode);
				
			EndIf;
			
			// Receipt. Inventory.
			TableRowReceipt = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory,, "Quantity");
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
			TableRowReceipt.Company                  = RowTableInventory.CorrOrganization;
			TableRowReceipt.PresentationCurrency     = RowTableInventory.PresentationCurrency;
			TableRowReceipt.Products           		 = RowTableInventory.ProductsCorr;
			TableRowReceipt.Characteristic           = RowTableInventory.CharacteristicCorr;
			TableRowReceipt.Batch                    = RowTableInventory.BatchCorr;
			TableRowReceipt.Ownership                = RowTableInventory.OwnershipCorr;
			TableRowReceipt.CostObject               = RowTableInventory.CostObjectCorr;
			TableRowReceipt.GLAccount                = RowTableInventory.CorrGLAccount;
			TableRowReceipt.StructuralUnit           = RowTableInventory.StructuralUnitCorr;
			TableRowReceipt.InventoryAccountType     = RowTableInventory.CorrInventoryAccountType;
			
			TableRowReceipt.SalesOrder               = RowTableInventory.CustomerCorrOrder;
			
			TableRowReceipt.CorrOrganization         = RowTableInventory.Company;
			TableRowReceipt.CorrPresentationCurrency = RowTableInventory.PresentationCurrency;
			TableRowReceipt.ProductsCorr 			 = RowTableInventory.Products;
			TableRowReceipt.CharacteristicCorr		 = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr 				 = RowTableInventory.Batch;
			TableRowReceipt.OwnershipCorr            = RowTableInventory.Ownership;
			TableRowReceipt.CostObjectCorr            = RowTableInventory.CostObject;
			TableRowReceipt.CorrGLAccount            = RowTableInventory.GLAccount;
			TableRowReceipt.StructuralUnitCorr       = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrInventoryAccountType = RowTableInventory.InventoryAccountType;
			
			TableRowReceipt.CustomerCorrOrder = Undefined;
			
			TableRowReceipt.Amount = AmountToBeWrittenOff;
			TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'", MainLanguageCode);
			
		EndIf;
		
	EndDo;
	
	ColumnsStructure = GetColumnsStructure(TemporaryTableInventory);
	TemporaryTableInventory.GroupBy(ColumnsStructure.GroupingColumns, ColumnsStructure.TotalingColumns);
	
	ColumnsStructure = GetColumnsStructure(TableAccountingJournalEntries);
	TableAccountingJournalEntries.GroupBy(ColumnsStructure.GroupingColumns, ColumnsStructure.TotalingColumns);
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

Procedure GenerateRawMaterialsConsumptionTable(DocumentRefProduction, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.Date AS Period,
	|	SupplierInvoice.Counterparty AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN SupplierInvoice.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	UNDEFINED AS SalesOrder,
	|	SupplierInvoice.Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoice.StructuralUnit AS StructuralUnitCorr,
	|	UNDEFINED AS CustomerCorrOrder
	|INTO DocumentData
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.LineNumber AS CorrLineNumber,
	|	TableProduction.Products AS ProductsCorr,
	|	TableProduction.Characteristic AS CharacteristicCorr,
	|	TableProduction.Batch AS BatchCorr,
	|	TableProduction.Ownership AS OwnershipCorr,
	|	TableProduction.CostObject AS CostObjectCorr,
	|	TableProduction.Specification AS SpecificationCorr,
	|	TableProduction.InventoryAccountType AS CorrInventoryAccountType,
	|	TableProduction.GLAccount AS CorrGLAccount,
	|	TableProduction.GLAccount AS ProductsGLAccount,
	|	TableProduction.GLAccount AS AccountDr,
	|	TableProduction.GLAccount AS ProductsAccountDr,
	|	TableProduction.GLAccount AS ProductsAccountCr,
	|	TableProduction.Quantity AS CorrQuantity
	|FROM
	|	TemporaryTableInventory AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.LineNumber AS CorrLineNumber,
	|	TableProductsContent.Products AS ProductsCorr,
	|	TableProductsContent.Characteristic AS CharacteristicCorr,
	|	TableProductsContent.Batch AS BatchCorr,
	|	TableProductsContent.Ownership AS OwnershipCorr,
	|	TableProductsContent.CostObject AS CostObjectCorr,
	|	TableProductsContent.Specification AS SpecificationCorr,
	|	TableProductsContent.InventoryAccountType AS CorrInventoryAccountType,
	|	TableProductsContent.GLAccount AS CorrGLAccount,
	|	TableProductsContent.GLAccount AS ProductsGLAccount,
	|	TableProductsContent.GLAccount AS AccountDr,
	|	TableProductsContent.GLAccount AS ProductsAccountDr,
	|	TableProductsContent.GLAccount AS ProductsAccountCr,
	|	TableProductsContent.Quantity AS CorrQuantity,
	|	CASE
	|		WHEN VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN CASE
	|					WHEN TableMaterials.Quantity = 0
	|						THEN 1
	|					ELSE TableMaterials.Quantity
	|				END / TableMaterials.Ref.Quantity * TableProductsContent.Quantity
	|		ELSE CASE
	|				WHEN TableMaterials.Quantity = 0
	|					THEN 1
	|				ELSE TableMaterials.Quantity
	|			END * TableMaterials.MeasurementUnit.Factor / TableMaterials.Ref.Quantity * TableProductsContent.Quantity
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
	|FROM
	|	TemporaryTableInventory AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Materials.LineNumber AS LineNumber,
	|	Materials.Ref AS Ref,
	|	DocumentData.Period AS Period,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentData.StructuralUnit AS StructuralUnit,
	|	DocumentData.Cell AS Cell,
	|	VALUE(Enum.InventoryAccountTypes.InventoryOnHand) AS InventoryAccountType,
	|	VALUE(Enum.InventoryAccountTypes.EmptyRef) AS CorrInventoryAccountType,
	|	Materials.InventoryTransferredGLAccount AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsGLAccount,
	|	Materials.Products AS Products,
	|	VALUE(Catalog.Products.EmptyRef) AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Materials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Materials.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	&OwnInventory AS Ownership,
	|	VALUE(Catalog.InventoryOwnership.EmptyRef) AS OwnershipCorr,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObjectCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS SpecificationCorr,
	|	DocumentData.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(Materials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN Materials.Quantity
	|		ELSE Materials.Quantity * Materials.MeasurementUnit.Factor
	|	END AS Quantity,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS AccountDr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountDr,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Materials.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountCr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountCr,
	|	FALSE AS Distributed,
	|	DocumentData.Company AS Company,
	|	DocumentData.PresentationCurrency AS PresentationCurrency,
	|	DocumentData.Company AS CorrOrganization,
	|	DocumentData.StructuralUnitCorr AS StructuralUnitCorr,
	|	DocumentData.CustomerCorrOrder AS CustomerCorrOrder
	|FROM
	|	DocumentData AS DocumentData
	|		INNER JOIN Document.SupplierInvoice.Materials AS Materials
	|		ON DocumentData.Ref = Materials.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref",					DocumentRefProduction);
	Query.SetParameter("PresentationCurrency",  StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("OwnInventory",			Catalogs.InventoryOwnership.OwnInventory());
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProduction = ResultsArray[1].Unload();
	TableProductsContent = ResultsArray[2].Unload();
	MaterialsTable = ResultsArray[3].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.BOMLineType.Node Then
			NodesBillsOfMaterialstack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesBillsOfMaterialstack);
			TableProductsContent.Delete(ProductsRow);
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProductsContent.GroupBy("ProductsCorr, CharacteristicCorr, BatchCorr, OwnershipCorr, CostObjectCorr,
		|CorrGLAccount, SpecificationCorr, CorrInventoryAccountType, ProductsGLAccount, AccountDr,
		|ProductsAccountDr, ProductsAccountCr, CorrQuantity, TMProducts, TMCharacteristic, Distributed", "TMQuantity");
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRawMaterialsConsumption", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableIncomeAndExpenses.LineNumber) AS LineNumber,
	|	TRUE AS Active,
	|	TableIncomeAndExpenses.Period AS Period,
	|	TableIncomeAndExpenses.Company AS Company,
	|	TableIncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN TableIncomeAndExpenses.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|			THEN VALUE(Catalog.LinesOfBusiness.Other)
	|		ELSE TableIncomeAndExpenses.BusinessLine
	|	END AS BusinessLine,
	|	CASE
	|		WHEN TableIncomeAndExpenses.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TableIncomeAndExpenses.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableIncomeAndExpenses.Order
	|	END AS SalesOrder,
	|	TableIncomeAndExpenses.ExpenseItem AS IncomeAndExpenseItem,
	|	TableIncomeAndExpenses.GLAccount AS GLAccount,
	|	CAST(&OtherExpenses AS STRING(100)) AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	SUM(TableIncomeAndExpenses.Amount - TableIncomeAndExpenses.VATAmount + TableIncomeAndExpenses.ReverseChargeVATAmountForNotRegistered) AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExpenses AS TableIncomeAndExpenses
	|WHERE
	|	NOT TableIncomeAndExpenses.IncludeExpensesInCostPrice
	|	AND NOT &ZeroInvoice
	|	AND TableIncomeAndExpenses.RegisterExpense
	|	AND (TableIncomeAndExpenses.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)
	|			OR TableIncomeAndExpenses.ExpenseItemType = VALUE(Catalog.IncomeAndExpenseTypes.OtherExpenses))
	|
	|GROUP BY
	|	TableIncomeAndExpenses.Period,
	|	TableIncomeAndExpenses.Company,
	|	TableIncomeAndExpenses.PresentationCurrency,
	|	TableIncomeAndExpenses.StructuralUnit,
	|	TableIncomeAndExpenses.BusinessLine,
	|	TableIncomeAndExpenses.ExpenseItemType,
	|	TableIncomeAndExpenses.Order,
	|	TableIncomeAndExpenses.ExpenseItem,
	|	TableIncomeAndExpenses.GLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	TRUE,
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
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("RegisteredForVAT",								StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("Ref",											DocumentRefPurchaseInvoice);
	Query.SetParameter("ZeroInvoice",									StructureAdditionalProperties.DocumentAttributes.IsZeroInvoice);
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'; ru = 'Отражение расходов';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("IncomeReflection",
		NStr("en = 'Income accrued'; ru = 'Отражение доходов';pl = 'Naliczony dochód';es_ES = 'Ingreso acumulado';es_CO = 'Ingreso acumulado';tr = 'Tahakkuk eden gelir';it = 'Reddito maturato';de = 'Einnahme aufgelaufen'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("CostsReflection",
		NStr("en = 'Expenses accrued'; ru = 'Отражение расходов';pl = 'Naliczone rozchody';es_ES = 'Gastos acumulados';es_CO = 'Gastos acumulados';tr = 'Tahakkuk eden harcamalar';it = 'Spese maturate';de = 'Angelaufene Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	TableForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	If TableForRegisterRecords.Property("TableIncomeAndExpenses") Then
		Selection = QueryResult.Select();
		While Selection.Next() Do
			NewEntry = TableForRegisterRecords.TableIncomeAndExpenses.Add();
			FillPropertyValues(NewEntry, Selection);
		EndDo;
	Else
		TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	EndIf;
	
EndProcedure

// Cash flow projection table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("NetDates", PaymentTermsServer.NetPaymentDates());
	
	Query.Text =
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.PaymentMethod AS PaymentMethod,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.PettyCash AS PettyCash,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.BankAccount AS BankAccount,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SupplierInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SupplierInvoice.CashAssetType AS CashAssetType
	|INTO Document
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|	AND SupplierInvoice.SetPaymentTerms
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentTable.PaymentDate AS Period,
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
	|			THEN DocumentTable.PaymentAmount
	|		ELSE DocumentTable.PaymentAmount + DocumentTable.PaymentVATAmount
	|	END AS PaymentAmount,
	|	Document.CashAssetType AS CashAssetType,
	|	DocumentTable.CashFlowItem
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Document.SupplierInvoice.PaymentCalendar AS DocumentTable
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
	|	PaymentCalendar.CashFlowItem AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	CAST(-PaymentCalendar.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN 1 / (PaymentCalendar.ExchangeRate * PaymentCalendar.ContractCurrencyMultiplicity / (PaymentCalendar.ContractCurrencyExchangeRate * PaymentCalendar.Multiplicity))
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchases(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TablePurchases.Period AS Period,
	|	TablePurchases.Company AS Company,
	|	TablePurchases.PresentationCurrency AS PresentationCurrency,
	|	TablePurchases.Counterparty AS Counterparty,
	|	TablePurchases.Currency AS Currency,
	|	TablePurchases.Products AS Products,
	|	TablePurchases.Characteristic AS Characteristic,
	|	TablePurchases.Batch AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	TablePurchases.Order AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.VATAmount) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.VATAmount) AS Amount,
	|	SUM(TablePurchases.VATAmountDocCur) AS VATAmountCur,
	|	SUM(TablePurchases.AmountDocCur - TablePurchases.VATAmountDocCur) AS AmountCur,
	|	TablePurchases.ZeroInvoice AS ZeroInvoice
	|FROM
	|	TemporaryTableInventory AS TablePurchases
	|WHERE
	|	NOT TablePurchases.AdvanceInvoicing
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.Order,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	TablePurchases.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	SUM(TablePurchases.Quantity),
	|	SUM(TablePurchases.VATAmount),
	|	SUM(TablePurchases.Amount - TablePurchases.VATAmount),
	|	SUM(TablePurchases.VATAmountDocCur),
	|	SUM(TablePurchases.AmountDocCur - TablePurchases.VATAmountDocCur),
	|	TablePurchases.ZeroInvoice
	|FROM
	|	TemporaryTableExpenses AS TablePurchases
	|WHERE
	|	NOT TablePurchases.AdvanceInvoicing
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Characteristic,
	|	TablePurchases.Batch,
	|	TablePurchases.Ownership,
	|	TablePurchases.PurchaseOrder,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate,
	|	TablePurchases.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	Header.Date,
	|	Header.Company,
	|	Header.PresentationCurrency,
	|	Header.Counterparty,
	|	Header.Currency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	&OwnInventory,
	|	UNDEFINED,
	|	Header.Ref,
	|	UNDEFINED,
	|	0,
	|	0,
	|	0,
	|	0,
	|	0,
	|	TRUE
	|FROM
	|	SupplierInvoiceHeader AS Header
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON Header.Ref = TemporaryTableInventory.Document
	|WHERE
	|	Header.ZeroInvoice
	|	AND TemporaryTableInventory.Products IS NULL";
	
	Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInWarehouses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventoryInWarehouses.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventoryInWarehouses.Period AS Period,
	|	TableInventoryInWarehouses.Company AS Company,
	|	TableInventoryInWarehouses.Products AS Products,
	|	TableInventoryInWarehouses.Characteristic AS Characteristic,
	|	TableInventoryInWarehouses.Batch AS Batch,
	|	TableInventoryInWarehouses.Ownership AS Ownership,
	|	TableInventoryInWarehouses.StructuralUnit AS StructuralUnit,
	|	TableInventoryInWarehouses.Cell AS Cell,
	|	SUM(TableInventoryInWarehouses.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventoryInWarehouses
	|WHERE
	|	NOT TableInventoryInWarehouses.RetailTransferEarningAccounting
	|	AND TableInventoryInWarehouses.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TableInventoryInWarehouses.AdvanceInvoicing
	|	AND NOT TableInventoryInWarehouses.ZeroInvoice
	|	AND NOT TableInventoryInWarehouses.DropShipping
	|
	|GROUP BY
	|	TableInventoryInWarehouses.Period,
	|	TableInventoryInWarehouses.Company,
	|	TableInventoryInWarehouses.Products,
	|	TableInventoryInWarehouses.Characteristic,
	|	TableInventoryInWarehouses.Batch,
	|	TableInventoryInWarehouses.Ownership,
	|	TableInventoryInWarehouses.StructuralUnit,
	|	TableInventoryInWarehouses.Cell";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsAwaitingCustomsClearance(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ForExport Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TemporaryTableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Counterparty AS Counterparty,
	|	TemporaryTableInventory.Contract AS Contract,
	|	TemporaryTableInventory.Document AS SupplierInvoice,
	|	TemporaryTableInventory.Order AS PurchaseOrder,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	SUM(TemporaryTableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.RetailTransferEarningAccounting
	|	AND NOT TemporaryTableInventory.ZeroInvoice
	|
	|GROUP BY
	|	TemporaryTableInventory.Contract,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.Batch,
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Document,
	|	TemporaryTableInventory.Order,
	|	TemporaryTableInventory.Counterparty,
	|	TemporaryTableInventory.Products";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsAwaitingCustomsClearance", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryCostLayer(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	
	"SELECT
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN Inventory.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	Inventory.Quantity AS Quantity,
	|	Inventory.QuantityForCostLayer AS QuantityForCostLayer,
	|	Inventory.Amount AS Amount
	|INTO TemporaryTableInventoryComplete
	|FROM
	|	&TableInventory AS Inventory
	|WHERE
	|	Inventory.Products <> VALUE(Catalog.Products.EmptyRef)
	|	AND Inventory.Products <> UNDEFINED
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Inventory.Period AS Period,
	|	Inventory.Company AS Company,
	|	Inventory.PresentationCurrency AS PresentationCurrency,
	|	Inventory.Products AS Products,
	|	Inventory.SalesOrder AS SalesOrder,
	|	Inventory.Characteristic AS Characteristic,
	|	&Ref AS CostLayer,
	|	Inventory.Batch AS Batch,
	|	Inventory.Ownership AS Ownership,
	|	Inventory.InventoryAccountType AS InventoryAccountType,
	|	Inventory.StructuralUnit AS StructuralUnit,
	|	Inventory.GLAccount AS GLAccount,
	|	SUM(CASE
	|			WHEN Inventory.Quantity = 0
	|				THEN Inventory.QuantityForCostLayer
	|			ELSE Inventory.Quantity
	|		END) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	TemporaryTableInventoryComplete AS Inventory
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Inventory.Period,
	|	Inventory.Company,
	|	Inventory.PresentationCurrency,
	|	Inventory.Products,
	|	Inventory.SalesOrder,
	|	Inventory.Characteristic,
	|	Inventory.Batch,
	|	Inventory.Ownership,
	|	Inventory.InventoryAccountType,
	|	Inventory.StructuralUnit,
	|	Inventory.GLAccount";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	Query.SetParameter("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventory);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePurchaseOrders(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
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
	|	TablePurchaseOrders.Order AS PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TablePurchaseOrders
	|WHERE
	|	TablePurchaseOrders.Order <> UNDEFINED
	|	AND TablePurchaseOrders.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TablePurchaseOrders.ZeroInvoice
	|
	|GROUP BY
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.Order
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TablePurchaseOrders.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TablePurchaseOrders.Period,
	|	TablePurchaseOrders.Company,
	|	TablePurchaseOrders.Products,
	|	TablePurchaseOrders.Characteristic,
	|	TablePurchaseOrders.PurchaseOrder,
	|	SUM(TablePurchaseOrders.Quantity)
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
Procedure GenerateTableBackorders(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Inventory and expenses placement.
	Query.Text =
	"SELECT
	|	TablePlacement.Period AS Period,
	|	TablePlacement.Company AS Company,
	|	TablePlacement.Products AS Products,
	|	TablePlacement.Characteristic AS Characteristic,
	|	TablePlacement.PurchaseOrder AS Order,
	|	SUM(TablePlacement.Quantity) AS Quantity
	|INTO TemporaryTablePlacement
	|FROM
	|	TemporaryTableExpenses AS TablePlacement
	|WHERE
	|	NOT TablePlacement.PurchaseOrder IN (VALUE(Document.PurchaseOrder.EmptyRef), UNDEFINED)
	|
	|GROUP BY
	|	TablePlacement.Period,
	|	TablePlacement.Company,
	|	TablePlacement.Products,
	|	TablePlacement.Characteristic,
	|	TablePlacement.PurchaseOrder";
	
	Query.Execute();
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableBackorders.Company AS Company,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.Order AS SupplySource
	|FROM
	|	TemporaryTablePlacement AS TableBackorders";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableBackorders.Period AS Period,
	|	TableBackorders.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableBackorders.Products AS Products,
	|	TableBackorders.Characteristic AS Characteristic,
	|	TableBackorders.Order AS SupplySource,
	|	CASE
	|		WHEN TableBackorders.Quantity > ISNULL(BackordersBalances.Quantity, 0)
	|			THEN ISNULL(BackordersBalances.Quantity, 0)
	|		WHEN TableBackorders.Quantity <= ISNULL(BackordersBalances.Quantity, 0)
	|			THEN TableBackorders.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTablePlacement AS TableBackorders
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				BackordersBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						,
	|						(Company, Products, Characteristic, SupplySource) IN
	|							(SELECT
	|								TableBackorders.Company AS Company,
	|								TableBackorders.Products AS Products,
	|								TableBackorders.Characteristic AS Characteristic,
	|								TableBackorders.Order AS SupplySource
	|							FROM
	|								TemporaryTablePlacement AS TableBackorders)) AS BackordersBalances
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
	|		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableBackorders.Company = BackordersBalances.Company
	|			AND TableBackorders.Products = BackordersBalances.Products
	|			AND TableBackorders.Characteristic = BackordersBalances.Characteristic
	|			AND TableBackorders.Order = BackordersBalances.SupplySource
	|WHERE
	|	BackordersBalances.SalesOrder IS NOT NULL 
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableInventory.Period,
	|	TemporaryTableInventory.Company,
	|	TemporaryTableInventory.SalesOrder,
	|	TemporaryTableInventory.Products,
	|	TemporaryTableInventory.Characteristic,
	|	TemporaryTableInventory.Order,
	|	TemporaryTableInventory.Quantity
	|FROM
	|	TemporaryTableReservation AS TemporaryTableInventory
	|WHERE
	|	NOT TemporaryTableInventory.SalesOrder IN (VALUE(Document.SalesOrder.EmptyRef), VALUE(Document.SalesOrder.EmptyRef), UNDEFINED)";
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountsPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	ExpectedPayments = NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", StructureAdditionalProperties.DefaultLanguageCode);
	AdvanceCredit = NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización del pago adelantado';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", StructureAdditionalProperties.DefaultLanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	
	Query.SetParameter("ExpectedPayments", ExpectedPayments);
	Query.SetParameter("AdvanceCredit", AdvanceCredit);
	Query.SetParameter("AppearenceOfLiabilityToVendor", 
		NStr("en = 'Accounts payable recognition'; ru = 'Возникновение обязательств перед комитентом';pl = 'Powstanie zobowiązań wobec dostawcy';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento di debiti';de = 'Aufnahme von Offenen Posten Kreditoren'", StructureAdditionalProperties.DefaultLanguageCode));
	Query.SetParameter("ExchangeDifference", 
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Period AS Date,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.GLAccountVendorSettlements AS GLAccount,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.Document AS Document,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.Amount
	|		END) AS AmountForPayment,
	|	SUM(CASE
	|			WHEN DocumentTable.SetPaymentTerms
	|				THEN 0
	|			ELSE DocumentTable.AmountCur
	|		END) AS AmountForPaymentCur
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
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.Order REFS Document.PurchaseOrder
	|				AND DocumentTable.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|				AND DocumentTable.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	VALUE(AccumulationRecordType.Receipt),
	|	Header.Date,
	|	Header.Company,
	|	Header.PresentationCurrency,
	|	Header.Counterparty,
	|	UNDEFINED,
	|	Header.Contract,
	|	Header.Ref,
	|	VALUE(Document.PurchaseOrder.EmptyRef),
	|	Header.Currency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	0,
	|	0,
	|	0,
	|	0,
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)),
	|	0,
	|	0
	|FROM
	|	SupplierInvoiceHeader AS Header
	|		LEFT JOIN TemporaryTableInventory AS TemporaryTableInventory
	|		ON Header.Ref = TemporaryTableInventory.Document
	|WHERE
	|	Header.ZeroInvoice
	|	AND TemporaryTableInventory.Products IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.GLAccountVendorSettlements,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur),
	|	CAST(&AppearenceOfLiabilityToVendor AS STRING(100)),
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.AmountCur
	|	END
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.Document,
	|	CASE
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.PurchaseOrder <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN DocumentTable.PurchaseOrder
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentTable.SetPaymentTerms
	|			THEN 0
	|		ELSE DocumentTable.AmountCur
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
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
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
	|	SUM(DocumentTable.Amount),
	|	SUM(DocumentTable.AmountCur)
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
	|	Calendar.AccountsPayableGLAccount,
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
	
	TableAccountsPayable = PaymentTermsServer.RecalculateAmountForExpectedPayments(
		StructureAdditionalProperties,
		ResultsArray[QueryNumber].Unload(),
		ExpectedPayments);
	
	If StructureAdditionalProperties.DocumentAttributes.IsZeroInvoice Then
	
		DriveServer.SetZeroInvoiceInTable(TableAccountsPayable);
	
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", TableAccountsPayable);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableIncomeAndExpensesRetained(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
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
	|	DocumentTable.Amount - DocumentTable.VATAmount AS AmountExpense
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND NOT DocumentTable.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	DocumentTable.LineNumber,
	|	DocumentTable.Period,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	&Ref,
	|	DocumentTable.BusinessLine,
	|	DocumentTable.Amount - DocumentTable.VATAmount
	|FROM
	|	TemporaryTableExpenses AS DocumentTable
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
	
	TableInventoryIncomeAndExpensesRetained = ResultsArray[0].Unload();
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
Procedure GenerateTableUnallocatedExpenses(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
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
Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
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

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTablePOSSummary(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefPurchaseInvoice);
	Query.SetParameter("PointInTime"          , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod"        , StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company"              , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency" , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod"	  , StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.SetParameter("RetailIncome",
		NStr("en = 'Receipt to retail'; ru = 'Поступление в розницу';pl = 'Przyjęcie do detalu';es_ES = 'Recibo para la venta al por menor';es_CO = 'Recibo para la venta al por menor';tr = 'Perakendeye gelen';it = 'Ricevimento per vendita al dettaglio';de = 'Eingang im Einzelhandel'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.Text =
	"SELECT
	|	DocumentTable.Period AS Date,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.RetailPriceKind AS RetailPriceKind,
	|	DocumentTable.Products AS Products,
	|	DocumentTable.Characteristic AS Characteristic,
	|	DocumentTable.StructuralUnit AS StructuralUnit,
	|	DocumentTable.PriceCurrency AS Currency,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.MarkupGLAccount AS MarkupGLAccount,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN CurrencyPriceExchangeRate.Repetition / CurrencyPriceExchangeRate.Rate
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyPriceExchangeRate.Rate / CurrencyPriceExchangeRate.Repetition
	|				ELSE 0
	|			END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS Amount,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountCur,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN CurrencyPriceExchangeRate.Repetition / CurrencyPriceExchangeRate.Rate
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CurrencyPriceExchangeRate.Rate / CurrencyPriceExchangeRate.Repetition
	|				ELSE 0
	|			END / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountForBalance,
	|	SUM(CAST(PricesSliceLast.Price * DocumentTable.Quantity / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1) AS NUMBER(15, 2))) AS AmountCurForBalance,
	|	SUM(DocumentTable.Amount + DocumentTable.AmountExpense) AS Cost,
	|	&RetailIncome AS ContentOfAccountingRecord
	|INTO TemporaryTablePOSSummary
	|FROM
	|	TemporaryTableInventory AS DocumentTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&PointInTime,
	|				(PriceKind, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.RetailPriceKind,
	|						TemporaryTableInventory.Products,
	|						TemporaryTableInventory.Characteristic
	|					FROM
	|						TemporaryTableInventory)) AS PricesSliceLast
	|		ON DocumentTable.Products = PricesSliceLast.Products
	|			AND DocumentTable.RetailPriceKind = PricesSliceLast.PriceKind
	|			AND DocumentTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, Company = &Company) AS CurrencyPriceExchangeRate
	|		ON DocumentTable.PriceCurrency = CurrencyPriceExchangeRate.Currency
	|WHERE
	|	DocumentTable.RetailTransferEarningAccounting
	|	AND NOT DocumentTable.ZeroInvoice
	|
	|GROUP BY
	|	DocumentTable.Period,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.RetailPriceKind,
	|	DocumentTable.Products,
	|	DocumentTable.Characteristic,
	|	DocumentTable.StructuralUnit,
	|	DocumentTable.PriceCurrency,
	|	DocumentTable.GLAccount,
	|	DocumentTable.MarkupGLAccount
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	StructuralUnit,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTablePOSSummary.Company AS Company,
	|	TemporaryTablePOSSummary.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTablePOSSummary.StructuralUnit AS StructuralUnit,
	|	TemporaryTablePOSSummary.Currency AS Currency
	|FROM
	|	TemporaryTablePOSSummary AS TemporaryTablePOSSummary";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.POSSummary");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesPOSSummary(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePOSSummary", ResultsArray[QueryNumber].Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableAccountingJournalEntries(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ISNULL(SUM(TemporaryTable.ReverseChargeVATAmount), 0) AS ReverseChargeVATInventory
	|FROM
	|	TemporaryTableInventory AS TemporaryTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(SUM(CASE
	|				WHEN NOT TemporaryTable.IncludeExpensesInCostPrice
	|					THEN TemporaryTable.ReverseChargeVATAmount
	|				ELSE 0
	|			END), 0) AS ReverseChargeVATExpenses
	|FROM
	|	TemporaryTableExpenses AS TemporaryTable";
	
	ResultArray = Query.ExecuteBatch();
	
	Selection = ResultArray[0].Select();
	Selection.Next();
	ReverseChargeVATInventory		= Selection.ReverseChargeVATInventory;
	
	Selection = ResultArray[1].Select();
	Selection.Next();
	ReverseChargeVATExpenses	= Selection.ReverseChargeVATExpenses;
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableAccountingJournalEntries.Period AS Period,
	|	TableAccountingJournalEntries.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAccountingJournalEntries.GLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.AmountExpenseCur - TableAccountingJournalEntries.VATAmountCur
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
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.AmountExpenseCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount + TableAccountingJournalEntries.AmountExpense - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	(NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|			OR TableAccountingJournalEntries.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|				AND NOT TableAccountingJournalEntries.ContinentalMethod)
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GoodsInvoicedNotDeliveredGLAccount,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.AmountCur + TableAccountingJournalEntries.AmountExpenseCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount + TableAccountingJournalEntries.AmountExpense - TableAccountingJournalEntries.VATAmount,
	|	&InventoryIncreaseGoodsInvoicedNotReceived,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.AdvanceInvoicing
	|	AND TableAccountingJournalEntries.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.ReverseChargeVATAmountCur
	|		ELSE 0
	|	END,
	|	&TaxPayable,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.ReverseChargeVATAmount,
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|	AND NOT &RegisteredForVAT
	|	AND NOT &RegisteredForSalesTax
	|	AND (NOT TableAccountingJournalEntries.AdvanceInvoicing
	|				AND TableAccountingJournalEntries.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|			OR TableAccountingJournalEntries.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|				AND NOT TableAccountingJournalEntries.ContinentalMethod)
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GoodsInvoicedNotDeliveredGLAccount,
	|	UNDEFINED,
	|	0,
	|	&TaxPayable,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.ReverseChargeVATAmount,
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|	AND NOT &RegisteredForVAT
	|	AND NOT &RegisteredForSalesTax
	|	AND TableAccountingJournalEntries.AdvanceInvoicing
	|	AND TableAccountingJournalEntries.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
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
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount,
	|	&OtherExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.ReverseChargeVATAmountCur
	|		ELSE 0
	|	END,
	|	&TaxPayable,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.ReverseChargeVATAmount,
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|	AND NOT &RegisteredForVAT
	|	AND NOT &RegisteredForSalesTax
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|UNION ALL
	|
	|SELECT
	|	7,
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
	|	8,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.GLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	TableAccountingJournalEntries.MarkupGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.MarkupGLAccount.Currency
	|			THEN TableAccountingJournalEntries.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.Cost,
	|	&Markup,
	|	FALSE
	|FROM
	|	TemporaryTablePOSSummary AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	9,
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
	|	&PreVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	10,
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
	|	&PreVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements
	|
	|UNION ALL
	|
	|SELECT
	|	11,
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
	|	&PreVATInventory,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	12,
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
	|	&PreVATExpenses,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|	AND TableAccountingJournalEntries.VATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccountVendorSettlements.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	13,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.ReverseChargeVATAmount),
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.VATOutputGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	14,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|				THEN TableAccountingJournalEntries.ReverseChargeVATAmount
	|			ELSE 0
	|		END),
	|	&ReverseChargeVAT,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.VATOutputGLAccount,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	15,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(TableAccountingJournalEntries.ReverseChargeVATAmount),
	|	&ReverseChargeVATReclaimed,
	|	FALSE
	|FROM
	|	TemporaryTableInventory AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company
	|
	|UNION ALL
	|
	|SELECT
	|	16,
	|	TableAccountingJournalEntries.Period,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	UNDEFINED,
	|	0,
	|	&GLAccountVATReverseCharge,
	|	UNDEFINED,
	|	0,
	|	SUM(CASE
	|			WHEN NOT TableAccountingJournalEntries.IncludeExpensesInCostPrice
	|				THEN TableAccountingJournalEntries.ReverseChargeVATAmount
	|			ELSE 0
	|		END),
	|	&ReverseChargeVATReclaimed,
	|	FALSE
	|FROM
	|	TemporaryTableExpenses AS TableAccountingJournalEntries
	|WHERE
	|	&RegisteredForVAT
	|	AND TableAccountingJournalEntries.ReverseChargeVATAmount > 0
	|	AND NOT TableAccountingJournalEntries.ZeroInvoice
	|
	|GROUP BY
	|	TableAccountingJournalEntries.VATInputGLAccount,
	|	TableAccountingJournalEntries.Company,
	|	TableAccountingJournalEntries.Period
	|
	|UNION ALL
	|
	|SELECT
	|	17,
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
	|	18,
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
	|	19,
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
	|	20,
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
	
	Query.SetParameter("PositiveExchangeDifferenceGLAccount",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchangeDifferenceAccountOfAccounting",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	
	Query.SetParameter("VATAdvancesToSuppliers",			Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",							Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("TaxPayable",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("TaxPayable"));
	Query.SetParameter("Date",								StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("Company",							StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PostVATEntriesBySourceDocuments",	StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("RegisteredForVAT",					StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("RegisteredForSalesTax",				StructureAdditionalProperties.AccountingPolicy.RegisteredForSalesTax);
	Query.SetParameter("Ref",								DocumentRefPurchaseInvoice);
	
	Query.SetParameter("InventoryIncrease",
		NStr("en = 'Inventory receipt'; ru = 'Прием запасов';pl = 'Przyjęcie zapasów';es_ES = 'Recibo del inventario';es_CO = 'Recibo del inventario';tr = 'Stok fişi';it = 'Ricevimento di scorte';de = 'Bestandszugang'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("InventoryIncreaseGoodsInvoicedNotReceived",
		NStr("en = 'Goods invoiced not received'; ru = 'Товары к получению';pl = 'Towary zafakturowane ""w drodze""';es_ES = 'Los productos facturados no recibidos';es_CO = 'Los productos facturados no recibidos';tr = 'Faturalanan ama teslim alınmayan mallar';it = 'Merci fatturate non ricevute';de = 'Fakturierte, aber nicht erhaltene Waren'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("OtherExpenses",
		NStr("en = 'Expenses incurred'; ru = 'Отражение затрат';pl = 'Poniesione rozchody';es_ES = 'Gastos incurridos';es_CO = 'Gastos incurridos';tr = 'Tahakkuk eden giderler';it = 'Spese sostenute';de = 'Anfallende Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("SetOffAdvancePayment",
		NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización de pagos anticipados';es_CO = 'Amortización de pagos anticipados';tr = 'Avans ödeme mahsuplaştırılması';it = 'Annullamento del pagamento anticipato';de = 'Verrechnung der Vorauszahlung'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PrepaymentReversal",
		NStr("en = 'Advance payment reversal'; ru = 'Сторнирование аванса';pl = 'Anulowanie zaliczki';es_ES = 'Inversión del pago anticipado';es_CO = 'Inversión del pago anticipado';tr = 'Avans ödeme iptali';it = 'Restituzione del pagamento anticipato';de = 'Stornierung der Vorauszahlung'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReversalOfReserves",
		NStr("en = 'Cost of goods sold reversal'; ru = 'Сторнирование себестоимости';pl = 'Koszt własny odwrócenia sprzedanych towarów';es_ES = 'Coste de la inversión de mercancías vendidas';es_CO = 'Coste de la inversión de mercancías vendidas';tr = 'Satılan malların maliyetinin geri dönmesi';it = 'Costo dei beni venduti inversione';de = 'Stornierung des Wareneinsatzes'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("Markup",
		NStr("en = 'Retail markup'; ru = 'Торговая наценка';pl = 'Marża detaliczna';es_ES = 'Marca de la venta al por menor';es_CO = 'Marca de la venta al por menor';tr = 'Perakende kâr marjı';it = 'Margine di vendita al dettaglio';de = 'Einzelhandels-Aufschlag'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVATInventory",
		NStr("en = 'VAT input on goods purchased'; ru = 'Входящий НДС по закупленным товарам';pl = 'VAT na zakupiony towar';es_ES = 'Entrada del IVA de las mercancías compradas';es_CO = 'Entrada del IVA de las mercancías compradas';tr = 'Satın alınan mallarda KDV girişi';it = 'IVA inserita sulla merce acquistata';de = 'USt.-Eingabe auf eingekaufte Waren'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVATExpenses",
		NStr("en = 'VAT input on expenses incurred'; ru = 'Входящий НДС по предъявленным расходам';pl = 'VAT od poniesionych rozchodów';es_ES = 'Entrada del IVA de los gastos incurridos';es_CO = 'Entrada del IVA de los gastos incurridos';tr = 'Yapılan giderlere ilişkin KDV girişi';it = 'IVA inserita sulle spese sostenute';de = 'USt.-Eingabe auf angefallenen Ausgaben'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVAT",
		NStr("en = 'VAT input'; ru = 'Входящий НДС';pl = 'VAT naliczony';es_ES = 'Entrada del IVA';es_CO = 'Entrada del IVA';tr = 'KDV girişi';it = 'IVA c\acquisti';de = 'USt.-Eingabe'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ContentVATRevenue",
		NStr("en = 'Advance VAT clearing'; ru = 'Зачет аванса';pl = 'Zaliczkowe rozliczenie podatku VAT';es_ES = 'Eliminación del IVA de anticipo';es_CO = 'Eliminación del IVA de anticipo';tr = 'Peşin KDV mahsuplaştırılması';it = 'Annullamento dell''anticipo IVA';de = 'USt. -Vorschussverrechnung'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'; ru = 'Реверсивный НДС';pl = 'Odwrotne obciążenie podatkiem VAT';es_ES = 'IVA de la inversión impositiva';es_CO = 'IVA de la inversión impositiva';tr = 'Sorumlu sıfatıyla KDV';it = 'Reverse charge IVA';de = 'Steuerschuldumkehr'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ReverseChargeVATReclaimed",
		NStr("en = 'Reverse charge VAT reclaimed'; ru = 'Реверсивный НДС отозван';pl = 'Odzyskana kwota podatku VAT';es_ES = 'Inversión impositiva IVA reclamado';es_CO = 'Inversión impositiva IVA reclamado';tr = 'Karşı ödemeli KDV iadesi';it = 'Reclamata l''inversione caricamento IVA';de = 'Steuerschuldumkehr zurückgewonnen'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	If Query.Parameters.RegisteredForVAT
		And ReverseChargeVATInventory + ReverseChargeVATExpenses > 0 Then
		Query.SetParameter("GLAccountVATReverseCharge", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATReverseCharge"));
	Else
		Query.SetParameter("GLAccountVATReverseCharge", Undefined);
	EndIf;
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT
		Or StructureAdditionalProperties.DocumentAttributes.Counterparty = Catalogs.Counterparties.RetailCustomer 
		Or StructureAdditionalProperties.DocumentAttributes.IsZeroInvoice Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	If NOT StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		QueryText = WorkWithVAT.GetVATPreparationQueryText() + 
		"SELECT
		|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
		|	TTVATPreparation.Document AS ShipmentDocument,
		|	TTVATPreparation.VATRate AS VATRate,
		|	TTVATPreparation.Period AS Period,
		|	TTVATPreparation.Company AS Company,
		|	TTVATPreparation.CompanyVATNumber AS CompanyVATNumber,
		|	TTVATPreparation.PresentationCurrency AS PresentationCurrency,
		|	TTVATPreparation.Counterparty AS Supplier,
		|	TTVATPreparation.VATInputGLAccount AS GLAccount,
		|	TTVATPreparation.VATAmount AS VATAmount,
		|	TTVATPreparation.AmountExcludesVAT AS AmountExcludesVAT
		|FROM
		|	TTVATPreparation AS TTVATPreparation";
	EndIf;
	
	If ValueIsFilled(QueryText) Then
		QueryText = QueryText + "
		|
		|UNION ALL
		|"
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
	|	&VATInput AS GLAccount,
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
	Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATInput(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.DocumentAttributes.Counterparty = Catalogs.Counterparties.RetailCustomer Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	
	If StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments
		And (StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		Or StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
		Or StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ForExport) Then
		
		QueryText = WorkWithVAT.GetVATPreparationQueryText() + 
		"SELECT
		|	TTVATPreparation.Document AS ShipmentDocument,
		|	TTVATPreparation.VATRate AS VATRate,
		|	TTVATPreparation.Period AS Period,
		|	TTVATPreparation.Company AS Company,
		|	TTVATPreparation.CompanyVATNumber AS CompanyVATNumber,
		|	TTVATPreparation.PresentationCurrency AS PresentationCurrency,
		|	TTVATPreparation.Counterparty AS Supplier,
		|	TTVATPreparation.VATInputGLAccount AS GLAccount,
		|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
		|	TTVATPreparation.ProductsType AS ProductType,
		|	TTVATPreparation.VATAmount AS VATAmount,
		|	TTVATPreparation.AmountExcludesVAT AS AmountExcludesVAT
		|FROM
		|	TTVATPreparation AS TTVATPreparation
		|
		|UNION ALL
		|
		|SELECT
		|	PrepaymentVAT.ShipmentDocument,
		|	PrepaymentVAT.VATRate,
		|	PrepaymentVAT.Period,
		|	PrepaymentVAT.Company,
		|	PrepaymentVAT.CompanyVATNumber AS CompanyVATNumber,
		|	PrepaymentVAT.PresentationCurrency,
		|	PrepaymentVAT.Customer,
		|	&VATInput,
		|	VALUE(Enum.VATOperationTypes.AdvanceCleared) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
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
		|	PrepaymentVAT.CompanyVATNumber AS CompanyVATNumber,
		|	PrepaymentVAT.PresentationCurrency,
		|	PrepaymentVAT.Customer,
		|	&VATInput,
		|	VALUE(Enum.VATOperationTypes.AdvanceCleared) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
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
		
	ElsIf StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		QueryText = QueryText + 
		"SELECT
		|	UnionTable.Document AS ShipmentDocument,
		|	UnionTable.VATRate AS VATRate,
		|	UnionTable.Period AS Period,
		|	UnionTable.Company AS Company,
		|	UnionTable.CompanyVATNumber AS CompanyVATNumber,
		|	UnionTable.PresentationCurrency AS PresentationCurrency,
		|	UnionTable.Company AS Supplier,
		|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
		|	UnionTable.ProductsType AS ProductType,
		|	UnionTable.VATInputGLAccount AS GLAccount,
		|	SUM(UnionTable.VATAmount) AS VATAmount,
		|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.ReverseChargeVATRate AS VATRate,
		|		TemporaryTableInventory.ReverseChargeVATAmount AS VATAmount,
		|		TemporaryTableInventory.Amount + TemporaryTableInventory.AmountExpense AS AmountExcludesVAT,
		|		TemporaryTableInventory.Document AS Document,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.ProductsType AS ProductsType,
		|		TemporaryTableInventory.Company AS Company,
		|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
		|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTableInventory.VATInputGLAccount
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|	WHERE
		|		NOT TemporaryTableInventory.ZeroInvoice
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.ReverseChargeVATRate,
		|		TemporaryTableExpenses.ReverseChargeVATAmount,
		|		TemporaryTableExpenses.Amount,
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.ProductsType,
		|		TemporaryTableExpenses.Company,
		|		TemporaryTableExpenses.CompanyVATNumber,
		|		TemporaryTableExpenses.PresentationCurrency,
		|		TemporaryTableExpenses.VATInputGLAccount
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|	WHERE
		|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
		|
		|GROUP BY
		|	UnionTable.VATRate,
		|	UnionTable.ProductsType,
		|	UnionTable.Document,
		|	UnionTable.Period,
		|	UnionTable.Company,
		|	UnionTable.CompanyVATNumber,
		|	UnionTable.PresentationCurrency,
		|	UnionTable.Company,
		|	UnionTable.VATInputGLAccount";
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = "";
	If StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		QueryText = QueryText + 
		"SELECT
		|	UnionTable.Document AS ShipmentDocument,
		|	UnionTable.VATRate AS VATRate,
		|	UnionTable.Period AS Period,
		|	UnionTable.Company AS Company,
		|	UnionTable.CompanyVATNumber AS CompanyVATNumber,
		|	UnionTable.PresentationCurrency AS PresentationCurrency,
		|	UnionTable.Company AS Customer,
		|	VALUE(Enum.VATOperationTypes.ReverseChargeApplied) AS OperationType,
		|	UnionTable.ProductsType AS ProductType,
		|	UnionTable.VATOutputGLAccount AS GLAccount,
		|	SUM(UnionTable.VATAmount) AS VATAmount,
		|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
		|FROM
		|	(SELECT
		|		TemporaryTableInventory.ReverseChargeVATRate AS VATRate,
		|		TemporaryTableInventory.ReverseChargeVATAmount AS VATAmount,
		|		TemporaryTableInventory.Amount + TemporaryTableInventory.AmountExpense AS AmountExcludesVAT,
		|		TemporaryTableInventory.Document AS Document,
		|		TemporaryTableInventory.Period AS Period,
		|		TemporaryTableInventory.ProductsType AS ProductsType,
		|		TemporaryTableInventory.Company AS Company,
		|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
		|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTableInventory.VATOutputGLAccount
		|	FROM
		|		TemporaryTableInventory AS TemporaryTableInventory
		|	WHERE
		|		NOT TemporaryTableInventory.ZeroInvoice
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TemporaryTableExpenses.ReverseChargeVATRate,
		|		TemporaryTableExpenses.ReverseChargeVATAmount,
		|		TemporaryTableExpenses.Amount,
		|		TemporaryTableExpenses.Document,
		|		TemporaryTableExpenses.Period,
		|		TemporaryTableExpenses.ProductsType,
		|		TemporaryTableExpenses.Company,
		|		TemporaryTableExpenses.CompanyVATNumber,
		|		TemporaryTableExpenses.PresentationCurrency,
		|		TemporaryTableExpenses.VATOutputGLAccount
		|	FROM
		|		TemporaryTableExpenses AS TemporaryTableExpenses
		|	WHERE
		|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
		|
		|GROUP BY
		|	UnionTable.VATRate,
		|	UnionTable.Document,
		|	UnionTable.Period,
		|	UnionTable.ProductsType,
		|	UnionTable.Company,
		|	UnionTable.CompanyVATNumber,
		|	UnionTable.PresentationCurrency,
		|	UnionTable.Company,
		|	UnionTable.VATOutputGLAccount";
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		Return;
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableTaxPayable(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		Or StructureAdditionalProperties.AccountingPolicy.RegisteredForSalesTax
		Or Not StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", New ValueTable);
		Return;
		
	EndIf;
	
	QueryText = 
	"SELECT
	|	UnionTable.Period AS Period,
	|	UnionTable.Company AS Company,
	|	UnionTable.CompanyVATNumber AS CompanyVATNumber,
	|	UnionTable.PresentationCurrency AS PresentationCurrency,
	|	VALUE(Catalog.TaxTypes.VAT) AS TaxKind,
	|	SUM(UnionTable.ReverseChargeVATAmount) AS Amount,
	|	&ReverseChargeVAT AS ContentOfAccountingRecord
	|FROM
	|	(SELECT
	|		TemporaryTableInventory.Period AS Period,
	|		TemporaryTableInventory.Company AS Company,
	|		TemporaryTableInventory.CompanyVATNumber AS CompanyVATNumber,
	|		TemporaryTableInventory.PresentationCurrency AS PresentationCurrency,
	|		TemporaryTableInventory.ReverseChargeVATAmount AS ReverseChargeVATAmount
	|	FROM
	|		TemporaryTableInventory AS TemporaryTableInventory
	|	WHERE
	|		NOT TemporaryTableInventory.ZeroInvoice
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TemporaryTableExpenses.Period,
	|		TemporaryTableExpenses.Company,
	|		TemporaryTableExpenses.CompanyVATNumber,
	|		TemporaryTableExpenses.PresentationCurrency,
	|		TemporaryTableExpenses.ReverseChargeVATAmount
	|	FROM
	|		TemporaryTableExpenses AS TemporaryTableExpenses
	|	WHERE
	|		NOT TemporaryTableExpenses.IncludeExpensesInCostPrice) AS UnionTable
	|
	|GROUP BY
	|	UnionTable.Period,
	|	UnionTable.Company,
	|	UnionTable.CompanyVATNumber,
	|	UnionTable.PresentationCurrency";
	
	Query = New Query(QueryText);
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("ReverseChargeVAT",
		NStr("en = 'Reverse charge VAT'; ru = 'Реверсивный НДС';pl = 'Odwrotne obciążenie VAT';es_ES = 'IVA de la inversión impositiva';es_CO = 'IVA de la inversión impositiva';tr = 'Sorumlu sıfatıyla KDV';it = 'Reverse charge IVA';de = 'Steuerschuldumkehr'",
			StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableTaxPayable", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoiced(DocumentRef, StructureAdditionalProperties)
	If StructureAdditionalProperties.AccountingPolicy.ContinentalMethod Then
		GenerateTableGoodsReceivedNotInvoicedContinentalMethod(DocumentRef, StructureAdditionalProperties);
	Else
		GenerateTableGoodsReceivedNotInvoicedAngloSaxonMethod(DocumentRef, StructureAdditionalProperties);
	EndIf;
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoicedContinentalMethod(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
#Region GenerateTableGoodsReceivedNotInvoicedContinentalMethodQueryText
	
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	TableProducts.GoodsReceipt AS GoodsReceipt,
	|	TableProducts.Company AS Company,
	|	TableProducts.CompanyVATNumber AS CompanyVATNumber,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.SettlementsCurrency AS SettlementsCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	CASE
	|		WHEN TableProducts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableProducts.Order
	|	END AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.VATTaxation AS VATTaxation,
	|	TableProducts.VATRate AS VATRate,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	SUM(TableProducts.Amount - TableProducts.VATAmount + TableProducts.AmountExpense) AS Amount,
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableProducts.Specification AS Specification,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	TableProducts.BusinessLineSales AS BusinessLine,
	|	TableProducts.GoodsReceivedNotInvoicedGLAccount AS AccountDr,
	|	TableProducts.GLAccountVendorSettlements AS AccountCr,
	|	CASE
	|		WHEN TableProducts.GLAccountVendorSettlements.Currency
	|			THEN TableProducts.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	SUM(CASE
	|			WHEN TableProducts.GLAccountVendorSettlements.Currency
	|				THEN TableProducts.AmountCur + TableProducts.AmountExpenseCur - TableProducts.VATAmountCur
	|			ELSE 0
	|		END) AS AmountCurCr
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND TableProducts.Quantity > 0
	|	AND NOT TableProducts.ZeroInvoice
	|
	|GROUP BY
	|	TableProducts.GoodsReceipt,
	|	TableProducts.Company,
	|	TableProducts.CompanyVATNumber,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.SettlementsCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.VATTaxation,
	|	TableProducts.VATRate,
	|	TableProducts.Period,
	|	TableProducts.Specification,
	|	TableProducts.StructuralUnit,
	|	TableProducts.BusinessLineSales,
	|	TableProducts.GoodsReceivedNotInvoicedGLAccount,
	|	TableProducts.GLAccountVendorSettlements,
	|	CASE
	|		WHEN TableProducts.GLAccountVendorSettlements.Currency
	|			THEN TableProducts.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	TableProducts = QueryResult.Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsReceivedNotInvoiced");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	StructureForSearch = New Structure;
	
	MetaRegisterDimensions = Metadata.AccumulationRegisters.GoodsReceivedNotInvoiced.Dimensions;
	For Each ColumnQueryResult In QueryResult.Columns Do
		If MetaRegisterDimensions.Find(ColumnQueryResult.Name) <> Undefined
			And ValueIsFilled(ColumnQueryResult.ValueType) Then
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
			StructureForSearch.Insert(ColumnQueryResult.Name);
		EndIf;
	EndDo;
	Block.Lock();
	
#Region GenerateTableGoodsReceivedNotInvoicedContinentalMethodBalancesQueryText
	
	Query.Text =
	"SELECT
	|	UNDEFINED AS Period,
	|	UNDEFINED AS RecordType,
	|	Balances.GoodsReceipt AS GoodsReceipt,
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.PurchaseOrder AS PurchaseOrder,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	SUM(Balances.Quantity) AS Quantity,
	|	SUM(Balances.Amount) AS Amount,
	|	SUM(Balances.Quantity) = SUM(Balances.ProductsQuantity) AS GoesToZero
	|FROM
	|	(SELECT
	|		Balances.GoodsReceipt AS GoodsReceipt,
	|		Balances.Company AS Company,
	|		Balances.PresentationCurrency AS PresentationCurrency,
	|		Balances.Counterparty AS Counterparty,
	|		Balances.Contract AS Contract,
	|		Balances.PurchaseOrder AS PurchaseOrder,
	|		Balances.Products AS Products,
	|		Balances.Characteristic AS Characteristic,
	|		Balances.Batch AS Batch,
	|		Balances.QuantityBalance AS Quantity,
	|		Balances.AmountBalance AS Amount,
	|		0 AS ProductsQuantity
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|				&ControlTime,
	|				(GoodsReceipt, PresentationCurrency, Company, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TableProducts.GoodsReceipt AS GoodsReceipt,
	|						TableProducts.PresentationCurrency AS PresentationCurrency,
	|						TableProducts.Company AS Company,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						CASE
	|							WHEN TableProducts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableProducts.Order
	|						END AS PurchaseOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch
	|					FROM
	|						TemporaryTableInventory AS TableProducts)) AS Balances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRecords.GoodsReceipt,
	|		DocumentRecords.Company,
	|		DocumentRecords.PresentationCurrency,
	|		DocumentRecords.Counterparty,
	|		DocumentRecords.Contract,
	|		DocumentRecords.PurchaseOrder,
	|		DocumentRecords.Products,
	|		DocumentRecords.Characteristic,
	|		DocumentRecords.Batch,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Quantity
	|			ELSE -DocumentRecords.Quantity
	|		END,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Amount
	|			ELSE -DocumentRecords.Amount
	|		END,
	|		0
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced AS DocumentRecords
	|	WHERE
	|		DocumentRecords.Recorder = &Ref
	|		AND DocumentRecords.Period <= &ControlPeriod
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableProducts.GoodsReceipt,
	|		TableProducts.Company,
	|		TableProducts.PresentationCurrency,
	|		TableProducts.Counterparty,
	|		TableProducts.Contract,
	|		CASE
	|			WHEN VALUE(Document.PurchaseOrder.EmptyRef)
	|				THEN TableProducts.Order = UNDEFINED
	|			ELSE TableProducts.Order
	|		END,
	|		TableProducts.Products,
	|		TableProducts.Characteristic,
	|		TableProducts.Batch,
	|		0,
	|		0,
	|		TableProducts.Quantity
	|	FROM
	|		TemporaryTableInventory AS TableProducts) AS Balances
	|
	|GROUP BY
	|	Balances.GoodsReceipt,
	|	Balances.Company,
	|	Balances.PresentationCurrency,
	|	Balances.Counterparty,
	|	Balances.Contract,
	|	Balances.PurchaseOrder,
	|	Balances.Products,
	|	Balances.Characteristic,
	|	Balances.Batch";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add("GoodsReceipt, PresentationCurrency, Company, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch");
	
	TemporaryTableProducts = TableBalances.CopyColumns();
	
	TablesForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
	UseTemplateBasedTypesOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting;
	
	TableAccountingJournalEntries = TablesForRegisterRecords.TableAccountingJournalEntries;
	
	If UseTemplateBasedTypesOfAccounting Then
		
		TableAccountingEntriesData = ?(TablesForRegisterRecords.Property("TableAccountingEntriesData"),
			TablesForRegisterRecords.TableAccountingEntriesData, 
			InformationRegisters.AccountingEntriesData.EmptyTableAccountingEntriesData());
		
	EndIf;
	
	InventoryContent = NStr("en = 'Inventory invoiced'; ru = 'Отраженные запасы';pl = 'Zafakturowane zapasy';es_ES = 'Inventario facturado';es_CO = 'Inventario facturado';tr = 'Stok faturalandırıldı';it = 'Scorte fatturate';de = 'In Rechnung gestellter Bestand'");
	OtherExpensesItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("PurchaseCostDiscrepancies");
	DiscrepancyGLAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PurchaseCostDiscrepancies");
	DiscrepancyContent = NStr("en = 'Purchase cost discrepancies'; ru = 'Отклонения в закупочной стоимости';pl = 'Rozbieżności w kosztach zakupu';es_ES = 'Discrepancias del coste de compra';es_CO = 'Discrepancias del coste de compra';tr = 'Satın alma maliyeti uyuşmazlıkları';it = 'Discrepanza dei prezzi di acquisto';de = 'Diskrepanzen bei den Anschaffungskosten'");
	
	If TablesForRegisterRecords.Property("TableIncomeAndExpenses") Then
		TableIncomeAndExpenses = TablesForRegisterRecords.TableIncomeAndExpenses;
	Else
		IncomeAndExpensesEmptyRecordSet = AccumulationRegisters.IncomeAndExpenses.CreateRecordSet();
		TableIncomeAndExpenses = IncomeAndExpensesEmptyRecordSet.UnloadColumns();
	EndIf;
	
	For Each TableProductsRow In TableProducts Do
		
		FillPropertyValues(StructureForSearch, TableProductsRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableProductsRow.Quantity;
		
		For Each TableBalancesRow In BalanceRowsArray Do
			
			If TableBalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableProducts.Add();
				FillPropertyValues(NewRow, TableBalancesRow, , "Quantity, Amount");
				FillPropertyValues(NewRow, TableProductsRow, "Period, RecordType");
				
				NewRow.Quantity = Min(TableBalancesRow.Quantity, QuantityToBeWrittenOff);
				
				If NewRow.Quantity < TableBalancesRow.Quantity Then
					If TableBalancesRow.GoesToZero Then
						NewRow.Amount = Round(TableBalancesRow.Amount * NewRow.Quantity / TableBalancesRow.Quantity, 2, 1);
					EndIf;
					QuantityToBeWrittenOff = 0;
				Else
					If TableBalancesRow.GoesToZero Then
						NewRow.Amount = TableBalancesRow.Amount;
					EndIf;
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
				EndIf;
				If Not TableBalancesRow.GoesToZero Then
					NewRow.Amount = TableProductsRow.Amount;
				EndIf;
				
				If UseDefaultTypeOfAccounting Then
					
					TableAccountingRow = TableAccountingJournalEntries.Add();
					FillPropertyValues(TableAccountingRow, TableProductsRow);
					TableAccountingRow.Content = InventoryContent;
					
				EndIf;
				
				If TableBalancesRow.GoesToZero And NewRow.Amount > TableProductsRow.Amount Then
					
					AmountDiff = NewRow.Amount - TableProductsRow.Amount;
					
					If UseDefaultTypeOfAccounting Then
						
						TableAccountingRow.Amount = TableProductsRow.Amount;
						
						TableAccountingRow = TableAccountingJournalEntries.Add();
						FillPropertyValues(TableAccountingRow, TableProductsRow);
						TableAccountingRow.Amount = AmountDiff;
						TableAccountingRow.AccountCr = DiscrepancyGLAccount;
						TableAccountingRow.CurrencyCr = Undefined;
						TableAccountingRow.AmountCurCr = 0;
						TableAccountingRow.Content = DiscrepancyContent;
						
					EndIf;
					
					If UseTemplateBasedTypesOfAccounting Then
						
						TableAccountingEntriesRow = TableAccountingEntriesData.Add();
						FillPropertyValues(TableAccountingEntriesRow, TableProductsRow);
						
						TableAccountingEntriesRow.Recorder = DocumentRef;
						TableAccountingEntriesRow.RowNumber = TableProductsRow.LineNumber;
						TableAccountingEntriesRow.EntryType = Enums.EntryTypes.GoodsReceivedNotInvoicedDiscrepancyCost;
						TableAccountingEntriesRow.Product = TableProductsRow.Products;
						TableAccountingEntriesRow.SettlementCurrency = TableProductsRow.SettlementsCurrency;
						TableAccountingEntriesRow.Warehouse = TableProductsRow.StructuralUnit;
						TableAccountingEntriesRow.VATID = TableProductsRow.CompanyVATNumber;
						TableAccountingEntriesRow.TaxCategory = TableProductsRow.VATTaxation;
						TableAccountingEntriesRow.TaxRate = TableProductsRow.VATRate;
						TableAccountingEntriesRow.Amount = AmountDiff;
						
					EndIf;
					
					IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
					FillPropertyValues(IncomeAndExpensesRow, TableProductsRow);
					IncomeAndExpensesRow.Active = True;
					IncomeAndExpensesRow.IncomeAndExpenseItem = OtherExpensesItem;
					IncomeAndExpensesRow.GLAccount = DiscrepancyGLAccount;
					IncomeAndExpensesRow.AmountIncome = AmountDiff;
					IncomeAndExpensesRow.ContentOfAccountingRecord = DiscrepancyContent;
					
				ElsIf TableBalancesRow.GoesToZero And NewRow.Amount < TableProductsRow.Amount Then
					
					AmountDiff = TableProductsRow.Amount - NewRow.Amount;
					
					If UseDefaultTypeOfAccounting Then
						
						TableAccountingRow.Amount = NewRow.Amount;
						TableAccountingRow.AmountCurCr = 
							Round(TableProductsRow.AmountCurCr * NewRow.Amount / TableProductsRow.Amount, 2, 1);
						NextAccountingRowAmountCr = TableProductsRow.AmountCurCr - TableAccountingRow.AmountCurCr;
						
						TableAccountingRow = TableAccountingJournalEntries.Add();
						FillPropertyValues(TableAccountingRow, TableProductsRow);
						TableAccountingRow.Amount = AmountDiff;
						TableAccountingRow.AmountCurCr = NextAccountingRowAmountCr;
						TableAccountingRow.AccountDr = DiscrepancyGLAccount;
						TableAccountingRow.Content = DiscrepancyContent;
						
					EndIf;
					
					If UseTemplateBasedTypesOfAccounting Then
						
						TableAccountingEntriesRow = TableAccountingEntriesData.Add();
						FillPropertyValues(TableAccountingEntriesRow, TableProductsRow);
						
						TableAccountingEntriesRow.Recorder = DocumentRef;
						TableAccountingEntriesRow.RowNumber = TableProductsRow.LineNumber;
						TableAccountingEntriesRow.EntryType = Enums.EntryTypes.DiscrepancyCostAccountsPayable;
						TableAccountingEntriesRow.Product = TableProductsRow.Products;
						TableAccountingEntriesRow.SettlementCurrency = TableProductsRow.SettlementsCurrency;
						TableAccountingEntriesRow.Warehouse = TableProductsRow.StructuralUnit;
						TableAccountingEntriesRow.VATID = TableProductsRow.CompanyVATNumber;
						TableAccountingEntriesRow.TaxCategory = TableProductsRow.VATTaxation;
						TableAccountingEntriesRow.TaxRate = TableProductsRow.VATRate;
						TableAccountingEntriesRow.Amount = AmountDiff;
						
					EndIf;
					
					IncomeAndExpensesRow = TableIncomeAndExpenses.Add();
					FillPropertyValues(IncomeAndExpensesRow, TableProductsRow);
					IncomeAndExpensesRow.Active = True;
					IncomeAndExpensesRow.IncomeAndExpenseItem = OtherExpensesItem;
					IncomeAndExpensesRow.GLAccount = DiscrepancyGLAccount;
					IncomeAndExpensesRow.AmountExpense = AmountDiff;
					IncomeAndExpensesRow.ContentOfAccountingRecord = DiscrepancyContent;
					
				ElsIf UseDefaultTypeOfAccounting Then
					
					TableAccountingRow.Amount = NewRow.Amount;
					
				EndIf;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			
			NewRow = TemporaryTableProducts.Add();
			FillPropertyValues(NewRow, TableProductsRow, , "Quantity");
			NewRow.Quantity = QuantityToBeWrittenOff;
			
		EndIf;
		
	EndDo;
	
	TablesForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", TemporaryTableProducts);
	TablesForRegisterRecords.Insert("TableIncomeAndExpenses", TableIncomeAndExpenses);
	
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoicedAngloSaxonMethod(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
#Region GenerateTableGoodsReceivedNotInvoicedAngloSaxonMethodQueryText
	Query.Text =
	"SELECT
	|	TableInventory.GoodsReceipt AS GoodsReceipt,
	|	TableInventory.Company AS Company,
	|	TableInventory.PresentationCurrency AS PresentationCurrency,
	|	TableInventory.Counterparty AS Counterparty,
	|	TableInventory.Contract AS Contract,
	|	CASE
	|		WHEN TableInventory.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TableInventory.Order
	|	END AS PurchaseOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.CostObject AS CostObject,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense + TableInventory.ReverseChargeVATAmountForNotRegistered) AS Amount,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Period AS Period,
	|	TableInventory.CorrOrganization AS CorrOrganization,
	|	TableInventory.CorrPresentationCurrency AS CorrPresentationCurrency,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitCorr AS StructuralUnitCorr,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.OwnershipCorr AS OwnershipCorr,
	|	TableInventory.VATRate AS VATRate,
	|	VALUE(Catalog.Employees.EmptyRef) AS Responsible,
	|	FALSE AS Return,
	|	TableInventory.GoodsReceipt AS SourceDocument,
	|	UNDEFINED AS SalesOrder,
	|	UNDEFINED AS CorrSalesOrder,
	|	VALUE(Catalog.BusinessUnits.EmptyRef) AS Department,
	|	TableInventory.Order AS SupplySource,
	|	UNDEFINED AS CustomerCorrOrder,
	|	TableInventory.FixedCost AS FixedCost,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord,
	|	TableInventory.InventoryAccountType AS InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	NOT TableInventory.RetailTransferEarningAccounting
	|	AND TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|	AND NOT TableInventory.ZeroInvoice
	|
	|GROUP BY
	|	TableInventory.GoodsReceipt,
	|	TableInventory.Company,
	|	TableInventory.PresentationCurrency,
	|	TableInventory.Counterparty,
	|	TableInventory.Contract,
	|	TableInventory.Order,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ownership,
	|	TableInventory.CostObject,
	|	TableInventory.RecordType,
	|	TableInventory.Period,
	|	TableInventory.CorrOrganization,
	|	TableInventory.CorrPresentationCurrency,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitCorr,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Specification,
	|	TableInventory.ProductsCorr,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.BatchCorr,
	|	TableInventory.OwnershipCorr,
	|	TableInventory.VATRate,
	|	TableInventory.FixedCost,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.GoodsReceipt,
	|	TableInventory.InventoryAccountType,
	|	TableInventory.CorrInventoryAccountType";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	TableProducts = QueryResult.Unload();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsReceivedNotInvoiced");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	StructureForSearch = New Structure;
	
	MetaRegisterDimensions = Metadata.AccumulationRegisters.GoodsReceivedNotInvoiced.Dimensions;
	For Each ColumnQueryResult In QueryResult.Columns Do
		If MetaRegisterDimensions.Find(ColumnQueryResult.Name) <> Undefined
			And ValueIsFilled(ColumnQueryResult.ValueType) Then
			LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
			StructureForSearch.Insert(ColumnQueryResult.Name);
		EndIf;
	EndDo;
	Block.Lock();
	
#Region GenerateTableGoodsReceivedNotInvoicedAngloSaxonMethodBalancesQueryText
	
	Query.Text =
	"SELECT
	|	UNDEFINED AS Period,
	|	UNDEFINED AS RecordType,
	|	Balances.GoodsReceipt AS GoodsReceipt,
	|	Balances.Company AS Company,
	|	Balances.PresentationCurrency AS PresentationCurrency,
	|	Balances.Counterparty AS Counterparty,
	|	Balances.Contract AS Contract,
	|	Balances.PurchaseOrder AS PurchaseOrder,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	Balances.SalesOrder AS SalesOrder,
	|	SUM(Balances.Quantity) AS Quantity,
	|	0 AS Amount
	|FROM
	|	(SELECT
	|		Balances.GoodsReceipt AS GoodsReceipt,
	|		Balances.Company AS Company,
	|		Balances.PresentationCurrency AS PresentationCurrency,
	|		Balances.Counterparty AS Counterparty,
	|		Balances.Contract AS Contract,
	|		Balances.PurchaseOrder AS PurchaseOrder,
	|		Balances.Products AS Products,
	|		Balances.Characteristic AS Characteristic,
	|		Balances.Batch AS Batch,
	|		Balances.SalesOrder AS SalesOrder,
	|		Balances.QuantityBalance AS Quantity
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|				&ControlTime,
	|				(GoodsReceipt, Company, PresentationCurrency, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch) IN
	|					(SELECT
	|						TableProducts.GoodsReceipt AS GoodsReceipt,
	|						TableProducts.Company AS Company,
	|						TableProducts.PresentationCurrency AS PresentationCurrency,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						CASE
	|							WHEN TableProducts.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableProducts.Order
	|						END AS PurchaseOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch
	|					FROM
	|						TemporaryTableInventory AS TableProducts)) AS Balances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRecords.GoodsReceipt,
	|		DocumentRecords.Company,
	|		DocumentRecords.PresentationCurrency,
	|		DocumentRecords.Counterparty,
	|		DocumentRecords.Contract,
	|		DocumentRecords.PurchaseOrder,
	|		DocumentRecords.Products,
	|		DocumentRecords.Characteristic,
	|		DocumentRecords.Batch,
	|		DocumentRecords.SalesOrder,
	|		CASE
	|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRecords.Quantity
	|			ELSE -DocumentRecords.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced AS DocumentRecords
	|	WHERE
	|		DocumentRecords.Recorder = &Ref
	|		AND DocumentRecords.Period <= &ControlPeriod) AS Balances
	|
	|GROUP BY
	|	Balances.GoodsReceipt,
	|	Balances.Company,
	|	Balances.PresentationCurrency,
	|	Balances.Counterparty,
	|	Balances.Contract,
	|	Balances.PurchaseOrder,
	|	Balances.Products,
	|	Balances.Characteristic,
	|	Balances.Batch,
	|	Balances.SalesOrder";
	
#EndRegion
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add("GoodsReceipt, PresentationCurrency, Company, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch");
	
	TemporaryTableProducts = TableBalances.CopyColumns();
	
	TablesForRegisterRecords = StructureAdditionalProperties.TableForRegisterRecords;
	
	TableInventory = TablesForRegisterRecords.TableInventory;
	
	For Each TableProductsRow In TableProducts Do
		
		FillPropertyValues(StructureForSearch, TableProductsRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableProductsRow.Quantity;
		AmountToBeWrittenOff = TableProductsRow.Amount;
		
		For Each TableBalancesRow In BalanceRowsArray Do
			
			If TableBalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableProducts.Add();
				FillPropertyValues(NewRow, TableBalancesRow, , "Quantity, Amount");
				FillPropertyValues(NewRow, TableProductsRow, "Period, RecordType");
				
				NewRow.Quantity = Min(TableBalancesRow.Quantity, QuantityToBeWrittenOff);
				
				If NewRow.Quantity < TableBalancesRow.Quantity Then
					NewRow.Amount = AmountToBeWrittenOff;
					QuantityToBeWrittenOff = 0;
					AmountToBeWrittenOff = 0;
					TableBalancesRow.Quantity = TableBalancesRow.Quantity - NewRow.Quantity;
				Else
					NewRow.Amount = Round(AmountToBeWrittenOff * NewRow.Quantity / QuantityToBeWrittenOff, 2, 1);
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
					AmountToBeWrittenOff = AmountToBeWrittenOff - NewRow.Amount;
					TableBalancesRow.Quantity = 0;
				EndIf;
				
				TableInventoryRow = TableInventory.Add();
				FillPropertyValues(TableInventoryRow, TableProductsRow);
				TableInventoryRow.RecordType = AccumulationRecordType.Receipt;
				TableInventoryRow.SalesOrder = TableBalancesRow.SalesOrder;
				TableInventoryRow.Quantity = 0;
				TableInventoryRow.QuantityForCostLayer = NewRow.Quantity;
				TableInventoryRow.Amount = NewRow.Amount;
				
				NewRow.Amount = 0;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			
			NewRow = TemporaryTableProducts.Add();
			FillPropertyValues(NewRow, TableProductsRow, , "Quantity, Amount");
			NewRow.Quantity = QuantityToBeWrittenOff;
			NewRow.Amount = 0;
			
		EndIf;
		
	EndDo;
	
	TablesForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", TemporaryTableProducts);
	
EndProcedure

Procedure GenerateTableGoodsInvoicedNotReceived(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProducts.Period AS Period,
	|	TableProducts.Document AS SupplierInvoice,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.VATRate AS VATRate,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	SUM(TableProducts.Amount - TableProducts.VATAmount + TableProducts.AmountExpense + TableProducts.ReverseChargeVATAmountForNotRegistered) AS Amount,
	|	SUM(TableProducts.VATAmount) AS VATAmount
	|FROM
	|	TemporaryTableInventory AS TableProducts
	|WHERE
	|	TableProducts.AdvanceInvoicing
	|	AND TableProducts.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|GROUP BY
	|	TableProducts.Period,
	|	TableProducts.Document,
	|	TableProducts.Company,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Contract,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsInvoicedNotReceived", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableMaterials.Period AS Period,
	|	TemporaryTableMaterials.Company AS Company,
	|	TemporaryTableMaterials.Products AS Products,
	|	TemporaryTableMaterials.Characteristic AS Characteristic,
	|	TemporaryTableMaterials.Batch AS Batch,
	|	TemporaryTableMaterials.Counterparty AS Counterparty,
	|	TemporaryTableMaterials.Quantity AS Quantity
	|FROM
	|	TemporaryTableMaterials AS TemporaryTableMaterials";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRefPurchaseInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	VALUE(Enum.EntryTypes.InventoryAccountsPayable) AS EntryType,
	|	TableInventory.LineNumber AS LineNumber,
	|	TableHeader.Date AS Period,
	|	TableHeader.Company AS Company,
	|	TableHeader.PresentationCurrency AS PresentationCurrency,
	|	TableHeader.CompanyVATNumber AS VATID,
	|	TableHeader.VATTaxation AS TaxCategory,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATRate
	|		ELSE TableInventory.VATRate
	|	END AS TaxRate,
	|	"""" AS IncomeAndExpenseItem,
	|	UNDEFINED AS Department,
	|	TableInventory.Products AS Product,
	|	TableInventory.Characteristic AS Variant,
	|	TableInventory.Batch AS Batch,
	|	TableHeader.StructuralUnit AS Warehouse,
	|	TableInventory.Ownership AS Ownership,
	|	TableInventory.Project AS Project,
	|	TableInventory.Order AS Order,
	|	TableHeader.Counterparty AS Counterparty,
	|	TableHeader.Contract AS Contract,
	|	TableHeader.SettlementsCurrency AS SettlementCurrency,
	|	VALUE(catalog.Counterparties.EmptyRef) AS CorrCounterparty,
	|	VALUE(catalog.CounterpartyContracts.EmptyRef) AS CorrContract,
	|	UNDEFINED AS AdvanceDocument,
	|	TableInventory.Quantity AS Quantity,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.Amount + TableInventory.AmountExpense
	|		ELSE TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense
	|	END AS Amount,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.AmountCur + TableInventory.AmountExpenseCur
	|		ELSE TableInventory.AmountCur - TableInventory.VATAmountCur + TableInventory.AmountExpenseCur
	|	END AS SettlementsAmount,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmount
	|		ELSE TableInventory.VATAmount
	|	END AS Tax,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmountCur
	|		ELSE TableInventory.VATAmountCur
	|	END AS SettlementsTax,
	|	TableHeader.BasisDocument.Date AS SourceDocumentDate,
	|	UNDEFINED AS DeliveryPeriodStart,
	|	UNDEFINED AS DeliveryPeriodEnd,
	|	TableHeader.Ref AS Recorder
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableInventory.Document = TableHeader.Ref
	|WHERE
	|	NOT TableHeader.AdvanceInvoicing
	|	AND (TableHeader.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.AngloSaxon)
	|			OR TableHeader.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental)
	|				AND TableInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.GoodsInvoicedNotReceivedAccountsPayable),
	|	TableInventory.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATRate
	|		ELSE TableInventory.VATRate
	|	END,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableHeader.StructuralUnit,
	|	TableInventory.Ownership,
	|	TableInventory.Project,
	|	TableInventory.Order,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.Quantity,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.Amount + TableInventory.AmountExpense
	|		ELSE TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.AmountCur + TableInventory.AmountExpenseCur
	|		ELSE TableInventory.AmountCur - TableInventory.VATAmountCur + TableInventory.AmountExpenseCur
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmount
	|		ELSE TableInventory.VATAmount
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmountCur
	|		ELSE TableInventory.VATAmountCur
	|	END,
	|	TableHeader.BasisDocument.Date,
	|	TableHeader.Date,
	|	TableHeader.Date,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableInventory.Document = TableHeader.Ref
	|WHERE
	|	TableHeader.AdvanceInvoicing
	|	AND TableInventory.GoodsReceipt = VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.GoodsReceivedNotInvoicedAccountsPayable),
	|	TableInventory.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATRate
	|		ELSE TableInventory.VATRate
	|	END,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableHeader.StructuralUnit,
	|	TableInventory.Ownership,
	|	TableInventory.Project,
	|	TableInventory.Order,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.Quantity,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.Amount + TableInventory.AmountExpense
	|		ELSE TableInventory.Amount - TableInventory.VATAmount + TableInventory.AmountExpense
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.AmountCur + TableInventory.AmountExpenseCur
	|		ELSE TableInventory.AmountCur - TableInventory.VATAmountCur + TableInventory.AmountExpenseCur
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmount
	|		ELSE TableInventory.VATAmount
	|	END,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATAmountCur
	|		ELSE TableInventory.VATAmountCur
	|	END,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableInventory.Document = TableHeader.Ref
	|WHERE
	|	TableHeader.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental)
	|	AND TableInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.ServicesAccountsPayable),
	|	TableExpenses.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableExpenses.ReverseChargeVATRate
	|		ELSE TableExpenses.VATRate
	|	END,
	|	TableExpenses.ExpenseItem,
	|	TableHeader.Department,
	|	TableExpenses.Products,
	|	TableExpenses.Characteristic,
	|	TableExpenses.Batch,
	|	TableHeader.StructuralUnit,
	|	TableExpenses.Ownership,
	|	TableExpenses.Project,
	|	TableExpenses.PurchaseOrder,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.Quantity
	|	END,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.Amount
	|	END,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.AmountCur
	|	END,
	|	TableExpenses.ReverseChargeVATAmount,
	|	TableExpenses.ReverseChargeVATAmountCur,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableExpenses AS TableExpenses
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableExpenses.Document = TableHeader.Ref
	|			AND (TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT))
	|			AND (NOT TableHeader.IncludeExpensesInCostPrice
	|				OR TableExpenses.ReverseChargeVATAmount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.ServicesAccountsPayable),
	|	TableExpenses.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableExpenses.ReverseChargeVATRate
	|		ELSE TableExpenses.VATRate
	|	END,
	|	TableExpenses.ExpenseItem,
	|	TableHeader.Department,
	|	TableExpenses.Products,
	|	TableExpenses.Characteristic,
	|	TableExpenses.Batch,
	|	TableHeader.StructuralUnit,
	|	TableExpenses.Ownership,
	|	TableExpenses.Project,
	|	TableExpenses.PurchaseOrder,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.Quantity
	|	END,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.Amount - TableExpenses.VATAmount
	|	END,
	|	CASE
	|		WHEN TableHeader.IncludeExpensesInCostPrice
	|			THEN 0
	|		ELSE TableExpenses.AmountCur - TableExpenses.VATAmountCur
	|	END,
	|	TableExpenses.VATAmount,
	|	TableExpenses.VATAmountCur,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableExpenses AS TableExpenses
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableExpenses.Document = TableHeader.Ref
	|			AND (TableHeader.VATTaxation <> VALUE(Enum.VATTaxationTypes.ReverseChargeVAT))
	|			AND (NOT TableHeader.IncludeExpensesInCostPrice
	|				OR TableExpenses.VATAmount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.AccountsPayableAdvanceToSupplier),
	|	TablePrepayment.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Order,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TablePrepayment.Document,
	|	0,
	|	TablePrepayment.Amount,
	|	TablePrepayment.AmountCur,
	|	0,
	|	0,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTablePrepayment AS TablePrepayment
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TablePrepayment.DocumentWhere = TableHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.VATOnAdvancePaymentVAT),
	|	1,
	|	TablePrepaymentVAT.Period,
	|	TablePrepaymentVAT.Company,
	|	TablePrepaymentVAT.PresentationCurrency,
	|	TablePrepaymentVAT.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	TablePrepaymentVAT.VATRate,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Order,
	|	TablePrepaymentVAT.Customer,
	|	TableHeader.Contract,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TablePrepaymentVAT.ShipmentDocument,
	|	0,
	|	TablePrepaymentVAT.VATAmount,
	|	0,
	|	0,
	|	0,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTablePrepaymentVAT AS TablePrepaymentVAT
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TablePrepaymentVAT.Ref = TableHeader.Ref
	|WHERE
	|	TableHeader.RegisteredForVAT
	|	AND TableHeader.PostVATEntriesBySourceDocuments
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(Enum.EntryTypes.InventoryRetailMarkup),
	|	TableInventory.LineNumber,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	CASE
	|		WHEN TableHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN TableInventory.ReverseChargeVATRate
	|		ELSE TableInventory.VATRate
	|	END,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableHeader.StructuralUnit,
	|	TableInventory.Ownership,
	|	TableInventory.Project,
	|	UNDEFINED,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	TemporaryTablePOSSummary.Amount - TemporaryTablePOSSummary.Cost,
	|	0,
	|	0,
	|	0,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		INNER JOIN TemporaryTablePOSSummary AS TemporaryTablePOSSummary
	|		ON TableInventory.LineNumber = TemporaryTablePOSSummary.LineNumber
	|			AND TableInventory.Products = TemporaryTablePOSSummary.Products
	|			AND TableInventory.Characteristic = TemporaryTablePOSSummary.Characteristic
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|		ON TableInventory.Document = TableHeader.Ref
	|WHERE
	|	TableHeader.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.Invoice)
	|	AND TableHeader.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN VALUE(Enum.EntryTypes.AccountsPayableFXGain)
	|		ELSE VALUE(Enum.EntryTypes.AccountsPayableFXLoss)
	|	END,
	|	1,
	|	TableHeader.Date,
	|	TableHeader.Company,
	|	TableHeader.PresentationCurrency,
	|	TableHeader.CompanyVATNumber,
	|	TableHeader.VATTaxation,
	|	UNDEFINED,
	|	CASE
	|		WHEN TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN &DefaultEXIncome
	|		ELSE &DefaultEXExpense
	|	END,
	|	TableHeader.Department,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Counterparty,
	|	TableHeader.Contract,
	|	TableHeader.SettlementsCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	CASE
	|		WHEN TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences > 0
	|			THEN TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|		ELSE -TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences
	|	END,
	|	0,
	|	0,
	|	0,
	|	TableHeader.BasisDocument.Date,
	|	UNDEFINED,
	|	UNDEFINED,
	|	TableHeader.Ref
	|FROM
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS TemporaryTableOfExchangeRateDifferencesAccountsPayable
	|		INNER JOIN SupplierInvoiceHeader AS TableHeader
	|			INNER JOIN Constant.ForeignExchangeAccounting AS ForeignExchangeAccounting
	|			ON (ForeignExchangeAccounting.Value = TRUE)
	|			INNER JOIN Constant.ForeignCurrencyRevaluationPeriodicity AS ForeignCurrencyRevaluationPeriodicity
	|			ON (ForeignCurrencyRevaluationPeriodicity.Value = VALUE(Enum.ForeignCurrencyRevaluationPeriodicity.DuringOpertionExecution))
	|		ON TemporaryTableOfExchangeRateDifferencesAccountsPayable.Document = TableHeader.Ref
	|WHERE
	|	TemporaryTableOfExchangeRateDifferencesAccountsPayable.AmountOfExchangeDifferences <> 0";
	
	Query.SetParameter("Ref"			 , DocumentRefPurchaseInvoice);
	Query.SetParameter("DefaultEXIncome" , Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("DefaultEXExpense", Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	
	QueryResult = Query.Execute();
	
	TableResult = QueryResult.Unload();
	
	TypedTableResult = New ValueTable;
	DriveServer.ValueTableCreateTypedColumnsByRegister(TypedTableResult, "AccountingEntriesData");
	
	For Each Row In TableResult Do
		NewRow = TypedTableResult.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	TypedTableResult.FillValues(True, "Active");
	DriveServer.ValueTableEnumerateRows(TypedTableResult, "RowNumber", 1);
	
	If StructureAdditionalProperties.TableForRegisterRecords.TableAccountingEntriesData.Count() = 0 Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", TypedTableResult);
	Else
		For Each TypesTableRow In TypedTableResult Do
			NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingEntriesData.Add();
			FillPropertyValues(NewRow, TypesTableRow);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

Procedure SetInStructureOperationKind(StructureDocument, DocumentRef)
	
	EnumOperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
	
	If EnumOperationKind = Enums.OperationTypesSupplierInvoice.AdvanceInvoice Then
		
		StructureDocument.Insert("AdvanceInvoicing", True);
		
	Else 
		
		StructureDocument.Insert("AdvanceInvoicing", False);
		
	EndIf;
	
	If EnumOperationKind = Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
		
		StructureDocument.Insert("IsZeroInvoice", True);
		
	Else 
		
		StructureDocument.Insert("IsZeroInvoice", False);
		
	EndIf;
	
	If EnumOperationKind = Enums.OperationTypesSupplierInvoice.DropShipping Then
		
		StructureDocument.Insert("IsDropShipping", True);
		
	Else 
		
		StructureDocument.Insert("IsDropShipping", False);
		
	EndIf;
	
EndProcedure

Procedure CheckPermissionToGenerateInvoiceBasedOnOrder(FillingData, IsNotPermission, TextRaise, CurrentOperationKind) Export
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("DropShipping")
		And FillingData.DropShipping Then
		
		Return;
		
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure") 
		And FillingData.Property("ArrayOfPurchaseOrders") Then
		
		OrdersArray = FillingData.ArrayOfPurchaseOrders;
	
		Query = New Query;
		Query.Text = 
		"SELECT
		|	PurchaseOrder.Ref AS Ref,
		|	PurchaseOrder.OperationKind AS OperationKind
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|WHERE
		|	PurchaseOrder.Ref IN(&OrdersArray)";
		
		Query.SetParameter("OrdersArray", OrdersArray);
		
		QueryResult = Query.Execute();
		
		SelectionDetailRecords = QueryResult.Select();
		
		While SelectionDetailRecords.Next() Do
			
			If SelectionDetailRecords.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForDropShipping Then
				IsNotPermission = True;
				TextRaise = NStr("en = 'Cannot generate a Supplier invoice. 
								|The Purchase order requires drop shipping. 
								|For this order, generate ""Supplier invoice: Drop shipping"".'; 
								|ru = 'Не удалось сформировать инвойс поставщика. 
								|Для заказа поставщику требуется дропшиппинг. 
								|Для этого заказа создайте «Инвойс поставщика: Дропшиппинг».';
								|pl = 'Nie można wygenerować Faktury zakupu. 
								|Zamówienie zakupu wymaga dropshippingu. 
								|Dla tego zamówienia, wygeneruj ""Faktura zakupu: Dropshipping"".';
								|es_ES = 'No se puede generar una factura de proveedor. 
								|La orden de compra requiere envío directo. 
								|Para este pedido, genere ""Factura de proveedor: Envío directo"".';
								|es_CO = 'No se puede generar una factura de proveedor. 
								|La orden de compra requiere envío directo. 
								|Para este pedido, genere ""Factura de proveedor: Envío directo"".';
								|tr = 'Satın alma faturası oluşturulamıyor. 
								|Satın alma siparişi için stoksuz satış gerekli. 
								|Bu sipariş için ""Satın alma faturası: Stoksuz satış"" seçin.';
								|it = 'Impossibile generare una Fattura del fornitore. 
								|L''Ordine di acquisto richiede dropshipping. 
								|Per questo ordine, generare ""Fattura del fornitore: Dropshipping"".';
								|de = 'Fehler beim Generieren einer Lieferantenrechnung. 
								|Die Bestellung an Lieferanten benötigt Streckengeschäft. 
								|Für diesen Auftrag generieren Sie ""Lieferantenrechnung: Streckengeschäft"".'");
				Break;
			EndIf;
		
		EndDo;
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") 
		And Not CurrentOperationKind = Enums.OperationTypesSupplierInvoice.DropShipping Then
		
		EnumOperationKind = Common.ObjectAttributeValue(FillingData, "OperationKind");
		
		If EnumOperationKind = Enums.OperationTypesPurchaseOrder.OrderForDropShipping Then
			IsNotPermission = True;
			TextRaise = NStr("en = 'Cannot generate a Supplier invoice. 
							|The Purchase order requires drop shipping. 
							|For this order, generate ""Supplier invoice: Drop shipping"".'; 
							|ru = 'Не удалось сформировать инвойс поставщика. 
							|Для заказа поставщику требуется дропшиппинг. 
							|Для этого заказа создайте «Инвойс поставщика: Дропшиппинг».';
							|pl = 'Nie można wygenerować Faktury zakupu. 
							|Zamówienie zakupu wymaga dropshippingu. 
							|Dla tego zamówienia, wygeneruj ""Faktura zakupu: Dropshipping"".';
							|es_ES = 'No se puede generar una factura de proveedor. 
							|La orden de compra requiere envío directo. 
							|Para este pedido, genere ""Factura de proveedor: Envío directo"".';
							|es_CO = 'No se puede generar una factura de proveedor. 
							|La orden de compra requiere envío directo. 
							|Para este pedido, genere ""Factura de proveedor: Envío directo"".';
							|tr = 'Satın alma faturası oluşturulamıyor. 
							|Satın alma siparişi için stoksuz satış gerekli. 
							|Bu sipariş için ""Satın alma faturası: Stoksuz satış"" seçin.';
							|it = 'Impossibile generare una Fattura del fornitore. 
							|L''Ordine di acquisto richiede dropshipping. 
							|Per questo ordine, generare ""Fattura del fornitore: Dropshipping"".';
							|de = 'Fehler beim Generieren einer Lieferantenrechnung. 
							|Die Bestellung an Lieferanten benötigt Streckengeschäft. 
							|Für diesen Auftrag generieren Sie ""Lieferantenrechnung: Streckengeschäft"".'");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure FillByPurchaseOrders(DocumentData, FilterData, Inventory, Expenses, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PurchaseOrder.Ref AS Ref,
	|	PurchaseOrder.StructuralUnit AS StructuralUnit
	|INTO TT_PurchaseOrders
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	&PurchaseOrdersConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.PurchaseOrder AS PurchaseOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder IN
	|						(SELECT
	|							TT_PurchaseOrders.Ref
	|						FROM
	|							TT_PurchaseOrders)
	|					AND (Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|						OR Products.ProductsType = VALUE(Enum.ProductsTypes.Service))) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.PurchaseOrder,
	|		DocumentRegisterRecordsPurchaseOrders.Products,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsPurchaseOrders.Quantity
	|			ELSE -DocumentRegisterRecordsPurchaseOrders.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchaseOrderInventory.LineNumber AS LineNumber,
	|	PurchaseOrderInventory.CrossReference AS CrossReference,
	|	PurchaseOrderInventory.SalesOrder AS SalesOrder,
	|	TT_PurchaseOrders.StructuralUnit AS StructuralUnitExpense,
	|	ProductsCatalog.Ref AS Products,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	PrimaryChartOfAccounts.TypeOfAccount AS TypeOfAccount,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	PurchaseOrderInventory.Batch AS Batch,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	PurchaseOrderInventory.Quantity AS Quantity,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	PurchaseOrderInventory.Price AS Price,
	|	PurchaseOrderInventory.Amount AS Amount,
	|	PurchaseOrderInventory.VATRate AS VATRate,
	|	PurchaseOrderInventory.VATAmount AS VATAmount,
	|	PurchaseOrderInventory.Total AS Total,
	|	ProductsCatalog.VATRate AS ReverseChargeVATRate,
	|	PurchaseOrderInventory.Content AS Content,
	|	PurchaseOrderInventory.Ref AS OrderBasis,
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.inventoryItem) AS ProductsTypeInventory,
	|	PurchaseOrderInventory.Specification AS Specification,
	|	PurchaseOrderInventory.DiscountPercent AS DiscountPercent,
	|	PurchaseOrderInventory.DiscountAmount AS DiscountAmount,
	|	PurchaseOrderInventory.Project AS Project
	|FROM
	|	TT_PurchaseOrders AS TT_PurchaseOrders
	|		INNER JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON TT_PurchaseOrders.Ref = PurchaseOrderInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (PurchaseOrderInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN ChartOfAccounts.PrimaryChartOfAccounts AS PrimaryChartOfAccounts
	|		ON (ProductsCatalog.ExpensesGLAccount = PrimaryChartOfAccounts.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (PurchaseOrderInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	(ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.Service)
	|			OR ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "PurchaseOrder.Ref IN(&OrdersArray)";
		Query.SetParameter("OrdersArray", FilterData.OrdersArray);
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "PurchaseOrder." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
		
		If GetFunctionalOption("UsePurchaseOrderApproval") Then
			FilterString = FilterString + "
				|	AND (PurchaseOrder.ApprovalStatus = VALUE(Enum.ApprovalStatuses.Approved)
				|		OR PurchaseOrder.ApprovalStatus = VALUE(Enum.ApprovalStatuses.EmptyRef))";
		EndIf;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&PurchaseOrdersConditions", FilterString);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[1].Unload();
	BalanceTable.Indexes.Add("PurchaseOrder,Products,Characteristic");
	
	Inventory.Clear();
	Expenses.Clear();
	
	IsReverseCharge = DocumentData.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
	
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("PurchaseOrder",	Selection.OrderBasis);
			StructureForSearch.Insert("Products",		Selection.Products);
			StructureForSearch.Insert("Characteristic",	Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			If Selection.ProductsTypeInventory Then
				NewRow = Inventory.Add();
				NewRow.Order = Selection.OrderBasis;
			Else
				
				NewRow = Expenses.Add();
				NewRow.PurchaseOrder = Selection.OrderBasis;
				NewRow.StructuralUnit = Selection.StructuralUnitExpense;
				
				If DefaultFill Then
					If ValueIsFilled(Selection.SalesOrder)
						And (Not GetFunctionalOption("UseDefaultTypeOfAccounting")
							Or Selection.TypeOfAccount = Enums.GLAccountsTypes.Expenses
							Or Selection.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
							Or Selection.TypeOfAccount = Enums.GLAccountsTypes.WorkInProgress) Then
						NewRow.Order = Selection.SalesOrder;
					EndIf;
				Else
					NewRow.Order = Selection.OrderBasis;
				EndIf;
				
			EndIf;
			
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				QuantityToWriteOff = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				DataStructure = New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
				DataStructure.Quantity			= QuantityToWriteOff;
				DataStructure.Price				= Selection.Price;
				DataStructure.Amount			= 0;
				DataStructure.VATRate			= Selection.VATRate;
				DataStructure.VATAmount			= 0;
				DataStructure.AmountIncludesVAT	= DocumentData.AmountIncludesVAT;
				DataStructure.Total				= 0;
				
				DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
				
				FillPropertyValues(NewRow, DataStructure);
				
			EndIf;
			
			If IsReverseCharge Then
				
				DataStructure = New Structure("Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
				DataStructure.Amount			= NewRow.Total;
				DataStructure.VATRate			= NewRow.ReverseChargeVATRate;
				DataStructure.VATAmount			= 0;
				DataStructure.AmountIncludesVAT	= False;
				DataStructure.Total				= 0;
				
				DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
			
				NewRow.ReverseChargeVATAmount = DataStructure.VATAmount;
				
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillByGoodsReceipts(DocumentData, FilterData, Inventory, Expenses, DefaultFill = True) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsReceipt.Ref AS Ref,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit
	|INTO TT_GoodsReceipt
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	&GoodsReceiptConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE SupplierInvoiceInventory.Order
	|	END AS Order,
	|	SupplierInvoiceInventory.GoodsReceipt AS GoodsReceipt,
	|	SupplierInvoiceInventory.Products AS Products,
	|	SupplierInvoiceInventory.Characteristic AS Characteristic,
	|	SupplierInvoiceInventory.Batch AS Batch,
	|	SUM(SupplierInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1)) AS BaseQuantity
	|INTO TT_AlreadyInvoiced
	|FROM
	|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		INNER JOIN TT_GoodsReceipt AS TT_GoodsReceipt
	|		ON SupplierInvoiceInventory.GoodsReceipt = TT_GoodsReceipt.Ref
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoiceDocument
	|		ON SupplierInvoiceInventory.Ref = SupplierInvoiceDocument.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON SupplierInvoiceInventory.Products = ProductsCatalog.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON SupplierInvoiceInventory.MeasurementUnit = UOM.Ref
	|WHERE
	|	SupplierInvoiceDocument.Posted
	|	AND SupplierInvoiceInventory.Ref <> &Ref
	|
	|GROUP BY
	|	SupplierInvoiceInventory.Batch,
	|	SupplierInvoiceInventory.Order,
	|	SupplierInvoiceInventory.Products,
	|	SupplierInvoiceInventory.Characteristic,
	|	SupplierInvoiceInventory.GoodsReceipt
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.GoodsReceipt AS GoodsReceipt,
	|	OrdersBalance.PurchaseOrder AS Order,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO GoodsReceivedBalance
	|FROM
	|	(SELECT
	|		GoodsReceivedNotInvoicedBalance.PurchaseOrder AS PurchaseOrder,
	|		GoodsReceivedNotInvoicedBalance.GoodsReceipt AS GoodsReceipt,
	|		GoodsReceivedNotInvoicedBalance.Products AS Products,
	|		GoodsReceivedNotInvoicedBalance.Batch AS Batch,
	|		GoodsReceivedNotInvoicedBalance.Characteristic AS Characteristic,
	|		GoodsReceivedNotInvoicedBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|				,
	|				GoodsReceipt IN
	|					(SELECT
	|						TT_GoodsReceipt.Ref
	|					FROM
	|						TT_GoodsReceipt)) AS GoodsReceivedNotInvoicedBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.PurchaseOrder,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.GoodsReceipt,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Products,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Batch,
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsGoodsReceivedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsGoodsReceivedNotInvoiced.Quantity
	|			ELSE -DocumentRegisterRecordsGoodsReceivedNotInvoiced.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.GoodsReceivedNotInvoiced AS DocumentRegisterRecordsGoodsReceivedNotInvoiced
	|	WHERE
	|		DocumentRegisterRecordsGoodsReceivedNotInvoiced.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.GoodsReceipt,
	|	OrdersBalance.PurchaseOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.Batch
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceiptInventory.LineNumber AS LineNumber,
	|	GoodsReceiptInventory.CrossReference AS CrossReference,
	|	TT_GoodsReceipt.StructuralUnit AS StructuralUnitExpense,
	|	ProductsCatalog.Ref AS Products,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	GoodsReceiptInventory.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	GoodsReceiptInventory.Quantity AS Quantity,
	|	GoodsReceiptInventory.MeasurementUnit AS MeasurementUnit,
	|	GoodsReceiptInventory.Batch AS Batch,
	|	CASE
	|		WHEN GoodsReceiptInventory.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE GoodsReceiptInventory.Order
	|	END AS Order,
	|	GoodsReceiptInventory.Contract AS Contract,
	|	GoodsReceiptInventory.Price AS Price,
	|	GoodsReceiptInventory.VATRate AS VATRAte,
	|	ProductsCatalog.VATRate AS ProductsVATRate,
	|	GoodsReceiptInventory.Ref AS GoodsReceipt,
	|	TRUE AS ProductsTypeInventory,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptInventory.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptInventory.GoodsReceivedNotInvoicedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsReceivedNotInvoicedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptInventory.GoodsInvoicedNotDeliveredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GoodsInvoicedNotDeliveredGLAccount,
	|	GoodsReceiptInventory.DiscountPercent AS DiscountPercent
	|INTO TT_Inventory
	|FROM
	|	TT_GoodsReceipt AS TT_GoodsReceipt
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptInventory
	|		ON TT_GoodsReceipt.Ref = GoodsReceiptInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (GoodsReceiptInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	(GoodsReceiptInventory.Contract = &Contract
	|			OR &Contract = UNDEFINED)
	|	AND GoodsReceiptInventory.SupplierInvoice = VALUE(Document.SupplierInvoice.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor AS BaseQuantity,
	|	SUM(TT_InventoryCumulative.Quantity * TT_InventoryCumulative.Factor) AS BaseQuantityCumulative
	|INTO TT_InventoryCumulative
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_Inventory AS TT_InventoryCumulative
	|		ON TT_Inventory.Products = TT_InventoryCumulative.Products
	|			AND TT_Inventory.Characteristic = TT_InventoryCumulative.Characteristic
	|			AND TT_Inventory.Batch = TT_InventoryCumulative.Batch
	|			AND TT_Inventory.Order = TT_InventoryCumulative.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryCumulative.GoodsReceipt
	|			AND TT_Inventory.LineNumber >= TT_InventoryCumulative.LineNumber
	|
	|GROUP BY
	|	TT_Inventory.LineNumber,
	|	TT_Inventory.Products,
	|	TT_Inventory.Characteristic,
	|	TT_Inventory.Batch,
	|	TT_Inventory.Order,
	|	TT_Inventory.GoodsReceipt,
	|	TT_Inventory.Factor,
	|	TT_Inventory.Quantity * TT_Inventory.Factor
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryCumulative.LineNumber AS LineNumber,
	|	TT_InventoryCumulative.Products AS Products,
	|	TT_InventoryCumulative.Characteristic AS Characteristic,
	|	TT_InventoryCumulative.Batch AS Batch,
	|	TT_InventoryCumulative.Order AS Order,
	|	TT_InventoryCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_AlreadyInvoiced.BaseQuantity > TT_InventoryCumulative.BaseQuantityCumulative - TT_InventoryCumulative.BaseQuantity
	|			THEN TT_InventoryCumulative.BaseQuantityCumulative - TT_AlreadyInvoiced.BaseQuantity
	|		ELSE TT_InventoryCumulative.BaseQuantity
	|	END AS BaseQuantity
	|INTO TT_InventoryNotYetInvoiced
	|FROM
	|	TT_InventoryCumulative AS TT_InventoryCumulative
	|		LEFT JOIN TT_AlreadyInvoiced AS TT_AlreadyInvoiced
	|		ON TT_InventoryCumulative.Products = TT_AlreadyInvoiced.Products
	|			AND TT_InventoryCumulative.Characteristic = TT_AlreadyInvoiced.Characteristic
	|			AND TT_InventoryCumulative.Batch = TT_AlreadyInvoiced.Batch
	|			AND TT_InventoryCumulative.Order = TT_AlreadyInvoiced.Order
	|			AND TT_InventoryCumulative.GoodsReceipt = TT_AlreadyInvoiced.GoodsReceipt
	|WHERE
	|	ISNULL(TT_AlreadyInvoiced.BaseQuantity, 0) < TT_InventoryCumulative.BaseQuantityCumulative
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoiced.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoiced.Products AS Products,
	|	TT_InventoryNotYetInvoiced.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch AS Batch,
	|	TT_InventoryNotYetInvoiced.Order AS Order,
	|	TT_InventoryNotYetInvoiced.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor AS Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity AS BaseQuantity,
	|	SUM(TT_InventoryNotYetInvoicedCumulative.BaseQuantity) AS BaseQuantityCumulative
	|INTO TT_InventoryNotYetInvoicedCumulative
	|FROM
	|	TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoiced
	|		INNER JOIN TT_InventoryNotYetInvoiced AS TT_InventoryNotYetInvoicedCumulative
	|		ON TT_InventoryNotYetInvoiced.Products = TT_InventoryNotYetInvoicedCumulative.Products
	|			AND TT_InventoryNotYetInvoiced.Characteristic = TT_InventoryNotYetInvoicedCumulative.Characteristic
	|			AND TT_InventoryNotYetInvoiced.Batch = TT_InventoryNotYetInvoicedCumulative.Batch
	|			AND TT_InventoryNotYetInvoiced.Order = TT_InventoryNotYetInvoicedCumulative.Order
	|			AND TT_InventoryNotYetInvoiced.GoodsReceipt = TT_InventoryNotYetInvoicedCumulative.GoodsReceipt
	|			AND TT_InventoryNotYetInvoiced.LineNumber >= TT_InventoryNotYetInvoicedCumulative.LineNumber
	|
	|GROUP BY
	|	TT_InventoryNotYetInvoiced.LineNumber,
	|	TT_InventoryNotYetInvoiced.Products,
	|	TT_InventoryNotYetInvoiced.Characteristic,
	|	TT_InventoryNotYetInvoiced.Batch,
	|	TT_InventoryNotYetInvoiced.Order,
	|	TT_InventoryNotYetInvoiced.GoodsReceipt,
	|	TT_InventoryNotYetInvoiced.Factor,
	|	TT_InventoryNotYetInvoiced.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_InventoryNotYetInvoicedCumulative.LineNumber AS LineNumber,
	|	TT_InventoryNotYetInvoicedCumulative.Products AS Products,
	|	TT_InventoryNotYetInvoicedCumulative.Characteristic AS Characteristic,
	|	TT_InventoryNotYetInvoicedCumulative.Batch AS Batch,
	|	TT_InventoryNotYetInvoicedCumulative.Order AS Order,
	|	TT_InventoryNotYetInvoicedCumulative.GoodsReceipt AS GoodsReceipt,
	|	TT_InventoryNotYetInvoicedCumulative.Factor AS Factor,
	|	CASE
	|		WHEN TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative
	|			THEN TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|		WHEN TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|			THEN TT_GoodsReceivedBalance.QuantityBalance - (TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity)
	|	END AS BaseQuantity
	|INTO TT_InventoryToBeInvoiced
	|FROM
	|	TT_InventoryNotYetInvoicedCumulative AS TT_InventoryNotYetInvoicedCumulative
	|		INNER JOIN GoodsReceivedBalance AS TT_GoodsReceivedBalance
	|		ON TT_InventoryNotYetInvoicedCumulative.Products = TT_GoodsReceivedBalance.Products
	|			AND TT_InventoryNotYetInvoicedCumulative.Characteristic = TT_GoodsReceivedBalance.Characteristic
	|			AND TT_InventoryNotYetInvoicedCumulative.Order = TT_GoodsReceivedBalance.Order
	|			AND TT_InventoryNotYetInvoicedCumulative.GoodsReceipt = TT_GoodsReceivedBalance.GoodsReceipt
	|WHERE
	|	TT_GoodsReceivedBalance.QuantityBalance > TT_InventoryNotYetInvoicedCumulative.BaseQuantityCumulative - TT_InventoryNotYetInvoicedCumulative.BaseQuantity
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_Inventory.LineNumber AS LineNumber,
	|	TT_Inventory.CrossReference AS CrossReference,
	|	TT_Inventory.Products AS Products,
	|	TT_Inventory.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_Inventory.Characteristic AS Characteristic,
	|	TT_Inventory.Batch AS Batch,
	|	CASE
	|		WHEN (CAST(TT_Inventory.Quantity * TT_Inventory.Factor AS NUMBER(15, 3))) = TT_InventoryToBeInvoiced.BaseQuantity
	|			THEN TT_Inventory.Quantity
	|		ELSE CAST(TT_InventoryToBeInvoiced.BaseQuantity / TT_Inventory.Factor AS NUMBER(15, 3))
	|	END AS Quantity,
	|	TT_Inventory.MeasurementUnit AS MeasurementUnit,
	|	TT_Inventory.Factor AS Factor,
	|	TT_Inventory.Order AS Order,
	|	TT_Inventory.Contract AS Contract,
	|	TT_Inventory.GoodsReceipt AS GoodsReceipt,
	|	TT_Inventory.Price AS Price,
	|	PurchaseOrderInventory.Price AS PurchaseOrderPrice,
	|	TT_Inventory.VATRAte AS VATRate,
	|	TT_Inventory.ProductsVATRate AS ReverseChargeVATRate,
	|	ISNULL(PurchaseOrderInventory.VATRate, TT_Inventory.ProductsVATRate) AS PurchaseOrderVATRate,
	|	ISNULL(PurchaseOrderInventory.Quantity, 0) AS QuantityOrd,
	|	TT_Inventory.InventoryGLAccount AS InventoryGLAccount,
	|	TT_Inventory.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	TT_Inventory.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount,
	|	PurchaseOrderInventory.Specification AS Specification,
	|	ISNULL(PurchaseOrderInventory.DiscountPercent, TT_Inventory.DiscountPercent) AS DiscountPercent
	|INTO TT_WithOrders
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN TT_InventoryToBeInvoiced AS TT_InventoryToBeInvoiced
	|		ON TT_Inventory.LineNumber = TT_InventoryToBeInvoiced.LineNumber
	|			AND TT_Inventory.Order = TT_InventoryToBeInvoiced.Order
	|			AND TT_Inventory.GoodsReceipt = TT_InventoryToBeInvoiced.GoodsReceipt
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON TT_Inventory.Order = PurchaseOrderInventory.Ref
	|			AND TT_Inventory.Products = PurchaseOrderInventory.Products
	|			AND TT_Inventory.Characteristic = PurchaseOrderInventory.Characteristic
	|			AND TT_Inventory.MeasurementUnit = PurchaseOrderInventory.MeasurementUnit
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_WithOrders.LineNumber AS LineNumber,
	|	TT_WithOrders.CrossReference AS CrossReference,
	|	TT_WithOrders.Products AS Products,
	|	TT_WithOrders.ProductsTypeInventory AS ProductsTypeInventory,
	|	TT_WithOrders.Characteristic AS Characteristic,
	|	TT_WithOrders.Batch AS Batch,
	|	TT_WithOrders.Quantity AS Quantity,
	|	TT_WithOrders.MeasurementUnit AS MeasurementUnit,
	|	TT_WithOrders.Factor AS Factor,
	|	TT_WithOrders.Order AS Order,
	|	TT_WithOrders.Contract AS Contract,
	|	TT_WithOrders.GoodsReceipt AS GoodsReceipt,
	|	CASE
	|		WHEN TT_WithOrders.Price = 0
	|			THEN MAX(ISNULL(ISNULL(TT_WithOrders.PurchaseOrderPrice, PricesSliceLast.Price), 0))
	|		ELSE TT_WithOrders.Price
	|	END AS Price,
	|	CASE
	|		WHEN TT_WithOrders.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|			THEN MAX(TT_WithOrders.PurchaseOrderVATRate)
	|		ELSE TT_WithOrders.VATRate
	|	END AS VATRate,
	|	MAX(TT_WithOrders.ReverseChargeVATRate) AS ReverseChargeVATRate,
	|	MAX(TT_WithOrders.QuantityOrd) AS QuantityOrd,
	|	TT_WithOrders.InventoryGLAccount AS InventoryGLAccount,
	|	TT_WithOrders.GoodsReceivedNotInvoicedGLAccount AS GoodsReceivedNotInvoicedGLAccount,
	|	TT_WithOrders.GoodsInvoicedNotDeliveredGLAccount AS GoodsInvoicedNotDeliveredGLAccount,
	|	TT_WithOrders.Specification AS Specification,
	|	CASE
	|		WHEN TT_WithOrders.DiscountPercent = 0
	|			THEN MAX(TT_WithOrders.DiscountPercent)
	|		ELSE TT_WithOrders.DiscountPercent
	|	END AS DiscountPercent
	|FROM
	|	TT_WithOrders AS TT_WithOrders
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast AS PricesSliceLast
	|		ON TT_WithOrders.Products = PricesSliceLast.Products
	|			AND TT_WithOrders.Characteristic = PricesSliceLast.Characteristic
	|			AND TT_WithOrders.MeasurementUnit = PricesSliceLast.MeasurementUnit
	|			AND TT_WithOrders.Contract.SupplierPriceTypes = PricesSliceLast.SupplierPriceTypes
	|
	|GROUP BY
	|	TT_WithOrders.MeasurementUnit,
	|	TT_WithOrders.CrossReference,
	|	TT_WithOrders.Products,
	|	TT_WithOrders.ProductsTypeInventory,
	|	TT_WithOrders.Order,
	|	TT_WithOrders.Batch,
	|	TT_WithOrders.Characteristic,
	|	TT_WithOrders.Contract,
	|	TT_WithOrders.GoodsReceipt,
	|	TT_WithOrders.Price,
	|	TT_WithOrders.VATRate,
	|	TT_WithOrders.LineNumber,
	|	TT_WithOrders.Quantity,
	|	TT_WithOrders.Factor,
	|	TT_WithOrders.InventoryGLAccount,
	|	TT_WithOrders.GoodsReceivedNotInvoicedGLAccount,
	|	TT_WithOrders.GoodsInvoicedNotDeliveredGLAccount,
	|	TT_WithOrders.Specification,
	|	TT_WithOrders.DiscountPercent
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
		
	Contract = Undefined;
	
	FilterData.Property("Contract", Contract);
	Query.SetParameter("Contract", Contract);
	
	If FilterData.Property("ArrayOfGoodsReceipts") Then
		FilterString = "GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)";
		Query.SetParameter("ArrayOfGoodsReceipts", FilterData.ArrayOfGoodsReceipts);
	Else
		FilterString = "";
		NotFirstItem = False;
		For Each FilterItem In FilterData Do
			If NotFirstItem Then
				FilterString = FilterString + "
				|	AND ";
			Else
				NotFirstItem = True;
			EndIf;
			FilterString = FilterString + "GoodsReceipt." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&GoodsReceiptConditions", FilterString);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", DocumentData);
	
	Inventory.Clear();
	Expenses.Clear();
	
	IsReverseCharge = DocumentData.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT;
	
	While Selection.Next() Do
		
		TabularSectionRow = Inventory.Add();
		
		FillPropertyValues(TabularSectionRow, Selection);
		
		If Not DefaultFill Then
			TabularSectionRow.GoodsIssue = Selection.GoodsReceipt;
		EndIf;
		
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		TabularSectionRow.DiscountAmount = TabularSectionRow.DiscountPercent * TabularSectionRow.Amount / 100;
		TabularSectionRow.Amount = TabularSectionRow.Amount - TabularSectionRow.DiscountAmount;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		TabularSectionRow.VATAmount = ?(DocumentData.AmountIncludesVAT,
										TabularSectionRow.Amount - (TabularSectionRow.Amount) / ((VATRate + 100) / 100),
										TabularSectionRow.Amount * VATRate / 100);

		TabularSectionRow.Total = TabularSectionRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
		If IsReverseCharge Then
			
			DataStructure = New Structure("Amount, VATRate, VATAmount, AmountIncludesVAT, Total");
			DataStructure.Amount			= TabularSectionRow.Total;
			DataStructure.VATRate			= TabularSectionRow.ReverseChargeVATRate;
			DataStructure.VATAmount			= 0;
			DataStructure.AmountIncludesVAT	= False;
			DataStructure.Total				= 0;
			
			DataStructure = DriveServer.GetTabularSectionRowSum(DataStructure);
		
			TabularSectionRow.ReverseChargeVATAmount = DataStructure.VATAmount;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Exists or not Early payment discount on specified date
// Parameters:
//  DocumentRefSupplierInvoice - DocumentRef.SupplierInvoice - the Supplier invoice on which we check the EPD
//  CheckDate - date - the date of EPD check
// Returns:
//  Boolean - TRUE if EPD exists
//
Function CheckExistsEPD(DocumentRefSupplierInvoice, CheckDate) Export
	
	Result = False;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TRUE AS ExistsEPD
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref = &Ref
	|	AND ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("Ref", DocumentRefSupplierInvoice);
	Query.SetParameter("DueDate", CheckDate);
	
	QuerySelection = Query.Execute().Select();
	If QuerySelection.Next() Then
		Result = QuerySelection.ExistsEPD;
	EndIf;
	
	Return Result;
	
EndFunction

// Gets an array of invoices that have an EPD on the specified date
// Parameters:
//  SupplierInvoiceArray - Array - documents (DocumentRef.SupplierInvoice)
//  CheckDate - date - the date of EPD check
// Returns:
//  Array - documents (DocumentRef.SupplierInvoice) that have an EPD
//
Function GetSupplierInvoiceArrayWithEPD(SupplierInvoiceArray, Val CheckDate) Export
	
	Result = New Array;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED DISTINCT
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref AS SupplierInvoice
	|FROM
	|	Document.SupplierInvoice.EarlyPaymentDiscounts AS SupplierInvoiceEarlyPaymentDiscounts
	|WHERE
	|	SupplierInvoiceEarlyPaymentDiscounts.Ref IN(&SupplierInvoices)
	|	AND ENDOFPERIOD(SupplierInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &DueDate";
	
	Query.SetParameter("SupplierInvoices", SupplierInvoiceArray);
	Query.SetParameter("DueDate", CheckDate);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		Result = QueryResult.Unload().UnloadColumn("SupplierInvoice");
	EndIf;
	
	Return Result;
	
EndFunction

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringBySupplierInvoice(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'; ru = 'Документ %1 не проведен. Ввод на основании непроведенного документа запрещен.';pl = '%1 dokument nie został zatwierdzony. Nie można użyć go jako dokumentu źródłowego. Najpierw zatwierdź go.';es_ES = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';es_CO = '%1 no se ha enviado. No se puede utilizarlo como un documento de base. Por favor, enviarlo primero.';tr = '%1 kaydedilmediğinden temel belge olarak kullanılamıyor. Lütfen, önce kaydedin.';it = '%1 non pubblicato. Non è possibile utilizzarlo come documento di base. Si prega di pubblicarlo prima di tutto.';de = '%1 wird nicht gebucht. Kann nicht als Basisdokument verwendet werden. Zuerst bitte buchen.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
		
EndProcedure

Procedure CheckAbilityOfDropShippingEnteringBySupplierInvoice(SelectionCounterInvoices) Export
	
	While SelectionCounterInvoices.Next() Do
		
		If SelectionCounterInvoices.CountDropShippingInvoices <> 0 
			And SelectionCounterInvoices.CountDropShippingInvoices <> SelectionCounterInvoices.CountInvoices Then
			ErrorText = NStr("en = 'Cannot generate a single Sales invoice for multiple Supplier invoices 
							|with different Invoice types. 
							|Select Supplier invoices with the same Invoice type.
							|Then try again.'; 
							|ru = 'Не удалось создать инвойс покупателю для нескольких инвойсов поставщиков 
							|с разными типами инвойсов. 
							|Выберите инвойсы поставщиков с одинаковым типом инвойса.
							|Затем повторите попытку.';
							|pl = 'Nie można wygenerować pojedynczej Faktury sprzedaży dla kilku Faktur zakupu 
							|z różnymi typami faktury. 
							|Wybierz Faktury zakupu z takim samym typem faktury.
							|Następnie spróbuj ponownie.';
							|es_ES = 'No se puede generar una única factura de ventas para varias facturas de proveedores 
							|con diferentes tipos de factura. 
							|Seleccione las facturas de proveedor con el mismo tipo de factura. 
							|A continuación, inténtelo de nuevo.';
							|es_CO = 'No se puede generar una única factura de ventas para varias facturas de proveedores 
							|con diferentes tipos de factura. 
							|Seleccione las facturas de proveedor con el mismo tipo de factura. 
							|A continuación, inténtelo de nuevo.';
							|tr = 'Farklı fatura türlerine sahip birden fazla Satın alma faturası için 
							|tek bir Satış faturası oluşturulamaz. 
							|Aynı fatura türüne sahip Satın alma faturaları seçip 
							|tekrar deneyin.';
							|it = 'Impossibile generare una singola Fattura di vendita per multiple Fatture del fornitore 
							|con diverso Tipo di fattura. 
							|Selezionare Fattura del fornitore con lo stesso Tipo di fattura, 
							|poi riprovare.';
							|de = 'Fehler beim Generieren einer Verkaufsrechnung für mehrere Lieferantenrechnungen 
							|mit unterschiedlichen Rechnungstypen. 
							|Wählen Sie Lieferantenrechnungen mit demselben Rechnungstyp aus.
							|Dann versuchen Sie erneut.'");
			Raise ErrorText;
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetDropShippingData(RefSupplierInvoice) Export
	
	StructureData = New Structure;
	StructureData.Insert("IsDropShipping");
	StructureData.Insert("Counterparty");
	StructureData.Insert("Contract");
	StructureData.Insert("Order");
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.OperationKind AS OperationKind,
	|	SupplierInvoice.Order AS Order
	|INTO HeaderSupplierInvoice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS IsDropShipping,
	|	MAX(PurchaseOrderInventory.SalesOrder) AS RefSalesOrder
	|INTO TempTable
	|FROM
	|	HeaderSupplierInvoice AS SupplierInvoice
	|		LEFT JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON SupplierInvoice.Order = PurchaseOrder.Ref
	|			AND (SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping))
	|		LEFT JOIN Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|		ON (PurchaseOrder.Ref = PurchaseOrderInventory.Ref)
	|
	|GROUP BY
	|	CASE
	|		WHEN SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|			THEN TRUE
	|		ELSE FALSE
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempTable.IsDropShipping AS IsDropShipping,
	|	ISNULL(SalesOrder.Counterparty, VALUE(Catalog.Counterparties.EmptyRef)) AS Counterparty,
	|	ISNULL(SalesOrder.Contract, VALUE(Catalog.CounterpartyContracts.EmptyRef)) AS Contract,
	|	ISNULL(SalesOrder.Ref, VALUE(Document.SalesOrder.EmptyRef)) AS Order
	|FROM
	|	TempTable AS TempTable
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (TempTable.IsDropShipping)
	|			AND TempTable.RefSalesOrder = SalesOrder.Ref";
	
	Query.SetParameter("Ref", RefSupplierInvoice);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		FillPropertyValues(StructureData, SelectionDetailRecords);
	EndDo;
	
	Return StructureData;
	
EndFunction

Function ThereIsAdvanceInvoiceByOrders(OrdersArray) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	SupplierInvoice.Ref AS Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Posted
	|	AND SupplierInvoice.Order IN(&PurchaseOrders)
	|	AND SupplierInvoice.OperationKind = VALUE(Enum.OperationTypesSupplierInvoice.AdvanceInvoice)";
	
	Query.SetParameter("PurchaseOrders", OrdersArray);
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

// Procedure generates  nodes content.
//
Procedure FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN TableMaterials.Quantity / TableMaterials.Ref.Quantity * &ProductsQuantity
	|			ELSE TableMaterials.Quantity * TableMaterials.MeasurementUnit.Factor / TableMaterials.Ref.Quantity * &ProductsQuantity
	|		END) AS ExpenseNorm,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	Catalog.BillsOfMaterials.Content AS TableMaterials,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TableMaterials.Ref = &Ref
	|
	|GROUP BY
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	StructureLineNumber";
	
	Query.SetParameter("Ref", StringProducts.TMSpecification);
	Query.SetParameter("ProductsQuantity", StringProducts.TMQuantity);
	
	NodesBillsOfMaterialstack.Add(StringProducts.TMSpecification);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'Recursive item inclusion is found %1 in BOM %2
					|The operation failed.'; 
					|ru = 'В спецификации %2 найдены рекурсивные ссылки %1
					|Операция не выполнена.';
					|pl = 'Włączenie elementu rekurencyjnego znajduje się %1 w specyfikacji materiałowej %2
					|Operacja nie powiodła się.';
					|es_ES = 'Inclusión del artículo recursivo está encontrada %1 en BOM %2
					|Operación fallada.';
					|es_CO = 'Inclusión del artículo recursivo está encontrada %1 en BOM %2
					|Operación fallada.';
					|tr = '%1 Ürün reçetesinde %2 tekrarlayan bir öğe bulundu
					|Operasyon başarısız oldu.';
					|it = 'Inclusione elemento ricorsivo è stato trovato %1 nella Di.Ba. %2
					|L''operazione è fallita.';
					|de = 'Die rekursive Elementeinbindung befindet sich %1 in der Stückliste %2
					|Die Operation  ist fehlgeschlagen.'");
				Raise StringFunctionsClientServer.SubstituteParametersToString(MessageText, Selection.Products, StringProducts.SpecificationCorr);
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			StringProducts.TMQuantity = Selection.ExpenseNorm;
			StringProducts.TMSpecification = Selection.Specification;
			FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack);
		Else
			NewRow = TableProduction.Add();
			FillPropertyValues(NewRow, StringProducts);
			NewRow.TMContentRowType = Selection.ContentRowType;
			NewRow.TMProducts = Selection.Products;
			NewRow.TMCharacteristic = Selection.Characteristic;
			NewRow.TMQuantity = Selection.ExpenseNorm;
			NewRow.TMSpecification = Selection.Specification;
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	
EndProcedure

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

Function GetColumnsStructure(TemporaryTableInventory)
	
	GroupingColumns = "";
	TotalingColumns = "";
	
	For Each Column In TemporaryTableInventory.Columns Do
		
		If Column.Name = "LineNumber" Then
			Continue;
		EndIf;
		
		If Column.ValueType.ContainsType(Type("Number")) Then   
			TotalingColumns = TotalingColumns + Column.Name + ", ";
		Else
			GroupingColumns = GroupingColumns + Column.Name + ", ";
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(GroupingColumns) Then
		StringFunctionsClientServer.DeleteLastCharInString(GroupingColumns, 2);
	EndIf;
	
	If ValueIsFilled(TotalingColumns) Then
		StringFunctionsClientServer.DeleteLastCharInString(TotalingColumns, 2);
	EndIf;
	
	Return New Structure("GroupingColumns, TotalingColumns", GroupingColumns, TotalingColumns);
	
EndFunction

Function DocumentVATRate(DocumentRef) Export
	
	VATRateInv = DriveServer.DocumentVATRate(DocumentRef);
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Expenses");
	VATRateExp = DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
	If ValueIsFilled(VATRateInv) And ValueIsFilled(VATRateExp) Then
		
		If VATRateInv = VATRateExp Then
			Return VATRateInv;
		Else
			Return Catalogs.VATRates.EmptyRef();
		EndIf;
		
	ElsIf ValueIsFilled(VATRateInv) Then
		
		Return VATRateInv;
		
	Else
		
		Return VATRateExp;
		
	EndIf;
	
EndFunction

Function EntryTypes() Export 
	
	EntryTypes = New Array;
	
	EntryTypes.Add(Enums.EntryTypes.InventoryAccountsPayable);
	EntryTypes.Add(Enums.EntryTypes.GoodsInvoicedNotReceivedAccountsPayable);
	EntryTypes.Add(Enums.EntryTypes.GoodsReceivedNotInvoicedAccountsPayable);
	EntryTypes.Add(Enums.EntryTypes.ServicesAccountsPayable);
	EntryTypes.Add(Enums.EntryTypes.AccountsPayableAdvanceToSupplier);
	EntryTypes.Add(Enums.EntryTypes.VATOnAdvancePaymentVAT);
	EntryTypes.Add(Enums.EntryTypes.InventoryRetailMarkup);
	EntryTypes.Add(Enums.EntryTypes.AccountsPayableFXGain);
	EntryTypes.Add(Enums.EntryTypes.AccountsPayableFXLoss);
	EntryTypes.Add(Enums.EntryTypes.GoodsReceivedNotInvoicedDiscrepancyCost);
	EntryTypes.Add(Enums.EntryTypes.DiscrepancyCostAccountsPayable);
	
	Return EntryTypes;
	
EndFunction

Function AccountingFields() Export 
	
	AccountingFields = New Map;
	
	AccountingFields.Insert("InventoryAccountsPayable"					, GetEntriesStructureInventoryAccountsPayable());
	AccountingFields.Insert("GoodsInvoicedNotReceivedAccountsPayable"	, GetEntriesStructureGoodsInvoicedNotReceivedAccountsPayable());
	AccountingFields.Insert("GoodsReceivedNotInvoicedAccountsPayable"	, GetEntriesStructureGoodsReceivedNotInvoicedAccountsPayable());
	AccountingFields.Insert("ServicesAccountsPayable"					, GetEntriesStructureServicesAccountsPayable());
	AccountingFields.Insert("AccountsPayableAdvanceToSupplier"			, GetEntriesStructureAccountsPayableAdvanceToSupplier());
	AccountingFields.Insert("VATOnAdvancePaymentVAT"					, GetEntriesStructureVATOnAdvancePaymentVAT());
	AccountingFields.Insert("InventoryRetailMarkup"						, GetEntriesStructureInventoryRetailMarkup());
	AccountingFields.Insert("AccountsPayableFXGain"						, GetEntriesStructureAccountsPayableFXGain());
	AccountingFields.Insert("AccountsPayableFXLoss"						, GetEntriesStructureAccountsPayableFXLoss());
	AccountingFields.Insert("GoodsReceivedNotInvoicedDiscrepancyCost"	, GetEntriesStructureGoodsReceivedNotInvoicedDiscrepancyCost());
	AccountingFields.Insert("DiscrepancyCostAccountsPayable"			, GetEntriesStructureDiscrepancyCostAccountsPayable());
	
	Return AccountingFields;
	
EndFunction

#Region EntriesStructure

Function GetEntriesStructureMainAdditionalDetails(EntryTypeFields, TaxIncludes = True)
	
	MainDetails = New Structure;
	MainDetails.Insert("Company"				, NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
	MainDetails.Insert("PresentationCurrency"	, NStr("en = 'Presentation currency'; ru = 'Валюта представления отчетности';pl = 'Waluta prezentacji';es_ES = 'Moneda de presentación';es_CO = 'Moneda de presentación';tr = 'Finansal tablo para birimi';it = 'Valuta di presentazione';de = 'Währung für die Berichtserstattung'"));
	
	If TaxIncludes Then
		MainDetails.Insert("VATID", NStr("en = 'VAT ID'; ru = 'Номер плательщика НДС';pl = 'Numer VAT';es_ES = 'Identificador del IVA';es_CO = 'Identificador del IVA';tr = 'KDV kodu';it = 'P.IVA';de = 'USt.- IdNr.'"));
	EndIf;
	
	EntryTypeFields.Insert("MainDetails", MainDetails);
	
	AdditionalDetails = New Structure;
	AdditionalDetails.Insert("Period"			, NStr("en = 'Document date'; ru = 'Дата документа';pl = 'Data dokumentu';es_ES = 'Fecha del documento';es_CO = 'Fecha del documento';tr = 'Belge tarihi';it = 'Data del documento';de = 'Belegdatum'"));
	
	If TaxIncludes Then
		AdditionalDetails.Insert("TaxCategory"	, NStr("en = 'Tax category'; ru = 'Налогообложение';pl = 'Rodzaj opodatkowania VAT';es_ES = 'Categoría de impuestos';es_CO = 'Categoría de impuestos';tr = 'Vergi kategorisi';it = 'Categoria di imposta';de = 'Steuerkategorie'"));
		AdditionalDetails.Insert("TaxRate"		, NStr("en = 'Tax rate'; ru = 'Налоговая ставка';pl = 'Stawka VAT';es_ES = 'Tipo de impuesto';es_CO = 'Tipo de impuesto';tr = 'Vergi oranı';it = 'Aliquota fiscale';de = 'Steuersatz'"));
	EndIf;
	
	EntryTypeFields.Insert("AdditionalDetails", AdditionalDetails);
	
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureInventoryAccountsPayable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureGoodsInvoicedNotReceivedAccountsPayable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureGoodsReceivedNotInvoicedAccountsPayable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureServicesAccountsPayable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"				, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"				, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Expense item'; ru = 'Статья расходов';pl = 'Pozycja rozchodów';es_ES = 'Artículo de gastos';es_CO = 'Artículo de gastos';tr = 'Gider kalemi';it = 'Voce di uscita';de = 'Position von Ausgaben'"));
	DebitDetails.Insert("Department"			, NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	DebitDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails"	, DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Quantity"			, NStr("en = 'Quantity'; ru = 'Количество';pl = 'Ilość';es_ES = 'Cantidad';es_CO = 'Cantidad';tr = 'Miktar';it = 'Quantità';de = 'Menge'"));
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	Amounts.Insert("SettlementsTax"		, NStr("en = 'Tax (Settlement currency)'; ru = 'Налог (Валюта расчетов)';pl = 'VAT (Waluta rozliczeniowa)';es_ES = 'Impuesto (Moneda de liquidación)';es_CO = 'Impuesto (Moneda de liquidación)';tr = 'Vergi (Uzlaşma para birimi)';it = 'Tassa (Valuta di regolamento)';de = 'Steuer (Abrechnungswährung)'"));
	Amounts.Insert("Tax"				, NStr("en = 'Tax (Presentation currency)'; ru = 'Налог (Валюта представления отчетности)';pl = 'VAT (Waluta prezentacji)';es_ES = 'Impuesto (Moneda de presentación)';es_CO = 'Impuesto (Moneda de presentación)';tr = 'Vergi (Finansal tablo para birimi)';it = 'Tassa (Valuta di presentazione)';de = 'Steuer (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsPayableAdvanceToSupplier()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields, False);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"		, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"			, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency", NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"			, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("AdvanceDocument"		, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("SettlementsAmount"	, NStr("en = 'Amount (Settlement currency)'; ru = 'Сумма (Валюта расчетов)';pl = 'Wartość (Waluta rozliczeniowa)';es_ES = 'Importe (Moneda de liquidación)';es_CO = 'Importe (Moneda de liquidación)';tr = 'Tutar (Uzlaşma para birimi)';it = 'Importo (Valuta di regolamento)';de = 'Betrag (Abrechnungswährung)'"));
	Amounts.Insert("Amount"				, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureVATOnAdvancePaymentVAT()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"					, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency"		, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("AdvanceDocument"		, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount"	, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureInventoryRetailMarkup()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount"	, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsPayableFXGain()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	DebitDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	DebitDetails.Insert("Order"					, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	DebitDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	DebitDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Income item'; ru = 'Статья доходов';pl = 'Pozycja dochodów';es_ES = 'Artículo de ingresos';es_CO = 'Artículo de ingresos';tr = 'Gelir kalemi';it = 'Voce di entrata';de = 'Position von Einnahme'"));
	CreditDetails.Insert("Department"			, NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	CreditDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount"	, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureAccountsPayableFXLoss()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("IncomeAndExpenseItem"	, NStr("en = 'Expense item'; ru = 'Статья расходов';pl = 'Pozycja rozchodów';es_ES = 'Artículo de gastos';es_CO = 'Artículo de gastos';tr = 'Gider kalemi';it = 'Voce di uscita';de = 'Position von Ausgaben'"));
	DebitDetails.Insert("Department"			, NStr("en = 'Department'; ru = 'Подразделение';pl = 'Dział';es_ES = 'Departamento';es_CO = 'Departamento';tr = 'Bölüm';it = 'Reparto';de = 'Abteilung'"));
	DebitDetails.Insert("Project"				, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount"	, NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureGoodsReceivedNotInvoicedDiscrepancyCost()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

Function GetEntriesStructureDiscrepancyCostAccountsPayable()
	
	EntryTypeFields = New Structure;
	
	GetEntriesStructureMainAdditionalDetails(EntryTypeFields);
	
	DebitDetails = New Structure;
	
	DebitDetails.Insert("Product"	, NStr("en = 'Product'; ru = 'Номенклатура';pl = 'Produkt';es_ES = 'Producto';es_CO = 'Producto';tr = 'Ürün';it = 'Articolo';de = 'Produkt'"));
	DebitDetails.Insert("Variant"	, NStr("en = 'Variant'; ru = 'Вариант';pl = 'Wariant';es_ES = 'Variante';es_CO = 'Variante';tr = 'Varyant';it = 'Variante';de = 'Variante'"));
	DebitDetails.Insert("Batch"		, NStr("en = 'Batch'; ru = 'Партия';pl = 'Partia';es_ES = 'Lote';es_CO = 'Lote';tr = 'Parti';it = 'Lotto';de = 'Charge'"));
	DebitDetails.Insert("Warehouse"	, NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
	DebitDetails.Insert("Ownership"	, NStr("en = 'Ownership'; ru = 'Владение';pl = 'Własność';es_ES = 'Propiedad';es_CO = 'Propiedad';tr = 'Sahiplik';it = 'Proprietà';de = 'Eigentumsverhältnisse'"));
	DebitDetails.Insert("Project"	, NStr("en = 'Project'; ru = 'Проект';pl = 'Projekt';es_ES = 'Proyecto';es_CO = 'Proyecto';tr = 'Proje';it = 'Progetto';de = 'Projekt'"));
	
	EntryTypeFields.Insert("DebitDetails", DebitDetails);
	
	CreditDetails = New Structure;
	CreditDetails.Insert("Counterparty"			, NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
	CreditDetails.Insert("Contract"				, NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
	CreditDetails.Insert("Order"				, NStr("en = 'Order'; ru = 'Заказ';pl = 'Zamówienie';es_ES = 'Orden';es_CO = 'Orden';tr = 'Sipariş';it = 'Ordine';de = 'Auftrag'"));
	CreditDetails.Insert("SettlementCurrency"	, NStr("en = 'Settlement currency'; ru = 'Валюта расчетов';pl = 'Waluta rozliczeniowa';es_ES = 'Moneda de liquidación';es_CO = 'Moneda de liquidación';tr = 'Uzlaşma para birimi';it = 'Valuta di regolamento';de = 'Abrechnungswährung'"));
	CreditDetails.Insert("Recorder"				, NStr("en = 'Document'; ru = 'Документ';pl = 'Dokument';es_ES = 'Documento';es_CO = 'Documento';tr = 'Belge';it = 'Documento';de = 'Dokument'"));
	
	EntryTypeFields.Insert("CreditDetails", CreditDetails);
	
	Amounts = New Structure;
	Amounts.Insert("Amount", NStr("en = 'Amount (Presentation currency)'; ru = 'Сумма (Валюта представления отчетности)';pl = 'Wartość (Waluta prezentacji)';es_ES = 'Importe (Moneda de presentación)';es_CO = 'Importe (Moneda de presentación)';tr = 'Tutar (Finansal tablo para birimi)';it = 'Importo (Valuta di presentazione)';de = 'Betrag (Währung für die Berichtserstattung)'"));
	
	EntryTypeFields.Insert("Amounts", Amounts);
	
	Return EntryTypeFields;
	
EndFunction

#EndRegion

#EndRegion

#EndIf
