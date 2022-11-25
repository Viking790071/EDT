#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Date = EndOfMonth(Date);
	
	FindExistDocumentsInCurrentPeriod(Cancel);
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.MonthEndClosing.InitializeDocumentData(Ref, AdditionalProperties);
	
	DriveServer.ReflectForeignExchangeGainsAndLosses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFundsTransfersBeingProcessed(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectFinancialResult(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectMonthEndErrors(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	// begin Drive.FullVersion
	DriveServer.ReflectWorkInProgress(AdditionalProperties, RegisterRecords, Cancel);
	// end Drive.FullVersion
	
	DriveServer.ReflectCostOfSubcontractorGoods(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	If AdditionalProperties.AccountingPolicy.UseTemplateBasedTypesOfAccounting Then
		DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	InventoryValuationMethod = InformationRegisters.AccountingPolicy.InventoryValuationMethod(Date, Company);
	
	If InventoryValuationMethod = Enums.InventoryValuationMethods.FIFO Then
		
		InformationRegisters.TasksForCostsCalculation.CreateRegisterRecord(
			BegOfMonth(Date),
			Company,
			Ref);
		
	EndIf;
	
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

#EndRegion

#Region Private

#Region DocumentsInPeriods

Procedure FindExistDocumentsInCurrentPeriod(Cancel)
	
	Query = New Query(
	"SELECT ALLOWED
	|	MonthEndClosing.Ref AS Ref,
	|	MonthEndClosing.DirectCostCalculation AS DirectCostCalculation,
	|	MonthEndClosing.CostAllocation AS CostAllocation,
	|	MonthEndClosing.ActualCostCalculation AS ActualCostCalculation,
	|	MonthEndClosing.FinancialResultCalculation AS FinancialResultCalculation,
	|	MonthEndClosing.ExchangeDifferencesCalculation AS ExchangeDifferencesCalculation,
	|	MonthEndClosing.RetailCostCalculationEarningAccounting AS RetailCostCalculationEarningAccounting,
	|	MonthEndClosing.VerifyTaxInvoices AS VerifyTaxInvoices,
	|	MonthEndClosing.VATPayableCalculation AS VATPayableCalculation
	|INTO ExistingDocuments
	|FROM
	|	Document.MonthEndClosing AS MonthEndClosing
	|WHERE
	|	MonthEndClosing.Posted
	|	AND ENDOFPERIOD(MonthEndClosing.Date, MONTH) = &Date
	|	AND MonthEndClosing.Company = &Company
	|	AND MonthEndClosing.Ref <> &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TRUE
	|FROM
	|	ExistingDocuments AS MonthEndClosing
	|WHERE
	|	(MonthEndClosing.DirectCostCalculation = &DirectCostCalculation
	|				AND MonthEndClosing.DirectCostCalculation
	|			OR MonthEndClosing.CostAllocation = &CostAllocation
	|				AND MonthEndClosing.CostAllocation
	|			OR MonthEndClosing.ActualCostCalculation = &ActualCostCalculation
	|				AND MonthEndClosing.ActualCostCalculation
	|			OR MonthEndClosing.FinancialResultCalculation = &FinancialResultCalculation
	|				AND MonthEndClosing.FinancialResultCalculation
	|			OR MonthEndClosing.ExchangeDifferencesCalculation = &ExchangeDifferencesCalculation
	|				AND MonthEndClosing.ExchangeDifferencesCalculation
	|			OR MonthEndClosing.RetailCostCalculationEarningAccounting = &RetailCostCalculationEarningAccounting
	|				AND MonthEndClosing.RetailCostCalculationEarningAccounting
	|			OR MonthEndClosing.VerifyTaxInvoices = &VerifyTaxInvoices
	|				AND MonthEndClosing.VerifyTaxInvoices
	|			OR MonthEndClosing.VATPayableCalculation = &VATPayableCalculation
	|				AND MonthEndClosing.VATPayableCalculation)");
	
	Query.SetParameter("Date", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("DirectCostCalculation", DirectCostCalculation);
	Query.SetParameter("CostAllocation", CostAllocation);
	Query.SetParameter("ActualCostCalculation", ActualCostCalculation);
	Query.SetParameter("FinancialResultCalculation", FinancialResultCalculation);
	Query.SetParameter("ExchangeDifferencesCalculation", ExchangeDifferencesCalculation);
	Query.SetParameter("RetailCostCalculationEarningAccounting", RetailCostCalculationEarningAccounting);
	Query.SetParameter("VerifyTaxInvoices", VerifyTaxInvoices);
	Query.SetParameter("VATPayableCalculation", VATPayableCalculation);
	
	ExistDocuments = Query.Execute().Select();
	If ExistDocuments.Next() Then
		ExceptionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("en = 'The document ""Month-end closing"" in month %1 is already exist in infobase.'; ru = 'Документ ""Закрытие месяца"" за %1 уже создан в базе.';pl = 'Dokument ""Zamknięcie miesiąca"" w miesiącu %1 już istnieje w bazie informacyjnej.';es_ES = 'El documento ""Cierre del mes"" para el mes %1 ya existe en la infobase.';es_CO = 'El documento ""Cierre del mes"" para el mes %1 ya existe en la infobase.';tr = '%1 ayındaki ""Ay sonu kapanışı"" belgesi Infobase''de zaten mevcut.';it = 'Il documento ""Chiusura di fine mese"" nel mese %1 già esiste nel infobase.';de = 'Das Dokument ""Monatsabschluss"" im Monat %1 ist bereits in der Infobase vorhanden.'"),
			Format(Date, "DF='MMMM yyyy'"));
		CommonClientServer.MessageToUser(ExceptionText, , , , Cancel);
	EndIf;
	
EndProcedure

#EndRegion


#EndRegion

#EndIf
