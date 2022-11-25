#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties, Registers = Undefined) Export
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	FillInitializationParameters(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing, OperationKind = Undefined) Export
	
	If Data.Number = Null
		Or Not ValueIsFilled(Data.Number)
		Or Not ValueIsFilled(Data.Ref) Then
		
		If ValueIsFilled(Data.OperationKind) Then
			Presentation = DriveServerCall.TaxInvoiceIssuedGetTitle(Data.OperationKind);
		EndIf;
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If Data.Posted Then
		State = "";
	ElsIf Data.DeletionMark Then
		State = NStr("en = '(deleted)'; ru = '(удален)';pl = '(usunięty)';es_ES = '(borrado)';es_CO = '(borrado)';tr = '(silindi)';it = '(eliminato)';de = '(gelöscht)'");
	EndIf;
	
	If ValueIsFilled(Data.OperationKind) Then
		TitlePresentation = Documents.TaxInvoiceIssued.GetTitle(Data.OperationKind);
	EndIf;
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 dated %3 %4'; ru = '%1 %2 от %3 %4';pl = '%1 %2 z dn. %3 %4';es_ES = '%1 %2 fechado %3 %4';es_CO = '%1 %2 fechado %3 %4';tr = '%1 %2 tarihli %3 %4';it = '%1 %2 con data %3 %4';de = '%1 %2 datiert %3 %4'"),
		TitlePresentation,
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		State);
	
EndProcedure

// Gets Tax invoice for basis document
//
// Parameters:
//	BasisDocument - DocumentRef - basis document of tax invoice.
//
// Returns:
//	DocumentRef.TaxInvoiceIssue - an empty reference if there is no Tax Invoice.
//
Function GetTaxInvoiceIssued(BasisDocument) Export
	
	TaxInvoice = Documents.TaxInvoiceIssued.EmptyRef();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED DISTINCT
	|	TaxInvoiceIssuedBasisDocuments.Ref AS Ref
	|INTO TaxInvoiceTempTable
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|WHERE
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TaxInvoiceIssued.Ref AS Ref
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		INNER JOIN TaxInvoiceTempTable AS TaxInvoiceTempTable
	|		ON TaxInvoiceIssued.Ref = TaxInvoiceTempTable.Ref
	|WHERE
	|	NOT TaxInvoiceIssued.DeletionMark";
	
	Query.SetParameter("BasisDocument", BasisDocument);
	
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		SelectionResult = QueryResult.Select();
		If SelectionResult.Next() Then
			TaxInvoice = SelectionResult.Ref;
		EndIf;
	EndIf;
	
	Return TaxInvoice;
	
EndFunction

#Region Presentation

// Function returns the Title for invoice.
//
// Parameters:
//	OperationKind - Enum.OperationTypesTaxInvoiceReceived - Operation in invoice.
//	ThisIsNewInvoice - Boolean - Shows what this is a new invoice.
//
// ReturnedValue:
//	String - Title for Tax invoice.
//
Function GetTitle(OperationKind, ThisIsNewInvoice = False) Export
	
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		TitlePresentation = NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'");
	Else
		TitlePresentation = NStr("en = 'Tax invoice issued'; ru = 'Налоговый инвойс выданный';pl = 'Wystawiona faktura VAT';es_ES = 'Factura de impuestos emitida';es_CO = 'Factura fiscal emitida';tr = 'Düzenlenen vergi faturası';it = 'Fattura fiscale emessa';de = 'Steuerrechnung ausgestellt'");
	EndIf;
	
	If ThisIsNewInvoice Then
		TitlePresentation = TitlePresentation + " " + NStr("en = '(Create)'; ru = '(Создание)';pl = '(Tworzenie)';es_ES = '(Crear)';es_CO = '(Crear)';tr = '(Oluştur)';it = '(Crea)';de = '(Erstellen)'");
	EndIf;
	
	Return TitlePresentation;
	
EndFunction

#EndRegion

#Region InfobaseUpdate

Procedure VATRegistersEntriesReGeneration() Export
	
	Query = New Query;
	Query.Text =
	"SELECT DISTINCT
	|	TaxInvoiceIssued.Ref AS Ref,
	|	TaxInvoiceIssued.Company AS Company,
	|	TaxInvoiceIssued.Date AS Date
	|INTO TT_Data
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|		LEFT JOIN AccumulationRegister.VATOutput AS VATOutput
	|		ON TaxInvoiceIssued.Ref = VATOutput.Recorder
	|WHERE
	|	TaxInvoiceIssued.Posted
	|	AND TaxInvoiceIssued.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.SalesReturn)
	|	AND VATOutput.ShipmentDocument = UNDEFINED
	|	AND NOT VATOutput.Recorder IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(AccountingPolicy.Period) AS Period,
	|	AccountingPolicy.Company AS Company
	|INTO TT_MaxPeriod
	|FROM
	|	TT_Data AS TT_Data
	|		INNER JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON TT_Data.Company = AccountingPolicy.Company
	|			AND (AccountingPolicy.Period <= TT_Data.Date)
	|
	|GROUP BY
	|	AccountingPolicy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Data.Ref AS Ref,
	|	TT_Data.Date AS Date,
	|	TT_Data.Company AS Company,
	|	AccountingPolicy.RegisteredForVAT AS RegisteredForVAT
	|FROM
	|	TT_Data AS TT_Data
	|		INNER JOIN TT_MaxPeriod AS TT_MaxPeriod
	|		ON TT_Data.Company = TT_MaxPeriod.Company
	|		INNER JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
	|		ON (TT_MaxPeriod.Company = AccountingPolicy.Company)
	|			AND (TT_MaxPeriod.Period = AccountingPolicy.Period)
	|TOTALS
	|	MAX(RegisteredForVAT)
	|BY
	|	Company,
	|	Date";
	
	CompanySelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While CompanySelection.Next() Do
		
		DateCompanySelection = CompanySelection.Select(QueryResultIteration.ByGroups);
		While DateCompanySelection.Next() Do
			
			If DateCompanySelection.RegisteredForVAT Then
				
				Selection = DateCompanySelection.Select();
				While Selection.Next() Do
					
					DocObject = Selection.Ref.GetObject();
					InfobaseUpdateDrive.VATRegistersEntriesReGeneration(DocObject);
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion 

#EndIf

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("OperationKind");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ListForm" Then
			StandardProcessing = False;
			SelectedForm = "ListFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndIf

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

#Region LibrariesHandlers

#Region Print

// Fills printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "TaxInvoice";
	PrintCommand.Presentation = NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = True;
	PrintCommand.Order = 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "AdvancePaymentInvoice";
	PrintCommand.Presentation = NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'");
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 2;
	
EndProcedure

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
		
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "TaxInvoice") Then
		
		SpreadsheetDocument = DataProcessors.PrintTaxInvoice.PrintForm(ObjectsArray, PrintObjects, "TaxInvoice", PrintParameters.Result);
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"TaxInvoice",
			NStr("en = 'Tax invoice'; ru = 'Налоговый инвойс';pl = 'Faktura VAT';es_ES = 'Factura de impuestos';es_CO = 'Factura fiscal';tr = 'Vergi faturası';it = 'Fattura fiscale';de = 'Steuerrechnung'"),
			SpreadsheetDocument);
			
	ElsIf PrintManagement.TemplatePrintRequired(PrintFormsCollection, "AdvancePaymentInvoice") Then
			
		SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
			ObjectsArray,
			PrintObjects,
			"AdvancePaymentInvoice",,PrintParameters.Result);
			
		PrintManagement.OutputSpreadsheetDocumentToCollection(
			PrintFormsCollection,
			"AdvancePaymentInvoice",
			NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'"),
			SpreadsheetDocument);
			
	EndIf;
		
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#Region MessageTemplates

// StandardSubsystems.MessageTemplates

// It is called when preparing message templates and allows you to override a list of attributes and attachments.
//
// Parameters:
//  Attributes - ValueTree - a list of template attributes.
//    * Name            - String - a unique name of a common attribute.
//    * Presentation  - String - a common attribute presentation.
//    * Type            - Type - an attribute type. It is a string by default.
//    * Format         - String - a value output format for numbers, dates, strings, and boolean values.
//  Attachments - ValueTable - print forms and attachments, where:
//    * Name           - String - a unique attachment name.
//    * Presentation - String - an option presentation.
//    * FileType      - String - an attachment type that matches the file extension: pdf, png, jpg, mxl, and so on.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnPrepareMessageTemplate(Attributes, Attachments, AdditionalParameters) Export
	
EndProcedure

// It is called upon creating messages from template to fill in values of attributes and attachments.
//
// Parameters:
//  Message - Structure - a structure with the following keys:
//    * AttributesValues - Map - a list of attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * CommonAttributesValues - Map - a list of common attributes used in the template.
//      ** Key     - String - an attribute name in the template.
//      ** Value - String - a filling value in the template.
//    * Attachments - Map - attribute values
//      ** Key     - String - an attachment name in the template.
//      ** Value - BinaryData, String - binary data or an address in a temporary storage of the attachment.
//    * AdditionalParameters - Structure - additional message parameters.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//  AdditionalParameters - Structure - additional information on the message template.
//
Procedure OnCreateMessage(Message, MessageSubject, AdditionalParameters) Export
	
EndProcedure

// Fills in a list of text message recipients when sending a message generated from template.
//
// Parameters:
//   SMSMessageRecipients - ValueTable - a list of text message recipients.
//     * PhoneNumber - String - a phone number to send a text message to.
//     * Presentation - String - a text message recipient presentation.
//     * Contact       - Arbitrary - a contact that owns the phone number.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsPhonesInMessage(SMSMessageRecipients, MessageSubject) Export
	
EndProcedure

// Fills in a list of email recipients upon sending a message generated from a template.
//
// Parameters:
//   MailRecipients - ValueTable - a list of mail recipients.
//     * Address           - String - a recipient email address.
//     * Presentation   - String - an email recipient presentation.
//     * Contact         - Arbitrary - a contact that owns the email address.
//  MessageSubject - AnyRef - a reference to an object that is a data source.
//                   - Structure  - a structure describing template parameters:
//    * Subject               - AnyRef - a reference to an object that is a data source.
//    * ArbitraryParameters - Map - a filled list of arbitrary parameters.
//
Procedure OnFillRecipientsEmailsInMessage(EmailRecipients, MessageSubject) Export
	
EndProcedure

// End StandardSubsystems.MessageTemplates

#EndRegion

// StandardSubsystems.Interactions

// Get counterparty and contact persons.
//
// Parameters:
//  Subject  - DocumentRef.GoodsIssue - the document whose contacts you need to get.
//
// Returns:
//   Array   - array of contacts.
// 
Function GetContacts(Subject) Export
	
	If Not ValueIsFilled(Subject) Then
		Return New Array;
	EndIf;
	
	Return DriveContactInformationServer.GetContactsRefs(Subject);
	
EndFunction

// End StandardSubsystems.Interactions

#EndRegion

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

Procedure FillInitializationParameters(DocumentRef, StructureAdditionalProperties)
		
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("Ref"                  , DocumentRef);
	Query.SetParameter("PointInTime"          , New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("PresentationCurrency" , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency"         , DocumentRef.Currency);
	Query.SetParameter("Company"              , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod"   ,	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text = 
	"SELECT
	|	TaxInvoiceIssuedHeader.Ref AS Ref,
	|	TaxInvoiceIssuedHeader.Date AS Date,
	|	TaxInvoiceIssuedHeader.Number AS Number,
	|	TaxInvoiceIssuedHeader.Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty AS Counterparty,
	|	TaxInvoiceIssuedHeader.Currency AS Currency,
	|	TaxInvoiceIssuedHeader.Date AS Period,
	|	TaxInvoiceIssuedHeader.Department AS Department,
	|	TaxInvoiceIssuedHeader.Responsible AS Responsible,
	|	TaxInvoiceIssuedHeader.OperationKind AS OperationKind
	|INTO TaxInvoiceIssuedHeader
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssuedHeader
	|WHERE
	|	TaxInvoiceIssuedHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	Header.OperationKind AS OperationKind
	|INTO BasisDocuments
	|FROM
	|	TaxInvoiceIssuedHeader AS Header
	|		INNER JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
	|		ON Header.Ref = BasisDocuments.Ref
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	CreditNoteHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	CreditNoteHeader.BasisDocument AS SourceDocument,
	|	CreditNoteHeader.VATRate AS VATRate,
	|	CreditNoteHeader.DocumentCurrency AS DocumentCurrency,
	|	CreditNoteHeader.VATTaxation AS VATTaxation,
	|	CreditNoteHeader.Date AS Date,
	|	CreditNoteHeader.VATAmount AS VATAmount,
	|	CreditNoteHeader.DocumentAmount AS DocumentAmount
	|INTO BasisDocumentsCreditNotes
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CreditNote AS CreditNoteHeader
	|		ON BasisDocuments.BasisDocument = CreditNoteHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ExchangeRate.Currency AS Currency,
	|	ExchangeRate.Rate AS ExchangeRate,
	|	ExchangeRate.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &CashCurrency)
	|				AND Company = &Company) AS ExchangeRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	CashReceiptHeader.CashCurrency AS CashCurrency,
	|	CashReceiptHeader.Date AS Date,
	|	CashReceiptHeader.Company AS Company,
	|	CashReceiptHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CashReceiptHeader.Counterparty AS Counterparty,
	|	CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	(CAST(Payments.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) - (CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsCashReceipt
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashReceipt.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.CashReceipt AS CashReceiptHeader
	|		ON BasisDocuments.BasisDocument = CashReceiptHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND Payments.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	PaymentReceiptHeader.CashCurrency AS CashCurrency,
	|	PaymentReceiptHeader.Date AS Date,
	|	PaymentReceiptHeader.Company AS Company,
	|	PaymentReceiptHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentReceiptHeader.Counterparty AS Counterparty,
	|	CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	(CAST(Payments.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) - (CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsPaymentReceipt
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentReceipt.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.PaymentReceipt AS PaymentReceiptHeader
	|		ON BasisDocuments.BasisDocument = PaymentReceiptHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND Payments.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	OnlineReceiptHeader.CashCurrency AS CashCurrency,
	|	OnlineReceiptHeader.Date AS Date,
	|	OnlineReceiptHeader.Company AS Company,
	|	OnlineReceiptHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	OnlineReceiptHeader.Counterparty AS Counterparty,
	|	CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	(CAST(Payments.PaymentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) - (CAST(Payments.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))) AS PaymentAmount,
	|	BasisDocuments.OperationKind AS OperationKind
	|INTO BasisDocumentsOnlineReceipt
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.OnlineReceipt.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.OnlineReceipt AS OnlineReceiptHeader
	|		ON BasisDocuments.BasisDocument = OnlineReceiptHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND Payments.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SalesInvoiceHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	SalesInvoiceHeader.Date AS Date,
	|	SalesInvoiceHeader.Company AS Company,
	|	SalesInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SalesInvoiceHeader.Counterparty AS Counterparty
	|INTO BasisDocumentsSalesInvoices
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SalesInvoice AS SalesInvoiceHeader
	|		ON BasisDocuments.BasisDocument = SalesInvoiceHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SalesInvoices.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoices.Date AS Date,
	|	SalesInvoices.Company AS Company,
	|	SalesInvoices.CompanyVATNumber AS CompanyVATNumber,
	|	SalesInvoices.PresentationCurrency AS PresentationCurrency,
	|	SalesInvoices.Counterparty AS Counterparty,
	|	SalesInvoices.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO SalesInvoicesPrepaymentVAT
	|FROM
	|	BasisDocumentsSalesInvoices AS SalesInvoices
	|		INNER JOIN Document.SalesInvoice.PrepaymentVAT AS Prepayment
	|		ON SalesInvoices.BasisDocument = Prepayment.Ref
	|WHERE
	|	SalesInvoices.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SalesInvoices.DocumentCurrency,
	|	SalesInvoices.Date,
	|	SalesInvoices.Company,
	|	SalesInvoices.CompanyVATNumber,
	|	SalesInvoices.PresentationCurrency,
	|	SalesInvoices.Counterparty,
	|	SalesInvoices.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS BasisRef,
	|	Inventory.VATRate AS VATRate,
	|	SalesInvoices.DocumentCurrency AS DocumentCurrency,
	|	SalesInvoices.Date AS Date,
	|	CAST(Inventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SalesInvoices.IncludeVATInPrice
	|				THEN Inventory.Total
	|			ELSE Inventory.Total - Inventory.VATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountExcludesVAT,
	|	TaxInvoiceIssuedHeader.Company AS Company,
	|	TaxInvoiceIssuedHeader.PresentationCurrency AS PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty AS Customer,
	|	CASE
	|		WHEN SalesInvoices.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR SalesInvoices.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	CatalogProducts.ProductsType AS ProductType,
	|	TaxInvoiceIssuedHeader.Period AS Period
	|INTO BasisDocumentsData
	|FROM
	|	BasisDocumentsSalesInvoices AS SalesInvoices
	|		INNER JOIN Document.SalesInvoice.Inventory AS Inventory
	|		ON SalesInvoices.BasisDocument = Inventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|
	|UNION ALL
	|
	|SELECT
	|	CASE
	|		WHEN SalesSlip.Ref IS NULL
	|			THEN CreditNoteInventory.SalesDocument
	|		ELSE SalesSlip.CashCRSession
	|	END,
	|	CreditNoteInventory.VATRate,
	|	CreditNoteHeader.DocumentCurrency,
	|	CreditNoteHeader.Date,
	|	-(CAST(CreditNoteInventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((CreditNoteInventory.Total - CreditNoteInventory.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.SalesReturn)
	|	END,
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNoteHeader
	|		INNER JOIN Document.CreditNote.Inventory AS CreditNoteInventory
	|		ON CreditNoteHeader.BasisDocument = CreditNoteInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (CreditNoteInventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|		LEFT JOIN Document.SalesSlip AS SalesSlip
	|		ON (CreditNoteInventory.SalesDocument = SalesSlip.Ref)
	|WHERE
	|	CreditNoteHeader.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.SalesReturn)
	|	AND (CreditNoteInventory.VATAmount <> 0
	|			OR CreditNoteInventory.Amount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.BasisDocument,
	|	CreditNote.VATRate,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.Date,
	|	-(CAST(CreditNote.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((CreditNote.DocumentAmount - CreditNote.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.OtherAdjustments)
	|	END,
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNote
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|WHERE
	|	CreditNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Adjustments)
	|
	|UNION ALL
	|
	|SELECT
	|	CreditNote.BasisDocument,
	|	CreditNote.VATRate,
	|	CreditNote.DocumentCurrency,
	|	CreditNote.Date,
	|	-(CAST(CreditNote.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((CreditNote.DocumentAmount - CreditNote.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceIssuedHeader.Company,
	|	TaxInvoiceIssuedHeader.PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty,
	|	CASE
	|		WHEN CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR CreditNote.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.DiscountAllowed)
	|	END,
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceIssuedHeader.Period
	|FROM
	|	BasisDocumentsCreditNotes AS CreditNote
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|WHERE
	|	CreditNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.DiscountAllowed)";
	
	// begin Drive.FullVersion
	
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter() +
	"SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SubcontractorInvoiceIssuedHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SubcontractorInvoiceIssuedHeader.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoiceIssuedHeader.VATTaxation AS VATTaxation,
	|	SubcontractorInvoiceIssuedHeader.Date AS Date,
	|	SubcontractorInvoiceIssuedHeader.Company AS Company,
	|	SubcontractorInvoiceIssuedHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceIssuedHeader.Counterparty AS Counterparty
	|INTO BasisDocumentsSubcontractorInvoicesIssued
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SubcontractorInvoiceIssued AS SubcontractorInvoiceIssuedHeader
	|		ON BasisDocuments.BasisDocument = SubcontractorInvoiceIssuedHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SubcontractorInvoicesIssued.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoicesIssued.Date AS Date,
	|	SubcontractorInvoicesIssued.Company AS Company,
	|	SubcontractorInvoicesIssued.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoicesIssued.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoicesIssued.Counterparty AS Counterparty,
	|	SubcontractorInvoicesIssued.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO SubcontractorInvoicesIssuedPrepaymentVAT
	|FROM
	|	BasisDocumentsSubcontractorInvoicesIssued AS SubcontractorInvoicesIssued
	|		INNER JOIN Document.SubcontractorInvoiceIssued.PrepaymentVAT AS Prepayment
	|		ON SubcontractorInvoicesIssued.BasisDocument = Prepayment.Ref
	|WHERE
	|	SubcontractorInvoicesIssued.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SubcontractorInvoicesIssued.DocumentCurrency,
	|	SubcontractorInvoicesIssued.Date,
	|	SubcontractorInvoicesIssued.Company,
	|	SubcontractorInvoicesIssued.CompanyVATNumber,
	|	SubcontractorInvoicesIssued.PresentationCurrency,
	|	SubcontractorInvoicesIssued.Counterparty,
	|	SubcontractorInvoicesIssued.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SubcontractorInvoiceIssuedProducts.Ref AS BasisRef,
	|	SubcontractorInvoiceIssuedProducts.VATRate AS VATRate,
	|	SubcontractorInvoicesIssued.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoicesIssued.Date AS Date,
	|	CAST(SubcontractorInvoiceIssuedProducts.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN SubcontractorInvoicesIssued.IncludeVATInPrice
	|				THEN SubcontractorInvoiceIssuedProducts.Total
	|			ELSE SubcontractorInvoiceIssuedProducts.Total - SubcontractorInvoiceIssuedProducts.VATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS AmountExcludesVAT,
	|	TaxInvoiceIssuedHeader.Company AS Company,
	|	TaxInvoiceIssuedHeader.PresentationCurrency AS PresentationCurrency,
	|	TaxInvoiceIssuedHeader.Counterparty AS Customer,
	|	CASE
	|		WHEN SubcontractorInvoicesIssued.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport)
	|				OR SubcontractorInvoicesIssued.VATTaxation = VALUE(Enum.VATTaxationTypes.ReverseChargeVAT)
	|			THEN VALUE(Enum.VATOperationTypes.Export)
	|		ELSE VALUE(Enum.VATOperationTypes.Sales)
	|	END AS OperationType,
	|	CatalogProducts.ProductsType AS ProductType,
	|	TaxInvoiceIssuedHeader.Period AS Period
	|INTO AdditionBasisDocumentsData
	|FROM
	|	BasisDocumentsSubcontractorInvoicesIssued AS SubcontractorInvoicesIssued
	|		INNER JOIN Document.SubcontractorInvoiceIssued.Products AS SubcontractorInvoiceIssuedProducts
	|		ON SubcontractorInvoicesIssued.BasisDocument = SubcontractorInvoiceIssuedProducts.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (SubcontractorInvoiceIssuedProducts.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceIssuedHeader AS TaxInvoiceIssuedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)";
	
	// end Drive.FullVersion 
	
	Query.ExecuteBatch();
	
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

#Region TableGeneration

Procedure GenerateTableVATOutput(DocumentRefTaxInvoiceIssued, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	DocumentsData.BasisRef AS ShipmentDocument,
	|	DocumentsData.VATRate AS VATRate,
	|	SUM(DocumentsData.VATAmount) AS VATAmount,
	|	SUM(DocumentsData.AmountExcludesVAT) AS AmountExcludesVAT,
	|	DocumentsData.Company AS Company,
	|	DocumentsData.BasisRef.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentsData.PresentationCurrency AS PresentationCurrency,
	|	DocumentsData.Customer AS Customer,
	|	&VATOutput AS GLAccount,
	|	DocumentsData.OperationType AS OperationType,
	|	DocumentsData.ProductType AS ProductType,
	|	DocumentsData.Period AS Period
	|FROM
	|	BasisDocumentsData AS DocumentsData
	|
	|GROUP BY
	|	DocumentsData.Customer,
	|	DocumentsData.OperationType,
	|	DocumentsData.ProductType,
	|	DocumentsData.VATRate,
	|	DocumentsData.Period,
	|	DocumentsData.Company,
	|	DocumentsData.BasisRef.CompanyVATNumber,
	|	DocumentsData.PresentationCurrency,
	|	DocumentsData.BasisRef
	|
	|UNION ALL
	|
	|SELECT
	|	CashReceiptPayments.BasisDocument,
	|	CashReceiptPayments.VATRate,
	|	CashReceiptPayments.VATAmount,
	|	CashReceiptPayments.PaymentAmount,
	|	CashReceiptPayments.Company,
	|	CashReceiptPayments.CompanyVATNumber,
	|	CashReceiptPayments.PresentationCurrency,
	|	CashReceiptPayments.Counterparty,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	CashReceiptPayments.Date
	|FROM
	|	BasisDocumentsCashReceipt AS CashReceiptPayments
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentReceiptPayments.BasisDocument,
	|	PaymentReceiptPayments.VATRate,
	|	PaymentReceiptPayments.VATAmount,
	|	PaymentReceiptPayments.PaymentAmount,
	|	PaymentReceiptPayments.Company,
	|	PaymentReceiptPayments.CompanyVATNumber,
	|	PaymentReceiptPayments.PresentationCurrency,
	|	PaymentReceiptPayments.Counterparty,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PaymentReceiptPayments.Date
	|FROM
	|	BasisDocumentsPaymentReceipt AS PaymentReceiptPayments
	|
	|UNION ALL
	|
	|SELECT
	|	OnlineReceiptPayments.BasisDocument,
	|	OnlineReceiptPayments.VATRate,
	|	OnlineReceiptPayments.VATAmount,
	|	OnlineReceiptPayments.PaymentAmount,
	|	OnlineReceiptPayments.Company,
	|	OnlineReceiptPayments.CompanyVATNumber,
	|	OnlineReceiptPayments.PresentationCurrency,
	|	OnlineReceiptPayments.Counterparty,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	OnlineReceiptPayments.Date
	|FROM
	|	BasisDocumentsOnlineReceipt AS OnlineReceiptPayments
	|
	|UNION ALL
	|
	|SELECT
	|	PrepaymentVAT.ShipmentDocument,
	|	PrepaymentVAT.VATRate,
	|	-PrepaymentVAT.VATAmount,
	|	-PrepaymentVAT.AmountExcludesVAT,
	|	PrepaymentVAT.Company,
	|	PrepaymentVAT.CompanyVATNumber,
	|	PrepaymentVAT.PresentationCurrency,
	|	PrepaymentVAT.Counterparty,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	SalesInvoicesPrepaymentVAT AS PrepaymentVAT";
	
	// begin Drive.FullVersion
	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
	"SELECT
	|	DocumentsData.BasisRef AS ShipmentDocument,
	|	DocumentsData.VATRate AS VATRate,
	|	SUM(DocumentsData.VATAmount) AS VATAmount,
	|	SUM(DocumentsData.AmountExcludesVAT) AS AmountExcludesVAT,
	|	DocumentsData.Company AS Company,
	|	DocumentsData.BasisRef.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentsData.PresentationCurrency AS PresentationCurrency,
	|	DocumentsData.Customer AS Customer,
	|	&VATOutput AS GLAccount,
	|	DocumentsData.OperationType AS OperationType,
	|	DocumentsData.ProductType AS ProductType,
	|	DocumentsData.Period AS Period
	|FROM
	|	AdditionBasisDocumentsData AS DocumentsData
	|
	|GROUP BY
	|	DocumentsData.Customer,
	|	DocumentsData.OperationType,
	|	DocumentsData.ProductType,
	|	DocumentsData.VATRate,
	|	DocumentsData.Period,
	|	DocumentsData.Company,
	|	DocumentsData.BasisRef.CompanyVATNumber,
	|	DocumentsData.PresentationCurrency,
	|	DocumentsData.BasisRef
	|
	|UNION ALL
	|
	|SELECT
	|	PrepaymentVAT.ShipmentDocument,
	|	PrepaymentVAT.VATRate,
	|	-PrepaymentVAT.VATAmount,
	|	-PrepaymentVAT.AmountExcludesVAT,
	|	PrepaymentVAT.Company,
	|	PrepaymentVAT.CompanyVATNumber,
	|	PrepaymentVAT.PresentationCurrency,
	|	PrepaymentVAT.Counterparty,
	|	&VATOutput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	SubcontractorInvoicesIssuedPrepaymentVAT AS PrepaymentVAT";
	
	// end Drive.FullVersion 
	
	Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefTaxInvoiceIssued, StructureAdditionalProperties)
	
	If Not StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Date",						StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("ContentVATOnAdvance",		NStr("en = 'VAT on advance'; ru = 'НДС с авансов';pl = 'VAT z zaliczek';es_ES = 'IVA del anticipo';es_CO = 'IVA del anticipo';tr = 'Avans KDV''si';it = 'IVA sull''anticipo';de = 'USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",			NStr("en = 'Deduction of VAT on advance payment'; ru = 'Удержание НДС с аванса';pl = 'Odliczenie podatku VAT od zaliczki';es_ES = 'Deducción del IVA del pago anticipado';es_CO = 'Deducción del IVA del pago anticipado';tr = 'Avans ödemede KDV kesintisi';it = 'Deduzione IVA caricata sul pagamento anticipato';de = 'Abzug der USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&VATAdvancesFromCustomers AS AccountDr,
	|	&VATOutput AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	SUM(DocumentTable.VATAmount) AS Amount,
	|	&ContentVATOnAdvance AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	BasisDocumentsCashReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND NOT &PostAdvancePaymentsBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesFromCustomers,
	|	&VATOutput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	BasisDocumentsPaymentReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND NOT &PostAdvancePaymentsBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATAdvancesFromCustomers,
	|	&VATOutput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	BasisDocumentsOnlineReceipt AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.AdvancePayment)
	|	AND NOT &PostAdvancePaymentsBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATOutput,
	|	&VATAdvancesFromCustomers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SalesInvoicesPrepaymentVAT AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company";
	
	// begin Drive.FullVersion
	
	Query.Text = Query.Text + DriveClientServer.GetQueryUnion() +
	"SELECT
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	&VATOutput,
	|	&VATAdvancesFromCustomers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SubcontractorInvoicesIssuedPrepaymentVAT AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceIssued.Sale)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company";
	
	// end Drive.FullVersion 
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#EndIf
