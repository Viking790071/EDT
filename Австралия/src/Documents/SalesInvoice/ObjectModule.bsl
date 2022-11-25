#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region DocumentFillingProcedures

Procedure FillPrepayment() Export
	
	OrderInHeader = (SalesOrderPosition = Enums.AttributeStationing.InHeader);
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "Order, Total, SalesTaxAmount");
	If Not Counterparty.DoOperationsByOrders Then
		OrdersTable.FillValues(Undefined, "Order");
	ElsIf OrderInHeader Then
		OrdersTable.FillValues(Order, "Order");
	EndIf;
	OrdersTable.GroupBy("Order", "Total, SalesTaxAmount");
	OrdersTable.Columns.Add("TotalCalc");
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	For Each CurRow In OrdersTable Do
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total + CurRow.SalesTaxAmount,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
	EndDo;
	
	OrdersTable.Sort("Order Asc");
	
	SetPrivilegedMode(True);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.AmountBalance AS AmountBalance,
	|		AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsReceivable.Amount
	|			ELSE DocumentRegisterRecordsAccountsReceivable.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsReceivable.AmountCur
	|			ELSE DocumentRegisterRecordsAccountsReceivable.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order IN(&Order)
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-AccountsReceivableBalances.AmountCurBalance AS SettlementsAmount,
	|	-AccountsReceivableBalances.AmountBalance AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN AccountsReceivableBalances.AmountBalance <> 0
	|						THEN AccountsReceivableBalances.AmountCurBalance / AccountsReceivableBalances.AmountBalance
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN AccountsReceivableBalances.AmountCurBalance <> 0
	|					THEN AccountsReceivableBalances.AmountBalance / AccountsReceivableBalances.AmountCurBalance
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance < 0
	|
	|ORDER BY
	|	DocumentDate";

	Query.SetParameter("Order", OrdersTable.UnloadColumn("Order"));
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
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "Order");
		
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
	
	WorkWithVAT.FillPrepaymentVATFromVATOutput(ThisObject);
	
EndProcedure

Procedure FillAmountAllocation() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableBalances
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND &ContractTypesList
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsReceivableBalanceAndTurnovers.Company,
	|	AccountsReceivableBalanceAndTurnovers.Counterparty,
	|	AccountsReceivableBalanceAndTurnovers.Contract,
	|	AccountsReceivableBalanceAndTurnovers.Document,
	|	AccountsReceivableBalanceAndTurnovers.Order,
	|	AccountsReceivableBalanceAndTurnovers.SettlementsType,
	|	-AccountsReceivableBalanceAndTurnovers.AmountCurTurnover
	|FROM
	|	AccumulationRegister.AccountsReceivable.BalanceAndTurnovers(
	|			,
	|			,
	|			Recorder,
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalanceAndTurnovers
	|WHERE
	|	AccountsReceivableBalanceAndTurnovers.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	CASE
	|		WHEN ISNULL(Counterparties.DoOperationsByOrders, FALSE)
	|			THEN AccountsReceivableBalances.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate
	|INTO AccountsReceivableBalancesPrev
	|FROM
	|	AccountsReceivableBalances AS AccountsReceivableBalances
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableBalances.Counterparty = Counterparties.Ref
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	SUM(CAST(AccountsReceivableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN CAST(&ContractCurrencyExchangeRate * &Multiplicity / (&ExchangeRate * &ContractCurrencyMultiplicity) AS NUMBER)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN 1 / (&ContractCurrencyExchangeRate * &Multiplicity / (&ExchangeRate * &ContractCurrencyMultiplicity))
	|			END AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate
	|FROM
	|	AccountsReceivableBalancesPrev AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Company,
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.DocumentDate
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", 		ParentCompany);
	Query.SetParameter("Counterparty",	Counterparty);
	Query.SetParameter("Contract",		Contract);
	Query.SetParameter("Period", 		New Boundary(Date, BoundaryType.Including));
	Query.SetParameter("ExchangeRateMethod", DriveServer.GetExchangeMethod(Company));
	Query.SetParameter("Ref", 			Ref);
	
	Query.SetParameter("ExchangeRate",					?(ExchangeRate = 0, 1, ExchangeRate));
	Query.SetParameter("Multiplicity",					?(Multiplicity = 0, 1, Multiplicity));
	Query.SetParameter("ContractCurrencyExchangeRate",	?(ContractCurrencyExchangeRate = 0, 1, ContractCurrencyExchangeRate));
	Query.SetParameter("ContractCurrencyMultiplicity",	?(ContractCurrencyMultiplicity = 0, 1, ContractCurrencyMultiplicity));
	
	NeedFilterByContracts	= DriveReUse.CounterpartyContractsControlNeeded();
	ContractTypesList 		= Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	
	If NeedFilterByContracts And Counterparty.DoOperationsByContracts Then
		Query.Text = StrReplace(Query.Text, "&ContractTypesList", "Contract.ContractKind IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", ContractTypesList);
	Else
		Query.Text = StrReplace(Query.Text, "&ContractTypesList", "TRUE");
	EndIf;
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	AmountAllocation.Clear();
	InitialAmountLeftToDistribute = -DocumentAmount;
	AmountLeftToDistribute = InitialAmountLeftToDistribute;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = AmountAllocation.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.OffsetAmount		= SelectionOfQueryResult.AmountCurrDocument;
				AmountLeftToDistribute	= AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.OffsetAmount 	= AmountLeftToDistribute;
				AmountLeftToDistribute	= 0;
				
			EndIf;
			
		Else
			
			NewRow.AdvanceFlag	= True;
			NewRow.OffsetAmount	= AmountLeftToDistribute;
			
			AmountLeftToDistribute	= 0;
			
		EndIf;
		
	EndDo;
	
	AmountLeftToDistribute = InitialAmountLeftToDistribute - AmountAllocation.Total("OffsetAmount");
	If AmountLeftToDistribute <> 0 Then
		AmountAllocation[AmountAllocation.Count()-1].OffsetAmount = AmountAllocation[AmountAllocation.Count()-1].OffsetAmount + AmountLeftToDistribute;
	EndIf;
	
	If AmountAllocation.Count() = 0 Then
		AmountAllocation.Add();
		AmountAllocation[0].OffsetAmount = -DocumentAmount;
	EndIf;
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfGoodsIssues") Then
		FillByGoodsIssue(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfWorkOrders") Then
		FillByWorkOrder(FillingData);
	EndIf;

	If FillingData.Property("ArrayOfInvoices") Then
		FillBySupplierInvoice(FillingData);
	EndIf;
	
	If FillingData.Property("ClosingInvoiceProcessing") Then
		FillByClosingInvioiceProcessingData(FillingData);
	EndIf;
	
EndProcedure

Procedure FillByClosingInvioiceProcessingData(FillingData)
	
	Date = FillingData.Date;
	
	Company = FillingData.Company;
	WorkWithVAT.ProcessingCompanyVATNumbers(ThisObject, "CompanyVATNumber");
	
	Department = FillingData.Department;
	If Not ValueIsFilled(Department) Then
		Department = Catalogs.BusinessUnits.MainDepartment;
	EndIf;
	
	OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice;
	
	DocumentCurrency = FillingData.PresentationCurrency;
	
	DeliveryDatePosition = Enums.AttributeStationing.InHeader;
	DeliveryStartDate = FillingData.DeliveryStartDate;
	DeliveryEndDate = FillingData.DeliveryEndDate;
	If DeliveryStartDate = DeliveryEndDate Then
		DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date;
	Else
		DeliveryDatePeriod = Enums.DeliveryDatePeriod.Period;
	EndIf;
	
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	
	PriceKind = Common.ObjectAttributeValue(Contract, "PriceKind");
	AmountIncludesVAT = Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
	
	SetPaymentTerms = FillingData.SetPaymentTerms;
	PaymentMethod = FillingData.PaymentMethod;
	CashAssetType = Common.ObjectAttributeValue(PaymentMethod, "CashAssetType");
	PettyCash = FillingData.PettyCash;
	BankAccount = FillingData.BankAccount;
	DirectDebitMandate = FillingData.DirectDebitMandate;
	PaymentCalendar.Load(FillingData.PaymentCalendar);
	
	For Each InventoryData In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, InventoryData);
		
		If NewRow.DeliveryStartDate <> DeliveryStartDate Or NewRow.DeliveryEndDate <> DeliveryEndDate Then
			DeliveryDatePosition = Enums.AttributeStationing.InTabularSection;
		EndIf;
		If DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date And NewRow.DeliveryStartDate <> NewRow.DeliveryEndDate Then
			DeliveryDatePeriod = Enums.DeliveryDatePeriod.Period;
		EndIf;
		
		NewRow.Amount = NewRow.Quantity * NewRow.Price;
		VATRate = DriveReUse.GetVATRateValue(NewRow.VATRate);
		
		If AmountIncludesVAT Then
			NewRow.VATAmount = NewRow.Amount - NewRow.Amount * 100 / (VATRate + 100);
			NewRow.Total = NewRow.Amount;
		Else
			NewRow.VATAmount = NewRow.Amount * VATRate / 100;
			NewRow.Total = NewRow.Amount + NewRow.VATAmount;
		EndIf;
		
		For Each InvoicesData In InventoryData.Invoices Do
			
			NewRow = IssuedInvoices.Add();
			FillPropertyValues(NewRow, InventoryData);
			
			NewRow.Invoice = InvoicesData.Invoice;
			NewRow.Quantity = InvoicesData.Quantity;
			
			NewRow.Amount = NewRow.Quantity * NewRow.Price;
			
			If AmountIncludesVAT Then
				NewRow.VATAmount = NewRow.Amount - NewRow.Amount * 100 / (VATRate + 100);
				NewRow.Total = NewRow.Amount;
			Else
				NewRow.VATAmount = NewRow.Amount * VATRate / 100;
				NewRow.Total = NewRow.Amount + NewRow.VATAmount;
			EndIf;
			
		EndDo;
		
	EndDo;
	
	If DriveReUse.GetAdvanceOffsettingSettingValue() = Enums.YesNo.Yes And Inventory.Total("Total") > 0 Then 
		FillPrepayment();
	EndIf;
	
EndProcedure

Procedure FillBySalesOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
		FillPropertyValues(ThisObject, FillingData);
	Else
		OrdersArray.Add(FillingData.Ref);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CompanyVATNumber AS CompanyVATNumber,
	|	CASE
	|		WHEN SalesOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|			THEN SalesOrder.Company.BankAccountByDefault
	|		ELSE SalesOrder.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN InventoryReservation.Value
	|			THEN SalesOrder.StructuralUnitReserve
	|	END AS StructuralUnit,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	Contracts.ProvideEPD AS ProvideEPD,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	SalesOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.VATTaxation AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	SalesOrder.PaymentMethod AS PaymentMethod,
	|	SalesOrder.CashAssetType AS CashAssetType,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.SetPaymentTerms AS SetPaymentTerms,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.Incoterms AS Incoterms,
	|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesOrder.GoodsMarking AS GoodsMarking,
	|	SalesOrder.LogisticsCompany AS LogisticsCompany,
	|	SalesOrder.DeliveryOption AS DeliveryOption,
	|	SalesOrder.SalesTaxRate AS SalesTaxRate,
	|	SalesOrder.SalesTaxPercentage AS SalesTaxPercentage,
	|	Contracts.DirectDebitMandate AS DirectDebitMandate
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SalesOrder.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON SalesOrder.DocumentCurrency = DC_Rates.Currency
	|			AND SalesOrder.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND SalesOrder.Company = CC_Rates.Company,
	|	Constant.UseInventoryReservation AS InventoryReservation
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrders.BasisRef AS BasisRef,
	|	TT_SalesOrders.BasisPosted AS BasisPosted,
	|	TT_SalesOrders.Closed AS Closed,
	|	TT_SalesOrders.OrderState AS OrderState,
	|	TT_SalesOrders.Company AS Company,
	|	TT_SalesOrders.CompanyVATNumber AS CompanyVATNumber,
	|	TT_SalesOrders.BankAccount AS BankAccount,
	|	TT_SalesOrders.StructuralUnit AS StructuralUnit,
	|	TT_SalesOrders.Counterparty AS Counterparty,
	|	TT_SalesOrders.Contract AS Contract,
	|	TT_SalesOrders.ProvideEPD AS ProvideEPD,
	|	TT_SalesOrders.PriceKind AS PriceKind,
	|	TT_SalesOrders.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrders.DiscountCard AS DiscountCard,
	|	TT_SalesOrders.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	TT_SalesOrders.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrders.VATTaxation AS VATTaxation,
	|	TT_SalesOrders.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrders.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrders.ExchangeRate AS ExchangeRate,
	|	TT_SalesOrders.Multiplicity AS Multiplicity,
	|	TT_SalesOrders.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TT_SalesOrders.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TT_SalesOrders.PaymentMethod AS PaymentMethod,
	|	TT_SalesOrders.CashAssetType AS CashAssetType,
	|	TT_SalesOrders.PettyCash AS PettyCash,
	|	TT_SalesOrders.SetPaymentTerms AS SetPaymentTerms,
	|	TT_SalesOrders.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrders.ContactPerson AS ContactPerson,
	|	TT_SalesOrders.Incoterms AS Incoterms,
	|	TT_SalesOrders.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	TT_SalesOrders.DeliveryTimeTo AS DeliveryTimeTo,
	|	TT_SalesOrders.GoodsMarking AS GoodsMarking,
	|	TT_SalesOrders.LogisticsCompany AS LogisticsCompany,
	|	TT_SalesOrders.DeliveryOption AS DeliveryOption,
	|	TT_SalesOrders.SalesTaxRate AS SalesTaxRate,
	|	TT_SalesOrders.SalesTaxPercentage AS SalesTaxPercentage,
	|	TT_SalesOrders.DirectDebitMandate AS DirectDebitMandate
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsShippedNotInvoiced.GoodsIssue AS GoodsIssue
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
	|		ON TT_SalesOrders.BasisRef = GoodsShippedNotInvoiced.SalesOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	ResultTable = QueryResults[1].Unload();
	If ResultTable.Count() > 0 Then
		
		For Each TableRow In ResultTable Do
			VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
				TableRow.OrderState,
				TableRow.Closed,
				TableRow.BasisPosted);
			Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(TableRow.BasisRef, VerifiedAttributesValues);
		EndDo;
		
		AddressesTable = ResultTable.Copy(, "ShippingAddress");
		AddressesTable.GroupBy("ShippingAddress");
		
		If AddressesTable.Count() = 1 Then
			ExcludingProperties = "";
		Else
			ExcludingProperties = "ContactPerson, Incoterms, DeliveryTimeFrom,
				|DeliveryTimeTo, GoodsMarking, LogisticsCompany, DeliveryOption, ShippingAddress";
		EndIf;
		
		FillPropertyValues(ThisObject, TableRow, , ExcludingProperties);
		
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("PackingSlip") Then
		DocumentData.Insert("PackingSlip", FillingData.PackingSlip);
		BasisDocument = FillingData.PackingSlip;
		
		If Not Common.ObjectAttributeValue(BasisDocument, "Posted") Then
			Raise NStr("en = 'Cannot generate documents from unposted documents. Post this document first. Then try again.'; ru = 'Создание документов на основании непроведенных документов запрещено. Проведите документ и повторите попытку.';pl = 'Nie można wygenerować dokumentów z niezatwierdzonych dokumentów. Najpierw zatwierdź ten dokument. Zatem spróbuj ponownie.';es_ES = 'No se han podido generar documentos desde los documentos no enviados. En primer lugar, envíe este documento. Inténtelo de nuevo.';es_CO = 'No se han podido generar documentos desde los documentos no enviados. En primer lugar, envíe este documento. Inténtelo de nuevo.';tr = 'Kaydedilmemiş belgelerden belge oluşturulamaz. Önce bu belgeyi kaydedip tekrar deneyin.';it = 'Impossibile creare i documenti dai documenti non pubblicati. Pubblicare prima questo documento, poi riprovare.';de = 'Fehler beim Generieren von Dokumenten aus nicht gebuchten Dokumenten. Buchen Sie dieses Dokument zuerst. Dann versuchen Sie erneut.'");	
		EndIf;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("OrderedProductsTable") Then
		FilterData = New Structure("OrdersArray, OrderedProductsTable", OrdersArray, FillingData.OrderedProductsTable);
		Documents.SalesInvoice.FillBySalesOrdersWithOrderedProducts(DocumentData, FilterData, Inventory);
	Else
		Documents.SalesInvoice.FillBySalesOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory, SerialNumbers);
	EndIf;
	
	// Bundles
	BundlesServer.FillAddedBundles(ThisObject, OrdersArray);
	// End Bundles
	
	GoodsIssuesArray = QueryResults[2].Unload().UnloadColumn("GoodsIssue");
	If GoodsIssuesArray.Count() Then
		
		IssuedInventory = Inventory.UnloadColumns();
		
		FilterData = New Structure("GoodsIssuesArray, Contract", GoodsIssuesArray, Contract);
		Documents.SalesInvoice.FillByGoodsIssues(DocumentData, FilterData, IssuedInventory);
		
		For Each IssuedProductsRow In IssuedInventory Do
			If Not OrdersArray.Find(IssuedProductsRow.Order) = Undefined Then
				FillPropertyValues(Inventory.Add(), IssuedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Inventory.Unload(, "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = ?(OrdersTable.Count() = 1, OrdersTable[0].Order, Undefined);
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() Then
		Order = OrdersTable[0].Order;
	EndIf;
	
	If TypeOf(FillingData) = Type("Structure")
		And FillingData.Property("PackingSlip") 
		And (OrdersArray.Count() = 0 Or Not ValueIsFilled(Order)) Then
		Raise NStr("en = 'Cannot generate ""Sales invoice"" from this Package slip. Package contents are inapplicable.
				|Ensure that they include only the items from Sales orders specified on the Main tab. Then try again.'; 
				|ru = 'Не удалось создать инвойс покупателю на основании данного упаковочного листа. Содержимое упаковки недопустимо.
				|Убедитесь, что она включает только товары из заказов покупателей, указанных на вкладке ""Основные данные"", и повторите попытку.';
				|pl = 'Nie można wygenerować ""Faktury sprzedaży"" z tego Listu przewozowego. Zawartość opakowania nie ma zastosowania.
				|Upewnij się, że zawierają one tylko elementy z Zamówień sprzedaży, określonych na karcie Podstawowe. Zatem spróbuj ponownie.';
				|es_ES = 'No se puede generar la ""Factura de ventas"" desde este Albarán de entrega. El contenido del albarán es inaplicable.
				|Asegúrese de que incluye sólo los artículos de las Órdenes de ventas especificadas en la pestaña Principal. Inténtelo de nuevo.';
				|es_CO = 'No se puede generar la ""Factura de ventas"" desde este Albarán de entrega. El contenido del albarán es inaplicable.
				|Asegúrese de que incluye sólo los artículos de las Órdenes de ventas especificadas en la pestaña Principal. Inténtelo de nuevo.';
				|tr = 'Bu Sevk irsaliyesinden ""Satış faturası"" oluşturulamıyor. Ambalaj içeriği uygulanamıyor.
				|Sadece Ana sekmede belirtilen Satış siparişlerindeki öğelerin içerildiğinden emin olup tekrar deneyin.';
				|it = 'Impossibile generare ""Fattura di vendita"" da questa Packing list. Il contenuto del pacchetto non è applicabile.
				|Assicurarsi che includano solo gli elementi dagli Ordini Cliente indicati nella scheda Principale, poi riprovare.';
				|de = 'Fehler beim Generieren von ""Verkaufsrechnung"" aus diesem Beipackzettel. Der Beipackinhalt ist nicht anwendbar.
				|Überprüfen Sie ob dieser nur die Artikel aus den Kundenaufträgen angegeben auf der Hauptregisterkarte enthalten. Dann versuchen Sie erneut.'");
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				OrdersArray[0]);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'; ru = 'Выбранные заказы уже отражены в учете.';pl = 'Wybrane zamówienia zostały już zafakturowane.';es_ES = 'Las facturas seleccionadas han sido facturadas ya.';es_CO = 'Las facturas seleccionadas han sido facturadas ya.';tr = 'Seçilen siparişler zaten faturalandırıldı';it = 'Gli ordini selezionati sono già stati fatturati.';de = 'Die ausgewählten Aufträge wurden bereits in Rechnung gestellt.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, GoodsIssuesArray);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, GoodsIssuesArray);
	EndIf;
	
	RecalculateSalesTax();
	
	SetPaymentTerms = False;
	If OrdersArray.Count() > 1 Then
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
	Else
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, Order);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EndIf;
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithCustomer);
	
EndProcedure

Procedure FillByWorkOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfWorkOrders") Then
		OrdersArray = FillingData.ArrayOfWorkOrders;
	Else
		OrdersArray.Add(FillingData.Ref);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkOrder.Ref AS BasisRef,
	|	WorkOrder.Posted AS BasisPosted,
	|	WorkOrder.Closed AS Closed,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.CompanyVATNumber AS CompanyVATNumber,
	|	CASE
	|		WHEN WorkOrder.BankAccount = VALUE(Catalog.BankAccounts.EmptyRef)
	|			THEN WorkOrder.Company.BankAccountByDefault
	|		ELSE WorkOrder.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN InventoryReservation.Value
	|			THEN WorkOrder.StructuralUnitReserve
	|	END AS StructuralUnit,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.PriceKind AS PriceKind,
	|	WorkOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	WorkOrder.DiscountCard AS DiscountCard,
	|	WorkOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.VATTaxation AS VATTaxation,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	WorkOrder.PaymentMethod AS PaymentMethod,
	|	WorkOrder.PettyCash AS PettyCash,
	|	WorkOrder.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrder.ContactPerson AS ContactPerson,
	|	WorkOrder.LogisticsCompany AS LogisticsCompany,
	|	WorkOrder.Location AS ShippingAddress,
	|	WorkOrder.CashAssetType AS CashAssetType,
	|	WorkOrder.SalesTaxRate AS SalesTaxRate,
	|	WorkOrder.SalesTaxPercentage AS SalesTaxPercentage,
	|	WorkOrder.SalesStructuralUnit AS Department
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON WorkOrder.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON WorkOrder.DocumentCurrency = DC_Rates.Currency
	|			AND WorkOrder.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND WorkOrder.Company = CC_Rates.Company,
	|	Constant.UseInventoryReservation AS InventoryReservation
	|WHERE
	|	WorkOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	QueryResult = Query.Execute();
	
	ResultTable = QueryResult.Unload();
	For Each TableRow In ResultTable Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			TableRow.OrderState,
			TableRow.Closed,
			TableRow.BasisPosted);
		Documents.WorkOrder.CheckAbilityOfEnteringByWorkOrder(TableRow.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	AddressesTable = ResultTable.Copy(, "ShippingAddress");
	AddressesTable.GroupBy("ShippingAddress");
	If AddressesTable.Count() = 1 Then
		ExcludingProperties = "";
	Else
		ExcludingProperties = "LogisticsCompany, ShippingAddress";
	EndIf;
	
	FillPropertyValues(ThisObject, TableRow, , ExcludingProperties);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	
	Documents.SalesInvoice.FillByWorkOrdersInventory(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	Documents.SalesInvoice.FillByWorkOrdersWorks(DocumentData, New Structure("OrdersArray", OrdersArray), Inventory);
	DiscountsAreCalculated = False;
	
	// Bundles
	BundlesServer.FillAddedBundles(ThisObject, OrdersArray);
	// End Bundles
	
	OrdersTable = Inventory.Unload(, "Order");
	OrdersTable.GroupBy("Order");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = ?(OrdersTable.Count() = 1, OrdersTable[0].Order, Undefined);
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() Then
		Order = OrdersTable[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				Order);
		Else
			MessageText = NStr("en = 'The selected orders have already been invoiced.'; ru = 'Выбранные заказы уже отражены в учете.';pl = 'Wybrane zamówienia zostały już zafakturowane.';es_ES = 'Las facturas seleccionadas han sido facturadas ya.';es_CO = 'Las facturas seleccionadas han sido facturadas ya.';tr = 'Seçilen siparişler zaten faturalandırıldı';it = 'Gli ordini selezionati sono già stati fatturati.';de = 'Die ausgewählten Aufträge wurden bereits in Rechnung gestellt.'");
		EndIf;
		Raise MessageText;
	EndIf;
	
	RecalculateSalesTax();
	
	SetPaymentTerms = False;
	If OrdersArray.Count() > 1 Then
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
	Else
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, Order);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EndIf;
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithCustomer);
	
EndProcedure

Procedure FillByRMARequest(FillingData) Export
	
	DocumentDate		= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Company AS Company,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequest.Ref AS BasisDocument,
	|	RMARequest.Company AS Company,
	|	RMARequest.Contract AS Contract,
	|	RMARequest.Counterparty AS Counterparty,
	|	RMARequest.Department AS SalesStructuralUnit,
	|	RMARequest.Location AS ShippingAddress,
	|	RMARequest.ContactPerson AS ContactPerson,
	|	RMARequest.Equipment AS Equipment,
	|	RMARequest.Characteristic AS Characteristic,
	|	RMARequest.ExpectedDate AS ShipmentDate
	|INTO RMARequestTable
	|FROM
	|	Document.RMARequest AS RMARequest
	|WHERE
	|	RMARequest.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	RMARequestTable.BasisDocument AS BasisDocument,
	|	RMARequestTable.Company AS Company,
	|	RMARequestTable.Contract AS Contract,
	|	RMARequestTable.Counterparty AS Counterparty,
	|	RMARequestTable.SalesStructuralUnit AS SalesStructuralUnit,
	|	RMARequestTable.ShippingAddress AS ShippingAddress,
	|	RMARequestTable.ContactPerson AS ContactPerson,
	|	RMARequestTable.Equipment AS Equipment,
	|	RMARequestTable.Characteristic AS Characteristic,
	|	ISNULL(CounterpartyContracts.SettlementsCurrency, RMARequestTable.Company.PresentationCurrency) AS DocumentCurrency,
	|	RMARequestTable.ShipmentDate AS ShipmentDate
	|INTO RMARequestWithCurrency
	|FROM
	|	RMARequestTable AS RMARequestTable
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON RMARequestTable.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RMARequestWithCurrency.BasisDocument AS BasisDocument,
	|	RMARequestWithCurrency.Company AS Company,
	|	RMARequestWithCurrency.Contract AS Contract,
	|	RMARequestWithCurrency.Counterparty AS Counterparty,
	|	RMARequestWithCurrency.SalesStructuralUnit AS SalesStructuralUnit,
	|	RMARequestWithCurrency.ShippingAddress AS ShippingAddress,
	|	RMARequestWithCurrency.ContactPerson AS ContactPerson,
	|	RMARequestWithCurrency.Equipment AS Equipment,
	|	RMARequestWithCurrency.Characteristic AS Characteristic,
	|	RMARequestWithCurrency.DocumentCurrency AS DocumentCurrency,
	|	TemporaryExchangeRate.ExchangeRate AS ExchangeRate,
	|	TemporaryExchangeRate.Multiplicity AS Multiplicity,
	|	TemporaryExchangeRate.ExchangeRate AS ContractCurrencyExchangeRate,
	|	TemporaryExchangeRate.Multiplicity AS ContractCurrencyMultiplicity,
	|	RMARequestWithCurrency.ShipmentDate AS ShipmentDate,
	|	CASE
	|		WHEN RMARequestWithCurrency.ShippingAddress <> VALUE(Catalog.ShippingAddresses.EmptyRef)
	|			THEN VALUE(Enum.DeliveryOptions.Delivery)
	|		ELSE VALUE(Enum.DeliveryOptions.SelfPickup)
	|	END AS DeliveryOption
	|FROM
	|	RMARequestWithCurrency AS RMARequestWithCurrency
	|		LEFT JOIN TemporaryExchangeRate AS TemporaryExchangeRate
	|		ON RMARequestWithCurrency.DocumentCurrency = TemporaryExchangeRate.Currency
	|			AND RMARequestWithCurrency.Company = TemporaryExchangeRate.Company";
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("DocumentDate", DocumentDate);
	
	QueryResults = Query.Execute();
	
	Header = QueryResults.Unload();
	
	If Header.Count() > 0 Then
		
		FillPropertyValues(ThisObject, Header[0]);
		
		DeliveryData = ShippingAddressesServer.GetDeliveryAttributesForAddress(Header[0].ShippingAddress);
		
		FillPropertyValues(ThisObject, DeliveryData);
		
		PriceKind 			= ?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.Wholesale);
		AmountIncludesVAT	= Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
		VATTaxation			= ?(ValueIsFilled(VATTaxation), VATTaxation, DriveServer.VATTaxation(Company, DocumentDate));
		
		Inventory.Clear();
		
		TabularSectionRow = Inventory.Add();
		
		StructureData = New Structure;
		StructureData.Insert("Company",							Company);
		StructureData.Insert("Products",						Header[0].Equipment);
		StructureData.Insert("Characteristic",					Header[0].Characteristic);
		StructureData.Insert("VATTaxation",						VATTaxation);
		StructureData.Insert("ProcessingDate",					DocumentDate);
		StructureData.Insert("DocumentCurrency",				DocumentCurrency);
		StructureData.Insert("AmountIncludesVAT",				AmountIncludesVAT);
		StructureData.Insert("PriceKind",						PriceKind);
		StructureData.Insert("Factor",							1);
		StructureData.Insert("DiscountMarkupKind",				DiscountMarkupKind);
		StructureData.Insert("DiscountCard",					DiscountCard);
		StructureData.Insert("DiscountPercentByDiscountCard",	DiscountPercentByDiscountCard);
		
		StructureData = GetDataProducts(StructureData);
		
		FillPropertyValues(TabularSectionRow, StructureData);
		
		TabularSectionRow.Quantity				= 1;
		TabularSectionRow.Content				= "";
		TabularSectionRow.ProductsTypeInventory	= StructureData.IsInventoryItem;
		TabularSectionRow.Amount				= TabularSectionRow.Quantity * TabularSectionRow.Price;
		
		If TabularSectionRow.DiscountMarkupPercent = 100 Then
			TabularSectionRow.Amount = 0;
		ElsIf TabularSectionRow.DiscountMarkupPercent <> 0 AND TabularSectionRow.Quantity <> 0 Then
			TabularSectionRow.Amount = TabularSectionRow.Amount * (1 - TabularSectionRow.DiscountMarkupPercent / 100);
		EndIf;
		
		VATRate = DriveReUse.GetVATRateValue(TabularSectionRow.VATRate);
		
		If AmountIncludesVAT Then
			TabularSectionRow.VATAmount = TabularSectionRow.Amount - TabularSectionRow.Amount / ((VATRate + 100) / 100);
		Else
			TabularSectionRow.VATAmount = TabularSectionRow.Amount * VATRate / 100;
		EndIf;
		
		TabularSectionRow.Total = TabularSectionRow.Amount + ?(AmountIncludesVAT, 0, TabularSectionRow.VATAmount);
		
		DocumentAmount = Inventory.Total("Total");
		
		SetPaymentTerms = False;
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithCustomer);
		
	EndIf;
	
EndProcedure

Procedure FillByQuote(FillingDataRef) Export
	
	// Filling out a document header.
	BasisDocument = FillingDataRef;
	
	FillingData = FillingDataRef.GetObject();
	
	Company				= FillingData.Company;
	CompanyVATNumber	= FillingData.CompanyVATNumber;
	BankAccount			= FillingData.BankAccount;
	PaymentMethod		= FillingData.PaymentMethod;
	CashAssetType		= FillingData.CashAssetType;
	Counterparty		= FillingData.Counterparty;
	PettyCash			= FillingData.PettyCash;
	Contract			= FillingData.Contract;
	PriceKind			= FillingData.PriceKind;
	DiscountMarkupKind	= FillingData.DiscountMarkupKind;
	DocumentCurrency	= FillingData.DocumentCurrency;
	AmountIncludesVAT	= FillingData.AmountIncludesVAT;
	VATTaxation			= FillingData.VATTaxation;
	Department		= FillingData.Department;
	SalesTaxRate		= FillingData.SalesTaxRate;
	SalesTaxPercentage	= FillingData.SalesTaxPercentage;
	// DiscountCards
	DiscountCard = FillingData.DiscountCard;
	DiscountPercentByDiscountCard = FillingData.DiscountPercentByDiscountCard;
	// End DiscountCards
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate = StructureByCurrency.Rate;
	Multiplicity = StructureByCurrency.Repetition;
	
	If ValueIsFilled(Contract) Then
		SettlementsCurrency = Common.ObjectAttributeValue(Contract, "SettlementsCurrency");
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, SettlementsCurrency, Company);
		ContractCurrencyExchangeRate = StructureByCurrency.Rate;
		ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		If Not TabularSectionRow.Variant = FillingData.PreferredVariant Then
			Continue;
		EndIf;
		
		If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem
			OR TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Service Then
		
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.ProductsTypeInventory = (NewRow.Products.ProductsType = Enums.ProductsTypes.InventoryItem);
			NewRow.SalesRep = FillingData.SalesRep;
			
		EndIf;
		
	EndDo;
	
	// Bundles
	BasisArray = New Array;
	BasisArray.Add(BasisDocument);
	BundlesServer.FillAddedBundles(ThisObject, BasisArray);
	// End Bundles
	
	// AutomaticDiscounts
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		DiscountsAreCalculated = True;
		DiscountsMarkups.Clear();
		For Each TabularSectionRow In FillingData.DiscountsMarkups Do
			If Inventory.Find(TabularSectionRow.ConnectionKey, "ConnectionKey") <> Undefined Then
				NewRowDiscountsMarkups = DiscountsMarkups.Add();
				FillPropertyValues(NewRowDiscountsMarkups, TabularSectionRow);
			EndIf;
		EndDo;
	EndIf;
	// End AutomaticDiscounts
	
	RecalculateSalesTax();
	
	// Cash flow projection
	If ThirdPartyPayment Then
		PaymentCalendar.Clear();
		SetPaymentTerms = False;
	Else
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, FillingDataRef);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EndIf;
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithCustomer);
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData, Operation = "") Export
	
	// Document basis and document setting.
	InvoicesArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfInvoices") Then
		InvoicesArray = FillingData.ArrayOfInvoices;
	Else
		InvoicesArray.Add(FillingData.Ref);
		
	EndIf; 
	
	UseDropShipping = GetFunctionalOption("UseDropShipping");
	If UseDropShipping Then
		StructureDropShippingData = Documents.SupplierInvoice.GetDropShippingData(InvoicesArray[0]);
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoice.Ref AS BasisRef,
	|	SupplierInvoice.Posted AS BasisPosted,
	|	SupplierInvoice.Company AS Company,
	|	SupplierInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoice.StructuralUnit AS StructuralUnit,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.Cell AS Cell,
	|	SupplierInvoice.IncludeVATInPrice AS IncludeVATInPrice,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	SupplierInvoice.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	SupplierInvoice.OperationKind AS SupplierInvoiceOperationKind,
	|	SupplierInvoice.Order AS SupplierInvoiceOrder
	|INTO TT_SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&InvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoices.BasisRef AS BasisRef,
	|	TT_SupplierInvoices.BasisPosted AS BasisPosted,
	|	TT_SupplierInvoices.Company AS Company,
	|	TT_SupplierInvoices.CompanyVATNumber AS CompanyVATNumber,
	|	TT_SupplierInvoices.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoices.DocumentCurrency AS DocumentCurrency,
	|	TT_SupplierInvoices.Cell AS Cell,
	|	TT_SupplierInvoices.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SupplierInvoices.ExchangeRate AS ExchangeRate,
	|	TT_SupplierInvoices.Multiplicity AS Multiplicity,
	|	TT_SupplierInvoices.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	TT_SupplierInvoices.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	TT_SupplierInvoices.SupplierInvoiceOperationKind AS SupplierInvoiceOperationKind,
	|	TT_SupplierInvoices.SupplierInvoiceOrder AS SupplierInvoiceOrder
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TT_SupplierInvoices.StructuralUnit AS StructuralUnit
	|FROM
	|	TT_SupplierInvoices AS TT_SupplierInvoices
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(TableCounterDropShippingInvoices.CountInvoices) AS CountInvoices,
	|	SUM(TableCounterDropShippingInvoices.CountDropShippingInvoices) AS CountDropShippingInvoices
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_SupplierInvoices.BasisRef) AS CountInvoices,
	|		0 AS CountDropShippingInvoices
	|	FROM
	|		TT_SupplierInvoices AS TT_SupplierInvoices
	|	WHERE
	|		&UseDropShipping
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		COUNT(DISTINCT TT_SupplierInvoices.BasisRef)
	|	FROM
	|		TT_SupplierInvoices AS TT_SupplierInvoices
	|	WHERE
	|		TT_SupplierInvoices.SupplierInvoiceOperationKind = VALUE(Enum.OperationTypesSupplierInvoice.DropShipping)
	|		AND &UseDropShipping) AS TableCounterDropShippingInvoices";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("UseDropShipping", UseDropShipping);
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("Posted", Selection.BasisPosted);
		Documents.SupplierInvoice.CheckAbilityOfEnteringBySupplierInvoice(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	If UseDropShipping Then
		Documents.SupplierInvoice.CheckAbilityOfDropShippingEnteringBySupplierInvoice(QueryResults[3].Select());
	EndIf;
	
	FillPropertyValues(ThisObject, Selection);
	
	If UseDropShipping 
		And StructureDropShippingData.IsDropShipping Then
		FillPropertyValues(ThisObject, StructureDropShippingData);
	EndIf;
	
	VATTaxation = DriveServer.VATTaxation(Company, Date);

	StructuralUnitSelection = QueryResults[2].Select();
	
	If StructuralUnitSelection.Count() > 1 OR Not ValueIsFilled(StructuralUnit) Then
		
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	
	EndIf;
		
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("VATTaxation", VATTaxation);
	DocumentData.Insert("PriceKind", PriceKind);

	Documents.SalesInvoice.FillBySupplierInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), Inventory, SerialNumbers);
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	For Each FillingDataInvoice In InvoicesArray Do
		WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingDataInvoice);
	EndDo;
	
	// Cash flow projection
	If ThirdPartyPayment Then
		PaymentCalendar.Clear();
		SetPaymentTerms = False;
	Else
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, InvoicesArray);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	EndIf;
	
EndProcedure

Procedure FillByGoodsIssue(FillingData) Export
	
	// Document basis and document setting.
	GoodsIssuesArray = New Array;
	Contract = Undefined;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfGoodsIssues") Then
		
		For Each ArrayItem In FillingData.ArrayOfGoodsIssues Do
			Contract = ArrayItem.Contract;
			GoodsIssuesArray.Add(ArrayItem.Ref);
		EndDo;
		
		GoodsIssue = GoodsIssuesArray[0];
		
	Else
		GoodsIssuesArray.Add(FillingData.Ref);
		GoodsIssue = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsIssue.Ref AS BasisRef,
	|	GoodsIssue.Posted AS BasisPosted,
	|	GoodsIssue.Company AS Company,
	|	GoodsIssue.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsIssue.StructuralUnit AS StructuralUnit,
	|	GoodsIssue.Cell AS Cell,
	|	GoodsIssue.Contract AS Contract,
	|	GoodsIssue.Order AS Order,
	|	GoodsIssue.Counterparty AS Counterparty,
	|	GoodsIssue.ShippingAddress AS ShippingAddress,
	|	GoodsIssue.ContactPerson AS ContactPerson,
	|	GoodsIssue.Incoterms AS Incoterms,
	|	GoodsIssue.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GoodsIssue.DeliveryTimeTo AS DeliveryTimeTo,
	|	GoodsIssue.GoodsMarking AS GoodsMarking,
	|	GoodsIssue.LogisticsCompany AS LogisticsCompany,
	|	GoodsIssue.DeliveryOption AS DeliveryOption,
	|	GoodsIssue.OperationType AS OperationType,
	|	GoodsIssue.VATTaxation AS VATTaxation
	|INTO GoodsIssueHeader
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref IN(&GoodsIssuesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsIssueHeader.BasisRef AS BasisRef,
	|	GoodsIssueHeader.BasisPosted AS BasisPosted,
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Cell AS Cell,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueProducts.Contract
	|		ELSE GoodsIssueHeader.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE GoodsIssueHeader.Order
	|	END AS Order,
	|	GoodsIssueHeader.ShippingAddress AS ShippingAddress,
	|	GoodsIssueHeader.ContactPerson AS ContactPerson,
	|	GoodsIssueHeader.Incoterms AS Incoterms,
	|	GoodsIssueHeader.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GoodsIssueHeader.DeliveryTimeTo AS DeliveryTimeTo,
	|	GoodsIssueHeader.GoodsMarking AS GoodsMarking,
	|	GoodsIssueHeader.LogisticsCompany AS LogisticsCompany,
	|	GoodsIssueHeader.DeliveryOption AS DeliveryOption,
	|	GoodsIssueHeader.OperationType AS OperationType,
	|	GoodsIssueHeader.VATTaxation AS VATTaxation
	|INTO GIFiltred
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.BasisRef = GoodsIssueProducts.Ref
	|			AND (GoodsIssueProducts.Contract = &Contract
	|				OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GIFiltred.BasisRef AS BasisRef,
	|	GIFiltred.BasisPosted AS BasisPosted,
	|	GIFiltred.Company AS Company,
	|	GIFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	GIFiltred.StructuralUnit AS StructuralUnit,
	|	GIFiltred.Cell AS Cell,
	|	GIFiltred.Counterparty AS Counterparty,
	|	GIFiltred.Contract AS Contract,
	|	GIFiltred.Order AS Order,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	SalesOrder.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	ISNULL(SalesOrder.DocumentCurrency, Contracts.SettlementsCurrency) AS DocumentCurrency,
	|	ISNULL(SalesOrder.VATTaxation, GIFiltred.VATTaxation) AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	SalesOrder.PaymentMethod AS PaymentMethod,
	|	SalesOrder.CashAssetType AS CashAssetType,
	|	SalesOrder.PettyCash AS PettyCash,
	|	SalesOrder.SetPaymentTerms AS SetPaymentTerms,
	|	SalesOrder.BankAccount AS BankAccount,
	|	GIFiltred.ShippingAddress AS ShippingAddress,
	|	GIFiltred.ContactPerson AS ContactPerson,
	|	GIFiltred.Incoterms AS Incoterms,
	|	GIFiltred.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	GIFiltred.DeliveryTimeTo AS DeliveryTimeTo,
	|	GIFiltred.GoodsMarking AS GoodsMarking,
	|	GIFiltred.LogisticsCompany AS LogisticsCompany,
	|	GIFiltred.DeliveryOption AS DeliveryOption,
	|	GIFiltred.OperationType AS OperationType
	|FROM
	|	GIFiltred AS GIFiltred
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON GIFiltred.Order = SalesOrder.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON GIFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON (ISNULL(SalesOrder.DocumentCurrency, Contracts.SettlementsCurrency) = DC_Rates.Currency)
	|			AND GIFiltred.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND GIFiltred.Company = CC_Rates.Company
	|
	|ORDER BY
	|	Order DESC";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("GoodsIssuesArray", GoodsIssuesArray);
	Query.SetParameter("Contract", Contract);
	
	ResultTable = Query.Execute().Unload();
	For Each TableRow In ResultTable Do
		Documents.GoodsIssue.CheckAbilityOfEnteringByGoodsIssue(ThisObject, TableRow.BasisRef, TableRow.BasisPosted, TableRow.OperationType);
	EndDo;
	
	If ResultTable.Count() > 0 Then
		TableRow = ResultTable[0];
	EndIf;
	
	AddressesTable = ResultTable.Copy(, "ShippingAddress");
	AddressesTable.GroupBy("ShippingAddress");
	
	If AddressesTable.Count() = 1 Then
		ExcludingProperties = "";
	Else
		ExcludingProperties = "ContactPerson, Incoterms, DeliveryTimeFrom,
			|DeliveryTimeTo, GoodsMarking, LogisticsCompany, DeliveryOption, ShippingAddress";
	EndIf;
	
	FillPropertyValues(ThisObject, TableRow, , ExcludingProperties);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	    
	FilterData = New Structure("GoodsIssuesArray, Contract", GoodsIssuesArray, Contract);
	
	Documents.SalesInvoice.FillByGoodsIssues(DocumentData, FilterData, Inventory);
	
	// Bundles
	BundlesServer.FillAddedBundles(ThisObject, GoodsIssuesArray, "Products");
	// End Bundles
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Inventory.Unload(, "Order, GoodsIssue");
	OrdersTable.GroupBy("Order, GoodsIssue");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
		
	EndIf;
	
	OrdersTable.GroupBy("Order");
	
	If OrdersTable.Count() = 1
		And ValueIsFilled(OrdersTable[0].Order) 
		And Not ThirdPartyPayment Then
		
		PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, OrdersTable[0].Order);
		PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	Else
		SetPaymentTerms = False;
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
	EndIf;
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	EarlyPaymentDiscountsServer.FillEarlyPaymentDiscounts(ThisObject, Enums.ContractType.WithCustomer);
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
	ElsIf Not ValueIsFilled(Order) AND GoodsIssuesArray.Count() > 0 Then
		Order = GoodsIssuesArray[0].Order;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If GoodsIssuesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				GoodsIssue);
		Else
			MessageText = NStr("en = 'The selected goods issues have already been invoiced.'; ru = 'Выбранные документы ""Отпуск товаров"" уже отражены в учете.';pl = 'Wybrane wydania zewnętrzne są już zafakturowane.';es_ES = 'Las salidas de mercancías seleccionadas han sido facturadas ya.';es_CO = 'Las expediciones de los productos seleccionados han sido facturadas ya.';tr = 'Seçilen Ambar çıkışları zaten faturalandırıldı.';it = 'Le spedizioni merci selezionate sono già state fatturate.';de = 'Die ausgewählten Warenausgänge wurden bereits fakturiert.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByReserves() Export
	DocumentData = New Structure;
	DocumentData.Insert("Date", Date);
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	DocumentData.Insert("Order", Order);
	DocumentData.Insert("SalesOrderPosition", SalesOrderPosition);
	Documents.SalesInvoice.FillColumnReserveByReserves(DocumentData, Inventory);	
EndProcedure

Function GetDataProducts(StructureData)
	
	ProductsAttributes = Common.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, VATRate, ProductsType");
	
	StructureData.Insert("MeasurementUnit", ProductsAttributes.MeasurementUnit);
	StructureData.Insert("IsInventoryItem", (ProductsAttributes.ProductsType = Enums.ProductsTypes.InventoryItem));
	
	If StructureData.Property("VATTaxation") 
		AND NOT StructureData.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If StructureData.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			StructureData.Insert("VATRate", Catalogs.VATRates.Exempt);
		Else
			StructureData.Insert("VATRate", Catalogs.VATRates.ZeroRate);
		EndIf;
		
	ElsIf ValueIsFilled(StructureData.Products) And ValueIsFilled(ProductsAttributes.VATRate) Then
		StructureData.Insert("VATRate", ProductsAttributes.VATRate);
	Else
		StructureData.Insert("VATRate", InformationRegisters.AccountingPolicy.GetDefaultVATRate(, StructureData.Company));
	EndIf;
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	If StructureData.Property("PriceKind") Then
		
		If Not StructureData.Property("Characteristic") Then
			StructureData.Insert("Characteristic", Catalogs.ProductsCharacteristics.EmptyRef());
		EndIf;
		
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
		
	Else
		
		StructureData.Insert("Price", 0);
		
	EndIf;
	
	If StructureData.Property("DiscountMarkupKind") 
		AND ValueIsFilled(StructureData.DiscountMarkupKind) Then
		StructureData.Insert("DiscountMarkupPercent", 
			Common.ObjectAttributeValue(StructureData.DiscountMarkupKind, "Percent"));
	Else
		StructureData.Insert("DiscountMarkupPercent", 0);
	EndIf;
		
	If StructureData.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(StructureData.DiscountCard) Then
		CurPercent = StructureData.DiscountMarkupPercent;
		StructureData.Insert("DiscountMarkupPercent", CurPercent + StructureData.DiscountPercentByDiscountCard);
	EndIf;
	
	Return StructureData;
	
EndFunction

Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.LineNumber AS LineNumber,
	|	TableInventory.Quantity AS Quantity,
	|	TableInventory.Factor AS Factor,
	|	TableInventory.Specification AS Specification
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		ConsumerMaterials.Clear();
		TableInventory = Inventory.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableInventory.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableInventory Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableInventory.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableInventory", TableInventory);
	Else
		Query.SetParameter("TableInventory", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS ProductionLineNumber,
	|	TableInventory.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.Ref.Quantity * TableInventory.Factor * TableInventory.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON (TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.ThirdPartyMaterial))
	|			AND TableInventory.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableInventory.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'; 
				                   |ru = 'При попытке заполнить табличную
				                   |часть Материалы по спецификации, обнаружено рекурсивное вхождение элемента';
				                   |pl = 'Podczas wypełniania sekcji tabelarycznej
				                   |""Specyfikacja materiałowa"", wykryto rekursywne włączenie elementu';
				                   |es_ES = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |es_CO = 'Rellenando la sección tabular
				                   |de Materiales de Especificación, una ocurrencia del artículo recursivo se ha encontrado';
				                   |tr = 'Spesifikasyon materyalleri sekme kısmının doldurulması sırasında
				                   |, tekrarlamalı bir öğe oluşumu bulundu.';
				                   |it = 'Durante la compilazione delle Distinte Base dei materiali
				                   |sono stati trovati elementi ricorsivi nella sezione tabellare';
				                   |de = 'Beim Ausfüllen des
				                   |Tabellenbereichs Spezifikationsmaterialien wurde ein rekursives Element gefunden'")+" "+Selection.Products+" "+NStr("en = 'in BOM'; ru = 'в спецификации';pl = 'w zestawieniu materiałowym';es_ES = 'en BOM';es_CO = 'en BOM';tr = 'ürün reçetesinde';it = 'in Distinta Base';de = 'in der Stückliste'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable);
		Else
			NewRow = ConsumerMaterials.Add();
			FillPropertyValues(NewRow, Selection);
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	ConsumerMaterials.GroupBy("Products, Characteristic, MeasurementUnit", "Quantity");
	
EndProcedure

Procedure FillTabularSectionByGoodsConsumed() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	GoodsConsumedToDeclareBalance.Products AS Products,
	|	GoodsConsumedToDeclareBalance.Characteristic AS Characteristic,
	|	GoodsConsumedToDeclareBalance.Batch AS Batch,
	|	GoodsConsumedToDeclareBalance.QuantityBalance AS Quantity,
	|	ISNULL(GoodsConsumedToDeclareBalance.Products.MeasurementUnit, VALUE(Catalog.UOM.EmptyRef)) AS MeasurementUnit
	|FROM
	|	AccumulationRegister.GoodsConsumedToDeclare.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty) AS GoodsConsumedToDeclareBalance
	|		LEFT JOIN Catalog.Products AS ProductsTable
	|		ON GoodsConsumedToDeclareBalance.Products = ProductsTable.Ref";
	
	Query.SetParameter("Company",		Company);
	Query.SetParameter("Counterparty",	Counterparty);
	
	ConsumerMaterials.Load(Query.Execute().Unload());
	
EndProcedure

Procedure RecalculateSalesTax() Export
	
	SalesTax.Clear();
	
	If ValueIsFilled(SalesTaxRate) Then
		
		InventoryTaxable = Inventory.Unload(New Structure("Taxable", True));
		AmountTaxable = InventoryTaxable.Total("Total");
		
		If AmountTaxable <> 0 Then
			
			Combined = Common.ObjectAttributeValue(SalesTaxRate, "Combined");
			
			If Combined Then
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	SalesTaxRatesTaxComponents.Component AS SalesTaxRate,
				|	SalesTaxRatesTaxComponents.Rate AS SalesTaxPercentage,
				|	CAST(&AmountTaxable * SalesTaxRatesTaxComponents.Rate / 100 AS NUMBER(15, 2)) AS Amount
				|FROM
				|	Catalog.SalesTaxRates.TaxComponents AS SalesTaxRatesTaxComponents
				|WHERE
				|	SalesTaxRatesTaxComponents.Ref = &Ref";
				
				Query.SetParameter("Ref", SalesTaxRate);
				Query.SetParameter("AmountTaxable", AmountTaxable);
				
				SalesTax.Load(Query.Execute().Unload());
				
			Else
				
				NewRow = SalesTax.Add();
				NewRow.SalesTaxRate = SalesTaxRate;
				NewRow.SalesTaxPercentage = SalesTaxPercentage;
				NewRow.Amount = Round(AmountTaxable * SalesTaxPercentage / 100, 2, RoundMode.Round15as20);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"));
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesOrder")]			= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.Quote")]				= "FillByQuote";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]			= "FillByGoodsIssue";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.WorkOrder")]			= "FillByWorkOrder";
	FillingStrategy[Type("DocumentRef.RMARequest")]			= "FillByRMARequest";
	
	ExcludingProperties = "Order";
	If TypeOf(FillingData) = Type("Structure") Then
		If FillingData.Property("ArrayOfSalesOrders") Then
			ExcludingProperties = ExcludingProperties + ", AmountIncludesVAT";
		ElsIf FillingData.Property("ClosingInvoiceProcessing") Then
			ExcludingProperties = ExcludingProperties + ", AmountIncludesVAT, PriceKind, Department";
		EndIf;
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
	If TypeOf(FillingData) = Type("CatalogRef.Counterparties") Then
		
		PaymentTermsServer.FillPaymentCalendarFromContract(ThisObject);
		ShippingAddress = Undefined;
		
	EndIf;
	
	If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
		DeliveryData = ShippingAddressesServer.GetDeliveryDataForCounterparty(Counterparty);
		If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
			DeliveryOption = DeliveryData.DeliveryOption;
		EndIf;
		If Not ValueIsFilled(DeliveryOption) Or Not ValueIsFilled(ShippingAddress) Then
			ShippingAddress = DeliveryData.ShippingAddress;
		EndIf;
	EndIf;
	
	If Not ValueIsFilled(OperationKind) Then
		OperationKind = Enums.OperationTypesSalesInvoice.Invoice;
	EndIf;
	
	If Not ValueIsFilled(DeliveryDatePeriod) Then
		DeliveryDatePeriod = Enums.DeliveryDatePeriod.Date;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			TabularSectionRow.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each TabularSectionRow In Prepayment Do
				TabularSectionRow.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	For Each TabularSectionRow In Inventory Do
		If IsRegisterDeliveryDate Or OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
			If DeliveryDatePosition = Enums.AttributeStationing.InHeader Then
				TabularSectionRow.DeliveryStartDate = DeliveryStartDate;
				TabularSectionRow.DeliveryEndDate = DeliveryEndDate;
			EndIf;
		Else
			TabularSectionRow.DeliveryStartDate = Date;
			TabularSectionRow.DeliveryEndDate = Date;
		EndIf;
	EndDo;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"));
	
	Totals = DriveServer.CalculateSubtotal(Inventory, AmountIncludesVAT, SalesTax);
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Totals.DocumentTotal;
		
	EndIf;
	
	DocumentTax = Totals.DocumentTax;
	DocumentSubtotal = Totals.DocumentSubtotal;
	
	If OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
		
		If DocumentAmount < 0 Then
			
			If AmountAllocation.Count() = 0 Then
				
				FillAmountAllocation();
				
				If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
					FillGLAccountsForAmountAllocation();
				EndIf;
				
			EndIf;
			
			Prepayment.Clear();
			
		Else
			AmountAllocation.Clear();
		EndIf;
	Else
		AmountAllocation.Clear();
	EndIf;
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	If ThirdPartyPayment Then
		ClearTabularSectionsWithThirdPartyPayment();
	EndIf;
	
	FillSalesRep();
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillOwnershipTable(ThisObject, WriteMode, Cancel);
	
	If WriteMode = DocumentWriteMode.Posting And QuotationStatuses.CheckQuotationStatusToConverted(BasisDocument) Then
		AdditionalProperties.Insert("QuoteStatusToConverted", True);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	CheckedAttributes.Add("Department");
	
	OrderInHeader = SalesOrderPosition = Enums.AttributeStationing.InHeader;
	
	TableInventory = Inventory.Unload(, "Order, Total");
	TableInventory.GroupBy("Order", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	If OrderInHeader Then
		For Each StringInventory In TableInventory Do
			StringInventory.Order = Order;
		EndDo;
		If Counterparty.DoOperationsByOrders Then
			For Each RowPrepayment In TablePrepayment Do
				RowPrepayment.Order = Order;
			EndDo;
		EndIf;
	EndIf;
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringInventory = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.SalesOrder.EmptyRef()
		   AND String.Order <> Documents.PurchaseOrder.EmptyRef() Then
			FoundStringInventory = TableInventory.Find(String.Order, "Order");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "Order");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.SalesOrder.EmptyRef(), "Order"), FoundStringInventory);
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.PurchaseOrder.EmptyRef(), "Order"), FoundStringInventory);				
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'You can''t make an advance clearing against the sales order if the sales invoice doesn''t refer to this sales order.'; ru = 'Нельзя зачесть аванс по заказу покупателя, если инвойс не относится к данному заказу.';pl = 'Nie można wykonać zaliczki na poczet zamówienia sprzedaży, jeśli faktura sprzedaży nie odnosi się do tego zamówienia sprzedaży.';es_ES = 'Usted no puede realizar una liquidación de anticipos contra el orden de ventas si la factura de ventas no se refiere a este orden de ventas.';es_CO = 'Usted no puede realizar una liquidación de anticipo contra la orden de ventas si la factura de ventas no se refiere a esta orden de ventas.';tr = 'Satış faturası bu satış siparişi ile ilgili değilse, satış siparişine karşı peşin mahsuplaştırılma yapılamaz.';it = 'Non è possibile una compensazione dell''anticipo in relazione all''ordine cliente  se la fattura di vendita non fa riferimento a questo ordine Cliente.';de = 'Sie können keine Vorschussverrechnung mit dem Kundenauftrag vornehmen, wenn die Verkaufsrechnung nicht auf diesen Kundenauftrag verweist.'");
			DriveServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel
			);
		EndIf;
	EndDo;
	
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity
				And StringInventory.Reserve > 0 Then
				
				MessageText = NStr("en = 'On the Products tab, in line #%1, Reserve is greater than Quantity.
					|To be able to continue, either decrease Reserve or increase Quantity.'; 
					|ru = 'Во вкладке Номенклатура в строке %1 Резерв превышает Количество.
					|Для продолжения либо уменьшите Резерв, либо увеличьте Количество.';
					|pl = 'Na karcie Produkty, w wierszu nr%1, Rezerwa jest większa niż Ilość.
					|Aby mieć możliwość kontynuowania, zmniejsz Rezerwę lub zwiększ Ilość.';
					|es_ES = 'En la pestaña Productos, en la línea #%1, la Reserva es mayor que la Cantidad.
					|Para poder continuar, disminuya la Reserva o aumente la Cantidad.';
					|es_CO = 'En la pestaña Productos, en la línea #%1, la Reserva es mayor que la Cantidad.
					|Para poder continuar, disminuya la Reserva o aumente la Cantidad.';
					|tr = 'Ürünler sekmesinin %1 numaralı satırında Rezerve değeri Miktar değerinden büyük.
					|Devam edebilmek için Rezerve''yi azaltın veya Miktar''ı artırın.';
					|it = 'Nella scheda Articoli, nella riga #%1, Riserva è maggiore di Quantità. 
					|Per poter continuare, ridurre Riserva o aumentare Quantità.';
					|de = 'Auf der Registerkarte Produkte in der Zeile #%1, ist Reserve mehr als Menge.
					|Um fortfahren zu können, reduzieren Sie Reserve oder erhöhen Menge.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts");
	
	If ThereAreManualDiscounts
		OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			// AutomaticDiscounts
			CurAmount = StringInventory.Price * StringInventory.Quantity;
			
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, Round(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Please fill the amount in line #%1 of the Products list.'; ru = 'Не заполнена колонка ""Сумма"" в строке %1 списка ""Запасы"".';pl = 'Proszę wypełnić kwotę w wierszu #%1 Listy produktów.';es_ES = 'Por favor, rellene el importe en la línea #%1 de la lista Productos.';es_CO = 'Por favor, rellene el importe en la línea #%1 de la lista Productos.';tr = 'Ürün listesinin %1 # satırındaki tutarı doldurun.';it = 'Si prega di compilare l''importo nella linea #%1 dell''elenco Articoli.';de = 'Bitte geben Sie den Betrag in Zeile Nr %1 der Produktliste ein.'"),
								StringInventory.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Serial numbers
	If OperationKind = Enums.OperationTypesSalesInvoice.Invoice Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
		BatchesServer.CheckFilling(ThisObject, Cancel);
		CheckExpiredBatches(Cancel);
	EndIf;
	
	//Cash flow projection
	Amount = Inventory.Total("Amount") + SalesTax.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	// Advances
	If OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice Then
		If Not IsNew() Then
			AdvanceInvoicingDateCheck(Cancel);
		EndIf;
	EndIf;
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
	If Not (GetFunctionalOption("UseThirdPartyPayment") And ThirdPartyPayment) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Payer");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PayerContract");
	EndIf;
	
	If OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
		
		CheckedAttributes.Add("DeliveryDatePeriod");
		
		CheckedAttributes.Add("DeliveryStartDate");
		If DeliveryDatePeriod <> Enums.DeliveryDatePeriod.Date Then
			CheckedAttributes.Add("DeliveryEndDate");
		EndIf;
		
		If DeliveryDatePosition = Enums.AttributeStationing.InTabularSection Then
			CheckedAttributes.Add("Inventory.DeliveryStartDate");
			If DeliveryDatePeriod <> Enums.DeliveryDatePeriod.Date Then
				CheckedAttributes.Add("Inventory.DeliveryEndDate");
			EndIf;
		EndIf;
	
	EndIf;
	
	// Zero invoice
	If OperationKind = Enums.OperationTypesSalesInvoice.ZeroInvoice Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Price");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Amount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.Quantity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.MeasurementUnit");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Inventory.VATRate");
		
	Else
		
		For Each Row In Inventory Do
			
			If Not ValueIsFilled(Row.RevenueItem)
				And (Not OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
					Or ValueIsFilled(Row.GoodsIssue) Or Not Row.ProductsTypeInventory) Then
				
				DriveServer.ShowMessageAboutError(
						ThisObject,
						StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'Revenue item is required in line #%1 of the Products list.'; ru = 'Не заполнена статья выручки в строке %1 списка ""Номенклатура"".';pl = 'Pozycja przychodu jest wymagana w wierszu nr %1 listy Produkty.';es_ES = 'Se requiere el artículo de ingresos en la línea #%1 de la lista Productos.';es_CO = 'Se requiere el artículo de ingresos en la línea #%1 de la lista Productos.';tr = 'Ürünler listesinin %1 nolu satırında hasılat kalemi gerekli.';it = 'La voce di ricavo è richiesta nella riga #%1 dell''elenco Articoli.';de = 'Die Position von Erlös ist in Zeile Nr %1 der Produktliste erforderlich.'"),
							Row.LineNumber),
						"Inventory",
						Row.LineNumber,
						"RevenueItem",
						Cancel);
		
			EndIf;
			
			If Not ValueIsFilled(Row.COGSItem)
				And (Row.ProductsTypeInventory
					And Not OperationKind = Enums.OperationTypesSalesInvoice.AdvanceInvoice
						Or ValueIsFilled(Row.GoodsIssue)) Then
				
				DriveServer.ShowMessageAboutError(
						ThisObject,
						StringFunctionsClientServer.SubstituteParametersToString(
							NStr("en = 'COGS item is required in line #%1 of the Products list.'; ru = 'Не заполнена статья себестоимости продаж в строке %1 списка ""Номенклатура"".';pl = 'Pozycja KWS jest wymagana w wierszu nr %1 listy Produkty.';es_ES = 'Se requiere el artículo de precio de coste en la línea #%1 de la lista Productos.';es_CO = 'Se requiere el artículo de precio de coste en la línea #%1 de la lista Productos.';tr = 'Ürünler listesinin %1 nolu satırında SMM kalemi gerekli.';it = 'Voce di costo del venduto nella riga #%1 dell''elenco Articoli.';de = 'Die Position von Wareneinsatz ist in Zeile Nr %1 der Produktliste erforderlich.'"),
							Row.LineNumber),
						"Inventory",
						Row.LineNumber,
						"COGSItem",
						Cancel);
				
			EndIf;
		
		EndDo;
		
	EndIf;
	
	If OperationKind = Enums.OperationTypesSalesInvoice.ClosingInvoice Then
		DriveServer.CheckInventoryForNonServices(ThisObject, Cancel);
	EndIf;
		
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.SalesInvoice.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	//Limit Exceed Control (if the "Override credit limit settings" it not set)
	If Not OverrideCreditLimitSettings Then
		
		DriveServer.CheckLimitsExceed(ThisObject, True, Cancel);
		
	EndIf;
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsConsumedToDeclare(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	DriveServer.ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectThirdPartyPayments(AdditionalProperties, RegisterRecords, Cancel);
	
	// DiscountCards
	DriveServer.ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);

	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);

	//VAT
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Sales tax
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		If Not AdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments
			And OperationKind <> Enums.OperationTypesSalesInvoice.ZeroInvoice Then
			
			If AdditionalProperties.AccountingPolicy.IssueAutomaticallyAgainstSales Then
				WorkWithVAT.CreateTaxInvoice(DocumentWriteMode.Posting, Ref)
			EndIf;
			
			WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
			
		EndIf;
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	Documents.SalesInvoice.RunControl(Ref, AdditionalProperties, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate documents
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
	EndIf;
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	Documents.SalesInvoice.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
	Prepayment.Clear();
	PrepaymentVAT.Clear();
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	ForOpeningBalancesOnly = False;
	
	InventoryOwnership.Clear();
	
	AllowExpiredBatches = False;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	EDIServer.OnWrite_ObjectModule(Ref, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
			
	EndIf;
	
	If AdditionalProperties.Property("QuoteStatusToConverted") And AdditionalProperties.QuoteStatusToConverted Then
		QuotationStatuses.SetQuotationStatus(BasisDocument, Catalogs.QuotationStatuses.Converted);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure FillGLAccountsForAmountAllocation()
	
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Ref", Ref);
	ObjectParameters.Insert("DocumentName", Ref.Metadata().Name);
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("Counterparty", Counterparty);
	ObjectParameters.Insert("Contract", Contract);
	ObjectParameters.Insert("VATTaxation", VATTaxation);
	ObjectParameters.Insert("OperationKind", OperationKind);
	
	StructureData = IncomeAndExpenseItemsInDocuments.GetCounterpartyStructureData(ObjectParameters, "AmountAllocation");
	GLAccountsInDocuments.CompleteCounterpartyStructureData(StructureData, ObjectParameters, "AmountAllocation");
	
	For Each Row In AmountAllocation Do
		
		FillPropertyValues(StructureData, Row);
		GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
		FillPropertyValues(Row, StructureData);
		
	EndDo;
	
EndProcedure

Procedure CheckExpiredBatches(Cancel)
	
	If Not GetFunctionalOption("UseBatches") Or AllowExpiredBatches Then
		Return;
	EndIf;
	
	EmptyGoodsIssueFilter = New Structure("GoodsIssue", Documents.GoodsIssue.EmptyRef());
	BatchesTable = Inventory.Unload(EmptyGoodsIssueFilter, "LineNumber, Products, Batch, DeliveryEndDate");
	BatchesTable.Columns.DeliveryEndDate.Name = "DeliveryDate";
	
	For Each BatchesRow In BatchesTable Do
		If IsRegisterDeliveryDate And DeliveryDatePosition = Enums.AttributeStationing.InHeader Then
			BatchesRow.DeliveryDate = DeliveryEndDate;
		EndIf;
		If Not ValueIsFilled(BatchesRow.DeliveryDate) Then
			BatchesRow.DeliveryDate = Date;
		EndIf;
	EndDo;
	
	Parameters = New Structure;
	Parameters.Insert("BatchesTable", BatchesTable);
	Parameters.Insert("DocObject", ThisObject);
	
	BatchesServer.CheckExpiredBatches(Parameters, Cancel);
	
EndProcedure

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

Procedure AdvanceInvoicingDateCheck(Cancel)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	MIN(GoodsInvoicedNotShipped.Period) AS Period
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|WHERE
	|	GoodsInvoicedNotShipped.SalesInvoice = &Ref
	|	AND GoodsInvoicedNotShipped.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND GoodsInvoicedNotShipped.Period <= &Date";
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Date", Date);
	
	Sel = Query.Execute().Select();
	If Sel.Next() And ValueIsFilled(Sel.Period) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'An advance invoice must be dated earlier than its subordinate goods issues are (%1).'; ru = 'Дата авансового инвойса должна быть меньше, чем дата подчиненных документов ""Отпуск товаров"" (%1).';pl = 'Faktura zaliczkowa musi być opatrzona datą wcześniejszą, niż są jej podrzędne wydania zewnętrzne(%1).';es_ES = 'La factura avanzada debe ser fechada más temprano que las salidas de mercancías subordinadas son (%1).';es_CO = 'La factura Anticipada debe ser fechada más temprano que las expediciones de los productos subordinados son (%1).';tr = 'Bir avans faturası, asıl ambar çıkışından (%1) daha önce tarihli olmalıdır.';it = 'Una fattura di anticipo dovrebbe avere una data precedente rispetto ai documenti di trasporto subordinati (%1).';de = 'Eine Rechnung per Vorkasse muss früher datiert sein als ihre untergeordneten Warenausgänge (%1).'"),
			Sel.Period);
		
		CommonClientServer.MessageToUser(MessageText, ThisObject, "Date", , Cancel);
		
	EndIf;
	
EndProcedure

Procedure FillSalesRep()
	
	If Inventory.Count() Then
		
		Filter = New Structure("Order", Undefined);
		RowsWithEmptyOrder = Inventory.FindRows(Filter);
		
		If (SalesOrderPosition = Enums.AttributeStationing.InTabularSection
				AND RowsWithEmptyOrder.Count() < Inventory.Count())
			OR (SalesOrderPosition = Enums.AttributeStationing.InHeader
				AND Not ValueIsFilled(Inventory[0].SalesRep) AND ValueIsFilled(Order)) Then
			
			SalesRep = Undefined;
			If ValueIsFilled(ShippingAddress) Then
				SalesRep = Common.ObjectAttributeValue(ShippingAddress, "SalesRep");
			EndIf;
			If Not ValueIsFilled(SalesRep) Then
				SalesRep = Common.ObjectAttributeValue(Counterparty, "SalesRep");
			EndIf;
			
			For Each CurrentRow In Inventory Do
				If ValueIsFilled(CurrentRow.Order)
					And CurrentRow.Order <> Order Then
					CurrentRow.SalesRep = Common.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
				Else
					CurrentRow.SalesRep = SalesRep;
				EndIf;
			EndDo;
			
		EndIf;
	
	EndIf;
	
EndProcedure

Procedure ClearTabularSectionsWithThirdPartyPayment()
	
	SetPaymentTerms = False;
	
	Prepayment.Clear();
	PrepaymentVAT.Clear();
	PaymentCalendar.Clear();
	EarlyPaymentDiscounts.Clear();
	
EndProcedure

#EndRegion

#EndIf