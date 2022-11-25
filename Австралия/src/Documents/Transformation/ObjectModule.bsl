#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillByTransformationTemplate() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	TransformationTemplates.SourceChartOfAccounts AS ChartOfAccountsSource,
	|	TransformationTemplates.ReceivingChartOfAccounts AS ChartOfAccounts,
	|	TransformationTemplates.SourceAccountingRegister AS AccountingRegisterSource,
	|	TransformationTemplates.ReceivingAccountingRegister AS AccountingRegister
	|FROM
	|	Catalog.TransformationTemplates AS TransformationTemplates
	|WHERE
	|	TransformationTemplates.Ref = &Ref";
	
	Query.SetParameter("Ref", TransformationTemplate);
	
	ResultTable = Query.Execute().Unload();
	
	If ResultTable.Count() > 0 Then
		
		FillPropertyValues(ThisObject, ResultTable[0]);
		
	EndIf;
	
EndProcedure

Procedure FillDocumentPostings() Export
	
	Postings.Clear();
	
	If NOT ValueIsFilled(AccountingRegister) OR NOT ValueIsFilled(AccountingRegisterSource) Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountingJournalEntries.Period AS PostingDate,
	|	AccountingJournalEntries.AccountDr AS DebitSource,
	|	&EmptyChartOfAccountsRecepient AS Debit,
	|	AccountingJournalEntries.AccountCr AS CreditSource,
	|	&EmptyChartOfAccountsRecepient AS Credit,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.Content AS Content
	|FROM
	|	&AccountingJournalEntries AS AccountingJournalEntries
	|WHERE
	|	AccountingJournalEntries.Active
	|	AND AccountingJournalEntries.Company = &Company
	|	AND AccountingJournalEntries.Period BETWEEN &StartDate AND &EndDate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GLAccountsMapping.ReceivingAccount AS ReceivingAccount,
	|	GLAccountsMapping.SourceAccount AS SourceAccount,
	|	GLAccountsMapping.CorrSourceAccount AS CorrSourceAccount,
	|	TranslationRules.UseDr AS UseDr,
	|	TranslationRules.UseCr AS UseCr
	|FROM
	|	Catalog.Mapping AS GLAccountsMapping
	|		INNER JOIN InformationRegister.MappingRules AS TranslationRules
	|		ON GLAccountsMapping.Ref = TranslationRules.AccountsMapping
	|			AND GLAccountsMapping.Owner = TranslationRules.TranslationTemplate
	|WHERE
	|	GLAccountsMapping.Owner = &TransformationTemplate
	|	AND NOT GLAccountsMapping.SourceAccount IN (&EmptyCharts)
	|	AND NOT GLAccountsMapping.CorrSourceAccount IN (&EmptyCharts)
	|	AND NOT GLAccountsMapping.DeletionMark
	|	AND (TranslationRules.UseDr
	|			OR TranslationRules.UseCr)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GLAccountsMapping.ReceivingAccount AS ReceivingAccount,
	|	GLAccountsMapping.SourceAccount AS SourceAccount,
	|	TranslationRules.UseDr AS UseDr,
	|	TranslationRules.UseCr AS UseCr
	|FROM
	|	Catalog.Mapping AS GLAccountsMapping
	|		INNER JOIN InformationRegister.MappingRules AS TranslationRules
	|		ON GLAccountsMapping.Ref = TranslationRules.AccountsMapping
	|			AND GLAccountsMapping.Owner = TranslationRules.TranslationTemplate
	|WHERE
	|	GLAccountsMapping.Owner = &TransformationTemplate
	|	AND NOT GLAccountsMapping.SourceAccount IN (&EmptyCharts)
	|	AND GLAccountsMapping.CorrSourceAccount IN(&EmptyCharts)
	|	AND NOT GLAccountsMapping.DeletionMark
	|	AND (TranslationRules.UseDr
	|			OR TranslationRules.UseCr)";
	
	EmptyCharts = New Array;
	EmptyCharts.Add(Undefined);
	
	For Each MetadataChart In Metadata.ChartsOfAccounts Do
		EmptyCharts.Add(PredefinedValue("ChartOfAccounts." + MetadataChart.Name + ".EmptyRef"));
	EndDo;
	
	AccountingRegisterSourceName	= Common.ObjectAttributeValue(AccountingRegisterSource, "Name");
	ChartOfAccountsName				= Common.ObjectAttributeValue(ChartOfAccounts, "Name");
	EmptyChartOfAccountsRecepient	= PredefinedValue("ChartOfAccounts." + ChartOfAccountsName + ".EmptyRef");
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("StartDate", BegOfDay(StartDate));
	Query.SetParameter("EndDate", EndOfDay(EndDate));
	Query.SetParameter("EmptyCharts", EmptyCharts);
	Query.SetParameter("TransformationTemplate", TransformationTemplate);
	Query.SetParameter("EmptyChartOfAccountsRecepient", EmptyChartOfAccountsRecepient);
	
	Query.Text = StrReplace(Query.Text, "&AccountingJournalEntries", "AccountingRegister." + AccountingRegisterSourceName);
	
	QueryResult = Query.ExecuteBatch();
	
	EntriesTable			= QueryResult[0].Unload();
	MappingWithCorrTable	= QueryResult[1].Unload();
	MappingTable			= QueryResult[2].Unload();
	
	If MappingWithCorrTable.Count() > 0 Then
		MappingWithCorrTable.Indexes.Add("SourceAccount, CorrSourceAccount, UseDr");
		MappingWithCorrTable.Indexes.Add("SourceAccount, CorrSourceAccount, UseCr");
	EndIf;
	
	If MappingTable.Count() > 0 Then
		MappingTable.Indexes.Add("SourceAccount, UseDr");
		MappingTable.Indexes.Add("SourceAccount, UseCr");
	EndIf;
	
	For Each Entry In EntriesTable Do
		
		// Debit
		SearchStructure = New Structure("SourceAccount, CorrSourceAccount, UseDr", Entry.DebitSource, Entry.CreditSource, True);
		MappingRowsCorr = MappingWithCorrTable.FindRows(SearchStructure);
		
		If MappingRowsCorr.Count() > 0 Then
			
			Entry.Debit = MappingRowsCorr[0].ReceivingAccount;
			
		Else
			
			SearchStructure = New Structure("SourceAccount, UseDr", Entry.DebitSource, True);
			MappingRows = MappingTable.FindRows(SearchStructure);
			
			If MappingRows.Count() > 0 Then
				
				Entry.Debit = MappingRows[0].ReceivingAccount;
				
			EndIf;
			
		EndIf;
		
		// Credit
		SearchStructure = New Structure("SourceAccount, CorrSourceAccount, UseCr", Entry.CreditSource, Entry.DebitSource, True);
		MappingRowsCorr = MappingWithCorrTable.FindRows(SearchStructure);
		
		If MappingRowsCorr.Count() > 0 Then
			
			Entry.Credit = MappingRowsCorr[0].ReceivingAccount;
			
		Else
			
			SearchStructure = New Structure("SourceAccount, UseCr", Entry.CreditSource, True);
			MappingRows = MappingTable.FindRows(SearchStructure);
			
			If MappingRows.Count() > 0 Then
				
				Entry.Credit = MappingRows[0].ReceivingAccount;
				
			EndIf;
			
		EndIf;
		
		If ValueIsFilled(Entry.Debit) AND ValueIsFilled(Entry.Credit) Then
			FillPropertyValues(Postings.Add(), Entry);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.Transformation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectAccountingRegister(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
EndProcedure

#EndRegion

#EndIf