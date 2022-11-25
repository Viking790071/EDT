#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties, Registers = Undefined) Export
	
	FillInitializationParameters(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefTaxInvoiceReceived, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsVATIncurredChange Then
		
		Query = New Query;
		
		Query.Text = AccumulationRegisters.VATIncurred.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		Result = Query.Execute();
		
		If Not Result.IsEmpty() Then
			DocumentObjectTaxInvoiceReceived = DocumentRefTaxInvoiceReceived.GetObject();
			QueryResultSelection = Result.Select();
			DriveServer.ShowMessageAboutPostingToVATIncurredRegisterErrors(DocumentObjectTaxInvoiceReceived, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing, OperationKind = Undefined) Export
	
	If Data.Number = Null
		Or Not ValueIsFilled(Data.Number)
		Or Not ValueIsFilled(Data.Ref) Then
		
		If ValueIsFilled(Data.OperationKind) Then
			Presentation = DriveServerCall.TaxInvoiceReceivedGetTitle(Data.OperationKind);
		EndIf;
		
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If Data.Posted Then
		State = "";
	ElsIf Data.DeletionMark Then
		State = NStr("en = '(deleted)'; ru = '(удален)';pl = '(usunięty)';es_ES = '(borrado)';es_CO = '(borrado)';tr = '(silindi)';it = '(eliminato)';de = '(gelöscht)'");
	EndIf;
	
	TitlePresentation = DriveServerCall.TaxInvoiceReceivedGetTitle(Data.OperationKind);
	
	Presentation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 %2 dated %3 %4'; ru = '%1 %2 от %3 %4';pl = '%1 %2 z dn. %3 %4';es_ES = '%1 %2 fechado %3 %4';es_CO = '%1 %2 fechado %3 %4';tr = '%1 %2 tarihli %3 %4';it = '%1 %2 con data %3 %4';de = '%1 %2 datiert %3 %4'"),
		TitlePresentation,
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		State);
	
EndProcedure

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
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		TitlePresentation = NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago anticipado';es_CO = 'Factura del pago anticipado';tr = 'Avans ödeme faturası';it = 'Fattura pagamento di anticipo';de = 'Vorauszahlung Zahlung Rechnung'");
	Else
		TitlePresentation = NStr("en = 'Tax invoice received'; ru = 'Налоговый инвойс полученный';pl = 'Otrzymana faktura VAT';es_ES = 'Factura de impuestos recibida';es_CO = 'Factura fiscal recibida';tr = 'Alınan vergi faturası';it = 'Fattura fiscale ricevuta';de = 'Steuerrechnung erhalten'");
	EndIf;
	
	If ThisIsNewInvoice Then
		TitlePresentation = TitlePresentation + " " + NStr("en = '(Create)'; ru = '(Создание)';pl = '(Tworzenie)';es_ES = '(Crear)';es_CO = '(Crear)';tr = '(Oluştur)';it = '(Crea)';de = '(Erstellen)'");
	EndIf;
	
	Return TitlePresentation;
EndFunction

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
		
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

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
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);	
	
	Query.Text =
	"SELECT
	|	TaxInvoiceReceivedHeader.Ref AS Ref,
	|	TaxInvoiceReceivedHeader.Date AS Period,
	|	TaxInvoiceReceivedHeader.Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty AS Counterparty,
	|	TaxInvoiceReceivedHeader.Number AS Number,
	|	TaxInvoiceReceivedHeader.Currency AS Currency,
	|	TaxInvoiceReceivedHeader.Department AS Department,
	|	TaxInvoiceReceivedHeader.Responsible AS Responsible,
	|	TaxInvoiceReceivedHeader.OperationKind AS OperationKind
	|INTO TaxInvoiceReceivedHeader
	|FROM
	|	Document.TaxInvoiceReceived AS TaxInvoiceReceivedHeader
	|WHERE
	|	TaxInvoiceReceivedHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	Header.OperationKind AS OperationKind
	|INTO BasisDocuments
	|FROM
	|	TaxInvoiceReceivedHeader AS Header
	|		INNER JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
	|		ON Header.Ref = BasisDocuments.Ref
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentHeader.Date AS Date
	|INTO BasisDocumentsAllDates
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SupplierInvoice AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentExpense AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.DebitNote AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashVoucher AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.AdditionalExpenses AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SubcontractorInvoiceReceived AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentHeader.Date
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.ExpenseReport AS DocumentHeader
	|		ON BasisDocuments.BasisDocument = DocumentHeader.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	BasisDocumentsAllDates.Date AS Date
	|INTO BasisDocumentsDates
	|FROM
	|	BasisDocumentsAllDates AS BasisDocumentsAllDates
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocumentsDates.Date AS Date,
	|	ExchangeRate.Period AS Period,
	|	ExchangeRate.Currency AS Currency,
	|	ExchangeRate.Rate AS ExchangeRate,
	|	ExchangeRate.Repetition AS Multiplicity
	|INTO TableAllRates
	|FROM
	|	BasisDocumentsDates AS BasisDocumentsDates
	|		INNER JOIN InformationRegister.ExchangeRate AS ExchangeRate
	|		ON BasisDocumentsDates.Date >= ExchangeRate.Period
	|WHERE
	|	ExchangeRate.Currency IN (&PresentationCurrency, &CashCurrency)
	|	AND ExchangeRate.Company = &Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableAllRates.Date AS Date,
	|	TableAllRates.Currency AS Currency,
	|	MAX(TableAllRates.Period) AS Period
	|INTO TableRatesMaxPeriod
	|FROM
	|	TableAllRates AS TableAllRates
	|
	|GROUP BY
	|	TableAllRates.Date,
	|	TableAllRates.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableRatesMaxPeriod.Date AS Date,
	|	TableRatesMaxPeriod.Currency AS Currency,
	|	TableAllRates.ExchangeRate AS ExchangeRate,
	|	TableAllRates.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	TableRatesMaxPeriod AS TableRatesMaxPeriod
	|		INNER JOIN TableAllRates AS TableAllRates
	|		ON TableRatesMaxPeriod.Period = TableAllRates.Period
	|			AND TableRatesMaxPeriod.Currency = TableAllRates.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	DebitNoteHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	DebitNoteHeader.BasisDocument AS SourceDocument,
	|	DebitNoteHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DebitNoteHeader.VATRate AS VATRate,
	|	DebitNoteHeader.DocumentCurrency AS DocumentCurrency,
	|	DebitNoteHeader.Date AS Date,
	|	DebitNoteHeader.VATAmount AS VATAmount,
	|	DebitNoteHeader.DocumentAmount AS DocumentAmount
	|INTO BasisDocumentsDebitNotes
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.DebitNote AS DebitNoteHeader
	|		ON BasisDocuments.BasisDocument = DebitNoteHeader.Ref
	|WHERE
	|	DebitNoteHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	CashVoucherHeader.CashCurrency AS CashCurrency,
	|	CashVoucherHeader.Date AS Date,
	|	CashVoucherHeader.Company AS Company,
	|	CashVoucherHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	CashVoucherHeader.Counterparty AS Counterparty,
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
	|INTO BasisDocumentsCashVoucher
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashVoucher.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.CashVoucher AS CashVoucherHeader
	|		ON BasisDocuments.BasisDocument = CashVoucherHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND (CashVoucherHeader.Date = PC_ExchangeRates.Date)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND (CashVoucherHeader.Date = DC_ExchangeRates.Date)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	FALSE AS IncludeVATInPrice,
	|	Payments.VATRate AS VATRate,
	|	PaymentExpenseHeader.CashCurrency AS CashCurrency,
	|	PaymentExpenseHeader.Date AS Date,
	|	PaymentExpenseHeader.Company AS Company,
	|	PaymentExpenseHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	PaymentExpenseHeader.Counterparty AS Counterparty,
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
	|INTO BasisDocumentsPaymentExpense
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentExpense.PaymentDetails AS Payments
	|		ON BasisDocuments.BasisDocument = Payments.Ref
	|		INNER JOIN Document.PaymentExpense AS PaymentExpenseHeader
	|		ON BasisDocuments.BasisDocument = PaymentExpenseHeader.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND (PaymentExpenseHeader.Date = PC_ExchangeRates.Date)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND (PaymentExpenseHeader.Date = DC_ExchangeRates.Date)
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SupplierInvoiceHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SupplierInvoiceHeader.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoiceHeader.Date AS Date,
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty
	|INTO BasisDocumentsSupplierInvoices
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoiceHeader
	|		ON BasisDocuments.BasisDocument = SupplierInvoiceHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND (SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|			OR SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.NotSubjectToVAT)
	|			OR SupplierInvoiceHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.ForExport))
	|
	|INDEX BY
	|	BasisDocument,
	|	OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SupplierInvoices.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoices.Date AS Date,
	|	SupplierInvoices.Company AS Company,
	|	SupplierInvoices.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SupplierInvoices.Counterparty AS Counterparty,
	|	SupplierInvoices.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO SupplierInvoicesPrepaymentVAT
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.PrepaymentVAT AS Prepayment
	|		ON SupplierInvoices.BasisDocument = Prepayment.Ref
	|WHERE
	|	SupplierInvoices.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SupplierInvoices.DocumentCurrency,
	|	SupplierInvoices.Date,
	|	SupplierInvoices.Company,
	|	SupplierInvoices.CompanyVATNumber,
	|	SupplierInvoices.Counterparty,
	|	SupplierInvoices.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	ExpenseReportHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	ExpenseReportHeader.DocumentCurrency AS DocumentCurrency,
	|	ExpenseReportHeader.Date AS Date,
	|	ExpenseReportHeader.Company AS Company,
	|	ExpenseReportHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency
	|INTO BasisDocumentsExpenseReports
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.ExpenseReport AS ExpenseReportHeader
	|		ON BasisDocuments.BasisDocument = ExpenseReportHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND ExpenseReportHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument,
	|	OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	SubcontractorInvoiceReceivedHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SubcontractorInvoiceReceivedHeader.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoiceReceivedHeader.Date AS Date,
	|	SubcontractorInvoiceReceivedHeader.Company AS Company,
	|	SubcontractorInvoiceReceivedHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoiceReceivedHeader.Counterparty AS Counterparty
	|INTO BasisDocumentsSubcontractorInvoicesReceived
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.SubcontractorInvoiceReceived AS SubcontractorInvoiceReceivedHeader
	|		ON BasisDocuments.BasisDocument = SubcontractorInvoiceReceivedHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND SubcontractorInvoiceReceivedHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument,
	|	OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	SubcontractorInvoicesReceived.DocumentCurrency AS DocumentCurrency,
	|	SubcontractorInvoicesReceived.Date AS Date,
	|	SubcontractorInvoicesReceived.Company AS Company,
	|	SubcontractorInvoicesReceived.CompanyVATNumber AS CompanyVATNumber,
	|	SubcontractorInvoicesReceived.PresentationCurrency AS PresentationCurrency,
	|	SubcontractorInvoicesReceived.Counterparty AS Counterparty,
	|	SubcontractorInvoicesReceived.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO SubcontractorInvoicesReceivedPrepaymentVAT
	|FROM
	|	BasisDocumentsSubcontractorInvoicesReceived AS SubcontractorInvoicesReceived
	|		INNER JOIN Document.SubcontractorInvoiceReceived.PrepaymentVAT AS Prepayment
	|		ON SubcontractorInvoicesReceived.BasisDocument = Prepayment.Ref
	|WHERE
	|	SubcontractorInvoicesReceived.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	SubcontractorInvoicesReceived.DocumentCurrency,
	|	SubcontractorInvoicesReceived.Date,
	|	SubcontractorInvoicesReceived.Company,
	|	SubcontractorInvoicesReceived.CompanyVATNumber,
	|	SubcontractorInvoicesReceived.Counterparty,
	|	SubcontractorInvoicesReceived.OperationKind,
	|	SubcontractorInvoicesReceived.PresentationCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BasisDocuments.BasisDocument AS BasisDocument,
	|	BasisDocuments.OperationKind AS OperationKind,
	|	AdditionalExpensesHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	AdditionalExpensesHeader.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpensesHeader.Date AS Date,
	|	AdditionalExpensesHeader.Company AS Company,
	|	AdditionalExpensesHeader.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	AdditionalExpensesHeader.Counterparty AS Counterparty
	|INTO BasisDocumentsAdditionalExpenses
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.AdditionalExpenses AS AdditionalExpensesHeader
	|		ON BasisDocuments.BasisDocument = AdditionalExpensesHeader.Ref
	|WHERE
	|	BasisDocuments.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND AdditionalExpensesHeader.VATTaxation = VALUE(Enum.VATTaxationTypes.SubjectToVAT)
	|
	|INDEX BY
	|	BasisDocument,
	|	OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Ref AS Ref,
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.VATRate AS VATRate,
	|	AdditionalExpenses.DocumentCurrency AS DocumentCurrency,
	|	AdditionalExpenses.Date AS Date,
	|	AdditionalExpenses.Company AS Company,
	|	AdditionalExpenses.CompanyVATNumber AS CompanyVATNumber,
	|	AdditionalExpenses.PresentationCurrency AS PresentationCurrency,
	|	AdditionalExpenses.Counterparty AS Counterparty,
	|	AdditionalExpenses.OperationKind AS OperationKind,
	|	SUM(Prepayment.VATAmount) AS VATAmount,
	|	SUM(Prepayment.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO AdditionalExpensesPrepaymentVAT
	|FROM
	|	BasisDocumentsAdditionalExpenses AS AdditionalExpenses
	|		INNER JOIN Document.AdditionalExpenses.PrepaymentVAT AS Prepayment
	|		ON AdditionalExpenses.BasisDocument = Prepayment.Ref
	|WHERE
	|	AdditionalExpenses.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|
	|GROUP BY
	|	Prepayment.Ref,
	|	Prepayment.Document,
	|	Prepayment.VATRate,
	|	AdditionalExpenses.DocumentCurrency,
	|	AdditionalExpenses.Date,
	|	AdditionalExpenses.Company,
	|	AdditionalExpenses.CompanyVATNumber,
	|	AdditionalExpenses.PresentationCurrency,
	|	AdditionalExpenses.Counterparty,
	|	AdditionalExpenses.OperationKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Inventory.Ref AS SourceRef,
	|	Inventory.Ref AS BasisRef,
	|	Inventory.VATRate AS VATRate,
	|	SupplierInvoices.DocumentCurrency AS DocumentCurrency,
	|	SupplierInvoices.Date AS Date,
	|	CAST(Inventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CASE
	|		WHEN SupplierInvoices.IncludeVATInPrice
	|			THEN CAST(Inventory.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|					END AS NUMBER(15, 2))
	|		ELSE (CAST(Inventory.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|				END AS NUMBER(15, 2))) - (CAST(Inventory.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|				END AS NUMBER(15, 2)))
	|	END AS AmountExcludesVAT,
	|	TaxInvoiceReceivedHeader.Company AS Company,
	|	SupplierInvoices.CompanyVATNumber AS CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency AS PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty AS Customer,
	|	VALUE(Enum.VATOperationTypes.Purchases) AS OperationType,
	|	CatalogProducts.ProductsType AS ProductType,
	|	TaxInvoiceReceivedHeader.Period AS Period
	|INTO BasisDocumentsData
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Inventory AS Inventory
	|		ON SupplierInvoices.BasisDocument = Inventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND SupplierInvoices.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND SupplierInvoices.Date = DC_ExchangeRates.Date
	|
	|UNION ALL
	|
	|SELECT
	|	Expenses.Ref,
	|	Expenses.Ref,
	|	Expenses.VATRate,
	|	SupplierInvoices.DocumentCurrency,
	|	SupplierInvoices.Date,
	|	CAST(Expenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CASE
	|		WHEN SupplierInvoices.IncludeVATInPrice
	|			THEN CAST(Expenses.Total * CASE
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|						WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|					END AS NUMBER(15, 2))
	|		ELSE (CAST(Expenses.Total * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|				END AS NUMBER(15, 2))) - (CAST(Expenses.VATAmount * CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|				END AS NUMBER(15, 2)))
	|	END,
	|	TaxInvoiceReceivedHeader.Company,
	|	SupplierInvoices.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsSupplierInvoices AS SupplierInvoices
	|		INNER JOIN Document.SupplierInvoice.Expenses AS Expenses
	|		ON SupplierInvoices.BasisDocument = Expenses.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Expenses.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND SupplierInvoices.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND SupplierInvoices.Date = DC_ExchangeRates.Date
	|
	|UNION ALL
	|
	|SELECT
	|	Inventory.Ref,
	|	Inventory.Ref,
	|	Inventory.VATRate,
	|	ExpenseReports.DocumentCurrency,
	|	ExpenseReports.Date,
	|	Inventory.VATAmountPresentationCur,
	|	CASE
	|		WHEN ExpenseReports.IncludeVATInPrice
	|			THEN Inventory.TotalPresentationCur
	|		ELSE Inventory.TotalPresentationCur - Inventory.VATAmountPresentationCur
	|	END,
	|	TaxInvoiceReceivedHeader.Company,
	|	ExpenseReports.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsExpenseReports AS ExpenseReports
	|		INNER JOIN Document.ExpenseReport.Inventory AS Inventory
	|		ON ExpenseReports.BasisDocument = Inventory.Ref
	|			AND (Inventory.DeductibleTax)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (Inventory.Supplier = TaxInvoiceReceivedHeader.Counterparty)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Inventory.Products = CatalogProducts.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	Expenses.Ref,
	|	Expenses.Ref,
	|	Expenses.VATRate,
	|	ExpenseReports.DocumentCurrency,
	|	ExpenseReports.Date,
	|	Expenses.VATAmountPresentationCur,
	|	CASE
	|		WHEN ExpenseReports.IncludeVATInPrice
	|			THEN Expenses.TotalPresentationCur
	|		ELSE Expenses.TotalPresentationCur - Expenses.VATAmountPresentationCur
	|	END,
	|	TaxInvoiceReceivedHeader.Company,
	|	ExpenseReports.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsExpenseReports AS ExpenseReports
	|		INNER JOIN Document.ExpenseReport.Expenses AS Expenses
	|		ON ExpenseReports.BasisDocument = Expenses.Ref
	|			AND (Expenses.DeductibleTax)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (Expenses.Supplier = TaxInvoiceReceivedHeader.Counterparty)
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Expenses.Products = CatalogProducts.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	Expenses.Ref,
	|	Expenses.Ref,
	|	Expenses.VATRate,
	|	AdditionalExpenses.DocumentCurrency,
	|	AdditionalExpenses.Date,
	|	CAST(Expenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CAST(CASE
	|			WHEN AdditionalExpenses.IncludeVATInPrice
	|				THEN Expenses.Total
	|			ELSE Expenses.Total - Expenses.VATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	TaxInvoiceReceivedHeader.Company,
	|	AdditionalExpenses.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	VALUE(Enum.ProductsTypes.Service),
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsAdditionalExpenses AS AdditionalExpenses
	|		INNER JOIN Document.AdditionalExpenses.Expenses AS Expenses
	|		ON AdditionalExpenses.BasisDocument = Expenses.Ref
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND AdditionalExpenses.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND AdditionalExpenses.Date = DC_ExchangeRates.Date
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNoteInventory.SupplierInvoice,
	|	DebitNote.BasisDocument,
	|	DebitNoteInventory.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNoteInventory.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((DebitNoteInventory.Total - DebitNoteInventory.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	DebitNote.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.PurchasesReturn),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN Document.DebitNote.Inventory AS DebitNoteInventory
	|		ON DebitNote.BasisDocument = DebitNoteInventory.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (DebitNoteInventory.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND DebitNote.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND DebitNote.Date = DC_ExchangeRates.Date
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.PurchaseReturn)
	|	AND (DebitNoteInventory.VATAmount <> 0
	|			OR DebitNoteInventory.Amount <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNote.BasisDocument,
	|	DebitNote.BasisDocument,
	|	DebitNote.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNote.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((DebitNote.DocumentAmount - DebitNote.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	DebitNote.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.OtherAdjustments),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND DebitNote.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND DebitNote.Date = DC_ExchangeRates.Date
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Adjustments)
	|
	|UNION ALL
	|
	|SELECT
	|	DebitNote.BasisDocument,
	|	DebitNote.BasisDocument,
	|	DebitNote.VATRate,
	|	DebitNote.DocumentCurrency,
	|	DebitNote.Date,
	|	-(CAST(DebitNote.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	-(CAST((DebitNote.DocumentAmount - DebitNote.VATAmount) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2))),
	|	TaxInvoiceReceivedHeader.Company,
	|	DebitNote.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.DiscountReceived),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsDebitNotes AS DebitNote
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND DebitNote.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND DebitNote.Date = DC_ExchangeRates.Date
	|WHERE
	|	DebitNote.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.DiscountReceived)
	|
	|UNION ALL
	|
	|SELECT
	|	Expenses.Ref,
	|	Expenses.Ref,
	|	Expenses.VATRate,
	|	SubcontractorInvoicesReceived.DocumentCurrency,
	|	SubcontractorInvoicesReceived.Date,
	|	CAST(Expenses.VATAmount * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	CAST(CASE
	|			WHEN SubcontractorInvoicesReceived.IncludeVATInPrice
	|				THEN Expenses.Total
	|			ELSE Expenses.Total - Expenses.VATAmount
	|		END * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (DC_ExchangeRates.ExchangeRate * PC_ExchangeRates.Multiplicity / (PC_ExchangeRates.ExchangeRate * DC_ExchangeRates.Multiplicity))
	|		END AS NUMBER(15, 2)),
	|	TaxInvoiceReceivedHeader.Company,
	|	SubcontractorInvoicesReceived.CompanyVATNumber,
	|	TaxInvoiceReceivedHeader.PresentationCurrency,
	|	TaxInvoiceReceivedHeader.Counterparty,
	|	VALUE(Enum.VATOperationTypes.Purchases),
	|	CatalogProducts.ProductsType,
	|	TaxInvoiceReceivedHeader.Period
	|FROM
	|	BasisDocumentsSubcontractorInvoicesReceived AS SubcontractorInvoicesReceived
	|		INNER JOIN Document.SubcontractorInvoiceReceived.Products AS Expenses
	|		ON SubcontractorInvoicesReceived.BasisDocument = Expenses.Ref
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON (Expenses.Products = CatalogProducts.Ref)
	|		INNER JOIN TaxInvoiceReceivedHeader AS TaxInvoiceReceivedHeader
	|		ON (TRUE)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS PC_ExchangeRates
	|		ON (PC_ExchangeRates.Currency = &PresentationCurrency)
	|			AND SubcontractorInvoicesReceived.Date = PC_ExchangeRates.Date
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS DC_ExchangeRates
	|		ON (DC_ExchangeRates.Currency = &CashCurrency)
	|			AND SubcontractorInvoicesReceived.Date = DC_ExchangeRates.Date
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO PrepaymentWithoutInvoice
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO AdditionalExpensesPrepaymentWithoutInvoice
	|FROM
	|	AdditionalExpensesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentVAT.ShipmentDocument AS ShipmentDocument
	|INTO SubcontractorPrepaymentWithoutInvoice
	|FROM
	|	SubcontractorInvoicesReceivedPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS PrepaymentDocuments
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentDocuments.BasisDocument
	|WHERE
	|	PrepaymentDocuments.BasisDocument IS NULL";
	
	Query.ExecuteBatch();
	
	GenerateTableVATInput(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATIncurred(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

#Region TableGeneration

Procedure GenerateTableVATInput(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	BasisDocuments.SourceRef AS ShipmentDocument,
	|	BasisDocuments.VATRate AS VATRate,
	|	SUM(BasisDocuments.VATAmount) AS VATAmount,
	|	SUM(BasisDocuments.AmountExcludesVAT) AS AmountExcludesVAT,
	|	BasisDocuments.Company AS Company,
	|	BasisDocuments.CompanyVATNumber AS CompanyVATNumber,
	|	BasisDocuments.PresentationCurrency AS PresentationCurrency,
	|	BasisDocuments.Customer AS Supplier,
	|	&VATInput AS GLAccount,
	|	BasisDocuments.OperationType AS OperationType,
	|	BasisDocuments.ProductType AS ProductType,
	|	BasisDocuments.Period AS Period
	|FROM
	|	BasisDocumentsData AS BasisDocuments
	|
	|GROUP BY
	|	BasisDocuments.SourceRef,
	|	BasisDocuments.VATRate,
	|	BasisDocuments.OperationType,
	|	BasisDocuments.ProductType,
	|	BasisDocuments.Company,
	|	BasisDocuments.CompanyVATNumber,
	|	BasisDocuments.PresentationCurrency,
	|	BasisDocuments.Customer,
	|	BasisDocuments.Period
	|
	|UNION ALL
	|
	|SELECT
	|	CashVoucherPayments.BasisDocument,
	|	CashVoucherPayments.VATRate,
	|	CashVoucherPayments.VATAmount,
	|	CashVoucherPayments.PaymentAmount,
	|	CashVoucherPayments.Company,
	|	CashVoucherPayments.CompanyVATNumber,
	|	CashVoucherPayments.PresentationCurrency,
	|	CashVoucherPayments.Counterparty,
	|	&VATInput,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	CashVoucherPayments.Date
	|FROM
	|	BasisDocumentsCashVoucher AS CashVoucherPayments
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentExpensePayments.BasisDocument,
	|	PaymentExpensePayments.VATRate,
	|	PaymentExpensePayments.VATAmount,
	|	PaymentExpensePayments.PaymentAmount,
	|	PaymentExpensePayments.Company,
	|	PaymentExpensePayments.CompanyVATNumber,
	|	PaymentExpensePayments.PresentationCurrency,
	|	PaymentExpensePayments.Counterparty,
	|	&VATInput,
	|	VALUE(Enum.VATOperationTypes.AdvancePayment),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PaymentExpensePayments.Date
	|FROM
	|	BasisDocumentsPaymentExpense AS PaymentExpensePayments
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
	|	&VATInput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
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
	|	&VATInput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	AdditionalExpensesPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN AdditionalExpensesPrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL
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
	|	&VATInput,
	|	VALUE(Enum.VATOperationTypes.AdvanceCleared),
	|	VALUE(Enum.ProductsTypes.EmptyRef),
	|	PrepaymentVAT.Date
	|FROM
	|	SubcontractorInvoicesReceivedPrepaymentVAT AS PrepaymentVAT
	|		LEFT JOIN SubcontractorPrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON PrepaymentVAT.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	PrepaymentWithoutInvoice.ShipmentDocument IS NULL";
	
	Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATInput", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableVATIncurred(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	BasisDocuments.BasisRef AS ShipmentDocument,
	|	BasisDocuments.VATRate AS VATRate,
	|	SUM(BasisDocuments.VATAmount) AS VATAmount,
	|	SUM(BasisDocuments.AmountExcludesVAT) AS AmountExcludesVAT,
	|	BasisDocuments.Company AS Company,
	|	BasisDocuments.CompanyVATNumber AS CompanyVATNumber,
	|	BasisDocuments.PresentationCurrency AS PresentationCurrency,
	|	BasisDocuments.Customer AS Supplier,
	|	&VATInput AS GLAccount,
	|	BasisDocuments.Period AS Period
	|FROM
	|	BasisDocumentsData AS BasisDocuments
	|
	|GROUP BY
	|	BasisDocuments.BasisRef,
	|	BasisDocuments.VATRate,
	|	BasisDocuments.Company,
	|	BasisDocuments.CompanyVATNumber,
	|	BasisDocuments.PresentationCurrency,
	|	BasisDocuments.Customer,
	|	BasisDocuments.Period
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	CashVoucherPayments.BasisDocument,
	|	CashVoucherPayments.VATRate,
	|	CashVoucherPayments.VATAmount,
	|	CashVoucherPayments.PaymentAmount,
	|	CashVoucherPayments.Company,
	|	CashVoucherPayments.CompanyVATNumber,
	|	CashVoucherPayments.PresentationCurrency,
	|	CashVoucherPayments.Counterparty,
	|	&VATInput,
	|	CashVoucherPayments.Date
	|FROM
	|	BasisDocumentsCashVoucher AS CashVoucherPayments
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	PaymentExpensePayments.BasisDocument,
	|	PaymentExpensePayments.VATRate,
	|	PaymentExpensePayments.VATAmount,
	|	PaymentExpensePayments.PaymentAmount,
	|	PaymentExpensePayments.Company,
	|	PaymentExpensePayments.CompanyVATNumber,
	|	PaymentExpensePayments.PresentationCurrency,
	|	PaymentExpensePayments.Counterparty,
	|	&VATInput,
	|	PaymentExpensePayments.Date
	|FROM
	|	BasisDocumentsPaymentExpense AS PaymentExpensePayments";
	
	Query.SetParameter("VATInput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATIncurred", Query.Execute().Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefTaxInvoiceReceived, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Company",					StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("Date",						StructureAdditionalProperties.ForPosting.Date);
	Query.SetParameter("ContentVATOnAdvance",		NStr("en = 'VAT on advance'; ru = 'НДС с авансов';pl = 'VAT z zaliczek';es_ES = 'IVA del anticipo';es_CO = 'IVA del anticipo';tr = 'Avans KDV''si';it = 'IVA sull''anticipo';de = 'USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ContentVATRevenue",			NStr("en = 'Advance recognized as payment'; ru = 'Зачет аванса';pl = 'Zaliczenie zaliczki jako płatności';es_ES = 'Anticipo reconocido como un pago';es_CO = 'Anticipo reconocido como un pago';tr = 'Ödeme olarak tanımlanan avans';it = 'Anticipo riconosciuto come pagamento';de = 'Vorauszahlung aufgenommen als Zahlung'", MainLanguageCode));
	Query.SetParameter("VATAdvancesToSuppliers",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesToSuppliers"));
	Query.SetParameter("VATInput",					Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATInput"));
	
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	Query.SetParameter("PostVATEntriesBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostVATEntriesBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	&VATInput AS AccountDr,
	|	&VATAdvancesToSuppliers AS AccountCr,
	|	UNDEFINED AS CurrencyDr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurDr,
	|	0 AS AmountCurCr,
	|	SUM(DocumentTable.VATAmount) AS Amount,
	|	&ContentVATOnAdvance AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	BasisDocumentsCashVoucher AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
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
	|	&VATInput,
	|	&VATAdvancesToSuppliers,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATOnAdvance,
	|	FALSE
	|FROM
	|	BasisDocumentsPaymentExpense AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.AdvancePayment)
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
	|	&VATAdvancesToSuppliers,
	|	&VATInput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SupplierInvoicesPrepaymentVAT AS DocumentTable
	|		LEFT JOIN PrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON DocumentTable.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|	AND PrepaymentWithoutInvoice.ShipmentDocument IS NULL
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
	|	&VATAdvancesToSuppliers,
	|	&VATInput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	AdditionalExpensesPrepaymentVAT AS DocumentTable
	|		LEFT JOIN AdditionalExpensesPrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON DocumentTable.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|	AND PrepaymentWithoutInvoice.ShipmentDocument IS NULL
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
	|	&VATAdvancesToSuppliers,
	|	&VATInput,
	|	UNDEFINED,
	|	UNDEFINED,
	|	0,
	|	0,
	|	SUM(DocumentTable.VATAmount),
	|	&ContentVATRevenue,
	|	FALSE
	|FROM
	|	SubcontractorInvoicesReceivedPrepaymentVAT AS DocumentTable
	|		LEFT JOIN SubcontractorPrepaymentWithoutInvoice AS PrepaymentWithoutInvoice
	|		ON DocumentTable.ShipmentDocument = PrepaymentWithoutInvoice.ShipmentDocument
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesTaxInvoiceReceived.Purchase)
	|	AND NOT &PostVATEntriesBySourceDocuments
	|	AND PrepaymentWithoutInvoice.ShipmentDocument IS NULL
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndRegion

#EndIf

