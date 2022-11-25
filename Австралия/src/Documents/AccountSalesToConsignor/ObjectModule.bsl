#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills advances.
//
Procedure FillPrepayment()Export
	
	ParentCompany      = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "PurchaseOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow In OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.PurchaseOrder = Undefined;
		EndIf;
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
	EndDo;
	OrdersTable.GroupBy("PurchaseOrder", "Total, TotalCalc");
	OrdersTable.Sort("PurchaseOrder Asc");
	
	SetPrivilegedMode(True);
	
	// Filling prepayment details.
	Query = New Query;
	QueryText =
	"SELECT
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.AmountBalance AS AmountBalance,
	|		AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.Amount
	|			ELSE DocumentRegisterRecordsVendorSettlements.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|			ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN(&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-AccountsPayableBalances.AmountCurBalance AS SettlementsAmount,
	|	-AccountsPayableBalances.AmountBalance AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN AccountsPayableBalances.AmountBalance <> 0
	|						THEN AccountsPayableBalances.AmountCurBalance / AccountsPayableBalances.AmountBalance
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN AccountsPayableBalances.AmountCurBalance <> 0
	|					THEN AccountsPayableBalances.AmountBalance / AccountsPayableBalances.AmountCurBalance
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance < 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("PurchaseOrder"));
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	SetPrivilegedMode(False);
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "PurchaseOrder");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				SelectionOfQueryResult.ExchangeRate,
				1,
				SelectionOfQueryResult.Multiplicity,
				1);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
		NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			ExchangeRateMethod,
			ContractCurrencyExchangeRate,
			ExchangeRate,
			ContractCurrencyMultiplicity,
			Multiplicity);
		
	EndDo;
	
EndProcedure

// Procedure of the document filling according to the header attributes.
//
Procedure FillByHeaderAttributes()
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	Query = New Query();
	Query.SetParameter("Company",		            ParentCompany);
	Query.SetParameter("PresentationCurrency",		DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("ExchangeRateMethod",		DriveServer.GetExchangeMethod(ParentCompany));
	Query.SetParameter("Counterparty",		    	Counterparty);
	Query.SetParameter("Contract",			        Contract);
	Query.SetParameter("SettlementsCurrency",		Contract.SettlementsCurrency);
	Query.SetParameter("DocumentCurrency",	        DocumentCurrency);
	Query.SetParameter("EndOfPeriod",		        CurrentSessionDate());
	Query.SetParameter("SupplierPriceTypes",	    SupplierPriceTypes);
	Query.SetParameter("PriceKindCurrency",		    SupplierPriceTypes.PriceCurrency);
	Query.SetParameter("Ref",			         	Ref);
	
	// Define date of the last report
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	AccountSalesToConsignor.Date AS Date
	|FROM
	|	Document.AccountSalesToConsignor AS AccountSalesToConsignor
	|WHERE
	|	AccountSalesToConsignor.Posted
	|	AND AccountSalesToConsignor.Company = &Company
	|	AND AccountSalesToConsignor.Counterparty = &Counterparty
	|	AND AccountSalesToConsignor.Contract = &Contract
	|	AND AccountSalesToConsignor.Date < &EndOfPeriod
	|	AND AccountSalesToConsignor.Ref <> &Ref
	|
	|ORDER BY
	|	Date DESC";
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Query.SetParameter("BeginOfPeriod",Undefined);
	Else
		Selection = Result.Select();
		Selection.Next();
		Query.SetParameter("BeginOfPeriod",Selection.Date);
	EndIf;
	
	// Define the amount of sold goods and purchase prices
	Query.Text = 
	"SELECT ALLOWED
	|	InventoryOwnership.Ref AS Ownership
	|INTO TT_Ownership
	|FROM
	|	Catalog.InventoryOwnership AS InventoryOwnership
	|WHERE
	|	InventoryOwnership.OwnershipType = VALUE(Enum.InventoryOwnershipTypes.CounterpartysInventory)
	|	AND InventoryOwnership.Counterparty = &Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountingPolicySliceLast.DefaultVATRate AS CompanyVATRate,
	|	SalesTurnovers.Products AS Products,
	|	SalesTurnovers.Products.VATRate AS ProductsVATRate,
	|	SalesTurnovers.Characteristic AS Characteristic,
	|	SalesTurnovers.Batch AS Batch,
	|	SalesTurnovers.SalesOrder AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|			THEN SalesTurnovers.Document.Counterparty
	|	END AS Customer,
	|	CASE
	|		WHEN VALUETYPE(SalesTurnovers.Document) = TYPE(Document.SalesInvoice)
	|			THEN SalesTurnovers.Document.Date
	|	END AS DateOfSale,
	|	SalesTurnovers.QuantityTurnover AS Quantity,
	|	SalesTurnovers.Products.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover > 0
	|			THEN CASE
	|					WHEN &DocumentCurrency = &PresentationCurrency
	|						THEN (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) / SalesTurnovers.QuantityTurnover
	|					ELSE ISNULL((SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * CASE
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|									THEN AccountingCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * AccountingCurrencyRate.Repetition)
	|								WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|									THEN 1 / (AccountingCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * AccountingCurrencyRate.Repetition))
	|							END, 0) / SalesTurnovers.QuantityTurnover
	|				END
	|		ELSE 0
	|	END AS Price,
	|	CASE
	|		WHEN &DocumentCurrency = &PresentationCurrency
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE (SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover) * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN AccountingCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * AccountingCurrencyRate.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (AccountingCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * AccountingCurrencyRate.Repetition))
	|			END
	|	END AS Amount,
	|	ISNULL(CASE
	|			WHEN &DocumentCurrency = &PriceKindCurrency
	|				THEN FixedReceiptPrices.Price
	|			ELSE FixedReceiptPrices.Price * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN PriceKindCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * PriceKindCurrencyRate.Repetition)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (PriceKindCurrencyRate.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * PriceKindCurrencyRate.Repetition))
	|				END
	|		END, 0) AS ReceiptPrice,
	|	StockReceivedFromThirdPartiesBalances.Order AS PurchaseOrder
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			,
	|			Company = &Company
	|				AND Ownership IN
	|					(SELECT
	|						TT_Ownership.Ownership
	|					FROM
	|						TT_Ownership AS TT_Ownership)) AS SalesTurnovers
	|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
	|				&EndOfPeriod,
	|				Company = &Company
	|					AND Counterparty = &Counterparty) AS StockReceivedFromThirdPartiesBalances
	|		ON (StockReceivedFromThirdPartiesBalances.Products = SalesTurnovers.Products)
	|			AND (StockReceivedFromThirdPartiesBalances.Characteristic = SalesTurnovers.Characteristic)
	|			AND (StockReceivedFromThirdPartiesBalances.Batch = SalesTurnovers.Batch)
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&EndOfPeriod,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Actuality) AS FixedReceiptPrices
	|		ON (FixedReceiptPrices.Products = SalesTurnovers.Products)
	|			AND (FixedReceiptPrices.Characteristic = SalesTurnovers.Characteristic)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&EndOfPeriod,
	|				Currency = &SettlementsCurrency
	|					AND Company = &Company) AS SettlementsCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&EndOfPeriod,
	|				Currency = &DocumentCurrency
	|					AND Company = &Company) AS DocumentCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&EndOfPeriod,
	|				Currency = &PresentationCurrency
	|					AND Company = &Company) AS AccountingCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&EndOfPeriod,
	|				Currency = &PriceKindCurrency
	|					AND Company = &Company) AS PriceKindCurrencyRate
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&EndOfPeriod, ) AS AccountingPolicySliceLast
	|		ON SalesTurnovers.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	SalesTurnovers.QuantityTurnover > 0
	|	AND StockReceivedFromThirdPartiesBalances.QuantityBalance > 0";
	
	RemunerationVATRateNumber = DriveReUse.GetVATRateValue(VATCommissionFeePercent);
	
	// Refill the Inventory tabular section
	Inventory.Clear();
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, Selection);
		
		// VAT rate, VATAmount and Total
		If VATTaxation <> Enums.VATTaxationTypes.SubjectToVAT Then
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				NewRow.VATRate = Catalogs.VATRates.Exempt;
			Else
				NewRow.VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;	
		ElsIf ValueIsFilled(Selection.ProductsVATRate) Then
			NewRow.VATRate = Selection.ProductsVATRate;
		Else
			NewRow.VATRate = Selection.CompanyVATRate;
		EndIf;
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		NewRow.VATAmount = ?(AmountIncludesVAT, 
								 NewRow.Amount - (NewRow.Amount) / ((VATRate + 100) / 100),
								 NewRow.Amount * VATRate / 100);
		
		NewRow.Total = NewRow.Amount + ?(AmountIncludesVAT, 0, NewRow.VATAmount);
		
		// Receipt amount and VAT.
		NewRow.AmountReceipt = NewRow.Quantity * NewRow.ReceiptPrice;
		
		NewRow.ReceiptVATAmount = ?(AmountIncludesVAT, 
											NewRow.AmountReceipt - (NewRow.AmountReceipt) / ((VATRate + 100) / 100),
											NewRow.AmountReceipt * VATRate / 100);
		
		// Fee
		If BrokerageCalculationMethod <> Enums.CommissionFeeCalculationMethods.IsNotCalculating Then

			If BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromSaleAmount Then
	
				NewRow.BrokerageAmount = CommissionFeePercent * NewRow.Amount / 100;
	
			ElsIf BrokerageCalculationMethod = Enums.CommissionFeeCalculationMethods.PercentFromDifferenceOfSaleAndAmountReceipts Then

				NewRow.BrokerageAmount = CommissionFeePercent * (NewRow.Amount - NewRow.AmountReceipt) / 100;

			Else
		
				NewRow.BrokerageAmount = 0;
		
			EndIf;
			
		EndIf;
	
		NewRow.BrokerageVATAmount = ?(AmountIncludesVAT, 
												NewRow.BrokerageAmount - (NewRow.BrokerageAmount) / ((RemunerationVATRateNumber + 100) / 100),
												NewRow.BrokerageAmount * RemunerationVATRateNumber / 100);
		
	EndDo;
	
EndProcedure

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling
//	data
Procedure FillByGoodsReceipt(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Header.Ref AS Ref,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.VATTaxation AS VATTaxation
	|INTO Header
	|FROM
	|	Document.GoodsReceipt AS Header
	|WHERE
	|	Header.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.VATTaxation AS VATTaxation,
	|	Contracts.SettlementsCurrency AS SettlementsCurrency,
	|	GRProducts.Products AS Products,
	|	GRProducts.Characteristic AS Characteristic,
	|	GRProducts.Batch AS Batch,
	|	GRProducts.Quantity AS Quantity,
	|	GRProducts.MeasurementUnit AS MeasurementUnit,
	|	GRProducts.VATRate AS VATRate,
	|	GRProducts.Order AS SalesOrder,
	|	ISNULL(SalesOrderRef.SalesRep, Counterparties.SalesRep) AS SalesRep,
	|	0 AS ConnectionKey,
	|	GRProducts.ConnectionKey AS ConnectionKeySerialNumbes,
	|	Contracts.PaymentMethod AS PaymentMethod,
	|	Companies.BankAccountByDefault AS BankAccountByDefault,
	|	Companies.PettyCashByDefault AS PettyCashByDefault,
	|	Contracts.PriceKind AS PriceKind,
	|	Contracts.PaymentMethod.CashAssetType AS CashAssetType
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.GoodsReceipt.Products AS GRProducts
	|		ON Header.Ref = GRProducts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (GRProducts.Ref.Contract = Contracts.Ref)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON (GRProducts.Ref.Company = Companies.Ref)
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON (GRProducts.Order = SalesOrderRef.Ref)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Header.Counterparty = Counterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Calendar.Term AS Term,
	|	Calendar.DuePeriod AS DuePeriod,
	|	Calendar.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Calendar
	|		INNER JOIN Header AS Header
	|		ON (Header.Contract = Calendar.Ref)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResultFull = Query.ExecuteBatch();
	QueryResult = QueryResultFull[1];
	
	QueryResultSelection = QueryResult.Select();
	
	QueryResultSelection.Next();
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	DocumentCurrency = QueryResultSelection.SettlementsCurrency;
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate = StructureByCurrency.Rate;
	Multiplicity = StructureByCurrency.Repetition;
	ContractCurrencyExchangeRate = StructureByCurrency.Rate;
	ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
	
	QueryResultSelection.Reset();
	While QueryResultSelection.Next() Do
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
	EndDo;
	
	If GetFunctionalOption("UseSerialNumbers") Then
		SerialNumbers.Load(FillingData.SerialNumbers.Unload());
		For Each Str In Inventory Do
			Str.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, Str.ConnectionKey);
		EndDo;
	EndIf;
	
	QueryResult = QueryResultFull[2];
	SessionDate = CurrentSessionDate();
	
	CalendarSelection = QueryResult.Select();
	While CalendarSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		NewLine.PaymentPercentage = CalendarSelection.PaymentPercentage;
		
		If CalendarSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = SessionDate - CalendarSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = SessionDate + CalendarSelection.DuePeriod * 86400;
		EndIf;
		
	EndDo;
	
	SetPaymentTerms = False;
	If QueryResultSelection.CashAssetType = Enums.CashAssetTypes.Noncash Then
		BankAccount = QueryResultSelection.BankAccountByDefault;
	ElsIf QueryResultSelection.CashAssetType = Enums.CashAssetTypes.Cash Then
		PettyCash = QueryResultSelection.PettyCashByDefault;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
	
		Counterparty	= FillingData;
		Contract		= FillingData.ContractByDefault;
		
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
		If ValueIsFilled(SettingValue) Then
			If Company <> SettingValue Then
				Company = SettingValue;
			EndIf;
		Else
			Company = Catalogs.Companies.MainCompany;
		EndIf;
		
		CompanyVATNumber	= Company.VATNumber;
		DocumentCurrency	= Contract.SettlementsCurrency;
		StructureByCurrency	= CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company);
		ExchangeRate		= StructureByCurrency.Rate;
		Multiplicity		= StructureByCurrency.Repetition;
		
		VATTaxation = DriveServer.CounterpartyVATTaxation(Counterparty, DriveServer.VATTaxation(Company, Date));
		
		FillByHeaderAttributes();
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsReceipt") Then
		
		If FillingData.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			FillByGoodsReceipt(FillingData);
		Else
			Raise NStr("en = 'Please select a goods receipt with ""Receipt from a third party"" operation.'; ru = 'Выберите поступление товаров с видом операции ""Поступление от третьих лиц"".';pl = 'Proszę wybrać przyjęcie zewnętrzne za pomocą operacji ""Przyjęcie od strony trzeciej"".';es_ES = 'Por favor, seleccione una recepción de productos con operación ""Recepción de los terceros"".';es_CO = 'Por favor, seleccione una recepción de productos con operación ""Recepción de los terceros"".';tr = 'Lütfen ""Üçüncü taraflardan makbuz"" işlemi olan bir Ambar girişi seçin.';it = 'Per piacere selezionare un ricevimento di beni con operazione ""Ricevimento da terze parti"".';de = 'Bitte wählen Sie einen Wareneingang mit der Operation ""Eingang von einem Dritten"" aus.'");
		EndIf;
		
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		FillByHeaderAttributes();
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	TableInventory = Inventory.Unload(, "PurchaseOrder, Total");
	TableInventory.GroupBy("PurchaseOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "PurchaseOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "PurchaseOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "PurchaseOrder"), FoundStringInventory);
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Cannot register the advance payment because the order to be paid is not listed on the Goods tab'; ru = 'Нельзя зачесть аванс по заказу, отсутствующему в табличной части ""Запасы"".';pl = 'Nie można zarejestrować zaliczki, ponieważ zamówienie do opłaty nie figuruje na karcie Towary.';es_ES = 'No se puede registrar el pago anticipado porque el orden a pagar no está en la lista de la pestaña Mercancías';es_CO = 'No se puede registrar el pago anticipado porque el orden a pagar no está en la lista de la pestaña Mercancías';tr = 'Ön ödeme kaydedilemiyor çünkü ödenecek sipariş, Mallar sekmesinde listelenmemiş';it = 'Impossibile registrare l''acconto perché l''ordine da pagare non è elencato nella tabella Merci';de = 'Die Vorauszahlung kann nicht registriert werden, da der zu zahlende Auftrag nicht auf der Registerkarte Waren aufgeführt ist'");
			DriveServer.ShowMessageAboutError(
				Undefined,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel);
		EndIf;
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
	//Cash flow projection
	If KeepBackCommissionFee Then
		InventoryTotal = Inventory.Total("Total");
		VATAmount = Inventory.Total("VATAmount") - Inventory.Total("BrokerageVATAmount");
		Amount = Round(InventoryTotal - (CommissionFeePercent * InventoryTotal / 100) - VATAmount, 2);
	Else
		VATAmount = Inventory.Total("VATAmount");
		Amount = Inventory.Total("Amount");
	EndIf;
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
		And Not Counterparty.DoOperationsByContracts
		And Not ValueIsFilled(Contract) Then
		
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Inventory.Total("Total");
		DocumentTax = Inventory.Total("VATAmount");
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;

	// Document data initialization.
	Documents.AccountSalesToConsignor.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);

	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);

	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesToConsignor.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	If Not Cancel Then
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
	EndIf;
		
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesToConsignor.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	If Not Cancel Then
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;

EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

#EndRegion

#EndIf
