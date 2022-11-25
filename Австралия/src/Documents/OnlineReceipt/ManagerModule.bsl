#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region IncomeAndExpenseItemsInDocuments

Function GetIncomeAndExpenseItemsStructure(StructureData) Export
	
	IncomeAndExpenseStructure = New Structure;
	Return IncomeAndExpenseStructure;
	
EndFunction

Function GetIncomeAndExpenseItemsGLAMap(StructureData) Export

	Return New Structure;
	
EndFunction

#EndRegion

#Region GLAccounts

Function GetGLAccountsStructure(StructureData) Export

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	GLAccountsForFilling.Insert("AccountsReceivableGLAccount", StructureData.AccountsReceivableGLAccount);
	GLAccountsForFilling.Insert("AdvancesReceivedGLAccount", StructureData.AdvancesReceivedGLAccount);
	
	If StructureData.Property("ExistsEPD")
		And StructureData.ExistsEPD <> Undefined
		And StructureData.ExistsEPD Then
		
		GLAccountsForFilling.Insert("DiscountAllowedGLAccount", StructureData.DiscountAllowedGLAccount);
		
		If StructureData.EPDAmount > 0
			And StructureData.Property("Document")
			And ValueIsFilled(StructureData.Document)
			And TypeOf(StructureData.Document) = Type("DocumentRef.SalesInvoice") Then
			
			ProvideEPD = Common.ObjectAttributeValue(StructureData.Document, "ProvideEPD");
			If ProvideEPD = Enums.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment Then
				GLAccountsForFilling.Insert("VATOutputGLAccount", StructureData.VATOutputGLAccount);
			EndIf;
		EndIf;
		
	EndIf;
	
	Return GLAccountsForFilling;
	
EndFunction

#EndRegion

#Region LibrariesHandlers

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	Var Errors;
	
	If PrintManagement.TemplatePrintRequired(PrintFormsCollection, "AdvancePaymentInvoice") Then
		
		OnlineReceiptArray	= New Array;
		TaxInvoiceArray		= New Array;
		
		For Each PrintObject In ObjectsArray Do
			
			If Not WorkWithVAT.GetPostAdvancePaymentsBySourceDocuments(PrintObject.Date, PrintObject.Company) Then
				
				TaxInvoice = Documents.TaxInvoiceIssued.GetTaxInvoiceIssued(PrintObject);
				If ValueIsFilled(TaxInvoice) Then
					
					TaxInvoiceArray.Add(TaxInvoice);
					
				Else
					
					PrintManagement.OutputSpreadsheetDocumentToCollection(
						PrintFormsCollection,
						"AdvancePaymentInvoice",
						NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago adelantado';es_CO = 'Factura del pago adelantado';tr = 'Avans ödeme faturası';it = 'Fattura di pagamento anticipato';de = 'Vorauszahlungsrechnung'"), 
						New SpreadsheetDocument);
						
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'From %1, generate ""Tax invoice issued"" with operation ""Advance payment"". Then try again.'; ru = 'От %1 создайте ""Налоговый инвойс выданный"" с операцией ""Авансовый платеж"". Затем попробуйте еще раз.';pl = 'Z %1, wygeneruj ""Fakturę VAT wystawioną"" z operacją ""Zaliczka"". Następnie spróbuj ponownie.';es_ES = 'Desde %1, genere la ""Factura de impuestos emitida"" con la operación "" Pago adelantado"". A continuación, inténtelo de nuevo.';es_CO = 'Desde %1, genere la ""Factura de impuestos emitida"" con la operación "" Pago adelantado"". A continuación, inténtelo de nuevo.';tr = '%1 öğesinden, ""Avans ödeme"" işlemli ""Düzenlenen vergi faturası"" oluşturup tekrar deneyin.';it = 'Da %1 generare ""Fattura fiscale emessa"" con l''operazione ""Pagamento anticipato"", poi riprovare.';de = 'Aus %1, generieren Sie ""Steuerrechnung ausgestellt"" mit der Operation ""Vorauszahlung"". dann versuchen Sie es erneut.'"),
						PrintObject);
					
					CommonClientServer.AddUserError(Errors,, MessageText, Undefined);
					
					Continue;
					
				EndIf;
				
			Else
				
				OnlineReceiptArray.Add(PrintObject);
				
			EndIf;
			
		EndDo;
		
		If OnlineReceiptArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				OnlineReceiptArray,
				PrintObjects, 
				"AdvancePaymentInvoice",, PrintParameters.Result);
			
		EndIf;
		
		If TaxInvoiceArray.Count() > 0 Then
			
			SpreadsheetDocument = DataProcessors.PrintAdvancePaymentInvoice.PrintForm(
				TaxInvoiceArray,
				PrintObjects, 
				"AdvancePaymentInvoice",
				SpreadsheetDocument, PrintParameters.Result);
			
		EndIf;
		
		If OnlineReceiptArray.Count() > 0 Or TaxInvoiceArray.Count() > 0 Then
			
			PrintManagement.OutputSpreadsheetDocumentToCollection(
				PrintFormsCollection,
				"AdvancePaymentInvoice",
				NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago adelantado';es_CO = 'Factura del pago adelantado';tr = 'Avans ödeme faturası';it = 'Fattura di pagamento anticipato';de = 'Vorauszahlungsrechnung'"),
				SpreadsheetDocument);
			
		EndIf;
		
	EndIf;
	
	If Errors <> Undefined Then
		CommonClientServer.ReportErrorsToUser(Errors);
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendOptions, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "AdvancePaymentInvoice";
	PrintCommand.Presentation				= NStr("en = 'Advance payment invoice'; ru = 'Инвойс на аванс';pl = 'Faktura zaliczkowa';es_ES = 'Factura del pago adelantado';es_CO = 'Factura del pago adelantado';tr = 'Avans ödeme faturası';it = 'Fattura di pagamento anticipato';de = 'Vorauszahlungsrechnung'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region ObjectVersioning

// StandardSubsystems.ObjectVersioning

Procedure OnDefineObjectVersioningSettings(Settings) Export

EndProcedure

// End StandardSubsystems.ObjectVersioning

#EndRegion

#EndRegion

Procedure InitializeDocumentData(DocumentRef, StructureAdditionalProperties) Export
	
	Query = New Query;
	
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	DocumentAttributes = Common.ObjectAttributesValues(DocumentRef, "CashCurrency, Date");
	StructureAdditionalProperties.Insert("DocumentAttributes", DocumentAttributes);
	
	Query.SetParameter("Ref", DocumentRef);
	Query.SetParameter("PointInTime",
		New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency", StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("CashCurrency", StructureAdditionalProperties.DocumentAttributes.CashCurrency);
	Query.SetParameter("ExchangeRateMethod", StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	Query.SetParameter("FeeExpensesGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
	Query.SetParameter("FeeProcessorDebtGLAccount", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("AccountsPayable"));
	Query.SetParameter("UseDefaultTypeOfAccounting", GetFunctionalOption("UseDefaultTypeOfAccounting"));
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("ContentPaymentProcessorFee", NStr("en = 'Payment processor fee'; ru = 'Комиссия платежной системы';pl = 'Prowizja systemu płatności';es_ES = 'Tasa del procesador de pagos';es_CO = 'Tasa del procesador de pagos';tr = 'Ödeme işlemcisi ücreti';it = 'Commissione elaboratore pagamenti';de = 'Gebühr des Zahlungsanbieters'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO TemporaryTableExchangeRateSliceLatest
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(
	|			&PointInTime,
	|			Currency IN (&PresentationCurrency, &CashCurrency)
	|				AND Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS LineNumber,
	|	DocumentTable.OperationKind AS OperationKind,
	|	DocumentTable.Date AS Date,
	|	&Company AS Company,
	|	DocumentTable.CompanyVATNumber AS CompanyVATNumber,
	|	&PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.CashCurrency AS CashCurrency,
	|	DocumentTable.Ref AS Ref,
	|	DocumentTable.Counterparty AS Counterparty,
	|	&FundsTransfersBeingProcessedGLAccount AS FundsTransfersBeingProcessedGLAccount,
	|	&FeeExpensesGLAccount AS FeeExpensesGLAccount,
	|	&FeeProcessorDebtGLAccount AS FeeProcessorDebtGLAccount,
	|	CASE
	|		WHEN POSTerminals.WithholdFeeOnPayout
	|			THEN VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|		ELSE DocumentTable.ExpenseItem
	|	END AS ExpenseItem,
	|	DocumentTable.FeeTotal AS FeeTotal,
	|	CAST(DocumentTable.FeeTotal * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN 1 / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRateSliceLast.Multiplicity / (AccountingExchangeRateSliceLast.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|		END AS NUMBER(15, 2)) AS FeeTotalPC,
	|	DocumentTable.POSTerminal AS POSTerminal,
	|	POSTerminals.WithholdFeeOnPayout AS WithholdFeeOnPayout,
	|	POSTerminals.PaymentProcessor AS PaymentProcessor,
	|	POSTerminals.PaymentProcessorContract AS PaymentProcessorContract,
	|	POSTerminals.BusinessLine AS FeeBusinessLine,
	|	POSTerminals.Department AS FeeDepartment,
	|	&ContentPaymentProcessorFee AS ContentPaymentProcessorFee
	|INTO TemporaryTableHeader
	|FROM
	|	Document.OnlineReceipt AS DocumentTable
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRateSliceLast
	|		ON (AccountingExchangeRateSliceLast.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRateSliceLatest AS BankAcountExchangeRate
	|		ON (BankAcountExchangeRate.Currency = &CashCurrency)
	|		LEFT JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocumentTable.POSTerminal = POSTerminals.Ref
	|WHERE
	|	DocumentTable.Ref = &Ref
	|	AND DocumentTable.PaymentStatus = VALUE(Enum.PaymentStatuses.Succeeded)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(DocumentTable.LineNumber) AS LineNumber,
	|	TemporaryTableHeader.CashCurrency AS CashCurrency,
	|	DocumentTable.Document AS Document,
	|	TemporaryTableHeader.OperationKind AS OperationKind,
	|	TemporaryTableHeader.Counterparty AS Counterparty,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AccountsReceivableGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS GLAccountCustomerSettlements,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.AdvancesReceivedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS CustomerAdvancesGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.DiscountAllowedGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS DiscountAllowedGLAccount,
	|	CASE
	|		WHEN &UseDefaultTypeOfAccounting
	|			THEN DocumentTable.VATOutputGLAccount
	|		ELSE VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef)
	|	END AS VATOutputGLAccount,
	|	DocumentTable.Contract AS Contract,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	DocumentTable.Item AS Item,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END AS Order,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	TemporaryTableHeader.Date AS Date,
	|	DocumentTable.Ref AS Ref,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.PaymentAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.PaymentAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AccountingAmount,
	|	SUM(DocumentTable.SettlementsAmount) AS SettlementsAmount,
	|	SUM(DocumentTable.PaymentAmount) AS PaymentAmount,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.EPDAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.EPDAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AccountingEPDAmount,
	|	SUM(DocumentTable.SettlementsEPDAmount) AS SettlementsEPDAmount,
	|	SUM(DocumentTable.EPDAmount) AS EPDAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.VATAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.VATAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS VATAmount,
	|	SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.PaymentAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.PaymentAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) - SUM(CAST(CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN DocumentTable.VATAmount * BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity)
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN DocumentTable.VATAmount / (BankAcountExchangeRate.ExchangeRate * AccountingExchangeRate.Multiplicity / (AccountingExchangeRate.ExchangeRate * BankAcountExchangeRate.Multiplicity))
	|			END AS NUMBER(15, 2))) AS AmountExcludesVAT,
	|	TemporaryTableHeader.Company AS Company,
	|	TemporaryTableHeader.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTableHeader.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableHeader.POSTerminal AS POSTerminal,
	|	TemporaryTableHeader.WithholdFeeOnPayout AS WithholdFeeOnPayout,
	|	TemporaryTableHeader.PaymentProcessor AS PaymentProcessor,
	|	TemporaryTableHeader.PaymentProcessorContract AS PaymentProcessorContract,
	|	TemporaryTableHeader.FeeTotal AS FeeTotal,
	|	TemporaryTableHeader.FeeTotalPC AS FeeTotalPC
	|INTO TemporaryTablePaymentDetailsPre
	|FROM
	|	TemporaryTableHeader AS TemporaryTableHeader
	|		INNER JOIN Document.OnlineReceipt.PaymentDetails AS DocumentTable
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS AccountingExchangeRate
	|			ON (AccountingExchangeRate.Currency = &PresentationCurrency)
	|			LEFT JOIN TemporaryTableExchangeRateSliceLatest AS BankAcountExchangeRate
	|			ON (BankAcountExchangeRate.Currency = &CashCurrency)
	|			LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			ON DocumentTable.Contract = CounterpartyContracts.Ref
	|		ON TemporaryTableHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON TemporaryTableHeader.Counterparty = Counterparties.Ref
	|
	|GROUP BY
	|	DocumentTable.Document,
	|	DocumentTable.Contract,
	|	DocumentTable.AdvanceFlag,
	|	DocumentTable.Ref,
	|	DocumentTable.AccountsReceivableGLAccount,
	|	DocumentTable.AdvancesReceivedGLAccount,
	|	DocumentTable.VATRate,
	|	DocumentTable.DiscountAllowedGLAccount,
	|	DocumentTable.VATOutputGLAccount,
	|	TemporaryTableHeader.CashCurrency,
	|	TemporaryTableHeader.OperationKind,
	|	TemporaryTableHeader.Counterparty,
	|	CASE
	|		WHEN DocumentTable.Order = UNDEFINED
	|				OR DocumentTable.Order = VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE DocumentTable.Order
	|	END,
	|	TemporaryTableHeader.Date,
	|	TemporaryTableHeader.Company,
	|	TemporaryTableHeader.CompanyVATNumber,
	|	TemporaryTableHeader.PresentationCurrency,
	|	CounterpartyContracts.SettlementsCurrency,
	|	Counterparties.DoOperationsByContracts,
	|	Counterparties.DoOperationsByOrders,
	|	DocumentTable.Item,
	|	TemporaryTableHeader.POSTerminal,
	|	TemporaryTableHeader.WithholdFeeOnPayout,
	|	TemporaryTableHeader.PaymentProcessor,
	|	TemporaryTableHeader.PaymentProcessorContract,
	|	TemporaryTableHeader.FeeTotal,
	|	TemporaryTableHeader.FeeTotalPC
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTable.Company AS Company,
	|	TemporaryTable.CompanyVATNumber AS CompanyVATNumber,
	|	TemporaryTable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTable.LineNumber AS LineNumber,
	|	TemporaryTable.CashCurrency AS CashCurrency,
	|	TemporaryTable.Document AS Document,
	|	TemporaryTable.OperationKind AS OperationKind,
	|	TemporaryTable.Counterparty AS Counterparty,
	|	TemporaryTable.DoOperationsByContracts AS DoOperationsByContracts,
	|	TemporaryTable.DoOperationsByOrders AS DoOperationsByOrders,
	|	&FundsTransfersBeingProcessedGLAccount AS FundsTransfersBeingProcessedGLAccount,
	|	TemporaryTable.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	TemporaryTable.CustomerAdvancesGLAccount AS CustomerAdvancesGLAccount,
	|	TemporaryTable.DiscountAllowedGLAccount AS DiscountAllowedGLAccount,
	|	TemporaryTable.VATOutputGLAccount AS VATOutputGLAccount,
	|	TemporaryTable.Contract AS Contract,
	|	TemporaryTable.SettlementsCurrency AS SettlementsCurrency,
	|	TemporaryTable.Item AS Item,
	|	TemporaryTable.Order AS Order,
	|	TemporaryTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN TemporaryTable.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	TemporaryTable.Date AS Date,
	|	TemporaryTable.Ref AS Ref,
	|	TemporaryTable.AccountingAmount AS AccountingAmount,
	|	TemporaryTable.SettlementsAmount AS SettlementsAmount,
	|	TemporaryTable.PaymentAmount AS PaymentAmount,
	|	TemporaryTable.AccountingEPDAmount AS AccountingEPDAmount,
	|	TemporaryTable.SettlementsEPDAmount AS SettlementsEPDAmount,
	|	TemporaryTable.EPDAmount AS EPDAmount,
	|	CAST(TemporaryTable.AccountingEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS AccountingEPDAmountExclVAT,
	|	CAST(TemporaryTable.SettlementsEPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS SettlementsEPDAmountExclVAT,
	|	CAST(TemporaryTable.EPDAmount / (ISNULL(VATRates.Rate, 0) + 100) * 100 AS NUMBER(15, 2)) AS EPDAmountExclVAT,
	|	TemporaryTable.VATRate AS VATRate,
	|	TemporaryTable.VATAmount AS VATAmount,
	|	TemporaryTable.AmountExcludesVAT AS AmountExcludesVAT,
	|	TemporaryTable.POSTerminal AS POSTerminal,
	|	TemporaryTable.WithholdFeeOnPayout AS WithholdFeeOnPayout,
	|	TemporaryTable.PaymentProcessor AS PaymentProcessor,
	|	TemporaryTable.PaymentProcessorContract AS PaymentProcessorContract,
	|	TemporaryTable.FeeTotal AS FeeTotal,
	|	TemporaryTable.FeeTotalPC AS FeeTotalPC
	|INTO TemporaryTablePaymentDetails
	|FROM
	|	TemporaryTablePaymentDetailsPre AS TemporaryTable
	|		LEFT JOIN Catalog.VATRates AS VATRates
	|		ON TemporaryTable.VATRate = VATRates.Ref";
	
	Query.Execute();
	
	GenerateTableCustomerAccounts(DocumentRef, StructureAdditionalProperties);
	GenerateTableFundsTransfersBeingProcessed(DocumentRef, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties);
	GenerateTableInvoicesAndOrdersPayment(DocumentRef, StructureAdditionalProperties);
	GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties);
	GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties);
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties);

	If StructureAdditionalProperties.AccountingPolicy.UseDefaultTypeOfAccounting Then
		GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
	EndIf;
	
	FinancialAccounting.FillExtraDimensions(DocumentRef, StructureAdditionalProperties);
	
	If StructureAdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		
		AccountingTemplatesPosting.GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		AccountingTemplatesPosting.GenerateTableMasterAccountingJournalEntries(DocumentRef, StructureAdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not Constants.CheckStockBalanceOnPosting.Get() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables contain records, it is
	// necessary to execute negative balance control.
	If StructureTemporaryTables.RegisterRecordsAccountsReceivableChange
		Or StructureTemporaryTables.RegisterRecordsFundsTransfersBeingProcessedChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsAccountsReceivableChange.LineNumber AS LineNumber,
		|	RegisterRecordsAccountsReceivableChange.Company AS CompanyPresentation,
		|	RegisterRecordsAccountsReceivableChange.PresentationCurrency AS PresentationCurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Counterparty AS CounterpartyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract AS ContractPresentation,
		|	RegisterRecordsAccountsReceivableChange.Contract.SettlementsCurrency AS CurrencyPresentation,
		|	RegisterRecordsAccountsReceivableChange.Document AS DocumentPresentation,
		|	RegisterRecordsAccountsReceivableChange.Order AS OrderPresentation,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS CalculationsTypesPresentation,
		|	TRUE AS RegisterRecordsOfCashDocuments,
		|	RegisterRecordsAccountsReceivableChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsAccountsReceivableChange.AmountChange AS AmountChange,
		|	RegisterRecordsAccountsReceivableChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange AS SumCurChange,
		|	RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS DebtBalanceAmount,
		|	-(RegisterRecordsAccountsReceivableChange.SumCurChange + ISNULL(AccountsReceivableBalances.AmountCurBalance, 0)) AS AmountOfOutstandingAdvances,
		|	ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsAccountsReceivableChange.SettlementsType AS SettlementsType
		|FROM
		|	RegisterRecordsAccountsReceivableChange AS RegisterRecordsAccountsReceivableChange
		|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(&ControlTime, ) AS AccountsReceivableBalances
		|		ON RegisterRecordsAccountsReceivableChange.Company = AccountsReceivableBalances.Company
		|			AND RegisterRecordsAccountsReceivableChange.PresentationCurrency = AccountsReceivableBalances.PresentationCurrency
		|			AND RegisterRecordsAccountsReceivableChange.Counterparty = AccountsReceivableBalances.Counterparty
		|			AND RegisterRecordsAccountsReceivableChange.Contract = AccountsReceivableBalances.Contract
		|			AND RegisterRecordsAccountsReceivableChange.Document = AccountsReceivableBalances.Document
		|			AND RegisterRecordsAccountsReceivableChange.Order = AccountsReceivableBalances.Order
		|			AND RegisterRecordsAccountsReceivableChange.SettlementsType = AccountsReceivableBalances.SettlementsType
		|WHERE
		|	CASE
		|			WHEN RegisterRecordsAccountsReceivableChange.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) > 0
		|			ELSE ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) < 0
		|		END
		|
		|ORDER BY
		|	LineNumber");
		
		Query.Text = Query.Text + DriveClientServer.GetQueryDelimeter();
		Query.Text = Query.Text + AccumulationRegisters.FundsTransfersBeingProcessed.BalancesControlQueryText();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty() Then
			DocObject = DocumentRef.GetObject()
		EndIf;
		
		// Negative balance on accounts receivable.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocObject, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on FundsTransfersBeingProcessed
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToFundsTransfersBeingProcessed(DocObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

Function DocumentVATRate(DocumentRef) Export
	
	Parameters = New Structure;
	Parameters.Insert("TableName", "PaymentDetails");
	
	Return DriveServer.DocumentVATRate(DocumentRef, Parameters);
	
EndFunction

#EndRegion

#Region Internal

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

Procedure GenerateTableCustomerAccounts(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",                           DocumentRef);
	Query.SetParameter("PointInTime",                   New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",                 StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",                       StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency",          StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("AppearenceOfCustomerAdvance",   NStr("en = 'Advance payment from customer'; ru = 'Аванс покупателя';pl = 'Zaliczka od nabywcy';es_ES = 'El pago del anticipo por el cliente';es_CO = 'El pago del anticipo por el cliente';tr = 'Müşteriden alınan avans ödeme';it = 'Pagamento anticipato da parte del cliente';de = 'Vorauszahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("CustomerObligationsRepayment",  NStr("en = 'Payment from customer'; ru = 'Оплата от покупателя';pl = 'Płatność od nabywcy';es_ES = 'Pago del cliente';es_CO = 'Pago del cliente';tr = 'Müşteriden ödeme';it = 'Pagamento dal cliente';de = 'Zahlung vom Kunden'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",          NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",            NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ExchangeRateMethod",			StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	
	Query.Text =
	"SELECT
	|	FALSE AS IsEPD,
	|	TemporaryTablePaymentDetails.LineNumber AS LineNumber,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END AS Document,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END AS ContentOfAccountingRecord,
	|	&Company AS Company,
	|	&PresentationCurrency AS PresentationCurrency,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTablePaymentDetails.Counterparty AS Counterparty,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END AS GLAccount,
	|	TemporaryTablePaymentDetails.FundsTransfersBeingProcessedGLAccount AS FundsTransfersBeingProcessedGLAccount,
	|	TemporaryTablePaymentDetails.Contract AS Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency AS Currency,
	|	TemporaryTablePaymentDetails.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	TemporaryTablePaymentDetails.Date AS Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END AS SettlementsType,
	|	SUM(TemporaryTablePaymentDetails.PaymentAmount) AS PaymentAmount,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS Amount,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCur,
	|	-SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForBalance,
	|	-SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountCurForBalance,
	|	SUM(TemporaryTablePaymentDetails.AccountingAmount) AS AmountForPayment,
	|	SUM(TemporaryTablePaymentDetails.SettlementsAmount) AS AmountForPaymentCur,
	|	TemporaryTablePaymentDetails.POSTerminal AS POSTerminal,
	|	TemporaryTablePaymentDetails.WithholdFeeOnPayout AS WithholdFeeOnPayout,
	|	TemporaryTablePaymentDetails.PaymentProcessor AS PaymentProcessor,
	|	TemporaryTablePaymentDetails.PaymentProcessorContract AS PaymentProcessorContract,
	|	TemporaryTablePaymentDetails.FeeTotal AS FeeTotal,
	|	TemporaryTablePaymentDetails.FeeTotalPC AS FeeTotalPC
	|INTO TemporaryTableAccountsReceivable
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &Ref
	|		ELSE TemporaryTablePaymentDetails.Document
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN &AppearenceOfCustomerAdvance
	|		ELSE &CustomerObligationsRepayment
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN TemporaryTablePaymentDetails.CustomerAdvancesGLAccount
	|		ELSE TemporaryTablePaymentDetails.GLAccountCustomerSettlements
	|	END,
	|	TemporaryTablePaymentDetails.FundsTransfersBeingProcessedGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.AdvanceFlag
	|			THEN VALUE(Enum.SettlementsTypes.Advance)
	|		ELSE VALUE(Enum.SettlementsTypes.Debt)
	|	END,
	|	TemporaryTablePaymentDetails.POSTerminal,
	|	TemporaryTablePaymentDetails.WithholdFeeOnPayout,
	|	TemporaryTablePaymentDetails.PaymentProcessor,
	|	TemporaryTablePaymentDetails.PaymentProcessorContract,
	|	TemporaryTablePaymentDetails.FeeTotal,
	|	TemporaryTablePaymentDetails.FeeTotalPC
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Document,
	|	&EarlyPaymentDiscount,
	|	&Company,
	|	&PresentationCurrency,
	|	VALUE(AccumulationRecordType.Receipt),
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.FundsTransfersBeingProcessedGLAccount,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.Date,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	-SUM(TemporaryTablePaymentDetails.EPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.AccountingEPDAmount),
	|	-SUM(TemporaryTablePaymentDetails.SettlementsEPDAmount),
	|	TemporaryTablePaymentDetails.POSTerminal,
	|	TemporaryTablePaymentDetails.WithholdFeeOnPayout,
	|	TemporaryTablePaymentDetails.PaymentProcessor,
	|	TemporaryTablePaymentDetails.PaymentProcessorContract,
	|	TemporaryTablePaymentDetails.FeeTotal,
	|	TemporaryTablePaymentDetails.FeeTotalPC
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.LineNumber,
	|	TemporaryTablePaymentDetails.Counterparty,
	|	TemporaryTablePaymentDetails.Contract,
	|	TemporaryTablePaymentDetails.SettlementsCurrency,
	|	TemporaryTablePaymentDetails.CashCurrency,
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.Document,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	TemporaryTablePaymentDetails.FundsTransfersBeingProcessedGLAccount,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DoOperationsByOrders
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|				AND TemporaryTablePaymentDetails.Order <> VALUE(Document.WorkOrder.EmptyRef)
	|			THEN TemporaryTablePaymentDetails.Order
	|		ELSE UNDEFINED
	|	END,
	|	TemporaryTablePaymentDetails.POSTerminal,
	|	TemporaryTablePaymentDetails.WithholdFeeOnPayout,
	|	TemporaryTablePaymentDetails.PaymentProcessor,
	|	TemporaryTablePaymentDetails.PaymentProcessorContract,
	|	TemporaryTablePaymentDetails.FeeTotal,
	|	TemporaryTablePaymentDetails.FeeTotalPC
	|
	|INDEX BY
	|	Company,
	|	PresentationCurrency,
	|	Counterparty,
	|	Contract,
	|	Currency,
	|	Document,
	|	Order,
	|	SettlementsType,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting the exclusive lock for the controlled balances of accounts receivable.
	Query.Text =
	"SELECT
	|	TemporaryTableAccountsReceivable.Company AS Company,
	|	TemporaryTableAccountsReceivable.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableAccountsReceivable.Counterparty AS Counterparty,
	|	TemporaryTableAccountsReceivable.Contract AS Contract,
	|	TemporaryTableAccountsReceivable.Document AS Document,
	|	TemporaryTableAccountsReceivable.Order AS Order,
	|	TemporaryTableAccountsReceivable.SettlementsType AS SettlementsType
	|FROM
	|	TemporaryTableAccountsReceivable AS TemporaryTableAccountsReceivable";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.AccountsReceivable");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextCurrencyExchangeRateAccountsReceivable(Query.TempTablesManager, False, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountsReceivable", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref", 							DocumentRef);
	Query.SetParameter("Company", 						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency", 			StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("PointInTime", 					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("FXIncomeItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXIncome"));
	Query.SetParameter("FXExpenseItem",					Catalogs.DefaultIncomeAndExpenseItems.GetItem("FXExpenses"));
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	UNDEFINED AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END AS GLAccount,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END AS IncomeAndExpenseItem,
	|	&ExchangeDifference AS ContentOfAccountingRecord,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END AS AmountIncome,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END AS AmountExpense,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	SalesInvoice.Department,
	|	CASE
	|		WHEN DocumentTable.Order = VALUE(Document.SalesOrder.EmptyRef)
	|				OR DocumentTable.Order = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE DocumentTable.Order
	|	END,
	|	UNDEFINED,
	|	DocumentTable.DiscountAllowedGLAccount,
	|	VALUE(Catalog.IncomeAndExpenseItems.EmptyRef),
	|	&EarlyPaymentDiscount,
	|	0,
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN DocumentTable.AccountingEPDAmountExclVAT
	|			ELSE DocumentTable.AccountingEPDAmount
	|		END),
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	SalesInvoice.Department,
	|	DocumentTable.Order,
	|	DocumentTable.DiscountAllowedGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	DocumentTable.PresentationCurrency,
	|	UNDEFINED,
	|	UNDEFINED,
	|	VALUE(Catalog.LinesOfBusiness.Other),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &FXIncomeItem
	|		ELSE &FXExpenseItem
	|	END,
	|	&ExchangeDifference,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN 0
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	1,
	|	DocumentTable.Date,
	|	&Company,
	|	&PresentationCurrency,
	|	DocumentTable.FeeDepartment,
	|	UNDEFINED,
	|	DocumentTable.FeeBusinessLine,
	|	DocumentTable.FeeExpensesGLAccount,
	|	DocumentTable.ExpenseItem,
	|	DocumentTable.ContentPaymentProcessorFee,
	|	0,
	|	DocumentTable.FeeTotalPC,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	NOT DocumentTable.WithholdFeeOnPayout
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRef, StructureAdditionalProperties)
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonClientServer.DefaultLanguageCode();
	
	Query.SetParameter("Ref",							DocumentRef);
	Query.SetParameter("Company",						StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",					New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ExchangeDifference",			NStr("en = 'Foreign currency exchange gains and losses'; ru = 'Прибыли и убытки от курсовой разницы';pl = 'Zyski i straty z tytułu wymiany waluty obcej';es_ES = 'Ganancias y pérdidas del cambio de la moneda extranjera';es_CO = 'Ganancias y pérdidas del cambio de la moneda extranjera';tr = 'Döviz alım-satımından kaynaklanan kâr ve zarar';it = 'Utili e perdite del cambio in valuta estera';de = 'Wechselkursgewinne und -verluste'", MainLanguageCode));
	Query.SetParameter("ForeignCurrencyExchangeGain",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeGain")); 
	Query.SetParameter("ForeignCurrencyExchangeLoss",	Catalogs.DefaultGLAccounts.GetDefaultGLAccount("ForeignCurrencyExchangeLoss"));
	Query.SetParameter("ContentVATOnAdvance",			NStr("en = 'VAT on advance'; ru = 'НДС с авансов';pl = 'VAT z zaliczek';es_ES = 'IVA del anticipo';es_CO = 'IVA del anticipo';tr = 'Avans KDV''si';it = 'IVA sull''anticipo';de = 'USt. auf Vorauszahlung'", MainLanguageCode));
	Query.SetParameter("ContentVAT",					NStr("en = 'VAT'; ru = 'НДС';pl = 'VAT';es_ES = 'IVA';es_CO = 'IVA';tr = 'KDV';it = 'IVA';de = 'USt.'", MainLanguageCode));
	Query.SetParameter("EarlyPaymentDiscount",			NStr("en = 'Early payment discount'; ru = 'Скидка за досрочную оплату';pl = 'Skonto';es_ES = 'Descuento por pronto pago';es_CO = 'Descuento por pronto pago';tr = 'Erken ödeme indirimi';it = 'Sconto per pagamento anticipato';de = 'Skonto'", MainLanguageCode));
	Query.SetParameter("ContentComissionWithhold",		NStr("en = 'Commission deducted'; ru = 'Комиссия удержана';pl = 'Potrącono prowizję';es_ES = 'Comisión deducida';es_CO = 'Comisión deducida';tr = 'Komisyon düşülür';it = 'Commissione dedotta';de = 'Provisionszahlung abgezogen'", MainLanguageCode));
	Query.SetParameter("VATAdvancesFromCustomers",		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATAdvancesFromCustomers"));
	Query.SetParameter("VATOutput",						Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
	Query.SetParameter("RegisteredForVAT",				StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT);
	Query.SetParameter("PostAdvancePaymentsBySourceDocuments", StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments);
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.FundsTransfersBeingProcessedGLAccount AS AccountDr,
	|	DocumentTable.GLAccount AS AccountCr,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END AS CurrencyDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END AS CurrencyCr,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.PaymentAmount
	|		ELSE 0
	|	END AS AmountCurDr,
	|	CASE
	|		WHEN DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.AmountCur
	|		ELSE 0
	|	END AS AmountCurCr,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.ContentOfAccountingRecord AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.IsEPD
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.GLAccount
	|		ELSE &ForeignCurrencyExchangeLoss
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN &ForeignCurrencyExchangeGain
	|		ELSE DocumentTable.GLAccount
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences < 0
	|				AND DocumentTable.GLAccount.Currency
	|			THEN DocumentTable.Currency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	0,
	|	CASE
	|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
	|			THEN DocumentTable.AmountOfExchangeDifferences
	|		ELSE -DocumentTable.AmountOfExchangeDifferences
	|	END,
	|	&ExchangeDifference,
	|	FALSE
	|FROM
	|	TemporaryTableExchangeRateDifferencesFundsTransfersBeingProcessed AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	4,
	|	1,
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
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.OperationKind = VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|	AND &PostAdvancePaymentsBySourceDocuments
	|	AND DocumentTable.AdvanceFlag
	|	AND &RegisteredForVAT
	|	AND DocumentTable.VATAmount <> 0
	|
	|GROUP BY
	|	DocumentTable.Date,
	|	DocumentTable.Company
	|
	|UNION ALL
	|
	|SELECT
	|	5,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.DiscountAllowedGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.EPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.EPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN CASE
	|						WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|							THEN TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|						ELSE TemporaryTablePaymentDetails.SettlementsEPDAmount
	|					END
	|			ELSE 0
	|		END),
	|	SUM(CASE
	|			WHEN SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment)
	|				THEN TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT
	|			ELSE TemporaryTablePaymentDetails.AccountingEPDAmount
	|		END),
	|	&EarlyPaymentDiscount,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.DiscountAllowedGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.DiscountAllowedGLAccount.Currency
	|			THEN TemporaryTablePaymentDetails.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	6,
	|	1,
	|	TemporaryTablePaymentDetails.Date,
	|	&Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	TemporaryTablePaymentDetails.VATOutputGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	UNDEFINED,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END,
	|	0,
	|	SUM(CASE
	|			WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|				THEN TemporaryTablePaymentDetails.SettlementsEPDAmount - TemporaryTablePaymentDetails.SettlementsEPDAmountExclVAT
	|			ELSE 0
	|		END),
	|	SUM(TemporaryTablePaymentDetails.AccountingEPDAmount - TemporaryTablePaymentDetails.AccountingEPDAmountExclVAT),
	|	&ContentVAT,
	|	FALSE
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoice.Ref
	|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|WHERE
	|	TemporaryTablePaymentDetails.OperationKind = VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer)
	|	AND NOT TemporaryTablePaymentDetails.AdvanceFlag
	|	AND TemporaryTablePaymentDetails.EPDAmount > 0
	|
	|GROUP BY
	|	TemporaryTablePaymentDetails.Date,
	|	TemporaryTablePaymentDetails.VATOutputGLAccount,
	|	TemporaryTablePaymentDetails.GLAccountCustomerSettlements,
	|	CASE
	|		WHEN TemporaryTablePaymentDetails.GLAccountCustomerSettlements.Currency
	|			THEN TemporaryTablePaymentDetails.SettlementsCurrency
	|		ELSE UNDEFINED
	|	END
	|
	|UNION ALL
	|
	|SELECT
	|	7,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FeeExpensesGLAccount,
	|	DocumentTable.FeeProcessorDebtGLAccount,
	|	CASE
	|		WHEN DocumentTable.FeeExpensesGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeExpensesGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	DocumentTable.FeeTotalPC,
	|	DocumentTable.ContentPaymentProcessorFee,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	NOT DocumentTable.WithholdFeeOnPayout
	|
	|UNION ALL
	|
	|SELECT
	|	8,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.FeeProcessorDebtGLAccount,
	|	DocumentTable.FundsTransfersBeingProcessedGLAccount,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.CashCurrency
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN DocumentTable.FeeProcessorDebtGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	CASE
	|		WHEN DocumentTable.FundsTransfersBeingProcessedGLAccount.Currency
	|			THEN DocumentTable.FeeTotal
	|		ELSE 0
	|	END,
	|	DocumentTable.FeeTotalPC,
	|	&ContentComissionWithhold,
	|	FALSE
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	NOT DocumentTable.WithholdFeeOnPayout
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTablePaymentCalendar(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref"                    , DocumentRef);
	Query.SetParameter("Company"                , StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PresentationCurrency"   , StructureAdditionalProperties.ForPosting.PresentationCurrency);
	Query.SetParameter("UsePaymentCalendar"     , Constants.UsePaymentCalendar.Get());
	
	Query.Text =
	"SELECT DISTINCT
	|	DocumentTable.Document AS Document,
	|	DocumentTable.Date AS Period
	|INTO SalesInvoiceTable
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON DocumentTable.Document = SalesInvoice.Ref
	|WHERE
	|	&UsePaymentCalendar
	|	AND DocumentTable.EPDAmount > 0
	|	AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocument)
	|			OR SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivable.AmountCur AS AmountCur,
	|	AccountsReceivable.Document AS Document
	|INTO PaymentsAmountsDocument
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON AccountsReceivable.Document = SalesInvoiceTable.Document
	|WHERE
	|	AccountsReceivable.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND AccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|	AND AccountsReceivable.Recorder <> AccountsReceivable.Document
	|	AND AccountsReceivable.Recorder <> &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	TemporaryTablePaymentDetails.SettlementsAmount,
	|	TemporaryTablePaymentDetails.Document
	|FROM
	|	TemporaryTablePaymentDetails AS TemporaryTablePaymentDetails
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON TemporaryTablePaymentDetails.Document = SalesInvoiceTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(PaymentsAmountsDocument.AmountCur) AS AmountCur,
	|	PaymentsAmountsDocument.Document AS Document
	|INTO PaymentsAmounts
	|FROM
	|	PaymentsAmountsDocument AS PaymentsAmountsDocument
	|
	|GROUP BY
	|	PaymentsAmountsDocument.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Company AS Company,
	|	PaymentCalendar.PresentationCurrency AS PresentationCurrency,
	|	PaymentCalendar.Currency AS Currency,
	|	PaymentCalendar.Item AS Item,
	|	PaymentCalendar.PaymentMethod AS PaymentMethod,
	|	PaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	PaymentCalendar.Quote AS Quote,
	|	PaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	SUM(PaymentCalendar.Amount) AS Amount,
	|	SalesInvoiceTable.Document AS Document,
	|	SalesInvoiceTable.Period AS Period
	|INTO SalesInvoicePaymentCalendar
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|		INNER JOIN SalesInvoiceTable AS SalesInvoiceTable
	|		ON PaymentCalendar.Recorder = SalesInvoiceTable.Document
	|
	|GROUP BY
	|	PaymentCalendar.PaymentMethod,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.Item,
	|	PaymentCalendar.Company,
	|	PaymentCalendar.PresentationCurrency,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	PaymentCalendar.Quote,
	|	SalesInvoiceTable.Document,
	|	SalesInvoiceTable.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesInvoicePaymentCalendar.Company AS Company,
	|	SalesInvoicePaymentCalendar.PresentationCurrency AS PresentationCurrency,
	|	SalesInvoicePaymentCalendar.Currency AS Currency,
	|	SalesInvoicePaymentCalendar.Item AS Item,
	|	SalesInvoicePaymentCalendar.PaymentMethod AS PaymentMethod,
	|	SalesInvoicePaymentCalendar.BankAccountPettyCash AS BankAccountPettyCash,
	|	SalesInvoicePaymentCalendar.Quote AS Quote,
	|	SalesInvoicePaymentCalendar.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	ISNULL(PaymentsAmounts.AmountCur, 0) - SalesInvoicePaymentCalendar.Amount AS Amount,
	|	SalesInvoicePaymentCalendar.Document AS Document,
	|	SalesInvoicePaymentCalendar.Period AS Period
	|INTO Tabular
	|FROM
	|	SalesInvoicePaymentCalendar AS SalesInvoicePaymentCalendar
	|		LEFT JOIN PaymentsAmounts AS PaymentsAmounts
	|		ON SalesInvoicePaymentCalendar.Document = PaymentsAmounts.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	Tabular.Period AS Period,
	|	Tabular.Company AS Company,
	|	Tabular.PresentationCurrency AS PresentationCurrency,
	|	Tabular.Item AS Item,
	|	Tabular.PaymentMethod AS PaymentMethod,
	|	Tabular.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	Tabular.BankAccountPettyCash AS BankAccountPettyCash,
	|	Tabular.Currency AS Currency,
	|	Tabular.Quote AS Quote,
	|	0 AS PaymentAmount,
	|	Tabular.Amount AS Amount
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.Amount < 0
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableInvoicesAndOrdersPayment(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	
	Query.Text =
	"SELECT
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	&Company AS Company,
	|	DocumentTable.Order AS Quote,
	|	SUM(CASE
	|			WHEN NOT DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) AS AdvanceAmount,
	|	SUM(CASE
	|			WHEN DocumentTable.AdvanceFlag
	|				THEN 0
	|			ELSE DocumentTable.SettlementsAmount
	|		END) AS PaymentAmount
	|FROM
	|	TemporaryTablePaymentDetails AS DocumentTable
	|WHERE
	|	DocumentTable.DoOperationsByOrders
	|	AND VALUETYPE(DocumentTable.Order) = TYPE(Document.SalesOrder)
	|	AND DocumentTable.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|
	|GROUP BY
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	DocumentTable.Order,
	|	DocumentTable.OperationKind
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInvoicesAndOrdersPayment", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableVATOutput(DocumentRef, StructureAdditionalProperties)
	
	If StructureAdditionalProperties.AccountingPolicy.RegisteredForVAT Then
		
		PostAdvancePayments = StructureAdditionalProperties.AccountingPolicy.PostAdvancePaymentsBySourceDocuments;
		
		Query = New Query;
		Query.SetParameter("PostAdvancePayments", PostAdvancePayments);
		Query.SetParameter("VATOutput", Catalogs.DefaultGLAccounts.GetDefaultGLAccount("VATOutput"));
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		Query.Text =
		"SELECT
		|	Payment.Date AS Period,
		|	Payment.Company AS Company,
		|	Payment.CompanyVATNumber AS CompanyVATNumber,
		|	Payment.PresentationCurrency AS PresentationCurrency,
		|	Payment.Counterparty AS Customer,
		|	Payment.Ref AS ShipmentDocument,
		|	Payment.VATRate AS VATRate,
		|	&VATOutput AS GLAccount,
		|	VALUE(Enum.VATOperationTypes.AdvancePayment) AS OperationType,
		|	VALUE(Enum.ProductsTypes.EmptyRef) AS ProductType,
		|	SUM(Payment.AmountExcludesVAT) AS AmountExcludesVAT,
		|	SUM(Payment.VATAmount) AS VATAmount
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|WHERE
		|	NOT Payment.VATRate.NotTaxable
		|	AND Payment.AdvanceFlag
		|	AND Payment.VATAmount > 0
		|	AND &PostAdvancePayments
		|
		|GROUP BY
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.Counterparty,
		|	Payment.Ref,
		|	Payment.VATRate,
		|	Payment.PresentationCurrency
		|
		|UNION ALL
		|
		|SELECT
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.PresentationCurrency,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATOutputGLAccount,
		|	VALUE(Enum.VATOperationTypes.DiscountAllowed),
		|	VALUE(Enum.ProductsTypes.EmptyRef),
		|	-SUM(Payment.AccountingEPDAmountExclVAT),
		|	-SUM(Payment.AccountingEPDAmount - Payment.AccountingEPDAmountExclVAT)
		|FROM
		|	TemporaryTablePaymentDetails AS Payment
		|		INNER JOIN Document.SalesInvoice AS SalesInvoice
		|		ON Payment.Document = SalesInvoice.Ref
		|			AND (SalesInvoice.ProvideEPD = VALUE(Enum.VariantsOfProvidingEPD.PaymentDocumentWithVATAdjustment))
		|		LEFT JOIN Catalog.VATRates AS VATRates
		|		ON (VATRates.Ref = Payment.VATRate)
		|WHERE
		|	NOT Payment.VATRate.NotTaxable
		|	AND NOT Payment.AdvanceFlag
		|	AND Payment.AccountingEPDAmount > 0
		|
		|GROUP BY
		|	Payment.Date,
		|	Payment.Company,
		|	Payment.CompanyVATNumber,
		|	Payment.Counterparty,
		|	SalesInvoice.Ref,
		|	Payment.VATRate,
		|	Payment.VATOutputGLAccount,
		|	Payment.PresentationCurrency";
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", Query.Execute().Unload());
		
	Else
		
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableVATOutput", New ValueTable);
		
	EndIf;
	
EndProcedure

Procedure GenerateTableFundsTransfersBeingProcessed(DocumentRef, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("Ref",					DocumentRef);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("ExchangeRateMethod",	StructureAdditionalProperties.ForPosting.ExchangeRateMethod);
	Query.SetParameter("FundsTransfersBeingProcessedGLAccount",
		Catalogs.DefaultGLAccounts.GetDefaultGLAccount("FundsTransfersBeingProcessed"));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	&Company AS Company,
	|	DocumentTable.PresentationCurrency AS PresentationCurrency,
	|	DocumentTable.PaymentProcessor AS PaymentProcessor,
	|	DocumentTable.PaymentProcessorContract AS PaymentProcessorContract,
	|	DocumentTable.POSTerminal AS POSTerminal,
	|	DocumentTable.CashCurrency AS Currency,
	|	&Ref AS Document,
	|	SUM(DocumentTable.PaymentAmount) AS AmountCur,
	|	SUM(DocumentTable.Amount) AS Amount,
	|	SUM(DocumentTable.PaymentAmount) AS AmountCurForBalance,
	|	SUM(DocumentTable.Amount) AS AmountForBalance,
	|	DocumentTable.FeeTotal AS FeeAmount
	|INTO TemporaryTableFundsTransfersBeingProcessed
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
	|WHERE
	|	DocumentTable.WithholdFeeOnPayout
	|
	|GROUP BY
	|	DocumentTable.CashCurrency,
	|	DocumentTable.Date,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.PaymentProcessor,
	|	DocumentTable.PaymentProcessorContract,
	|	DocumentTable.POSTerminal,
	|	DocumentTable.FeeTotal
	|
	|UNION ALL
	|
	|SELECT
	|	1,
	|	DocumentTable.Date,
	|	VALUE(AccumulationRecordType.Receipt),
	|	&Company,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.PaymentProcessor,
	|	DocumentTable.PaymentProcessorContract,
	|	DocumentTable.POSTerminal,
	|	DocumentTable.CashCurrency,
	|	UNDEFINED,
	|	SUM(DocumentTable.PaymentAmount) - DocumentTable.FeeTotal,
	|	SUM(DocumentTable.Amount) - DocumentTable.FeeTotalPC,
	|	SUM(DocumentTable.PaymentAmount) - DocumentTable.FeeTotal,
	|	SUM(DocumentTable.Amount) - DocumentTable.FeeTotalPC,
	|	0
	|FROM
	|	TemporaryTableAccountsReceivable AS DocumentTable
	|WHERE
	|	NOT DocumentTable.WithholdFeeOnPayout
	|
	|GROUP BY
	|	DocumentTable.CashCurrency,
	|	DocumentTable.PaymentProcessor,
	|	DocumentTable.Date,
	|	DocumentTable.PresentationCurrency,
	|	DocumentTable.POSTerminal,
	|	DocumentTable.PaymentProcessorContract,
	|	DocumentTable.FeeTotal,
	|	DocumentTable.FeeTotalPC";
	
	QueryResult = Query.Execute();
	
	Query.Text =
	"SELECT
	|	TemporaryTableFundsTransfersBeingProcessed.Company AS Company,
	|	TemporaryTableFundsTransfersBeingProcessed.PresentationCurrency AS PresentationCurrency,
	|	TemporaryTableFundsTransfersBeingProcessed.PaymentProcessor AS PaymentProcessor,
	|	TemporaryTableFundsTransfersBeingProcessed.PaymentProcessorContract AS PaymentProcessorContract,
	|	TemporaryTableFundsTransfersBeingProcessed.POSTerminal AS POSTerminal,
	|	TemporaryTableFundsTransfersBeingProcessed.Currency AS Currency,
	|	TemporaryTableFundsTransfersBeingProcessed.Document AS Document
	|FROM
	|	TemporaryTableFundsTransfersBeingProcessed AS TemporaryTableFundsTransfersBeingProcessed";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.FundsTransfersBeingProcessed");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesFundsTransfersBeingProcessed(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableFundsTransfersBeingProcessed", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableAccountingEntriesData(DocumentRef, StructureAdditionalProperties)

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingEntriesData", New ValueTable);

EndProcedure

#EndRegion

#EndIf