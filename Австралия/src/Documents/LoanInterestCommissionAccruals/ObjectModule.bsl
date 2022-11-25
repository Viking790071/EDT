#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	AccrualPeriod = New StandardPeriod;
	AccrualPeriod.Variant	= StandardPeriodVariant.LastMonth;
	StartDate				= AccrualPeriod.StartDate;
	EndDate					= AccrualPeriod.EndDate;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

// Procedure - handler of the PostingProcessing event of the object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties to post the document
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization
	Documents.LoanInterestCommissionAccruals.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Prepare record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record in accounting sections
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the PopulationCheckProcessing event of the object.
//
Procedure FillCheckProcessing(Cancel, AttributesToCheck)
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Accruals.Borrower");
	Else
		DriveServer.DeleteAttributeBeingChecked(AttributesToCheck, "Accruals.Lender");
	EndIf;
	
	If ValueIsFilled(StartDate) And ValueIsFilled(EndDate)
		And StartDate > EndDate Then
		
		MessageText = NStr("en = 'Incorrect period is specified. Start date > End date.'; ru = 'Указан неверный период. Дата начала > Даты окончания!.';pl = 'Określono nieprawidłowy okres. Data rozpoczęcia > Data zakończenia.';es_ES = 'Período incorrecto está especificado. Fecha del inicio > Fecha del fin.';es_CO = 'Período incorrecto está especificado. Fecha del inicio > Fecha del fin.';tr = 'Yanlış dönem belirtildi. Başlangıç tarihi > Bitiş tarihi.';it = 'E'' specificato un periodo non corretto. Data di inizio > Data di fine.';de = 'Falscher Zeitraum ist angegeben. Startdatum> Enddatum.'");
		
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			,
			,
			"StartDate",
			Cancel);
		
	EndIf;
	
EndProcedure

// Procedure - handler of the PostingDeletionProcessing of the object event.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to post the document
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Prepare record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

// Procedure - handler of the BeforeWriting event of the object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
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

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

#EndRegion

#EndIf
