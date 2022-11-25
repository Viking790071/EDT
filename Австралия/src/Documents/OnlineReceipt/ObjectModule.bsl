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
		WorkWithVAT.SubordinatedTaxInvoiceControl(AdditionalProperties.WriteMode, Ref, DeletionMark);
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, AdditionalProperties.WriteMode, DeletionMark, Company, Date, AdditionalProperties);

	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		FillBySalesInvoice(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		GLAccountsInDocuments.FillGLAccountsInDocument(ThisObject, FillingData);
	EndIf;
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	For Each RowPaymentDetails In PaymentDetails Do
		
		If Not ValueIsFilled(RowPaymentDetails.Document) And Not RowPaymentDetails.AdvanceFlag Then
			If PaymentDetails.Count() = 1 Then
				MessageText = NStr("en = 'Cannot post the document. Select Document or ""Advance payment"" checkbox on the Payment allocation tab. Then try again.'; ru = 'Не удалось провести документ. Установите флажок Документ или ""Авансовый платеж"" на вкладке Расшифровка платежа. Затем повторите попытку.';pl = 'Nie można zatwierdzić dokumentu. Zaznacz pole wyboru Dokument lub ""Zaliczka"" w karcie Alokacja płatności. Następnie spróbuj ponownie.';es_ES = 'No se puede enviar el documento. Seleccione la casilla Documento o ""Pago adelantado"" en la pestaña Asignación del pago. A continuación, inténtelo de nuevo.';es_CO = 'No se puede enviar el documento. Seleccione la casilla Documento o ""Pago adelantado"" en la pestaña Asignación del pago. A continuación, inténtelo de nuevo.';tr = 'Belge kaydedilemiyor. Ödeme tahsisi sekmesinde Belge veya ""Avans ödeme"" onay kutusunu seçip tekrar deneyin.';it = 'Impossibile pubblicare il documento. Selezionare Documento o la casella di controllo ""Pagamento anticipato"" nella scheda Allocazione pagamento, poi riprovare.';de = 'Das Dokument kann nicht gebucht werden. Aktivieren Sie das Kontrollkästchen Dokument oder ""Vorauszahlung"" in der Registerkarte Zahlungszuordnung. Dann versuchen Sie es erneut.'");
			Else
				MessageText = NStr("en = 'Cannot post the document. Select Document or ""Advance payment"" checkbox in line #%1 of the Payment allocation tab. Then try again.'; ru = 'Не удалось провести документ. Установите флажок Документ или ""Авансовый платеж"" в строке №%1 на вкладке Расшифровка платежа. Затем повторите попытку.';pl = 'Nie można zatwierdzić dokumentu. Zaznacz pole wyboru Dokument lub ""Zaliczka"" w wierszu nr %1 na karcie Alokacja płatności. Następnie spróbuj ponownie.';es_ES = 'No se puede enviar el documento. Seleccione la casilla Documento o ""Pago adelantado"" en la línea #%1 de la pestaña Asignación del pago. A continuación, inténtelo de nuevo.';es_CO = 'No se puede enviar el documento. Seleccione la casilla Documento o ""Pago adelantado"" en la línea #%1 de la pestaña Asignación del pago. A continuación, inténtelo de nuevo.';tr = 'Belge kaydedilemiyor. Ödeme tahsisi sekmesinin %1 numaralı satırında Belge veya ""Avans ödeme"" onay kutusunu seçip tekrar deneyin.';it = 'Impossibile pubblicare il documento. Selezionare il Documento o casella di controllo ""Pagamento anticipato"" nella riga #%1 della scheda di Allocazione pagamento, poi riprovare.';de = 'Das Dokument kann nicht gebucht werden. Aktivieren Sie das Kontrollkästchen Dokument oder ""Vorauszahlung"" in der Zeile No. %1 der Registerkarte Zahlungszuordnung. Dann versuchen Sie es erneut.'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(MessageText, RowPaymentDetails.LineNumber);
			EndIf;
			DriveServer.ShowMessageAboutError(ThisObject,
				MessageText, "PaymentDetails", RowPaymentDetails.LineNumber, "Document", Cancel);
		EndIf;
	EndDo;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	If PaymentAmount <> DocumentAmount Then
		MessageText = NStr("en = 'Cannot post the document. Amount (%1 %3) must match the total amount of lines (%2 %3) on the Payment allocation tab.'; ru = 'Не удалось провести документ. Сумма (%1 %3) должна соответствовать общей сумме строк (%2 %3) на вкладке «Расшифровка платежа».';pl = 'Nie można zatwierdzić dokumentu. Wartość (%1 %3) musi odpowiadać ogólnej wartości wierszy (%2 %3) na karcie Alokacja płatności.';es_ES = 'No se puede enviar el documento. El importe (%1 %3) debe coincidir con el importe total de las líneas (%2 %3) en la pestaña Asignación del pago.';es_CO = 'No se puede enviar el documento. El importe (%1 %3) debe coincidir con el importe total de las líneas (%2 %3) en la pestaña Asignación del pago.';tr = 'Belge kaydedilemiyor. Tutar (%1 %3), Ödeme tahsisi sekmesindeki satırların toplam tutarına (%2%3) eşit olmalıdır.';it = 'Impossibile pubblicare il documento. L''importo (%1 %3) deve corrispondere con l''importo totale delle righe (%2 %3) nella scheda Allocazione pagamento.';de = 'Das Dokument kann nicht gebucht werden. Der Betrag (%1 %3) muss mit der Gesamtsumme der Zeilen (%2 %3) der Registerkarte Zahlungszuordnung übereinstimmen.'");
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
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.OnlineReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
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
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.Posting, Ref, DeletionMark);
	EndIf;
	
	Documents.OnlineReceipt.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	DriveServer.WriteRecordSets(ThisObject);
	
	If Not Cancel Then
		WorkWithVAT.SubordinatedTaxInvoiceControl(DocumentWriteMode.UndoPosting, Ref, DeletionMark);
	EndIf;
	
	Documents.OnlineReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

#EndRegion

#Region Private

Procedure FillPaymentDetails(Val VATAmountLeftToDistribute = 0) Export
	
	IsOrderSet = False;
	
	DoOperationsByOrders = Common.ObjectAttributeValue(Counterparty, "DoOperationsByOrders");
	
	If DoOperationsByOrders And ValueIsFilled(BasisDocument) Then
		If TypeOf(BasisDocument) = Type("DocumentRef.SalesOrder") Then
			IsOrderSet = True;
		EndIf;
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	StructureByCurrency = CurrencyRateOperations.GetCurrencyRate(Date, CashCurrency, Company);
	
	ExchangeRateCurrenciesDC = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Rate);
	CurrencyUnitConversionFactor = ?(StructureByCurrency.Rate = 0, 1, StructureByCurrency.Repetition);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	ExchangeRateSliceLast.Currency AS Currency,
	|	ExchangeRateSliceLast.Rate AS ExchangeRate,
	|	ExchangeRateSliceLast.Repetition AS Multiplicity
	|INTO ExchangeRateOnPeriod
	|FROM
	|	InformationRegister.ExchangeRate.SliceLast(&Period, Company = &Company) AS ExchangeRateSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentAccountsReceivable.Company,
	|	DocumentAccountsReceivable.Counterparty,
	|	DocumentAccountsReceivable.Contract,
	|	DocumentAccountsReceivable.Document,
	|	DocumentAccountsReceivable.Order,
	|	DocumentAccountsReceivable.SettlementsType,
	|	CASE
	|		WHEN DocumentAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentAccountsReceivable.AmountCur
	|		ELSE DocumentAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentAccountsReceivable
	|WHERE
	|	DocumentAccountsReceivable.Recorder = &Ref
	|	AND DocumentAccountsReceivable.Period <= &Period
	|	AND DocumentAccountsReceivable.Company = &Company
	|	AND DocumentAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Counterparty AS Counterparty,
	|	AccountsReceivableTable.Contract AS Contract,
	|	AccountsReceivableTable.Document AS Document,
	|	AccountsReceivableTable.Order AS Order,
	|	SUM(AccountsReceivableTable.AmountCurBalance) AS AmountCurBalance
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|WHERE
	|	AccountsReceivableTable.AmountCurBalance > 0
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
	|	AccountsReceivableGrouped.Counterparty AS Counterparty,
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	AccountsReceivableGrouped.Document AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableGrouped.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	AccountsReceivableGrouped.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.CashFlowItem AS Item
	|INTO AccountsReceivableContract
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableGrouped.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableGrouped.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON AccountsReceivableGrouped.Document = SalesInvoice.Ref
	|WHERE
	|	(NOT &IsOrderSet
	|			OR AccountsReceivableGrouped.Order = &Order)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsReceivableContract.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	SalesInvoiceEarlyPaymentDiscounts.DueDate AS DueDate,
	|	SalesInvoiceEarlyPaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoice
	|INTO EarlePaymentDiscounts
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(EarlePaymentDiscounts.DueDate) AS DueDate,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMinDueDate
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|
	|GROUP BY
	|	EarlePaymentDiscounts.SalesInvoice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TRUE AS ExistsEPD,
	|	EarlePaymentDiscounts.DiscountAmount AS DiscountAmount,
	|	EarlePaymentDiscounts.SalesInvoice AS SalesInvoice
	|INTO EarlyPaymentMaxDiscountAmount
	|FROM
	|	EarlePaymentDiscounts AS EarlePaymentDiscounts
	|		INNER JOIN EarlyPaymentMinDueDate AS EarlyPaymentMinDueDate
	|		ON EarlePaymentDiscounts.SalesInvoice = EarlyPaymentMinDueDate.SalesInvoice
	|			AND EarlePaymentDiscounts.DueDate = EarlyPaymentMinDueDate.DueDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED DISTINCT
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Period AS Period
	|INTO EntriesRecorderPeriod
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON AccountingJournalEntries.Recorder = DocumentTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableContract.Contract AS Contract,
	|	AccountsReceivableContract.Item AS Item,
	|	AccountsReceivableContract.Document AS Document,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate,
	|	AccountsReceivableContract.Order AS Order,
	|	ExchangeRateOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRateOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRate.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRate.Multiplicity AS Multiplicity,
	|	AccountsReceivableContract.AmountCurBalance AS AmountCur,
	|	CAST(AccountsReceivableContract.AmountCurBalance * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS AmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) AS DiscountAmountCur,
	|	CAST(ISNULL(EarlyPaymentMaxDiscountAmount.DiscountAmount, 0) * CASE
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Divisor)
	|				THEN ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity / (SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity)
	|			WHEN &ExchangeRateMethod = VALUE(Enum.ExchangeRateMethods.Multiplier)
	|				THEN SettlementsExchangeRate.ExchangeRate * ExchangeRateOfDocument.Multiplicity / (ExchangeRateOfDocument.ExchangeRate * SettlementsExchangeRate.Multiplicity)
	|			ELSE 0
	|		END AS NUMBER(15, 2)) AS DiscountAmountCurDocument,
	|	ISNULL(EarlyPaymentMaxDiscountAmount.ExistsEPD, FALSE) AS ExistsEPD
	|INTO AccountsReceivableWithDiscount
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|		LEFT JOIN ExchangeRateOnPeriod AS ExchangeRateOfDocument
	|		ON (ExchangeRateOfDocument.Currency = &Currency)
	|		LEFT JOIN ExchangeRateOnPeriod AS SettlementsExchangeRate
	|		ON AccountsReceivableContract.SettlementsCurrency = SettlementsExchangeRate.Currency
	|		LEFT JOIN EarlyPaymentMaxDiscountAmount AS EarlyPaymentMaxDiscountAmount
	|		ON AccountsReceivableContract.Document = EarlyPaymentMaxDiscountAmount.SalesInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsReceivableContract.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableWithDiscount.Contract AS Contract,
	|	AccountsReceivableWithDiscount.Item AS Item,
	|	AccountsReceivableWithDiscount.Document AS Document,
	|	AccountsReceivableWithDiscount.DocumentDate AS DocumentDate,
	|	AccountsReceivableWithDiscount.Order AS Order,
	|	AccountsReceivableWithDiscount.CashAssetsRate AS CashAssetsRate,
	|	AccountsReceivableWithDiscount.CashMultiplicity AS CashMultiplicity,
	|	AccountsReceivableWithDiscount.ExchangeRate AS ExchangeRate,
	|	AccountsReceivableWithDiscount.Multiplicity AS Multiplicity,
	|	AccountsReceivableWithDiscount.AmountCur AS AmountCur,
	|	AccountsReceivableWithDiscount.AmountCurDocument AS AmountCurDocument,
	|	AccountsReceivableWithDiscount.DiscountAmountCur AS DiscountAmountCur,
	|	AccountsReceivableWithDiscount.DiscountAmountCurDocument AS DiscountAmountCurDocument,
	|	AccountsReceivableWithDiscount.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsReceivableWithDiscount AS AccountsReceivableWithDiscount
	|
	|ORDER BY
	|	DocumentDate
	|TOTALS
	|	SUM(AmountCurDocument),
	|	MAX(DiscountAmountCur),
	|	MAX(DiscountAmountCurDocument)
	|BY
	|	Document";
	
	Query.SetParameter("Company"       , ParentCompany);
	Query.SetParameter("Counterparty"  , Counterparty);
	Query.SetParameter("Period"        , Date);
	Query.SetParameter("Currency"      , CashCurrency);
	Query.SetParameter("Ref"           , Ref);
	Query.SetParameter("IsOrderSet"    , IsOrderSet);
	Query.SetParameter("Order"         , BasisDocument);
	Query.SetParameter("ExchangeRateMethod" , DriveServer.GetExchangeMethod(ParentCompany));
	
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractTypesListForDocument(Ref, OperationKind);
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Company,
		ContractTypesList);
	
	StructureContractCurrencyRateByDefault = CurrencyRateOperations.GetCurrencyRate(Date, ContractByDefault.SettlementsCurrency, Company);
	
	PaymentDetails.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	ByGroupsSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	ExchangeRateMethod = DriveServer.GetExchangeMethod(Company);
	
	While ByGroupsSelection.Next() And AmountLeftToDistribute > 0 Do
		
		If ByGroupsSelection.AmountCurDocument - ByGroupsSelection.DiscountAmountCurDocument <= AmountLeftToDistribute Then
			EPD				= ByGroupsSelection.DiscountAmountCurDocument;
			SettlementEPD	= ByGroupsSelection.DiscountAmountCur;
		Else
			EPD				= 0;
			SettlementEPD	= 0;
		EndIf;
		
		SelectionOfQueryResult = ByGroupsSelection.Select();
		
		While SelectionOfQueryResult.Next() And AmountLeftToDistribute > 0 Do
			
			NewRow = PaymentDetails.Add();
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurDocument >= EPD Then
				
				AmountCurDocument	= SelectionOfQueryResult.AmountCurDocument - EPD;
				AmountCur			= SelectionOfQueryResult.AmountCur - SettlementEPD;
				EPDAmountDocument	= EPD;
				EPDAmount			= SettlementEPD;
				EPD					= 0;
				SettlementEPD		= 0;
			Else
				
				AmountCurDocument	= 0;
				AmountCur			= 0;
				EPDAmountDocument	= SelectionOfQueryResult.AmountCurDocument;
				EPDAmount			= SelectionOfQueryResult.AmountCur;
				EPD					= EPD - SelectionOfQueryResult.AmountCurDocument;
				SettlementEPD		= SettlementEPD - SelectionOfQueryResult.AmountCur;
				
			EndIf;
			
			If AmountCurDocument <= AmountLeftToDistribute Then
				
				NewRow.SettlementsAmount	= AmountCur;
				NewRow.PaymentAmount		= AmountCurDocument;
				NewRow.EPDAmount			= EPDAmountDocument;
				NewRow.SettlementsEPDAmount	= EPDAmount;
				
				VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
				
				NewRow.VATRate = VATRateData.VATRate;
				
				VATAmount					= NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100);
				NewRow.VATAmount			= VATAmount;
				
				AmountLeftToDistribute		= AmountLeftToDistribute - AmountCurDocument;
				VATAmountLeftToDistribute	= VATAmountLeftToDistribute - NewRow.VATAmount;
				
			Else
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					ExchangeRateMethod,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity);
				
				NewRow.PaymentAmount		= AmountLeftToDistribute;
				NewRow.EPDAmount			= 0;
				NewRow.SettlementsEPDAmount	= 0;
				
				VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
				
				NewRow.VATRate = VATRateData.VATRate;
				
				VATAmount					= ?(
					VATAmountLeftToDistribute > 0, 
					VATAmountLeftToDistribute,
					NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100));
					
				NewRow.VATAmount			= VATAmount;
					
				AmountLeftToDistribute		= 0;
				VATAmountLeftToDistribute	= 0;
				
			EndIf;
		EndDo;
	EndDo;
	
	If AmountLeftToDistribute > 0 Then
		
		NewRow = PaymentDetails.Add();
		
		NewRow.Contract = ContractByDefault;
		NewRow.ExchangeRate = ?(
			StructureContractCurrencyRateByDefault.Rate = 0,
			1,
			StructureContractCurrencyRateByDefault.Rate);
			
		NewRow.Multiplicity = ?(
			StructureContractCurrencyRateByDefault.Repetition = 0,
			1,
			StructureContractCurrencyRateByDefault.Repetition);
			
		NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
			AmountLeftToDistribute,
			ExchangeRateMethod,
			ExchangeRateCurrenciesDC,
			NewRow.ExchangeRate,
			CurrencyUnitConversionFactor,
			NewRow.Multiplicity);
			
		NewRow.AdvanceFlag			= True;
		NewRow.Order				= ?(IsOrderSet, BasisDocument, Undefined);
		NewRow.PaymentAmount		= AmountLeftToDistribute;
		NewRow.EPDAmount			= 0;
		NewRow.SettlementsEPDAmount	= 0;
		
		VATRateData = DriveServer.DocumentVATRateData(NewRow.Document, DefaultVATRate);
		
		NewRow.VATRate = VATRateData.VATRate;
		
		VATAmount					= ?(
			VATAmountLeftToDistribute > 0, 
			VATAmountLeftToDistribute,
			NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((VATRateData.Rate + 100) / 100));
					
		NewRow.VATAmount			= VATAmount;
		
		AmountLeftToDistribute		= 0;
		VATAmountLeftToDistribute	= 0;
		
		NewRow.Item					= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		
	EndIf;
	
	If PaymentDetails.Count() = 0 Then
		NewRow = PaymentDetails.Add();
		NewRow.Contract			= ContractByDefault;
		NewRow.Item				= Common.ObjectAttributeValue(NewRow.Contract, "CashFlowItem");
		NewRow.PaymentAmount	= DocumentAmount;
	EndIf;
	
	PaymentAmount = PaymentDetails.Total("PaymentAmount");
	
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
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity
	|INTO DocumentHeader
	|FROM
	|	Document.SalesOrder AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(POSTerminals.Ref) AS POSTerminal,
	|	MAX(POSTerminals.Ref) AS POSTerminalForCheck,
	|	DocumentHeader.CashCurrency AS Currency
	|INTO POSTerminals
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocumentHeader.Company = POSTerminals.Company
	|			AND (NOT POSTerminals.DeletionMark)
	|			AND (POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments))
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON DocumentHeader.CashCurrency = CounterpartyContracts.SettlementsCurrency
	|			AND (POSTerminals.PaymentProcessorContract = CounterpartyContracts.Ref)
	|
	|GROUP BY
	|	DocumentHeader.CashCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer) AS OperationKind,
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
	|	CatalogPOSTerminals.ExpenseItem AS ExpenseItem,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentHeader.Ref
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	TRUE AS AdvanceFlag,
	|	UNDEFINED AS Document,
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
	|		ON (POSTerminals.POSTerminal = POSTerminals.POSTerminalForCheck)
	|		LEFT JOIN Catalog.POSTerminals AS CatalogPOSTerminals
	|		ON POSTerminals.POSTerminal = CatalogPOSTerminals.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	POSTerminals.POSTerminal,
	|	CatalogPOSTerminals.ExpenseItem,
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
	|	DocumentHeader.CashCurrency,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.VATRate";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		If ValueIsFilled(POSTerminal) Then
			ExludeProperties = "POSTerminal,ExpenseItem";
		Else
			ExludeProperties = "";
		EndIf;
		FillPropertyValues(ThisObject, Selection, , ExludeProperties);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
EndProcedure

Procedure FillBySalesInvoice(FillingData)
	
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
	|	DocumentHeader.ContractCurrencyExchangeRate AS ContractCurrencyExchangeRate,
	|	DocumentHeader.ContractCurrencyMultiplicity AS ContractCurrencyMultiplicity,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|INTO DocumentHeader
	|FROM
	|	Document.SalesInvoice AS DocumentHeader
	|WHERE
	|	DocumentHeader.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	MIN(POSTerminals.Ref) AS POSTerminal,
	|	MAX(POSTerminals.Ref) AS POSTerminalForCheck,
	|	DocumentHeader.CashCurrency AS Currency
	|INTO POSTerminals
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		INNER JOIN Catalog.POSTerminals AS POSTerminals
	|		ON DocumentHeader.Company = POSTerminals.Company
	|			AND (NOT POSTerminals.DeletionMark)
	|			AND (POSTerminals.TypeOfPOS = VALUE(Enum.TypesOfPOS.OnlinePayments))
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON DocumentHeader.CashCurrency = CounterpartyContracts.SettlementsCurrency
	|			AND (POSTerminals.PaymentProcessorContract = CounterpartyContracts.Ref)
	|
	|GROUP BY
	|	DocumentHeader.CashCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	VALUE(Enum.OperationTypesOnlineReceipt.FromCustomer) AS OperationKind,
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
	|	CatalogPOSTerminals.ExpenseItem AS ExpenseItem,
	|	DocumentHeader.Counterparty AS Counterparty,
	|	DocumentHeader.CashCurrency AS CashCurrency,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN DocumentTable.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
	|	DocumentHeader.Contract AS Contract,
	|	FALSE AS AdvanceFlag,
	|	&Ref AS Document,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS SettlementsAmount,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate) AS ExchangeRate,
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity) AS Multiplicity,
	|	SUM(DocumentTable.Total + DocumentTable.SalesTaxAmount) AS PaymentAmount,
	|	DocumentTable.VATRate AS VATRate,
	|	SUM(DocumentTable.VATAmount) AS VATAmount,
	|	DocumentHeader.AccountsReceivableGLAccount AS AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount AS AdvancesReceivedGLAccount
	|FROM
	|	DocumentHeader AS DocumentHeader
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON DocumentHeader.Counterparty = Counterparties.Ref
	|		LEFT JOIN Document.SalesInvoice.Inventory AS DocumentTable
	|		ON DocumentHeader.Ref = DocumentTable.Ref
	|		LEFT JOIN POSTerminals AS POSTerminals
	|		ON (POSTerminals.POSTerminal = POSTerminals.POSTerminalForCheck)
	|		LEFT JOIN Catalog.POSTerminals AS CatalogPOSTerminals
	|		ON POSTerminals.POSTerminal = CatalogPOSTerminals.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON DocumentHeader.Contract = Contracts.Ref
	|		LEFT JOIN InformationRegister.ExchangeRate.SliceLast(&Date, ) AS SettlementsRates
	|		ON (Contracts.SettlementsCurrency = SettlementsRates.Currency)
	|			AND DocumentHeader.Company = SettlementsRates.Company
	|
	|GROUP BY
	|	DocumentHeader.Ref,
	|	POSTerminals.POSTerminal,
	|	CatalogPOSTerminals.ExpenseItem,
	|	DocumentHeader.Company,
	|	DocumentHeader.CompanyVATNumber,
	|	DocumentHeader.VATTaxation,
	|	Counterparties.DoOperationsByOrders,
	|	DocumentTable.Order,
	|	DocumentHeader.Contract,
	|	CASE
	|		WHEN ISNULL(Contracts.CashFlowItem, VALUE(Catalog.CashFlowItems.EmptyRef)) = VALUE(Catalog.CashFlowItems.EmptyRef)
	|			THEN VALUE(Catalog.CashFlowItems.PaymentFromCustomers)
	|		ELSE Contracts.CashFlowItem
	|	END,
	|	ISNULL(SettlementsRates.Rate, DocumentHeader.ContractCurrencyExchangeRate),
	|	ISNULL(SettlementsRates.Repetition, DocumentHeader.ContractCurrencyMultiplicity),
	|	DocumentHeader.CashCurrency,
	|	DocumentHeader.Counterparty,
	|	DocumentTable.VATRate,
	|	DocumentHeader.AccountsReceivableGLAccount,
	|	DocumentHeader.AdvancesReceivedGLAccount";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		
		If ValueIsFilled(POSTerminal) Then
			ExludeProperties = "POSTerminal,ExpenseItem";
		Else
			ExludeProperties = "";
		EndIf;
		FillPropertyValues(ThisObject, Selection, , ExludeProperties);
		
		PaymentDetails.Clear();
		NewRow = PaymentDetails.Add();
		FillPropertyValues(NewRow, Selection);
		DocumentAmount = Selection.PaymentAmount;
		
		While Selection.Next() Do
			NewRow = PaymentDetails.Add();
			FillPropertyValues(NewRow, Selection);
			DocumentAmount = DocumentAmount + Selection.PaymentAmount;
		EndDo;
		
		DefinePaymentDetailsExistsEPD();
		
	EndIf;
	
EndProcedure

Procedure DefinePaymentDetailsExistsEPD() Export
	
	If OperationKind = Enums.OperationTypesOnlineReceipt.FromCustomer And PaymentDetails.Count() > 0 Then
		
		DocumentArray			= PaymentDetails.UnloadColumn("Document");
		CheckDate				= ?(ValueIsFilled(Date), Date, CurrentSessionDate());
		DocumentArrayWithEPD	= Documents.SalesInvoice.GetSalesInvoiceArrayWithEPD(DocumentArray, CheckDate);
		
		For Each TabularSectionRow In PaymentDetails Do
			
			If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.SalesInvoice") Then
				If DocumentArrayWithEPD.Find(TabularSectionRow.Document) = Undefined Then
					TabularSectionRow.ExistsEPD = False;
				Else
					TabularSectionRow.ExistsEPD = True;
				EndIf;
			Else
				TabularSectionRow.ExistsEPD = False;
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
