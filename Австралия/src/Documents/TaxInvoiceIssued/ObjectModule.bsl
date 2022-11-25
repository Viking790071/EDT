#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		
		If Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(FillingData.Date, FillingData.Company) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'; ru = 'Организация %1 не использует налоговые инвойсы на %2 (укажите данную опцию в учетной политике)';pl = 'Firma %1 nie stosuje faktur VAT do %2 (określ tę opcję w zasadach rachunkowości)';es_ES = 'Empresa %1 no utiliza las factura de impuestos en %2 (especificar esta opción en la política de contabilidad)';es_CO = 'Empresa %1 no utiliza las facturas fiscales en %2 (especificar esta opción en la política de contabilidad)';tr = '%1 iş yeri %2 tarihinde vergi faturaları kullanmıyor (muhasebe politikasında bu seçeneği belirtin)';it = 'L''azienda %1 non utilizza fatture fiscali a %2 (specificare questa opzione nella politica contabile)';de = 'Die Firma %1 verwendet keine Steuerrechnungen bei %2 (diese Option in der Bilanzierungsrichtlinie angeben)'"),
				FillingData.Company,
				Format(FillingData.Date, "DLF=D"))
			
		EndIf;
			
		If FillingData.OperationKind = Enums.OperationTypesSalesInvoice.ZeroInvoice Then
		
			Raise NStr("en = 'Cannot generate a Tax invoice for an invoice with Zero invoice type.
				|Select an invoice with another type.'; 
				|ru = 'Невозможно создать налоговый инвойс для инвойса нулевого типа.
				|Выберите инвойс другого типа.';
				|pl = 'Nie można wygenerować Faktury VAT dla faktury z zerowym typem faktury.
				|Wybierz fakturę z innym typem.';
				|es_ES = 'No se puede generar una Factura de impuestos para una factura con el tipo de factura con importe Cero. 
				|Seleccione una factura de otro tipo.';
				|es_CO = 'No se puede generar una Factura de impuestos para una factura con el tipo de factura con importe Cero. 
				|Seleccione una factura de otro tipo.';
				|tr = 'Sıfır bedelli fatura türü fatura için Vergi faturası oluşturulamıyor.
				|Başka tür fatura seçin.';
				|it = 'Impossibile generare una Fattura fiscale per una fattura con tipo Fattura a zero. 
				|Selezionare una fattura di un altro tipo.';
				|de = 'Eine Steuerrechnung für eine Rechnung mit dem Rechnungstyp Null kann nicht generiert werden.
				|Wählen Sie eine Rechnung mit einem anderen Typ aus.'");
		
		EndIf;
		
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")] = "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesInvoice")] = "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.CreditNote")] = "FillByCreditNote";
	FillingStrategy[Type("DocumentRef.CashReceipt")] = "FillByCashReceipt";
	FillingStrategy[Type("DocumentRef.PaymentReceipt")] = "FillByPaymentReceipt";
	FillingStrategy[Type("DocumentRef.OnlineReceipt")] = "FillByPaymentReceipt";
	// begin Drive.FullVersion
	FillingStrategy[Type("DocumentRef.SubcontractorInvoiceIssued")] = "FillBySubcontractorInvoiceIssued";
	// end Drive.FullVersion
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
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
	
	GenerateBasisArrayForChecking();
		
	If Not DeletionMark Then
		CheckTaxInvoiceForDublicates(Cancel);
	EndIf;
	
	If IsNew() AND Not ValueIsFilled(Number) Then
		SetNewNumber();
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
	
	Documents.TaxInvoiceIssued.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckDate = ?(ValueIsFilled(DateOfSupply), DateOfSupply, Date);
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(CheckDate, Company, Cancel);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(CheckDate, Company, Cancel);
	EndIf;
	
	BasisCount = BasisDocuments.Count();
	
	If BasisCount = 0 Then
		MessageText = NStr("en = 'No base documents are available.'; ru = 'Список документов-оснований пуст.';pl = 'Brak dostępnych dokumentów źródłowych.';es_ES = 'No hay documentos de base disponibles.';es_CO = 'No hay documentos de base disponibles.';tr = 'Hiçbir temel belge mevcut değildir.';it = 'Nessun documento di base è disponibile.';de = 'Es sind keine Basisbelege verfügbar.'");
		CommonClientServer.MessageToUser(MessageText, , "BasisDocuments", , Cancel);
	EndIf;
	
	DocumentsNotPosted = False;
	
	If BasisDocuments.Count() > 0 Then
		
		Query = New Query("SELECT ALLOWED
		|	BasisDocuments.BasisDocument.Posted AS BasisDocumentPosted
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|WHERE
		|	BasisDocuments.Ref = &Ref
		|");
		Query.SetParameter("Ref", Ref);
		SetPrivilegedMode(True);
		ResultSelection = Query.Execute().Select();
		SetPrivilegedMode(False);
		
		While ResultSelection.Next() Do
			
			If Not ResultSelection.BasisDocumentPosted Then
				DocumentsNotPosted = True;
				Break;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If DocumentsNotPosted Then
		If BasisCount > 1 Then
			MessageText = NStr("en = 'Please post all of the base documents of the tax invoice.'; ru = 'Налоговый инвойс можно провести, если проведены все документы списка ""Документы-основания"".';pl = 'Proszę zaksięgować wszystkie dokumenty źródłowe faktury VAT.';es_ES = 'Por favor, enviar todo de los documentos de base de la factura de impuestos.';es_CO = 'Por favor, enviar todo de los documentos de base de la factura fiscal.';tr = 'Lütfen vergi faturasının tüm temel belgelerini onaylayın.';it = 'Si prega di pubblicare tutti i documenti di base della fattura fiscale.';de = 'Bitte senden Sie alle Basisbelege der Steuerrechnung.'");
		Else
			MessageText = NStr("en = 'Please post the base document of the tax invoice.'; ru = 'Налоговый инвойс можно провести только на основании проведенного документа.';pl = 'Proszę zaksięgować dokument źródłowy faktury VAT.';es_ES = 'Por favor, enviar el documento de base de la factura de impuestos.';es_CO = 'Por favor, enviar el documento de base de la factura fiscal.';tr = 'Lütfen vergi faturasının temel belgesini onaylayın.';it = 'Si prega di pubblicare il documento di base della fattura fiscale.';de = 'Bitte buchen Sie das Basisdokument der Steuerrechnung.'");
		EndIf;
		CommonClientServer.MessageToUser(MessageText, , "BasisDocuments", , Cancel);
	EndIf;
	
	For Each Row In BasisDocuments Do
		
		FilterParameters = New Structure;
		FilterParameters.Insert("BasisDocument", Row.BasisDocument);
		
		SearchArray = BasisDocuments.FindRows(FilterParameters);
		
		For Each ArrayItem In SearchArray Do
			If ArrayItem.LineNumber <> Row.LineNumber Then
				CommonClientServer.MessageToUser(
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The document %1 already exists in the list.'; ru = 'Документ %1 уже присутствует в списке.';pl = 'Dokument %1 jest już na liście.';es_ES = 'El documento %1 ya existe en la lista.';es_CO = 'El documento %1 ya existe en la lista.';tr = '%1 belgesi listede zaten var.';it = 'Il documento %1 esiste già nell''elenco.';de = 'Das Dokument %1 existiert bereits in der Liste.'"),
						Row.BasisDocument),,
					"BasisDocuments",,
					Cancel);
				Break;
			EndIf;
		EndDo;
		
	EndDo;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.WriteRecordSets(ThisObject);
	
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

#Region InitializationAndFilling

Procedure FillByStructure(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		If FillingData.Property("BasisDocument") Then
			FillFromBasisDocument(FillingData);
		EndIf;
		
		If Not FillingData.Property("DateOfSupply") Then
			FillingData.Insert("DateOfSupply", CurrentSessionDate());
		EndIf;
		
	EndIf;
	
	InitializeDocument(FillingData);	
	
EndProcedure

Procedure FillByCreditNote(FillingData) Export
	
	If Not ValueIsFilled(FillingData)
		Or Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	Currency		= FillingData.DocumentCurrency;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	If FillingData.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.SalesReturn;
	ElsIf FillingData.OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Then
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.DiscountAllowed;
	Else
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.Adjustments;
	EndIf;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillByCashReceipt(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Responsible, Comment");
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceIssued.Sale;
	
	If WorkWithVAT.GetIssueAutomaticallyAgainstSales(Date, Company) Then
		DateOfSupply = Date;
	EndIf;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure InitializeDocument(FillingData = Undefined)
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Company") Then
		Company = DriveServer.GetCompany(Company);
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Currency") Then
		Currency = DriveReUse.GetFunctionalCurrency();
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Counterparty") Then
		Counterparty = Catalogs.Counterparties.EmptyRef();
	EndIf;
		
EndProcedure

Procedure FillTaxInvoiceParametersByBasis(SelectedTexInvoice = Undefined) Export
	
	If BasisDocuments.Count() = 0
		Or Not ValueIsFilled(BasisDocuments[0].BasisDocument) Then
			Return;
	EndIf;
	
	BasisDocument = BasisDocuments[0].BasisDocument;
	
	TaxInvoiceParameters = GetTaxInvoiceParametersByBasis();
	BasisAttributes = TaxInvoiceParameters.BasisAttributes;
	
	If Not TaxInvoiceParameters.Company = Undefined AND Not TaxInvoiceParameters.Company = Company Then
		Number = "";
		Company = TaxInvoiceParameters.Company;
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined AND Not TaxInvoiceParameters.Counterparty = Counterparty Then
		Counterparty = TaxInvoiceParameters.Counterparty;
	EndIf;
	
	If Not TaxInvoiceParameters.Currency = Undefined
		AND Currency <> TaxInvoiceParameters.Currency Then
			Currency = TaxInvoiceParameters.Currency;
	EndIf;
				
	If Not TaxInvoiceParameters.Department = Undefined AND Not TaxInvoiceParameters.Department = Department Then
		Department = TaxInvoiceParameters.Department;
	EndIf;
		
	If BasisAttributes.Count() > 0 Then
		BasisDocuments.Load(BasisAttributes);
	EndIf;
	
EndProcedure

Procedure FillFromBasisDocument(FillingData)
	
	If TypeOf(FillingData.BasisDocument) = Type("Array") Then
		
		BasisArray = FillingData.BasisDocument;
		For Each BasisForFilling In BasisArray Do
			BasisRow = BasisDocuments.Add();
			BasisRow.BasisDocument = BasisForFilling;
		EndDo;
		
		If BasisArray.Count() > 0 Then
			FillingData.BasisDocument = BasisArray[0];
		EndIf;
	Else
		BasisRow = BasisDocuments.Add();
		BasisRow.BasisDocument = FillingData.BasisDocument;
	EndIf;
	
	TaxInvoiceParameters = GetTaxInvoiceParametersByBasis();
	
	If Not TaxInvoiceParameters.Company = Undefined Then
		FillingData.Insert("Company", TaxInvoiceParameters.Company);
	EndIf;
	
	If Not TaxInvoiceParameters.Department = Undefined Then
		FillingData.Insert("Department", TaxInvoiceParameters.Department);
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined Then
		FillingData.Insert("Counterparty", TaxInvoiceParameters.Counterparty);
	EndIf;
		
	BasisAttributes = TaxInvoiceParameters.BasisAttributes;
		
EndProcedure

Procedure FillByPaymentReceipt(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

// begin Drive.FullVersion
Procedure FillBySubcontractorInvoiceIssued(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Responsible, Comment");
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceIssued.Sale;
	
	If WorkWithVAT.GetIssueAutomaticallyAgainstSales(Date, Company) Then
		DateOfSupply = Date;
	EndIf;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure
// end Drive.FullVersion 

#EndRegion

#Region Other

// Defines the attributes of the tax invoice based on the selected basis documents 
//
// Returns:
//	Structure - attributes of tax invoice.
//
Function GetTaxInvoiceParametersByBasis()
	
	SetPrivilegedMode(True);
	
	Result = New Structure("Company, Counterparty, Currency, BasisAttributes, Department");
	
	BasisAttributes = New ValueTable;
	Columns = BasisAttributes.Columns;
	Columns.Add("BasisDocument");
	
	Result.BasisAttributes = BasisAttributes;
	
	DocumentsArray = BasisDocuments.UnloadColumn("BasisDocument");
	BasisTypes = DriveServer.ArrangeListByTypesOfObjects(DocumentsArray);
	
	Query = New Query;
	QueryBasisText = "";
	QueryBasisText = "";
	
	For Each BasisType In BasisTypes Do
		
		ObjectsTypes		= BasisType.Value;
		DocumentsMetadata	= ObjectsTypes[0].Metadata();
		ObjectName			= DocumentsMetadata.Name;
		
		Query.Parameters.Insert("BasisDocument_" + ObjectName, ObjectsTypes);
		
		If Not IsBlankString(QueryBasisText) Then
			QueryBasisText = QueryBasisText + "
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		QueryBasisText = QueryBasisText + 
			"SELECT
			|	Table.Company   AS Company,
			|	Table.Counterparty    AS Counterparty,
			|	Table.Department AS Department,
			|	Table.Currency   AS Currency
			|FROM
			|	Document." + ObjectName + " AS Table
			|WHERE
			|	Table.Ref IN (&BasisDocument_" + ObjectName + ")";
			
	EndDo;
	
	BasisSelection = Undefined;
	InitialDataSelection = Undefined;
	
	If IsBlankString(QueryBasisText) Then
	
		Query.Text = QueryBasisText;
		BasisSelection = Query.Execute().Select();
	
	Else
		
		Query.Text = QueryBasisText + "
		|;
		|
		|" + QueryBasisText;
		
		Query.SetParameter("TaxInvoice", Ref);
		QueryResult = Query.ExecuteBatch();
		BasisSelection = QueryResult[0].Select();
		QueryCount = QueryResult.Count();
		InitialDataSelection = QueryResult[QueryCount-1].Select(QueryResultIteration.ByGroups);
		
	EndIf;
	
	FirstRow				= True;
	DifferentCompanies		= False;
	DifferentCounterparties	= False;
	DifferentCurrencies		= False;
	DifferentDepartments	= False;
	
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
	
	If DifferentCompanies OR DifferentCounterparties OR DifferentCurrencies Then
		
		MessageText = NStr("en = 'The following fields of the tax invoice''s base documents do not match:'; ru = 'В документах-основаниях налогового инвойса не совпадают следующие поля:';pl = 'Następujące pola dokumentów źródłowych faktury VAT nie są zgodne:';es_ES = 'Los siguientes campos de los documentos de base de la factura de impuestos no coinciden:';es_CO = 'Los siguientes campos de los documentos de base de la factura fiscal no coinciden:';tr = 'Vergi faturası temel belgelerinin aşağıdaki alanları eşleşmiyor:';it = 'I seguenti campi dei documenti di base della fattura fiscale non corrispondono:';de = 'Die folgenden Felder der Basisbelege der Steuerrechnung stimmen nicht überein:'")
			+ ?(DifferentCompanies, Chars.LF + NStr("en = '- company'; ru = '- организация';pl = '- organizacja';es_ES = '- empresa';es_CO = '- empresa';tr = '- iş yeri';it = '- azienda';de = '- Firma'"), "")
			+ ?(DifferentCounterparties, Chars.LF + NStr("en = '- counterparty'; ru = '- контрагент';pl = '- kontrahent';es_ES = '- contraparte';es_CO = '- contraparte';tr = '- cari hesap';it = '- controparte';de = '- Geschäftspartner'"), "")
			+ ?(DifferentCurrencies, Chars.LF + NStr("en = '- currency'; ru = '- валюта документа';pl = '- waluta';es_ES = '- moneda';es_CO = '- moneda';tr = '- para birimi';it = '- valuta del documento';de = '- Währung'"), "");
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

Procedure CheckTaxInvoiceForDublicates(Cancel)
	
	SetPrivilegedMode(True);
	
	Query = New Query("SELECT
	|	DocumentData.Ref AS Ref,
	|	DocumentData.BasisDocument AS BasisDocument
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS DocumentData
	|WHERE
	|	DocumentData.Ref <> &Ref
	|	AND DocumentData.BasisDocument IN(&BasisArray)
	|	AND DocumentData.Ref.Posted
	|	AND NOT DocumentData.Ref.DeletionMark
	|	AND DocumentData.Ref.OperationKind = &OperationKind");
	
	Query.SetParameter("Ref", 			Ref);
	Query.SetParameter("BasisArray",	BasisDocuments.UnloadColumn("BasisDocument"));
	Query.SetParameter("OperationKind",	OperationKind);
	
	Result = Query.Execute();
	ResultSelection = Result.Select();
	
	While ResultSelection.Next() Do
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '%2 for document %1 already exists'; ru = 'Для документа %1 уже введен налоговый инвойс %2';pl = 'Dla dokumentu %2 wprowadzono już fakturę VAT %1';es_ES = '%2 para el documento %1 ya existe';es_CO = '%2 para el documento %1 ya existe';tr = 'belge %2 için %1 zaten var';it = 'Per il documento %1 già esiste la fattura fiscale %2';de = '%2 für das Dokument %1 existiert bereits'"),
			ResultSelection.BasisDocument,
			ResultSelection.Ref);
			
		CommonClientServer.MessageToUser(Text, ThisObject,,, Cancel);
		
	EndDo;
	
EndProcedure

Procedure GenerateBasisArrayForChecking()
	
	BasisArray = New Array;
	
	If Not AdditionalProperties.IsNew Then
		
		Query = New Query(
		"SELECT ALLOWED
		|	BasisDocuments.BasisDocument AS BasisDocument
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|WHERE
		|	BasisDocuments.Ref = &Ref");
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		BasisArray = Result.Unload().UnloadColumn("BasisDocument");
		
	EndIf;
	
	If AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		DocumentBasesArray = BasisDocuments.UnloadColumn("BasisDocument");
		CommonClientServer.SupplementArray(BasisArray, DocumentBasesArray, True);
	EndIf;
	
	AdditionalProperties.Insert("BasisArrayForChecking", New FixedArray(BasisArray));
	
EndProcedure

Procedure FillDocumentAmounts(NewRow) Export

	Query = New Query;
	
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.Sale Then
		
		Query.Text = 
		"SELECT ALLOWED
		|	SalesInvoiceInventory.Ref AS BasisDocument,
		|	SUM(SalesInvoiceInventory.VATAmount) AS VATAmount,
		|	SUM(SalesInvoiceInventory.Total) AS Amount
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref IN(&Documents)
		|
		|GROUP BY
		|	SalesInvoiceInventory.Ref";
		
		// begin Drive.FullVersion
		
		Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
		"SELECT
		|	SubcontractorInvoiceIssuedProducts.Ref AS BasisDocument,
		|	SUM(SubcontractorInvoiceIssuedProducts.VATAmount) AS VATAmount,
		|	SUM(SubcontractorInvoiceIssuedProducts.Total) AS Amount
		|FROM
		|	Document.SubcontractorInvoiceIssued.Products AS SubcontractorInvoiceIssuedProducts
		|WHERE
		|	SubcontractorInvoiceIssuedProducts.Ref IN(&Documents)
		|
		|GROUP BY
		|	SubcontractorInvoiceIssuedProducts.Ref"
		
		// end Drive.FullVersion 
		
	ElsIf OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		Query.Text = 
		"SELECT ALLOWED
		|	AdvancePayment.Ref AS Ref,
		|	SUM(AdvancePayment.VATAmount) AS VATAmount,
		|	SUM(AdvancePayment.PaymentAmount) AS Amount
		|FROM
		|	Document.CashReceipt.PaymentDetails AS AdvancePayment
		|WHERE
		|	AdvancePayment.Ref IN(&Documents)
		|	AND AdvancePayment.AdvanceFlag
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
		|	Document.PaymentReceipt.PaymentDetails AS PaymentReceipt
		|WHERE
		|	PaymentReceipt.Ref IN(&Documents)
		|	AND PaymentReceipt.AdvanceFlag
		|
		|GROUP BY
		|	PaymentReceipt.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	OnlineReceipt.Ref,
		|	SUM(OnlineReceipt.VATAmount),
		|	SUM(OnlineReceipt.PaymentAmount)
		|FROM
		|	Document.OnlineReceipt.PaymentDetails AS OnlineReceipt
		|WHERE
		|	OnlineReceipt.Ref IN(&Documents)
		|	AND OnlineReceipt.AdvanceFlag
		|
		|GROUP BY
		|	OnlineReceipt.Ref";
	Else
		Query.Text = 
		"SELECT ALLOWED
		|	CreditNote.VATAmount AS VATAmount,
		|	CreditNote.DocumentAmount AS Amount
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Ref IN(&Documents)";
	EndIf;
	
	Query.SetParameter("Documents", NewRow.BasisDocument);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

Procedure FillAdvancePayment(FillingData)
	
	If Not ValueIsFilled(FillingData)
		OR Not Common.RefTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	Currency = FillingData.CashCurrency;
	OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
