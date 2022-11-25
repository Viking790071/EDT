#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	Date = Common.CurrentUserDate();
	
	For Each RecordSet In CopiedObject.RegisterRecords Do
		
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			Continue;
		EndIf;
		
		RegisterName = RecordSet.Metadata().Name;
		RecordSetTable = RecordSet.Unload();
		RecordSetTable.FillValues(Undefined, "Recorder");
		RegisterRecords[RegisterName].Load(RecordSetTable);
		
	EndDo;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	If ValueIsFilled(Company)
		And Not ValueIsFilled(TypeOfAccounting)
		And Not ValueIsFilled(ChartOfAccounts) Then
		
		TypesOfAccounting = AccountingTemplatesPosting.GetApplicableTypesOfAccounting(Company, Date, Catalogs.TypesOfAccounting.EmptyRef(), Undefined, True);
		
		If TypesOfAccounting.Count() = 1 Then
			
			TypeOfAccounting = TypesOfAccounting[0].TypeOfAccounting;
			ChartOfAccounts = TypesOfAccounting[0].ChartOfAccounts;
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each RecordSet In RegisterRecords Do
		
		If Not RecordSet.Write Then
			RecordSet.Read();
			RecordSet.Write = True;
		EndIf;
		
	EndDo;
	
	AccountingJournalEntries = New ValueTable;
	AccountingJournalEntries.Columns.Add("Period"		, New TypeDescription("Date"));
	AccountingJournalEntries.Columns.Add("Account"		, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	AccountingJournalEntries.Columns.Add("AccountDr"	, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	AccountingJournalEntries.Columns.Add("AccountCr"	, New TypeDescription("ChartOfAccountsRef.MasterChartOfAccounts"));
	AccountingJournalEntries.Columns.Add("RecordType"	, New TypeDescription("AccountingRecordType"));
	AccountingJournalEntries.Columns.Add("Amount"		, New TypeDescription("Number"));
	AccountingJournalEntries.Columns.Add("EntryNumber"	, New TypeDescription("Number"));
	AccountingJournalEntries.Columns.Add("LineNumber"	, New TypeDescription("Number"));
	
	FieldsList = "Period, Account, RecordType, Amount, EntryNumber, LineNumber";
	For Each EntryRow In RegisterRecords.AccountingJournalEntriesCompound Do
		
		NewRow = AccountingJournalEntries.Add();
		FillPropertyValues(NewRow, EntryRow, FieldsList);
		
	EndDo;
	
	FieldsList = "Period, AccountDr, AccountCr, Amount, LineNumber";
	For Each EntryRow In RegisterRecords.AccountingJournalEntriesSimple Do
		
		NewRow = AccountingJournalEntries.Add();
		FillPropertyValues(NewRow, EntryRow, FieldsList);
		
		NewRow.EntryNumber = EntryRow.LineNumber;
		
	EndDo;
	
	EntriesTable = New Array;
	EntriesTableRow = New Structure;
	EntriesTableRow.Insert("TypeOfAccounting"	, TypeOfAccounting);
	EntriesTableRow.Insert("ChartOfAccounts"	, ChartOfAccounts);
	EntriesTableRow.Insert("Entries"			, AccountingJournalEntries);
	EntriesTable.Add(EntriesTableRow);
	
	If WriteMode = DocumentWriteMode.Posting
		And (IsManual Or (AdditionalProperties.Property("AdjustedManually") And AdditionalProperties.AdjustedManually)) Then
		
		AccountingTemplatesPosting.CheckTransactionsFilling(ThisObject, EntriesTable, Cancel, Not IsManual);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	FillRecordFieldsFromHeader();
	SetupDocumentAccountingEntriesStatuses();
	SetupRecordsActivity(WriteMode);
	
	If WriteMode = DocumentWriteMode.UndoPosting Then
		RegisterRecords.Write();
	EndIf;
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
		
EndProcedure

#EndRegion

#Region Private

Procedure SetupRecordsActivity(WriteMode)
	
	Activity = (WriteMode = DocumentWriteMode.Posting Or (Posted And WriteMode = DocumentWriteMode.Write));
	
	For Each RecordSet In RegisterRecords Do
		
		For Each Record In RecordSet Do
			
			If Record.Active = Activity Then
				Continue;
			EndIf;
			
			Record.Active = Activity;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure SetupDocumentAccountingEntriesStatuses()
	
	RecordSet = RegisterRecords.DocumentAccountingEntriesStatuses;
	
	If RecordSet.Count() < 1 Then
		Record = RecordSet.Add();
		Record.Status = Enums.AccountingEntriesStatus.NotApproved;
	Else
		Record = RecordSet[0];
	EndIf;
	
	FillPropertyValues(Record, ThisObject, "Company, TypeOfAccounting, ChartOfAccounts, DocumentCurrency, Author, Comment");
	Record.Period = Date;
	
EndProcedure

Procedure FillRecordFieldsFromHeader()
	
	HeaderAttributes = New Structure("Company, TypeOfAccounting, ChartOfAccounts");
	FillPropertyValues(HeaderAttributes, ThisObject);
	
	For Each RecordSet In RegisterRecords Do
		
		For Each Record In RecordSet Do
			FillPropertyValues(Record, HeaderAttributes);
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf