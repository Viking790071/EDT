#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(DateOfSupply, Company, Cancel);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(DateOfSupply, Company, Cancel);
	EndIf;
	BasisDocumentsFillCheck(Cancel);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DriveServer.SetPostingMode(ThisObject, WriteMode, PostingMode);
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("IsNew",    IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
		
	If WriteMode = DocumentWriteMode.Posting Then
		CheckTaxInvoiceForDublicates(Cancel);
	EndIf;
	
	DocumentAmount = BasisDocuments.Total("Amount");
	DocumentTax = BasisDocuments.Total("VATAmount");
	DocumentSubtotal = DocumentAmount - DocumentTax;
			
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.TaxInvoiceReceived.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);	// Accounting
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.TaxInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
	
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If (TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice")
		Or TypeOf(FillingData) = Type("DocumentRef.AdditionalExpenses")
		Or TypeOf(FillingData) = Type("DocumentRef.SubcontractorInvoiceReceived"))
		AND Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(FillingData.Date, FillingData.Company) Then
			
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'; ru = '?????????????????????? %1 ???? ???????????????????? ?????????????????? ?????????????? ???? %2 (?????????????? ???????????? ?????????? ?? ?????????????? ????????????????)';pl = 'Firma %1 nie stosuje faktur VAT do %2 (okre??l t?? opcj?? w zasadach rachunkowo??ci)';es_ES = 'Empresa %1 no utiliza las factura de impuestos en %2 (especificar esta opci??n en la pol??tica de contabilidad)';es_CO = 'Empresa %1 no utiliza las facturas fiscales en %2 (especificar esta opci??n en la pol??tica de contabilidad)';tr = '%1 i?? yeri %2 tarihinde vergi faturalar?? kullanm??yor (muhasebe politikas??nda bu se??ene??i belirtin)';it = 'L''azienda %1 non utilizza fatture fiscali a %2 (specificare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keine Steuerrechnungen bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
			FillingData.Company,
			Format(FillingData.Date, "DLF=D"))
		
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice")
		And FillingData.OperationKind = Enums.OperationTypesSupplierInvoice.ZeroInvoice Then
		
		Raise NStr("en = 'Cannot generate a Tax invoice for an invoice with Zero invoice type.
			|Select an invoice with another type.'; 
			|ru = '???????????????????? ?????????????? ?????????????????? ???????????? ?????? ?????????????? ???????????????? ????????.
			|???????????????? ???????????? ?????????????? ????????.';
			|pl = 'Nie mo??na wygenerowa?? Faktury VAT dla faktury z zerowym typem faktury.
			|Wybierz faktur?? z innym typem.';
			|es_ES = 'No se puede generar una Factura de impuestos para una factura con el tipo de factura con importe Cero. 
			|Seleccione una factura de otro tipo.';
			|es_CO = 'No se puede generar una Factura de impuestos para una factura con el tipo de factura con importe Cero. 
			|Seleccione una factura de otro tipo.';
			|tr = 'S??f??r bedelli fatura t??r?? fatura i??in Vergi faturas?? olu??turulam??yor.
			|Ba??ka t??r fatura se??in.';
			|it = 'Impossibile generare una Fattura fiscale per una fattura con tipo Fattura a zero. 
			|Selezionare una fattura di un altro tipo.';
			|de = 'Eine Steuerrechnung f??r eine Rechnung mit dem Rechnungstyp Null kann nicht generiert werden.
			|W??hlen Sie eine Rechnung mit einem anderen Typ aus.'");
		
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]									= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]				= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.DebitNote")]						= "FillByDebitNote";
	FillingStrategy[Type("DocumentRef.CashVoucher")]					= "FillByCashVoucher";
	FillingStrategy[Type("DocumentRef.PaymentExpense")]					= "FillByPaymentExpense";
	FillingStrategy[Type("DocumentRef.AdditionalExpenses")]				= "FillByAdditionalExpenses";
	FillingStrategy[Type("DocumentRef.SubcontractorInvoiceReceived")]	= "FillBySubcontractorInvoice";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.TaxInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel, True);

	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

#EndRegion

#Region ServiceFunctionsAndProcedures

#Region InitialazingAndFilling

Procedure FillByStructure(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") And FillingData.Property("BasisDocument") Then
		FillFromBasisDocument(FillingData);
		InitializeDocument(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure") And FillingData.Property("ExpenseReportData") Then
		FillFromExpenseReportDataStructure(FillingData.ExpenseReportData);
		InitializeDocument(FillingData.ExpenseReportData);
	Else
		InitializeDocument(FillingData);
	EndIf;
	
EndProcedure

Procedure FillFromExpenseReportDataStructure(DataStructure)
	
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, DataStructure);
	BasisDocuments.Clear();
	FillPropertyValues(BasisDocuments.Add(), DataStructure);
	
	OperationKind = Enums.OperationTypesTaxInvoiceReceived.Purchase;
	
EndProcedure

Procedure FillByDebitNote(FillingData) Export
	
	If Not ValueIsFilled(FillingData)
		Or Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date, Posted");
	Currency		= FillingData.DocumentCurrency;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	If FillingData.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.PurchaseReturn;
	ElsIf FillingData.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.DiscountReceived;
	Else
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.Adjustments;
	EndIf;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData, , "Date, Number, Comment, Posted");
	
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceReceived.Purchase;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillBySubcontractorInvoice(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Or Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData, , "Date, Number, Posted");
	
	Currency = FillingData.DocumentCurrency;
	OperationKind = Enums.OperationTypesTaxInvoiceReceived.Purchase;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillByAdditionalExpenses(FillingData) Export
	
	If NOT ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If NOT Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData, , "Date, Number, Posted");
	
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceReceived.Purchase;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillFromBasisDocument(FillingData)
	
	If TypeOf(FillingData.BasisDocument) = Type("Array") Then
		
		BasisArray = FillingData.BasisDocument;
		For each BasisForFilling In BasisArray Do
			BasisRow = BasisDocuments.Add();
			BasisRow.BasisDocument = BasisForFilling;
		EndDo;
		FillingData.BasisDocument = BasisArray[0];
		
	Else
		BasisRow = BasisDocuments.Add();
		BasisRow.BasisDocument = FillingData.BasisDocument;
	EndIf;
	
	TaxInvoiceParameters = GetBasisTaxInvoiceParameters();
	
	If Not TaxInvoiceParameters.Company = Undefined Then
		FillingData.Insert("Company", TaxInvoiceParameters.Company);
	EndIf;
	
	If Not TaxInvoiceParameters.Department = Undefined Then
		FillingData.Insert("Department", TaxInvoiceParameters.Department);
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined Then
		FillingData.Insert("Counterparty",     TaxInvoiceParameters.Counterparty);
	EndIf;
				
EndProcedure

Procedure FillByCashVoucher(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillByPaymentExpense(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillAdvancePayment(FillingData)
	
	If Not ValueIsFilled(FillingData)
		Or Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED DISTINCT
	|	VATIncurred.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&Documents)
	|	AND VATIncurred.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND VALUETYPE(VATIncurred.Recorder) = TYPE(Document.SupplierInvoice)");
	
	Query.SetParameter("Documents", FillingData);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	ErrorText = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                 |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                 |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'; 
	                 |ru = '?????????? ?????? ???????????? ?? %1. ?????? ?????????????????????????? ?? ???????????? ?????? ?? ??????????????. ???????? ???? ?????? ???? ????????????
	                 |???????????? ???????????? ???? ??????????, ???? ???????????????????? ???????????????? ???????????????????? ?????????????? ????????????????????,
	                 |???????????? ???????????? ???? ?????????? ?? ???????????????? ???????????? ???????????????????? ????????????.';
	                 |pl = 'Kwota zaliczki zatwierdzona wed??ug tego dokumentu p??atno??ci jest ju?? potr??cona przez %1.
	                 |Nie jest konieczne zaliczanie zaliczki VAT. Je??li nadal chcesz wprowadzi?? faktur?? p??atno??ci zaliczkowej,
	                 |wr???? do zapisanego stanu faktury zakupu, wprowad?? faktur?? p??atno??ci zaliczkowej, a nast??pnie ponownie zatwierd?? faktur?? zakupu.';
	                 |es_ES = 'El importe de anticipo enviado por este documento de pago ya est?? desactivado por %1.
	                 |No hay necesidad para reconocer el IVA del anticipo. Si usted a??n quiere introducir la factura de Pago anticipado,
	                 |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                 |es_CO = 'El importe de anticipo enviado por este documento de pago ya est?? desactivado por %1.
	                 |No hay necesidad para reconocer el IVA del anticipo. Si usted a??n quiere introducir la factura de Pago anticipado,
	                 |volver a la factura de Proveedor en el estado guardado, introducir la factura de pago anticipado, y entonces enviar de nuevo la factura de proveedor.';
	                 |tr = 'Bu ??deme belgesiyle g??nderilen avans tutar?? %1 ile ayarlan??r.
	                 |Avans KDV''sini tan??maya gerek yoktur. Avans ??deme faturas??n?? yine de girmek istiyorsan??z, 
	                 |kaydedilmi?? durumdaki Sat??n alma faturas??n?? de??i??tirin, avans ??deme faturas??n?? girin ve ard??ndan sat??n alma faturas??n?? yeniden g??nderin.';
	                 |it = 'Il pagamento anticipato pubblicato con questo documento di pagamento ?? gi?? stato compensato da %1.
	                 |Non c''?? motivo per risconoscere anticipo IVA. Se volete ancora inserire fattura di pagamento Anticipato,
	                 |storna la Fattura del fornitore (togli pubblicazione), inserisci fattura di pagamento anticipato, e pubblica nuovamente la Fattura del fornitore.';
	                 |de = 'Der durch diesen Zahlungsbeleg gebuchte Vorauszahlungsbetrag wird bereits durch das %1 verrechnet.
	                 |Eine Aufnahme der USt.-Vorauszahlung ist nicht erforderlich. Wenn Sie dennoch eine Vorauszahlungsrechnung eingeben m??chten,
	                 |stornieren Sie die Lieferantenrechnung im gespeicherten Zustand, geben Sie eine Vorauszahlungsrechnung ein und buchen Sie die Lieferantenrechnung erneut.'");
	
	While Selection.Next() Do
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText, Selection.Recorder);
		CommonClientServer.AddUserError(Errors, , ErrorText, Undefined);
		
	EndDo;
	
	CommonClientServer.ReportErrorsToUser(Errors, Cancel);
	
	If Not Cancel Then
		FillPropertyValues(ThisObject, FillingData,, "Number, Date, Posted");
		
		Currency = FillingData.CashCurrency;
		OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment;
		
		BasisDocuments.Clear();
		NewRow = BasisDocuments.Add();
		NewRow.BasisDocument = FillingData;
		
		FillDocumentAmounts(NewRow);
	EndIf;
	
EndProcedure

Procedure InitializeDocument(FillingData = Undefined)
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Company") Then
		Company = Company = DriveServer.GetCompany(Company);
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Currency") Then
		Currency = DriveReUse.GetFunctionalCurrency();
	EndIf;
		
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("DateOfSupply") Then
		DateOfSupply = CurrentSessionDate();
	EndIf;
	
EndProcedure

Function GetBasisTaxInvoiceParameters()
	
	SetPrivilegedMode(True);
	
	Result = New Structure("Company, Counterparty, Currency,
		|BasisAttributes, Department");
	
	BasisAttributes = New ValueTable;
	Columns = BasisAttributes.Columns;
	Columns.Add("BasisDocument");
	
	Result.BasisAttributes = BasisAttributes;
	
	DocumentsArray = BasisDocuments.UnloadColumn("BasisDocument");
	
	BasisTypes = DriveServer.ArrangeListByTypesOfObjects(DocumentsArray);
	BasisTypes = Undefined;
	
	Query = New Query;
	QueryBasisText = "";
	QueryInitialDataText = "";
	
	For each BasisType In BasisTypes Do
		
		ObjectType			= BasisType.Value;
		DocumentsMetadata	= ObjectType[0].Metadata();
		ObjectName			= DocumentsMetadata.Name;
		
		Query.Parameters.Insert("BasisDocument_" + ObjectName, ObjectType);
		
		If Not IsBlankString(QueryBasisText) Then
			QueryBasisText = QueryBasisText + "
			|
			|UNION ALL
			|
			|";
		EndIf;
	
		QueryBasisText = QueryBasisText + 
		"SELECT
		|	Table.Company AS Company,
		|	Table.Counterparty  AS Counterparty,
		|	Table.Currency        AS Currency,
		|	Table.Department AS Department
		|FROM
		|	Document." + ObjectName + " AS Table
		|WHERE
		|	Table.Ref IN (&BasisDocument_" + ObjectName + ")";

				
	EndDo;
	
	BasisSelection = Undefined;
	InitialDataSelection = Undefined;
	
	If IsBlankString(QueryInitialDataText) Then
		Query.Text = QueryBasisText;
		BasisSelection = Query.Execute().Select();
	Else
		Query.Text = QueryBasisText + "
		|;
		|
		|" + QueryInitialDataText;
		
		Query.SetParameter("TaxInvoice", Ref);
		QueryResult = Query.ExecuteBatch();
		BasisSelection = QueryResult[0].Select();
		QueryCount = QueryResult.Count();
		InitialDataSelection = QueryResult[QueryCount-1].Select(QueryResultIteration.ByGroups);
	EndIf;
	
	FirstRow					= True;
	DifferentCompanies			= False;
	DifferentCounterparties		= False;
	DifferentCurrencies			= False;
	
	While BasisSelection.Next() Do
		If FirstRow Then
			FirstRow = False;
			FillPropertyValues(Result, BasisSelection);
		Else
			DifferentCompanies		= DifferentCompanies Or Result.Company <> BasisSelection.Company;
			DifferentCounterparties	= DifferentCounterparties Or Result.Counterparty <> BasisSelection.Counterparty;
			DifferentCurrencies		= DifferentCurrencies Or Result.Currency <> BasisSelection.Currency;
		EndIf;
	EndDo;
	
	If DifferentCompanies Or DifferentCounterparties Or DifferentCurrencies Then
		
		Attributes = Ref.Metadata().Attributes;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The following fields of the tax invoice''s base documents do not match: %1%2%3'; ru = '?? ????????????????????-???????????????????? ???????????????????? ?????????????? ???? ?????????????????? ?????????????????? ????????: %1%2%3';pl = 'Nast??puj??ce pola dokument??w ??r??d??owych faktury VAT nie s?? zgodne: %1%2%3';es_ES = 'Los siguientes campos de los documentos de la base de la factura de impuestos no coinciden: %1%2%3';es_CO = 'Los siguientes campos de los documentos de la base de la factura fiscal no coinciden: %1%2%3';tr = 'Vergi faturas?? temel belgelerinin a??a????daki alanlar?? e??le??miyor: %1%2%3';it = 'I seguenti campi dei documenti di base della fattura fiscale non corrispondono: %1%2%3';de = 'Die folgenden Felder der Basisbelege der Steuerrechnung stimmen nicht ??berein: %1%2%3'"),
			?(DifferentCompanies, Chars.LF + "- " + Lower(Attributes.Company.Synonym), ""),
			?(DifferentCounterparties, Chars.LF + "- " + Lower(Attributes.Counterparty.Synonym), ""),
			?(DifferentCurrencies, Chars.LF + "- " + Lower(Attributes.Currency.Synonym), ""));
		
		CommonClientServer.MessageToUser(MessageText);
		
		If DifferentCompanies Then
			Result.Company = Undefined;
		EndIf;
		
		If DifferentCounterparties Then
			Result.Counterparty = Undefined;
		EndIf;
		
		If DifferentCurrencies Then
			Result.Currency = Undefined;
		EndIf;
		
	EndIf;
			
	Return Result;
	
EndFunction

#EndRegion

#Region Other

Procedure BasisDocumentsFillCheck(Cancel)
	
	BasisArray				= New Array;
	PurchaseFromSupplier	= Undefined;
	BasisType				= Undefined;
	
	For each BasisRow In BasisDocuments Do 
		
		If TypeOf(BasisRow.BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
		 
			If PurchaseFromSupplier = Undefined Then
				PurchaseFromSupplier = True;
			ElsIf NOT PurchaseFromSupplier Then
				BasisTypesErrorMessage(BasisRow.LineNumber, Cancel);
			EndIf;
			
		ElsIf BasisType = Undefined Then			
			BasisType = TypeOf(BasisRow.BasisDocument);		
		ElsIf BasisType <> Undefined AND BasisType <> TypeOf(BasisRow.BasisDocument) Then		
			BasisTypesErrorMessage(BasisRow.LineNumber, Cancel);			
		EndIf;
		
		If BasisArray.Find(BasisRow.BasisDocument) <> Undefined Then
			BasisDublicatesErrorMessage(BasisRow.LineNumber, BasisRow.BasisDocument, Cancel);
		EndIf; 
		
		BasisArray.Add(BasisRow.BasisDocument);
		
		If ValueIsFilled(BasisRow.BasisDocument)
			AND	NOT Common.ObjectAttributeValue(BasisRow.BasisDocument, "Posted") Then
				BasisPostingStatusErrorMessage(BasisRow.LineNumber, Cancel);
		EndIf;
		
		If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
			CurrencyName = "CashCurrency";
		Else 
			CurrencyName = "DocumentCurrency";
		EndIf;
		
		If Currency <> Common.ObjectAttributeValue(BasisRow.BasisDocument, CurrencyName) Then
			BasisCurrencyErrorMessage(BasisRow.LineNumber, Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BasisTypesErrorMessage(LineNumber, Cancel)
	
	MessageText = NStr("en = 'All documents included into tax invoice must have the same type'; ru = '?????? ?????????????????? ?? ?????????????????? ?????????????? ???????????? ???????? ???????????? ????????.';pl = 'Wszystkie dokumenty w fakturze VAT musz?? by?? tego samego rodzaju';es_ES = 'Todos los documentos incluidos en la factura de impuestos tienen que tener el mismo tipo';es_CO = 'Todos los documentos incluidos en la factura fiscal tienen que tener el mismo tipo';tr = 'Vergi faturas??na dahil edilen t??m belgeler ayn?? t??rde olmal??d??r';it = 'Tutti i documenti inclusi nella fattura fiscare devono essere dello stesso tipo';de = 'Alle in der Steuerrechnung enthaltenen Dokumente m??ssen vom gleichen Typ sein'");
	Field = CommonClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonClientServer.MessageToUser(MessageText,, Field, "Object", Cancel);
	
EndProcedure

Procedure BasisDublicatesErrorMessage(LineNumber, Basis, Cancel)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Duplicate document %2 in line #%1.'; ru = '?? ???????????? %1 ?? ???????????????? ??????????????????-?????????????????? ???????????????? ???????????? ???????????????? %2.';pl = 'Zduplikowany dokument ""%2"" w wierszu %1.';es_ES = 'Duplicar el documento %2 en la l??nea #%1.';es_CO = 'Duplicar el documento %2 en la l??nea #%1.';tr = '%2 belgesini #%1 sat??r??nda yenileyin.';it = 'Documento duplicato %2 nella linea #%1.';de = 'Dokument %2 in Zeile Nr %1 duplizieren.'"),
		LineNumber,
		Basis);
	Field = CommonClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure BasisPostingStatusErrorMessage(LineNumber, Cancel)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Please select a posted document in line #%1. A tax invoice can be based on posted documents only.'; ru = '?? ???????????? %1 ????????????????-?????????????????? ???? ????????????????. ?????????????????? ???????????? ?????????? ???????????????? ???????????? ???? ?????????????????? ?????????????????????? ????????????????????.';pl = 'Prosz?? wybra?? zatwierdzony dokument w wierszu #%1. Faktura VAT mo??e by?? oparta tylko na zatwierdzonych dokumentach.';es_ES = 'Por favor, seleccione un documento enviado en la l??nea #%1. Una factura de impuestos puede basarse solo en los documentos enviados.';es_CO = 'Por favor, seleccione un documento enviado en la l??nea #%1. Una factura fiscal puede basarse solo en los documentos enviados.';tr = 'L??tfen #%1 sat??r??nda onaylanan belgeyi se??in. Vergi faturas?? yaln??zca onaylanan belgelere dayal?? olabilir.';it = 'Si prega di selezionare un documento pubblicato nella linea #%1. Una fattura fiscale, pu?? essere basata solo su documenti pubblicati.';de = 'Bitte w??hlen Sie ein gebuchtes Dokument in Zeile Nr %1. Eine Steuerrechnung kann nur auf gebuchten Belegen basieren.'"),
		LineNumber);
	Field = CommonClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure BasisCurrencyErrorMessage(LineNumber, Cancel)
	
	MessageText = NStr("en = 'All documents included into tax invoice must have the same currency.'; ru = '?????? ?????????????????? ?? ?????????????????? ?????????????? ???????????? ???????? ?? ?????????? ????????????.';pl = 'Waluta wszystkich dokument??w w fakturze VAT musi by?? jednakowa.';es_ES = 'Todos los documentos incluidos en la factura de impuestos tienen que tener la misma moneda.';es_CO = 'Todos los documentos incluidos en la factura fiscal tienen que tener la misma moneda.';tr = 'Vergi faturas??na dahil edilen t??m belgelerin para birimi ayn?? olmal??d??r.';it = 'Tutti i documenti inclusi nella fattura fiscare devono avere la stessa valuta';de = 'Alle Dokumente, die in der Steuerrechnung enthalten sind, m??ssen dieselbe W??hrung haben.'");
	Field = CommonClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure CheckTaxInvoiceForDublicates(Cancel)
		
	SetPrivilegedMode(True);
	
	Query = New Query("
	|SELECT DISTINCT
	|	BasisTable.BasisDocument AS BasisDocument
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS BasisTable
	|WHERE
	|	BasisTable.Ref <> &Ref
	|	AND BasisTable.BasisDocument IN(&BasisList)
	|	AND NOT BasisTable.BasisDocument REFS Document.ExpenseReport
	|	AND BasisTable.Ref.Posted
	|");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("BasisList", BasisDocuments.UnloadColumn("BasisDocument"));
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'For document %1 tax invoice already exists'; ru = '?????? ?????????????????? %1 ?????? ???????????? ?????????????????? ????????????';pl = 'Dla dokumentu %1 faktura VAT ju?? istnieje';es_ES = 'Para el documento %1 la factura de impuestos ya existe';es_CO = 'Para el documento %1 la factura fiscal ya existe';tr = 'Belge %1 i??in vergi faturas?? zaten var';it = 'Per il documento %1 la fattura fiscale gi?? esiste';de = 'F??r das Dokument %1 existiert bereits eine Steuerrechnung'"),
			Selection.BasisDocument);
			
		CommonClientServer.MessageToUser(
			Text,
			ThisObject,
			"BasisDocuments",
			,
			Cancel);
		
	EndDo;
	
EndProcedure

Procedure FillDocumentAmounts(NewRow) Export
	
	Query = New Query;
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.Purchase Then
		Query.Text = 
		"SELECT ALLOWED
		|	SupplierInvoiceInventory.Ref AS BasisDocument,
		|	SupplierInvoiceInventory.VATAmount AS VATAmount,
		|	SupplierInvoiceInventory.Total AS Amount
		|INTO DocumentData
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Ref,
		|	SupplierInvoiceExpenses.VATAmount,
		|	SupplierInvoiceExpenses.Total
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	AdditionalExpensesExpenses.Ref,
		|	AdditionalExpensesExpenses.VATAmount,
		|	AdditionalExpensesExpenses.Total
		|FROM
		|	Document.AdditionalExpenses.Expenses AS AdditionalExpensesExpenses
		|WHERE
		|	AdditionalExpensesExpenses.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SubcontractorInvoiceReceivedProducts.Ref,
		|	SubcontractorInvoiceReceivedProducts.VATAmount,
		|	SubcontractorInvoiceReceivedProducts.Total
		|FROM
		|	Document.SubcontractorInvoiceReceived.Products AS SubcontractorInvoiceReceivedProducts
		|WHERE
		|	SubcontractorInvoiceReceivedProducts.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	ExpenseReportInventory.Ref,
		|	ExpenseReportInventory.VATAmount,
		|	ExpenseReportInventory.Total
		|FROM
		|	Document.ExpenseReport.Inventory AS ExpenseReportInventory
		|WHERE
		|	ExpenseReportInventory.Ref IN(&Documents)
		|	AND ExpenseReportInventory.DeductibleTax
		|	AND ExpenseReportInventory.Supplier = &Counterparty
		|
		|UNION ALL
		|
		|SELECT
		|	ExpenseReportExpenses.Ref,
		|	ExpenseReportExpenses.VATAmount,
		|	ExpenseReportExpenses.Total
		|FROM
		|	Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|WHERE
		|	ExpenseReportExpenses.Ref IN(&Documents)
		|	AND ExpenseReportExpenses.DeductibleTax
		|	AND ExpenseReportExpenses.Supplier = &Counterparty
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentData.BasisDocument AS BasisDocument,
		|	SUM(DocumentData.VATAmount) AS VATAmount,
		|	SUM(DocumentData.Amount) AS Amount
		|FROM
		|	DocumentData AS DocumentData
		|
		|GROUP BY
		|	DocumentData.BasisDocument";
	ElsIf OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		Query.Text = 
		"SELECT ALLOWED
		|	AdvancePayment.Ref AS BasisDocument,
		|	SUM(AdvancePayment.VATAmount) AS VATAmount,
		|	SUM(AdvancePayment.PaymentAmount) AS Amount
		|FROM
		|	Document.CashVoucher.PaymentDetails AS AdvancePayment
		|WHERE
		|	AdvancePayment.Ref IN(&Documents)
		|
		|GROUP BY
		|	AdvancePayment.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	PaymentReceipt.Ref,
		|	SUM(PaymentReceipt.VATAmount),
		|	SUM(PaymentReceipt.PaymentAmount)
		|FROM
		|	Document.PaymentExpense.PaymentDetails AS PaymentReceipt
		|WHERE
		|	PaymentReceipt.Ref IN(&Documents)
		|
		|GROUP BY
		|	PaymentReceipt.Ref";
	Else
		Query.Text = 
		"SELECT ALLOWED
		|	DebitNote.VATAmount AS VATAmount,
		|	DebitNote.DocumentAmount AS Amount
		|FROM
		|	Document.DebitNote AS DebitNote
		|WHERE
		|	DebitNote.Ref IN(&Documents)";
	EndIf;
	
	Query.SetParameter("Documents", NewRow.BasisDocument);
	Query.SetParameter("Counterparty", Counterparty);
	
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
