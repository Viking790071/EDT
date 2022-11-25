#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region LibrariesHandlers

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
	
	FillInParametersOfElectronicMail = True;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "Quote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "Quote", 
            NStr("en = 'Quote'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'"), 
            DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, "Quote", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "QuoteAllVariants") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "QuoteAllVariants", 
            NStr("en = 'Quotation (all variants)'; ru = 'Коммерческое предложение (все варианты)';pl = 'Oferta cenowa (wszystkie warianty)';es_ES = 'Presupuesto (todas las variantes)';es_CO = 'Presupuesto (todas las variantes)';tr = 'Teklif (tüm varyantlar)';it = 'Preventivo (tutte le varianti)';de = 'Angebot (alle Varianten)'"), 
            DataProcessors.PrintQuote.PrintQuote(ObjectsArray, PrintObjects, "QuoteAllVariants", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProformaInvoice") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection, 
            "ProformaInvoice", 
            NStr("en = 'Proforma invoice'; ru = 'Проформа-инвойс';pl = 'Faktura proforma';es_ES = 'Factura proforma';es_CO = 'Factura proforma';tr = 'Proforma fatura';it = 'Fattura proforma';de = 'Proforma-Rechnung'"), 
            DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoice", PrintParameters.Result));
	EndIf;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "ProformaInvoiceAllVariants") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(
            PrintFormsCollection,
            "ProformaInvoiceAllVariants", 
            NStr("en = 'Proforma invoice (all variants)'; ru = 'Проформа-инвойс (все варианты)';pl = 'Faktura proforma (wszystkie warianty)';es_ES = 'Factura proforma (todas las variantes)';es_CO = 'Factura proforma (todas las variantes)';tr = 'Proforma fatura (tüm varyantlar)';it = 'Fattura proforma (tutte le varianti)';de = 'Proforma-Rechnung (alle Varianten)'"), 
            DataProcessors.PrintQuote.PrintProformaInvoice(ObjectsArray, PrintObjects, "ProformaInvoiceAllVariants", PrintParameters.Result));
	EndIf;
	
	// parameters of sending printing forms by email
	If FillInParametersOfElectronicMail Then
		DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	EndIf;
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "Quote";
	PrintCommand.Presentation				= NStr("en = 'Quotation'; ru = 'Коммерческое предложение';pl = 'Oferta cenowa';es_ES = 'Presupuesto';es_CO = 'Presupuesto';tr = 'Teklif';it = 'Preventivo';de = 'Angebot'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 1;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "QuoteAllVariants";
	PrintCommand.Presentation				= NStr("en = 'Quotation (all variants)'; ru = 'Коммерческое предложение (все варианты)';pl = 'Oferta cenowa (wszystkie warianty)';es_ES = 'Presupuesto (todas las variantes)';es_CO = 'Presupuesto (todas las variantes)';tr = 'Teklif (tüm varyantlar)';it = 'Preventivo (tutte le varianti)';de = 'Angebot (alle Varianten)'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 2;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoice";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice'; ru = 'Проформа-инвойс';pl = 'Faktura proforma';es_ES = 'Factura proforma';es_CO = 'Factura proforma';tr = 'Proforma fatura';it = 'Fattura proforma';de = 'Proforma-Rechnung'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 3;
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "ProformaInvoiceAllVariants";
	PrintCommand.Presentation				= NStr("en = 'Proforma invoice (all variants)'; ru = 'Проформа-инвойс (все варианты)';pl = 'Faktura proforma (wszystkie warianty)';es_ES = 'Factura proforma (todas las variantes)';es_CO = 'Factura proforma (todas las variantes)';tr = 'Proforma fatura (tüm varyantlar)';it = 'Fattura proforma (tutte le varianti)';de = 'Proforma-Rechnung (alle Varianten)'");
	PrintCommand.FormsList					= "DocumentForm,ListForm,DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= True;
	PrintCommand.Order						= 4;
	
EndProcedure

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

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	Quote.Ref AS Ref,
	|	Quote.Company AS Company,
	|	Quote.Counterparty AS Counterparty,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CAST(Quote.DocumentAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN Quote.ExchangeRate / Quote.Multiplicity
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN Quote.Multiplicity / Quote.ExchangeRate
	|		END AS NUMBER(15, 2)) AS Amount,
	|	Quote.Date AS Period
	|INTO TemporaryTableHeader
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref = &Ref";
	
	Query.ExecuteBatch();
	
	// Register record table creation
	GenerateTableQuotations(DocumentRef, StructureAdditionalProperties);
	
EndProcedure

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	GLAccountsForFilling = New Structure;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#EndRegion

#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	User = Users.CurrentUser();
	
	If TypeOf(User) = Type("CatalogRef.ExternalUsers") Then
		If FormType = "ListForm" Then
			StandardProcessing = False;
			SelectedForm = "ListFormForExternalUsers";
		ElsIf FormType = "ChoiceForm" Then
			StandardProcessing = False;
			SelectedForm = "ChoiceFormForExternalUsers";
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableQuotations(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TableQuotations.Ref AS Quotation,
	|	TableQuotations.Company AS Company,
	|	TableQuotations.Counterparty AS Counterparty,
	|	TableQuotations.PresentationCurrency AS PresentationCurrency,
	|	TableQuotations.Amount AS Amount,
	|	TableQuotations.Period AS Period
	|FROM
	|	TemporaryTableHeader AS TableQuotations";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableQuotations", QueryResult.Unload());
	
EndProcedure

#EndRegion

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export 
	Return New Structure;
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Result = New Structure;
	If StructureData.TabName = "Inventory" Then
		Result.Insert("RevenueGLAccount", "RevenueItem");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure UpdateQuotationStatus() Export
	
	DefaultLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Quote.Ref AS Ref
	|INTO QuoteTable
	|FROM
	|	Document.Quote AS Quote
	|		LEFT JOIN InformationRegister.QuotationKanbanStatuses.SliceLast AS QuotationKanbanStatuses
	|		ON Quote.Ref = QuotationKanbanStatuses.Quotation
	|WHERE
	|	NOT Quote.DeletionMark
	|	AND ISNULL(QuotationKanbanStatuses.Status, VALUE(Catalog.QuotationStatuses.EmptyRef)) <> VALUE(Catalog.QuotationStatuses.Converted)
	|	AND ISNULL(QuotationKanbanStatuses.Status, VALUE(Catalog.QuotationStatuses.EmptyRef)) <> VALUE(Catalog.QuotationStatuses.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuoteTable.Ref AS Ref
	|INTO QuoteTableWithDocs
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN QuoteTable AS QuoteTable
	|		ON SalesInvoice.BasisDocument = QuoteTable.Ref
	|WHERE
	|	SalesInvoice.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	QuoteTable.Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		INNER JOIN QuoteTable AS QuoteTable
	|		ON SalesOrder.BasisDocument = QuoteTable.Ref
	|WHERE
	|	SalesOrder.Posted
	|
	|UNION ALL
	|
	|SELECT
	|	QuoteTable.Ref
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN QuoteTable AS QuoteTable
	|		ON WorkOrder.BasisDocument = QuoteTable.Ref
	|WHERE
	|	WorkOrder.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	QuoteTableWithDocs.Ref AS Ref
	|FROM
	|	QuoteTableWithDocs AS QuoteTableWithDocs";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		BeginTransaction();
		
		Try
			
			QuotationStatuses.SetQuotationStatus(Selection.Ref, Catalogs.QuotationStatuses.Converted);
			
			CommitTransaction();
			
		Except
			
			RollbackTransaction();
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot update status of document ""%1"". Details: %2'; ru = 'Не удалось обновить статус документа ""%1"". Подробнее: %2';pl = 'Nie można zaktualizować statusu dokumentu ""%1"". Szczegóły: %2';es_ES = 'No se ha podido actualizar el estado del documento ""%1"". Detalles: %2';es_CO = 'No se ha podido actualizar el estado del documento ""%1"". Detalles: %2';tr = '""%1"" belgesinin durumu güncellenemiyor. Ayrıntılar: %2';it = 'Impossibile aggiornare lo stato del documento ""%1"". Dettagli: %2';de = 'Aktualisieren des Status des Dokuments ""%1"" fehlgeschlagen. Details: %2'", DefaultLanguageCode),
				Selection.Ref,
				BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(NStr("en = 'Infobase update'; ru = 'Обновление информационной базы';pl = 'Aktualizacja bazy informacyjnej';es_ES = 'Actualización de la infobase';es_CO = 'Actualización de la infobase';tr = 'Infobase güncellemesi';it = 'Aggiornamento infobase';de = 'Infobase-Aktualisierung'", DefaultLanguageCode),
				EventLogLevel.Error,
				Metadata.InformationRegisters.QuotationKanbanStatuses,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf