#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
	For Each TSRow In PaymentDetails Do
		If ValueIsFilled(Counterparty)
			And Not Counterparty.DoOperationsByContracts
			And Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
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

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.OnlineReceipt") Then
		FillByOnlineReceipt(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.CreditNote") Then
		FillByCreditNote(FillingData);
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each RowPaymentDetails In PaymentDetails Do
		
		If Not ValueIsFilled(RowPaymentDetails.Document) Then
			If PaymentDetails.Count() = 1 Then
				MessageText = NStr("en = 'Document is required.'; ru = 'Требуется документ.';pl = 'Wymagany jest dokument.';es_ES = 'Se requiere el documento.';es_CO = 'Se requiere el documento.';tr = 'Belge gerekli.';it = 'È richiesto il documento.';de = 'Dokument ist erforderlich.'");
			Else
				MessageText = NStr("en = 'Document is required in line #%1 of the Payment allocation tab.'; ru = 'Укажите документ в строке №%1 на вкладке ""Расшифровка платежа"".';pl = 'Dokument jest wymgany w wierszu nr %1 karty Alokacja platności.';es_ES = 'Se requiere el documento en la línea #%1 de la pestaña Asignación del pago.';es_CO = 'Se requiere el documento en la línea #%1 de la pestaña Asignación del pago.';tr = 'Ödeme tahsisi sekmesinin %1 numaralı satırında belge gerekli.';it = 'È richiesto il documento nella riga #%1 della scheda Allocazione pagamento.';de = 'Das Dokument ist in der Zeile Nr.%1 der Registerkarte Zahlungszuordnung nötig.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, RowPaymentDetails.LineNumber);
			EndIf;
			DriveServer.ShowMessageAboutError(ThisObject,
				MessageText, "PaymentDetails", RowPaymentDetails.LineNumber, "Document", Cancel);
		EndIf;
	EndDo;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	If PaymentAmount <> DocumentAmount Then
		MessageText = NStr("en = 'The document amount (%1 %3) is not equal to the sum of payment amounts in the payment details (%2 %3).'; ru = 'Сумма документа (%1 %3) не соответствует сумме платежей в табличной части (%2 %3).';pl = 'Kwota dokumentu (%1 %3) różni się od sumy kwot płatności w szczegółach płatności (%2 %3).';es_ES = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';es_CO = 'El importe del documento (%1 %3) no es igual a la suma de los importes de pagos en los detalles de pago (%2 %3).';tr = 'Belge tutarı (%1 %3), ödeme bilgilerindeki ödeme tutarlarının toplamına eşit değil (%2 %3).';it = 'L''importo del documento (%1 %3) non corrisponde alla somma degli importi dei pagamenti nei dettagli dei pagamenti (%2 %3).';de = 'Der Belegbetrag (%1 %3) entspricht nicht der Summe der Zahlungsbeträge in den Zahlungsdetails (%2 %3).'");
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText,
			DocumentAmount, PaymentAmount, TrimAll(CashCurrency));
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "DocumentAmount", Cancel);
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentDetails.Contract");
	EndIf;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
	If Common.ObjectAttributeValue(POSTerminal, "WithholdFeeOnPayout") = True Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExpenseItem");
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.OnlinePayment.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFundsTransfersBeingProcessed(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.OnlinePayment.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.OnlinePayment.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

#EndRegion

#Region Private

Procedure FillAdvancesPaymentDetails() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.Rate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Repetition AS Multiplicity
	|INTO ExchangeRatesOnPeriod
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.AmountBalance AS Amount,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCur
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.Amount
	|		ELSE DocumentAccountsReceivable.Amount
	|	END,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	-SUM(AccountsReceivableTable.Amount) AS Amount,
	|	-SUM(AccountsReceivableTable.AmountCur) AS AmountCur
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCur < 0
	|
	|GROUP BY
	|	AccountsReceivableTable.Counterparty,
	|	AccountsReceivableTable.Contract,
	|	AccountsReceivableTable.Document,
	|	AccountsReceivableTable.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	CounterpartyContracts.CashFlowItem AS Item,
	|	TRUE AS AdvanceFlag,
	|	AccountsReceivableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCur AS SettlementsAmount,
	|	CASE
	|		WHEN &PresentationCurrency = &Currency
	|			THEN AccountsReceivableGrouped.Amount
	|		WHEN CounterpartyContracts.SettlementsCurrency = &Currency
	|			THEN AccountsReceivableGrouped.AmountCur
	|		ELSE CASE
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|					THEN AccountsReceivableGrouped.AmountCur * SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity
	|				WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|					THEN AccountsReceivableGrouped.AmountCur / (SettlementsRates.ExchangeRate * CashCurrencyRates.Multiplicity / CashCurrencyRates.ExchangeRate / SettlementsRates.Multiplicity)
	|			END
	|	END AS PaymentAmount,
	|	CASE
	|		WHEN &PresentationCurrency = &Currency
	|			THEN CASE
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|						THEN AccountsReceivableGrouped.Amount / AccountsReceivableGrouped.AmountCur * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|					WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|						THEN AccountsReceivableGrouped.AmountCur / AccountsReceivableGrouped.Amount * CashCurrencyRates.ExchangeRate / CashCurrencyRates.Multiplicity * SettlementsRates.Multiplicity
	|				END
	|		ELSE SettlementsRates.ExchangeRate
	|	END AS ExchangeRate,
	|	SettlementsRates.Multiplicity AS Multiplicity
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN ExchangeRatesOnPeriod AS SettlementsRates
	|		ON (CounterpartyContracts.SettlementsCurrency = SettlementsRates.Currency)
	|		LEFT JOIN ExchangeRatesOnPeriod AS CashCurrencyRates
	|		ON (CashCurrencyRates.Currency = &Currency)";
	
	Query.SetParameter("Company"               , ParentCompany);
	Query.SetParameter("PresentationCurrency"  , DriveServer.GetPresentationCurrency(ParentCompany));
	Query.SetParameter("Counterparty"          , Counterparty);
	Query.SetParameter("Period"                , Date);
	Query.SetParameter("Ref"                   , Ref);
	Query.SetParameter("Currency"              , CashCurrency);
	Query.SetParameter("ExchangeRateMethod"    , DriveServer.GetExchangeMethod(ParentCompany));
	
	PaymentDetails.Load(Query.Execute().Unload());
	
	If PaymentDetails.Count() = 0 Then
		
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			Counterparty,
			Company,
			ContractTypesList);
		
		NewRow = PaymentDetails.Add();
		NewRow.Contract			= ContractByDefault;
		NewRow.Item				= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		NewRow.PaymentAmount	= DocumentAmount;
		
	Else
		
		For Each NewRow In PaymentDetails Do
			VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
			NewRow.VATRate = VATRateData.VATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
		EndDo;
		
		DocumentAmount = PaymentDetails.Total("PaymentAmount");
		
	EndIf;
	
	CalculateFee();
	
EndProcedure

Procedure FillBySalesOrder(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.DocumentAmount AS DocumentAmount
	|INTO DocumentHeader
	|FROM
	|	Document.SalesOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED TOP 1
	|	POSTerminals.POSTerminal AS POSTerminal,
	|	POSTerminals.ExpenseItem AS ExpenseItem,
	|	POSTerminals.Currency AS Currency,
	|	POSTerminals.ChargeCardKind AS ChargeCardKind,
	|	POSTerminals.ChargeCardNo AS ChargeCardNo,
	|	POSTerminals.OnlineReceipt AS OnlineReceipt
	|INTO POSTerminals
	|FROM
	|	(SELECT
	|		POSTerminals.Ref AS POSTerminal,
	|		POSTerminals.ExpenseItem AS ExpenseItem,
	|		DocumentHeader.CashCurrency AS Currency,
	|		VALUE(Catalog.PaymentCardTypes.EmptyRef) AS ChargeCardKind,
	|		"""" AS ChargeCardNo,
	|		UNDEFINED AS OnlineReceipt,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.POSTerminals AS POSTerminals
	|			ON DocumentHeader.Company = POSTerminals.Company
	|				AND (NOT POSTerminals.DeletionMark)
	|				AND (POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments))
	|			INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			ON DocumentHeader.CashCurrency = CounterpartyContracts.SettlementsCurrency
	|				AND (POSTerminals.PaymentProcessorContract = CounterpartyContracts.Ref)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		OnlineReceipt.POSTerminal,
	|		OnlineReceipt.ExpenseItem,
	|		OnlineReceipt.CashCurrency,
	|		OnlineReceipt.ChargeCardKind,
	|		OnlineReceipt.ChargeCardNo,
	|		OnlineReceipt.Ref,
	|		1
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Document.OnlineReceipt AS OnlineReceipt
	|			ON DocumentHeader.Ref = OnlineReceipt.BasisDocument
	|				AND (OnlineReceipt.Posted)) AS POSTerminals
	|
	|ORDER BY
	|	POSTerminals.Priority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesOnlinePayment.ToCustomer) AS OperationKind,
	|	CASE
	|		WHEN ISNULL(Contracts.CashFlowItem, VALUE(Catalog.CashFlowItems.EmptyRef)) = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE Contracts.CashFlowItem
	|	END AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	POSTerminals.POSTerminal AS POSTerminal,
	|	POSTerminals.ExpenseItem AS ExpenseItem,
	|	POSTerminals.ChargeCardKind AS ChargeCardKind,
	|	POSTerminals.ChargeCardNo AS ChargeCardNo,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	POSTerminals.OnlineReceipt AS Document,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS SettlementsAmount,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate) AS ExchangeRate,
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity) AS Multiplicity,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(DocumentTable.VATAmount) AS VATAmount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Document.SalesOrder.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN POSTerminals AS POSTerminals
	|		ON (TRUE)
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	POSTerminals.POSTerminal,
	|	POSTerminals.ExpenseItem,
	|	POSTerminals.ChargeCardKind,
	|	POSTerminals.ChargeCardNo,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	Counterparties.DoOperationsByOrders,
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN ISNULL(Contracts.CashFlowItem, VALUE(Catalog.CashFlowItems.EmptyRef)) = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE Contracts.CashFlowItem
	|	END,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate),
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity),
	|	POSTerminals.OnlineReceipt,
	|	DocumentHeader.CashCurrency,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.VATRate";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		CalculateFee();
		
	EndIf;
	
EndProcedure

Procedure FillByOnlineReceipt(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.POSTerminal AS POSTerminal,
	|	DocumentHeader.ExpenseItem AS ExpenseItem,
	|	DocumentHeader.ChargeCardKind AS ChargeCardKind,
	|	DocumentHeader.ChargeCardNo AS ChargeCardNo,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	DocumentHeader.Counterparty AS Counterparty
	|INTO DocumentHeader
	|FROM
	|	Document.OnlineReceipt AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesOnlinePayment.ToCustomer) AS OperationKind,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.POSTerminal AS POSTerminal,
	|	DocumentHeader.ExpenseItem AS ExpenseItem,
	|	DocumentHeader.ChargeCardKind AS ChargeCardKind,
	|	DocumentHeader.ChargeCardNo AS ChargeCardNo,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.AdvanceFlag AS AdvanceFlag,
	|	DocumentHeader.Ref AS Document,
	|	DocumentTable.SettlementsAmount AS SettlementsAmount,
	|	DocumentTable.ExchangeRate AS ExchangeRate,
	|	DocumentTable.Multiplicity AS Multiplicity,
	|	DocumentTable.PaymentAmount AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	DocumentTable.VATAmount AS VATAmount,
	|	DocumentTable.Order AS Order,
	|	DocumentTable.Item AS Item1,
	|	DocumentTable.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentTable.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.OnlineReceipt.PaymentDetails AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		CalculateFee();
		
	EndIf;
	
EndProcedure

Procedure FillByCreditNote(FillingData)
	
	Query = New Query;
	
	Query.SetParameter("Ref", FillingData);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	
	Query.Text = 
	"SELECT ALLOWED
	|	DocumentHeader.Ref AS Ref,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.Contract AS Contract,
	|	DocumentHeader.DocumentCurrency AS CashCurrency,
	|	DocumentHeader.ExchangeRate AS ExchangeRate,
	|	DocumentHeader.Multiplicity AS Multiplicity,
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.BasisDocument AS BasisDocument
	|INTO DocumentHeader
	|FROM
	|	Document.CreditNote AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|SELECT ALLOWED TOP 1
	|	POSTerminals.POSTerminal AS POSTerminal,
	|	POSTerminals.ExpenseItem AS ExpenseItem,
	|	POSTerminals.Currency AS Currency,
	|	POSTerminals.ChargeCardKind AS ChargeCardKind,
	|	POSTerminals.ChargeCardNo AS ChargeCardNo,
	|	POSTerminals.OnlineReceipt AS OnlineReceipt
	|INTO POSTerminals
	|FROM
	|	(SELECT
	|		POSTerminals.Ref AS POSTerminal,
	|		POSTerminals.ExpenseItem AS ExpenseItem,
	|		DocumentHeader.CashCurrency AS Currency,
	|		VALUE(Catalog.PaymentCardTypes.EmptyRef) AS ChargeCardKind,
	|		"""" AS ChargeCardNo,
	|		UNDEFINED AS OnlineReceipt,
	|		2 AS Priority
	|	FROM
	|		DocumentHeader AS DocumentHeader
	|			INNER JOIN Catalog.POSTerminals AS POSTerminals
	|			ON DocumentHeader.Company = POSTerminals.Company
	|				AND (NOT POSTerminals.DeletionMark)
	|				AND (POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments))
	|			INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|			ON DocumentHeader.CashCurrency = CounterpartyContracts.SettlementsCurrency
	|				AND (POSTerminals.PaymentProcessorContract = CounterpartyContracts.Ref)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		OnlineReceipt.POSTerminal,
	|		OnlineReceipt.ExpenseItem,
	|		OnlineReceipt.CashCurrency,
	|		OnlineReceipt.ChargeCardKind,
	|		OnlineReceipt.ChargeCardNo,
	|		OnlineReceipt.Ref,
	|		1
	|	FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON (DocumentHeader.BasisDocument = SalesInvoice.Ref
	|				AND SalesInvoice.Posted)
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON (SalesInvoice.Order = SalesOrder.Ref
	|				AND SalesOrder.Posted)
	|		INNER JOIN Document.OnlineReceipt AS OnlineReceipt
	|		ON (SalesOrder.Ref = OnlineReceipt.BasisDocument
	|				AND OnlineReceipt.Posted)) AS POSTerminals
	|
	|ORDER BY
	|	POSTerminals.Priority
	|
	|;
	|
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesOnlinePayment.ToCustomer) AS OperationKind,
	|	CASE
	|		WHEN ISNULL(Contracts.CashFlowItem, VALUE(Catalog.CashFlowItems.EmptyRef)) = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE Contracts.CashFlowItem
	|	END AS Item,
	|	DocumentHeader.Ref AS BasisDocument,
	|	DocumentHeader.Company AS Company,
	|	DocumentHeader.CompanyVATNumber AS CompanyVATNumber,
	|	DocumentHeader.VATTaxation AS VATTaxation,
	|	POSTerminals.POSTerminal AS POSTerminal,
	|	POSTerminals.ExpenseItem AS ExpenseItem,
	|	POSTerminals.ChargeCardKind AS ChargeCardKind,
	|	POSTerminals.ChargeCardNo AS ChargeCardNo,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	DocumentHeader.Ref AS Document,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS SettlementsAmount,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate) AS ExchangeRate,
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity) AS Multiplicity,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(DocumentTable.VATAmount) AS VATAmount,
	|	DocumentTable.Order AS Order
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Document.CreditNote.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN POSTerminals AS POSTerminals
	|		ON (TRUE)
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	POSTerminals.POSTerminal,
	|	POSTerminals.ExpenseItem,
	|	POSTerminals.ChargeCardKind,
	|	POSTerminals.ChargeCardNo,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN ISNULL(Contracts.CashFlowItem, VALUE(Catalog.CashFlowItems.EmptyRef)) = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE Contracts.CashFlowItem
	|	END,
	|	DocumentTable.Order,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate),
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity),
	|	DocumentHeader.CashCurrency,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.VATRate";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		FillPropertyValues(ThisObject, Selection);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		CalculateFee();
		
	EndIf;
	
EndProcedure

Procedure CalculateFee()
	
	If ValueIsFilled(POSTerminal) And ValueIsFilled(ChargeCardKind) Then
		FeeData = Catalogs.POSTerminals.GetFeeData(POSTerminal, ChargeCardKind);
		FillPropertyValues(ThisObject, FeeData);
		FeeAmount = DocumentAmount * FeePercent / 100;
		FeeTotal = FeeAmount + FeeFixedPart;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
