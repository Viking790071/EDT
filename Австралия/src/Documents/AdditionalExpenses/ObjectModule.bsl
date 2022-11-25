#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure distributes expenses by quantity.
//
Procedure DistributeTabSectExpensesByQuantity() Export
	
	SrcAmount					= 0;
	DistributionBaseQuantity	= Inventory.Total("Quantity");
	TotalExpenses				= Expenses.Total("Total");
	
	GCD	= DriveServer.GetGCDForArray(Inventory.UnloadColumn("Quantity"), 1000);
	
	If GCD = 0 Then
		Return;
	EndIf;
	
	If Not IncludeVATInPrice Then
		VATAmountExpense	= Expenses.Total("VATAmount");
		TotalExpenses		= TotalExpenses - VATAmountExpense;
	EndIf;
	
	For Each StringInventory In Inventory Do
		
		StringInventory.Factor = StringInventory.Quantity / GCD * 1000;
		StringInventory.AmountExpense = ?(DistributionBaseQuantity <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Quantity / DistributionBaseQuantity, 2, 1),0);
		DistributionBaseQuantity = DistributionBaseQuantity - StringInventory.Quantity;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

// Procedure distributes expenses by amount.
// 
Procedure DistributeTabSectExpensesByAmount() Export

	SrcAmount = 0;
	ReserveAmount = Inventory.Total("Amount");
	TotalExpenses = Expenses.Total("Total");
	
	GCD = DriveServer.GetGCDForArray(Inventory.UnloadColumn("Amount"), 100);
	
	If GCD = 0 Then
		Return;
	EndIf;
	
	If Not IncludeVATInPrice Then
		VATAmountExpense	= Expenses.Total("VATAmount");
		TotalExpenses		= TotalExpenses - VATAmountExpense;
	EndIf;

	
	For Each StringInventory In Inventory Do
		
		StringInventory.Factor = StringInventory.Amount / GCD * 100;
		StringInventory.AmountExpense = ?(ReserveAmount <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Amount / ReserveAmount, 2, 1), 0);
		ReserveAmount = ReserveAmount - StringInventory.Amount;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

#Region FillingTheDocument

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany      = DriveServer.GetCompany(Company);
	ExchangeRateMethod = DriveServer.GetExchangeMethod(ParentCompany);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.AmountBalance AS AmountBalance,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalancesNotGrouped
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND PresentationCurrency = &PresentationCurrency
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND Order = &Order) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsVendorSettlements.Contract,
	|	DocumentRegisterRecordsVendorSettlements.Document,
	|	DocumentRegisterRecordsVendorSettlements.Document.Date,
	|	DocumentRegisterRecordsVendorSettlements.Order,
	|	CASE
	|		WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentRegisterRecordsVendorSettlements.Amount
	|		ELSE DocumentRegisterRecordsVendorSettlements.Amount
	|	END,
	|	CASE
	|		WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentRegisterRecordsVendorSettlements.AmountCur
	|		ELSE DocumentRegisterRecordsVendorSettlements.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|WHERE
	|	DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|	AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|	AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|	AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|	AND DocumentRegisterRecordsVendorSettlements.Order IN(&Order)
	|	AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Document AS Document,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Order AS Order,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.DocumentDate AS DocumentDate,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(TemporaryTableAccountsPayableBalancesNotGrouped.AmountBalance) AS AmountBalance,
	|	SUM(TemporaryTableAccountsPayableBalancesNotGrouped.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	TemporaryTableAccountsPayableBalancesNotGrouped AS TemporaryTableAccountsPayableBalancesNotGrouped
	|
	|GROUP BY
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Document,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Order,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.DocumentDate,
	|	TemporaryTableAccountsPayableBalancesNotGrouped.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(TemporaryTableAccountsPayableBalancesNotGrouped.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AmountCurBalance) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.AmountBalance) AS PaymentAmount,
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN SUM(AccountsPayableBalances.AmountBalance) <> 0
	|						THEN SUM(AccountsPayableBalances.AmountCurBalance) / SUM(AccountsPayableBalances.AmountBalance)
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN SUM(AccountsPayableBalances.AmountCurBalance) <> 0
	|					THEN SUM(AccountsPayableBalances.AmountBalance) / SUM(AccountsPayableBalances.AmountCurBalance)
	|				ELSE 1
	|			END
	|	END AS ExchangeRate,
	|	1 AS Multiplicity
	|FROM
	|	TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", ?(Counterparty.DoOperationsByOrders, PurchaseOrder, Undefined));
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("PresentationCurrency", DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", EndOfDay(Date) + 1);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	AmountLeftToDistribute = Expenses.Total("Total");
	
	AmountLeftToDistribute = DriveServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		ExchangeRateMethod,
		ExchangeRate,
		ContractCurrencyExchangeRate,
		Multiplicity,
		ContractCurrencyMultiplicity);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					ExchangeRateMethod,
					SelectionOfQueryResult.ExchangeRate,
					1,
					SelectionOfQueryResult.Multiplicity,
					1);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
			NewRow.AmountDocCur = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				ExchangeRateMethod,
				ContractCurrencyExchangeRate,
				ExchangeRate,
				ContractCurrencyMultiplicity,
				Multiplicity);
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	WorkWithVAT.FillPrepaymentVATFromVATInput(ThisObject);
	
EndProcedure

// Procedure of filling the document on the basis of supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillBySupplierInvoice(FillingDataRef) Export
	
	FillingData = FillingDataRef.GetObject();
	
	Company = FillingData.Company;
	CompanyVATNumber = FillingData.CompanyVATNumber;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	DocumentCurrency = FillingData.DocumentCurrency;
	BankAccount = FillingData.BankAccount;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	VATTaxation = FillingData.VATTaxation;
	
	If ValueIsFilled(FillingData.BasisDocument) 
		And TypeOf(FillingData.BasisDocument) = Type("DocumentRef.PurchaseOrder") Then
		PurchaseOrder = FillingData.BasisDocument;
	EndIf;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
	ExchangeRate		= StructureByCurrency.Rate;
	Multiplicity		= StructureByCurrency.Repetition;
	
	If DocumentCurrency <> Contract.SettlementsCurrency Then
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company);
	EndIf;
	
	ContractCurrencyExchangeRate = StructureByCurrency.Rate;
	ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		NewRow.ReceiptDocument = FillingData.Ref;
		NewRow.PurchaseOrder = TabularSectionRow.Order;
		NewRow.StructuralUnit = FillingData.StructuralUnit;
		
		If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOM") Then
			
			NewFactor			= Common.ObjectAttributeValue(TabularSectionRow.MeasurementUnit, "Factor");
			NewMeasurementUnit	= Common.ObjectAttributeValue(TabularSectionRow.Products, "MeasurementUnit");
			
			NewRow.Quantity			= NewRow.Quantity * NewFactor;
			NewRow.Price			= ?(NewRow.Quantity = 0, 0, NewRow.Amount / NewRow.Quantity);
			NewRow.MeasurementUnit	= NewMeasurementUnit;
			
		EndIf;
		
	EndDo;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
	// Cash flow projection
	PaymentTermsServer.FillPaymentCalendarFromDocument(ThisObject, FillingDataRef);
	PaymentTermsClientServer.CalculateAmountsInThePaymentCalendar(ThisObject);
	
EndProcedure

// Procedure of filling the document on the basis of the expense report.
//
// Parameters:
//  BasisDocument - DocumentRef.ExpenseReport - The expense report
//  FillingData - Structure - Document filling data
//	
Procedure FillByExpenseReport(FillingData) Export
		
	Company = FillingData.Company;
	CompanyVATNumber = FillingData.CompanyVATNumber;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	ExchangeRate = FillingData.ExchangeRate;
	Multiplicity = FillingData.Multiplicity;
	VATTaxation = FillingData.VATTaxation; 
	
	// Filling document tabular section.	
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		NewRow.ReceiptDocument	= FillingData.Ref;
		
	EndDo;
		
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SupplierInvoice")] = "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.ExpenseReport")]   = "FillByExpenseReport";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	VATExpenses = 0;
	If NOT IncludeVATInPrice Then
		VATExpenses = Expenses.Total("VATAmount");
	EndIf;	 
 	
	If Inventory.Total("AmountExpense") <> Expenses.Total("Total") - VATExpenses Then  
		
		DriveServer.ShowMessageAboutError(
			Undefined,
			NStr("en = 'Amount of services is not equal to the amount allocated by inventory.'; ru = 'Сумма услуг не равна распределенной сумме по запасам!';pl = 'Kwota usług nie jest równa kwocie przydzielonej według zapasów.';es_ES = 'Cantidad de servicios no es igual a la cantidad asignada por el inventario.';es_CO = 'Cantidad de servicios no es igual a la cantidad asignada por el inventario.';tr = 'Hizmet tutarı, stok tarafından dağıtılan tutar kadar değildir.';it = 'L''importo dei servizi non è uguale all''importo assegnato per le scorte.';de = 'Die Menge der Dienstleistungen entspricht nicht der Menge, die von dem Bestand verteilt wurde.'"),
			Undefined,
			Undefined,
			Undefined,
			Cancel);
		
	EndIf;
	
	If NOT Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	//Cash flow projection
	Amount = Expenses.Total("Amount") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(ThisObject);
	VATAmount = Expenses.Total("VATAmount");
	
	PaymentTermsServer.CheckRequiredAttributes(ThisObject, CheckedAttributes, Cancel);
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
	BatchesServer.CheckFilling(ThisObject, Cancel);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	If Expenses.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = Expenses.Total("Total") + PaymentTermsClientServer.GetCustomsDeclarationTabAmount(ThisObject);
		
	EndIf;
	
	DocumentTax = Expenses.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
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
	Documents.AdditionalExpenses.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);

	// Offline registers
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// VAT
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.AdditionalExpenses.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.AdditionalExpenses.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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
	PrepaymentVAT.Clear();
	
	ForOpeningBalancesOnly = False;
	
	IncomingDocumentNumber = "";
	IncomingDocumentDate = "";
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate tax invoice
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
