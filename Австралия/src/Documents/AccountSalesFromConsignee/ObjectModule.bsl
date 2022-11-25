#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany      = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "SalesOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	
	For Each CurRow In OrdersTable Do
		
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			ExchangeRateMethod,
			ExchangeRate,
			ContractCurrencyExchangeRate,
			Multiplicity,
			ContractCurrencyMultiplicity);
		
	EndDo;
	
	If NOT Counterparty.DoOperationsByOrders Then
		OrdersTable.Columns.Delete("SalesOrder");
		OrdersTable.Columns.Add("SalesOrder");
	EndIf;
	
	OrdersTable.GroupBy("SalesOrder", "Total, TotalCalc");
	OrdersTable.Sort("SalesOrder Asc");
	
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
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("SalesOrder"));
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
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "SalesOrder");
		
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

// Procedure of the document filling based on the sales invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData   - Structure - Document filling data
//	
Procedure FillByGoodsIssue(FillingData)
	
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
	|	Document.GoodsIssue AS Header
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
	|	GIProducts.Products AS Products,
	|	GIProducts.Characteristic AS Characteristic,
	|	GIProducts.Batch AS Batch,
	|	GIProducts.Quantity AS Quantity,
	|	GIProducts.MeasurementUnit AS MeasurementUnit,
	|	GIProducts.Order AS SalesOrder,
	|	ISNULL(SalesOrderRef.SalesRep, Counterparties.SalesRep) AS SalesRep,
	|	0 AS ConnectionKey,
	|	GIProducts.ConnectionKey AS ConnectionKeySerialNumbes,
	|	Contracts.PaymentMethod AS PaymentMethod,
	|	Companies.BankAccountByDefault AS BankAccountByDefault,
	|	Companies.PettyCashByDefault AS PettyCashByDefault,
	|	Contracts.PriceKind AS PriceKind,
	|	ProductsCat.VATRate AS VATRate,
	|	GIProducts.RevenueItem AS RevenueItem,
	|	GIProducts.COGSItem AS COGSItem,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GIProducts.InventoryTransferredGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS InventoryTransferredGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GIProducts.RevenueGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS RevenueGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN GIProducts.COGSGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS COGSGLAccount,
	|	Contracts.PaymentMethod.CashAssetType AS CashAssetType
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.GoodsIssue.Products AS GIProducts
	|		ON Header.Ref = GIProducts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (GIProducts.Ref.Contract = Contracts.Ref)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON (GIProducts.Ref.Company = Companies.Ref)
	|		LEFT JOIN Catalog.Products AS ProductsCat
	|		ON (GIProducts.Products = ProductsCat.Ref)
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON (GIProducts.Order = SalesOrderRef.Ref)
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
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
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
	
	NewRow = Customers.Add();
	NewRow.Customer = QueryResultSelection.Counterparty;
	NewRow.ConnectionKey = QueryResultSelection.ConnectionKey;
	
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", Catalogs.BusinessUnits.EmptyRef());
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	QueryResultSelection.Reset();
	While QueryResultSelection.Next() Do
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
	EndDo;
	
	If GetFunctionalOption("UseSerialNumbers") Then
		SerialNumbers.Load(FillingData.SerialNumbers.Unload());
		For Each Str In Inventory Do
			Str.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, Str.ConnectionKeySerialNumbers);
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
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
	If SetPaymentTerms Then
		If QueryResultSelection.CashAssetType = Enums.CashAssetTypes.Noncash Then
			BankAccount = QueryResultSelection.BankAccountByDefault;
		ElsIf QueryResultSelection.CashAssetType = Enums.CashAssetTypes.Cash Then
			PettyCash = QueryResultSelection.PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	TableInventory = Inventory.Unload(, "SalesOrder, Total");
	TableInventory.GroupBy("SalesOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.SalesOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "SalesOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "SalesOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.SalesOrder.EmptyRef(), "SalesOrder"), FoundStringInventory);
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Cannot register the advance payment because the order to be paid is not listed on the Goods tab.'; ru = 'Нельзя зачесть аванс по заказу, отсутствующему в табличной части ""Запасы"".';pl = 'Nie można zarejestrować zaliczki, ponieważ zamówienie do opłaty nie figuruje na karcie Towary.';es_ES = 'No se puede registrar el pago anticipado porque el orden a pagar no está en la lista en la pestaña de Mercancías.';es_CO = 'No se puede registrar el pago anticipado porque el orden a pagar no está en la lista en la pestaña de Mercancías.';tr = 'Ödenecek sipariş Mallar sekmesinde listelenmediğinden avans ödemesi kaydedilemez.';it = 'Non è possibile registrare il pagamento in anticipo, perché l''ordine di pagamento non è elencato nella scheda Merci.';de = 'Die Vorauszahlung kann nicht registriert werden, da der zu zahlende Auftrag nicht auf der Registerkarte Waren aufgeführt ist.'");
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

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsIssue") Then
		If FillingData.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			FillByGoodsIssue(FillingData);
		Else
			Raise NStr("en = 'Please select a sales invoice with ""Transfer to a third party"" operation.'; ru = 'Выберите инвойс покупателю с видом операции ""Передача третьим лицам"".';pl = 'Proszę wybrać fakturę za pomocą operacji ""Przenieś do strony trzeciej"".';es_ES = 'Por favor, seleccione una factura de ventas con la operación ""Traslado a los terceros"".';es_CO = 'Por favor, seleccione una factura de ventas con la operación ""Traslado a los terceros"".';tr = 'Lütfen ""Üçüncü taraflara devret"" işlemi olan bir satış faturası seçin.';it = 'Per piacere selezionare una fattura di vendita con operazione ""Trasferimento a terze parti"".';de = 'Bitte wählen Sie eine Verkaufsrechnung mit der Operation ""Übertragung an einen Dritten"" aus.'");
		EndIf;
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
	IncomeAndExpenseItemsInDocuments.FillIncomeAndExpenseItemsInDocument(ThisObject, FillingData);
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Inventory.Total("Total");
		DocumentTax = Inventory.Total("VATAmount");
		
	EndIf;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		
		Contract = Counterparty.ContractByDefault;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
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
	Documents.AccountSalesFromConsignee.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesFromConsignee.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
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
	Documents.AccountSalesFromConsignee.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
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
