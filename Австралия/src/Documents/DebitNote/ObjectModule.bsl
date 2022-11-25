#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	
#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(AdjustedAmount) And AmountAllocation.Count() = 0 Then
		
		FillAmountAllocation();
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then 
			FillGLAccountsForAmountAllocation();
		EndIf;
		
	EndIf;
	
	If Inventory.Count() > 0 
		Or Not ForOpeningBalancesOnly Then
		
		DocumentAmount = AdjustedAmount;
		
	EndIf;
	
	DocumentTax = Inventory.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
	
	If OperationKind <> Enums.OperationTypesDebitNote.PurchaseReturn
		And OperationKind <> Enums.OperationTypesDebitNote.DropShipping Then
		DocumentAmount = DocumentAmount + ?(AmountIncludesVAT, 0, VATAmount);
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	InventoryOwnershipServer.FillMainTableColumn(ThisObject, WriteMode, Cancel);
	
	If OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		
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
	
	UseDefaultTypeOfAccounting = GetFunctionalOption("UseDefaultTypeOfAccounting");
	IsReturn = (OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Or OperationKind = Enums.OperationTypesDebitNote.DropShipping);
	
	If IsReturn
		And Inventory.Count() <> 0
		And AdjustedAmount = 0 Then
		
		CommonClientServer.MessageToUser(NStr("en = 'Fill in the quantity of goods to return.'; ru = 'Укажите количество товаров, которые необходимо оформить к возврату.';pl = 'Uzupełnij ilość towarów do zwrotu.';es_ES = 'Rellenar la cantidad de mercancías para devolver.';es_CO = 'Rellenar la cantidad de mercancías para devolver.';tr = 'İade edilecek ürün miktarını doldurun.';it = 'Compilate la quantità di beni da restituire.';de = 'Geben Sie die Menge der Waren ein, die Sie zurücksenden möchten.'"), , , , Cancel);
	EndIf;
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	If OperationKind <> Enums.OperationTypesDebitNote.PurchaseReturn 
		Or AccountingPolicy.UseGoodsReturnToSupplier Then
		CheckedAttributes.Delete(CheckedAttributes.Find("StructuralUnit"));
	EndIf;
	
	If Not IsReturn Then
		
		If UseDefaultTypeOfAccounting Then
			If Not GLAccountsInDocuments.IsIncomeGLA(GLAccount) Then
				CheckedAttributes.Delete(CheckedAttributes.Find("IncomeItem"));
			EndIf;
		ElsIf Not RegisterIncome Then
			CheckedAttributes.Delete(CheckedAttributes.Find("IncomeItem"));
		EndIf;
		
	EndIf;
	
	If IsReturn Then	
		
		CheckedAttributes.Delete(CheckedAttributes.Find("AdjustedAmount"));
		CheckedAttributes.Delete(CheckedAttributes.Find("IncomeItem"));
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			CheckedAttributes.Delete(CheckedAttributes.Find("GLAccount"));
			
			For Each Row In Inventory Do
				
				If GLAccountsInDocuments.IsIncomeAndExpenseGLA(Row.PurchaseReturnGLAccount)
					And Not ValueIsFilled(Row.PurchaseReturnItem) Then
						Message = NStr("en = 'The ""Purchase return item"" is required on line %1 of the ""Products"" list.'; ru = 'Не заполнена статья возврата поставщику в строке %1 списка ""Номенклатура"".';pl = 'Wymagana jest ""Pozycja zwrotu zakupu"" w wierszu %1 listy ""Produkty"".';es_ES = 'El ""Artículo de la devolución de la compra"" se requiere en la línea %1 de la lista ""Productos"".';es_CO = 'El ""Artículo de la devolución de la compra"" se requiere en la línea %1 de la lista ""Productos"".';tr = '""Ürünler"" listesinin %1 satırında ""Satın alma iadesi kalemi"" gerekli.';it = '""Voce di ritorno di acquisto"" è richiesto alla riga %1 dell''elenco ""Articoli"".';de = 'Die ""Position von Einkaufsrückgabe"" ist in der Zeile %1 der Liste ""Produkte"" erforderlich.'");
						Message = StringFunctionsClientServer.SubstituteParametersToString(Message, Row.LineNumber);
						CommonClientServer.MessageToUser(Message, , , , Cancel);
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory"));
	EndIf;
	
	If (OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn And GetBasisTable().Count() <= 1)
			Or OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		FoundAttribute = CheckedAttributes.Find("BasisDocument");
		If FoundAttribute = Undefined Then
			CheckedAttributes.Add("BasisDocument");
		EndIf;
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BasisDocument");
	EndIf;
	
	If Not AccountingPolicy.UseGoodsReturnToSupplier Then
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnit, ThisObject);
		BatchesServer.CheckFilling(ThisObject, Cancel);
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
		
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]			= "FillByGoodsIssue";
	FillingStrategy[Type("DocumentRef.CashVoucher")]		= "FillByCashVoucher";
	FillingStrategy[Type("DocumentRef.PaymentExpense")]		= "FillByPaymentExpense";
	FillingStrategy[Type("DocumentRef.RMARequest")]			= "FillByRMARequest";
	FillingStrategy[Type("DocumentRef.CreditNote")]			= "FillByCreditNote";
	
	If TypeOf(FillingData) = Type("DocumentRef.CashVoucher")
		OR TypeOf(FillingData) = Type("DocumentRef.PaymentExpense") Then
		
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
	Documents.DebitNote.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel);
	
	If OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn
			Or OperationKind = Enums.OperationTypesDebitNote.DropShipping Then
		If NOT AdditionalProperties.AccountingPolicy.UseGoodsReturnToSupplier Then
			DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
	EndIf;
	
	If GetFunctionalOption("UseVAT")
		AND VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		
		If WorkWithVAT.GetUseTaxInvoiceForPostingVAT(Date, Company) Then
			DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
		Else
			DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		
	EndIf;
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Subordinate documents
	If Not Cancel Then
		
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
	// Control of occurrence of a negative balance.
	Documents.DebitNote.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
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
	Documents.DebitNote.RunControl(Ref, AdditionalProperties, Cancel);
	
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

Procedure FillBySupplierInvoice(FillingData) Export
	
	// Document basis and document setting.
	SupplierInvoicesArray = New Array;
	Contract = Undefined;
	VATAmount = 0;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfSupplierInvoices") Then
		
		For Each ArrayItem In FillingData.ArrayOfSupplierInvoices Do
			Contract = ArrayItem.Contract;
			SupplierInvoicesArray.Add(ArrayItem.Ref);
		EndDo;
		
		SupplierInvoice = SupplierInvoicesArray[0];
		
	Else
		SupplierInvoicesArray.Add(FillingData.Ref);
		SupplierInvoice = FillingData;
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
	|	SupplierInvoice.Cell AS Cell,
	|	SupplierInvoice.Contract AS Contract,
	|	SupplierInvoice.Order AS Order,
	|	SupplierInvoice.Counterparty AS Counterparty,
	|	SupplierInvoice.VATTaxation AS VATTaxation,
	|	SupplierInvoice.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoice.ExchangeRate AS ExchangeRate,
	|	SupplierInvoice.Multiplicity AS Multiplicity,
	|	SupplierInvoice.AmountIncludesVAT AS AmountIncludesVAT
	|INTO SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref IN(&SupplierInvoiceArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	SupplierInvoiceHeader.BasisRef AS BasisRef,
	|	SupplierInvoiceHeader.BasisPosted AS BasisPosted,
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.Cell AS Cell,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	SupplierInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceHeader.ExchangeRate AS ExchangeRate,
	|	SupplierInvoiceHeader.Multiplicity AS Multiplicity,
	|	SupplierInvoiceHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	CASE
	|		WHEN SupplierInvoiceInventory.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN SupplierInvoiceInventory.Order
	|		ELSE SupplierInvoiceHeader.Order
	|	END AS Order,
	|	SupplierInvoiceInventory.VATRate AS VATRate,
	|	SupplierInvoiceInventory.VATAmount AS VATAmount
	|INTO SupplierInvoiceFiltred
	|FROM
	|	SupplierInvoiceHeader AS SupplierInvoiceHeader
	|		LEFT JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON SupplierInvoiceHeader.BasisRef = SupplierInvoiceInventory.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoiceFiltred.BasisRef AS BasisDocument,
	|	SupplierInvoiceFiltred.BasisPosted AS BasisPosted,
	|	SupplierInvoiceFiltred.Company AS Company,
	|	SupplierInvoiceFiltred.CompanyVATNumber AS CompanyVATNumber,
	|	SupplierInvoiceFiltred.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceFiltred.Cell AS Cell,
	|	SupplierInvoiceFiltred.Counterparty AS Counterparty,
	|	SupplierInvoiceFiltred.Contract AS Contract,
	|	SupplierInvoiceFiltred.Order AS Order,
	|	ISNULL(SupplierInvoiceFiltred.DocumentCurrency, Contracts.SettlementsCurrency) AS DocumentCurrency,
	|	SupplierInvoiceFiltred.VATTaxation AS VATTaxation,
	|	SupplierInvoiceFiltred.AmountIncludesVAT AS AmountIncludesVAT,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	SupplierInvoiceFiltred.VATRate AS VATRate,
	|	SupplierInvoiceFiltred.VATAmount AS VATAmount,
	|	VALUE(Enum.OperationTypesDebitNote.PurchaseReturn) AS OperationKind
	|FROM
	|	SupplierInvoiceFiltred AS SupplierInvoiceFiltred
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON SupplierInvoiceFiltred.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON (ISNULL(SupplierInvoiceFiltred.DocumentCurrency, Contracts.SettlementsCurrency) = DC_Rates.Currency)
	|			AND SupplierInvoiceFiltred.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND SupplierInvoiceFiltred.Company = CC_Rates.Company
	|
	|ORDER BY
	|	Order DESC";
	
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("SupplierInvoiceArray", SupplierInvoicesArray);
	Query.SetParameter("Contract", Contract);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	    
	FilterData = New Structure("SupplierInvoicesArray, Contract", SupplierInvoicesArray, Contract);
	
	Documents.DebitNote.FillBySupplierInvoices(DocumentData, FilterData, Inventory);
	
	AdjustedAmount = Inventory.Total("Total");
	VATAmount = Inventory.Total("VATAmount");
	BasisTable = GetBasisTable();
	BasisDocumentInTabularSection = False;
	
	If BasisTable.Count() > 1 Then
		BasisDocumentInTabularSection = True;
		BasisDocument = Undefined;
	ElsIf Not ValueIsFilled(BasisDocument) Then
		If BasisTable.Count() > 0 Then
			BasisDocument = BasisTable[0].SupplierInvoice;
		EndIf;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If SupplierInvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Goods from this document have already been returned: %1.'; ru = 'Товары из этого документа уже возвращены: %1.';pl = 'Towary z tego dokumentu już zostały zwrócone: %1.';es_ES = 'Se han devuelto ya las mercancías de este documento: %1.';es_CO = 'Se han devuelto ya las mercancías de este documento: %1.';tr = 'Bu belgeden ürünler zaten iade edildi: %1.';it = 'Le merci di questo documento sono già state restituite: %1.';de = 'Waren aus diesem Dokument sind bereits zurückgegeben: %1.'"),
				SupplierInvoice);
		Else
			MessageText = NStr("en = 'Goods from these documents have already been returned.'; ru = 'Товары из этих документов уже возвращены.';pl = 'Towary z tych dokumentów już zostały zwrócone.';es_ES = 'Se han devuelto ya las mercancías de estos documentos.';es_CO = 'Se han devuelto ya las mercancías de estos documentos.';tr = 'Bu belgelerden ürünler zaten iade edildi.';it = 'Le merci di questo documento sono già state restituite.';de = 'Waren aus diesen Dokumenten sind bereits zurückgegeben.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;

EndProcedure

Procedure FillByRMARequest(FillingData) Export
	
	DocumentDate	= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	RMARequest.Equipment AS Equipment,
	|	RMARequest.Characteristic AS Characteristic,
	|	RMARequest.Company AS Company,
	|	RMARequest.SerialNumber AS SerialNumber
	|INTO RMARequestTable
	|FROM
	|	Document.RMARequest AS RMARequest
	|WHERE
	|	RMARequest.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SerialNumbers.Recorder AS Recorder
	|INTO SerialNumberRecorder
	|FROM
	|	InformationRegister.SerialNumbersInWarranty AS SerialNumbers
	|		INNER JOIN RMARequestTable AS RMARequestTable
	|		ON SerialNumbers.Products = RMARequestTable.Equipment
	|			AND SerialNumbers.Characteristic = RMARequestTable.Characteristic
	|			AND SerialNumbers.SerialNumber = RMARequestTable.SerialNumber
	|WHERE
	|	SerialNumbers.Operation = VALUE(Enum.SerialNumbersOperations.Receipt)
	|	AND (SerialNumbers.Recorder REFS Document.SupplierInvoice
	|			OR SerialNumbers.Recorder REFS Document.GoodsReceipt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	GoodsInvoicedNotReceived.SupplierInvoice AS SupplierInvoice
	|FROM
	|	AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|		INNER JOIN RMARequestTable AS RMARequestTable
	|		ON GoodsInvoicedNotReceived.Company = RMARequestTable.Company
	|			AND GoodsInvoicedNotReceived.Products = RMARequestTable.Equipment
	|			AND GoodsInvoicedNotReceived.Characteristic = RMARequestTable.Characteristic
	|		INNER JOIN SerialNumberRecorder AS SerialNumberRecorder
	|		ON GoodsInvoicedNotReceived.Recorder = SerialNumberRecorder.Recorder
	|			AND (SerialNumberRecorder.Recorder REFS Document.GoodsReceipt)
	|WHERE
	|	GoodsInvoicedNotReceived.RecordType = VALUE(AccumulationRecordType.Expense)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	GoodsReceivedNotInvoiced.Recorder
	|FROM
	|	AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
	|		INNER JOIN RMARequestTable AS RMARequestTable
	|		ON GoodsReceivedNotInvoiced.Company = RMARequestTable.Company
	|			AND GoodsReceivedNotInvoiced.Products = RMARequestTable.Equipment
	|			AND GoodsReceivedNotInvoiced.Characteristic = RMARequestTable.Characteristic
	|		INNER JOIN SerialNumberRecorder AS SerialNumberRecorder
	|		ON GoodsReceivedNotInvoiced.GoodsReceipt = SerialNumberRecorder.Recorder
	|			AND (SerialNumberRecorder.Recorder REFS Document.GoodsReceipt)
	|WHERE
	|	GoodsReceivedNotInvoiced.RecordType = VALUE(AccumulationRecordType.Expense)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	SerialNumberRecorder.Recorder
	|FROM
	|	SerialNumberRecorder AS SerialNumberRecorder
	|WHERE
	|	SerialNumberRecorder.Recorder REFS Document.SupplierInvoice";
	
	Query.SetParameter("Ref", FillingData.Ref);
	
	QueryResult = Query.Execute();
	
	If NOT QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection.SupplierInvoice,, "Ref, Number, Date, BasisDocument, Author, Posted, DeletionMark, Comment");
		
		BasisDocument = Selection.SupplierInvoice;
		
		DocumentAmount		= 0;
		OperationKind		= Enums.OperationTypesDebitNote.PurchaseReturn;
		PriceKind			= ?(ValueIsFilled(PriceKind), PriceKind, Catalogs.PriceTypes.Wholesale);
		AmountIncludesVAT	= Common.ObjectAttributeValue(PriceKind, "PriceIncludesVAT");
		VATTaxation			= ?(ValueIsFilled(VATTaxation), VATTaxation, DriveServer.VATTaxation(Company, DocumentDate));
		VATRate				= InformationRegisters.AccountingPolicy.GetDefaultVATRate(DocumentDate, Company);
		
		FillInventoryOnRMARequest(BasisDocument, FillingData, DocumentDate);
		
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'Supplier invoice not found'; ru = 'Инвойс поставщика не найден';pl = 'Nie znaleziono faktury zakupu';es_ES = 'La factura de proveedor no encontrada';es_CO = 'La factura de proveedor no encontrada';tr = 'Satın alma faturası bulunamadı';it = 'Fattura fornitore non trovata';de = 'Lieferantenrechnung nicht gefunden'"), Ref);
		
	EndIf
	
EndProcedure

Procedure FillInventoryOnRMARequest(BasisDocument, RMARequest, DocumentDate);
	
	If BasisDocument = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
		
		Query = New Query;
		Query.SetParameter("AmountIncludesVAT",	AmountIncludesVAT);
		Query.SetParameter("BasisDocument",		BasisDocument);
		Query.SetParameter("Ref",				Ref);
		Query.SetParameter("RMARequest",		RMARequest);
		
		Query.Text = 
		"SELECT ALLOWED
		|	SupplierInvoice.Ref AS Ref,
		|	SupplierInvoice.Company AS Company
		|INTO SupplInvHeader
		|FROM
		|	Document.SupplierInvoice AS SupplierInvoice
		|WHERE
		|	SupplierInvoice.Ref = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	RMARequest.Ref AS Ref,
		|	RMARequest.Company AS Company,
		|	RMARequest.Equipment AS Equipment,
		|	RMARequest.Characteristic AS Characteristic,
		|	RMARequest.SerialNumber AS SerialNumber
		|INTO RMARequestHeader
		|FROM
		|	Document.RMARequest AS RMARequest
		|WHERE
		|	RMARequest.Ref = &RMARequest
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SupplInvHeader.Company AS Company,
		|	SupplInvInventory.Price AS Price,
		|	SupplInvInventory.MeasurementUnit AS MeasurementUnit,
		|	SupplInvInventory.Products AS Products,
		|	SupplInvInventory.Characteristic AS Characteristic,
		|	SupplInvInventory.Batch AS Batch,
		|	SUM(SupplInvInventory.Quantity) AS Quantity,
		|	SUM(SupplInvInventory.Amount) AS Amount,
		|	SupplInvInventory.VATRate AS VATRate,
		|	SupplInvInventory.ConnectionKey AS ConnectionKey,
		|	SupplInvInventory.Order AS Order
		|INTO SupplierInvoice
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplInvInventory
		|		INNER JOIN SupplInvHeader AS SupplInvHeader
		|		ON SupplInvInventory.Ref = SupplInvHeader.Ref
		|
		|GROUP BY
		|	SupplInvHeader.Company,
		|	SupplInvInventory.Products,
		|	SupplInvInventory.MeasurementUnit,
		|	SupplInvInventory.Characteristic,
		|	SupplInvInventory.Batch,
		|	SupplInvInventory.VATRate,
		|	SupplInvInventory.ConnectionKey,
		|	SupplInvInventory.Price,
		|	SupplInvInventory.Order
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	PurchasesTurnovers.Products AS Products,
		|	PurchasesTurnovers.Characteristic AS Characteristic,
		|	PurchasesTurnovers.Batch AS Batch,
		|	PurchasesTurnovers.VATRate AS VATRate,
		|	SUM(PurchasesTurnovers.QuantityTurnover) AS QuantityBalance
		|INTO Purchases
		|FROM
		|	AccumulationRegister.Purchases.Turnovers(, , Recorder, Document = &BasisDocument) AS PurchasesTurnovers
		|WHERE
		|	PurchasesTurnovers.Recorder <> &Ref
		|
		|GROUP BY
		|	PurchasesTurnovers.Products,
		|	PurchasesTurnovers.Characteristic,
		|	PurchasesTurnovers.Batch,
		|	PurchasesTurnovers.VATRate
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Purchases.Products AS Products,
		|	Purchases.Characteristic AS Characteristic,
		|	Purchases.Batch AS Batch,
		|	Purchases.VATRate AS VATRate,
		|	Purchases.QuantityBalance AS QuantityBalance
		|INTO Balances
		|FROM
		|	Purchases AS Purchases
		|WHERE
		|	Purchases.QuantityBalance > 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	SupplierInvoice.Price AS InitialPrice,
		|	SupplierInvoice.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoice.Products AS Products,
		|	SupplierInvoice.Characteristic AS Characteristic,
		|	SupplierInvoice.Batch AS Batch,
		|	SupplierInvoice.Quantity AS InitialQuantity,
		|	SupplierInvoice.Amount AS InitialAmount,
		|	SupplierInvoice.VATRate AS VATRate,
		|	SupplierInvoice.ConnectionKey AS ConnectionKey,
		|	SupplierInvoice.Order AS Order,
		|	SupplierInvoice.Price AS Price,
		|	1 AS Quantity,
		|	CASE
		|		WHEN SupplierInvoice.Quantity = 0
		|			THEN 0
		|		ELSE CAST(SupplierInvoice.Amount / SupplierInvoice.Quantity AS NUMBER(15, 2))
		|	END AS Amount
		|INTO SupplierInvoiceTable
		|FROM
		|	SupplierInvoice AS SupplierInvoice
		|		INNER JOIN Balances AS Balances
		|		ON SupplierInvoice.Products = Balances.Products
		|			AND SupplierInvoice.Characteristic = Balances.Characteristic
		|			AND SupplierInvoice.Batch = Balances.Batch
		|			AND SupplierInvoice.VATRate = Balances.VATRate
		|		INNER JOIN RMARequestHeader AS RMARequestHeader
		|		ON SupplierInvoice.Products = RMARequestHeader.Equipment
		|			AND SupplierInvoice.Characteristic = RMARequestHeader.Characteristic
		|			AND SupplierInvoice.Company = RMARequestHeader.Company
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SupplierInvoiceSerialNumbers.ConnectionKey AS ConnectionKey,
		|	SupplierInvoiceSerialNumbers.SerialNumber AS SerialNumber
		|FROM
		|	Document.SupplierInvoice.SerialNumbers AS SupplierInvoiceSerialNumbers
		|		INNER JOIN SupplInvHeader AS SupplInvHeader
		|		ON SupplierInvoiceSerialNumbers.Ref = SupplInvHeader.Ref
		|		INNER JOIN RMARequestHeader AS RMARequestHeader
		|		ON SupplierInvoiceSerialNumbers.SerialNumber = RMARequestHeader.SerialNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SupplierInvoiceTable.InitialPrice AS InitialPrice,
		|	SupplierInvoiceTable.MeasurementUnit AS MeasurementUnit,
		|	SupplierInvoiceTable.Products AS Products,
		|	SupplierInvoiceTable.Characteristic AS Characteristic,
		|	SupplierInvoiceTable.Batch AS Batch,
		|	SupplierInvoiceTable.InitialQuantity AS InitialQuantity,
		|	SupplierInvoiceTable.InitialAmount AS InitialAmount,
		|	SupplierInvoiceTable.VATRate AS VATRate,
		|	SupplierInvoiceTable.ConnectionKey AS ConnectionKey,
		|	SupplierInvoiceTable.Order AS Order,
		|	SupplierInvoiceTable.Price AS Price,
		|	SupplierInvoiceTable.Quantity AS Quantity,
		|	SupplierInvoiceTable.Amount AS Amount,
		|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers
		|FROM
		|	SupplierInvoiceTable AS SupplierInvoiceTable
		|		INNER JOIN Catalog.Products AS CatalogProducts
		|		ON SupplierInvoiceTable.Products = CatalogProducts.Ref";
		
		QueryResult = Query.ExecuteBatch();
		
		SerialNumbersTable	= QueryResult[6].Unload();
		ProductsTable		= QueryResult[7].Unload();
		
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
			
			If NOT UseGoodsReturnFromCustomer AND RowProductsTable.UseSerialNumbers Then
				
				If SerialNumbersTable.Count() > 0 Then
					
					SerialNumber = SerialNumbersTable[0].SerialNumber;
					
					WorkWithSerialNumbers.AddRowByConnectionKeyAndSerialNumber(
						ThisObject,
						BasisDocument,
						InventoryRow.ConnectionKey,
						SerialNumber);
					
				Else
					
					SerialNumber = Common.ObjectAttributeValue(RMARequest, "SerialNumber");
					
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

Procedure FillByCashOrBankPayment(FillingData, QueryText)
	
	BasisDocument = FillingData;
	
	FillPropertyValues(ThisObject, FillingData,, "Ref, Number, Date, Posted, DeletionMark, BasisDocument, Comment, OperationKind");
	
	OperationKind		= Enums.OperationTypesDebitNote.DiscountReceived;
	AmountIncludesVAT	= True;
	
	DateParameter = EndOfDay(?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	IncomeItem = Catalogs.DefaultIncomeAndExpenseItems.GetItem("DiscountReceived");
	
	Query = New Query;
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("DocumentDate", DateParameter);
	
	Query.Text = QueryText;
	
	ResultArray		= Query.ExecuteBatch();
	QueryResult1	= ResultArray[4];
	QueryResult2	= ResultArray[5];
	
	If NOT QueryResult1.IsEmpty() Then
		
		ResultTable	= QueryResult1.Unload();
		FirstRow	= ResultTable[0];
		
		DebitedTransactions.Load(QueryResult2.Unload());
		
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
		ElsIf DebitedTransactions.Count() > 0 Then
			VATRatesDT = DebitedTransactions.Unload( , "VATRate");
			VATRatesDT.GroupBy("VATRate");
			If VATRatesDT.Count() = 1 Then
				VATRate = VATRatesDT[0].VATRate;
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
			
			FillPropertyValues(NewAllocation, Row, "Contract, Document, OffsetAmount, Order, AccountsPayableGLAccount, AdvancesPaidGLAccount");
			
			NewAllocation.VATRate = VATRate;
			
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				
				NewAllocation.VATAmount = 0;
				
			Else
				
				VATRateForCalc = DriveReUse.GetVATRateValue(NewAllocation.VATRate);
				NewAllocation.VATAmount = NewAllocation.OffsetAmount - NewAllocation.OffsetAmount / (100 + VATRateForCalc) * 100;
				
			EndIf;
			
			If Not ValueIsFilled(NewAllocation.VATInputGLAccount) And GetFunctionalOption("UseDefaultTypeOfAccounting") Then
				
				StructureData = New Structure;
				StructureData.Insert("TabName", "AmountAllocation");
				ObjectParameters = GLAccountsInDocuments.GetObjectParametersByMetadata(ThisObject, Metadata());
				StructureData.Insert("ObjectParameters", ObjectParameters);
				StructureData.Insert("CounterpartyGLAccounts",	True);
				StructureData.Insert("AccountsPayableGLAccount",	NewAllocation.AccountsPayableGLAccount);
				StructureData.Insert("AdvancesPaidGLAccount",	NewAllocation.AdvancesPaidGLAccount);
				StructureData.Insert("VATInputGLAccount",	NewAllocation.VATInputGLAccount);
				StructureData.Insert("Document",			NewAllocation.Document);
				StructureData.Insert("VATRate",				NewAllocation.VATRate);
				StructureData.Insert("LineNumber",			NewAllocation.LineNumber);
				GLAccountsInDocuments.FillCounterpartyGLAccounts(StructureData);
				
				NewAllocation.VATInputGLAccount = StructureData.VATInputGLAccount;
				
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

Procedure FillByCashVoucher(FillingData) Export
	
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
	|	CashVoucherPaymentDetails.Contract AS Contract,
	|	CashVoucherPaymentDetails.Document AS Document,
	|	CashVoucherPaymentDetails.Order AS Order,
	|	CashVoucherPaymentDetails.SettlementsEPDAmount AS OffsetAmount,
	|	CashVoucherPaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	CashVoucherPaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO TempPaymentDelails
	|FROM
	|	Document.CashVoucher.PaymentDetails AS CashVoucherPaymentDetails
	|WHERE
	|	CashVoucherPaymentDetails.Ref = &Ref
	|	AND CashVoucherPaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SupplierInvoice.ProvideEPD AS ProvideEPD,
	|	SupplierInvoice.Number AS Number,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.Company AS Company,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	TempPaymentDelails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	TempPaymentDelails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TempPaymentDelails.Document = SupplierInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SupplierInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
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
	|	TempPaymentDelailsWithInvoice.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	TempPaymentDelailsWithInvoice.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRate AS TempExchangeRate
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRate.Currency
	|			AND TempPaymentDelailsWithInvoice.Company = TempExchangeRate.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
	|		ON PurchasesTurnovers.Recorder = SupplierInvoiceTable.Document";
	
	FillByCashOrBankPayment(FillingData, QueryText);
	
EndProcedure

Procedure FillByPaymentExpense(FillingData) Export
	
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
	|	PaymentExpensePaymentDetails.Contract AS Contract,
	|	PaymentExpensePaymentDetails.Document AS Document,
	|	PaymentExpensePaymentDetails.Order AS Order,
	|	PaymentExpensePaymentDetails.SettlementsEPDAmount AS OffsetAmount,
	|	PaymentExpensePaymentDetails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	PaymentExpensePaymentDetails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO TempPaymentDelails
	|FROM
	|	Document.PaymentExpense.PaymentDetails AS PaymentExpensePaymentDetails
	|WHERE
	|	PaymentExpensePaymentDetails.Ref = &Ref
	|	AND PaymentExpensePaymentDetails.SettlementsEPDAmount > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TempPaymentDelails.Contract AS Contract,
	|	TempPaymentDelails.Document AS Document,
	|	TempPaymentDelails.Order AS Order,
	|	TempPaymentDelails.OffsetAmount AS OffsetAmount,
	|	SupplierInvoice.ProvideEPD AS ProvideEPD,
	|	SupplierInvoice.Number AS Number,
	|	SupplierInvoice.Date AS Date,
	|	SupplierInvoice.Company AS Company,
	|	ISNULL(Contracts.SettlementsCurrency, VALUE(Catalog.Currencies.EmptyRef)) AS SettlementsCurrency,
	|	TempPaymentDelails.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	TempPaymentDelails.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|INTO TempPaymentDelailsWithInvoice
	|FROM
	|	TempPaymentDelails AS TempPaymentDelails
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON TempPaymentDelails.Document = SupplierInvoice.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON TempPaymentDelails.Contract = Contracts.Ref
	|WHERE
	|	(SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNote)
	|			OR SupplierInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.CreditDebitNoteWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TempPaymentDelailsWithInvoice.Document AS Document
	|INTO SupplierInvoiceTable
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
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
	|	TempPaymentDelailsWithInvoice.AccountsPayableGLAccount AS AccountsPayableGLAccount,
	|	TempPaymentDelailsWithInvoice.AdvancesPaidGLAccount AS AdvancesPaidGLAccount
	|FROM
	|	TempPaymentDelailsWithInvoice AS TempPaymentDelailsWithInvoice
	|		LEFT JOIN TempExchangeRate AS TempExchangeRate
	|		ON TempPaymentDelailsWithInvoice.SettlementsCurrency = TempExchangeRate.Currency
	|			AND TempPaymentDelailsWithInvoice.Company = TempExchangeRate.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PurchasesTurnovers.Recorder AS Document,
	|	PurchasesTurnovers.VATRate AS VATRate,
	|	CASE
	|		WHEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover
	|		ELSE -(PurchasesTurnovers.AmountTurnover + PurchasesTurnovers.VATAmountTurnover)
	|	END AS Amount,
	|	CASE
	|		WHEN PurchasesTurnovers.VATAmountTurnover > 0
	|			THEN PurchasesTurnovers.VATAmountTurnover
	|		ELSE -PurchasesTurnovers.VATAmountTurnover
	|	END AS VATAmount
	|FROM
	|	AccumulationRegister.Purchases.Turnovers(, , Recorder, ) AS PurchasesTurnovers
	|		INNER JOIN SupplierInvoiceTable AS SupplierInvoiceTable
	|		ON PurchasesTurnovers.Recorder = SupplierInvoiceTable.Document";
	
	FillByCashOrBankPayment(FillingData, QueryText);
	
EndProcedure

Procedure FillByGoodsIssue(FillingData) Export
	
	// Document basis and document setting.
	GoodsIssuesArray = New Array;
	Contract = Undefined;
	VATAmount = 0;
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("ArrayOfGoodsIssues") Then
		
		NoProductsDoc = 0;
		For Each ArrayItem In FillingData.ArrayOfGoodsIssues Do
			If ArrayItem.Ref.Products.Count() = 0 Then
				NoProductsDoc = NoProductsDoc + 1;
			EndIf;
			Contract = ArrayItem.Contract;
			GoodsIssuesArray.Add(ArrayItem.Ref);
		EndDo;
		
		If NoProductsDoc = GoodsIssuesArray.Count() Then
			MessageToUser = NStr("en = 'Cannot perform the action. The Goods issue does not include any products.'; ru = 'Не удалось выполнить действие. Отпуск товаров не содержит номенклатуру.';pl = 'Nie można wykonać działania. Wydanie zewnętrzne nie może zawierać żadnych produktów.';es_ES = 'No se puede realizar la acción. La salida de mercancías no incluye ningún producto.';es_CO = 'No se puede realizar la acción. La salida de mercancías no incluye ningún producto.';tr = 'İşlem gerçekleştirilemiyor. Ambar çıkışı hiçbir ürün içermiyor.';it = 'Impossibile eseguire l''azione. La spedizione della merce non include nessun articolo.';de = 'Fehler beim Erfüllen der Aktion. Der Warenausgang enthält keine Produkte.'");
			Raise MessageToUser;
		EndIf;
		
		GoodsIssue = GoodsIssuesArray[0];
		
	Else
		If FillingData.Products.Count() = 0 Then
			MessageToUser = NStr("en = 'Cannot perform the action. The Goods issue does not include any products.'; ru = 'Не удалось выполнить действие. Отпуск товаров не содержит номенклатуру.';pl = 'Nie można wykonać działania. Wydanie zewnętrzne nie może zawierać żadnych produktów.';es_ES = 'No se puede realizar la acción. La salida de mercancías no incluye ningún producto.';es_CO = 'No se puede realizar la acción. La salida de mercancías no incluye ningún producto.';tr = 'İşlem gerçekleştirilemiyor. Ambar çıkışı hiçbir ürün içermiyor.';it = 'Impossibile eseguire l''azione. La spedizione della merce non include nessun articolo.';de = 'Fehler beim Erfüllen der Aktion. Der Warenausgang enthält keine Produkte.'");
			Raise MessageToUser;
		EndIf;
	
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
	|	GoodsIssue.OperationType AS OperationType,
	|	GoodsIssue.VATTaxation AS VATTaxation,
	|	GoodsIssue.DocumentCurrency AS DocumentCurrency,
	|	GoodsIssue.ExchangeRate AS ExchangeRate,
	|	GoodsIssue.Multiplicity AS Multiplicity,
	|	GoodsIssue.AmountIncludesVAT AS AmountIncludesVAT
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
	|	GoodsIssueHeader.OperationType AS OperationType,
	|	GoodsIssueProducts.VATRate AS VATRate,
	|	ISNULL(GoodsIssueProducts.VATAmount, 0) AS VATAmount,
	|	GoodsIssueHeader.DocumentCurrency AS DocumentCurrency,
	|	GoodsIssueHeader.ExchangeRate AS ExchangeRate,
	|	GoodsIssueHeader.Multiplicity AS Multiplicity,
	|	GoodsIssueHeader.VATTaxation AS VATTaxation,
	|	GoodsIssueHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	GoodsIssueProducts.SupplierInvoice AS SupplierInvoice
	|INTO GIFiltred
	|FROM
	|	GoodsIssueHeader AS GoodsIssueHeader
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.BasisRef = GoodsIssueProducts.Ref
	|WHERE
	|	(GoodsIssueProducts.Contract = &Contract
	|			OR &Contract = VALUE(Catalog.CounterpartyContracts.EmptyRef))
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
	|	GIFiltred.DocumentCurrency AS DocumentCurrency,
	|	GIFiltred.VATTaxation AS VATTaxation,
	|	GIFiltred.AmountIncludesVAT AS AmountIncludesVAT,
	|	GIFiltred.ExchangeRate AS ExchangeRate,
	|	GIFiltred.Multiplicity AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	GIFiltred.OperationType AS OperationType,
	|	GIFiltred.VATRate AS VATRate,
	|	GIFiltred.VATAmount AS VATAmount,
	|	GIFiltred.SupplierInvoice AS BasisDocument
	|FROM
	|	GIFiltred AS GIFiltred
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON GIFiltred.Contract = Contracts.Ref
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
		VATAmount = VATAmount + TableRow.VATAmount;
	EndDo;
	
	If ResultTable.Count() > 0 Then
		TableRow = ResultTable[0];
		FillPropertyValues(ThisObject, TableRow, , "VATAmount");
	EndIf;
	
	OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn;	
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	FilterData = New Structure("GoodsIssuesArray, Contract", GoodsIssuesArray, Contract);
	
	Documents.DebitNote.FillByGoodsIssues(DocumentData, FilterData, Inventory);
	
	AdjustedAmount = Inventory.Total("Total");
	BasisTable = GetBasisTable();
	BasisDocumentInTabularSection = False;
	
	If BasisTable.Count() > 1 Then
		BasisDocumentInTabularSection = True;
		BasisDocument = Undefined;
	ElsIf Not ValueIsFilled(BasisDocument) Then
		If BasisTable.Count() > 0 Then
			BasisDocument = BasisTable[0].SupplierInvoice;
		EndIf;
	EndIf;
	
	If Inventory.Count() = 0 Then
		If GoodsIssuesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 has already been invoiced.'; ru = 'Для %1 уже зарегистрирован инвойс.';pl = '%1 został już zafakturowany.';es_ES = '%1 ha sido facturado ya.';es_CO = '%1 ha sido facturado ya.';tr = '%1 zaten faturalandırıldı.';it = '%1 è stato già fatturato.';de = '%1 wurde bereits in Rechnung gestellt.'"),
				GoodsIssue);
		Else
			MessageText = NStr("en = 'The selected goods issues have already been invoiced.'; ru = 'Выбранные документы ""Отпуск товаров"" уже отражены в учете.';pl = 'Wybrane wydana zewnętrzne zostały już zafakturowane.';es_ES = 'Las salidas de mercancías seleccionadas han sido facturadas ya.';es_CO = 'Las expediciones de los productos seleccionados han sido facturadas ya.';tr = 'Seçilen Ambar çıkışları zaten faturalandırıldı.';it = 'Le spedizioni merci selezionate sono già state fatturate.';de = 'Die ausgewählten Warenausgänge wurden bereits fakturiert.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillByCreditNote(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		FillPropertyValues(ThisObject, FillingData);
		
		If Not FillingData.HaveSalesOrders Or Not FillingData.HaveSupplierInvoices Then
			FillByCreditNoteWithoutSupplierInvoices(FillingData);
			Return;
		EndIf;
		
		SupplierInvoices = FillingData.SupplierInvoices;
		
	Else
		
		FillingDataAttributes = Common.ObjectAttributesValues(FillingData, "Posted, OperationKind, Company");
		Documents.DebitNote.CheckAbilityOfEnteringByCreditNote(FillingData,
			FillingDataAttributes.Posted,
			FillingDataAttributes.OperationKind,
			FillingDataAttributes.Company);
		
		If Documents.DebitNote.EverythingFromCreditNoteIsAlreadyReturned(FillingData, Ref) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'For ""%1"", the return of all drop shipping products has already been recorded.'; ru = 'Для ""%1"" уже зарегистрирован возврат всех товаров для дропшиппинга.';pl = 'Dla ""%1"", zwrot wszystkich produktów dropshipping już zostały zapisane.';es_ES = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';es_CO = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';tr = '""%1"" için tüm stoksuz satış ürünlerinin iadesi zaten kaydedildi.';it = 'Per ""%1"", è stato registrato il ritorno di tutti i prodotti di dropshipping.';de = 'Für ""%1"", ist die Rückgabe von alle Produkten aus dem Streckengeschäft bereits gebucht.'"),
					FillingData);
			CommonClientServer.MessageToUser(MessageText, FillingData);
			Return;
		EndIf;
		
		FilterData = New Structure;
		FilterData.Insert("Counterparty", Counterparty);
		FilterData.Insert("Contract", Contract);
		
		CurrentSupplierInvoices = New Array;
		If Not Ref.IsEmpty() Then
			RefIsPosted = Common.ObjectAttributeValue(Ref, "Posted");
			If RefIsPosted And Ref.Inventory.Count() Then
				CurrentSupplierInvoices = Ref.Inventory.UnloadColumn("SupplierInvoice");
			EndIf;
		EndIf;
		Result = Documents.DebitNote.DropShippingSupplierInvoicesToReturn(FillingData, FilterData, CurrentSupplierInvoices);
		
		If Not Result.HaveSalesOrders Or Not Result.HaveSupplierInvoices Then
			FillByCreditNoteWithoutSupplierInvoices(Result);
			Return;
		EndIf;
		
		SupplierInvoices = Result.SupplierInvoicesMap.Get(Contract);
		
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	VALUE(Enum.OperationTypesDebitNote.DropShipping) AS OperationKind,
	|	TRUE AS BasisDocumentInTabularSection,
	|	CreditNote.Company AS Company,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	ISNULL(CreditNote.DocumentCurrency, Contracts.SettlementsCurrency) AS DocumentCurrency,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	DC_Rates.Rate AS ExchangeRate,
	|	DC_Rates.Repetition AS Multiplicity,
	|	CC_Rates.Rate AS ContractCurrencyExchangeRate,
	|	CC_Rates.Repetition AS ContractCurrencyMultiplicity,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.VATRate AS VATRate,
	|	CreditNote.VATAmount AS VATAmount
	|FROM
	|	Document.CreditNote AS CreditNote
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (Contracts.Ref = &Contract)
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS DC_Rates
	|		ON (ISNULL(CreditNote.DocumentCurrency, Contracts.SettlementsCurrency) = DC_Rates.Currency)
	|			AND CreditNote.Company = DC_Rates.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&DocumentDate, ) AS CC_Rates
	|		ON (Contracts.SettlementsCurrency = CC_Rates.Currency)
	|			AND CreditNote.Company = CC_Rates.Company
	|WHERE
	|	CreditNote.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	SUM(CreditNoteInventory.Quantity) AS Quantity,
	|	MAX(CreditNoteInventory.LineNumber) AS LineNumber
	|INTO TT_CreditNoteInventory
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|WHERE
	|	CreditNoteInventory.DropShipping
	|	AND CreditNoteInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Quantity - SUM(ISNULL(DebitNoteInventory.Quantity, 0)) AS Quantity,
	|	CreditNoteInventory.LineNumber AS LineNumber
	|FROM
	|	TT_CreditNoteInventory AS CreditNoteInventory
	|		LEFT JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON (DebitNoteInventory.Ref.BasisDocument = &BasisDocument)
	|			AND CreditNoteInventory.Products = DebitNoteInventory.Products
	|			AND CreditNoteInventory.Characteristic = DebitNoteInventory.Characteristic
	|			AND CreditNoteInventory.Batch = DebitNoteInventory.Batch
	|			AND DebitNoteInventory.Ref <> &Ref
	|
	|GROUP BY
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.Batch,
	|	CreditNoteInventory.Quantity,
	|	CreditNoteInventory.LineNumber
	|
	|ORDER BY
	|	CreditNoteInventory.LineNumber";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("UseBatches", Constants.UseBatches.Get());
	
	QueryResult = Query.ExecuteBatch();
	
	Selection = QueryResult[0].Select();
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Date", CurrentSessionDate());
	DocumentData.Insert("PriceKind", PriceKind);
	DocumentData.Insert("DocumentCurrency", DocumentCurrency);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("AmountIncludesVAT", AmountIncludesVAT);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	FilterData = New Structure("SupplierInvoicesArray, Contract", SupplierInvoices, Contract);
	
	Documents.DebitNote.FillBySupplierInvoices(DocumentData, FilterData, Inventory);
	
	If Inventory.Count() Then
		
		CopyInventory = Inventory.Unload();
		Inventory.Clear();
		
		SortedInventory = Inventory.UnloadColumns();
		SortedInventory.Columns.Add("PointInTime", New TypeDescription("PointInTime"));
		
		ProductSelection = QueryResult[2].Select();
		While ProductSelection.Next() Do
			
			SortedInventory.Clear();
			QuantityToReturn = ProductSelection.Quantity;
			
			If QuantityToReturn <= 0 Then
				Continue;
			EndIf;
			
			RowFilter = New Structure;
			RowFilter.Insert("Products", ProductSelection.Products);
			RowFilter.Insert("Characteristic", ProductSelection.Characteristic);
			RowFilter.Insert("Batch", ProductSelection.Batch);
			
			ProductRows = CopyInventory.FindRows(RowFilter);
			For Each Row In ProductRows Do
				NewRow = SortedInventory.Add();
				FillPropertyValues(NewRow, Row);
				NewRow.PointInTime = NewRow.SupplierInvoice.PointInTime();
			EndDo;
			
			SortedInventory.Sort("PointInTime, LineNumber");
			
			For Each Row In SortedInventory Do
				If QuantityToReturn > 0 Then
					NewRow = Inventory.Add();
					FillPropertyValues(NewRow, Row);
					
					NewRow.Quantity = ?(QuantityToReturn < NewRow.Quantity, QuantityToReturn, NewRow.Quantity);
					NewRow.Amount = ?(NewRow.InitialQuantity = 0, 0, NewRow.InitialAmount / NewRow.InitialQuantity * NewRow.Quantity);
					
					Rate = DriveReUse.GetVATRateValue(NewRow.VATRate);
					If AmountIncludesVAT Then
						NewRow.VATAmount = NewRow.Amount - (NewRow.Amount) / ((Rate + 100) / 100);
					Else
						NewRow.VATAmount = NewRow.Amount * Rate / 100;
					EndIf;
					NewRow.Total = NewRow.Amount + ?(AmountIncludesVAT, 0, NewRow.VATAmount);
					
					QuantityToReturn = QuantityToReturn - NewRow.Quantity;
				Else
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
		AdjustedAmount = Inventory.Total("Total");
		VATAmount = Inventory.Total("VATAmount");
		DocumentTax = VATAmount;
		DocumentSubtotal = AdjustedAmount - VATAmount;
		
	EndIf;
	
	If Inventory.Count() = 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For ""%1"", the return of all drop shipping products has already been recorded.'; ru = 'Для ""%1"" уже зарегистрирован возврат всех товаров для дропшиппинга.';pl = 'Dla ""%1"", zwrot wszystkich produktów dropshipping już zostały zapisane.';es_ES = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';es_CO = 'En el caso de ""%1"", ya se ha registrado la devolución de todos los productos de envío directo.';tr = '""%1"" için tüm stoksuz satış ürünlerinin iadesi zaten kaydedildi.';it = 'Per ""%1"", è stato registrato il ritorno di tutti i prodotti di dropshipping.';de = 'Für ""%1"", ist die Rückgabe von alle Produkten aus dem Streckengeschäft bereits gebucht.'"),
			BasisDocument);
		Raise MessageText;
	EndIf;
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfGoodsIssues") Then
		FillByGoodsIssue(FillingData);
	EndIf;
	
	If FillingData.Property("ArrayOfSupplierInvoices") Then
		FillBySupplierInvoice(FillingData);
	EndIf;
	
	If FillingData.Property("IsDropShipping") Then
		FillByCreditNote(FillingData);
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
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsPayableBalances
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND &ContractTypesList
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayableBalanceAndTurnovers.Company,
	|	AccountsPayableBalanceAndTurnovers.Counterparty,
	|	AccountsPayableBalanceAndTurnovers.Contract,
	|	AccountsPayableBalanceAndTurnovers.Document,
	|	AccountsPayableBalanceAndTurnovers.Order,
	|	AccountsPayableBalanceAndTurnovers.SettlementsType,
	|	-AccountsPayableBalanceAndTurnovers.AmountCurTurnover
	|FROM
	|	AccumulationRegister.AccountsPayable.BalanceAndTurnovers(
	|			,
	|			&Period,
	|			Recorder,
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalanceAndTurnovers
	|WHERE
	|	AccountsPayableBalanceAndTurnovers.Recorder = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	CASE
	|		WHEN ISNULL(Counterparties.DoOperationsByOrders, FALSE)
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	AccountsPayableBalances.AmountCurBalance AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate
	|INTO AccountsPayableBalancesPrev
	|FROM
	|	AccountsPayableBalances AS AccountsPayableBalances
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsPayableBalances.Counterparty = Counterparties.Ref
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN &ContractCurrencyExchangeRate * &Multiplicity / (&ExchangeRate * &ContractCurrencyMultiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (&ContractCurrencyExchangeRate * &Multiplicity / (&ExchangeRate * &ContractCurrencyMultiplicity))
	|		END AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate
	|FROM
	|	AccountsPayableBalancesPrev AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.DocumentDate
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", 				ParentCompany);
	Query.SetParameter("Counterparty",			Counterparty);
	Query.SetParameter("Contract",				Contract);
	Query.SetParameter("Period", 				New Boundary(Date, BoundaryType.Excluding));
	Query.SetParameter("Ref", 					Ref);
	Query.SetParameter("ExchangeRateMethod",	DriveServer.GetExchangeMethod(ParentCompany));
	
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
	If OperationKind <> PredefinedValue("Enum.OperationTypesDebitNote.PurchaseReturn")
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

#EndRegion

#Region Private

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

Function GetBasisTable()
	
	BasisTable = Inventory.Unload(, "SupplierInvoice");
	BasisTable.GroupBy("SupplierInvoice");
	Return BasisTable;
	
EndFunction

Procedure FillByCreditNoteWithoutSupplierInvoices(FillingData)
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	VALUE(Enum.OperationTypesDebitNote.DropShipping) AS OperationKind,
	|	TRUE AS BasisDocumentInTabularSection,
	|	CreditNote.Company AS Company,
	|	CreditNote.CompanyVATNumber AS CompanyVATNumber,
	|	CreditNote.DocumentCurrency AS DocumentCurrency,
	|	CreditNote.AmountIncludesVAT AS AmountIncludesVAT,
	|	CreditNote.VATTaxation AS VATTaxation,
	|	CreditNote.VATRate AS VATRate
	|FROM
	|	Document.CreditNote AS CreditNote
	|WHERE
	|	CreditNote.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DebitNote.Ref AS Ref
	|INTO TT_Documents
	|FROM
	|	Document.DebitNote AS DebitNote
	|WHERE
	|	DebitNote.BasisDocument = &BasisDocument
	|	AND DebitNote.Posted
	|	AND DebitNote.Ref <> &DebitNoteRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Products AS Products,
	|	CASE
	|		WHEN &UseBatches
	|				AND (ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.Manual)
	|					OR ISNULL(BatchTrackingPolicies.TrackingMethod, VALUE(Enum.BatchTrackingMethods.EmptyRef)) = VALUE(Enum.BatchTrackingMethods.FEFO))
	|			THEN CreditNoteInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchForBalance,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN CreditNoteInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicForBalance
	|INTO InventoryForBalance
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON CreditNoteInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCategories AS ProductsCategories
	|		ON (CatalogProducts.ProductsCategory = ProductsCategories.Ref)
	|			AND (CatalogProducts.UseBatches)
	|		LEFT JOIN InformationRegister.BatchTrackingPolicy AS BatchTrackingPolicy
	|		ON (BatchTrackingPolicy.StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping))
	|			AND (ProductsCategories.BatchSettings = BatchTrackingPolicy.BatchSettings)
	|		LEFT JOIN Catalog.BatchTrackingPolicies AS BatchTrackingPolicies
	|		ON (BatchTrackingPolicy.Policy = BatchTrackingPolicies.Ref)
	|WHERE
	|	CreditNoteInventory.DropShipping
	|	AND CreditNoteInventory.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	InventoryTurnovers.Products AS Products,
	|	InventoryTurnovers.Characteristic AS Characteristic,
	|	InventoryTurnovers.QuantityTurnover AS QuantityTurnover
	|INTO TT_InventoryTurnovers
	|FROM
	|	AccumulationRegister.Inventory.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			StructuralUnit = VALUE(Catalog.BusinessUnits.DropShipping)
	|				AND (Products, Characteristic, Batch) IN
	|					(SELECT
	|						InventoryForBalance.Products,
	|						InventoryForBalance.CharacteristicForBalance,
	|						InventoryForBalance.BatchForBalance
	|					FROM
	|						InventoryForBalance AS InventoryForBalance)) AS InventoryTurnovers
	|WHERE
	|	InventoryTurnovers.Recorder IN
	|			(SELECT
	|				TT_Documents.Ref
	|			FROM
	|				TT_Documents AS TT_Documents)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CreditNoteInventory.Products AS Products,
	|	CreditNoteInventory.Characteristic AS Characteristic,
	|	CreditNoteInventory.Batch AS Batch,
	|	CreditNoteInventory.Quantity - SUM(ISNULL(InventoryTurnovers.QuantityTurnover, 0)) AS Quantity,
	|	CreditNoteInventory.InitialAmount AS InitialAmount,
	|	CreditNoteInventory.InitialQuantity AS InitialQuantity,
	|	CreditNoteInventory.MeasurementUnit AS MeasurementUnit,
	|	MAX(CreditNoteInventory.LineNumber) AS LineNumber
	|FROM
	|	Document.CreditNote.Inventory AS CreditNoteInventory
	|		LEFT JOIN TT_InventoryTurnovers AS InventoryTurnovers
	|		ON CreditNoteInventory.Products = InventoryTurnovers.Products
	|			AND CreditNoteInventory.Characteristic = InventoryTurnovers.Characteristic
	|WHERE
	|	CreditNoteInventory.DropShipping
	|	AND CreditNoteInventory.Ref = &BasisDocument
	|
	|GROUP BY
	|	CreditNoteInventory.Products,
	|	CreditNoteInventory.Characteristic,
	|	CreditNoteInventory.Batch,
	|	CreditNoteInventory.Quantity,
	|	CreditNoteInventory.InitialAmount,
	|	CreditNoteInventory.InitialQuantity,
	|	CreditNoteInventory.MeasurementUnit
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	Query.SetParameter("DebitNoteRef", Ref);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("UseCharacteristics", Constants.UseCharacteristics.Get());
	Query.SetParameter("UseBatches", Constants.UseBatches.Get());
	
	QueryResult = Query.ExecuteBatch();
	
	Selection = QueryResult[0].Select();
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	Inventory.Clear();
	
	InventorySelection = QueryResult[QueryResult.Count()-1].Select();
	While InventorySelection.Next() Do
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, InventorySelection,,"LineNumber");
	EndDo;
	
	If Not FillingData.HaveSalesOrders Then
		MessageText = NStr("en = 'Cannot find the Sales order and Supplier invoice for the products specified in the selected Credit note.
			|Supplier and product details will not be autofilled in the Debit note. Fill them in manually.'; 
			|ru = 'Не удалось найти заказ покупателя и инвойс поставщика для номенклатуры, указанной в выбранном кредитовом авизо.
			|Сведения о поставщике и номенклатуре не будут автоматически заполнены в дебетовом авизо. Заполните их вручную.';
			|pl = 'Nie można znaleźć Zamówienia sprzedaży i Faktury zakupu dla produktów, określonych w wybranej Nocie kredytowej.
			|Dane o dostawcy i produkcie nie będą automatycznie wypełnione w Nocie debetowej. Wypełnij je ręcznie.';
			|es_ES = 'No se puede encontrar la Orden de venta y la Factura del proveedor para los productos especificados en la Nota de crédito seleccionada.
			|Los detalles del proveedor y el producto no se rellenarán automáticamente en la Nota de débito. Rellénelos manualmente.';
			|es_CO = 'No se puede encontrar la Orden de venta y la Factura del proveedor para los productos especificados en la Nota de crédito seleccionada.
			|Los detalles del proveedor y el producto no se rellenarán automáticamente en la Nota de débito. Rellénelos manualmente.';
			|tr = 'Seçilen Alacak dekontunda belirtilen ürünler için Satış siparişi ve Satın alma faturası bulunamadı.
			|Tedarikçi ve ürün bilgileri Borç dekontunda otomatik olarak doldurulmayacak. Bu bilgileri manuel olarak doldurun.';
			|it = 'Impossibile trovare l''Ordine cliente e la Fattura di acquisto per gli articoli indicati nella nota di Credito selezionata.
			|Il fornitore e i dettagli dell''articolo non saranno compilati automaticamente nella nota di Debito. Sarà necessario compilarli manualmente.';
			|de = 'Fehler beim Finden des Kundenauftrags und der Lieferantenrechnung für die in der ausgewählten Gutschrift angegebenen Produkte.
			|In der Lastschrift werden die Details über den Lieferanten und das Produkt nicht automatisch aufgefüllt. Füllen Sie diese manuell auf.'");
		CommonClientServer.MessageToUser(MessageText, ThisObject);
	EndIf;
	
	If Not FillingData.HaveSupplierInvoices Then
		MessageText = NStr("en = 'Cannot find the Supplier invoice for the products specified in the selected Credit note.
			|Supplier and product details will not be autofilled in the Debit note. Fill them in manually.'; 
			|ru = 'Не удалось найти инвойс поставщика для номенклатуры, указанной в выбранном кредитовом авизо.
			|Сведения о поставщике и номенклатуре не будут автоматически заполнены в дебетовом авизо. Заполните их вручную.';
			|pl = 'Nie można znaleźć Faktury zakupu dla produktów, określonych w wybranej Nocie kredytowej.
			|Dane o dostawcy i produkcie nie będą automatycznie wypełnione w Nocie debetowej. Wypełnij je ręcznie.';
			|es_ES = 'No se puede encontrar la Factura del proveedor para los productos especificados en la Nota de crédito seleccionada.
			|Los detalles del proveedor y el producto no se rellenarán automáticamente en la Nota de débito. Rellénelos manualmente.';
			|es_CO = 'No se puede encontrar la Factura del proveedor para los productos especificados en la Nota de crédito seleccionada.
			|Los detalles del proveedor y el producto no se rellenarán automáticamente en la Nota de débito. Rellénelos manualmente.';
			|tr = 'Seçilen Alacak dekontunda belirtilen ürünler için Satın alma faturası bulunamadı.
			|Tedarikçi ve ürün bilgileri Borç dekontunda otomatik olarak doldurulmayacak. Bu bilgileri manuel olarak doldurun.';
			|it = 'Impossibile trovare la Fattura di acquisto per gli articoli indicati nella nota di Credito selezionata.
			|Il fornitore e i dettagli dell''articolo non saranno compilati automaticamente nella nota di Debito. Sarà necessario compilarli manualmente.';
			|de = 'Fehler beim Finden der Lieferantenrechnung für die in der ausgewählten Gutschrift angegebenen Produkte.
			|In der Lastschrift werden die Details über den Lieferanten und das Produkt nicht automatisch aufgefüllt. Füllen Sie diese manuell auf.'");
		CommonClientServer.MessageToUser(MessageText, ThisObject);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
