
#Region GeneralPurposeProceduresAndFunctions

// Gets query for customer settlement document selection for "Payment receipt" and "Cash receipt" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableReceipt(ShouldIncludeSalesInvicesOnly = False)
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments)
		And Not ShouldIncludeSalesInvicesOnly Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesFromConsignee)
		And Not ShouldIncludeSalesInvicesOnly Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AccountSalesFromConsignee AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetSale)
		And Not ShouldIncludeSalesInvicesOnly Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetSale AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DirectDebitMandate,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS Field2
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	// begin Drive.FullVersion
	
	If AccessRight("Read", Metadata.Documents.SubcontractorInvoiceIssued)
		And Not ShouldIncludeSalesInvicesOnly Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END AS Field2
		|FROM
		|	Document.SubcontractorInvoiceIssued AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	// end Drive.FullVersion
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServerNoContext
Function GetQueryTextAccountDocumentsOfThirdPartyPayment()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DirectDebitMandate,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets query for supplier settlement document selection for "Payment receipt" and "Cash Reciept" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableReceipt()
	
	QueryText =
	"SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.ExpenseReport) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	&CounterpartyByDefault,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ExpenseReport AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AdditionalExpenses) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AdditionalExpenses AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesToConsignor) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.AccountSalesToConsignor AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CashVoucher) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashVoucher AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.DebitNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.DebitNote AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets a query for selecting accounts receivable documents for "Bank payment" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.OnlineReceipt)
		And GetFunctionalOption("UsePaymentProcessors") Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.OnlineReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesFromConsignee) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AccountSalesFromConsignee AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.FixedAssetSale) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.FixedAssetSale AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DirectDebitMandate,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CreditNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CreditNote AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|	AND &SelectCreditNote";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets a query for selecting accounts payable documents for "Bank payment" and "Cash payment" documents.
// 
&AtServerNoContext
Function GetQueryTextDocumentsOfAccountsPayableWriteOff()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.AdditionalExpenses) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.AdditionalExpenses AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.CustomsDeclaration) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CustomsDeclaration AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	DocumentData.DirectDebitMandate,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.AccountSalesToConsignor) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE WHEN DocumentData.Posted THEN
		|		1
		|	WHEN DocumentData.DeletionMark THEN
		|		2
		|	ELSE
		|		0
		|	END
		|FROM
		|	Document.AccountSalesToConsignor AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ArApAdjustments) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.SettlementsAmount,
		|	VALUE(Catalog.Currencies.EmptyRef),
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ArApAdjustments AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorInvoiceReceived) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SubcontractorInvoiceReceived AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|";
		
	EndIf;
		
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServerNoContext
Function GetQueryTextDocumentForBankStatementProcessing()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets order from the settlement document header.
//
&AtServerNoContext
Function GetOrder(Document, ThisIsAccountsReceivable)
	
	If ThisIsAccountsReceivable Then
		
		If (TypeOf(Document) = Type("DocumentRef.ArApAdjustments")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.SalesInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.SalesOrder") Then
			
			Order = Document.Order;
			
		Else
			
			Order = Documents.SalesOrder.EmptyRef();
			
		EndIf;
			
	Else
		
		If TypeOf(Document) = Type("DocumentRef.AdditionalExpenses") Then
			
			Order = Document.PurchaseOrder;
			
		ElsIf (TypeOf(Document) = Type("DocumentRef.ArApAdjustments")
			OR TypeOf(Document) = Type("DocumentRef.SupplierInvoice")
			OR TypeOf(Document) = Type("DocumentRef.SalesInvoice"))
			AND TypeOf(Document.Order) = Type("DocumentRef.PurchaseOrder") Then
			
			Order = Document.Order;
			
		ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorInvoiceReceived")
			AND TypeOf(Document.BasisDocument) = Type("DocumentRef.SubcontractorOrderIssued") Then
			
			Order = Document.BasisDocument;
			
		Else
			
			Order = Documents.PurchaseOrder.EmptyRef();
			
		EndIf;
		
	EndIf;
	
	Return Order;
	
EndFunction

// Gets advans payments to supplier.
//
&AtServerNoContext
Function GetQueryTextAdvancePaymentsReceived()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashVoucher) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashVoucher AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesCashVoucher.Vendor)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentExpense) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentExpense AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.Vendor)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets text for the Tax invoice received.
//
&AtServerNoContext
Function GetQueryTextTaxInvoiceReceived()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	VALUE(Catalog.Employees.EmptyRef) AS Employee,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.DebitNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	VALUE(Catalog.Employees.EmptyRef),
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.DebitNote AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON (DocumentData.Ref = BasisDocuments.BasisDocument
		|			AND BasisDocuments.Ref.Posted)
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SupplierInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	VALUE(Catalog.Employees.EmptyRef),
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SupplierInvoice AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON (DocumentData.Ref = BasisDocuments.BasisDocument
		|			AND BasisDocuments.Ref.Posted)
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SubcontractorInvoiceReceived) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	VALUE(Catalog.Employees.EmptyRef),
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SubcontractorInvoiceReceived AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON (DocumentData.Ref = BasisDocuments.BasisDocument
		|			AND BasisDocuments.Ref.Posted)
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.ExpenseReport) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	&CounterpartyByDefault,
		|	DocumentData.Employee,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.ExpenseReport AS DocumentData
		|		LEFT JOIN Document.ExpenseReport.Inventory AS ExpenseReportInventory
		|		ON DocumentData.Ref = ExpenseReportInventory.Ref
		|			AND (ExpenseReportInventory.Supplier = &CounterpartyByDefault)
		|			AND (ExpenseReportInventory.DeductibleTax)
		|		LEFT JOIN Document.ExpenseReport.Expenses AS ExpenseReportExpenses
		|		ON DocumentData.Ref = ExpenseReportExpenses.Ref
		|			AND (ExpenseReportExpenses.Supplier = &CounterpartyByDefault)
		|			AND (ExpenseReportExpenses.DeductibleTax)
		|WHERE
		|	DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|	AND (NOT ExpenseReportInventory.Ref IS NULL
		|			OR NOT ExpenseReportExpenses.Ref IS NULL)
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets advans payments from customer.
//
&AtServerNoContext
Function GetQueryTextAdvancePaymentsIssued()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CashReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CashReceipt AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesCashReceipt.FromCustomer)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.PaymentReceipt) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.PaymentReceipt AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.OperationKind = VALUE(Enum.OperationTypesPaymentReceipt.FromCustomer)
		|	AND DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.OnlineReceipt)
		And GetFunctionalOption("UsePaymentProcessors") Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.CashCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.OnlineReceipt AS DocumentData
		|WHERE
		|	DocumentData.Posted
		|	AND DocumentData.CashCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

// Gets text for the Tax invoice issued.
//
&AtServerNoContext
Function GetQueryTextTaxInvoiceIssued()
	
	QueryText =
	"SELECT ALLOWED
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|";
	
	If AccessRight("Read", Metadata.Documents.CreditNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CreditNote AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If AccessRight("Read", Metadata.Documents.SalesInvoice) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	&ContractByDefault,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.SalesInvoice AS DocumentData
		|		LEFT JOIN Document.TaxInvoiceReceived.BasisDocuments AS BasisDocuments
		|		ON DocumentData.Ref = BasisDocuments.BasisDocument
		|WHERE
		|	BasisDocuments.BasisDocument IS NULL
		|	AND DocumentData.Posted
		|	AND DocumentData.DocumentCurrency = &Currency
		|";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

&AtServerNoContext
Function GetQueryTextReturnAdvances(IsSupplierReturn)
	
	QueryText =
	"SELECT ALLOWED
	|	TableBalances.Company AS Company,
	|	TableBalances.Counterparty AS Counterparty,
	|	TableBalances.Contract AS Contract,
	|	TableBalances.Document AS Document,
	|	TableBalances.PresentationCurrency AS PresentationCurrency,
	|	TableBalances.AmountCurBalance AS AmountCur
	|INTO TT_Table
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &CounterpartyByDefault
	|				AND CASE
	|					WHEN &ContractByDefault = VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|						THEN TRUE
	|					ELSE Contract = &ContractByDefault
	|				END
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				AND (&DocumentsType)) AS TableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	Table.Company,
	|	Table.Counterparty,
	|	Table.Contract,
	|	Table.Document,
	|	Table.PresentationCurrency,
	|	CASE
	|		WHEN Table.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -Table.AmountCur
	|		ELSE Table.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS Table
	|WHERE
	|	Table.Recorder = &Ref
	|	AND Table.Company = &Company
	|	AND Table.Counterparty = &CounterpartyByDefault
	|	AND Table.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|	AND CASE
	|			WHEN &ContractByDefault = VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|				THEN TRUE
	|			ELSE Table.Contract = &ContractByDefault
	|		END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_Table.Company AS Company,
	|	TT_Table.Counterparty AS Counterparty,
	|	TT_Table.Contract AS Contract,
	|	TT_Table.Document AS Document,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(TT_Table.AmountCur) AS AmountCur
	|INTO TT_TableGrouped
	|FROM
	|	TT_Table AS TT_Table
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON TT_Table.Contract = CounterpartyContracts.Ref
	|WHERE
	|	TT_Table.AmountCur < 0
	|
	|GROUP BY
	|	TT_Table.Company,
	|	TT_Table.Counterparty,
	|	TT_Table.Contract,
	|	TT_Table.Document,
	|	CounterpartyContracts.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	UNDEFINED AS Ref,
	|	DATETIME(1, 1, 1) AS Date,
	|	CAST("""" AS STRING(20)) AS Number,
	|	VALUE(Catalog.Companies.EmptyRef) AS Company,
	|	&CounterpartyByDefault AS Counterparty,
	|	&ContractByDefault AS Contract,
	|	&DirectDebitMandateByDefault AS DirectDebitMandate,
	|	0 AS Amount,
	|	&Currency AS Currency,
	|	UNDEFINED AS Type,
	|	0 AS DocumentStatus
	|WHERE
	|	FALSE
	|
	|UNION ALL
	|
	|SELECT
	|	TT_TableGrouped.Document,
	|	TT_TableGrouped.Document.Date,
	|	TT_TableGrouped.Document.Number,
	|	TT_TableGrouped.Company,
	|	TT_TableGrouped.Counterparty,
	|	TT_TableGrouped.Contract,
	|	VALUE(Catalog.DirectDebitMandates.EmptyRef),
	|	TT_TableGrouped.AmountCur,
	|	TT_TableGrouped.SettlementsCurrency,
	|	VALUETYPE(TT_TableGrouped.Document),
	|	1
	|FROM
	|	TT_TableGrouped AS TT_TableGrouped";
	
	If IsSupplierReturn Then
		QueryText = StrReplace(QueryText, "AccountsReceivable", "AccountsPayable");
		QueryText = StrReplace(QueryText, "&DocumentsType", "
		|					Document REFS Document.CashVoucher
		|					OR Document REFS Document.DebitNote
		|					OR Document REFS Document.PaymentExpense");
	Else
		QueryText = StrReplace(QueryText, "&DocumentsType", "
		|					Document REFS Document.CashReceipt
		|					OR Document REFS Document.PaymentReceipt
		|					OR Document REFS Document.CreditNote
		|					OR Document REFS Document.OnlineReceipt");
	EndIf;

	Return QueryText;
	
EndFunction

// Gets text for the credit note document.
//
&AtServerNoContext
Function GetQueryTextCreditNote(QueryText)
	
	If AccessRight("Read", Metadata.Documents.CreditNote) Then
		
		QueryText = QueryText + "UNION ALL";
		
		QueryText = QueryText +
		"
		|SELECT
		|	DocumentData.Ref,
		|	DocumentData.Date,
		|	DocumentData.Number,
		|	DocumentData.Company,
		|	DocumentData.Counterparty,
		|	DocumentData.Contract,
		|	&DirectDebitMandateByDefault,
		|	DocumentData.DocumentAmount,
		|	DocumentData.DocumentCurrency,
		|	VALUETYPE(DocumentData.Ref),
		|	CASE
		|		WHEN DocumentData.Posted
		|			THEN 1
		|		WHEN DocumentData.DeletionMark
		|			THEN 2
		|		ELSE 0
		|	END
		|FROM
		|	Document.CreditNote AS DocumentData
		|WHERE
		|	DocumentData.Posted";
		
	EndIf;
	
	If Left(QueryText, 10) = "UNION" Then
		QueryText = Mid(QueryText, 14);
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ThisIsAccountsReceivable = Parameters.ThisIsAccountsReceivable;
	
	ThisIsBankStatementProcessing = Parameters.Property("ThisIsBankStatementProcessing");
	ThisIsAdvancePaymentsReceived = Parameters.Property("ThisIsAdvancePaymentsReceived");
	ThisIsAdvancePaymentsIssued = Parameters.Property("ThisIsAdvancePaymentsIssued");
	ThisIsTaxInvoiceReceived = Parameters.Property("ThisIsTaxInvoiceReceived");
	ThisIsTaxInvoiceIssued = Parameters.Property("ThisIsTaxInvoiceIssued");
	ThisIsThirdPartyPayment = Parameters.Property("ThisIsThirdPartyPayment");
	
	IsCustomerReturn = False;
	If Parameters.Property("IsCustomerReturn") Then
		IsCustomerReturn = Parameters.IsCustomerReturn;
	EndIf;	
	IsSupplierReturn = False;
	If Parameters.Property("IsSupplierReturn") Then
		IsSupplierReturn = Parameters.IsSupplierReturn;
	EndIf;	
	
	DocumentType = Parameters.DocumentType;
	
	If IsCustomerReturn Or IsSupplierReturn Then
		
		List.QueryText = GetQueryTextReturnAdvances(IsSupplierReturn);
		
	ElsIf DocumentType = Type("DocumentRef.PaymentReceipt")
		OR DocumentType = Type("DocumentRef.CashReceipt") 
		OR DocumentType = Type("DocumentRef.DebitNote")
		OR DocumentType = Type("DocumentRef.DirectDebit") Then
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableReceipt();
		ElsIf ThisIsThirdPartyPayment Then
			List.QueryText = GetQueryTextAccountDocumentsOfThirdPartyPayment();
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableReceipt();
		EndIf;
		
	ElsIf DocumentType = Type("DocumentRef.OnlineReceipt") Then
		
		List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableReceipt(True);
		
	ElsIf DocumentType = Type("DocumentRef.OnlinePayment") Then
		
		If Parameters.Filter.AdvanceFlag Then
			List.QueryText = GetQueryTextAdvancePaymentsIssued();
		Else
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableReceipt(True);
		EndIf;
		
		List.QueryText = GetQueryTextCreditNote(List.QueryText);
	Else
		
		If ThisIsAccountsReceivable Then
			List.QueryText = GetQueryTextAccountDocumentsOfAccountsReceivableWriteOff();
			List.Parameters.SetParameterValue("SelectCreditNote", DocumentType <> Type("DocumentRef.CreditNote"));
		ElsIf ThisIsBankStatementProcessing Then
			List.QueryText = GetQueryTextDocumentForBankStatementProcessing();
		ElsIf ThisIsAdvancePaymentsReceived Then
			List.QueryText = GetQueryTextAdvancePaymentsReceived();
		ElsIf ThisIsAdvancePaymentsIssued Then
			List.QueryText = GetQueryTextAdvancePaymentsIssued();
		ElsIf ThisIsTaxInvoiceReceived Then
			List.QueryText = GetQueryTextTaxInvoiceReceived();
		ElsIf ThisIsTaxInvoiceIssued Then
			List.QueryText = GetQueryTextTaxInvoiceIssued();
		Else
			List.QueryText = GetQueryTextDocumentsOfAccountsPayableWriteOff();
		EndIf;
		
	EndIf;
	
	Items.Company.Visible = Not Parameters.Filter.Property("Company");
	Items.Employee.Visible = ThisIsTaxInvoiceReceived;
	
	If Parameters.Filter.Property("Counterparty") Then
		Items.Counterparty.Visible = True;
		List.Parameters.SetParameterValue("CounterpartyByDefault", Parameters.Filter.Counterparty);
	Else
		Items.Counterparty.Visible = False;
		List.Parameters.SetParameterValue("CounterpartyByDefault", Catalogs.Counterparties.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("Contract") Then
		List.Parameters.SetParameterValue("ContractByDefault", Parameters.Filter.Contract);
	Else
		List.Parameters.SetParameterValue("ContractByDefault", Catalogs.CounterpartyContracts.EmptyRef());
	EndIf;
	
	If Parameters.Filter.Property("DirectDebitMandate") Then
		List.Parameters.SetParameterValue("DirectDebitMandateByDefault", Parameters.Filter.DirectDebitMandate);
	Else
		List.Parameters.SetParameterValue("DirectDebitMandateByDefault", Catalogs.DirectDebitMandates.EmptyRef());
	EndIf; 
	
	If Parameters.Filter.Property("Currency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.Currency);
	ElsIf Parameters.Filter.Property("DocumentCurrency") Then
		List.Parameters.SetParameterValue("Currency", Parameters.Filter.DocumentCurrency);
	Else
		List.Parameters.SetParameterValue("Currency", Catalogs.Currencies.EmptyRef());
	EndIf;
	
	If IsCustomerReturn Or IsSupplierReturn  Then
		If Parameters.Property("Document") Then
			List.Parameters.SetParameterValue("Ref", Parameters.Document);
		EndIf;
		
		If Parameters.Filter.Property("Company") Then
			List.Parameters.SetParameterValue("Company", Parameters.Filter.Company);
		EndIf;
	EndIf;
	
	//Conditional appearance
	SetConditionalAppearance();
	
EndProcedure

#EndRegion

#Region ActionsOfTheFormCommandPanels

// The procedure is called when clicking button "Select".
//
&AtClient
Procedure ChooseDocument(Command)
	
	CurrentData = Items.List.CurrentData;
	If CurrentData <> Undefined Then
		
		DocumentData = New Structure;
		DocumentData.Insert("Document", CurrentData.Ref);
		DocumentData.Insert("Contract", CurrentData.Contract);
		
		Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
		DocumentData.Insert("Order", Order);
		
		NotifyChoice(DocumentData);
	Else
		Close();
	EndIf;
	
EndProcedure

// The procedure is called when clicking button "Open document".
//
&AtClient
Procedure OpenDocument(Command)
	
	TableRow = Items.List.CurrentData;
	If TableRow <> Undefined Then
		ShowValue(Undefined,TableRow.Ref);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormFieldEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentData = Items.List.CurrentData;
	
	DocumentData = New Structure;
	DocumentData.Insert("Document", CurrentData.Ref);
	DocumentData.Insert("Contract", CurrentData.Contract);
	
	Order = GetOrder(CurrentData.Ref, ThisIsAccountsReceivable);
	DocumentData.Insert("Order", Order);
	
	NotifyChoice(DocumentData);
	
EndProcedure

#EndRegion

#Region Private

// Procedure set conditional appearance
//
&AtServer
Procedure SetConditionalAppearance()
	
	//List
	ItemAppearance = ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add((Type("DataCompositionFilterItem")));
	DataFilterItem.LeftValue		= New DataCompositionField("List.DocumentStatus");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.NotEqual;
	DataFilterItem.RightValue		= 0;
	DataFilterItem.Use				= True;
	
	ColorBlack = StyleColors.BusinessCalendarDayKindWorkdayColor;
	ItemAppearance.Appearance.SetParameterValue("TextColor", ColorBlack);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("List");
	FieldAppearance.Use = True;
	
EndProcedure

#EndRegion