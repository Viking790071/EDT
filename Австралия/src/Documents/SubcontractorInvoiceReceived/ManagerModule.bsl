#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
EndFunction

Procedure FillBySubcontractorOrder(DocumentData, FilterData, Products, Inventory, ByProducts) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SubcontractorOrderIssued.Ref AS Ref
	|INTO TT_SubcontractorOrders
	|FROM
	|	Document.SubcontractorOrderIssued AS SubcontractorOrderIssued
	|WHERE
	|	&SubcontractorOrderIssuedConditions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceipt.Order AS SubcontractorOrder,
	|	GoodsReceiptProducts.Products AS Products,
	|	GoodsReceiptProducts.Characteristic AS Characteristic,
	|	GoodsReceiptProducts.Batch AS Batch,
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) AS QuantityBalance,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryGLAccount
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.GoodsReceipt AS GoodsReceipt
	|		ON TT_SubcontractorOrders.Ref = GoodsReceipt.Order
	|		INNER JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON (GoodsReceipt.Ref = GoodsReceiptProducts.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (GoodsReceiptProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	GoodsReceipt.Posted
	|	AND GoodsReceipt.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReceiptFromSubcontractor)
	|
	|GROUP BY
	|	GoodsReceiptProducts.Characteristic,
	|	GoodsReceiptProducts.Batch,
	|	GoodsReceiptProducts.Products,
	|	GoodsReceipt.Order,
	|	GoodsReceipt.StructuralUnit,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GoodsReceiptProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END
	|
	|HAVING
	|	SUM(GoodsReceiptProducts.Quantity * ISNULL(UOM.Factor, 1)) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	OrdersBalance.SubcontractorOrder AS SubcontractorOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.Batch AS Batch,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Order AS SubcontractorOrder,
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.Batch AS Batch,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.StockTransferredToThirdParties.Balance(
	|				,
	|				Order IN
	|						(SELECT
	|							TT_SubcontractorOrders.Ref
	|						FROM
	|							TT_SubcontractorOrders)
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|					AND Counterparty = &Counterparty) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsTransferredInventory.Order,
	|		DocumentRegisterRecordsTransferredInventory.Products,
	|		DocumentRegisterRecordsTransferredInventory.Characteristic,
	|		DocumentRegisterRecordsTransferredInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsTransferredInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN DocumentRegisterRecordsTransferredInventory.Quantity
	|			ELSE -DocumentRegisterRecordsTransferredInventory.Quantity
	|		END
	|	FROM
	|		AccumulationRegister.StockTransferredToThirdParties AS DocumentRegisterRecordsTransferredInventory
	|	WHERE
	|		DocumentRegisterRecordsTransferredInventory.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.SubcontractorOrder,
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
	|	SubcontractorOrderProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderProducts.Products AS Products,
	|	ProductsCatalog.ProductsType AS ProductsType,
	|	SubcontractorOrderProducts.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SubcontractorOrderProducts.Quantity AS Quantity,
	|	SubcontractorOrderProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderProducts.Ref AS BasisOrder,
	|	SubcontractorOrderProducts.Specification AS Specification,
	|	SubcontractorOrderProducts.Price AS Price,
	|	SubcontractorOrderProducts.Amount AS Amount,
	|	SubcontractorOrderProducts.VATRate AS VATRate,
	|	SubcontractorOrderProducts.VATAmount AS VATAmount,
	|	SubcontractorOrderProducts.Total AS Total
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.SubcontractorOrderIssued.Products AS SubcontractorOrderProducts
	|		ON TT_SubcontractorOrders.Ref = SubcontractorOrderProducts.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorOrderByProducts.LineNumber AS LineNumber,
	|	SubcontractorOrderByProducts.Products AS Products,
	|	SubcontractorOrderByProducts.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SubcontractorOrderByProducts.Quantity AS Quantity,
	|	SubcontractorOrderByProducts.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderByProducts.CostValue AS CostValue,
	|	SubcontractorOrderByProducts.Total AS Total,
	|	SubcontractorOrderByProducts.Ref AS BasisOrder
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.SubcontractorOrderIssued.ByProducts AS SubcontractorOrderByProducts
	|		ON TT_SubcontractorOrders.Ref = SubcontractorOrderByProducts.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderByProducts.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderByProducts.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SubcontractorOrderInventory.LineNumber AS LineNumber,
	|	SubcontractorOrderInventory.Products AS Products,
	|	SubcontractorOrderInventory.Characteristic AS Characteristic,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SubcontractorOrderInventory.Quantity AS Quantity,
	|	SubcontractorOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SubcontractorOrderInventory.Ref AS BasisOrder
	|FROM
	|	TT_SubcontractorOrders AS TT_SubcontractorOrders
	|		INNER JOIN Document.SubcontractorOrderIssued.Inventory AS SubcontractorOrderInventory
	|		ON TT_SubcontractorOrders.Ref = SubcontractorOrderInventory.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SubcontractorOrderInventory.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorOrderInventory.MeasurementUnit = UOM.Ref)
	|WHERE
	|	ProductsCatalog.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("Ref", DocumentData.Ref);
	Query.SetParameter("Counterparty", DocumentData.Counterparty);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	If FilterData.Property("OrdersArray") Then
		FilterString = "SubcontractorOrderIssued.Ref IN(&OrdersArray)";
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
			FilterString = FilterString + "SubcontractorOrderIssued." + FilterItem.Key + " = &" + FilterItem.Key;
			Query.SetParameter(FilterItem.Key, FilterItem.Value);
		EndDo;
	EndIf;
	
	Query.Text = StrReplace(Query.Text, "&SubcontractorOrderIssuedConditions", FilterString);
	
	ResultsArray = Query.ExecuteBatch();
	
	ProductsBalanceTable = ResultsArray[1].Unload();
	ProductsBalanceTable.Indexes.Add("SubcontractorOrder,Products,Characteristic");
	
	InventoryBalanceTable = ResultsArray[2].Unload();
	InventoryBalanceTable.Indexes.Add("SubcontractorOrder,Products,Characteristic");
	
	FillInTabularSection(DocumentData, Products, ResultsArray[3], ProductsBalanceTable);
	FillInTabularSection(DocumentData, ByProducts, ResultsArray[4], ProductsBalanceTable);
	FillInTabularSection(DocumentData, Inventory, ResultsArray[5], InventoryBalanceTable);
	
EndProcedure

Function GetGLAccountsStructure(StructureData) Export
	
	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If StructureData.Property("CounterpartyGLAccounts") Then
		
		GLAccountsForFilling.Insert("AccountsPayableGLAccount", ObjectParameters.AccountsPayableGLAccount);
		GLAccountsForFilling.Insert("AdvancesPaidGLAccount", ObjectParameters.AdvancesPaidGLAccount);
		
	ElsIf StructureData.Property("ProductGLAccounts") Then
		
		If StructureData.TabName = "Inventory" Then
			GLAccountsForFilling.Insert("InventoryTransferredGLAccount", StructureData.InventoryTransferredGLAccount);
		EndIf;
		
		If StructureData.TabName = "Products" Then
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
			GLAccountsForFilling.Insert("VATInputGLAccount", StructureData.VATInputGLAccount);
		EndIf;
		
		If StructureData.TabName = "ByProducts" Then
			GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

Function InventoryOwnershipParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	If Type("DocumentRef.SubcontractorOrderIssued") = TypeOf(DocObject.BasisDocument)
		And ValueIsFilled(DocObject.BasisDocument.OrderReceived) Then 
		
		OrderReceived = DocObject.BasisDocument.OrderReceived;
		
		Parameters = New Structure;
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OrderReceived.Counterparty);
		Parameters.Insert("Contract", OrderReceived.Contract);

		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Products");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OrderReceived.Counterparty);
		Parameters.Insert("Contract", OrderReceived.Contract);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "ByProducts");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.CustomerProvidedInventory);
		Parameters.Insert("Counterparty", OrderReceived.Counterparty);
		Parameters.Insert("Contract", OrderReceived.Contract);
		ParametersSet.Add(Parameters);
	Else 
		Parameters = New Structure;
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "Products");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
		
		Parameters = New Structure;
		Parameters.Insert("TableName", "ByProducts");
		Parameters.Insert("OwnershipType", Enums.InventoryOwnershipTypes.OwnInventory);
		ParametersSet.Add(Parameters);
	EndIf;
	Return ParametersSet;
	
EndFunction

Function BatchCheckFillingParameters(DocObject) Export
	
	ParametersSet = New Array;
	
	#Region BatchCheckFillingParameters_Products
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "Products");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", "StructuralUnit");
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	#Region BatchCheckFillingParameters_ByProducts
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "ByProducts");
	
	Warehouses = New Array;
	
	WarehouseData = New Structure;
	WarehouseData.Insert("Warehouse", "StructuralUnit");
	WarehouseData.Insert("TrackingArea", "Inbound_FromSupplier");
	Warehouses.Add(WarehouseData);
	
	Parameters.Insert("Warehouses", Warehouses);
	
	ParametersSet.Add(Parameters);
	
	#EndRegion
	
	Return ParametersSet;
	
EndFunction

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefSubcontractorInvoice, StructureAdditionalProperties) Export
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRefSubcontractorInvoice,
		"VATTaxation, Counterparty, BasisDocument");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	StructureAdditionalProperties.Insert("DefaultLanguageCode", Metadata.DefaultLanguage.LanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRefSubcontractorInvoice);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",	StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	Query.SetParameter("IsOrderReceived", 		Type("DocumentRef.SubcontractorOrderIssued") = TypeOf(DocumentRefSubcontractorInvoice.BasisDocument)
												And ValueIsFilled(DocumentRefSubcontractorInvoice.BasisDocument.OrderReceived));
	
	Query.Text =
	"SELECT
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Date AS Date,
	|	&Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.SetPaymentTerms AS SetPaymentTerms,
	|	DocumentHeader.BasisDocument AS BasisDocument,
	|	DocumentHeader.StructuralUnit AS StructuralUnit,
	|	DocumentHeader.DocumentCurrency AS DocumentCurrency,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AccountsPayableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AccountsPayableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentHeader.AdvancesPaidGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS AdvancesPaidGLAccount,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.PaymentMethod AS PaymentMethod,
	|	DocumentHeader.PettyCash AS PettyCash,
	|	DocumentHeader.BankAccount AS BankAccount,
	|	DocumentHeader.CashAssetType AS CashAssetType,
	|	DocumentHeader.Responsible AS Responsible
	|INTO InvoiceHeaderTable
	|FROM
	|	Document.SubcontractorInvoiceReceived AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InvoiceHeaderTable.Ref AS Ref,
	|	InvoiceHeaderTable.Date AS Date,
	|	InvoiceHeaderTable.Company AS Company,
	|	InvoiceHeaderTable.CompanyVATNumber AS CompanyVATNumber,
	|	InvoiceHeaderTable.IncludeVATInPrice AS IncludeVATInPrice,
	|	InvoiceHeaderTable.AmountIncludesVAT AS AmountIncludesVAT,
	|	InvoiceHeaderTable.PresentationCurrency AS PresentationCurrency,
	|	InvoiceHeaderTable.Counterparty AS Counterparty,
	|	InvoiceHeaderTable.Contract AS Contract,
	|	InvoiceHeaderTable.ExchangeRate AS ExchangeRate,
	|	InvoiceHeaderTable.Multiplicity AS Multiplicity,
	|	InvoiceHeaderTable.SetPaymentTerms AS SetPaymentTerms,
	|	InvoiceHeaderTable.BasisDocument AS BasisDocument,
	|	InvoiceHeaderTable.StructuralUnit AS StructuralUnit,
	|	InvoiceHeaderTable.DocumentCurrency AS DocumentCurrency,
	|	InvoiceHeaderTable.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	InvoiceHeaderTable.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	InvoiceHeaderTable.AccountsPayableGLAccount AS GLAccountVendorSettlements,
	|	InvoiceHeaderTable.AdvancesPaidGLAccount AS VendorAdvancesGLAccount,
	|	InvoiceHeaderTable.VATTaxation AS VATTaxation,
	|	InvoiceHeaderTable.PaymentMethod AS PaymentMethod,
	|	InvoiceHeaderTable.PettyCash AS PettyCash,
	|	InvoiceHeaderTable.BankAccount AS BankAccount,
	|	InvoiceHeaderTable.CashAssetType AS CashAssetType,
	|	InvoiceHeaderTable.Responsible AS Responsible,
	|	ISNULL(Counterparties.DoOperationsByOrders, FALSE) AS DoOperationsByOrders,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, InvoiceHeaderTable.DocumentCurrency) AS SettlementsCurrency
	|INTO SubcontractorInvoiceHeader
	|FROM
	|	InvoiceHeaderTable AS InvoiceHeaderTable
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON InvoiceHeaderTable.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON InvoiceHeaderTable.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceProducts.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SubcontractorInvoiceHeader.Date AS Period,
	|	SubcontractorInvoiceHeader.Ref AS Document,
	|	SubcontractorInvoiceHeader.Responsible AS Responsible,
	|	SubcontractorInvoiceHeader.Company AS Company,
	|	SubcontractorInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceProducts.StructuralUnit AS StructuralUnit,
	|	SubcontractorInvoiceHeader.DocumentCurrency AS Currency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SubcontractorInvoiceProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorInvoiceProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN SubcontractorInvoiceProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SubcontractorInvoiceProducts.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS InventoryAccountType,
	|	CASE
	|		WHEN &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	SubcontractorInvoiceHeader.BasisDocument AS Order,
	|	SubcontractorInvoiceProducts.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	SubcontractorInvoiceProducts.VATRate AS VATRate,
	|	CAST(SubcontractorInvoiceProducts.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SubcontractorInvoiceHeader.Multiplicity / SubcontractorInvoiceHeader.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceHeader.ExchangeRate / SubcontractorInvoiceHeader.Multiplicity
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(SubcontractorInvoiceProducts.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SubcontractorInvoiceHeader.ContractCurrencyExchangeRate * SubcontractorInvoiceHeader.Multiplicity / (SubcontractorInvoiceHeader.ExchangeRate * SubcontractorInvoiceHeader.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceHeader.ExchangeRate * SubcontractorInvoiceHeader.ContractCurrencyMultiplicity / (SubcontractorInvoiceHeader.ContractCurrencyExchangeRate * SubcontractorInvoiceHeader.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	CAST(CASE
	|			WHEN SubcontractorInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SubcontractorInvoiceProducts.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SubcontractorInvoiceHeader.Multiplicity / SubcontractorInvoiceHeader.ExchangeRate
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceHeader.ExchangeRate / SubcontractorInvoiceHeader.Multiplicity
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorInvoiceHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE SubcontractorInvoiceProducts.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN SubcontractorInvoiceHeader.ContractCurrencyExchangeRate * SubcontractorInvoiceHeader.Multiplicity / (SubcontractorInvoiceHeader.ExchangeRate * SubcontractorInvoiceHeader.ContractCurrencyMultiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN SubcontractorInvoiceHeader.ExchangeRate * SubcontractorInvoiceHeader.ContractCurrencyMultiplicity / (SubcontractorInvoiceHeader.ContractCurrencyExchangeRate * SubcontractorInvoiceHeader.Multiplicity)
	|					ELSE 0
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	SubcontractorInvoiceHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorInvoiceHeader.Contract AS Contract,
	|	SubcontractorInvoiceHeader.SettlementsCurrency AS SettlementsCurrency,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceHeader.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	SubcontractorInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SubcontractorInvoiceHeader.Multiplicity AS Multiplicity,
	|	SubcontractorInvoiceHeader.VATTaxation AS VATTaxation,
	|	CASE
	|		WHEN SubcontractorInvoiceHeader.IncludeVATInPrice
	|			THEN 0
	|		ELSE SubcontractorInvoiceProducts.VATAmount
	|	END AS VATAmountDocCur,
	|	SubcontractorInvoiceProducts.Total AS AmountDocCur,
	|	SubcontractorInvoiceHeader.SetPaymentTerms AS SetPaymentTerms,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceProducts.VATInputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATInputGLAccount
	|INTO TemporaryTableProducts
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Products AS SubcontractorInvoiceProducts
	|		ON SubcontractorInvoiceHeader.Ref = SubcontractorInvoiceProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorInvoiceProducts.MeasurementUnit = UOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (SubcontractorInvoiceProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON SubcontractorInvoiceHeader.StructuralUnit = BatchTrackingPolicy.StructuralUnit
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceHeader.Date AS Period,
	|	SubcontractorInvoiceHeader.Company AS Company,
	|	SubcontractorInvoiceInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorInvoiceInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN SubcontractorInvoiceInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SubcontractorInvoiceInventory.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.ComponentsForSubcontractor) AS InventoryAccountType,
	|	SubcontractorInvoiceHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceHeader.BasisDocument AS Order,
	|	SubcontractorInvoiceInventory.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceInventory.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryTransferredGLAccount
	|INTO TemporaryTableInventory
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Inventory AS SubcontractorInvoiceInventory
	|		ON SubcontractorInvoiceHeader.Ref = SubcontractorInvoiceInventory.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorInvoiceInventory.MeasurementUnit = UOM.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceHeader.Date AS Period,
	|	SubcontractorInvoiceHeader.Company AS Company,
	|	SubcontractorInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceHeader.Contract AS Contract,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceHeader.GLAccountVendorSettlements
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountVendorSettlements,
	|	SubcontractorInvoiceHeader.BasisDocument AS Order,
	|	SubcontractorInvoiceByProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN SubcontractorInvoiceByProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN SubcontractorInvoiceByProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	SubcontractorInvoiceByProducts.Ownership AS Ownership,
	|	VALUE(Enum.InventoryAccountTypes.ComponentsForSubcontractor) AS InventoryAccountType,
	|	SubcontractorInvoiceByProducts.Quantity * ISNULL(UOM.Factor, 1) AS Quantity,
	|	SubcontractorInvoiceByProducts.CostValue AS CostValue,
	|	SubcontractorInvoiceByProducts.Total AS Total,
	|	CAST(SubcontractorInvoiceByProducts.Total * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN SubcontractorInvoiceHeader.ContractCurrencyExchangeRate / SubcontractorInvoiceHeader.ContractCurrencyMultiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SubcontractorInvoiceHeader.ContractCurrencyMultiplicity / SubcontractorInvoiceHeader.ContractCurrencyExchangeRate
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS TotalCur,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN SubcontractorInvoiceByProducts.InventoryGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	SubcontractorInvoiceByProducts.StructuralUnit AS StructuralUnit
	|INTO TemporaryTableByProducts
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.ByProducts AS SubcontractorInvoiceByProducts
	|		ON SubcontractorInvoiceHeader.Ref = SubcontractorInvoiceByProducts.Ref
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SubcontractorInvoiceByProducts.MeasurementUnit = UOM.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (SubcontractorInvoiceByProducts.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (SubcontractorInvoiceByProducts.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceHeader.Ref AS Ref,
	|	SubcontractorInvoiceHeader.Date AS Period,
	|	SubcontractorInvoiceHeader.Company AS Company,
	|	SubcontractorInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceHeader.DocumentCurrency AS Currency,
	|	SubcontractorInvoiceHeader.Responsible AS Responsible,
	|	SubcontractorInvoiceHeader.BasisDocument AS Order,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.GLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccount,
	|	TableAllocation.StructuralUnit AS StructuralUnit,
	|	TableAllocation.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableAllocation.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (NOT TableAllocation.IsByProduct
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CostObject,
	|	CASE
	|		WHEN TableAllocation.IsByProduct
	|			THEN CASE
	|					WHEN &IsOrderReceived
	|						THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|					ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|				END
	|		ELSE VALUE(Enum.InventoryAccountTypes.ComponentsForSubcontractor)
	|	END AS InventoryAccountType,
	|	TableAllocation.CorrProducts AS CorrProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableAllocation.CorrCharacteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CorrCharacteristic,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPoliciesCorr.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN TableAllocation.CorrBatch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS CorrBatch,
	|	TableAllocation.CorrOwnership AS CorrOwnership,
	|	VALUE(Catalog.CostObjects.EmptyRef) AS CorrCostObject,
	|	CASE
	|		WHEN &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN TableAllocation.CorrGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CorrGLAccount,
	|	TableAllocation.CorrStructuralUnit AS CorrStructuralUnit,
	|	TableAllocation.IsByProduct AS IsByProduct,
	|	TableAllocation.Specification AS Specification,
	|	TableAllocation.Quantity AS Quantity,
	|	TableAllocation.CorrQuantity AS CorrQuantity
	|INTO TemporaryTableAllocation
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Allocation AS TableAllocation
	|		ON SubcontractorInvoiceHeader.Ref = TableAllocation.Ref
	|		INNER JOIN Catalog.Products AS CatalogProductsCorr
	|		ON (TableAllocation.CorrProducts = CatalogProductsCorr.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategoriesCorr
	|		ON (CatalogProductsCorr.ProductsCategory = ProductsCategoriesCorr.Ref)
	|			AND (CatalogProductsCorr.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicyCorr
	|		ON (TableAllocation.StructuralUnit = BatchTrackingPolicyCorr.StructuralUnit)
	|			AND (ProductsCategoriesCorr.BatchSettings = BatchTrackingPolicyCorr.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPoliciesCorr
	|		ON (BatchTrackingPolicyCorr.Policy = BatchTrackingPoliciesCorr.Ref)
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON (TableAllocation.Products = CatalogProducts.Ref)
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (TableAllocation.StructuralUnit = BatchTrackingPolicy.StructuralUnit)
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllocation.Period AS Period,
	|	TableAllocation.Company AS Company,
	|	TableAllocation.PresentationCurrency AS PresentationCurrency,
	|	TableAllocation.Counterparty AS Counterparty,
	|	TableAllocation.Currency AS Currency,
	|	TableAllocation.Ref AS Document,
	|	TableAllocation.Responsible AS Responsible,
	|	TableAllocation.Order AS Order,
	|	TableAllocation.StructuralUnit AS StructuralUnit,
	|	TableAllocation.GLAccount AS GLAccount,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.Batch AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	TableAllocation.CostObject AS CostObject,
	|	TableAllocation.InventoryAccountType AS InventoryAccountType,
	|	SUM(TableAllocation.Quantity) AS Quantity,
	|	SUM(CASE
	|			WHEN TableAllocation.Quantity = TableByProducts.Quantity
	|				THEN TableByProducts.Total
	|			ELSE CAST(TableByProducts.Total * TableAllocation.Quantity / TableByProducts.Quantity AS NUMBER(15, 2))
	|		END) AS Amount,
	|	CAST(SUM(CASE
	|				WHEN TableAllocation.Quantity = TableByProducts.Quantity
	|					THEN TableByProducts.Total
	|				ELSE CAST(TableByProducts.Total * TableAllocation.Quantity / TableByProducts.Quantity AS NUMBER(15, 2))
	|			END * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN SubcontractorInvoiceHeader.ContractCurrencyExchangeRate / SubcontractorInvoiceHeader.ContractCurrencyMultiplicity
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SubcontractorInvoiceHeader.ContractCurrencyMultiplicity / SubcontractorInvoiceHeader.ContractCurrencyExchangeRate
	|				ELSE 0
	|			END) AS NUMBER(15, 2)) AS AmountCur,
	|	TableAllocation.CorrProducts AS CorrProducts,
	|	TableAllocation.CorrCharacteristic AS CorrCharacteristic,
	|	TableAllocation.CorrBatch AS CorrBatch,
	|	CASE
	|		WHEN &IsOrderReceived
	|			THEN VALUE(Enum.InventoryAccountTypes.CustomerOwnedComponents)
	|		ELSE VALUE(Enum.InventoryAccountTypes.InventoryOnHand)
	|	END AS CorrInventoryAccountType,
	|	TableAllocation.CorrOwnership AS CorrOwnership,
	|	TableAllocation.CorrCostObject AS CorrCostObject,
	|	TableAllocation.CorrGLAccount AS CorrGLAccount,
	|	TableAllocation.CorrStructuralUnit AS CorrStructuralUnit,
	|	SUM(TableAllocation.CorrQuantity) AS CorrQuantity
	|INTO TemporaryTableByProductsAllocation
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN TemporaryTableAllocation AS TableAllocation
	|		ON SubcontractorInvoiceHeader.Ref = TableAllocation.Ref
	|		LEFT JOIN TemporaryTableByProducts AS TableByProducts
	|		ON (TableAllocation.Products = TableByProducts.Products)
	|			AND (TableAllocation.Characteristic = TableByProducts.Characteristic)
	|			AND (TableAllocation.Batch = TableByProducts.Batch)
	|			AND (TableAllocation.Ownership = TableByProducts.Ownership)
	|			AND (TableAllocation.StructuralUnit = TableByProducts.StructuralUnit)
	|			AND (TableAllocation.GLAccount = TableByProducts.GLAccount)
	|WHERE
	|	TableAllocation.IsByProduct
	|
	|GROUP BY
	|	TableAllocation.StructuralUnit,
	|	TableAllocation.Company,
	|	TableAllocation.Characteristic,
	|	TableAllocation.Currency,
	|	TableAllocation.Ref,
	|	TableAllocation.Responsible,
	|	TableAllocation.Period,
	|	TableAllocation.Counterparty,
	|	TableAllocation.GLAccount,
	|	TableAllocation.PresentationCurrency,
	|	TableAllocation.Products,
	|	TableAllocation.Batch,
	|	TableAllocation.Ownership,
	|	TableAllocation.CostObject,
	|	TableAllocation.InventoryAccountType,
	|	TableAllocation.CorrStructuralUnit,
	|	TableAllocation.CorrCharacteristic,
	|	TableAllocation.CorrGLAccount,
	|	TableAllocation.CorrProducts,
	|	TableAllocation.CorrBatch,
	|	TableAllocation.CorrInventoryAccountType,
	|	TableAllocation.CorrOwnership,
	|	TableAllocation.CorrCostObject,
	|	TableAllocation.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Prepayment.LineNumber) AS LineNumber,
	|	SubcontractorInvoiceHeader.Date AS Period,
	|	SubcontractorInvoiceHeader.Company AS Company,
	|	SubcontractorInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoiceHeader.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceHeader.Counterparty AS Counterparty,
	|	SubcontractorInvoiceHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	SubcontractorInvoiceHeader.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	SubcontractorInvoiceHeader.VendorAdvancesGLAccount AS VendorAdvancesGLAccount,
	|	SubcontractorInvoiceHeader.Contract AS Contract,
	|	SubcontractorInvoiceHeader.SettlementsCurrency AS SettlementsCurrency,
	|	Prepayment.Order AS Order,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLineSales,
	|	VALUE(Enum.SettlementsTypes.Advance) AS SettlementsType,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS DocumentWhere,
	|	Prepayment.Document AS Document,
	|	SubcontractorInvoiceHeader.BasisDocument AS BasisDocument,
	|	CASE
	|		WHEN VALUETYPE(Prepayment.Document) = TYPE(Document.ExpenseReport)
	|				OR VALUETYPE(Prepayment.Document) = TYPE(Document.ArApAdjustments)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|		ELSE CASE
	|				WHEN Prepayment.Document REFS Document.PaymentExpense
	|					THEN CAST(Prepayment.Document AS Document.PaymentExpense).Item
	|				WHEN Prepayment.Document REFS Document.PaymentReceipt
	|					THEN CAST(Prepayment.Document AS Document.PaymentReceipt).Item
	|				WHEN Prepayment.Document REFS Document.CashReceipt
	|					THEN CAST(Prepayment.Document AS Document.CashReceipt).Item
	|				WHEN Prepayment.Document REFS Document.CashVoucher
	|					THEN CAST(Prepayment.Document AS Document.CashVoucher).Item
	|				ELSE VALUE(Catalog.CashFlowItems.PaymentToVendor)
	|			END
	|	END AS Item,
	|	CASE
	|		WHEN Prepayment.Document REFS Document.PaymentExpense
	|			THEN CAST(Prepayment.Document AS Document.PaymentExpense).Date
	|		WHEN Prepayment.Document REFS Document.PaymentReceipt
	|			THEN CAST(Prepayment.Document AS Document.PaymentReceipt).Date
	|		WHEN Prepayment.Document REFS Document.CashReceipt
	|			THEN CAST(Prepayment.Document AS Document.CashReceipt).Date
	|		WHEN Prepayment.Document REFS Document.CashVoucher
	|			THEN CAST(Prepayment.Document AS Document.CashVoucher).Date
	|		WHEN Prepayment.Document REFS Document.ExpenseReport
	|			THEN CAST(Prepayment.Document AS Document.ExpenseReport).Date
	|		WHEN Prepayment.Document REFS Document.ArApAdjustments
	|			THEN CAST(Prepayment.Document AS Document.ArApAdjustments).Date
	|	END AS DocumentDate,
	|	SUM(Prepayment.PaymentAmount) AS Amount,
	|	SUM(Prepayment.SettlementsAmount) AS AmountCur,
	|	SubcontractorInvoiceHeader.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepayment
	|FROM
	|	SubcontractorInvoiceHeader AS SubcontractorInvoiceHeader
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Prepayment AS Prepayment
	|		ON SubcontractorInvoiceHeader.Ref = Prepayment.Ref
	|
	|GROUP BY
	|	SubcontractorInvoiceHeader.Date,
	|	SubcontractorInvoiceHeader.Company,
	|	SubcontractorInvoiceHeader.CompanyVATNumber,
	|	SubcontractorInvoiceHeader.PresentationCurrency,
	|	SubcontractorInvoiceHeader.Counterparty,
	|	SubcontractorInvoiceHeader.DoOperationsByOrders,
	|	SubcontractorInvoiceHeader.GLAccountVendorSettlements,
	|	SubcontractorInvoiceHeader.SettlementsCurrency,
	|	Prepayment.Order,
	|	SubcontractorInvoiceHeader.BasisDocument,
	|	SubcontractorInvoiceHeader.Contract,
	|	SubcontractorInvoiceHeader.VendorAdvancesGLAccount,
	|	Prepayment.Document,
	|	SubcontractorInvoiceHeader.SetPaymentTerms
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
	|	Header.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTablePrepaymentVAT
	|FROM
	|	SubcontractorInvoiceHeader AS Header
	|		INNER JOIN Document.SubcontractorInvoiceReceived.PrepaymentVAT AS PrepaymentVAT
	|		ON Header.Ref = PrepaymentVAT.Ref
	|		INNER JOIN Catalog.VATRates AS CatalogVATRates
	|		ON (PrepaymentVAT.VATRate = CatalogVATRates.Ref)
	|			AND (NOT CatalogVATRates.NotTaxable)
	|
	|GROUP BY
	|	Header.Company,
	|	Header.CompanyVATNumber,
	|	Header.PresentationCurrency,
	|	Header.Date,
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
	|	PaymentCalendar.LineNumber AS LineNumber,
	|	PaymentCalendar.Ref AS Ref,
	|	PaymentCalendar.PaymentDate AS Period,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.PresentationCurrency AS PresentationCurrency,
	|	Header.Counterparty AS Counterparty,
	|	Header.DoOperationsByOrders AS DoOperationsByOrders,
	|	Header.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	Header.Contract AS Contract,
	|	Header.SettlementsCurrency AS SettlementsCurrency,
	|	Header.Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	Header.BasisDocument AS Order,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN PaymentCalendar.PaymentAmount
	|			ELSE PaymentCalendar.PaymentAmount + PaymentCalendar.PaymentVATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.Multiplicity / Header.ExchangeRate
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate / Header.Multiplicity
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN Header.AmountIncludesVAT
	|				THEN PaymentCalendar.PaymentAmount
	|			ELSE PaymentCalendar.PaymentAmount + PaymentCalendar.PaymentVATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Header.ContractCurrencyExchangeRate * Header.Multiplicity / (Header.ExchangeRate * Header.ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Header.ExchangeRate * Header.ContractCurrencyMultiplicity / (Header.ContractCurrencyExchangeRate * Header.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	Header.PaymentMethod AS PaymentMethod,
	|	Header.PettyCash AS PettyCash,
	|	Header.BankAccount AS BankAccount,
	|	Header.CashAssetType AS CashAssetType,
	|	PaymentCalendar.PaymentBaselineDate AS PaymentBaselineDate
	|INTO TemporaryTablePaymentCalendarPre
	|FROM
	|	SubcontractorInvoiceHeader AS Header
	|		INNER JOIN Document.SubcontractorInvoiceReceived.PaymentCalendar AS PaymentCalendar
	|		ON Header.Ref = PaymentCalendar.Ref
	|			AND (Header.SetPaymentTerms)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Ref AS Ref,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.CompanyVATNumber AS CompanyVATNumber,
	|	Calendar.PresentationCurrency AS PresentationCurrency,
	|	Calendar.Counterparty AS Counterparty,
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
	|	Calendar.PaymentMethod AS PaymentMethod,
	|	Calendar.PettyCash AS PettyCash,
	|	Calendar.BankAccount AS BankAccount,
	|	Calendar.CashAssetType AS CashAssetType,
	|	Calendar.PaymentBaselineDate AS PaymentBaselineDate,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarPre AS Calendar
	|
	|GROUP BY
	|	Calendar.Ref,
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.CompanyVATNumber,
	|	Calendar.PresentationCurrency,
	|	Calendar.Counterparty,
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
	|	Calendar.Order,
	|	Calendar.PaymentMethod,
	|	Calendar.PettyCash,
	|	Calendar.BankAccount,
	|	Calendar.CashAssetType,
	|	Calendar.PaymentBaselineDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarPre";
	
	Query.ExecuteBatch();
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	
	GenerateTableCostOfSubcontractorGoods(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTablePurchases(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableAccountsPayable(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableStockTransferredToThirdParties(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableGoodsReceivedNotInvoiced(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableLandedCosts(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	EndIf;
	
	//VAT
	GenerateTableVATIncurred(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	GenerateTableVATInput(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
		
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
		Or StructureTemporaryTables.RegisterRecordsSuppliersSettlementsChange
		Or StructureTemporaryTables.RegisterRecordsVATIncurredChange
		Or StructureTemporaryTables.RegisterRecordsStockTransferredToThirdPartiesChange 
		Or StructureTemporaryTables.RegisterRecordsGoodsReceivedNotInvoicedChange Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
		|	RegisterRecordsInventoryChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
		|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	RegisterRecordsInventoryChange.QuantityChange + InventoryBalances.QuantityBalance AS BalanceInventory,
		|	InventoryBalances.QuantityBalance AS QuantityBalanceInventory,
		|	InventoryBalances.AmountBalance AS AmountBalanceInventory
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
		|			AND RegisterRecordsInventoryChange.CostObject = InventoryBalances.CostObject
		|			AND (InventoryBalances.QuantityBalance < 0)
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
		|	RegisterRecordsSuppliersSettlementsChange.SumCurOnWrite - AccountsPayableBalances.AmountCurBalance AS AdvanceAmountsPaid,
		|	RegisterRecordsSuppliersSettlementsChange.SumCurChange + AccountsPayableBalances.AmountCurBalance AS AmountOfOutstandingDebt,
		|	AccountsPayableBalances.AmountBalance AS AmountBalance,
		|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance,
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
		|					THEN AccountsPayableBalances.AmountCurBalance > 0
		|				ELSE AccountsPayableBalances.AmountCurBalance < 0
		|			END)
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockTransferredToThirdPartiesChange.LineNumber AS LineNumber,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Company AS CompanyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Products AS ProductsPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Batch AS BatchPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsStockTransferredToThirdPartiesChange.Order AS OrderPresentation,
		|	StockTransferredToThirdPartiesBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockTransferredToThirdPartiesChange.QuantityChange, 0) + ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockTransferredToThirdParties,
		|	ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockTransferredToThirdParties
		|FROM
		|	RegisterRecordsStockTransferredToThirdPartiesChange AS RegisterRecordsStockTransferredToThirdPartiesChange
		|		INNER JOIN AccumulationRegister.StockTransferredToThirdParties.Balance(&ControlTime, ) AS StockTransferredToThirdPartiesBalances
		|		ON RegisterRecordsStockTransferredToThirdPartiesChange.Company = StockTransferredToThirdPartiesBalances.Company
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Products = StockTransferredToThirdPartiesBalances.Products
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Characteristic = StockTransferredToThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Batch = StockTransferredToThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Counterparty = StockTransferredToThirdPartiesBalances.Counterparty
		|			AND RegisterRecordsStockTransferredToThirdPartiesChange.Order = StockTransferredToThirdPartiesBalances.Order
		|			AND (ISNULL(StockTransferredToThirdPartiesBalances.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber";
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.GoodsReceivedNotInvoiced.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			Or Not ResultsArray[1].IsEmpty()
			Or Not ResultsArray[2].IsEmpty()
			Or Not ResultsArray[4].IsEmpty()
			Or Not ResultsArray[5].IsEmpty() Then
			DocumentObject = DocumentRef.GetObject()
		EndIf;
		
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToAccountsPayableRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel);
		EndIf;
		
		If Not ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(
				DocumentObject,
				QueryResultSelection,
				Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	Return New Structure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
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

#Region Private

#Region TableGeneration

Procedure GenerateTableInventory(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableAllocation.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableAllocation.Company AS Company,
	|	TableAllocation.PresentationCurrency AS PresentationCurrency,
	|	TableAllocation.Counterparty AS Counterparty,
	|	TableAllocation.Order AS Order,
	|	TableAllocation.Currency AS Currency,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	TableAllocation.Order AS SourceDocument,
	|	TableAllocation.Responsible AS Responsible,
	|	CASE
	|		WHEN TableAllocation.IsByProduct
	|			THEN TableAllocation.StructuralUnit
	|		ELSE TableAllocation.Counterparty
	|	END AS StructuralUnit,
	|	TableAllocation.GLAccount AS GLAccount,
	|	TableAllocation.Products AS Products,
	|	TableAllocation.Characteristic AS Characteristic,
	|	TableAllocation.Batch AS Batch,
	|	TableAllocation.Ownership AS Ownership,
	|	TableAllocation.CostObject AS CostObject,
	|	TableAllocation.InventoryAccountType AS InventoryAccountType,
	|	TableAllocation.CorrStructuralUnit AS StructuralUnitCorr,
	|	TableAllocation.CorrGLAccount AS CorrGLAccount,
	|	TableAllocation.CorrProducts AS ProductsCorr,
	|	TableAllocation.CorrCharacteristic AS CharacteristicCorr,
	|	TableAllocation.CorrBatch AS BatchCorr,
	|	TableAllocation.CorrOwnership AS OwnershipCorr,
	|	TableAllocation.CorrCostObject AS CostObjectCorr,
	|	TableAllocation.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	TableAllocation.Quantity AS Quantity,
	|	0 AS Amount,
	|	TableAllocation.CorrGLAccount AS AccountDr,
	|	TableAllocation.GLAccount AS AccountCr,
	|	&ReceiptFromSubcontractor AS Content,
	|	&ReceiptFromSubcontractor AS ContentOfAccountingRecord,
	|	FALSE AS FixedCost,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableAllocation AS TableAllocation
	|WHERE
	|	NOT TableAllocation.IsByProduct
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProducts.Period AS Period,
	|	TableProducts.RecordType AS RecordType,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Currency AS Currency,
	|	TableProducts.Document AS SourceDocument,
	|	TableProducts.Responsible AS Responsible,
	|	TableProducts.StructuralUnit AS StructuralUnit,
	|	TableProducts.GLAccount AS GLAccount,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	TableProducts.Ownership AS Ownership,
	|	TableProducts.CostObject AS CostObject,
	|	TableProducts.InventoryAccountType AS InventoryAccountType,
	|	0 AS Quantity,
	|	SUM(TableProducts.Quantity) AS QuantityInDoc,
	|	TableProducts.VATRate AS VATRate,
	|	SUM(TableProducts.Amount - TableProducts.VATAmount) AS Amount,
	|	&ReceiptFromSubcontractor AS ContentOfAccountingRecord,
	|	TRUE AS FixedCost
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|GROUP BY
	|	TableProducts.Characteristic,
	|	TableProducts.Batch,
	|	TableProducts.Ownership,
	|	TableProducts.CostObject,
	|	TableProducts.InventoryAccountType,
	|	TableProducts.Products,
	|	TableProducts.VATRate,
	|	TableProducts.GLAccount,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Currency,
	|	TableProducts.StructuralUnit,
	|	TableProducts.Counterparty,
	|	TableProducts.Company,
	|	TableProducts.Document,
	|	TableProducts.Period,
	|	TableProducts.Responsible,
	|	TableProducts.RecordType
	|
	|UNION ALL
	|
	|SELECT
	|	TableByProductsAllocation.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableByProductsAllocation.Company,
	|	TableByProductsAllocation.PresentationCurrency,
	|	TableByProductsAllocation.Counterparty,
	|	TableByProductsAllocation.Currency,
	|	TableByProductsAllocation.Document,
	|	TableByProductsAllocation.Responsible,
	|	TableByProductsAllocation.StructuralUnit,
	|	TableByProductsAllocation.GLAccount,
	|	TableByProductsAllocation.Products,
	|	TableByProductsAllocation.Characteristic,
	|	TableByProductsAllocation.Batch,
	|	TableByProductsAllocation.Ownership,
	|	TableByProductsAllocation.CostObject,
	|	TableByProductsAllocation.InventoryAccountType,
	|	0,
	|	TableByProductsAllocation.Quantity,
	|	UNDEFINED,
	|	TableByProductsAllocation.Amount,
	|	&ReceiptFromSubcontractor,
	|	TRUE
	|FROM
	|	TemporaryTableByProductsAllocation AS TableByProductsAllocation
	|
	|UNION ALL
	|
	|SELECT
	|	TableByProductsAllocation.Period,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableByProductsAllocation.Company,
	|	TableByProductsAllocation.PresentationCurrency,
	|	TableByProductsAllocation.Counterparty,
	|	TableByProductsAllocation.Currency,
	|	TableByProductsAllocation.Document,
	|	TableByProductsAllocation.Responsible,
	|	TableByProductsAllocation.CorrStructuralUnit,
	|	TableByProductsAllocation.CorrGLAccount,
	|	TableByProductsAllocation.CorrProducts,
	|	TableByProductsAllocation.CorrCharacteristic,
	|	TableByProductsAllocation.CorrBatch,
	|	TableByProductsAllocation.CorrOwnership,
	|	TableByProductsAllocation.CorrCostObject,
	|	TableByProductsAllocation.CorrInventoryAccountType,
	|	0,
	|	TableByProductsAllocation.CorrQuantity,
	|	UNDEFINED,
	|	-TableByProductsAllocation.Amount,
	|	&ReceiptFromSubcontractor,
	|	TRUE
	|FROM
	|	TemporaryTableByProductsAllocation AS TableByProductsAllocation";
	
	Query.SetParameter("ReceiptFromSubcontractor",
		NStr("en = 'Receipt from the subcontractor'; ru = 'Поступление от переработчика';pl = 'Przyjęcie od podwykonawcy';es_ES = 'Recepción del subcontratista';es_CO = 'Recepción del subcontratista';tr = 'Alt yüklenici fişi';it = 'Ricevuta da parte del subfornitore';de = 'Eingang vom Subunternehmer'", StructureAdditionalProperties.DefaultLanguageCode));
	
	QueryResult = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", QueryResult[0].Unload());
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	TableSubcontractorGoods = StructureAdditionalProperties.TableForRegisterRecords.TableCostOfSubcontractorGoods.CopyColumns();
	
	TableProducts = QueryResult[1].Unload();
	
	If Not FillAmount Then
		
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
			
			RowSubcontractorGoods = TableSubcontractorGoods.Add();
			FillPropertyValues(RowSubcontractorGoods, RowTableInventory);
			RowSubcontractorGoods.FinishedProducts = RowTableInventory.ProductsCorr;
			RowSubcontractorGoods.FinishedProductsCharacteristic = RowTableInventory.CharacteristicCorr;
			RowSubcontractorGoods.SubcontractorOrder = RowTableInventory.Order;
			
		EndDo;
		
	Else
	
		// Setting the exclusive lock for the controlled inventory balances.
		Query.Text =
		"SELECT
		|	TableAllocation.Company AS Company,
		|	TableAllocation.PresentationCurrency AS PresentationCurrency,
		|	TableAllocation.Counterparty AS StructuralUnit,
		|	TableAllocation.Products AS Products,
		|	TableAllocation.Characteristic AS Characteristic,
		|	TableAllocation.Batch AS Batch,
		|	TableAllocation.Ownership AS Ownership,
		|	TableAllocation.CostObject AS CostObject,
		|	TableAllocation.InventoryAccountType AS InventoryAccountType
		|FROM
		|	TemporaryTableAllocation AS TableAllocation
		|WHERE
		|	NOT TableAllocation.IsByProduct
		|
		|GROUP BY
		|	TableAllocation.Company,
		|	TableAllocation.PresentationCurrency,
		|	TableAllocation.Counterparty,
		|	TableAllocation.Products,
		|	TableAllocation.Characteristic,
		|	TableAllocation.Batch,
		|	TableAllocation.Ownership,
		|	TableAllocation.CostObject,
		|	TableAllocation.InventoryAccountType";
		
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
		|	InventoryBalances.InventoryAccountType AS InventoryAccountType,
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
		|		InventoryBalances.InventoryAccountType AS InventoryAccountType,
		|		InventoryBalances.QuantityBalance AS QuantityBalance,
		|		InventoryBalances.AmountBalance AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject) IN
		|					(SELECT
		|						TableAllocation.Company,
		|						TableAllocation.PresentationCurrency,
		|						TableAllocation.Counterparty,
		|						TableAllocation.InventoryAccountType,
		|						TableAllocation.Products,
		|						TableAllocation.Characteristic,
		|						TableAllocation.Batch,
		|						TableAllocation.Ownership,
		|						TableAllocation.CostObject
		|					FROM
		|						TemporaryTableAllocation AS TableAllocation
		|					WHERE
		|						NOT TableAllocation.IsByProduct)) AS InventoryBalances
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
		|		DocumentRegisterRecordsInventory.InventoryAccountType,
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
		|	InventoryBalances.CostObject,
		|	InventoryBalances.InventoryAccountType";
		
		Query.SetParameter("Ref", DocumentRefSubcontractorInvoice);
		Query.SetParameter("ControlTime",
			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalances = QueryResult.Unload();
		TableInventoryBalances.Indexes.Add(
			"Company, PresentationCurrency, StructuralUnit, InventoryAccountType, Products, Characteristic, Batch, Ownership, CostObject");
		
	UseDefaultTypeOfAccounting = StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting;
		
		TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();
		For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
			
			RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
			
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
			
			QuantityWanted = RowTableInventory.Quantity;
			
			If QuantityWanted > 0 Then
				
				BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
				
				QuantityBalance = 0;
				AmountBalance = 0;
				
				If BalanceRowsArray.Count() > 0 Then
					QuantityBalance = BalanceRowsArray[0].QuantityBalance;
					AmountBalance = BalanceRowsArray[0].AmountBalance;
				EndIf;
				
				If QuantityBalance > 0 And QuantityBalance > QuantityWanted Then
					
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
				
				TableRowExpense = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowExpense, RowTableInventory);
				
				TableRowExpense.Amount = AmountToBeWrittenOff;
				TableRowExpense.Quantity = QuantityWanted;
				
				RowSubcontractorGoods = TableSubcontractorGoods.Add();
				FillPropertyValues(RowSubcontractorGoods, TableRowExpense);
				RowSubcontractorGoods.FinishedProducts = TableRowExpense.ProductsCorr;
				RowSubcontractorGoods.FinishedProductsCharacteristic = TableRowExpense.CharacteristicCorr;
				RowSubcontractorGoods.SubcontractorOrder = RowTableInventory.Order;
				
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					
					If UseDefaultTypeOfAccounting Then
						
						RowEntries = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
						FillPropertyValues(RowEntries, RowTableInventory);
						RowEntries.Amount = AmountToBeWrittenOff;
						
					EndIf;
					
					TableRowReceipt = TemporaryTableInventory.Add();
					FillPropertyValues(TableRowReceipt,
						RowTableInventory,
						,
						"ProductsCorr, CharacteristicCorr, BatchCorr, OwnershipCorr, CostObjectCorr,
						|CorrGLAccount, StructuralUnitCorr, CorrInventoryAccountType, SourceDocument");
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Ownership = RowTableInventory.OwnershipCorr;
					TableRowReceipt.CostObject = RowTableInventory.CostObjectCorr;
					TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.InventoryAccountType = RowTableInventory.CorrInventoryAccountType;
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
		StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
		
	EndIf;
	
	For Each Row In TableProducts Do
		
		InventoryRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(InventoryRow, Row);
		InventoryRow.OfflineRecord = False;
		
	EndDo;
	
	TableSubcontractorGoods.GroupBy(
		"Period,
		|Company,
		|PresentationCurrency,
		|Counterparty,
		|SubcontractorOrder,
		|FinishedProducts,
		|FinishedProductsCharacteristic,
		|Products,
		|Characteristic",
		"Quantity, Amount");
	
	For Each Row In TableSubcontractorGoods Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableCostOfSubcontractorGoods.Add();
		FillPropertyValues(NewRow, Row);
	EndDo;
	
	AddOfflineRecords(DocumentRefSubcontractorInvoice, StructureAdditionalProperties);
	
EndProcedure

Procedure GenerateTablePaymentCalendar(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("NetDates", PaymentTermsServer.NetPaymentDates());
	Query.Text =
	"SELECT
	|	PaymentCalendar.Period AS Period,
	|	PaymentCalendar.Company AS Company,
	|	PaymentCalendar.PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	PaymentCalendar.SettlementsCurrency AS Currency,
	|	-PaymentCalendar.AmountCur AS Amount
	|FROM
	|	TemporaryTablePaymentCalendar AS PaymentCalendar
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|WHERE
	|	PaymentCalendar.PaymentBaselineDate IN(&NetDates)";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTablePurchases(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
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
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	TablePurchases.Ownership AS Ownership,
	|	TablePurchases.Order AS PurchaseOrder,
	|	TablePurchases.Document AS Document,
	|	TablePurchases.VATRate AS VATRate,
	|	SUM(TablePurchases.Quantity) AS Quantity,
	|	SUM(TablePurchases.VATAmount) AS VATAmount,
	|	SUM(TablePurchases.Amount - TablePurchases.VATAmount) AS Amount,
	|	SUM(TablePurchases.VATAmountDocCur) AS VATAmountCur,
	|	SUM(TablePurchases.AmountDocCur - TablePurchases.VATAmountDocCur) AS AmountCur
	|FROM
	|	TemporaryTableProducts AS TablePurchases
	|
	|GROUP BY
	|	TablePurchases.Period,
	|	TablePurchases.Company,
	|	TablePurchases.PresentationCurrency,
	|	TablePurchases.Counterparty,
	|	TablePurchases.Currency,
	|	TablePurchases.Products,
	|	TablePurchases.Ownership,
	|	TablePurchases.Order,
	|	TablePurchases.Document,
	|	TablePurchases.VATRate";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePurchases", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountsPayable(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	DefaultLanguageCode = StructureAdditionalProperties.DefaultLanguageCode;
	
	ExpectedPayments = NStr("en = 'Expected payment'; ru = 'Ожидаемый платеж';pl = 'Oczekiwana płatność';es_ES = 'Pago esperado';es_CO = 'Pago esperado';tr = 'Beklenen ödeme';it = 'Pagamento previsto';de = 'Erwartete Zahlung'", DefaultLanguageCode);
	AdvanceCredit = NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización del pago adelantado';es_CO = 'Amortización del pago anticipado';tr = 'Avans ödeme mahsuplaştırılması';it = 'Compensazione pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", DefaultLanguageCode);
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRefSubcontractorInvoice);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("UseDefaultTypeOfAccounting", StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting);
	Query.SetParameter("LiabilityToVendor", NStr("en = 'Accounts payable recognition'; ru = 'Возникновение кредиторской задолженности';pl = 'Przyjęcie do ewidencji zobowiązań';es_ES = 'Reconocimiento de las cuentas por pagar';es_CO = 'Reconocimiento de las cuentas a pagar';tr = 'Borçlu hesapların doğrulanması';it = 'Riconoscimento debiti contabili';de = 'Aufnahme von Offenen Posten Kreditoren'", DefaultLanguageCode));
	Query.SetParameter("ExchangeDifference", NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", DefaultLanguageCode));
	
	Query.SetParameter("AdvanceCredit", AdvanceCredit);
	Query.SetParameter("ExpectedPayments", ExpectedPayments);
	
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	DocumentTable.SettlementsCurrency AS Currency,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlementsType,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.AmountCur) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	SUM(DocumentTable.AmountCur) AS AmountCurForBalance,
	|	CAST(&LiabilityToVendor AS STRING(100)) AS ContentOfAccountingRecord,
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
	|	TemporaryTableProducts AS DocumentTable
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
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|			THEN DocumentTable.Order
	|		ELSE UNDEFINED
	|	END,
	|	DocumentTable.SettlementsCurrency,
	|	DocumentTable.GLAccountVendorSettlements
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
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
	|		WHEN DocumentTable.DoOperationsByOrders
	|				AND DocumentTable.Order REFS Document.SubcontractorOrderIssued
	|				AND DocumentTable.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
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
	|				AND Calendar.Order REFS Document.SubcontractorOrderIssued
	|				AND Calendar.Order <> VALUE(Document.SubcontractorOrderIssued.EmptyRef)
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
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsPayable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
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
	|	TableAccountingJournalEntries.GLAccount AS AccountDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN TableAccountingJournalEntries.GLAccount.Currency
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
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
	|			THEN TableAccountingJournalEntries.AmountCur - TableAccountingJournalEntries.VATAmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	TableAccountingJournalEntries.Amount - TableAccountingJournalEntries.VATAmount AS Amount,
	|	&ReceiptFromSubcontractor AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	TableByProductsAllocation.Period,
	|	TableByProductsAllocation.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TableByProductsAllocation.GLAccount,
	|	CASE
	|		WHEN TableByProductsAllocation.GLAccount.Currency
	|			THEN TableByProductsAllocation.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableByProductsAllocation.GLAccount.Currency
	|			THEN TableByProductsAllocation.AmountCur
	|		ELSE 0
	|	END,
	|	TableByProductsAllocation.CorrGLAccount,
	|	CASE
	|		WHEN TableByProductsAllocation.CorrGLAccount.Currency
	|			THEN TableByProductsAllocation.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TableByProductsAllocation.CorrGLAccount.Currency
	|			THEN TableByProductsAllocation.AmountCur
	|		ELSE 0
	|	END,
	|	TableByProductsAllocation.Amount,
	|	&ReceiptFromSubcontractor,
	|	FALSE
	|FROM
	|	TemporaryTableByProductsAllocation AS TableByProductsAllocation
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
	|	TemporaryTableProducts AS TableAccountingJournalEntries
	|WHERE
	|	TableAccountingJournalEntries.VATAmount > 0
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
	|	4,
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
	|	AND &PostVATBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
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
	|		INNER JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|		INNER JOIN PrepaymentPostBySourceDocuments AS PrepaymentPostBySourceDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentPostBySourceDocuments.ShipmentDocument
	|WHERE
	|	&PostVATBySourceDocuments
	|
	|GROUP BY
	|	PrepaymentVAT.Period,
	|	PrepaymentVAT.Company
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	TableAccountingJournalEntries.Date,
	|	TableAccountingJournalEntries.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN TableAccountingJournalEntries.AmountOfExchangeDifferences > 0
	|			THEN &NegativeExchDiffGLAccount
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
	|		ELSE &PositiveExchDiffGLAccount
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
	|	7,
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
	
	Query.SetParameter("PositiveExchDiffGLAccount",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain"));
	Query.SetParameter("NegativeExchDiffGLAccount",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("VATAdvancesToSuppliers",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	Query.SetParameter("PostVATBySourceDocuments",	StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	Query.SetParameter("Ref",						DocumentRefSubcontractorInvoice);
	
	Query.SetParameter("ReceiptFromSubcontractor",
		NStr("en = 'Receipt from the subcontractor'; ru = 'Поступление от переработчика';pl = 'Przyjęcie od podwykonawcy';es_ES = 'Recepción del subcontratista';es_CO = 'Recepción del subcontratista';tr = 'Alt yüklenici fişi';it = 'Ricevuta da parte del subfornitore';de = 'Eingang vom Subunternehmer'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("SetOffAdvancePayment",
		NStr("en = 'Advance payment clearing'; ru = 'Зачет аванса';pl = 'Rozliczanie zaliczki';es_ES = 'Amortización del pago anticipado';es_CO = 'Amortización del pago anticipado';tr = 'Avans ödeme mahsuplaştırılması';it = 'Compensazione pagamento anticipato';de = 'Verrechnung der Vorauszahlung'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ExchangeDifference",
		NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Profitti e perdite da cambio valuta';de = 'Wechselkursgewinne und -verluste'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("PreVATExpenses",
		NStr("en = 'VAT input on expenses incurred'; ru = 'Входящий НДС по предъявленным расходам';pl = 'VAT naliczony od poniesionych rozchodów';es_ES = 'Entrada del IVA de los gastos incurridos';es_CO = 'Entrada del IVA de los gastos incurridos';tr = 'Yapılan giderlere ilişkin KDV girişi';it = 'IVA a monte sulle spese occorse';de = 'USt.-Eingabe auf angefallene Ausgaben'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Query.SetParameter("ContentVATRevenue",
		NStr("en = 'Advance VAT clearing'; ru = 'Зачет НДС с аванса';pl = 'Zaliczkowe rozliczenie podatku VAT';es_ES = 'Eliminación del IVA de anticipo';es_CO = 'Eliminación del IVA de anticipo';tr = 'Peşin KDV mahsuplaştırılması';it = 'Compensazione IVA pagamento anticipato';de = 'USt. -Vorschussverrechnung'", StructureAdditionalProperties.DefaultLanguageCode));
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		NewEntry = StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Add();
		FillPropertyValues(NewEntry, Selection);
	EndDo;
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		And StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		And StructureAdditionalProperties.DocumentAttributes.Counterparty <> Catalogs.Counterparties.RetailCustomer Then
		
		QueryText = "";
		If Not StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
			QueryText =
			"SELECT
			|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
			|	TemporaryTableProducts.Document AS ShipmentDocument,
			|	TemporaryTableProducts.VATRate AS VATRate,
			|	TemporaryTableProducts.Period AS Period,
			|	TemporaryTableProducts.Company AS Company,
			|	TemporaryTableProducts.CompanyVATNumber AS CompanyVATNumber,
			|	TemporaryTableProducts.PresentationCurrency AS PresentationCurrency,
			|	TemporaryTableProducts.Counterparty AS Supplier,
			|	&VATInput AS GLAccount,
			|	SUM(TemporaryTableProducts.VATAmount) AS VATAmount,
			|	SUM(TemporaryTableProducts.Amount - TemporaryTableProducts.VATAmount) AS AmountExcludesVAT
			|FROM
			|	TemporaryTableProducts AS TemporaryTableProducts
			|
			|GROUP BY
			|	TemporaryTableProducts.Company,
			|	TemporaryTableProducts.CompanyVATNumber,
			|	TemporaryTableProducts.Period,
			|	TemporaryTableProducts.VATRate,
			|	TemporaryTableProducts.Document,
			|	TemporaryTableProducts.Counterparty,
			|	TemporaryTableProducts.PresentationCurrency";
		EndIf;
		
		If ValueIsFilled(QueryText) Then
			QueryText = QueryText + DriveClientServer.GetQueryUnion()
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
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", New ValueTable);
		Return;
	EndIf;

EndProcedure

Procedure GenerateTableVATInput(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT
		And StructureAdditionalProperties.DocumentAttributes.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT
		And StructureAdditionalProperties.DocumentAttributes.Counterparty <> Catalogs.Counterparties.RetailCustomer
		And StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	TemporaryTableProducts.Document AS ShipmentDocument,
		|	TemporaryTableProducts.VATRate AS VATRate,
		|	TemporaryTableProducts.Period AS Period,
		|	TemporaryTableProducts.Company AS Company,
		|	TemporaryTableProducts.CompanyVATNumber AS CompanyVATNumber,
		|	TemporaryTableProducts.PresentationCurrency AS PresentationCurrency,
		|	TemporaryTableProducts.Counterparty AS Supplier,
		|	&VATInput AS GLAccount,
		|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
		|	VALUE(Enum.ProductsTypes.Service) AS ProductsType,
		|	SUM(TemporaryTableProducts.VATAmount) AS VATAmount,
		|	SUM(TemporaryTableProducts.Amount - TemporaryTableProducts.VATAmount) AS AmountExcludesVAT
		|FROM
		|	TemporaryTableProducts AS TemporaryTableProducts
		|
		|GROUP BY
		|	TemporaryTableProducts.VATRate,
		|	TemporaryTableProducts.CompanyVATNumber,
		|	TemporaryTableProducts.PresentationCurrency,
		|	TemporaryTableProducts.Document,
		|	TemporaryTableProducts.Period,
		|	TemporaryTableProducts.Company,
		|	TemporaryTableProducts.Counterparty
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
		|	&VATInput,
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
		|	&VATInput,
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
		
		Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
		
		QueryResult = Query.Execute();
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", QueryResult.Unload());
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", New ValueTable);
		Return;
	EndIf;
	
EndProcedure

Procedure GenerateTableStockTransferredToThirdParties(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableInventory.Period AS Period,
	|	TemporaryTableInventory.Company AS Company,
	|	TemporaryTableInventory.Products AS Products,
	|	TemporaryTableInventory.Characteristic AS Characteristic,
	|	TemporaryTableInventory.Batch AS Batch,
	|	TemporaryTableInventory.Counterparty AS Counterparty,
	|	TemporaryTableInventory.Order AS Order,
	|	TemporaryTableInventory.Quantity AS Quantity
	|FROM
	|	TemporaryTableInventory AS TemporaryTableInventory";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockTransferredToThirdParties", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableGoodsReceivedNotInvoiced(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableProducts.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Document.GoodsReceipt.EmptyRef) AS GoodsReceipt,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Contract AS Contract,
	|	TableProducts.Order AS PurchaseOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Batch AS Batch,
	|	VALUE(Document.SalesOrder.EmptyRef) AS SalesOrder,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	0 AS Amount
	|INTO TemporaryGoodsReceivedNotInvoiced
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|GROUP BY
	|	TableProducts.Batch,
	|	TableProducts.Characteristic,
	|	TableProducts.Period,
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Contract,
	|	TableProducts.Counterparty,
	|	TableProducts.Order,
	|	TableProducts.Company,
	|	TableProducts.RecordType,
	|	TableProducts.Products
	|
	|UNION ALL
	|
	|SELECT
	|	TableByProducts.Period,
	|	VALUE(AccumulationRecordType.Expense),
	|	VALUE(Document.GoodsReceipt.EmptyRef),
	|	TableByProducts.Company,
	|	TableByProducts.PresentationCurrency,
	|	TableByProducts.Counterparty,
	|	TableByProducts.Contract,
	|	TableByProducts.Order,
	|	TableByProducts.Products,
	|	TableByProducts.Characteristic,
	|	TableByProducts.Batch,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	SUM(TableByProducts.Quantity),
	|	0
	|FROM
	|	TemporaryTableByProducts AS TableByProducts
	|
	|GROUP BY
	|	TableByProducts.Company,
	|	TableByProducts.Period,
	|	TableByProducts.PresentationCurrency,
	|	TableByProducts.Contract,
	|	TableByProducts.Order,
	|	TableByProducts.Products,
	|	TableByProducts.Batch,
	|	TableByProducts.Characteristic,
	|	TableByProducts.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryGoodsReceivedNotInvoiced.Company AS Company,
	|	TemporaryGoodsReceivedNotInvoiced.PresentationCurrency AS PresentationCurrency,
	|	TemporaryGoodsReceivedNotInvoiced.Counterparty AS Counterparty,
	|	TemporaryGoodsReceivedNotInvoiced.Contract AS Contract,
	|	TemporaryGoodsReceivedNotInvoiced.PurchaseOrder AS PurchaseOrder,
	|	TemporaryGoodsReceivedNotInvoiced.Products AS Products,
	|	TemporaryGoodsReceivedNotInvoiced.Characteristic AS Characteristic,
	|	TemporaryGoodsReceivedNotInvoiced.Batch AS Batch,
	|	TemporaryGoodsReceivedNotInvoiced.SalesOrder AS SalesOrder
	|FROM
	|	TemporaryGoodsReceivedNotInvoiced AS TemporaryGoodsReceivedNotInvoiced
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryGoodsReceivedNotInvoiced.Period AS Period,
	|	TemporaryGoodsReceivedNotInvoiced.RecordType AS RecordType,
	|	TemporaryGoodsReceivedNotInvoiced.GoodsReceipt AS GoodsReceipt,
	|	TemporaryGoodsReceivedNotInvoiced.Company AS Company,
	|	TemporaryGoodsReceivedNotInvoiced.PresentationCurrency AS PresentationCurrency,
	|	TemporaryGoodsReceivedNotInvoiced.Counterparty AS Counterparty,
	|	TemporaryGoodsReceivedNotInvoiced.Contract AS Contract,
	|	TemporaryGoodsReceivedNotInvoiced.PurchaseOrder AS PurchaseOrder,
	|	TemporaryGoodsReceivedNotInvoiced.Products AS Products,
	|	TemporaryGoodsReceivedNotInvoiced.Characteristic AS Characteristic,
	|	TemporaryGoodsReceivedNotInvoiced.Batch AS Batch,
	|	TemporaryGoodsReceivedNotInvoiced.SalesOrder AS SalesOrder,
	|	TemporaryGoodsReceivedNotInvoiced.Quantity AS Quantity,
	|	TemporaryGoodsReceivedNotInvoiced.Amount AS Amount
	|FROM
	|	TemporaryGoodsReceivedNotInvoiced AS TemporaryGoodsReceivedNotInvoiced";
	
	QueryResult = Query.ExecuteBatch();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.GoodsReceivedNotInvoiced");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult[1];
	
	For Each ColumnQueryResult In QueryResult[1].Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	TableGoodsReceivedNotInvoiced = QueryResult[2].Unload();
	
	Query.Text =
	"SELECT
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
	|	SUM(Balances.Quantity) AS Quantity
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
	|				(Company, PresentationCurrency, Counterparty, Contract, PurchaseOrder, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableProducts.Company AS Company,
	|						TableProducts.PresentationCurrency AS PresentationCurrency,
	|						TableProducts.Counterparty AS Counterparty,
	|						TableProducts.Contract AS Contract,
	|						CASE
	|							WHEN TableProducts.PurchaseOrder = VALUE(Document.SubcontractorOrderIssued.EmptyRef)
	|								THEN UNDEFINED
	|							ELSE TableProducts.PurchaseOrder
	|						END AS PurchaseOrder,
	|						TableProducts.Products AS Products,
	|						TableProducts.Characteristic AS Characteristic,
	|						TableProducts.Batch AS Batch,
	|						TableProducts.SalesOrder AS SalesOrder
	|					FROM
	|						TemporaryGoodsReceivedNotInvoiced AS TableProducts)) AS Balances
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
	
	Query.SetParameter("Ref", DocumentRefSubcontractorInvoice);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableBalances = QueryResult.Unload();
	TableBalances.Indexes.Add(
		"GoodsReceipt,
		|Company,
		|PresentationCurrency,
		|Counterparty,
		|Contract,
		|PurchaseOrder,
		|Products,
		|Characteristic,
		|Batch,
		|SalesOrder");
	
	TemporaryTableGoods = TableGoodsReceivedNotInvoiced.CopyColumns();
	
	StructureForSearch = New Structure(
		"Company,
		|PresentationCurrency,
		|Counterparty,
		|Contract,
		|PurchaseOrder,
		|Products,
		|Characteristic,
		|Batch,
		|SalesOrder");
	
	For Each TableGoodsRow In TableGoodsReceivedNotInvoiced Do
		
		FillPropertyValues(StructureForSearch, TableGoodsRow);
		
		BalanceRowsArray = TableBalances.FindRows(StructureForSearch);
		
		QuantityToBeWrittenOff = TableGoodsRow.Quantity;
		
		For Each BalancesRow In BalanceRowsArray Do
			
			If BalancesRow.Quantity > 0 Then
				
				NewRow = TemporaryTableGoods.Add();
				FillPropertyValues(NewRow, TableGoodsRow, , "Quantity");
				NewRow.Quantity = Min(BalancesRow.Quantity, QuantityToBeWrittenOff);
				NewRow.GoodsReceipt = BalancesRow.GoodsReceipt;
				
				If NewRow.Quantity < BalancesRow.Quantity Then
					QuantityToBeWrittenOff = 0;
					BalancesRow.Quantity = BalancesRow.Quantity - NewRow.Quantity;
				Else
					QuantityToBeWrittenOff = QuantityToBeWrittenOff - NewRow.Quantity;
					BalancesRow.Quantity = 0;
				EndIf;
				
			EndIf;
			
			If QuantityToBeWrittenOff = 0 Then
				Break;
			EndIf;
			
		EndDo;
		
		If QuantityToBeWrittenOff > 0 Then
			NewRow = TemporaryTableGoods.Add();
			FillPropertyValues(NewRow, TableGoodsRow, , "Quantity");
			NewRow.Quantity = QuantityToBeWrittenOff;
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableGoodsReceivedNotInvoiced", TemporaryTableGoods);
	
EndProcedure

Procedure GenerateTableLandedCosts(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	LandedCosts.Period AS Period,
	|	LandedCosts.RecordType AS RecordType,
	|	LandedCosts.Company AS Company,
	|	LandedCosts.PresentationCurrency AS PresentationCurrency,
	|	LandedCosts.Products AS Products,
	|	LandedCosts.Characteristic AS Characteristic,
	|	LandedCosts.Batch AS Batch,
	|	LandedCosts.Ownership AS Ownership,
	|	LandedCosts.StructuralUnit AS StructuralUnit,
	|	LandedCosts.CostObject AS CostObject,
	|	LandedCosts.CostLayer AS CostLayer,
	|	LandedCosts.InventoryAccountType AS InventoryAccountType,
	|	LandedCosts.Amount AS Amount,
	|	LandedCosts.SourceRecord AS SourceRecord,
	|	LandedCosts.VATRate AS VATRate,
	|	LandedCosts.Responsible AS Responsible,
	|	LandedCosts.Department AS Department,
	|	LandedCosts.SourceDocument AS SourceDocument,
	|	LandedCosts.CorrSalesOrder AS CorrSalesOrder,
	|	LandedCosts.CorrStructuralUnit AS CorrStructuralUnit,
	|	LandedCosts.CorrGLAccount AS CorrGLAccount,
	|	LandedCosts.RIMTransfer AS RIMTransfer,
	|	LandedCosts.SalesRep AS SalesRep,
	|	LandedCosts.Counterparty AS Counterparty,
	|	LandedCosts.Currency AS Currency,
	|	LandedCosts.SalesOrder AS SalesOrder,
	|	LandedCosts.CorrCostObject AS CorrCostObject,
	|	LandedCosts.CorrInventoryAccountType AS CorrInventoryAccountType,
	|	LandedCosts.CorrProducts AS CorrProducts,
	|	LandedCosts.GLAccount AS GLAccount,
	|	LandedCosts.CorrCharacteristic AS CorrCharacteristic,
	|	LandedCosts.CorrBatch AS CorrBatch,
	|	LandedCosts.CorrOwnership AS CorrOwnership,
	|	LandedCosts.CorrSpecification AS CorrSpecification,
	|	LandedCosts.Specification AS Specification,
	|	LandedCosts.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	LandedCosts.CorrIncomeAndExpenseItem AS CorrIncomeAndExpenseItem
	|FROM
	|	AccumulationRegister.LandedCosts AS LandedCosts";
	
	QueryResult = Query.Execute();
	TableLandedCosts = QueryResult.Unload();
	
	If StructureAdditionalProperties.AccountingPolicy.UseFIFO Then
		
		TableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory;
		SubcontractorOrderIssued = StructureAdditionalProperties.DocumentAttributes.BasisDocument;
		
		For Each InventoryRow In TableInventory Do
			
			If InventoryRow.RecordType = AccumulationRecordType.Receipt And Not InventoryRow.OfflineRecord Then
				
				LandedCostsRow = TableLandedCosts.Add();
				FillPropertyValues(LandedCostsRow, InventoryRow);
				LandedCostsRow.SourceRecord = True;
				LandedCostsRow.CostLayer = SubcontractorOrderIssued;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableLandedCosts", TableLandedCosts);
	
EndProcedure

Procedure GenerateTableCostOfSubcontractorGoods(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProducts.Period AS Period,
	|	TableProducts.Company AS Company,
	|	TableProducts.PresentationCurrency AS PresentationCurrency,
	|	TableProducts.Counterparty AS Counterparty,
	|	TableProducts.Order AS SubcontractorOrder,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Products AS FinishedProducts,
	|	TableProducts.Characteristic AS FinishedProductsCharacteristic,
	|	SUM(TableProducts.Quantity) AS Quantity,
	|	SUM(TableProducts.Amount - TableProducts.VATAmount) AS Amount,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|GROUP BY
	|	TableProducts.PresentationCurrency,
	|	TableProducts.Counterparty,
	|	TableProducts.Company,
	|	TableProducts.Period,
	|	TableProducts.Products,
	|	TableProducts.Characteristic,
	|	TableProducts.Order,
	|	TableProducts.Products,
	|	TableProducts.Characteristic
	|
	|UNION ALL
	|
	|SELECT
	|	TableByProductsAllocation.Period,
	|	TableByProductsAllocation.Company,
	|	TableByProductsAllocation.PresentationCurrency,
	|	TableByProductsAllocation.Counterparty,
	|	TableByProductsAllocation.Order,
	|	TableByProductsAllocation.Products,
	|	TableByProductsAllocation.Characteristic,
	|	TableByProductsAllocation.CorrProducts,
	|	TableByProductsAllocation.CorrCharacteristic,
	|	-SUM(TableByProductsAllocation.Quantity),
	|	-SUM(TableByProductsAllocation.Amount),
	|	FALSE
	|FROM
	|	TemporaryTableByProductsAllocation AS TableByProductsAllocation
	|
	|GROUP BY
	|	TableByProductsAllocation.CorrProducts,
	|	TableByProductsAllocation.CorrCharacteristic,
	|	TableByProductsAllocation.Counterparty,
	|	TableByProductsAllocation.Products,
	|	TableByProductsAllocation.Company,
	|	TableByProductsAllocation.PresentationCurrency,
	|	TableByProductsAllocation.Characteristic,
	|	TableByProductsAllocation.Period,
	|	TableByProductsAllocation.Order";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCostOfSubcontractorGoods", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);
	
EndProcedure

#EndRegion 

Procedure FillInTabularSection(DocumentData, TabularSection, QueryResult, BalanceTable)
	
	TabularSection.Clear();
	
	If BalanceTable.Count() > 0 Then
		
		TabSectionColumns = TabularSection.UnloadColumns().Columns;
		
		Selection = QueryResult.Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("SubcontractorOrder",	Selection.BasisOrder);
			StructureForSearch.Insert("Products",			Selection.Products);
			StructureForSearch.Insert("Characteristic",		Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			
			For Each BalanceRowItem In BalanceRowsArray Do
				
				If BalanceRowItem.QuantityBalance = 0 Then
					Continue;
				EndIf;
				
				NewRow = TabularSection.Add();
				
				FillPropertyValues(NewRow, Selection);
				
				NewRow.Batch = BalanceRowItem.Batch;
				If TabSectionColumns.Find("StructuralUnit") <> Undefined
					And TabSectionColumns.Find("InventoryGLAccount") <> Undefined Then
					NewRow.StructuralUnit = BalanceRowItem.StructuralUnit;
					NewRow.InventoryGLAccount = BalanceRowItem.InventoryGLAccount;
				EndIf;
				
				If BalanceRowItem.QuantityBalance >= QuantityToWriteOff Then
					BalanceRowItem.QuantityBalance = BalanceRowItem.QuantityBalance - QuantityToWriteOff;
					Break;
				Else
					NewRow.Quantity = BalanceRowItem.QuantityBalance / Selection.Factor;
					If TabSectionColumns.Find("Total") <> Undefined
						And TabSectionColumns.Find("CostValue") <> Undefined Then
						
						NewRow.Total = NewRow.Quantity * NewRow.CostValue;
						
					ElsIf TabSectionColumns.Find("Price") <> Undefined
						And TabSectionColumns.Find("Amount") <> Undefined
						And TabSectionColumns.Find("VATAmount") <> Undefined
						And TabSectionColumns.Find("VATRate") <> Undefined Then
						
						VATRateValue = DriveReUse.GetVATRateValue(NewRow.VATRate);
						
						NewRow.Amount = NewRow.Quantity * NewRow.Price;
						NewRow.VATAmount = ?(DocumentData.AmountIncludesVAT, 
							NewRow.Amount - (NewRow.Amount) / ((VATRateValue + 100) / 100),
							NewRow.Amount * VATRateValue / 100);
						NewRow.Total = NewRow.Amount + ?(DocumentData.AmountIncludesVAT, 0, NewRow.VATAmount);
						
					EndIf;
					
					BalanceRowItem.QuantityBalance = 0;
					QuantityToWriteOff = QuantityToWriteOff - BalanceRowItem.QuantityBalance;
				EndIf;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure AddOfflineRecords(DocumentRefSubcontractorInvoice, StructureAdditionalProperties)
	
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
	|	Inventory.CorrInventoryAccountType AS CorrInventoryAccountType
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Recorder = &Recorder
	|	AND Inventory.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CostOfSubcontractorGoods.Period AS Period,
	|	CostOfSubcontractorGoods.Recorder AS Recorder,
	|	CostOfSubcontractorGoods.LineNumber AS LineNumber,
	|	CostOfSubcontractorGoods.Active AS Active,
	|	CostOfSubcontractorGoods.Company AS Company,
	|	CostOfSubcontractorGoods.PresentationCurrency AS PresentationCurrency,
	|	CostOfSubcontractorGoods.Counterparty AS Counterparty,
	|	CostOfSubcontractorGoods.SubcontractorOrder AS SubcontractorOrder,
	|	CostOfSubcontractorGoods.FinishedProducts AS FinishedProducts,
	|	CostOfSubcontractorGoods.FinishedProductsCharacteristic AS FinishedProductsCharacteristic,
	|	CostOfSubcontractorGoods.Products AS Products,
	|	CostOfSubcontractorGoods.Characteristic AS Characteristic,
	|	CostOfSubcontractorGoods.Quantity AS Quantity,
	|	CostOfSubcontractorGoods.Amount AS Amount,
	|	CostOfSubcontractorGoods.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.CostOfSubcontractorGoods AS CostOfSubcontractorGoods
	|WHERE
	|	CostOfSubcontractorGoods.Recorder = &Recorder
	|	AND CostOfSubcontractorGoods.OfflineRecord";
	
	Query.SetParameter("Recorder", DocumentRefSubcontractorInvoice);
	
	QueryResult = Query.ExecuteBatch();
	
	InventoryRecords = QueryResult[0].Unload();
	CostOfSubcontractorGoodsRecords = QueryResult[1].Unload();
	
	For Each InventoryRecord In InventoryRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(NewRow, InventoryRecord);
	EndDo;
	
	For Each CostOfSubcontractorGoodsRecord In CostOfSubcontractorGoodsRecords Do
		NewRow = StructureAdditionalProperties.TableForRegisterRecords.TableCostOfSubcontractorGoods.Add();
		FillPropertyValues(NewRow, CostOfSubcontractorGoodsRecord);
	EndDo;
	
EndProcedure

#EndRegion

#EndIf
