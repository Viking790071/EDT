#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Services_methods

// Fill in empty dates with dates
// from accounting documents for the CounterpartyData tabular section
Procedure FillEmptyDatesForCounterpartyAtServer(CounterpartyData) Export
	
	If Not ValueIsFilled(CounterpartyData) Then
		Return;
	EndIf;
	
EndProcedure

// Sets status for documents array
//
// Parameters:
// DocumentArray - Array(DocumentRef.ReconciliationStatement) 	  - Array of documents for
// status setting StatusValue  - EnumRef.ReconciliationStatementStatus - Set status
//
// Return value: Boolean - Function execution result
//
Function SetStatus(DocumentArray, StatusValue) Export

	Query = New Query("
		|SELECT ALLOWED
		|	Table.Ref AS Ref
		|FROM
		|	Document.ReconciliationStatement AS Table
		|WHERE
		|	Table.Status <> &Status
		|	AND Table.Ref IN(&DocumentArray)
		|	AND Not Table.DeletionMark
		|");
	Query.SetParameter("DocumentArray", DocumentArray);
	Query.SetParameter("Status", StatusValue);
	Selection = Query.Execute().Select();

	NumberOfProcessed = 0;

	BeginTransaction();
	
	While Selection.Next() Do

		Try
			LockDataForEdit(Selection.Ref);
		Except
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;

			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t lock %1. %2'; ru = 'Не удалось заблокировать %1. %2';pl = 'Nie udało się zablokować %1. %2';es_ES = 'No se ha podido bloquear %1. %2';es_CO = 'No se ha podido bloquear %1. %2';tr = '%1 kilitlenemedi. %2';it = 'Impossibile bloccare %1. %2';de = 'Fehler beim Sperren von %1. %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			Raise ErrorText;

		EndTry;

		DocObject 			= Selection.Ref.GetObject();
		DocObject.Status 	= StatusValue;
		
		Try
		
			DocObject.Write(DocumentWriteMode.Write);
			NumberOfProcessed = NumberOfProcessed + 1;
			
		Except
			
			If TransactionActive() Then
				RollbackTransaction();
			EndIf;
		
			ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Couldn''t save %1. %2'; ru = 'Не удалось записать %1. %2';pl = 'Nie udało się zapisać %1. %2';es_ES = 'No se ha podido guardar %1.%2';es_CO = 'No se ha podido guardar %1.%2';tr = '%1 saklanamadı. %2';it = 'Impossibile salvare %1. %2';de = 'Fehler beim Speichern von %1. %2'"),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			Raise ErrorText;

		EndTry;

	EndDo;

	Try
	
		CommitTransaction();
	
	Except
		
		If TransactionActive() Then
			RollbackTransaction();
		EndIf;
	
	EndTry;
	

	Return NumberOfProcessed;

EndFunction

#EndRegion

#Region description_and_Presentation_details

// Procedure processes query data and fills in document string (strings)
//
// Parameters:
//	DataSelectionFromQuery - query data for transfer to
//	the DocumentDataStructure tabular section - data structure from reconciliation document according to which query is generated
//
//	DocumentCurrentStringFieldsStructure - structure of the ReconciliationStatements
//											current string fields If the RemainingsInput document is selected, you can add strings
//
Function GetCompanyRowData(DocumentData, Selection) Export
	
	RowData = New Structure;
	
	RowData.Insert("DocumentNumber", 		Selection.DocumentNumber);
	RowData.Insert("DocumentDate",			Selection.Period);
	RowData.Insert("Contract", 				Selection.Contract);
	RowData.Insert("AccountingDocument", 	Selection.AccountingDocument);
	
	DocumentDescription = CompanyAccountingDocumentDescription(Selection.AccountingDocument, "", Undefined);
	RowData.Insert("DocumentDescription", DocumentDescription);
	
	Amount = 0;
	If Selection.AmountCurTurnover > 0 Then 
		
		Amount = Selection.AmountCurTurnover; 
		StructureKey = "ClientDebtAmount";
		
	Else
		
		Amount = -Selection.AmountCurTurnover; 
		StructureKey = "CompanyDebtAmount";
		
	EndIf;
	
	RowData.Insert(StructureKey, Amount);
	
	Return RowData;
	
EndFunction

// Returns documents listing with their synonyms for the Reconciliation statement 
//
Function GetDocumentPresentationsForCounterparties()
	
	DocumentTypesCounterparty = New Structure;
	
	DocumentTypesCounterparty.Insert("ExpenseReport",				NStr("en = 'Cash receipt #%1, %2.'; ru = 'Приходный кассовый ордер № %1, %2.';pl = 'Kasa przyjmie nr %1, %2.';es_ES = 'Recibo de caja #%1, %2.';es_CO = 'Recibo de caja #%1, %2.';tr = 'Nakit tahsilat #%1, %2.';it = 'Entrata di cassa #%1, %2.';de = 'Zahlungseingang Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("ArApAdjustments",				NStr("en = 'AR/AP adjustment #%1, %2.'; ru = 'Корректировка долга № %1, %2.';pl = 'Korekta Wn/Ma nr %1, %2.';es_ES = 'Ajuste AR/AP #%1, %2.';es_CO = 'Ajuste AR/AP #%1, %2.';tr = 'Alacak/Borç hesapları düzeltmesi #%1, %2.';it = 'Assestamento Crediti/Debiti #%1, %2.';de = 'Anpassung von OPK/OPD Nr. %1, %2.'"));
	DocumentTypesCounterparty.Insert("SalesOrder",					NStr("en = 'Purchase order #%1, %2.'; ru = 'Заказ поставщику № %1, %2.';pl = 'Zamówienie zakupu nr %1, %2.';es_ES = 'Pedido de compra #%1, %2.';es_CO = 'Pedido de compra #%1, %2.';tr = 'Satın alma siparişi #%1, %2.';it = 'Ordine di acquisto #%1, %2.';de = 'Bestellung an Lieferanten Nr. %1, %2.'"));
	DocumentTypesCounterparty.Insert("PurchaseOrder",				NStr("en = 'Sales order #%1, %2.'; ru = 'Заказ покупателя № %1, %2.';pl = 'Zamówienie sprzedaży nr %1, %2.';es_ES = 'Orden de venta #%1, %2.';es_CO = 'Orden de venta #%1, %2.';tr = 'Satış siparişi #%1, %2.';it = 'Ordine cliente #%1, %2.';de = 'Kundenauftrag Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("RegistersCorrection",			NStr("en = 'AR/AP adjustment #%1, %2.'; ru = 'Корректировка долга № %1, %2.';pl = 'Korekta Wn/Ma nr %1, %2.';es_ES = 'Ajuste AR/AP #%1, %2.';es_CO = 'Ajuste AR/AP #%1, %2.';tr = 'Alacak/Borç hesapları düzeltmesi #%1, %2.';it = 'Assestamento Crediti/Debiti #%1, %2.';de = 'Anpassung von OPK/OPD Nr. %1, %2.'"));
	DocumentTypesCounterparty.Insert("AccountSalesFromConsignee",	NStr("en = 'Account sales to consignor #%1, %2.'; ru = 'Отчет комитенту № %1, %2.';pl = 'Raport sprzedaży komitentowi nr %1, %2.';es_ES = 'Ventas de cuenta al consignador %1, %2.';es_CO = 'Ventas de cuenta al consignador %1, %2.';tr = 'Konsinye alışlar #%1, %2.';it = 'Saldo delle vendite per il committente #%1, %2.';de = 'Verkaufsbericht (Kommittent) Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("AccountSalesToConsignor",		NStr("en = 'Account sales from consignee #%1, %2.'; ru = 'Отчет комиссионера № %1, %2.';pl = 'Raport sprzedaży od komisanta nr %1, %2.';es_ES = 'Ventas de cuenta del destinatario #%1, %2.';es_CO = 'Ventas de cuenta del destinatario #%1, %2.';tr = 'Konsinye satışlar #%1, %2.';it = 'Saldo delle vendite dall''agente in conto vendita #%1, %2.';de = 'Verkaufsbericht (Kommissionär) Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("PaymentReceipt",				NStr("en = 'Bank payment #%1, %2.'; ru = 'Списание со счета № %1, %2.';pl = 'Cash receipt nr %1, %2.';es_ES = 'Pago bancario #%1, %2.';es_CO = 'Pago bancario #%1, %2.';tr = 'Banka ödemesi #%1, %2.';it = 'Bonifico bancario #%1, %2.';de = 'Überweisung Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("CashReceipt",					NStr("en = 'Cash voucher #%1, %2.'; ru = 'Расходный кассовый ордер № %1, %2.';pl = 'Dowód kasowy KW nr %1, %2.';es_ES = 'Bono de pago en efectivo #%1, %2.';es_CO = 'Bono de pago en efectivo #%1, %2.';tr = 'Nakit ödeme #%1, %2.';it = 'Uscita di cassa #%1, %2.';de = 'Kassenbeleg Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("PaymentExpense",				NStr("en = 'Bank receipt #%1, %2.'; ru = 'Поступление на счет № %1, %2.';pl = 'Potwierdzenie zapłaty nr %1, %2.';es_ES = 'Recibo bancario #%1, %2.';es_CO = 'Recibo bancario #%1, %2.';tr = 'Banka tahsilatı #%1, %2.';it = 'Ricevuta bancario #%1, %2.';de = 'Eingang Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("CashVoucher",					NStr("en = 'Cash receipt #%1, %2.'; ru = 'Приходный кассовый ордер № %1, %2.';pl = 'Kasa przyjmie nr %1, %2.';es_ES = 'Recibo de caja #%1, %2.';es_CO = 'Recibo de caja #%1, %2.';tr = 'Nakit tahsilat #%1, %2.';it = 'Entrata di cassa #%1, %2.';de = 'Zahlungseingang Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("SupplierInvoice",				NStr("en = 'Sales invoice #%1, %2.'; ru = 'Инвойс покупателю № %1, %2.';pl = 'Faktura sprzedaży nr %1, %2.';es_ES = 'Factura de ventas #%1, %2.';es_CO = 'Factura de ventas #%1, %2.';tr = 'Satış faturası #%1, %2.';it = 'Fattura di vendita #%1, %2.';de = 'Verkaufsrechnung Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("SalesInvoice",				NStr("en = 'Supplier invoice #%1, %2.'; ru = 'Инвойс поставщика № %1, %2.';pl = 'Faktura zakupu nr %1, %2.';es_ES = 'Factura del proveedor #%1, %2.';es_CO = 'Factura del proveedor #%1, %2.';tr = 'Satın alma faturası #%1, %2.';it = 'Fattura di acquisto #%1, %2.';de = 'Lieferantenrechnung Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("CreditNote",					NStr("en = 'Debit note #%1, %2.'; ru = 'Дебетовое авизо № %1, %2.';pl = 'Nota debetowa nr %1, %2.';es_ES = 'Nota de debito #%1, %2.';es_CO = 'Nota de debito #%1, %2.';tr = 'Borç dekontu #%1, %2.';it = 'Nota di debito #%1, %2.';de = 'Lastschrift Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("DebitNote",					NStr("en = 'Credit note #%1, %2.'; ru = 'Кредитовое авизо № %1, %2.';pl = 'Nota kredytowa nr %1, %2.';es_ES = 'Nota de crédito #%1, %2.';es_CO = 'Nota de crédito #%1, %2.';tr = 'Alacak dekontu #%1, %2.';it = 'Nota di credito #%1, %2.';de = 'Gutschrift Nr.%1, %2.'"));
	DocumentTypesCounterparty.Insert("AdditionalExpenses",			NStr("en = 'Sales invoice #%1, %2.'; ru = 'Инвойс покупателю № %1, %2.';pl = 'Faktura sprzedaży nr %1, %2.';es_ES = 'Factura de ventas #%1, %2.';es_CO = 'Factura de ventas #%1, %2.';tr = 'Satış faturası #%1, %2.';it = 'Fattura di vendita #%1, %2.';de = 'Verkaufsrechnung Nr.%1, %2.'"));
	
	Return DocumentTypesCounterparty;
	
EndFunction

// Receives an incoming number by
// the counterparty document if it is not possible to receive number, it returns an empty string
Function GetIncNumber(DocumentRef, DecryptionJSC = Undefined) Export
	
	IncomingDocumentNumber = "";
	If Not ValueIsFilled(DocumentRef) Then 
		
		Return IncomingDocumentNumber;
		
	EndIf;
	
	// Possible accounting documents list in description
	If TypeOf(DocumentRef) = Type("DocumentRef.ExpenseReport") 
		AND TypeOf(DecryptionJSC) = Type("Structure") Then
		
		Query = New Query;
		Query.SetParameter("Contract", DecryptionJSC.Contract);
		Query.SetParameter("PaymentAmount", DecryptionJSC.PaymentAmount);
		Query.Text = "SELECT ALLOWED AO.IncomingDocumentNumber FROM Document.ExpenseReport.Payments AS AO WHERE AO.AdvanceFlag AND AO.Contract = &Contract AND AO.PaymentAmount = &PaymentAmount";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			IncomingDocumentNumber = Selection.IncomingDocumentNumber;
			
		EndIf;
		
	ElsIf DriveServer.IsDocumentAttribute("IncomingDocumentNumber", DocumentRef.Metadata()) Then
		
		IncomingDocumentNumber = DocumentRef.IncomingDocumentNumber;
		
	EndIf;
	
	Return IncomingDocumentNumber;
	
EndFunction

// Receives an incoming date
// by the counterparty document if it is not possible to receive date, it returns an empty date
Function GetIncDate(DocumentRef, DecryptionJSC = Undefined) Export
	
	IncomingDocumentDate = Date(01, 01, 01);
	If Not ValueIsFilled(DocumentRef) Then 
		
		Return IncomingDocumentDate;
		
	EndIf;
	
	// List of possible accounting documents in the description to the GetLoginNumber() function
	If TypeOf(DocumentRef) = Type("DocumentRef.ExpenseReport") 
		AND TypeOf(DecryptionJSC) = Type("Structure") Then
		
		Query = New Query;
		Query.SetParameter("Contract", DecryptionJSC.Contract);
		Query.SetParameter("PaymentAmount", DecryptionJSC.PaymentAmount);
		Query.Text = "SELECT ALLOWED AO.IncomingDocumentDate FROM Document.ExpenseReport.Payments AS AO WHERE AO.AdvanceFlag AND AO.Contract = &Contract AND AO.PaymentAmount = &PaymentAmount";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			
			IncomingDocumentDate = Selection.IncomingDocumentDate;
			
		EndIf;
		
	ElsIf DriveServer.IsDocumentAttribute("IncomingDocumentDate", DocumentRef.Metadata()) Then
		
		IncomingDocumentDate = DocumentRef.IncomingDocumentDate;
		
	EndIf;
	
	Return IncomingDocumentDate;
	
EndFunction

// Returns accouning document presentation for the Reconciliation statement 
//
// Parameters:
//    DocumentRef 	- DocumentRef 	- Ref to accounting document;
//    Number		- String		- Accounting document
//    number Date	- Date			- Payment document date
//
// Return value: String.
//
Function CompanyAccountingDocumentDescription(DocumentRef, DocumentNumber = "" , Val DocumentDate) Export
	
	If DocumentRef = Undefined Then
		
		DescriptionString =  NStr("en = 'Settlement document #%1 dated %2'; ru = 'Расчетный документ №%1 от %2 г.';pl = 'Dokument rozliczeń nr %1 z dn. %2';es_ES = 'Documento de liquidaciones #%1 fechado %2';es_CO = 'Documento de liquidaciones #%1 fechado %2';tr = '%1 no.''lu %2 tarihli uzlaşma belgesi';it = 'Documento di pagamento №  %1 con data %2';de = 'Abrechnungsbeleg Nr %1 datiert %2'");
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString(DescriptionString, 
			?(IsBlankString(DocumentNumber), NStr("en = '_______'; ru = '_______';pl = '_______';es_ES = '_______';es_CO = '_______';tr = '_______';it = '_______';de = '_______'"), ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True)), 
			?(ValueIsFilled(DocumentDate), Format(DocumentDate, "DLF=D"), NStr("en = '___.___.________'; ru = '___.___.________';pl = '___.___.________';es_ES = '___.___.________';es_CO = '___.___.________';tr = '___.___.________';it = '___.___.________';de = '___.___.________'"))
			);
		
		Return DescriptionString;
		
	EndIf;
	
	// Document description
	DocumentDescription = "";
	
	If TypeOf(DocumentRef) = Type("DocumentRef.GoodsReceipt") Then
		OperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
		If OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
			DocumentDescription = NStr("en = '%1 (return from customer) #%2, %3.'; ru = '%1 (возврат от покупателя) № %2, %3.';pl = '%1 (zwrot od nabywcy) nr %2, %3.';es_ES = '%1 (devolución del cliente) #%2, %3.';es_CO = '%1 (devolución del cliente) #%2, %3.';tr = '%1 (müşteriden iade) #%2, %3.';it = '%1 (restituzione da cliente) #%2, %3.';de = '%1 (Rückgabe vom Kunden) Nr. %2, %3.'")
		EndIf;
	ElsIf TypeOf(DocumentRef) = Type("DocumentRef.GoodsIssue") Then
		OperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
		If OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
			DocumentDescription = NStr("en = '%1 (return to vendor) #%2, %3.'; ru = '%1 (возврат поставщику) № %2, %3.';pl = '%1 (Zwrot do sprzedawcy) nr %2, %3.';es_ES = '%1 (devolución al proveedor) #%2, %3.';es_CO = '%1 (devolución al proveedor) #%2, %3.';tr = '%1 (satıcıya iade) #%2, %3.';it = '%1 (restituzione a venditore) #%2, %3.';de = '%1 (Rückgabe vom Verkäufer) Nr. %2, %3.'")
		EndIf;
	EndIf;
	
	If IsBlankString(DocumentDescription) Then
		DocumentDescription = NStr("en = '%1 #%2, %3.'; ru = '%1 #%2, %3.';pl = '%1 #%2, %3.';es_ES = '%1 #%2, %3.';es_CO = '%1 #%2, %3.';tr = '%1 #%2, %3.';it = '%1 #%2, %3.';de = '%1 #%2, %3.'");
	EndIf;
	
	// Document No.
	If IsBlankString(DocumentNumber) Then
		
		DocumentNumber = DocumentRef.Number;
		
	EndIf;
	DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True);
	
	// Document date
	If Not ValueIsFilled(DocumentDate) Then
		
		DocumentDate = DocumentRef.Date;
		
	EndIf;
	DocumentDate = Format(DocumentDate, "DLF=D");
	
	DocumentDescription = StringFunctionsClientServer.SubstituteParametersToString(DocumentDescription,
		String(TypeOf(DocumentRef)),
		DocumentNumber, 
		DocumentDate);
	
	Return DocumentDescription;
	
EndFunction

// Returns accouning document presentation for the Reconciliation statement 
//
// Parameters:
//    DocumentRef 		- DocumentRef 	- Ref to accounting document;
//    Number			- String		- Accounting document
//    number Date		- Date			- Payment document date
//
// Return value: String.
//
Function CounterpartyAccountingDocumentDescription(DocumentRef, Val DocumentNumber, Val DocumentDate) Export
	
	// Process number and date immediately as it is needed for an empty ref
	DocumentNumber	= ?(IsBlankString(DocumentNumber), "_______", ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, False, True));
	DocumentDate	= ?(ValueIsFilled(DocumentDate), Format(DocumentDate, "DLF=D"), "___.___._______");
	
	If DocumentRef = Undefined Then
		
		DescriptionString = NStr("en = 'Settlement document #%1 dated %2'; ru = 'Расчетный документ №%1 от %2 г.';pl = 'Dokument rozliczeń nr %1 z dn. %2';es_ES = 'Documento de liquidaciones #%1 fechado %2';es_CO = 'Documento de liquidaciones #%1 fechado %2';tr = '%1 no.''lu %2 tarihli uzlaşma belgesi';it = 'Documento di pagamento №  %1 con data %2';de = 'Abrechnungsbeleg Nr %1 datiert %2'");
		DescriptionString = StringFunctionsClientServer.SubstituteParametersToString(DescriptionString, DocumentNumber, DocumentDate);
		
		Return DescriptionString;
		
	EndIf;
	
	// Document description
	DocumentDescription = "";
	CounterpartyDocumentsPresentation = GetDocumentPresentationsForCounterparties();
	CounterpartyDocumentsPresentation.Property(DocumentRef.Metadata().Name, DocumentDescription);
	
	If IsBlankString(DocumentDescription) Then
		If TypeOf(DocumentRef) = Type("DocumentRef.GoodsReceipt") Then
			OperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
			If OperationKind = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
				DocumentDescription =  NStr("en = 'Payment document (return to supplier) #%1, %2.'; ru = 'Документ оплаты (возврат поставщику) № %1, %2.';pl = 'Dokument płatności (zwrot do dostawcy) nr %1, %2.';es_ES = 'Documento de pago (devolución al proveedor) #%1, %2.';es_CO = 'Documento de pago (devolución al proveedor) #%1, %2.';tr = 'Ödeme belgesi (tedarikçiye iade) #%1, %2.';it = 'Documento di pagamento (restituzione a fornitore) #%1, %2.';de = 'Zahlungsbeleg (Rückgabe an Lieferanten) Nr.%1, %2.'");
			EndIf;
		ElsIf TypeOf(DocumentRef) = Type("DocumentRef.GoodsIssue") Then
			OperationKind = Common.ObjectAttributeValue(DocumentRef, "OperationKind");
			If OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
				DocumentDescription =  NStr("en = 'Payment document (return from customer) #%1, %2.'; ru = 'Документ оплаты (возврат от покупателя) № %1, %2.';pl = 'Dokument płatności (zwrot od nabywcy) nr %1, %2.';es_ES = 'Documento de pago (devolución del cliente) #%1, %2.';es_CO = 'Documento de pago (devolución del cliente) #%1, %2.';tr = 'Ödeme belgesi (müşteriden iade) #%1, %2.';it = 'Documento di pagamento (restituzione da cliente) #%1, %2.';de = 'Zahlungsbeleg (Rückgabe von Kunden) Nr.%1, %2.'");
			EndIf;
		EndIf;
	EndIf;
	
	If IsBlankString(DocumentDescription) Then
		DocumentDescription = NStr("en = 'Payment document #%1, %2.'; ru = 'Документ оплаты № %1, %2.';pl = 'Dokument płatności nr %1, %2.';es_ES = 'Documento de pago #%1, %2.';es_CO = 'Documento de pago #%1, %2.';tr = 'Ödeme belgesi #%1, %2.';it = 'Documento di pagamento #%1, %2.';de = 'Zahlungsbeleg Nr.%1, %2.'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(DocumentDescription, DocumentNumber, DocumentDate);
	
EndFunction

#EndRegion

#Region Filling_CWT

// Procedure fills in tabular section "Company data".
//
// Parameters:
// DocumentData	 - Structure					- Reconciliation statement data;
// TabularSection	 - Document tabular section	- Tabular section for filling.
//
Procedure FillDataByCompany(DocumentData, TabularSection) Export
	
	SetPrivilegedMode(True);
	
	TabularSection.Clear();
	QueryResult = GetCompanyDataSelection(DocumentData);
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		NewRow = TabularSection.Add();
		DataStructure = GetCompanyRowData(DocumentData, Selection);
		
		FillPropertyValues(NewRow, DataStructure);
		
	EndDo;
	
	SetPrivilegedMode(False);
	
EndProcedure

// Procedure fills in tabular section "Company data".
//
Procedure FillCounterpartyInformationByCompanyData(CompanyData, CounterpartyData) Export
	
	CounterpartyData.Clear();
	For Each CompanyRow In CompanyData Do
		
		CounterpartyRow = CounterpartyData.Add();
		FillPropertyValues(CounterpartyRow, CompanyRow, "AccountingDocument");
		
		DecryptionJSC = Undefined;
		If TypeOf(CompanyRow.AccountingDocument) = Type("DocumentRef.ExpenseReport") Then
			
			DecryptionJSC = New Structure;
			DecryptionJSC.Insert("Contract", CompanyRow.Contract);
			DecryptionJSC.Insert("PaymentAmount", CompanyRow.ClientDebtAmount);
			
		EndIf;
		
		CounterpartyRow.IncomingDocumentNumber = GetIncNumber(CompanyRow.AccountingDocument, DecryptionJSC);
		CounterpartyRow.IncomingDocumentDate = GetIncDate(CompanyRow.AccountingDocument, DecryptionJSC);
		
		CounterpartyRow.DocumentDescription = CounterpartyAccountingDocumentDescription(CompanyRow.AccountingDocument, CounterpartyRow.IncomingDocumentNumber, CounterpartyRow.IncomingDocumentDate);
		
		CounterpartyRow.CompanyDebtAmount = CompanyRow.ClientDebtAmount;
		CounterpartyRow.ClientDebtAmount = CompanyRow.CompanyDebtAmount;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region DataReceiving

// Returns data selection by accounts payable
// balance by the registers "Accounts receivable" and "Accounts payable"
// 
// Parameters:
//    DocumentsData - Structure - Structure containing fields:
//    									Company - CatalogRef.Companies - Company for selection from registers;
//    									Counterparty  - CatalogRef.Counterparties - Counterparty for selection from registers;
//    									EndOfPeriod - Date - Period for balance receipt.
// Returns:
//    Selection from query result OR Undefined - if query result is empty.
//
Function GetCompanyDataSelection(DocumentData) Export
	
	CompanyDataQuery = New Query;
	CompanyDataQuery.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		ELSE CustomersSettlementsTurnovers.Recorder.Date
	|	END AS Period,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		ELSE CustomersSettlementsTurnovers.Recorder.Number
	|	END AS DocumentNumber,
	|	CustomersSettlementsTurnovers.Contract AS Contract,
	|	CustomersSettlementsTurnovers.Contract.ContractDate AS ContractDate,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document
	|		ELSE CustomersSettlementsTurnovers.Recorder
	|	END AS AccountingDocument,
	|	CustomersSettlementsTurnovers.Recorder AS Recorder,
	|	SUM(CustomersSettlementsTurnovers.AmountCurTurnover) AS AmountCurTurnover
	|INTO ResultInCurrency
	|FROM
	|	AccumulationRegister.AccountsReceivable.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Recorder,
	|			Company = &Company
	|				AND &Filter) AS CustomersSettlementsTurnovers
	|WHERE
	|	NOT ISNULL(CAST(CustomersSettlementsTurnovers.Recorder AS Document.MonthEndClosing) REFS Document.MonthEndClosing, FALSE)
	|	AND CustomersSettlementsTurnovers.Recorder.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND &SelectDocumentDataByCustomers
	|
	|GROUP BY
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CASE
	|					WHEN CAST(CustomersSettlementsTurnovers.Document AS Document.SalesOrder) REFS Document.SalesOrder
	|						THEN CustomersSettlementsTurnovers.Document.Finish
	|					ELSE CustomersSettlementsTurnovers.Document.Date
	|				END
	|		ELSE CustomersSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document.Number
	|		ELSE CustomersSettlementsTurnovers.Recorder.Number
	|	END,
	|	CustomersSettlementsTurnovers.Contract,
	|	CASE
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN CustomersSettlementsTurnovers.Document
	|		WHEN CAST(CustomersSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN CustomersSettlementsTurnovers.Document
	|		ELSE CustomersSettlementsTurnovers.Recorder
	|	END,
	|	CustomersSettlementsTurnovers.Recorder,
	|	CustomersSettlementsTurnovers.Contract.ContractDate
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		ELSE VendorsSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		ELSE VendorsSettlementsTurnovers.Recorder.Number
	|	END,
	|	VendorsSettlementsTurnovers.Contract,
	|	VendorsSettlementsTurnovers.Contract.ContractDate,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document
	|		ELSE VendorsSettlementsTurnovers.Recorder
	|	END,
	|	VendorsSettlementsTurnovers.Recorder,
	|	SUM(-VendorsSettlementsTurnovers.AmountCurTurnover)
	|FROM
	|	AccumulationRegister.AccountsPayable.Turnovers(
	|			&BeginOfPeriod,
	|			&EndOfPeriod,
	|			Recorder,
	|			Company = &Company
	|				AND &Filter) AS VendorsSettlementsTurnovers
	|WHERE
	|	NOT ISNULL(CAST(VendorsSettlementsTurnovers.Recorder AS Document.MonthEndClosing) REFS Document.MonthEndClosing, FALSE)
	|	AND VendorsSettlementsTurnovers.Recorder.Date BETWEEN &BeginOfPeriod AND &EndOfPeriod
	|	AND &SelectDocumentDataByVendors
	|
	|GROUP BY
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Date
	|		ELSE VendorsSettlementsTurnovers.Recorder.Date
	|	END,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document.Number
	|		ELSE VendorsSettlementsTurnovers.Recorder.Number
	|	END,
	|	VendorsSettlementsTurnovers.Contract,
	|	CASE
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.OpeningBalanceEntry) REFS Document.OpeningBalanceEntry
	|			THEN VendorsSettlementsTurnovers.Document
	|		WHEN CAST(VendorsSettlementsTurnovers.Recorder AS Document.RegistersCorrection) REFS Document.RegistersCorrection
	|			THEN VendorsSettlementsTurnovers.Document
	|		ELSE VendorsSettlementsTurnovers.Recorder
	|	END,
	|	VendorsSettlementsTurnovers.Recorder,
	|	VendorsSettlementsTurnovers.Contract.ContractDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ResultInCurrency.Period AS Period,
	|	ResultInCurrency.DocumentNumber AS DocumentNumber,
	|	ResultInCurrency.Contract AS Contract,
	|	ResultInCurrency.ContractDate AS ContractDate,
	|	ResultInCurrency.AccountingDocument AS AccountingDocument,
	|	ResultInCurrency.Recorder AS Recorder,
	|	ResultInCurrency.AmountCurTurnover AS AmountCurTurnover
	|FROM
	|	ResultInCurrency AS ResultInCurrency
	|
	|ORDER BY
	|	Period,
	|	Contract,
	|	ContractDate";
	
	CompanyDataQuery.SetParameter("BeginOfPeriod",	DocumentData.BeginOfPeriod);
	CompanyDataQuery.SetParameter("EndOfPeriod",	EndOfDay(DocumentData.EndOfPeriod));
	CompanyDataQuery.SetParameter("Company",		DocumentData.Company);
	CompanyDataQuery.SetParameter("Counterparty",	DocumentData.Counterparty);
	CompanyDataQuery.SetParameter("Contract",		DocumentData.Contract);
	
	ReplaceConditionDoOperationsByContracts(CompanyDataQuery.Text, DocumentData.DoOperationsByContracts);
	
	If ValueIsFilled(DocumentData.Ref) Then
		
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByCustomers", "AccountsReceivable.Registrar.Ref = &Ref");
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByVendors", "AccountsPayable.Registrar.Ref = &Ref");
		CompanyDataQuery.SetParameter("Ref", DocumentData.Ref);
		
	Else
		
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByCustomers", "True");
		CompanyDataQuery.Text = StrReplace(CompanyDataQuery.Text, "&SelectDocumentDataByVendors", "True");
		
	EndIf;
	
	Return CompanyDataQuery.Execute();
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

// Returns filled printing form "Reconciliation statement"
//
// Parameters:
//    DocumentPrint  - DocumentRef	  - Document that
//    should be printed PrintingObjects	  - ValueList	  - Printing objects list
//
// Return value: Tabular document
//
Function PrintReconciliationStatement(ObjectsArray, PrintObjects, TemplateName, PrintParams)
    
    DisplayPrintOption = (PrintParams <> Undefined);
    
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ReconciliationStatement";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	Query.Text = QueryText();
	
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
	
	ResultArray = Query.Execute();
	
	FirstDocument = True;
	
	Header = ResultArray.Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Template = PrintManagement.PrintFormTemplate(
			"Document.ReconciliationStatement.PF_MXL_ReconciliationStatement",
			LanguageCode);
		
		#Region PrintReconciliationStatementTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
        If DisplayPrintOption Then 
            TitleArea.Parameters.OriginalDuplicate = ?(PrintParams.OriginalCopy,
				NStr("en = 'ORIGINAL'; ru = 'ОРИГИНАЛ';pl = 'ORYGINAŁ';es_ES = 'ORIGINAL';es_CO = 'ORIGINAL';tr = 'ORİJİNAL';it = 'ORIGINALE';de = 'ORIGINAL'", LanguageCode),
				NStr("en = 'COPY'; ru = 'КОПИЯ';pl = 'KOPIA';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'KOPYA';it = 'COPIA';de = 'KOPIE'", LanguageCode));
        EndIf;
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.Date,
			,
			,
			,
			LanguageCode);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetBinaryFileData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintReconciliationStatementCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Company, Header.Date, , , Header.CompanyVATNumber, LanguageCode);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		BarcodesInPrintForms.AddBarcodeToTableDocument(CompanyInfoArea, Header.Ref);
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion

		#Region PrintSalesInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(
			Header.Counterparty,
			Header.Date,
			,
			,
			,
			LanguageCode);
		
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		BeginOfPeriod = Format(Header.BeginOfPeriod, "DLF=D");
		EndOfPeriod = Format(Header.EndOfPeriod, "DLF=D");
		
		If ValueIsFilled(BeginOfPeriod) Then
			Period = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'from %1 to %2'; ru = 'с %1 по %2';pl = 'od %1 do %2';es_ES = 'desde %1 hasta %2';es_CO = 'desde %1 hasta %2';tr = '%1 itibaren %2 kadar';it = 'da %1 a %2';de = 'von %1 bis %2'", LanguageCode),
				BeginOfPeriod,
				EndOfPeriod);
		Else
			Period = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'to %1'; ru = 'с %1';pl = 'do %1';es_ES = 'a %1';es_CO = 'a %1';tr = '%1 ye';it = 'a %1';de = 'zu %1'", LanguageCode), EndOfPeriod);
		EndIf;
		
		CounterpartyInfoArea.Parameters.Period = Period;
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintReconciliationStatementCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintReconciliationStatementContractArea
		
		If Header.DoOperationsByContracts Then
			ContractArea = Template.GetArea("Contract");
			ContractArea.Parameters.Fill(Header);
			SpreadsheetDocument.Put(ContractArea);
		EndIf;
		
		#EndRegion

		#Region PrintReconciliationStatementLinesArea
		LineHeaderArea = Template.GetArea("LineHeader");
		LineHeaderArea.Parameters.Fill(Header);
		LineSectionArea	= Template.GetArea("Line");
        
        SpreadsheetDocument.Put(LineHeaderArea);
		
		OpeningBalance = BalanceByContracts(Header);
		OpeningBalanceArea = Template.GetArea("OpeningBalance");
		OpeningBalanceArea.Parameters.PositiveOB = ?(OpeningBalance < 0, -OpeningBalance, 0);
		OpeningBalanceArea.Parameters.NegativeOB = ?(OpeningBalance > 0, OpeningBalance, 0);
		SpreadsheetDocument.Put(OpeningBalanceArea);
		
		#Region PrintReconciliationStatementTotalsAreaPrefill
		
		TotalsAreasArray = New Array;
		AreasToBeChecked = New Array;
		
		ClosingBalanceArea = Template.GetArea("ClosingBalance");
		ClosingBalance = OpeningBalance + Header.CreditContractCcy - Header.DebitContractCcy;
		ClosingBalanceArea.Parameters.PositiveCB = ?(ClosingBalance < 0, -ClosingBalance, 0);
		ClosingBalanceArea.Parameters.NegativeCB = ?(ClosingBalance > 0, ClosingBalance, 0);
		
		TotalsAreasArray.Add(ClosingBalanceArea);
		
		SignaturesArea = Template.GetArea("Signatures");
		SignaturesArea.Parameters.Fill(Header);
		
		TotalsAreasArray.Add(SignaturesArea);
		
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		#EndRegion
		
		TabSelection = Header.Select();
		While TabSelection.Next()
			And Header.RowsCount > 0 Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			AreasToBeChecked.Clear();
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				LineSectionArea.Parameters.Fill(TabSelection);
				LineSectionArea.Parameters.CompanyDataDate = Format(TabSelection.CompanyDataDate, "DLF=D");
				
				If TabSelection.AccountingDocument <> Undefined Then
					LineSectionArea.Parameters.CompanyDataDocumentDescription = String(TypeOf(TabSelection.AccountingDocument));
				Else
					LineSectionArea.Parameters.CompanyDataDocumentDescription = NStr("en = 'Settlement document'; ru = 'Документ расчетов';pl = 'Dokument rozliczeń';es_ES = 'Documento de liquidaciones';es_CO = 'Documento de liquidaciones';tr = 'Hesaplaşma belgesi';it = 'Documento di pagamento';de = 'Abrechnungsbeleg'", LanguageCode);
				EndIf;
				
				LineSectionArea.Parameters.CompanyDataNumber = NStr("en = '#'; ru = '#';pl = '#';es_ES = '#';es_CO = '#';tr = '#';it = '#';de = '#'", LanguageCode)
					+ ObjectPrefixationClientServer.GetNumberForPrinting(TabSelection.CompanyDataNumber, False, True);
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintReconciliationStatementTotalsArea
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
        #Region PrintAdditionalAttributes
        If DisplayPrintOption And PrintParams.AdditionalAttributes And PrintManagementServerCallDrive.HasAdditionalAttributes(Header.Ref) Then
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesStaticHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            SpreadsheetDocument.Put(EmptyLineArea);
            
            AddAttribHeader = Template.GetArea("AdditionalAttributesHeader");
            SpreadsheetDocument.Put(AddAttribHeader);
            
            AddAttribRow = Template.GetArea("AdditionalAttributesRow");
            
            For each Attr In Header.Ref.AdditionalAttributes Do
                AddAttribRow.Parameters.AddAttributeName = Attr.Property.Title;
                AddAttribRow.Parameters.AddAttributeValue = Attr.Value;
                SpreadsheetDocument.Put(AddAttribRow);                
            EndDo;                
        EndIf;    
        #EndRegion
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
        
		For i = 1 To 50 Do
			
			If Not Common.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Function QueryText()
	
	QueryText = 
	"SELECT
	|	ReconciliationStatement.Ref AS Ref,
	|	ReconciliationStatement.Number AS Number,
	|	ReconciliationStatement.Date AS Date,
	|	ReconciliationStatement.Company AS Company,
	|	ReconciliationStatement.CompanyVATNumber AS CompanyVATNumber,
	|	ReconciliationStatement.Counterparty AS Counterparty,
	|	ReconciliationStatement.Contract AS Contract,
	|	ReconciliationStatement.DocumentCurrency AS DocumentCurrency,
	|	CAST(ReconciliationStatement.DocumentDescription AS STRING(1024)) AS DocumentDescription,
	|	ReconciliationStatement.BeginOfPeriod AS BeginOfPeriod,
	|	ReconciliationStatement.EndOfPeriod AS EndOfPeriod
	|INTO ReconciliationStatements
	|FROM
	|	Document.ReconciliationStatement AS ReconciliationStatement
	|WHERE
	|	ReconciliationStatement.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReconciliationStatements.Ref AS Ref,
	|	ReconciliationStatements.Number AS Number,
	|	ReconciliationStatements.Date AS Date,
	|	ReconciliationStatements.Company AS Company,
	|	ReconciliationStatements.CompanyVATNumber AS CompanyVATNumber,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	ReconciliationStatements.Counterparty AS Counterparty,
	|	ReconciliationStatements.Contract AS Contract,
	|	CASE
	|		WHEN CounterpartyContracts.ContactPerson = VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN Counterparties.ContactPerson
	|		ELSE CounterpartyContracts.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	ReconciliationStatements.DocumentCurrency AS DocumentCurrency,
	|	ReconciliationStatements.DocumentDescription AS DocumentDescription,
	|	ReconciliationStatements.BeginOfPeriod AS BeginOfPeriod,
	|	ReconciliationStatements.EndOfPeriod AS EndOfPeriod,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts
	|INTO Header
	|FROM
	|	ReconciliationStatements AS ReconciliationStatements
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON ReconciliationStatements.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON ReconciliationStatements.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON ReconciliationStatements.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(ReconciliationStatementCompanyData.DocumentDate, DATETIME(1, 1, 1)) AS CompanyDataDate,
	|	ISNULL(ReconciliationStatementCompanyData.DocumentNumber, """") AS CompanyDataNumber,
	|	ISNULL(ReconciliationStatementCompanyData.AccountingDocument, UNDEFINED) AS AccountingDocument,
	|	ISNULL(ReconciliationStatementCompanyData.DocumentDescription, """") AS CompanyDataDocumentDescription,
	|	ISNULL(ReconciliationStatementCompanyData.ClientDebtAmount, 0) AS DebitContractCcy,
	|	ISNULL(ReconciliationStatementCompanyData.CompanyDebtAmount, 0) AS CreditContractCcy,
	|	ISNULL(ReconciliationStatementCompanyData.LineNumber, 0) AS RowsCount,
	|	Header.Ref AS Ref,
	|	Header.Company AS Company,
	|	Header.CompanyVATNumber AS CompanyVATNumber,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.DocumentDescription AS DocumentDescription,
	|	Header.BeginOfPeriod AS BeginOfPeriod,
	|	Header.EndOfPeriod AS EndOfPeriod,
	|	Header.DoOperationsByContracts AS DoOperationsByContracts,
	|	Header.Number AS Number,
	|	Header.Date AS Date
	|FROM
	|	Header AS Header
	|		LEFT JOIN Document.ReconciliationStatement.CompanyData AS ReconciliationStatementCompanyData
	|		ON Header.Ref = ReconciliationStatementCompanyData.Ref
	|TOTALS
	|	SUM(DebitContractCcy),
	|	SUM(CreditContractCcy),
	|	MAX(RowsCount),
	|	MAX(Company),
	|	MAX(CompanyVATNumber),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(DocumentCurrency),
	|	MAX(DocumentDescription),
	|	MAX(BeginOfPeriod),
	|	MAX(EndOfPeriod),
	|	MAX(DoOperationsByContracts),
	|	MAX(Number),
	|	MAX(Date)
	|BY
	|	Ref";
	
	Return QueryText;
	
EndFunction

Function BalanceByContracts(DocumentData) Export
	
	BeginOfPeriod = DocumentData.BeginOfPeriod;
	If Not ValueIsFilled(BeginOfPeriod) Then
		
		BeginOfPeriod = DriveServer.GetDefaultDate();
		
	EndIf;
	
	BalanceBeginPeriod = 0;
	
	Query = New Query;
	Query.SetParameter("Company", DocumentData.Company);
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("Counterparty", DocumentData.Counterparty);
	Query.SetParameter("Contract", DocumentData.Contract);
	
	Query.Text = 
	"SELECT ALLOWED
	|	CASE
	|		WHEN AccountsPayableBalances.AmountCurBalance > 0
	|				AND AccountsReceivableBalances.AmountCurBalance < 0
	|			THEN -1 * AccountsReceivableBalances.AmountCurBalance + AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsPayableBalances.AmountCurBalance > 0
	|			THEN AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsReceivableBalances.AmountCurBalance < 0
	|			THEN -AccountsReceivableBalances.AmountCurBalance
	|		ELSE 0
	|	END - CASE
	|		WHEN AccountsPayableBalances.AmountCurBalance < 0
	|				AND AccountsReceivableBalances.AmountCurBalance > 0
	|			THEN -1 * AccountsPayableBalances.AmountCurBalance + AccountsReceivableBalances.AmountCurBalance
	|		WHEN AccountsPayableBalances.AmountCurBalance < 0
	|			THEN -AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsReceivableBalances.AmountCurBalance > 0
	|			THEN AccountsReceivableBalances.AmountCurBalance
	|		ELSE 0
	|	END AS Balance
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&BeginOfPeriod,
	|			Company = &Company
	|				AND &Filter) AS AccountsReceivableBalances
	|		FULL JOIN AccumulationRegister.AccountsPayable.Balance(
	|				&BeginOfPeriod,
	|				Company = &Company
	|					AND &Filter) AS AccountsPayableBalances
	|		ON AccountsReceivableBalances.Contract = AccountsPayableBalances.Contract";
	
	ReplaceConditionDoOperationsByContracts(Query.Text, DocumentData.DoOperationsByContracts);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		BalanceBeginPeriod = BalanceBeginPeriod + Selection.Balance;
	EndDo;
	
	Return BalanceBeginPeriod;
	
EndFunction

Procedure ReplaceConditionDoOperationsByContracts(QueryText, DoOperationsByContracts) Export
	
	If DoOperationsByContracts Then
		QueryText = StrReplace(QueryText, "&Filter", "Contract = &Contract");
	Else
		QueryText = StrReplace(QueryText, "&Filter", "Counterparty = &Counterparty");
	EndIf;		
	
EndProcedure

// Generate printed forms of objects
//
// PARAMETERS.
// Incoming:
//   DocumentPrint  - DocumentRef		- Document that
//   should be printed PrintingParameters - Structure 			- Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   tabular documents PrintingObjects		   - ValueList	  - InputParameters
//   printing objects list       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ReconciliationStatement") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"ReconciliationStatement",
			NStr("en = 'Reconciliation statement'; ru = 'Сверка взаиморасчетов';pl = 'Uzgodnienie';es_ES = 'Declaración de reconciliación';es_CO = 'Declaración de reconciliación';tr = 'Mutabakat ekstresi';it = 'Dichiarazione di riconciliazione';de = 'Überleitungsrechnung'"),
			PrintForm(ObjectsArray, PrintObjects, "ReconciliationStatement", PrintParameters.Result));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// The procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName, PrintParams = Undefined)
	
	If TemplateName = "ReconciliationStatement" Then
		
		Return PrintReconciliationStatement(ObjectsArray, PrintObjects, TemplateName, PrintParams);
		
	EndIf;
	
EndFunction

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "ReconciliationStatement";
	PrintCommand.Presentation = NStr("en = 'Reconciliation statement'; ru = 'Сверка взаиморасчетов';pl = 'Uzgodnienie';es_ES = 'Declaración de reconciliación';es_CO = 'Declaración de reconciliación';tr = 'Mutabakat ekstresi';it = 'Dichiarazione di riconciliazione';de = 'Überleitungsrechnung'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

#Region InfobaseUpdate

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
	
		If FormType = "ListForm" Then
		
			StandardProcessing = False;
			
			SelectedForm = "ListFormForExternalUsers";
		EndIf;
		
	EndIf;
EndProcedure

#EndRegion

#EndIf