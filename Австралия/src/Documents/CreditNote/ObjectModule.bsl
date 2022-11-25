#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(AdjustedAmount)
		AND AmountAllocation.Count() = 0 Then
		FillAmountAllocation();
		FillGLAccountsForAmountAllocation();
	EndIf;
	
	SalesTaxServer.CalculateInventorySalesTaxAmount(Inventory, SalesTax.Total("Amount"));
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = AdjustedAmount;
		
	EndIf;
	
	DocumentTax = Inventory.Total("VATAmount") + SalesTax.Total("Amount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	If OperationKind <> Enums.OperationTypesCreditNote.SalesReturn Then
		DocumentAmount = DocumentAmount + ?(AmountIncludesVAT, 0, VATAmount);
	EndIf;
	
	FillSalesRep();
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn
		And Inventory.FindRows(New Structure("DropShipping", True)).Count() > 0 Then
		
		Params = New Structure("Company, Date", Company, Date);
		DriveServer.DropShippingReturnIsSupported(Params, Cancel);
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn
		And Inventory.Count() <> 0
		And AdjustedAmount = 0 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Fill in the quantity of goods to return.'; ru = 'Укажите количество товаров, которые необходимо оформить к возврату.';pl = 'Uzupełnij ilość towarów do zwrotu.';es_ES = 'Rellenar la cantidad de mercancías para devolver.';es_CO = 'Rellenar la cantidad de mercancías para devolver.';tr = 'İade edilecek ürün miktarını doldurun.';it = 'Compilate la quantità di beni da restituire.';de = 'Geben Sie die Menge der Waren ein, die Sie zurücksenden möchten.'"), , , , Cancel);
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If OperationKind <> Enums.OperationTypesCreditNote.SalesReturn 
		Or AccountingPolicy.UseGoodsReturnFromCustomer Then
		CheckedAttributes.Delete(CheckedAttributes.Find("StructuralUnit"));
	EndIf;
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		
		CheckedAttributes.Delete(CheckedAttributes.Find("AdjustedAmount"));
		CheckedAttributes.Delete(CheckedAttributes.Find("ExpenseItem"));
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then 
			CheckedAttributes.Delete(CheckedAttributes.Find("GLAccount"));
		EndIf;
		
		If GetBasisTable().Count() > 1 Then
			CheckedAttributes.Delete(CheckedAttributes.Find("BasisDocument"));
		EndIf;
		
	Else
		
		CheckedAttributes.Delete(CheckedAttributes.Find("BasisDocument"));
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory"));
		
		If OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Or Not RegisterExpense Then
			CheckedAttributes.Delete(CheckedAttributes.Find("ExpenseItem"));
		EndIf;
		
	EndIf;
	
	If Not AccountingPolicy.UseGoodsReturnFromCustomer Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
		BatchesServer.CheckFilling(ThisObject, Cancel);
	EndIf;
	
	If Not AccountingPolicy.RegisteredForVAT Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	// Bundles
	BundlesServer.CheckTableFilling(ThisObject, "Inventory", Cancel);
	// End Bundles
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
		
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.SalesSlip")]		= "FillBySalesSlip";
	FillingStrategy[Type("DocumentRef.CashReceipt")]	= "FillByCashReceipt";
	FillingStrategy[Type("DocumentRef.PaymentReceipt")]	= "FillByPaymentReceipt";
	FillingStrategy[Type("DocumentRef.RMARequest")]		= "FillByRMARequest";
	FillingStrategy[Type("DocumentRef.GoodsReceipt")]	= "FillByGoodsReceipt";
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	
	If TypeOf(FillingData) = Type("DocumentRef.CashReceipt")
		OR TypeOf(FillingData) = Type("DocumentRef.PaymentReceipt") Then
		
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "AmountIncludesVAT");
		
	Else
		
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
		
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, DocumentCurrency, Company);
		ExchangeRate		= StructureByCurrency.Rate;
		Multiplicity		= StructureByCurrency.Repetition;
		
		If DocumentCurrency <> Contract.SettlementsCurrency Then
			StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company);
		EndIf;
		
		ContractCurrencyExchangeRate = StructureByCurrency.Rate;
		ContractCurrencyMultiplicity = StructureByCurrency.Repetition;
		
		AmountAllocation.Clear();
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	// Subordinate documents
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Initialization of document data
	Documents.CreditNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel);
	
	If OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then 
		
		If Not AdditionalProperties.AccountingPolicy.UseGoodsReturnFromCustomer Then
			DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesCreditNote.Adjustments Then
		DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If GetFunctionalOption("UseVAT")
		And Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Date, Company) 
		And VATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT
		And VATTaxation <> Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
		
	EndIf;
	
	// Sales tax
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CreditNote.RunControl(Ref, AdditionalProperties, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
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
	
	// Subordinate documents
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
	// Control of occurrence of a negative balance.
	Documents.CreditNote.RunControl(Ref, AdditionalProperties, Cancel);
	
	If Not Cancel Then
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
	EndIf;
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	If SerialNumbers.Count() Then
		
		For Each InventoryLine In Inventory Do
			InventoryLine.SerialNumbers = "";
		EndDo;
		
		SerialNumbers.Clear();
		
	EndIf;
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

#EndRegion

#Region Internal

Procedure FillBySalesInvoice(FillingData) Export
	
	// Document basis and document setting.
	ArrayOfSalesInvoices = New Array;
	Contract = Undefined;
	VATAmount = 0;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfSalesInvoices") Then
		
		For Each ArrayItem In FillingData.ArrayOfSalesInvoices Do
			Contract = ArrayItem.Contract;
			ArrayOfSalesInvoices.Add(ArrayItem.Ref);
		EndDo;
		
		SalesInvoice = ArrayOfSalesInvoices[0];
		
	Else
		ArrayOfSalesInvoices.Add(FillingData.Ref);
		SalesInvoice = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS BasisRef,
	|	SalesInvoice.Posted AS BasisPosted,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Cell AS Cell,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.Order AS Order,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.VATTaxation AS VATTaxation,
	|	SalesInvoice.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoice.ExchangeRate AS ExchangeRate,
	|	SalesInvoice.Multiplicity AS Multiplicity,
	|	SalesInvoice.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoice.SalesTaxRate AS SalesTaxRate,
	|	SalesInvoice.SalesTaxPercentage AS SalesTaxPercentage
	|INTO SalesInvoiceHeader
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&ArrayOfSalesInvoices)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	SalesInvoiceHeader.BasisRef AS BasisRef,
	|	SalesInvoiceHeader.BasisPosted AS BasisPosted,
	|	SalesInvoiceHeader.Company AS Company,
	|	SalesInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SalesInvoiceHeader.Cell AS Cell,
	|	SalesInvoiceHeader.Counterparty AS Counterparty,
	|	SalesInvoiceHeader.Contract AS Contract,
	|	SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	SalesInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SalesInvoiceHeader.Multiplicity AS Multiplicity,
	|	SalesInvoiceHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesInvoiceHeader.SalesTaxRate AS SalesTaxRate,
	|	SalesInvoiceHeader.SalesTaxPercentage AS SalesTaxPercentage,
	|	CASE
	|		WHEN SalesInvoiceInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN SalesInvoiceInventory.Order
	|		ELSE SalesInvoiceHeader.Order
	|	END AS Order,
	|	SalesInvoiceInventory.VATRate AS VATRate,
	|	SalesInvoiceInventory.VATAmount AS VATAmount
	|INTO SalesInvoiceFiltred
	|FROM
	|	SalesInvoiceHeader AS SalesInvoiceHeader
	|		LEFT JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON SalesInvoiceHeader.BasisRef = SalesInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceFiltred.BasisRef AS BasisDocument,
	|	SalesInvoiceFiltred.BasisPosted AS BasisPosted,
	|	SalesInvoiceFiltred.Company AS Company,
	|	SalesInvoiceFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoiceFiltred.StructuralUnit AS StructuralUnit,
	|	SalesInvoiceFiltred.Cell AS Cell,
	|	SalesInvoiceFiltred.Counterparty AS Counterparty,
	|	SalesInvoiceFiltred.Contract AS Contract,
	|	SalesInvoiceFiltred.Order AS Order,
	|	ISNULL(SalesInvoiceFiltred.DocumentCurrency, Contracts.SettlementsCurrency) AS DocumentCurrency,
	|	SalesInvoiceFiltred.VATTaxation AS VATTaxation,
	|	SalesInvoiceFiltred.AmountIncludesVAT AS AmountIncludesVAT,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	SalesInvoiceFiltred.VATRate AS VATRate,
	|	SalesInvoiceFiltred.VATAmount AS VATAmount,
	|	SalesInvoiceFiltred.SalesTaxRate AS SalesTaxRate,
	|	SalesInvoiceFiltred.SalesTaxPercentage AS SalesTaxPercentage,
	|	VALUE(Enum.OperationTypesCreditNote.SalesReturn) AS OperationKind
	|FROM
	|	SalesInvoiceFiltred AS SalesInvoiceFiltred
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SalesInvoiceFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON (ISNULL(SalesInvoiceFiltred.DocumentCurrency, Contracts.SettlementsCurrency) = DC_Rates.Currency)
	|			AND SalesInvoiceFiltred.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND SalesInvoiceFiltred.Company = CC_Rates.Company
	|
	|ORDER BY
	|	Order DESC";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ArrayOfSalesInvoices", ArrayOfSalesInvoices);
	Query.SetParameter("Contract", Contract);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("ThisObject", ThisObject);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	    
	FilterData = New Structure("ArrayOfSalesInvoices, Contract", ArrayOfSalesInvoices, Contract);
	
	Documents.CreditNote.FillBySalesInvoices(DocumentData, FilterData, Inventory, SerialNumbers);
	
	RecalculateSalesTax();
	
	AdjustedAmount = Inventory.Total("Total") + SalesTax.Total("Amount");
	BasisTable = GetBasisTable();
	BasisDocumentInTabularSection = False;
	
	If BasisTable.Count() > 1 Then
		BasisDocumentInTabularSection = True;
		BasisDocument = Undefined;
	ElsIf Not ValueIsFilled(BasisDocument) Then
		If BasisTable.Count() > 0 Then
			BasisDocument = BasisTable[0].SalesDocument;
		EndIf;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If ArrayOfSalesInvoices.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Goods from this document have already been returned: %1.'; ru = 'Товары из этого документа уже возвращены: %1.';pl = 'Towary z tego dokumentu już zostały zwrócone: %1.';es_ES = 'Se han devuelto ya las mercancías de este documento: %1.';es_CO = 'Se han devuelto ya las mercancías de este documento: %1.';tr = 'Bu belgeden ürünler zaten iade edildi: %1.';it = 'Le merci di questo documento sono già state restituite: %1.';de = 'Waren aus diesem Dokument sind bereits zurückgegeben: %1.'"),
				SalesInvoice);
		Else
			MessageText = NStr("en = 'Goods from these documents have already been returned.'; ru = 'Товары из этих документов уже возвращены.';pl = 'Towary z tych dokumentów już zostały zwrócone.';es_ES = 'Se han devuelto ya las mercancías de estos documentos.';es_CO = 'Se han devuelto ya las mercancías de estos documentos.';tr = 'Bu belgelerden ürünler zaten iade edildi.';it = 'Le merci di questo documento sono già state restituite.';de = 'Waren aus diesen Dokumenten sind bereits zurückgegeben.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;

EndProcedure

Procedure FillByRMARequest(FillingData) Export
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	BasisDocument = FillingData.Ref;
	
	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Author, Posted, DeletionMark, Comment");
	
	DocumentAmount		= 0;
	OperationKind		= Enums.OperationTypesCreditNote.SalesReturn;
	PriceKind			= ?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.Wholesale);
	AmountIncludesVAT	= Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
	VATTaxation			= ?(ValueIsFilled(VATTaxation), VATTaxation, DriveServer.VATTaxation(Company, DocumentDate));
	VATRate				= InformationRegisters.AccountingPolicy.GetDefaultVATRate(DocumentDate, Company);
	SalesDocument		= Common.ObjectAttributeValue(BasisDocument, "Invoice");
	
	If ValueIsFilled(SalesDocument) Then
		DocumentCurrency = Common.ObjectAttributeValue(SalesDocument, "DocumentCurrency");
	EndIf;
	
	FillInventoryOnRMARequest(FillingData, DocumentDate, SalesDocument);
	
EndProcedure

Procedure FillBySalesSlip(FillingData) Export
	
	OperationKind = Enums.OperationTypesCreditNote.SalesReturn;
	
	BasisDocument = FillingData.Ref;
	FillPropertyValues(ThisObject, FillingData,, "Number, Date, Author");
	If Not ValueIsFilled(Counterparty) Then
		Counterparty = Catalogs.Counterparties.RetailCustomer;
		Contract = DriveServer.GetContractByDefault(Ref, Counterparty, Company, OperationKind);
	EndIf;
	
	DocumentAmount = 0;
	ExchangeRate = 1; 
	Multiplicity = 1;
	
	FillInventory(FillingData);

EndProcedure

Procedure FillByCashOrBankReceipt(FillingData, QueryText)
	
	BasisDocument = FillingData;
	
	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark, BasisDocument, Comment, OperationKind");
	
	OperationKind		= Enums.OperationTypesCreditNote.DiscountAllowed;
	AmountIncludesVAT	= True;
	
	ExpenseItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountAllowed");
	
	DateParameter = EndOfDay(?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query = New Query;
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("DocumentDate", DateParameter);
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	Query.Text = QueryText;
	
	ResultArray		= Query.ExecuteBatch();
	QueryResult1	= ResultArray[4];
	QueryResult2	= ResultArray[5];
	
	If NOT QueryResult1.IsEmpty() Then
		
		ResultTable	= QueryResult1.Unload();
		FirstRow	= ResultTable[0];
		
		CreditedTransactions.Load(QueryResult2.Unload());
		
		DocumentCurrency				= FirstRow.SettlementsCurrency;
		ExchangeRate					= FirstRow.ExchangeRate;
		Multiplicity					= FirstRow.Multiplicity;
		ContractCurrencyExchangeRate	= FirstRow.ContractCurrencyExchangeRate;
		ContractCurrencyMultiplicity	= FirstRow.ContractCurrencyMultiplicity;
		Contract						= FirstRow.Contract;
		ProvideEPD						= FirstRow.ProvideEPD;
		
		If ProvideEPD = Enums.VariantsOfProvidingEPD.CreditDebitNote Then
			VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
			VATRate = Catalogs.VATRates.Exempt;
		ElsIf CreditedTransactions.Count() > 0 Then
			VATRatesCT = CreditedTransactions.Unload( , "VATRate");
			VATRatesCT.GroupBy("VATRate");
			If VATRatesCT.Count() = 1 Then
				VATRate = VATRatesCT[0].VATRate;
				If VATRate = Catalogs.VATRates.Exempt Then
					VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT;
				Else
					VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
				EndIf;
			EndIf;
		EndIf;
		If Not ValueIsFilled(VATRate) Then
			VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
			VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
		EndIf;
		
		AmountAllocation.Clear();
		
		ReasonForCorrectionArray = New Array;
		
		For each Row In ResultTable Do
			
			NewAllocation = AmountAllocation.Add();
			
			FillPropertyValues(NewAllocation, Row, "Contract, Document, OffsetAmount, Order, AccountsReceivableGLAccount, AdvancesReceivedGLAccount");
			
			NewAllocation.VATRate = VATRate;
			
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				
				NewAllocation.VATAmount = 0;
				
			Else
				
				VATRateForCalc = DriveReUse.GetVATRateValue(NewAllocation.VATRate);
				NewAllocation.VATAmount = NewAllocation.OffsetAmount - NewAllocation.OffsetAmount / (100 + VATRateForCalc) * 100;
				
			EndIf;
			
			If Not ValueIsFilled(NewAllocation.VATOutputGLAccount) And GetFunctionalOption("UseDefaultTypeOfAccounting") Then
				
				StructureData = New Structure;
				StructureData.Insert("TabName", "AmountAllocation");
				ObjectParameters = GLAccountsInDocuments.GetObjectParametersByMetadata(ThisObject, Metadata());
				StructureData.Insert("ObjectParameters", ObjectParameters);
				StructureData.Insert("CounterpartyGLAccounts",	True);
				StructureData.Insert("AccountsReceivableGLAccount",	NewAllocation.AccountsReceivableGLAccount);
				StructureData.Insert("AdvancesReceivedGLAccount",	NewAllocation.AdvancesReceivedGLAccount);
				StructureData.Insert("VATOutputGLAccount",	NewAllocation.VATOutputGLAccount);
				StructureData.Insert("Document",			NewAllocation.Document);
				StructureData.Insert("VATRate",				NewAllocation.VATRate);
				StructureData.Insert("LineNumber",			NewAllocation.LineNumber);
				GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
				
				NewAllocation.VATOutputGLAccount = StructureData.VATOutputGLAccount;
				
			EndIf;
			
			ReasonForCorrectionArray.Add(
				Row.Number
				+ StringFunctionsClientServer.SubstituteParametersToString(" %1 ", NStr("en = 'dated'; ru = 'от';pl = 'z dn.';es_ES = 'fechado';es_CO = 'fechado';tr = 'tarihli';it = 'con data';de = 'datiert'"))
				+ Format(Row.Date, "DLF=D"));
			
		EndDo;
		
		If ReasonForCorrectionArray.Count() > 0 Then
			
			Reason = StringFunctionsClientServer.StringFromSubstringArray(ReasonForCorrectionArray, ", ");
			
			ReasonForCorrection = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Early payment discount provided against invoices: %1'; ru = 'Предоставленная скидка за досрочную оплату по инвойсам: %1';pl = 'Skonto przewidziane na podstawie faktur: %1';es_ES = 'El descuento por pronto pago contra las facturas: %1';es_CO = 'El descuento por pronto pago contra las facturas: %1';tr = 'Fatura ibrazında erken ödeme indirimi sağlanmaktadır: %1';it = 'Sconto per pagamento anticipato fornito a seguito delle fatture: %1';de = 'Skonto wird auf Rechnungen gewährt: %1'"),
				Reason);
			
			
		EndIf;
		
	EndIf;
	
	AdjustedAmount	= AmountAllocation.Total("OffsetAmount");
	VATAmount			= AmountAllocation.Total("VATAmount");
	
EndProcedure

Procedure FillByCashReceipt(FillingData) Export
	
	QueryText =
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Company AS Company,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TempExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CashReceiptPaymentDetails.Contract AS Contract,
	|	CashReceiptPaymentDetails.Document AS Document,
	|	CashReceiptPaymentDetails.Order AS Order,
	|	CashReceiptPaymentDetails.SettlementsEPDAmount AS OffsetAmount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashReceiptPaymentDetails.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN CashReceiptPaymentDetails.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AdvancesReceivedGLAccount
	|INTO TempPaymentDelails
	|FROM
	|	Document.CashReceipt.PaymentDetails AS CashReceiptPaymentDetails
	|WHERE
	|	CashReceiptPaymentDetails.Ref = &Ref
	|	AND CashReceiptPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	TempPaymentDelails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	TempPaymentDelails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TempPaymentDelails.Document = SalesInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SalesInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelailsWithInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	TempPaymentDelailsWithInvoice.Contract AS Contract,
	|	TempPaymentDelailsWithInvoice.Document AS Document,
	|	TempPaymentDelailsWithInvoice.Order AS Order,
	|	TempPaymentDelailsWithInvoice.OffsetAmount AS OffsetAmount,
	|	TempPaymentDelailsWithInvoice.ProvideEPD AS ProvideEPD,
	|	TempPaymentDelailsWithInvoice.Number AS Number,
	|	TempPaymentDelailsWithInvoice.Date AS Date,
	|	ISNULL(TempExchangeRate.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(TempExchangeRate.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(TempExchangeRate.ExchangeRate, 1) AS ContractCurrencyExchangeRate,
	|	ISNULL(TempExchangeRate.Multiplicity, 1) AS ContractCurrencyMultiplicity,
	|	TempPaymentDelailsWithInvoice.SettlementsCurrency AS SettlementsCurrency,
	|	TempPaymentDelailsWithInvoice.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	TempPaymentDelailsWithInvoice.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRate AS TempExchangeRate
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRate.Currency
	|			AND TempPaymentDelailsWithInvoice.Company = TempExchangeRate.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(, , Recorder, ) AS SalesTurnovers
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesTurnovers.Recorder = SalesInvoiceTable.Document";
	
	FillByCashOrBankReceipt(FillingData, QueryText);
	
EndProcedure

Procedure FillByPaymentReceipt(FillingData) Export
	
	QueryText =
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Company AS Company,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TempExchangeRate
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PaymentReceiptPaymentDetails.Contract AS Contract,
	|	PaymentReceiptPaymentDetails.Document AS Document,
	|	PaymentReceiptPaymentDetails.Order AS Order,
	|	PaymentReceiptPaymentDetails.SettlementsEPDAmount AS OffsetAmount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PaymentReceiptPaymentDetails.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AccountsReceivableGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN PaymentReceiptPaymentDetails.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END  AS AdvancesReceivedGLAccount
	|INTO TempPaymentDelails
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptPaymentDetails
	|WHERE
	|	PaymentReceiptPaymentDetails.Ref = &Ref
	|	AND PaymentReceiptPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SalesInvoice.ProvideEPD AS ProvideEPD,
	|	SalesInvoice.Number AS Number,
	|	SalesInvoice.Date AS Date,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	TempPaymentDelails.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	TempPaymentDelails.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TempPaymentDelails.Document = SalesInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SalesInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempPaymentDelailsWithInvoice.CompanyVATNumber AS CompanyVATNumber,
	|	TempPaymentDelailsWithInvoice.Contract AS Contract,
	|	TempPaymentDelailsWithInvoice.Document AS Document,
	|	TempPaymentDelailsWithInvoice.Order AS Order,
	|	TempPaymentDelailsWithInvoice.OffsetAmount AS OffsetAmount,
	|	TempPaymentDelailsWithInvoice.ProvideEPD AS ProvideEPD,
	|	TempPaymentDelailsWithInvoice.Number AS Number,
	|	TempPaymentDelailsWithInvoice.Date AS Date,
	|	ISNULL(TempExchangeRate.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(TempExchangeRate.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(TempExchangeRate.ExchangeRate, 1) AS ContractCurrencyExchangeRate,
	|	ISNULL(TempExchangeRate.Multiplicity, 1) AS ContractCurrencyMultiplicity,
	|	TempPaymentDelailsWithInvoice.SettlementsCurrency AS SettlementsCurrency,
	|	TempPaymentDelailsWithInvoice.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	TempPaymentDelailsWithInvoice.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRate AS TempExchangeRate
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRate.Currency
	|			AND TempPaymentDelailsWithInvoice.Company = TempExchangeRate.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesTurnovers.Recorder AS Document,
	|	SalesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover
	|		ELSE -(SalesTurnovers.AmountTurnover + SalesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN SalesTurnovers.VATAmountTurnover > 0
	|			THEN SalesTurnovers.VATAmountTurnover
	|		ELSE -SalesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Sales.Turnovers(, , Recorder, ) AS SalesTurnovers
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON SalesTurnovers.Recorder = SalesInvoiceTable.Document";
	
	FillByCashOrBankReceipt(FillingData, QueryText);
	
EndProcedure

Procedure FillByGoodsReceipt(FillingData) Export
	
	// Document basis and document setting.
	ArrayOfGoodsReceipts = New Array;
	Contract = Undefined;
	VATAmount = 0;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfGoodsReceipts") Then
		
		For Each ArrayItem In FillingData.ArrayOfGoodsReceipts Do
			Contract = ArrayItem.Contract;
			ArrayOfGoodsReceipts.Add(ArrayItem.Ref);
		EndDo;
		
		GoodsReceipt = ArrayOfGoodsReceipts[0];
		
	Else
		ArrayOfGoodsReceipts.Add(FillingData.Ref);
		GoodsReceipt = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsReceipt.Ref AS BasisRef,
	|	GoodsReceipt.Posted AS BasisPosted,
	|	GoodsReceipt.Company AS Company,
	|	GoodsReceipt.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsReceipt.OperationType AS OperationType,
	|	GoodsReceipt.StructuralUnit AS StructuralUnit,
	|	GoodsReceipt.Cell AS Cell,
	|	GoodsReceipt.Contract AS Contract,
	|	GoodsReceipt.Order AS Order,
	|	GoodsReceipt.Counterparty AS Counterparty,
	|	GoodsReceipt.VATTaxation AS VATTaxation,
	|	GoodsReceipt.DocumentCurrency AS DocumentCurrency,
	|	GoodsReceipt.ExchangeRate AS ExchangeRate,
	|	GoodsReceipt.Multiplicity AS Multiplicity,
	|	GoodsReceipt.AmountIncludesVAT AS AmountIncludesVAT
	|INTO GoodsReceiptHeader
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref IN(&ArrayOfGoodsReceipts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsReceiptHeader.BasisRef AS BasisRef,
	|	GoodsReceiptHeader.BasisPosted AS BasisPosted,
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.CompanyVATNumber AS CompanyVATNumber,
	|	GoodsReceiptHeader.OperationType AS OperationType,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Cell AS Cell,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptProducts.Contract
	|		ELSE GoodsReceiptHeader.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE GoodsReceiptHeader.Order
	|	END AS Order,
	|	ISNULL(GoodsReceiptProducts.VATRate, VALUE(Catalog.VATRates.EmptyRef)) AS VATRate,
	|	ISNULL(GoodsReceiptProducts.VATAmount, 0) AS VATAmount,
	|	GoodsReceiptHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsReceiptHeader.ExchangeRate AS ExchangeRate,
	|	GoodsReceiptHeader.Multiplicity AS Multiplicity,
	|	GoodsReceiptHeader.VATTaxation AS VATTaxation,
	|	GoodsReceiptHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	GoodsReceiptProducts.SalesDocument AS SalesDocument
	|INTO GRFiltred
	|FROM
	|	GoodsReceiptHeader AS GoodsReceiptHeader
	|		LEFT JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.BasisRef = GoodsReceiptProducts.Ref
	|WHERE
	|	(GoodsReceiptProducts.Contract = &Contract
	|			OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GRFiltred.BasisRef AS BasisRef,
	|	GRFiltred.BasisPosted AS BasisPosted,
	|	GRFiltred.Company AS Company,
	|	GRFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	GRFiltred.OperationType AS OperationType,
	|	GRFiltred.StructuralUnit AS StructuralUnit,
	|	GRFiltred.Cell AS Cell,
	|	GRFiltred.Counterparty AS Counterparty,
	|	GRFiltred.Contract AS Contract,
	|	GRFiltred.Order AS Order,
	|	GRFiltred.DocumentCurrency AS DocumentCurrency,
	|	GRFiltred.VATTaxation AS VATTaxation,
	|	GRFiltred.AmountIncludesVAT AS AmountIncludesVAT,
	|	GRFiltred.ExchangeRate AS ExchangeRate,
	|	GRFiltred.Multiplicity AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	VALUE(Enum.OperationTypesCreditNote.SalesReturn) AS OperationKind,
	|	GRFiltred.VATRate AS VATRate,
	|	GRFiltred.VATAmount AS VATAmount,
	|	GRFiltred.SalesDocument AS BasisDocument
	|FROM
	|	GRFiltred AS GRFiltred
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON GRFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND GRFiltred.Company = CC_Rates.Company
	|
	|ORDER BY
	|	Order DESC";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("ArrayOfGoodsReceipts", ArrayOfGoodsReceipts);
	Query.SetParameter("Contract", Contract);
	
	ResultTable = Query.Execute().Unload();
	For Each TableRow In ResultTable Do
		Documents.GoodsReceipt.CheckAbilityOfEnteringByGoodsReceipt(ThisObject, TableRow.BasisRef, TableRow.BasisPosted, TableRow.OperationType);
		VATAmount = VATAmount + TableRow.VATAmount;
	EndDo;
	
	If ResultTable.Count() > 0 Then
		TableRow = ResultTable[0];
		FillPropertyValues(ThisObject, TableRow, , "VATAmount");
	EndIf;

	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	FilterData = New Structure("ArrayOfGoodsReceipts, Contract", ArrayOfGoodsReceipts, Contract);
	
	Documents.CreditNote.FillByGoodsReceipts(DocumentData, FilterData, Inventory);
	
	AdjustedAmount = Inventory.Total("Total");
	BasisTable = GetBasisTable();
	BasisDocumentInTabularSection = False;
	
	If BasisTable.Count() > 1 Then
		BasisDocumentInTabularSection = True;
		BasisDocument = Undefined;
	ElsIf Not ValueIsFilled(BasisDocument) Then
		If BasisTable.Count() > 0 Then
			BasisDocument = BasisTable[0].SalesDocument;
		EndIf;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If ArrayOfGoodsReceipts.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				GoodsReceipt);
		Else
			MessageText = NStr("en = 'The selected goods receipts have already been invoiced.'; ru = 'Выбранные документы ""Поступление товаров"" уже отражены в учете.';pl = 'Wybrane wpływy kasowe, dotyczące towarów, zostały już zafakturowane.';es_ES = 'Las recepciones de los productos seleccionados han sido facturadas ya.';es_CO = 'Las recepciones de los productos seleccionados han sido facturadas ya.';tr = 'Seçilen Ambar girişleri zaten faturalandırıldı.';it = 'Le merci ricevute selezionate sono già state fatturate.';de = 'Die ausgewählten Wareneingänge wurden bereits in Rechnung gestellt.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfGoodsReceipts") Then
		FillByGoodsReceipt(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfSalesInvoices") Then
		FillBySalesInvoice(FillingData);
	EndIf;
	
EndProcedure

Procedure FillInventory(BasisDocument) Export
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(BasisDocument) = Type("DocumentRef.SalesSlip") Then
		BasisDocumentAttributes = Common.ObjectAttributesValues(BasisDocument, "Archival, CashCRSession");
		SalesDocument = ?(BasisDocumentAttributes.Archival,	BasisDocumentAttributes.CashCRSession, BasisDocument);
	Else
		SalesDocument = BasisDocument;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("AmountIncludesVAT", BasisDocument.AmountIncludesVAT);
	Query.SetParameter("BasisDocument", 	BasisDocument);
	Query.SetParameter("SalesDocument", 	SalesDocument);
	Query.SetParameter("Ref", 				Ref);
	
	Query.Text = 
	"SELECT ALLOWED
	|	Inventory.Price AS Price,
	|	Inventory.MeasurementUnit AS MeasurementUnit,
	|	Inventory.Products AS Products,
	|	Inventory.Characteristic AS Characteristic,
	|	Inventory.Batch AS Batch,
	|	SUM(Inventory.Quantity) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	Inventory.VATRate AS VATRate,
	|	Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	Inventory.Order AS Order,
	|	Inventory.SalesRep AS SalesRep,
	|	Inventory.Ref AS SalesDocument,
	|	Inventory.BundleProduct AS BundleProduct,
	|	Inventory.BundleCharacteristic AS BundleCharacteristic,
	|	Inventory.CostShare AS CostShare
	|INTO SalesDocument
	|FROM
	|	Document.SalesInvoice.Inventory AS Inventory
	|WHERE
	|	Inventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	Inventory.MeasurementUnit,
	|	Inventory.Products,
	|	Inventory.Characteristic,
	|	Inventory.VATRate,
	|	Inventory.Batch,
	|	Inventory.DiscountMarkupPercent,
	|	Inventory.Price,
	|	Inventory.Order,
	|	Inventory.SalesRep,
	|	Inventory.Ref,
	|	Inventory.BundleProduct,
	|	Inventory.BundleCharacteristic,
	|	Inventory.CostShare
	|
	|UNION ALL
	|
	|SELECT
	|	SalesSlipInventory.Price,
	|	SalesSlipInventory.MeasurementUnit,
	|	SalesSlipInventory.Products,
	|	SalesSlipInventory.Characteristic,
	|	SalesSlipInventory.Batch,
	|	SUM(SalesSlipInventory.Quantity),
	|	SUM(SalesSlipInventory.Amount),
	|	SalesSlipInventory.VATRate,
	|	SalesSlipInventory.DiscountMarkupPercent,
	|	VALUE(Document.SalesOrder.EmptyRef),
	|	VALUE(Catalog.Employees.EmptyRef),
	|	SalesSlipInventory.Ref,
	|	SalesSlipInventory.BundleProduct,
	|	SalesSlipInventory.BundleCharacteristic,
	|	SalesSlipInventory.CostShare
	|FROM
	|	Document.SalesSlip.Inventory AS SalesSlipInventory
	|WHERE
	|	SalesSlipInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	SalesSlipInventory.MeasurementUnit,
	|	SalesSlipInventory.Products,
	|	SalesSlipInventory.Characteristic,
	|	SalesSlipInventory.VATRate,
	|	SalesSlipInventory.Batch,
	|	SalesSlipInventory.DiscountMarkupPercent,
	|	SalesSlipInventory.Price,
	|	SalesSlipInventory.Ref,
	|	SalesSlipInventory.BundleProduct,
	|	SalesSlipInventory.BundleCharacteristic,
	|	SalesSlipInventory.CostShare
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesTurnovers.Products AS Products,
	|	SalesTurnovers.Characteristic AS Characteristic,
	|	SalesTurnovers.Batch AS Batch,
	|	SUM(SalesTurnovers.QuantityTurnover) AS QuantityBalance,
	|	SalesTurnovers.VATRate AS VATRate
	|INTO Sales
	|FROM
	|	AccumulationRegister.Sales.Turnovers(, , Recorder, Document = &SalesDocument) AS SalesTurnovers
	|WHERE
	|	SalesTurnovers.Recorder <> &Ref
	|
	|GROUP BY
	|	SalesTurnovers.Products,
	|	SalesTurnovers.VATRate,
	|	SalesTurnovers.Characteristic,
	|	SalesTurnovers.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Sales.Products AS Products,
	|	Sales.Characteristic AS Characteristic,
	|	Sales.Batch AS Batch,
	|	Sales.QuantityBalance AS QuantityBalance,
	|	Sales.VATRate AS VATRate
	|INTO Balances
	|FROM
	|	Sales AS Sales
	|WHERE
	|	Sales.QuantityBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesDoc.MeasurementUnit AS MeasurementUnit,
	|	SalesDoc.Products AS Products,
	|	SalesDoc.Characteristic AS Characteristic,
	|	SalesDoc.Batch AS Batch,
	|	SalesDoc.VATRate AS VATRate,
	|	SalesDoc.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesDoc.Order AS Order,
	|	SalesDoc.SalesRep AS SalesRep,
	|	SalesDoc.Quantity AS InitialQuantity,
	|	SalesDoc.Amount AS InitialAmount,
	|	SalesDoc.Price AS InitialPrice,
	|	SalesDoc.Price AS Price,
	|	SalesDoc.SalesDocument AS SalesDocument,
	|	TRUE AS Shipped,
	|	SalesDoc.BundleProduct AS BundleProduct,
	|	SalesDoc.BundleCharacteristic AS BundleCharacteristic,
	|	SalesDoc.CostShare AS CostShare
	|FROM
	|	Balances AS Balances
	|		INNER JOIN SalesDocument AS SalesDoc
	|		ON Balances.Products = SalesDoc.Products
	|			AND Balances.Characteristic = SalesDoc.Characteristic
	|			AND Balances.Batch = SalesDoc.Batch
	|			AND Balances.VATRate = SalesDoc.VATRate";
	
	QueryResult = Query.Execute();
	Inventory.Load(QueryResult.Unload());
	
	// Bundles
	BasisArray = New Array;
	BasisArray.Add(BasisDocument);
	BundlesServer.FillAddedBundles(ThisObject, BasisArray, , "InitialQuantity");
	// End Bundles
	
	For Each Row In Inventory Do
		Rate = DriveReUse.GetVATRateValue(Row.VATRate);
		VATAmount = VATAmount + Row.Amount * Rate / 100;
	EndDo;
	
EndProcedure

Procedure FillInventoryOnRMARequest(BasisDocument, DocumentDate, SalesDocument) Export
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(BasisDocument) = Type("DocumentRef.RMARequest") Then
		
		Query = New Query;
		Query.SetParameter("AmountIncludesVAT",	AmountIncludesVAT);
		Query.SetParameter("BasisDocument",		BasisDocument);
		Query.SetParameter("SalesDocument",		SalesDocument);
		Query.SetParameter("Ref",				Ref);
		
		Query.Text = 
		"SELECT ALLOWED
		|	RMARequest.Ref AS Ref,
		|	RMARequest.Equipment AS Equipment,
		|	RMARequest.Characteristic AS Characteristic,
		|	RMARequest.SerialNumber AS SerialNumber,
		|	RMARequest.Invoice AS Invoice
		|INTO RMARequestHeader
		|FROM
		|	Document.RMARequest AS RMARequest
		|WHERE
		|	RMARequest.Ref = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Inventory.Price AS Price,
		|	Inventory.MeasurementUnit AS MeasurementUnit,
		|	Inventory.Products AS Products,
		|	Inventory.Characteristic AS Characteristic,
		|	Inventory.Batch AS Batch,
		|	SUM(Inventory.Quantity) AS Quantity,
		|	SUM(Inventory.Amount) AS Amount,
		|	Inventory.VATRate AS VATRate,
		|	Inventory.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	Inventory.ConnectionKey AS ConnectionKey,
		|	Inventory.Order AS Order,
		|	Inventory.SalesRep AS SalesRep
		|INTO SalesDocument
		|FROM
		|	Document.SalesInvoice.Inventory AS Inventory
		|WHERE
		|	Inventory.Ref = &SalesDocument
		|
		|GROUP BY
		|	Inventory.MeasurementUnit,
		|	Inventory.Products,
		|	Inventory.Characteristic,
		|	Inventory.VATRate,
		|	Inventory.Batch,
		|	Inventory.DiscountMarkupPercent,
		|	Inventory.ConnectionKey,
		|	Inventory.Price,
		|	Inventory.Order,
		|	Inventory.SalesRep
		|
		|UNION ALL
		|
		|SELECT
		|	SalesSlipInventory.Price,
		|	SalesSlipInventory.MeasurementUnit,
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.Batch,
		|	SUM(SalesSlipInventory.Quantity),
		|	SUM(SalesSlipInventory.Amount),
		|	SalesSlipInventory.VATRate,
		|	SalesSlipInventory.DiscountMarkupPercent,
		|	SalesSlipInventory.ConnectionKey,
		|	VALUE(Document.SalesOrder.EmptyRef),
		|	VALUE(Catalog.Employees.EmptyRef)
		|FROM
		|	Document.SalesSlip.Inventory AS SalesSlipInventory
		|WHERE
		|	SalesSlipInventory.Ref = &SalesDocument
		|
		|GROUP BY
		|	SalesSlipInventory.MeasurementUnit,
		|	SalesSlipInventory.Products,
		|	SalesSlipInventory.Characteristic,
		|	SalesSlipInventory.VATRate,
		|	SalesSlipInventory.Batch,
		|	SalesSlipInventory.DiscountMarkupPercent,
		|	SalesSlipInventory.ConnectionKey,
		|	SalesSlipInventory.Price
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesTurnovers.Products AS Products,
		|	SalesTurnovers.Characteristic AS Characteristic,
		|	SalesTurnovers.Batch AS Batch,
		|	SUM(SalesTurnovers.QuantityTurnover) AS QuantityBalance,
		|	SalesTurnovers.VATRate AS VATRate
		|INTO Sales
		|FROM
		|	AccumulationRegister.Sales.Turnovers(, , Recorder, Document = &SalesDocument) AS SalesTurnovers
		|WHERE
		|	SalesTurnovers.Recorder <> &Ref
		|
		|GROUP BY
		|	SalesTurnovers.Products,
		|	SalesTurnovers.VATRate,
		|	SalesTurnovers.Characteristic,
		|	SalesTurnovers.Batch
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Sales.Products AS Products,
		|	Sales.Characteristic AS Characteristic,
		|	Sales.Batch AS Batch,
		|	Sales.QuantityBalance AS QuantityBalance,
		|	Sales.VATRate AS VATRate
		|INTO Balances
		|FROM
		|	Sales AS Sales
		|WHERE
		|	Sales.QuantityBalance > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SalesDocument.MeasurementUnit AS MeasurementUnit,
		|	SalesDocument.Products AS Products,
		|	SalesDocument.Characteristic AS Characteristic,
		|	SalesDocument.Batch AS Batch,
		|	SalesDocument.VATRate AS VATRate,
		|	SalesDocument.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesDocument.ConnectionKey AS ConnectionKey,
		|	SalesDocument.Order AS Order,
		|	SalesDocument.SalesRep AS SalesRep,
		|	SalesDocument.Quantity AS InitialQuantity,
		|	SalesDocument.Amount AS InitialAmount,
		|	SalesDocument.Price AS InitialPrice,
		|	SalesDocument.Price AS Price,
		|	1 AS Quantity,
		|	CASE
		|		WHEN SalesDocument.Quantity = 0
		|			THEN 0
		|		ELSE CAST(SalesDocument.Amount / SalesDocument.Quantity AS NUMBER(15, 2))
		|	END AS Amount
		|INTO SalesDocumentTable
		|FROM
		|	SalesDocument AS SalesDocument
		|		INNER JOIN Balances AS Balances
		|		ON SalesDocument.Products = Balances.Products
		|			AND SalesDocument.Characteristic = Balances.Characteristic
		|			AND SalesDocument.Batch = Balances.Batch
		|			AND SalesDocument.VATRate = Balances.VATRate
		|		INNER JOIN RMARequestHeader AS RMARequestHeader
		|		ON SalesDocument.Products = RMARequestHeader.Equipment
		|			AND SalesDocument.Characteristic = RMARequestHeader.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
		|	SalesInvoiceSerialNumbers.SerialNumber AS SerialNumber
		|FROM
		|	Document.SalesInvoice.SerialNumbers AS SalesInvoiceSerialNumbers
		|		INNER JOIN RMARequestHeader AS RMARequestHeader
		|		ON SalesInvoiceSerialNumbers.SerialNumber = RMARequestHeader.SerialNumber
		|			AND SalesInvoiceSerialNumbers.Ref = RMARequestHeader.Invoice
		|
		|UNION ALL
		|
		|SELECT
		|	SalesSlipSerialNumbers.ConnectionKey,
		|	SalesSlipSerialNumbers.SerialNumber
		|FROM
		|	Document.SalesSlip.SerialNumbers AS SalesSlipSerialNumbers
		|		INNER JOIN RMARequestHeader AS RMARequestHeader
		|		ON SalesSlipSerialNumbers.SerialNumber = RMARequestHeader.SerialNumber
		|			AND SalesSlipSerialNumbers.Ref = RMARequestHeader.Invoice
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesDocumentTable.MeasurementUnit AS MeasurementUnit,
		|	SalesDocumentTable.Products AS Products,
		|	SalesDocumentTable.Characteristic AS Characteristic,
		|	SalesDocumentTable.Batch AS Batch,
		|	SalesDocumentTable.VATRate AS VATRate,
		|	SalesDocumentTable.DiscountMarkupPercent AS DiscountMarkupPercent,
		|	SalesDocumentTable.ConnectionKey AS ConnectionKey,
		|	SalesDocumentTable.Order AS Order,
		|	SalesDocumentTable.SalesRep AS SalesRep,
		|	SalesDocumentTable.InitialQuantity AS InitialQuantity,
		|	SalesDocumentTable.InitialAmount AS InitialAmount,
		|	SalesDocumentTable.InitialPrice AS InitialPrice,
		|	SalesDocumentTable.Price AS Price,
		|	SalesDocumentTable.Quantity AS Quantity,
		|	SalesDocumentTable.Amount AS Amount,
		|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
		|	TRUE AS Shipped
		|FROM
		|	SalesDocumentTable AS SalesDocumentTable
		|		INNER JOIN Catalog.Products AS CatalogProducts
		|		ON SalesDocumentTable.Products = CatalogProducts.Ref";
		
		QueryResult = Query.ExecuteBatch();
		
		SerialNumbersTable	= QueryResult[5].Unload();
		ProductsTable		= QueryResult[6].Unload();
		
		AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(DocumentDate, Company);
		UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
		
		Inventory.Clear();
		SerialNumbers.Clear();
		
		For Each RowProductsTable In ProductsTable Do
			
			InventoryRow = Inventory.Add();
			
			FillPropertyValues(InventoryRow, RowProductsTable);
			
			Rate = DriveReUse.GetVATRateValue(RowProductsTable.VATRate);
			
			If AmountIncludesVAT Then
				InventoryRow.VATAmount = InventoryRow.Amount - (InventoryRow.Amount) / ((Rate + 100) / 100);
			Else
				InventoryRow.VATAmount = InventoryRow.Amount * Rate / 100;
			EndIf;
			
			InventoryRow.Total = InventoryRow.Amount + ?(AmountIncludesVAT, 0, InventoryRow.VATAmount);
			
			StructureData = New Structure;
			StructureData.Insert("Products",			InventoryRow.Products);
			StructureData.Insert("Characteristic",		InventoryRow.Characteristic);
			StructureData.Insert("Batch",				InventoryRow.Batch);
			StructureData.Insert("Quantity",			InventoryRow.Quantity);
			StructureData.Insert("MeasurementUnit",		InventoryRow.MeasurementUnit);
			StructureData.Insert("PointInTime",			New Boundary(DocumentDate, BoundaryType.Excluding));
			StructureData.Insert("Document",			SalesDocument);
			
			InventoryRow.CostOfGoodsSold = GetCostAmount(StructureData);
			
			If NOT UseGoodsReturnFromCustomer AND RowProductsTable.UseSerialNumbers Then
				
				If SerialNumbersTable.Count() > 0 Then
					
					SerialNumber = SerialNumbersTable[0].SerialNumber;
					
					WorkWithSerialNumbers.AddRowByConnectionKeyAndSerialNumber(
						ThisObject,
						SalesDocument,
						InventoryRow.ConnectionKey,
						SerialNumber);
					
				Else
					
					SerialNumber = Common.ObjectAttributeValue(BasisDocument, "SerialNumber");
					
					WorkWithSerialNumbersClientServer.FillConnectionKey(Inventory, InventoryRow, "ConnectionKey");
					WorkWithSerialNumbers.AddRowByConnectionKeyAndSerialNumber(
						ThisObject,
						Undefined,
						InventoryRow.ConnectionKey, 
						SerialNumber);
					
				EndIf;
				
				InventoryRow.SerialNumbers = WorkWithSerialNumbers.StringSerialNumbers(SerialNumbers, InventoryRow.ConnectionKey);
				
			EndIf;
			
		EndDo;
		
		AdjustedAmount	= Inventory.Total("Total");
		VATAmount			= Inventory.Total("VATAmount");
		
	EndIf;
	
EndProcedure

// Procedure is filling the allocation amount.
//
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
	|			,
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
	If OperationKind <> PredefinedValue("Enum.OperationTypesCreditNote.SalesReturn")
		AND NOT AmountIncludesVAT Then
		InitialAmountLeftToDistribute = AdjustedAmount + VATAmount;
	Else
		InitialAmountLeftToDistribute = AdjustedAmount;
	EndIf;
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
			
			NewRow.VATRate = VATRate;
			NewRow.VATAmount = NewRow.OffsetAmount - (NewRow.OffsetAmount) / ((VATRate.Rate + 100) / 100);
			
		Else
			
			NewRow.Contract		= Contract;
			NewRow.AdvanceFlag	= True;
			NewRow.OffsetAmount	= AmountLeftToDistribute;
			NewRow.VATRate		= VATRate;
			NewRow.VATAmount = NewRow.OffsetAmount - (NewRow.OffsetAmount) / ((VATRate.Rate + 100) / 100);
			
			AmountLeftToDistribute	= 0;
			
		EndIf;
		
	EndDo;
	
	AmountLeftToDistribute = InitialAmountLeftToDistribute - AmountAllocation.Total("OffsetAmount");
	If AmountLeftToDistribute <> 0 Then
		AmountAllocation[AmountAllocation.Count()-1].OffsetAmount = AmountAllocation[AmountAllocation.Count()-1].OffsetAmount + AmountLeftToDistribute;
	EndIf;
	
	VATAmountLeftToDistribute = VATAmount - AmountAllocation.Total("VATAmount");
	If VATAmountLeftToDistribute <> 0 Then
		AmountAllocation[AmountAllocation.Count()-1].VATAmount = AmountAllocation[AmountAllocation.Count()-1].VATAmount + VATAmountLeftToDistribute;
	EndIf;
	
	If AmountAllocation.Count() = 0 Then
		AmountAllocation.Add();
		AmountAllocation[0].OffsetAmount = AdjustedAmount;
	EndIf;
	
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

#Region Private

Procedure FillGLAccountsForAmountAllocation()
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
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

Procedure FillSalesRep()
	
	SalesRep = Undefined;
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = Common.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
	For Each CurrentRow In Inventory Do
		Order = Undefined;
		If ValueIsFilled(CurrentRow.SalesRep) Then
			Continue;
		ElsIf ValueIsFilled(CurrentRow.Order)
			And CurrentRow.Order <> Order Then
			CurrentRow.SalesRep = Common.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
			Order = CurrentRow.SalesRep;
		Else
			CurrentRow.SalesRep = SalesRep;
		EndIf;
	EndDo;
	
EndProcedure

Function GetCostAmount(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		ReturnQuantity = StructureData.Quantity;
	Else
		ReturnQuantity = StructureData.Quantity * StructureData.MeasurementUnit.Factor;
	EndIf;
	
	If TypeOf(StructureData.Document) = Type("DocumentRef.SalesSlip") Then
		ShiftClosure = Common.ObjectAttributeValue(StructureData.Document, "CashCRSession");
	Else
		ShiftClosure = Documents.ShiftClosure.EmptyRef();
	EndIf;
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesTurnovers.QuantityTurnover AS QuantityTurnover,
	|	SalesTurnovers.CostTurnover AS CostTurnover,
	|	SalesTurnovers.Recorder AS Recorder
	|INTO SalesTurnoversTable
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			,
	|			&PointInTime,
	|			Recorder,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND Batch = &Batch) AS SalesTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(SalesTurnoversTable.QuantityTurnover) AS QuantityTurnover,
	|	SUM(SalesTurnoversTable.CostTurnover) AS CostTurnover
	|INTO Table
	|FROM
	|	SalesTurnoversTable AS SalesTurnoversTable
	|WHERE
	|	(SalesTurnoversTable.Recorder = &Document
	|			OR SalesTurnoversTable.Recorder = &ShiftClosure)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	CASE
	|		WHEN Table.QuantityTurnover = 0
	|			THEN 0
	|		ELSE CAST(Table.CostTurnover * &ReturnQuantity / Table.QuantityTurnover AS NUMBER(15, 2))
	|	END AS CostOfGoodsSold
	|FROM
	|	Table AS Table";
	
	Query.SetParameter("Batch",				StructureData.Batch);
	Query.SetParameter("Characteristic",	StructureData.Characteristic);
	Query.SetParameter("Document",			StructureData.Document);
	Query.SetParameter("Products",			StructureData.Products);
	Query.SetParameter("PointInTime",		StructureData.PointInTime);
	Query.SetParameter("ReturnQuantity",	ReturnQuantity);
	Query.SetParameter("ShiftClosure",		ShiftClosure);
	
	QueryResult = Query.Execute();
	
	CostOfGoodsSold = 0;
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		CostOfGoodsSold = Selection.CostOfGoodsSold;
		
	EndIf;
	
	Return CostOfGoodsSold;
	
EndFunction

Function GetBasisTable()
	
	BasisTable = Inventory.Unload(, "SalesDocument");
	BasisTable.GroupBy("SalesDocument");
	Return BasisTable;
	
EndFunction

#EndRegion

#EndIf
