
#Region ServiceProgrammingInterface

// Procedure initializes the IsFirstLaunch session parameters.
//
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	If ParameterName = "LanguageCodeForOutput" Then
		SessionParameters.LanguageCodeForOutput = "";	
		SpecifiedParameters.Add("LanguageCodeForOutput");
	EndIf;
	
	If ParameterName = "CodeCompletionAddInPath" Then
		SessionParameters.CodeCompletionAddInPath = "";
		SpecifiedParameters.Add("LanguageCodeForOutput");
	EndIf;
	
EndProcedure

// Defines whether the passed object is a document
//
Function IsMetadataKindDocument(ObjectName)
	
	Return Not Metadata.Documents.Find(ObjectName) = Undefined;
	
EndFunction

// Function converts row to the plural
//
// Parameters: 
//  Word1 - word form in singular
//  ("box") Word2 - word form for numeral
//  2-4 ("box") Word3 - word form for numeral 5-10
//  ("boxes") IntegerNumber - integer number
//
// Returns:
//  string - one of the rows depending on the IntegerNumber parameter
//
// Definition:
//  Designed to generate "correct" signature to numerals
//
Function FormOfMultipleNumbers(Word1, Word2, Word3, Val IntegerNumber) Export
	
	// Change integer sign, otherwise, negative numbers will be converted incorrectly.
	If IntegerNumber < 0 Then
		IntegerNumber = -1 * IntegerNumber;
	EndIf;
	
	If IntegerNumber <> Int(IntegerNumber) Then 
		// for nonintegral numbers - always the second form
		Return Word2;
	EndIf;
	
	// Balance
	Balance = IntegerNumber%10;
	If (IntegerNumber > 10) And (IntegerNumber < 20) Then
		// for the second dozen - always the third form
		Return Word3;
	ElsIf Balance = 1 Then
		Return Word1;
	ElsIf (Balance > 1) And (Balance < 5) Then
		Return Word2;
	Else
		Return Word3;
	EndIf;

EndFunction

Procedure UpdateDocumentStatuses(ExportParameters = Undefined, ResultAddress = Undefined) Export
	
	Common.OnStartExecuteScheduledJob();
	
	EventName = NStr("en = 'Update document statuses'; ru = 'Обновить статусы документов';pl = 'Zaktualizuj statusy dokumentu';es_ES = 'Actualizar los estados del documento';es_CO = 'Actualizar los estados del documento';tr = 'Belge durumlarını güncelle';it = 'Aggiornare stati documento';de = 'Dokumentstatus aktualisieren'",
		CommonClientServer.DefaultLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("en = 'Document status update is started'; ru = 'Запущено обновление состояния документа';pl = 'Aktualizacja statusu dokumentu jest uruchomiona';es_ES = 'La actualización del estado de documento ha empezado';es_CO = 'La actualización del estado de documento ha empezado';tr = 'Belge durum güncellemesi başlatıldı';it = 'L''aggiornamento dello stato documento è avviata';de = 'Die Aktualisierung des Dokumentstatus wird gestartet'"));
	
	ResultArray = GetDocumentStatusesTables();
	DocumentStatusesTable = ResultArray[9].Unload();
	PreviousDocumentStatusesTable = ResultArray[10].Unload();
	
	SearchStructure = New Structure("Document, Status");
	
	For Each TableRow In DocumentStatusesTable Do
		
		FillPropertyValues(SearchStructure, TableRow);
		CurrentStatusesArray = PreviousDocumentStatusesTable.FindRows(SearchStructure);
		
		StatusIsChanged = Not Boolean(CurrentStatusesArray.Count());
		If StatusIsChanged Then
			RecordSet = InformationRegisters[TableRow.RegisterName].CreateRecordSet();
			RecordSet.Filter.Document.Set(TableRow.Document);
			
			If TableRow.Status <> Undefined Then
				RecordSetRow = RecordSet.Add();
				FillPropertyValues(RecordSetRow, TableRow);
			EndIf;
			RecordSet.Write(True);
			
		EndIf;
		
		If TableRow.Delete Then
			RecordSetForUpdating = InformationRegisters.TasksForUpdatingStatuses.CreateRecordSet();
			RecordSetForUpdating.Filter.Document.Set(TableRow.Document);
			RecordSetForUpdating.Write(True);
		EndIf;
		
	EndDo;
	
	// begin Drive.FullVersion
	ReflectProductionOperationsSequence();
	// end Drive.FullVersion
	
EndProcedure

Function GetDocumentStatusesTables()

	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	TasksForUpdatingStatuses.Document AS Document
	|INTO DocumentsForUpdatingStatuses
	|FROM
	|	InformationRegister.TasksForUpdatingStatuses AS TasksForUpdatingStatuses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentsForUpdatingStatuses.Document AS Quotation,
	|	Quote.ValidUntil AS ValidUntil,
	|	Quote.Posted AS QuotationPosted
	|INTO Quotations
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN Document.Quote AS Quote
	|		ON DocumentsForUpdatingStatuses.Document = Quote.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS Document
	|INTO GoodsDocuments
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|WHERE
	|	(VALUETYPE(DocumentsForUpdatingStatuses.Document) = TYPE(Document.GoodsIssue)
	|			OR VALUETYPE(DocumentsForUpdatingStatuses.Document) = TYPE(Document.GoodsReceipt))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Quotations.Quotation AS Ref,
	|	Quotations.ValidUntil AS ValidUntil,
	|	Quotations.QuotationPosted AS QuotationPosted,
	|	ISNULL(SalesOrder.Posted, FALSE) AS SalesDocumentPosted
	|INTO QuotationsWithDocuments
	|FROM
	|	Quotations AS Quotations
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON Quotations.Quotation = SalesOrder.BasisDocument
	|
	|UNION ALL
	|
	|SELECT
	|	Quotations.Quotation,
	|	Quotations.ValidUntil,
	|	Quotations.QuotationPosted,
	|	ISNULL(SalesInvoice.Posted, FALSE)
	|FROM
	|	Quotations AS Quotations
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON Quotations.Quotation = SalesInvoice.BasisDocument
	|
	|UNION ALL
	|
	|SELECT
	|	Quotations.Quotation,
	|	Quotations.ValidUntil,
	|	Quotations.QuotationPosted,
	|	ISNULL(WorkOrder.Posted, FALSE)
	|FROM
	|	Quotations AS Quotations
	|		LEFT JOIN Document.WorkOrder AS WorkOrder
	|		ON Quotations.Quotation = WorkOrder.BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuotationsWithDocuments.Ref AS Quotation,
	|	QuotationsWithDocuments.ValidUntil AS ValidUntil,
	|	QuotationsWithDocuments.QuotationPosted AS QuotationPosted,
	|	MAX(QuotationsWithDocuments.SalesDocumentPosted) AS SalesDocumentPosted
	|INTO GroupedQuotations
	|FROM
	|	QuotationsWithDocuments AS QuotationsWithDocuments
	|
	|GROUP BY
	|	QuotationsWithDocuments.Ref,
	|	QuotationsWithDocuments.QuotationPosted,
	|	QuotationsWithDocuments.ValidUntil
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsDocument,
	|	COUNT(DISTINCT GoodsReceivedNotInvoiced.Recorder) AS CountOfRecorders,
	|	MIN(NOT GoodsInvoicedNotReceived.Recorder IS NULL) AS HasGoodsInvoicedInAdvance
	|INTO GoodsNotInvoiced
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
	|		ON GoodsDocuments.Document = GoodsReceivedNotInvoiced.GoodsReceipt
	|		LEFT JOIN AccumulationRegister.GoodsInvoicedNotReceived AS GoodsInvoicedNotReceived
	|		ON GoodsDocuments.Document = GoodsInvoicedNotReceived.Recorder
	|			AND (GoodsInvoicedNotReceived.LineNumber = 1)
	|
	|GROUP BY
	|	GoodsReceivedNotInvoiced.GoodsReceipt
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsShippedNotInvoiced.GoodsIssue,
	|	COUNT(DISTINCT GoodsShippedNotInvoiced.Recorder),
	|	MIN(NOT GoodsInvoicedNotShipped.Recorder IS NULL)
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
	|		ON GoodsDocuments.Document = GoodsShippedNotInvoiced.GoodsIssue
	|		LEFT JOIN AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|		ON GoodsDocuments.Document = GoodsInvoicedNotShipped.Recorder
	|			AND (GoodsInvoicedNotShipped.LineNumber = 1)
	|
	|GROUP BY
	|	GoodsShippedNotInvoiced.GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GoodsReceivedNotInvoicedBalance.GoodsReceipt AS GoodsDocument,
	|	GoodsReceivedNotInvoicedBalance.QuantityBalance AS QuantityBalance
	|INTO GoodsNotInvoicedBalance
	|FROM
	|	AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|			,
	|			GoodsReceipt IN
	|				(SELECT
	|					DocumentsForUpdatingStatuses.Document AS Document
	|				FROM
	|					DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses)) AS GoodsReceivedNotInvoicedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsShippedNotInvoicedBalance.GoodsIssue,
	|	GoodsShippedNotInvoicedBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced.Balance(
	|			,
	|			GoodsIssue IN
	|				(SELECT
	|					DocumentsForUpdatingStatuses.Document AS Document
	|				FROM
	|					DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses)) AS GoodsShippedNotInvoicedBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentsForUpdatingStatuses.Document AS SalesInvoice,
	|	SalesInvoice.DocumentAmount AS SalesInvoiceAmount,
	|	SalesInvoice.Posted AS SalesInvoicePosted,
	|	MAX(ISNULL(SalesInvoicePaymentCalendar.PaymentDate, DATETIME(1, 1, 1))) AS PaymentDate
	|INTO SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		ON SalesInvoice.Ref = DocumentsForUpdatingStatuses.Document
	|		LEFT JOIN Document.SalesInvoice.PaymentCalendar AS SalesInvoicePaymentCalendar
	|		ON SalesInvoice.Ref = SalesInvoicePaymentCalendar.Ref
	|
	|GROUP BY
	|	DocumentsForUpdatingStatuses.Document,
	|	SalesInvoice.DocumentAmount,
	|	SalesInvoice.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	DocumentsForUpdatingStatuses.Document AS SupplierInvoice,
	|	CAST(CASE
	|			WHEN CounterpartyContracts.SettlementsCurrency <> SupplierInvoice.DocumentAmount
	|				THEN CASE
	|						WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN SupplierInvoice.DocumentAmount * CASE
	|									WHEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity = 0
	|										THEN 1
	|									ELSE SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity)
	|								END
	|						WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.DocumentAmount * CASE
	|									WHEN SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity = 0
	|										THEN 1
	|									ELSE SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity)
	|								END
	|						ELSE 0
	|					END
	|			ELSE SupplierInvoice.DocumentAmount
	|		END AS NUMBER(15, 2)) AS SupplierInvoiceAmount,
	|	SupplierInvoice.Posted AS SupplierInvoicePosted,
	|	MAX(ISNULL(SupplierInvoicePaymentCalendar.PaymentDate, DATETIME(1, 1, 1))) AS PaymentDate
	|INTO SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|		INNER JOIN DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		ON SupplierInvoice.Ref = DocumentsForUpdatingStatuses.Document
	|		LEFT JOIN Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|		ON SupplierInvoice.Ref = SupplierInvoicePaymentCalendar.Ref
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON SupplierInvoice.Company = Companies.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON SupplierInvoice.Contract = CounterpartyContracts.Ref
	|
	|GROUP BY
	|	DocumentsForUpdatingStatuses.Document,
	|	SupplierInvoice.DocumentAmount,
	|	SupplierInvoice.Posted,
	|	CAST(CASE
	|			WHEN CounterpartyContracts.SettlementsCurrency <> SupplierInvoice.DocumentAmount
	|				THEN CASE
	|						WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|							THEN SupplierInvoice.DocumentAmount * CASE
	|									WHEN SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity = 0
	|										THEN 1
	|									ELSE SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity / (SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity)
	|								END
	|						WHEN Companies.ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|							THEN SupplierInvoice.DocumentAmount * CASE
	|									WHEN SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity = 0
	|										THEN 1
	|									ELSE SupplierInvoice.ExchangeRate * SupplierInvoice.ContractCurrencyMultiplicity / (SupplierInvoice.ContractCurrencyExchangeRate * SupplierInvoice.Multiplicity)
	|								END
	|						ELSE 0
	|					END
	|			ELSE SupplierInvoice.DocumentAmount
	|		END AS NUMBER(15, 2))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	GroupedQuotations.Quotation AS Document,
	|	CASE
	|		WHEN GroupedQuotations.SalesDocumentPosted
	|			THEN VALUE(Enum.QuotationStatuses.Completed)
	|		WHEN GroupedQuotations.ValidUntil <> DATETIME(1, 1, 1)
	|				AND GroupedQuotations.ValidUntil < &CurrentDate
	|			THEN VALUE(Enum.QuotationStatuses.Expired)
	|		ELSE VALUE(Enum.QuotationStatuses.Sent)
	|	END AS Status,
	|	CASE
	|		WHEN NOT GroupedQuotations.QuotationPosted
	|				OR GroupedQuotations.ValidUntil = DATETIME(1, 1, 1)
	|			THEN TRUE
	|		ELSE &CurrentDate > GroupedQuotations.ValidUntil
	|	END AS Delete,
	|	""QuotationStatuses"" AS RegisterName
	|FROM
	|	GroupedQuotations AS GroupedQuotations
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsDocuments.Document,
	|	CASE
	|		WHEN GoodsNotInvoiced.CountOfRecorders = 1
	|				AND NOT GoodsNotInvoiced.HasGoodsInvoicedInAdvance
	|			THEN VALUE(Enum.GoodsDocumentStatuses.NotInvoiced)
	|		WHEN ISNULL(GoodsNotInvoicedBalance.QuantityBalance, 0) = 0
	|			THEN VALUE(Enum.GoodsDocumentStatuses.Invoiced)
	|		WHEN GoodsNotInvoicedBalance.QuantityBalance > 0
	|			THEN VALUE(Enum.GoodsDocumentStatuses.PartiallyInvoiced)
	|	END,
	|	TRUE,
	|	""GoodsDocumentsStatuses""
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		LEFT JOIN GoodsNotInvoiced AS GoodsNotInvoiced
	|		ON GoodsDocuments.Document = GoodsNotInvoiced.GoodsDocument
	|		LEFT JOIN GoodsNotInvoicedBalance AS GoodsNotInvoicedBalance
	|		ON GoodsDocuments.Document = GoodsNotInvoicedBalance.GoodsDocument
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoices.SalesInvoice,
	|	CASE
	|		WHEN NOT SalesInvoices.SalesInvoicePosted
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.EmptyRef)
	|		WHEN ISNULL(AccountsReceivableBalance.AmountCurBalance, 0) <= 0
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInFull)
	|		WHEN SalesInvoices.PaymentDate <> DATETIME(1, 1, 1)
	|				AND &BegOfCurrentDate > SalesInvoices.PaymentDate
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.Overdue)
	|		WHEN ISNULL(AccountsReceivableBalance.AmountCurBalance, 0) < SalesInvoices.SalesInvoiceAmount
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInPart)
	|		ELSE VALUE(Enum.InvoicesPaymentStatuses.Unpaid)
	|	END,
	|	TRUE,
	|	""InvoicesPaymentStatuses""
	|FROM
	|	SalesInvoices AS SalesInvoices
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Document IN
	|					(SELECT
	|						SalesInvoices.SalesInvoice AS SalesInvoice
	|					FROM
	|						SalesInvoices AS SalesInvoices)) AS AccountsReceivableBalance
	|		ON SalesInvoices.SalesInvoice = AccountsReceivableBalance.Document
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoices.SupplierInvoice,
	|	CASE
	|		WHEN NOT SupplierInvoices.SupplierInvoicePosted
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.EmptyRef)
	|		WHEN ISNULL(AccountsPayableBalance.AmountCurBalance, 0) <= 0
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInFull)
	|		WHEN SupplierInvoices.PaymentDate <> DATETIME(1, 1, 1)
	|				AND &BegOfCurrentDate > SupplierInvoices.PaymentDate
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.Overdue)
	|		WHEN ISNULL(AccountsPayableBalance.AmountCurBalance, 0) < SupplierInvoices.SupplierInvoiceAmount
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInPart)
	|		ELSE VALUE(Enum.InvoicesPaymentStatuses.Unpaid)
	|	END,
	|	TRUE,
	|	""InvoicesPaymentStatuses""
	|FROM
	|	SupplierInvoices AS SupplierInvoices
	|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Document IN
	|					(SELECT
	|						SupplierInvoices.SupplierInvoice AS SupplierInvoice
	|					FROM
	|						SupplierInvoices AS SupplierInvoices)) AS AccountsPayableBalance
	|		ON SupplierInvoices.SupplierInvoice = AccountsPayableBalance.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuotationStatuses.Document AS Document,
	|	QuotationStatuses.Status AS Status
	|FROM
	|	Quotations AS Quotations
	|		INNER JOIN InformationRegister.QuotationStatuses AS QuotationStatuses
	|		ON (QuotationStatuses.Document = Quotations.Quotation)
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsDocumentsStatuses.Document,
	|	GoodsDocumentsStatuses.Status
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN InformationRegister.GoodsDocumentsStatuses AS GoodsDocumentsStatuses
	|		ON DocumentsForUpdatingStatuses.Document = GoodsDocumentsStatuses.Document
	|
	|UNION ALL
	|
	|SELECT
	|	InvoicesPaymentStatuses.Document,
	|	InvoicesPaymentStatuses.Status
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN InformationRegister.InvoicesPaymentStatuses AS InvoicesPaymentStatuses
	|		ON DocumentsForUpdatingStatuses.Document = InvoicesPaymentStatuses.Document";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("BegOfCurrentDate", BegOfDay(CurrentSessionDate()));
	
	Return Query.ExecuteBatch();

EndFunction

Function GetDefaultDate() Export
	
	Return Date(1980, 1, 1);
	
EndFunction

Function DocumentVATRate(DocumentRef, Parameters = Undefined) Export
	
	If Parameters = Undefined Then
		Parameters = New Structure;
	EndIf;
	If Not Parameters.Property("TableName") Then
		Parameters.Insert("TableName", "Inventory");
	EndIf;
	If Not Parameters.Property("AttributeName") Then
		Parameters.Insert("AttributeName", "VATRate");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", DocumentRef);
	Query.Text =
	"SELECT DISTINCT TOP 2
	|	DocumentTable._AttributeName AS VATRate
	|FROM
	|	_DocumentName._TableName AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	Query.Text = StrReplace(Query.Text, "_DocumentName", Common.TableNameByRef(DocumentRef));
	Query.Text = StrReplace(Query.Text, "_TableName", Parameters.TableName);
	Query.Text = StrReplace(Query.Text, "_AttributeName", Parameters.AttributeName);
	
	Sel = Query.Execute().Select();
	
	If Sel.Count() = 1 And Sel.Next() Then
		
		Return Sel.VATRate;
		
	Else
		
		Return Catalogs.VATRates.EmptyRef();
		
	EndIf;
	
EndFunction

Function DocumentVATRateData(DocumentRef, DefaultVATRate, GetRateValue = True) Export
	
	Result = New Structure("VATRate, Rate", DefaultVATRate, 0);
	
	If ValueIsFilled(DocumentRef) Then
		VATRate = Common.ObjectManagerByRef(DocumentRef).DocumentVATRate(DocumentRef);
		If ValueIsFilled(VATRate) Then
			Result.VATRate = VATRate;
		EndIf;
	EndIf;
	
	If GetRateValue And ValueIsFilled(Result.VATRate) Then
		Result.Rate = Common.ObjectAttributeValue(Result.VATRate, "Rate");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure CheckPOApprovalStatus(BasisDocument, MessageText, Cancel)

	If TypeOf(BasisDocument) <> Type("DocumentRef.PurchaseOrder") Then
		Return;
	EndIf;
	
	ApprovalStatus = Common.ObjectAttributeValue(BasisDocument, "ApprovalStatus");
	
	If TypeOf(BasisDocument) = Type("DocumentRef.PurchaseOrder")
		And (ApprovalStatus = Enums.ApprovalStatuses.ReadyForApproval
		Or ApprovalStatus = Enums.ApprovalStatuses.SentForApproval
		Or ApprovalStatus = Enums.ApprovalStatuses.Rejected) Then
		
		Cancel = True;
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot perform the action for %1. First, get the purchase order approval. Then try again.'; ru = 'Не удалось выполнить действие для %1. Утвердите заказ поставщику и повторите попытку.';pl = 'Nie można wykonać działania dla %1. Najpierw, uzyskaj zatwierdzenie zamówienia zakupu. Zatem spróbuj ponownie.';es_ES = 'No se puede realizar la acción para %1. Primero, obtenga la aprobación de la orden de compra. Luego, inténtelo de nuevo.';es_CO = 'No se puede realizar la acción para %1. Primero, obtenga la aprobación de la orden de compra. Luego, inténtelo de nuevo.';tr = '%1 için eylem gerçekleştirilemiyor. Önce satın alma siparişi onayı alıp tekrar deneyin.';it = 'Impossibile eseguire l''azione per %1. Ottenere prima l''approvazione dell''ordine di acquisto, poi riprovare.';de = 'Fehler beim Ausführen der Aktion für %1. Zuerst holen Sie die Genehmigung der Bestellung an Lieferanten ein. Dann versuchen Sie erneut.'"),
			BasisDocument);
	EndIf;

EndProcedure

Function GetCurrencyRateChoiceList(Currency, PresentationCurrency, DocumentDate, Company) Export
	
	Result = New ValueList;
	
	If ValueIsFilled(Currency) And Currency <> PresentationCurrency Then
		
		For DayMinus = 0 To 5 Do
			
			RateDate = DocumentDate - (DayMinus * 86400);
			
			CurrencyRate = CurrencyRateOperations.GetCurrencyRate(RateDate, Currency, Company);
			
			TextOnDate = " " + StrTemplate(NStr("en = '(on %1)'; ru = '(на %1)';pl = '(na %1)';es_ES = '(en %1)';es_CO = '(en %1)';tr = '(%1 tarihinde)';it = '(il %1)';de = '(Am %1)'"), Format(RateDate, "DLF = D"));
			Representation = Format(CurrencyRate.Rate, "NFD=4") + TextOnDate;
			
			Result.Add(CurrencyRate.Rate, Representation);
			
		EndDo;
		
		Result.Add(0, NStr("en = '<Select exchange rate date>'; ru = '<Укажите дату курса валюты>';pl = '<Wybierz datę kursu waluty>';es_ES = '<Seleccione la fecha del tipo de cambio>';es_CO = '<Seleccione la fecha del tipo de cambio>';tr = '<Döviz kuru tarihi seçin>';it = '<Selezionare data del tasso di cambio>';de = '<Wählen Sie das Datum des Wechselkurses aus>'"));
		
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillCurrenciesRatesInPaymentDetails(PaymentDocumentObject) Export
	
	CashCurrencyRate = CurrencyRateOperations.GetCurrencyRate(PaymentDocumentObject.Date, 
		PaymentDocumentObject.CashCurrency, 
		PaymentDocumentObject.Company);
		
	CounterpartyData = Common.ObjectAttributesValues(PaymentDocumentObject.Counterparty, "DoOperationsByContracts, SettlementsCurrency");
	CounterpartyData.DoOperationsByContracts = ?(CounterpartyData.DoOperationsByContracts = Undefined, False, CounterpartyData.DoOperationsByContracts);
	
	For Each PaymentDetailRow In PaymentDocumentObject.PaymentDetails Do
		
		ExchangeRateMethod = DriveServer.GetExchangeMethod(PaymentDocumentObject.Company);
		
		PaymentDetailRow.PaymentExchangeRate = ?(
			CashCurrencyRate.Rate = 0,
			1,
			CashCurrencyRate.Rate);
			
		PaymentDetailRow.PaymentMultiplier = ?(
			CashCurrencyRate.Repetition = 0,
			1,
			CashCurrencyRate.Repetition);
			
		If CounterpartyData.DoOperationsByContracts
			And ValueIsFilled(PaymentDetailRow.Contract) Then
			PaymentDetailRow.SettlementsCurrency = PaymentDetailRow.Contract.SettlementsCurrency;
		Else
			PaymentDetailRow.SettlementsCurrency = CounterpartyData.SettlementsCurrency;
		EndIf;
		
		SettlementsCurrencyRate = CurrencyRateOperations.GetCurrencyRate(PaymentDocumentObject.Date, 
			PaymentDetailRow.Contract.SettlementsCurrency, 
			PaymentDocumentObject.Company);
			
		If Not ValueIsFilled(PaymentDetailRow.ExchangeRate) Then
			
			PaymentDetailRow.ExchangeRate = ?(
				SettlementsCurrencyRate.Rate = 0,
				1,
				SettlementsCurrencyRate.Rate);
				
		EndIf;
		
		If Not ValueIsFilled(PaymentDetailRow.Multiplicity) Then
			
			PaymentDetailRow.Multiplicity = ?(
				SettlementsCurrencyRate.Repetition = 0,
				1,
				SettlementsCurrencyRate.Repetition);
				
		EndIf;
		
		If Not ValueIsFilled(PaymentDetailRow.SettlementsAmount) Then
			
			PaymentDetailRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				PaymentDetailRow.PaymentAmount,
				ExchangeRateMethod,
				PaymentDetailRow.PaymentExchangeRate,
				PaymentDetailRow.ExchangeRate,
				PaymentDetailRow.PaymentMultiplier,
				PaymentDetailRow.Multiplicity);
				
		Else
			
			If ExchangeRateMethod = PredefinedValue("Enum.ExchangeRateMethods.Divisor") Then
				If PaymentDetailRow.PaymentAmount <> 0 Then
					PaymentDetailRow.ExchangeRate = PaymentDetailRow.SettlementsAmount
						* PaymentDetailRow.PaymentExchangeRate
						/ PaymentDetailRow.PaymentMultiplier
						/ PaymentDetailRow.PaymentAmount
						* PaymentDetailRow.Multiplicity;
				EndIf;
			Else
				If PaymentDetailRow.SettlementsAmount <> 0 Then
					PaymentDetailRow.ExchangeRate = PaymentDetailRow.PaymentAmount
						* PaymentDetailRow.PaymentExchangeRate
						/ PaymentDetailRow.PaymentMultiplier
						/ PaymentDetailRow.SettlementsAmount
						* PaymentDetailRow.Multiplicity;
				EndIf;
			EndIf;
			
		EndIf;
		
		
		
	EndDo;
	
EndProcedure

// begin Drive.FullVersion
Procedure ReflectProductionOperationsSequence() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	TasksForUpdatingStatuses.Document AS Document
	|INTO DocumentsForUpdatingStatuses
	|FROM
	|	InformationRegister.TasksForUpdatingStatuses AS TasksForUpdatingStatuses
	|WHERE
	|	TasksForUpdatingStatuses.Document REFS Document.ProductionOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS ProductionOrder,
	|	ManufacturingOperation.Ref AS WorkInProgress,
	|	ManufacturingOperation.Specification AS Specification,
	|	ManufacturingOperationActivities.Activity AS Operation,
	|	ManufacturingOperationActivities.ConnectionKey AS ConnectionKey,
	|	ManufacturingOperationActivities.ActivityNumber AS SequenceNumber,
	|	ManufacturingOperationActivities.NextActivityNumber AS NextNumber
	|INTO TemporaryTable
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN Document.ManufacturingOperation AS ManufacturingOperation
	|		ON DocumentsForUpdatingStatuses.Document = ManufacturingOperation.BasisDocument
	|			AND (ManufacturingOperation.Posted)
	|		INNER JOIN Document.ManufacturingOperation.Activities AS ManufacturingOperationActivities
	|		ON (ManufacturingOperation.Ref = ManufacturingOperationActivities.Ref)
	|		INNER JOIN Document.ProductionOrder AS ProductionOrder
	|		ON DocumentsForUpdatingStatuses.Document = ProductionOrder.Ref
	|			AND (ProductionOrder.Posted)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.ProductionOrder AS ProductionOrder,
	|	TemporaryTable.WorkInProgress AS WorkInProgress,
	|	TemporaryTable.Specification AS BillOfMaterials,
	|	TemporaryTable.Operation AS Operation,
	|	TemporaryTable.ConnectionKey AS ConnectionKey,
	|	TemporaryTable.SequenceNumber AS SequenceNumber,
	|	TemporaryTable.NextNumber AS NextNumber,
	|	ISNULL(ProductionAccomplishmentBalance.QuantityProducedBalance, 0) = 0 AS IsFinished,
	|	FALSE AS CanBeStarted
	|FROM
	|	TemporaryTable AS TemporaryTable
	|		LEFT JOIN AccumulationRegister.ProductionAccomplishment.Balance(
	|				,
	|				(WorkInProgress, Operation, ConnectionKey) IN
	|					(SELECT
	|						TemporaryTable.WorkInProgress,
	|						TemporaryTable.Operation,
	|						TemporaryTable.ConnectionKey
	|					FROM
	|						TemporaryTable AS TemporaryTable)) AS ProductionAccomplishmentBalance
	|		ON TemporaryTable.WorkInProgress = ProductionAccomplishmentBalance.WorkInProgress
	|			AND TemporaryTable.Operation = ProductionAccomplishmentBalance.Operation
	|			AND TemporaryTable.ConnectionKey = ProductionAccomplishmentBalance.ConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TemporaryTable.Specification AS ParentSpecification,
	|	ISNULL(BillsOfMaterialsContent.Specification, VALUE(Catalog.BillsOfMaterials.EmptyRef)) AS Specification
	|FROM
	|	TemporaryTable AS TemporaryTable
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		ON TemporaryTable.Specification = BillsOfMaterialsContent.Ref
	|			AND TemporaryTable.ConnectionKey = BillsOfMaterialsContent.ActivityConnectionKey
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionOrderProducts.Ref AS ProductionOrder,
	|	ProductionOrderProducts.Specification AS Specification
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN Document.ProductionOrder.Products AS ProductionOrderProducts
	|		ON DocumentsForUpdatingStatuses.Document = ProductionOrderProducts.Ref
	|
	|GROUP BY
	|	ProductionOrderProducts.Ref,
	|	ProductionOrderProducts.Specification
	|
	|ORDER BY
	|	ProductionOrder
	|TOTALS BY
	|	ProductionOrder";
	
	QueryResult = Query.ExecuteBatch();
	
	MainTable = QueryResult[2].Unload();
	ProdOrderSelection = QueryResult[4].Select(QueryResultIteration.ByGroups);
	
	If MainTable.Count() Then
		
		BOMsStructure = QueryResult[3].Unload();
		
		BOMTree = New ValueTree;
		BOMTree.Columns.Add("Specification");
		BOMTree.Columns.Add("AllFinished");
		
		MaxNumberOfBOMLevels = Constants.MaxNumberOfBOMLevels.Get();
		
		While ProdOrderSelection.Next() Do
			ProdOrder = ProdOrderSelection.ProductionOrder;
			BOMTree.Rows.Clear();
			
			Specifications = ProdOrderSelection.Select();
			While Specifications.Next() Do
				Node = BOMTree.Rows.Add();
				Node.Specification = Specifications.Specification;
				AddChildSpecifications(Node, BOMsStructure, 1, MaxNumberOfBOMLevels);
				
				FillCanBeStarted(Node, MainTable, ProdOrder);
			EndDo;
		EndDo;
		
	EndIf;
	
	SetPrivilegedMode(True);
	
	// clear table by Production order
	ProdOrderSelection.Reset();
	While ProdOrderSelection.Next() Do
		RecordSetForUpdating = InformationRegisters.ProductionOperationsSequence.CreateRecordSet();
		RecordSetForUpdating.Filter.ProductionOrder.Set(ProdOrderSelection.ProductionOrder);
		RecordSetForUpdating.Write(True);
	EndDo;
	
	// create new records by Production order
	For Each Row In MainTable Do
		RecordManager = InformationRegisters.ProductionOperationsSequence.CreateRecordManager();
		FillPropertyValues(RecordManager, Row);
		RecordManager.Write(True);
	EndDo;
	
	// delete Production order from task to Reflect production operations sequence 
	ProdOrderSelection.Reset();
	While ProdOrderSelection.Next() Do
		RecordSetForUpdating = InformationRegisters.TasksForUpdatingStatuses.CreateRecordSet();
		RecordSetForUpdating.Filter.Document.Set(ProdOrderSelection.ProductionOrder);
		RecordSetForUpdating.Write(True);
	EndDo;
	
	SetPrivilegedMode(False);
	
EndProcedure

Procedure AddChildSpecifications(Node, BOMsStructure, Val CurLevel, Val MaxNumberOfBOMLevels)
	
	If CurLevel > MaxNumberOfBOMLevels Then
		Return;
	EndIf;
	
	Filter = New Structure;
	Filter.Insert("ParentSpecification", Node.Specification);
	
	Children = BOMsStructure.FindRows(Filter);
	For Each ChildLine In Children Do
		
		If ValueIsFilled(ChildLine.Specification) Then
			
			NewNode = Node.Rows.Add();
			NewNode.Specification = ChildLine.Specification;
			
			AddChildSpecifications(NewNode, BOMsStructure, CurLevel+1, MaxNumberOfBOMLevels);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure FillCanBeStarted(Node, MainTable, ProdOrder)
	
	Node.AllFinished = True;
	
	If Node.Rows.Count() Then
		For Each Row In Node.Rows Do
			FillCanBeStarted(Row, MainTable, ProdOrder);
		EndDo;
	Else
		
		CheckSpecificationOperations(Node, ProdOrder, MainTable);
		Return;
		
	EndIf;
	
	For Each Row In Node.Rows Do
		If Not Row.AllFinished Then
			Node.AllFinished = False;
			Break;
		EndIf;
	EndDo;
	
	If Node.AllFinished Then
		CheckSpecificationOperations(Node, ProdOrder, MainTable);
	EndIf;
	
EndProcedure

Procedure CheckSpecificationOperations(Node, ProdOrder, MainTable)
	
	Filter = New Structure("ProductionOrder, BillOfMaterials", ProdOrder, Node.Specification);
	
	SpecificationRows = MainTable.FindRows(Filter);
	NewTable = MainTable.CopyColumns();
	For Each Row In SpecificationRows Do
		NewRow = NewTable.Add();
		FillPropertyValues(NewRow,Row);
	EndDo;
	
	NewTable.Sort("SequenceNumber");
	
	For Each Row In NewTable Do
		If Not Row.IsFinished Then
			Node.AllFinished = False;
			
			Filter.Insert("Operation", Row.Operation);
			Filter.Insert("ConnectionKey", Row.ConnectionKey);
			MainTableRows = MainTable.FindRows(Filter);
			MainTableRows[0].CanBeStarted = True;
			
			Filter.Delete("Operation");
			Filter.Delete("ConnectionKey");
			
			Filter.Insert("WorkInProgress", MainTableRows[0].WorkInProgress);
			Filter.Insert("SequenceNumber", MainTableRows[0].SequenceNumber);
			Filter.Insert("IsFinished", False);
			Filter.Insert("CanBeStarted", False);
			MainTableRows = MainTable.FindRows(Filter);
			For Each MainTableRow In MainTableRows Do
				MainTableRow.CanBeStarted = True;
			EndDo;
			
			Break;
		EndIf;
	EndDo;
	
EndProcedure

Procedure StartUpdateDocumentStatuses() Export
	
	ScheduledJob 	= Metadata.ScheduledJobs.UpdateDocumentStatuses;
	MethodName 		= ScheduledJob.MethodName;
	
	Filter = New Structure;
	Filter.Insert("MethodName", MethodName);
	Filter.Insert("State", BackgroundJobState.Active);
	
	ActiveJobs = BackgroundJobs.GetBackgroundJobs(Filter);
	If ActiveJobs.Count() = 0 Then
		BackgroundJobs.Execute(MethodName,,, ScheduledJob.Synonym);
	EndIf;
	
EndProcedure

// end Drive.FullVersion

Function GetAttributeVariant(AttributeName) Export
	
	If Metadata.ScriptVariant = Metadata.ObjectProperties.ScriptVariant.Russian Then
		If Upper(AttributeName) = Upper("Ref") Then
			Return "Ссылка";
		ElsIf Upper(AttributeName) = Upper("Name") Then
			Return "Наименование";
		ElsIf Upper(AttributeName) = Upper("Code") Then
			Return "Код";
		ElsIf Upper(AttributeName) = Upper("Number") Then
			Return "Номер";
		ElsIf Upper(AttributeName) = Upper("Date") Then
			Return "Дата";
		Else
			Return AttributeName;
		EndIf;
	Else
		Return AttributeName;
	EndIf;
	
EndFunction

Procedure ValueTableEnumerateRows(ValueTable, ColumnName, StartNumber) Export
	
	If ValueTable.Columns.Find(ColumnName) = Undefined Then
		ValueTable.Columns.Add(ColumnName);
	EndIf;
	
	CurrentNumber = StartNumber;
	For Each Row In ValueTable Do
		
		Row[ColumnName] = CurrentNumber;
		CurrentNumber = CurrentNumber + 1;
		
	EndDo;
	
EndProcedure

Procedure ValueTableCreateTypedColumnsByRegister(ValueTable, RegisterName, RegisterType= "InformationRegister") Export
	
	MetadataRegister = StringFunctionsClientServer.SubstituteParametersToString("%1s", RegisterType);
	
	For Each Column In Metadata[MetadataRegister][RegisterName].Dimensions Do
		ValueTable.Columns.Add(Column.Name, Column.Type);
	EndDo;
	For Each Column In Metadata[MetadataRegister][RegisterName].Resources Do
		ValueTable.Columns.Add(Column.Name, Column.Type);
	EndDo;
	For Each Column In Metadata[MetadataRegister][RegisterName].Attributes Do
		ValueTable.Columns.Add(Column.Name, Column.Type);
	EndDo;
	For Each Column In Metadata[MetadataRegister][RegisterName].StandardAttributes Do
		ValueTable.Columns.Add(Column.Name, Column.Type);
	EndDo;
	
EndProcedure

Function IsRestrictedByCompany() Export
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT DISTINCT
	|	AccessGroupsUsers.Ref AS Ref
	|INTO UsersGroups
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	AccessGroupsUsers.User = &User
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccessGroupsAccessValues.AccessValue AS AccessValue
	|FROM
	|	Catalog.AccessGroups.AccessValues AS AccessGroupsAccessValues
	|WHERE
	|	AccessGroupsAccessValues.Ref IN
	|			(SELECT
	|				UsersGroups.Ref AS Ref
	|			FROM
	|				UsersGroups AS UsersGroups)
	|	AND AccessGroupsAccessValues.AccessKind = &AccessKind";
	
	Query.SetParameter("AccessKind", Catalogs.Companies.EmptyRef());
	Query.SetParameter("User", Users.CurrentUser());
	
	QueryResult = Query.Execute();
	
	SetPrivilegedMode(False);
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsOfDocumentHeaderFilling

// Procedure is designed to fill in
// the documents general attributes. It is called in the OnCreateAtServer event handlers in the form modules of all documents.
//
// Parameters:
//  DocumentObject					- object of the edited document;
//  OperationKind						- optional, operation kind row ("Purchase"
// 									or "Sell") if it is not passed, the attributes that depend on the operation type are not filled in
//
//  ParameterCopiedObject		- REF in document copying either structure with
//  data copying BasisParameter				- ref to base document or a structure with copying data
//
Procedure FillDocumentHeader(Object,
	OperationKind = "",
	ParameterCopyingValue = Undefined,
	BasisParameter = Undefined,
	PostingIsAllowed,
	FillingValues = Undefined) Export
	
	User 		= Users.CurrentUser();
	DocumentMetadata = Object.Ref.Metadata();
	PostingIsAllowed = DocumentMetadata.Posting = Metadata.ObjectProperties.Posting.Allow;
	
	If ValueIsFilled(BasisParameter)
		And Not TypeOf(BasisParameter) = Type("Structure") Then
		
		BasisDocumentMetadata = BasisParameter.Metadata();
		
	EndIf;
	
	If ValueIsFilled(ParameterCopyingValue) 
		And Not TypeOf(ParameterCopyingValue) = Type("Structure") Then
		
		CopyingDocumentMetadata =  ParameterCopyingValue.Metadata();
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		Object.Author				= User;
		
	EndIf;
	
	//  Exceptions
	If DocumentMetadata.Name = "SalesSlip"
	Or DocumentMetadata.Name = "ProductReturn" Then
	
		If Not ValueIsFilled(Object.Ref)
			And IsDocumentAttribute("Responsible", DocumentMetadata)
			And Not (FillingValues <> Undefined 
				And FillingValues.Property("Responsible") 
				And ValueIsFilled(FillingValues.Responsible))
			And Not ValueIsFilled(Object.Responsible) Then
			
			Object.Responsible = 
				DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
			
		EndIf;
		
		Return;
		
	EndIf;
	
	//  Filling
	If Not ValueIsFilled(Object.Ref) Then
		
		If IsDocumentAttribute("AmountIncludesVAT", DocumentMetadata) Then 					// Document has the AmountIncludesVAT attribute
			
			If ValueIsFilled(BasisParameter) 												// Fill in if the base parameter is filled in
				And Not TypeOf(BasisParameter) = Type("Structure")									// (in some cases, a structure is passed instead of a document ref)
				And IsMetadataKindDocument(BasisDocumentMetadata.Name) 						// and base is a document and not, for example, a catalog
				And IsDocumentAttribute("AmountIncludesVAT", BasisDocumentMetadata) Then 	// that has the similar attribute "AmountIncludesVAT"
				
				Object.AmountIncludesVAT = BasisParameter.AmountIncludesVAT;
				
			ElsIf ValueIsFilled(ParameterCopyingValue) 								// Fill in if the copying parameter is filled in.
				And Not TypeOf(ParameterCopyingValue) = Type("Structure")							// (in some cases, a structure is passed instead of a document ref)
				And IsMetadataKindDocument(CopyingDocumentMetadata.Name)						// and is a document 
				And IsDocumentAttribute("AmountIncludesVAT", CopyingDocumentMetadata) Then	// that has the similar attribute "AmountIncludesVAT"
				
				Object.AmountIncludesVAT = ParameterCopyingValue.AmountIncludesVAT;
				
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(ParameterCopyingValue) Then
			
			If DocumentMetadata.Name = "ShiftClosure" Then
				If IsDocumentAttribute("PositionAssignee", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PositionAssignee");
					If ValueIsFilled(SettingValue) Then
						If Object.PositionAssignee <> SettingValue Then
							Object.PositionAssignee = SettingValue;
						EndIf;
					Else
						Object.PositionAssignee = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				If IsDocumentAttribute("PositionResponsible", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PositionResponsible");
					If ValueIsFilled(SettingValue) Then
						If Object.PositionResponsible <> SettingValue Then
							Object.PositionResponsible = SettingValue;
						EndIf;
					Else
						Object.PositionResponsible = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				Return;
			EndIf;
			
			If IsDocumentAttribute("Company", DocumentMetadata) 
				And Not (FillingValues <> Undefined And FillingValues.Property("Company") And ValueIsFilled(FillingValues.Company))
				And Not (ValueIsFilled(BasisParameter)
				And ValueIsFilled(Object.Company)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainCompany");
				If ValueIsFilled(SettingValue) Then
					If Object.Company <> SettingValue Then
						Object.Company = SettingValue;
					EndIf;
				Else
					Object.Company = GetPredefinedCompany();
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "OpeningBalanceEntry" Then
				If IsDocumentAttribute("InventoryValuationMethod", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("InventoryValuationMethod") And ValueIsFilled(FillingValues.InventoryValuationMethod))
					And Not (ValueIsFilled(BasisParameter)
					And ValueIsFilled(Object.InventoryValuationMethod)) Then
					SettingValue = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Undefined, Object.Company);
					If ValueIsFilled(SettingValue) Then
						If Object.InventoryValuationMethod <> SettingValue Then
							Object.InventoryValuationMethod = SettingValue;
						EndIf;
					Else
						Object.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
					EndIf;
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("SalesStructuralUnit", DocumentMetadata) 
				And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.SalesStructuralUnit)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				
				If ValueIsFilled(SettingValue) Then
					If Object.SalesStructuralUnit <> SettingValue Then
						Object.SalesStructuralUnit = SettingValue;
					EndIf;
				Else
					Object.SalesStructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Department);	
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("Department", DocumentMetadata) 
				And Not (FillingValues <> Undefined And FillingValues.Property("Department") And ValueIsFilled(FillingValues.Department))
				And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.Department)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If ValueIsFilled(SettingValue) Then
					If Object.Department <> SettingValue Then
						Object.Department = SettingValue;
					EndIf;
				Else
					Object.Department = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Department);
				EndIf;
			EndIf;
			
			FunctionalCurrency = DriveReUse.GetFunctionalCurrency();
			
			If IsDocumentAttribute("DocumentCurrency", DocumentMetadata)
				And Not ValueIsFilled(Object.DocumentCurrency)
				And Not (FillingValues <> Undefined
				    And FillingValues.Property("DocumentCurrency")
				    And ValueIsFilled(FillingValues.DocumentCurrency)) Then
				Object.DocumentCurrency = FunctionalCurrency;
			EndIf;
			
			If IsDocumentAttribute("CashCurrency", DocumentMetadata) Then
				If Not ValueIsFilled(Object.CashCurrency) Then
					Object.CashCurrency = FunctionalCurrency;
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("SettlementsCurrency", DocumentMetadata) Then
				If Not ValueIsFilled(Object.SettlementsCurrency) Then
					Object.SettlementsCurrency = FunctionalCurrency;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "EmployeeTask"
			 Or DocumentMetadata.Name = "PurchaseOrder"
			 Or DocumentMetadata.Name = "Payroll"
			 Or DocumentMetadata.Name = "SalesTarget"
			 Or DocumentMetadata.Name = "PayrollSheet"
			 Or DocumentMetadata.Name = "OtherExpenses"
			 Or DocumentMetadata.Name = "CostAllocation"
			 Or DocumentMetadata.Name = "JobSheet"
			 Or DocumentMetadata.Name = "Timesheet"
			 Or DocumentMetadata.Name = "WeeklyTimesheet"
			 Then
				If IsDocumentAttribute("StructuralUnit", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.StructuralUnit)) Then
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Department);	
					EndIf;
						
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("StructuralUnitReserve", DocumentMetadata) 
				And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.StructuralUnitReserve)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
				If ValueIsFilled(SettingValue) 
					And StructuralUnitTypeToChoiceParameters("StructuralUnitReserve", DocumentMetadata, SettingValue) Then
					If Object.StructuralUnitReserve <> SettingValue Then
						Object.StructuralUnitReserve = SettingValue;
					EndIf;
				Else
					Object.StructuralUnitReserve = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Warehouse);
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "AdditionalExpenses"
				Or DocumentMetadata.Name = "Stocktaking"
				Or DocumentMetadata.Name = "InventoryIncrease"
				Or DocumentMetadata.Name = "IntraWarehouseTransfer"
				Or DocumentMetadata.Name = "FixedAssetRecognition"
				Or DocumentMetadata.Name = "SupplierInvoice"
				Or DocumentMetadata.Name = "SalesInvoice"
				Or DocumentMetadata.Name = "InventoryWriteOff"
				Or DocumentMetadata.Name = "SubcontractorOrderIssued"
				Or DocumentMetadata.Name = "SubcontractorInvoiceReceived" 
				// begin Drive.FullVersion
				Or DocumentMetadata.Name = "SubcontractorOrderReceived"
				Or DocumentMetadata.Name = "SubcontractorInvoiceIssued" 
				// end Drive.FullVersion 
				Then
				
				If IsDocumentAttribute("StructuralUnit", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.StructuralUnit)) Then
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Warehouse);
					EndIf;
				EndIf;
			EndIf;
			
			// begin Drive.FullVersion
			If DocumentMetadata.Name = "Production"
				Or DocumentMetadata.Name = "Manufacturing" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit))
					And Not (ValueIsFilled(BasisParameter)
					And ValueIsFilled(Object.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Department);	
					EndIf;
				EndIf;
				
				// business unit of products.
				If Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.ProductsStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferRecipient)
						And (Object.StructuralUnit.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
							Or Object.StructuralUnit.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Department) Then
						Object.ProductsStructuralUnit = Object.StructuralUnit.TransferRecipient;
						Object.ProductsCell = Object.StructuralUnit.TransferRecipientCell;
					Else
						Object.ProductsStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
						
				// Inventory business unit.
				If Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.InventoryStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferSource)
						And (Object.StructuralUnit.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
							Or Object.StructuralUnit.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department) Then
						Object.InventoryStructuralUnit = Object.StructuralUnit.TransferSource;
						Object.CellInventory = Object.StructuralUnit.TransferSourceCell;
					Else
						Object.InventoryStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
				
				// business unit of waste.
				If Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.DisposalsStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.RecipientOfWastes) Then
						Object.DisposalsStructuralUnit = Object.StructuralUnit.RecipientOfWastes;
						Object.DisposalsCell = Object.StructuralUnit.DisposalsRecipientCell;
					Else
						Object.DisposalsStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
				
			EndIf;
			// end Drive.FullVersion
			
			If DocumentMetadata.Name = "InventoryTransfer" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
				If Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit))
					And Not (ValueIsFilled(BasisParameter) 
					And ValueIsFilled(Object.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Warehouse);
					EndIf;
				EndIf;
				
				// business unit receiver.
				If Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnitPayee") And ValueIsFilled(FillingValues.StructuralUnitPayee))
					And Not (ValueIsFilled(BasisParameter) 
					And ValueIsFilled(Object.StructuralUnitPayee)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferRecipient) Then
						Object.StructuralUnitPayee = Object.StructuralUnit.TransferRecipient;
						Object.CellPayee = Object.StructuralUnit.TransferRecipientCell;
					EndIf;
				EndIf;
				
			EndIf;
			
			If DocumentMetadata.Name = "TransferOrder" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
				If Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit))
					And Not (ValueIsFilled(BasisParameter) 
					And ValueIsFilled(Object.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Warehouse);
					EndIf;
				EndIf;
				
			EndIf;
			
			// begin Drive.FullVersion
			If DocumentMetadata.Name = "ProductionOrder" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If Not (ValueIsFilled(BasisParameter) 
					And ValueIsFilled(Object.StructuralUnit))
					And Not (FillingValues <> Undefined And FillingValues.Property("StructuralUnit") And ValueIsFilled(FillingValues.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						And StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = GetPredefinedBusinessUnit(Enums.BusinessUnitsTypes.Department);	
					EndIf;
				EndIf;
				
			EndIf;
			// end Drive.FullVersion
			
			If IsDocumentAttribute("Responsible", DocumentMetadata)
				And Not (FillingValues <> Undefined And FillingValues.Property("Responsible") And ValueIsFilled(FillingValues.Responsible))
				And Not ValueIsFilled(Object.Responsible) Then
				Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
			EndIf;
			
			If IsDocumentAttribute("PriceKind", DocumentMetadata)
			   And DocumentMetadata.Name <> "ShiftClosure"
			   And DocumentMetadata.Name <> "SalesSlip"
			   And DocumentMetadata.Name <> "ProductReturn" 
			   And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.PriceKind))
			   And Not (FillingValues <> Undefined And FillingValues.Property("PriceKind")) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainPriceTypesales");
				If ValueIsFilled(SettingValue) Then
					If Object.PriceKind <> SettingValue Then
						Object.PriceKind = SettingValue;
					EndIf;
				Else
					Object.PriceKind = Catalogs.PriceTypes.Wholesale;
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("PriceKind", DocumentMetadata)
			   And ValueIsFilled(Object.PriceKind) 
			   And Not ValueIsFilled(BasisParameter) Then
				If IsDocumentAttribute("AmountIncludesVAT", DocumentMetadata) Then
					Object.AmountIncludesVAT = Object.PriceKind.PriceIncludesVAT;
				EndIf;
			EndIf;
			
			// begin Drive.FullVersion
			If DocumentMetadata.Name = "ProductionOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("OrderState") And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.OrderState)) Then
					If Constants.UseProductionOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.ProductionOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.ProductionOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			// end Drive.FullVersion
			
			If DocumentMetadata.Name = "KitOrder" Then
				
				If IsDocumentAttribute("OrderState", DocumentMetadata)
					And Not (FillingValues <> Undefined
					And FillingValues.Property("OrderState")
					And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter)
					And ValueIsFilled(Object.OrderState)) Then
					
					If Constants.UseKitOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewKitOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.KitOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.KitOrdersInProgressStatus.Get();
					EndIf;
					
				EndIf;
				
			EndIf;
			
			If DocumentMetadata.Name = "PurchaseOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("OrderState") And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.OrderState)) Then
					If Constants.UsePurchaseOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.PurchaseOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SalesOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("OrderState") And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.OrderState)) Then
					If Constants.UseSalesOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSalesOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.SalesOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.SalesOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SubcontractorOrderIssued" Then
				
				If IsDocumentAttribute("OrderState", DocumentMetadata)
					And Not (FillingValues <> Undefined
					And FillingValues.Property("OrderState")
					And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter)
					And ValueIsFilled(Object.OrderState)) Then
					
					If Constants.UseSubcontractorOrderIssuedStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSubcontractorOrderIssued");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.SubcontractorOrderIssuedStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.SubcontractorOrderIssuedInProgressStatus.Get();
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// begin Drive.FullVersion
			
			If DocumentMetadata.Name = "SubcontractorOrderReceived" Then
				
				If IsDocumentAttribute("OrderState", DocumentMetadata)
					And Not (FillingValues <> Undefined
					And FillingValues.Property("OrderState")
					And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter)
					And ValueIsFilled(Object.OrderState)) Then
					
					If Constants.UseSubcontractorOrderReceivedStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSubcontractorOrderReceived");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.SubcontractorOrderReceivedStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.SubcontractorOrderReceivedInProgressStatus.Get();
					EndIf;
					
				EndIf;
				
			EndIf;
			
			// end Drive.FullVersion 
			
			If DocumentMetadata.Name = "TransferOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("OrderState") And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.OrderState)) Then
					If Constants.UseTransferOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewTransferOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.TransferOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.TransferOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "PurchaseOrder" Then
				If IsDocumentAttribute("ReceiptDatePosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "ReceiptDatePositionInPurchaseOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.ReceiptDatePosition <> SettingValue Then
							Object.ReceiptDatePosition = SettingValue;
						EndIf;
					Else
						Object.ReceiptDatePosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "EmployeeTask" Then
				If IsDocumentAttribute("WorkKindPosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "WorkKindPositionInWorkTask");
					If ValueIsFilled(SettingValue) Then
						If Object.WorkKindPosition <> SettingValue Then
							Object.WorkKindPosition = SettingValue;
						EndIf;
					Else
						Object.WorkKindPosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SalesOrder" Then
				If IsDocumentAttribute("ShipmentDatePosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "ShipmentDatePositionInSalesOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.ShipmentDatePosition <> SettingValue Then
							Object.ShipmentDatePosition = SettingValue;
						EndIf;
					Else
						Object.ShipmentDatePosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SupplierInvoice" Then
				If IsDocumentAttribute("PurchaseOrderPosition", DocumentMetadata)
					
					And Not (FillingValues <> Undefined
					And FillingValues.Property("PurchaseOrderPosition")
					And ValueIsFilled(FillingValues.PurchaseOrderPosition))
					
					And Not (ValueIsFilled(BasisParameter) 
					And ValueIsFilled(Object.PurchaseOrderPosition)
					And Object.PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection) Then
					
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PurchaseOrderPositionInReceiptDocuments");
					If ValueIsFilled(SettingValue) Then
						If Object.PurchaseOrderPosition <> SettingValue Then
							Object.PurchaseOrderPosition = SettingValue;
						EndIf;
					Else
						Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "InventoryTransfer" Then
				If IsDocumentAttribute("SalesOrderPosition", DocumentMetadata) 
					
					And Not (ValueIsFilled(Object.SalesOrderPosition)) Then 
					
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "SalesOrderPositionInInventoryTransfer");
					If ValueIsFilled(SettingValue) Then
						If Object.SalesOrderPosition <> SettingValue Then
							Object.SalesOrderPosition = SettingValue;
						EndIf;
					Else
						Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
			EndIf;
			
			// begin Drive.FullVersion
			If DocumentMetadata.Name = "ProductionOrder" Then
				If IsDocumentAttribute("UseCompanyResources", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseCompanyResourcesInProductionOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseCompanyResources <> SettingValue Then
							Object.UseCompanyResources = SettingValue;
						EndIf;
					Else
						Object.UseCompanyResources = True;
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "ManufacturingOperation" Then
				If IsDocumentAttribute("InventoryStructuralUnitPosition", DocumentMetadata) Then
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "InventoryStructuralUnitPositionInWIP");
					If ValueIsFilled(SettingValue) Then
						If Object.InventoryStructuralUnitPosition <> SettingValue Then
							Object.InventoryStructuralUnitPosition = SettingValue;
						EndIf;
					Else
						Object.InventoryStructuralUnitPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
			EndIf;
			// end Drive.FullVersion
			
			If DocumentMetadata.Name = "WorkOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					And Not (FillingValues <> Undefined And FillingValues.Property("OrderState") And ValueIsFilled(FillingValues.OrderState))
					And Not (ValueIsFilled(BasisParameter) And ValueIsFilled(Object.OrderState)) Then
					If Constants.UseSalesOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewWorkOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.WorkOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.WorkOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
				If IsDocumentAttribute("WorkKindPosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "WorkKindPositionInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.WorkKindPosition <> SettingValue Then
							Object.WorkKindPosition = SettingValue;
						EndIf;
					Else
						Object.WorkKindPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseProducts", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseProductsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseProducts <> SettingValue Then
							Object.UseProducts = SettingValue;
						EndIf;
					Else
						Object.UseProducts = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseCompanyResources", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseCompanyResourcesInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseCompanyResources <> SettingValue Then
							Object.UseCompanyResources = SettingValue;
						EndIf;
					Else
						Object.UseCompanyResources = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseConsumerMaterials", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseConsumerMaterialsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseConsumerMaterials <> SettingValue Then
							Object.UseConsumerMaterials = SettingValue;
						EndIf;
					Else
						Object.UseConsumerMaterials = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseMaterials", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseMaterialsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseMaterials <> SettingValue Then
							Object.UseMaterials = SettingValue;
						EndIf;
					Else
						Object.UseMaterials = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UsePerformerSalaries", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UsePerformerSalariesInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UsePerformerSalaries <> SettingValue Then
							Object.UsePerformerSalaries = SettingValue;
						EndIf;
					Else
						Object.UsePerformerSalaries = True;
					EndIf;
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

// Function returns predefined company.
//
Function GetPredefinedCompany() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Company;
	Else	
		Return Catalogs.Companies.EmptyRef();
	EndIf;	
	
EndFunction

// Function returns predefined Business unit.
//
Function GetPredefinedBusinessUnit(StructuralUnitType) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	BusinessUnits.Ref AS BusinessUnit
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Predefined
	|	AND BusinessUnits.StructuralUnitType = &StructuralUnitType";
	
	Query.SetParameter("StructuralUnitType", StructuralUnitType);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.BusinessUnit;
	Else
		Return Catalogs.BusinessUnits.EmptyRef();
	EndIf;
	
EndFunction

// The function returns a default specification for products, variants.
//
Function GetDefaultSpecification(Products, Characteristic = Undefined, OperationTypeOrder = Undefined, ExcludeByProducts = False) Export
	
	DefaultSpecification = Catalogs.BillsOfMaterials.EmptyRef();
	
	If ValueIsFilled(Products) Then
		ProductSpecification = Common.ObjectAttributeValue(Products, "Specification");
	Else
		ProductSpecification = Catalogs.BillsOfMaterials.EmptyRef();
	EndIf;
	
	If ValueIsFilled(ProductSpecification) Then
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			ProductCharacteristic = ?(ValueIsFilled(Characteristic), Characteristic, Catalogs.ProductsCharacteristics.EmptyRef());
			
			If ProductSpecification.ProductCharacteristic <> ProductCharacteristic Then
				ProductSpecification = Catalogs.BillsOfMaterials.EmptyRef();
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(OperationTypeOrder) And ValueIsFilled(ProductSpecification) Then
		
		SpecificationOperationKind = Common.ObjectAttributeValue(ProductSpecification, "OperationKind");
		
		If Not OperationTypeOrder = SpecificationOperationKind Then
			
			ProductSpecification = Catalogs.BillsOfMaterials.EmptyRef();
			
		EndIf;
		
	EndIf;
	
	If ExcludeByProducts And ProductSpecification.ByProducts.Count() Then
		ProductSpecification = Catalogs.BillsOfMaterials.EmptyRef();
	EndIf;
	
	If ProductSpecification.IsEmpty() Then
		
		Query = New Query;
		Query.Text = 
		"SELECT DISTINCT
		|	BillsOfMaterials.Ref AS Ref
		|FROM
		|	Catalog.BillsOfMaterials AS BillsOfMaterials
		|		LEFT JOIN Catalog.BillsOfMaterials.ByProducts AS BillsOfMaterialsByProducts
		|		ON BillsOfMaterials.Ref = BillsOfMaterialsByProducts.Ref
		|WHERE
		|	BillsOfMaterials.Owner = &Products
		|	AND NOT BillsOfMaterials.DeletionMark
		|	AND &ConditionCharacteristic
		|	AND &ConditionOperationKind
		|	AND (BillsOfMaterialsByProducts.Product IS NULL
		|			OR NOT &ExcludeByProducts)";
		
		Query.SetParameter("Products", Products);
		Query.SetParameter("ExcludeByProducts", ExcludeByProducts);
		
		If GetFunctionalOption("UseCharacteristics") Then
			
			ProductCharacteristic = ?(ValueIsFilled(Characteristic), Characteristic, Catalogs.ProductsCharacteristics.EmptyRef());
			
			Query.Text = StrReplace(Query.Text, "&ConditionCharacteristic", "BillsOfMaterials.ProductCharacteristic = &ProductCharacteristic");
			Query.SetParameter("ProductCharacteristic", ProductCharacteristic);
			
		Else
			
			Query.SetParameter("ConditionCharacteristic", True);
			
		EndIf;
			
		If ValueIsFilled(OperationTypeOrder) Then
			
			Query.Text = StrReplace(Query.Text, "&ConditionOperationKind", "BillsOfMaterials.OperationKind = &OperationKind");
			Query.SetParameter("OperationKind", OperationTypeOrder);
			
		Else
			
			Query.Text = StrReplace(Query.Text, "&ConditionOperationKind", "BillsOfMaterials.OperationKind <> &OperationKind");
			Query.SetParameter("OperationKind", Enums.OperationTypesProductionOrder.Disassembly);
			
		EndIf;
		
		Result = Query.Execute().Unload();
		
		If Result.Count() = 1 Then
			ProductSpecification = Result[0].Ref;
		EndIf;
		
	EndIf;
	
	Return ProductSpecification;
	
EndFunction

// Gets the default contract depending on the account details.
//
Function GetContractByDefault(Document,
	Counterparty,
	Company,
	OperationKind = Undefined,
	TabularSectionName = "",
	Currency = Undefined) Export
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	If ValueIsFilled(Counterparty) Then
		ContractTypesList = ManagerOfCatalog.GetContractTypesListForDocument(Document, OperationKind, TabularSectionName);
		ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty,
			Company,
			ContractTypesList,
			Currency);
	Else
		ContractByDefault = ManagerOfCatalog.EmptyRef();
	EndIf;
	
	Return ContractByDefault;
	
EndFunction

#Region PurchaseDocumentsFormEvents

Function GetDataContractOnChange(Date, DocumentCurrency, Contract, Company) Export
	
	StructureData = New Structure();
	
	StructureData.Insert(
	"SettlementsCurrency",
	Contract.SettlementsCurrency);
	
	StructureData.Insert(
	"SettlementsCurrencyRateRepetition",
	CurrencyRateOperations.GetCurrencyRate(Date, Contract.SettlementsCurrency, Company));
	
	StructureData.Insert(
	"SupplierPriceTypes",
	Contract.SupplierPriceTypes);
	
	If Not ValueIsFilled(StructureData.SupplierPriceTypes) Then
		MainSupplierPriceType = DriveReUse.GetValueOfSetting("MainSupplierPriceType");
		If ValueIsFilled(MainSupplierPriceType) Then
			StructureData.SupplierPriceTypes = MainSupplierPriceType;
		EndIf;	
	EndIf;
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(StructureData.SupplierPriceTypes), StructureData.SupplierPriceTypes.PriceIncludesVAT, Undefined));
	
	StructureData.Insert("DiscountType", Common.ObjectAttributeValue(Contract, "DiscountMarkupKind"));
	
	Return StructureData;
	
EndFunction

Function GetDataCounterpartyOnChange(Ref, Date, Counterparty, Company) Export
	
	ContractByDefault = GetContractByDefault(Ref, Counterparty, Company);
	
	StructureData = New Structure;
	
	StructureData.Insert(
		"Contract",
		ContractByDefault);
		
	StructureData.Insert(
		"SettlementsCurrency",
		ContractByDefault.SettlementsCurrency);
	
	StructureData.Insert(
		"SettlementsCurrencyRateRepetition",
		CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company));
	
	StructureData.Insert(
		"SupplierPriceTypes",
		ContractByDefault.SupplierPriceTypes);
	
	If Not ValueIsFilled(StructureData.SupplierPriceTypes) Then
		MainSupplierPriceType = DriveReUse.GetValueOfSetting("MainSupplierPriceType");
		If ValueIsFilled(MainSupplierPriceType) Then
			StructureData.SupplierPriceTypes = MainSupplierPriceType;
		EndIf;	
	EndIf;
	
	StructureData.Insert(
		"AmountIncludesVAT",
		?(ValueIsFilled(StructureData.SupplierPriceTypes), StructureData.SupplierPriceTypes.PriceIncludesVAT, Undefined));
	
	StructureData.Insert("DiscountType", Common.ObjectAttributeValue(ContractByDefault, "DiscountMarkupKind"));
	
	Return StructureData;
	
EndFunction

#EndRegion

#EndRegion

#Region ExportProceduresAndFunctions

Procedure CheckObjectGeneratedEnteringBalances(Form) Export
	
	If Form.Object.ForOpeningBalancesOnly Then
		
		For Each Item In Form.Items Do
			
			If TypeOf(Item) = Type("FormField") And Item.Type = FormFieldType.InputField Then
				
				Item.AutoMarkIncomplete = False;
				
			EndIf;
			
		EndDo;
		
		Message = NStr("en = 'This document was automatically generated upon posting the Opening balance entry document.'; ru = 'Этот документ был создан автоматически при проведении документа ""Ввод начальных остатков"".';pl = 'Ten dokument został wygenerowany automatycznie podczas zatwierdzenia dokumentu ""Wprowadzenie salda początkowego"".';es_ES = 'Este documento se ha generado automáticamente al contabilizar el documento Entrada de saldo de apertura.';es_CO = 'Este documento se ha generado automáticamente al contabilizar el documento Entrada de saldo de apertura.';tr = 'Bu belge, Açılış bakiyesi giriş belgesinin kaydedilmesi üzerine otomatik olarak oluşturulmuştur.';it = 'Questo documento è stato generato automaticamente durante la pubblicazione del documento di ingresso Saldo iniziale.';de = 'Dieses Dokument wurde bei der Buchung des Dokuments von Anfangssaldo-Buchung automatisch generiert.'");
		CommonClientServer.MessageToUser(Message);
		
	EndIf;
	
EndProcedure

Procedure CheckAvailabilityOfGoodsReturn(Document, Cancel = False) Export
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Document.Date, Document.Company);
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	UseGoodsReturnToSupplier = AccountingPolicy.UseGoodsReturnToSupplier;
	
	If Document.OperationType = Enums.OperationTypesGoodsReceipt.SalesReturn
		And Not UseGoodsReturnFromCustomer Then
		MessageText = NStr("en = 'Couldn''t post the document.
			|For the specified period, the company used Credit notes to post inventory movement on goods returns.
			|To create a new accounting setting, go to Company > Accounting policy.'; 
			|ru = 'Не удалось провести документ.
			|За указанный период организация использовала кредитовые авизо для проведения движения запасов при возврате товаров.
			|Чтобы создать новые настройки учета, перейдите в меню Организация > Учетная политика.';
			|pl = 'Nie udało się zatwierdzić dokumentu.
			|Dla wybranego okresu, firma używała Not kredytowych do zatwierdzenia ruchu zapasów przy zwrotach towarów.
			|Aby utworzyć nową politykę rachunkowości, przejdź do Firma > Polityka rachunkowości.';
			|es_ES = 'No se ha podido enviar el documento.
			|Para el período especificado, la empresa utilizó Notas de crédito para enviar el movimiento de inventario en las devoluciones de mercancías.
			|Para crear una nueva configuración de contabilidad, ir a Empresa > Política de contabilidad.';
			|es_CO = 'No se ha podido enviar el documento.
			|Para el período especificado, la empresa utilizó Notas de crédito para enviar el movimiento de inventario en las devoluciones de mercancías.
			|Para crear una nueva configuración de contabilidad, ir a Empresa > Política de contabilidad.';
			|tr = 'Belge kaydedilemedi.
			|Belirtilen dönem için, iş yeri iade edilen mallarda stok hareketi kaydetmek için Alacak dekontları kullandı.
			|Yeni bir muhasebe ayarı oluşturmak için İş yeri > Muhasebe politikası yolunu takip edin.';
			|it = 'Impossibile pubblicare il documento.
			|Per il periodo indicato, l''azienda utilizza Note di credito per pubblicare i movimenti di scorte sui resi delle merci.
			|Per creare una nuova impostazione di contabilità, andare in Azienda > Politica contabile.';
			|de = 'Fehler beim Buchen des Dokuments.
			|Für den angegebenen Zeitraum verwendet die Firma Gutschriften um Bestandsbewegungen bei Warenretouren zu buchen.
			|Um eine neue Bilanzierungseinstellungen zu erstellen, gehen Sie zu Firma > Bilanzierungsrichtlinien.'");
	ElsIf Document.OperationType = Enums.OperationTypesGoodsIssue.PurchaseReturn
		And Not UseGoodsReturnToSupplier Then
		MessageText = NStr("en = 'Couldn''t post the document.
			|For the specified period, the company used Debit notes to post inventory movement on goods returns.
			|To create a new accounting setting, go to Company > Accounting policy.'; 
			|ru = 'Не удалось провести документ.
			|За указанный период организация использовала дебетовые авизо для проведения движения запасов при возврате товаров.
			|Чтобы создать новые настройки учета, перейдите в меню Организация > Учетная политика.';
			|pl = 'Nie udało się zatwierdzić dokumentu.
			|Dla wybranego okresu, firma używała Not debetowych do zatwierdzenia ruchu zapasów przy zwrotach towarów.
			|Aby utworzyć nową politykę rachunkowości, przejdź do Firma > Polityka rachunkowości.';
			|es_ES = 'No se ha podido enviar el documento.
			|Para el período especificado, la empresa utilizó Notas de débito para enviar el movimiento de inventario en las devoluciones de mercancías.
			|Para crear una nueva configuración de contabilidad, ir a Empresa > Política de contabilidad.';
			|es_CO = 'No se ha podido enviar el documento.
			|Para el período especificado, la empresa utilizó Notas de débito para enviar el movimiento de inventario en las devoluciones de mercancías.
			|Para crear una nueva configuración de contabilidad, ir a Empresa > Política de contabilidad.';
			|tr = 'Belge kaydedilemedi.
			|Belirtilen dönem için, iş yeri iade edilen mallarda stok hareketi kaydetmek için Borç dekontları kullandı.
			|Yeni bir muhasebe ayarı oluşturmak için İş yeri > Muhasebe politikası yolunu takip edin.';
			|it = 'Impossibile pubblicare il documento.
			|Per il periodo indicato, l''azienda utilizza Note di credito ricevute per pubblicare i movimenti di scorte sui resi delle merci.
			|Per creare una nuova impostazione di contabilità, andare in Azienda > Politica contabile.';
			|de = 'Fehler beim Buchen des Dokuments.
			|Für den angegebenen Zeitraum verwendet die Firma Lastschriften um Bestandsbewegungen bei Warenretouren zu buchen.
			|Um eine neue Bilanzierungseinstellungen zu erstellen, gehen Sie zu Firma > Bilanzierungsrichtlinien.'");
	EndIf;
	
	If ValueIsFilled(MessageText) Then
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

Procedure CheckBasis(DataStructure, BasisDocument, Cancel) Export
	
	MessageText = "";
	Ref = DataStructure.Ref;
	
	If TypeOf(Ref) = Type("DocumentRef.CreditNote") Then
		
		If TypeOf(BasisDocument) = Type("DocumentRef.SalesInvoice") Then
			If DataStructure.Inventory.Count() = 0 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'All goods from %1 have been claimed for return.'; ru = 'По документу %1 уже оформлен возврат на все товары.';pl = 'Zwrot według dokumentu %1 został już przeprowadzony dla wszystkich towarów.';es_ES = 'Todas mercancías de %1 se han reclamado para devolución.';es_CO = 'Todas mercancías de %1 se han reclamado para devolución.';tr = 'Tüm malların iadesi %1 talep edilmiştir.';it = 'Per tutte le merci da %1 è stata richiesta la restituzione.';de = 'Alle Waren von %1 wurden für die Rücksendung beansprucht.'"),
					BasisDocument);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Ref) = Type("DocumentRef.DebitNote") Then
		
		If TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
			If DataStructure.Inventory.Count() = 0 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'All goods from %1 have been claimed for return.'; ru = 'По документу %1 уже оформлен возврат на все товары.';pl = 'Zwrot według dokumentu %1 został już przeprowadzony dla wszystkich towarów.';es_ES = 'Todas mercancías de %1 se han reclamado para devolución.';es_CO = 'Todas mercancías de %1 se han reclamado para devolución.';tr = 'Tüm malların iadesi %1 talep edilmiştir.';it = 'Per tutte le merci da %1 è stata richiesta la restituzione.';de = 'Alle Waren von %1 wurden für die Rücksendung beansprucht.'"),
					BasisDocument);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Ref) = Type("DocumentRef.PaymentExpense") Then
		
		If TypeOf(BasisDocument) = Type("DocumentRef.CustomsDeclaration") Then
			OperationKind = Common.ObjectAttributeValue(BasisDocument, "OperationKind");
			If OperationKind <> Enums.OperationTypesCustomsDeclaration.Broker  Then 
				Cancel = True;
				MessageText = NStr("en = 'Cannot create a Bank payment. You can do this only for a
				|Customs declaration with ""Paid to"" set to Customs broker.'; 
				|ru = 'Не удалось создать списание со счета. Его можно создать только для
				|таможенной декларации, у которой в поле ""Платеж"" указано ""Таможенному брокеру"".';
				|pl = 'Nie można utworzyć przelewu wychodzącego. Możesz zrobić to tylko dla a
				|Deklaracji celnej z polem ""Zapłacono do"" ustawionym na Agent celny.';
				|es_ES = 'No se puede crear un pago bancario. Puede hacer esto solo para una
				|declaración de aduanas con ""Pagar para"" configurado como Agente de aduanas.';
				|es_CO = 'No se puede crear un pago bancario. Puede hacer esto solo para una
				|declaración de aduanas con ""Pagar para"" configurado como Agente de aduanas.';
				|tr = 'Banka ödemesi oluşturulamıyor. Bu işlem sadece ""Ödemeyi alan""
				|Gümrük komisyoncusu olarak ayarlanmış Gümrük beyannamesi için yapılabilir.';
				|it = 'Impossibile creare Bonifico bancario. È possibile farlo solo per una 
				|Dichiarazione doganale con ""Pagato a"" impostato su Broker doganale.';
				|de = 'Fehler beim Erstellen der Überweisung. Sie können es nur für eine an Zollagenten festgelegte 
				|Zollanmeldung mit ""Bezahlt an"" tun.'");
			EndIf;
		EndIf;
		
	EndIf;
	
	CheckPOApprovalStatus(BasisDocument, MessageText, Cancel);
	
	If ValueIsFilled(MessageText) Then
		CommonClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

// Displays a message on filling error.
//
Procedure ShowMessageAboutError(ErrorObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancel = False) Export
	
	Message = New UserMessage();
	Message.Text = MessageText;
	
	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;
	
	Message.SetData(ErrorObject);
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Allows to determine whether there is attribute
// with the passed name among the document header attributes.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function IsDocumentAttribute(AttributeName, DocumentMetadata) Export

	If Not DocumentMetadata.Attributes.Find(AttributeName) = Undefined Then
		Return True;
	EndIf;
	
	For Each StandardAttribute In DocumentMetadata.StandardAttributes Do
		If StandardAttribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;

EndFunction

// Allows to determine whether there is attribute
// with the passed name among the document header attributes.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function DocumentAttributeExistsOnLink(AttributeName, DocumentRef) Export

	DocumentMetadata = DocumentRef.Metadata();
	
	If Not DocumentMetadata.Attributes.Find(AttributeName) = Undefined Then
		Return True;
	EndIf;
	
	For Each StandardAttribute In DocumentMetadata.StandardAttributes Do
		If StandardAttribute.Name = AttributeName Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
	
EndFunction

// Allows to determine whether there is attribute
// with the passed path among the object header attributes.
//
// Parameters: 
//  AttributesChain - desired attribute row name with "." 
// separators, e.g. "BasisDocument.Contract.ContractType" 
//  Object - reference or form data structure among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function AttributesChainExist(AttributesChain, Object) Export
	
	If Common.IsReference(TypeOf(Object)) Then
		Ref = Object;
	ElsIf TypeOf(Object) = Type("FormDataStructure") Then
		Ref = Object.Ref;
	Else
		Return False;
	EndIf;		
	
	If AttributesChain.Count() = 0 Then
		Return False;
	ElsIf AttributesChain.Count() = 1 Then
		Return DocumentAttributeExistsOnLink(AttributesChain[0], Ref);
	Else 
		
		AttributeName = AttributesChain[0];
		If DocumentAttributeExistsOnLink(AttributeName, Ref) Then
			AttributesChain.Delete(0);
			Return AttributesChainExist(AttributesChain, Object[AttributeName]);
		Else
			Return False;
		EndIf;
		
	EndIf;
	
EndFunction

// Checks if row contains list separator or receives it from constant.
//
// Parameters: 
//  CheckString - String - String for check.
//
// Returns:
//  String - Character that separates list lines.
//
Function GetListSeparator(CheckString = "") Export
	
	If ValueIsFilled(CheckString) Then
		FormattedString = StringFunctionsClientServer.ReplaceCharsWithOther(" ", Lower(CheckString), "");
		
		If StrStartsWith(FormattedString, "sep=") Then
			ListSeparator =  Mid(FormattedString, 5, 1);
		Else
			ListSeparator = Constants.ListSeparator.Get();
		EndIf;
	Else
		ListSeparator = Constants.ListSeparator.Get();
	EndIf;
	
	Return ListSeparator;
	
EndFunction

// Checks whether business unit meets selection
// parameters of attribute with the passed name.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function StructuralUnitTypeToChoiceParameters(AttributeName, DocumentMetadata, SettingValue)

	ChoiceParameters = DocumentMetadata.Attributes[AttributeName].ChoiceParameters;
	StructuralUnitType = SettingValue.StructuralUnitType;
	For Each ChoiceParameter In ChoiceParameters Do
		If ChoiceParameter.Name = "Filter.StructuralUnitType" Then
			If TypeOf(ChoiceParameter.Value) = Type("FixedArray") Then
				For Each ParameterValue In ChoiceParameter.Value Do
					If StructuralUnitType = ParameterValue Then
						Return True;
					EndIf; 
				EndDo;
			ElsIf TypeOf(ChoiceParameter.Value) = Type("EnumRef.BusinessUnitsTypes") 
				And StructuralUnitType = ChoiceParameter.Value Then
				Return True;
			EndIf; 
		EndIf; 
	EndDo;
	  
	Return False;	  

EndFunction

// The procedure deletes a checked attribute from the array of checked attributes.
Procedure DeleteAttributeBeingChecked(CheckedAttributes, CheckedAttribute) Export
	
	FoundAttribute = CheckedAttributes.Find(CheckedAttribute);
	If FoundAttribute <> Undefined Then
		CheckedAttributes.Delete(FoundAttribute);
	EndIf;
	
EndProcedure

// Procedure creates a new key of links for tables.
//
// Parameters:
//  DocumentForm - ClientApplicationForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For Each TSRow In TabularSection Do
        ValueList.Add(TSRow.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction

// Procedure writes user new setting.
//
Procedure SetUserSetting(SettingValue, SettingName, User = Undefined) Export
	
	If Not ValueIsFilled(User) Then
		
		User = Users.AuthorizedUser();
		
	EndIf;
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();

	RecordSet.Filter.User.Use			= True;
	RecordSet.Filter.User.Value			= User;
	RecordSet.Filter.Setting.Use		= True;
	RecordSet.Filter.Setting.Value		= ChartsOfCharacteristicTypes.UserSettings[SettingName];

	Record = RecordSet.Add();

	Record.User		= User;
	Record.Setting	= ChartsOfCharacteristicTypes.UserSettings[SettingName];
	Record.Value	= ChartsOfCharacteristicTypes.UserSettings[SettingName].ValueType.AdjustValue(SettingValue);
	
	RecordSet.Write();
	
	RefreshReusableValues();
	
EndProcedure

// Function returns the related User employees for the passed record
//
// User - (Catalog.Users) User for whom a value table with records is received
//
Function GetUserEmployees(User) Export
	
	Query = New Query("SELECT ALLOWED TOP 1 * FROM InformationRegister.UserEmployees AS UserEmployees WHERE UserEmployees.User = &User");
	Query.SetParameter("User", User);
	QueryResult = Query.Execute();
	
	Return ?(QueryResult.IsEmpty(), New ValueTable, QueryResult.Unload());
	
EndFunction

// Procedure sets conditional design.
//
Procedure MarkMainItemWithBold(SelectedItem, List, SettingName = "MainItem") Export
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = SettingName Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	If Not ValueIsFilled(SelectedItem) Then
		Return;
	EndIf;
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Ref");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = SelectedItem;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(, , True));
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = SettingName;
	ConditionalAppearanceItem.Presentation = "Selection of main item";
	
EndProcedure

// Function receives greatest common denominator of two numbers.
//
Function GetGCD(a, b)
	
	Return ?(b = 0, a, GetGCD(b, a % b));
	
EndFunction

// Function receives greatest common denominator for array.
//
Function GetGCDForArray(NumbersArray, Multiplicity) Export
	
	If NumbersArray.Count() = 0 Then
		Return 0;
	EndIf;
	
	GCD = NumbersArray[0] * Multiplicity;
	
	For Each Ct In NumbersArray Do
		GCD = GetGCD(GCD, Ct * Multiplicity);
	EndDo;
	
	Return GCD;
	
EndFunction

// Function checks whether profile is set for user.
//
Function ProfileSetForUser(User = Undefined, ProfileId = "", Profile = Undefined) Export
	
	If User = Undefined Then
		User = Users.CurrentUser();
	EndIf;

	If Profile = Undefined Then
		Profile = Catalogs.AccessGroupProfiles.GetRef(New UUID(ProfileId));
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("Profile", Profile);
	
	Query.Text =
	"SELECT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	(NOT AccessGroupsUsers.Ref.DeletionMark)
	|	AND AccessGroupsUsers.User = &User
	|	AND (AccessGroupsUsers.Ref.Profile = &Profile
	|			OR AccessGroupsUsers.Ref.Profile = VALUE(Catalog.AccessGroupProfiles.Administrator))";
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	If Result.Next() Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Function checks users’ administrative rights
//
//
Function InfobaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	// Used as replacement:
	// DriveServer.ProfileSetForUser(, , PredefinedValue("Catalog.AccessGroupProfiles.Administrator"))
	
	Return Users.IsFullUser(User, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

// Procedure adds structure values to the values list
//
// ValueList - values list to which structure values will be added;
// StructureWithValues - structure values of which will be added to the values list;
// AddDuplicates - check box that adjusts adding 
//
Procedure StructureValuesToValuesList(ValueList, StructureWithValues, AddDuplicates = False) Export
	
	For Each StructureItem In StructureWithValues Do
		
		If Not ValueIsFilled(StructureItem.Value)
			Or (Not AddDuplicates And Not ValueList.FindByValue(StructureItem.Value) = Undefined) Then
			
			Continue;
			
		EndIf;
		
		ValueList.Add(StructureItem.Value, StructureItem.Key);
		
	EndDo;
	
EndProcedure

// Adds structure values to the array
//
// Parameters:
//  ArrayOfValues - array for adding values from the structure.
//  StructureWithValues - structure with values to add to the array.
//
Procedure StructureValuesToArray(ArrayOfValues, StructureWithValues) Export
	
	For Each StructureItem In StructureWithValues Do
		
		If Not ValueIsFilled(StructureItem.Value) Or ArrayOfValues.Find(StructureItem.Value) <> Undefined Then
			Continue;
		EndIf;
		
		ArrayOfValues.Add(StructureItem.Value);
		
	EndDo;
	
EndProcedure

// Receives contact persons of a counterparty by the counterparty
//
Function GetCounterpartyContactPersons(Counterparty) Export
	
	ContactPersonsList = New ValueList;
	
	Query = New Query("SELECT ALLOWED * FROM Catalog.ContactPersons AS ContactPersons WHERE ContactPersons.Owner = &Counterparty");
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ContactPersonsList.Add(Selection.Ref);
		
	EndDo;
	
	Return ContactPersonsList;
	
EndFunction

// Subscription to events during document copying.
//
Procedure OnCopyObject(Source) Export
	
	If Not IsBlankString(Source.Comment) Then
		Source.Comment = "";
	EndIf;
	
EndProcedure

// Receives TS row presentation for display in the Content field.
//
Function GetContentText(Products, Characteristic = Undefined) Export
	
	ContentTemplate = GetProductsPresentationForPrinting(
						?(ValueIsFilled(Products.DescriptionFull), Products.DescriptionFull, Products.Description),
						Characteristic, Products.SKU);
	
	Return ContentTemplate;
	
EndFunction

// Function - Reference to binary file data.
//
// Parameters:
//  AttachedFile - CatalogRef - reference to catalog with name "*AttachedFiles".
//  FormID - UUID - Form ID, which is used in the preparation of binary file data.
// 
// Returned value:
//   - String - address in temporary storage; 
//   - Undefined, if you can not get the data.
//
Function ReferenceToBinaryFileData(AttachedFile, FormID) Export
	
	SetPrivilegedMode(True);
	Try
		Return AttachedFiles.GetFileData(AttachedFile, FormID).BinaryFileDataRef;
	Except
		Return Undefined;
	EndTry;
	
EndFunction

Function CalculateSubtotal(Table, AmountIncludesVAT, SalesTaxTable = Undefined, CountFreightServices = True) Export
	
	DocumentSubtotal	= 0;
	DocumentFreight		= 0;
	DocumentDiscount	= 0;
	DocumentTax			= 0;
	DocumentTotal		= 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Table.Products AS Products,
	|	CAST(Table.Price * Table.Quantity AS NUMBER(15, 2)) AS Amount,
	|	Table.VATRate AS VATRate,
	|	Table.VATAmount AS VATAmount,
	|	Table.Total AS Total
	|INTO Inventory
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Inventory.Amount) AS Amount,
	|	ProductsCat.IsFreightService AS IsFreightService,
	|	SUM(CASE
	|			WHEN &AmountIncludesVAT
	|				THEN Inventory.Amount - Inventory.Amount / ((VATRates.Rate + 100) / 100)
	|			ELSE 0
	|		END) AS TrueVATAmount,
	|	SUM(Inventory.VATAmount) AS VATAmount,
	|	SUM(Inventory.Total) AS Total
	|INTO Calculation
	|FROM
	|	Inventory AS Inventory
	|		INNER JOIN Catalog.Products AS ProductsCat
	|		ON Inventory.Products = ProductsCat.Ref
	|		INNER JOIN Catalog.VATRates AS VATRates
	|		ON Inventory.VATRate = VATRates.Ref
	|
	|GROUP BY
	|	ProductsCat.IsFreightService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calculation.Amount - Calculation.TrueVATAmount AS Subtotal,
	|	Calculation.IsFreightService AS IsFreightService,
	|	Calculation.Total AS Total,
	|	Calculation.VATAmount AS VATAmount
	|FROM
	|	Calculation AS Calculation";
	
	Query.SetParameter("Table", Table);
	Query.SetParameter("AmountIncludesVAT", AmountIncludesVAT);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.IsFreightService And CountFreightServices Then
			DocumentFreight = DocumentFreight + Selection.Subtotal;
		Else
			DocumentSubtotal = DocumentSubtotal + Selection.Subtotal;
		EndIf;
		
		DocumentDiscount 	= DocumentDiscount + Selection.Subtotal + Selection.VATAmount - Selection.Total;
		
		DocumentTax			= DocumentTax + Selection.VATAmount;
		DocumentTotal		= DocumentTotal + Selection.Total;
		
	EndDo;
	
	If SalesTaxTable <> Undefined And SalesTaxTable.Count() > 0 Then
		
		DocumentTax = SalesTaxTable.Total("Amount");
		DocumentTotal = DocumentTotal + DocumentTax;
		
	EndIf;
	
	TotalsStructure = New Structure;
	TotalsStructure.Insert("DocumentSubtotal",	DocumentSubtotal);
	TotalsStructure.Insert("DocumentFreight",	DocumentFreight);
	TotalsStructure.Insert("DocumentDiscount",	DocumentDiscount);
	TotalsStructure.Insert("DocumentTax",		DocumentTax);
	TotalsStructure.Insert("DocumentTotal",		DocumentTotal);
	TotalsStructure.Insert("DocumentAmount",	DocumentTotal);
	
	Return TotalsStructure;
	
EndFunction

Function CalculateSubtotalPurchases(Table, AmountIncludesVAT) Export
	
	TotalsStructure = New Structure;
	TotalsStructure.Insert("DocumentSubtotal",	0);
	TotalsStructure.Insert("DocumentDiscount",	0);
	TotalsStructure.Insert("DocumentTax",		0);
	TotalsStructure.Insert("DocumentTotal",		0);
	TotalsStructure.Insert("DocumentAmount",	0);
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CAST(Table.Price * Table.Quantity AS NUMBER(15, 2)) AS Amount,
	|	Table.VATRate AS VATRate,
	|	Table.VATAmount AS VATAmount,
	|	Table.Total AS Total
	|INTO Inventory
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Inventory.Amount) AS Amount,
	|	SUM(CASE
	|			WHEN &AmountIncludesVAT
	|				THEN Inventory.Amount - (CAST(Inventory.Amount / ((VATRates.Rate + 100) / 100) AS NUMBER(15, 2)))
	|			ELSE 0
	|		END) AS TrueVATAmount,
	|	SUM(Inventory.VATAmount) AS VATAmount,
	|	SUM(Inventory.Total) AS Total
	|INTO Calculation
	|FROM
	|	Inventory AS Inventory
	|		INNER JOIN Catalog.VATRates AS VATRates
	|		ON Inventory.VATRate = VATRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calculation.Amount - Calculation.TrueVATAmount AS DocumentSubtotal,
	|	Calculation.Amount - Calculation.TrueVATAmount + Calculation.VATAmount - Calculation.Total AS DocumentDiscount,
	|	Calculation.VATAmount AS DocumentTax,
	|	Calculation.Total AS DocumentTotal,
	|	Calculation.Total AS DocumentAmount
	|FROM
	|	Calculation AS Calculation
	|WHERE
	|	NOT Calculation.Total IS NULL";
	
	Query.SetParameter("Table", Table);
	Query.SetParameter("AmountIncludesVAT", AmountIncludesVAT);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(TotalsStructure, Selection);
	EndIf;
	
	Return TotalsStructure;
	
EndFunction

Function GetCostAmount(StructureData) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref
	|INTO Documents
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SalesSlip.CashCRSession
	|FROM
	|	Document.SalesSlip AS SalesSlip
	|WHERE
	|	SalesSlip.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN SalesTurnovers.QuantityTurnover = 0
	|			THEN SalesTurnovers.CostTurnover
	|		ELSE SalesTurnovers.CostTurnover / SalesTurnovers.QuantityTurnover * &ReturnQuantity
	|	END AS CostOfGoodsSold
	|FROM
	|	AccumulationRegister.Sales.Turnovers(
	|			,
	|			,
	|			Recorder,
	|			Products = &Product
	|				AND Characteristic = &Characteristic
	|				AND Batch = &Batch) AS SalesTurnovers
	|WHERE
	|	SalesTurnovers.Recorder IN
	|			(SELECT
	|				Documents.Ref AS Ref
	|			FROM
	|				Documents AS Documents)";
	
	Query.SetParameter("Batch",				StructureData.Batch);
	Query.SetParameter("Characteristic", 	StructureData.Characteristic);
	Query.SetParameter("Product",			StructureData.Product);
	Query.SetParameter("ReturnQuantity",	StructureData.Quantity);
	Query.SetParameter("Document", 			StructureData.Document);
	QueryResult = Query.Execute();
	
	Result = 0;
	Selection = QueryResult.Select();
	
	If Selection.Next() Then
		Result = Selection.CostOfGoodsSold;
	EndIf;
	
	Return Result;
	
EndFunction

Function GetSerialNumbersQuery(QueryText, Ref, TTName) Export
	
	ObjectMetadata = Ref.Metadata();
	If ObjectMetadata.TabularSections.Find("SerialNumbers") <> Undefined Then
	
		QueryText = QueryText + DriveClientServer.GetQueryDelimeter();
		QueryText = QueryText + 
		"SELECT
		|	DocumentSerialNumbers.Ref AS Ref,
		|	DocumentSerialNumbers.SerialNumber AS SerialNumber,
		|	DocumentSerialNumbers.ConnectionKey AS ConnectionKey
		|FROM
		|	&TTName AS TTName
		|		INNER JOIN &DocumentSN AS DocumentSerialNumbers
		|		ON TTName.Ref = DocumentSerialNumbers.Ref";
		
		QueryText = StrReplace(QueryText, "&DocumentSN", "Document." + ObjectMetadata.Name + ".SerialNumbers");
		QueryText = StrReplace(QueryText, "&TTName", TTName);
		
	EndIf;
	
	Return QueryText;
	
EndFunction

Procedure FillDocumentsTypesList(List, MarkedItems = Undefined) Export
	
	DocsFullNames = New Array;
	
	For Each MetaDoc In Metadata.Documents Do
		DocsFullNames.Add(MetaDoc.FullName());
	EndDo;
	
	DocIDs = Common.MetadataObjectIDs(DocsFullNames);
	
	For Each MetaDoc In Metadata.Documents Do
		MetadataObjectID = DocIDs[MetaDoc.FullName()];
		If ValueIsFilled(MarkedItems) Then
			List.Add(MetadataObjectID, MetaDoc.Presentation(), (MarkedItems.Find(MetadataObjectID) <> Undefined));
		Else
			List.Add(MetadataObjectID, MetaDoc.Presentation());
		EndIf;
	EndDo;
	
	List.SortByPresentation();
	
EndProcedure

// Function returns the presentation (national) currency by company
//
Function GetPresentationCurrency(Val Company = Undefined) Export
	
	SetPrivilegedMode(True);
	
	If Not ValueIsFilled(Company) Then
		Company = DriveReUse.GetUserDefaultCompany();
	EndIf;
	
	Return Common.ObjectAttributeValue(Company, "PresentationCurrency");
	
EndFunction

Function GetExchangeMethod(Company) Export
	
	Return Common.ObjectAttributeValue(Company, "ExchangeRateMethod");
	
EndFunction

Procedure ReadCounterpartyAttributes(StructureAttributes, CatalogCounterparty, StringAttributes) Export
	
	If StructureAttributes = Undefined Then
		StructureAttributes = New Structure(StringAttributes);
	EndIf;
	
	If ValueIsFilled(CatalogCounterparty) Then
		FillPropertyValues(StructureAttributes, Common.ObjectAttributesValues(CatalogCounterparty, StringAttributes));
	Else
		FillPropertyValues(StructureAttributes, Catalogs.Counterparties.EmptyRef());
	EndIf;
	
EndProcedure

Function GetRefAttributes(Ref, StringAttributes) Export
	
	If Common.IsReference(TypeOf(Ref)) Then
		
		StructureAttributes = New Structure(StringAttributes);
		
		If ValueIsFilled(Ref) Then
			FillPropertyValues(StructureAttributes, Common.ObjectAttributesValues(Ref, StringAttributes));
		Else
			FillPropertyValues(StructureAttributes, Common.ObjectManagerByRef(Ref).EmptyRef());
		EndIf;
		
		Return StructureAttributes;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
EndFunction

Procedure ExecuteNumberCodeGenerationIfNecessary(Object, Prefix = "", Forcibly = False) Export	
	ObjectTypeName = Common.ObjectKindByType(TypeOf(Object.Ref));
	
	If ObjectTypeName = "Document"
		Or ObjectTypeName = "BusinessProcess"
		Or ObjectTypeName = "Task" Then
		
		AttributeName = "Number";
		AttributeValue = Object.Number;
		AttributeLength = Object.Metadata().NumberLength;
		
	ElsIf ObjectTypeName = "Catalog"
		Or ObjectTypeName = "ChartOfCharacteristicTypes" Then
	
		If Not Object.Metadata().Autonumbering Then
			Return;
		EndIf;
		
		AttributeName = "Code";
		AttributeValue = Object.Code;
		AttributeLength = Object.Metadata().CodeLength;
		
	Else
		Return;
	EndIf;
	
	If AttributeLength = 0 Then
		Return;
	EndIf;
	
	TableName = Common.TableNameByRef(Object.Ref);
			
	If Not Forcibly And ValueIsFilled(AttributeValue) Then
		
		QueryText =
		"SELECT
		|	TableName.Ref AS Ref
		|FROM
		|	%1 AS TableName
		|WHERE
		|	TableName.Ref <> &Ref
		|	AND TableName.%2 = &AttributeValue";
		
		Query = New Query;
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(QueryText, TableName, AttributeName);
		
		Query.SetParameter("Ref", Object.Ref);
		Query.SetParameter("AttributeValue", AttributeValue);
		
		If Query.Execute().IsEmpty() Then
			Return;
		EndIf;
		
	EndIf;
	
	If AttributeName = "Number" Then
		Object.SetNewNumber(Prefix);
	Else
		Object.SetNewCode(Prefix);
	EndIf;
		
EndProcedure

Function AttributeExistsForObject(CurrentObject, AttributeName) Export
	
	MetadataObject = CurrentObject.Metadata();
	
	If Not Common.HasObjectAttribute(AttributeName, MetadataObject) Then
		Return False;	
	EndIf;
	
	If CurrentObject.IsFolder Then
		Return MetadataObject.Attributes[AttributeName].ChoiceFoldersAndItems <> FoldersAndItemsUse.Items;
	Else
		Return MetadataObject.Attributes[AttributeName].ChoiceFoldersAndItems <> FoldersAndItemsUse.Folders;
	EndIf;
	
EndFunction

Function DateDiff(BegDate, EndDate, Periodicity) Export
	
	If Periodicity = Enums.Periodicity.Day Then
		PeriodName = "DAY";
	ElsIf Periodicity = Enums.Periodicity.Month Then
		PeriodName = "MONTH";
	ElsIf Periodicity = Enums.Periodicity.Quarter Then
		PeriodName = "QUARTER";
	ElsIf Periodicity = Enums.Periodicity.Year Then
		PeriodName = "YEAR";
	Else
		Return 0;
	EndIf;
	
	QueryTemplate =
	"SELECT
	|	DATEDIFF(&BegDate, &EndDate, %1) AS Difference";
	
	Query = New Query;
	Query.SetParameter("BegDate", BegDate);
	Query.SetParameter("EndDate", EndDate);
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, PeriodName);
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	Return Selection.Difference;
	
EndFunction

// Generate an array/a string of standard attributes for a metadata object
Function GetStandardAttributesNames(Object, AsString = True) Export
	
	StandardAttributes = New Array;
	
	ObjectMetadata = Object.Metadata();
	
	If Common.IsDocument(ObjectMetadata) Then
		
		For Each Attribute In ObjectMetadata.StandardAttributes Do
			StandardAttributes.Add(Attribute.Name);
		EndDo;
		
	EndIf;
	
	If AsString Then
		Return StringFunctionsClientServer.StringFromSubstringArray(StandardAttributes);
	EndIf;
	
	Return StandardAttributes;
	
EndFunction

Function GetStorageBin(StructureData) Export
	
	StorageBin = Catalogs.Cells.EmptyRef();
	
	ProductAttributes = Common.ObjectAttributesValues(StructureData.Products, "Warehouse, Cell");
	If ProductAttributes.Warehouse = StructureData.Warehouse Then
		
		StorageBin = ProductAttributes.Cell;
		
	EndIf;
	
	Return StorageBin;
	
EndFunction

Procedure SetCodeCompletionAddInSessionParameters(CodeCompletionAddInPath) Export
	
	SetPrivilegedMode(True);
	SessionParameters.CodeCompletionAddInPath = CodeCompletionAddInPath;
	SetPrivilegedMode(False);
	
EndProcedure

Procedure WriteErrorInEventLog(EventName, ErrorDescription) Export
	
	WriteLogEvent(
		EventName,
		EventLogLevel.Error,
		,
		,
		ErrorDescription);
	
EndProcedure

Function DriveLicenseErrorEventName() Export
	Return Nstr("en = 'Drive license. Initialize'; ru = 'Лицензия Drive. Инициализировать';pl = 'Licencja Drive. Inicjuj';es_ES = 'Permiso de conducir. Iniciar';es_CO = 'Permiso de conducir. Iniciar';tr = 'Drive lisansı. Başlat';it = 'Patente di guida. Inizializzare';de = 'Drive-Lizenz. Initialisieren'", CommonClientServer.DefaultLanguageCode());
EndFunction

Function AreUserAndSystemLanguagesDifferent() Export
	
	Result = False;
	
	If Not ValueIsFilled(SessionParameters.CurrentUser) Then
		Return Result;
	EndIf;
	If DriveReUse.GetValueOfSetting("DoNotShowDisplayLanguageCheck") Then
		Return Result;
	EndIf;
	
	SetPrivilegedMode(True);
	
	IBUserID 			= Common.ObjectAttributeValue(SessionParameters.CurrentUser, "IBUserID");
	IBUserProperties 	= Users.IBUserProperies(IBUserID);
	
	If IBUserProperties = Undefined
		Or Not IBUserProperties.Property("InfobaseUser") Then
		Return Result;
	EndIf;
	
	InfobaseUser = IBUserProperties.InfobaseUser;
	
	If Not InfobaseUser = Undefined Then
		Language = InfobaseUser.Language;
		If Not Language = Undefined Then
			CurrentUserLanguage = StrSplit(Language.LanguageCode, "_")[0];
			CurrentSystemLanguage = StrSplit(CurrentSystemLanguage(), "_")[0];
			If Not CurrentUserLanguage = CurrentSystemLanguage Then
				Result = True;
			EndIf;
		EndIf;
	EndIf;
	
	SetPrivilegedMode(False);
	
	Return Result;
	
EndFunction

Function DenyWorkWithCodeCompletionAddIn() Export
	
	Return Constants.DenyWorkWithCodeCompletionAddIn.Get();
	
EndFunction

Procedure AttachAddInServer() Export
	
	If DenyWorkWithCodeCompletionAddIn() Then
		Return;
	EndIf;
	
	AddInTempate = "CommonTemplate.CodeCompletionAddIn";
	
	Try
		
		AddInAttached = AttachAddIn(AddInTempate, "CodeCompletionAddIn", AddInType.Native);
		If AddInAttached Then
			
			CodeCompletionAddIn = New("AddIn.CodeCompletionAddIn.TestAddIn");
			Result = CodeCompletionAddIn.Unpack();
			
			UUID = New UUID();
			BinaryData = New BinaryData(Result);
			Address = PutToTempStorage(BinaryData, UUID);
			BinaryData.Write(CoreMethodsTempFileName());
			
			SetCodeCompletionAddInSessionParameters(Address);
			
		Else
			
			ErrorDescription = NStr("en = 'The component is not attached successfully'; ru = 'Компонента не подключена';pl = 'Nie udało się podłączyć komponentu';es_ES = 'El componente no se ha adjuntado correctamente';es_CO = 'El componente no se ha adjuntado correctamente';tr = 'Malzeme eklenemedi';it = 'La componente non è stata collegata correttamente';de = 'Die Komponente ist nicht erfolgreich verbunden'");
			WriteErrorInEventLog(DriveLicenseErrorEventName(), ErrorDescription);
			
		EndIf;
		
	Except
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Сomponent attached error: %1'; ru = 'Ошибка при подключении компоненты: %1';pl = 'Błąd podłączenia komponentu: %1';es_ES = 'Error al adjuntar el componente: %1';es_CO = 'Error al adjuntar el componente: %1';tr = 'Malzeme ekleme hatası: %1';it = 'Errore componente collegata: %1';de = 'Fehler beim Verbinden der Komponente: %1'"),
			DetailErrorDescription(ErrorInfo()));
			
		WriteErrorInEventLog(DriveLicenseErrorEventName(), ErrorDescription);
		
	EndTry;
	
EndProcedure

Function GetModifiedAttributes(Object, CheckTab = True, CheckStandard = True) Export
	
	ModifiedAttributes = New Array;
	
	Ref = Object.Ref;
	ObjectMetadata = Ref.Metadata();
	TypeValueStorage = New TypeDescription("ValueStorage");
	
	For Each Attribute In ObjectMetadata.Attributes Do
		
		If Attribute.Type = TypeValueStorage Then
			
			If Object[Attribute.Name].Get() <> Ref[Attribute.Name].Get() Then
				ModifiedAttributes.Add(Attribute.Name);
			EndIf;
			
		ElsIf Object[Attribute.Name] <> Ref[Attribute.Name] Then
			ModifiedAttributes.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	If CheckStandard Then
		
		For Each Attribute In ObjectMetadata.StandardAttributes Do
			If Object[Attribute.Name] <> Ref[Attribute.Name] Then
				ModifiedAttributes.Add(Attribute.Name);
			EndIf;
		EndDo;
		
	EndIf;
	
	If CheckTab Then
		
		For Each TS In ObjectMetadata.TabularSections Do
			
			For Index = 0 To Object[TS.Name].Count() - 1 Do
				
				If Index < Ref[TS.Name].Count() Then
					
					ObjectTSRow = Object[TS.Name][Index];
					RefTSRow = Ref[TS.Name][Index];
					
					For Each TSAttribute In TS.Attributes Do
						
						If TSAttribute.Type = TypeValueStorage Then
							
							If ObjectTSRow[TSAttribute.Name].Get() <> RefTSRow[TSAttribute.Name].Get() Then
								ModifiedAttributes.Add(TS.Name + "." + TSAttribute.Name);
							EndIf;
							
						ElsIf ObjectTSRow[TSAttribute.Name] <> RefTSRow[TSAttribute.Name] Then
							ModifiedAttributes.Add(TS.Name + "." + TSAttribute.Name);
						EndIf;
					EndDo;
					
				Else
					
					ObjectTSRow = Object[TS.Name][Index];
					
					For Each TSAttribute In TS.Attributes Do
						ModifiedAttributes.Add(TS.Name + "." + TSAttribute.Name);
					EndDo;
					
				EndIf;
				
			EndDo;
			
			If Index < Ref[TS.Name].Count() Then
				ModifiedAttributes.Add(TS.Name);
			EndIf;
			
		EndDo;
	EndIf;
	
	Return ModifiedAttributes;
	
EndFunction

Function GetModifiedTabularSectionAttributes(Object, TabName) Export
	
	ModifiedAttributes = New Array;
	
	Ref				 = Object.Ref;
	ObjectMetadata	 = Ref.Metadata();
	TypeValueStorage = New TypeDescription("ValueStorage");
	TSAttributes	 = ObjectMetadata.TabularSections[TabName].Attributes;
	
	For Index = 0 To Object[TabName].Count() - 1 Do
		
		If Index < Ref[TabName].Count() Then
			
			ObjectTSRow = Object[TabName][Index];
			RefTSRow = Ref[TabName][Index];
			
			For Each TSAttribute In TSAttributes Do
				
				If TSAttribute.Type = TypeValueStorage Then
					
					If ObjectTSRow[TSAttribute.Name].Get() <> RefTSRow[TSAttribute.Name].Get() Then
						ModifiedAttributes.Add(New Structure("Index, Attribute", Index, TSAttribute.Name));
					EndIf;
					
				ElsIf ObjectTSRow[TSAttribute.Name] <> RefTSRow[TSAttribute.Name] Then
					ModifiedAttributes.Add(New Structure("Index, Attribute", Index, TSAttribute.Name));
				EndIf;
			EndDo;
			
		Else
			
			ObjectTSRow = Object[TabName][Index];
			
			For Each TSAttribute In TSAttributes Do
				ModifiedAttributes.Add(New Structure("Index, Attribute", Index, TSAttribute.Name));
			EndDo;
			
		EndIf;
		
	EndDo;
	
	Return ModifiedAttributes;
	
EndFunction

Function DropShippingReturnIsSupported(Parameters, Cancel = False) Export
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Drop shipping is inapplicable for company ""%1"". For drop shipping, select a company with the accounting policy where:
		|- For Sales return flow, Credit note posts all entries, including inventory
		|- For Purchase return flow, Debit note posts all entries, including inventory'; 
		|ru = 'В организации ""%1"" не применяется дропшиппинг. Чтобы использовать дропшиппинг, выберите организацию с учетной политикой, в которой:
		|- В процессе возврата от покупателей документ ""Кредитовое авизо"" делает все движения по регистрам, включая движения по товарам
		|- В процессе возврата поставщикам документ ""Дебетовое авизо"" делает все движения по регистрам, включая движения по товарам';
		|pl = 'Dropshipping nie ma zastosowania dla firmy ""%1"". Dla dropshippingu, wybierz firmę z polityką rachunkowości, gdzie:
		|- Dla Przepływu zwrotu sprzedaży, Noty kredytowej zatwierdza wszystkie wpisy, w tym zapasy
		|- Dla przepływu zwrotu zakupu, Noty debetowej zatwierdza wszystkie wpisy, w tym zapasy';
		|es_ES = 'El envío directo no es aplicable para la empresa ""%1"". Para el envío directo, seleccione una empresa con la política contable en la que:
		|- Para el flujo de la devolución de ventas, la nota de crédito contabiliza todas las entradas, incluyendo el inventario
		|- Para el flujo de la devolución de compras, la nota de débito contabiliza todas las entradas de diario, incluyendo el inventario';
		|es_CO = 'El envío directo no es aplicable para la empresa ""%1"". Para el envío directo, seleccione una empresa con la política contable en la que:
		|- Para el flujo de la devolución de ventas, la nota de crédito contabiliza todas las entradas, incluyendo el inventario
		|- Para el flujo de la devolución de compras, la nota de débito contabiliza todas las entradas de diario, incluyendo el inventario';
		|tr = 'Stoksuz satış ""%1"" iş yerine uygulanamaz. Stoksuz satış için, muhasebe politikası şu özelliklere sahip bir iş yeri seçin:
		|- Satış iade akışı için Alacak dekontu stok dahil tüm girişleri kaydeder
		|- Satın alma iade akışı için Borç dekontu stok dahil tüm girişleri kaydeder';
		|it = 'Non è possibile applicare il dropshipping all''azienda ""%1"". Per effettuare il dropshipping, selezionare una azienda con politica contabile dove:
		|- Per il flusso di ritorno delle Vendite, la nota di credito inserisce tutte le voci compreso l''inventario
		|- Per il flusso di ritorno degli acquisti, la nota di debito inserisce tutte le voci compreso l''inventario';
		|de = 'Streckengeschäft ist für die Firma ""%1"" nicht verwendbar. Wählen Sie eine Firma mit den Bilanzierungsrichtlinien wie folgt aus:
		|- Für Verkaufsrücklauf, bucht Gutschrift alle Buchungen, einschließlich Bestand
		|- Für Einrkaufsrücklauf, bucht Lastschrift alle Buchungen, einschließlich Bestand'"),
		Parameters.Company);
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	CASE
	|		WHEN NOT AccountingPolicySliceLast.UseGoodsReturnFromCustomer
	|				AND NOT AccountingPolicySliceLast.UseGoodsReturnToSupplier
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ReturnIsSupported
	|FROM
	|	InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast";
	
	Query.SetParameter("Company", Parameters.Company);
	Query.SetParameter("Date", ?(Parameters.Property("Date"), Parameters.Date, CurrentSessionDate()));
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		If Not Selection.ReturnIsSupported Then
			Cancel = True;
			If Parameters.Property("IsError") Then
				Raise MessageText;
			Else
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		EndIf;
		
		Return Selection.ReturnIsSupported;
	EndIf;
	
	Cancel = True;
	If Parameters.Property("IsError") Then
		Raise MessageText;
	Else
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
	Return False;
	
EndFunction

Function CheckCloseOrderEnabled(DocumentRef) Export

	Return AccessRight("InteractiveInsert", DocumentRef.Metadata())
		And AccessRight("Use", Metadata.DataProcessors.OrdersClosing);
	
EndFunction

#EndRegion

#Region ProceduresAndFunctions

// Function receives table from the temporary table.
//
Function TableFromTemporaryTable(TempTablesManager, Table) Export
	
	Query = New Query(
	"SELECT *
	|	FROM " + Table + " AS Table");
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Function dependinding on the accounting flag
// by the company of company-organization or document organization.
//
// Parameters:
// Company - CatalogRef.Companies.
//
// Returns:
//  CatalogRef.Company - ref to the company.
//
Function GetCompany(Company) Export
	
	Return ?(Constants.AccountingBySubsidiaryCompany.Get(), Constants.ParentCompany.Get(), Company);
	
EndFunction

// Function defines product sale taxation type with VAT.
//
// Parameters:
// Company - CatalogRef.Companies - Company for which Warehouse
// taxation system is defined. - CatalogRef.Warehouses - Retail warehouse for which
// Date taxation system is defined - Date of taxation system definition
//
Function VATTaxation(Company, Date) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return ?(Policy.RegisteredForVAT, Enums.VATTaxationTypes.SubjectToVAT, Enums.VATTaxationTypes.NotSubjectToVAT);
	
EndFunction

Function AutomaticVATCalculation(Company, Date) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.PerInvoiceVATRoundingRule;
	
EndFunction

Function CounterpartyVATTaxation(Counterparty, CompanyVATTaxation, ReverseChargeNotApplicable = False) Export
	
	RegisteredForVAT = (CompanyVATTaxation <> Enums.VATTaxationTypes.NotSubjectToVAT);
	
	If ValueIsFilled(Counterparty) Then
		
		CounterpartyVATTaxation = Common.ObjectAttributeValue(Counterparty, "VATTaxation");
		
		If ValueIsFilled(CounterpartyVATTaxation)
			And WorkWithVAT.VATTaxationTypeIsValid(CounterpartyVATTaxation, RegisteredForVAT, ReverseChargeNotApplicable) Then
			
			If RegisteredForVAT
				Or CounterpartyVATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT
				Or CounterpartyVATTaxation = Enums.VATTaxationTypes.ForExport Then
				
				Return CounterpartyVATTaxation;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return CompanyVATTaxation;
	
EndFunction

Function CounterpartySalesTaxRate(Counterparty, RegisteredForSalesTax) Export
	
	If RegisteredForSalesTax And ValueIsFilled(Counterparty) Then
		
		SalesTaxRate = Common.ObjectAttributeValue(Counterparty, "SalesTaxRate");
		
	Else
		
		SalesTaxRate = Catalogs.SalesTaxRates.EmptyRef();
		
	EndIf;
	
	Return SalesTaxRate;
	
EndFunction

// The procedure checks the exceding of the limits set for the contract.
// If the limits are exceeded, a message is displayed to the user.
// The posting of sales documents are cancelled. 
//
// Parameters:
//   DocumentObject - DocumentObject.SalesInvoice, DocumentObject.SalesOrder, DocumentObject.WorkOrder, 
//                 DocumentObject.SupplierInvoice, DocumentObject.PurchaseOrder - the reference to the document which try posting.
//   IsSaleDocument - Boolean - True for Sales documents, False - for Purchase.
//   Cancel - Boolean - if True, posting will cancel.
//   
Procedure CheckLimitsExceed(DocumentObject, IsSaleDocument, Cancel) Export
	
	Limits = Common.ObjectAttributesValues(DocumentObject.Contract,
		"CreditLimit, OverdueLimit, TransactionLimit, SettlementsCurrency");
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AR_AP_Balanse.Company AS Company,
	|	AR_AP_Balanse.SettlementsType AS SettlementsType,
	|	AR_AP_Balanse.Counterparty AS Counterparty,
	|	AR_AP_Balanse.Contract AS Contract,
	|	AR_AP_Balanse.Document AS Document,
	|	AR_AP_Balanse.Order AS Order,
	|	AR_AP_Balanse.AmountCurBalance AS AmountBalance,
	|	AR_AP_Balanse.AmountForPaymentCurBalance AS AmountForPaymentBalance
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&Period,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND Contract = &Contract) AS AR_AP_Balanse";
	
	If NOT IsSaleDocument Then // For purchase documents use another registry
		Query.Text = StrReplace(Query.Text, "AccountsReceivable", "AccountsPayable");
	EndIf;
	
	Query.SetParameter("Company",      DocumentObject.Company);
	Query.SetParameter("Contract",     DocumentObject.Contract);
	Query.SetParameter("Counterparty", DocumentObject.Counterparty);
	Query.SetParameter("Period",       DocumentObject.Date);
	
	QueryResult = Query.Execute();
	
	ResultTable = QueryResult.Unload();
	
	// Save the exceeding values to table
	ExceedingTable = New ValueTable();
	ExceedingTable.Columns.Add("ParameterName");
	ExceedingTable.Columns.Add("ParameterValue");
	
	DocumentAmountInContractCurrency = 0;
	If Limits.CreditLimit <> 0 Or Limits.TransactionLimit <> 0 Then
		
		ExchangeRateMethod = DriveServer.GetExchangeMethod(DocumentObject.Company);
		
		DocumentAmountInContractCurrency = DriveServer.RecalculateFromCurrencyToCurrency(
			DocumentObject.DocumentAmount,
			ExchangeRateMethod,
			DocumentObject.ExchangeRate,
			DocumentObject.ContractCurrencyExchangeRate,
			DocumentObject.Multiplicity,
			DocumentObject.ContractCurrencyMultiplicity);
		
	EndIf;
	
	If Limits.CreditLimit <> 0 Then
		ExceedingValue = ResultTable.Total("AmountBalance") + DocumentAmountInContractCurrency - Limits.CreditLimit;
		
		If ExceedingValue > 0 Then
			
			NewRow = ExceedingTable.Add();
			
			NewRow.ParameterName  = NStr("en = 'Credit Limit'; ru = 'Кредитный лимит';pl = 'Limit kredytowy';es_ES = 'Límite de crédito';es_CO = 'Límite de crédito';tr = 'Kredi limiti';it = 'Limite credito';de = 'Kreditlimit'");
			NewRow.ParameterValue = ExceedingValue;
			
		EndIf;
	EndIf;
	
	If Limits.OverdueLimit <> 0 Then
		ExceedingValue = ResultTable.Total("AmountForPaymentBalance") - Limits.OverdueLimit;
		If ExceedingValue > 0 Then
			
			NewRow = ExceedingTable.Add();
			
			NewRow.ParameterName  = NStr("en = 'Overdue Limit'; ru = 'Лимит просрочки';pl = 'Zaległy limit';es_ES = 'Límite de atraso';es_CO = 'Límite de atraso';tr = 'Vadesi geçmiş limiti';it = 'Limite scoperto';de = 'Überfälligkeitsgrenze'");
			NewRow.ParameterValue = ExceedingValue;
			
		EndIf;
	EndIf;
	
	If Limits.TransactionLimit <> 0 Then
		ExceedingValue = DocumentAmountInContractCurrency - Limits.TransactionLimit;
		
		If ExceedingValue > 0 Then
			
			NewRow = ExceedingTable.Add();
			
			NewRow.ParameterName  = NStr("en = 'Transaction Limit'; ru = 'Лимит транзакции';pl = 'Limit transakcji';es_ES = 'Límite de transacción';es_CO = 'Límite de transacción';tr = 'İşlem limiti';it = 'Limite transazione';de = 'Transaktionslimit'");
			NewRow.ParameterValue = ExceedingValue;
			
		EndIf;
	EndIf;
	
	If ExceedingTable.Count() > 0 Then
		
		MessageTemplate = NStr("en = 'The transaction result exceeds the %1 by %2 %3'; ru = 'Результат транзакции превышает %1 на %2 %3';pl = 'Wynik transakcji przekracza %1 o %2 %3';es_ES = 'El resultado de la transacción excede el %1 en %2 %3';es_CO = 'El resultado de la transacción excede el %1 en %2 %3';tr = 'İşlem sonucu %1 değerini %2 %3 aşıyor';it = 'Il risultato della transazione supera %1 di %2 %3';de = 'Das Transaktionsergebnis übertrifft %1 um %2%3'");
		
		For Each Row In ExceedingTable Do
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
							MessageTemplate,
							Row.ParameterName,
							Format(Row.ParameterValue, "L=en; NFD=2; NDS=."),
							Limits.SettlementsCurrency);
			
			If IsSaleDocument Then 
				ShowMessageAboutError(DocumentObject, MessageText, , , , Cancel);
			Else
				// For Purchase order and Supplier invoice show message and continue posting the documents.
				CommonClientServer.MessageToUser(MessageText, DocumentObject);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure // CheckLimitsExceed()

Procedure CheckInventoryForNonServices(DocObject, Cancel) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Inventory.LineNumber AS LineNumber,
	|	Inventory.Products AS Products
	|INTO TT_Inventory
	|FROM
	|	&Inventory AS Inventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Inventory.LineNumber AS LineNumber
	|FROM
	|	TT_Inventory AS TT_Inventory
	|		INNER JOIN Catalog.Products AS CatalogProducts
	|		ON TT_Inventory.Products = CatalogProducts.Ref
	|WHERE
	|	CatalogProducts.ProductsType <> VALUE(Enum.ProductsTypes.Service)";
	Query.SetParameter("Inventory", DocObject.Inventory);
	
	Sel = Query.Execute().Select();
	While Sel.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'On the Products tab, in line %1, select a product with the Service type.'; ru = 'Во вкладке Номенклатура в строке %1 выберите номенклатуру с типом Услуга.';pl = 'Na karcie Produkty, w wierszu %1, wybierz produkt z typem Usługa.';es_ES = 'En la pestaña Productos, en la línea %1, seleccione un producto con el tipo de Servicio.';es_CO = 'En la pestaña Productos, en la línea %1, seleccione un producto con el tipo de Servicio.';tr = 'Ürünler sekmesinin %1 satırında Hizmet türünde bir ürün seçin.';it = 'Nella scheda Articoli, nella riga %1, selezionare un articolo con il tipo Servizio.';de = 'Auf der Registerkarte Produkte in der Zeile %1, wählen Sie ein Produkt mit dem Dienstleistungstyp aus.'"),
			Sel.LineNumber);
		CommonClientServer.MessageToUser(MessageText,
			DocObject,
			CommonClientServer.PathToTabularSection("Inventory", Sel.LineNumber, "Products"),
			,
			Cancel);
		
	EndDo;
	
EndProcedure

Function GetOrderStringStatuses() Export
	
	StatusesStructure = New Structure;
	StatusesStructure.Insert("StatusInProcess", NStr("en = 'In process'; ru = 'В работе';pl = 'W toku';es_ES = 'En proceso';es_CO = 'En proceso';tr = 'İşlemde';it = 'In lavorazione';de = 'In Bearbeitung'"));
	StatusesStructure.Insert("StatusCompleted", NStr("en = 'Completed'; ru = 'Завершено';pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'"));
	StatusesStructure.Insert("StatusCanceled", NStr("en = 'Canceled'; ru = 'Отменено';pl = 'Anulowano';es_ES = 'Cancelado';es_CO = 'Cancelado';tr = 'İptal edildi';it = 'Annullato';de = 'Abgebrochen'"));
	
	Return StatusesStructure;
	
EndFunction

#EndRegion

#Region InformationPanel

// Receives required data for output to the list information panel.
//
Function InfoPanelGetData(CICurrentAttribute, InfPanelParameters) Export
	
	CIFieldList = "";
	QueryText = "";
	
	Query = New Query;
	QueryOrder = 0;
	If InfPanelParameters.Property("Counterparty") Then
		
		CIFieldList = "Phone,E_mail,Fax,RealAddress,LegAddress,MailAddress,ShippingAddress,OtherInformation";
		GenerateQueryTextCounterpartiesInfoPanel(QueryText);
		
		QueryOrder = QueryOrder + 1;
		InfPanelParameters.Counterparty = QueryOrder;
		
		Query.SetParameter("Counterparty", CICurrentAttribute);
		
		If InfPanelParameters.Property("StatementOfAccount") Then
			
			CIFieldList = CIFieldList + ",Debt,OurDebt";
			GenerateQueryTextStatementOfAccountInfoPanel(QueryText);
			
			QueryOrder = QueryOrder + 1;
			InfPanelParameters.StatementOfAccount = QueryOrder;
			
			StatementOfAccountParameters = InformationPanelGetParametersOfStatementOfAccount();
			Query.SetParameter("CompaniesList", StatementOfAccountParameters.CompaniesList);
			Query.SetParameter("ListTypesOfCalculations", StatementOfAccountParameters.ListTypesOfCalculations);
			
		EndIf;
		
		If InfPanelParameters.Property("DiscountCard") Then
			CIFieldList = CIFieldList + ",DiscountPercentByDiscountCard,SalesAmountOnDiscountCard,PeriodPresentation";
		EndIf;
		
	EndIf;
	
	If InfPanelParameters.Property("ContactPerson") Then
		
		CIFieldList = ?(IsBlankString(CIFieldList), "CLPhone,ClEmail", CIFieldList + ",CLPhone,ClEmail");
		GenerateQueryTextContactsInfoPanel(QueryText);
		
		QueryOrder = QueryOrder + 1;
		InfPanelParameters.ContactPerson = QueryOrder;
		
		If TypeOf(CICurrentAttribute) = Type("CatalogRef.Counterparties") Then
			Query.SetParameter("ContactPerson", Common.ObjectAttributeValue(CICurrentAttribute, "ContactPerson"));
		Else
			Query.SetParameter("ContactPerson", CICurrentAttribute);
		EndIf;
		
	EndIf;
	
	Query.Text = QueryText;
	
	IPData = New Structure(CIFieldList);
	
	Result = Query.ExecuteBatch();
	
	If InfPanelParameters.Property("Counterparty") Then
		
		CISelection = Result[InfPanelParameters.Counterparty - 1].Select();
		IPData = GetDataCounterpartyInfoPanel(CISelection, IPData);
		
		If InfPanelParameters.Property("StatementOfAccount") Then
			
			DebtsSelection = Result[InfPanelParameters.StatementOfAccount - 1].Select();
			IPData = GetFillDataSettlementsInfoPanel(DebtsSelection, IPData);
			
		EndIf;
		
		If InfPanelParameters.Property("DiscountCard") Then
			
			AdditionalParameters = New Structure("GetSalesAmount, Amount, PeriodPresentation", True, 0, "");
			DiscountPercentByDiscountCard = CalculateDiscountPercentByDiscountCard(CurrentSessionDate(), InfPanelParameters.DiscountCard, AdditionalParameters);
			IPData = GetFillDataDiscountPercentByDiscountCardInfPanel(DiscountPercentByDiscountCard, AdditionalParameters.Amount, AdditionalParameters.PeriodPresentation, IPData);
			
		EndIf;
		
	EndIf;
	
	If InfPanelParameters.Property("ContactPerson") Then
		CISelection = Result[InfPanelParameters.ContactPerson - 1].Select();
		IPData = GetDataContactPersonInfoPanel(CISelection, IPData);
	EndIf;
	
	Return IPData;
	
EndFunction

// Procedure generates query text by counterparty CI.
//
Procedure GenerateQueryTextCounterpartiesInfoPanel(QueryText)
	
	QueryText = QueryText +
	"SELECT ALLOWED
	|	CIKinds.Ref AS CIKind,
	|	ISNULL(CICounterparty.Presentation, """") AS CIPresentation
	|FROM
	|	Catalog.ContactInformationKinds AS CIKinds
	|		LEFT JOIN Catalog.Counterparties.ContactInformation AS CICounterparty
	|		ON (CICounterparty.Ref = &Counterparty)
	|			AND CIKinds.Ref = CICounterparty.Kind
	|WHERE
	|	CIKinds.Parent = VALUE(Catalog.ContactInformationKinds.CatalogCounterparties)
	|	AND CIKinds.Predefined
	|
	|ORDER BY
	|	CICounterparty.LineNumber";
	
EndProcedure

// Procedure generates query text by contact person CI.
//
Procedure GenerateQueryTextContactsInfoPanel(QueryText)
	
	If Not IsBlankString(QueryText) Then
		QueryText = QueryText +
		";
		|////////////////////////////////////////////////////////////////////////////////
		|";
	EndIf;
	
	QueryText = QueryText +
	"SELECT ALLOWED
	|	CIKinds.Ref AS CIKind,
	|	ISNULL(CIContactPersons.Presentation, """") AS CIPresentation
	|FROM
	|	Catalog.ContactInformationKinds AS CIKinds
	|		LEFT JOIN Catalog.ContactPersons.ContactInformation AS CIContactPersons
	|		ON (CIContactPersons.Ref = &ContactPerson)
	|			AND CIKinds.Ref = CIContactPersons.Kind
	|WHERE
	|	CIKinds.Parent = VALUE(Catalog.ContactInformationKinds.CatalogContactPersons)
	|	AND CIKinds.Predefined";
	
EndProcedure

// Procedure generates query text by the counterparty ArApAdjustments.
//
Procedure GenerateQueryTextStatementOfAccountInfoPanel(QueryText)
	
	QueryText = QueryText +
	";
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	QueryText = QueryText +
	"SELECT ALLOWED
	|	CASE
	|		WHEN AccountsPayableBalances.AmountBalance < 0
	|				AND AccountsReceivableBalances.AmountBalance > 0
	|			THEN -1 * BankAccountsPayableBalances.AmountBalance + AccountsReceivableBalances.AmountBalance
	|		WHEN AccountsPayableBalances.AmountBalance < 0
	|			THEN -AccountsPayableBalances.AmountBalance
	|		WHEN AccountsReceivableBalances.AmountBalance > 0
	|			THEN AccountsReceivableBalances.AmountBalance
	|		ELSE 0
	|	END AS CounterpartyDebt,
	|	CASE
	|		WHEN AccountsPayableBalances.AmountBalance > 0
	|				AND AccountsReceivableBalances.AmountBalance < 0
	|			THEN -1 * BankAccountsReceivableBalances.AmountBalance + AccountsPayableBalances.AmountBalance
	|		WHEN AccountsPayableBalances.AmountBalance > 0
	|			THEN AccountsPayableBalances.AmountBalance
	|		WHEN AccountsReceivableBalances.AmountBalance < 0
	|			THEN -AccountsReceivableBalances.AmountBalance
	|		ELSE 0
	|	END AS OurDebt
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			,
	|			Company IN (&CompaniesList)
	|				AND SettlementsType IN (&ListTypesOfCalculations)
	|				AND Counterparty = &Counterparty) AS AccountsPayableBalances,
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company IN (&CompaniesList)
	|				AND SettlementsType IN (&ListTypesOfCalculations)
	|				AND Counterparty = &Counterparty) AS AccountsReceivableBalances";
	
EndProcedure

// Function returns required parameters for ArApAdjustments calculation in inf. panels.
//
Function InformationPanelGetParametersOfStatementOfAccount()
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies";
	
	QueryResult = Query.Execute().Unload();
	CompaniesArray = QueryResult.UnloadColumn("Company");
	
	CalculationsTypesArray = New Array;
	CalculationsTypesArray.Add(Enums.SettlementsTypes.Advance);
	CalculationsTypesArray.Add(Enums.SettlementsTypes.Debt);
	
	Return New Structure("CompaniesList,CalculationsTypesList", CompaniesArray, CalculationsTypesArray);
	
EndFunction

// Receives required data about counterparty CI.
//
Function GetDataCounterpartyInfoPanel(CISelection, IPData)
	
	While CISelection.Next() Do
		
		CIPresentation = TrimAll(CISelection.CIPresentation);
		If CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyPhone") Then
			IPData.Phone = ?(IsBlankString(IPData.Phone), CIPresentation, IPData.Phone + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyEmail") Then
			IPData.E_mail = ?(IsBlankString(IPData.E_mail), CIPresentation, IPData.E_mail + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyFax") Then
			IPData.Fax = ?(IsBlankString(IPData.Fax), CIPresentation, IPData.Fax + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyActualAddress") Then
			IPData.RealAddress = ?(IsBlankString(IPData.RealAddress), CIPresentation, IPData.RealAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyLegalAddress") Then
			IPData.LegAddress = ?(IsBlankString(IPData.LegAddress), CIPresentation, IPData.LegAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyPostalAddress") Then
			IPData.MailAddress = ?(IsBlankString(IPData.MailAddress), CIPresentation, IPData.MailAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyDeliveryAddress") Then
			IPData.ShippingAddress = ?(IsBlankString(IPData.ShippingAddress), CIPresentation, IPData.ShippingAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.CounterpartyOtherInformation") Then
			IPData.OtherInformation = ?(IsBlankString(IPData.OtherInformation), CIPresentation, IPData.OtherInformation + Chars.LF + CIPresentation);
		EndIf;
		
	EndDo;
	
	Return IPData;
	
EndFunction

// Receives required data about contact person CI.
//
Function GetDataContactPersonInfoPanel(CISelection, IPData)
	
	While CISelection.Next() Do
		
		CIPresentation = TrimAll(CISelection.CIPresentation);
		If CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.ContactPersonPhone") Then
			IPData.CLPhone = ?(IsBlankString(IPData.CLPhone), CIPresentation, IPData.CLPhone + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationKinds.ContactPersonEmail") Then
			IPData.ClEmail = ?(IsBlankString(IPData.ClEmail), CIPresentation, IPData.ClEmail + ", "+ CIPresentation);
		EndIf;
		
	EndDo;
	
	Return IPData;
	
EndFunction

// Receives necessary data about counterparty ArApAdjustments.
//
Function GetFillDataSettlementsInfoPanel(DebtsSelection, IPData)
	
	DebtsSelection.Next();
	
	IPData.Debt = DebtsSelection.CounterpartyDebt;
	IPData.OurDebt = DebtsSelection.OurDebt;
	
	Return IPData;
	
EndFunction

// Receives required data on the discount percentage by a counterparty discount card.
//
Function GetFillDataDiscountPercentByDiscountCardInfPanel(DiscountPercentByDiscountCard, SalesAmountOnDiscountCard, PeriodPresentation, IPData)
	
	IPData.DiscountPercentByDiscountCard = DiscountPercentByDiscountCard;
	IPData.SalesAmountOnDiscountCard = SalesAmountOnDiscountCard;
	IPData.PeriodPresentation = PeriodPresentation;
		
	Return IPData;
	
EndFunction

#EndRegion

#Region PostingManagement

// Fill posting mode.
//
// Parameters:
//  DocumentObject		- DocumentObject		- document object.
//  WriteMode			- DocumentWriteMode		- value of write mode.
//  PostingMode			- DocumentPostingMode	- value of posting mode.
//
Procedure SetPostingMode(DocumentObject, WriteMode, PostingMode) Export

	If DocumentObject.Posted And WriteMode = DocumentWriteMode.Posting Then
		PostingMode = DocumentPostingMode.Regular;
	EndIf;

EndProcedure

// Initializes additional properties to post a document.
//
Procedure InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties) Export
	
	If Not DenyWorkWithCodeCompletionAddIn() Then
		
		Try
			
			TempFileName = CoreMethodsTempFileName();
			File = New File(TempFileName);
			
			If ValueIsFilled(SessionParameters.CodeCompletionAddInPath) Then
				If Not File.Exist() Then
					BinaryData = GetFromTempStorage(SessionParameters.CodeCompletionAddInPath);
					BinaryData.Write(TempFileName);
				EndIf;
				
				ProtectionDescription = New UnsafeOperationProtectionDescription();
				ProtectionDescription.UnsafeOperationWarnings = False;
				
				ExternalDataProcessor = ExternalDataProcessors.Create(TempFileName, False, ProtectionDescription);
				ExternalDataProcessor.InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties);
			Else
				If Metadata.DataProcessors.Find("CoreMethods") <> Undefined Then
					DataProcessor = DataProcessors.CoreMethods.Create();
					DataProcessor.InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties);
				Else
					ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot create external data processor from component. Error: %1'; ru = 'Не удалось создать внешнюю обработку из компоненты. Ошибка: %1';pl = 'Nie można utworzyć zewnętrznego procesora danych z komponentu. Błąd: %1';es_ES = 'No se puede crear el procesamiento de datos externo desde el componente. Error: %1';es_CO = 'No se puede crear el procesamiento de datos externo desde el componente. Error: %1';tr = 'Bileşenden harici veri işlemcisi oluşturulamıyor. Hata: %1';it = 'Impossibile creare elaboratore dati esterno da componente. Errore: %1';de = 'Fehler beim Erstellen von externem Datenprozessor aus Komponente. Fehler: %1'"),
					DetailErrorDescription(ErrorInfo()));
					WriteErrorInEventLog(DriveLicenseErrorEventName(), ErrorDescription);
				EndIf;
			EndIf;
			
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create external data processor from component. Error: %1'; ru = 'Не удалось создать внешнюю обработку из компоненты. Ошибка: %1';pl = 'Nie można utworzyć zewnętrznego procesora danych z komponentu. Błąd: %1';es_ES = 'No se puede crear el procesamiento de datos externo desde el componente. Error: %1';es_CO = 'No se puede crear el procesamiento de datos externo desde el componente. Error: %1';tr = 'Bileşenden harici veri işlemcisi oluşturulamıyor. Hata: %1';it = 'Impossibile creare elaboratore dati esterno da componente. Errore: %1';de = 'Fehler beim Erstellen von externem Datenprozessor aus Komponente. Fehler: %1'"),
				DetailErrorDescription(ErrorInfo()));
			WriteErrorInEventLog(DriveLicenseErrorEventName(), ErrorDescription);
			
			If Metadata.DataProcessors.Find("CoreMethods") <> Undefined Then
				DataProcessor = DataProcessors.CoreMethods.Create();
				DataProcessor.InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties);
			EndIf;
		EndTry;
		
	ElsIf Metadata.DataProcessors.Find("CoreMethods") <> Undefined Then
		DataProcessor = DataProcessors.CoreMethods.Create();
		DataProcessor.InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
EndProcedure

// Checks table existance in query texts
//
// Parameters:
//  TableName		- String		- table name
//  QueryTexts		- ValueList		- value list, values is table names
//
// Returned value:
//  Boolean - True, if text exist.
//
Function IsTableInQuery(TableName, QueryTexts) Export

	If QueryTexts = Undefined Then
		Return True;
	EndIf; 
	
	For each QueryText In QueryTexts Do
		If Upper(QueryText.Presentation) = Upper(TableName) Then
			Return True;
		EndIf; 
	EndDo; 
	
	Return False;

EndFunction

// Generates register names array on which there are document movements.
//
Function GetNamesArrayOfUsedRegisters(Recorder, DocumentMetadata, ExcludedRegisters = Undefined)
	
	RegisterArray = New Array;
	QueryText = "";
	TableCounter = 0;
	DoCounter = 0;
	RegistersTotalAmount = DocumentMetadata.RegisterRecords.Count();
	
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		
		DoCounter = DoCounter + 1;
		
		SkipRegister = ExcludedRegisters <> Undefined
			And ExcludedRegisters.Find(RegisterRecord.Name) <> Undefined;
			
		If Not SkipRegister Then
		
			If TableCounter > 0 Then
				
				QueryText = QueryText + "
				|UNION ALL
				|";
				
			EndIf;
		
			TableCounter = TableCounter + 1;
		
			QueryText = QueryText + 
			"SELECT " + ?(TableCounter = 0, "ALLOWED ", "") + "TOP 1
			|""" + RegisterRecord.Name + """ AS RegisterName
			|
			|FROM " + RegisterRecord.FullName() + "
			|
			|WHERE Recorder = &Recorder
			|";
			
		EndIf;
		
		If TableCounter = 256 Or DoCounter = RegistersTotalAmount Then
			
			Query = New Query(QueryText);
			Query.SetParameter("Recorder", Recorder);
			
			QueryText  = "";
			TableCounter = 0;
			
			If RegisterArray.Count() = 0 Then
				RegisterArray = Query.Execute().Unload().UnloadColumn("RegisterName");
			Else
				
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					RegisterArray.Add(Selection.RegisterName);
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return RegisterArray;
	
EndFunction

// Prepares document records sets.
//
Procedure PrepareRecordSetsForRecording(ObjectStructure) Export
	
	Var IsNewDocument;
	
	AdditionalProperties = ObjectStructure.AdditionalProperties;
	
	If Not AdditionalProperties.Property("IsNew", IsNewDocument) Then
		IsNewDocument = False;
	EndIf;
	
	For Each RecordSet In ObjectStructure.RegisterRecords Do
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			RecordSet = RecordSet.Value;
		EndIf;
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
		EndIf;
	EndDo;
	
	ExcludedRegisters = Undefined;
	If AdditionalProperties.Property("WriteMode")
		And Not AdditionalProperties.WriteMode = DocumentWriteMode.UndoPosting Then
		ExcludedRegisters = New Array;
		ExcludedRegisters.Add("InventoryCostLayer");
		ExcludedRegisters.Add("LandedCosts");
	EndIf;
	
	ArrayOfNamesOfRegisters = GetNamesArrayOfUsedRegisters(
		ObjectStructure.Ref,
		AdditionalProperties.ForPosting.DocumentMetadata,
		ExcludedRegisters);
	
	For Each RegisterName In ArrayOfNamesOfRegisters Do
		ObjectStructure.RegisterRecords[RegisterName].Write = True;
	EndDo;
	
EndProcedure

// Writes document records sets.
//
Procedure WriteRecordSets(ObjectStructure) Export
	
	For Each RecordSet In ObjectStructure.RegisterRecords Do
		
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			
			RecordSet = RecordSet.Value;
			
		EndIf;
		
		If RecordSet.Write Then
			
			If Not RecordSet.AdditionalProperties.Property("ForPosting") Then
				
				RecordSet.AdditionalProperties.Insert("ForPosting", New Structure);
				
			EndIf;
			
			If Not RecordSet.AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
				
				RecordSet.AdditionalProperties.ForPosting.Insert("StructureTemporaryTables", ObjectStructure.AdditionalProperties.ForPosting.StructureTemporaryTables);
				
			EndIf;
			
			RecordSet.Write();
			RecordSet.Write = False;
			
		Else
			
			RecordSetMetadata = RecordSet.Metadata();
			If Common.IsAccumulationRegister(RecordSetMetadata)
				And ThereAreProcedureCreateAnEmptyTemporaryTableUpdate(RecordSetMetadata.FullName()) Then
				
				ObjectManager = Common.ObjectManagerByFullName(RecordSetMetadata.FullName());
				ObjectManager.CreateEmptyTemporaryTableChange(ObjectStructure.AdditionalProperties);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ThereAreProcedureCreateAnEmptyTemporaryTableUpdate(FullNameOfRegister)
	
	RegistersWithTheProcedure = New Array;
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.FixedAssets.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.CashAssets.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.CashInCashRegisters.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.UnallocatedExpenses.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.IncomeAndExpensesRetained.FullName());
	// begin Drive.FullVersion
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SubcontractorPlanning.FullName());
	// end Drive.FullVersion
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SalesOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsInvoicedNotReceived.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsShippedNotInvoiced.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsInvoicedNotShipped.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsReceivedNotInvoiced.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.PurchaseOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Inventory.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.InventoryInWarehouses.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.StockTransferredToThirdParties.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.StockReceivedFromThirdParties.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.InventoryDemand.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Backorders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.TaxPayable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Payroll.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AdvanceHolders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AccountsReceivable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AccountsPayable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.POSSummary.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SerialNumbers.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.VATIncurred.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsAwaitingCustomsClearance.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.WorkOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.TransferOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.ReservedProducts.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.BankReconciliation.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SubcontractorOrdersIssued.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.KitOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.FundsTransfersBeingProcessed.FullName());
	// begin Drive.FullVersion
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.ProductionOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.WorkInProgress.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.ManufacturingProcessSupply.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SubcontractComponents.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SubcontractorOrdersReceived.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.CustomerOwnedInventory.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.WorkInProgressStatement.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.ProductionComponents.FullName());
	// end Drive.FullVersion
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.KitOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.FundsTransfersBeingProcessed.FullName());
	Return RegistersWithTheProcedure.Find(FullNameOfRegister) <> Undefined;
	
EndFunction

// Checks whether it is possible to clear the UseSerialNumbers option.
//
Function CancelRemoveFunctionalOptionUseSerialNumbers() Export
	
	ErrorText = "";
	AreRecords = False;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 1
	|	SerialNumbers.SerialNumber
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'Serial numbers functionality has been already used. To turn it off, please, make sure there are no records in the Serial numbers accumulation register.'; ru = 'Учет по серийным номерам уже используется. Чтобы отключить его, убедитесь, что в регистре накопления ""Серийные номера"" нет записей.';pl = 'Funkcje Numerów seryjnych zostały już użyte. Aby wyłączyć tę funkcję, upewnij się, że w rejestrze rejestrów Numerów seryjnych nie ma żadnych wpisów.';es_ES = 'Funcionalidad de los números de serie se ha ya utilizado. Para desactivarla, por favor, asegurarse que no haya grabaciones en el registro de la Acumulación de números de serie.';es_CO = 'Funcionalidad de los números de serie se ha ya utilizado. Para desactivarla, por favor, asegurarse que no haya grabaciones en el registro de la Acumulación de números de serie.';tr = 'Seri numaraları işlevselliği zaten kullanılmıştır. Kapatmak için lütfen, kayıt sırasında Seri numaralarında kayıt olmadığından emin olun.';it = 'La funzionalità dei numeri di serie è già stata utilizzata. Per disattivarla, per favore, assicuratevi che non ci siano registrazioni nel registro di accumulo dei numeri di serie.';de = 'Seriennummernfunktionalität wurde bereits verwendet. Um sie auszuschalten, vergewissern Sie sich, dass sich keine Datensätze im Seriennummern-Sammelregister befinden.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

Procedure CheckDocumentsReposting(Ref, Posted, Cancel) Export
	
	If Posted And GetFunctionalOption("UseConsistentAuditTrail") Then
		
		If Not Users.RolesAvailable("DocumentsReposting") Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Insufficient access rights to repost the document %1. You should have either ""Full rights"" or ""Documents reposting"" profile.'; ru = 'Недостаточные права доступы для перепроведения документа %1. У вас должен быть профиль ""Полный доступ"" или ""Перепроведение документов"".';pl = 'Nie masz wystarczająco praw dostępu do przeksięgowania dokumentu %1. Musisz mieć lub profil ""Pełny dostęp"" lub ""Przeksięgowanie dokumentów"".';es_ES = 'Insuficientes derechos de acceso para reenviar el documento%1. Debe tener un perfil de ""Pleno derecho"" o ""Reenvío de documentos"".';es_CO = 'Insuficientes derechos de acceso para reenviar el documento%1. Debe tener un perfil de ""Pleno derecho"" o ""Reenvío de documentos"".';tr = '%1 belgesini yeniden yayınlamak için erişim yetkileriniz yetersiz. Profilinizde ""Tüm yetkiler"" veya ""Belgeleri yeniden yayınlama"" yetkiniz olmalıdır.';it = 'Permessi insufficienti per ripubblicare il documento %1. Dovete avere ""Permessi completi"" o un profilo ""Ripubblicazione documenti"".';de = 'Unzureichende Zugriffsrechte, um das Dokument erneut zu buchen %1. Sie sollten entweder das Profil ""Vollrechte"" oder das Profil ""Umbuchung von Dokumenten"" haben.'"),
				Ref);
			
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#Region OfflineRegisters

// Reflect document in information registers "Tasks..."
Procedure CreateRecordsInTasksRegisters(DocumentObject, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FIFO.ReflectTasks(DocumentObject, DocumentObject.AdditionalProperties);
	
EndProcedure

// Moves accumulation register InventoryCostLayer.
//
Procedure ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryCostLayer = AdditionalProperties.TableForRegisterRecords.TableInventoryCostLayer;
	
	If (Cancel Or TableInventoryCostLayer.Count() = 0)
		And (AdditionalProperties.Property("DocumentAttributes")
			And Not AdditionalProperties.DocumentAttributes.Property("AdvanceInvoicing")) Then
		Return;
	EndIf;
	
	InventoryCostLayerRegistering = RegisterRecords.InventoryCostLayer;
	InventoryCostLayerRegistering.Write = True;
	InventoryCostLayerRegistering.Load(TableInventoryCostLayer);
	
EndProcedure

// Moves information register AccountingEntriesData.
//
Procedure ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountingEntriesData = AdditionalProperties.TableForRegisterRecords.TableAccountingEntriesData;
	
	If (Cancel Or TableAccountingEntriesData.Count() = 0) Then
		Return;
	EndIf;
	
	InventoryAccountingEntriesData = RegisterRecords.AccountingEntriesData;
	InventoryAccountingEntriesData.Write = True;
	InventoryAccountingEntriesData.Load(TableAccountingEntriesData);
	
EndProcedure

// Moves accumulation register LandedCosts.
//
Procedure ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableLandedCosts = AdditionalProperties.TableForRegisterRecords.TableLandedCosts;
	
	If Cancel Or TableLandedCosts.Count() = 0 Then
		Return;
	EndIf;
	
	LandedCostsRegistering = RegisterRecords.LandedCosts;
	LandedCostsRegistering.Write = True;
	LandedCostsRegistering.Load(TableLandedCosts);
	
EndProcedure

// Moves accumulation register ForeignExchangeGainsAndLosses.
//
Procedure ReflectForeignExchangeGainsAndLosses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableForeignExchangeGainsAndLosses = AdditionalProperties.TableForRegisterRecords.TableForeignExchangeGainsAndLosses;
	
	If Cancel
		Or TableForeignExchangeGainsAndLosses.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsForeignExchangeGainsAndLosses = RegisterRecords.ForeignExchangeGainsAndLosses;
	RegisterRecordsForeignExchangeGainsAndLosses.Write = True;
	RegisterRecordsForeignExchangeGainsAndLosses.Load(TableForeignExchangeGainsAndLosses);
	
EndProcedure

#EndRegion

#Region ZeroInvoice

Procedure SetZeroInvoiceInTable(ValueTableSource) Export
	
	ValueTableSource.Columns.Add("ZeroInvoice", New TypeDescription("Boolean"));
	
	For Each Line In ValueTableSource Do
	
		Line.ZeroInvoice = True;
	
	EndDo;
	
	SetDistinctRows(ValueTableSource);
	
EndProcedure

#EndRegion

#EndRegion

#Region RegistersMovementsGeneratingProcedures

// Function returns the ControlBalancesDuringOnPosting constant value.
// 
Function RunBalanceControl() Export
	
	Return Constants.CheckStockBalanceOnPosting.Get();
	
EndFunction

// Checks the stock balance with reserves.
//
Procedure CheckAvailableStockBalance(DocumentObject, AdditionalProperties, Cancel) Export
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
		And StructureTemporaryTables.RegisterRecordsInventoryChange
		Or StructureTemporaryTables.Property("RegisterRecordsReservedProductsChange")
		And StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
		
		Query = New Query;
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		If StructureTemporaryTables.Property("RegisterRecordsInventoryChange")
			And StructureTemporaryTables.RegisterRecordsInventoryChange Then
			
			Query.Text =
			"SELECT DISTINCT
			|	InventoryChanges.Company AS Company,
			|	InventoryChanges.StructuralUnit AS StructuralUnit,
			|	InventoryChanges.Products AS Products,
			|	InventoryChanges.Characteristic AS Characteristic,
			|	InventoryChanges.Batch AS Batch,
			|	SUM(InventoryChanges.QuantityChange) AS Quantity
			|INTO RegisterRecordsInventoryChanges
			|FROM
			|	RegisterRecordsInventoryChange AS InventoryChanges
			|
			|GROUP BY
			|	InventoryChanges.Company,
			|	InventoryChanges.StructuralUnit,
			|	InventoryChanges.Products,
			|	InventoryChanges.Characteristic,
			|	InventoryChanges.Batch
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	Balance.Company AS Company,
			|	Balance.StructuralUnit AS StructuralUnit,
			|	Balance.Products AS Products,
			|	Balance.Characteristic AS Characteristic,
			|	Balance.Batch AS Batch,
			|	SUM(Balance.Quantity) AS Quantity
			|INTO BalanceInStock
			|FROM
			|	(SELECT
			|		Inventory.Company AS Company,
			|		Inventory.StructuralUnit AS StructuralUnit,
			|		Inventory.Products AS Products,
			|		Inventory.Characteristic AS Characteristic,
			|		Inventory.Batch AS Batch,
			|		Inventory.QuantityBalance AS Quantity
			|	FROM
			|		AccumulationRegister.Inventory.Balance(
			|				&ControlTime,
			|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) IN
			|					(SELECT
			|						RegisterRecordsInventoryChanges.Company AS Company,
			|						RegisterRecordsInventoryChanges.StructuralUnit AS StructuralUnit,
			|						RegisterRecordsInventoryChanges.Products AS Products,
			|						RegisterRecordsInventoryChanges.Characteristic AS Characteristic,
			|						RegisterRecordsInventoryChanges.Batch AS Batch,
			|						&OwnInventory AS Ownership
			|					FROM
			|						RegisterRecordsInventoryChanges AS RegisterRecordsInventoryChanges)) AS Inventory
			|	
			|	UNION ALL
			|	
			|	SELECT
			|		ReservedProducts.Company,
			|		ReservedProducts.StructuralUnit,
			|		ReservedProducts.Products,
			|		ReservedProducts.Characteristic,
			|		ReservedProducts.Batch,
			|		-ReservedProducts.QuantityBalance
			|	FROM
			|		AccumulationRegister.ReservedProducts.Balance(
			|				&ControlTime,
			|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
			|					(SELECT
			|						RegisterRecordsInventoryChanges.Company AS Company,
			|						RegisterRecordsInventoryChanges.StructuralUnit AS StructuralUnit,
			|						RegisterRecordsInventoryChanges.Products AS Products,
			|						RegisterRecordsInventoryChanges.Characteristic AS Characteristic,
			|						RegisterRecordsInventoryChanges.Batch AS Batch
			|					FROM
			|						RegisterRecordsInventoryChanges AS RegisterRecordsInventoryChanges)) AS ReservedProducts) AS Balance
			|
			|GROUP BY
			|	Balance.Company,
			|	Balance.StructuralUnit,
			|	Balance.Products,
			|	Balance.Characteristic,
			|	Balance.Batch
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	1 AS LineNumber,
			|	RegisterRecordsInventoryChanges.Company AS CompanyPresentation,
			|	RegisterRecordsInventoryChanges.StructuralUnit AS StructuralUnitPresentation,
			|	RegisterRecordsInventoryChanges.Products AS ProductsPresentation,
			|	RegisterRecordsInventoryChanges.Characteristic AS CharacteristicPresentation,
			|	RegisterRecordsInventoryChanges.Batch AS BatchPresentation,
			|	BusinessUnit.StructuralUnitType AS StructuralUnitType,
			|	Product.MeasurementUnit AS MeasurementUnitPresentation,
			|	RegisterRecordsInventoryChanges.Quantity + Balance.Quantity AS BalanceInventory,
			|	Balance.Quantity AS QuantityBalanceInventory
			|FROM
			|	RegisterRecordsInventoryChanges AS RegisterRecordsInventoryChanges
			|		INNER JOIN BalanceInStock AS Balance
			|		ON RegisterRecordsInventoryChanges.Company = Balance.Company
			|			AND RegisterRecordsInventoryChanges.StructuralUnit = Balance.StructuralUnit
			|			AND RegisterRecordsInventoryChanges.Products = Balance.Products
			|			AND RegisterRecordsInventoryChanges.Characteristic = Balance.Characteristic
			|			AND RegisterRecordsInventoryChanges.Batch = Balance.Batch
			|			AND (Balance.Quantity < 0)
			|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnit
			|		ON RegisterRecordsInventoryChanges.StructuralUnit = BusinessUnit.Ref
			|		LEFT JOIN Catalog.Products AS Product
			|		ON RegisterRecordsInventoryChanges.Products = Product.Ref";
			
		ElsIf StructureTemporaryTables.Property("RegisterRecordsReservedProductsChange")
			And StructureTemporaryTables.RegisterRecordsReservedProductsChange Then
			
			Query.Text =
			"SELECT DISTINCT
			|	ReservedProductsChanges.Company AS Company,
			|	ReservedProductsChanges.StructuralUnit AS StructuralUnit,
			|	ReservedProductsChanges.Products AS Products,
			|	ReservedProductsChanges.Characteristic AS Characteristic,
			|	ReservedProductsChanges.Batch AS Batch,
			|	SUM(ReservedProductsChanges.QuantityChange) AS Quantity
			|INTO RegisterRecordsReservedProductsChanges
			|FROM
			|	RegisterRecordsReservedProductsChange AS ReservedProductsChanges
			|
			|GROUP BY
			|	ReservedProductsChanges.Company,
			|	ReservedProductsChanges.StructuralUnit,
			|	ReservedProductsChanges.Products,
			|	ReservedProductsChanges.Characteristic,
			|	ReservedProductsChanges.Batch
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED
			|	Balance.Company AS Company,
			|	Balance.StructuralUnit AS StructuralUnit,
			|	Balance.Products AS Products,
			|	Balance.Characteristic AS Characteristic,
			|	Balance.Batch AS Batch,
			|	SUM(Balance.Quantity) AS Quantity
			|INTO BalanceInStockReserved
			|FROM
			|	(SELECT
			|		Inventory.Company AS Company,
			|		Inventory.StructuralUnit AS StructuralUnit,
			|		Inventory.Products AS Products,
			|		Inventory.Characteristic AS Characteristic,
			|		Inventory.Batch AS Batch,
			|		Inventory.QuantityBalance AS Quantity
			|	FROM
			|		AccumulationRegister.Inventory.Balance(
			|				&ControlTime,
			|				(Company, StructuralUnit, Products, Characteristic, Batch, Ownership) IN
			|					(SELECT
			|						RegisterRecordsReservedProductsChanges.Company AS Company,
			|						RegisterRecordsReservedProductsChanges.StructuralUnit AS StructuralUnit,
			|						RegisterRecordsReservedProductsChanges.Products AS Products,
			|						RegisterRecordsReservedProductsChanges.Characteristic AS Characteristic,
			|						RegisterRecordsReservedProductsChanges.Batch AS Batch,
			|						&OwnInventory
			|					FROM
			|						RegisterRecordsReservedProductsChanges AS RegisterRecordsReservedProductsChanges)) AS Inventory
			|	
			|	UNION ALL
			|	
			|	SELECT
			|		ReservedProducts.Company,
			|		ReservedProducts.StructuralUnit,
			|		ReservedProducts.Products,
			|		ReservedProducts.Characteristic,
			|		ReservedProducts.Batch,
			|		-ReservedProducts.QuantityBalance
			|	FROM
			|		AccumulationRegister.ReservedProducts.Balance(
			|				&ControlTime,
			|				(Company, StructuralUnit, Products, Characteristic, Batch) IN
			|					(SELECT
			|						RegisterRecordsReservedProductsChanges.Company AS Company,
			|						RegisterRecordsReservedProductsChanges.StructuralUnit AS StructuralUnit,
			|						RegisterRecordsReservedProductsChanges.Products AS Products,
			|						RegisterRecordsReservedProductsChanges.Characteristic AS Characteristic,
			|						RegisterRecordsReservedProductsChanges.Batch AS Batch
			|					FROM
			|						RegisterRecordsReservedProductsChanges AS RegisterRecordsReservedProductsChanges)) AS ReservedProducts) AS Balance
			|
			|GROUP BY
			|	Balance.Company,
			|	Balance.StructuralUnit,
			|	Balance.Products,
			|	Balance.Characteristic,
			|	Balance.Batch
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	1 AS LineNumber,
			|	RegisterRecordsReservedProductsChanges.Company AS CompanyPresentation,
			|	RegisterRecordsReservedProductsChanges.StructuralUnit AS StructuralUnitPresentation,
			|	RegisterRecordsReservedProductsChanges.Products AS ProductsPresentation,
			|	RegisterRecordsReservedProductsChanges.Characteristic AS CharacteristicPresentation,
			|	RegisterRecordsReservedProductsChanges.Batch AS BatchPresentation,
			|	BusinessUnit.StructuralUnitType AS StructuralUnitType,
			|	Product.MeasurementUnit AS MeasurementUnitPresentation,
			|	-RegisterRecordsReservedProductsChanges.Quantity + Balance.Quantity AS BalanceInventory,
			|	Balance.Quantity AS QuantityBalanceInventory
			|FROM
			|	RegisterRecordsReservedProductsChanges AS RegisterRecordsReservedProductsChanges
			|		INNER JOIN BalanceInStockReserved AS Balance
			|		ON RegisterRecordsReservedProductsChanges.Company = Balance.Company
			|			AND RegisterRecordsReservedProductsChanges.StructuralUnit = Balance.StructuralUnit
			|			AND RegisterRecordsReservedProductsChanges.Products = Balance.Products
			|			AND RegisterRecordsReservedProductsChanges.Characteristic = Balance.Characteristic
			|			AND RegisterRecordsReservedProductsChanges.Batch = Balance.Batch
			|			AND (Balance.Quantity < 0)
			|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnit
			|		ON RegisterRecordsReservedProductsChanges.StructuralUnit = BusinessUnit.Ref
			|		LEFT JOIN Catalog.Products AS Product
			|		ON RegisterRecordsReservedProductsChanges.Products = Product.Ref";
			
		EndIf;
		
		Query.SetParameter("OwnInventory", Catalogs.InventoryOwnership.OwnInventory());
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObject, Selection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Checks the Backorders balance with reserves.
//
Procedure CheckSalesOrdersMinusBackordersBalance(DocumentObject, AdditionalProperties, Cancel) Export
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.Property("RegisterRecordsBackordersChange")
		And StructureTemporaryTables.RegisterRecordsBackordersChange Then
		
		Query = New Query;
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.Text =
		"SELECT ALLOWED
		|	OrdersBalance.Company AS Company,
		|	OrdersBalance.SalesOrder AS SalesOrder,
		|	OrdersBalance.Products AS Products,
		|	OrdersBalance.Characteristic AS Characteristic,
		|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
		|INTO BalanceTable
		|FROM
		|	(SELECT
		|		SalesOrdersBalance.Company AS Company,
		|		SalesOrdersBalance.SalesOrder AS SalesOrder,
		|		SalesOrdersBalance.Products AS Products,
		|		SalesOrdersBalance.Characteristic AS Characteristic,
		|		SalesOrdersBalance.QuantityBalance AS QuantityBalance
		|	FROM
		|		AccumulationRegister.SalesOrders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS SalesOrdersBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		WorkOrdersBalance.Company,
		|		WorkOrdersBalance.WorkOrder,
		|		WorkOrdersBalance.Products,
		|		WorkOrdersBalance.Characteristic,
		|		WorkOrdersBalance.QuantityBalance
		|	FROM
		|		AccumulationRegister.WorkOrders.Balance(
		|				&ControlTime,
		|				(Company, WorkOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS WorkOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS WorkOrdersBalance
		|	
		|	UNION ALL
		// begin Drive.FullVersion
		|	
		|	SELECT
		|		ProductionComponentsBalance.Company,
		|		ProductionComponentsBalance.ProductionDocument,
		|		ProductionComponentsBalance.Products,
		|		ProductionComponentsBalance.Characteristic,
		|		ProductionComponentsBalance.QuantityBalance
		|	FROM
		|		AccumulationRegister.ProductionComponents.Balance(
		|				&ControlTime,
		|				(Company, ProductionDocument, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS ProductionComponentsBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		SubcontractorPlanning.Company,
		|		SubcontractorPlanning.WorkInProgress,
		|		SubcontractorPlanning.Products,
		|		SubcontractorPlanning.Characteristic,
		|		CASE
		|			WHEN SubcontractorPlanning.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN SubcontractorPlanning.Quantity
		|			ELSE -SubcontractorPlanning.Quantity
		|		END
		|	FROM
		|		AccumulationRegister.SubcontractorPlanning AS SubcontractorPlanning
		|	WHERE
		|		(SubcontractorPlanning.Company, SubcontractorPlanning.Recorder, SubcontractorPlanning.WorkInProgress, SubcontractorPlanning.Products, SubcontractorPlanning.Characteristic) IN
		|				(SELECT
		|					RegisterRecordsBackordersChange.Company AS Company,
		|					RegisterRecordsBackordersChange.SalesOrder AS Recorder,
		|					RegisterRecordsBackordersChange.SalesOrder AS WorkInProgress,
		|					RegisterRecordsBackordersChange.Products AS Products,
		|					RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|				FROM
		|					RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)
		|	
		|	UNION ALL
		// end Drive.FullVersion
		|	
		|	SELECT
		|		ReservedProductsBalances.Company,
		|		ReservedProductsBalances.SalesOrder,
		|		ReservedProductsBalances.Products,
		|		ReservedProductsBalances.Characteristic,
		|		-ReservedProductsBalances.QuantityBalance
		|	FROM
		|		AccumulationRegister.ReservedProducts.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, SalesOrder) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS ReservedProductsBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		BackordersBalances.Company,
		|		BackordersBalances.SalesOrder,
		|		BackordersBalances.Products,
		|		BackordersBalances.Characteristic,
		|		-BackordersBalances.QuantityBalance
		|	FROM
		|		AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		GoodsInvoicedNotShippedBalance.Company,
		|		GoodsInvoicedNotShippedBalance.SalesOrder,
		|		GoodsInvoicedNotShippedBalance.Products,
		|		GoodsInvoicedNotShippedBalance.Characteristic,
		|		GoodsInvoicedNotShippedBalance.QuantityBalance
		|	FROM
		|		AccumulationRegister.GoodsInvoicedNotShipped.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS GoodsInvoicedNotShippedBalance) AS OrdersBalance
		|
		|GROUP BY
		|	OrdersBalance.Company,
		|	OrdersBalance.SalesOrder,
		|	OrdersBalance.Products,
		|	OrdersBalance.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.SalesOrder AS SalesOrderPresentation,
		|	RegisterRecordsBackordersChange.Products AS ProductsPresentation,
		|	RegisterRecordsBackordersChange.Characteristic AS CharacteristicPresentation,
		|	Product.MeasurementUnit AS MeasurementUnitPresentation,
		|	-RegisterRecordsBackordersChange.QuantityChange + Balance.QuantityBalance AS BalanceOrders,
		|	Balance.QuantityBalance AS QuantityBalanceOrders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		INNER JOIN BalanceTable AS Balance
		|		ON RegisterRecordsBackordersChange.Company = Balance.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = Balance.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = Balance.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = Balance.Characteristic
		|			AND (Balance.QuantityBalance < 0)
		|		LEFT JOIN Catalog.Products AS Product
		|		ON RegisterRecordsBackordersChange.Products = Product.Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP BalanceTable";
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			ShowMessageAboutPostingToBackordersAndSalesOrdersRegistersErrors(DocumentObject, Selection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region OrderedMinusBackorderedBalance

// Ordered minus backordered balance
Procedure CheckOrderedMinusBackorderedBalance(DocumentRef, AdditionalProperties, Cancel) Export
	
	DocumentsDescription = New Structure;
	DocumentsDescription.Insert("DocumentRef", DocumentRef);
	ChangedDocuments = New Array;
	
	DocumentType = TypeOf(DocumentRef);
	
	If DocumentType = Type("DocumentRef.InventoryReservation") Or TypeOf(DocumentRef) = Type("DocumentRef.TransferOrder") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "TransferOrder";
		DocumentStructure.RegisterName = "TransferOrders";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	
	If DocumentType = Type("DocumentRef.InventoryReservation") Or TypeOf(DocumentRef) = Type("DocumentRef.SubcontractorOrderIssued") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "SubcontractorOrder";
		DocumentStructure.RegisterName = "SubcontractorOrdersIssued";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	
	If DocumentType = Type("DocumentRef.InventoryReservation") Or TypeOf(DocumentRef) = Type("DocumentRef.SalesOrder") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "SalesOrder";
		DocumentStructure.RegisterName = "SalesOrders";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	
	// begin Drive.FullVersion
	If DocumentType = Type("DocumentRef.InventoryReservation") Or TypeOf(DocumentRef) = Type("DocumentRef.ProductionOrder") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "ProductionOrder";
		DocumentStructure.RegisterName = "ProductionOrders";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	// end Drive.FullVersion
	
	If DocumentType = Type("DocumentRef.InventoryReservation") Or DocumentType = Type("DocumentRef.PurchaseOrder") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "PurchaseOrder";
		DocumentStructure.RegisterName = "PurchaseOrders";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	
	If DocumentType = Type("DocumentRef.InventoryReservation") Or TypeOf(DocumentRef) = Type("DocumentRef.KitOrder") Then
		
		DocumentStructure = New Structure("DocumentName, RegisterName");
		DocumentStructure.DocumentName = "KitOrder";
		DocumentStructure.RegisterName = "KitOrders";
		
		ChangedDocuments.Add(DocumentStructure);
		
	EndIf;
	
	DocumentsDescription.Insert("ChangedDocuments", ChangedDocuments);
	CheckOrderedMinusBackorderedBalanceForOrder(DocumentsDescription, AdditionalProperties, Cancel);
	
EndProcedure

Procedure CheckOrderedMinusBackorderedBalanceForOrder(DocumentsDescription, AdditionalProperties, Cancel)
	
	DocumentRef = DocumentsDescription.DocumentRef;
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.Property("RegisterRecordsBackordersChange")
		And StructureTemporaryTables.RegisterRecordsBackordersChange Then
		
		Query = New Query;
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		Query.Text = BackordersChangeQueryText(DocumentsDescription);
		
		QueryResult = Query.Execute();
		
		If NOT QueryResult.IsEmpty() Then
			Selection = QueryResult.Select();
			ShowMessageAboutPostingToBackordersAndOrdersRegistersErrors(DocumentRef, Selection, Cancel);
		EndIf;
		
	EndIf;
	
	If DocumentsDescription.ChangedDocuments.Count() = 1 Then
		
		DocumentStructure = DocumentsDescription.ChangedDocuments[0];
		
		DocumentName = DocumentStructure.DocumentName;
		RegisterName = DocumentStructure.RegisterName;
		
		TemporaryTableName = StringFunctionsClientServer.SubstituteParametersToString("RegisterRecords%1Change", RegisterName);
		
		If StructureTemporaryTables.Property(TemporaryTableName)
			And StructureTemporaryTables[TemporaryTableName] Then
			
			Query = New Query;
			Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
			Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
			Query.Text =
			"SELECT ALLOWED
			|	OrdersBalance.Company AS Company,
			|	OrdersBalance.DocumentOrder AS DocumentOrder,
			|	OrdersBalance.Products AS Products,
			|	OrdersBalance.Characteristic AS Characteristic,
			|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
			|INTO OrdersMinusBackordersBalanceTable
			|FROM
			|	(SELECT
			|		PurchaseOrdersBalance.Company AS Company,
			|		PurchaseOrdersBalance.PurchaseOrder AS DocumentOrder,
			|		PurchaseOrdersBalance.Products AS Products,
			|		PurchaseOrdersBalance.Characteristic AS Characteristic,
			|		PurchaseOrdersBalance.QuantityBalance AS QuantityBalance
			|	FROM
			|		AccumulationRegister.PurchaseOrders.Balance(
			|				&ControlTime,
			|				(Company, PurchaseOrder, Products, Characteristic) IN
			|					(SELECT
			|						RegisterRecordsBackordersChange.Company AS Company,
			|						RegisterRecordsBackordersChange.PurchaseOrder AS PurchaseOrder,
			|						RegisterRecordsBackordersChange.Products AS Products,
			|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
			|					FROM
			|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsBackordersChange)) AS PurchaseOrdersBalance
			|	
			|	UNION ALL
			|	
			|	SELECT
			|		BackordersBalances.Company,
			|		BackordersBalances.SupplySource,
			|		BackordersBalances.Products,
			|		BackordersBalances.Characteristic,
			|		-BackordersBalances.QuantityBalance
			|	FROM
			|		AccumulationRegister.Backorders.Balance(
			|				&ControlTime,
			|				(Company, SupplySource, Products, Characteristic) IN
			|					(SELECT
			|						RegisterRecordsBackordersChange.Company AS Company,
			|						RegisterRecordsBackordersChange.PurchaseOrder AS PurchaseOrder,
			|						RegisterRecordsBackordersChange.Products AS Products,
			|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
			|					FROM
			|						RegisterRecordsPurchaseOrdersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances) AS OrdersBalance
			|
			|GROUP BY
			|	OrdersBalance.Company,
			|	OrdersBalance.DocumentOrder,
			|	OrdersBalance.Products,
			|	OrdersBalance.Characteristic
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT
			|	RegisterRecordsPurchaseOrdersChange.PurchaseOrder AS DocumentOrderPresentation,
			|	RegisterRecordsPurchaseOrdersChange.Products AS ProductsPresentation,
			|	RegisterRecordsPurchaseOrdersChange.Characteristic AS CharacteristicPresentation,
			|	Product.MeasurementUnit AS MeasurementUnitPresentation,
			|	RegisterRecordsPurchaseOrdersChange.QuantityChange - Balance.QuantityBalance AS BalanceOrders,
			|	Balance.QuantityBalance AS QuantityBalanceOrders
			|FROM
			|	RegisterRecordsPurchaseOrdersChange AS RegisterRecordsPurchaseOrdersChange
			|		INNER JOIN OrdersMinusBackordersBalanceTable AS Balance
			|		ON RegisterRecordsPurchaseOrdersChange.Company = Balance.Company
			|			AND RegisterRecordsPurchaseOrdersChange.PurchaseOrder = Balance.DocumentOrder
			|			AND RegisterRecordsPurchaseOrdersChange.Products = Balance.Products
			|			AND RegisterRecordsPurchaseOrdersChange.Characteristic = Balance.Characteristic
			|			AND (Balance.QuantityBalance < 0)
			|		LEFT JOIN Catalog.Products AS Product
			|		ON RegisterRecordsPurchaseOrdersChange.Products = Product.Ref
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|DROP OrdersMinusBackordersBalanceTable";
			
			Query.Text = StrReplace(Query.Text, "RegisterRecordsPurchaseOrdersChange", TemporaryTableName);
			Query.Text = StrReplace(Query.Text, "PurchaseOrders", RegisterName);
			Query.Text = StrReplace(Query.Text, "PurchaseOrder", DocumentName);
			
			QueryResult = Query.Execute();
			
			If NOT QueryResult.IsEmpty() Then
				Selection = QueryResult.Select();
				ShowMessageAboutPostingToBackordersAndOrdersRegistersErrors(DocumentRef, Selection, Cancel);
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Function BackordersChangeQueryText(DocumentsDescription)
	
	DocumentsBalanceQueryText = "";
	
	For Each DocumentStructure In DocumentsDescription.ChangedDocuments Do
		
		DocumentName = DocumentStructure.DocumentName;
		RegisterName = DocumentStructure.RegisterName;
		
		QueryText =
		"SELECT
		|	PurchaseOrdersBalance.Company AS Company,
		|	PurchaseOrdersBalance.PurchaseOrder AS DocumentOrder,
		|	PurchaseOrdersBalance.Products AS Products,
		|	PurchaseOrdersBalance.Characteristic AS Characteristic,
		|	PurchaseOrdersBalance.QuantityBalance AS QuantityBalance
		|FROM
		|	AccumulationRegister.PurchaseOrders.Balance(
		|			&ControlTime,
		|			(Company, PurchaseOrder, Products, Characteristic) IN
		|				(SELECT
		|					RegisterRecordsBackordersChange.Company AS Company,
		|					RegisterRecordsBackordersChange.SupplySource AS SupplySource,
		|					RegisterRecordsBackordersChange.Products AS Products,
		|					RegisterRecordsBackordersChange.Characteristic AS Characteristic
		|				FROM
		|					RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS PurchaseOrdersBalance";
		
		QueryText = StrReplace(QueryText, "PurchaseOrders", RegisterName);
		QueryText = StrReplace(QueryText, "PurchaseOrder", DocumentName);
		
		DocumentsBalanceQueryText = DocumentsBalanceQueryText + DriveClientServer.GetQueryUnion() + QueryText;
		
	EndDo;
	
	ResultQueryText =
	"SELECT ALLOWED
	|	OrdersBalance.Company AS Company,
	|	OrdersBalance.DocumentOrder AS DocumentOrder,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|INTO OrdersMinusBackordersBalanceTable
	|FROM
	|	(SELECT
	|		BackordersBalances.Company AS Company,
	|		BackordersBalances.SupplySource AS DocumentOrder,
	|		BackordersBalances.Products AS Products,
	|		BackordersBalances.Characteristic AS Characteristic,
	|		-BackordersBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				&ControlTime,
	|				(Company, SupplySource, Products, Characteristic) IN
	|					(SELECT
	|						RegisterRecordsBackordersChange.Company AS Company,
	|						RegisterRecordsBackordersChange.SupplySource AS SupplySource,
	|						RegisterRecordsBackordersChange.Products AS Products,
	|						RegisterRecordsBackordersChange.Characteristic AS Characteristic
	|					FROM
	|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Company,
	|	OrdersBalance.DocumentOrder,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RegisterRecordsBackordersChange.SupplySource AS DocumentOrderPresentation,
	|	RegisterRecordsBackordersChange.Products AS ProductsPresentation,
	|	RegisterRecordsBackordersChange.Characteristic AS CharacteristicPresentation,
	|	Product.MeasurementUnit AS MeasurementUnitPresentation,
	|	-RegisterRecordsBackordersChange.QuantityChange + Balance.QuantityBalance AS BalanceOrders,
	|	Balance.QuantityBalance AS QuantityBalanceOrders
	|FROM
	|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
	|		INNER JOIN OrdersMinusBackordersBalanceTable AS Balance
	|		ON RegisterRecordsBackordersChange.Company = Balance.Company
	|			AND RegisterRecordsBackordersChange.SupplySource = Balance.DocumentOrder
	|			AND RegisterRecordsBackordersChange.Products = Balance.Products
	|			AND RegisterRecordsBackordersChange.Characteristic = Balance.Characteristic
	|			AND (Balance.QuantityBalance < 0)
	|		LEFT JOIN Catalog.Products AS Product
	|		ON RegisterRecordsBackordersChange.Products = Product.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP OrdersMinusBackordersBalanceTable";
	
	ResultQueryText = StrReplace(ResultQueryText, ") AS OrdersBalance", DocumentsBalanceQueryText + ") AS OrdersBalance");

	Return ResultQueryText;
	
EndFunction

Procedure ShowMessageAboutPostingToBackordersAndOrdersRegistersErrors(DocumentRef, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Registered more than the inventory allocated in the orders.'; ru = 'Оформлено больше запасов, чем размещено в заказах.';pl = 'Zarejestrowano więcej. niż zapas przydzielony w zamówieniach.';es_ES = 'Registrado más del inventario asignado en los órdenes.';es_CO = 'Registrado más del inventario asignado en los órdenes.';tr = 'Siparişlerde tahsis edilenden stoktan daha fazlası kaydedildi.';it = 'È stato registrato più dell''inventario assegnato agli ordini.';de = 'Mehr als der in den Bestellungen zugewiesene Bestand registriert.'");
	ShowMessageAboutError(DocumentRef, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1, order: %5
							|balance by order %2 %3,
							|exceeds by %4 %3'; 
							|ru = 'Номенклатура: %1, заказ: %5
							|остаток по заказу %2 %3,
							|превышает на %4 %3';
							|pl = 'Produkty: %1, zamówienie: %5
							|saldo według zamówienia %2 %3,
							|przekracza o %4 %3';
							|es_ES = 'Productos: %1, orden: %5
							|saldo por orden %2 %3,
							|excede por %4 %3';
							|es_CO = 'Productos: %1, orden: %5
							|saldo por orden %2 %3,
							|excede por %4 %3';
							|tr = 'Ürünler: %1, sipariş: %5
							|siparişe göre bakiye %2 %3,
							|fazlalık %4 %3';
							|it = 'Articoli: %1, ordine: %5
							|saldo per ordine %2 %3,
							|eccede di %4 %3';
							|de = 'Produkte: %1, Auftrag: %5
							|Auftragssaldo %2%3,
							|übersteigt um %4%3'");
	
	While RecordsSelection.Next() Do
		
		ProductsPresentation = PresentationOfProducts(RecordsSelection.ProductsPresentation,
			RecordsSelection.CharacteristicPresentation);
			
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
			ProductsPresentation,
			String(RecordsSelection.BalanceOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceOrders),
			TrimAll(RecordsSelection.DocumentOrderPresentation));
		
		ShowMessageAboutError(DocumentRef, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region OtherSettlements

// Moves accumulation register MiscellaneousPayable.
//
Procedure ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableMiscellaneousPayable = AdditionalProperties.TableForRegisterRecords.TableMiscellaneousPayable;
	
	If Cancel
	 Or TableMiscellaneousPayable.Count() = 0 Then
		Return;
	EndIf;
	
	MiscellaneousPayableRegistering = RegisterRecords.MiscellaneousPayable;
	MiscellaneousPayableRegistering.Write = True;
	MiscellaneousPayableRegistering.Load(TableMiscellaneousPayable);
	
EndProcedure

// Generates records of the LoanSettlements accumulation register.
//
Procedure ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableLoanSettlements = AdditionalProperties.TableForRegisterRecords.TableLoanSettlements;
	
	If Cancel
	 Or TableLoanSettlements.Count() = 0 Then
		Return;
	EndIf;
	
	RecordsLoanSettlements = RegisterRecords.LoanSettlements;
	RecordsLoanSettlements.Write = True;
	RecordsLoanSettlements.Load(TableLoanSettlements);
	
EndProcedure

// Generates records of the LoanRepaymentSchedule information register.
//
Procedure RecordLoanRepaymentSchedule(AdditionalProperties, Records, Cancel) Export
	
	TableLoanRepaymentSchedule = AdditionalProperties.TableForRegisterRecords.TableLoanRepaymentSchedule;
	
	If Cancel
	 Or TableLoanRepaymentSchedule.Count() = 0 Then
		Return;
	EndIf;
	
	RecordsLoanRepaymentSchedule = Records.LoanRepaymentSchedule;
	RecordsLoanRepaymentSchedule.Write = True;
	RecordsLoanRepaymentSchedule.Load(TableLoanRepaymentSchedule);
	
EndProcedure

Function GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(TempTablesManager, QueryNumber) Export
	
	QueryNumber = 2;
	
	QueryText =
	"SELECT ALLOWED
	|	AcccountsBalances.Company AS Company,
	|	AcccountsBalances.PresentationCurrency AS PresentationCurrency,
	|	AcccountsBalances.Counterparty AS Counterparty,
	|	AcccountsBalances.Contract AS Contract,
	|	SUM(AcccountsBalances.AmountBalance) AS AmountBalance,
	|	SUM(AcccountsBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|		TemporaryTable.Counterparty AS Counterparty,
	|		TemporaryTable.Contract AS Contract,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableOtherSettlements AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.PresentationCurrency,
	|		TableBalances.Counterparty,
	|		TableBalances.Contract,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.MiscellaneousPayable.Balance(
	|				&PointInTime,
	|				(Company, PresentationCurrency, Counterparty, Contract) IN
	|					(SELECT DISTINCT
	|						TemporaryTableOtherSettlements.Company,
	|						TemporaryTableOtherSettlements.PresentationCurrency,
	|						TemporaryTableOtherSettlements.Counterparty,
	|						TemporaryTableOtherSettlements.Contract
	|					FROM
	|						TemporaryTableOtherSettlements)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.PresentationCurrency,
	|		DocumentRegisterRecords.Counterparty,
	|		DocumentRegisterRecords.Contract,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.MiscellaneousPayable AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AcccountsBalances
	|
	|GROUP BY
	|	AcccountsBalances.Company,
	|	AcccountsBalances.PresentationCurrency,
	|	AcccountsBalances.Counterparty,
	|	AcccountsBalances.Contract
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableAccounts.Company AS Company,
	|	TableAccounts.PresentationCurrency AS PresentationCurrency,
	|	TableAccounts.Counterparty AS Counterparty,
	|	TableAccounts.Contract AS Contract,
	|	TableAccounts.GLAccount AS GLAccount,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition / (ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition / (ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition)
	|	END - ISNULL(TableBalances.AmountBalance, 0) AS ExchangeRateDifferenceAmount,
	|	TableAccounts.Currency AS Currency
	|INTO ExchangeDifferencesTemporaryTableOtherSettlements
	|FROM
	|	TemporaryTableOtherSettlements AS TableAccounts
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableAccounts.Company = TableBalances.Company
	|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
	|			AND TableAccounts.Counterparty = TableBalances.Counterparty
	|			AND TableAccounts.Contract = TableBalances.Contract
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS ExchangeRateSliceLast
	|		ON TableAccounts.Company = ExchangeRateSliceLast.Company
	|			AND TableAccounts.PresentationCurrency = ExchangeRateSliceLast.Currency
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT DISTINCT
	|						TemporaryTableOtherSettlements.Currency
	|					FROM
	|						TemporaryTableOtherSettlements)) AS ExchangeRateAccountsSliceLast
	|		ON TableAccounts.Contract.SettlementsCurrency = ExchangeRateAccountsSliceLast.Currency
	|			AND TableAccounts.Company = ExchangeRateAccountsSliceLast.Company
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition / (ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition / (ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition)
	|	END - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition / (ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRateAccountsSliceLast.Rate * ExchangeRateSliceLast.Repetition / (ExchangeRateSliceLast.Rate * ExchangeRateAccountsSliceLast.Repetition)
	|	END - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Currency AS Currency,
	|	DocumentTable.PostingContent AS PostingContent,
	|	DocumentTable.Comment AS Comment
	|FROM
	|	TemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	0,
	|	DocumentTable.Currency,
	|	&ExchangeRateDifference,
	|	""""
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
		
	Return QueryText;
	
EndFunction

// Function returns query text to calculate exchange rate differences.
//
Function GetQueryTextExchangeRateDifferencesLoanSettlements(TemporaryTableManager, QueryNumber, IsBusinessUnit = False) Export
	
	CalculateExchangeRateDifferences = GetNeedToCalculateExchangeDifferences(TemporaryTableManager, "TemporaryTableLoanSettlements");
	
	If CalculateExchangeRateDifferences Then
		
		QueryNumber = 3;
		
		QueryText = 
		"SELECT ALLOWED
		|	SettlementsBalance.LoanKind AS LoanKind,
		|	SettlementsBalance.Counterparty AS Counterparty,
		|	SettlementsBalance.Company AS Company,
		|	SettlementsBalance.PresentationCurrency AS PresentationCurrency,
		|	SettlementsBalance.LoanContract AS LoanContract,
		|	SUM(SettlementsBalance.PrincipalDebtBalance) AS PrincipalDebtBalance,
		|	SUM(SettlementsBalance.PrincipalDebtCurBalance) AS PrincipalDebtCurBalance,
		|	SUM(SettlementsBalance.InterestBalance) AS InterestBalance,
		|	SUM(SettlementsBalance.InterestCurBalance) AS InterestCurBalance,
		|	SUM(SettlementsBalance.CommissionBalance) AS CommissionBalance,
		|	SUM(SettlementsBalance.CommissionCurBalance) AS CommissionCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.LoanKind AS LoanKind,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.LoanContract AS LoanContract,
		|		TemporaryTable.PrincipalDebtForBalance AS PrincipalDebtBalance,
		|		TemporaryTable.PrincipalDebtCurForBalance AS PrincipalDebtCurBalance,
		|		TemporaryTable.InterestForBalance AS InterestBalance,
		|		TemporaryTable.InterestCurForBalance AS InterestCurBalance,
		|		TemporaryTable.CommissionForBalance AS CommissionBalance,
		|		TemporaryTable.CommissionCurForBalance AS CommissionCurBalance
		|	FROM
		|		TemporaryTableLoanSettlements AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalance.LoanKind,
		|		TableBalance.Counterparty,
		|		TableBalance.Company,
		|		TableBalance.PresentationCurrency,
		|		TableBalance.LoanContract,
		|		ISNULL(TableBalance.PrincipalDebtBalance, 0),
		|		ISNULL(TableBalance.PrincipalDebtCurBalance, 0),
		|		ISNULL(TableBalance.InterestBalance, 0),
		|		ISNULL(TableBalance.InterestCurBalance, 0),
		|		ISNULL(TableBalance.CommissionBalance, 0),
		|		ISNULL(TableBalance.CommissionCurBalance, 0)
		|	FROM
		|		AccumulationRegister.LoanSettlements.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Counterparty, LoanContract, LoanKind) IN
		|					(SELECT DISTINCT
		|						TemporaryTableLoanSettlements.Company,
		|						TemporaryTableLoanSettlements.PresentationCurrency,
		|						TemporaryTableLoanSettlements.Counterparty,
		|						TemporaryTableLoanSettlements.LoanContract,
		|						TemporaryTableLoanSettlements.LoanKind
		|					FROM
		|						TemporaryTableLoanSettlements)) AS TableBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRecords.LoanKind,
		|		DocumentRecords.Counterparty,
		|		DocumentRecords.Company,
		|		DocumentRecords.PresentationCurrency,
		|		DocumentRecords.LoanContract,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.PrincipalDebt, 0)
		|			ELSE ISNULL(DocumentRecords.PrincipalDebt, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.PrincipalDebtCur, 0)
		|			ELSE ISNULL(DocumentRecords.PrincipalDebtCur, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.Interest, 0)
		|			ELSE ISNULL(DocumentRecords.Interest, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.InterestCur, 0)
		|			ELSE ISNULL(DocumentRecords.InterestCur, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.Commission, 0)
		|			ELSE ISNULL(DocumentRecords.Commission, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.CommissionCur, 0)
		|			ELSE ISNULL(DocumentRecords.CommissionCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.LoanSettlements AS DocumentRecords
		|	WHERE
		|		DocumentRecords.Recorder = &Ref
		|		AND DocumentRecords.Period <= &ControlPeriod) AS SettlementsBalance
		|
		|GROUP BY
		|	SettlementsBalance.Company,
		|	SettlementsBalance.PresentationCurrency,
		|	SettlementsBalance.Counterparty,
		|	SettlementsBalance.LoanKind,
		|	SettlementsBalance.LoanContract
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Counterparty,
		|	LoanKind,
		|	LoanContract
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableSettlements.Company AS Company,
		|	TableSettlements.PresentationCurrency AS PresentationCurrency,
		|	TableSettlements.Counterparty AS Counterparty,
		|	TableSettlements.LoanKind AS LoanKind,
		|	TableSettlements.Currency AS Currency,
		|	CAST(TableSettlements.LoanContract AS Document.LoanContract) AS LoanContract,
		|	TableSettlements.GLAccount AS GLAccount,
		|	ISNULL(TableBalance.PrincipalDebtCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition / (SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition / (AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition)
		|	END - ISNULL(TableBalance.PrincipalDebtBalance, 0) AS ExchangeRateDifferenceAmountPrincipalDebt,
		|	ISNULL(TableBalance.InterestCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition / (SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition / (AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition)
		|	END - ISNULL(TableBalance.InterestBalance, 0) AS ExchangeRateDifferenceAmountInterest,
		|	ISNULL(TableBalance.CommissionCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition / (SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN SettlementExchangeRateLastSlice.Rate * AccountingExchangeRateLastSlice.Repetition / (AccountingExchangeRateLastSlice.Rate * SettlementExchangeRateLastSlice.Repetition)
		|	END - ISNULL(TableBalance.CommissionBalance, 0) AS ExchangeRateDifferenceAmountCommission
		|INTO TemporaryTableOfExchangeRateDifferences
		|FROM
		|	TemporaryTableLoanSettlements AS TableSettlements
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalance
		|		ON TableSettlements.Company = TableBalance.Company
		|			AND TableSettlements.Counterparty = TableBalance.Counterparty
		|			AND TableSettlements.LoanKind = TableBalance.LoanKind
		|			AND TableSettlements.LoanContract = TableBalance.LoanContract
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateLastSlice
		|		ON TableSettlements.Company = AccountingExchangeRateLastSlice.Company
		|			AND TableSettlements.PresentationCurrency = AccountingExchangeRateLastSlice.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency = &PresentationCurrency) AS SettlementExchangeRateLastSlice
		|		ON TableSettlements.LoanContract.SettlementsCurrency = SettlementExchangeRateLastSlice.Currency
		|			AND TableSettlements.Company = SettlementExchangeRateLastSlice.Company
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber AS LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date AS Date,
		|	TemporaryTableOfExchangeRateDifferences.Company AS Company,
		|	TemporaryTableOfExchangeRateDifferences.PresentationCurrency AS PresentationCurrency,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty AS Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind AS LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency AS Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract AS LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount AS GLAccount,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt AS ExchangeRateDifferenceAmountPrincipalDebt,
		|	0 AS ExchangeRateDifferenceAmountInterest,
		|	0 AS ExchangeRateDifferenceAmountCommission,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt AS ExchangeRateDifferenceAmount
		|INTO TemporaryTableExchangeRateDifferencesLoanSettlements
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt <= -0.005)
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date,
		|	TemporaryTableOfExchangeRateDifferences.Company,
		|	TemporaryTableOfExchangeRateDifferences.PresentationCurrency,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest <= -0.005)
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date,
		|	TemporaryTableOfExchangeRateDifferences.Company,
		|	TemporaryTableOfExchangeRateDifferences.PresentationCurrency,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount,
		|	0,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order1,
		|	1 AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.LoanContract AS LoanContract,
		|	DocumentTable.LoanKind AS LoanKind,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.LoanContract.SettlementsCurrency AS Currency,
		|	DocumentTable.PrincipalDebt AS PrincipalDebt,
		|	DocumentTable.PrincipalDebtCur AS PrincipalDebtCur,
		|	DocumentTable.Interest AS Interest,
		|	DocumentTable.InterestCur AS InterestCur,
		|	DocumentTable.Commission AS Commission,
		|	DocumentTable.CommissionCur AS CommissionCur,
		|	DocumentTable.PrincipalDebt + DocumentTable.Interest + DocumentTable.Commission AS Amount,
		|	DocumentTable.PrincipalDebtCur + DocumentTable.InterestCur + DocumentTable.CommissionCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	CAST(DocumentTable.PostingContent AS STRING(100)) AS PostingContent,
		|	DocumentTable.DeductedFromSalary AS DeductedFromSalary,
		|	"""" AS BusinessUnit
		|FROM
		|	TemporaryTableLoanSettlements AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	1,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|				OR DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|				OR DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.LoanContract,
		|	DocumentTable.LoanKind,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.LoanContract.SettlementsCurrency,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountInterest
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountInterest
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountCommission
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountCommission
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|	END + CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountInterest
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountInterest
		|	END + CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountCommission
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountCommission
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeRateDifference,
		|	FALSE,
		|	UNDEFINED
		|FROM
		|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
		|
		|ORDER BY
		|	Order1,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText = 
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableSettlements.Company AS Company,
		|	TableSettlements.PresentationCurrency AS PresentationCurrency,
		|	TableSettlements.Counterparty AS Counterparty,
		|	TableSettlements.LoanKind AS LoanKind,
		|	TableSettlements.LoanContract AS LoanContract,
		|	0 AS ExchangeRateDifferenceAmount,
		|	TableSettlements.Currency AS Currency,
		|	TableSettlements.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesLoanSettlements
		|FROM
		|	TemporaryTableLoanSettlements AS TableSettlements
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order1,
		|	1 AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.LoanContract AS LoanContract,
		|	DocumentTable.LoanKind AS LoanKind,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.PrincipalDebt AS PrincipalDebt,
		|	DocumentTable.PrincipalDebtCur AS PrincipalDebtCur,
		|	DocumentTable.Interest AS Interest,
		|	DocumentTable.InterestCur AS InterestCur,
		|	DocumentTable.Commission AS Commission,
		|	DocumentTable.CommissionCur AS CommissionCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.PostingContent AS PostingContent,
		|	DocumentTable.DeductedFromSalary AS DeductedFromSalary,
		|	DocumentTable.PrincipalDebtCur + DocumentTable.InterestCur + DocumentTable.CommissionCur AS AmountCur,
		|	DocumentTable.PrincipalDebt + DocumentTable.Interest + DocumentTable.Commission AS Amount,
		|	"""" AS BusinessArea
		|FROM
		|	TemporaryTableLoanSettlements AS DocumentTable
		|
		|ORDER BY
		|	Order1,
		|	LineNumber";
		
	EndIf;
	
	If IsBusinessUnit
		Then QueryText = StrReplace(QueryText, """"" AS BusinessUnit", "DocumentTable.BusinessUnit AS BusinessUnit");
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

// Moves accumulation register CashAssets.
//
Procedure ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashAssets = AdditionalProperties.TableForRegisterRecords.TableCashAssets;
	
	If Cancel
	 Or TableCashAssets.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCashAssets = RegisterRecords.CashAssets;
	RegisterRecordsCashAssets.Write = True;
	RegisterRecordsCashAssets.Load(TableCashAssets);
	
EndProcedure

Procedure ReflectBankReconciliation(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableBankReconciliation = AdditionalProperties.TableForRegisterRecords.TableBankReconciliation;
	
	If Cancel
		Or TableBankReconciliation.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsBankReconciliation = RegisterRecords.BankReconciliation;
	RegisterRecordsBankReconciliation.Write = True;
	RegisterRecordsBankReconciliation.Load(TableBankReconciliation);
	
EndProcedure

// Moves accumulation register AdvanceHoldersPayments.
//
Procedure ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAdvanceHolders = AdditionalProperties.TableForRegisterRecords.TableAdvanceHolders;
	
	If Cancel
	 Or TableAdvanceHolders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsAdvanceHolders = RegisterRecords.AdvanceHolders;
	RegisterRecordsAdvanceHolders.Write = True;
	RegisterRecordsAdvanceHolders.Load(TableAdvanceHolders);
	
EndProcedure

// Moves accumulation register CounterpartiesSettlements.
//
Procedure ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountsReceivable = AdditionalProperties.TableForRegisterRecords.TableAccountsReceivable;
	
	If Cancel
	 Or TableAccountsReceivable.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsAccountsReceivable = RegisterRecords.AccountsReceivable;
	RegisterRecordsAccountsReceivable.Write = True;
	RegisterRecordsAccountsReceivable.Load(TableAccountsReceivable);
	
EndProcedure

// Moves accumulation register ThirdPartyPayments.
//
Procedure ReflectThirdPartyPayments(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableThirdPartyPayments = AdditionalProperties.TableForRegisterRecords.TableThirdPartyPayments;
	
	If Cancel
		Or TableThirdPartyPayments.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsThirdPartyPayments = RegisterRecords.ThirdPartyPayments;
	RegisterRecordsThirdPartyPayments.Write = True;
	RegisterRecordsThirdPartyPayments.Load(TableThirdPartyPayments);
	
EndProcedure

// Moves accumulation register CounterpartiesSettlements.
//
Procedure ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountsPayable = AdditionalProperties.TableForRegisterRecords.TableAccountsPayable;
	
	If Cancel
	 Or TableAccountsPayable.Count() = 0 Then
		Return;
	EndIf;
	
	VendorsPaymentsRegistration = RegisterRecords.AccountsPayable;
	VendorsPaymentsRegistration.Write = True;
	VendorsPaymentsRegistration.Load(TableAccountsPayable);
	
EndProcedure

// Moves accumulation register Payment schedule.
//
// Parameters:
//  DocumentObject - Current
//  document Denial - Boolean - Check box of canceling document posting.
//
Procedure ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePaymentCalendar = AdditionalProperties.TableForRegisterRecords.TablePaymentCalendar;
	
	If Cancel
	 Or TablePaymentCalendar.Count() = 0 Then
		Return;
	EndIf;
	
	PaymentCalendarRegistration = RegisterRecords.PaymentCalendar;
	PaymentCalendarRegistration.Write = True;
	PaymentCalendarRegistration.Load(TablePaymentCalendar);
	
EndProcedure

// Moves accumulation register Accounts payment.
//
// Parameters:
//  DocumentObject - Current
//  document Denial - Boolean - Check box of canceling document posting.
//
Procedure ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInvoicesAndOrdersPayment = AdditionalProperties.TableForRegisterRecords.TableInvoicesAndOrdersPayment;
	
	If Cancel
	 Or TableInvoicesAndOrdersPayment.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsInvoicesAndOrdersPayment = RegisterRecords.InvoicesAndOrdersPayment;
	RegisterRecordsInvoicesAndOrdersPayment.Write = True;
	RegisterRecordsInvoicesAndOrdersPayment.Load(TableInvoicesAndOrdersPayment);
	
EndProcedure

// Procedure moves IncomingsAndExpensesPettyCashMethodaccumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesCashMethod = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesCashMethod;
	
	If Cancel
	 Or TableIncomeAndExpensesCashMethod.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpensesCashMethod = RegisterRecords.IncomeAndExpensesCashMethod;
	IncomeAndExpensesCashMethod.Write = True;
	IncomeAndExpensesCashMethod.Load(TableIncomeAndExpensesCashMethod);
	
EndProcedure

// Procedure moves the UnallocatedExpenses accumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableUnallocatedExpenses = AdditionalProperties.TableForRegisterRecords.TableUnallocatedExpenses;
	
	If Cancel
	 Or TableUnallocatedExpenses.Count() = 0 Then
		Return;
	EndIf;
	
	UnallocatedExpenses = RegisterRecords.UnallocatedExpenses;
	UnallocatedExpenses.Write = True;
	UnallocatedExpenses.Load(TableUnallocatedExpenses);
	
EndProcedure

// Procedure moves IncomeAndExpensesDelayed accumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesRetained = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesRetained;
	
	If Cancel
	 Or TableIncomeAndExpensesRetained.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpensesRetained = RegisterRecords.IncomeAndExpensesRetained;
	IncomeAndExpensesRetained.Write = True;
	IncomeAndExpensesRetained.Load(TableIncomeAndExpensesRetained);
	
EndProcedure

// Moves accumulation register DeductionsAndEarning.
//
Procedure ReflectEarningsAndDeductions(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableEarningsAndDeductions = AdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions;
	
	If Cancel
	 Or TableEarningsAndDeductions.Count() = 0 Then
		Return;
	EndIf;
	
	RegistrationEarningsAndDeductions = RegisterRecords.EarningsAndDeductions;
	RegistrationEarningsAndDeductions.Write = True;
	RegistrationEarningsAndDeductions.Load(TableEarningsAndDeductions);
	
EndProcedure

// Moves accumulation register Payroll.
//
Procedure ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePayroll = AdditionalProperties.TableForRegisterRecords.TablePayroll;
	
	If Cancel
	 Or TablePayroll.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPayroll = RegisterRecords.Payroll;
	RegisterRecordsPayroll.Write = True;
	RegisterRecordsPayroll.Load(TablePayroll);
	
EndProcedure

// Moves information register PlannedEarningsAndDeductions.
//
Procedure ReflectCompensationPlan(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCompensationPlan = AdditionalProperties.TableForRegisterRecords.TableCompensationPlan;
	
	If Cancel
	 Or TableCompensationPlan.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPlannedEarningsAndDeductions = RegisterRecords.CompensationPlan;
	RegisterRecordsPlannedEarningsAndDeductions.Write = True;
	RegisterRecordsPlannedEarningsAndDeductions.Load(TableCompensationPlan);
	
EndProcedure

// Moves information register Employees.
//
Procedure ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableEmployees = AdditionalProperties.TableForRegisterRecords.TableEmployees;
	
	If Cancel
	 Or TableEmployees.Count() = 0 Then
		Return;
	EndIf;
	
	EmployeeRecords = RegisterRecords.Employees;
	EmployeeRecords.Write = True;
	EmployeeRecords.Load(TableEmployees);
	
EndProcedure

// Moves information register WriteOffCostAdjustment.
//
Procedure ReflectWriteOffCostAdjustment(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWriteOffCostAdjustment = AdditionalProperties.TableForRegisterRecords.TableWriteOffCostAdjustment;
	
	If Cancel
		Or TableWriteOffCostAdjustment.Count() = 0 Then
		Return;
	EndIf;
	
	EmployeeRecords = RegisterRecords.WriteOffCostAdjustment;
	EmployeeRecords.Write = True;
	EmployeeRecords.Load(TableWriteOffCostAdjustment);
	
EndProcedure

// Moves accumulation register Time sheet.
//
Procedure ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableTimesheet = AdditionalProperties.TableForRegisterRecords.TableTimesheet;
	
	If Cancel
	 Or TableTimesheet.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterTimesheet = RegisterRecords.Timesheet;
	RegisterTimesheet.Write = True;
	RegisterTimesheet.Load(TableTimesheet);
	
EndProcedure

// Returns empty value table
Function EmptyIncomeAndExpensesTable() Export
	
	Query = New Query("SELECT ALLOWED TOP 0
	|	IncomeAndExpenses.Period AS Period,
	|	IncomeAndExpenses.Recorder AS Recorder,
	|	IncomeAndExpenses.LineNumber AS LineNumber,
	|	IncomeAndExpenses.Active AS Active,
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.PresentationCurrency AS PresentationCurrency,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	IncomeAndExpenses.SalesOrder AS SalesOrder,
	|	IncomeAndExpenses.IncomeAndExpenseItem AS IncomeAndExpenseItem,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	IncomeAndExpenses.AmountIncome AS AmountIncome,
	|	IncomeAndExpenses.AmountExpense AS AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	IncomeAndExpenses.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses");
	
	Return Query.Execute().Unload();
	
EndFunction

// Returns empty value table
//
Function EmptyReservedProductsTable() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 0
	|	ReservedProducts.Period AS Period,
	|	ReservedProducts.Recorder AS Recorder,
	|	ReservedProducts.LineNumber AS LineNumber,
	|	ReservedProducts.Active AS Active,
	|	ReservedProducts.RecordType AS RecordType,
	|	ReservedProducts.Company AS Company,
	|	ReservedProducts.StructuralUnit AS StructuralUnit,
	|	ReservedProducts.Products AS Products,
	|	ReservedProducts.Characteristic AS Characteristic,
	|	ReservedProducts.Batch AS Batch,
	|	ReservedProducts.SalesOrder AS SalesOrder,
	|	ReservedProducts.Quantity AS Quantity,
	|	ReservedProducts.GLAccount AS GLAccount
	|FROM
	|	AccumulationRegister.ReservedProducts AS ReservedProducts";
	
	Return Query.Execute().Unload();
	
EndFunction

// Moves accumulation register IncomingsAndExpenses.
//
Procedure ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpenses = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	If Cancel
	 Or TableIncomeAndExpenses.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpencesRegistering = RegisterRecords.IncomeAndExpenses;
	IncomeAndExpencesRegistering.Write = True;
	IncomeAndExpencesRegistering.Load(TableIncomeAndExpenses);
	
EndProcedure

// Moves accumulation register AmountAccountingInRetail.
//
Procedure ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePOSSummary = AdditionalProperties.TableForRegisterRecords.TablePOSSummary;
	
	If Cancel
	 Or TablePOSSummary.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPOSSummary = RegisterRecords.POSSummary;
	RegisterRecordsPOSSummary.Write = True;
	RegisterRecordsPOSSummary.Load(TablePOSSummary);
	
EndProcedure

// Moves accumulation register CalculationsOnTaxes.
//
Procedure ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableTaxPayable = AdditionalProperties.TableForRegisterRecords.TableTaxPayable;
	
	If Cancel
	 Or TableTaxPayable.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterTaxPayable = RegisterRecords.TaxPayable;
	RegisterTaxPayable.Write = True;
	RegisterTaxPayable.Load(TableTaxPayable);
	
EndProcedure

// Moves accumulation register InventoryOnWarehouses.
//
Procedure ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryInWarehouses = AdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses;
	
	If Cancel
	 Or TableInventoryInWarehouses.Count() = 0 Then
		Return;
	EndIf;
	
	WarehouseInventoryRegistering = RegisterRecords.InventoryInWarehouses;
	WarehouseInventoryRegistering.Write = True;
	WarehouseInventoryRegistering.Load(TableInventoryInWarehouses);
	
EndProcedure

Procedure ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsAwaitingCustomsClearance = AdditionalProperties.TableForRegisterRecords.TableGoodsAwaitingCustomsClearance;
	
	If Cancel
	 Or TableGoodsAwaitingCustomsClearance.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsAwaitingCustomsClearance = RegisterRecords.GoodsAwaitingCustomsClearance;
	RegisterRecordsGoodsAwaitingCustomsClearance.Write = True;
	RegisterRecordsGoodsAwaitingCustomsClearance.Load(TableGoodsAwaitingCustomsClearance);
	
EndProcedure

// Moves accumulation register CashAssetsInCRRReceipt.
//
Procedure ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashInCashRegisters = AdditionalProperties.TableForRegisterRecords.TableCashInCashRegisters;
	
	If Cancel
	 Or TableCashInCashRegisters.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCashInCashRegisters = RegisterRecords.CashInCashRegisters;
	RegisterRecordsCashInCashRegisters.Write = True;
	RegisterRecordsCashInCashRegisters.Load(TableCashInCashRegisters);
	
EndProcedure

// Moves accumulation register Inventory.
//
Procedure ReflectInventory(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventory = AdditionalProperties.TableForRegisterRecords.TableInventory;
	
	If Cancel
	 Or TableInventory.Count() = 0 Then
		Return;
	EndIf;
	
	InventoryRecords = RegisterRecords.Inventory;
	InventoryRecords.Write = True;
	InventoryRecords.Load(TableInventory);
	
EndProcedure

Procedure ReflectWorkInProgress(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkInProgress = AdditionalProperties.TableForRegisterRecords.TableWorkInProgress;
	
	If Cancel
		Or TableWorkInProgress.Count() = 0 Then
		Return;
	EndIf;
	
	WorkInProgressRecords = RegisterRecords.WorkInProgress;
	WorkInProgressRecords.Write = True;
	WorkInProgressRecords.Load(TableWorkInProgress);
	
EndProcedure

// Moves accumulation register ReservedProducts.
//
Procedure ReflectReservedProducts(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableReservedProducts = AdditionalProperties.TableForRegisterRecords.TableReservedProducts;
	
	If Cancel Or TableReservedProducts.Count() = 0 Then
		Return;
	EndIf;
	
	ReservedProductsRecords = RegisterRecords.ReservedProducts;
	ReservedProductsRecords.Write = True;
	ReservedProductsRecords.Load(TableReservedProducts)
	
EndProcedure

// Moves on the register Sales targets.
//
Procedure ReflectSalesTarget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSalesTarget = AdditionalProperties.TableForRegisterRecords.TableSalesTarget;
	
	If Cancel
	 Or TableSalesTarget.Count() = 0 Then
		Return;
	EndIf;
	
	SalesTargetRecords = RegisterRecords.SalesTarget;
	SalesTargetRecords.Write = True;
	SalesTargetRecords.Load(TableSalesTarget);
	
EndProcedure

// Moves on the register CashBudget.
//
Procedure ReflectCashBudget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashBudget = AdditionalProperties.TableForRegisterRecords.TableCashBudget;
	
	If Cancel
	 Or TableCashBudget.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsBudgetCashBudget = RegisterRecords.CashBudget;
	RegisterRecordsBudgetCashBudget.Write = True;
	RegisterRecordsBudgetCashBudget.Load(TableCashBudget);
	
EndProcedure

// Moves accumulation register IncomeAndExpensesBudget.
//
Procedure ReflectIncomeAndExpensesBudget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesBudget = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesBudget;
	
	If Cancel
	 Or TableIncomeAndExpensesBudget.Count() = 0 Then
		Return;
	EndIf;
	
	RegesteringIncomeAndExpencesForecast = RegisterRecords.IncomeAndExpensesBudget;
	RegesteringIncomeAndExpencesForecast.Write = True;
	RegesteringIncomeAndExpencesForecast.Load(TableIncomeAndExpensesBudget);
	
EndProcedure

// Moves on the register FinancialResultForecast.
//
Procedure ReflectFinancialResultForecast(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFinancialResultForecast = AdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast;
	
	If Cancel
	 Or TableFinancialResultForecast.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFinancialResultForecast = RegisterRecords.FinancialResultForecast;
	RegisterRecordsFinancialResultForecast.Write = True;
	RegisterRecordsFinancialResultForecast.Load(TableFinancialResultForecast);
	
EndProcedure

// Moves on the register FinancialResult.
//
Procedure ReflectFinancialResult(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFinancialResult = AdditionalProperties.TableForRegisterRecords.TableFinancialResult;
	
	If Cancel
		Or TableFinancialResult.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFinancialResult = RegisterRecords.FinancialResult;
	RegisterRecordsFinancialResult.Write = True;
	RegisterRecordsFinancialResult.Load(TableFinancialResult);
	
EndProcedure

// Moves on the register Purchases.
//
Procedure ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePurchases = AdditionalProperties.TableForRegisterRecords.TablePurchases;
	
	If Cancel
	 Or TablePurchases.Count() = 0 Then
		Return;
	EndIf;
	
	If Not RegisterRecords.Purchases.AdditionalProperties.Property("AllowEmptyRecords") Then
		
		RegisterRecords.Purchases.AdditionalProperties.Insert("AllowEmptyRecords", AdditionalProperties.ForPosting.AllowEmptyRecords);
		
	EndIf;
			
	PurchaseRecord = RegisterRecords.Purchases;
	PurchaseRecord.Write = True;
	PurchaseRecord.Load(TablePurchases);
	
EndProcedure

// Moves on the register CostOfSubcontractorGoods.
//
Procedure ReflectCostOfSubcontractorGoods(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCostOfSubcontractorGoods = AdditionalProperties.TableForRegisterRecords.TableCostOfSubcontractorGoods;
	
	If Cancel
		Or TableCostOfSubcontractorGoods.Count() = 0 Then
		Return;
	EndIf;
	
	CostOfSubcontractorGoodsRecord = RegisterRecords.CostOfSubcontractorGoods;
	CostOfSubcontractorGoodsRecord.Write = True;
	CostOfSubcontractorGoodsRecord.Load(TableCostOfSubcontractorGoods);
	
EndProcedure

// Moves on the register StockTransferredToThirdParties.
//
Procedure ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableStockTransferredToThirdParties = AdditionalProperties.TableForRegisterRecords.TableStockTransferredToThirdParties;
	
	If Cancel
	 Or TableStockTransferredToThirdParties.Count() = 0 Then
		Return;
	EndIf;
	
	StockTransferredToThirdPartiesRegestering = RegisterRecords.StockTransferredToThirdParties;
	StockTransferredToThirdPartiesRegestering.Write = True;
	StockTransferredToThirdPartiesRegestering.Load(TableStockTransferredToThirdParties);
	
EndProcedure

// Moves on the register Inventory received.
//
Procedure ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableStockReceivedFromThirdParties = AdditionalProperties.TableForRegisterRecords.TableStockReceivedFromThirdParties;
	
	If Cancel
	 Or TableStockReceivedFromThirdParties.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsStockReceivedFromThirdParties = RegisterRecords.StockReceivedFromThirdParties;
	RegisterRecordsStockReceivedFromThirdParties.Write = True;
	RegisterRecordsStockReceivedFromThirdParties.Load(TableStockReceivedFromThirdParties);
	
EndProcedure

// Moves on the register Goods consumed to declare.
//
Procedure ReflectGoodsConsumedToDeclare(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsConsumedToDeclare = AdditionalProperties.TableForRegisterRecords.TableGoodsConsumedToDeclare;
	
	If Cancel
	 Or TableGoodsConsumedToDeclare.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsStockGoodsConsumedToDeclare = RegisterRecords.GoodsConsumedToDeclare;
	RegisterRecordsStockGoodsConsumedToDeclare.Write = True;
	RegisterRecordsStockGoodsConsumedToDeclare.Load(TableGoodsConsumedToDeclare);
	
EndProcedure

// Moves on register Orders placement.
//
Procedure ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableBackorders = AdditionalProperties.TableForRegisterRecords.TableBackorders;
	
	If Cancel
	 Or TableBackorders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsBackorders = RegisterRecords.Backorders;
	RegisterRecordsBackorders.Write = True;
	RegisterRecordsBackorders.Load(TableBackorders);
	
EndProcedure

// Moves on the register Sales.
//
Procedure ReflectSales(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSales = AdditionalProperties.TableForRegisterRecords.TableSales;
	
	If Cancel
	 Or TableSales.Count() = 0 Then
		Return;
	EndIf;
	
	If Not RegisterRecords.Sales.AdditionalProperties.Property("AllowEmptyRecords") Then
		
		RegisterRecords.Sales.AdditionalProperties.Insert("AllowEmptyRecords", AdditionalProperties.ForPosting.AllowEmptyRecords);
		
	EndIf;
	
	SalesRecord = RegisterRecords.Sales;
	SalesRecord.Write = True;
	SalesRecord.Load(TableSales);
	
EndProcedure

Procedure ReflectActualSalesVolume(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableActualSalesVolume = AdditionalProperties.TableForRegisterRecords.TableActualSalesVolume;
	
	If Cancel
		Or TableActualSalesVolume.Count() = 0 Then
		Return;
	EndIf;
	
	ActualSalesVolumeRecord = RegisterRecords.ActualSalesVolume;
	ActualSalesVolumeRecord.Write = True;
	ActualSalesVolumeRecord.Load(TableActualSalesVolume);
	
EndProcedure

// Moves on the register Sales orders.
//
Procedure ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSalesOrders = AdditionalProperties.TableForRegisterRecords.TableSalesOrders;
	
	If Cancel
	 Or TableSalesOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSalesOrders = RegisterRecords.SalesOrders;
	RegisterRecordsSalesOrders.Write = True;
	RegisterRecordsSalesOrders.Load(TableSalesOrders);
	
EndProcedure

// Moves on the register Work orders.
//
Procedure ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkOrders = AdditionalProperties.TableForRegisterRecords.TableWorkOrders;
	
	If Cancel
	 Or TableWorkOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsWorkOrders = RegisterRecords.WorkOrders;
	RegisterRecordsWorkOrders.Write = True;
	RegisterRecordsWorkOrders.Load(TableWorkOrders);
	
EndProcedure

// Moves on the register Transfer orders.
//
Procedure ReflectTransferOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableTransferOrders = AdditionalProperties.TableForRegisterRecords.TableTransferOrders;
	
	If Cancel
	 Or TableTransferOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsTransferOrders = RegisterRecords.TransferOrders;
	RegisterRecordsTransferOrders.Write = True;
	RegisterRecordsTransferOrders.Load(TableTransferOrders);
	
EndProcedure

Procedure ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsShippedNotInvoiced = AdditionalProperties.TableForRegisterRecords.TableGoodsShippedNotInvoiced;
	
	If Cancel
	 Or TableGoodsShippedNotInvoiced.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsShippedNotInvoiced = RegisterRecords.GoodsShippedNotInvoiced;
	RegisterRecordsGoodsShippedNotInvoiced.Write = True;
	RegisterRecordsGoodsShippedNotInvoiced.Load(TableGoodsShippedNotInvoiced);
	
EndProcedure

Procedure ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsInvoicedNotShipped = AdditionalProperties.TableForRegisterRecords.TableGoodsInvoicedNotShipped;
	
	If Cancel
	 Or TableGoodsInvoicedNotShipped.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsInvoicedNotShipped = RegisterRecords.GoodsInvoicedNotShipped;
	RegisterRecordsGoodsInvoicedNotShipped.Write = True;
	RegisterRecordsGoodsInvoicedNotShipped.Load(TableGoodsInvoicedNotShipped);
	
EndProcedure

Procedure ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsReceivedNotInvoiced = AdditionalProperties.TableForRegisterRecords.TableGoodsReceivedNotInvoiced;
	
	If Cancel
	 Or TableGoodsReceivedNotInvoiced.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsReceivedNotInvoiced = RegisterRecords.GoodsReceivedNotInvoiced;
	RegisterRecordsGoodsReceivedNotInvoiced.Write = True;
	RegisterRecordsGoodsReceivedNotInvoiced.Load(TableGoodsReceivedNotInvoiced);
	
EndProcedure

Procedure ReflectGoodsInvoicedNotReceived(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsInvoicedNotReceived = AdditionalProperties.TableForRegisterRecords.TableGoodsInvoicedNotReceived;
	
	If Cancel
	 Or TableGoodsInvoicedNotReceived.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsInvoicedNotReceived = RegisterRecords.GoodsInvoicedNotReceived;
	RegisterRecordsGoodsInvoicedNotReceived.Write = True;
	RegisterRecordsGoodsInvoicedNotReceived.Load(TableGoodsInvoicedNotReceived);
	
EndProcedure

// Moves on the register InventoryFlowCalendar.
//
Procedure ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryFlowCalendar = AdditionalProperties.TableForRegisterRecords.TableInventoryFlowCalendar;
	
	If Cancel
	 Or TableInventoryFlowCalendar.Count() = 0 Then
		Return;
	EndIf;
	
	RegesteringSchedeuleInventoryMovement = RegisterRecords.InventoryFlowCalendar;
	RegesteringSchedeuleInventoryMovement.Write = True;
	RegesteringSchedeuleInventoryMovement.Load(TableInventoryFlowCalendar);
	
EndProcedure

// begin Drive.FullVersion

// Moves on the register ProductionOrders.
//
Procedure ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductionOrders = AdditionalProperties.TableForRegisterRecords.TableProductionOrders;
	
	If Cancel 
	 Or TableProductionOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsProductionOrders = RegisterRecords.ProductionOrders;
	RegisterRecordsProductionOrders.Write = True;
	RegisterRecordsProductionOrders.Load(TableProductionOrders);
	
EndProcedure

// Moves on the register Subcontractor orders received statement.
//
Procedure ReflectSubcontractorOrdersReceived(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSubcontractorOrdersReceived = AdditionalProperties.TableForRegisterRecords.TableSubcontractorOrdersReceived;
	
	If Cancel
		Or TableSubcontractorOrdersReceived.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSubcontractorOrdersReceived = RegisterRecords.SubcontractorOrdersReceived;
	RegisterRecordsSubcontractorOrdersReceived.Write = True;
	RegisterRecordsSubcontractorOrdersReceived.Load(TableSubcontractorOrdersReceived);
	
EndProcedure

// Moves accumulation register CustomerOwnedInventory.
//
Procedure ReflectCustomerOwnedInventory(AdditionalProperties, RegisterRecords, Cancel) Export

	TableCustomerOwnedInventory = AdditionalProperties.TableForRegisterRecords.TableCustomerOwnedInventory;
	
	If Cancel
	 Or TableCustomerOwnedInventory.Count() = 0 Then
		Return;
	EndIf;
	
	CustomerOwnedInventoryRecord = RegisterRecords.CustomerOwnedInventory;
	CustomerOwnedInventoryRecord.Write = True;
	CustomerOwnedInventoryRecord.Load(TableCustomerOwnedInventory);

EndProcedure

// end Drive.FullVersion

Procedure ReflectKitOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableKitOrders = AdditionalProperties.TableForRegisterRecords.TableKitOrders;
	
	If Cancel 
	 Or TableKitOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsProductionOrders = RegisterRecords.KitOrders;
	RegisterRecordsProductionOrders.Write = True;
	RegisterRecordsProductionOrders.Load(TableKitOrders);
	
EndProcedure

// Moves on the register InventoryDemand.
//
Procedure ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryDemand = AdditionalProperties.TableForRegisterRecords.TableInventoryDemand;
	
	If Cancel 
	 Or TableInventoryDemand.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsInventoryDemand = RegisterRecords.InventoryDemand;
	RegisterRecordsInventoryDemand.Write = True;
	RegisterRecordsInventoryDemand.Load(TableInventoryDemand);
	
EndProcedure

// Moves on the register Purchase orders statement.
//
Procedure ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePurchaseOrders = AdditionalProperties.TableForRegisterRecords.TablePurchaseOrders;
	
	If Cancel
	 Or TablePurchaseOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPurchaseOrders = RegisterRecords.PurchaseOrders;
	RegisterRecordsPurchaseOrders.Write = True;
	RegisterRecordsPurchaseOrders.Load(TablePurchaseOrders);
	
EndProcedure

// Moves on the register Orders by fulfillment method.
//
Procedure ReflectOrdersByFulfillmentMethod(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableOrdersByFulfillmentMethod = AdditionalProperties.TableForRegisterRecords.TableOrdersByFulfillmentMethod;
	
	If Cancel
		Or TableOrdersByFulfillmentMethod.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsOrdersByFulfillmentMethod = RegisterRecords.OrdersByFulfillmentMethod;
	RegisterRecordsOrdersByFulfillmentMethod.Write = True;
	RegisterRecordsOrdersByFulfillmentMethod.Load(TableOrdersByFulfillmentMethod);
	
EndProcedure

// Moves on the register Purchase orders statement.
//
Procedure ReflectSubcontractorOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSubcontractorOrdersIssued = AdditionalProperties.TableForRegisterRecords.TableSubcontractorOrdersIssued;
	
	If Cancel
		Or TableSubcontractorOrdersIssued.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPurchaseOrders = RegisterRecords.SubcontractorOrdersIssued;
	RegisterRecordsPurchaseOrders.Write = True;
	RegisterRecordsPurchaseOrders.Load(TableSubcontractorOrdersIssued);
	
EndProcedure

// Moves on the register Subcontract components statement.
//
Procedure ReflectSubcontractComponents(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSubcontractComponents = AdditionalProperties.TableForRegisterRecords.TableSubcontractComponents;
	
	If Cancel
		Or TableSubcontractComponents.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPurchaseOrders = RegisterRecords.SubcontractComponents;
	RegisterRecordsPurchaseOrders.Write = True;
	RegisterRecordsPurchaseOrders.Load(TableSubcontractComponents);
	
EndProcedure

// Moves on the register Purchase orders statement.
//
Procedure ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetUsage = AdditionalProperties.TableForRegisterRecords.TableFixedAssetUsage;
	
	If Cancel
	 Or TableFixedAssetUsage.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssetsProduction = RegisterRecords.FixedAssetUsage;
	RegisterRecordsFixedAssetsProduction.Write = True;
	RegisterRecordsFixedAssetsProduction.Load(TableFixedAssetUsage);
	
EndProcedure

// Moves information register FixedAssetStatus.
//
Procedure ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetStatus = AdditionalProperties.TableForRegisterRecords.TableFixedAssetStatus;
	
	If Cancel
	 Or TableFixedAssetStatus.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterFixedAssetStatus = RegisterRecords.FixedAssetStatus;
	RegisterFixedAssetStatus.Write = True;
	RegisterFixedAssetStatus.Load(TableFixedAssetStatus);
	
EndProcedure

// Moves the InitialInformationDepreciationParameters information register.
//
Procedure ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetParameters = AdditionalProperties.TableForRegisterRecords.TableFixedAssetParameters;
	
	If Cancel
	 Or TableFixedAssetParameters.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssetParameters = RegisterRecords.FixedAssetParameters;
	RegisterRecordsFixedAssetParameters.Write = True;
	RegisterRecordsFixedAssetParameters.Load(TableFixedAssetParameters);
	
EndProcedure

// Moves information register MonthClosingError.
//
Procedure ReflectMonthEndErrors(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableMonthEndErrors = AdditionalProperties.TableForRegisterRecords.TableMonthEndErrors;
	
	If Cancel
	 Or TableMonthEndErrors.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsMonthEndErrors = RegisterRecords.MonthEndErrors;
	RegisterRecordsMonthEndErrors.Write = True;
	RegisterRecordsMonthEndErrors.Load(TableMonthEndErrors);
	
EndProcedure

// Moves accumulation register CapitalAssetsDepreciation
//
Procedure ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssets = AdditionalProperties.TableForRegisterRecords.TableFixedAssets;
	
	If Cancel
	 Or TableFixedAssets.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssets = RegisterRecords.FixedAssets;
	RegisterRecordsFixedAssets.Write = True;
	RegisterRecordsFixedAssets.Load(TableFixedAssets);
	
EndProcedure

// Moves on the register EmployeeTasks.
//
Procedure ReflectEmployeeTasks(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableEmployeeTasks = AdditionalProperties.TableForRegisterRecords.TableEmployeeTasks;
	
	If Cancel
	 Or TableEmployeeTasks.Count() = 0 Then
		Return;
	EndIf;
	
	RegisteringsEmployeeTasks = RegisterRecords.EmployeeTasks;
	RegisteringsEmployeeTasks.Write = True;
	RegisteringsEmployeeTasks.Load(TableEmployeeTasks);
	
EndProcedure

// Moves on the register Workload.
//
Procedure ReflectWorkload(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkload = AdditionalProperties.TableForRegisterRecords.TableWorkload;
	
	If Cancel
	 Or TableWorkload.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterWorkload = RegisterRecords.Workload;
	RegisterWorkload.Write = True;
	RegisterWorkload.Load(TableWorkload);
	
EndProcedure

// Moves on the register ProductRelease.
//
Procedure ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductRelease = AdditionalProperties.TableForRegisterRecords.TableProductRelease;
	
	If Cancel
	 Or TableProductRelease.Count() = 0 Then
		Return;
	EndIf;
	
	RegistersProductionTurnout = RegisterRecords.ProductRelease;
	RegistersProductionTurnout.Write = True;
	RegistersProductionTurnout.Load(TableProductRelease);
	
EndProcedure

// Moves on the register ManufacturingProcessSupply.
//
Procedure ReflectManufacturingProcessSupply(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableManufacturingProcessSupply = AdditionalProperties.TableForRegisterRecords.TableManufacturingProcessSupply;
	
	If Cancel
		Or TableManufacturingProcessSupply.Count() = 0 Then
		Return;
	EndIf;
	
	RegistersManufacturingProcessSupply = RegisterRecords.ManufacturingProcessSupply;
	RegistersManufacturingProcessSupply.Write = True;
	RegistersManufacturingProcessSupply.Load(TableManufacturingProcessSupply);
	
EndProcedure

// Moves accumulation register BankCharges.
//
Procedure ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableBankCharges = AdditionalProperties.TableForRegisterRecords.TableBankCharges;
	
	If Cancel
	 Or TableBankCharges.Count() = 0 Then
		Return;
	EndIf;
	
	BankChargesRegistering = RegisterRecords.BankCharges;
	BankChargesRegistering.Write = True;
	BankChargesRegistering.Load(TableBankCharges);
	
EndProcedure

// Moves accounting register.
//
Procedure ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	TableAccountingJournalEntries = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	If Cancel Or TableAccountingJournalEntries.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterAdministratives = RegisterRecords.AccountingJournalEntries;
	RegisterAdministratives.Write = True;
	
	For Each RowTableAccountingJournalEntries In TableAccountingJournalEntries Do
		RegisterAdministrative = RegisterAdministratives.Add();
		FillPropertyValues(RegisterAdministrative, RowTableAccountingJournalEntries);
	EndDo;
	
EndProcedure

// Moves accounting register.
//
Procedure ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountingJournalEntriesCompound = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesCompound;
	
	If Cancel Or TableAccountingJournalEntriesCompound.Count() = 0 Then
		Return;
	EndIf;
	
	Register = RegisterRecords.AccountingJournalEntriesCompound;
	Register.Write = True;
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Each RowTable In TableAccountingJournalEntriesCompound Do
		
		RegisterRow = Register.Add();
		FillPropertyValues(RegisterRow, RowTable);
		
		CheckTypeAndAddExtDimensionsToRecord(RowTable, RegisterRow, "", MaxAnalyticalDimensionsNumber);
		
	EndDo;
	
EndProcedure

// Moves accounting register.
//
Procedure ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountingJournalEntriesSimple = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesSimple;
	
	If Cancel Or TableAccountingJournalEntriesSimple.Count() = 0 Then
		Return;
	EndIf;
	
	Register = RegisterRecords.AccountingJournalEntriesSimple;
	Register.Write = True;
	
	MaxAnalyticalDimensionsNumber = ChartsOfAccounts.MasterChartOfAccounts.MaxAnalyticalDimensionsNumber();
	For Each RowTable In TableAccountingJournalEntriesSimple Do
		
		RegisterRow = Register.Add();
		FillPropertyValues(RegisterRow, RowTable);
		
		CheckTypeAndAddExtDimensionsToRecord(RowTable, RegisterRow, "Dr", MaxAnalyticalDimensionsNumber);
		CheckTypeAndAddExtDimensionsToRecord(RowTable, RegisterRow, "Cr", MaxAnalyticalDimensionsNumber);
		
	EndDo;
	
EndProcedure

// Moves accounting register.
//
Procedure ReflectAccountingRegister(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableJournalEntries = AdditionalProperties.TableForRegisterRecords.TableJournalEntries;
	AccountingRegisterName = AdditionalProperties.ForPosting.AccountingRegisterName;
	
	If Cancel
		Or TableJournalEntries.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterAdministratives = RegisterRecords[AccountingRegisterName];
	RegisterAdministratives.Write = True;
	
	For Each RowTableJournalEntries In TableJournalEntries Do
		RegisterAdministrative = RegisterAdministratives.Add();
		FillPropertyValues(RegisterAdministrative, RowTableJournalEntries);
	EndDo;
	
EndProcedure

// Moves accumulation register VATInput
//
Procedure ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATIncurred = AdditionalProperties.TableForRegisterRecords.TableVATIncurred;
	
	If Cancel
	 Or TableVATIncurred.Count() = 0 Then
		Return;
	EndIf;
	
	VATIncurredRecord = RegisterRecords.VATIncurred;
	VATIncurredRecord.Write = True;
	VATIncurredRecord.Load(TableVATIncurred);
	
EndProcedure

// Moves accumulation register VATInput
//
Procedure ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATInput = AdditionalProperties.TableForRegisterRecords.TableVATInput;
	
	If Cancel
	 Or TableVATInput.Count() = 0 Then
		Return;
	EndIf;
	
	VATInputRecord = RegisterRecords.VATInput;
	VATInputRecord.Write = True;
	VATInputRecord.Load(TableVATInput);
	
EndProcedure

// Moves accumulation register VATOutput
//
Procedure ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATOutput = AdditionalProperties.TableForRegisterRecords.TableVATOutput;
	
	If Cancel
	 Or TableVATOutput.Count() = 0 Then
		Return;
	EndIf;
	
	VATOutputRecord = RegisterRecords.VATOutput;
	VATOutputRecord.Write = True;
	VATOutputRecord.Load(TableVATOutput);
	
EndProcedure

Procedure ReflectFundsTransfersBeingProcessed(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFundsTransfersBeingProcessed = AdditionalProperties.TableForRegisterRecords.TableFundsTransfersBeingProcessed;
	
	If Cancel
	 Or TableFundsTransfersBeingProcessed.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterFundsTransfersBeingProcessed = RegisterRecords.FundsTransfersBeingProcessed;
	RegisterFundsTransfersBeingProcessed.Write = True;
	RegisterFundsTransfersBeingProcessed.Load(TableFundsTransfersBeingProcessed);
	
EndProcedure

Procedure ReflectTasksForUpdatingStatuses(Document, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Document", Document);
	
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.BasisDocument AS BasisDocument
	|INTO SalesInovice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.BasisDocument AS BasisDocument
	|INTO SupplierInovice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	Quote.Ref AS Document
	|INTO DocumentForUpdating
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrder.BasisDocument
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Document
	|	AND VALUETYPE(SalesOrder.BasisDocument) = TYPE(Document.Quote)
	|	AND SalesOrder.BasisDocument <> VALUE(Document.Quote.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.BasisDocument
	|FROM
	|	SalesInovice AS SalesInvoice
	|WHERE
	|	VALUETYPE(SalesInvoice.BasisDocument) = TYPE(Document.Quote)
	|	AND SalesInvoice.BasisDocument <> VALUE(Document.Quote.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesInvoiceInventory.GoodsIssue
	|FROM
	|	SalesInovice AS SalesInvoice
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON SalesInvoice.Ref = SalesInvoiceInventory.Ref
	|			AND (SalesInvoiceInventory.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SupplierInvoiceInventory.GoodsReceipt
	|FROM
	|	SupplierInovice AS SupplierInovice
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON SupplierInovice.Ref = SupplierInvoiceInventory.Ref
	|			AND (SupplierInvoiceInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsIssue.Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReceipt.Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Document
	// begin Drive.FullVersion
	|
	|UNION ALL
	|
	|SELECT
	|	ProductionOrder.Ref
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &Document
	|	AND ProductionOrder.OperationKind = VALUE(Enum.OperationTypesProductionOrder.Production)
	// end Drive.FullVersion 
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentForUpdating.Document AS Document
	|FROM
	|	DocumentForUpdating AS DocumentForUpdating
	|
	|GROUP BY
	|	DocumentForUpdating.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	TasksForUpdatingStatuses.Document AS Document
	|FROM
	|	InformationRegister.TasksForUpdatingStatuses AS TasksForUpdatingStatuses
	|WHERE
	|	TasksForUpdatingStatuses.Document = &Document";
	
	ResultArray = Query.ExecuteBatch();
	
	If ResultArray[3].IsEmpty() Then
		Return;
	EndIf;
	
	DocumentsInRegister = ResultArray[4].Unload();
	SelectionDocument = ResultArray[3].Select();
	
	While SelectionDocument.Next() Do
		If DocumentsInRegister.Find(SelectionDocument.Document, "Document") = Undefined Then
			RecordManager = InformationRegisters.TasksForUpdatingStatuses.CreateRecordManager();
			RecordManager.Document = SelectionDocument.Document;
			RecordManager.Write();
		EndIf;
	EndDo;
	
EndProcedure

// Moves information register DocumentAccountingEntriesStatuses.
//
Procedure ReflectDocumentAccountingEntriesStatuses(Object, AdditionalProperties, RegisterRecords, Cancel) Export
	
	If Cancel
		Or (AdditionalProperties.AccountingPolicy.AccountingModuleSettings
			= Enums.AccountingModuleSettingsTypes.DoNotUseAccountingModule)
		Or (AdditionalProperties.AccountingPolicy.AccountingModuleSettings
			= Enums.AccountingModuleSettingsTypes.UseDefaultTypeOfAccounting
			And Not GetFunctionalOption("UseAccountingApproval")) Then
		
		Return;
		
	EndIf;
	
	IsManualAccountingTransaction = (TypeOf(Object) = Type("DocumentObject.AccountingTransaction") And Object.IsManual);
	
	If Not IsManualAccountingTransaction
		And CheckAccountingEntriesExist(AdditionalProperties)
		And Not CheckAccountingSettingExist(AdditionalProperties) Then
		
		Return;
		
	EndIf;
	
	Company	= Object.Company;
	Period	= Object.Date;
	
	RegisterRecordsDocumentAccountingEntriesStatuses = RegisterRecords.DocumentAccountingEntriesStatuses;
	RegisterRecordsDocumentAccountingEntriesStatuses.Write = True;
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 0
	|	DocumentAccountingEntriesStatuses.Recorder AS Recorder,
	|	DocumentAccountingEntriesStatuses.Period AS Period,
	|	DocumentAccountingEntriesStatuses.Company AS Company,
	|	DocumentAccountingEntriesStatuses.Counterparty AS Counterparty,
	|	DocumentAccountingEntriesStatuses.ChartOfAccounts AS ChartOfAccounts,
	|	DocumentAccountingEntriesStatuses.DocumentAmount AS DocumentAmount,
	|	DocumentAccountingEntriesStatuses.DocumentCurrency AS DocumentCurrency,
	|	DocumentAccountingEntriesStatuses.OperationKind AS OperationKind,
	|	DocumentAccountingEntriesStatuses.Author AS Author,
	|	DocumentAccountingEntriesStatuses.TypeOfAccounting AS TypeOfAccounting,
	|	DocumentAccountingEntriesStatuses.Status AS Status,
	|	DocumentAccountingEntriesStatuses.AdjustedManually AS AdjustedManually,
	|	DocumentAccountingEntriesStatuses.EntriesGenerated AS EntriesGenerated
	|FROM
	|	InformationRegister.DocumentAccountingEntriesStatuses AS DocumentAccountingEntriesStatuses";
	
	TableData = Query.Execute().Unload();
	
	Status = Enums.AccountingEntriesStatus.NotApproved;
	DocumentType = Common.MetadataObjectID(Object.Metadata());
	
	Recorder = Object.Ref;
	
	If TypeOf(Object) = Type("DocumentObject.AccountingTransaction") And ValueIsFilled(Object.BasisDocument) Then
		
		BasisDocument	 = Object.BasisDocument;
		TypeOfAccounting = Object.TypeOfAccounting;
		ChartOfAccounts	 = Object.ChartOfAccounts;
		
		NewRow = TableData.Add();
		
		ObjectMetadata = Object.Metadata();
		
		FillPropertyValues(NewRow, BasisDocument, "Company, Author");
		
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "Counterparty");
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentAmount");
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentCurrency");
		
		NewRow.Recorder						= Recorder;
		NewRow.Period						= Period;
		NewRow.TypeOfAccounting				= TypeOfAccounting;
		NewRow.ChartOfAccounts				= ChartOfAccounts;
		NewRow.Status						= Status;
		
		If AdditionalProperties.Property("AdjustedManually") Then
			NewRow.AdjustedManually			= AdditionalProperties.AdjustedManually;
		EndIf;
		
		NewRow.EntriesGenerated				= Enums.AccountingEntriesGenerationStatus.Generated;
		
		RegisterRecordsDocumentAccountingEntriesStatuses.Load(TableData);
		RegisterRecordsDocumentAccountingEntriesStatuses.Write();
		
		ReflectAccountingTransactionDocuments(Object.Ref, BasisDocument, TypeOfAccounting, ChartOfAccounts);
		
	ElsIf AdditionalProperties.ForPosting.Property("AccountingSettingTable") 
		And AdditionalProperties.ForPosting.AccountingSettingTable.Count() > 0 Then
		
		AccountingSettingTable = AdditionalProperties.ForPosting.AccountingSettingTable;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	AccountingTransactionDocuments.TypeOfAccounting AS TypeOfAccounting,
		|	AccountingTransactionDocuments.AccountingEntriesRecorder AS AccountingEntriesRecorder
		|FROM
		|	InformationRegister.AccountingTransactionDocuments AS AccountingTransactionDocuments
		|WHERE
		|	AccountingTransactionDocuments.SourceDocument = &BasisDocument";
		
		Query.SetParameter("BasisDocument", Recorder);
		
		QueryResult = Query.Execute();
		
		TableAccountingEntriesRecorders = QueryResult.Unload();
		ObjectMetadata = Object.Metadata();
		
		For Each SettingRow In AccountingSettingTable Do
			
			If Not SettingRow.IsRecorder Then
				Continue;
			EndIf;
			
			SelfGenerated = (SettingRow.EntriesPostingOption = Enums.AccountingEntriesRegisterOptions.SourceDocuments);
			
			AccountingTransactionDocumentsRecorder = Undefined;
			
			If SelfGenerated Then
				
				NewRow = TableData.Add();
				FillPropertyValues(NewRow, Object, "Company, Author");
				CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "Counterparty");
				CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentAmount");
				CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentCurrency");
				
				NewRow.Recorder						= Recorder;
				NewRow.Period						= Period;
				NewRow.TypeOfAccounting				= SettingRow.TypeOfAccounting;
				NewRow.ChartOfAccounts				= SettingRow.ChartOfAccounts;
				NewRow.Status						= Status;
				NewRow.EntriesGenerated				= Enums.AccountingEntriesGenerationStatus.Generated;
				
				If Common.HasObjectAttribute("OperationKind", Object.Metadata()) Then
					NewRow.OperationKind = Object.OperationKind;
				EndIf;
				
				FillRowCurrencyFromObject(NewRow, Object);
				
				AccountingTransactionDocumentsRecorder = Recorder;
				
			Else
				
				FoundRows = TableAccountingEntriesRecorders.FindRows(New Structure("TypeOfAccounting", SettingRow.TypeOfAccounting));
				
				If FoundRows.Count() > 0 Then
					AccountingTransactionDocumentsRecorder = FoundRows[0].AccountingEntriesRecorder;
				EndIf;
				
			EndIf;
			
			ReflectAccountingTransactionDocuments(
				AccountingTransactionDocumentsRecorder,
				Recorder,
				SettingRow.TypeOfAccounting,
				SettingRow.ChartOfAccounts);
			
		EndDo;
		
		RegisterRecordsDocumentAccountingEntriesStatuses.Load(TableData);
		RegisterRecordsDocumentAccountingEntriesStatuses.Write();
		
	Else
		
		NewRow = TableData.Add();
		FillPropertyValues(NewRow, Object, "Company, Author");
		
		ObjectMetadata = Object.Metadata();
		
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "Counterparty");
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentAmount");
		CheckAndFillAttribute(NewRow, Object, ObjectMetadata, "DocumentCurrency");
		
		NewRow.Recorder						= Recorder;
		NewRow.Period						= Period;
		NewRow.Status						= Status;
		NewRow.EntriesGenerated				= Enums.AccountingEntriesGenerationStatus.Generated;
		NewRow.AdjustedManually				= False;
			
		If Common.HasObjectAttribute("OperationKind", Object.Metadata()) Then
			NewRow.OperationKind = Object.OperationKind;
		EndIf;
		
		FillRowCurrencyFromObject(NewRow, Object);
		
		RegisterRecordsDocumentAccountingEntriesStatuses.Load(TableData);
		RegisterRecordsDocumentAccountingEntriesStatuses.Write();
		
	EndIf;
	
	TableAccountingJournalEntries = RegisterRecords.Find("AccountingJournalEntries");
	If TableAccountingJournalEntries <> Undefined Then
		For Each Record In TableAccountingJournalEntries Do
			Record.Status = Status;
		EndDo;
	EndIf;
	
	TableAccountingJournalEntriesSimple = RegisterRecords.Find("AccountingJournalEntriesSimple");
	If TableAccountingJournalEntriesSimple <> Undefined Then
		For Each Record In TableAccountingJournalEntriesSimple Do
			Record.Status = Status;
		EndDo;
	EndIf;
	
	TableAccountingJournalEntriesCompound = RegisterRecords.Find("AccountingJournalEntriesCompound");
	If TableAccountingJournalEntriesCompound <> Undefined Then
		For Each Record In TableAccountingJournalEntriesCompound Do
			Record.Status = Status;
		EndDo;
	EndIf;
	
EndProcedure

Procedure ReflectDeletionAccountingTransactionDocuments(Recorder) Export
	
	AccountingTransactionDocumentsRecordSet = InformationRegisters.AccountingTransactionDocuments.CreateRecordSet();
	
	AccountingTransactionDocumentsRecordSet.Filter.AccountingEntriesRecorder.Set(Recorder);
	
	AccountingTransactionDocumentsRecordSet.Write();
	
EndProcedure

Procedure ReflectUsingPaymentTermsInDocuments(Document, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	RecordManager = InformationRegisters.UsingPaymentTermsInDocuments.CreateRecordManager();
	RecordManager.Document = Document;
	RecordManager.UsingPaymentTerms = Document.SetPaymentTerms;
	RecordManager.Write();

EndProcedure

// Moves accounting register.
//
Procedure ReflectQuotations(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableQuotations = AdditionalProperties.TableForRegisterRecords.TableQuotations;
	
	If Cancel
		Or TableQuotations.Count() = 0 Then
		Return;
	EndIf;
	
	QuotationsRecord = RegisterRecords.Quotations;
	QuotationsRecord.Write = True;
	QuotationsRecord.Load(TableQuotations);
	
EndProcedure

Procedure ReflectPackedOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePackedOrders = AdditionalProperties.TableForRegisterRecords.TablePackedOrders;
	
	If Cancel
	 Or TablePackedOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterPackedOrders = RegisterRecords.PackedOrders;
	RegisterPackedOrders.Write = True;
	RegisterPackedOrders.Load(TablePackedOrders);
	
EndProcedure

// Moves information register Prices.
//
Procedure ReflectPrices(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePrices = AdditionalProperties.TableForRegisterRecords.TablePrices;
	
	If Cancel
	 Or TablePrices.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPrices = RegisterRecords.Prices;
	RegisterRecordsPrices.Write = True;
	RegisterRecordsPrices.Load(TablePrices);
	
EndProcedure

// Moves information register PredeterminedOverheadRates.
//
Procedure ReflectPredeterminedOverheadRates(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePredeterminedOverheadRates = AdditionalProperties.TableForRegisterRecords.TablePredeterminedOverheadRates;
	
	If Cancel
	 Or TablePredeterminedOverheadRates.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPrices = RegisterRecords.PredeterminedOverheadRates;
	RegisterRecordsPrices.Write = True;
	RegisterRecordsPrices.Load(TablePredeterminedOverheadRates);
	
EndProcedure

// Moves accounting register WorkcentersAvailability.
//
Procedure ReflectWorkcentersAvailability(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkcentersAvailability = AdditionalProperties.TableForRegisterRecords.TableWorkcentersAvailability;
	
	If Cancel
		Or TableWorkcentersAvailability.Count() = 0 Then
		Return;
	EndIf;
	
	QuotationsRecord = RegisterRecords.WorkcentersAvailability;
	QuotationsRecord.Write = True;
	QuotationsRecord.Load(TableWorkcentersAvailability);
	
EndProcedure

Procedure ReflectProductionAccomplishment(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductionAccomplishment = AdditionalProperties.TableForRegisterRecords.TableProductionAccomplishment;
	
	If Cancel
		Or TableProductionAccomplishment.Count() = 0 Then
		Return;
	EndIf;
	
	ProductionRecord = RegisterRecords.ProductionAccomplishment;
	ProductionRecord.Write = True;
	ProductionRecord.Load(TableProductionAccomplishment);
	
EndProcedure

// Moves accumulation register GoodsInTransit.
//
Procedure ReflectGoodsInTransit(AdditionalProperties, RegisterRecords, Cancel) Export

	TableGoodsInTransit = AdditionalProperties.TableForRegisterRecords.TableGoodsInTransit;
	
	If Cancel
	 Or TableGoodsInTransit.Count() = 0 Then
		Return;
	EndIf;
	
	GoodsInTransitRecord = RegisterRecords.GoodsInTransit;
	GoodsInTransitRecord.Write = True;
	GoodsInTransitRecord.Load(TableGoodsInTransit);	

EndProcedure

// begin Drive.FullVersion

// Moves accumulation register WorkInProgressStatement.
//
Procedure ReflectWorkInProgressStatement(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkInProgressStatement = AdditionalProperties.TableForRegisterRecords.TableWorkInProgressStatement;
	
	If Cancel
		Or TableWorkInProgressStatement.Count() = 0 Then
		Return;
	EndIf;
	
	WorkInProgressStatementRecords = RegisterRecords.WorkInProgressStatement;
	WorkInProgressStatementRecords.Write = True;
	WorkInProgressStatementRecords.Load(TableWorkInProgressStatement);
	
EndProcedure

// Moves accumulation register SubcontractorPlanning.
//
Procedure ReflectSubcontractorPlanning(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSubcontractorPlanning = AdditionalProperties.TableForRegisterRecords.TableSubcontractorPlanning;
	
	If Cancel
		Or TableSubcontractorPlanning.Count() = 0 Then
		Return;
	EndIf;
	
	SubcontractorPlanningRecords = RegisterRecords.SubcontractorPlanning;
	SubcontractorPlanningRecords.Write = True;
	SubcontractorPlanningRecords.Load(TableSubcontractorPlanning);
	
EndProcedure

// Moves accumulation register ReflectProductionComponents.
//
Procedure ReflectProductionComponents(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductionComponents = AdditionalProperties.TableForRegisterRecords.TableProductionComponents;
	
	If Cancel Or TableProductionComponents.Count() = 0 Then
		Return;
	EndIf;
	
	ProductionComponentsRecords = RegisterRecords.ProductionComponents;
	ProductionComponentsRecords.Write = True;
	ProductionComponentsRecords.Load(TableProductionComponents);
	
EndProcedure

// Returns empty value table
//
Function EmptyProductionComponentsTable() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 0
	|	ProductionComponents.Period AS Period,
	|	ProductionComponents.Recorder AS Recorder,
	|	ProductionComponents.LineNumber AS LineNumber,
	|	ProductionComponents.Active AS Active,
	|	ProductionComponents.RecordType AS RecordType,
	|	ProductionComponents.Company AS Company,
	|	ProductionComponents.ProductionDocument AS ProductionDocument,
	|	ProductionComponents.Products AS Products,
	|	ProductionComponents.Characteristic AS Characteristic,
	|	ProductionComponents.Quantity AS Quantity
	|FROM
	|	AccumulationRegister.ProductionComponents AS ProductionComponents";
	
	Return Query.Execute().Unload();
	
EndFunction

// end Drive.FullVersion

#Region DiscountCards

// Moves on the register SalesWithCardBasedDiscounts.
//
Procedure ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSalesWithCardBasedDiscounts = AdditionalProperties.TableForRegisterRecords.TableSalesWithCardBasedDiscounts;
	
	If Cancel
	 Or TableSalesWithCardBasedDiscounts.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterSalesWithCardBasedDiscounts = RegisterRecords.SalesWithCardBasedDiscounts;
	RegisterSalesWithCardBasedDiscounts.Write = True;
	RegisterSalesWithCardBasedDiscounts.Load(TableSalesWithCardBasedDiscounts);
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Moves on the register ProvidedAutomaticDiscounts.
//
Procedure FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAutomaticDiscountsApplied = AdditionalProperties.TableForRegisterRecords.TableAutomaticDiscountsApplied;
	
	If Cancel
	 Or TableAutomaticDiscountsApplied.Count() = 0 Then
		Return;
	EndIf;
	
	MovementsProvidedAutomaticDiscounts = RegisterRecords.AutomaticDiscountsApplied;
	MovementsProvidedAutomaticDiscounts.Write = True;
	MovementsProvidedAutomaticDiscounts.Load(TableAutomaticDiscountsApplied);
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

Procedure ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSerialNumbersInWarranty = AdditionalProperties.TableForRegisterRecords.TableSerialNumbersInWarranty;
	
	If Cancel
	 Or TableSerialNumbersInWarranty.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSerialNumbersInWarranty = RegisterRecords.SerialNumbersInWarranty;
	RegisterRecordsSerialNumbersInWarranty.Write = True;
	RegisterRecordsSerialNumbersInWarranty.Load(TableSerialNumbersInWarranty);
	
EndProcedure

Procedure ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSerialNumbers = AdditionalProperties.TableForRegisterRecords.TableSerialNumbers;
	
	If Cancel
	 Or TableSerialNumbers.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSerialNumbersBalance = RegisterRecords.SerialNumbers;
	RegisterRecordsSerialNumbersBalance.Write = True;
	RegisterRecordsSerialNumbersBalance.Load(TableSerialNumbers);
	
EndProcedure

#EndRegion

#Region AccountingRegisters

// Returns table with online and offline records.
// Online records created by source document, offline created by Month-end closing.
//
// Paremeters:
//	AccountingRecords - AccountingRegister.AccountingJournalEntries.Records - online records
//	DocumentRef - Document.Ref - Source document
//
// Returned value:
//	AccountingRegister.AccountingJournalEntries.Records
//
Function AddOfflineAccountingJournalEntriesRecords(AccountingRecords, DocumentRef) Export
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then 
		Return AccountingRecords;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	Table.AccountDr AS AccountDr,
	|	Table.AccountCr AS AccountCr,
	|	Table.Company AS Company,
	|	Table.PlanningPeriod AS PlanningPeriod,
	|	Table.CurrencyDr AS CurrencyDr,
	|	Table.CurrencyCr AS CurrencyCr,
	|	Table.Amount AS Amount,
	|	Table.AmountCurDr AS AmountCurDr,
	|	Table.AmountCurCr AS AmountCurCr,
	|	Table.Content AS Content,
	|	FALSE AS OfflineRecord,
	|	Table.Period AS Period
	|INTO NewRecords
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	NewRecords.Period AS Period,
	|	NewRecords.AccountDr AS AccountDr,
	|	NewRecords.AccountCr AS AccountCr,
	|	NewRecords.Company AS Company,
	|	NewRecords.PlanningPeriod AS PlanningPeriod,
	|	NewRecords.CurrencyDr AS CurrencyDr,
	|	NewRecords.CurrencyCr AS CurrencyCr,
	|	NewRecords.Amount AS Amount,
	|	NewRecords.AmountCurDr AS AmountCurDr,
	|	NewRecords.AmountCurCr AS AmountCurCr,
	|	NewRecords.Content AS Content,
	|	NewRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	NewRecords AS NewRecords
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	Query.SetParameter("Table", AccountingRecords);
	Query.SetParameter("Ref", DocumentRef);
	
	Return Query.Execute().Unload();
	
EndFunction

// Returns empty value table
Function EmptyAccountingJournalEntriesTable() Export
	
	Query = New Query("
	|SELECT ALLOWED TOP 0
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries");
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region DuplicateChecking

// Moves on the register DuplicateRulesIndex.
//
Procedure ReflectDuplicateRulesIndex(AdditionalProperties, CatalogRef, Cancel) Export
	
	DuplicateRulesIndexTable = AdditionalProperties.DuplicateRulesIndexTable;
	
	If Cancel Then
		Return;
	EndIf;
	
	RecordManager = InformationRegisters.DuplicateRulesIndex.CreateRecordSet();
	RecordManager.Filter.ObjectRef.Set(CatalogRef);
	RecordManager.Write();

	If Not CatalogRef.DeletionMark Then
		For Each IndexLine In DuplicateRulesIndexTable Do
			
			Record = InformationRegisters.DuplicateRulesIndex.CreateRecordManager();
			FillPropertyValues(Record, IndexLine);
			Record.Write(True);
			
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

Function EmptyProductReleaseTable() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 0
	|	ProductRelease.Period AS Period,
	|	ProductRelease.Recorder AS Recorder,
	|	ProductRelease.LineNumber AS LineNumber,
	|	ProductRelease.Active AS Active,
	|	ProductRelease.Company AS Company,
	|	ProductRelease.StructuralUnit AS StructuralUnit,
	|	ProductRelease.Products AS Products,
	|	ProductRelease.Characteristic AS Characteristic,
	|	ProductRelease.Batch AS Batch,
	|	ProductRelease.Ownership AS Ownership,
	|	ProductRelease.SalesOrder AS SalesOrder,
	|	ProductRelease.Specification AS Specification,
	|	ProductRelease.Quantity AS Quantity,
	|	ProductRelease.QuantityPlan AS QuantityPlan
	|FROM
	|	AccumulationRegister.ProductRelease AS ProductRelease";
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#Region PricingSubsystemProceduresAndFunctions

// Returns currencies rates to date.
//
// Parameters:
//  Currency       - CatalogRef.Currencies - Currency (catalog item
//  "Currencies") CourseDate    - Date - date for which a rate should be received.
//
// Returns: 
//  Structure, contains:
//   ExchangeRate - Number - the exchange rate.
//   Multiplicity - Number - the exchange rate multiplier.
//
Function GetExchangeRate(Company, CurrencyBeg, CurrencyEnd, ExchangeRateDate) Export
	
	StructureBeg = CurrencyRateOperations.GetCurrencyRate(ExchangeRateDate, CurrencyBeg, Company);
	StructureEnd = CurrencyRateOperations.GetCurrencyRate(ExchangeRateDate, CurrencyEnd, Company);
	
	StructureEnd.Rate = ?(StructureEnd.Rate = 0, 1, StructureEnd.Rate);
	StructureEnd.Repetition = ?(StructureEnd.Repetition = 0, 1, StructureEnd.Repetition);
	
	StructureEnd.Insert("InitRate", ?(StructureBeg.Rate = 0, 1, StructureBeg.Rate));
	StructureEnd.Insert("RepetitionBeg", ?(StructureBeg.Repetition = 0, 1, StructureBeg.Repetition));
	
	Return StructureEnd;
	
EndFunction

Function RecalculateFromCurrencyToAccountingCurrency(Company, AmountCur, CurrencyContract, ExchangeRateDate, PricesPrecision = 2) Export
	
	Amount = 0;
	
	If ValueIsFilled(CurrencyContract) Then
		
		Currency = ?(TypeOf(CurrencyContract) = Type("CatalogRef.CounterpartyContracts"), CurrencyContract.SettlementsCurrency, CurrencyContract);
		PresentationCurrency = GetPresentationCurrency(Company);
		ExchangeRateStructure = GetExchangeRate(Company, Currency, PresentationCurrency, ExchangeRateDate);
		
		Amount = RecalculateFromCurrencyToCurrency(
			AmountCur,
			GetExchangeMethod(Company),
			ExchangeRateStructure.InitRate,
			ExchangeRateStructure.Rate,
			ExchangeRateStructure.RepetitionBeg,
			ExchangeRateStructure.Repetition,
			PricesPrecision);
		
	EndIf;
	
	Return Amount;
	
EndFunction

// Function recalculates the amount from one currency to another
//
// Parameters:      
//  Amount        - Number - the amount to be converted.
// 	InitRate      - Number - the source currency exchange rate.
// 	FinRate       - Number - the target currency exchange rate.
// 	RepetitionBeg - Number - the exchange rate multiplier of the source currency.
//                           The default value is 1.
// 	RepetitionEnd - Number - the exchange rate multiplier of the target currency.
//                           The default value is 1.
//
// Returns: 
//  Number - amount recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, ExchangeRateMethod, SourceRate, RecepientRate, SourceMultiplicity = 1, RecepientMultiplicity = 1, PricesPrecision = 2) Export
	
	If SourceRate = RecepientRate And SourceMultiplicity = RecepientMultiplicity Then
		Return Amount;
	EndIf;
	
	If SourceRate = 0
		Or RecepientRate = 0
		Or SourceMultiplicity = 0
		Or RecepientMultiplicity = 0 Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Zero exchange rate is found. Conversion is not executed.'; ru = 'Обнаружен нулевой курс валюты. Пересчет не выполнен.';pl = 'Wykryto zerowy kurs waluty. Konwersja nie jest została przeprowadzona.';es_ES = 'Tipo de cambio nulo se ha encontrado. Conversión no se ha ejecutado.';es_CO = 'Tipo de cambio nulo se ha encontrado. Conversión no se ha ejecutado.';tr = 'Sıfır döviz kuru bulundu. Dönüşüm gerçekleştirilemedi.';it = 'È stato trovato un tasso di cambio pari a zero. La conversione non è eseguita.';de = 'Null Wechselkurs wird gefunden. Die Konvertierung wird nicht ausgeführt.'"));
		Return Amount;
	EndIf;
	
	If ExchangeRateMethod = Enums.ExchangeRateMethods.Divisor Then
		RecalculatedSumm = Round((Amount * RecepientRate * SourceMultiplicity) / (SourceRate * RecepientMultiplicity), PricesPrecision);
	ElsIf ExchangeRateMethod = Enums.ExchangeRateMethods.Multiplier Then
		RecalculatedSumm = Round((Amount * SourceRate * RecepientMultiplicity) / (RecepientRate * SourceMultiplicity), PricesPrecision);
	Else
		CommonClientServer.MessageToUser(
			NStr("en = 'Exchange rate method is undefined. Conversion is not executed.'; ru = 'Метод расчета курсов валют не определен. Конвертация не выполнена.';pl = 'Nie określono kursu waluty. Nie wykonano wymiany.';es_ES = 'El método del tipo de cambio no está definido. La conversión no se ejecuta.';es_CO = 'El método del tipo de cambio no está definido. La conversión no se ejecuta.';tr = 'Döviz kuru yöntemi tanımlanmamış. Dönüştürme yapılmadı.';it = 'Il metodo del tasso di scambio non è definito. La conversione non è stata eseguita.';de = 'Die Wechselkursmethode ist nicht bestimmt. Keine Umrechnung ist ausgeführt.'"));
		Return Amount;
	EndIf;
	
	Return RecalculatedSumm;
	
EndFunction

// Calculates VAT amount on the basis of amount and taxation check boxes.
//
// Parameters:
//  Amount        - Number - VAT
//  amount AmountIncludesVAT - Boolean - shows that VAT is
//  included in the VATRate amount.    - CatalogRef.VATRates - ref to VAT rate.
//
// Returns:
//  Number        - recalculated VAT amount.
//
Function RecalculateAmountOnVATFlagsChange(Amount, AmountIncludesVAT, VATRate) Export
	
	Rate = VATRate.Rate;
	
	If AmountIncludesVAT Then
		
		Amount = (Amount * (100 + Rate)) / 100;
		
	Else
		
		Amount = (Amount * 100) / (100 + Rate);
		
	EndIf;
	
	Return Amount;
	
EndFunction

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection) Export
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		And ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;	
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		And ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
	
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	ProductsTable.Columns.Add("BundleProduct", TypeDescription);
	
	// Variants.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	ProductsTable.Columns.Add("BundleCharacteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	// MeasurementUnit.
	Array.Add(Type("CatalogRef.UOM"));
	Array.Add(Type("CatalogRef.UOMClassifier"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);	
	
	// Ratio.
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Factor", TypeDescription);
	
	ProductsTable.Columns.Add("CostShare", TypeDescription);
	ProductsTable.Columns.Add("Quantity", TypeDescription);
	ProductsTable.Columns.Add("BundesQuantity", TypeDescription);
	ProductsTable.Columns.Add("Variant", TypeDescription);
		
	For Each TSRow In DocumentTabularSection Do
		
		If TypeOf(TSRow) = Type("Structure")
			And TSRow.Property("BundleProduct")
			And ValueIsFilled(TSRow.BundleProduct)
			And TSRow.CostShare = 0 Then
			
			Continue;
			
		EndIf;
		
		NewRow = ProductsTable.Add();
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		If TypeOf(TSRow) = Type("Structure")
		   And TSRow.Property("VATRate") Then
			NewRow.VATRate		 = TSRow.VATRate;
		EndIf;
		
		If TypeOf(TSRow) = Type("Structure") And TSRow.Property("BundleProduct") Then
			NewRow.BundleProduct = TSRow.BundleProduct;
			NewRow.BundleCharacteristic = TSRow.BundleCharacteristic;
			NewRow.CostShare = TSRow.CostShare;
			NewRow.Quantity = TSRow.Quantity;
			If TSRow.Property("BundesQuantity") Then
				NewRow.BundesQuantity = TSRow.BundesQuantity;
			Else
				NewRow.BundesQuantity = 1;
			EndIf;
			If TSRow.Property("Variant") Then
				NewRow.Variant = TSRow.Variant;
			Else
				NewRow.Variant = 0;
			EndIf;
		EndIf;
		
		If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			NewRow.Factor = 1;
		ElsIf TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOM") Then
			NewRow.Factor = TSRow.MeasurementUnit.Factor;
		EndIf;
		
	EndDo;
	
	For Each TSRow In DocumentTabularSection Do
		If Not TypeOf(TSRow) = Type("Structure")
			Or Not TSRow.Property("BundleProduct")
			Or Not ValueIsFilled(TSRow.BundleProduct)
			Or TSRow.CostShare > 0 Then
			Continue;
		EndIf;
		SearchStructure = New Structure("BundleProduct, BundleCharacteristic, Products, Characteristic, MeasurementUnit");
		FillPropertyValues(SearchStructure, TSRow);
		If TSRow.Property("Variant") Then
			SearchStructure.Insert("Variant", TSRow.Variant);
		EndIf;
		ProductsRows = ProductsTable.FindRows(SearchStructure);
		If ProductsRows.Count() > 0 Then
			ProductsRow = ProductsRows[0];
			ProductsRow.Quantity = ProductsRow.Quantity + TSRow.Quantity;
		EndIf;
	EndDo;
	UseBundles = False;
	If GetFunctionalOption("UseProductBundles") Then
		For Each ProductsRow In ProductsTable Do
			If ValueIsFilled(ProductsRow.BundleProduct) Then
				UseBundles = True;
				Break;
			EndIf;
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.SetParameter("ProductsTable", ProductsTable);
	
	
	Query.Text =
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	CAST(ProductsTable.BundleProduct AS Catalog.Products) AS BundleProduct,
	|	ProductsTable.BundleCharacteristic AS BundleCharacteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.VATRate AS VATRate,
	|	ProductsTable.Factor AS Factor,
	|	ProductsTable.Variant AS Variant,
	|	ProductsTable.CostShare AS CostShare,
	|	ProductsTable.Quantity AS Quantity,
	|	ProductsTable.BundesQuantity AS BundesQuantity
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
	
	If DataStructure.PriceKind.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
		
		Query.Text = Query.Text +
		"SELECT
		|	TemporaryProductsTable.Products AS Products,
		|	TemporaryProductsTable.Characteristic AS Characteristic,
		|	TemporaryProductsTable.MeasurementUnit AS MeasurementUnit,
		|	MAX(TemporaryProductsTable.Factor) AS Factor
		|FROM
		|	TemporaryProductsTable AS TemporaryProductsTable
		|
		|GROUP BY
		|	TemporaryProductsTable.Characteristic,
		|	TemporaryProductsTable.MeasurementUnit,
		|	TemporaryProductsTable.Products
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryProductsTable.BundleProduct AS Products,
		|	TemporaryProductsTable.BundleCharacteristic AS Characteristic,
		|	CatalogProducts.MeasurementUnit AS MeasurementUnit,
		|	1 AS Factor
		|FROM
		|	TemporaryProductsTable AS TemporaryProductsTable
		|		INNER JOIN Catalog.Products AS CatalogProducts
		|		ON TemporaryProductsTable.BundleProduct = CatalogProducts.Ref
		|
		|GROUP BY
		|	TemporaryProductsTable.BundleCharacteristic,
		|	TemporaryProductsTable.BundleProduct,
		|	CatalogProducts.MeasurementUnit";
		
		Query.SetParameter("UseBundles", UseBundles);
		
		Result = Query.ExecuteBatch();
		
		ProductsCharacteristicTable = PriceGenerationFormulaServerCall.GetTabularSectionPricesByFormula(DataStructure,
			Result[1].Unload());
		
		BundlesProductsCharacteristicTable = PriceGenerationFormulaServerCall.GetTabularSectionPricesByFormula(DataStructure,
			Result[2].Unload());
		
	Else
		
		Query.Text = Query.Text +
		"SELECT
		|	TemporaryProductsTable.Products AS Products,
		|	TemporaryProductsTable.Characteristic AS Characteristic
		|INTO ProductsCharacteristicTable
		|FROM
		|	TemporaryProductsTable AS TemporaryProductsTable
		|
		|GROUP BY
		|	TemporaryProductsTable.Products,
		|	TemporaryProductsTable.Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryProductsTable.BundleProduct AS BundleProduct,
		|	TemporaryProductsTable.BundleCharacteristic AS BundleCharacteristic
		|INTO BundlesProductsCharacteristicTable
		|FROM
		|	TemporaryProductsTable AS TemporaryProductsTable
		|
		|GROUP BY
		|	TemporaryProductsTable.BundleCharacteristic,
		|	TemporaryProductsTable.BundleProduct";
		
		Query.Execute();
		
	EndIf;
	
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		
		If DataStructure.PriceKind.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
			
			DynamicPriceKind = True;
			PriceKindParameter = DataStructure.PriceKind;
			Markup = 0;
			
		Else
			
			DynamicPriceKind = True;
			PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
			Markup = DataStructure.PriceKind.Percent;
			
		EndIf;
		
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If DataStructure.PriceKind.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
		
		Query.SetParameter("ProductsCharacteristicTable", ProductsCharacteristicTable);
		Query.SetParameter("BundlesProductsCharacteristicTable", BundlesProductsCharacteristicTable);
		
		Query.Text = 
		"SELECT
		|	TempPriceTable.Products AS Products,
		|	TempPriceTable.Characteristic AS Characteristic,
		|	TempPriceTable.Price AS Price,
		|	TempPriceTable.Factor AS Factor
		|INTO ProductsPrices
		|FROM
		|	&ProductsCharacteristicTable AS TempPriceTable
		|
		|INDEX BY
		|	Products,
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TempPriceTable.Products AS Products,
		|	TempPriceTable.Characteristic AS Characteristic,
		|	TempPriceTable.Price AS Price,
		|	TempPriceTable.Factor AS Factor
		|INTO BundlesPrices
		|FROM
		|	&BundlesProductsCharacteristicTable AS TempPriceTable
		|WHERE &UseBundles
		|
		|INDEX BY
		|	Products,
		|	Characteristic";
		
	Else
		
		Query.Text = 
		"SELECT ALLOWED
		|	ProductsCharacteristicTable.Products AS Products,
		|	ProductsCharacteristicTable.Characteristic AS Characteristic,
		|	ISNULL(PricesSliceLast.Price, CommonPrices.Price) AS Price,
		|	CASE
		|		WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
		|			THEN PricesSliceLast.MeasurementUnit.Factor
		|		WHEN CommonPrices.MeasurementUnit REFS Catalog.UOM
		|			THEN CommonPrices.MeasurementUnit.Factor
		|		ELSE 1
		|	END AS Factor
		|INTO ProductsPrices
		|FROM
		|	ProductsCharacteristicTable AS ProductsCharacteristicTable
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&ProcessingDate,
		|				PriceKind = &PriceKind
		|					AND (Products, Characteristic) IN
		|						(SELECT
		|							ProductsCharacteristicTable.Products,
		|							ProductsCharacteristicTable.Characteristic
		|						FROM
		|							ProductsCharacteristicTable AS ProductsCharacteristicTable)) AS PricesSliceLast
		|		ON ProductsCharacteristicTable.Products = PricesSliceLast.Products
		|			AND ProductsCharacteristicTable.Characteristic = PricesSliceLast.Characteristic
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&ProcessingDate,
		|				PriceKind = &PriceKind
		|					AND Products IN
		|						(SELECT
		|							ProductsCharacteristicTable.Products
		|						FROM
		|							ProductsCharacteristicTable AS ProductsCharacteristicTable)
		|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS CommonPrices
		|		ON ProductsCharacteristicTable.Products = CommonPrices.Products
		|WHERE
		|	(NOT PricesSliceLast.Price IS NULL
		|			OR NOT CommonPrices.Price IS NULL)
		|
		|INDEX BY
		|	Products,
		|	Characteristic
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	Bundles.BundleProduct AS Products,
		|	Bundles.BundleCharacteristic AS Characteristic,
		|	ISNULL(PricesSliceLast.Price, CommonPrices.Price) AS Price,
		|	CASE
		|		WHEN PricesSliceLast.MeasurementUnit REFS Catalog.UOM
		|			THEN PricesSliceLast.MeasurementUnit.Factor
		|		WHEN CommonPrices.MeasurementUnit REFS Catalog.UOM
		|			THEN CommonPrices.MeasurementUnit.Factor
		|		ELSE 1
		|	END AS Factor
		|INTO BundlesPrices
		|FROM
		|	BundlesProductsCharacteristicTable AS Bundles
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&ProcessingDate,
		|				PriceKind = &PriceKind
		|					AND (Products, Characteristic) IN
		|						(SELECT
		|							Bundles.BundleProduct,
		|							Bundles.BundleCharacteristic
		|						FROM
		|							BundlesProductsCharacteristicTable AS Bundles)) AS PricesSliceLast
		|		ON Bundles.BundleProduct = PricesSliceLast.Products
		|			AND Bundles.BundleCharacteristic = PricesSliceLast.Characteristic
		|		LEFT JOIN InformationRegister.Prices.SliceLast(
		|				&ProcessingDate,
		|				PriceKind = &PriceKind
		|					AND Products IN
		|						(SELECT
		|							Bundles.BundleProduct
		|						FROM
		|							BundlesProductsCharacteristicTable AS Bundles)
		|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS CommonPrices
		|		ON Bundles.BundleProduct = CommonPrices.Products
		|WHERE
		|	&UseBundles
		|	AND (NOT PricesSliceLast.Price IS NULL
		|			OR NOT CommonPrices.Price IS NULL)
		|
		|INDEX BY
		|	Products,
		|	Characteristic";
		
	EndIf;
	
	Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
	Query.Text = Query.Text +
	"SELECT ALLOWED
	|	TemporaryProductsTable.BundleProduct AS BundleProduct,
	|	TemporaryProductsTable.BundleCharacteristic AS BundleCharacteristic,
	|	TemporaryProductsTable.Variant AS Variant,
	|	SUM(CASE
	|			WHEN TemporaryProductsTable.Quantity = 0
	|				THEN 0
	|			ELSE TemporaryProductsTable.CostShare
	|		END) AS CostShare,
	|	SUM(TemporaryProductsTable.Quantity) AS Quantity,
	|	MAX(TemporaryProductsTable.BundesQuantity * ISNULL(BundlesPrices.Price * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition / (ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition / (ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition)
	|	END / ISNULL(BundlesPrices.Factor, 1), 0)) AS BundlePrice,
	|	SUM(ISNULL(ProductsPrices.Price * TemporaryProductsTable.Quantity * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition / (ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition / (ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition)
	|	END * ISNULL(TemporaryProductsTable.Factor, 1) / ISNULL(ProductsPrices.Factor, 1), 0)) AS Price
	|INTO CalculationBase
	|FROM
	|	TemporaryProductsTable AS TemporaryProductsTable
	|		LEFT JOIN ProductsPrices AS ProductsPrices
	|		ON TemporaryProductsTable.Products = ProductsPrices.Products
	|			AND TemporaryProductsTable.Characteristic = ProductsPrices.Characteristic
	|		LEFT JOIN BundlesPrices AS BundlesPrices
	|		ON TemporaryProductsTable.BundleProduct = BundlesPrices.Products
	|			AND TemporaryProductsTable.BundleCharacteristic = BundlesPrices.Characteristic,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &PriceCurrency AND Company = &Company) AS ExchangeRatePriceKind,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS ExchangeRateDocument
	|WHERE
	|	&UseBundles
	|	AND TemporaryProductsTable.BundleProduct <> VALUE(Catalog.Products.EmptyRef)
	|	AND TemporaryProductsTable.BundleProduct.BundlePricingStrategy <> VALUE(Enum.ProductBundlePricingStrategy.PerComponentPricing)
	|
	|GROUP BY
	|	TemporaryProductsTable.BundleProduct,
	|	TemporaryProductsTable.BundleCharacteristic,
	|	TemporaryProductsTable.Variant
	|
	|INDEX BY
	|	BundleProduct,
	|	BundleCharacteristic,
	|	Variant
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TemporaryProductsTable.Products AS Products,
	|	TemporaryProductsTable.Characteristic AS Characteristic,
	|	TemporaryProductsTable.Variant AS Variant,
	|	TemporaryProductsTable.MeasurementUnit AS MeasurementUnit,
	|	TemporaryProductsTable.VATRate AS VATRate,
	|	ISNULL(ProductsPrices.Price * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition / (ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition / (ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition)
	|	END * ISNULL(TemporaryProductsTable.Factor, 1) / ISNULL(ProductsPrices.Factor, 1), 0) AS Price,
	|	TemporaryProductsTable.BundleProduct AS BundleProduct,
	|	TemporaryProductsTable.BundleCharacteristic AS BundleCharacteristic,
	|	TemporaryProductsTable.BundleProduct.BundlePricingStrategy AS BundlePricingStrategy,
	|	TemporaryProductsTable.Quantity AS Quantity
	|INTO PricesTable
	|FROM
	|	TemporaryProductsTable AS TemporaryProductsTable
	|		LEFT JOIN ProductsPrices AS ProductsPrices
	|		ON TemporaryProductsTable.Products = ProductsPrices.Products
	|			AND TemporaryProductsTable.Characteristic = ProductsPrices.Characteristic,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &PriceCurrency AND Company = &Company) AS ExchangeRatePriceKind,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS ExchangeRateDocument
	|WHERE
	|	(TemporaryProductsTable.BundleProduct = VALUE(Catalog.Products.EmptyRef)
	|			OR TemporaryProductsTable.BundleProduct.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.PerComponentPricing))
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryProductsTable.Products,
	|	TemporaryProductsTable.Characteristic,
	|	TemporaryProductsTable.Variant,
	|	TemporaryProductsTable.MeasurementUnit,
	|	TemporaryProductsTable.VATRate,
	|	CASE
	|		WHEN TemporaryProductsTable.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(ProductsPrices.Price * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition / (ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN ExchangeRatePriceKind.Rate * ExchangeRateDocument.Repetition / (ExchangeRateDocument.Rate * ExchangeRatePriceKind.Repetition)
	|			END * ISNULL(TemporaryProductsTable.Factor, 1) / ISNULL(ProductsPrices.Factor, 1) * CalculationBase.BundlePrice / CalculationBase.Price, 0) AS NUMBER(15, 2))
	|	END,
	|	TemporaryProductsTable.BundleProduct,
	|	TemporaryProductsTable.BundleCharacteristic,
	|	TemporaryProductsTable.BundleProduct.BundlePricingStrategy,
	|	TemporaryProductsTable.Quantity
	|FROM
	|	TemporaryProductsTable AS TemporaryProductsTable
	|		LEFT JOIN ProductsPrices AS ProductsPrices
	|		ON TemporaryProductsTable.Products = ProductsPrices.Products
	|			AND TemporaryProductsTable.Characteristic = ProductsPrices.Characteristic
	|		LEFT JOIN CalculationBase AS CalculationBase
	|		ON TemporaryProductsTable.BundleProduct = CalculationBase.BundleProduct
	|			AND TemporaryProductsTable.BundleCharacteristic = CalculationBase.BundleCharacteristic
	|			AND TemporaryProductsTable.Variant = CalculationBase.Variant,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &PriceCurrency AND Company = &Company) AS ExchangeRatePriceKind,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS ExchangeRateDocument
	|WHERE
	|	TemporaryProductsTable.BundleProduct <> VALUE(Catalog.Products.EmptyRef)
	|	AND TemporaryProductsTable.BundleProduct.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.BundlePriceProratedByPrices)
	|	AND &UseBundles
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryProductsTable.Products,
	|	TemporaryProductsTable.Characteristic,
	|	TemporaryProductsTable.Variant,
	|	TemporaryProductsTable.MeasurementUnit,
	|	TemporaryProductsTable.VATRate,
	|	CASE
	|		WHEN TemporaryProductsTable.Quantity = 0
	|			THEN 0
	|		ELSE CAST(ISNULL(TemporaryProductsTable.CostShare / CalculationBase.CostShare * CalculationBase.BundlePrice, 0) / TemporaryProductsTable.Quantity AS NUMBER(15, 2))
	|	END,
	|	TemporaryProductsTable.BundleProduct,
	|	TemporaryProductsTable.BundleCharacteristic,
	|	TemporaryProductsTable.BundleProduct.BundlePricingStrategy,
	|	TemporaryProductsTable.Quantity
	|FROM
	|	TemporaryProductsTable AS TemporaryProductsTable
	|		LEFT JOIN CalculationBase AS CalculationBase
	|		ON TemporaryProductsTable.BundleProduct = CalculationBase.BundleProduct
	|			AND TemporaryProductsTable.BundleCharacteristic = CalculationBase.BundleCharacteristic
	|			AND TemporaryProductsTable.Variant = CalculationBase.Variant
	|WHERE
	|	TemporaryProductsTable.BundleProduct <> VALUE(Catalog.Products.EmptyRef)
	|	AND TemporaryProductsTable.BundleProduct.BundlePricingStrategy = VALUE(Enum.ProductBundlePricingStrategy.BundlePriceProratedByComponentsCost)
	|	AND &UseBundles
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NestedSelect.BundleProduct AS BundleProduct,
	|	NestedSelect.BundleCharacteristic AS BundleCharacteristic,
	|	NestedSelect.Variant AS Variant,
	|	SUM(NestedSelect.Price) AS Price
	|FROM
	|	(SELECT
	|		PricesTable.BundleProduct AS BundleProduct,
	|		PricesTable.BundleCharacteristic AS BundleCharacteristic,
	|		PricesTable.Variant AS Variant,
	|		-PricesTable.Price * PricesTable.Quantity AS Price
	|	FROM
	|		PricesTable AS PricesTable
	|	WHERE
	|		PricesTable.BundleProduct <> VALUE(Catalog.Products.EmptyRef)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CalculationBase.BundleProduct,
	|		CalculationBase.BundleCharacteristic,
	|		CalculationBase.Variant,
	|		CalculationBase.BundlePrice
	|	FROM
	|		CalculationBase AS CalculationBase) AS NestedSelect
	|WHERE
	|	&UseBundles
	|
	|GROUP BY
	|	NestedSelect.BundleProduct,
	|	NestedSelect.BundleCharacteristic,
	|	NestedSelect.Variant
	|
	|HAVING
	|	SUM(NestedSelect.Price) <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PricesTable.Products AS Products,
	|	PricesTable.Characteristic AS Characteristic,
	|	PricesTable.Variant AS Variant,
	|	PricesTable.MeasurementUnit AS MeasurementUnit,
	|	PricesTable.VATRate AS VATRate,
	|	&PriceCurrency AS Currency,
	|	CAST(&PriceKind AS Catalog.PriceTypes).PriceIncludesVAT AS PriceIncludesVAT,
	|	PricesTable.Price AS Price,
	|	PricesTable.Quantity AS Quantity,
	|	PricesTable.BundleProduct AS BundleProduct,
	|	PricesTable.BundleCharacteristic AS BundleCharacteristic
	|FROM
	|	PricesTable AS PricesTable";
		
	Query.SetParameter("ProcessingDate",		DataStructure.Date);
	Query.SetParameter("PriceKind",				PriceKindParameter);
	Query.SetParameter("PriceCurrency",			Common.ObjectAttributeValue(PriceKindParameter, "PriceCurrency"));
	Query.SetParameter("DocumentCurrency",		DataStructure.DocumentCurrency);
	Query.SetParameter("UseBundles",			UseBundles);
	Query.SetParameter("Company",				DataStructure.Company);
	Query.SetParameter("ExchangeRateMethod",	GetExchangeMethod(DataStructure.Company));
	
	QueryResult = Query.ExecuteBatch();
	PricesTable = QueryResult[5].Unload();
	RoundingTable = QueryResult[4].Unload();
	
	DataStructure.Insert("BundlesRoundings", New Array);
	For Each RoundingRow In RoundingTable Do
		RoundingDescription = New Structure;
		RoundingDescription.Insert("BundleProduct", RoundingRow.BundleProduct);
		RoundingDescription.Insert("BundleCharacteristic", RoundingRow.BundleCharacteristic);
		If RoundingRow.Variant > 0 Then
			RoundingDescription.Insert("Variant", RoundingRow.Variant);
		EndIf;
		RoundingDescription.Insert("Rounding", RoundingRow.Price);
		DataStructure.BundlesRoundings.Add(RoundingDescription);
	EndDo;
	
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		If TypeOf(TSRow) = Type("Structure")
			And TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		If TypeOf(TSRow) = Type("Structure")
			And TabularSectionRow.Property("BundleProduct") Then
			SearchStructure.Insert("BundleProduct", TabularSectionRow.BundleProduct);
		EndIf;
		If TypeOf(TSRow) = Type("Structure")
			And TabularSectionRow.Property("BundleCharacteristic") Then
			SearchStructure.Insert("BundleCharacteristic", TabularSectionRow.BundleCharacteristic);
		EndIf;
		If TypeOf(TSRow) = Type("Structure")
			And TabularSectionRow.Property("Variant") Then
			SearchStructure.Insert("Variant", TabularSectionRow.Variant);
		EndIf;
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
					
				EndIf;
				
				If DataStructure.Property("AmountIncludesVAT") 
					And ((DataStructure.AmountIncludesVAT And Not SearchResult[0].PriceIncludesVAT) 
					Or (NOT DataStructure.AmountIncludesVAT And SearchResult[0].PriceIncludesVAT)) Then
					
					Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
					
				EndIf;
				
				If TypeOf(TabularSectionRow) <> Type("Structure")
					Or Not TabularSectionRow.Property("BundleProduct")
					Or Not ValueIsFilled(TabularSectionRow.BundleProduct) Then
					
					TabularSectionRow.Price = DriveClientServer.RoundPrice(Price, Enums.RoundingMethods.Round0_01);
					
				Else
					
					TabularSectionRow.Price = Price;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetPricesTabularSectionBySupplierPriceTypes(DataStructure, DocumentTabularSection) Export
	
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	
	// Variants.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	// MeasurementUnit.
	Array.Add(Type("CatalogRef.UOM"));
	Array.Add(Type("CatalogRef.UOMClassifier"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);	
	
	// Ratio.
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Factor", TypeDescription);
	
	For Each TSRow In DocumentTabularSection Do
		
		NewRow = ProductsTable.Add();
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		NewRow.VATRate		 = TSRow.VATRate;
		
		If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier")
			Or Not ValueIsFilled(TSRow.MeasurementUnit) Then
			NewRow.Factor = 1;
		Else
			NewRow.Factor = TSRow.MeasurementUnit.Factor;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.VATRate,
	|	ProductsTable.Factor
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Execute();
	
	// 2. We will fill prices.
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT ALLOWED
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.VATRate AS VATRate,
	|	ProductsTable.Factor AS Factor,
	|	&SupplierPriceTypes AS SupplierPriceTypes,
	|	ISNULL(ISNULL(CounterpartyPricesSliceLast.Price, CommonPrices.Price), 0) AS Price,
	|	ISNULL(ISNULL(CounterpartyPricesSliceLast.MeasurementUnit, CommonPrices.MeasurementUnit), ProductsTable.MeasurementUnit) AS PriceMeasurementUnit
	|INTO ProductsPricesTable
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Counterparty = &Counterparty) AS CounterpartyPricesSliceLast
	|		ON ProductsTable.Products = CounterpartyPricesSliceLast.Products
	|			AND ProductsTable.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|			AND (CounterpartyPricesSliceLast.Actuality)
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				SupplierPriceTypes = &SupplierPriceTypes
	|					AND Counterparty = &Counterparty
	|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)) AS CommonPrices
	|		ON ProductsTable.Products = CommonPrices.Products
	|			AND (CommonPrices.Actuality)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	ProductsPricesTable.Products AS Products,
	|	ProductsPricesTable.Characteristic AS Characteristic,
	|	ProductsPricesTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsPricesTable.VATRate AS VATRate,
	|	CatalogSupplierPriceTypes.PriceCurrency AS PricesCurrency,
	|	CatalogSupplierPriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(ProductsPricesTable.Price * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|	END * ProductsPricesTable.Factor / ISNULL(PriceUOM.Factor, 1), 0) AS Price
	|FROM
	|	ProductsPricesTable AS ProductsPricesTable
	|		INNER JOIN Catalog.SupplierPriceTypes AS CatalogSupplierPriceTypes
	|		ON ProductsPricesTable.SupplierPriceTypes = CatalogSupplierPriceTypes.Ref
	|		LEFT JOIN Catalog.UOM AS PriceUOM
	|		ON ProductsPricesTable.PriceMeasurementUnit = PriceUOM.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON (CatalogSupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentCurrencyRate";
	
	Query.SetParameter("ProcessingDate",		DataStructure.Date);
	Query.SetParameter("SupplierPriceTypes",	DataStructure.SupplierPriceTypes);
	Query.SetParameter("DocumentCurrency",		DataStructure.DocumentCurrency);
	Query.SetParameter("Company",				DataStructure.Company);
	Query.SetParameter("Counterparty",			DataStructure.Counterparty);
	Query.SetParameter("ExchangeRateMethod",	GetExchangeMethod(DataStructure.Company));
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",		 TabularSectionRow.VATRate);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Consider: amount includes VAT.
				If (DataStructure.AmountIncludesVAT And Not SearchResult[0].PriceIncludesVAT) 
					Or (NOT DataStructure.AmountIncludesVAT And SearchResult[0].PriceIncludesVAT) Then
					Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
				
				TabularSectionRow.Price = Price;
				
			EndIf;
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Recalculates document after changes in "Prices and currency" form.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetProductsPriceByPriceKind(DataStructure) Export
	
	If DataStructure.PriceKind.PriceCalculationMethod = Enums.PriceCalculationMethods.Formula Then
		
		Return PriceGenerationFormulaServerCall.GetPriceByFormula(DataStructure);
		
	EndIf;
	
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PriceTypes.PriceCurrency AS PriceCurrency,
	|	PriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(PricesSliceLast.Price, ISNULL(CommonPrices.Price, 0)) AS Price,
	|	ISNULL(PricesSliceLast.MeasurementUnit, ISNULL(CommonPrices.MeasurementUnit, VALUE(Catalog.UOM.EmptyRef))) AS MeasurementUnit
	|INTO PricesTable
	|FROM
	|	Catalog.PriceTypes AS PriceTypes
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ProcessingDate,
	|				Products = &Products
	|					AND Characteristic = &Characteristic
	|					AND PriceKind = &PriceKind) AS PricesSliceLast
	|		ON PriceTypes.Ref = PricesSliceLast.PriceKind
	|		LEFT JOIN InformationRegister.Prices.SliceLast(
	|				&ProcessingDate,
	|				Products = &Products
	|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|					AND PriceKind = &PriceKind) AS CommonPrices
	|		ON PriceTypes.Ref = CommonPrices.PriceKind
	|WHERE
	|	PriceTypes.Ref = &PriceKind
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PricesTable.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(PricesTable.Price *  CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition))
	|	END * &Factor / ISNULL(CatalogUOM.Factor, 1), 0) AS Price
	|FROM
	|	PricesTable AS PricesTable
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON PricesTable.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON PricesTable.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentCurrencyRate";
	
	Query.SetParameter("ProcessingDate",		BegOfDay(DataStructure.ProcessingDate));
	Query.SetParameter("Products",	 			DataStructure.Products);
	Query.SetParameter("Characteristic",  		DataStructure.Characteristic);
	Query.SetParameter("Factor",	 			DataStructure.Factor);
	Query.SetParameter("DocumentCurrency", 		DataStructure.DocumentCurrency);
	Query.SetParameter("PriceKind",				PriceKindParameter);
	Query.SetParameter("Company",				DataStructure.Company);
	Query.SetParameter("ExchangeRateMethod",	GetExchangeMethod(DataStructure.Company));
	
	Selection = Query.Execute().Select();
	
	PricePrecision = PrecisionAppearancetServer.CompanyPrecision(DataStructure.Company);
	
	Price = 0;
	While Selection.Next() Do
		
		Price = Selection.Price;
		
		// Dynamically calculate the price
		If DynamicPriceKind Then
			
			Price = Price * (1 + Markup / 100);
			
		EndIf;
		
		If DataStructure.Property("AmountIncludesVAT") And DataStructure.Property("VATRate")
			And ((DataStructure.AmountIncludesVAT And Not Selection.PriceIncludesVAT)
			Or (NOT DataStructure.AmountIncludesVAT And Selection.PriceIncludesVAT)) Then
			Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
		EndIf;
		
		Price = DriveClientServer.RoundPrice(Price, Enums.RoundingMethods.Round0_01,, PricePrecision);
		
	EndDo;
	
	Return Price;
	
EndFunction

// Recalculates document after changes in "Prices and currency" form.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetPriceProductsBySupplierPriceTypes(DataStructure) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CatalogSupplierPriceTypes.PriceCurrency AS PriceCurrency,
	|	CatalogSupplierPriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(CounterpartyPricesSliceLast.Price, ISNULL(CommonPrices.Price, 0)) AS Price,
	|	ISNULL(CounterpartyPricesSliceLast.MeasurementUnit, ISNULL(CommonPrices.MeasurementUnit, VALUE(Catalog.UOM.EmptyRef))) AS MeasurementUnit
	|INTO PricesTable
	|FROM
	|	Catalog.SupplierPriceTypes AS CatalogSupplierPriceTypes
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				Products = &Products
	|					AND Characteristic = &Characteristic
	|					AND SupplierPriceTypes = &SupplierPriceTypes
	|					AND Counterparty = &Counterparty) AS CounterpartyPricesSliceLast
	|		ON CatalogSupplierPriceTypes.Ref = CounterpartyPricesSliceLast.SupplierPriceTypes
	|			AND (CounterpartyPricesSliceLast.Actuality)
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(
	|				&ProcessingDate,
	|				Products = &Products
	|					AND Characteristic = VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|					AND SupplierPriceTypes = &SupplierPriceTypes
	|					AND Counterparty = &Counterparty) AS CommonPrices
	|		ON CatalogSupplierPriceTypes.Ref = CommonPrices.SupplierPriceTypes
	|			AND (CommonPrices.Actuality)
	|WHERE
	|	CatalogSupplierPriceTypes.Ref = &SupplierPriceTypes
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	PricesTable.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(PricesTable.Price * CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|			THEN RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition)
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN 1 / (RateCurrencyTypePrices.Rate * DocumentCurrencyRate.Repetition / (DocumentCurrencyRate.Rate * RateCurrencyTypePrices.Repetition))
	|	END * &Factor / ISNULL(CatalogUOM.Factor, 1), 0) AS Price
	|FROM
	|	PricesTable AS PricesTable
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON PricesTable.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Company = &Company) AS RateCurrencyTypePrices
	|		ON PricesTable.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRate.SliceLast(&ProcessingDate, Currency = &DocumentCurrency AND Company = &Company) AS DocumentCurrencyRate";
	
	Query.SetParameter("ProcessingDate",	 	DataStructure.ProcessingDate);
	Query.SetParameter("Products",	 			DataStructure.Products);
	Query.SetParameter("Characteristic",  		DataStructure.Characteristic);
	Query.SetParameter("Factor",	 			DataStructure.Factor);
	Query.SetParameter("DocumentCurrency", 		DataStructure.DocumentCurrency);
	Query.SetParameter("SupplierPriceTypes",	DataStructure.SupplierPriceTypes);
	Query.SetParameter("Counterparty",			DataStructure.Counterparty);
	Query.SetParameter("Company",				DataStructure.Company);
	Query.SetParameter("ExchangeRateMethod", 	GetExchangeMethod(DataStructure.Company));
	
	Selection = Query.Execute().Select();
	
	Price = 0;
	While Selection.Next() Do
		
		Price = Selection.Price;
		
		// Consider: amount includes VAT.
		If (DataStructure.AmountIncludesVAT And Not Selection.PriceIncludesVAT)
			Or (Not DataStructure.AmountIncludesVAT And Selection.PriceIncludesVAT) Then
			Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
			Price = DriveClientServer.RoundPrice(Price, Enums.RoundingMethods.Round0_01);
		EndIf;
		
	EndDo;
	
	Return Price;
	
EndFunction

// Get working time standard.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetWorkTimeRate(DataStructure) Export
	
	Query = New Query("SELECT
	|	SliceLastTimeStandards.Norm AS Norm
	|FROM
	|	InformationRegister.StandardTime.SliceLast(
	|			&ProcessingDate,
	|			Products = &Products
	|				AND Characteristic = &Characteristic) AS SliceLastTimeStandards");
	
	Query.SetParameter("Products", DataStructure.Products);
	Query.SetParameter("Characteristic", DataStructure.Characteristic);
	Query.SetParameter("ProcessingDate", DataStructure.ProcessingDate);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Return Selection.Norm;		
	EndDo;
	
	Return 1;
	
EndFunction

// Receives data set: Amount, VAT amount.
//
Function GetTabularSectionRowSum(DataStructure) Export
	
	If DataStructure.Property("Quantity") And DataStructure.Property("Price") Then
		
		DataStructure.Amount = DataStructure.Quantity * DataStructure.Price;
		
	EndIf;
	
	If DataStructure.Property("DiscountMarkupPercent") Then
		
		If DataStructure.DiscountMarkupPercent = 100 Then
			
			DataStructure.Amount = 0;
			
		ElsIf DataStructure.DiscountMarkupPercent <> 0 Then
			
			DataStructure.Amount = DataStructure.Amount * (1 - DataStructure.DiscountMarkupPercent / 100);
			
		EndIf;
		
	EndIf;
	
	If DataStructure.Property("VATAmount") Then
		
		VATRate = DriveReUse.GetVATRateValue(DataStructure.VATRate);
		DataStructure.VATAmount = ?(DataStructure.AmountIncludesVAT, DataStructure.Amount - (DataStructure.Amount) / ((VATRate + 100) / 100), DataStructure.Amount * VATRate / 100);
		DataStructure.Total = DataStructure.Amount + ?(DataStructure.AmountIncludesVAT, 0, DataStructure.VATAmount);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function TableRoundingOrders() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Order", New TypeDescription("EnumRef.RoundingMethods"));
	Result.Columns.Add("Value", New TypeDescription("Number", New NumberQualifiers(15, 2)));
	
	For Each Value In Metadata.Enums.RoundingMethods.EnumValues Do
		Row = Result.Add();
		Row.Order = Enums.RoundingMethods[Value.Name];
		Row.Value = DriveClientServer.NumberByRoundingOrder(Row.Order);
	EndDo;
	
	Return Result;
	
EndFunction

// Deletes records from the Counterparties products prices information register.
//
Procedure DeleteVendorPrices(DocumentRef) Export

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CounterpartyPrices.Period AS Period,
	|	CounterpartyPrices.SupplierPriceTypes AS SupplierPriceTypes,
	|	CounterpartyPrices.Counterparty AS Counterparty,
	|	CounterpartyPrices.Products AS Products,
	|	CounterpartyPrices.Characteristic AS Characteristic
	|FROM
	|	InformationRegister.CounterpartyPrices AS CounterpartyPrices
	|WHERE
	|	CounterpartyPrices.DocumentRecorder = &DocumentRecorder";
	
	Query.SetParameter("DocumentRecorder", DocumentRef);
	
	QueryResult = Query.Execute();
	RecordsTable = QueryResult.Unload();
	
	For Each TableRow In RecordsTable Do
		RecordSet = InformationRegisters.CounterpartyPrices.CreateRecordSet();
		RecordSet.Filter.Period.Set(TableRow.Period);
		RecordSet.Filter.SupplierPriceTypes.Set(TableRow.SupplierPriceTypes);
		RecordSet.Filter.Counterparty.Set(TableRow.Counterparty);
		RecordSet.Filter.Products.Set(TableRow.Products);
		RecordSet.Filter.Characteristic.Set(TableRow.Characteristic);
		RecordSet.Write();
	EndDo;

EndProcedure

#Region DiscountCards

// Function returns a structure with the start date and accumulation period
// end by discount card and also the period text presentation.
//
Function GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard) Export

	If Not ValueIsFilled(DiscountDate) Then
		DiscountDate = CurrentSessionDate();
	EndIf;
	
	PeriodPresentation = "";
	If DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.EntirePeriod Then
		BeginOfPeriod = '00010101';
		EndOfPeriod = '00010101';
		PeriodPresentation = "for all time";
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Current Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			BeginOfPeriod = BegOfYear(DiscountDate);
			PeriodPresentation = "for the current year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			BeginOfPeriod = BegOfQuarter(DiscountDate);
			PeriodPresentation = "for the current quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			BeginOfPeriod = BegOfMonth(DiscountDate);
			PeriodPresentation = "for the current month";
		EndIf;
		EndOfPeriod = EndOfDay(DiscountDate);
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Past Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			DatePrePeriod = AddMonth(DiscountDate, -12);
			BeginOfPeriod = BegOfYear(DatePrePeriod);
			EndOfPeriod = EndOfYear(DatePrePeriod);
			PeriodPresentation = "for the past year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			DatePrePeriod = AddMonth(DiscountDate, -3);
			BeginOfPeriod = BegOfQuarter(DatePrePeriod);
			EndOfPeriod = EndOfQuarter(DatePrePeriod);
			PeriodPresentation = "for the past year quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			DatePrePeriod = AddMonth(DiscountDate, -1);
			BeginOfPeriod = BegOfMonth(DatePrePeriod);
			EndOfPeriod = EndOfMonth(DatePrePeriod);
			PeriodPresentation = "for the past month";
		EndIf;
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Last Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			DatePrePeriod = AddMonth(DiscountDate, -12);
			PeriodPresentation = "for the past year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			DatePrePeriod = AddMonth(DiscountDate, -3);
			PeriodPresentation = "for the last quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			DatePrePeriod = AddMonth(DiscountDate, -1);
			PeriodPresentation = "for the last month";
		EndIf;		
		BeginOfPeriod = BegOfDay(DatePrePeriod);
		EndOfPeriod = BegOfDay(DiscountDate) - 1; // Previous day end.
	Else
		BeginOfPeriod = '00010101';
		EndOfPeriod = '00010101';
		PeriodPresentation = "";
	EndIf;
	
	Return New Structure("BeginOfPeriod, EndOfPeriod, PeriodPresentation", BeginOfPeriod, EndOfPeriod, PeriodPresentation);

EndFunction

// Returns the discount percent by discount card.
//
// Parameters:
//  DiscountCard - CatalogRef.DiscountCards - Ref on discount card.
//
// Returns: 
//   Number - discount percent.
//
Function CalculateDiscountPercentByDiscountCard(Val DiscountDate, DiscountCard, AdditionalParameters = Undefined) Export
	
	Var BeginOfPeriod, EndOfPeriod;
	
	If Not ValueIsFilled(DiscountDate) Then
		DiscountDate = CurrentSessionDate();
	EndIf;
	
	If DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount Then
		
		If AdditionalParameters <> Undefined And AdditionalParameters.GetSalesAmount Then
			AccumulationPeriod = GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard.Ref);

			AdditionalParameters.Insert("PeriodPresentation", AccumulationPeriod.PeriodPresentation);
			
			Query = New Query("SELECT ALLOWED
			                      |	ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
			                      |FROM
			                      |	AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales");

			Query.SetParameter("DateBeg", AccumulationPeriod.BeginOfPeriod);
			Query.SetParameter("DateEnd", AccumulationPeriod.EndOfPeriod);
			Query.SetParameter("DiscountCard", DiscountCard.Ref);
	        
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				AdditionalParameters.Amount = Selection.AmountTurnover;
			Else
				AdditionalParameters.Amount = 0;
			EndIf;		
		
		EndIf;
		
		Return DiscountCard.Owner.Discount;
		
	Else
		
		AccumulationPeriod = GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard.Ref);
		
		Query = New Query("SELECT ALLOWED
		                      |	Thresholds.Discount AS Discount,
		                      |	Thresholds.LowerBound AS LowerBound
		                      |INTO TU_Thresholds
		                      |FROM
		                      |	Catalog.DiscountCardTypes.ProgressiveDiscountLimits AS Thresholds
		                      |WHERE
		                      |	Thresholds.Ref = &KindDiscountCard
		                      |;
		                      |
		                      |////////////////////////////////////////////////////////////////////////////////
		                      |SELECT ALLOWED
		                      |	RegThresholds.Discount AS Discount
		                      |FROM
		                      |	(SELECT
		                      |		ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
		                      |	FROM
		                      |		AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales) AS RegSales
		                      |		INNER JOIN (SELECT
		                      |			Thresholds.LowerBound AS LowerBound,
		                      |			Thresholds.Discount AS Discount
		                      |		FROM
		                      |			TU_Thresholds AS Thresholds) AS RegThresholds
		                      |		ON (RegThresholds.LowerBound <= RegSales.AmountTurnover)
		                      |		INNER JOIN (SELECT
		                      |			MAX(RegThresholds.LowerBound) AS LowerBound
		                      |		FROM
		                      |			(SELECT
		                      |				ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
		                      |			FROM
		                      |				AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales) AS RegSales
		                      |				INNER JOIN (SELECT
		                      |					Thresholds.LowerBound AS LowerBound
		                      |				FROM
		                      |					TU_Thresholds AS Thresholds) AS RegThresholds
		                      |				ON (RegThresholds.LowerBound <= RegSales.AmountTurnover)) AS RegMaxThresholds
		                      |		ON (RegMaxThresholds.LowerBound = RegThresholds.LowerBound)");

		Query.SetParameter("DateBeg", AccumulationPeriod.BeginOfPeriod);
		Query.SetParameter("DateEnd", AccumulationPeriod.EndOfPeriod);
		Query.SetParameter("DiscountCard", DiscountCard.Ref);
        Query.SetParameter("KindDiscountCard", DiscountCard.Owner);

		If AdditionalParameters <> Undefined And AdditionalParameters.GetSalesAmount Then
			AdditionalParameters.Insert("PeriodPresentation", AccumulationPeriod.PeriodPresentation);
			
			Query.Text = Query.Text + ";
			                              |////////////////////////////////////////////////////////////////////////////////
			                              |SELECT ALLOWED
			                              |	SalesWithCardBasedDiscountsTurnovers.AmountTurnover
			                              |FROM
			                              |	AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS SalesWithCardBasedDiscountsTurnovers";
			MResults = Query.ExecuteBatch();
			
			Selection = MResults[1].Select();
			If Selection.Next() Then
				CumulativeDiscountPercent = Selection.Discount;
			Else
				CumulativeDiscountPercent = 0;
			EndIf;		
			
			SelectionByAmountOfSales = MResults[2].Select();
			If SelectionByAmountOfSales.Next() Then
				AdditionalParameters.Amount = SelectionByAmountOfSales.AmountTurnover;
			Else
				AdditionalParameters.Amount = 0;
			EndIf;
			
			Return CumulativeDiscountPercent;

		Else
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CumulativeDiscountPercent = Selection.Discount;
			Else
				CumulativeDiscountPercent = 0;
			EndIf;		
				
			Return CumulativeDiscountPercent;
		EndIf;
		
	EndIf;
	
EndFunction

// Returns the discount percentage by discount type.
//
// Parameters:
//  DataStructure - Structure - Structure of attributes required during recalculation
//
// Returns: 
//   Number - discount percent.
//
Function GetDiscountPercentByDiscountMarkupKind(DiscountMarkupKind) Export
	
	Return DiscountMarkupKind.Percent;
	
EndFunction

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsGeneratingMessagesTextsOnPostingErrors

// Generates petty cash presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - variant presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function CashBankAccountPresentation(BankAccountCashPresentation,
										   PaymentMethodRepresentation = "",
										   CurrencyPresentation = "") Export
	
	PresentationString = TrimAll(BankAccountCashPresentation);
	
	If ValueIsFilled(PaymentMethodRepresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(PaymentMethodRepresentation);
	EndIf;
	
	If ValueIsFilled(CurrencyPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates a string of products presentation considering variants and series.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  CharacteristicPresentation - String - variant presentation.
//  BatchPresentation - String - batch presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfProducts(ProductsPresentation,
	                              CharacteristicPresentation  = "",
	                              BatchPresentation          = "",
								  SalesOrderPresentation = "") Export
	
	PresentationString = TrimAll(ProductsPresentation);
	
	If ValueIsFilled(CharacteristicPresentation)Then
		PresentationString = PresentationString + " / " + TrimAll(CharacteristicPresentation);
	EndIf;
	
	If  ValueIsFilled(BatchPresentation) Then
		PresentationString = PresentationString + " / " + TrimAll(BatchPresentation);
	EndIf;
	
	If ValueIsFilled(SalesOrderPresentation) Then
		PresentationString = PresentationString + " / " + TrimAll(SalesOrderPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates counterparty presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - variant presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function CounterpartyPresentation(CounterpartyPresentation,
	                             ContractPresentation = "",
	                             DocumentPresentation = "",
	                             OrderPresentation = "",
	                             CalculationTypesPresentation = "") Export
	
	PresentationString = TrimAll(CounterpartyPresentation);
	
	If ValueIsFilled(ContractPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(ContractPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(DocumentPresentation);
	EndIf;
	
	If ValueIsFilled(OrderPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(OrderPresentation);
	EndIf;
	
	If ValueIsFilled(CalculationTypesPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CalculationTypesPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates a business unit presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - variant presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfStructuralUnit(StructuralUnitPresentation,
	                             PresentationCell = "") Export
	
	PresentationString = TrimAll(StructuralUnitPresentation);
	
	If ValueIsFilled(PresentationCell) Then
		PresentationString = PresentationString + " (" + PresentationCell + ")";
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates petty cash presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - variant presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfAccountablePerson(AdvanceHolderPresentation,
	                       			  CurrencyPresentation = "",
									  DocumentPresentation = "") Export
	
	PresentationString = TrimAll(AdvanceHolderPresentation);
	
	If ValueIsFilled(CurrencyPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(DocumentPresentation);
	EndIf;    
	
	Return PresentationString;
	
EndFunction

// The function returns individual passport details
// as a string used in print forms.
//
// Parameters
//  DataStructure - Structure - ref to Ind and date
//                 
// Returns:
//   Row      - String containing passport data
//
Function GetPassportDataAsString(DataStructure) Export

	If Not ValueIsFilled(DataStructure.Ind) Then
		Return NStr("en = 'There is no data on the identity card.'; ru = 'Отсутствуют данные об удостоверении личности.';pl = 'Brak danych o dowodzie osobistym.';es_ES = 'No hay datos en la tarjeta de identidad.';es_CO = 'No hay datos en la tarjeta de identidad.';tr = 'Kimlik kartında veri bulunmamaktadır.';it = 'Non ci sono dati sulla carta di identità.';de = 'Es gibt keine Daten auf dem Ausweis.'");
	EndIf; 
	
	Query = New Query("SELECT ALLOWED
	                  |	LegalDocuments.DocumentKind,
	                  |	LegalDocuments.Number,
	                  |	LegalDocuments.IssueDate,
	                  |	LegalDocuments.Authority
	                  |FROM
	                  |	Catalog.LegalDocuments AS LegalDocuments
	                  |WHERE
	                  |	LegalDocuments.Owner = &Owner
	                  |
	                  |ORDER BY
	                  |	LegalDocuments.IssueDate DESC");
	
	Query.SetParameter("Owner", DataStructure.Ind);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return NStr("en = 'There is no data on the identity card.'; ru = 'Отсутствуют данные об удостоверении личности.';pl = 'Brak danych o dowodzie osobistym.';es_ES = 'No hay datos en la tarjeta de identidad.';es_CO = 'No hay datos en la tarjeta de identidad.';tr = 'Kimlik kartında veri bulunmamaktadır.';it = 'Non ci sono dati sulla carta di identità.';de = 'Es gibt keine Daten auf dem Ausweis.'");
	Else
		PassportData	= QueryResult.Unload()[0];
		DocumentKind	= PassportData.DocumentKind;
		Number			= PassportData.Number;
		IssueDate		= PassportData.IssueDate;
		Authority		= PassportData.Authority;
		
		If Not (NOT ValueIsFilled(IssueDate)
			And Not ValueIsFilled(DocumentKind)
			And Not ValueIsFilled(Number + Authority)) Then

			PersonalDataList = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 #%2, Issued: %3, %4'; ru = '%1 №%2, Выдан: %3 года, %4';pl = '%1 #%2, Wydany: %3, %4';es_ES = '%1 #%2, Emitido: %3, %4';es_CO = '%1 #%2, Emitido: %3, %4';tr = '%1 no %2, Yayımlama tarihi: %3, %4';it = '%1 #%2, emesso: %3, %4';de = '%1 Nr %2, Ausgestellt: %3, %4'"),
			?(DocumentKind.IsEmpty(),"","" + DocumentKind + ", "), Number, Format(IssueDate,"DLF=DD"), Authority);
			
			Return PersonalDataList;

		Else
			Return NStr("en = 'There is no data on the identity card.'; ru = 'Отсутствуют данные об удостоверении личности.';pl = 'Brak danych o dowodzie osobistym.';es_ES = 'No hay datos en la tarjeta de identidad.';es_CO = 'No hay datos en la tarjeta de identidad.';tr = 'Kimlik kartında veri bulunmamaktadır.';it = 'Non ci sono dati sulla carta di identità.';de = 'Es gibt keine Daten auf dem Ausweis.'");
		EndIf;
	EndIf;

EndFunction

// Function returns structural units type presentation.
//
Function GetStructuralUnitTypePresentation(StructuralUnitType)
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		StructuralUnitTypePresentation = Nstr("en = 'department'; ru = 'Подразделение';pl = 'dział';es_ES = 'departamento';es_CO = 'departamento';tr = 'bölüm';it = 'reparto';de = 'abteilung'");
	ElsIf StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		Or StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		StructuralUnitTypePresentation = Nstr("en = 'POS'; ru = 'Складской учет';pl = 'Magazyny';es_ES = 'TPV';es_CO = 'TPV';tr = 'POS';it = 'POS';de = 'POS'");
	Else
		StructuralUnitTypePresentation = Nstr("en = 'warehouse'; ru = 'Склад';pl = 'magazyn';es_ES = 'almacén';es_CO = 'almacén';tr = 'ambar';it = 'magazzino';de = 'lager'");
	EndIf;
	
	Return StructuralUnitTypePresentation
	
EndFunction

#EndRegion

#Region ProcedureOfPostingErrorsMessagesIssuing

// The procedure informs of errors that occurred when posting by register Inventory in warehouses.
//
Procedure ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleTemplate = ErrorTitle + " " + NStr("en = 'Insufficient quantity on %1 %2'; ru = 'Недостаточное количество %1 %2';pl = 'Niewystarczająca ilość w %1 %2';es_ES = 'Cantidad insuficiente en %1 %2';es_CO = 'Cantidad insuficiente en %1 %2';tr = '%1 %2 için yetersiz miktar';it = 'Quantità non sufficiente in %1 %2';de = 'Zu geringe Menge an %1 %2'");
	
	MessagePattern = NStr("en = 'Product: %1, available %2 %3, shortage %4 %3'; ru = 'Номенклатура: %1, в наличии %2 %3, не хватает %4 %3';pl = 'Produkt: %1, dostępne %2 %3, niedobór%4 %3';es_ES = 'Producto:%1, disponible %2 %3, falta %4 %3';es_CO = 'Producto:%1, disponible %2 %3, falta %4 %3';tr = 'Ürünler: %1, mevcut %2 %3, yetersiz %4 %3';it = 'Articolo: %1, disponibile %2 %3, deficit %4 %3';de = 'Produkt: %1, verfügbar %2 %3, Fehlmenge %4 %3'");
		
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				Or (NOT UseSeveralDepartments And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
			EndIf;
			MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTitleTemplate,
				GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
				PresentationOfStructuralUnit);
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, PresentationOfProducts, String(RecordsSelection.BalanceInventoryInWarehouses),
						TrimAll(RecordsSelection.MeasurementUnitPresentation), String(-RecordsSelection.QuantityBalanceInventoryInWarehouses));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The entry results in negative inventory in the ""Goods awaiting customs clearance"" register'; ru = 'При проведении документа в регистре ""Товары, ожидающие таможенной очистки"" образуется отрицательный остаток.';pl = 'Wpis prowadzi do ujemnego stanu zapasów w rejestrze rejestracyjnym ""Towary oczekujące na odprawę celną""';es_ES = 'La entrada da como resultado un inventario negativo en el registro de ""Mercancías en espera de despacho de aduanas""';es_CO = 'La entrada da como resultado un inventario negativo en el registro de ""Mercancías en espera de despacho de aduanas""';tr = 'Bu giriş, ""Gümrük tasfiyesini bekleyen mallar"" sicilinde negatif stok ile sonuçlandı';it = 'I risultati di inserimento nell''inventario negativo nel registro ""Merci in attesa di dichiarazione doganale""';de = 'Die Buchung führt zu einem negativen Bestand im Register ""Waren, die auf die Zollabfertigung warten""'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance %2 %3, shortage %4 %3'; ru = 'Номенклатура: %1, остаток %2 %3, не хватает %4 %3';pl = 'Produkt: %1, bilans %2 %3, niedobór %4 %3';es_ES = 'Producto: %1, saldo%2 %3, falta%4 %3';es_CO = 'Producto: %1, saldo%2 %3, falta%4 %3';tr = 'Ürün: %1, bakiye %2 %3, eksiklik %4 %3';it = 'Articolo: %1, saldo %2 %3, deficit %4 %3';de = 'Produkt: %1, ausgleichen %2 %3, Fehlmenge %4 %3'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic, RecordsSelection.Batch);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.QuantityBalanceBeforeChange),
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToWorkInProgressRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient quantity in Work-in-progress register:'; ru = 'Недостаточное количество в регистре ""Незавершенное производство"":';pl = 'Niewystarczająca ilość w rejestrze Praca w toku:';es_ES = 'Cantidad insuficiente en el registro de Trabajo en progreso:';es_CO = 'Cantidad insuficiente en el registro de Trabajo en progreso:';tr = 'İşlem bitişi kaydında yetersiz miktar:';it = 'Quantità insufficiente nel registro Lavori in corso:';de = 'Unzureichende Menge im Register von Arbeit in Bearbeitung:'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	While RecordsSelection.Next() Do
		
		If TypeOf(RecordsSelection.Products) = Type("CatalogRef.Products") Then
		
			MessagePattern = NStr("en = 'Product: %1, balance %2 %3, shortage %4 %3'; ru = 'Номенклатура: %1, остаток %2 %3, не хватает %4 %3';pl = 'Produkt: %1, bilans %2 %3, niedobór %4 %3';es_ES = 'Producto: %1, saldo%2 %3, falta%4 %3';es_CO = 'Producto: %1, saldo%2 %3, falta%4 %3';tr = 'Ürün: %1, bakiye %2 %3, eksiklik %4 %3';it = 'Articolo: %1, saldo %2 %3, deficit %4 %3';de = 'Produkt: %1, ausgleichen %2 %3, Fehlmenge %4 %3'");
			
			PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessagePattern,
				PresentationOfProducts,
				RecordsSelection.QuantityBalanceBeforeChange,
				TrimAll(RecordsSelection.MeasurementUnit),
				-RecordsSelection.QuantityBalance);
			
		Else
			
			MessagePattern = NStr("en = 'Activity: %1, balance %2, shortage %3'; ru = 'Вид деятельности: %1, остаток %2, недостача %3';pl = 'Rodzaj działalności: %1, saldo %2, niedobór %3';es_ES = 'Actividad: %1, saldo %2, falta%3';es_CO = 'Actividad: %1, saldo %2, falta%3';tr = 'Aktivite: %1, bakiye %2, eksiklik %3';it = 'Attività: %1, saldo %2, deficit %3';de = 'Aktivität: %1, ausgeglichen%2, Fehlmenge%3'");
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessagePattern,
				RecordsSelection.Products,
				RecordsSelection.QuantityBalanceBeforeChange,
				-RecordsSelection.QuantityBalance);
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors occurred while posting by the
// Inventory on warehouses register for the structural units list.
//
Procedure ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + " " + NStr("en = 'Insufficient quantity'; ru = 'Недостаточное количество';pl = 'Niewystarczająca ilość';es_ES = 'Cantidad insuficiente';es_CO = 'Cantidad insuficiente';tr = 'Yetersiz miktar';it = 'Quantità insufficiente';de = 'Zu geringe Menge'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, %2 %3, available %4 %5, shortage %6 %5'; ru = 'Номенклатура: %1, %2 %3, в наличии %4 %5, не хватает %6 %5';pl = 'Produkt: %1, %2 %3, dostępne %4 %5, niedobór %6 %5';es_ES = 'Producto: %1, %2 %3, disponible %4 %5, falta%6 %5';es_CO = 'Producto: %1, %2 %3, disponible %4 %5, falta%6 %5';tr = 'Ürün: %1, %2 %3, mevcut %4 %5, yetersiz %6 %5';it = 'Articolo: %1, %2 %3, disponibile %4 %5, deficit %6 %5';de = 'Produkt: %1, %2 %3, verfügbar %4 %5, Fehlmenge%6 %5'");
	
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If (NOT UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
			Or (NOT UseSeveralDepartments And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
			PresentationOfStructuralUnit = "";
		Else
			PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, 
																				RecordsSelection.CharacteristicPresentation,
																				RecordsSelection.BatchPresentation);
																				
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern, PresentationOfProducts,
																				GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
																				PresentationOfStructuralUnit,
																				String(RecordsSelection.BalanceInventoryInWarehouses),
																				TrimAll(RecordsSelection.MeasurementUnitPresentation),
																				String(-RecordsSelection.QuantityBalanceInventoryInWarehouses),
																				TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory.
//
Procedure ShowMessageAboutPostingToInventoryRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleTemplate = ErrorTitle + " " + NStr("en = 'Insufficient quantity on %1 %2'; ru = 'Недостаточное количество (%1 %2)';pl = 'Niewystarczająca ilość w %1 %2';es_ES = 'Cantidad insuficiente en %1%2';es_CO = 'Cantidad insuficiente en %1%2';tr = '%1 %2 için yetersiz miktar';it = 'Quantità non sufficiente in %1 %2';de = 'Zu geringe Menge an %1 %2'");
	
	MessagePattern = NStr("en = 'Product: %1, available %2 %3, shortage %4 %5'; ru = 'Номенклатура: %1, в наличии %2 %3, не хватает %4 %5';pl = 'Produkt: %1, dostępne %2 %3, niedobór %4 %5';es_ES = 'Producto: %1, disponible %2 %3, falta %4 %5';es_CO = 'Producto: %1, disponible %2 %3, falta %4 %5';tr = 'Ürün: %1, mevcut %2 %3, yetersiz %4 %5';it = 'Articolo: %1, disponibile %2 %3, deficit %4 %5';de = 'Produkt: %1, verfügbar%2 %3, Fehlmenge %4 %5'");
	
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				Or (NOT UseSeveralDepartments And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				PresentationOfStructuralUnit = TrimAll(RecordsSelection.StructuralUnitPresentation);
			EndIf;
			MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTitleTemplate,
				GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
				PresentationOfStructuralUnit);
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutNegativeAmountInInventoryRegister(DocObject, RecordsSelection, Cancel) Export
	
	MessagePattern = NStr("en = 'The production cost (in %1) is negative (%2).
                           |It is calculated as the difference between the finished products amount and by-products amount. 
                           |It is recommended that you check the by-products quantity or price and edit them if required.'; 
                           |ru = 'Себестоимость производства (в %1) отрицательная (%2).
                           |Рассчитывается как разница между количеством готовой продукции и количеством побочной продукции. 
                           |Рекомендуется проверить количество или цену побочной продукции и при необходимости изменить их.';
                           |pl = 'Koszt produkcji (w %1) jest ujemny (%2).
                           |Jest on obliczany jako różnica między kwotą gotowych produktów a kwotą produktów ubocznych. 
                           |Zaleca się sprawdzenie ilości produktów ubocznych lub ceny i edytowanie ich w razie potrzeby.';
                           |es_ES = 'El coste de producción (en %1) es negativo (%2).
                           |Se calcula como la diferencia entre el importe de los productos acabados y el importe de los trozos y deterioros. 
                           |Se recomienda verificar la cantidad o el precio de los trozos y deterioros y corregirlos si es necesario.';
                           |es_CO = 'El coste de producción (en %1) es negativo (%2).
                           |Se calcula como la diferencia entre el importe de los productos acabados y el importe de los trozos y deterioros. 
                           |Se recomienda verificar la cantidad o el precio de los trozos y deterioros y corregirlos si es necesario.';
                           |tr = 'Üretim maliyeti (%1) negatif (%2).
                           |Bitmiş ürünlerin tutarı ile yan ürünlerin tutarı arasındaki fark olarak hesaplanır. 
                           |Yan ürünlerin miktarını ve fiyatını kontrol edip, gerekirse düzeltmeniz önerilir.';
                           |it = 'Il costo di produzione (in %1) è negativo (%2). 
                           |Viene calcolato come la differenza tra l''importo degli articoli finiti e l''importo di scarti e residui. 
                           |Si consiglia di controllare la quantità di scarti e residui o il loro prezzo e modificarli se richiesto.';
                           |de = 'Die Produktionskosten (in %1) sind negativ (%2).
                           |Es wird als Differenz zwischen der Menge der Fertigprodukte und der Menge der Nebenprodukte berechnet. 
                           |Es wird empfohlen, die Menge oder den Preis der Nebenprodukte zu überprüfen und sie bei Bedarf zu bearbeiten.'");
	
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			RecordsSelection.AmountBalanceInventory);
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of posting errors
// by the Reserves register for a business unit list.
//
Procedure ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	MessageTitleText = NStr("en = 'Cannot post the document. The product quantity in stock is insufficient.'; ru = 'Не удалось провести документ. Недостаточно товара на складе.';pl = 'Nie można zatwierdzić dokumentu. Ilość produktu na stanie jest niewystarczająca.';es_ES = 'No se puede enviar el documento. La cantidad de producto en stock es insuficiente.';es_CO = 'No se puede enviar el documento. La cantidad de producto en stock es insuficiente.';tr = 'Belge kaydedilemiyor. Stoktaki ürün miktarı yetersiz.';it = 'Impossibile pubblicare il documento. La quantità di prodotto in stock non è sufficiente.';de = 'Fehler beim Buchen des Dokuments. Die Produktmenge im Lager ist ungenügend.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1.
							|Warehouse: %2, %3.
							|Available product quantity: %4 %5.
							|Product shortage: %6 %5. '; 
							|ru = 'Номенклатура: %1.
							|Склад: %2, %3.
							|Доступное количество: %4 %5.
							|Не хватает: %6 %5. ';
							|pl = 'Produkt: %1.
							|Magazyn: %2, %3.
							|Ilość dostępnych produktów: %4 %5.
							|Niedobór produktów: %6 %5. ';
							|es_ES = 'Producto: %1.
							|Almacén: %2, %3.
							|Cantidad de producto disponible: %4 %5.
							|Falta de producto: %6 %5. ';
							|es_CO = 'Producto: %1.
							|Almacén: %2, %3.
							|Cantidad de producto disponible: %4%5.
							|Falta de producto: %6%5. ';
							|tr = 'Ürün: %1.
							|Ambar: %2, %3.
							|Mevcut ürün miktarı: %4 %5.
							|Ürün eksiği: %6 %5. ';
							|it = 'Prodotto: %1.
							|Magazzino: %2, %3.
							|Quantità di prodotto disponibile: %4 %5.
							|Carenza di prodotto: %6 %5. ';
							|de = 'Produkt: %1.
							|Lager: %2, %3.
							|Verfügbare Produktmenge: %4 %5.
							|Produktfehlmenge: %6 %5. '");
	
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If (NOT UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
			Or (NOT UseSeveralDepartments And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
			PresentationOfStructuralUnit = "";
		Else
			PresentationOfStructuralUnit = TrimAll(RecordsSelection.StructuralUnitPresentation);
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
			PresentationOfStructuralUnit,
			String(RecordsSelection.BalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceInventory));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory transferred.
//
Procedure ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleTemplate = ErrorTitle + " " + NStr("en = 'Insufficient quantity transferred to %1'; ru = 'В %1 передано недостаточное количество';pl = 'Niewystarczającą ilość przekazano do %1';es_ES = 'La cantidad insuficiente se transfiere a %1';es_CO = 'La cantidad insuficiente se transfiere a %1';tr = '%1''a aktarılan yetersiz miktar';it = 'Quantità insufficiente trasferita a %1';de = 'Unzureichende Menge übergeben an %1'");
	MessagePattern = NStr("en = 'Product: %1,'; ru = 'Номенклатура: %1,';pl = 'Produkt: %1,';es_ES = 'Producto:%1,';es_CO = 'Producto:%1,';tr = 'Ürün: %1,';it = 'Articolo: %1,';de = 'Produkt: %1,'");
	
	TitleInDetailsShow = True;
	PresentationCurrency = GetPresentationCurrency(DocObject.Company);
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTitleTemplate,
				TrimAll(RecordsSelection.CounterpartyPresentation));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts);
		
		If RecordsSelection.QuantityBalanceStockTransferredToThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'available %1 %2, shortage %3 %4'; ru = 'в наличии %1 %2, не хватает %3 %4';pl = 'dostępne %1 %2, niedobór %3 %4';es_ES = 'disponible %1 %2, falta %3 %4';es_CO = 'disponible %1 %2, falta %3 %4';tr = 'mevcut %1 %2, eksik %3 %4';it = 'disponibile %1 %2, deficit %3 %4';de = 'verfügbar %1 %2, Fehlmenge %3 %4'");
			
			TextOfMessageQuantity = StringFunctionsClientServer.SubstituteParametersToString(
				TextOfMessageQuantity,
				String(RecordsSelection.BalanceStockTransferredToThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation),
				String(-RecordsSelection.QuantityBalanceStockTransferredToThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageTitleText = MessageTitleText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors occurred while posting by
// the Inventory register passed for the third party counterparties list.
//
Procedure ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + " " + NStr("en = 'Insufficient quantity transferred to the counterparty.'; ru = 'Контрагенту передано недостаточное количество';pl = 'Niewystarczającą ilość przekazano kontrahentowi.';es_ES = 'La cantidad insuficiente se transfiere a la contrapartida.';es_CO = 'La cantidad insuficiente se transfiere a la contrapartida.';tr = 'Cari hesaba aktarılan yetersiz miktar.';it = 'Quantità insufficiente trasferita alla controparte';de = 'Zu geringe Menge, die an den Geschäftspartner überwiesen wurde.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1, counterparty %2'; ru = 'Номенклатура: %1, контрагент %2';pl = 'Produkty: %1, kontrahent %2';es_ES = 'Productos:%1, contrapartida%2';es_CO = 'Productos:%1, contrapartida%2';tr = 'Ürünler: %1, cari hesap %2';it = 'Articoli: %1, controparte %2';de = 'Produkte: %1, Geschäftspartner %2'");
	PresentationCurrency = GetPresentationCurrency(DocObject.Company);
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.CounterpartyPresentation));
		
		If RecordsSelection.QuantityBalanceStockTransferredToThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'available %1 %2, shortage %3 %4'; ru = 'в наличии %1 %2, не хватает %3 %4';pl = 'dostępne %1 %2, niedobór %3 %4';es_ES = 'disponible %1%2, falta %3%4';es_CO = 'disponible %1%2, falta %3%4';tr = 'mevcut %1 %2, eksik %3 %4';it = 'disponibile %1 %2, deficit %3 %4';de = 'verfügbar %1 %2, Fehlmenge %3 %4'");
			
			TextOfMessageQuantity = StringFunctionsClientServer.SubstituteParametersToString(
				TextOfMessageQuantity,
				String(RecordsSelection.BalanceStockTransferredToThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation),
				String(-RecordsSelection.QuantityBalanceStockTransferredToThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory received.
//
Procedure ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	ObjectMetadata = DocObject.Metadata();
	ThereIsCounterparty = ObjectMetadata.Attributes.Find("Counterparty") <> Undefined;
	If ThereIsCounterparty Then
		MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'Insufficient quantity received from %1'; ru = 'От %1 получено недостаточное количество';pl = 'Otrzymano niewystarczającą ilość od %1';es_ES = 'Cantidad insuficiente recibida de %1';es_CO = 'Cantidad insuficiente recibida de %1';tr = '%1''dan alınan yetersiz miktar';it = 'Quantità insufficiente ricevuta da %1';de = 'Zu geringe Menge erhalten von %1'");
	Else
		MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'Insufficient quantity received'; ru = 'Получено недостаточное количество';pl = 'Otrzymano niewystarczającą ilość';es_ES = 'Cantidad insuficiente recibida';es_CO = 'Cantidad insuficiente recibida';tr = 'Alınan yetersiz miktar';it = 'Quantità insufficiente ricevuta';de = 'Zu geringe Menge erhalten'");
	EndIf;

	MessagePattern = NStr("en = 'Product: %1,'; ru = 'Номенклатура: %1,';pl = 'Produkt: %1,';es_ES = 'Producto:%1,';es_CO = 'Producto:%1,';tr = 'Ürün: %1,';it = 'Articolo: %1,';de = 'Produkt: %1,'");
	
	TitleInDetailsShow = True;
	PresentationCurrency = GetPresentationCurrency(DocObject.Company);
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If ThereIsCounterparty Then
				MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
					MessageTitleTemplate,
					TrimAll(RecordsSelection.CounterpartyPresentation));
			EndIf;
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts);
		
		If RecordsSelection.QuantityBalanceStockReceivedFromThirdParties <> 0 Then
			
			TextOfMessageQuantity = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'available %1 %2, shortage %3 %4'; ru = 'в наличии %1 %2, не хватает %3 %4';pl = 'dostępne %1 %2, niedobór %3 %4';es_ES = 'disponible %1%2, falta %3%4';es_CO = 'disponible %1%2, falta %3%4';tr = 'mevcut %1 %2, eksik %3 %4';it = 'disponibile %1 %2, deficit %3 %4';de = 'verfügbar %1 %2, Fehlmenge %3 %4'"),
				String(RecordsSelection.BalanceStockReceivedFromThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation),
				String(-RecordsSelection.QuantityBalanceStockReceivedFromThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory received.
//
Procedure ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient inventory received from the counterparty'; ru = 'Не хватает товаров, полученных от контрагента';pl = 'Niewystarczająca ilość zapasów otrzymanych od kontrahenta';es_ES = 'Insuficiente inventario recibido de la contraparte';es_CO = 'Insuficiente inventario recibido de la contraparte';tr = 'Cari hesaptan alınan stok yetersiz';it = 'Scorte insufficienti ricevute dalla controparte';de = 'Unzureichender Bestand von dem Geschäftspartner erhalten'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	MessagePattern = NStr("en = 'Product: %1, 
		|counterparty %2'; 
		|ru = 'Номенклатура: %1, 
		|контрагент %2';
		|pl = 'Produkt: %1, 
		|kontrahent %2';
		|es_ES = 'Producto: %1,
		| contrapartida %2';
		|es_CO = 'Producto: %1,
		| contrapartida %2';
		|tr = 'Ürün: %1, 
		| cari hesap %2';
		|it = 'Articolo: %1,
		|controparte%2';
		|de = 'Produkt: %1,
		|Geschäftspartner %2'");
		
	PresentationCurrency = GetPresentationCurrency(DocObject.Company);
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.CounterpartyPresentation));
		
		If RecordsSelection.QuantityBalanceStockReceivedFromThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'balance %1 %2,
				|shortage %3 %4'; 
				|ru = 'остаток %1 %2,
				|недостача %3 %4';
				|pl = 'saldo %1 %2,
				|niedobór %3 %4';
				|es_ES = 'saldo %1 %2,
				|falta %3 %4';
				|es_CO = 'saldo %1 %2,
				|falta %3 %4';
				|tr = 'bakiye %1 %2,
				| eksik %3 %4';
				|it = 'saldo %1 %2,
				|deficit %3 %4';
				|de = 'Bilanz %1 %2,
				|Fehlmenge %3 %4'");
			
			TextOfMessageQuantity = StringFunctionsClientServer.SubstituteParametersToString(
				TextOfMessageQuantity,
				String(RecordsSelection.BalanceStockReceivedFromThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation),
				String(-RecordsSelection.QuantityBalanceStockReceivedFromThirdParties),
				TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Sales orders.
//
Procedure ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the sales order'; ru = 'Оформлено больше, чем указано в заказе покупателя';pl = 'Wysyłasz więcej niż określono w zamówieniu sprzedaży';es_ES = 'Usted está enviando más que está especificado en el orden de ventas';es_CO = 'Usted está enviando más que está especificado en el orden de ventas';tr = 'Düzenlenen miktar satış siparişinde belirtilenden daha fazladır';it = 'State inviando più di quanto specificato nell''ordine cliente';de = 'Sie versenden mehr als im Kundenauftrag angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
	                      |balance by order %2 %3, 
	                      |exceeds by %4 %5 %6'; 
	                      |ru = 'Номенклатура: %1,
	                      |остаток по заказу %2 %3, 
	                      |превышает на %4 %5 %6';
	                      |pl = 'Produkty: %1,
	                      |saldo według zamówienia %2 %3, 
	                      |przekracza o %4 %5 %6';
	                      |es_ES = 'Productos: %1,
	                      |saldo por orden %2 %3,
	                      |excede por %4 %5 %6';
	                      |es_CO = 'Productos: %1,
	                      |saldo por orden %2 %3,
	                      |excede por %4 %5 %6';
	                      |tr = 'Ürünler: %1, 
	                      | siparişe göre bakiye %2 %3, 
	                      | fazla olan tutar %4 %5 %6';
	                      |it = 'Articolo: %1,
	                      |saldo per ordine %2 %3,
	                      |eccede di %4 %5 %6';
	                      |de = 'Produkte: %1,
	                      |Saldo auf Bestellung %2 %3,
	                      |übersteigt um %4 %5 %6'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceSalesOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceSalesOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.OrderPresentation));
			
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Transfer orders.
//
Procedure ShowMessageAboutPostingToTransferOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the transfer order'; ru = 'Оформлено больше товара, чем указано в заказе на перемещение';pl = 'Wysyłasz więcej, niż podano w zamówieniu przeniesienia';es_ES = 'Usted está enviando más de lo especificado en la orden de transferencia.';es_CO = 'Usted está enviando más de lo especificado en la orden de transferencia.';tr = 'Transfer emrinde belirtilenden daha fazlasını gönderiyorsunuz';it = 'State inviando più di quanto specificato nell''ordine di trasferimento';de = 'Sie liefern mehr als im Transportauftrag angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
	                      |balance by order %2 %3, 
	                      |exceeds by %4 %5 %6'; 
	                      |ru = 'Номенклатура: %1,
	                      |остаток по заказу %2 %3, 
	                      |превышает на %4 %5 %6';
	                      |pl = 'Produkty: %1,
	                      |saldo według zamówienia %2 %3, 
	                      |przekracza o %4 %5 %6';
	                      |es_ES = 'Productos: %1, 
	                      |saldo por orden %2%3, 
	                      |excede por %4%5%6';
	                      |es_CO = 'Productos: %1, 
	                      |saldo por orden %2%3, 
	                      |excede por %4%5%6';
	                      |tr = 'Ürünler: %1, 
	                      | siparişe göre bakiye %2 %3, 
	                      | fazla olan tutar %4 %5 %6';
	                      |it = 'Articolo: %1,
	                      |saldo per ordine %2 %3,
	                      |eccede di %4 %5 %6';
	                      |de = 'Produkte: %1,
	                      |Saldo auf Bestellung %2 %3,
	                      |übersteigt um %4 %5 %6'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceTransferOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceTransferOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.OrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Work orders.
//
Procedure ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the work order'; ru = 'Оформлено больше, чем указано в заказe-наряде';pl = 'Wysyłasz więcej, niż określono w zleceniu pracy';es_ES = 'Usted está enviando más que está especificado en el orden de trabajo';es_CO = 'Usted está enviando más que está especificado en el orden de trabajo';tr = 'İş emrinde belirtilenden daha fazlasını gönderiyorsunuz';it = 'State inviando più di quanto specificato nella Commessa';de = 'Sie liefern mehr als im Arbeitsauftrag angegeben.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
						|balance by order %2 %3, 
						|exceeds by %4 %3. %5'; 
						|ru = 'Номенклатура: %1,
						|остаток по заказу %2 %3,
						|превышает на %4 %3. %5';
						|pl = 'Produkty: %1,
						|saldo według zamówienia %2 %3, 
						|zostało przekroczone o %4 %3. %5';
						|es_ES = 'Productos: %1, 
						|saldo por orden %2 %3, 
						|excede por %4 %3. %5';
						|es_CO = 'Productos: %1, 
						|saldo por orden %2 %3, 
						|excede por %4 %3. %5';
						|tr = 'Ürünler: %1,
						|sipariş bakiyesi %2 %3, 
						|fazla olan tutar %4 %3. %5';
						|it = 'Articoli: %1,
						|saldo per ordine %2 %3, 
						|eccede per %4 %3. %5';
						|de = 'Produkte: %1,
						|Auftragssaldo %2 %3,
						|übersteigt %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			RecordsSelection.BalanceWorkOrders,
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			-RecordsSelection.QuantityBalanceWorkOrders,
			TrimAll(RecordsSelection.OrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Purchase orders statement.
//
Procedure ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are receiving more than specified in the purchase order'; ru = 'Оформлено больше, чем указано в заказе поставщику';pl = 'Odbierasz więcej niż określono w zamówieniu zakupu';es_ES = 'Usted está recibiendo más de que está especificado en el pedido';es_CO = 'Usted está recibiendo más de que está especificado en el pedido';tr = 'Düzenlenen miktar satın alma siparişinde belirtilenden daha fazla';it = 'State ricevendo più di quanto specificato nell''ordine di acquisto';de = 'Sie erhalten mehr als in der Bestellung an Lieferanten angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Products: %1,
	                      |balance by order %2 %3, 
	                      |exceeds by %4 %5
	                      |%6'; 
	                      |ru = 'Номенклатура: %1,
	                      |остаток по заказу %2 %3, 
	                      |превышает на %4 %5
	                      |%6';
	                      |pl = 'Produkty: %1,
	                      |saldo według zamówienia %2 %3,
	                      | przekracza o %4 %5
	                      |%6';
	                      |es_ES = 'Productos: %1,
	                      |saldo por orden %2 %3,
	                      |excede por %4 %5
	                      |%6';
	                      |es_CO = 'Productos: %1,
	                      |saldo por orden %2 %3,
	                      |excede por %4 %5
	                      |%6';
	                      |tr = 'Ürünler: %1, 
	                      | siparişe göre bakiye %2 %3, 
	                      | %6ne göre fazla olan tutar %4 %5
	                      |';
	                      |it = 'Articoli: %1,
	                      | saldo per ordine %2 %3, 
	                      |eccede di %4 %5
	                      |%6';
	                      |de = 'Produkte: %1,
	                      |Saldo auf Bestellung %2 %3,
	                      |übersteigt um %4 %5
	                      |%6'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalancePurchaseOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalancePurchaseOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.PurchaseOrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Informs of errors that occurred when posting Purchase order by register Backorders.
//
Procedure ShowMessageAboutPostingToBackordersAndSalesOrdersRegistersErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are ordering more than specified in the base document'; ru = 'Заказано больше запасов, чем указано в документе-основании';pl = 'Zamawiasz więcej, niż podano w dokumencie źródłowym';es_ES = 'Usted está pidiendo más de lo especificado en el documento base';es_CO = 'Usted está pidiendo más de lo especificado en el documento base';tr = 'Temel belgede belirtilenden daha fazlasını sipariş ediyorsunuz';it = 'L''ordine è superiore a quello specificato nel documento di base.';de = 'Sie bestellen mehr als in dem Basisdokument angegeben ist'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1, order: %5
	                      |balance by order %2 %3,
	                      |exceeds by %4 %3'; 
	                      |ru = 'Номенклатура: %1, заказ: %5
	                      |остаток по заказу %2 %3,
	                      |превышает на %4 %3';
	                      |pl = 'Produkty: %1, zamówienie: %5
	                      |saldo według zamówienia %2 %3,
	                      |przekracza o %4 %3';
	                      |es_ES = 'Productos: %1, orden: %5
	                      |saldo por orden %2 %3,
	                      |excede por %4 %3';
	                      |es_CO = 'Productos: %1, orden: %5
	                      |saldo por orden %2 %3,
	                      |excede por %4 %3';
	                      |tr = 'Ürünler: %1, sipariş: %5
	                      |siparişe göre bakiye %2 %3,
	                      |fazlalık %4 %3';
	                      |it = 'Articoli: %1, ordie: %5
	                      |saldo per ordine %2 %3,
	                      |eccede di %4%3';
	                      |de = 'Produkte: %1, Auftrag: %5
	                      |Auftragssaldo %2 %3,
	                      |übersteigt um %4 %3'");
	
	While RecordsSelection.Next() Do
		
		ProductsPresentation = PresentationOfProducts(RecordsSelection.ProductsPresentation,
			RecordsSelection.CharacteristicPresentation);
			
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
			ProductsPresentation,
			String(RecordsSelection.BalanceOrders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceOrders),
			TrimAll(RecordsSelection.SalesOrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// begin Drive.FullVersion

// The procedure informs of errors that occurred when posting by register Production order.
//
Procedure ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ShowMessageAboutError(DocObject,
		NStr("en = 'Error:
		     |You are producing more than specified in the production order'; 
		     |ru = 'Ошибка:
		     |Оформлено больше, чем указано в заказе на производство';
		     |pl = 'Błąd:
		     |Produkujesz więcej niż określono w zleceniu produkcyjnym';
		     |es_ES = 'Error:
		     |Usted está produciendo más de que está especificado en el orden de producción';
		     |es_CO = 'Error:
		     |Usted está produciendo más de que está especificado en el orden de producción';
		     |tr = 'Hata:
		     |Üretilen miktar üretim emrinde belirtilenden fazla';
		     |it = 'Errore:
		     |State producendo più di quanto specificato nell''ordine di produzione';
		     |de = 'Fehler:
		     |Sie produzieren mehr als im Fertigungsauftrag angegeben'"),,,,
		Cancel);
		
	MessagePattern = NStr("en = 'Product: %1,
	                      |balance by order %2 %3, 
	                      |exceeded %4 %3
	                      |%5'; 
	                      |ru = 'Номенклатура: %1,
	                      |остаток по заказу %2 %3,
	                      |превышает на %4 %3
	                      |%5';
	                      |pl = 'Towar: %1,
	                      |saldo według zamówienia %2 %3,
	                      |zostało przekroczone o %4 %3
	                      |%5';
	                      |es_ES = 'Producto: %1,
	                      |saldo por orden %2 %3, 
	                      |excede %4 %3
	                      |%5';
	                      |es_CO = 'Producto: %1,
	                      |saldo por orden %2 %3, 
	                      |excede %4 %3
	                      |%5';
	                      |tr = 'Ürün: %1,
	                      |sipariş bakiyesi %2 %3, 
	                      |fazla olan tutar %4 %3
	                      |%5';
	                      |it = 'Articolo: %1,
	                      |saldo per ordine %2 %3, 
	                      |ecceduto in %4 %3
	                      |%5';
	                      |de = 'Produkt: %1,
	                      |Balance im Auftrag %2 %3,
	                      |überschritten %4 %3
	                      |%5'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		ShowMessageAboutError(DocObject, 
			StringFunctionsClientServer.SubstituteParametersToString(
				MessagePattern, 
				PresentationOfProducts,
				String(RecordsSelection.BalanceProductionOrders),
				TrimAll(RecordsSelection.MeasurementUnitPresentation), 
				String(-RecordsSelection.QuantityBalanceProductionOrders), 
				TrimAll(RecordsSelection.ProductionOrderPresentation)),,,, 
			Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Subcontractor orders received statement.
//
Procedure ShowMessageAboutPostingToSubcontractorOrdersReceivedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle
		+ Chars.LF
		+ NStr("en = 'Quantity of finished products issued is more than specified quantity in the subcontractor order received'; ru = 'Количество выданной готовой продукции больше, чем указано в полученном заказе на переработку';pl = 'Ilość wydanych gotowych produktów jest większa niż ilość, określona w otrzymanym zamówieniu podwykonawcy';es_ES = 'La cantidad de productos terminados emitidos excede la cantidad especificada en la orden recibida del subcontratista';es_CO = 'La cantidad de productos terminados emitidos excede la cantidad especificada en la orden recibida del subcontratista';tr = 'Düzenlenen nihai ürün miktarı, alınan alt yüklenici siparişinde belirtilen miktardan fazla';it = 'La quantità di articoli finiti emessi è maggiore della quantità specificata dall''ordine ricevuto del subfornitore';de = 'Menge der ausgegebenen Fertigprodukte überschreitet die angegebene Menge im Subunternehmerauftrag erhalten'");
	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, surplus %3 %2. %4'; ru = 'Номенклатура: %1, излишки %3 %2. %4';pl = 'Produkt: %1, nadwyżka %3 %2. %4';es_ES = 'Producto: %1, superávit %3 %2. %4';es_CO = 'Producto: %1, superávit %3 %2. %4';tr = 'Ürün: %1, fazlalık %3 %2. %4';it = 'Articolo: %1, surplus %3 %2. %4';de = 'Produkt: %1, Überschuss %3 %2. %4'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.SubcontractorOrder));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Customer-owned inventory statement.
//
Procedure ShowMessageAboutPostingToCustomerOwnedInventoryRegisterErrors(DocObject, RecordsSelection, Cancel, WriteMode) Export
	
	MessageText = NStr("en = 'Cannot change the product quantity.'; ru = 'Не удалось изменить количество номенклатуры.';pl = 'Nie można zmienić ilości produktu.';es_ES = 'No se puede cambiar la cantidad de producto.';es_CO = 'No se puede cambiar la cantidad de producto.';tr = 'Ürün miktarı değiştirilemiyor.';it = 'Impossibile modificare la quantità di articoli.';de = 'Fehler beim Ändern von Produktmenge.'");
	
	IsProduction = (TypeOf(DocObject) = Type("DocumentObject.Manufacturing"));
	
	If IsProduction And WriteMode = DocumentWriteMode.UndoPosting Then
		
		MessageText = NStr("en = 'Cannot clear the document posting and set the produced product quantity to 0.'; ru = 'Не удалось отменить проведение документа и изменить количество изготовленной номенклатуры на 0.';pl = 'Nie można anulować zatwierdzenie dokumentu i ustawić ilość wyprodukowanego produktu na 0.';es_ES = 'No se puede contabilizar el documento y establecer la cantidad de producto producido en 0.';es_CO = 'No se puede contabilizar el documento y establecer la cantidad de producto producido en 0.';tr = 'Belge kaydetme temizlenemiyor ve üretilen ürün miktarı 0 olarak ayarlanamıyor.';it = 'Impossibile cancellare la pubblicazione del documento e impostare la quantità di articoli prodotti a 0.';de = 'Fehler beim Löschen von Buchen des Dokuments und Festlegen der Menge von hergestellten Produkte auf 0.'");
		
	EndIf;
	
	While RecordsSelection.Next() Do
		
		If RecordsSelection.QuantityToIssueBalance < 0 Then
			
			MessageText = MessageText
				+ Chars.LF
				+ ?(IsProduction,
					NStr("en = 'This quantity must be equal to or greater than the quantity in the related Goods issue.'; ru = 'Количество не может быть меньше количества в связанном отпуске товаров.';pl = 'Ilość musi być równa lub większa niż ilość w powiązanym Wydaniu zewnętrznym.';es_ES = 'Esta cantidad debe ser igual o mayor que la de la Salida de mercancías correspondiente.';es_CO = 'Esta cantidad debe ser igual o mayor que la de la Salida de mercancías correspondiente.';tr = 'Bu miktar ilgili Ambar çıkışındaki miktara eşit veya ondan büyük olmalıdır.';it = 'Questa quantità deve essere pari o maggiore della quantità nella relativa spedizione merce/DDT.';de = 'Diese Menge muss der Menge im verbundenen Warenausgang gleich sein oder sie übersteigen.'"),
					NStr("en = 'This quantity must be equal to or less than the quantity in the related Production document.'; ru = 'Количество не может быть больше количества в связанном документе ""Производство"".';pl = 'Ta ilość musi być równa lub mniejsza niż ilość w powiązanym dokumencie Produkcja.';es_ES = 'Esta cantidad debe ser igual o inferior a la del Documento de producción correspondiente.';es_CO = 'Esta cantidad debe ser igual o inferior a la del Documento de producción correspondiente.';tr = 'Bu miktar ilgili Üretim belgesindeki miktara eşit veya ondan küçük olmalıdır.';it = 'Questa quantità deve essere pari o inferiore alla quantità del relativo documento di Produzione.';de = 'Diese Menge muss der Menge im verbundenen Produktionsdokument gleich oder weniger sein.'"));
			Break;
			
		ElsIf RecordsSelection.QuantityToInvoiceBalance < 0 Then
			
			MessageText = MessageText
				+ Chars.LF
				+ ?(IsProduction,
					NStr("en = 'This quantity must be equal to the quantity in the related ""Subcontractor invoice issued"" document.'; ru = 'Количество должно соответствовать количеству в связанном документе ""Выданный инвойс переработчика"".';pl = 'Ta ilość musi być równa ilości w powiązanym dokumencie ""Wydana faktura od podwykonawcy"".';es_ES = 'Esta cantidad debe ser igual a la que aparece en el documento ""Factura emitida del Subcontratista"" correspondiente.';es_CO = 'Esta cantidad debe ser igual a la que aparece en el documento ""Factura emitida del Subcontratista"" correspondiente.';tr = 'Bu miktar ilgili ""Düzenlenen alt yüklenici faturası"" belgesindeki miktara eşit olmalıdır.';it = 'Questa quantità deve essere pari alla quantità nel relativo documento ""Fattura subfornitore emessa"".';de = 'Diese Menge muss der Menge in der verbundenen Subunternehmerrechnung ausgestellt gleich oder weniger sein.'"),
					NStr("en = 'This quantity must be equal to the quantity in the related Production document.'; ru = 'Количество должно соответствовать количеству в связанном документе ""Производство"".';pl = 'Ta ilość musi być równa ilości w powiązanym dokumencie Produkcja.';es_ES = 'Esta cantidad debe ser igual a la del Documento de producción correspondiente.';es_CO = 'Esta cantidad debe ser igual a la del Documento de producción correspondiente.';tr = 'Bu miktar ilgili Üretim belgesindeki miktara eşit olmalıdır.';it = 'Questa quantità deve essere pari alla quantità nel relativo documento Produzione.';de = 'Diese Menge muss der Menge im verbundenen Produktionsdokument gleich sein.'"));
			Break;
			
		EndIf;
		
	EndDo;
	
	ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Subcontractor planning.
//
Procedure ShowMessageAboutPostingToSubcontractorPlanningRegisterErrors(DocObject, WorkInProgressPresentation, RecordsSelection, Cancel) Export
	
	ShowMessageAboutError(DocObject,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The ordered product quantity in ""Subcontractor orders issued"" cannot exceed the quantity in ""%1"".'; ru = 'Количество заказанной номенклатуры в ""Выданных заказах на переработку"" не может превышать количество в ""%1"".';pl = 'Ilość zamówionych produktów w ""Wydane zamówienia wykonawcy"" nie mogą przekraczać ilość w ""%1"".';es_ES = 'La cantidad del producto solicitado en ""Órdenes emitidas del subcontratista"" no puede exceder la cantidad en ""%1 "".';es_CO = 'La cantidad del producto solicitado en ""Órdenes emitidas del subcontratista"" no puede exceder la cantidad en ""%1 "".';tr = '""Düzenlenen alt yüklenici siparişleri""ndeki sipariş edilen ürün miktarı ""%1"" miktarını aşamaz.';it = 'La quantità di articoli ordinata in ""Ordini di subfornitura emessi"" non può superare la quantità in ""%1"".';de = 'Die in ""Subunternehmeraufträgen ausgestellt"" bestellte Produktmenge darf die Menge in ""%1"" nicht überschreiten.'"),
			TrimAll(WorkInProgressPresentation)),,,
		Cancel);
		
	MessagePattern = NStr("en = 'Product: %1.
		|Required: %2 %3.
		|Ordered by Subcontractor orders issued:
		|Variance: %4 %3.'; 
		|ru = 'Номенклатура: %1.
		|Требуется: %2 %3.
		|Заказано в выданном заказе на переработку:
		|Расхождение: %4 %3.';
		|pl = 'Produkt: %1.
		|Wymagane: %2 %3.
		|Zamówione przez Wydane zamówienie wykonawcy:
		|Odchylenie: %4 %3.';
		|es_ES = 'Producto: %1.
		|Requerido: %2 %3.
		|Pedido por las órdenes emitidas del subcontratista:
		|Varianza: %4 %3.';
		|es_CO = 'Producto: %1.
		|Requerido: %2 %3.
		|Pedido por las órdenes emitidas del subcontratista:
		|Varianza: %4 %3.';
		|tr = 'Ürün: %1.
		|Gereken: %2 %3.
		|Düzenlenen alt yüklenici siparişleri ile sipariş edilen:
		|Fark: %4 %3.';
		|it = 'Articolo: %1.
		|Richiesto: %2 %3.
		|Ordinati per Ordini di subfornitura emessi:
		|Variazione: %4 %3.';
		|de = 'Produkt: %1.
		|Erforderlich: %2 %3.
		|Bestellt durch Subunternehmerauftrag ausgestellt:
		|Abweichung: %4 %3.'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern, 
			PresentationOfProducts,
			String(RecordsSelection.BalanceWorkInProgreses),
			TrimAll(RecordsSelection.MeasurementUnitPresentation), 
			String(-RecordsSelection.QuantityBalanceWorkInProgreses));
			
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// end Drive.FullVersion

// The procedure informs of errors that occurred when posting by register Production order.
//
Procedure ShowMessageAboutPostingToKitOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ShowMessageAboutError(DocObject,
		NStr("en = 'On the Finished products tab, the product quantity exceeds the quantity specified in the related Kit order.'; ru = 'На вкладке Готовая продукция количество номенклатуры превышает количество, указанное в соответствующем заказе на комплектацию.';pl = 'Na karcie Gotowe produkty, ilość produktów przekracza ilość określoną w powiązanym zamówieniu zestawu.';es_ES = 'En la pestaña Productos terminados, la cantidad del producto excede la cantidad especificada en el pedido del kit relacionado.';es_CO = 'En la pestaña Productos terminados, la cantidad del producto excede la cantidad especificada en el pedido del kit relacionado.';tr = 'Nihai ürünler sekmesinde ürün miktarı, ilgili Set siparişinde belirtilen miktardan fazla.';it = 'Nella scheda Articoli finiti, la quantità dell''articolo eccede la quantità specificata nell''Ordine kit correlato.';de = 'Auf der Registerkarte ""Fertigprodukte"", überschreitet die Produktmenge die Menge angegeben im bezogenen Kit-Auftrag.'"),,,,
		Cancel);
		
		MessagePattern = NStr("en = 'For product %1, the quantity exceeds the ordered quantity (%2 %3) by %4 %3 %5.
			|To be able to continue, do any of the following:
			|- Edit either of the quantities so that they match.
			|- In the KIt processed, clear the Kit order field.'; 
			|ru = 'Для номенклатуры %1 количество превышает заказанное (%2 %3) by %4 %3 %5.
			|Для продолжения выполните одно из следующих действий:
			|- Измените любое из количеств так, чтобы они совпадали.
			|- В форме Результат комплектации очистите поле Заказ на комплектацию.';
			|pl = 'Dla produktu %1, ilość przekracza zamówioną ilość (%2 %3) o %4 %3 %5.
			|Aby mieć możliwość kontynuowania, wykonaj dowolną z następujących czynności:
			|- Zmień jedną z ilości tak, aby odpowiadały sobie.
			|- W przetwarzanym zestawie, wyczyść pole Zamówienie zestawu.';
			|es_ES = 'Para el producto %1, la cantidad excede la cantidad pedida (%2 %3) en %4 %3 %5.
			|Para poder continuar, realice una de las siguientes acciones:
			|- Edite cualquiera de las cantidades para que coincidan.
			|- En el kit procesado, borre el campo pedido del kit.';
			|es_CO = 'Para el producto %1, la cantidad excede la cantidad pedida (%2 %3) en %4 %3 %5.
			|Para poder continuar, realice una de las siguientes acciones:
			|- Edite cualquiera de las cantidades para que coincidan.
			|- En el kit procesado, borre el campo pedido del kit.';
			|tr = '%1 ürünü için, miktar sipariş edilen miktarı (%2 %3) %4 %3 %5 geçiyor.
			|Devam edebilmek şunlardan birini yapın:
			|- Miktarları eşitleyecek şekilde birini değiştirin.
			|- İşlenen sette, Set siparişi alanını silin.';
			|it = 'Per l''articolo %1, la quantità eccede la quantità ordinata (%2%3) di %4 %3 %5.
			|Per poter continuare, eseguire una delle opzioni seguenti:
			|- Modificare una delle quantità così che corrispondano.
			|- Nel kit elaborato, cancellare il campo Ordine kit.';
			|de = 'Für Produkt %1, überschreitet die Menge die bestellte Menge(%2 %3) um %4 %3 %5.
			|Um Fortfahren zu können, tun Sie ein des Folgenden:
			|- Eine der Mengen bearbeiten damit die beiden übereinstimmen.
			|- Im Kit bearbeitet das Kit-Auftragsfeld löschen.'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		ShowMessageAboutError(DocObject, 
			StringFunctionsClientServer.SubstituteParametersToString(
				MessagePattern, 
				PresentationOfProducts,
				String(RecordsSelection.BalanceKitOrders),
				TrimAll(RecordsSelection.MeasurementUnitPresentation),
				String(-RecordsSelection.QuantityBalanceKitOrders),
				TrimAll(RecordsSelection.KitOrderPresentation)),,,,
				Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory demand.
//
Procedure ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Registered more than the inventory demand'; ru = 'Оформлено больше, чем есть потребность в запасах';pl = 'Zarejestrowano więcej niż wynosi zapotrzebowanie na zapas';es_ES = 'Registrado más de la demanda de inventario';es_CO = 'Registrado más de la demanda de inventario';tr = 'Kaydedilen miktar, stok talebinden fazla';it = 'Eseguito più di quanto specificato nel fabbisogno di scorte';de = 'Registriert mehr als den Bestandsbedarf'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
	                      |demand %2 %3,
	                      |exceeds by %4 %5
	                      |%6'; 
	                      |ru = 'Номенклатура: %1,
	                      |потребность %2 %3,
	                      |превышает на %4 %5
	                      |%6';
	                      |pl = 'Produkty: %1,
	                      |zapotrzebowanie %2 %3,
	                      |przekracza o %4 %5
	                      |%6';
	                      |es_ES = 'Productos: %1,
	                      |demanda %2 %3,
	                      |excede por %4 %5
	                      |%6';
	                      |es_CO = 'Productos: %1,
	                      |demanda %2 %3,
	                      |excede por %4 %5
	                      |%6';
	                      |tr = 'Ürünler: %1,
	                      | talep%2 %3,
	                      | aşıyor %4 %5
	                      |%6';
	                      |it = 'Articoli: %1,
	                      |domanda %2 %3,
	                      |eccede per %4 %5
	                      |%6';
	                      |de = 'Produkte: %1,
	                      |Nachfrage %2 %3,
	                      |übersteigt um %4 %5
	                      |%6'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceInventoryDemand),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceInventoryDemand),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.SalesOrderPresentation));
			
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register ReservedProducts demand.
//
Procedure ShowMessageAboutPostingToReservedProductsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'This document reserved products. Some of them were already sold
		|or the reserve was cleared in another way. You are trying to post the document and clear the reserve.
		|The reserve to clear cannot exceed the available reserve.'; 
		|ru = 'Этот документ содержит зарезервированную номенклатуру. Часть этой номенклатуры уже была продана
		|или резерв был снят другим способом. Вы пытаетесь провести документ и снять резерв.
		|Резерв к снятию не может превышать доступный резерв.';
		|pl = 'Ten dokument zarezerwował produkty. Niektóre z nich są już sprzedaży
		|lub rezerwa została usunięta w inny sposób. Próbujesz zatwierdzić dokument i usunąć rezerwę.
		|Rezerwa do usunięcia nie może przekraczać dostępnej rezerwy.';
		|es_ES = 'Este documento de productos reservados. Algunos de ellos ya se vendieron
		| o la reserva se compensó de otra manera. Usted está intentando contabilizar el documento y compensar la reserva.
		|La reserva a eliminar no puede exceder la reserva disponible.';
		|es_CO = 'Este documento de productos reservados. Algunos de ellos ya se vendieron
		| o la reserva se compensó de otra manera. Usted está intentando contabilizar el documento y compensar la reserva.
		|La reserva a eliminar no puede exceder la reserva disponible.';
		|tr = 'Bu belgenin rezerve ettiği bazı ürünler zaten satıldı veya rezerv başka şekilde silindi. Belgeyi kaydedip rezervi silmeye çalışıyorsunuz. Silinecek rezerv mevcut rezervden büyük olamaz.';
		|it = 'Questo documento ha prodotti riservati. Alcuni di questi sono stati già venduti
		| o la riserva è stata cancellata in altro modo. Stai provando a pubblicare il documento e a cancellare la riserva.
		|La riserva da cancellare non può essere maggiore della riserva disponibile.';
		|de = 'Dieses Dokument reservierte Produkte. Einige von diesen sind bereits ausverkauft
		|oder die Reserve war in einer anderen weise gelöscht. Sie versuchen das Dokument zu buchen und die Reserve zu löschen.
		|Die Reserve zum Löschen darf die verfügbare Reserve nicht überschreiten.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
		|Available reserve %2 %3,
		|Reserve to clear %4 %3'; 
		|ru = 'Номенклатура: %1,
		|Доступный резерв %2 %3,
		|Резерв к снятию %4 %3';
		|pl = 'Produkty: %1,
		|Dostępna rezerwa %2 %3,
		|Rezerwa do usunięcia %4 %3';
		|es_ES = 'Productos: %1,
		|Reserva disponible %2 %3,
		|Reserva a eliminar %4 %3';
		|es_CO = 'Productos: %1,
		|Reserva disponible %2 %3,
		|Reserva a eliminar %4 %3';
		|tr = 'Ürünler: %1,
		|Mevcut rezerv %2 %3,
		|Silinecek rezerv %4 %3';
		|it = 'Articoli: %1,
		|Riserva disponibile %2 %3, 
		|Riserva da cancellare %4 %3';
		|de = 'Produkte: %1,
		|Verfügbare Reserve %2 %3,
		|Reserve zum Löschen%4 %3'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceInventory));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Orders placement.
//
Procedure ShowMessageAboutPostingToBackordersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Registered more than the inventory allocated in the orders'; ru = 'Оформлено больше, чем размещено запасов в заказах';pl = 'Zarejestrowano więcej. niż zapas przydzielony w zamówieniach';es_ES = 'Registrado más del inventario asignado en los órdenes';es_CO = 'Registrado más del inventario asignado en los órdenes';tr = 'Kayıtlı miktar, sipariş edilen stoklardan daha fazladır';it = 'Registrato più delle scorte assegnate negli ordini';de = 'Mehr als der in den Bestellungen zugewiesene Bestand registriert'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Product: %1,
	                      |allocated %2 %3
	                      |in %4,
	                      |exceeds %5 %6
	                      |by %SalesOrder%'; 
	                      |ru = 'Номенклатура: %1,
	                      |распределено %2 %3
	                      |в %4,
	                      |превышает %5 %6
	                      |by %SalesOrder%';
	                      |pl = 'Produkt: %1,
	                      |przydzielono %2 %3
	                      |w %4,
	                      |przekracza %5 %6
	                      |o %SalesOrder%';
	                      |es_ES = 'Producto: %1,
	                      |asignado %2 %3
	                      |en %4,
	                      |excede %5 %6
	                      |por %SalesOrder%';
	                      |es_CO = 'Producto: %1,
	                      |asignado %2 %3
	                      |en %4,
	                      |excede %5 %6
	                      |por %SalesOrder%';
	                      |tr = 'Ürün: %1, 
	                      | %4 içinde tahsis edilen %2 %3 
	                      |,
	                      |aşan %5 %6 
	                      | %SalesOrder%ne göre';
	                      |it = 'Articolo: %1,
	                      |allocato %2 %3
	                      |in %4,
	                      |eccede %5 %6
	                      |secondo %SalesOrder%';
	                      |de = 'Produkt: %1,
	                      |zugeteilt %2 %3
	                      |in %4,
	                      |übersteigt %5 %6
	                      |um %SalesOrder%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceBackorders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.SupplySourcePresentation),
			String(-RecordsSelection.QuantityBalanceBackorders),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			TrimAll(RecordsSelection.SalesOrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Cash assets.
//
Procedure ShowMessageAboutPostingToCashAssetsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient funds'; ru = 'Недостаточно средств';pl = 'Niewystarczające środki';es_ES = 'Fondos insuficientes';es_CO = 'Fondos insuficientes';tr = 'Yetersiz para kaynağı';it = 'Fondi insufficienti';de = 'Unzureichende Mittel'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = '%1: %2,
	                      |balance %3 %4,
	                      |shortage %5 %6'; 
	                      |ru = '%1: %2,
	                      |остаток %3 %4,
	                      |недостача %5 %6';
	                      |pl = '%1: %2,
	                      |saldo %3 %4,
	                      |niedobór %5 %6';
	                      |es_ES = '%1: %2,
	                      |saldo%3 %4,
	                      |falta%5 %6';
	                      |es_CO = '%1: %2,
	                      |saldo%3 %4,
	                      |falta%5 %6';
	                      |tr = '%1: %2,
	                      | bakiye %3 %4, 
	                      | eksik %5 %6';
	                      |it = '%1 :%2,
	                      |saldo %3 %4m
	                      |deficit %5 %6';
	                      |de = '%1: %2,
	                      |Saldo %3 %4,
	                      |Fehlmenge %5 %6'");
		
	While RecordsSelection.Next() Do
		
		PettyCashAccountPresentation = CashBankAccountPresentation(RecordsSelection.BankAccountCashPresentation);
		
		If RecordsSelection.PaymentMethod.CashAssetType = Enums.CashAssetTypes.Noncash Then
			PettyCashAccountText = NStr("en = 'Bank account'; ru = 'Счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'");
		Else
			PettyCashAccountText = NStr("en = 'Cash-in-hand account'; ru = 'Счет кассы';pl = 'Rachunek gotówkowy';es_ES = 'Cuenta de efectivo';es_CO = 'Cuenta de efectivo';tr = 'Kasa hesabı';it = 'Conto cassa in contanti';de = 'Konto der verfügbaren Finanzmittel'");
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PettyCashAccountText,
			PettyCashAccountPresentation,
			String(RecordsSelection.BalanceCashAssets),
			TrimAll(RecordsSelection.CurrencyPresentation),
			String(-RecordsSelection.AmountCurBalance),
			TrimAll(RecordsSelection.CurrencyPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Cash in cash registers.
//
Procedure ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient funds in the cash register'; ru = 'Недостаточно средств в кассе';pl = 'Niewystarczające środki w kasie fiskalnej';es_ES = 'Fondos insuficientes en la caja registradora';es_CO = 'Fondos insuficientes en la caja registradora';tr = 'Yazar kasada yetersiz para kaynağı';it = 'Fondi insufficienti nel registratore di cassa';de = 'Unzureichende Mittel in der Kasse'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Cash register: %1,
		|balance %2 %3,
		|shortage %4 %3'; 
		|ru = 'Касса: %1,
		|остаток %2 %3,
		| не хватает %4 %3';
		|pl = 'Kasa fiskalna: %1,
		|saldo %2 %3,
		|niedobór %4 %3';
		|es_ES = 'Caja registradora: %1,
		|saldo %2 %3,
		|falta%4 %3';
		|es_CO = 'Caja registradora: %1,
		|saldo %2 %3,
		|falta%4 %3';
		|tr = 'Yazar kasa: %1, 
		| bakiye %2 %3, 
		| yetersiz %4 %3';
		|it = 'Registratore di cassa: %1,
		|saldo %2 %3,
		|deficit %4 %3';
		|de = 'Kasse: %1,
		|ausgleichen %2 %3,
		|Fehlmenge %4 %3'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			CashBankAccountPresentation(RecordsSelection.CashCRDescription),
			String(RecordsSelection.BalanceCashAssets),
			TrimAll(RecordsSelection.CurrencyPresentation),
			String(-RecordsSelection.AmountCurBalance));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Advance holder payments.
//
Procedure ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	MessageTitleText = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'")
		+ Chars.LF
		+ NStr("en = 'The transaction causes a negative balance of the advance holder debt.'; ru = 'В результате транзакции образовался отрицательный остаток долга подотчетного лица.';pl = 'Transakcja powoduje ujemne saldo zadłużenia zaliczkobiorcy.';es_ES = 'La transacción causa el saldo negativo de la deuda del titular de anticipo.';es_CO = 'La transacción causa el saldo negativo de la deuda del titular de anticipo.';tr = 'Bu işlem, avans sahibinin borcunun eksi bakiye göstermesine neden oluyor.';it = 'Le transazioni causano un saldo negativo del debito della persona che ha anticipato.';de = 'Die Transaktion führt zu einem negativen Saldo der Schuld der abrechnungspflichtigen Person.'");
	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = '%1,
		|Accountable funds balance: %2 %3'; 
		|ru = '%1,
		|Остаток учетных средств: %2 %3';
		|pl = '%1,
		|Rozliczane saldo środków pieniężnych: %2 %3';
		|es_ES = '%1,
		|Saldo contable de fondos: %2 %3';
		|es_CO = '%1,
		|Saldo contable de fondos: %2 %3';
		|tr = '%1,
		| Sorumlu fonlar bakiyesi: %2 %3';
		|it = '%1,
		|Saldo fondi Crediti: %2 %3';
		|de = '%1,
		|Rechenschaftspflichtiges Guthaben: %2 %3'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfAccountablePerson = PresentationOfAccountablePerson(RecordsSelection.EmployeePresentation,
			RecordsSelection.CurrencyPresentation,
			RecordsSelection.DocumentPresentation);
		AmountCurBalance = ?(RecordsSelection.AmountCurBalance > 0,
			-RecordsSelection.AmountCurBalance,
			RecordsSelection.AmountCurBalance);
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfAccountablePerson,
			String(AmountCurBalance),
			TrimAll(RecordsSelection.CurrencyPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Accounts payable.
//
Procedure ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	While RecordsSelection.Next() Do
		
		CounterpartyPresentation = CounterpartyPresentation(
			RecordsSelection.CounterpartyPresentation,
			RecordsSelection.ContractPresentation,
			RecordsSelection.DocumentPresentation,
			RecordsSelection.OrderPresentation,
			RecordsSelection.CalculationsTypesPresentation);
			
		CurrencyPresentation = TrimAll(RecordsSelection.CurrencyPresentation);

		
		If RecordsSelection.RegisterRecordsOfCashDocuments Then
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Invoice payable amount is less than entered. Details: %1.
					     |Entered: %3 %2
					     |Invoice payable:%4 %2'; 
					     |ru = 'Остаток задолженности по инвойсу меньше оплаченной суммы. Аналитика расчетов: %1.
					     |Разнесенная сумма платежа: %3 %2
					     |Остаток задолженности перед поставщиком: %4 %2';
					     |pl = 'Wartość należności z tytułu faktury jest niższa, niż kwota wprowadzona. Szczegóły: %1.
					     |Wprowadzono: %3 %2
					     |Faktura płatna:%4 %2';
					     |es_ES = 'Importe de la factura a pagar es menor del introducido. Detalles: %1.
					     |Introducido: %3 %2
					     |Factura a pagar:%4 %2';
					     |es_CO = 'Importe de la factura a pagar es menor del introducido. Detalles: %1.
					     |Introducido: %3 %2
					     |Factura a pagar:%4 %2';
					     |tr = 'Fatura ödenebilir tutarı girilenden daha azdır. Ayrıntılar: %1. 
					     |Girilen: %3 %2
					     | Fatura ödenebilir: %4 %2';
					     |it = 'L''importo pagabile della fattura è inferiore a quello inserito. Dettagli: %1.
					     |Inserito: %3 %2
					     |Importo pagabile della fattura:%4 %2';
					     |de = 'Der Betrag der Rechnung ist niedriger als der eingegebene Betrag. Details: %1.
					     |Eingabe: %3 %2
					     |Rechnung zahlbar: %4 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.SumCurOnWrite),
					String(RecordsSelection.DebtBalanceAmount));
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				If RecordsSelection.AmountOfOutstandingAdvances = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The advance payment has been cleared in full by invoices. Details: %1.'; ru = 'Авансовый платеж был полностью компенсирован инвойсами. Описание: %1.';pl = 'Zaliczka została w całości rozliczona na podstawie faktur. Szczegóły: %1.';es_ES = 'El pago adelantado ha sido amortizado por completo con facturas. Detalles: %1.';es_CO = 'El pago Anticipado ha sido amortizado por completo con facturas. Detalles: %1.';tr = 'Avans ödeme, faturalarla tamamen silindi. Ayrıntılar: %1.';it = 'L''anticipo è stato compensato integralmente da fatture. Dettagli: %1.';de = 'Die Vorauszahlung wurde durch Rechnungen vollständig verrechnet. Details: %1.'"),
						CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The advance payment has been cleared in part by invoices. Details: %1.
						     |Advance balance: %3 %2'; 
						     |ru = 'Авансовый платеж был частично компенсирован инвойсами. Описание: %1.
						     | Остаток аванса: %3 %2';
						     |pl = 'Zaliczka została częściowo rozliczona na podstawie faktur. Szczegóły:%1.
						     |Wcześniejsze saldo: %3 %2';
						     |es_ES = 'El pago adelantado ha sido amortizado en parte con facturas. Detalles: %1.
						     |Saldo de anticipos: %3 %2';
						     |es_CO = 'El pago Anticipado ha sido amortizado en parte con facturas. Detalles: %1.
						     |Saldo de anticipos: %3 %2';
						     |tr = 'Avans ödeme, faturalarla kısmen mahsup edildi. Ayrıntılar: %1. 
						     | avans bakiyesi: %3 %2';
						     |it = 'Il pagamento anticipato è stato parzialmente compensato da fatture. Dettagli: %1.
						     |Saldo anticipi: %3 %2';
						     |de = 'Die Vorauszahlung wurde teilweise durch Rechnungen ausgeglichen. Details: %1.
						     |Voraussaldo: %3 %2'"),
						CounterpartyPresentation,
						CurrencyPresentation,
						String(RecordsSelection.AmountOfOutstandingAdvances));
				EndIf;
			EndIf;
			
		Else
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				If RecordsSelection.AmountOfOutstandingDebt = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The invoice is already settled in full. Details: %1.'; ru = 'Инвойс полностью оплачен. Описание: %1.';pl = 'Faktura jest już w pełni opłacona. Szczegóły: %1.';es_ES = 'La factura ya está pagada en parte. Detalles: %1.';es_CO = 'La factura ya está pagada en parte. Detalles: %1.';tr = 'Fatura tamamen ödendi. Ayrıntılar: %1.';it = 'La fattura è già completamente saldata. Dettagli: %1.';de = 'Die Rechnung wurde vollständig bezahlt. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The invoice is already settled in part. Details: %1.
					     |Unpaid: %3 %2'; 
					     |ru = 'Инвойс частично оплачен. Описание: %1.
					     |К оплате: %3 %2';
					     |pl = 'Faktura jest już częściowo opłacona. Szczegóły: %1.
					     |Nieopłacono: %3 %2';
					     |es_ES = 'La factura ya está pagada en parte. Detalles: %1. 
					     |No pagado: %3 %2';
					     |es_CO = 'La factura ya está pagada en parte. Detalles: %1. 
					     |No pagado: %3 %2';
					     |tr = 'Fatura kısmen ödendi. Ayrıntılar: %1.
					     |Ödenmeyen: %3 %2';
					     |it = 'La fattura è parzialmente saldata. Dettagli: %1.
					     | Non pagato: %3 %2';
					     |de = 'Die Rechnung wurde teilweise bezahlt. Details: %1.
					     |Unbezahlt: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingDebt));
				EndIf;
			EndIf;
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'You cannot clear a larger amount than the advance payment is. Details: %1.
				     |Entered amount:%3 %2
				     |Advance balance: %4 %2'; 
				     |ru = 'Нельзя зачесть сумму, превышающую сумму аванса. Описание: %1.
				     |Указанная сумма:%3 %2
				     | Остаток авансов: %4 %2';
				     |pl = 'Nie możesz wyczyścić większej kwoty niż suma płatności zaliczkowej. Szczegóły: %1.
				     |Wprowadzona kwota:%3 %2
				     |Saldo zaliczki: %4 %2';
				     |es_ES = 'Usted no puede amortizar un importe mayor de que es el pago adelantado. Detalles: %1.
				     |Importe introducido:%3 %2
				     |Saldo de anticipos: %4 %2';
				     |es_CO = 'Usted no puede amortizar un importe mayor al pago Anticipado. Detalles: %1.
				     |Importe introducido:%3 %2
				     |Saldo de anticipos: %4 %2';
				     |tr = 'Avans ödemesinden daha fazla bir tutarı mahsup edemezsiniz: Ayrıntılar: %1. 
				     | Girilen tutar: %3 %2
				     |Avans bakiyesi: %4 %2';
				     |it = 'Non è possibile cancellare un importo maggiore rispetto al pagamento anticipato. Dettagli: %1.
				     |Importo inserito:%3 %2
				     |Saldo anticipo: %4 %2';
				     |de = 'Sie können keinen größeren Betrag als die Vorauszahlung ausgleichen. Details: %1.
				     |Eingegebener Betrag: %3 %2
				     |Voraussaldo: %4 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.SumCurOnWrite),
					String(RecordsSelection.AdvanceAmountsPaid));
			EndIf;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Accounts receivable.
//
Procedure ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	While RecordsSelection.Next() Do
		
		CounterpartyPresentation = CounterpartyPresentation(
			RecordsSelection.CounterpartyPresentation,
			RecordsSelection.ContractPresentation,
			RecordsSelection.DocumentPresentation,
			RecordsSelection.OrderPresentation,
			RecordsSelection.CalculationsTypesPresentation);
			
		CurrencyPresentation = TrimAll(RecordsSelection.CurrencyPresentation);
		
		If RecordsSelection.RegisterRecordsOfCashDocuments Then
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Invoice receivable amount is less than entered. Details: %1.
				     |Entered amount: %3 %2
				     |Invoice receivable amount: %4 %2'; 
				     |ru = 'Остаток задолженности покупателя по инвойсу меньше разнесенной суммы платежа. Аналитика расчетов: %1.
				     |Разнесенная сумма платежа: %3 %2
				     |Остаток задолженности покупателя: %4 %2';
				     |pl = 'Kwota należności z tytułu faktury jest mniejsza niż kwota wprowadzona. Szczegóły: %1.
				     |Wprowadzona kwota: %3 %2
				     |Kwota należności z tytułu faktury: %4 %2';
				     |es_ES = 'Importe de la factura a cobrar es menor del introducido. Detalles: %1.
				     |Importe introducido: %3 %2
				     |Importe de la factura a cobrar: %4 %2';
				     |es_CO = 'Importe de la factura a cobrar es menor del introducido. Detalles: %1.
				     |Importe introducido: %3 %2
				     |Importe de la factura a cobrar: %4 %2';
				     |tr = 'Fatura alacak tutarı girilenden daha azdır. Ayrıntılar: %1.
				     |Girilen tutar: %3 %2
				     |Fatura alacak tutarı: %4 %2';
				     |it = 'L''importo da pagare della fattura è inferiore a quello inserito. Dettagli: %1.
				     |Importo inserito: %3 %2
				     |Importo da pagare della fattura:%4 %2';
				     |de = 'Der Forderungsbetrag der Rechnung ist niedriger als eingegeben. Details:%1.
				     |Eingegebener Betrag: %3 %2
				     |Forderungsbetrag der Rechnung: %4 %2'"),
				CounterpartyPresentation,
				CurrencyPresentation,
				String(RecordsSelection.SumCurOnWrite),
				String(-RecordsSelection.AmountCurBeforeWrite));
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				If RecordsSelection.AmountOfOutstandingAdvances = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The advance payment has been cleared by invoices. Details: %1.'; ru = 'Авансовый платеж был компенсирован инвойсами. Описание: %1';pl = 'Zaliczka została rozliczona na podstawie faktur. Szczegóły: %1.';es_ES = 'El pago del anticipo se ha amortizado con facturas. Detalles: %1.';es_CO = 'El pago Anticipado se ha amortizado con facturas. Detalles: %1.';tr = 'Avans ödeme, faturalarla mahsup edildi. Ayrıntılar: %1.';it = 'L''anticipo è stato compensato da fatture. Dettagli: %1.';de = 'Die Vorauszahlung wurde per Rechnung verrechnet. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The invoice is already settled in part. Details: %1.
					     |Advance balance: %3 %2'; 
					     |ru = 'Инвойс частично оплачен. Описание: %1.
					     |Остаток авансов: %3 %2';
					     |pl = 'Faktura jest już częściowo opłacona. Szczegóły: %1.
					     |Saldo zaliczki: %3 %2';
					     |es_ES = 'La factura ya está pagada en parte. Detalles: %1.
					     |Saldo de anticipos: %3 %2';
					     |es_CO = 'La factura ya está pagada en parte. Detalles: %1.
					     |Saldo de anticipos: %3 %2';
					     |tr = 'Fatura kısmen ödendi. Ayrıntılar: %1.
					     |Avans bakiyesi: %3 %2';
					     |it = 'La fattura è parzialmente saldata. Dettagli: %1.
					     | Importo pagamento anticipato non saldato: %3 %2';
					     |de = 'Die Rechnung wurde teilweise bezahlt. Details: %1.
					     |Voraussaldo: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingAdvances));
				EndIf;
			EndIf;
			
		Else
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				If RecordsSelection.AmountOfOutstandingDebt = 0 Then
					MessageText =StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The invoice is already settled in full. Details: %1.'; ru = 'Товарная накладная была полностью оплачена. Описание: %1.';pl = 'Faktura jest już w pełni opłacona. Szczegóły: %1.';es_ES = 'La factura ya está pagada en parte. Detalles: %1.';es_CO = 'La factura ya está pagada en parte. Detalles: %1.';tr = 'Fatura tamamen ödendi. Ayrıntılar: %1.';it = 'La fattura è già completamente saldata. Dettagli: %1.';de = 'Die Rechnung wurde vollständig bezahlt. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText =StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The invoice is already settled in part. Details: %1.
					     |Unpaid: %3 %2'; 
					     |ru = 'Товарная накладная уже частично оплачена. Описание: %1.
					     |Не оплачено: %3 %2';
					     |pl = 'Faktura jest już częściowo opłacona. Szczegóły: %1.
					     |Nieopłacono: %3 %2';
					     |es_ES = 'La factura ya está pagada en parte. Detalles: %1. 
					     |No pagado: %3 %2';
					     |es_CO = 'La factura ya está pagada en parte. Detalles: %1. 
					     |No pagado: %3 %2';
					     |tr = 'Fatura kısmen ödendi. Ayrıntılar: %1.
					     |Ödenmeyen: %3 %2';
					     |it = 'La fattura è parzialmente saldata. Dettagli: %1.
					     | Non pagato: %3 %2';
					     |de = 'Die Rechnung wurde teilweise bezahlt. Details: %1.
					     |Unbezahlt: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingDebt));
				EndIf;
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'You cannot clear a larger amount than the advance payment is. Details: %1.
				     |Entered amount: %3 %2 
				     |Advance balance: %4 %2'; 
				     |ru = 'Нельзя зачесть сумму, превышающую сумму аванса. Описание: %1.
				     |Указанная сумма: %3 %2 
				     |Остаток авансов: %4 %2';
				     |pl = 'Nie możesz wyczyścić większej kwoty niż suma płatności zaliczkowej. Szczegóły: %1.
				     |Wprowadzona kwota:%3 %2 
				     |Saldo zaliczki: %4 %2';
				     |es_ES = 'Usted no puede amortizar un importe mayor a que es el pago del anticipo. Detalles: %1.
				     | Importe introducido: %3 %2 
				     |Saldo de anticipos: %4 %2';
				     |es_CO = 'Usted no puede amortizar un importe mayor al pago Anticipado. Detalles: %1.
				     | Importe introducido: %3 %2 
				     |Saldo de anticipos: %4 %2';
				     |tr = 'Avans ödemesinden daha fazla bir tutarı mahsup edemezsiniz: Ayrıntılar: %1. 
				     | Girilen tutar: %3 %2
				     |Avans bakiyesi: %4 %2';
				     |it = 'Non è possibile cancellare un importo maggiore rispetto al pagamento anticipato. Dettagli: %1.
				     |Importo inserito:%3 %2
				     |Saldo anticipo: %4 %2';
				     |de = 'Sie können keinen größeren Betrag als die Vorauszahlung verrechnen. Details: %1.
				     |Eingegebener Betrag: %3 %2 
				     |Voraussaldo: %4 %2'"),
				CounterpartyPresentation,
				CurrencyPresentation,
				String(RecordsSelection.SumCurOnWrite),
				String(RecordsSelection.AdvanceAmountsReceived));
			EndIf;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Fixed assets.
//
Procedure ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The fixed asset might have been written off or transferred'; ru = 'Возможно, основное средство уже списано или передано';pl = 'Środek trwały mógł zostać rozchodowany lub przeniesiony';es_ES = 'El activo fijo podría haber sido amortizado o transferido';es_CO = 'El activo fijo podría haber sido amortizado o transferido';tr = 'Sabit kıymet silinmiş veya transfer edilmiş olabilir';it = 'Il cespite potrebbe essere stato cancellato o trasferito';de = 'Das Anlagevermögen wurde möglicherweise abgeschrieben oder übertragen'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Fixed asset: %1,
		|depreciated cost: %3'; 
		|ru = 'Основное средство: %1,
		|остаточная стоимость: %3';
		|pl = 'Środek trwały: %1,
		|naliczanie amortyzacji: %3';
		|es_ES = 'Activo fijo: %1, 
		|coste depreciado: %3';
		|es_CO = 'Activo fijo: %1, 
		|coste depreciado: %3';
		|tr = 'Sabit kıymet: %1,
		| amortismana tabi gider: %3';
		|it = 'Cespite: %1,
		|costo ammortamento: %3';
		|de = 'Anlagevermögen: %1,
		|abgeschriebene Kosten: %3'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			TrimAll(RecordsSelection.FixedAssetPresentation),
			String(RecordsSelection.DepreciatedCost));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Retail amount accounting.
//
Procedure ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'The debt of the POS %1 has been paid in full'; ru = 'Долг по заказам поставщику %1 полностью погашен';pl = 'Dług w POS %1 został zapłacony w całości';es_ES = 'La deuda del TPV %1 ha sido pagada por completo';es_CO = 'La deuda del TPV %1 ha sido pagada por completo';tr = '%1 POS''unun borcu tamamen ödendi';it = 'Il debito del POS %1 è stato pagato completamente';de = 'Die Schulden der POS %1 sind vollständig bezahlt'");
	
	MessagePattern = NStr("en = 'Debt balance: %1 %2'; ru = 'Остаток задолженности: %1 %2';pl = 'Saldo zobowiązania: %1 %2';es_ES = 'Saldo de deuda: %1 %2';es_CO = 'Saldo de deuda: %1 %2';tr = 'Borç bakiyesi: %1 %2';it = 'Saldo debito: %1 %2';de = 'Schuldensaldo: %1 %2'");
	
	TitleInDetailsShow = True;
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTitleTemplate,
				TrimAll(RecordsSelection.StructuralUnitPresentation));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			String(RecordsSelection.BalanceInRetail),
			TrimAll(RecordsSelection.CurrencyPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors by the register Serial numbers.
//
Procedure ShowMessageAboutPostingSerialNumbersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'Insufficient serial numbers quantity on %1 %2'; ru = 'Недостаточное количество серийных номеров по %1 %2';pl = 'Niewystarczająca ilość numerów seryjnych dla %1 %2';es_ES = 'Cantidad insuficiente de números de serie en %1 %2';es_CO = 'Cantidad insuficiente de números de serie en %1 %2';tr = '%1 %2''de yetersiz seri numarası miktarı';it = 'Quantità di numeri di serie non sufficienti in %1 %2';de = 'Zu geringe Menge an Seriennummern bei %1 %2'");
	
	MessagePattern = NStr("en = 'Product:
		|%1, serial number %2'; 
		|ru = 'Номенклатура:
		|%1, серийный номер %2';
		|pl = 'Produkt:
		|%1, numer seryjny %2';
		|es_ES = 'Producto:
		|%1, número de serie %2';
		|es_CO = 'Producto:
		|%1, número de serie %2';
		|tr = 'Ürün:
		|%1, seri numarası %2';
		|it = 'Articolo:
		|%1, numero di serie %2';
		|de = 'Produkt:
		|%1, Seriennummer%2'");
		
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	AccountingBySeveralDivisions = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				Or (NOT AccountingBySeveralDivisions And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				If WorkWithProductsClientServer.IsObjectAttribute("PresentationCell" , RecordsSelection) Then
					PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
				Else
					PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation);
				EndIf;
				
			EndIf;
			
			MessageTitleText = StringFunctionsClientServer.SubstituteParametersToString(
				MessageTitleTemplate,
				GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
				PresentationOfStructuralUnit);
				
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.SerialNumberPresentation));
			
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors by the register Serial numbers for a business unit list
//
Procedure ShowMessageAboutPostingSerialNumbersRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	MessageTitleText = NStr("en = 'Cannot post the document. You have specified products with serial numbers.
							|The quantity of these products in stock is insufficient.'; 
							|ru = 'Не удалось провести документ. Указана номенклатура с серийными номерами.
							|Номенклатуры с такими серийными номерами на складе недостаточно.';
							|pl = 'Nie można zatwierdzić dokumentu. Wybrano produkty z numerami seryjnymi.
							|Ilość tych produktów na stanie jest niewystarczająca.';
							|es_ES = 'No se puede enviar el documento. Se han especificado productos con números de serie.
							|La cantidad de estos productos en stock es insuficiente.';
							|es_CO = 'No se puede enviar el documento. Se han especificado productos con números de serie.
							|La cantidad de estos productos en stock es insuficiente.';
							|tr = 'Belge kaydedilemiyor. Seri numaralı ürünler belirttiniz.
							|Bu ürünlerin stoktaki miktarı yetersiz.';
							|it = 'Impossibile pubblicare il documento. Sono stati indicati prodotti con numeri di serie.
							|La quantità di questi prodotti in stock non è sufficiente.';
							|de = 'Fehler beim Buchen des Dokuments. Sie müssen Produkte mit Seriennummern angeben.
							|Die Menge dieser Produkte im Lager ist ungenügend.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1.
							|Serial number: %2.
							|Warehouse: %3, %4.
							|Available product quantity: %5 %6.
							|Product shortage: %7 %6.'; 
							|ru = 'Номенклатура: %1.
							|Серийный номер: %2.
							|Склад: %3, %4.
							|Доступное количество:%5 %6.
							|Не хватает: %7 %6';
							|pl = 'Produkt: %1.
							|Numer seryjny: %2.
							|Magazyn: %3, %4.
							|Dostępna ilość produktów: %5 %6.
							|Niedobór produktów: %7 %6.';
							|es_ES = 'Producto: %1.
							|Número de serie: %2.
							|Almacén: %3, %4.
							|Cantidad de producto disponible: %5 %6.
							|Falta de producto: %7 %6.';
							|es_CO = 'Producto: %1.
							|Número de serie: %2.
							|Almacén: %3, %4.
							|Cantidad de producto disponible: %5%6.
							|Falta de producto: %7%6.';
							|tr = 'Ürün: %1.
							|Seri numarası: %2.
							|Ambar: %3, %4.
							|Mevcut ürün miktarı: %5 %6.
							|Ürün eksiği: %7 %6.';
							|it = 'Prodotto: %1.
							|Numero di serie: %2.
							|Magazzino: %3, %4.
							|Quantità di prodotto disponibile:%5 %6.
							|Carenza di prodotto:%7 %6.';
							|de = 'Produkt: %1.
							|Seriennummer: %2.
							|Lager: %3, %4.
							|Verfügbare Produktmenge: %5 %6.
							|Produktfehlmenge: %7 %6.'");
	
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	AccountingBySeveralDivisions = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If (Not UseSeveralWarehouses And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
			Or (Not AccountingBySeveralDivisions And RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
			PresentationOfStructuralUnit = "";
		Else
			If WorkWithProductsClientServer.IsObjectAttribute("PresentationCell" , RecordsSelection) Then
				PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
			Else
				PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation);
			EndIf;
			
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.SerialNumberPresentation),
			GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
			PresentationOfStructuralUnit,
			String(RecordsSelection.BalanceSerialNumbers),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.BalanceQuantitySerialNumbers));
			
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are invoicing more than specified in the goods issue'; ru = 'Количество товара в счете превышает количество в документе отпуска товаров';pl = 'Fakturujesz więcej, niż określono w wydaniu zewnętrznym';es_ES = 'Usted está facturando más de lo especificado en las mercancías emitidas';es_CO = 'Usted está facturando más de lo especificado en las mercancías emitidas';tr = 'Ambar çıkışında belirtilenden daha fazla ürün fatura ediyorsunuz';it = 'State fatturando più di quanto specificato nella Spedizione Merce';de = 'Sie fakturieren mehr als im Warenausgang angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance in goods issue %2 %3, exceeds %4 %3. %5'; ru = 'Номенклатура %1, остаток в отпуске товаров %2 %3 превышен на %4 %3. %5';pl = 'Produkt: %1, saldo w wydaniu zewnętrznym %2 %3, przekracza o %4 %3. %5';es_ES = 'Producto: %1, saldo en la emisión de mercancías %2 %3, excede %4 %3. %5';es_CO = 'Producto: %1, saldo en la emisión de mercancías %2 %3, excede %4 %3. %5';tr = 'Ürün: %1, Ambar çıkışı bakiyesi %2 %3, %4 %3 kadar aşıldı. %5';it = 'Articolo: %1, il saldo nella Spedizione Merce %2 %3, supera %4 %3. %5';de = 'Produkt: %1, Balance in Warenausgang %2 %3, überschreitet %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						MessagePattern,
						PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation),
						RecordsSelection.BalanceGoodsShippedNotInvoiced,
						TrimAll(RecordsSelection.MeasurementUnitPresentation),
						-RecordsSelection.QuantityBalanceGoodsShippedNotInvoiced,
						TrimAll(RecordsSelection.GoodsIssuePresentation));
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are invoicing more than specified in the goods receipt'; ru = 'Количество в инвойсе превышает количество в поступлении товаров';pl = 'Fakturujesz więcej, niż określono w potwierdzeniu przyjęciu zewnętrznym';es_ES = 'Usted está facturando más de lo especificado en el recibo de mercancías';es_CO = 'Usted está facturando más de lo especificado en el recibo de mercancías';tr = 'Ambar girişinde belirtilenden daha fazlasını faturalandırmaktasınız';it = 'State fatturando più di quanto specificato nella ricezione merci';de = 'Sie fakturieren mehr als im Wareneingang angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance in goods receipt %2 %3, exceeds by %4 %3. %5'; ru = 'Номенклатура: %1 остаток в поступлении товаров %2 %3, превышен на %4 %3. %5';pl = 'Produkt: %1, saldo w przyjęciu zewnętrznym %2 %3, przekracza o %4 %3. %5';es_ES = 'Producto: %1, saldo en el recibo de mercancías %2 %3, excede por %4 %3. %5';es_CO = 'Producto: %1, saldo en el recibo de mercancías %2 %3, excede por %4 %3. %5';tr = 'Ürün: %1, Ambar girişi bakiyesi %2 %3, %4 %3 kadar aşıldı. %5';it = 'Articolo: %1, saldo nel documento di trasporto %2 %3, supera di %4 %3. %5';de = 'Produkt: %1, Saldo des Wareneingangs %2 %3, übersteigt um %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						MessagePattern,
						PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation),
						RecordsSelection.BalanceGoodsReceivedNotInvoiced,
						TrimAll(RecordsSelection.MeasurementUnitPresentation),
						-RecordsSelection.QuantityBalanceGoodsReceivedNotInvoiced,
						TrimAll(RecordsSelection.GoodsReceiptPresentation));
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsInvoicedNotReceivedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are receiving more than specified in the supplier invoice'; ru = 'Оформлено больше, чем указано в инвойсе поставщика.';pl = 'Odbierasz więcej niż określono w fakturze zakupu';es_ES = 'Usted está recibiendo más de que está especificado en la factura del proveedor';es_CO = 'Usted está recibiendo más de que está especificado en la factura del proveedor';tr = 'Satın alma faturasında belirtilenden daha fazlasını alıyorsunuz';it = 'State ricevendo più di quanto è specificato nella fattura fornitore';de = 'Sie erhalten mehr als in der Lieferantenrechnung angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, received %2 %3, surplus %4 %3. %5'; ru = 'Номенклатура: %1, получено %2 %3, излишек %4 %3. %5';pl = 'Produkt: %1, otrzymano %2 %3, nadwyżka %4 %3. %5';es_ES = 'Producto: %1, recibido%2 %3, superávit %4 %3. %5';es_CO = 'Producto: %1, recibido%2 %3, superávit %4 %3. %5';tr = 'Ürün: %1, alınan %2 %3, fazlalık %4 %3. %5';it = 'Articolo: %1, ricevuto %2 %3, eccesso %4 %3. %5';de = 'Produkt: %1, erhalten %2 %3, Überschuss %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic, RecordsSelection.Batch);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			RecordsSelection.QuantityBalanceBeforeChange,
			TrimAll(RecordsSelection.MeasurementUnit),
			-RecordsSelection.QuantityBalance,
			TrimAll(RecordsSelection.SupplierInvoice));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the sales invoice'; ru = 'Оформлено больше, чем указано в инвойсе покупателю.';pl = 'Wysyłasz więcej niż określono w zamówieniu faktura sprzedaży';es_ES = 'Usted está enviando más que está especificado en la factura de ventas';es_CO = 'Usted está enviando más que está especificado en la factura de ventas';tr = 'Satış faturasında belirtilenden daha fazla mal göndermektesiniz';it = 'State inviando più di quanto specificato nella fattura di vendita';de = 'Sie liefern mehr als in der Verkaufsrechnung angegeben'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, shipped %2 %3, surplus %4 %3. %5'; ru = 'Номенклатура: %1, отгружено %2 %3, излишек %4 %3. %5';pl = 'Produkt: %1, wysłano %2 %3, nadwyżka %4 %3. %5';es_ES = 'Producto: %1, enviado%2 %3, superávit%4 %3. %5';es_CO = 'Producto: %1, enviado%2 %3, superávit%4 %3. %5';tr = 'Ürün: %1, sevk edilen %2 %3, fazlalık %4 %3. %5';it = 'Articolo: %1, spedito %2 %3, eccesso %4 %3. %5';de = 'Produkt: %1, versandt %2 %3, Überschuss %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic, RecordsSelection.Batch);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.QuantityBalanceBeforeChange),
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.SalesInvoice));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToVATIncurredRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The entry results in negative inventory in the ""VAT incurred"" register'; ru = 'При проведении документа в регистре ""НДС предъявленный"" образуется отрицательный остаток.';pl = 'Wpis prowadzi do ujemnego stanu zapasów w rejestrze ""poniesione VAT""';es_ES = 'La entrada da como resultado un inventario negativo en el registro de ""IVA incurrido""';es_CO = 'La entrada da como resultado un inventario negativo en el registro de ""IVA incurrido""';tr = 'Bu giriş, ""Tahakkuk eden KDV"" kayıt defterinde negatif stok ile sonuçlanmaktadır';it = 'L''inserimento comporta scorte negative nel registro ""IVA pagata""';de = 'Die Buchung führt zu einem negativen Bestand im Register ""Angefallene USt""'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr(
		"en = 'Shipping document: %1, VAT rate: %2
	                        		|	Amount:	%3; exceeds: %4
	                        		|	VAT amount:			%5; exceeds: %6'; 
	                        		|ru = 'Документ доставки: %1, ставка НДС: %2
	                        		|	Сумма:	%3; Превышение: %4
	                        		|	Сумма НДС:			%5; превышает: %6';
	                        		|pl = 'Dokument przesyłki: %1, stawka VAT: %2
	                        		|	Kwota:	%3; przekracza: %4
	                        		|	Kwota VAT:			%5; przekracza: %6';
	                        		|es_ES = 'Documento de envío: %1, tasa del IVA: %2
	                        		|	Importe:	%3; excede: %4
	                        		|	IVA importe:			%5; excede: %6';
	                        		|es_CO = 'Documento de envío: %1, tasa del IVA: %2
	                        		|	Importe:	%3; excede: %4
	                        		|	IVA importe:			%5; excede: %6';
	                        		|tr = 'Nakliye belgesi: %1, KDV oranı: %2
	                        		|	Tutar:	%3; %4
	                        		| aşar:	KDV tutarı:			%5; aşılan tutar: %6';
	                        		|it = 'Documento di spedizione: %1, aliquota IVA: %2
	                        		| 	Importo:	%3; supera: %4
	                        		|	Importo IVA:			%5; supera: %6';
	                        		|de = 'Lieferschein: %1, USt.-Satz: %2
	                        		|	Betrag:	%3; übersteigt: %4
	                        		|	USt.-Betrag:			%5; übersteigt: %6'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						MessagePattern,
						TrimAll(RecordsSelection.ShipmentDocument),
						TrimAll(RecordsSelection.VATRate),
						RecordsSelection.AmountExcludesVAT,
						-RecordsSelection.AmountExcludesVATBalance,
						RecordsSelection.VATAmount,
						-RecordsSelection.VATAmountBalance);
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToFundsTransfersBeingProcessed(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF
		+ NStr("en = 'The total document amount cannot exceed the payment processor balance recorded by Online payments and Online receipts.'; ru = 'Общая сумма документа не может превышать баланс платежной системы, зарегистрированный онлайн-платежами и онлайн-чеками.';pl = 'Ogólna wartość dokumentu nie może przekraczać bilansu systemu płatności, zapisanego przez Płatności online i Paragony online.';es_ES = 'El importe total del documento no puede superar el saldo del procesador de pagos registrado por Pagos en línea y Recibos en línea.';es_CO = 'El importe total del documento no puede superar el saldo del procesador de pagos registrado por Pagos en línea y Recibos en línea.';tr = 'Toplam belge tutarı, Çevrimiçi ödemelerin ve Çevrimiçi tahsilatların kaydettiği ödeme işlemcisi bakiyesini aşamaz.';it = 'L''importo totale dei documenti non può essere maggiore il saldo dell''elaboratore di pagamenti registrato dai Pagamenti online e dalle Ricevute online.';de = 'Die Gesamtsumme darf den Zahlungsanbieter-Saldo eingetragen von Online-Überweisungen und Onlinebelegen nicht überschreiten.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'POS terminal: %1; Document: %2;
		|Amount: %4 %3; Payment processor balance: %5 %3;
		|Fee: %6 %3; Fee balance: %7 %3.'; 
		|ru = 'Эквайринговый терминал:%1; Документ:%2;
		|Сумма: %4 %3; Баланс платежной системы: %5 %3;
		|Комиссия: %6 %3; Остаток комиссии: %7 %3. ';
		|pl = 'Terminal POS: %1; Dokument: %2;
		|Wartość: %4 %3; Bilans Systemu płatności: %5 %3;
		|Prowizja: %6 %3; Saldo prowizji: %7 %3.';
		|es_ES = 'Terminal TPV: %1; Documento: %2;
		|Importe: %4 %3; Saldo del procesador de pagos: %5 %3;
		|Tasa: %6 %3; Saldo de la tasa: %7 %3.';
		|es_CO = 'Terminal TPV: %1; Documento: %2;
		|Importe: %4 %3; Saldo del procesador de pagos: %5 %3;
		|Tasa: %6 %3; Saldo de la tasa: %7 %3.';
		|tr = 'POS terminali: %1; Belge: %2;
		|Tutar: %4 %3; Ödeme işlemcisi bakiyesi: %5 %3;
		|Ücret: %6 %3; Ücret bakiyesi: %7 %3.';
		|it = 'Terminale POS: %1; Documento: %2;
		|Importo: %4 %3; Saldo elaboratore pagamenti: %5 %3;
		|Commissione: %6 %3; Saldo commissioni: %7 %3.';
		|de = 'POS-Terminal: %1; Dokument: %2;
		|Summe: %4 %3; Saldo des Zahlungsanbieters: %5 %3;
		|Gebühr: %6 %3; Gebührensaldo: %7 %3.'");
	
	MessagePatternNoDoc = NStr("en = 'POS terminal: %1;
		|Amount: %3 %2; Payment processor balance: %4 %2.'; 
		|ru = 'Эквайринговый терминал: %1
		|Сумма: %3 %2; Баланс платежной системы:%4 %2.';
		|pl = 'Terminal POS: %1;
		|Wartość: %3 %2; Bilans Systemu płatności: %4 %2.';
		|es_ES = 'Terminal TPV: %1;
		|Importe: %3 %2; Saldo del procesador de pagos: %4 %2.';
		|es_CO = 'Terminal TPV: %1;
		|Importe: %3 %2; Saldo del procesador de pagos: %4 %2.';
		|tr = 'POS terminali: %1;
		|Tutar: %3 %2; Ödeme işlemcisi bakiyesi: %4 %2.';
		|it = 'Terminale POS: %1;
		|Importo: %3 %2; Saldo elaboratore pagamenti: %4 %2.';
		|de = 'POS-Terminal: %1;
		|Summe: %3 %2; Saldo des Zahlungsanbieters: %4 %2.'");
		
	While RecordsSelection.Next() Do
		
		If ValueIsFilled(RecordsSelection.Document) Then
			
			Sign = 1 - 2 * Number(TypeOf(RecordsSelection.Document) = Type("DocumentRef.OnlinePayment"));
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePattern,
				TrimAll(RecordsSelection.POSTerminal),
				RecordsSelection.Document,
				TrimAll(RecordsSelection.Currency),
				Sign * (RecordsSelection.AmountCurBalanceBeforeChange - RecordsSelection.AmountCurBalance),
				Sign * RecordsSelection.AmountCurBalanceBeforeChange,
				RecordsSelection.FeeAmountBalanceBeforeChange - RecordsSelection.FeeAmountBalance,
				RecordsSelection.FeeAmountBalanceBeforeChange);
			
		Else
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessagePatternNoDoc,
				TrimAll(RecordsSelection.POSTerminal),
				TrimAll(RecordsSelection.Currency),
				RecordsSelection.AmountCurBalanceBeforeChange - RecordsSelection.AmountCurBalance,
				RecordsSelection.AmountCurBalanceBeforeChange);
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToBankReconciliationRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = '""Bank reconciliation"" register: Transaction amount and cleared amount differ'; ru = 'Регистр ""Взаиморасчеты с банком"": Сумма операции и сумма зачета отличаются';pl = 'Rejestr ""Uzgodnienie banku"": Kwota transakcji i kwota rozliczona są różne';es_ES = 'Registro de ""Conciliación bancaria"": El importe de la transacción y el importe liquidado difieren';es_CO = 'Registro de ""Conciliación bancaria"": El importe de la transacción y el importe liquidado difieren';tr = '""Banka mutabakatı"" kaydı: İşlem tutarı ve kullanıma uygun tutar farklı';it = 'Registro ""Riconciliazioni bancarie"": importo transazione e differenza di importo compensato';de = 'Register ""Bankabstimmung"": Transaktionsmenge und verrechnete Menge unterscheiden sich'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Bank account: %1, transaction: %2, type: %3, amount: %4 cleared: %5'; ru = 'Банковский счет: %1, операция: %2, тип: %3, сумма: %4 сумма зачета: %5';pl = 'Rachunek bankowy: %1, transakcja: %2, rodzaj: %3, kwota: %4 rozliczona: %5';es_ES = 'Cuenta bancaria: %1, transacción:%2, tipo: %3, importe: %4 liquidado: %5';es_CO = 'Cuenta bancaria: %1, transacción:%2, tipo: %3, importe: %4 liquidado: %5';tr = 'Banka hesabı: %1, işlem: %2, tür: %3, tutar: %4, ibra edilen: %5';it = 'Conto corrente: %1, transazione: %2, tipo: %3, importo: %4 compensato: %5';de = 'Bankkonto: %1, Transaktion: %2, Typ: %3, Betrag: %4, verrechnet: %5'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			RecordsSelection.BankAccount,
			RecordsSelection.Transaction,
			RecordsSelection.TransactionType,
			RecordsSelection.Amount,
			RecordsSelection.AmountCleared);
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Subcontractor orders statement.
//
Procedure ShowMessageAboutPostingToSubcontractorOrdersIssuedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle
		+ Chars.LF
		+ NStr("en = 'Quantity of finished products received is more than specified quantity in the subcontractor order issued'; ru = 'Количество полученной готовой продукции больше, чем указано в выданном заказе на переработку';pl = 'Ilość otrzymanych produktów gotowych jest większa niż określona ilość w wydanym zamówieniu wykonawcy';es_ES = 'La cantidad de productos terminados recibidos excede la cantidad especificada en la orden emitida del subcontratista';es_CO = 'La cantidad de productos terminados recibidos excede la cantidad especificada en la orden emitida del subcontratista';tr = 'Alınan nihai ürün miktarı, düzenlenen alt yüklenici siparişinde belirtilen miktardan fazla';it = 'La quantità di articoli finiti ricevuti è maggiore della quantità specificata nell''ordine di subfornitura emesso';de = 'Menge der erhaltenen Fertigprodukte überschreitet die angegebene Menge im Subunternehmerauftrag ausgegeben'");
	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, surplus %3 %2. %4'; ru = 'Номенклатура: %1, излишки %3 %2. %4';pl = 'Produkt: %1, nadwyżka %3 %2. %4';es_ES = 'Producto: %1, superávit %3 %2. %4';es_CO = 'Producto: %1, superávit %3 %2. %4';tr = 'Ürün: %1, fazlalık %3 %2. %4';it = 'Articolo: %1, surplus %3 %2. %4';de = 'Produkt: %1, Überschuss %3 %2. %4'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.SubcontractorOrder));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Subcontract components statement.
//
Procedure ShowMessageAboutPostingToSubcontractComponentsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	MessageText = NStr("en = 'The quantity of components issued cannot be greater than the quantity specified in the Subcontractor order issued'; ru = 'Количество выданных компонентов не может быть больше количества, указанного в выданном заказе на переработку';pl = 'Ilość wydanych komponentów nie może być większa niż ilość, określona w Wydanym zamówieniu wykonawcy';es_ES = 'La cantidad de componentes emitidos no puede ser superior a la cantidad especificada en la orden emitida del Subcontratista';es_CO = 'La cantidad de componentes emitidos no puede ser superior a la cantidad especificada en la orden emitida del Subcontratista';tr = 'Düzenlenen malzeme miktarı, düzenlenen Alt yüklenici siparişinde belirtilen miktardan büyük olamaz';it = 'La quantità di componenti emesse non può essere maggiore della quantità specificata dall''ordine di subfornitura emesso';de = 'Die Menge von ausgegebenen Komponenten darf die im Subunternehmerauftrag ausgestellt angegebene Menge nicht überschreiten'");
	
	// begin Drive.FullVersion
	If TypeOf(DocObject) = Type("DocumentObject.SubcontractorInvoiceIssued") Then
		MessageText = NStr("en = 'The quantity of components cannot be greater than the quantity specified in the Subcontractor order received.'; ru = 'Количество компонентов не может быть больше количества, указанного в полученном заказе на переработку.';pl = 'Ilość komponentów nie może być większa niż ilość, określona w otrzymanym zamówieniu podwykonawcy.';es_ES = 'La cantidad de componentes no puede ser superior a la especificada en la orden recibida del Subcontratista.';es_CO = 'La cantidad de componentes no puede ser superior a la especificada en la orden recibida del Subcontratista.';tr = 'Malzeme miktarı, alınan Alt yüklenici siparişinde belirtilen miktardan büyük olamaz.';it = 'La quantità di componenti non può essere maggiore della quantità specificata nell''ordine di subfornitura ricevuto.';de = 'Die Menge von Komponenten darf die im Subunternehmerauftrag erhalten angegebene Menge nicht überschreiten.'");
	EndIf;
	// end Drive.FullVersion 
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + MessageText;
	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, surplus %3 %2. %4'; ru = 'Номенклатура: %1, излишки %3 %2. %4';pl = 'Produkt: %1, nadwyżka %3 %2. %4';es_ES = 'Producto: %1, superávit %3 %2. %4';es_CO = 'Producto: %1, superávit %3 %2. %4';tr = 'Ürün: %1, fazlalık %3 %2. %4';it = 'Articolo: %1, surplus %3 %2. %4';de = 'Produkt: %1, Überschuss %3 %2. %4'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.SubcontractorOrder));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// begin Drive.FullVersion

// The procedure informs of errors that occurred when posting by register Subcontract components statement.
//
Procedure ShowMessageAboutPostingToProductionComponentsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	MessageText = NStr("en = 'The quantity of components cannot be less than the quantity specified in the Production'; ru = 'Количество компонентов не может быть меньше количества, указанного в документе ""Производство""';pl = 'Ilość komponentów nie może być większa niż ilość, określona w otrzymanym Produkcji';es_ES = 'La cantidad de componentes no puede ser inferior a la especificada en la Producción';es_CO = 'La cantidad de componentes no puede ser inferior a la especificada en la Producción';tr = 'Malzeme miktarı, Üretim''de belirtilen miktardan daha az olamaz';it = 'La quantità di componenti non può essere minore della quantità specificata nella produzione';de = 'Die Menge von Komponenten darf nicht unter der im Produktion angegebenen Menge liegen.'");
	
	If TypeOf(DocObject) = Type("DocumentObject.Manufacturing") Then
		MessageText = NStr("en = 'The quantity of components cannot be greater than the quantity specified in the Production order.'; ru = 'Количество компонентов не может быть больше количества, указанного в заказе на производство.';pl = 'Ilość komponentów nie może być większa niż ilość, określona w Zleceniu produkcyjnym.';es_ES = 'La cantidad de componentes no puede ser superior a la especificada en la Orden de producción.';es_CO = 'La cantidad de componentes no puede ser superior a la especificada en la Orden de producción.';tr = 'Malzeme miktarı, Üretim emrinde belirtilen miktardan büyük olamaz.';it = 'La quantità di componenti non può essere maggiore della quantità specificata nell''ordine di produzione.';de = 'Die Menge von Komponenten darf die im Produktionsauftrag angegebene Menge nicht überschreiten.'");
	EndIf;
	
	ErrorTitle = NStr("en = 'Error:'; ru = 'Ошибка:';pl = 'Błąd:';es_ES = 'Error:';es_CO = 'Error:';tr = 'Hata:';it = 'Errore:';de = 'Fehler:'");
	MessageTitleText = ErrorTitle + Chars.LF + MessageText;
	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, surplus %3 %2. %4'; ru = 'Номенклатура: %1, излишки %3 %2. %4';pl = 'Produkt: %1, nadwyżka %3 %2. %4';es_ES = 'Producto: %1, superávit %3 %2. %4';es_CO = 'Producto: %1, superávit %3 %2. %4';tr = 'Ürün: %1, fazlalık %3 %2. %4';it = 'Articolo: %1, surplus %3 %2. %4';de = 'Produkt: %1, Überschuss %3%2.%4'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.ProductionDocument));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Work-in-progress statement.
//
Procedure ShowMessageAboutPostingToWorkInProgressStatementRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	MessageTitleText = NStr("en = 'Product quantity exceeds the quantity in the related Work-in-progress (WIP).'; ru = 'Количество номенклатуры превышает количество в связанном документе ""Незавершенное производство"".';pl = 'Ilość produktu przekracza ilość w powiązanej pracy w toku.';es_ES = 'La cantidad de producto excede la cantidad en el Trabajo en progreso relacionado (WIP).';es_CO = 'La cantidad de producto excede la cantidad en el Trabajo en progreso relacionado (WIP).';tr = 'Ürün miktarı, ilgili İşlem bitişindeki miktardan fazla.';it = 'La quantità di articoli eccede la quantità nel Lavoro in corso correlato.';de = 'Produktmenge überschreitet die Menge in der verbundenen Arbeit in Bearbeitung (WIP).'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	While RecordsSelection.Next() Do
		
		MessagePattern = NStr("en = 'For product %1, the quantity exceeds the WIP quantity (%2 %3) by %4 %3.
			|To be able to continue, edit either of the quantities so that they match.'; 
			|ru = 'Количество номенклатуры %1 превышает количество в Незавершенном производстве (%2 %3) на %4 %3.
			|Для продолжения отредактируйте любое из количеств, чтобы они совпадали.';
			|pl = 'Dla produktu %1, ilość przekracza ilość Pracy w toku (%2 %3) o %4 %3.
			|Aby kontynuować, edytuj jedną z wartości aby jednakowe.';
			|es_ES = 'Para el producto %1, la cantidad excede la cantidad WIP (%2 %3) en %4 %3.
			|Para poder continuar, edite cualquiera de las cantidades para que coincidan.';
			|es_CO = 'Para el producto %1, la cantidad excede la cantidad WIP (%2 %3) en %4 %3.
			|Para poder continuar, edite cualquiera de las cantidades para que coincidan.';
			|tr = '%1 ürününün miktarı İşlem bitişi miktarından (%2 %3) %4 %3 fazla.
			|Devam edebilmek için miktarlardan birini değiştirerek eşitleyin.';
			|it = 'Per l''articolo %1, la quantità eccede la quantità di WIP (%2 %3) di %4%3.
			| Per continuare modificare una delle quantità così che corrispondano.';
			|de = 'Für Produkt %1, überschreitet die Menge aus Arbeit in Bearbeitung (%2 %3) by %4 %3.
			|Um fortfahren zu können, bearbeiten Sie eine der Mengen für Übereinstimmen.'");
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			RecordsSelection.QuantityBalanceBeforeChange,
			TrimAll(RecordsSelection.MeasurementUnit),
			-RecordsSelection.QuantityBalance);

		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// end Drive.FullVersion

// The procedure informs of errors that occurred when posting return advance payment
// by register AccountsReceivable / AccountsPayable.
//
Procedure ShowMessageAboutPostingReturnAdvanceToAccountsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	While RecordsSelection.Next() Do
		
		CounterpartyPresentation = CounterpartyPresentation(
			RecordsSelection.CounterpartyPresentation,
			RecordsSelection.ContractPresentation,
			RecordsSelection.DocumentPresentation,
			RecordsSelection.OrderPresentation,
			RecordsSelection.CalculationsTypesPresentation);
			
		CurrencyPresentation = TrimAll(RecordsSelection.CurrencyPresentation);

		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot post the document. Amount in line %1 exceeds the advance balance.
			     |Amount: %3 %2. 
			     |Advance balance: %4 %2.
				 |Edit Amount. Then try again.'; 
			     |ru = 'Не удалось провести документ. Сумма в строке %1 превышает остаток авансов.
			     |Сумма: %3 %2. 
			     |Остаток авансов: %4 %2.
			     |Измените сумму и повторите попытку.';
			     |pl = 'Nie można zatwierdzić dokumentu. Kwota w wierszu %1 przekracza saldo zaliczek.
			     |Kwota: %3 %2. 
			     |Saldo zaliczek: %4 %2.
			     |Zmień kwotę. Zatem spróbuj ponownie.';
			     |es_ES = 'No se puede enviar el documento. El importe de la línea %1 supera el saldo de anticipos.
			     |Saldo: %3%2. 
			     |Saldo de anticipos: %4 %2.
			     |Edite el importe. Inténtelo de nuevo.';
			     |es_CO = 'No se puede enviar el documento. El importe de la línea %1 supera el saldo de anticipos.
			     |Saldo: %3%2. 
			     |Saldo de anticipos: %4 %2.
			     |Edite el importe. Inténtelo de nuevo.';
			     |tr = 'Belge kaydedilemiyor. %1 satırındaki tutar avans bakiyesinden fazla.
			     |Tutar: %3 %2. 
			     |Avans bakiyesi: %4 %2.
			     |Tutarı değiştirip tekrar deneyin.';
			     |it = 'Impossibile pubblicare il documento. L''importo nella riga %1 eccede il saldo di anticipo. 
			     |Importo: %3 %2.
			     |Saldo anticipo: %4%2.
			     |Modificare Importo, poi riprovare.';
			     |de = 'Fehler beim Buchen des Dokuments. Die Menge in der Zeile %1 überschreitet den Voraussaldo.
			     |Menge: %3 %2. 
			     |Voraussaldo: %4 %2.
			     |Bearbeiten Sie die Menge. Dann versuchen Sie erneut.'"),
			CounterpartyPresentation,
			CurrencyPresentation,
			String(RecordsSelection.SumCurOnWrite),
			String(RecordsSelection.AdvanceAmountsReceived));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting refunds by register Inventory.
//
Procedure ShowMessageAboutPostingToInventoryRegisterRefundsErrors(DocObject, RecordsSelection, Cancel) Export
	
	MessageTitleText = NStr("en = 'Error: There is more quantity of returned goods than in initial document.'; ru = 'Ошибка: количество возвращаемых товаров превышает количество в исходном документе.';pl = 'Błąd: Ilość zwróconych towarów jest większa niż w początkowym dokumencie.';es_ES = 'Error: La cantidad de mercancías devueltas supera la indicada en el documento inicial.';es_CO = 'Error: La cantidad de mercancías devueltas supera la indicada en el documento inicial.';tr = 'Hata: İade edilen mal miktarı başlangıç belgesindekinden fazla.';it = 'Errore: Vi è più quantità di merci restituite di quanto indicato nel documento iniziale.';de = 'Fehler: Es gibt mehrere Menge der zurückgegebenen Produkte als im Ausgangsdokument.'");	
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance to be returned %2 %3, extra %4 %5'; ru = 'Номенклатура: %1, остаток к возврату %2 %3, дополнительно %4 %5';pl = 'Produkt: %1, pozostało do zwrotu %2 %3, dodatkowo %4 %5';es_ES = 'Producto: %1, saldo a devolver %2 %3, extra %4 %5';es_CO = 'Producto: %1, saldo a devolver %2 %3, extra %4 %5';tr = 'Ürün: %1, iade edilecek bakiye %2 %3, fazlalık %4 %5';it = 'Articolo: %1, saldo da restituire %2 %3, extra %4 %5';de = 'Produkt: %1, Saldo zur Rückgabe %2 %3, Extra %4 %5'");	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.BalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			String(-RecordsSelection.QuantityBalanceInventory),
			TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region SsmSubsystemsProceduresAndFunctions

// Procedure adds formula parameters to the structure.
//
Procedure AddParametersToStructure(FormulaString, ParametersStructure, Cancel = False) Export

	Formula = FormulaString;
	
	OperandStart = Find(Formula, "[");
	OperandEnd = Find(Formula, "]");
     
	IsOperand = True;
	While IsOperand Do
     
		If OperandStart <> 0 And OperandEnd <> 0 Then
			
            ID = TrimAll(Mid(Formula, OperandStart+1, OperandEnd - OperandStart - 1));
            Formula = Right(Formula, StrLen(Formula) - OperandEnd);   
			
			Try
				If Not ParametersStructure.Property(ID) Then
					ParametersStructure.Insert(ID);
				EndIf;
			Except
			    Break;
				Cancel = True;
			EndTry 
			 
		EndIf;     
          
		OperandStart = Find(Formula, "[");
		OperandEnd = Find(Formula, "]");
          
		If Not (OperandStart <> 0 And OperandEnd <> 0) Then
			IsOperand = False;
        EndIf;     
               
	EndDo;	

EndProcedure

// Function returns parameter value
//
Function CalculateParameterValue(ParametersStructure, CalculationParameter, ErrorText = "") Export
	
	// 1. Create query
	Query = New Query;
	Query.Text = CalculationParameter.Query;
	
	// 2. Control of all query parameters filling
	For Each QueryParameter In CalculationParameter.QueryParameters Do
		
		If ValueIsFilled(QueryParameter.Value) Then
			
			Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);
			
		Else
			
			If ParametersStructure.Property(StrReplace(QueryParameter.Name, ".", "")) Then
				
				PeriodString = CalculationParameter.DataFilterPeriods.Find(StrReplace(QueryParameter.Name, ".", ""), "BoundaryDateName");
				If PeriodString <> Undefined  Then
					
					If PeriodString.PeriodShift <> 0 Then
						NewPeriod = AddInterval(ParametersStructure[StrReplace(QueryParameter.Name, ".", "")], PeriodString.ShiftPeriod, PeriodString.PeriodShift);
						Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), NewPeriod);
					Else
						Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);
					EndIf;
					
				Else
					
					Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);
					
				EndIf; 
				
			ElsIf ValueIsFilled(TypeOf(QueryParameter.Value)) Then
				
				Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);
				
			Else
				
				Message = New UserMessage();
				Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Value for parameter %1 is not specified.'; ru = 'Не указано значение параметра %1.';pl = 'Wartość parametru %1 nie została określona.';es_ES = 'El valor para el parámetro %1 no está especificado.';es_CO = 'El valor para el parámetro %1 no está especificado.';tr = '%1 parametresi için değer belirtilmedi.';it = 'Il valore per il parametro %1 non è specificato.';de = 'Der Wert für den Parameter %1 ist nicht angegeben.'"),
					QueryParameter.Name) 
					+ ErrorText;
				Message.Message();
				
				Return 0;
			EndIf;
			
		EndIf; 
		
	EndDo; 
	
	// 4. Query execution
	QueryResult = Query.Execute().Unload();
	If QueryResult.Count() = 0 Then
		
		Return 0;
		
	Else
		
		Return QueryResult[0][0];
		
	EndIf;
	
EndFunction

// Function adds interval to date
//
// Parameters:
//     Periodicity (Enum.Periodicity)     - planning periodicity by script.
//     DateInPeriod (Date)                                   - custom
//     date Shift (number)                                   - defines the direction and quantity of periods where date
//     is moved
//
// Returns:
//     Date remote from the original by the specified periods quantity 
//
Function AddInterval(PeriodDate, Periodicity, Shift) Export

     If Shift = 0 Then
          NewPeriodData = PeriodDate;
          
     ElsIf Periodicity = Enums.Periodicity.Day Then
          NewPeriodData = BegOfDay(PeriodDate + Shift * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Week Then
          NewPeriodData = BegOfWeek(PeriodDate + Shift * 7 * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Month Then
          NewPeriodData = AddMonth(PeriodDate, Shift);
          
     ElsIf Periodicity = Enums.Periodicity.Quarter Then
          NewPeriodData = AddMonth(PeriodDate, Shift * 3);
          
     ElsIf Periodicity = Enums.Periodicity.Year Then
          NewPeriodData = AddMonth(PeriodDate, Shift * 12);
          
     Else
          NewPeriodData=BegOfDay(PeriodDate) + Shift * 24 * 3600;
          
     EndIf;

     Return NewPeriodData;

EndFunction

// Receives default expenses invoice of Earning type.
//
// Parameters:
//  DataStructure - Structure containing object attributes
//                 that should be received and filled in
//                 with attributes that are required for receipt.
//
Procedure GetEarningKindGLExpenseAccount(DataStructure) Export
	
	EarningAndDeductionType = DataStructure.EarningAndDeductionType;
	GLExpenseAccount = EarningAndDeductionType.GLExpenseAccount;
	
	If EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Tax Then
		
		GLExpenseAccount = EarningAndDeductionType.TaxKind.GLAccount;
		
		If GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.AccountsPayable Then			
			GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();			
		EndIf;
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Earning Then
		
		If ValueIsFilled(DataStructure.StructuralUnit) Then
			
			TypeOfAccount = GLExpenseAccount.TypeOfAccount;
			If DataStructure.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department
				And Not (TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					Or TypeOfAccount = Enums.GLAccountsTypes.Expenses
					Or TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
					Or TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					Or TypeOfAccount = Enums.GLAccountsTypes.WorkInProgress
					Or TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets) Then
				
				GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
				
			EndIf;
			
		EndIf;
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Deduction Then		
		GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");	
	EndIf;
	
	DataStructure.GLExpenseAccount	= GLExpenseAccount;
	DataStructure.TypeOfAccount		= GLExpenseAccount.TypeOfAccount;
	
EndProcedure

// Function generates a last name, name and patronymic as a string.
//
// Parameters
//  Surname      - last name of ind. bodies
//  Name          - name ind. bodies
//  Patronymic     - patronymic ind. bodies
//  DescriptionFullShort    - Boolean - If True (by default), then
//                 the individual presentation includes a last name and initials if False - surname
//                 or name and patronymic.
//
// Return value
// Surname, name, patronymic as one string.
//
Function GetSurnameNamePatronymic(Surname = " ", Name = " ", Patronymic = " ", NameAndSurnameShort = True) Export
	
	If NameAndSurnameShort Then
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Left(Name,1) + "." + 
				?(NOT IsBlankString(Patronymic) , 
				Left(Patronymic,1)+".", ""), ""), "");
	Else
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Name + 
				?(NOT IsBlankString(Patronymic) , " " + Patronymic, ""), ""), "");
	EndIf;

EndFunction

// Function defines whether calculation method or Earning kind was input earlier
//
// IdentifierValue (Row) - Identifier attribute value of the CalculationParameters catalog item
//
Function SettlementsParameterExist(IdentifierValue) Export
	
	If IsBlankString(IdentifierValue)Then
		
		Return False;
		
	EndIf;
	
	Return Not Catalogs.EarningsCalculationParameters.FindByAttribute("ID", IdentifierValue) = Catalogs.EarningsCalculationParameters.EmptyRef();
	
EndFunction

// Function determines whether the initial filling of the EarningAndDeductionTypes catalog is executed
//
//
Function EarningAndDeductionTypesInitialFillingPerformed() Export
	
	Query = New Query("SELECT ALLOWED * FROM Catalog.EarningAndDeductionTypes AS AAndDKinds WHERE NOT AAndDKinds.Predefined");
	
	QueryResult = Query.Execute();
	Return Not QueryResult.IsEmpty();
	
EndFunction

#EndRegion

#Region TransactionsMirrorProceduresAndFunctions

// Generates transactions table structure.
//
Procedure GenerateTransactionsTable(DocumentRef, AddProperties) Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED TOP 0
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Status AS Status,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntries.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntries.TransactionTemplateLineNumber AS TransactionTemplateLineNumber,
	|	AccountingJournalEntries.TypeOfAccounting AS TypeOfAccounting
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 0
	|	AccountingJournalEntriesCompound.Period AS Period,
	|	AccountingJournalEntriesCompound.Recorder AS Recorder,
	|	AccountingJournalEntriesCompound.LineNumber AS LineNumber,
	|	AccountingJournalEntriesCompound.RecordType AS RecordType,
	|	AccountingJournalEntriesCompound.Account AS Account,
	|	AccountingJournalEntriesCompound.Company AS Company,
	|	AccountingJournalEntriesCompound.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesCompound.Currency AS Currency,
	|	AccountingJournalEntriesCompound.Status AS Status,
	|	AccountingJournalEntriesCompound.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesCompound.Amount AS Amount,
	|	AccountingJournalEntriesCompound.AmountCur AS AmountCur,
	|	AccountingJournalEntriesCompound.Quantity AS Quantity,
	|	AccountingJournalEntriesCompound.Content AS Content,
	|	AccountingJournalEntriesCompound.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesCompound.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesCompound.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesCompound AS AccountingJournalEntriesCompound
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 0
	|	AccountingJournalEntriesSimple.Period AS Period,
	|	AccountingJournalEntriesSimple.Recorder AS Recorder,
	|	AccountingJournalEntriesSimple.LineNumber AS LineNumber,
	|	AccountingJournalEntriesSimple.AccountDr AS AccountDr,
	|	AccountingJournalEntriesSimple.AccountCr AS AccountCr,
	|	AccountingJournalEntriesSimple.Company AS Company,
	|	AccountingJournalEntriesSimple.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntriesSimple.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntriesSimple.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntriesSimple.Status AS Status,
	|	AccountingJournalEntriesSimple.TypeOfAccounting AS TypeOfAccounting,
	|	AccountingJournalEntriesSimple.Amount AS Amount,
	|	AccountingJournalEntriesSimple.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntriesSimple.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntriesSimple.QuantityDr AS QuantityDr,
	|	AccountingJournalEntriesSimple.QuantityCr AS QuantityCr,
	|	AccountingJournalEntriesSimple.Content AS Content,
	|	AccountingJournalEntriesSimple.OfflineRecord AS OfflineRecord,
	|	AccountingJournalEntriesSimple.TransactionTemplate AS TransactionTemplate,
	|	AccountingJournalEntriesSimple.TransactionTemplateLineNumber AS TransactionTemplateLineNumber
	|FROM
	|	AccountingRegister.AccountingJournalEntriesSimple AS AccountingJournalEntriesSimple";
	
	QueryResult = Query.ExecuteBatch();
	
	AddProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries",			QueryResult[0].Unload());
	AddProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntriesCompound",	QueryResult[1].Unload());
	AddProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntriesSimple",		QueryResult[2].Unload());
	
EndProcedure

#EndRegion

#Region ExplosionProceduresAndFunctions

// Generate structure with definite fields content for explosion.
//
// Parameters:
//  No.
//
// Returns:
//  Structure - structure with defined fields content
// for explosion.
//
Function GenerateContentStructure() Export
	
	Structure = New Structure();
	
	// Current node description fields.
	Structure.Insert("Products");
	Structure.Insert("Characteristic");
	Structure.Insert("MeasurementUnit");
	Structure.Insert("Quantity");
	Structure.Insert("AccountingPrice");
	Structure.Insert("Cost");
	Structure.Insert("Specification");
	Structure.Insert("ContentRowType");
	Structure.Insert("TableOperations");
	
	// Auxiliary data.
	Structure.Insert("Object");
	Structure.Insert("ProcessingDate", '00010101');
	Structure.Insert("Level");
	Structure.Insert("PriceKind");
	
	Return Structure;
	
EndFunction

// Function returns operations table.
//
// Parameters:
//  ContentStructure - Content structure
//
// Returns:
//  Values table with operations.
//
Function GetSpecificationOperations(ContentStructure)
	
	Query = New Query; 
	Query.Text =
	"SELECT ALLOWED
	|	OperationSpecification.Operation AS Operation,
	|	OperationSpecification.TimeNorm / OperationSpecification.Ref.Quantity AS TimeNorm,
	|	OperationSpecification.TimeNorm / OperationSpecification.Ref.Quantity * &Quantity AS Duration,
	|	ISNULL(PricesSliceLast.Price, 0) AS AccountingPrice,
	|	ISNULL(PricesSliceLast.Price, 0) * (1 / OperationSpecification.Ref.Quantity) * &Quantity AS Cost
	|FROM
	|	Catalog.BillsOfMaterials.Operations AS OperationSpecification
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON OperationSpecification.Operation = PricesSliceLast.Products
	|WHERE
	|	OperationSpecification.Ref = &Specification
	|	AND NOT OperationSpecification.Ref.DeletionMark";
		
	Query.SetParameter("Specification",  ContentStructure.Specification);
	Query.SetParameter("Quantity",	   ContentStructure.Quantity);
	Query.SetParameter("ProcessingDate", ContentStructure.ProcessingDate);
	Query.SetParameter("PriceKind",        ContentStructure.PriceKind);
	
	Return Query.Execute().Unload();
	
EndFunction

// Function returns operations table with norms.
//
// Parameters:
//  ContentStructure - TTManager
//  content structure - TempTablesManager - temporary
// 			   tables by the document
//
// Returns:
//  QueryResultSelection.
//
Function GetSpecificationContent(ContentStructure)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	ISNULL(BillsOfMaterialsContent.Quantity, 0) * &Quantity AS Quantity,
	|	ISNULL(BillsOfMaterialsContent.Ref.Quantity, 0) AS ProductsQuantity,
	|	ISNULL(PricesSliceLast.Price, 0) AS AccountingPrice,
	|	0 AS Cost
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON BillsOfMaterialsContent.Products = PricesSliceLast.Products
	|			AND BillsOfMaterialsContent.Characteristic = PricesSliceLast.Characteristic
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND NOT BillsOfMaterialsContent.Ref.DeletionMark";
	
	Query.SetParameter("Specification",  ContentStructure.Specification);
	Query.SetParameter("Quantity",	   ContentStructure.Quantity);
	Query.SetParameter("ProcessingDate", ContentStructure.ProcessingDate);
	Query.SetParameter("PriceKind",        ContentStructure.PriceKind);
		
	Return Query.Execute().Select();
	
EndFunction

// Procedure adds new node to products stack for explosion.
//
// Parameters:
//  ContentStructure - Structure
// of the Products content - ValuesTable
// products stack StackProductsStackLogins - ValuesTable NewRowStack
// products logons stack - ValueTableRow - String
// stack CurRow     - ValueTableRow - current row.
//
Procedure AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow)
	
	NewRowStack = StackProducts.Add();
	NewRowStack.Products	= CurRow.Products;
	NewRowStack.Characteristic = CurRow.Characteristic;
	NewRowStack.Specification	= CurRow.Specification;
	NewRowStack.Level		= CurRow.Level;
	
	// Inserted stack initialization.
	StackProductsStackEntries = StackProductsStackEntries.CopyColumns();
	NewRowStack.StackEntries = StackProductsStackEntries;
	
	// Fill out the content structure.
	ContentStructure.ContentRowType		= CurRow.ContentRowType;
	ContentStructure.Products			= CurRow.Products;
	ContentStructure.Characteristic		= CurRow.Characteristic;
	ContentStructure.MeasurementUnit	= CurRow.MeasurementUnit;
	ContentStructure.Quantity			= CurRow.Quantity / ?(CurRow.ProductsQuantity <> 0, CurRow.ProductsQuantity, 1);
	ContentStructure.Level				= NewRowStack.Level;
	ContentStructure.AccountingPrice	= CurRow.AccountingPrice;
	ContentStructure.Cost				= ContentStructure.Quantity * CurRow.AccountingPrice;
		
	If CurRow.Specification.DeletionMark Then
		ContentStructure.Specification = Catalogs.BillsOfMaterials.EmptyRef();
	Else
		ContentStructure.Specification = CurRow.Specification;
	EndIf;
		
	ContentStructure.TableOperations = GetSpecificationOperations(ContentStructure);
	
EndProcedure

// Explodes the node.
//
// Parameters:
//  ContentStructure - Structure that describes
// processed node ContentTable - ValuesList
// of the OpertionsTable content - ValueTable of operations.
//  
Procedure RunDenoding(ContentStructure, ContentTable, TableOfOperations) Export
	
	CompositionNewString = ContentTable.Add();
	CompositionNewString.Products		= ContentStructure.Products;
	CompositionNewString.Characteristic	= ContentStructure.Characteristic;
	CompositionNewString.MeasurementUnit	= ContentStructure.MeasurementUnit;
	CompositionNewString.Quantity		= ContentStructure.Quantity;
	CompositionNewString.Level			= ContentStructure.Level;
	CompositionNewString.Node				= False;
	CompositionNewString.AccountingPrice		= ContentStructure.AccountingPrice;
	CompositionNewString.Cost		= ContentStructure.Cost;
	
	If ContentStructure.ContentRowType = Enums.BOMLineType.Node
	 Or ContentStructure.ContentRowType = Enums.BOMLineType.Assembly
	 Or ContentStructure.Level = 0 Then
			
		CompositionNewString.Node			= True;
	 
	 	OperationsString = TableOfOperations.Add();
		OperationsString.Products		= ContentStructure.Products;
		OperationsString.Characteristic	= ContentStructure.Characteristic;
		OperationsString.TimeNorm		= ContentStructure.Quantity;
		OperationsString.Level			= ContentStructure.Level;
		OperationsString.Node				= True;
		
	EndIf;
		
	For Each TSRow In ContentStructure.TableOperations Do
			
		OperationsString = TableOfOperations.Add();
		OperationsString.Products	= TSRow.Operation;
		OperationsString.TimeNorm = TSRow.TimeNorm;
		OperationsString.Level		= ContentStructure.Level + 1;
		OperationsString.Duration = TSRow.Duration;
		OperationsString.AccountingPrice	= TSRow.AccountingPrice;
		OperationsString.Cost	= TSRow.Cost;
		OperationsString.Node			= False;
	
	EndDo;
		
EndProcedure

// Explosion procedure.
//
// Parameters:
//  ContentStructure - Structure that describes
// processed
// node Object ContentTable - ValuesList
// of the OpertionsTable content - ValueTable of operations.
//  
Procedure Denoding(ContentStructure, ContentTable, TableOfOperations) Export
	
	// Initialization of products stack.
	StackProducts = New ValueTable();
	StackProducts.Columns.Add("Products");
	StackProducts.Columns.Add("Characteristic");
	StackProducts.Columns.Add("Specification");
	StackProducts.Columns.Add("Level");
	
	StackProducts.Columns.Add("StackEntries");
	
	StackProducts.Indexes.Add("Products, Characteristic, Specification");
	
	// Entries table initialization.
	StackProductsStackEntries = New ValueTable();
	StackProductsStackEntries.Columns.Add("ContentRowType");
	StackProductsStackEntries.Columns.Add("Products");
	StackProductsStackEntries.Columns.Add("Characteristic");
	StackProductsStackEntries.Columns.Add("MeasurementUnit");
	StackProductsStackEntries.Columns.Add("Quantity");
	StackProductsStackEntries.Columns.Add("ProductsQuantity");
	StackProductsStackEntries.Columns.Add("Specification");
	StackProductsStackEntries.Columns.Add("Level");
	StackProductsStackEntries.Columns.Add("AccountingPrice");
	StackProductsStackEntries.Columns.Add("Cost");
	
	ContentStructure.TableOperations = GetSpecificationOperations(ContentStructure);
	
	ContentStructure.Level = 0;
	
	// Initial filling of the stack.
	NewRowStack = StackProducts.Add();
	NewRowStack.Products	= ContentStructure.Products;
	NewRowStack.Characteristic	= ContentStructure.Characteristic;
	NewRowStack.Specification	= ContentStructure.Specification;
	NewRowStack.Level		= ContentStructure.Level;
	
	NewRowStack.StackEntries		= StackProductsStackEntries;
	
	RunDenoding(ContentStructure, ContentTable, TableOfOperations);
	
	// Until we have what to explode.
	While StackProducts.Count() <> 0 Do
		
		ProductsSelection = GetSpecificationContent(ContentStructure);
		
		While ProductsSelection.Next() Do
			
			If Not ValueIsFilled(ProductsSelection.Products) Then
				Continue;
			EndIf;
			
			// Check the recursive input.
			SearchStructure = New Structure;
			SearchStructure.Insert("Products",	ProductsSelection.Products);
			SearchStructure.Insert("Characteristic",	ProductsSelection.Characteristic);
			SearchStructure.Insert("Specification",	ProductsSelection.Specification);
			
			RecursiveEntryStrings = StackProducts.FindRows(SearchStructure);
			
			If RecursiveEntryStrings.Count() <> 0 Then
				
				For Each EntAttributeString In RecursiveEntryStrings Do
					
					MessageText = NStr("en = 'BOM is recursive.'; ru = 'Спецификация рекурсивна.';pl = 'Specyfikacja materiałowa jest rekurencyjna.';es_ES = 'BOM es recursivo.';es_CO = 'BOM es recursivo.';tr = 'Ürün reçetesi tekrarlanmaktadır.';it = 'La Distinta Base è ricorsiva.';de = 'Stückliste ist rekursiv.'")+" "+ProductsSelection.Products+" "+NStr("en = 'to item'; ru = 'в элемент';pl = 'do elementu';es_ES = 'para el artículo';es_CO = 'para el artículo';tr = 'öğeye';it = 'all''elemento';de = 'zum Artikel'")+" "+ContentStructure.Products+".";
					ShowMessageAboutError(ContentStructure.Object, MessageText);
					
				EndDo;
				
				Continue;
				
			EndIf;
			
			// Adding new nodes.
			NewStringEnter = StackProductsStackEntries.Add();
			NewStringEnter.ContentRowType	= ProductsSelection.ContentRowType;
			NewStringEnter.Products		= ProductsSelection.Products;
			NewStringEnter.Characteristic		= ProductsSelection.Characteristic;
			NewStringEnter.MeasurementUnit	= ProductsSelection.MeasurementUnit;
			
			RateUnitDimensions			= ?(TypeOf(ContentStructure.MeasurementUnit) = Type("CatalogRef.UOM"),
														ContentStructure.MeasurementUnit.Factor,
														1);
														
			NewStringEnter.Quantity			= ProductsSelection.Quantity * RateUnitDimensions;
			NewStringEnter.ProductsQuantity = ProductsSelection.ProductsQuantity;
			NewStringEnter.Specification		= ProductsSelection.Specification;
			NewStringEnter.Level				= NewRowStack.Level + 1;
			NewStringEnter.AccountingPrice			= Number(ProductsSelection.AccountingPrice);
			NewStringEnter.Cost			= Number(ProductsSelection.Cost) * RateUnitDimensions;
			
		EndDo; // ProductsSelection
		
		// Branch end or not?
		If StackProductsStackEntries.Count() = 0 Then
			
			// Delete products that do not contain continuation from stack.
			StackProducts.Delete(NewRowStack);
			
			ReadinessFlag = True;
			While StackProducts.Count() <> 0 And ReadinessFlag Do
				
				// Receive the previous products stack row.
				PreStringProductsStack = StackProducts.Get(StackProducts.Count() - 1);
				
				// Delete entries from the stack.
				PreStringProductsStack.StackEntries.Delete(0);
					
				If PreStringProductsStack.StackEntries.Count() = 0 Then
					
					// If login stack is empty, delete row from products stack.
					StackProducts.Delete(PreStringProductsStack);
					
				Else // explode the following products from the logins stack.
					
					ReadinessFlag = False;
					
					CurRow = PreStringProductsStack.StackEntries.Get(0);
					
					AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow);
					RunDenoding(ContentStructure, ContentTable, TableOfOperations);
					
				EndIf;
				
			EndDo;
			
		Else // add nodes
			
			CurRow = StackProductsStackEntries.Get(0);
			
			AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow);
			RunDenoding(ContentStructure, ContentTable, TableOfOperations);
			
		EndIf;
		
	EndDo; // StackProducts
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfPrintingFormsGenerating

// Procedure fills in full name by the employee name.
//
Procedure SurnameInitialsByName(Initials, Description) Export
	
	If IsBlankString(Description) Then
		
		Return;
		
	EndIf;
	
	SubstringArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(Description, " ");
	Surname		= SubstringArray[0];
	Name 		= ?(SubstringArray.Count() > 1, SubstringArray[1], "");
	Patronymic	= ?(SubstringArray.Count() > 2, SubstringArray[2], "");
	
	Initials = GetSurnameNamePatronymic(Surname, Name, Patronymic, True);
	
EndProcedure

// Function returns products presentation for printing.
//
Function GetProductsPresentationForPrinting(Products, Characteristic = Undefined, SKU = "", SerialNumbers = "")  Export

	AddCharacteristics = "";
	If Constants.UseCharacteristics.Get() And ValueIsFilled(Characteristic) Then
		AddCharacteristics = AddCharacteristics + TrimAll(Characteristic);
	EndIf;
	
	AddItemNumberToProductDescriptionOnPrinting = Constants.AddItemNumberToProductDescriptionOnPrinting.Get();
	If AddItemNumberToProductDescriptionOnPrinting Then
		
		StringSKU = TrimAll(SKU);
		If ValueIsFilled(StringSKU) Then
			
			StringSKU = ", " + StringSKU;
			
		EndIf;
		
	Else
		
		StringSKU = "";
		
	EndIf;
	
	TextInBrackets = "";
	If AddCharacteristics <> "" And SerialNumbers <> "" Then
		TextInBrackets =  " (" + AddCharacteristics + " " + SerialNumbers + ")";
	ElsIf AddCharacteristics <> "" Then
		TextInBrackets =  " (" + AddCharacteristics + ")";
	ElsIf SerialNumbers <> "" Then
		TextInBrackets = " (" + SerialNumbers + ")";
	EndIf;
	
	If TextInBrackets <> "" Or ValueIsFilled(StringSKU) Then
		Return TrimAll(Products) + TextInBrackets + StringSKU;
	Else
		Return TrimAll(Products);
	EndIf;

EndFunction

// The function returns a set of data about an individual as a structure, The set of data includes full name, position
// in the organization, passport data etc..
//
// Parameters:
//  Company  - CatalogRef.Companies - company
//                 by which a position and
//  department of the employee is determined Individual      - CatalogRef.Individuals - individual
//                 on which CutoffDate data set
//  is returned    - Date - date on which
//  the DescriptionFullNameShort data is read    - Boolean - If True (by default), then
//                 the individual presentation includes a last name and initials if False - surname
//                 or name and patronymic.
//
// Returns:
//  Structure    - Structure with data set about individual:
//                 "LastName",
//                 "Name"
//                 "Patronymic"
//                 "Presentation (Full name)"
//                 "Department"
//                 "DocumentKind"
//                 "DocumentSeries"
//                 "DocumentNumber"
//                 "DocumentDateIssued"
//                 "DocumentIssuedBy"
//                 "DocumentDepartmentCode".
//
Function IndData(Company, Ind, CutoffDate, NameAndSurnameShort = True) Export
	
	PersonalQuery = New Query();
	PersonalQuery.SetParameter("CutoffDate", CutoffDate);
	PersonalQuery.SetParameter("Company", GetCompany(Company));
	PersonalQuery.SetParameter("Ind", Ind);
	PersonalQuery.Text =
	"SELECT ALLOWED
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic,
	|	Employees.Department,
	|	Employees.EmployeeCode,
	|	Employees.Position,
	|	LegalDocuments.DocumentKind AS DocumentKind,
	|	LegalDocuments.Number AS DocumentNumber,
	|	LegalDocuments.IssueDate AS DocumentIssueDate,
	|	LegalDocuments.Authority AS DocumentWhoIssued
	|FROM
	|	(SELECT
	|		Individuals.Ref AS Ind
	|	FROM
	|		Catalog.Individuals AS Individuals
	|	WHERE
	|		Individuals.Ref = &Ind) AS NatPerson
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&CutoffDate, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast
	|		ON NatPerson.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
	|		LEFT JOIN (SELECT TOP 1
	|			Employees.Employee.Code AS EmployeeCode,
	|			Employees.Employee.Ind AS Ind,
	|			Employees.Position AS Position,
	|			Employees.StructuralUnit AS Department
	|		FROM
	|			InformationRegister.Employees.SliceLast(
	|					&CutoffDate,
	|					Employee.Ind = &Ind
	|						AND Company = &Company) AS Employees
	|		WHERE
	|			Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|		
	|		ORDER BY
	|			Employees.Employee.EmploymentContractType.Order DESC) AS Employees
	|		ON NatPerson.Ind = Employees.Ind
	|		LEFT JOIN Catalog.LegalDocuments AS LegalDocuments
	|		ON NatPerson.Ind = LegalDocuments.Owner";
	
	Data = PersonalQuery.Execute().Select();
	Data.Next();
	
	Result = New Structure("Surname, Name, Patronymic, Presentation, EmployeeCode, Position, Department, DocumentKind,
							|DocumentNumber, DocumentIssueDate, DocumentWhoIssued, DocumentPresentation");

	FillPropertyValues(Result, Data);

	Result.Presentation = GetSurnameNamePatronymic(Data.Surname, Data.Name, Data.Patronymic, NameAndSurnameShort);
	Result.DocumentPresentation = GetNatPersonDocumentPresentation(Data);
	
	Return Result;
	
EndFunction

// The function returns info on the company responsible
// employees and their positions.
//
// Parameters:
//  Company - Compound
//                 type: CatalogRef.Companies,
//                 CatalogRef.CashAccounts, CatalogRef.StoragePlaces  organizational unit
//                 for which it is
//  reqired to get information about responsible people CutoffDate    - Date - date on which data is read.
//
// Returns:
//  Structure    - Structure with info on the
//                 business unit individuals.
//
Function OrganizationalUnitsResponsiblePersons(OrganizationalUnit, CutoffDate) Export
	
	Result = New Structure("ManagerDescriptionFull, ChiefAccountantDescriptionFull, CashierDescriptionFull, WarehouseSupervisorDescriptionFull");
	
	// Refs
	Result.Insert("Head");
	Result.Insert("ChiefAccountant");
	Result.Insert("Cashier");
	Result.Insert("WarehouseSupervisor");
	
	// Full name presentation
	Result.Insert("HeadDescriptionFull");
	Result.Insert("ChiefAccountantNameAndSurname");
	Result.Insert("CashierNameAndSurname");
	Result.Insert("WarehouseSupervisorSNP");
	
	// Positions presentation (ref)
	Result.Insert("HeadPositionRefs");
	Result.Insert("ChiefAccountantPositionRef");
	Result.Insert("CashierPositionRefs");
	Result.Insert("WarehouseSupervisorPositionRef");
	
	// Position presentation
	Result.Insert("HeadPosition");
	Result.Insert("ChiefAccountantPosition");
	Result.Insert("CashierPosition");
	Result.Insert("WarehouseSupervisor_Position");
	
	If OrganizationalUnit <> Undefined Then
	
		Query = New Query;
		Query.SetParameter("CutoffDate", CutoffDate);
		Query.SetParameter("OrganizationalUnit", OrganizationalUnit);
		
		Query.Text = 
		"SELECT ALLOWED
		|	ResponsiblePersonsSliceLast.Company AS OrganizationalUnit,
		|	ResponsiblePersonsSliceLast.ResponsiblePersonType AS ResponsiblePersonType,
		|	ResponsiblePersonsSliceLast.Employee AS Employee,
		|	CASE
		|		WHEN ChangeHistoryOfIndividualNamesSliceLast.Ind IS NULL 
		|			THEN ResponsiblePersonsSliceLast.Employee.Description
		|		ELSE ChangeHistoryOfIndividualNamesSliceLast.Surname + "" "" + SubString(ChangeHistoryOfIndividualNamesSliceLast.Name, 1, 1) + "". "" + SubString(ChangeHistoryOfIndividualNamesSliceLast.Patronymic, 1, 1) + "".""
		|	END AS Individual,
		|	ResponsiblePersonsSliceLast.Position AS Position,
		|	ResponsiblePersonsSliceLast.Position.Description AS AppointmentName
		|FROM
		|	InformationRegister.ResponsiblePersons.SliceLast(&CutoffDate, Company = &OrganizationalUnit) AS ResponsiblePersonsSliceLast
		|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast AS ChangeHistoryOfIndividualNamesSliceLast
		|		ON ResponsiblePersonsSliceLast.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind";
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			If Selection.ResponsiblePersonType 	= Enums.ResponsiblePersonTypes.ChiefExecutiveOfficer Then
				
				Result.Head					= Selection.Employee;
				Result.HeadDescriptionFull	= Selection.Individual;
				Result.HeadPositionRefs		= Selection.Position;
				Result.HeadPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefAccountant Then
				
				Result.ChiefAccountant					= Selection.Employee;
				Result.ChiefAccountantNameAndSurname 	= Selection.Individual;
				Result.ChiefAccountantPositionRef 		= Selection.Position;
				Result.ChiefAccountantPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Cashier Then
				
				Result.Cashier					= Selection.Employee;
				Result.CashierNameAndSurname	= Selection.Individual;
				Result.CashierPositionRefs 		= Selection.Position;
				Result.CashierPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.WarehouseSupervisor Then
				
				Result.WarehouseSupervisor				= Selection.Employee;
				Result.WarehouseSupervisorSNP			= Selection.Individual;
				Result.WarehouseSupervisorPositionRef	= Selection.Position;
				Result.WarehouseSupervisor_Position		= Selection.AppointmentName;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result
	
EndFunction

// Receive a presentation of the identity document.
//
// Parameters
//  IndData - Collection of bodies data. bodies (structure, table row
//                 ...) containing values: DokumentKind,
//                 DokumentSeries, DokumentNumber, IssuedateDokument, DocumentWhoIssued.  
//
// Returns:
//   String      - Identity papers presentation.
//
Function GetNatPersonDocumentPresentation(IndData) Export

	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = '%1 nubmer %2, issued on %3 by %4'; ru = '%1 номер %2, выдан %3 %4';pl = '%1 numer %2, wydany %3 przez %4';es_ES = '%1 el número %2, emitido en %3 por %4';es_CO = '%1 el número %2, emitido en %3 por %4';tr = '%1 numara %2, %3 tarihinde %4 tarafından düzenlendi';it = '%1 numero %2, emesso il %3 da %4';de = '%1 Nummer %2, ausgestellt am %3 von %4'"),
		String(IndData.DocumentKind),
		IndData.DocumentNumber,
		Format(IndData.DocumentIssueDate, "DLF=D"),
		IndData.DocumentWhoIssued);

EndFunction

// Procedure is designed to convert document number.
//
// Parameters:
//  Document     - (DocumentRef), document which number
//                 should be received for printing.
//
// Return value.
//  String       - document number for printing
//
Function GetNumberForPrinting(DocumentNumber, Prefix) Export

	If Not ValueIsFilled(DocumentNumber) Then 
		Return 0;
	EndIf;

	Number = TrimAll(DocumentNumber);
	
	// delete prefix from the document number
	If Find(Number, Prefix)=1 Then 
		Number = Mid(Number, StrLen(Prefix)+1);
	EndIf;
	
	ExchangePrefix = "";
			
	If GetFunctionalOption("UseDataSynchronization")
		And ValueIsFilled(Constants.DistributedInfobaseNodePrefix.Get()) Then
		ExchangePrefix = TrimAll(Constants.DistributedInfobaseNodePrefix.Get());
	EndIf;
	
	// delete prefix from the document number
	If Find(Number, ExchangePrefix)=1 Then 
		Number = Mid(Number, StrLen(ExchangePrefix)+1);
	EndIf;
	
	// also "minus" may be in front
	If Left(Number, 1) = "-" Then
		Number = Mid(Number, 2);
	EndIf;
	
	// delete leading nulls
	While Left(Number, 1)="0" Do
		Number = Mid(Number, 2);
	EndDo;

	Return Number;

EndFunction

Function GetNumberForPrintingConsideringDocumentDate(DocumentDate, DocumentNumber, Prefix) Export
	
	If DocumentDate < Date('20110101') Then
		
		Return GetNumberForPrinting(DocumentNumber, Prefix);
		
	Else
		
		Return ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, True, True);
		
	EndIf;
	
EndFunction

// Returns the data structure with the consolidated counterparty description.
//
// Parameters: 
//  ListInformation - values list with parameters values
//   of InformationList company is
//  generated by the InfoAboutLegalEntityIndividual function List         - company desired parameters
//  list WithPrefix     - Shows whether to output company parameter prefix or not
//
// Returns:
//  String - company specifier / counterparty / individuals.
//
Function CompaniesDescriptionFull(ListInformation, List = "", WithPrefix = True) Export

	If IsBlankString(List) Then
		List = "FullDescr,TIN,LegalAddress,PostalAddress,PhoneNumbers,Fax,AccountNo,IBAN,Bank,SWIFT";
	EndIf; 

	Result = "";

	AccordanceOfParameters = New Map();
	AccordanceOfParameters.Insert("FullDescr",			" ");
	AccordanceOfParameters.Insert("TIN",				" " + NStr("en = 'TIN'; ru = 'ИНН';pl = 'NIP';es_ES = 'NIF';es_CO = 'NIF';tr = 'VKN';it = 'Cod.Fiscale';de = 'Steuernummer'") + " ");
	AccordanceOfParameters.Insert("RegistrationNumber",	" ");
	AccordanceOfParameters.Insert("LegalAddress",		" ");
	AccordanceOfParameters.Insert("PostalAddress",		" ");
	AccordanceOfParameters.Insert("PhoneNumbers",		" " + NStr("en = 'phone'; ru = 'телефон';pl = 'telefon';es_ES = 'teléfono';es_CO = 'teléfono';tr = 'telefon';it = 'telefono';de = 'Telefon'") + ": ");
	AccordanceOfParameters.Insert("Fax",				" " + NStr("en = 'fax'; ru = 'факс';pl = 'faks';es_ES = 'fax';es_CO = 'fax';tr = 'faks';it = 'fax';de = 'Fax'") + ": ");
	AccordanceOfParameters.Insert("AccountNo",			" " + NStr("en = 'account number'; ru = 'номер счета';pl = 'numer rachunku';es_ES = 'número de cuenta';es_CO = 'número de cuenta';tr = 'hesap numarası';it = 'numero di conto';de = 'Kontonummer'") + " ");
	AccordanceOfParameters.Insert("IBAN",				" IBAN ");
	AccordanceOfParameters.Insert("Bank",				" " + NStr("en = 'in the bank'; ru = 'в банке';pl = 'w banku';es_ES = 'en el banco';es_CO = 'en el banco';tr = 'bankada';it = 'nella banca';de = 'An der Bank'") + " ");
	AccordanceOfParameters.Insert("SWIFT",				" SWIFT ");

	List = List + ?(Right(List, 1) = ",", "", ",");
	NumberOfParameters = StrOccurrenceCount(List, ",");

	For Counter = 1 To NumberOfParameters Do

		CommaPos = Find(List, ",");

		If CommaPos > 0  Then
			ParameterName = Left(List, CommaPos - 1);
			List = Mid(List, CommaPos + 1, StrLen(List));
			
			Try
				AdditionString = "";
				ListInformation.Property(ParameterName, AdditionString);
				
				If IsBlankString(AdditionString) Then
					Continue;
				EndIf;
				
				Prefix = AccordanceOfParameters[TrimAll(ParameterName)];
				If Not IsBlankString(Result)  Then
					Result = Result + ", ";
				EndIf; 

				Result = Result + ?(WithPrefix = True, Prefix, "") + AdditionString;

			Except
				CommonClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Failed to define value for parameter %1.'; ru = 'Не удалось установить значение параметра %1.';pl = 'Nie można zdefiniować wartości dla parametru %1.';es_ES = 'No se ha podido definir el valor para el parámetro %1.';es_CO = 'No se ha podido definir el valor para el parámetro %1.';tr = '%1 parametresi için değer tanımlanamadı.';it = 'Non riuscito a definire il valore per il parametro %1.';de = 'Der Wert für den Parameter %1 konnte nicht definiert werden.'"),
					ParameterName));
			EndTry;

		EndIf; 

	EndDo;

	Return TrimAll(Result);

EndFunction

// Standard formatting function of quantity writing.
//
// Parameters:
//  Count   - number that you want to format.
//
// Returns:
//  Properly formatted string presentation of the quantity.
//
Function QuantityInWords(Count) Export

	IntegralPart   = Int(Count);
	FractionalPart = Round(Count - IntegralPart, 3);

	If FractionalPart = Round(FractionalPart,0) Then
		ProtocolParameters = ", , , , , , , , 0";
   	ElsIf FractionalPart = Round(FractionalPart, 1) Then
		ProtocolParameters = "integer, integer, integer, F, tenth, tenth, tenth, M, 1";
   	ElsIf FractionalPart = Round(FractionalPart, 2) Then
		ProtocolParameters = "integer, integer, integer, F, hundredth, hundredth, hundredth, M, 2";
   	Else
		ProtocolParameters = "integer, integer, integer, F, thousandth, thousandth, thousandth, M, 3";
    EndIf;

	Return NumberInWords(Count, ,ProtocolParameters);

EndFunction

// Function generates information about the specified LegEntInd. Details include -
// name, address, phone number, bank connection.
//
// Parameters: 
//  LegalEntityIndividual    - company or individual for
//                 whom
//  info is collected PeriodDate  - date on which information about
//  LegEntInd ForIndividualOnlyInitials is selected - For ind. bodies output only name and
//                 patonymic initials
//
// Returns:
//  Information - collected info.
//
Function InfoAboutLegalEntityIndividual(
	LegalEntityIndividual,
	PeriodDate,
	ForIndividualOnlyInitials = True,
	BankAccount = Undefined,
	VATNumber = "",
	LanguageCode = "") Export
	
	Information = New Structure;
	Information.Insert("Presentation");
	Information.Insert("FullDescr");
	Information.Insert("TIN");
	Information.Insert("RegistrationNumber");
	Information.Insert("PhoneNumbers");
	Information.Insert("Fax");
	Information.Insert("ActualAddress");
	Information.Insert("LegalAddress");
	Information.Insert("Bank");
	Information.Insert("SWIFT");
	Information.Insert("CorrespondentText");
	Information.Insert("AccountNo");
	Information.Insert("IBAN");
	Information.Insert("BankAddress");
	Information.Insert("Email");
	Information.Insert("VATnumber");
	Information.Insert("DeliveryAddress");
	Information.Insert("ResponsibleEmployee");
	Information.Insert("FullDescrShipTo");
	
	Query	= New Query;
	Data	= Undefined;
	
	If Not ValueIsFilled(LegalEntityIndividual) Then
		Return Information;
	EndIf;
	
	If Not ValueIsFilled(LanguageCode) Then
		LanguageCode = GetCurrentUserLanguageCode();
	EndIf;
	
	CatalogName = "";
	
	If TypeOf(LegalEntityIndividual) = Type("CatalogRef.Companies") Then
		CatalogName = "Companies";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Counterparties") Then
		CatalogName = "Counterparties";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.BusinessUnits") Then
		CatalogName = "BusinessUnits";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Individuals") Then
		CatalogName = "Individuals";
	EndIf;
	
	If CatalogName = "Companies" Or CatalogName = "Counterparties" Then
		
		If BankAccount = Undefined Or BankAccount.IsEmpty() Then
			CurrentBankAccount = LegalEntityIndividual.BankAccountByDefault;
		Else
			CurrentBankAccount = BankAccount;
		EndIf;
		
		// Select main information about counterparty LegalEntityIndividual.MainBankAccount.Empty
		If CurrentBankAccount.AccountsBank.IsEmpty() Then
			BankAttributeName = "Bank";
		Else
			BankAttributeName = "AccountsBank";
		EndIf;
		
		Query.SetParameter("ParLegEntInd",		LegalEntityIndividual);
		Query.SetParameter("ParBankAccount",	CurrentBankAccount);
		
		Query.Text = 
		"SELECT ALLOWED
		|	Companies.Presentation AS Description,
		|	Companies.DescriptionFull AS FullDescr,
		|	Companies.TIN,
		|	Companies.VATNumber,
		|	Companies.RegistrationNumber,";
		
		If Not ValueIsFilled(CurrentBankAccount) Then
			
			Query.Text = Query.Text + "
			|	""""	AS AccountNo,
			|	""""	AS IBAN,
			|	""""	AS CorrespondentText,
			|	""""	AS Bank,
			|	""""	AS SWIFT,
			|	""""	AS BankAddress
			|FROM
			|	Catalog." + CatalogName + " AS Companies
			|WHERE Companies.Ref = &ParLegEntInd";
			
		Else
			
			Query.Text = Query.Text + "
			|	BankAccounts.AccountNo							AS AccountNo,
			|	BankAccounts.IBAN								AS IBAN,
			|	BankAccounts.CorrespondentText					AS CorrespondentText,
			|	BankAccounts." + BankAttributeName + "				AS Bank,
			|	BankAccounts." + BankAttributeName + ".Code			AS SWIFT,
			|	BankAccounts." + BankAttributeName + ".Address		AS BankAddress
			|FROM 
			|	Catalog." + CatalogName + " AS Companies,
			|	Catalog.BankAccounts AS BankAccounts
			|
			|WHERE
			|	Companies.Ref			= &ParLegEntInd
			|	AND BankAccounts.Ref	= &ParBankAccount";
			
		EndIf;
		
		// MultilingualSupport
		ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		// End MultilingualSupport
	
		Data = Query.Execute().Select();
		Data.Next();
		
		Information.Insert("FullDescr",			Data.FullDescr);
		Information.Insert("FullDescrShipTo",	Data.FullDescr);
		
		If Data <> Undefined Then
			
			EmptyContactInformationKind = Catalogs.ContactInformationKinds.EmptyRef();
			
			If TypeOf(LegalEntityIndividual) = Type("CatalogRef.Companies") Then
				
				Phone			= Catalogs.ContactInformationKinds.CompanyPhone;
				Fax				= Catalogs.ContactInformationKinds.CompanyFax;
				LegAddress		= Catalogs.ContactInformationKinds.CompanyLegalAddress;
				RealAddress		= Catalogs.ContactInformationKinds.CompanyActualAddress;
				PostAddress		= Catalogs.ContactInformationKinds.CompanyPostalAddress;
				DeliveryAddress	= RealAddress;
				Email			= Catalogs.ContactInformationKinds.CompanyEmail;
				Webpage			= Catalogs.ContactInformationKinds.CompanyWebpage;
				
			ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Individuals") Then
				
				Phone			= Catalogs.ContactInformationKinds.IndividualPhone;
				Fax				= EmptyContactInformationKind;
				LegAddress		= Catalogs.ContactInformationKinds.IndividualPostalAddress;
				RealAddress		= Catalogs.ContactInformationKinds.IndividualActualAddress;
				PostAddress		= RealAddress;
				DeliveryAddress	= RealAddress;
				Email			= Catalogs.ContactInformationKinds.IndividualEmail;
				Webpage			= EmptyContactInformationKind;
				
			ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Counterparties") Then
				
				Phone			= Catalogs.ContactInformationKinds.CounterpartyPhone;
				Fax				= Catalogs.ContactInformationKinds.CounterpartyFax;
				LegAddress		= Catalogs.ContactInformationKinds.CounterpartyLegalAddress;
				RealAddress		= Catalogs.ContactInformationKinds.CounterpartyActualAddress;
				PostAddress		= Catalogs.ContactInformationKinds.CounterpartyPostalAddress;
				DeliveryAddress	= Catalogs.ContactInformationKinds.CounterpartyDeliveryAddress;
				Email			= Catalogs.ContactInformationKinds.CounterpartyEmail;
				Webpage			= Catalogs.ContactInformationKinds.CounterpartyWebpage;
				
			Else
				
				Phone			= EmptyContactInformationKind;
				Fax				= EmptyContactInformationKind;
				LegAddress		= EmptyContactInformationKind;
				RealAddress		= EmptyContactInformationKind;
				PostAddress		= EmptyContactInformationKind;
				DeliveryAddress	= EmptyContactInformationKind;
				Email			= Undefined;
				Webpage			= EmptyContactInformationKind;
				
			EndIf;
			
			Information.Insert("Presentation",			Data.Description);
			Information.Insert("TIN",					Data.TIN);
			Information.Insert("VATNumber",				?(ValueIsFilled(VATNumber), String(VATNumber), Data.VATNumber));
			Information.Insert("RegistrationNumber",	Data.RegistrationNumber);
			Information.Insert("PhoneNumbers",			GetContactInformation(LegalEntityIndividual, Phone));
			Information.Insert("Fax",					GetContactInformation(LegalEntityIndividual, Fax));
			Information.Insert("AccountNo",				Data.AccountNo);
			Information.Insert("IBAN",					Data.IBAN);
			Information.Insert("Bank",					Data.Bank);
			Information.Insert("SWIFT",					Data.SWIFT);
			Information.Insert("BankAddress",			Data.BankAddress);
			Information.Insert("CorrespondentText",		Data.CorrespondentText);
			Information.Insert("LegalAddress",			GetContactInformation(LegalEntityIndividual, LegAddress));
			Information.Insert("ActualAddress",			GetContactInformation(LegalEntityIndividual, RealAddress));
			Information.Insert("PostalAddress",			GetContactInformation(LegalEntityIndividual, PostAddress));
			Information.Insert("DeliveryAddress",		GetContactInformation(LegalEntityIndividual, DeliveryAddress));
			Information.Insert("Webpage",				GetContactInformation(LegalEntityIndividual, Webpage));
			
			If ValueIsFilled(Email) Then
				Information.Insert("Email", GetContactInformation(LegalEntityIndividual, Email));
			EndIf;
			
			If Not ValueIsFilled(Information.FullDescr) Then
				Information.FullDescr		= Information.Presentation;
				Information.FullDescrShipTo	= Information.Presentation;
			EndIf;
			
		EndIf;
		
	ElsIf CatalogName = "BusinessUnits" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	BusinessUnits.Presentation AS Description,
		|	BusinessUnits.FRP AS FRP
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.Ref = &LegalEntityIndividual"; 
		
		Query.SetParameter("LegalEntityIndividual", LegalEntityIndividual);
		
		// MultilingualSupport
		ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		// End MultilingualSupport
	
	Data = Query.Execute().Select();
		Data.Next();
		
		If Data <> Undefined Then
			
			ObjectArray = New Array;
			ObjectArray.Add(LegalEntityIndividual);
			
			Information.Insert("FullDescr",			Data.Description);
			Information.Insert("FullDescrShipTo",	Data.Description);
			Information.Insert("Presentation",		Data.Description);
			PhoneArray = New Array;
			PhoneArray.Add(Enums.ContactInformationTypes.Phone);
			PhoneContactInformation = ContactsManager.ObjectsContactInformation(ObjectArray, PhoneArray);
			If PhoneContactInformation.Count() > 0 Then
				Information.Insert("PhoneNumbers", PhoneContactInformation[0].Presentation);
			EndIf;
			
			AddressArray = New Array;
			AddressArray.Add(Enums.ContactInformationTypes.Address);
			AddressContactInformation = ContactsManager.ObjectsContactInformation(ObjectArray, AddressArray);
			If AddressContactInformation.Count() > 0 Then
				Information.Insert("DeliveryAddress", AddressContactInformation[0].Presentation);
			EndIf;
			
			Information.Insert("ResponsibleEmployee", Data.FRP);
			
		EndIf;
		
	ElsIf CatalogName = "Individuals" Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Individuals.Presentation AS Description
		|FROM
		|	Catalog.Individuals AS Individuals
		|WHERE
		|	Individuals.Ref = &LegalEntityIndividual";
		
		Query.SetParameter("LegalEntityIndividual", LegalEntityIndividual);
		
		// MultilingualSupport
		ChangeQueryTextForCurrentLanguage(Query.Text, LanguageCode);
		// End MultilingualSupport
	
		Data = Query.Execute().Select();
		Data.Next();
		
		If Data <> Undefined Then
			ObjectArray = New Array;
			ObjectArray.Add(LegalEntityIndividual);
			Phone = Catalogs.ContactInformationKinds.IndividualPhone;

			Information.Insert("FullDescr",			Data.Description);
			Information.Insert("FullDescrShipTo",	Data.Description);
			Information.Insert("Presentation",		Data.Description);
			Information.Insert("PhoneNumbers",		GetContactInformation(LegalEntityIndividual, Phone));
		EndIf;
		
	EndIf;

	Return Information;

EndFunction

// Generates information about the specified ContactPerson. Details include -
// phone number, e-mail address.
//
// Parameters: 
//  ContactPerson - CatalogRef.ContactPersons - contact person for whom info is collected
//
// Returns:
//  Information - collected info.
//
Function InfoAboutContactPerson(ContactPerson) Export
	
	Information = New Structure;
	Information.Insert("PhoneNumbers", "");
	Information.Insert("Email", "");
	
	If NOT ValueIsFilled(ContactPerson) Then
		Return Information;
	EndIf;
	
	Phone = Catalogs.ContactInformationKinds.ContactPersonPhone;
	Email = Catalogs.ContactInformationKinds.ContactPersonEmail;
	
	Information.Insert("PhoneNumbers", GetContactInformation(ContactPerson, Phone));
	Information.Insert("Email", GetContactInformation(ContactPerson, Email));
	
	Return Information;

EndFunction

// Generates information about the specified ShippingAddress. Details include - address.
//
// Parameters: 
//  ShippingAddress - CatalogRef.ShippingAddresses - shipping address person for whom info is collected
//
// Returns:
//  Information - collected info.
//
Function InfoAboutShippingAddress(ShippingAddress) Export
	
	Information = New Structure;
	Information.Insert("DeliveryAddress", "");
	
	If TypeOf(ShippingAddress) = Type("CatalogRef.ShippingAddresses") Then
		Address = Catalogs.ContactInformationKinds.ShippingAddress;
		Information.Insert("DeliveryAddress", GetContactInformation(ShippingAddress, Address));
	EndIf;
	
	Return Information;

EndFunction

// The function finds an actual address value in contact information.
//
// Parameters:
//  Object       - CatalogRef, contact
//  information object AddressType    - contact information type.
//
// Returned
//  value String - found address presentation.
//                                          
Function GetContactInformation(ContactInformationObject, InformationKind) Export
	
	If TypeOf(ContactInformationObject) = Type("CatalogRef.Companies") Then
		
		SourceTable = "Companies";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.Individuals") Then
		
		SourceTable = "Individuals";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.Counterparties") Then
		
		SourceTable = "Counterparties";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.ContactPersons") Then
		
		SourceTable = "ContactPersons";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.ShippingAddresses") Then
		
		SourceTable = "ShippingAddresses";
		
	Else 
		
		Return "";
		
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Object", ContactInformationObject);
	Query.SetParameter("Kind",	InformationKind);
	
	Query.Text = "SELECT ALLOWED
	|	ContactInformation.Presentation
	|FROM
	|	Catalog." + SourceTable + ".ContactInformation
	|AS
	|ContactInformation WHERE ContactInformation.Kind
	|	= &Kind And ContactInformation.Ref = &Object";

	QueryResult = Query.Execute();
	
	Return ?(QueryResult.IsEmpty(), "", QueryResult.Unload()[0].Presentation);

EndFunction

// Standard for this configuration function of amounts formatting
//
// Parameters: 
//  Amount        - number that should be
// formatted Currency       - reference to the item of currencies catalog, if
//                 set, then NZ currency presentation will
//  be added to the resulting string           - String that presents the
//  zero value of NGS number          - character-separator of groups of number integral part.
//
// Returns:
//  Properly formatted string representation of the amount.
//
Function AmountsFormat(Amount, Currency = Undefined, NZ = "", NGS = "") Export

	FormatString = "ND=15;NFD=2" +
					?(NOT ValueIsFilled(NZ), "", ";" + "NZ=" + NZ) +
					?(NOT ValueIsFilled(NGS),"", ";" + "NGS=" + NGS);

	ResultString = TrimL(Format(Amount, FormatString));
	
	If ValueIsFilled(Currency) Then
		ResultString = ResultString + " " + TrimR(Currency);
	EndIf;

	Return ResultString;

EndFunction

// Generates bank payment document amount.
//
// Parameters:
//  Amount        - Number - attribute that
//  should be formatted OutputAmountWithoutKopeks - Boolean - check box of amount presentation without kopeks.
//
// Return
//  value Formatted string.
//
Function FormatPaymentDocumentSUM(Amount, DisplayAmountWithoutCents = False) Export
	
	Result  = Amount;
	IntegralPart = Int(Amount);
	
	If Result = IntegralPart Then
		If DisplayAmountWithoutCents Then
			Result = Format(Result, "NFD=2; NDS='='; NG=0");
			Result = Left(Result, Find(Result, "="));
		Else
			Result = Format(Result, "NFD=2; NDS='-'; NG=0");
		EndIf;
	Else
		Result = Format(Result, "NFD=2; NDS='-'; NG=0");
	EndIf;
	
	Return Result;
	
EndFunction

// Formats amount in writing of banking payment document.
//
// Parameters:
//  Amount        - Number - attribute that should be
// presented in writing Currency       - CatalogRef.Currencies - currency in which
//                 amount
//  should be OutputAmoutWithoutKopek - Boolean - check box of amount presentation without kopeks.
//
// Return
//  value Formatted string.
//
Function FormatPaymentDocumentAmountInWords(Amount, SubjectParam, DisplayAmountWithoutCents = False, FormatString = "") Export
	
	Result = "";
	
	If IsBlankString(FormatString) Then
		FormatString = "L=en_EN; FS=False";
	EndIf;
	
	If Amount = Int(Amount) Then
		If DisplayAmountWithoutCents Then
			Result = NumberInWords(Amount, FormatString, SubjectParam);
			Result = Left(Result, Find(Result, "0") - 1);
		Else
			Result = NumberInWords(Amount, FormatString, SubjectParam);
		EndIf;
	Else
		Result = NumberInWords(Amount, FormatString, SubjectParam);
	EndIf;
	
	Return Result;
	
EndFunction

// Sets the Long operation state for an item form of the tabular document type
//
Procedure StateDocumentsTableLongOperation(FormItem, StatusText = "") Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture = PictureLib.TimeConsumingOperation48;
	StatePresentation.Text = StatusText;
	
EndProcedure

// Sets the Long operation state for an item form of the tabular document type
//
Procedure NotActualSpreadsheetDocumentState(FormItem, StatusText = "") Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture = New Picture;
	StatePresentation.Text = StatusText;
	
EndProcedure

// Sets the Long operation state for an item form of the tabular document type
//
Procedure SpreadsheetDocumentStateActual(FormItem) Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture = New Picture;
	StatePresentation.Text = "";
	
EndProcedure

// Checks if the pass table documents fit in the printing page.
//
// Parameters
//  TabDocument       - Tabular
//  document DisplayedAreas - Array of checked tables or
//  tabular document ResultOnError - Which result to return if an error occurs
//
// Returns:
//   Boolean   - whether the sent documents fit in or not
//
Function SpreadsheetDocumentFitsPage(Spreadsheet, AreasToPut, ResultOnError = True)

	Try
		Return Spreadsheet.CheckPut(AreasToPut);
	Except
		ErrorDescription = ErrorInfo();
		WriteLogEvent(
			NStr("en = 'Cannot get information about the current printer (maybe, no printers are installed in the application)'; ru = 'Невозможно получить информацию о текущем принтере (возможно, в системе не установлено ни одного принтера)';pl = 'Nie można uzyskać informacji o bieżącej drukarce (być może w aplikacji nie są zainstalowane żadne drukarki)';es_ES = 'No se puede obtener la información sobre la impresora (probablemente, no hay impresoras instaladas en la aplicación)';es_CO = 'No se puede obtener la información sobre la impresora (probablemente, no hay impresoras instaladas en la aplicación)';tr = 'Geçerli yazıcı hakkında bilgi alınamıyor (uygulamada hiç yüklü yazıcı olmayabilir)';it = 'Impossibile ottenere informazioni sulla stampante corrente (forse, la stampante non è installata nell''applicazione)';de = 'Informationen über den aktuellen Drucker können nicht abgerufen werden (möglicherweise sind in der Anwendung keine Drucker installiert)'",
				CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			ErrorDescription.Definition);
		Return ResultOnError;
	EndTry;

EndFunction

// Count sheets quantity in document
//
Function CheckAccountsInvoicePagePut(Spreadsheet, AreaCurRows, IsLastRow, Template, NumberWorksheet, InvoiceNumber) Export
	
	// Check whether it is possible to output tabular document
	RowWithFooter = New Array;
	RowWithFooter.Add(AreaCurRows);
	If IsLastRow Then
		// If it is the last string, then total and footer should fit
		RowWithFooter.Add(Template.GetArea("Total"));
		RowWithFooter.Add(Template.GetArea("Footer"));
	EndIf;
	
	CheckResult = SpreadsheetDocumentFitsPage(Spreadsheet, RowWithFooter);
	
	If Not CheckResult Then
		// Output separator and table title on the new page
		
		NumberWorksheet = NumberWorksheet + 1;
		
		AreaSheetsNumbering = Template.GetArea("NumberingOfSheets");
		AreaSheetsNumbering.Parameters.Number = InvoiceNumber;
		AreaSheetsNumbering.Parameters.NumberWorksheet = NumberWorksheet;
		
		Spreadsheet.PutHorizontalPageBreak();
		
		Spreadsheet.Put(AreaSheetsNumbering);
		Spreadsheet.Put(Template.GetArea("TableTitle"));
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

// Function prepares data for printing labels and price tags.
//
// Returns:
//   Address   - data structure address in the temporary storage
//
Function PreparePriceTagsAndLabelsPrintingFromDocumentsDataStructure(DocumentArray, IsPriceTags) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ReceiptOfProductsServicesProducts.Products AS Products,
	|	ReceiptOfProductsServicesProducts.Characteristic AS Characteristic,
	|	ReceiptOfProductsServicesProducts.Batch AS Batch,
	|	SUM(ReceiptOfProductsServicesProducts.Quantity) AS Quantity
	|FROM
	|	Document.SupplierInvoice.Inventory AS ReceiptOfProductsServicesProducts
	|WHERE
	|	ReceiptOfProductsServicesProducts.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	ReceiptOfProductsServicesProducts.Products,
	|	ReceiptOfProductsServicesProducts.Characteristic,
	|	ReceiptOfProductsServicesProducts.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryTransferInventory.Products,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch,
	|	SUM(InventoryTransferInventory.Quantity)
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|WHERE
	|	InventoryTransferInventory.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	InventoryTransferInventory.Products,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch,
	|	SUM(SalesOrderInventory.Quantity)
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic,
	|	SalesInvoiceInventory.Batch,
	|	SUM(SalesInvoiceInventory.Quantity)
	|FROM
	|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|WHERE
	|	SalesInvoiceInventory.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	SalesInvoiceInventory.Products,
	|	SalesInvoiceInventory.Characteristic,
	|	SalesInvoiceInventory.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReceiptInventory.Products,
	|	GoodsReceiptInventory.Characteristic,
	|	GoodsReceiptInventory.Batch,
	|	SUM(GoodsReceiptInventory.Quantity)
	|FROM
	|	Document.GoodsReceipt.Products AS GoodsReceiptInventory
	|WHERE
	|	GoodsReceiptInventory.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	GoodsReceiptInventory.Products,
	|	GoodsReceiptInventory.Characteristic,
	|	GoodsReceiptInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	ReceiptOfGoodsAndServices.Company AS Company,
	|	ReceiptOfGoodsAndServices.StructuralUnit AS StructuralUnit,
	|	ISNULL(BusinessUnits.RetailPriceKind, VALUE(Catalog.BusinessUnits.EmptyRef)) AS PriceKind
	|FROM
	|	Document.SupplierInvoice AS ReceiptOfGoodsAndServices
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON ReceiptOfGoodsAndServices.StructuralUnit = BusinessUnits.Ref
	|WHERE
	|	ReceiptOfGoodsAndServices.Ref IN(&DocumentArray)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	InventoryTransfer.Company,
	|	InventoryTransfer.StructuralUnitPayee,
	|	ISNULL(BusinessUnits.RetailPriceKind, VALUE(Catalog.BusinessUnits.EmptyRef))
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON InventoryTransfer.StructuralUnitPayee = BusinessUnits.Ref
	|WHERE
	|	InventoryTransfer.Ref IN(&DocumentArray)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesOrder.Company,
	|	SalesOrder.StructuralUnitReserve,
	|	ISNULL(BusinessUnits.RetailPriceKind, VALUE(Catalog.BusinessUnits.EmptyRef))
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON SalesOrder.StructuralUnitReserve = BusinessUnits.Ref
	|WHERE
	|	SalesOrder.Ref IN(&DocumentArray)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesInvoice.Company,
	|	SalesInvoice.StructuralUnit,
	|	ISNULL(BusinessUnits.RetailPriceKind, VALUE(Catalog.BusinessUnits.EmptyRef))
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON SalesInvoice.StructuralUnit = BusinessUnits.Ref
	|WHERE
	|	SalesInvoice.Ref IN(&DocumentArray)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	GoodsReceipt.Company,
	|	GoodsReceipt.StructuralUnit,
	|	ISNULL(BusinessUnits.RetailPriceKind, VALUE(Catalog.BusinessUnits.EmptyRef))
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|		LEFT JOIN Catalog.BusinessUnits AS BusinessUnits
	|		ON GoodsReceipt.StructuralUnit = BusinessUnits.Ref
	|WHERE
	|	GoodsReceipt.Ref IN(&DocumentArray)";
	
	Query.SetParameter("DocumentArray", DocumentArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableAttributesDocuments	= ResultsArray[1].Unload();
	CompaniesArray				= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "Company").UnloadColumn(0);
	WarehousesArray				= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "StructuralUnit").UnloadColumn(0);
	PriceTypesArray				= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "PriceKind").UnloadColumn(0);
	
	// Prepare actions structure for labels and price tags printing processor
	ActionsStructure = New Structure;
	ActionsStructure.Insert("FillCompany", ?(CompaniesArray.Count() = 1,CompaniesArray[0], Undefined));
	ActionsStructure.Insert("FillWarehouse", ?(WarehousesArray.Count() = 1,WarehousesArray[0], WarehousesArray));
	ActionsStructure.Insert("FillKindPrices", ?(PriceTypesArray.Count() = 1,PriceTypesArray[0], Undefined));
	ActionsStructure.Insert("ShowColumnNumberOfDocument", True);
	ActionsStructure.Insert("SetPrintModeFromDocument");
	If IsPriceTags Then
		
		ActionsStructure.Insert("SetMode", "TagsPrinting");
		ActionsStructure.Insert("FillOutPriceTagsQuantityOnDocument");
		
	Else
		
		ActionsStructure.Insert("SetMode", "LabelsPrinting");
		ActionsStructure.Insert("FillLabelsQuantityByDocument");
		
	EndIf;
	ActionsStructure.Insert("FillProductsTable");
	
	// Data preparation for filling tabular section of labels and price tags printing processor
	ResultStructure = New Structure;
	ResultStructure.Insert("Inventory", ResultsArray[0].Unload());
	ResultStructure.Insert("ActionsStructure", ActionsStructure);
	
	Return PutToTempStorage(ResultStructure);
	
EndFunction

// Function returns passed document contract.
//
Function GetContractDocument(Document) Export
	
	Return Document.Contract;
	
EndFunction

#EndRegion

#Region MultilingualSupport

Procedure ChangeQueryTextForCurrentLanguage(QueryText, LanguageCode = "") Export
	
	If IsBlankString(LanguageCode) Then
		LanguageCode = GetCurrentUserLanguageCode();	
	EndIf;
	
	LanguageSuffix = LanguageSuffix(LanguageCode);
	
	If IsBlankString(LanguageSuffix) Then
		Return;
	EndIf;
	
	If IsBlankString(QueryText) Then
		Return;
	EndIf;
	
	SelectionTemplate = "CASE
	|WHEN ISNULL(Substring(%1.%2, 1, 1),"" "") <> "" "" THEN %1.%2
	|ELSE %1.%3
	|END";
	
	QueryModel = New QuerySchema;
	QueryModel.SetQueryText(QueryText);
	
	For Each QueryPackage In QueryModel.QueryBatch Do
		ChangeSourceTable(QueryPackage, SelectionTemplate, LanguageSuffix)
	EndDo;
	
	QueryText = QueryModel.GetQueryText();
	
EndProcedure

Function ObjectAttributesToLocalizeForCurrentLanguage(MetadataObject, LanguageSuffix = Undefined)
	
	AttributesList = New Map;
	ObjectAttributesList = New Map;
	
	For Each Attribute In MetadataObject.Attributes Do
		ObjectAttributesList.Insert(Attribute.Name, Attribute);
	EndDo;
	
	For Each Attribute In MetadataObject.StandardAttributes Do
		ObjectAttributesList.Insert(Attribute.Name, Attribute);
	EndDo;
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 0
		|	*
		|FROM
		|	" + MetadataObject.FullName() + " AS " + MetadataObject.Name;
	
	QueryResult = Query.Execute();
	
	AttributesList = New Map;
	For each Column In QueryResult.Columns Do
		If StrEndsWith(Column.Name, LanguageSuffix) Then
			Attribute = ObjectAttributesList.Get(Column.Name);
			If Attribute = Undefined Then
				Attribute = Metadata.CommonAttributes.Find(Column.Name);
			EndIf;
			AttributesList.Insert(Column.Name, Attribute);
			
		EndIf;
	EndDo;
	
	Return AttributesList;
	
EndFunction

// It returns suffix Language1 or Language2 by the language code.
//
Function LanguageSuffix(Language)
	
	If Language = Constants.AdditionalLanguage1.Get() Then
		Return "Language1";
	EndIf;
	
	If Language = Constants.AdditionalLanguage2.Get() Then
		Return "Language2";
	EndIf;
	
	If Language = Constants.AdditionalLanguage3.Get() Then
		Return "Language3";
	EndIf;
	
	If Language = Constants.AdditionalLanguage4.Get() Then
		Return "Language4";
	EndIf;
	
	Return "";
	
EndFunction

Function GetCurrentUserLanguageCode() Export
	
	User = Infobaseusers.CurrentUser();
	
	If User.Language <> Undefined Then
		UserLanguage = User.Language.LanguageCode;
	Else
		UserLanguage = SessionParameters.DefaultLanguage;
	EndIf;

	Return UserLanguage;
	
EndFunction

Procedure ChangeSourceTable(QueryPackage, SelectionTemplate, LanguageSuffix)
	
	For Each QueryOperator In QueryPackage.Operators Do
		For Each QuerySource In QueryOperator.Sources Do
			
			Source = QuerySource.Source;
			
			If TypeOf(Source) = Type("QuerySchemaNestedQuery") Then
				ChangeSourceTable(Source.Query, SelectionTemplate, LanguageSuffix);
			Else
				
				MetadataObjectName = Source.TableName;
				MetadataObject = Metadata.FindByFullName(MetadataObjectName);
				
				If MetadataObject <> Undefined
					And Not Common.IsConstant(MetadataObject) Then
					
					AttributesToLocalize = ObjectAttributesToLocalizeForCurrentLanguage(MetadataObject, LanguageSuffix);
					
					For each AttributeDetails In AttributesToLocalize Do
						
						MainAttributeName = Left(AttributeDetails.Key, StrLen(AttributeDetails.Key) - 9);
						FullName = Source.Alias + "."+ MainAttributeName;
						
						For Index = 0 To QueryOperator.SelectedFields.Count() - 1 Do
							
							FieldToSelect = QueryOperator.SelectedFields.Get(Index);
							Alias = QueryPackage.Columns[Index].Alias + LanguageSuffix;
							Position = StrFind(FieldToSelect, FullName);
							
							If Position = 0 Then
								Continue;
							EndIf;
							
							FieldChoiceText = StringFunctionsClientServer.SubstituteParametersToString(SelectionTemplate,
							Source.Alias, AttributeDetails.Key, MainAttributeName);
							
							If StrCompare(FieldToSelect, FullName) = 0 Then
								
								FieldToSelect = StrReplace(FieldToSelect, FullName, FieldChoiceText);
								
							Else
								
								FieldToSelect = StrReplace(FieldToSelect, FullName + Chars.LF,
								FieldChoiceText + Chars.LF);
								FieldToSelect = StrReplace(FieldToSelect, FullName + " ",
								FieldChoiceText + " " );
								FieldToSelect = StrReplace(FieldToSelect, FullName + ")",
								FieldChoiceText + ")" );
								
							EndIf;
							
							QueryOperator.SelectedFields.Set(Index, New QuerySchemaExpression(FieldToSelect));
						EndDo;
						
					EndDo;
					
				EndIf;
				
				ChangeNestedTable(QuerySource, QueryOperator.SelectedFields, QueryPackage.Columns, SelectionTemplate, LanguageSuffix);
				
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure ChangeNestedTable(QuerySource, SelectedFields, Columns, SelectionTemplate, LanguageSuffix)
	
	For Index = 0 To SelectedFields.Count() - 1 Do
				
		FieldsArray = New Array;
		FieldToSelect = SelectedFields.Get(Index);
		IsNestedTable = TypeOf(FieldToSelect) = Type("QuerySchemaNestedTable");
		
		If IsNestedTable Then
			
			ChangeNestedTable(QuerySource, FieldToSelect.Fields, Columns[Index].Columns, SelectionTemplate, LanguageSuffix);
			FieldsArray.Add(FieldToSelect);
			
		ElsIf SelectedFields.Get(Index).ValueType() = Undefined Then
			AddFieldsFromExpression(FieldsArray, FieldToSelect);	
		Else
			FieldsArray.Add(FieldToSelect);
		EndIf;
				
		For Each Field In FieldsArray Do		
			
			VariablesArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
				?(IsNestedTable, Field.Name, Field), " ");
				
			If VariablesArray.Count() > 1 Then
				Continue;
			EndIf;
				
			FieldToSelectArray = StringFunctionsClientServer.SplitStringIntoSubstringsArray(
				?(IsNestedTable, Field.Name, Field), ".");
			FieldToSelectArrayCount = FieldToSelectArray.Count();
			
			If FieldToSelectArrayCount > 2
				Or IsNestedTable Then
				
				If FieldToSelectArray[0] <> QuerySource.Source.Alias Then 		
					Continue;	
				EndIf;
				
				TableIndex = 1;
				
				CurrentTable = QuerySource.Source.AvailableFields.Find(FieldToSelectArray[TableIndex]);
				TablePath = QuerySource.Source.Alias + "." + CurrentTable.Name;
				
				While TableIndex < FieldToSelectArrayCount -  2 Do
					TableIndex = TableIndex + 1;
					CurrentTable = CurrentTable.Fields.Find(FieldToSelectArray[TableIndex]);
					TablePath = TablePath + "." + CurrentTable.Name;
				EndDo;
				
				If TypeOf(CurrentTable) = Type("QuerySchemaAvailableNestedTable") Then
					Continue;
				EndIf;
				
				ObjectTypes = CurrentTable.ValueType.Types();
				If ObjectTypes.Count() > 0 Then
					ObjectType = ObjectTypes[0];
				EndIf;
				
				MetadataObject = Metadata.FindByType(ObjectType);
				If MetadataObject <> Undefined Then
					
					AttributesToLocalize = ObjectAttributesToLocalizeForCurrentLanguage(MetadataObject, LanguageSuffix);
					
					For each AttributeDetails In AttributesToLocalize Do
						
						MainAttributeName = Left(AttributeDetails.Key, StrLen(AttributeDetails.Key) - 9);
						FullName = TablePath + "." + MainAttributeName;
						
						Alias = Columns[Index].Alias + LanguageSuffix;
						Position = StrFind(Field, FullName);
						
						If Position = 0 Then
							Continue;
						EndIf;
						
						FieldChoiceText = StringFunctionsClientServer.SubstituteParametersToString(SelectionTemplate,
						TablePath, AttributeDetails.Key, MainAttributeName);
						
						If StrCompare(FieldToSelect, FullName) = 0 Then
							
							FieldToSelect = StrReplace(FieldToSelect, FullName, FieldChoiceText);
							
						Else
							
							FieldToSelect = StrReplace(FieldToSelect, FullName + Chars.LF,
							FieldChoiceText + Chars.LF);
							FieldToSelect = StrReplace(FieldToSelect, FullName + " ",
							FieldChoiceText + " " );
							FieldToSelect = StrReplace(FieldToSelect, FullName + ")",
							FieldChoiceText + ")" );
							
						EndIf;
						
						SelectedFields.Set(Index, New QuerySchemaExpression(FieldToSelect));
						
					EndDo;
				EndIf;
			EndIf;
		EndDo;
	EndDo;
	
EndProcedure

Procedure AddFieldsFromExpression(FieldsArray, FieldToSelect)
	
	AllLinesInField = StringFunctionsClientServer.SplitStringIntoSubstringsArray(FieldToSelect, Char(10), True, True);
	For Each Line In AllLinesInField Do
		
		If StrStartsWith(Line, "THEN")
			Or StrStartsWith(Line, "ELSE") Then
			FieldWithoutConditions = Right(Line, StrLen(Line) - 5);
		Else
			FieldWithoutConditions = FieldToSelect;
		EndIf;
		
		If StrStartsWith(FieldWithoutConditions, "CAST") Then
			FieldArrayWithCast = StringFunctionsClientServer.SplitStringIntoSubstringsArray(FieldWithoutConditions, " ");
			FieldsArray.Add(Right(FieldArrayWithCast[0], StrLen(FieldArrayWithCast[0]) - 5));
		EndIf;
		
	EndDo;
	
	If FieldsArray.Count() = 0 Then
		FieldsArray.Add(FieldToSelect);
	EndIf;
	
EndProcedure

Procedure FillAttributesToLocalizeFromObject(ReceiverObject, SourceObject) Export
	
	ReceiverMetadataObject = ReceiverObject.Metadata();
	SourceMetadataObject = SourceObject.Metadata();
	
	If ReceiverMetadataObject = Undefined
		Or SourceMetadataObject = Undefined Then
		Return;
	EndIf;

	ReceiverAttributesToLocalize = NativeLanguagesSupportServer.ObjectAttributesToLocalizeDescriptions(ReceiverMetadataObject);
	SourceAttributesToLocalize = NativeLanguagesSupportServer.ObjectAttributesToLocalizeDescriptions(SourceMetadataObject);
	
	For Each Attribute In ReceiverAttributesToLocalize Do
		
		Name = Attribute.Key;
		If SourceAttributesToLocalize.Get(Name) = Undefined Then
			Continue;
		EndIf;
		
		FillAttributeToLocalize(ReceiverObject, SourceObject, Name, Name)
		
	EndDo;

EndProcedure

Function FillAttributeToLocalize(ReceiverObject, SourceObject, ReceiverAttribute, SourceAttribute) Export
	
	If NativeLanguagesSupportServer.FirstAdditionalLanguageUsed() Then
		ReceiverObject[ReceiverAttribute + "Language1"] = SourceObject[SourceAttribute + "Language1"];
	EndIf;
	If NativeLanguagesSupportServer.SecondAdditionalLanguageUsed() Then
		ReceiverObject[ReceiverAttribute + "Language2"] = SourceObject[SourceAttribute + "Language2"];
	EndIf;
	If NativeLanguagesSupportServer.ThirdAdditionalLanguageUsed() Then
		ReceiverObject[ReceiverAttribute + "Language3"] = SourceObject[SourceAttribute + "Language3"];
	EndIf;
	If NativeLanguagesSupportServer.FourthAdditionalLanguageUsed() Then
		ReceiverObject[ReceiverAttribute + "Language4"] = SourceObject[SourceAttribute + "Language4"];
	EndIf;
	
EndFunction

Function AdditionalLanguagesUsed() Export
	
	Return Constants.UseAdditionalLanguage1.Get()
			Or Constants.UseAdditionalLanguage2.Get()
			Or Constants.UseAdditionalLanguage3.Get()
			Or Constants.UseAdditionalLanguage4.Get();
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForWorkWithWorkCalendar

// Function returns row number in the
//  tabular document field for Events output by its date (beginning or end)
//
// Parameters
//  Hours - String,
//  hours dates Minutes - String, minutes
//  dates Date - Date, date current value
//  for definition Start - Boolean, shows that period has
//  begun or ended ComparisonDate - Date, date that is compared to the source date value
//
// Returns:
//   Number - String number in the tabular document field
//
Function ReturnLineNumber(Hours, Minutes, Date, Begin, DateComparison) Export
	
	If IsBlankString(Hours) Then
		Hours = 0;
	Else
		Hours = Number(Hours);
	EndIf; 
	
	If IsBlankString(Minutes) Then
		Minutes = 0;
	Else
		Minutes = Number(Minutes);
	EndIf; 
	
	If Begin Then
		If Date < BegOfDay(DateComparison) Then
			Return 1;
		Else
			If Minutes < 30 Then
				If Minutes = 0 Then
					If Hours = 0 Then
						Return 1;
					Else
						Return (Hours * 2 + 1);
					EndIf; 
				Else
					Return (Hours * 2 + 1);
				EndIf; 
			Else
				If Hours = 23 Then
					Return 48;
				Else
					Return (Hours * 2 + 2);
				EndIf; 
			EndIf;
		EndIf; 
	Else
		If Date > EndOfDay(DateComparison) Then
			Return 48;
		Else
			If Minutes = 0 Then
				If Hours = 0 Then
					Return 1;
				Else
					Return (Hours * 2);
				EndIf; 
			ElsIf Minutes <= 30 Then
				Return (Hours * 2 + 1);
			Else
				If Hours = 23 Then
					Return 48;
				Else
					Return (Hours * 2 + 2);
				EndIf; 
			EndIf;
		EndIf; 
	EndIf;
	
EndFunction

// Function returns weekday name by its number
//
// Parameters
//  WeekDayNumber - Day, number of the week day
//
// Returns:
//   String, weekday name
//
Function DefineWeekday(WeekDayNumber) Export
	
	If WeekDayNumber = 1 Then
		Return "Mo";
	ElsIf WeekDayNumber = 2 Then
		Return "Tu";
	ElsIf WeekDayNumber = 3 Then
		Return "We";
	ElsIf WeekDayNumber = 4 Then
		Return "Th";
	ElsIf WeekDayNumber = 5 Then
		Return "Fr";
	ElsIf WeekDayNumber = 6 Then
		Return "Sa";
	Else
		Return "Su";
	EndIf;
	
EndFunction

// Function defines the next date after the current
//  one depending on the set number of days in the week for displaying in the calendar
//
// Parameters
//  CurrentDate - Date, current date
//
// Returns:
//   Date - next date
//
Function DefineNextDate(CurrentDate, NumberOfWeekDays) Export
	
	If NumberOfWeekDays = "7" Then
		Return CurrentDate + 60*60*24;
	ElsIf NumberOfWeekDays = "6" Then
		If WeekDay(CurrentDate) = 6 Then
			Return CurrentDate + 60*60*24*2;
		Else
			Return CurrentDate + 60*60*24;
		EndIf; 
	ElsIf NumberOfWeekDays = "5" Then
		If WeekDay(CurrentDate) = 5 Then
			Return CurrentDate + 60*60*24*3;
		ElsIf WeekDay(CurrentDate) = 6 Then
			Return CurrentDate + 60*60*24*2;
		Else
			Return CurrentDate + 60*60*24;
		EndIf; 
	EndIf; 
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForWorkWithSelection

// The procedure sets (resets) filter settings for the specified user
// 
Procedure SetStandardFilterSettings(CurrentUser) Export
	
	If Not ValueIsFilled(CurrentUser) Then
		
		CommonClientServer.MessageToUser(
		NStr("en = 'User for whom default selection settings are set is not specified.'; ru = 'Не указан пользователь, для которого устанавливаются настройки подбора по умолчанию.';pl = 'Użytkownik, dla którego ustawiono domyślne ustawienia wyboru nie jest określony.';es_ES = 'Usuario para el cual las configuraciones de selección por defecto están establecidas, no está especificado.';es_CO = 'Usuario para el cual las configuraciones de selección por defecto están establecidas, no está especificado.';tr = 'Varsayılan seçim ayarları için ayarlanmış olan kullanıcı belirtilmemiştir.';it = 'L''utente per il quale le impostazioni di selezione sono impostate per default non è specificato.';de = 'Benutzer, für die Standardauswahleinstellungen festgelegt sind, werden nicht angegeben.'")
		);
		
		Return;
		
	EndIf;
	
	PickSettingsByDefault = PickSettingsByDefault();
	
	For Each Setting In PickSettingsByDefault Do
		
		SetUserSetting(Setting.Value, Setting.Key, CurrentUser);
		
	EndDo;
	
EndProcedure

// Returns default settings match.
//
Function PickSettingsByDefault()
	
	PickSettingsByDefault = New Map;
	
	PickSettingsByDefault.Insert("FilterGroup", 				Catalogs.Products.EmptyRef());
	PickSettingsByDefault.Insert("KeepCurrentHierarchy", 	False);
	PickSettingsByDefault.Insert("RequestQuantityAndPrice",	False);
	PickSettingsByDefault.Insert("ShowBalance", 			True);
	PickSettingsByDefault.Insert("ShowReserve", 			False);
	PickSettingsByDefault.Insert("ShowAvailableBalance",	False);
	PickSettingsByDefault.Insert("ShowPrices", 				True);
	PickSettingsByDefault.Insert("OutputBalancesMethod", 		Enums.BalancesOutputMethodInSelection.InTable);
	PickSettingsByDefault.Insert("OutputAdviceGoBackToProducts", True);
	PickSettingsByDefault.Insert("CouncilServicesOutputInReceiptDocuments", True);
	
	Return PickSettingsByDefault;
	
EndFunction

// Procedure initializes the setting
// of custom selection settings Relevant for new users
//
Procedure SettingUserPickSettingsOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load = True Then
		
		Return;
		
	EndIf;
	
	UserRef = Source.Ref;
	
	If Not ValueIsFilled(UserRef) Then
		
		UserRef = Source.GetNewObjectRef();
		
		If Not ValueIsFilled(UserRef) Then 
			
			UserRef = Catalogs.Users.GetRef();
			Source.SetNewObjectRef(UserRef);
			
		EndIf;
		
	EndIf;
	
	SetStandardFilterSettings(UserRef);
	
EndProcedure

#Region ProceduresForWorkWithVariantsSelectionForm

Function UseMatrixForm(Product) Export
	
	Result = False;
	
	ProductAttributes = Common.ObjectAttributesValues(Product, "ProductsCategory, UseCharacteristics");
	
	If ValueIsFilled(Product) And ProductAttributes.UseCharacteristics Then
		
		Result = UseMatrixFormWithCategory(ProductAttributes.ProductsCategory);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function UseMatrixFormWithCategory(ProductsCategory) Export
	
	Result = False;
	
	If ValueIsFilled(ProductsCategory) Then
		
		CategoryAttributes = Common.ObjectAttributesValues(
			ProductsCategory,
			"SetOfCharacteristicProperties, UseMatrixSelectionForm");
		
		If CategoryAttributes.UseMatrixSelectionForm Then
			
			Query = New Query;
			Query.Text = 
			"SELECT
			|	Properties.Property AS Property
			|FROM
			|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS Properties
			|WHERE
			|	Properties.Ref = &SetOfCharacteristicProperties
			|	AND NOT Properties.DeletionMark";
			
			Query.SetParameter("SetOfCharacteristicProperties", CategoryAttributes.SetOfCharacteristicProperties);
			
			QueryResult = Query.Execute();
			
			Result = (QueryResult.Unload().Count() = 2);
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function UseVariantsGenerator(Product) Export
	
	Result = False;
	
	ProductAttributes = Common.ObjectAttributesValues(Product, "ProductsCategory, UseCharacteristics");
	
	If ValueIsFilled(Product) And ProductAttributes.UseCharacteristics Then
		
		Result = UseVariantsGeneratorWithCategory(ProductAttributes.ProductsCategory);
		
	EndIf;
	
	Return Result;
	
EndFunction

Function UseVariantsGeneratorWithCategory(ProductsCategory)
	
	Result = False;
	
	If ValueIsFilled(ProductsCategory) Then
		
		SetOfCharacteristicProperties = Common.ObjectAttributeValue(
			ProductsCategory,
			"SetOfCharacteristicProperties");
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	Properties.Property AS Property
		|FROM
		|	Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS Properties
		|		INNER JOIN ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInfo
		|		ON Properties.Property = AdditionalAttributesAndInfo.Ref
		|WHERE
		|	Properties.Ref = &SetOfCharacteristicProperties
		|	AND NOT Properties.DeletionMark
		|	AND AdditionalAttributesAndInfo.AdditionalValuesUsed";
		
		Query.SetParameter("SetOfCharacteristicProperties", SetOfCharacteristicProperties);
		
		QueryResult = Query.Execute();
		
		Result = (QueryResult.Unload().Count() > 0);
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

#EndRegion

#Region EmailsSendingProceduresAndFunctions

// The procedure fills out email sending parameters when printing documents.
// Parameters match parameters passed to procedure Printing of documents managers modules.
Procedure FillSendingParameters(SendingParameters, ObjectsArray, PrintFormsCollection) Export
	
	If TypeOf(ObjectsArray) = Type("Array") Then
		
		Recipients = New ValueList;
		MetadataTypesContainingPartnersEmails = DriveContactInformationServer.GetTypesOfMetadataContainingAffiliateEmail();
		
		For Each ArrayObject In ObjectsArray Do
			
			If Not ValueIsFilled(ArrayObject) Then 
				
				Continue; 
				
			ElsIf TypeOf(ArrayObject) = Type("CatalogRef.Counterparties") Then 
				
				// It is for printing from catalogs, for example, price lists from Catalogs.Counterparties
				StructureValuesToValuesList(Recipients, New Structure("Counterparty", ArrayObject));
				Continue;
				
			EndIf;
			
			ObjectMetadata = ArrayObject.Metadata();
			
			AttributesNamesContainedEmail = New Array;
			
			// Check all attributes of the passed object.
			For Each MetadataItem In ObjectMetadata.Attributes Do
				
				ObjectContainsEmail(MetadataItem, MetadataTypesContainingPartnersEmails, AttributesNamesContainedEmail);
				
			EndDo;
			
			If AttributesNamesContainedEmail.Count() > 0 Then
				
				StructureValuesToValuesList(
					Recipients,
					Common.ObjectAttributesValues(ArrayObject, AttributesNamesContainedEmail)
					);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	SendingParameters.Recipient = DriveContactInformationServer.PrepareRecipientsEmailAddresses(Recipients, True);
	
	AvailableAccounts = EmailOperations.AvailableEmailAccounts(True);
	SendingParameters.Insert("Sender", ?(AvailableAccounts.Count() > 0, AvailableAccounts[0].Ref, Undefined));
	
	FillSubjectSendingText(SendingParameters, ObjectsArray, PrintFormsCollection);
	
	// MultilingualSupport
	If ValueIsFilled(SessionParameters.LanguageCodeForOutput) Then
		SessionParameters.LanguageCodeForOutput = "";
	EndIf;
	// End MultilingualSupport
	
EndProcedure

// Initiate receiving of available email
// accounts Parameters:
// ForSending - Boolean - If True is set, then only those records will be chosen from
// which you can send ForReceiving emails   - Boolean - If True is set, then only those records will be chosen by
// which you can receive emails EnableSystemAccount - Boolean - enable system account if it is available
//
// Returns:
// AvailableAccounts - ValueTable - With columns:
//    Ref       - CatalogRef.EmailAccounts - Ref to
//    the Name account - String - Name of
//    the Address account        - String - Email address
//
Function GetAvailableAccount(val ForSending = Undefined, val ForReceiving  = Undefined, val IncludingSystemEmailAccount = True) Export

	AvailableAccounts = EmailOperations.AvailableEmailAccounts(ForSending, ForReceiving, IncludingSystemEmailAccount);
	
	Return ?(AvailableAccounts.Count() > 0, AvailableAccounts[0].Ref, Undefined);
	
EndFunction

// Adds metadata name containing email to array.
//
Procedure ObjectContainsEmail(AttributeObjectMetadata, MetadataTypesContainingPartnersEmails, AttributesNamesContainedEmail)
	
	If Not MetadataTypesContainingPartnersEmails.FindByValue(AttributeObjectMetadata.Type) = Undefined Then
		
		AttributesNamesContainedEmail.Add(AttributeObjectMetadata.Name);
		
	EndIf;
	
EndProcedure

// Procedure fills in theme and text of email sending parameters while printing documents.
// Parameters match parameters passed to procedure Printing of documents managers modules.
Procedure FillSubjectSendingText(SendingParameters, ObjectsArray, PrintFormsCollection)
	
	Subject  = "";
	Text = "";
	
	DocumentTitlePresentation = "";
	PresentationForWhom = "";
	PresentationFromWhom = "";
	
	PrintedDocuments = ObjectsArray.Count() > 0 And Common.ObjectKindByRef(ObjectsArray[0]) = "Document";
	
	If PrintedDocuments Then
		If ObjectsArray.Count() = 1 Then
			DocumentTitlePresentation = GenerateDocumentTitle(ObjectsArray[0]);
		Else
			DocumentTitlePresentation = "Documents: ";
			For Each ObjectForPrinting In ObjectsArray Do
				DocumentTitlePresentation = DocumentTitlePresentation + ?(DocumentTitlePresentation = "Documents: ", "", "; ")
					+ GenerateDocumentTitle(ObjectForPrinting);
			EndDo;
		EndIf;
	EndIf;
	
	TypesStructurePrintObjects = ArrangeListByTypesOfObjects(ObjectsArray);
	
	CompanyByLetter = GetGeneralAttributeValue(TypesStructurePrintObjects, "Company", TypeDescriptionFromRow("Companies"));
	CounterpartyByEmail  = GetGeneralAttributeValue(TypesStructurePrintObjects, "Counterparty",  TypeDescriptionFromRow("Counterparties"));
	
	If ValueIsFilled(CounterpartyByEmail) Then
		PresentationForWhom = "for " + GetParticipantPresentation(CounterpartyByEmail);
	EndIf;
	
	If ValueIsFilled(CompanyByLetter) Then
		PresentationFromWhom = "from " + GetParticipantPresentation(CompanyByLetter);
	EndIf;
	
	AllowedSubjectLength = Metadata.Documents.Event.Attributes.Subject.Type.StringQualifiers.Length;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		PresentationFromWhom = "";
	EndIf;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		PresentationForWhom = "";
	EndIf;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		DocumentTitlePresentation = "";
		If PrintedDocuments Then
			DocumentTitlePresentation = "Documents: ";
			For Each KeyAndValue In TypesStructurePrintObjects Do
				DocumentTitlePresentation = DocumentTitlePresentation + ?(DocumentTitlePresentation = "Documents: ", "", "; ")
					+ ?(IsBlankString(KeyAndValue.Key.ListPresentation), KeyAndValue.Key.Synonym, KeyAndValue.Key.ListPresentation);
			EndDo;
		EndIf;
	EndIf;
	
	Subject = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 %2 %3'; ru = '%1 %2 %3';pl = '%1 %2 %3';es_ES = '%1 %2 %3';es_CO = '%1 %2 %3';tr = '%1 %2 %3';it = '%1 %2 %3';de = '%1 %2 %3'"),
		DocumentTitlePresentation,
		PresentationForWhom,
		PresentationFromWhom
		);
		
	If Not (SendingParameters.Property("Subject") And ValueIsFilled(SendingParameters.Subject)) Then
		SendingParameters.Insert("Subject", CutDoubleSpaces(Subject));
	EndIf;
	
	If Not (SendingParameters.Property("Text") And ValueIsFilled(SendingParameters.Text)) Then
		SendingParameters.Insert("Text", CutDoubleSpaces(Text));
	EndIf;
	
EndProcedure

// The function receives a value of the main print attribute for the email participants.
//
// Parameters:
//  Ref	 - CatalogRef.Counterparties, CatalogRef.Companies	 - Ref to a participant for whom
// it is required to get a presentation Return value:
//  String - presentation value
Function GetParticipantPresentation(Ref)
	
	If Not ValueIsFilled(Ref) Then
		Return "";
	EndIf;
	
	ObjectAttributesNames = New Map;
	
	ObjectAttributesNames.Insert(Type("CatalogRef.Counterparties"), "DescriptionFull");
	ObjectAttributesNames.Insert(Type("CatalogRef.Companies"), "Description");
	
	Return Common.ObjectAttributeValue(Ref, ObjectAttributesNames[TypeOf(Ref)]);
	
EndFunction

// Function replaces double spaces with ordinary ones.
//
// Parameters:
//  SourceLine	 - String
// Return value:
//  String - String without double spaces
Function CutDoubleSpaces(SourceLine)

	While Find(SourceLine, "  ") > 0  Do
	
		SourceLine = StrReplace(SourceLine, "  ", " ");
	
	EndDo; 
	
	Return TrimR(SourceLine);

EndFunction

// Function generates document title presentation.
//
// Returns:
//  String - document presentation as number and date in brief format
Function GenerateDocumentTitle(DocumentRef)

	If Not ValueIsFilled(DocumentRef) Then
		Return "";
	Else
		Return DocumentRef.Metadata().Synonym + StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = '#%1 dated %2'; ru = '№%1 от %2 г.';pl = '#%1 z dn. %2';es_ES = '#%1 fechado %2';es_CO = '#%1 fechado %2';tr = 'no %1 tarih %2';it = '#%1 con data %2';de = 'Nr %1 datiert %2'"),
			ObjectPrefixationClientServer.GetNumberForPrinting(DocumentRef.Number, True, True),
			Format(DocumentRef.Date, "DLF=D"));
	EndIf;

EndFunction

// Function returns reference types description by the incoming row.
//
// Parameters:
//  DescriptionStringTypes	 - String	 - String with catalog names
// separated by commas Return value:
//  TypeDescription
Function TypeDescriptionFromRow(DescriptionStringTypes)

	StructureAvailableTypes 	= New Structure(DescriptionStringTypes);
	ArrayAvailableTypes 		= New Array;
	
	For Each StructureItem In StructureAvailableTypes Do
		
		ArrayAvailableTypes.Add(Type("CatalogRef."+StructureItem.Key));
		
	EndDo; 
	
	Return New TypeDescription(ArrayAvailableTypes);
	
EndFunction

// Function breaks values list into match by values types.
//
// Parameters:
//  ObjectsArray - <ValuesList> - objects list of the different kind
//
// Returns:
//   Map   - match where Key = type Metadata, Value = array of objects of this type
Function ArrangeListByTypesOfObjects(ObjectList) Export
	
	TypesStructure = New Map;
	
	For Each Object In ObjectList Do
		
		DocumentMetadata = Object.Metadata();
		
		If TypesStructure.Get(DocumentMetadata) = Undefined Then
			DocumentArray = New Array;
			TypesStructure.Insert(DocumentMetadata, DocumentArray);
		EndIf;
		
		TypesStructure[DocumentMetadata].Add(Object);
		
	EndDo;
	
	Return TypesStructure;
	
EndFunction

// Returns a reference to the attribute value that must be the same in all the list documents. 
// If an attribute value differs in the list documents, Undefined is returned
//
// Parameters:
//  PrintObjects  - <ValuesList> - documents list in which you should look for counterparty
//
// Returns:
//   <CatalogRef>, Undefined - ref-attribute value that is in all documents, Undefined - else
//
Function GetGeneralAttributeValue(TypesStructure, AttributeName, AllowedTypeDescription)
	Var QueryText;
	
	Query = New Query;
	
	TextQueryByDocument = "
	|	%DocumentName%.%AttributeName% AS %AttributeName%
	|FROM
	|	Document.%DocumentName% AS %DocumentName%
	|WHERE
	|	%DocumentName%.Ref IN(&DocumentsList%DocumentName%)";
	
	TextQueryByDocument = StrReplace(TextQueryByDocument, "%AttributeName%", AttributeName);
	
	For Each KeyAndValue In TypesStructure Do
		
		If IsDocumentAttribute(AttributeName, KeyAndValue.Key) Then
			
			DocumentName = KeyAndValue.Key.Name;
			
			If ValueIsFilled(QueryText) Then
				
				QueryText = QueryText+"
				|UNION
				|
				|SELECT DISTINCT";
				
			Else
				
				QueryText = "SELECT ALLOWED DISTINCT";
				
			EndIf;
			
			QueryText = QueryText + StrReplace(TextQueryByDocument, "%DocumentName%", DocumentName);
			
			Query.SetParameter("DocumentsList"+DocumentName, KeyAndValue.Value);
			
		EndIf; 
		
	EndDo; 
	
	If IsBlankString(QueryText) Then
	
		Return Undefined;
	
	EndIf; 
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		If Selection.Count() = 1 Then
			
			If Selection.Next() Then
				Return AllowedTypeDescription.AdjustValue(Selection[AttributeName]);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

// Sends print forms of sales invoices and tax invoices to the customers,
// specified in Subscriptions information register
//
Procedure SendEmailsBySubscription(StructureData) Export
	
	If StructureData.SendingDocuments.Count() = 0 Then
		Return;
	EndIf;
	
	SalesInvoicesPrintForms = PrintManagement.FormPrintCommands("Document.SalesInvoice.Form.DocumentForm");	
	If StructureData.CreateTaxInvoices Then
		TaxInvoicesPrintForms = PrintManagement.FormPrintCommands("Document.TaxInvoiceIssued.Form.DocumentForm");
	EndIf;
	
	Query = New Query;
	
#Region SalesInvoiceQueryText

	Query.Text = 
	"SELECT ALLOWED
	|	SalesInvoice.Ref AS SalesInvoice,
	|	SalesInvoice.Subscription AS Subscription,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	ISNULL(TaxInvoiceIssuedBasisDocuments.Ref, VALUE(Document.TaxInvoiceIssued.EmptyRef)) AS TaxInvoice
	|INTO TT_SendingDocuments
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		LEFT JOIN Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|		ON SalesInvoice.Ref = TaxInvoiceIssuedBasisDocuments.BasisDocument
	|WHERE
	|	SalesInvoice.Ref IN(&SendingDocuments)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_SendingDocuments.SalesInvoice AS SalesInvoice,
	|	TT_SendingDocuments.TaxInvoice AS TaxInvoice,
	|	SubscriptionPlans.EmailAccount AS EmailAccount,
	|	SubscriptionPlans.EmailSubject AS EmailSubject,
	|	SubscriptionPlans.EmailSubject.Content AS EmailBody,
	|	SubscriptionPlans.SalesInvoicePrintForm AS SalesInvoicePrintForm,
	|	SubscriptionPlans.TaxInvoicePrintForm AS TaxInvoicePrintForm,
	|	Subscriptions.EmailTo AS EmailTo
	|INTO TT_Subscriptions
	|FROM
	|	TT_SendingDocuments AS TT_SendingDocuments
	|		INNER JOIN Catalog.SubscriptionPlans AS SubscriptionPlans
	|		ON TT_SendingDocuments.Subscription = SubscriptionPlans.Ref
	|		INNER JOIN InformationRegister.Subscriptions AS Subscriptions
	|		ON TT_SendingDocuments.Subscription = Subscriptions.SubscriptionPlan
	|			AND TT_SendingDocuments.Counterparty = Subscriptions.Counterparty
	|			AND TT_SendingDocuments.Contract = Subscriptions.Contract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TT_Subscriptions.SalesInvoicePrintForm AS SalesInvoicePrintForm,
	|	TT_Subscriptions.TaxInvoicePrintForm AS TaxInvoicePrintForm
	|FROM
	|	TT_Subscriptions AS TT_Subscriptions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Subscriptions.SalesInvoice AS SalesInvoice,
	|	TT_Subscriptions.TaxInvoice AS TaxInvoice,
	|	TT_Subscriptions.EmailAccount AS EmailAccount,
	|	TT_Subscriptions.EmailSubject AS EmailSubject,
	|	TT_Subscriptions.EmailBody AS EmailBody,
	|	TT_Subscriptions.SalesInvoicePrintForm AS SalesInvoicePrintForm,
	|	TT_Subscriptions.TaxInvoicePrintForm AS TaxInvoicePrintForm,
	|	TT_Subscriptions.EmailTo AS EmailTo
	|FROM
	|	TT_Subscriptions AS TT_Subscriptions
	|TOTALS BY
	|	EmailTo";

#EndRegion
	
	Query.SetParameter("SendingDocuments", StructureData.SendingDocuments);
	
	QueryResult = Query.ExecuteBatch();
	
	Templates = QueryResult[2].Unload()[0];
	SalesInvoiceTemplate = SalesInvoicesPrintForms.Find(Templates.SalesInvoicePrintForm, "UUID");
	If StructureData.CreateTaxInvoices Then
		TaxInvoiceTemplate = TaxInvoicesPrintForms.Find(Templates.TaxInvoicePrintForm, "UUID");
	EndIf;
	
	EmailParameters = New Structure;
	EmailParameters.Insert("SalesInvoices", New Array);
	EmailParameters.Insert("TaxInvoices", New Array);
	EmailParameters.Insert("PrintForms", New Array);
	EmailParameters.Insert("EmailTo", "");
	EmailParameters.Insert("EmailAccount", "");
	EmailParameters.Insert("EmailSubject", "");
	EmailParameters.Insert("EmailBody", "");
	
	Addressees = QueryResult[3].Select(QueryResultIteration.ByGroups);
	
	While Addressees.Next() Do
		
		EmailParameters.SalesInvoices.Clear();
		EmailParameters.TaxInvoices.Clear();
		EmailParameters.PrintForms.Clear();
		
		InvoicesSelection = Addressees.Select();
		While InvoicesSelection.Next() Do
			
			FillPropertyValues(EmailParameters, InvoicesSelection);
			
			EmailParameters.SalesInvoices.Add(InvoicesSelection.SalesInvoice);
			If StructureData.CreateTaxInvoices And Not InvoicesSelection.TaxInvoice.IsEmpty() Then
				EmailParameters.TaxInvoices.Add(InvoicesSelection.TaxInvoice);
			EndIf;
				
		EndDo;	
		
		AddPrintFormsToArray(EmailParameters.PrintForms, SalesInvoiceTemplate.ID, "Document.SalesInvoice", EmailParameters.SalesInvoices);
		If StructureData.CreateTaxInvoices Then
			AddPrintFormsToArray(EmailParameters.PrintForms, TaxInvoiceTemplate.ID, "Document.TaxInvoiceIssued", EmailParameters.TaxInvoices);
		EndIf;
		
		If EmailParameters.PrintForms.Count() = 0 Then
			Continue;
		EndIf;
		
		SendOptions = FillSendOptionsWithSubscription(EmailParameters);
		
		Try
			EmailOperations.SendEmailMessage(EmailParameters.EmailAccount, SendOptions);
		Except
			
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Cannot send Email to recipient: %1, due to: %2'; ru = 'Не удалось отправить E-mail получателю: %1. Причина: %2';pl = 'Nie można wysłać e-maila do odbiorcy: %1, przyczyna: %2';es_ES = 'No se puede enviar un Correo electrónico al destinatario: %1, debido a: %2';es_CO = 'No se puede enviar un Correo electrónico al destinatario: %1, debido a: %2';tr = 'Alıcıya e-posta gönderilemiyor:%1, nedeni:%2';it = 'Non è possibile inviare l''E-mail al destinatario: %1, a causa di: %2';de = 'E-Mail kann nicht an den Empfänger gesendet werden: %1, aufgrund von: %2'"),
				Addressees.EmailAccount,
				BriefErrorDescription(ErrorInfo()),
				);
				
			WriteLogEvent(
				NStr("en = 'Recurring invoicing'; ru = 'Регулярное выставление счетов';pl = 'Faktury cykliczne';es_ES = 'Facturación recurrente';es_CO = 'Facturación recurrente';tr = 'Yinelenen faturalandırma';it = 'Fatturazione ricorrente';de = 'Wiederkehrende Rechnungsstellung'", CommonClientServer.DefaultLanguageCode()),
				EventLogLevel.Error,
				Metadata.ScheduledJobs.CreateDocumentsOnSubscription,
				,
				ErrorDescription);
			
		EndTry;
		
	EndDo;	
	
EndProcedure

Procedure SendEmailsInBackground(Parameters, ResultAddress) Export
	
	Common.OnStartExecuteScheduledJob();
	
	SendTo = New Array;
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	
	EmailParameters = New Structure;
	EmailParameters.Insert("PrintForms", New Array);
	EmailParameters.Insert("EmailAccount", Parameters.EmailAccount);
	
	PrintFormTemplate= DataProcessors.ConfirmationOfArrival.GetTemplate(Parameters.TemplateID);
	
	For Each DocumentRow In Parameters.EmailsTree.Rows Do
		
		Attachments = New Array;
		ObjectsArray = New Array;
		ObjectsArray.Add(DocumentRow.Document);
		
		AddPrintFormsToArray(EmailParameters.PrintForms, Parameters.TemplateID, "DataProcessor.ConfirmationOfArrival", ObjectsArray);
		
		For Each Item In EmailParameters.PrintForms Do
			
			FileName = FilesOperationsServerCallDrive.DefaultPrintFormFileName(
				DocumentRow.Document, Item.TemplateSynonym);
			FullFileName = DriveServer.UniqueFileName(
				CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName + ".pdf");
			Item.PrintForm.Write(FullFileName, SpreadsheetDocumentFileType.PDF);
			FileAddress = PutToTempStorage(FullFileName);

			Attachments.Add(
				New Structure("Presentation, AddressInTempStorage", Item.TemplateSynonym, FileAddress));
		
		EndDo;
		
		For Each RecipientRow In DocumentRow.Rows Do
			SendTo.Add(New Structure("Address, Presentation", RecipientRow.Email, String(RecipientRow.ContactPerson)));
		EndDo;
		
		Subject = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Confirmation of arrival for %1'; ru = 'Подтверждение прибытия для %1';pl = 'Potwierdzenie przybycia dla %1';es_ES = 'Confirmación de llegada para %1';es_CO = 'Confirmación de llegada para %1';tr = '%1 için varış onayı';it = 'Conferma di arrivo per %1';de = 'Ankunftsbestätigung für %1'"), Lower(DocumentRow.Document));
		
		SendOptions = New Structure;
		SendOptions.Insert("SendTo", SendTo);
		SendOptions.Insert("Subject", Subject);
		SendOptions.Insert("Attachments", Attachments);
		
		EmailOperations.SendEmailMessage(EmailParameters.EmailAccount, SendOptions);
		
		EmailParameters.PrintForms.Clear();
		
	EndDo;
	
	DeleteFiles(TempFolderName);
	
EndProcedure

Procedure AddPrintFormsToArray(Forms, TemplateID, ObjectName, ObjectsArray)
	
	If ObjectsArray.Count() = 0 Then 
		Return;
	EndIf;
	
	PrintParameters = New Structure("AddExternalPrintFormsToSet, Result");
	PrintParameters.AddExternalPrintFormsToSet = False;
	PrintParameters.Result = PrintManagementServerCallDrive.ProgramPrintingPrintOptionsStructure(True);
	
	PrintForms = PrintManagement.GeneratePrintForms(
		ObjectName, TemplateID, ObjectsArray, PrintParameters);
		
	For Index = 0 To PrintForms.PrintFormsCollection.Count() - 1 Do
		
		PrintForm = PrintForms.PrintFormsCollection[Index];
		
		If PrintForms.PrintObjects.Count() > Index Then
			PrintObject = PrintForms.PrintObjects[Index].Value;
		
			Forms.Add(
				New Structure("TemplateSynonym, PrintForm, PrintObject",
				PrintForm.TemplateSynonym, PrintForm.SpreadsheetDocument, PrintObject));
		EndIf;
				
	EndDo;
				
EndProcedure

Function FillSendOptionsWithSubscription(EmailParameters)
	
	SendTo = New Array;
	TempFolderName = GetTempFileName();
	CreateDirectory(TempFolderName);
	
	RecipientsMailAddresses = CommonClientServer.ParseStringWithEmailAddresses(EmailParameters.EmailTo);
	For Each Recipient In RecipientsMailAddresses Do
		SendTo.Add(New Structure("Address, Presentation", Recipient.Address, Recipient.Presentation));
	EndDo;
		
	Attachments = New Array;
	For Each Item In EmailParameters.PrintForms Do
		
		FileName = FilesOperationsServerCallDrive.DefaultPrintFormFileName(Item.PrintObject, Item.TemplateSynonym);
		FullFileName = UniqueFileName(CommonClientServer.AddLastPathSeparator(TempFolderName) + FileName + ".pdf");
		Item.PrintForm.Write(FullFileName, SpreadsheetDocumentFileType.PDF);
		FileAddress = PutToTempStorage(FullFileName);

		Attachments.Add(New Structure("Presentation, AddressInTempStorage", Item.TemplateSynonym, FileAddress));
		
	EndDo;
	
	SendOptions = New Structure;
	SendOptions.Insert("SendTo", SendTo);
	SendOptions.Insert("Subject", EmailParameters.EmailSubject);
	SendOptions.Insert("Body", EmailParameters.EmailBody);	
	SendOptions.Insert("Attachments", Attachments);
	
	Return SendOptions;
	
EndFunction

Function UniqueFileName(FileName) Export
	
	File = New File(FileName);
	BaseName = File.BaseName;
	Extension = File.Extension;
	Folder = File.Path;
	
	Counter = 1;
	While File.Exist() Do
		Counter = Counter + 1;
		File = New File(Folder + BaseName + " (" + Counter + ")" + Extension);
	EndDo;
	
	Return File.FullName;
	
EndFunction


//////////////////////////////////////////////////////////////////////////////// 
// General module Common does not support "Server call" any more.
// Corrections and support of a new behavior
//

// Replaces
// call Common.ObjectAttributeValue from the Add() procedure of the Price-list processor form
//
Function ReadAttributeValue_Owner(ObjectOrRef) Export
	
	Return Common.ObjectAttributeValue(ObjectOrRef, "Owner");
	
EndFunction

Function ReadAttributeValue_IsFolder(ObjectOrRef) Export
	
	Return Common.ObjectAttributeValue(ObjectOrRef, "IsFolder");
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsExchangeRateDifference

// Function returns a flag showing that rate differences are required.
//
Function GetNeedToCalculateExchangeDifferences(TempTablesManager, PaymentsTemporaryTableName) Export
	
	CalculateCurrencyDifference = Constants.ForeignExchangeAccounting.Get();
	
	If CalculateCurrencyDifference Then
		QueryText =
		"SELECT DISTINCT
		|	TableAccounts.Currency AS Currency
		|FROM
		|	%TemporaryTableSettlements% AS TableAccounts
		|		INNER JOIN Catalog.Companies AS Companies
		|		ON TableAccounts.Company = Companies.Ref
		|WHERE
		|	TableAccounts.Currency <> Companies.PresentationCurrency";
		QueryText = StrReplace(QueryText, "%TemporaryTableSettlements%", PaymentsTemporaryTableName);
		Query = New Query();
		Query.Text = QueryText;
		Query.TempTablesManager = TempTablesManager;
		CalculateCurrencyDifference = Not Query.Execute().IsEmpty();
	EndIf;
	
	If CalculateCurrencyDifference Then
		ForeignCurrencyRevaluationPeriodicity = Constants.ForeignCurrencyRevaluationPeriodicity.Get();
		If ForeignCurrencyRevaluationPeriodicity = Enums.ForeignCurrencyRevaluationPeriodicity.DuringOpertionExecution Then
			CalculateCurrencyDifference = True;
		Else
			CalculateCurrencyDifference = False;
		EndIf;
	EndIf;
	
	Return CalculateCurrencyDifference;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesAccountsPayable(TempTablesManager, WithAdvanceOffset, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAccountsPayable");
	
	If Not CalculateCurrencyDifference Then
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur
		|FROM
		|	TemporaryTableAccountsPayable AS DocumentTable
		|
		|ORDER BY
		|	DocumentTable.ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType";
	
	ElsIf WithAdvanceOffset Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN NOT &UseDefaultTypeOfAccounting
		|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsPayable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsPayable.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Company,
		|						TemporaryTableAccountsPayable.PresentationCurrency,
		|						TemporaryTableAccountsPayable.Counterparty,
		|						TemporaryTableAccountsPayable.Contract,
		|						TemporaryTableAccountsPayable.Document,
		|						TemporaryTableAccountsPayable.Order,
		|						TemporaryTableAccountsPayable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsPayable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN NOT &UseDefaultTypeOfAccounting
		|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Contract.SettlementsCurrency
		|					FROM
		|						TemporaryTableAccountsPayable)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	(TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) = 0)
		|	AND (CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordTable.Period AS Period,
		|	RegisterRecordTable.RecordType AS RecordType,
		|	RegisterRecordTable.Company AS Company,
		|	RegisterRecordTable.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordTable.Counterparty AS Counterparty,
		|	RegisterRecordTable.Contract AS Contract,
		|	RegisterRecordTable.Document AS Document,
		|	RegisterRecordTable.Order AS Order,
		|	RegisterRecordTable.SettlementsType AS SettlementsType,
		|	RegisterRecordTable.Currency AS Currency,
		|	SUM(RegisterRecordTable.Amount) AS Amount,
		|	SUM(RegisterRecordTable.AmountCur) AS AmountCur,
		|	SUM(RegisterRecordTable.AmountForPayment) AS AmountForPayment,
		|	SUM(RegisterRecordTable.AmountForPaymentCur) AS AmountForPaymentCur,
		|	RegisterRecordTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Period,
		|		DocumentTable.RecordType AS RecordType,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.PresentationCurrency AS PresentationCurrency,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.Amount AS Amount,
		|		DocumentTable.AmountCur AS AmountCur,
		|		DocumentTable.AmountForPayment AS AmountForPayment,
		|		DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|		DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|	FROM
		|		TemporaryTableAccountsPayable AS DocumentTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Expense),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS RegisterRecordTable
		|
		|GROUP BY
		|	RegisterRecordTable.Period,
		|	RegisterRecordTable.Company,
		|	RegisterRecordTable.PresentationCurrency,
		|	RegisterRecordTable.Counterparty,
		|	RegisterRecordTable.Contract,
		|	RegisterRecordTable.Document,
		|	RegisterRecordTable.Order,
		|	RegisterRecordTable.SettlementsType,
		|	RegisterRecordTable.Currency,
		|	RegisterRecordTable.ContentOfAccountingRecord,
		|	RegisterRecordTable.RecordType
		|
		|HAVING
		|	SUM(RegisterRecordTable.Amount) <> 0
		|		OR SUM(RegisterRecordTable.AmountCur) <> 0
		|		OR SUM(RegisterRecordTable.AmountForPayment) <> 0
		|		OR SUM(RegisterRecordTable.AmountForPaymentCur) <> 0
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCurrencyDifferences.Company AS Company,
		|	TableCurrencyDifferences.PresentationCurrency AS PresentationCurrency,
		|	TableCurrencyDifferences.Counterparty AS Counterparty,
		|	TableCurrencyDifferences.Contract AS Contract,
		|	TableCurrencyDifferences.Document AS Document,
		|	TableCurrencyDifferences.Order AS Order,
		|	TableCurrencyDifferences.SettlementsType AS SettlementsType,
		|	SUM(TableCurrencyDifferences.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
		|	TableCurrencyDifferences.Currency AS Currency,
		|	TableCurrencyDifferences.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Date,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.PresentationCurrency AS PresentationCurrency,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.GLAccount AS GLAccount,
		|		DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		CASE
		|			WHEN &UseDefaultTypeOfAccounting
		|				THEN Counterparties.GLAccountVendorSettlements
		|			ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		END,
		|		DocumentTable.AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|			LEFT JOIN Catalog.Counterparties AS Counterparties
		|			ON DocumentTable.Counterparty = Counterparties.Ref
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableCurrencyDifferences
		|
		|GROUP BY
		|	TableCurrencyDifferences.Company,
		|	TableCurrencyDifferences.PresentationCurrency,
		|	TableCurrencyDifferences.Counterparty,
		|	TableCurrencyDifferences.Contract,
		|	TableCurrencyDifferences.Document,
		|	TableCurrencyDifferences.Order,
		|	TableCurrencyDifferences.SettlementsType,
		|	TableCurrencyDifferences.Currency,
		|	TableCurrencyDifferences.GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary";
		
	Else
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN NOT &UseDefaultTypeOfAccounting
		|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsPayable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsPayable.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) IN
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Company,
		|						TemporaryTableAccountsPayable.PresentationCurrency,
		|						TemporaryTableAccountsPayable.Counterparty,
		|						TemporaryTableAccountsPayable.Contract,
		|						TemporaryTableAccountsPayable.Document,
		|						TemporaryTableAccountsPayable.Order,
		|						TemporaryTableAccountsPayable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsPayable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN NOT &UseDefaultTypeOfAccounting
		|			THEN VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|				THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|				THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|		END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Currency
		|					FROM
		|						TemporaryTableAccountsPayable)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	TableAccounts.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	AND (CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|					THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|					THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|			END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Priority,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsPayable AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Contract,
		|	DocumentTable.Document,
		|	DocumentTable.Order,
		|	DocumentTable.SettlementsType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	0,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
		|
		|ORDER BY
		|	Priority,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextCurrencyExchangeRateAccountsReceivable(TempTablesManager, WithAdvanceOffset, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAccountsReceivable");
	
	If Not CalculateCurrencyDifference Then
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsReceivable AS DocumentTable
		|
		|ORDER BY
		|	DocumentTable.ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType";
	
	ElsIf WithAdvanceOffset Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsReceivable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsReceivable.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Company,
		|						TemporaryTableAccountsReceivable.PresentationCurrency,
		|						TemporaryTableAccountsReceivable.Counterparty,
		|						TemporaryTableAccountsReceivable.Contract,
		|						TemporaryTableAccountsReceivable.Document,
		|						TemporaryTableAccountsReceivable.Order,
		|						TemporaryTableAccountsReceivable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Contract.SettlementsCurrency
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	(TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) = 0)
		|	AND (CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordTable.Period AS Period,
		|	RegisterRecordTable.RecordType AS RecordType,
		|	RegisterRecordTable.Company AS Company,
		|	RegisterRecordTable.PresentationCurrency AS PresentationCurrency,
		|	RegisterRecordTable.Counterparty AS Counterparty,
		|	RegisterRecordTable.Contract AS Contract,
		|	RegisterRecordTable.Document AS Document,
		|	RegisterRecordTable.Order AS Order,
		|	RegisterRecordTable.SettlementsType AS SettlementsType,
		|	RegisterRecordTable.Currency AS Currency,
		|	SUM(RegisterRecordTable.Amount) AS Amount,
		|	SUM(RegisterRecordTable.AmountCur) AS AmountCur,
		|	SUM(RegisterRecordTable.AmountForPayment) AS AmountForPayment,
		|	SUM(RegisterRecordTable.AmountForPaymentCur) AS AmountForPaymentCur,
		|	RegisterRecordTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Period,
		|		DocumentTable.RecordType AS RecordType,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.PresentationCurrency AS PresentationCurrency,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.Amount AS Amount,
		|		DocumentTable.AmountCur AS AmountCur,
		|		DocumentTable.AmountForPayment AS AmountForPayment,
		|		DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|		DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|	FROM
		|		TemporaryTableAccountsReceivable AS DocumentTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Expense),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		0,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS RegisterRecordTable
		|
		|GROUP BY
		|	RegisterRecordTable.Period,
		|	RegisterRecordTable.Company,
		|	RegisterRecordTable.PresentationCurrency,
		|	RegisterRecordTable.Counterparty,
		|	RegisterRecordTable.Contract,
		|	RegisterRecordTable.Document,
		|	RegisterRecordTable.Order,
		|	RegisterRecordTable.SettlementsType,
		|	RegisterRecordTable.Currency,
		|	RegisterRecordTable.ContentOfAccountingRecord,
		|	RegisterRecordTable.RecordType
		|
		|HAVING
		|	SUM(RegisterRecordTable.Amount) <> 0
		|		OR SUM(RegisterRecordTable.AmountCur) <> 0
		|		OR SUM(RegisterRecordTable.AmountForPayment) <> 0
		|		OR SUM(RegisterRecordTable.AmountForPaymentCur) <> 0
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCurrencyDifferences.Company AS Company,
		|	TableCurrencyDifferences.PresentationCurrency AS PresentationCurrency,
		|	TableCurrencyDifferences.Counterparty AS Counterparty,
		|	TableCurrencyDifferences.Contract AS Contract,
		|	TableCurrencyDifferences.Document AS Document,
		|	TableCurrencyDifferences.Order AS Order,
		|	TableCurrencyDifferences.SettlementsType AS SettlementsType,
		|	SUM(TableCurrencyDifferences.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
		|	TableCurrencyDifferences.Currency AS Currency,
		|	TableCurrencyDifferences.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Date,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.PresentationCurrency AS PresentationCurrency,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.GLAccount AS GLAccount,
		|		DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		DocumentTable.Company,
		|		DocumentTable.PresentationCurrency,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		&Ref,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		CounterpartiesRef.GLAccountCustomerSettlements,
		|		DocumentTable.AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|			LEFT JOIN Catalog.Counterparties AS CounterpartiesRef
		|			ON DocumentTable.Counterparty = CounterpartiesRef.Ref
		|		
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableCurrencyDifferences
		|
		|GROUP BY
		|	TableCurrencyDifferences.Company,
		|	TableCurrencyDifferences.PresentationCurrency,
		|	TableCurrencyDifferences.Counterparty,
		|	TableCurrencyDifferences.Contract,
		|	TableCurrencyDifferences.Document,
		|	TableCurrencyDifferences.Order,
		|	TableCurrencyDifferences.SettlementsType,
		|	TableCurrencyDifferences.Currency,
		|	TableCurrencyDifferences.GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary
		|";
		
	Else
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsReceivable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsReceivable.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Company,
		|						TemporaryTableAccountsReceivable.PresentationCurrency,
		|						TemporaryTableAccountsReceivable.Counterparty,
		|						TemporaryTableAccountsReceivable.Contract,
		|						TemporaryTableAccountsReceivable.Document,
		|						TemporaryTableAccountsReceivable.Order,
		|						TemporaryTableAccountsReceivable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Currency
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	TableAccounts.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	AND (CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Priority,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	DocumentTable.ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsReceivable AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Contract,
		|	DocumentTable.Document,
		|	DocumentTable.Order,
		|	DocumentTable.SettlementsType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	0,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
		|
		|ORDER BY
		|	Priority,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesCashAssets(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableCashAssets");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	FundsBalance.Company AS Company,
		|	FundsBalance.PresentationCurrency AS PresentationCurrency,
		|	FundsBalance.PaymentMethod AS PaymentMethod,
		|	FundsBalance.CashAssetType AS CashAssetType,
		|	FundsBalance.BankAccountPettyCash AS BankAccountPettyCash,
		|	FundsBalance.Currency AS Currency,
		|	FundsBalance.BankAccountPettyCash.GLAccount AS GLAccount,
		|	SUM(FundsBalance.AmountBalance) AS AmountBalance,
		|	SUM(FundsBalance.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.PaymentMethod AS PaymentMethod,
		|		TemporaryTable.CashAssetType AS CashAssetType,
		|		TemporaryTable.BankAccountPettyCash AS BankAccountPettyCash,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableCashAssets AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.PaymentMethod,
		|		TableBalances.CashAssetType,
		|		TableBalances.BankAccountPettyCash,
		|		TableBalances.Currency,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.CashAssets.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, PaymentMethod, CashAssetType, BankAccountPettyCash, Currency) IN
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssets.Company,
		|						TemporaryTableCashAssets.PresentationCurrency,
		|						TemporaryTableCashAssets.PaymentMethod,
		|						TemporaryTableCashAssets.CashAssetType,
		|						TemporaryTableCashAssets.BankAccountPettyCash,
		|						TemporaryTableCashAssets.Currency
		|					FROM
		|						TemporaryTableCashAssets)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.PaymentMethod,
		|		DocumentRegisterRecords.CashAssetType,
		|		DocumentRegisterRecords.BankAccountPettyCash,
		|		DocumentRegisterRecords.Currency,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.CashAssets AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS FundsBalance
		|
		|GROUP BY
		|	FundsBalance.Company,
		|	FundsBalance.PresentationCurrency,
		|	FundsBalance.PaymentMethod,
		|	FundsBalance.CashAssetType,
		|	FundsBalance.BankAccountPettyCash,
		|	FundsBalance.Currency,
		|	FundsBalance.BankAccountPettyCash.GLAccount
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	PaymentMethod,
		|	CashAssetType,
		|	BankAccountPettyCash,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.PresentationCurrency AS PresentationCurrency,
		|	TableCashAssets.PaymentMethod AS PaymentMethod,
		|	TableCashAssets.CashAssetType AS CashAssetType,
		|	TableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesBanking
		|FROM
		|	TemporaryTableCashAssets AS TableCashAssets
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableCashAssets.Company = TableBalances.Company
		|			AND TableCashAssets.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableCashAssets.PaymentMethod = TableBalances.PaymentMethod
		|			AND TableCashAssets.CashAssetType = TableBalances.CashAssetType
		|			AND TableCashAssets.BankAccountPettyCash = TableBalances.BankAccountPettyCash
		|			AND TableCashAssets.Currency = TableBalances.Currency
		|			AND TableCashAssets.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableCashAssets.Company = AccountingExchangeRateSliceLast.Company
		|			AND (TableCashAssets.PresentationCurrency = AccountingExchangeRateSliceLast.Currency)
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssets.Currency
		|					FROM
		|						TemporaryTableCashAssets)) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
		|		ON TableCashAssets.Currency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
		|			AND TableCashAssets.Company = CurrencyExchangeRateBankAccountPettyCashSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.PaymentMethod AS PaymentMethod,
		|	DocumentTable.CashAssetType AS CashAssetType,
		|	DocumentTable.Item AS Item,
		|	DocumentTable.BankAccountPettyCash AS BankAccountPettyCash,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssets AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.PaymentMethod,
		|	DocumentTable.CashAssetType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
		|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
		|	END,
		|	DocumentTable.BankAccountPettyCash,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.PresentationCurrency AS PresentationCurrency,
		|	TableCashAssets.PaymentMethod AS PaymentMethod,
		|	TableCashAssets.CashAssetType AS CashAssetType,
		|	TableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		|	0 AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesBanking
		|FROM
		|	TemporaryTableCashAssets AS TableCashAssets
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.PaymentMethod AS PaymentMethod,
		|	DocumentTable.CashAssetType AS CashAssetType,
		|	DocumentTable.Item AS Item,
		|	DocumentTable.BankAccountPettyCash AS BankAccountPettyCash,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssets AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType";
	
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetQueryTextExchangeRateDifferencesFundsTransfersBeingProcessed(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableFundsTransfersBeingProcessed");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	FundsBalance.Company AS Company,
		|	FundsBalance.PresentationCurrency AS PresentationCurrency,
		|	FundsBalance.PaymentProcessor AS PaymentProcessor,
		|	FundsBalance.PaymentProcessorContract AS PaymentProcessorContract,
		|	FundsBalance.POSTerminal AS POSTerminal,
		|	FundsBalance.Currency AS Currency,
		|	FundsBalance.Document AS Document,
		|	SUM(FundsBalance.AmountBalance) AS AmountBalance,
		|	SUM(FundsBalance.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.PaymentProcessor AS PaymentProcessor,
		|		TemporaryTable.PaymentProcessorContract AS PaymentProcessorContract,
		|		TemporaryTable.POSTerminal AS POSTerminal,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableFundsTransfersBeingProcessed AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.PaymentProcessor,
		|		TableBalances.PaymentProcessorContract,
		|		TableBalances.POSTerminal,
		|		TableBalances.Currency,
		|		TableBalances.Document,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.FundsTransfersBeingProcessed.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, PaymentProcessor, PaymentProcessorContract, POSTerminal, Currency, Document) IN
		|					(SELECT DISTINCT
		|						TemporaryTableFundsTransfersBeingProcessed.Company,
		|						TemporaryTableFundsTransfersBeingProcessed.PresentationCurrency,
		|						TemporaryTableFundsTransfersBeingProcessed.PaymentProcessor,
		|						TemporaryTableFundsTransfersBeingProcessed.PaymentProcessorContract,
		|						TemporaryTableFundsTransfersBeingProcessed.POSTerminal,
		|						TemporaryTableFundsTransfersBeingProcessed.Currency,
		|						TemporaryTableFundsTransfersBeingProcessed.Document
		|					FROM
		|						TemporaryTableFundsTransfersBeingProcessed)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.PaymentProcessor,
		|		DocumentRegisterRecords.PaymentProcessorContract,
		|		DocumentRegisterRecords.POSTerminal,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.Document,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.FundsTransfersBeingProcessed AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS FundsBalance
		|
		|GROUP BY
		|	FundsBalance.Company,
		|	FundsBalance.PresentationCurrency,
		|	FundsBalance.PaymentProcessor,
		|	FundsBalance.PaymentProcessorContract,
		|	FundsBalance.POSTerminal,
		|	FundsBalance.Currency,
		|	FundsBalance.Document
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableFunds.Company AS Company,
		|	TableFunds.PresentationCurrency AS PresentationCurrency,
		|	TableFunds.PaymentProcessor AS PaymentProcessor,
		|	TableFunds.PaymentProcessorContract AS PaymentProcessorContract,
		|	TableFunds.POSTerminal AS POSTerminal,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition / (CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableFunds.Currency AS Currency,
		|	TableFunds.Document AS Document,
		|	&FundsTransfersBeingProcessedGLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed
		|FROM
		|	TemporaryTableFundsTransfersBeingProcessed AS TableFunds
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableFunds.Company = TableBalances.Company
		|			AND TableFunds.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableFunds.PaymentProcessor = TableBalances.PaymentProcessor
		|			AND TableFunds.PaymentProcessorContract = TableBalances.PaymentProcessorContract
		|			AND TableFunds.POSTerminal = TableBalances.POSTerminal
		|			AND TableFunds.Currency = TableBalances.Currency
		|			AND TableFunds.Document = TableBalances.Document
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableFunds.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableFunds.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTableFundsTransfersBeingProcessed.Currency
		|					FROM
		|						TemporaryTableFundsTransfersBeingProcessed)) AS CurrencyExchangeRateSliceLast
		|		ON TableFunds.Currency = CurrencyExchangeRateSliceLast.Currency
		|			AND TableFunds.Company = CurrencyExchangeRateSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|					THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition / (CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|					THEN CurrencyExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateSliceLast.Repetition)
		|			END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Period AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.PaymentProcessor AS PaymentProcessor,
		|	DocumentTable.PaymentProcessorContract AS PaymentProcessorContract,
		|	DocumentTable.POSTerminal AS POSTerminal,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.FeeAmount AS FeeAmount
		|FROM
		|	TemporaryTableFundsTransfersBeingProcessed AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.PaymentProcessor,
		|	DocumentTable.PaymentProcessorContract,
		|	DocumentTable.POSTerminal,
		|	DocumentTable.Currency,
		|	DocumentTable.Document,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	0
		|FROM
		|	TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT
		|	1 AS LineNumber,
		|	TableFunds.Period AS Date,
		|	TableFunds.Company AS Company,
		|	TableFunds.PresentationCurrency AS PresentationCurrency,
		|	TableFunds.PaymentProcessor AS PaymentProcessor,
		|	TableFunds.PaymentProcessorContract AS PaymentProcessorContract,
		|	TableFunds.POSTerminal AS POSTerminal,
		|	0 AS AmountOfExchangeDifferences,
		|	TableFunds.Currency AS Currency,
		|	TableFunds.Document AS Document,
		|	&FundsTransfersBeingProcessedGLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed
		|FROM
		|	TemporaryTableFundsTransfersBeingProcessed AS TableFunds
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Period AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.PaymentProcessor AS PaymentProcessor,
		|	DocumentTable.PaymentProcessorContract AS PaymentProcessorContract,
		|	DocumentTable.POSTerminal AS POSTerminal,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.FeeAmount AS FeeAmount
		|FROM
		|	TemporaryTableFundsTransfersBeingProcessed AS DocumentTable";
	
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesCashInCashRegisters(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableCashAssetsInRetailCashes");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	FundsBalance.Company AS Company,
		|	FundsBalance.PresentationCurrency AS PresentationCurrency,
		|	FundsBalance.CashCR AS CashCR,
		|	FundsBalance.CashCR.GLAccount AS GLAccount,
		|	FundsBalance.Currency AS Currency,
		|	SUM(FundsBalance.AmountBalance) AS AmountBalance,
		|	SUM(FundsBalance.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.CashCR AS CashCR,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableCashAssetsInRetailCashes AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.CashCR,
		|		TableBalances.CashCR.CashCurrency,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.CashInCashRegisters.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, CashCR) IN
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssetsInRetailCashes.Company,
		|						TemporaryTableCashAssetsInRetailCashes.PresentationCurrency,
		|						TemporaryTableCashAssetsInRetailCashes.CashCR
		|					FROM
		|						TemporaryTableCashAssetsInRetailCashes)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.CashCR,
		|		DocumentRegisterRecords.CashCR.CashCurrency,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.CashInCashRegisters AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS FundsBalance
		|
		|GROUP BY
		|	FundsBalance.Company,
		|	FundsBalance.PresentationCurrency,
		|	FundsBalance.CashCR,
		|	FundsBalance.Currency,
		|	FundsBalance.CashCR.GLAccount
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	CashCR,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.PresentationCurrency AS PresentationCurrency,
		|	TableCashAssets.CashCR AS CashCR,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesCashAssetsInRetailCashes
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS TableCashAssets
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableCashAssets.Company = TableBalances.Company
		|			AND TableCashAssets.CashCR = TableBalances.CashCR
		|			AND TableCashAssets.Currency = TableBalances.Currency
		|			AND TableCashAssets.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableCashAssets.Company = AccountingExchangeRateSliceLast.Company
		|			AND (&PresentationCurrency = AccountingExchangeRateSliceLast.Currency)
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssetsInRetailCashes.Currency
		|					FROM
		|						TemporaryTableCashAssetsInRetailCashes)) AS CurrencyExchangeRateBankAccountPettyCashSliceLast
		|		ON TableCashAssets.Currency = CurrencyExchangeRateBankAccountPettyCashSliceLast.Currency
		|			AND TableCashAssets.Company = CurrencyExchangeRateBankAccountPettyCashSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition / (CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateBankAccountPettyCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateBankAccountPettyCashSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.CashCR AS CashCR,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.Currency,
		|	DocumentTable.CashCR,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
	
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.PresentationCurrency AS PresentationCurrency,
		|	TableCashAssets.CashCR AS CashCR,
		|	0 AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesCashAssetsInRetailCashes
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS TableCashAssets
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.CashCR AS CashCR,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType";
	
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextCurrencyExchangeRateAdvanceHolders(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAdvanceHolders");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.Employee AS Employee,
		|	AccountsBalances.Currency AS Currency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Employee.AdvanceHoldersGLAccount AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.Employee AS Employee,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAdvanceHolders AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.Employee,
		|		TableBalances.Currency,
		|		TableBalances.Document,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AdvanceHolders.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, Employee, Currency, Document) In
		|					(SELECT DISTINCT
		|						TemporaryTableAdvanceHolders.Company,
		|						TemporaryTableAdvanceHolders.PresentationCurrency,
		|						TemporaryTableAdvanceHolders.Employee,
		|						TemporaryTableAdvanceHolders.Currency,
		|						TemporaryTableAdvanceHolders.Document
		|					FROM
		|						TemporaryTableAdvanceHolders)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.Employee,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.Document,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.Employee,
		|	AccountsBalances.Currency,
		|	AccountsBalances.Document,
		|	AccountsBalances.Employee.AdvanceHoldersGLAccount
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	Employee,
		|	Currency,
		|	Document,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.Document AS Document,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
		|FROM
		|	TemporaryTableAdvanceHolders AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.Employee = TableBalances.Employee
		|			AND TableAccounts.Currency = TableBalances.Currency
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAdvanceHolders.Currency
		|					FROM
		|						TemporaryTableAdvanceHolders)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAdvanceHolders AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Document,
		|	DocumentTable.Employee,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.Currency,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.Document AS Document,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
		|FROM
		|	TemporaryTableAdvanceHolders AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAdvanceHolders AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesPayroll(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTablePayroll");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.PresentationCurrency AS PresentationCurrency,
		|	AccountsBalances.StructuralUnit AS StructuralUnit,
		|	AccountsBalances.Employee AS Employee,
		|	AccountsBalances.Currency AS Currency,
		|	AccountsBalances.RegistrationPeriod AS RegistrationPeriod,
		|	AccountsBalances.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.StructuralUnit AS StructuralUnit,
		|		TemporaryTable.Employee AS Employee,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.RegistrationPeriod AS RegistrationPeriod,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTablePayroll AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.StructuralUnit,
		|		TableBalances.Employee,
		|		TableBalances.Currency,
		|		TableBalances.RegistrationPeriod,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.Payroll.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, StructuralUnit, Employee, Currency, RegistrationPeriod) In
		|					(SELECT DISTINCT
		|						TemporaryTablePayroll.Company,
		|						TemporaryTablePayroll.PresentationCurrency,
		|						TemporaryTablePayroll.StructuralUnit,
		|						TemporaryTablePayroll.Employee,
		|						TemporaryTablePayroll.Currency,
		|						TemporaryTablePayroll.RegistrationPeriod
		|					FROM
		|						TemporaryTablePayroll)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.StructuralUnit,
		|		DocumentRegisterRecords.Employee,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.RegistrationPeriod,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Payroll AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.PresentationCurrency,
		|	AccountsBalances.StructuralUnit,
		|	AccountsBalances.Employee,
		|	AccountsBalances.Currency,
		|	AccountsBalances.RegistrationPeriod,
		|	AccountsBalances.Employee.SettlementsHumanResourcesGLAccount
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	StructuralUnit,
		|	Employee,
		|	Currency,
		|	RegistrationPeriod,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.StructuralUnit AS StructuralUnit,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.RegistrationPeriod AS RegistrationPeriod,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesPayroll
		|FROM
		|	TemporaryTablePayroll AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TableAccounts.StructuralUnit = TableBalances.StructuralUnit
		|			AND TableAccounts.Employee = TableBalances.Employee
		|			AND TableAccounts.Currency = TableBalances.Currency
		|			AND TableAccounts.RegistrationPeriod = TableBalances.RegistrationPeriod
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TableAccounts.Company = AccountingExchangeRateSliceLast.Company
		|			AND TableAccounts.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTablePayroll.Currency
		|					FROM
		|						TemporaryTablePayroll)) AS CalculationExchangeRateSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRateSliceLast.Currency
		|			AND TableAccounts.Company = CalculationExchangeRateSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|					THEN AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition / (CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|					THEN CalculationExchangeRateSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CalculationExchangeRateSliceLast.Repetition)
		|			END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTablePayroll AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.StructuralUnit,
		|	DocumentTable.Employee,
		|	DocumentTable.Currency,
		|	DocumentTable.RegistrationPeriod,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
	
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.PresentationCurrency AS PresentationCurrency,
		|	TableAccounts.StructuralUnit AS StructuralUnit,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.RegistrationPeriod AS RegistrationPeriod,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesPayroll
		|FROM
		|	TemporaryTablePayroll AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTablePayroll AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesPOSSummary(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTablePOSSummary");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT ALLOWED
		|	POSSummaryBalances.Company AS Company,
		|	POSSummaryBalances.PresentationCurrency AS PresentationCurrency,
		|	POSSummaryBalances.StructuralUnit AS StructuralUnit,
		|	POSSummaryBalances.GLAccount AS GLAccount,
		|	POSSummaryBalances.Currency AS Currency,
		|	SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
		|	SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.PresentationCurrency AS PresentationCurrency,
		|		TemporaryTable.StructuralUnit AS StructuralUnit,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.GLAccount AS GLAccount,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTablePOSSummary AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.PresentationCurrency,
		|		TableBalances.StructuralUnit,
		|		TableBalances.Currency,
		|		TableBalances.StructuralUnit.GLAccountInRetail,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.POSSummary.Balance(
		|				&PointInTime,
		|				(Company, PresentationCurrency, StructuralUnit, Currency) IN
		|					(SELECT DISTINCT
		|						TemporaryTablePOSSummary.Company,
		|						TemporaryTablePOSSummary.PresentationCurrency,
		|						TemporaryTablePOSSummary.StructuralUnit,
		|						TemporaryTablePOSSummary.Currency
		|					FROM
		|						TemporaryTablePOSSummary)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.PresentationCurrency,
		|		DocumentRegisterRecords.StructuralUnit,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.StructuralUnit.GLAccountInRetail,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.POSSummary AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS POSSummaryBalances
		|
		|GROUP BY
		|	POSSummaryBalances.Company,
		|	POSSummaryBalances.PresentationCurrency,
		|	POSSummaryBalances.StructuralUnit,
		|	POSSummaryBalances.Currency,
		|	POSSummaryBalances.GLAccount
		|
		|INDEX BY
		|	Company,
		|	PresentationCurrency,
		|	StructuralUnit,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TablePOSSummary.Company AS Company,
		|	TablePOSSummary.PresentationCurrency AS PresentationCurrency,
		|	TablePOSSummary.StructuralUnit AS StructuralUnit,
		|	CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|			THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition / (CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|			THEN CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition)
		|	END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TablePOSSummary.Currency AS Currency,
		|	TablePOSSummary.GLAccount AS GLAccount
		|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
		|FROM
		|	TemporaryTablePOSSummary AS TablePOSSummary
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TablePOSSummary.Company = TableBalances.Company
		|			AND TablePOSSummary.PresentationCurrency = TableBalances.PresentationCurrency
		|			AND TablePOSSummary.StructuralUnit = TableBalances.StructuralUnit
		|			AND TablePOSSummary.Currency = TableBalances.Currency
		|			AND TablePOSSummary.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&PointInTime, ) AS AccountingExchangeRateSliceLast
		|		ON TablePOSSummary.Company = AccountingExchangeRateSliceLast.Company
		|			AND TablePOSSummary.PresentationCurrency = AccountingExchangeRateSliceLast.Currency
		|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTablePOSSummary.Currency
		|					FROM
		|						TemporaryTablePOSSummary)) AS CurrencyExchangeRateCashSliceLast
		|		ON TablePOSSummary.Currency = CurrencyExchangeRateCashSliceLast.Currency
		|			AND TablePOSSummary.Company = CurrencyExchangeRateCashSliceLast.Company
		|WHERE
		|	(CAST(ISNULL(TableBalances.AmountCurBalance, 0) * CASE
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
		|					THEN AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition / (CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition)
		|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
		|					THEN CurrencyExchangeRateCashSliceLast.Rate * AccountingExchangeRateSliceLast.Repetition / (AccountingExchangeRateSliceLast.Rate * CurrencyExchangeRateCashSliceLast.Repetition)
		|			END AS NUMBER(15, 2)) - ISNULL(TableBalances.AmountBalance, 0)) <> 0
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.Cost AS Cost,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTablePOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.PresentationCurrency,
		|	DocumentTable.StructuralUnit,
		|	DocumentTable.Currency,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	0,
		|	&ExchangeDifference,
		|	FALSE
		|FROM
		|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	3,
		|	OfflineRecords.LineNumber,
		|	OfflineRecords.RecordType,
		|	OfflineRecords.Period,
		|	OfflineRecords.Company,
		|	OfflineRecords.PresentationCurrency,
		|	OfflineRecords.StructuralUnit,
		|	OfflineRecords.Currency,
		|	OfflineRecords.Amount,
		|	OfflineRecords.AmountCur,
		|	OfflineRecords.Cost,
		|	OfflineRecords.ContentOfAccountingRecord,
		|	OfflineRecords.OfflineRecord
		|FROM
		|	AccumulationRegister.POSSummary AS OfflineRecords
		|WHERE
		|	OfflineRecords.Recorder = &Ref
		|	AND OfflineRecords.OfflineRecord
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TablePOSSummary.Company AS Company,
		|	TablePOSSummary.PresentationCurrency AS PresentationCurrency,
		|	TablePOSSummary.StructuralUnit AS StructuralUnit,
		|	0 AS AmountOfExchangeDifferences,
		|	TablePOSSummary.Currency AS Currency,
		|	TablePOSSummary.GLAccount AS GLAccount
		|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
		|FROM
		|	TemporaryTablePOSSummary AS TablePOSSummary
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.PresentationCurrency AS PresentationCurrency,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.Cost AS Cost,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTablePOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	OfflineRecords.LineNumber,
		|	OfflineRecords.RecordType,
		|	OfflineRecords.Period,
		|	OfflineRecords.Company,
		|	OfflineRecords.PresentationCurrency,
		|	OfflineRecords.StructuralUnit,
		|	OfflineRecords.Currency,
		|	OfflineRecords.Amount,
		|	OfflineRecords.AmountCur,
		|	OfflineRecords.Cost,
		|	OfflineRecords.ContentOfAccountingRecord,
		|	OfflineRecords.OfflineRecord
		|FROM
		|	AccumulationRegister.POSSummary AS OfflineRecords
		|WHERE
		|	OfflineRecords.Recorder = &Ref
		|	AND OfflineRecords.OfflineRecord
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetCalculatedAdvancePaidExchangeRate(Parameters) Export
	
	Ref = Parameters.Ref;
	Company = Parameters.Company;
	Counterparty = Parameters.Counterparty;
	Contract = Parameters.Contract;
	Document = Parameters.Document;
	Order = Parameters.Order;
	Period = Parameters.Period;
	
	ExchangeRateMethod = GetExchangeMethod(Company);
	DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	
	ExchangeRate = 1;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.AmountBalance AS AmountBalance,
	|		AccountsPayableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Document = &Document
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND &TextOrderCondition
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsPayable.Amount
	|			ELSE DocumentRegisterRecordsAccountsPayable.Amount
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsPayable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -DocumentRegisterRecordsAccountsPayable.AmountCur
	|			ELSE DocumentRegisterRecordsAccountsPayable.AmountCur
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsAccountsPayable
	|	WHERE
	|		DocumentRegisterRecordsAccountsPayable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsPayable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsPayable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsPayable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsPayable.Document = &Document
	|		AND DocumentRegisterRecordsAccountsPayable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
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
	|	END AS ExchangeRate
	|FROM
	|	TemporaryTableAccountsPayableBalances AS AccountsPayableBalances";
	
	If DoOperationsByOrders And ValueIsFilled(Order) Then
		Query.Text = StrReplace(Query.Text, "&TextOrderCondition", "Order = &Order");
		Query.SetParameter("Order", Order);
	Else
		Query.Text = StrReplace(Query.Text, "&TextOrderCondition", "TRUE");
	EndIf;
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	Query.SetParameter("Document", Document);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ExchangeRate = QueryResult.Unload()[0].ExchangeRate;
	EndIf;
	
	Return ExchangeRate
	
EndFunction

Function GetCalculatedAdvanceReceivedExchangeRate(Parameters) Export
	
	Ref = Parameters.Ref;
	Company = Parameters.Company;
	Counterparty = Parameters.Counterparty;
	Contract = Parameters.Contract;
	Document = Parameters.Document;
	Order = Parameters.Order;
	Period = Parameters.Period;
	
	ExchangeRateMethod = GetExchangeMethod(Company);
	DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	
	ExchangeRate = 1;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.AmountBalance AS AmountBalance,
	|		AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				&Period,
	|				Company = &Company
	|					AND Document = &Document
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND &TextOrderCondition
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
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
	|		AND DocumentRegisterRecordsAccountsReceivable.Document = &Document
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	CASE
	|		WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|			THEN CASE
	|					WHEN SUM(AccountsReceivableBalances.AmountBalance) <> 0
	|						THEN SUM(AccountsReceivableBalances.AmountCurBalance) / SUM(AccountsReceivableBalances.AmountBalance)
	|					ELSE 1
	|				END
	|		ELSE CASE
	|				WHEN SUM(AccountsReceivableBalances.AmountCurBalance) <> 0
	|					THEN SUM(AccountsReceivableBalances.AmountBalance) / SUM(AccountsReceivableBalances.AmountCurBalance)
	|				ELSE 1
	|			END
	|	END AS ExchangeRate
	|FROM
	|	TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances";
	
	If DoOperationsByOrders And ValueIsFilled(Order) Then
		Query.Text = StrReplace(Query.Text, "&TextOrderCondition", "Order = &Order");
		Query.SetParameter("Order", Order);
	Else
		Query.Text = StrReplace(Query.Text, "&TextOrderCondition", "TRUE");
	EndIf;
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("ExchangeRateMethod", ExchangeRateMethod);
	Query.SetParameter("Document", Document);
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ExchangeRate = QueryResult.Unload()[0].ExchangeRate;
	EndIf;
	
	Return ExchangeRate
	
EndFunction

#EndRegion

#Region SslSubsystemHelperProceduresAndFunctions

// Function clears separated data created during the first start.
// Used before the data import from service.
//
Function ClearDataInDatabase() Export
	
	If Not Users.IsFullUser(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'; ru = 'Недостаточно прав для выполнения операции';pl = 'Nie masz wystarczających uprawnień do wykonania operacji';es_ES = 'Insuficientes derechos para realizar la operación';es_CO = 'Insuficientes derechos para realizar la operación';tr = 'İşlem için gerekli yetkiler yok';it = 'Autorizzazioni insufficienti per eseguire l''operazione';de = 'Unzureichende Rechte auf Ausführen der Operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Try
		Common.LockIB();
	Except
		Message = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Cannot set the exclusive mode (%1)'; ru = 'Не удалось установить монопольный режим (%1)';pl = 'Nie można ustawić trybu wyłączności (%1)';es_ES = 'No se puede establecer el modo exclusivo (%1)';es_CO = 'No se puede establecer el modo exclusivo (%1)';tr = 'Özel mod ayarlanamıyor (%1)';it = 'Non è possibile impostare la modalità esclusiva (%1)';de = 'Kann den exklusiven Modus (%1) nicht einstellen'"),
			BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	BeginTransaction();
	Try
		
		CommonAttributeMD = Metadata.CommonAttributes.DataAreaMainData;
		
		// Traverse all metadata
		
		// Constants
		For Each MetadataConstants In Metadata.Constants Do
			
			ValueManager = Constants[MetadataConstants.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.Value = MetadataConstants.Type.AdjustValue();
			ValueManager.Write();
		EndDo;
		
		// Reference types
		
		ObjectKinds = New Array;
		ObjectKinds.Add("Catalogs");
		ObjectKinds.Add("Documents");
		ObjectKinds.Add("ChartsOfCharacteristicTypes");
		ObjectKinds.Add("ChartsOfAccounts");
		ObjectKinds.Add("ChartsOfCalculationTypes");
		ObjectKinds.Add("BusinessProcesses");
		ObjectKinds.Add("Tasks");
		
		For Each ObjectKind In ObjectKinds Do
			MetadataCollection = Metadata[ObjectKind];
			For Each ObjectMD In MetadataCollection Do
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	_XMLExport_Table.Ref AS Ref
				|FROM
				|	" + ObjectMD.FullName() + " AS _XMLExport_Table";
				If ObjectKind = "Catalogs"
					Or ObjectKind = "ChartsOfCharacteristicTypes"
					Or ObjectKind = "ChartsOfAccounts"
					Or ObjectKind = "ChartsOfCalculationTypes" Then
					
					Query.Text = Query.Text + "
					|WHERE
					|	_XMLExport_Table.Predefined = FALSE";
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					Delete = New ObjectDeletion(Selection.Ref);
					Delete.DataExchange.Load = True;
					Delete.Write();
				EndDo;
			EndDo;
		EndDo;
		
		// Registers in addition to the independent information and sequence registers
		TableKinds = New Array;
		TableKinds.Add("AccumulationRegisters");
		TableKinds.Add("CalculationRegisters");
		TableKinds.Add("AccountingRegisters");
		TableKinds.Add("InformationRegisters");
		TableKinds.Add("Sequences");
		For Each TableKind In TableKinds Do
			MetadataCollection = Metadata[TableKind];
			KindManager = Eval(TableKind);
			For Each RegisterMD In MetadataCollection Do
				
				If TableKind = "InformationRegisters"
					And RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					Continue;
				EndIf;
				
				TypeManager = KindManager[RegisterMD.Name];
				
				Query = New Query;
				Query.Text =
				"SELECT DISTINCT
				|	_XMLExport_Table.Recorder AS Recorder
				|FROM
				|	" + RegisterMD.FullName() + " AS _XMLExport_Table";
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					RecordSet = TypeManager.CreateRecordSet();
					RecordSet.Filter.Recorder.Set(Selection.Recorder);
					RecordSet.DataExchange.Load = True;
					RecordSet.Write();
				EndDo;
			EndDo;
		EndDo;
		
		// Independent information registers
		For Each RegisterMD In Metadata.InformationRegisters Do
			
			If RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
				
				Continue;
			EndIf;
			
			TypeManager = InformationRegisters[RegisterMD.Name];
			
			RecordSet = TypeManager.CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			RecordSet.Write();
		EndDo;
		
		// Exchange plans
		
		For Each ExchangePlanMD In Metadata.ExchangePlans Do
			
			TypeManager = ExchangePlans[ExchangePlanMD.Name];
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + ExchangePlanMD.FullName() + " AS
			|_XMLExport_Table
			|	WHERE _XMLExport_Table.Ref <> &ThisNode";
			Query.SetParameter("ThisNode", TypeManager.ThisNode());
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Delete = New ObjectDeletion(Selection.Ref);
				Delete.DataExchange.Load = True;
				Delete.Write();
			EndDo;
		EndDo;
		
		CommitTransaction();
		
	Except
		RollbackTransaction();
		WriteLogEvent(
			NStr("en = 'Data Deletion'; ru = 'Удаление данных';pl = 'Usuwanie danych';es_ES = 'Eliminación de Datos';es_CO = 'Eliminación de Datos';tr = 'Veri Silinmesi';it = 'Eliminazione dati';de = 'Datenlöschung'",
				CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Try
		Common.UnlockIB();
	Except
		WriteLogEvent(NStr("en = 'Data Deletion'; ru = 'Удаление данных';pl = 'Usuwanie danych';es_ES = 'Eliminación de Datos';es_CO = 'Eliminación de Datos';tr = 'Veri Silinmesi';it = 'Eliminazione dati';de = 'Datenlöschung'", CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#Region ExchangeProceduresWithBanks

// Procedure fills in payment decryption for expense.
//
Procedure FillPaymentDetailsExpense(CurrentObject, ParentCompany = Undefined, DefaultVATRate = Undefined, ExchangeRate = Undefined, Multiplicity = Undefined, Contract = Undefined) Export
	
	If ParentCompany = Undefined Then
		ParentCompany = GetCompany(CurrentObject.Company);
	EndIf;
	
	If ExchangeRate = Undefined
	   And Multiplicity = Undefined Then
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentObject.Date, CurrentObject.CashCurrency, CurrentObject.Company);
		ExchangeRate = ?(
			StructureByCurrency.Rate = 0,
			1,
			StructureByCurrency.Rate
		);
		Multiplicity = ?(
			StructureByCurrency.Rate = 0,
			1,
			StructureByCurrency.Repetition
		);
	EndIf;
	
	If DefaultVATRate = Undefined Then
		If CurrentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(CurrentObject.Date, CurrentObject.Company);
		ElsIf CurrentObject.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	EndIf;
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT ALLOWED
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Document AS Document,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition / (ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition)
	|			END AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	ExchangeRateOfDocument.Rate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Repetition AS CashMultiplicity,
	|	SettlementsExchangeRate.Rate AS ExchangeRate,
	|	SettlementsExchangeRate.Repetition AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Counterparty AS Counterparty,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND &TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Counterparty,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		DocumentRegisterRecordsVendorSettlements.SettlementsType,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Currency = &Currency) AS ExchangeRateOfDocument
	|		ON AccountsPayableBalances.Company = ExchangeRateOfDocument.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, ) AS SettlementsExchangeRate
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|			AND AccountsPayableBalances.Company = SettlementsExchangeRate.Company
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	ExchangeRateOfDocument.Rate,
	|	ExchangeRateOfDocument.Repetition,
	|	SettlementsExchangeRate.Rate,
	|	SettlementsExchangeRate.Repetition,
	|	AccountsPayableBalances.Document,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", CurrentObject.Counterparty);
	Query.SetParameter("Period", CurrentObject.Date);
	Query.SetParameter("Currency", CurrentObject.CashCurrency);
	Query.SetParameter("Ref", CurrentObject.Ref);
	Query.SetParameter("ExchangeRateMethod", GetExchangeMethod(ParentCompany));
	
	If ValueIsFilled(Contract) And TypeOf(Contract) = Type("CatalogRef.CounterpartyContracts") Then
		Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "Contract = &Contract");
		Query.SetParameter("Contract", Contract);
		ContractByDefault = Contract; // if there is no debt, then advance will be assigned to this contract
	Else
		NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(CurrentObject.Ref,
			CurrentObject.OperationKind);
		If NeedFilterByContracts And CurrentObject.Counterparty.DoOperationsByContracts Then
			Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "Contract.ContractKind IN (&ContractTypesList)");
			Query.SetParameter("ContractTypesList", ContractTypesList);
		Else
			Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "TRUE");
		EndIf;
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			CurrentObject.Counterparty,
			CurrentObject.Company,
			ContractTypesList); // if there is no debt, then advance will be assigned to this contract
	EndIf;
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(CurrentObject.Date, ContractByDefault.SettlementsCurrency, CurrentObject.Company);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	CurrentObject.PaymentDetails.Clear();
	
	AmountLeftToDistribute = CurrentObject.DocumentAmount;
	
	ExchangeRateMethod = GetExchangeMethod(ParentCompany);
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = CurrentObject.PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurrDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.Rate = 0,
				1,
				StructureContractCurrencyRateByDefault.Rate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Repetition = 0,
				1,
				StructureContractCurrencyRateByDefault.Repetition
			);
			NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRateMethod,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If CurrentObject.PaymentDetails.Count() = 0 Then
		CurrentObject.PaymentDetails.Add();
		CurrentObject.PaymentDetails[0].PaymentAmount = CurrentObject.DocumentAmount;
	EndIf;
	
	PaymentAmount = CurrentObject.PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure fills in payment decryption for receipt.
//
Procedure FillPaymentDetailsReceipt(CurrentObject, ParentCompany = Undefined, DefaultVATRate = Undefined, ExchangeRate = Undefined, Multiplicity = Undefined, Contract = Undefined) Export
	
	If ParentCompany = Undefined Then
		ParentCompany = GetCompany(CurrentObject.Company);
	EndIf;
	
	If ExchangeRate = Undefined
	   And Multiplicity = Undefined Then
		StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(CurrentObject.Date, CurrentObject.CashCurrency, CurrentObject.Company);
		ExchangeRate = ?(
			StructureByCurrency.Rate = 0,
			1,
			StructureByCurrency.Rate
		);
		Multiplicity = ?(
			StructureByCurrency.Rate = 0,
			1,
			StructureByCurrency.Repetition
		);
	EndIf;
	
	If DefaultVATRate = Undefined Then
		If CurrentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(CurrentObject.Date, CurrentObject.Company);
		ElsIf CurrentObject.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	EndIf;
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsReceivableBalances.AmountCurBalance * CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition / (SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN SettlementsExchangeRate.Rate * ExchangeRateOfDocument.Repetition / (ExchangeRateOfDocument.Rate * SettlementsExchangeRate.Repetition)
	|			END AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	ExchangeRateOfDocument.Rate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Repetition AS CashMultiplicity,
	|	SettlementsExchangeRate.Rate AS ExchangeRate,
	|	SettlementsExchangeRate.Repetition AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Company AS Company,
	|		AccountsReceivableBalances.Counterparty AS Counterparty,
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND &TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Company,
	|		DocumentRegisterRecordsAccountsReceivable.Counterparty,
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		DocumentRegisterRecordsAccountsReceivable.SettlementsType,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, Currency = &Currency) AS ExchangeRateOfDocument
	|		ON AccountsReceivableBalances.Company = ExchangeRateOfDocument.Company
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Period, ) AS SettlementsExchangeRate
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|			AND AccountsReceivableBalances.Company = SettlementsExchangeRate.Company
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsReceivableBalances.Company,
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.Document.Date,
	|	ExchangeRateOfDocument.Rate,
	|	ExchangeRateOfDocument.Repetition,
	|	SettlementsExchangeRate.Rate,
	|	SettlementsExchangeRate.Repetition,
	|	AccountsReceivableBalances.Document,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", CurrentObject.Counterparty);
	Query.SetParameter("Period", CurrentObject.Date);
	Query.SetParameter("Currency", CurrentObject.CashCurrency);
	Query.SetParameter("Ref", CurrentObject.Ref);
	Query.SetParameter("ExchangeRateMethod", GetExchangeMethod(ParentCompany));
	
	If ValueIsFilled(Contract) And TypeOf(Contract) = Type("CatalogRef.CounterpartyContracts") Then
		Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "Contract = &Contract");
		Query.SetParameter("Contract", Contract);
		ContractByDefault = Contract;
	Else
		NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(CurrentObject.Ref,
			CurrentObject.OperationKind);
		If NeedFilterByContracts And CurrentObject.Counterparty.DoOperationsByContracts Then
			Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "Contract.ContractKind IN (&ContractTypesList)");
			Query.SetParameter("ContractTypesList", ContractTypesList);
		Else
			Query.Text = StrReplace(Query.Text, "&TextOfContractSelection", "TRUE");
		EndIf;
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			CurrentObject.Counterparty,
			CurrentObject.Company,
			ContractTypesList); // if there is no debt, then advance will be assigned to this contract
	EndIf;
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(CurrentObject.Date, ContractByDefault.SettlementsCurrency, CurrentObject.Company);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	CurrentObject.PaymentDetails.Clear();
	
	AmountLeftToDistribute = CurrentObject.DocumentAmount;
	
	ExchangeRateMethod = GetExchangeMethod(ParentCompany);
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = CurrentObject.PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurrDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.Rate = 0,
				1,
				StructureContractCurrencyRateByDefault.Rate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Repetition = 0,
				1,
				StructureContractCurrencyRateByDefault.Repetition
			);
			NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRateMethod,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If CurrentObject.PaymentDetails.Count() = 0 Then
		CurrentObject.PaymentDetails.Add();
		CurrentObject.PaymentDetails[0].PaymentAmount = CurrentObject.DocumentAmount;
	EndIf;
	
	PaymentAmount = CurrentObject.PaymentDetails.Total("PaymentAmount");
	
EndProcedure

#EndRegion

#Region BusinessCalendarsProceduresAndFunctions

// Function returns Calendars catalog item If item is not found, Undefined is returned.
// 
Function GetFiveDaysCalendar() Export
	
	UpdateBusinessCalendars();
	
	BusinessCalendar = Catalogs.BusinessCalendars.FindByCode("5D");
	If BusinessCalendar = Undefined Then
		
		WriteLogEvent(
			NStr("en = 'Cannot fill in data for company work schedule.'; ru = 'Не удалось заполнить данные графиков работы для организации.';pl = 'Nie można wypełnić danych harmonogramu pracy dla firmy.';es_ES = 'No se puede rellenar los datos para el horario de trabajo de la empresa.';es_CO = 'No se puede rellenar los datos para el horario de trabajo de la empresa.';tr = 'İş yeri çalışma programı için veriler doldurulamadı.';it = 'Impossibile compilare i dati per il grafico di lavoro dell''azienda.';de = 'Die Daten für den Firmenarbeitszeitplan können nicht ausgefüllt werden.'",
				CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
		Return Undefined;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	Calendars.Ref AS Calendar
	|FROM
	|	Catalog.Calendars AS Calendars
	|WHERE
	|	Calendars.BusinessCalendar = &BusinessCalendar");
	
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	SelectionOfQueryResult = Query.Execute().Select();
	
	// Deliberately cancel recursion in case there is no work schedule
	Return ?(SelectionOfQueryResult.Next(),
					SelectionOfQueryResult.Calendar,
					Undefined);
	
EndFunction

Procedure UpdateBusinessCalendars() Export
	
	TextDocument = Catalogs.BusinessCalendars.GetTemplate("CalendarsDescription");
	TableCalendars = Common.ReadXMLToTable(TextDocument.GetText()).Data;
	
	Catalogs.BusinessCalendars.UpdateBusinessCalendars(TableCalendars);
	
EndProcedure

// Old. Saved to support compatibility.
// Function reads calendar data from register
//
// Parameters
// Calendar		- Refs to the
// current catalog item YearNumber		- Year number for which it is required to read the calendar
//
// Return
// value Array		- array in which dates included in the calendar are stored
//
Function ReadScheduleDataFromRegister(Calendar, YearNumber) Export
	
	Query = New Query;
	Query.SetParameter("Calendar",	Calendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &Calendar
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayAddedToSchedule";
	
	Return Query.Execute().Unload().UnloadColumn("CalendarDate");
	
EndFunction

#EndRegion

#Region BusinessPulse

Function ChartSeriesColors() Export
	
	ColorsArray = New Array;
	
	ColorsArray.Add(StyleColors.PriceKindColorPink);
	ColorsArray.Add(StyleColors.PriceKindColorLightSkyBlue);
	ColorsArray.Add(StyleColors.PriceKindColorLightGreen);
	ColorsArray.Add(StyleColors.PriceKindColorDarkOrchid);
	ColorsArray.Add(StyleColors.PriceKindColorLimeGreen);
	ColorsArray.Add(StyleColors.PriceKindColorHotPink);
	ColorsArray.Add(StyleColors.PriceKindColorDarkTurquoise);
	ColorsArray.Add(StyleColors.PriceKindColorLightGoldenRod);
	ColorsArray.Add(StyleColors.PriceKindColorViolet);
	ColorsArray.Add(StyleColors.PriceKindColorMediumTurquoise);
	
	Return ColorsArray;
	
EndFunction

Function ChartSeriesWithoutDataColors() Export
	
	ColorsArray = New Array;
	
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorPink);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorLightSkyBlue);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorLightGreen);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorDarkOrchid);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorLimeGreen);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorHotPink);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorDarkTurquoise);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorLightGoldenRod);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorViolet);
	ColorsArray.Add(StyleColors.PriceKindWithoutDataColorMediumTurquoise);
	
	Return ColorsArray;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsOfCounterpartiesContactInformationPrinting

// The function returns a request result by contact info kinds that can be used for printing.
//
Function GetAvailableForPrintingCIKinds() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	ContactInformationTypes.Ref AS CIKind,
		|	ContactInformationTypes.Description AS Description,
		|	ContactInformationTypes.ObsoleteTooltip AS ToolTip,
		|	1 AS CIOwnerIndex,
		|	ContactInformationTypes.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogCounterparties
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ContactInformationTypes.Ref,
		|	ContactInformationTypes.Description,
		|	ContactInformationTypes.ObsoleteTooltip,
		|	2,
		|	ContactInformationTypes.AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogContactPersons
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ContactInformationTypes.Ref,
		|	ContactInformationTypes.Description,
		|	ContactInformationTypes.ObsoleteTooltip,
		|	3,
		|	ContactInformationTypes.AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationKinds AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogIndividuals
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|	AND ContactInformationTypes.Type = &TypePhone
		|
		|ORDER BY
		|	CIOwnerIndex,
		|	AdditionalOrderingAttribute";
	
	Query.SetParameter("CICatalogCounterparties", Catalogs.ContactInformationKinds.CatalogCounterparties);	
	Query.SetParameter("CICatalogContactPersons", Catalogs.ContactInformationKinds.CatalogContactPersons);	
	Query.SetParameter("CICatalogIndividuals", Catalogs.ContactInformationKinds.CatalogIndividuals);	
	Query.SetParameter("TypePhone", Enums.ContactInformationTypes.Phone);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	Return QueryResult;
	
EndFunction

// The function sets an initial value of the contact information kind use.
//
// Parameters:
//  CIKind	 - Catalog.ContactInformationKinds	 - Check contact
// information kind Return value:
//  Boolean - Contact information kind is printed by default
Function SetPrintDefaultCIKind(CIKind) Export
	
	If CIKind = Catalogs.ContactInformationKinds.CounterpartyPostalAddress 
		Or CIKind = Catalogs.ContactInformationKinds.CounterpartyFax
		Or CIKind = Catalogs.ContactInformationKinds.CounterpartyOtherInformation
		Then
			Return False;
	EndIf;
	
	Return CIKind.Predefined;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsOfCatalogProducts

Procedure ExecuteCloneProductWithRelatedData(JobParameters, StorageAddress = "") Export
	
	JobResult = JobResult();
	JobResult.Insert("Product", Undefined);
		
	Try
		JobResult.Product = CloneProductWithRelatedData(JobParameters);
	Except
		JobResult.Done = False;
		JobResult.ErrorMessage = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	PutToTempStorage(JobResult, StorageAddress);
	
EndProcedure

Function JobResult()
	Return New Structure("Done, ErrorMessage, ProductIsCloned", True, "", False);
EndFunction

Function CloneProductWithRelatedData(JobParameters)
	
	ProductReceiver					= JobParameters.ProductSource.Copy();
	ProductReceiver.SKU				= "";
	ProductReceiver.Description		= StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'Copy %1'; ru = 'Копировать %1';pl = 'Kopiowanie %1';es_ES = 'Copia %1';es_CO = 'Copia %1';tr = 'Kopyala %1';it = 'Copia %1';de = 'Kopie %1'"), ProductReceiver.Description);
	ProductReceiver.DescriptionFull	= ProductReceiver.Description;
	ProductReceiver.Write();
	
	ProductReceiverRef = ProductReceiver.Ref;
	
	TableRelatedData = JobParameters.TableRelatedData;
	FillProductVariants = False;
	
	For Each StringRelatedData In TableRelatedData Do
		
		If Not StringRelatedData.Check Then
			Continue;
		EndIf;
		
		If StringRelatedData.NameHandler	= "ProductVariants" Then
			
			Catalogs.ProductsCharacteristics.MakeRelatedProductVariants(ProductReceiverRef, JobParameters.ProductSource);
			FillProductVariants = True;
			
		ElsIf StringRelatedData.NameHandler	= "BillsOfMaterials" Then
			
			Catalogs.BillsOfMaterials.MakeRelatedBillsOfMaterials(ProductReceiverRef, JobParameters.ProductSource);
			
		ElsIf StringRelatedData.NameHandler	= "AdditionalUOMs" Then
			
			Catalogs.UOM.MakeRelatedAdditionalUOM(ProductReceiverRef, JobParameters.ProductSource);
			
		ElsIf StringRelatedData.NameHandler	= "ProductCrossReferences" Then
			
			Catalogs.SuppliersProducts.MakeRelatedProductCrossreferences(ProductReceiverRef, JobParameters.ProductSource);
			
		ElsIf StringRelatedData.NameHandler	= "ProductGLAccounts" Then
			
			InformationRegisters.ProductGLAccounts.MakeRelatedProductGLAccounts(ProductReceiverRef, JobParameters.ProductSource);
			
		ElsIf StringRelatedData.NameHandler	= "ReorderPointSettings" Then
			
			InformationRegisters.ReorderPointSettings.MakeRelatedReorderPointSettings(ProductReceiverRef, JobParameters.ProductSource, FillProductVariants);
			
		ElsIf StringRelatedData.NameHandler	= "StandardTime" Then
			
			InformationRegisters.StandardTime.MakeRelatedStandardTime(ProductReceiverRef, JobParameters.ProductSource, FillProductVariants);
			
		ElsIf StringRelatedData.NameHandler	= "SubstituteGoods" Then
			
			InformationRegisters.SubstituteGoods.MakeRelatedSubstituteGoods(ProductReceiverRef, JobParameters.ProductSource);
			
		Else
			
			Message = New UserMessage;
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(NStr("en = 'No handler for related data ""%1""'; ru = 'Для связанных данных ""%1"" не указан обработчик';pl = 'Brak osoby zajmującej się danymi powiązanymi ""%1""';es_ES = 'Sin manipulador de datos relacionados ""%1""';es_CO = 'Sin manipulador de datos relacionados ""%1""';tr = 'İlgili ""%1"" verisi için işleyici yok';it = 'Nessun gestore per i dati correlati ""%1""';de = 'Kein Händler für relevanten Daten ""%1""'"),StringRelatedData.RelatedData);
			Message.Message();
			
		EndIf;
		
	EndDo;
	
	Return ProductReceiver.Ref;
	
EndFunction

#EndRegion

#Region ManagerMonitorProceduresAndFunctions

// Function creates report settings linker and overrides specified parameters and filters.
//
// Parameters:
//  ReportProperties			 - Structure	 - keys: "ReportName" - report name as specified in the configurator, "VariantKeys" (optional) - ParametersAndFilters
//  report option name	 - Array - structures array for specifying changing parameters and filters. Structure keys:
// 								"FieldName" (mandatory) - parameter name or data layout field by which
// 								the filter is set, "RightValue" (mandatory) - selected value of
// 								parameter or filter , "SettingKind" (optional) - defines a container for placing parameter or filter, options:
// 								"Settings" "FixedSettings", other structure keys are optional and they specify the filter item properties.
// Returns:
//  DataCompositionSettingsComposer - linker of settings with changed parameters and filters.
Function GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections) Export
	Var ReportName, VariantKey;
	
	ReportProperties.Property("ReportName", ReportName);
	ReportProperties.Property("VariantKey", VariantKey);
	
	DataCompositionSchema = Reports[ReportName].GetTemplate("MainDataCompositionSchema");
	
	If VariantKey <> Undefined And Not IsBlankString(VariantKey) Then
		DesiredReportOption = DataCompositionSchema.SettingVariants.Find(VariantKey);
		If DesiredReportOption <> Undefined Then
			Settings = DesiredReportOption.Settings;
		EndIf;
	EndIf;
	
	If Settings = Undefined Then
		Settings = DataCompositionSchema.DefaultSettings;
	EndIf;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	DataCompositionSettingsComposer.LoadSettings(Settings);
	
	For Each ParameterFilter In ParametersAndSelections Do
		
		If ParameterFilter.Property("SettingKind") Then
			If ParameterFilter.SettingKind = "Settings" Then
				Container = DataCompositionSettingsComposer.Settings;
			ElsIf ParameterFilter.SettingKind = "FixedSettings" Then
				Container = DataCompositionSettingsComposer.FixedSettings;
			EndIf;
		Else
			Container = DataCompositionSettingsComposer.Settings;
		EndIf;
		
		FoundParameter = Container.DataParameters.FindParameterValue(New DataCompositionParameter(ParameterFilter.FieldName));
		If FoundParameter <> Undefined Then
			Container.DataParameters.SetParameterValue(FoundParameter.Parameter, ParameterFilter.RightValue);
		EndIf;
		
		FoundFilters = CommonClientServer.FindFilterItemsAndGroups(Container.Filter, ParameterFilter.FieldName);
		For Each FoundFilter In FoundFilters Do
			
			If TypeOf(FoundFilter) <> Type("DataCompositionFilterItem") Then
				Continue;
			EndIf;
			
			FillPropertyValues(FoundFilter, ParameterFilter);
			
			If Not ParameterFilter.Property("ComparisonType") Then
				FoundFilter.ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
			If Not ParameterFilter.Property("Use") Then
				FoundFilter.Use = True;
			EndIf;
			If Not ParameterFilter.Property("ViewMode") Then
				FoundFilter.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
			EndIf;
			
		EndDo;
		
		If FoundFilters.Count() = 0 And FoundParameter = Undefined Then
			AddedItem = CommonClientServer.AddCompositionItem(Container.Filter, ParameterFilter.FieldName, DataCompositionComparisonType.Equal);
			FillPropertyValues(AddedItem, ParameterFilter);
		EndIf;
		
	EndDo;
	
	Return DataCompositionSettingsComposer;
	
EndFunction

// Function returns colors used for monitors.
//
// Parameters:
//  ColorName - String - Color name
Function ColorForMonitors(ColorName) Export
	
	Color = New Color();
	
	If ColorName = "Green" Then
		Color = StyleColors.ColorForMonitorsGreen;
	ElsIf ColorName = "Dark-green" Then
		Color = StyleColors.ColorForMonitorsDarkGreen;
	ElsIf ColorName = "Yellow" Then
		Color = StyleColors.ColorForMonitorsYellow;
	ElsIf ColorName = "Orange" Then
		Color = StyleColors.ColorForMonitorsOrange;
	ElsIf ColorName = "Coral" Then
		Color = StyleColors.ColorForMonitorsCoral;
	ElsIf ColorName = "Red" Then
		Color = StyleColors.ColorForMonitorsRed;
	ElsIf ColorName = "Magenta" Then
		Color = StyleColors.ColorForMonitorsMagenta;
	ElsIf ColorName = "Blue" Then
		Color = StyleColors.ColorForMonitorsDeepSkyBlue;
	ElsIf ColorName = "Light-gray" Then
		Color = StyleColors.ColorForMonitorsGainsboro;
	ElsIf ColorName = "Gray" Then
		Color = StyleColors.ColorForMonitorsGray;
	EndIf;
	
	Return Color;
	
EndFunction

// Function returns the resulting formatted string.
//
// Parameters:
//  RowItems - Structures array with the "Row" key
//    and the output row value, the other keys match the formatted row designer parameters
//
Function BuildFormattedString(RowItems) Export
	
	String = "";
	Font = Undefined;
	TextColor = Undefined;
	BackColor = Undefined;
	FormattedStringsArray = New Array;
	
	For Each Item In RowItems Do
		Item.Property("String", String);
		Item.Property("Font", Font);
		Item.Property("TextColor", TextColor);
		Item.Property("BackColor", BackColor);
		FormattedStringsArray.Add(New FormattedString(String, Font, TextColor, BackColor)); 
	EndDo;
	
	Return New FormattedString(FormattedStringsArray);
	
EndFunction

// The function creates a title as a formatted string for item widget headers.
//
// Parameters:
//  SourceAmount - Number - value from which
// title is generated Return value:
//  FormattedString - Title string
Function GenerateTitle(val SourceAmount) Export
	
	FormattedAmount = Format(SourceAmount, "NFD=2; NGS=' '; NZ=—; NG=3,0");
	Delimiter = Find(FormattedAmount, ",");
	RowPositionThousands = Left(FormattedAmount, Delimiter-4);
	RowDigitUnits = Mid(FormattedAmount, Delimiter-3);
	
	RowItems = New Array;
	RowItems.Add(New Structure("String, Font", RowPositionThousands, New Font(StyleFonts.ExtraLargeTextFont)));
	RowItems.Add(New Structure("String, Font", RowDigitUnits, New Font(StyleFonts.NormalTextFont)));
	
	Return BuildFormattedString(RowItems);
	
EndFunction

#EndRegion

#Region WorkWithObjectQuerySchema

// Function - Find the field of query schema available table
//
// Parameters:
//  AvailableTable - AvailableTableQuerySchema	 - table where search
//  FieldName is executed			 - String - search field
//  name FieldType			 - Type - possible values "QuerySchemaAvailableField", "QuerySchemaAvailableInsertedTable".
//  					If parameter is specified, then search is executed only by
// fields of the specified Return value type:
//  QuerySchemaAvailableField,QuerySchemaAvailableNestedTable - found field
Function FindAvailableTableQuerySchemaField(AvailableTable, FieldName, FieldType = Undefined) Export
	
	Result = Undefined;
	
	For Each Field In AvailableTable.Fields Do
		If Field.Name = FieldName And (FieldType = Undefined Or (TypeOf(Field) = FieldType)) Then
			Result = Field;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Function - Find query schema source
//
// Parameters:
//  Sources		 - SourcesQuerySchema 	 - sources where TableAlias
//  search is executed. - String	 - TableType
//  desired table alias		 - Type - possible values "QuerySchemaTable", "QuerySchemaInsertedQuery", "TemporaryQuerySchemaTableDescription".
//  					If the parameter is defined, then search is performed only
// by the sources of the specified type Return value:
//  QuerySchemaSource - source is found
Function FindQuerySchemaSource(Sources, TablePseudonym, TableType = Undefined) Export
	
	Result = Undefined;
	
	For Each Source In Sources Do
		If Source.Source.Alias = TablePseudonym And (TableType = Undefined Or (TypeOf(Source.Source) = TableType)) Then
			Result = Source;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetFunctionalOptionValue(Name) Export
	
	Return GetFunctionalOption(Name);
	
EndFunction

#Region GenerateCommands

Procedure OverrideStandartGenerateGoodsIssueCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.GoodsIssue) Then
		Return;
	EndIf;
	
	GenerateGoodsIssueCommand = Form.Commands.Add("GenerateGoodsIssue");
	GenerateGoodsIssueCommand.Action	= "Attachable_GenerateGoodsIssue";
	GenerateGoodsIssueCommand.Title		= NStr("en = 'Goods issue'; ru = 'Отпуск товаров';pl = 'Wydanie zewnętrzne';es_ES = 'Salida de mercancías';es_CO = 'Salida de productos';tr = 'Ambar çıkışı';it = 'Spedizione merce/DDT';de = 'Warenausgang'");
	
	StandartGenerateGoodsIssueButton = Form.Items.FormDocumentGoodsIssueCreateBasedOn;
	StandartGenerateGoodsIssueButton.Visible = False;
	OverridenGenerateGoodsIssueButton = Form.Items.Insert("FormCreateBasedOnGenerateGoodsIssue",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateGoodsIssueButton);
	OverridenGenerateGoodsIssueButton.CommandName = "GenerateGoodsIssue";
	
EndProcedure

Procedure OverrideStandartGenerateGoodsIssueReturnCommand(Form, Visible = True) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.GoodsIssue) Then
		Return;
	EndIf;
	
	GenerateGoodsIssueCommand = Form.Commands.Add("GenerateGoodsIssueReturn");
	GenerateGoodsIssueCommand.Action	= "Attachable_GenerateGoodsIssueReturn";
	GenerateGoodsIssueCommand.Title		= NStr("en = 'Goods issue (Purchase return)'; ru = 'Отпуск товаров (возврат)';pl = 'Wydanie zewnętrzne (Zwrot zakupu)';es_ES = 'Salida de mercancías (Devolución de la compra)';es_CO = 'Salida de mercancías (Devolución de la compra)';tr = 'Ambar çıkışı (Satın alma iadesi)';it = 'Spedizione merce (Restituzione acquisto)';de = 'Warenausgang (Retoure)'");
	
	StandartGenerateGoodsIssueButton = Form.Items.FormDocumentGoodsIssueCreateBasedOn;
	StandartGenerateGoodsIssueButton.Visible = False;
	OverridenGenerateGoodsIssueButton = Form.Items.Insert("FormCreateBasedOnGenerateGoodsIssueReturn",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateGoodsIssueButton);
	OverridenGenerateGoodsIssueButton.CommandName = "GenerateGoodsIssueReturn";
	OverridenGenerateGoodsIssueButton.Visible = Visible;
	
EndProcedure

Procedure OverrideStandartGenerateInventoryTransferCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.InventoryTransfer) Then
		Return;
	EndIf;
	
	GenerateInventoryTransferCommand = Form.Commands.Add("GenerateInventoryTransfer");
	GenerateInventoryTransferCommand.Action	= "Attachable_GenerateInventoryTransfer";
	GenerateInventoryTransferCommand.Title		= NStr("en = 'Inventory transfer'; ru = 'Перемещение запасов';pl = 'Przesunięcie międzymagazynowe';es_ES = 'Traslado del inventario';es_CO = 'Transferencia de inventario';tr = 'Stok transferi';it = 'Movimenti di scorte';de = 'Bestandsumlagerung'");
	
	StandartGenerateInventoryTransferButton = Form.Items.FormDocumentInventoryTransferCreateBasedOn;
	StandartGenerateInventoryTransferButton.Visible = False;
	OverridenGenerateInventoryTransferButton = Form.Items.Insert("FormCreateBasedOnGenerateInventoryTransfer",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateInventoryTransferButton);
	OverridenGenerateInventoryTransferButton.CommandName = "GenerateInventoryTransfer";
	
EndProcedure

Procedure OverrideStandartGenerateGoodsReceiptCommand(Form, Visible = True) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.GoodsReceipt) Then
		Return;
	EndIf;
	
	GenerateGoodsReceiptCommand = Form.Commands.Add("GenerateGoodsReceipt");
	GenerateGoodsReceiptCommand.Action	= "Attachable_GenerateGoodsReceipt";
	GenerateGoodsReceiptCommand.Title	= NStr("en = 'Goods receipt'; ru = 'Поступление товаров';pl = 'Przyjęcie zewnętrzne';es_ES = 'Recibo de mercancías';es_CO = 'Recibo de mercancías';tr = 'Ambar girişi';it = 'Ricezione merce';de = 'Wareneingang'");
	
	StandartGenerateGoodsReceiptButton = Form.Items.FormDocumentGoodsReceiptCreateBasedOn;
	StandartGenerateGoodsReceiptButton.Visible = False;
	OverridenGenerateGoodsReceiptButton = Form.Items.Insert("FormCreateBasedOnGenerateGoodsReceipt",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateGoodsReceiptButton);
	OverridenGenerateGoodsReceiptButton.CommandName = "GenerateGoodsReceipt";
	OverridenGenerateGoodsReceiptButton.Visible = Visible;
	
EndProcedure

Procedure OverrideStandartGenerateSalesInvoiceCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.SalesInvoice) Then
		Return;
	EndIf;
	
	GenerateSalesInvoiceCommand = Form.Commands.Add("GenerateSalesInvoice");
	GenerateSalesInvoiceCommand.Action = "Attachable_GenerateSalesInvoice";
	GenerateSalesInvoiceCommand.Title = NStr("en = 'Sales invoice'; ru = 'Инвойс покупателю';pl = 'Faktura sprzedaży';es_ES = 'Factura de ventas';es_CO = 'Factura de ventas';tr = 'Satış faturası';it = 'Fattura di vendita';de = 'Verkaufsrechnung'");
	
	StandartGenerateSalesInvoiceButton = Form.Items.FormDocumentSalesInvoiceCreateBasedOn;
	StandartGenerateSalesInvoiceButton.Visible = False;
	OverridenGenerateSalesInvoiceButton = Form.Items.Insert("FormCreateBasedOnGenerateSalesInvoice",
		Type("FormButton"),
		Form.Items.FormCreateBasedOn,
		StandartGenerateSalesInvoiceButton);
	OverridenGenerateSalesInvoiceButton.CommandName = "GenerateSalesInvoice";
	
EndProcedure

Procedure OverrideStandartGenerateJobCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.BusinessProcesses.Job) Then
		Return;
	EndIf;
	
	GenerateJobCommand = Form.Commands.Add("GenerateJob");
	GenerateJobCommand.Action = "Attachable_GenerateJob";
	GenerateJobCommand.Title = NStr("en = 'Job'; ru = 'Задание';pl = 'Zadanie';es_ES = 'Tarea';es_CO = 'Tarea';tr = 'İş';it = 'Processo';de = 'Arbeit'");
	
	StandartGenerateJobButton = Form.Items.FormBusinessProcessJobCreateBasedOn;
	StandartGenerateJobButton.Visible = False;
	OverridenGenerateJobButton = Form.Items.Insert("FormCreateBasedOnGenerateJob",
														Type("FormButton"),
														Form.Items.FormCreateBasedOn,
														StandartGenerateJobButton);
	OverridenGenerateJobButton.CommandName = "GenerateJob";
	
EndProcedure

Procedure OverrideStandartGenerateSupplierInvoiceCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.SupplierInvoice) Then
		Return;
	EndIf;
	
	GenerateSupplierInvoiceCommand = Form.Commands.Add("GenerateSupplierInvoice");
	GenerateSupplierInvoiceCommand.Action = "Attachable_GenerateSupplierInvoice";
	GenerateSupplierInvoiceCommand.Title = NStr("en = 'Supplier invoice'; ru = 'Инвойс поставщика';pl = 'Faktura zakupu';es_ES = 'Factura de proveedor';es_CO = 'Factura de proveedor';tr = 'Satın alma faturası';it = 'Fattura del fornitore';de = 'Lieferantenrechnung'");
	
	StandartGenerateSupplierInvoiceButton = Form.Items.FormDocumentSupplierInvoiceCreateBasedOn;
	StandartGenerateSupplierInvoiceButton.Visible = False;
	OverridenGenerateSupplierInvoiceButton = Form.Items.Insert("FormCreateBasedOnGenerateSupplierInvoice",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateSupplierInvoiceButton);
	OverridenGenerateSupplierInvoiceButton.CommandName = "GenerateSupplierInvoice";
	
EndProcedure

Procedure OverrideStandartGenerateCustomsDeclarationCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.CustomsDeclaration) Then
		Return;
	EndIf;
	
	GenerateCustomsDeclarationCommand = Form.Commands.Add("GenerateCustomsDeclaration");
	GenerateCustomsDeclarationCommand.Action = "Attachable_GenerateCustomsDeclaration";
	GenerateCustomsDeclarationCommand.Title = NStr("en = 'Customs declaration'; ru = 'Таможенная декларация';pl = 'Deklaracja celna';es_ES = 'Declaración de la aduana';es_CO = 'Declaración de la aduana';tr = 'Gümrük beyannamesi';it = 'Dichiarazione doganale';de = 'Zollanmeldung'");
	
	StandartGenerateCustomsDeclarationButton = Form.Items.FormDocumentCustomsDeclarationCreateBasedOn;
	StandartGenerateCustomsDeclarationButton.Visible = False;
	OverridenGenerateCustomsDeclarationButton = Form.Items.Insert("FormCreateBasedOnGenerateCustomsDeclaration",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateCustomsDeclarationButton);
	OverridenGenerateCustomsDeclarationButton.CommandName = "GenerateCustomsDeclaration";
	
EndProcedure

Procedure OverrideStandartGeneratePackingSlipCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.PackingSlip) Then
		Return;
	EndIf;
	
	GeneratePackingSlipCommand = Form.Commands.Add("GeneratePackingSlip");
	GeneratePackingSlipCommand.Action	= "Attachable_GeneratePackingSlip";
	GeneratePackingSlipCommand.Title	= NStr("en = 'Packing slip'; ru = 'Упаковочный лист';pl = 'List przewozowy';es_ES = 'Albarán de entrega';es_CO = 'Albarán de entrega';tr = 'Sevk irsaliyesi';it = 'Packing list';de = 'Packzettel'");
	
	StandartGeneratePackingSlipButton = Form.Items.FormDocumentPackingSlipCreateBasedOn;
	StandartGeneratePackingSlipButton.Visible = False;
	OverridenGeneratePackingSlipButton = Form.Items.Insert("FormCreateBasedOnGeneratePackingSlip",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGeneratePackingSlipButton);
	OverridenGeneratePackingSlipButton.CommandName = "GeneratePackingSlip";
	
EndProcedure

Procedure OverrideStandartGenerateCreditNoteCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.CreditNote) Then
		Return;
	EndIf;
	
	GenerateCreditNoteCommand = Form.Commands.Add("GenerateCreditNote");
	GenerateCreditNoteCommand.Action = "Attachable_GenerateCreditNote";
	GenerateCreditNoteCommand.Title = NStr("en = 'Credit note'; ru = 'Кредитовое авизо';pl = 'Nota kredytowa';es_ES = 'Nota de crédito';es_CO = 'Nota Credito';tr = 'Alacak dekontu';it = 'Nota di credito';de = 'Gutschrift'");
	
	StandartGenerateCreditNoteButton = Form.Items.FormDocumentCreditNoteCreateBasedOn;
	StandartGenerateCreditNoteButton.Visible = False;
	OverridenGenerateCreditNoteButton = Form.Items.Insert("FormCreateBasedOnGenerateCreditNote",
										Type("FormButton"),
										Form.Items.FormCreateBasedOn,
										StandartGenerateCreditNoteButton);
	OverridenGenerateCreditNoteButton.CommandName = "GenerateCreditNote";
	
EndProcedure

Procedure OverrideStandartGenerateDebitNoteCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.DebitNote) Then
		Return;
	EndIf;
	
	GenerateDebitNoteCommand = Form.Commands.Add("GenerateDebitNote");
	GenerateDebitNoteCommand.Action = "Attachable_GenerateDebitNote";
	GenerateDebitNoteCommand.Title = NStr("en = 'Debit note'; ru = 'Дебетовое авизо';pl = 'Nota debetowa';es_ES = 'Nota de débito';es_CO = 'Nota de débito';tr = 'Borç dekontu';it = 'Nota di debito';de = 'Lastschrift'");
	
	StandartGenerateDebitNoteButton = Form.Items.FormDocumentDebitNoteCreateBasedOn;
	StandartGenerateDebitNoteButton.Visible = False;
	OverridenGenerateDebitNoteButton = Form.Items.Insert("FormCreateBasedOnGenerateDebitNote",
										Type("FormButton"),
										Form.Items.FormCreateBasedOn,
										StandartGenerateDebitNoteButton);
	OverridenGenerateDebitNoteButton.CommandName = "GenerateDebitNote";
	
EndProcedure

Procedure OverrideStandartGenerateTaxInvoiceReceivedCommand(Form) Export
	
	If Not AccessRight("InteractiveInsert", Metadata.Documents.TaxInvoiceReceived) Then
		Return;
	EndIf;
	
	GenerateTaxInvoiceReceivedCommand = Form.Commands.Add("GenerateTaxInvoiceReceived");
	GenerateTaxInvoiceReceivedCommand.Action	= "Attachable_GenerateTaxInvoiceReceived";
	GenerateTaxInvoiceReceivedCommand.Title		= NStr("en = 'Tax invoice received'; ru = 'Налоговый инвойс полученный';pl = 'Otrzymana faktura VAT';es_ES = 'Factura de impuestos recibida';es_CO = 'Factura fiscal recibida';tr = 'Alınan vergi faturası';it = 'Fattura fiscale ricevuta';de = 'Steuerrechnung erhalten'");
	
	StandartGenerateTaxInvoiceReceivedButton = Form.Items.FormDocumentTaxInvoiceReceivedCreateBasedOn;
	StandartGenerateTaxInvoiceReceivedButton.Visible = False;
	
	OverridenGenerateTaxInvoiceReceivedButton = Form.Items.Insert("FormCreateBasedOnGenerateTaxInvoiceReceived",
		Type("FormButton"),
		Form.Items.FormCreateBasedOn,
		StandartGenerateTaxInvoiceReceivedButton);
	OverridenGenerateTaxInvoiceReceivedButton.CommandName = "GenerateTaxInvoiceReceived";
	
EndProcedure

Function CheckGoodsIssueKeyAttributes(GoodsIssueArray) Export
	
	DataStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	GoodsIssueHeader.Contract AS Contract,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Order AS Order,
	|	GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssue
	|FROM
	|	Document.GoodsIssue AS GoodsIssueHeader
	|WHERE
	|	GoodsIssueHeader.Ref IN(&GoodsIssueArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueProducts.Contract
	|		ELSE GoodsIssueHeader.Contract
	|	END AS Contract,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE GoodsIssueHeader.Order
	|	END AS Order,
	|	GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssueHeader
	|FROM
	|	TT_GoodsIssue AS GoodsIssueHeader
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.Ref = GoodsIssueProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesOrder.VATTaxation AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	TT_GoodsIssueHeader.Company AS Company,
	|	TT_GoodsIssueHeader.Counterparty AS Counterparty,
	|	TT_GoodsIssueHeader.Contract AS Contract,
	|	TT_GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	TT_GoodsIssueHeader.Order AS Order,
	|	TT_GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssueAndOrders
	|FROM
	|	TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_GoodsIssueHeader.Order = SalesOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Total.Company) AS Company,
	|	SUM(Total.Counterparty) AS Counterparty,
	|	SUM(Total.Contract) AS Contract,
	|	SUM(Total.StructuralUnit) AS StructuralUnit,
	|	SUM(Total.DocumentCurrency) AS DocumentCurrency,
	|	SUM(Total.IncludeVATInPrice) AS IncludeVATInPrice,
	|	SUM(Total.VATTaxation) AS VATTaxation,
	|	SUM(Total.AmountIncludesVAT) AS AmountIncludesVAT,
	|	SUM(Total.DiscountMarkupKind) AS DiscountMarkupKind,
	|	SUM(Total.PriceKind) AS PriceKind,
	|	SUM(Total.DiscountCard) AS DiscountCard
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Company) AS Company,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Counterparty) AS Counterparty,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Contract) AS Contract,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.StructuralUnit) AS StructuralUnit,
	|		0 AS DocumentCurrency,
	|		0 AS IncludeVATInPrice,
	|		0 AS VATTaxation,
	|		0 AS AmountIncludesVAT,
	|		0 AS DiscountMarkupKind,
	|		0 AS PriceKind,
	|		0 AS DiscountCard
	|	FROM
	|		TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		0,
	|		0,
	|		0,
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DocumentCurrency),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.IncludeVATInPrice),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.VATTaxation),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.AmountIncludesVAT),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DiscountMarkupKind),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.PriceKind),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DiscountCard)
	|	FROM
	|		TT_GoodsIssueAndOrders AS TT_GoodsIssueAndOrders) AS Total
	|
	|HAVING
	|	(SUM(Total.Company) > 1
	|		OR SUM(Total.Counterparty) > 1
	|		OR SUM(Total.Contract) > 1
	|		OR SUM(Total.StructuralUnit) > 1
	|		OR SUM(Total.DocumentCurrency) > 1
	|		OR SUM(Total.IncludeVATInPrice) > 1
	|		OR SUM(Total.VATTaxation) > 1
	|		OR SUM(Total.AmountIncludesVAT) > 1
	|		OR SUM(Total.DiscountMarkupKind) > 1
	|		OR SUM(Total.PriceKind) > 1
	|		OR SUM(Total.DiscountCard) > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_GoodsIssueHeader.Ref AS Ref,
	|	TT_GoodsIssueHeader.Contract AS Contract
	|FROM
	|	TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|TOTALS BY
	|	Contract";
	
	Query.SetParameter("GoodsIssueArray", GoodsIssueArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			OrdersArray = New Array;
			
			Sel = SelGroups.Select();
			While Sel.Next() Do
				OrdersArray.Add(New Structure("Ref, Contract", Sel.Ref, Sel.Contract));
			EndDo;
			
			GroupsArray.Add(OrdersArray);
		EndDo;
		DataStructure.Insert("GoodsIssueGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckOrdersKeyAttributes(OrdersArray, AdditionalParameters = Undefined) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.Counterparty AS Counterparty,
	|	SalesOrderHeader.Contract AS Contract,
	|	SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	SalesOrderHeader.PriceKind AS PriceKind,
	|	SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrderHeader.DiscountCard AS DiscountCard,
	|	SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesOrderHeader.VATTaxation AS VATTaxation,
	|	SalesOrderHeader.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|WHERE
	|	SalesOrderHeader.Ref IN(&OrdersArray)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	&Company,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	VALUE(Catalog.CounterpartyContracts.EmptyRef),
	|	VALUE(Catalog.BusinessUnits.EmptyRef),
	|	VALUE(Catalog.PriceTypes.EmptyRef),
	|	VALUE(Catalog.DiscountTypes.EmptyRef),
	|	VALUE(Catalog.DiscountCards.EmptyRef),
	|	VALUE(Catalog.Currencies.EmptyRef),
	|	FALSE,
	|	FALSE,
	|	VALUE(Enum.VATTaxationTypes.EmptyRef),
	|	VALUE(Document.SalesOrder.EmptyRef)
	|WHERE
	|	&AddEmptyShippingAddress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.Contract AS Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind AS PriceKind,
	|	TT_SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard AS DiscountCard,
	|	TT_SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SalesOrderHeader.Ref) AS MinRef
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.IncludeVATInPrice,
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind,
	|	TT_SalesOrderHeader.DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT,
	|	TT_SalesOrderHeader.VATTaxation,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SalesOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT SalesOrderHeader.PriceKind) AS PriceKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountMarkupKind) AS DiscountMarkupKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountCard) AS DiscountCard,
	|	COUNT(DISTINCT SalesOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT SalesOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT SalesOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT SalesOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.PriceKind
	|	END AS PriceKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountMarkupKind
	|	END AS DiscountMarkupKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountCard
	|	END AS DiscountCard,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR NOT &SimpleCheck
	|				AND (TT_SalesOrderHeaderCount.Contract > 1
	|					OR TT_SalesOrderHeaderCount.StructuralUnitReserve > 1
	|					OR TT_SalesOrderHeaderCount.PriceKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountMarkupKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountCard > 1
	|					OR TT_SalesOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_SalesOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_SalesOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_SalesOrderHeaderCount.VATTaxation > 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InnerTable.MinRef AS MinRef,
	|	InnerTable.Counterparty AS Counterparty,
	|	InnerTable.Ref AS Ref
	|FROM
	|	(SELECT
	|		TT_SalesOrderHeaderMin.MinRef AS MinRef,
	|		TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|		TT_SalesOrderHeader.Ref AS Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (NOT &SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|				AND TT_SalesOrderHeaderMin.Contract = TT_SalesOrderHeader.Contract
	|				AND TT_SalesOrderHeaderMin.StructuralUnitReserve = TT_SalesOrderHeader.StructuralUnitReserve
	|				AND TT_SalesOrderHeaderMin.PriceKind = TT_SalesOrderHeader.PriceKind
	|				AND TT_SalesOrderHeaderMin.DiscountMarkupKind = TT_SalesOrderHeader.DiscountMarkupKind
	|				AND TT_SalesOrderHeaderMin.DiscountCard = TT_SalesOrderHeader.DiscountCard
	|				AND TT_SalesOrderHeaderMin.DocumentCurrency = TT_SalesOrderHeader.DocumentCurrency
	|				AND TT_SalesOrderHeaderMin.AmountIncludesVAT = TT_SalesOrderHeader.AmountIncludesVAT
	|				AND TT_SalesOrderHeaderMin.IncludeVATInPrice = TT_SalesOrderHeader.IncludeVATInPrice
	|				AND TT_SalesOrderHeaderMin.VATTaxation = TT_SalesOrderHeader.VATTaxation
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_SalesOrderHeaderMin.Company,
	|		TT_SalesOrderHeaderMin.Counterparty,
	|		TT_SalesOrderHeader.Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (&SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty) AS InnerTable
	|
	|GROUP BY
	|	InnerTable.MinRef,
	|	InnerTable.Counterparty,
	|	InnerTable.Ref
	|TOTALS BY
	|	MinRef,
	|	Counterparty";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	If AdditionalParameters <> Undefined
		And AdditionalParameters.Property("SimpleCheck") Then
		Query.SetParameter("SimpleCheck", AdditionalParameters.SimpleCheck);
	Else
		Query.SetParameter("SimpleCheck", False);
	EndIf;
	
	If AdditionalParameters <> Undefined
		And AdditionalParameters.Property("AddEmptyShippingAddress") Then
		Query.SetParameter("AddEmptyShippingAddress", AdditionalParameters.AddEmptyShippingAddress);
		Query.SetParameter("Company", AdditionalParameters.Company);
	Else
		Query.SetParameter("AddEmptyShippingAddress", False);
		Query.SetParameter("Company", Catalogs.Companies.EmptyRef());
	EndIf;
	
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			SelCounterparty = SelGroups.Select(QueryResultIteration.ByGroups);
			
			While SelCounterparty.Next() Do
				OrdersArray = New Array;
				
				Sel = SelCounterparty.Select();
				While Sel.Next() Do
					OrdersArray.Add(Sel.Ref);
				EndDo;
				
				GroupsArray.Add(OrdersArray);
			EndDo;
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckWorkOrdersKeyAttributes(OrdersArray, SimpleCheck = False) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	WorkOrder.Company AS Company,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	WorkOrder.PriceKind AS PriceKind,
	|	WorkOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	WorkOrder.DiscountCard AS DiscountCard,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	WorkOrder.VATTaxation AS VATTaxation,
	|	WorkOrder.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.Contract AS Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind AS PriceKind,
	|	TT_SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard AS DiscountCard,
	|	TT_SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SalesOrderHeader.Ref) AS MinRef
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.IncludeVATInPrice,
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind,
	|	TT_SalesOrderHeader.DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT,
	|	TT_SalesOrderHeader.VATTaxation,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SalesOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT SalesOrderHeader.PriceKind) AS PriceKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountMarkupKind) AS DiscountMarkupKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountCard) AS DiscountCard,
	|	COUNT(DISTINCT SalesOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT SalesOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT SalesOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT SalesOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.PriceKind
	|	END AS PriceKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountMarkupKind
	|	END AS DiscountMarkupKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountCard
	|	END AS DiscountCard,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR NOT &SimpleCheck
	|				AND (TT_SalesOrderHeaderCount.Contract > 1
	|					OR TT_SalesOrderHeaderCount.StructuralUnitReserve > 1
	|					OR TT_SalesOrderHeaderCount.PriceKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountMarkupKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountCard > 1
	|					OR TT_SalesOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_SalesOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_SalesOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_SalesOrderHeaderCount.VATTaxation > 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InnerTable.MinRef AS MinRef,
	|	InnerTable.Counterparty AS Counterparty,
	|	InnerTable.Ref AS Ref
	|FROM
	|	(SELECT
	|		TT_SalesOrderHeaderMin.MinRef AS MinRef,
	|		TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|		TT_SalesOrderHeader.Ref AS Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (NOT &SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|				AND TT_SalesOrderHeaderMin.Contract = TT_SalesOrderHeader.Contract
	|				AND TT_SalesOrderHeaderMin.StructuralUnitReserve = TT_SalesOrderHeader.StructuralUnitReserve
	|				AND TT_SalesOrderHeaderMin.PriceKind = TT_SalesOrderHeader.PriceKind
	|				AND TT_SalesOrderHeaderMin.DiscountMarkupKind = TT_SalesOrderHeader.DiscountMarkupKind
	|				AND TT_SalesOrderHeaderMin.DiscountCard = TT_SalesOrderHeader.DiscountCard
	|				AND TT_SalesOrderHeaderMin.DocumentCurrency = TT_SalesOrderHeader.DocumentCurrency
	|				AND TT_SalesOrderHeaderMin.AmountIncludesVAT = TT_SalesOrderHeader.AmountIncludesVAT
	|				AND TT_SalesOrderHeaderMin.IncludeVATInPrice = TT_SalesOrderHeader.IncludeVATInPrice
	|				AND TT_SalesOrderHeaderMin.VATTaxation = TT_SalesOrderHeader.VATTaxation
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_SalesOrderHeaderMin.Company,
	|		TT_SalesOrderHeaderMin.Counterparty,
	|		TT_SalesOrderHeader.Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (&SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty) AS InnerTable
	|
	|GROUP BY
	|	InnerTable.MinRef,
	|	InnerTable.Counterparty,
	|	InnerTable.Ref
	|TOTALS BY
	|	MinRef,
	|	Counterparty";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("SimpleCheck", SimpleCheck);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			SelCounterparty = SelGroups.Select(QueryResultIteration.ByGroups);
			
			While SelCounterparty.Next() Do
				OrdersArray = New Array;
				
				Sel = SelCounterparty.Select();
				While Sel.Next() Do
					OrdersArray.Add(Sel.Ref);
				EndDo;
				
				GroupsArray.Add(OrdersArray);
			EndDo;
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckTransferOrdersKeyAttributes(TransferOrderArray) Export
	
	DataStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	OrderHeader.Company AS Company,
	|	OrderHeader.StructuralUnit AS StructuralUnit,
	|	OrderHeader.StructuralUnitPayee AS StructuralUnitPayee,
	|	OrderHeader.Ref AS Ref
	|INTO TT_Order
	|FROM
	|	Document.TransferOrder AS OrderHeader
	|WHERE
	|	OrderHeader.Ref IN(&GoodsIssueArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	OrderHeader.Company AS Company,
	|	OrderHeader.StructuralUnitPayee AS StructuralUnitPayee,
	|	OrderHeader.StructuralUnit AS StructuralUnit,
	|	OrderHeader.Ref AS Ref
	|INTO TT_OrderHeader
	|FROM
	|	TT_Order AS OrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Total.Company) AS Company,
	|	SUM(Total.StructuralUnitPayee) AS StructuralUnitPayee,
	|	SUM(Total.StructuralUnit) AS StructuralUnit
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_OrderHeader.Company) AS Company,
	|		COUNT(DISTINCT TT_OrderHeader.StructuralUnitPayee) AS StructuralUnitPayee,
	|		COUNT(DISTINCT TT_OrderHeader.StructuralUnit) AS StructuralUnit
	|	FROM
	|		TT_OrderHeader AS TT_OrderHeader) AS Total
	|
	|HAVING
	|	(SUM(Total.Company) > 1
	|		OR SUM(Total.StructuralUnitPayee) > 1
	|		OR SUM(Total.StructuralUnit) > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_OrderHeader.Ref AS Ref,
	|	TT_OrderHeader.StructuralUnit AS StructuralUnit,
	|	TT_OrderHeader.StructuralUnitPayee AS StructuralUnitPayee,
	|	TT_OrderHeader.Company AS Company
	|FROM
	|	TT_OrderHeader AS TT_OrderHeader
	|TOTALS BY
	|	Company,
	|	StructuralUnit,
	|	StructuralUnitPayee";
	
	Query.SetParameter("GoodsIssueArray", TransferOrderArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[2];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelectionCompany = Results[3].Select(QueryResultIteration.ByGroups);
		While SelectionCompany.Next() Do
			
			StructuralUnit = SelectionCompany.Select(QueryResultIteration.ByGroups);
			While StructuralUnit.Next() Do
				
				StructuralUnitPayee = StructuralUnit.Select(QueryResultIteration.ByGroups);
				While StructuralUnitPayee.Next() Do
					
					OrdersInvoicesArray = New Array;
					
					SelectionRef = StructuralUnitPayee.Select();
					While SelectionRef.Next() Do
						OrdersInvoicesArray.Add(SelectionRef.Ref);
					EndDo;
					
					GroupsArray.Add(OrdersInvoicesArray);
					
				EndDo;
			EndDo;
		EndDo;

		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersInvoicesArray, AdditionalParameters = Undefined) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.Counterparty AS Counterparty,
	|	SalesOrderHeader.ShippingAddress AS ShippingAddress,
	|	SalesOrderHeader.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|WHERE
	|	SalesOrderHeader.Ref IN(&OrdersInvoicesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Company,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.ShippingAddress,
	|	SalesInvoice.Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&OrdersInvoicesArray)
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	&Company,
	|	VALUE(Catalog.Counterparties.EmptyRef),
	|	"""",
	|	VALUE(Document.SalesOrder.EmptyRef)
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|WHERE
	|	&AddEmptyShippingAddress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.ShippingAddress AS ShippingAddress
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.ShippingAddress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.ShippingAddress) AS ShippingAddress
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	TT_SalesOrderHeaderCount.ShippingAddress AS ShippingAddress
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR TT_SalesOrderHeaderCount.ShippingAddress > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderMin.Company AS Company,
	|	TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|	TT_SalesOrderHeaderMin.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrderHeader.Ref AS Ref
	|FROM
	|	TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|		INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|		ON TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|			AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|			AND TT_SalesOrderHeaderMin.ShippingAddress = TT_SalesOrderHeader.ShippingAddress
	|
	|GROUP BY
	|	TT_SalesOrderHeaderMin.Company,
	|	TT_SalesOrderHeaderMin.Counterparty,
	|	TT_SalesOrderHeaderMin.ShippingAddress,
	|	TT_SalesOrderHeader.Ref
	|TOTALS BY
	|	Company,
	|	Counterparty,
	|	ShippingAddress";
	
	Query.SetParameter("OrdersInvoicesArray", OrdersInvoicesArray);
	
	If AdditionalParameters <> Undefined
		And AdditionalParameters.Property("AddEmptyShippingAddress") Then
		Query.SetParameter("AddEmptyShippingAddress", AdditionalParameters.AddEmptyShippingAddress);
		Query.SetParameter("Company", AdditionalParameters.Company);
	Else
		Query.SetParameter("AddEmptyShippingAddress", False);
		Query.SetParameter("Company", Catalogs.Companies.EmptyRef());
	EndIf;
	
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelectionCompany = Results[4].Select(QueryResultIteration.ByGroups);
		While SelectionCompany.Next() Do
			
			SelectionCounterparty = SelectionCompany.Select(QueryResultIteration.ByGroups);
			While SelectionCounterparty.Next() Do
				
				SelectionAddress = SelectionCounterparty.Select(QueryResultIteration.ByGroups);
				While SelectionAddress.Next() Do
					
					OrdersInvoicesArray = New Array;
					
					SelectionRef = SelectionAddress.Select();
					While SelectionRef.Next() Do
						OrdersInvoicesArray.Add(SelectionRef.Ref);
					EndDo;
					
					GroupsArray.Add(OrdersInvoicesArray);
					
				EndDo;
			EndDo;
		EndDo;
		
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function GetCheckedAttributesPresentationMap()
	
	Map = New Map;
	
	Map.Insert("Company",
		NStr("en = 'Company'; ru = 'Организация';pl = 'Firma';es_ES = 'Empresa';es_CO = 'Empresa';tr = 'İş yeri';it = 'Azienda';de = 'Firma'"));
		
	Map.Insert("Counterparty",
		NStr("en = 'Counterparty'; ru = 'Контрагент';pl = 'Kontrahent';es_ES = 'Contraparte';es_CO = 'Contraparte';tr = 'Cari hesap';it = 'Controparte';de = 'Geschäftspartner'"));
		
	Map.Insert("Contract",
		NStr("en = 'Contract'; ru = 'Договор';pl = 'Kontrakt';es_ES = 'Contrato';es_CO = 'Contrato';tr = 'Sözleşme';it = 'Contratto';de = 'Vertrag'"));
		
	Map.Insert("StructuralUnitReserve",
		NStr("en = 'Warehouse (reserve)'; ru = 'Склад (резерв)';pl = 'Magazyn (rezerwa)';es_ES = 'Almacén (reserva)';es_CO = 'Almacén (reserva)';tr = 'Ambar (rezerv)';it = 'Magazzino (riserva)';de = 'Lager (Reserve)'"));
		
	Map.Insert("StructuralUnit",
		NStr("en = 'Warehouse'; ru = 'Склад';pl = 'Magazyn';es_ES = 'Almacén';es_CO = 'Almacén';tr = 'Ambar';it = 'Magazzino';de = 'Lager'"));
		
	Map.Insert("PriceKind",
		NStr("en = 'Price type'; ru = 'Тип цен';pl = 'Rodzaj ceny';es_ES = 'Tipo de precios';es_CO = 'Tipo de precios';tr = 'Fiyat türü';it = 'Tipo di prezzo';de = 'Preistyp'"));
		
	Map.Insert("DiscountMarkupKind",
		NStr("en = 'Discount type'; ru = 'Тип скидки';pl = 'Typ rabatu';es_ES = 'Tipo de descuento';es_CO = 'Tipo de descuento';tr = 'İndirim türü';it = 'Tipo di sconto';de = 'Art des Rabatts'"));
		
	Map.Insert("DiscountCard",
		NStr("en = 'Discount card'; ru = 'Дисконтная карта';pl = 'Karta rabatowa';es_ES = 'Tarjeta de descuento';es_CO = 'Tarjeta de descuento';tr = 'İndirim kartı';it = 'Carta sconto';de = 'Rabattkarte'"));
		
	Map.Insert("DocumentCurrency",
		NStr("en = 'Currency'; ru = 'Валюта';pl = 'Waluta';es_ES = 'Moneda';es_CO = 'Moneda';tr = 'Para birimi';it = 'Valuta';de = 'Währung'"));
		
	Map.Insert("AmountIncludesVAT",
		NStr("en = 'Amount includes VAT'; ru = 'Сумма включает НДС';pl = 'Kwota zawiera VAT';es_ES = 'Importe incluye el IVA';es_CO = 'Importe incluye el IVA';tr = 'Tutara KDV dahil';it = 'Importo IVA inclusa';de = 'Der Betrag beinhaltet die USt.'"));
		
	Map.Insert("IncludeVATInPrice",
		NStr("en = 'Include VAT in cost'; ru = 'НДС включать в стоимость';pl = 'Włącz VAT do kosztów własnych';es_ES = 'Incluir el IVA en el coste';es_CO = 'Incluir el IVA en el coste';tr = 'Maliyete KDV''yi dahil et';it = 'Includere IVA nel costo';de = 'USt. in Kosten aufnehmen'"));
		
	Map.Insert("VATTaxation",
		NStr("en = 'Tax category'; ru = 'Налогообложение';pl = 'Rodzaj opodatkowania VAT';es_ES = 'Categoría de impuestos';es_CO = 'Categoría de impuestos';tr = 'Vergi kategorisi';it = 'Categoria di imposta';de = 'Steuerkategorie'"));
		
	Map.Insert("ShippingAddress",
		NStr("en = 'Shipping address'; ru = 'Адрес доставки';pl = 'Adres dostawy';es_ES = 'Dirección para el envío';es_CO = 'Dirección para el envío';tr = 'Teslimat adresi';it = 'Indirizzo di spedizione';de = 'Lieferadresse'"));
		
	Map.Insert("StructuralUnitPayee",
		NStr("en = 'Warehouse (to)'; ru = 'Склад (куда)';pl = 'Magazyn (do)';es_ES = 'Almacén (a)';es_CO = 'Almacén (a)';tr = 'Ambar (hedef)';it = 'Magazzino (a)';de = 'Lager (bis)'"));
		
	
	Return Map;
	
EndFunction

Function CheckPurchaseOrdersSupplierInvoicesKeyAttributes(OrdersInvoicesArray, SimpleCheck = False) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	PurchaseOrderHeader.Company AS Company,
	|	PurchaseOrderHeader.Counterparty AS Counterparty,
	|	PurchaseOrderHeader.Contract AS Contract,
	|	PurchaseOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	PurchaseOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrderHeader.VATTaxation AS VATTaxation,
	|	PurchaseOrderHeader.Ref AS Ref
	|INTO TT_PurchaseOrderHeader
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrderHeader
	|WHERE
	|	PurchaseOrderHeader.Ref IN(&OrdersInvoicesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoiceHeader.Company,
	|	SupplierInvoiceHeader.Counterparty,
	|	SupplierInvoiceHeader.Contract,
	|	SupplierInvoiceHeader.StructuralUnit,
	|	SupplierInvoiceHeader.DocumentCurrency,
	|	SupplierInvoiceHeader.AmountIncludesVAT,
	|	SupplierInvoiceHeader.IncludeVATInPrice,
	|	SupplierInvoiceHeader.VATTaxation,
	|	SupplierInvoiceHeader.Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoiceHeader
	|WHERE
	|	SupplierInvoiceHeader.Ref IN(&OrdersInvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	TT_PurchaseOrderHeader.Company AS Company,
	|	FALSE AS ContinentalMethod,
	|	TT_PurchaseOrderHeader.Counterparty AS Counterparty,
	|	TT_PurchaseOrderHeader.Contract AS Contract,
	|	TT_PurchaseOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_PurchaseOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_PurchaseOrderHeader.Ref) AS MinRef
	|INTO TT_PurchaseOrderHeaderMin
	|FROM
	|	TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|WHERE
	|	NOT &SimpleCheck
	|
	|GROUP BY
	|	TT_PurchaseOrderHeader.IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.Company,
	|	TT_PurchaseOrderHeader.Contract,
	|	TT_PurchaseOrderHeader.StructuralUnitReserve,
	|	TT_PurchaseOrderHeader.DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.VATTaxation,
	|	TT_PurchaseOrderHeader.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PurchaseOrderHeader.Company,
	|	TRUE,
	|	TT_PurchaseOrderHeader.Counterparty,
	|	TT_PurchaseOrderHeader.Contract,
	|	UNDEFINED,
	|	TT_PurchaseOrderHeader.DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.VATTaxation,
	|	MIN(TT_PurchaseOrderHeader.Ref)
	|FROM
	|	TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON TT_PurchaseOrderHeader.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	&SimpleCheck
	|	AND AccountingPolicySliceLast.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental)
	|
	|GROUP BY
	|	TT_PurchaseOrderHeader.IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.Company,
	|	TT_PurchaseOrderHeader.Contract,
	|	TT_PurchaseOrderHeader.DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.VATTaxation,
	|	TT_PurchaseOrderHeader.Counterparty
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PurchaseOrderHeader.Company,
	|	FALSE,
	|	TT_PurchaseOrderHeader.Counterparty,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	UNDEFINED,
	|	MIN(TT_PurchaseOrderHeader.Ref)
	|FROM
	|	TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON TT_PurchaseOrderHeader.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	&SimpleCheck
	|	AND AccountingPolicySliceLast.StockTransactionsMethodology <> VALUE(Enum.StockTransactionsMethodology.Continental)
	|
	|GROUP BY
	|	TT_PurchaseOrderHeader.Company,
	|	TT_PurchaseOrderHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	COUNT(DISTINCT PurchaseOrderHeader.Company) AS Company,
	|	MAX(AccountingPolicySliceLast.StockTransactionsMethodology = VALUE(Enum.StockTransactionsMethodology.Continental)) AS ContinentalMethod,
	|	COUNT(DISTINCT PurchaseOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT PurchaseOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT PurchaseOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT PurchaseOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT PurchaseOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT PurchaseOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT PurchaseOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_PurchaseOrderHeaderCount
	|FROM
	|	TT_PurchaseOrderHeader AS PurchaseOrderHeader
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON PurchaseOrderHeader.Company = AccountingPolicySliceLast.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrderHeaderCount.Company AS Company,
	|	TT_PurchaseOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|				AND NOT TT_PurchaseOrderHeaderCount.ContinentalMethod
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|				AND NOT TT_PurchaseOrderHeaderCount.ContinentalMethod
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|				AND NOT TT_PurchaseOrderHeaderCount.ContinentalMethod
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|				AND NOT TT_PurchaseOrderHeaderCount.ContinentalMethod
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|				AND NOT TT_PurchaseOrderHeaderCount.ContinentalMethod
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_PurchaseOrderHeaderCount AS TT_PurchaseOrderHeaderCount
	|WHERE
	|	(TT_PurchaseOrderHeaderCount.Company > 1
	|			OR TT_PurchaseOrderHeaderCount.Counterparty > 1
	|			OR (NOT &SimpleCheck
	|				OR TT_PurchaseOrderHeaderCount.ContinentalMethod)
	|				AND (TT_PurchaseOrderHeaderCount.Contract > 1
	|					OR TT_PurchaseOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_PurchaseOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_PurchaseOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_PurchaseOrderHeaderCount.VATTaxation > 1)
	|			OR NOT &SimpleCheck
	|				AND TT_PurchaseOrderHeaderCount.StructuralUnitReserve > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrderHeaderMin.MinRef AS MinRef,
	|	TT_PurchaseOrderHeader.Ref AS Ref
	|FROM
	|	TT_PurchaseOrderHeaderMin AS TT_PurchaseOrderHeaderMin
	|		INNER JOIN TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|		ON (NOT &SimpleCheck)
	|			AND TT_PurchaseOrderHeaderMin.Company = TT_PurchaseOrderHeader.Company
	|			AND TT_PurchaseOrderHeaderMin.Counterparty = TT_PurchaseOrderHeader.Counterparty
	|			AND TT_PurchaseOrderHeaderMin.Contract = TT_PurchaseOrderHeader.Contract
	|			AND TT_PurchaseOrderHeaderMin.StructuralUnitReserve = TT_PurchaseOrderHeader.StructuralUnitReserve
	|			AND TT_PurchaseOrderHeaderMin.DocumentCurrency = TT_PurchaseOrderHeader.DocumentCurrency
	|			AND TT_PurchaseOrderHeaderMin.AmountIncludesVAT = TT_PurchaseOrderHeader.AmountIncludesVAT
	|			AND TT_PurchaseOrderHeaderMin.IncludeVATInPrice = TT_PurchaseOrderHeader.IncludeVATInPrice
	|			AND TT_PurchaseOrderHeaderMin.VATTaxation = TT_PurchaseOrderHeader.VATTaxation
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PurchaseOrderHeaderMin.MinRef,
	|	TT_PurchaseOrderHeader.Ref
	|FROM
	|	TT_PurchaseOrderHeaderMin AS TT_PurchaseOrderHeaderMin
	|		INNER JOIN TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|		ON (&SimpleCheck)
	|			AND (TT_PurchaseOrderHeaderMin.ContinentalMethod)
	|			AND TT_PurchaseOrderHeaderMin.Company = TT_PurchaseOrderHeader.Company
	|			AND TT_PurchaseOrderHeaderMin.Counterparty = TT_PurchaseOrderHeader.Counterparty
	|			AND TT_PurchaseOrderHeaderMin.Contract = TT_PurchaseOrderHeader.Contract
	|			AND TT_PurchaseOrderHeaderMin.DocumentCurrency = TT_PurchaseOrderHeader.DocumentCurrency
	|			AND TT_PurchaseOrderHeaderMin.AmountIncludesVAT = TT_PurchaseOrderHeader.AmountIncludesVAT
	|			AND TT_PurchaseOrderHeaderMin.IncludeVATInPrice = TT_PurchaseOrderHeader.IncludeVATInPrice
	|			AND TT_PurchaseOrderHeaderMin.VATTaxation = TT_PurchaseOrderHeader.VATTaxation
	|
	|UNION ALL
	|
	|SELECT
	|	TT_PurchaseOrderHeaderMin.Company,
	|	TT_PurchaseOrderHeader.Ref
	|FROM
	|	TT_PurchaseOrderHeaderMin AS TT_PurchaseOrderHeaderMin
	|		INNER JOIN TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|		ON (&SimpleCheck)
	|			AND (NOT TT_PurchaseOrderHeaderMin.ContinentalMethod)
	|			AND TT_PurchaseOrderHeaderMin.Company = TT_PurchaseOrderHeader.Company
	|			AND TT_PurchaseOrderHeaderMin.Counterparty = TT_PurchaseOrderHeader.Counterparty
	|TOTALS BY
	|	MinRef
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT PurchaseOrderOperation.OperationKind) AS Counter
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrderOperation
	|WHERE
	|	PurchaseOrderOperation.Ref IN(&OrdersInvoicesArray)";
	
	Query.SetParameter("OrdersInvoicesArray", OrdersInvoicesArray);
	Query.SetParameter("SimpleCheck", SimpleCheck);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	Result_NumberOfOperations = Results[5].Unload();
	
	DataStructure.Insert("NumberOfOperations", Result_NumberOfOperations[0].Counter);
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			OrdersArray = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				OrdersArray.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(OrdersArray);
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckGoodsReceiptKeyAttributes(GoodsReceiptArray) Export
	
	DataStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	GoodsReceiptHeader.Contract AS Contract,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Order AS Order,
	|	GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceipt
	|FROM
	|	Document.GoodsReceipt AS GoodsReceiptHeader
	|WHERE
	|	GoodsReceiptHeader.Ref IN(&GoodsReceiptArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptProducts.Contract
	|		ELSE GoodsReceiptHeader.Contract
	|	END AS Contract,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE GoodsReceiptHeader.Order
	|	END AS Order,
	|	GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceiptHeader
	|FROM
	|	TT_GoodsReceipt AS GoodsReceiptHeader
	|		LEFT JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.Ref = GoodsReceiptProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_GoodsReceiptHeader.Company AS Company,
	|	TT_GoodsReceiptHeader.Counterparty AS Counterparty,
	|	TT_GoodsReceiptHeader.Contract AS Contract,
	|	TT_GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	TT_GoodsReceiptHeader.Order AS Order,
	|	TT_GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceiptAndOrders
	|FROM
	|	TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|		INNER JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON TT_GoodsReceiptHeader.Order = PurchaseOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Total.Company) AS Company,
	|	SUM(Total.Counterparty) AS Counterparty,
	|	SUM(Total.Contract) AS Contract,
	|	SUM(Total.StructuralUnit) AS StructuralUnit,
	|	SUM(Total.DocumentCurrency) AS DocumentCurrency,
	|	SUM(Total.IncludeVATInPrice) AS IncludeVATInPrice,
	|	SUM(Total.VATTaxation) AS VATTaxation,
	|	SUM(Total.AmountIncludesVAT) AS AmountIncludesVAT
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Company) AS Company,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Counterparty) AS Counterparty,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Contract) AS Contract,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.StructuralUnit) AS StructuralUnit,
	|		0 AS DocumentCurrency,
	|		0 AS IncludeVATInPrice,
	|		0 AS VATTaxation,
	|		0 AS AmountIncludesVAT
	|	FROM
	|		TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		0,
	|		0,
	|		0,
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.DocumentCurrency),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.IncludeVATInPrice),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.VATTaxation),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.AmountIncludesVAT)
	|	FROM
	|		TT_GoodsReceiptAndOrders AS TT_GoodsReceiptAndOrders) AS Total
	|
	|HAVING
	|	(SUM(Total.Company) > 1
	|		OR SUM(Total.Counterparty) > 1
	|		OR SUM(Total.Contract) > 1
	|		OR SUM(Total.StructuralUnit) > 1
	|		OR SUM(Total.DocumentCurrency) > 1
	|		OR SUM(Total.IncludeVATInPrice) > 1
	|		OR SUM(Total.VATTaxation) > 1
	|		OR SUM(Total.AmountIncludesVAT) > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_GoodsReceiptHeader.Ref AS Ref,
	|	TT_GoodsReceiptHeader.Contract AS Contract
	|FROM
	|	TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|TOTALS BY
	|	Contract";

	Query.SetParameter("GoodsReceiptArray", GoodsReceiptArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			OrdersArray = New Array;
			
			Sel = SelGroups.Select();
			While Sel.Next() Do
				OrdersArray.Add(New Structure("Ref, Contract", Sel.Ref, Sel.Contract));
			EndDo;
			
			GroupsArray.Add(OrdersArray);
		EndDo;
		DataStructure.Insert("GoodsReceiptGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckRMARequestKeyAttributes(RMARequestArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	RMARequestHeader.Company AS Company,
	|	RMARequestHeader.Counterparty AS Counterparty,
	|	RMARequestHeader.Ref AS Ref
	|INTO TT_RMARequestHeader
	|FROM
	|	Document.RMARequest AS RMARequestHeader
	|WHERE
	|	RMARequestHeader.Ref IN(&RMARequestArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_RMARequestHeader.Company AS Company,
	|	TT_RMARequestHeader.Counterparty AS Counterparty,
	|	MIN(TT_RMARequestHeader.Ref) AS MinRef
	|INTO TT_RMARequestHeaderMin
	|FROM
	|	TT_RMARequestHeader AS TT_RMARequestHeader
	|
	|GROUP BY
	|	TT_RMARequestHeader.Company,
	|	TT_RMARequestHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT RMARequestHeader.Company) AS Company,
	|	COUNT(DISTINCT RMARequestHeader.Counterparty) AS Counterparty
	|INTO TT_RMARequestHeaderCount
	|FROM
	|	TT_RMARequestHeader AS RMARequestHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_RMARequestHeaderCount.Company AS Company,
	|	TT_RMARequestHeaderCount.Counterparty AS Counterparty
	|FROM
	|	TT_RMARequestHeaderCount AS TT_RMARequestHeaderCount
	|WHERE
	|	(TT_RMARequestHeaderCount.Company > 1
	|			OR TT_RMARequestHeaderCount.Counterparty > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_RMARequestHeaderMin.MinRef AS MinRef,
	|	TT_RMARequestHeader.Ref AS Ref
	|FROM
	|	TT_RMARequestHeaderMin AS TT_RMARequestHeaderMin
	|		INNER JOIN TT_RMARequestHeader AS TT_RMARequestHeader
	|		ON TT_RMARequestHeaderMin.Company = TT_RMARequestHeader.Company
	|			AND TT_RMARequestHeaderMin.Counterparty = TT_RMARequestHeader.Counterparty
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("RMARequestArray", RMARequestArray);
	
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleGoodsReceipt", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleGoodsReceipt", True);
		
		DataPresentation			= "";
		AttributesPresentationMap	= GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				
				AttributeName = Column.Name;
				
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					
					If AttributePresentaion = Undefined Then
						
						AttributePresentaion = AttributeName;
						
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			
			RequestArray = New Array;
			
			Sel = SelGroups.Select();
			While Sel.Next() Do
				RequestArray.Add(Sel.Ref);
			EndDo;
			
			GroupsArray.Add(RequestArray);
			
		EndDo;
		
		DataStructure.Insert("RequestGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckSupplierInvoicesKeyAttributes(SupplierInvoicesArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	SupplierInvoiceHeader.Ref AS Ref
	|INTO TT_SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoiceHeader
	|WHERE
	|	SupplierInvoiceHeader.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeader.Company AS Company,
	|	TT_SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	TT_SupplierInvoiceHeader.Contract AS Contract,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SupplierInvoiceHeader.Ref) AS MinRef
	|INTO TT_SupplierInvoiceHeaderMin
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|
	|GROUP BY
	|	TT_SupplierInvoiceHeader.Company,
	|	TT_SupplierInvoiceHeader.Contract,
	|	TT_SupplierInvoiceHeader.StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation,
	|	TT_SupplierInvoiceHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SupplierInvoiceHeader.Company) AS Company,
	|	COUNT(DISTINCT SupplierInvoiceHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SupplierInvoiceHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SupplierInvoiceHeader.StructuralUnit) AS StructuralUnit,
	|	COUNT(DISTINCT SupplierInvoiceHeader.VATTaxation) AS VATTaxation
	|INTO TT_SupplierInvoiceHeaderCount
	|FROM
	|	TT_SupplierInvoiceHeader AS SupplierInvoiceHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeaderCount.Company AS Company,
	|	TT_SupplierInvoiceHeaderCount.Counterparty AS Counterparty,
	|	TT_SupplierInvoiceHeaderCount.Contract AS Contract,
	|	TT_SupplierInvoiceHeaderCount.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_SupplierInvoiceHeaderCount AS TT_SupplierInvoiceHeaderCount
	|WHERE
	|	(TT_SupplierInvoiceHeaderCount.Company > 1
	|			OR TT_SupplierInvoiceHeaderCount.Counterparty > 1
	|			OR TT_SupplierInvoiceHeaderCount.Contract > 1
	|			OR TT_SupplierInvoiceHeaderCount.StructuralUnit > 1
	|			OR TT_SupplierInvoiceHeaderCount.VATTaxation > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeaderMin.MinRef AS MinRef,
	|	TT_SupplierInvoiceHeader.Ref AS Ref
	|FROM
	|	TT_SupplierInvoiceHeaderMin AS TT_SupplierInvoiceHeaderMin
	|		INNER JOIN TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|		ON TT_SupplierInvoiceHeaderMin.Company = TT_SupplierInvoiceHeader.Company
	|			AND TT_SupplierInvoiceHeaderMin.Counterparty = TT_SupplierInvoiceHeader.Counterparty
	|			AND TT_SupplierInvoiceHeaderMin.Contract = TT_SupplierInvoiceHeader.Contract
	|			AND TT_SupplierInvoiceHeaderMin.StructuralUnit = TT_SupplierInvoiceHeader.StructuralUnit
	|			AND TT_SupplierInvoiceHeaderMin.VATTaxation = TT_SupplierInvoiceHeader.VATTaxation
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("OrdersArray", SupplierInvoicesArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleDocuments", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleDocuments", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			InvoicesArray = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				InvoicesArray.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(InvoicesArray);
		EndDo;
		DataStructure.Insert("SupplierInvoiceGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckSalesInvoicesKeyAttributes(InvoicesArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	SalesInvoiceHeader.Company AS Company,
	|	SalesInvoiceHeader.Counterparty AS Counterparty,
	|	SalesInvoiceHeader.Contract AS Contract,
	|	SalesInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	SalesInvoiceHeader.Ref AS Ref
	|INTO TT_SalesInvoiceHeader
	|FROM
	|	Document.SalesInvoice AS SalesInvoiceHeader
	|WHERE
	|	SalesInvoiceHeader.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesInvoiceHeader.Company AS Company,
	|	TT_SalesInvoiceHeader.Counterparty AS Counterparty,
	|	TT_SalesInvoiceHeader.Contract AS Contract,
	|	TT_SalesInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SalesInvoiceHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SalesInvoiceHeader.Ref) AS MinRef
	|INTO TT_SalesInvoiceHeaderMin
	|FROM
	|	TT_SalesInvoiceHeader AS TT_SalesInvoiceHeader
	|
	|GROUP BY
	|	TT_SalesInvoiceHeader.Company,
	|	TT_SalesInvoiceHeader.Contract,
	|	TT_SalesInvoiceHeader.StructuralUnit,
	|	TT_SalesInvoiceHeader.VATTaxation,
	|	TT_SalesInvoiceHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesInvoiceHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesInvoiceHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesInvoiceHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SalesInvoiceHeader.StructuralUnit) AS StructuralUnit,
	|	COUNT(DISTINCT SalesInvoiceHeader.VATTaxation) AS VATTaxation
	|INTO TT_SalesInvoiceHeaderCount
	|FROM
	|	TT_SalesInvoiceHeader AS SalesInvoiceHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesInvoiceHeaderCount.Company AS Company,
	|	TT_SalesInvoiceHeaderCount.Counterparty AS Counterparty,
	|	TT_SalesInvoiceHeaderCount.Contract AS Contract,
	|	TT_SalesInvoiceHeaderCount.StructuralUnit AS StructuralUnit,
	|	TT_SalesInvoiceHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_SalesInvoiceHeaderCount AS TT_SalesInvoiceHeaderCount
	|WHERE
	|	(TT_SalesInvoiceHeaderCount.Company > 1
	|			OR TT_SalesInvoiceHeaderCount.Counterparty > 1
	|			OR TT_SalesInvoiceHeaderCount.Contract > 1
	|			OR TT_SalesInvoiceHeaderCount.StructuralUnit > 1
	|			OR TT_SalesInvoiceHeaderCount.VATTaxation > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesInvoiceHeaderMin.MinRef AS MinRef,
	|	TT_SalesInvoiceHeader.Ref AS Ref
	|FROM
	|	TT_SalesInvoiceHeaderMin AS TT_SalesInvoiceHeaderMin
	|		INNER JOIN TT_SalesInvoiceHeader AS TT_SalesInvoiceHeader
	|		ON TT_SalesInvoiceHeaderMin.Company = TT_SalesInvoiceHeader.Company
	|			AND TT_SalesInvoiceHeaderMin.Counterparty = TT_SalesInvoiceHeader.Counterparty
	|			AND TT_SalesInvoiceHeaderMin.Contract = TT_SalesInvoiceHeader.Contract
	|			AND TT_SalesInvoiceHeaderMin.StructuralUnit = TT_SalesInvoiceHeader.StructuralUnit
	|			AND TT_SalesInvoiceHeaderMin.VATTaxation = TT_SalesInvoiceHeader.VATTaxation
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("OrdersArray", InvoicesArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleDocuments", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleDocuments", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			InvoicesArray = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				InvoicesArray.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(InvoicesArray);
		EndDo;
		DataStructure.Insert("SalesInvoiceGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckCreditNotesKeyAttributes(ArrayOfDebitNotes) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CreditNoteHeader.Company AS Company,
	|	CreditNoteHeader.Counterparty AS Counterparty,
	|	CreditNoteHeader.Contract AS Contract,
	|	CreditNoteHeader.StructuralUnit AS StructuralUnit,
	|	CreditNoteHeader.VATTaxation AS VATTaxation,
	|	CreditNoteHeader.Ref AS Ref
	|INTO TT_CreditNoteHeader
	|FROM
	|	Document.CreditNote AS CreditNoteHeader
	|WHERE
	|	CreditNoteHeader.Ref IN(&ArrayOfDebitNotes)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CreditNoteHeader.Company AS Company,
	|	TT_CreditNoteHeader.Counterparty AS Counterparty,
	|	TT_CreditNoteHeader.Contract AS Contract,
	|	TT_CreditNoteHeader.StructuralUnit AS StructuralUnit,
	|	TT_CreditNoteHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_CreditNoteHeader.Ref) AS MinRef
	|INTO TT_CreditNoteHeaderMin
	|FROM
	|	TT_CreditNoteHeader AS TT_CreditNoteHeader
	|
	|GROUP BY
	|	TT_CreditNoteHeader.Company,
	|	TT_CreditNoteHeader.Contract,
	|	TT_CreditNoteHeader.StructuralUnit,
	|	TT_CreditNoteHeader.VATTaxation,
	|	TT_CreditNoteHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT CreditNoteHeader.Company) AS Company,
	|	COUNT(DISTINCT CreditNoteHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT CreditNoteHeader.Contract) AS Contract,
	|	COUNT(DISTINCT CreditNoteHeader.StructuralUnit) AS StructuralUnit,
	|	COUNT(DISTINCT CreditNoteHeader.VATTaxation) AS VATTaxation
	|INTO TT_CreditNoteHeaderCount
	|FROM
	|	TT_CreditNoteHeader AS CreditNoteHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CreditNoteHeaderCount.Company AS Company,
	|	TT_CreditNoteHeaderCount.Counterparty AS Counterparty,
	|	TT_CreditNoteHeaderCount.Contract AS Contract,
	|	TT_CreditNoteHeaderCount.StructuralUnit AS StructuralUnit,
	|	TT_CreditNoteHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_CreditNoteHeaderCount AS TT_CreditNoteHeaderCount
	|WHERE
	|	(TT_CreditNoteHeaderCount.Company > 1
	|			OR TT_CreditNoteHeaderCount.Counterparty > 1
	|			OR TT_CreditNoteHeaderCount.Contract > 1
	|			OR TT_CreditNoteHeaderCount.StructuralUnit > 1
	|			OR TT_CreditNoteHeaderCount.VATTaxation > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_CreditNoteHeaderMin.MinRef AS MinRef,
	|	TT_CreditNoteHeader.Ref AS Ref
	|FROM
	|	TT_CreditNoteHeaderMin AS TT_CreditNoteHeaderMin
	|		INNER JOIN TT_CreditNoteHeader AS TT_CreditNoteHeader
	|		ON TT_CreditNoteHeaderMin.Company = TT_CreditNoteHeader.Company
	|			AND TT_CreditNoteHeaderMin.Counterparty = TT_CreditNoteHeader.Counterparty
	|			AND TT_CreditNoteHeaderMin.Contract = TT_CreditNoteHeader.Contract
	|			AND TT_CreditNoteHeaderMin.StructuralUnit = TT_CreditNoteHeader.StructuralUnit
	|			AND TT_CreditNoteHeaderMin.VATTaxation = TT_CreditNoteHeader.VATTaxation
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("ArrayOfDebitNotes", ArrayOfDebitNotes);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleDocuments", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleDocuments", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			ArrayOfDebitNotes = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				ArrayOfDebitNotes.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(ArrayOfDebitNotes);
		EndDo;
		DataStructure.Insert("DocumentGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckDebitNotesKeyAttributes(DebitNotesArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	DebitNoteHeader.Company AS Company,
	|	DebitNoteHeader.Counterparty AS Counterparty,
	|	DebitNoteHeader.Contract AS Contract,
	|	DebitNoteHeader.StructuralUnit AS StructuralUnit,
	|	DebitNoteHeader.VATTaxation AS VATTaxation,
	|	DebitNoteHeader.Ref AS Ref
	|INTO TT_DebitNoteHeader
	|FROM
	|	Document.DebitNote AS DebitNoteHeader
	|WHERE
	|	DebitNoteHeader.Ref IN(&DebitNotesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DebitNoteHeader.Company AS Company,
	|	TT_DebitNoteHeader.Counterparty AS Counterparty,
	|	TT_DebitNoteHeader.Contract AS Contract,
	|	TT_DebitNoteHeader.StructuralUnit AS StructuralUnit,
	|	TT_DebitNoteHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_DebitNoteHeader.Ref) AS MinRef
	|INTO TT_DebitNoteHeaderMin
	|FROM
	|	TT_DebitNoteHeader AS TT_DebitNoteHeader
	|
	|GROUP BY
	|	TT_DebitNoteHeader.Company,
	|	TT_DebitNoteHeader.Contract,
	|	TT_DebitNoteHeader.StructuralUnit,
	|	TT_DebitNoteHeader.VATTaxation,
	|	TT_DebitNoteHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT DebitNoteHeader.Company) AS Company,
	|	COUNT(DISTINCT DebitNoteHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT DebitNoteHeader.Contract) AS Contract,
	|	COUNT(DISTINCT DebitNoteHeader.StructuralUnit) AS StructuralUnit,
	|	COUNT(DISTINCT DebitNoteHeader.VATTaxation) AS VATTaxation
	|INTO TT_DebitNoteHeaderCount
	|FROM
	|	TT_DebitNoteHeader AS DebitNoteHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DebitNoteHeaderCount.Company AS Company,
	|	TT_DebitNoteHeaderCount.Counterparty AS Counterparty,
	|	TT_DebitNoteHeaderCount.Contract AS Contract,
	|	TT_DebitNoteHeaderCount.StructuralUnit AS StructuralUnit,
	|	TT_DebitNoteHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_DebitNoteHeaderCount AS TT_DebitNoteHeaderCount
	|WHERE
	|	(TT_DebitNoteHeaderCount.Company > 1
	|			OR TT_DebitNoteHeaderCount.Counterparty > 1
	|			OR TT_DebitNoteHeaderCount.Contract > 1
	|			OR TT_DebitNoteHeaderCount.StructuralUnit > 1
	|			OR TT_DebitNoteHeaderCount.VATTaxation > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_DebitNoteHeaderMin.MinRef AS MinRef,
	|	TT_DebitNoteHeader.Ref AS Ref
	|FROM
	|	TT_DebitNoteHeaderMin AS TT_DebitNoteHeaderMin
	|		INNER JOIN TT_DebitNoteHeader AS TT_DebitNoteHeader
	|		ON TT_DebitNoteHeaderMin.Company = TT_DebitNoteHeader.Company
	|			AND TT_DebitNoteHeaderMin.Counterparty = TT_DebitNoteHeader.Counterparty
	|			AND TT_DebitNoteHeaderMin.Contract = TT_DebitNoteHeader.Contract
	|			AND TT_DebitNoteHeaderMin.StructuralUnit = TT_DebitNoteHeader.StructuralUnit
	|			AND TT_DebitNoteHeaderMin.VATTaxation = TT_DebitNoteHeader.VATTaxation
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("DebitNotesArray", DebitNotesArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleDocuments", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleDocuments", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			DebitNotesArray = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				DebitNotesArray.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(DebitNotesArray);
		EndDo;
		DataStructure.Insert("DocumentGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckExpenseReportKeyAttributes(DocRef) Export
	
	DataStructure = New Structure();
	
	DocAttributes = Common.ObjectAttributesValues(DocRef, "Company, Date");
	
	If Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(DocAttributes.Date, DocAttributes.Company) Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'Company %1 doesn''t use tax invoices at %2. Specify this option in accounting policy'; ru = 'Организация %1 не использует налоговые инвойсы на %2. Укажите данную опцию в учетной политике';pl = 'Firma %1 nie stosuje faktur VAT do %2. Określ tę opcję w zasadach rachunkowości';es_ES = 'Empresa %1 no utiliza las factura de impuestos en %2. Especificar esta opción en la política de contabilidad';es_CO = 'Empresa %1 no utiliza las facturas fiscales en %2. Especificar esta opción en la política de contabilidad';tr = '%1 iş yeri %2 tarihinde vergi faturaları kullanmıyor. Muhasebe politikasında bu seçeneği belirtin';it = 'L''azienda %1 non utilizza fatture fiscali per %2. Specificare questa opzione nella politica contabile';de = 'Firma %1 verwendet keine Steuerrechnungen bei %2. Geben Sie diese Option in der Bilanzierungsrichtlinie an'"),
			DocAttributes.Company,
			Format(DocAttributes.Date, "DLF=D"));
		
		CommonClientServer.MessageToUser(MessageText);
		
		DataStructure.Insert("Checked", False);
		
	Else
		
		DataStructure.Insert("Checked", True);
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	ExpenseReport.Ref AS Ref,
		|	ExpenseReport.Company AS Company,
		|	ExpenseReport.DocumentCurrency AS Currency
		|INTO ExpenseReportHeader
		|FROM
		|	Document.ExpenseReport AS ExpenseReport
		|WHERE
		|	ExpenseReport.Ref = &Ref
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ExpenseReportHeader.Ref AS Ref,
		|	ExpenseReportHeader.Company AS Company,
		|	ExpenseReportHeader.Currency AS Currency,
		|	ExpenseReportInventory.VATAmount AS VATAmount,
		|	ExpenseReportInventory.Total AS Total,
		|	ExpenseReportInventory.Supplier AS Supplier
		|INTO ExpenseReportTax
		|FROM
		|	ExpenseReportHeader AS ExpenseReportHeader
		|		INNER JOIN Document.ExpenseReport.Inventory AS ExpenseReportInventory
		|		ON ExpenseReportHeader.Ref = ExpenseReportInventory.Ref
		|WHERE
		|	ExpenseReportInventory.DeductibleTax
		|
		|UNION ALL
		|
		|SELECT
		|	ExpenseReportHeader.Ref,
		|	ExpenseReportHeader.Company,
		|	ExpenseReportHeader.Currency,
		|	ExpenseReportExpenses.VATAmount,
		|	ExpenseReportExpenses.Total,
		|	ExpenseReportExpenses.Supplier
		|FROM
		|	ExpenseReportHeader AS ExpenseReportHeader
		|		INNER JOIN Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|		ON ExpenseReportHeader.Ref = ExpenseReportExpenses.Ref
		|WHERE
		|	ExpenseReportExpenses.DeductibleTax
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ExpenseReportTax.Ref AS BasisDocument,
		|	ExpenseReportTax.Company AS Company,
		|	ExpenseReportTax.Currency AS Currency,
		|	SUM(ExpenseReportTax.VATAmount) AS VATAmount,
		|	SUM(ExpenseReportTax.Total) AS Amount,
		|	ExpenseReportTax.Supplier AS Counterparty
		|FROM
		|	ExpenseReportTax AS ExpenseReportTax
		|
		|GROUP BY
		|	ExpenseReportTax.Ref,
		|	ExpenseReportTax.Company,
		|	ExpenseReportTax.Currency,
		|	ExpenseReportTax.Supplier";
		
		Query.SetParameter("Ref", DocRef);
		
		ResultTable = Query.Execute().Unload();
		
		If ResultTable.Count() = 0 Then
			
			Message = NStr("en = 'Cannot generate Tax invoice received. The Expense claim has no
				|items with the Deductible tax check box selected.'; 
				|ru = 'Не удалось создать документ ""Налоговый инвойс полученный"". Авансовый отчет не содержит
				|статьи расходов с установленным флажком ""Вычитаемый налог"".';
				|pl = 'Nie można wygenerować ""Otrzymanej faktury VAT"". Raport rozchodów nie ma 
				|elementów z zaznaczonym polem wyboru Podatek podlegający potrąceniu.';
				|es_ES = 'No se puede generar la ""Factura de impuestos recibida"". El informe de gastos no contiene
				|los artículos con la casilla de verificación Impuesto deducible seleccionada.';
				|es_CO = 'No se puede generar la ""Factura fiscal recibida"". El informe de gastos no contiene
				|los artículos con la casilla de verificación Impuesto deducible seleccionada.';
				|tr = '""Alınan vergi faturası"" oluşturulamıyor. Masraf raporu,
				|Düşülebilir vergi onay kutusu seçili olan masraf öğeleri içermiyor.';
				|it = 'Impossibile generare la Fattura fiscale ricevuta. La Nota spese non ha 
				|elementi con la casella di controllo Imposte deducibili selezionata.';
				|de = '„Steuerrechnung erhalten“ kann nicht generiert werden. Die Kostenabrechnung enthält keine 
				| Ausgabenpositionen, bei denen das Kontrollkästchen ""Abziehbare Steuer"" aktiviert ist.'");
			CommonClientServer.MessageToUser(Message);
			
			DataStructure.Insert("Checked", False);
			
		Else
			
			If ResultTable.Count() > 1 Then
				DataStructure.Insert("CreateMultipleDocuments", True);
			Else
				DataStructure.Insert("CreateMultipleDocuments", False);
			EndIf;
			
			RowsArray = New Array;
			
			For Each Row In ResultTable Do
				
				RowDataStructure = New Structure("BasisDocument, Company, Currency, VATAmount, Amount, Counterparty");
				FillPropertyValues(RowDataStructure, Row);
				RowsArray.Add(RowDataStructure);
				
			EndDo;
			
			DataStructure.Insert("RowsDataArray", RowsArray);
			
		EndIf;
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

#EndRegion

#EndRegion

#Region Properties

// Fill tabular section of propety value object from property value tree on form.
//
Procedure MovePropertiesValues(AdditionalAttributes, PropertyTree) Export
	
	Values = New Map;
	FillPropertyValuesFromTree(PropertyTree.Rows, Values);
	
	AdditionalAttributes.Clear();
	For Each Str In Values Do
		NewRow = AdditionalAttributes.Add();
		NewRow.Property = Str.Key;
		NewRow.Value = Str.Value;
	EndDo;
	
EndProcedure

// Fill property value tree on the object form.
//
Function FillValuesPropertiesTree(Ref, AdditionalAttributes, ForAdditionalAttributes, Sets) Export
	
	If TypeOf(Sets) = Type("ValueList") Then
		PrListOfSets = Sets;
	Else
		PrListOfSets = New ValueList;
		If Sets <> Undefined Then
			PrListOfSets.Add(Sets);
		EndIf;
	EndIf;
	
	Tree = GetTreeForEditPropertiesValues(PrListOfSets, AdditionalAttributes, ForAdditionalAttributes);
	
	Return Tree;
	
EndFunction

// Fill the matching by the rows of the property values tree with non-empty values.
//
Procedure FillPropertyValuesFromTree(TreeRows, Values)

	For Each Str In TreeRows Do
		If ValueIsFilled(Str.Value) Then
			Values.Insert(Str.Property, Str.Value);
		EndIf;
	EndDo;

EndProcedure

// Form property value tree to edit in object form.
//
Function GetTreeForEditPropertiesValues(PrListOfSets, propertiesTab, ForAddDetails)
	
	PrLstSelected = New ValueList;
	For Each Str In propertiesTab Do
		If PrListOfSets.FindByValue(Str.Property) = Undefined Then
			PrLstSelected.Add(Str.Property);
		EndIf;
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AdditionalAttributesAndInformation.Ref AS Property,
	|	AdditionalAttributesAndInformation.ValueType AS PropertyValueType,
	|	AdditionalAttributesAndInformation.FormatProperties AS FormatProperties,
	|	Properties.LineNumber AS LineNumber,
	|	CASE
	|		WHEN Properties.Error
	|			THEN 1
	|		ELSE -1
	|	END AS PictureNumber
	|FROM
	|	ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|		INNER JOIN (SELECT DISTINCT
	|			PropertiesSetsContent.Property AS Property,
	|			FALSE AS Error,
	|			PropertiesSetsContent.LineNumber AS LineNumber
	|		FROM
	|			Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSetsContent
	|		WHERE
	|			PropertiesSetsContent.Ref IN(&PrListOfSets)
	|			AND PropertiesSetsContent.Property.IsAdditionalInfo = &ThisIsAdditionalInformation
	|		
	|		UNION
	|		
	|		SELECT
	|			AdditionalAttributesAndInformation.Ref,
	|			TRUE,
	|			PropertiesSetsContent.LineNumber
	|		FROM
	|			ChartOfCharacteristicTypes.AdditionalAttributesAndInfo AS AdditionalAttributesAndInformation
	|				LEFT JOIN Catalog.AdditionalAttributesAndInfoSets.AdditionalAttributes AS PropertiesSetsContent
	|				ON (PropertiesSetsContent.Property = AdditionalAttributesAndInformation.Ref)
	|					AND (PropertiesSetsContent.Ref IN (&PrListOfSets))
	|		WHERE
	|			AdditionalAttributesAndInformation.Ref IN(&PrLstSelected)
	|			AND (PropertiesSetsContent.Ref IS NULL 
	|					OR AdditionalAttributesAndInformation.IsAdditionalInfo <> &ThisIsAdditionalInformation)) AS Properties
	|		ON AdditionalAttributesAndInformation.Ref = Properties.Property
	|
	|ORDER BY Properties.LineNumber";
	
	Query.SetParameter("ThisIsAdditionalInformation", Not ForAddDetails);
	Query.SetParameter("PrListOfSets", PrListOfSets);
	Query.SetParameter("PrLstSelected", PrLstSelected);
	
	Tree = Query.Execute().Unload(QueryResultIteration.ByGroupsWithHierarchy);
	Tree.Columns.Insert(2, "Value", Metadata.ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.Type);

	
	NewTree = New ValueTree;
	For Each Column In Tree.Columns Do
		NewTree.Columns.Add(Column.Name, Column.ValueType);
	EndDo;
	
	CopyStringValuesTree(NewTree.Rows, Tree.Rows, ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.EmptyRef());
	
	For Each Str In propertiesTab Do
		StrD = NewTree.Rows.Find(Str.Property, "Property", True);
		If StrD <> Undefined Then
			StrD.Value = Str.Value;
		EndIf;
	EndDo;
	
	Return NewTree;
	
EndFunction

// Copy necessary strings from formed value tree to another tree.
//
Procedure CopyStringValuesTree(RowsWhereTo, RowsFrom, Parent)
	
	For Each Str In RowsFrom Do
		If Str.Property = Parent Then
			CopyStringValuesTree(RowsWhereTo, Str.Rows, Str.Property);
		Else
			NewRow = RowsWhereTo.Add();
			FillPropertyValues(NewRow, Str);
			CopyStringValuesTree(NewRow.Rows, Str.Rows, Str.Property);
		EndIf;
		
	EndDo;
	
EndProcedure


#EndRegion

#Region ToDoList

Function ResponsibleStructure() Export
	
	ResponsibleStructure = New Structure();
	ResponsibleStructure.Insert("List", New Array);
	ResponsibleStructure.Insert("Initials", "");

	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	UserEmployees.Employee AS Employee,
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname AS Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name AS Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic AS Patronymic
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&ToDate, ) AS ChangeHistoryOfIndividualNamesSliceLast
	|		ON UserEmployees.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
	|WHERE
	|	UserEmployees.User = &User";
	
	Query.SetParameter("User", Users.AuthorizedUser());
	Query.SetParameter("ToDate", CurrentSessionDate());
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		ResponsibleStructure.List.Add(Selection.Employee);
		PresentationResponsible = GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
		ResponsibleStructure.Initials = ResponsibleStructure.Initials
			+ ?(ResponsibleStructure.Initials  = "", "", ", ")
			+ ?(ValueIsFilled(PresentationResponsible), PresentationResponsible, String(Selection.Employee));
	EndDo;
	
	Return ResponsibleStructure;
	
EndFunction

#EndRegion

#Region WorkWithStatusesInList

Procedure AddChangeStatusCommands(Form, SubmenuGroupName, CatalogStatusesName) Export
	
	StatusesList = StatusesList(CatalogStatusesName);
	SubmenuGroup = Form.Items[SubmenuGroupName];
	
	For Each DocumentStatus In StatusesList Do
		
		CommandName = BeginningOfCommandChangeStatus() + StrReplace(DocumentStatus.Ref.UUID(), "-", "x");
		
		FormCommand = Form.Commands.Add(CommandName);
		FormCommand.Action = "Attachable_ExecuteChangeStatusCommand";
		
		FormButton = Form.Items.Add(CommandName, Type("FormButton"), SubmenuGroup);
		FormButton.Type = FormButtonType.CommandBarButton;
		FormButton.CommandName = CommandName;
		FormButton.Title = DocumentStatus.Description;
		
	EndDo;
	
EndProcedure

Function StatusesList(CatalogStatusesName)
	
	SetPrivilegedMode(True);
	If Constants["Use" + CatalogStatusesName].Get() Then
		
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	StatusesCatalog.Ref AS Ref,
			|	StatusesCatalog.Description AS Description
			|FROM
			|	&StatusesCatalog AS StatusesCatalog
			|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
			|		ON StatusesCatalog.OrderStatus = OrderStatuses.Ref
			|WHERE
			|	NOT StatusesCatalog.DeletionMark
			|
			|ORDER BY
			|	OrderStatuses.Order";
		
		Query.Text = StrReplace(Query.Text, "&StatusesCatalog", "Catalog." + CatalogStatusesName);
		QueryResult = Query.Execute();
		
		Return QueryResult.Unload();
		
	Else
		
		StatusConstants = New Array;
		StatusConstants.Add("SalesOrdersInProgressStatus");
		StatusConstants.Add("StateCompletedSalesOrders");
		StatusConstants.Add("PurchaseOrdersInProgressStatus");
		StatusConstants.Add("PurchaseOrdersCompletionStatus");
		StatusConstants.Add("TransferOrdersInProgressStatus");
		StatusConstants.Add("StateCompletedTransferOrders");
		StatusConstants.Add("SubcontractorOrderIssuedInProgressStatus");
		StatusConstants.Add("SubcontractorOrderIssuedCompletionStatus");
		StatusConstants.Add("WorkOrdersInProgressStatus");
		StatusConstants.Add("StateCompletedWorkOrders");
		StatusConstants.Add("KitOrdersInProgressStatus");
		StatusConstants.Add("KitOrdersCompletionStatus");
		// begin Drive.FullVersion
		StatusConstants.Add("ProductionOrdersInProgressStatus");
		StatusConstants.Add("ProductionOrdersCompletionStatus");
		StatusConstants.Add("SubcontractorOrderReceivedInProgressStatus");
		StatusConstants.Add("SubcontractorOrderReceivedCompletionStatus");
		// end Drive.FullVersion
		
		Result = New Array;
		
		For Each StatusConstant In StatusConstants Do
			If Metadata.Constants[StatusConstant].Type.ContainsType(Type("CatalogRef." + CatalogStatusesName)) Then
				ConstantValue = Constants[StatusConstant].Get();
				Result.Add(New Structure("Ref, Description", ConstantValue, String(ConstantValue))); 
			EndIf;
		EndDo;
		
		Return Result;
		
	EndIf;
	
EndFunction

Procedure ChangeOrdersStatuses(OrdersArray, CommandName, CatalogStatusesName) Export
	
	CommandPartUUID = Right(CommandName, StrLen(CommandName) - StrLen(BeginningOfCommandChangeStatus()));
	CatalogUUID = New UUID(StrReplace(CommandPartUUID, "x", "-"));
	NewStatus = Catalogs[CatalogStatusesName].GetRef(CatalogUUID);
	
	// begin Drive.FullVersion
	CheckProductionOrderStatuses = Constants.UseProductionOrderStatuses.Get() And CatalogStatusesName = "ProductionOrderStatuses";
	// end Drive.FullVersion
	
	If Common.RefExists(NewStatus) Then
		
		For Each Order In OrdersArray Do
			
			// begin Drive.FullVersion
			If CheckProductionOrderStatuses Then
				
				StructureOrderState = Documents.ProductionOrder.CheckCompletedOrderState(Order);
				
				If Not StructureOrderState.CheckPassed Then
					
					TextMessage = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Unable to change status for %1. Related documents Work-in-progress must be completed'; ru = 'Не удалось изменить статус документа %1. Необходимо заполнить связанные документы ""Незавершенное производство""';pl = 'Nie można zmienić statusu dla %1. Związane dokumenty Praca w toku powinny być zakończone';es_ES = 'Imposible cambiar el estatus de %1. Los documentos relacionados con el Trabajo en progreso deben ser finalizados';es_CO = 'Imposible cambiar el estatus de %1. Los documentos relacionados con el Trabajo en progreso deben ser finalizados';tr = '%1 için durum değiştirilemiyor. İlgili İşlem bitişi belgeleri tamamlanmalıdır';it = 'Impossibile modificare lo stato per %1. I documenti correlati nel Lavoro in corso devono essere completati';de = 'Kann den Status für %1 nicht ändern. Verwandte Dokumente Arbeit-in-Bearbeitung sollen ausgefüllt sein'"),
						TrimAll(Order));
					CommonClientServer.MessageToUser(TextMessage);
					
					Continue;
					
				EndIf;
				
			EndIf;
			// end Drive.FullVersion
			
			OrderObject = Order.GetObject();
			OrderObject.OrderState = NewStatus;
			OrderObject.Closed = False;
			Try
				OrderObject.Write(?(Order.Posted, DocumentWriteMode.Posting, DocumentWriteMode.Write));
			Except
				ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'Cannot save document ""%1"". Details: %2'; ru = 'Не удалось записать документ ""%1"". Подробнее: %2';pl = 'Nie można zapisać dokumentu ""%1"". Szczegóły: %2';es_ES = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';es_CO = 'Ha ocurrido un error al guardar el documento ""%1"". Detalles: %2';tr = '""%1"" belgesi saklanamıyor. Ayrıntılar: %2';it = 'Impossibile salvare il documento ""%1"". Dettagli: %2';de = 'Fehler beim Speichern des Dokuments ""%1"". Details: %2'"),
					Order,
					BriefErrorDescription(ErrorInfo()));
				CommonClientServer.MessageToUser(ErrorDescription);
			EndTry;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function BeginningOfCommandChangeStatus()
	
	Return "CommandChangeStatus_";
	
EndFunction

#EndRegion

#Region WorkWithTypes

Function DescriptionOfStandartTypes(TypesDescription) Export
	
	TypeDescription = "";
	
	For Each Type In TypesDescription.Types() Do
		
		If Type = Type("String") Then
			
			StringLength = TypeDescription.StringQualifiers.Length;
			
			TypeDescription = TypeDescription
				+ StringFunctionsClientServer.SubstituteParametersToString(
					";String(%1, %2)",
					?(StringLength = 0,"0",Format(StringLength, "NG = 0")),
					TypesDescription.StringQualifiers.AllowedLength);
			
		ElsIf Type = Type("Number") Then
			
			TypeDescription = TypeDescription
				+ StringFunctionsClientServer.SubstituteParametersToString(
					";Number(%1, %2, %3)",
					TypesDescription.NumberQualifiers.Digits,
					TypesDescription.NumberQualifiers.FractionDigits,
					TypesDescription.NumberQualifiers.AllowedSign);
			
		ElsIf Type = Type("Boolean") Then
			
			TypeDescription = TypeDescription + ";Boolean";
			
		ElsIf Type = Type("Date") Then
			
			TypeDescription = TypeDescription + ";Date(" + TypesDescription.DateQualifiers.DateFractions + ")";
			
		EndIf;
		
	EndDo;
		
	Return Mid(TypeDescription,2);
		
EndFunction

Function StandartTypeToString(Type) Export
	
	If Type = Type("String") Then
		Return "String";
	ElsIf Type = Type("Number") Then
		Return "Number";
	ElsIf Type = Type("Date") Then
		Return "Date";
	ElsIf Type = Type("Boolean") Then
		Return "Boolean";
	Else
		Return Undefined;
	EndIf;
	
EndFunction

Function DescriptionOfDataTypes(TypesDescription) Export
	
	TypesArray = TypesDescription.Types();
	
	DescriptionOfDataTypes = "";
	DescriptionOfStandartTypes = "";
	
	If TypesArray.Count() > 1 Then
		DescriptionOfStandartTypes = DescriptionOfStandartTypes(TypesDescription);
	EndIf;
	
	For Each Type In TypesArray Do
		
		StandartType = StandartTypeToString(Type);
		If StandartType = Undefined Then
			
			MetadataObject = Metadata.FindByType(Type);
			
			If MetadataObject = Undefined Then
				Continue;;
			Else
				DataTypeDescription = MetadataObject.FullName();
				DescriptionOfDataTypes = DescriptionOfDataTypes + ";" + DataTypeDescription;
			EndIf;
			
		ElsIf IsBlankString(DescriptionOfStandartTypes) Then
			DescriptionOfDataTypes = DescriptionOfDataTypes + ";" + StandartType;
		EndIf;
		
	EndDo;
	
	If Not IsBlankString(DescriptionOfStandartTypes) Then
		DescriptionOfDataTypes = DescriptionOfDataTypes + ";" + DescriptionOfStandartTypes;
	EndIf;
	
	Return Mid(DescriptionOfDataTypes, 2);
	
EndFunction

#EndRegion

#Region WorkWithQuery

Function QueryExecuteUnload(QueryText, QueryParameters = Undefined, TempTablesManager = Undefined) Export
	
	Query = New Query(QueryText);
	
	If TempTablesManager <> Undefined Then
		Query.TempTablesManager = TempTablesManager;
	EndIf;
	
	If ValueIsFilled(QueryParameters) Then
		For Each Parameter In QueryParameters Do
			Query.SetParameter(Parameter.Key, Parameter.Value);
		EndDo;
	EndIf;
	
	Return Query.Execute().Unload();
EndFunction

#EndRegion

#Region WorkWithValueTable

Function ColumnMin(ValueTable, ColumnName) Export
	
	Return ApplyAgregateFunctionToColumn(ValueTable, ColumnName, "MIN");
	
EndFunction

Function ApplyAgregateFunctionToColumn(ValueTable, ColumnName, FunctionName)
	
	QueryTemplate =
	"SELECT
	|	ValueTable.%1 AS ColumnName
	|INTO TT_ValueTable
	|FROM
	|	&ValueTable AS ValueTable
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	%2(TT_ValueTable.ColumnName) AS Result
	|FROM
	|	TT_ValueTable AS TT_ValueTable";
	
	Query = New Query;
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(QueryTemplate, ColumnName, FunctionName);
	Query.SetParameter("ValueTable", ValueTable);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return Undefined;
	EndIf;
	
	Return QueryResult.Unload()[0].Result;
	
EndFunction

// Procedure excludes duplicate rows from ValueTable
//
Procedure SetDistinctRows(ValueTableSource)
	
	StringColumns = "";
	
	For Each Column In ValueTableSource.Columns Do
		
		StringColumns = StringColumns + Column.Name + ",";
		
	EndDo;
	
	StringColumns = Left(StringColumns, StrLen(StringColumns) - 1);
	
	ValueTableSource.GroupBy(StringColumns);
	
EndProcedure

// Circle shift value table
Procedure CircleShiftCollection(Collection, Val Shift) Export
	
	Size = Collection.Count();
	Shift = Shift % Size;
	
	If Size <= 1 Or Shift = 0 Then
		Return;
	EndIf;
	
	ReverseCollection(Collection, 0, Size - 1);
	ReverseCollection(Collection, 0, Shift - 1);
	ReverseCollection(Collection, Shift, Size - 1);
	
EndProcedure

// Reverse value table
Procedure ReverseCollection(Collection, Val StartIndex, Val EndIndex) Export
	
	BufferTable = Collection.CopyColumns();
	BufferRow = BufferTable.Add();
	
	While StartIndex < EndIndex Do
		
		FillPropertyValues(BufferRow, Collection[StartIndex]);
		FillPropertyValues(Collection[StartIndex], Collection[EndIndex]);
		FillPropertyValues(Collection[EndIndex], BufferRow);
		
		StartIndex = StartIndex + 1;
		EndIndex = EndIndex - 1;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region BarcodesClearing

Procedure CleanBarcodes(Products = Undefined, Variant = Undefined) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	Barcodes.Barcode AS Barcode
		|FROM
		|	InformationRegister.Barcodes AS Barcodes
		|WHERE
		|	&ProductsCondition
		|	AND &CharacteristicCondition";
	
	If Variant = Undefined Then
		Query.Text = StrReplace(Query.Text, "&CharacteristicCondition", "TRUE");
	Else
		Query.Text = StrReplace(Query.Text, "&CharacteristicCondition", "Barcodes.Characteristic = &Characteristic");
		Query.SetParameter("Characteristic", Variant);
	EndIf;
	
	If Products = Undefined Then
		Query.Text = StrReplace(Query.Text, "&ProductsCondition", "TRUE");
	Else
		Query.Text = StrReplace(Query.Text, "&ProductsCondition", "Barcodes.Products = &Products");
		Query.SetParameter("Products", Products);
	EndIf;
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		RecordSet = InformationRegisters.Barcodes.CreateRecordSet();
		RecordSet.Filter.Barcode.Set(SelectionDetailRecords.Barcode);
		RecordSet.Write();
		
	EndDo;
	
EndProcedure

#EndRegion

#Region PrintManagementServer

Function GetStructureFlags(IsDisplayPrintOption, PrintParameters) Export
	
	StructureFlags = New Structure;
	
	If IsDisplayPrintOption Then
	
		StructureFlags.Insert("IsDiscount",		PrintParameters.Discount);
		StructureFlags.Insert("IsNetAmount",	PrintParameters.NetAmount);
		StructureFlags.Insert("IsLineTotal",	PrintParameters.LineTotal);
		
	Else 
		
		StructureFlags.Insert("IsDiscount",		False);
		StructureFlags.Insert("IsNetAmount",	True);
		StructureFlags.Insert("IsLineTotal",	True);
		
	EndIf;
	
	Return StructureFlags;
	
EndFunction

Function GetStructureSecondFlags(IsDisplayPrintOption, PrintParameters) Export
	
	StructureSecondFlags = New Structure;
	
	If IsDisplayPrintOption Then
	
		StructureSecondFlags.Insert("IsPriceBeforeDiscount",	PrintParameters.PriceBeforeDiscount);
		StructureSecondFlags.Insert("IsTax",					PrintParameters.VAT);
		
	Else 
		
		StructureSecondFlags.Insert("IsPriceBeforeDiscount",	False);
		StructureSecondFlags.Insert("IsTax",					True);
		
	EndIf;
	
	Return StructureSecondFlags;
	
EndFunction

Procedure MakeShiftPictureWithShift(PictureInDocument, CounterShift) Export
	
	For Counter = 1 To CounterShift Do
			
			NumberLeftPosition = PictureInDocument.Left;
			PictureInDocument.Left = NumberLeftPosition + 17;
			
	EndDo;
	
EndProcedure

// Add one column PartAdditional to the area to match width of tabular section.
//
Procedure AddPartAdditionalToPageArea(Template, JoiningArea, StructureFlags, NameLine, NamePart = "PartAdditional") Export
	
	For Each ItemFlag In StructureFlags Do
		
		If ItemFlag.Value Then
			
			PartAdditional = Template.GetArea(NameLine + "|" + NamePart);
			JoiningArea.Join(PartAdditional);
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function GetCounterShift(StructureFlags, AddedShift = 0) Export
	
	Result = 0;
	
	If StructureFlags.IsDiscount Then
		
		Result = Result + 1;
		
	EndIf;
	
	If StructureFlags.IsNetAmount Then
		
		Result = Result + 1;
		
	EndIf;
	
	If StructureFlags.IsLineTotal Then
		
		Result = Result + 1;
		
	EndIf;
	
	If Result > 1 Then
	
		Result = Result - 1;
		
	EndIf;
	
	If AddedShift <> 0 Then
		
		Result = Result + AddedShift;
		
	EndIf;
		
	Return Result;
	
EndFunction

// Add one column PartAdditional to the area to match width of tabular section.
//
Procedure AddPartAdditionalToAreaWithShift(Template, JoiningArea, CounterShift, NameLine, NamePart) Export
	
	PartAdditional = Template.GetArea(NameLine + "|" + NamePart);
	For Counter = 1 To CounterShift Do
		JoiningArea.Join(PartAdditional);
	EndDo;
	
EndProcedure

Function GetAreaDocumentFooters(Template, StringNameFooter, CounterShift) Export
	
	FooterArea = Template.GetArea(StringNameFooter);
	
	RangeFooterPartAdditional = FooterArea.Areas["PartAdditional" + StringNameFooter];
	
	For Counter = 1 To CounterShift Do
		
		FooterArea.InsertArea(
			RangeFooterPartAdditional,
			RangeFooterPartAdditional,
			SpreadsheetDocumentShiftType.Horizontal);
		
	EndDo; 
	
	Return FooterArea;

EndFunction

Function GetCounterBundle() Export
	
	Return 7;
	
EndFunction

Procedure AddValueLineToParameter(Parameter, Value, IsFirst, FormatString = "") Export
	
	If IsBlankString(FormatString) Then
		FormattedValue = Value;
	Else
		FormattedValue = Format(Value, FormatString);
	EndIf;
	
	Parameter = "" + Parameter + ?(IsFirst, "", Chars.CR) + FormattedValue;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillRowCurrencyFromObject(Val NewRow, Val Object)
	
	If ValueIsFilled(NewRow.DocumentAmount) 
		And Not ValueIsFilled(NewRow.DocumentCurrency) Then
		
		If Common.HasObjectAttribute("CashCurrency", Object.Metadata()) Then
			NewRow.DocumentCurrency = Object.CashCurrency;
		ElsIf Common.HasObjectAttribute("Currency", Object.Metadata()) Then
			NewRow.DocumentCurrency = Object.Currency;
		EndIf;
		
	ElsIf Not ValueIsFilled(NewRow.DocumentAmount) 
		And ValueIsFilled(NewRow.DocumentCurrency) Then 
		NewRow.DocumentCurrency = Undefined;
	EndIf;

EndProcedure

Function CheckAccountingEntriesExist(AdditionalProperties)
	
	Return (Not AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntries")
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = Undefined
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries.Count() = 0)
				
			And (Not AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesCompound")
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesCompound = Undefined
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesCompound.Count() = 0)
				
			And (Not AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntriesSimple")
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesSimple = Undefined
				Or AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntriesSimple.Count() = 0);
				
EndFunction

Procedure CheckAndFillAttribute(NewRow, Object, ObjectMetadata, FieldName)

	If ObjectMetadata = Undefined Then
		Return;
	EndIf;
	
	If Common.HasObjectAttribute(FieldName, ObjectMetadata) Then
		FillPropertyValues(NewRow, Object, FieldName);
	EndIf;
	
EndProcedure

Function CheckAccountingSettingExist(AdditionalProperties)
	
	AccountingSettingExist = False;
	
	If AdditionalProperties.ForPosting.Property("AccountingSettingTable") Then
		
		AccountingSettingTable = AdditionalProperties.ForPosting.AccountingSettingTable;
		
		FoundRows = AccountingSettingTable.FindRows(
			New Structure("EntriesPostingOption", Enums.AccountingEntriesRegisterOptions.AccountingTransactionDocument));
			
		AccountingSettingExist = (FoundRows.Count() > 0);
	
	EndIf;
	
	Return AccountingSettingExist;
	
EndFunction

Function CoreMethodsTempFileName()
	Return TempFilesDir()+ "CoreMethods.epf";
EndFunction

Procedure ReflectAccountingTransactionDocuments(Recorder, SourceDocument, TypeOfAccounting, ChartOfAccounts)
	
	AccountingTransactionDocumentsRecordSet = InformationRegisters.AccountingTransactionDocuments.CreateRecordSet();
	AccountingTransactionDocumentsRecordSet.Filter.SourceDocument.Set(SourceDocument);
	AccountingTransactionDocumentsRecordSet.Filter.TypeOfAccounting.Set(TypeOfAccounting);
	
	NewRecord = AccountingTransactionDocumentsRecordSet.Add();
	NewRecord.SourceDocument			= SourceDocument;
	NewRecord.TypeOfAccounting			= TypeOfAccounting;
	NewRecord.ChartOfAccounts			= ChartOfAccounts;
	NewRecord.AccountingEntriesRecorder = Recorder;
	
	AttributesString = "Company, Author";
	
	If Common.HasObjectAttribute("DocumentCurrency", SourceDocument.Metadata()) Then
		AttributesString = StrTemplate("%1, DocumentCurrency", AttributesString);
	EndIf;
	
	If Common.HasObjectAttribute("Counterparty", SourceDocument.Metadata()) Then
		AttributesString = StrTemplate("%1, Counterparty", AttributesString);
	EndIf;
	
	If Common.HasObjectAttribute("DocumentAmount", SourceDocument.Metadata()) Then
		AttributesString = StrTemplate("%1, DocumentAmount", AttributesString);
	EndIf;
	
	If Common.HasObjectAttribute("OperationKind", SourceDocument.Metadata()) Then
		AttributesString = StrTemplate("%1, OperationKind", AttributesString);
	EndIf;
	
	SourceDocumentData = Common.ObjectAttributesValues(SourceDocument, AttributesString);
	
	FillPropertyValues(NewRecord, SourceDocumentData);
	
	AccountingTransactionDocumentsRecordSet.Write();
	
EndProcedure

Procedure CheckTypeAndAddExtDimensionsToRecord(RowTable, RegisterRow, NameAdding, MaxAnalyticalDimensionsNumber)
	
	AccountField	= StrTemplate("Account%1" , NameAdding);
	AccountData		= Common.ObjectAttributesValues(RowTable[AccountField], "AnalyticalDimensionsSet");
	
	If Not ValueIsFilled(AccountData.AnalyticalDimensionsSet) Then
		Return;
	EndIf;
	
	ExtDimensionTypeField	= StrTemplate("ExtDimensionType%1"	, NameAdding);
	ExtDimensionField		= StrTemplate("ExtDimension%1"		, NameAdding);
	ExtDimensionsData		= StrTemplate("ExtDimensions%1"		, NameAdding);
	
	For Index = 1 To MaxAnalyticalDimensionsNumber Do
		
		ExtType = RowTable[ExtDimensionTypeField + Index];
		If ValueIsFilled(ExtType) Then
			
			ExtValue = RowTable[ExtDimensionField + Index];
			RegisterRow[ExtDimensionsData].Insert(ExtType, ExtValue);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion