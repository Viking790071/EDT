#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	Documents.BankReconciliation.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectBankReconciliation(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);

	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.BankReconciliation.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	Documents.BankReconciliation.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	UncheckedAttributes = New Array;
	
	If Not UseServiceCharge Then
		
		UncheckedAttributes.Add("ServiceChargeType");
		UncheckedAttributes.Add("ServiceChargeCashFlowItem");
		UncheckedAttributes.Add("ExpenseItem");
		UncheckedAttributes.Add("ServiceChargeAccount");
		UncheckedAttributes.Add("ServiceChargeAmount");
		UncheckedAttributes.Add("ServiceChargeDate");
		UncheckedAttributes.Add("ExpenseItem");
		
	EndIf;
	
	If Not UseInterestEarned Then
		
		UncheckedAttributes.Add("InterestEarnedCashFlowItem");
		UncheckedAttributes.Add("IncomeItem");
		UncheckedAttributes.Add("InterestEarnedAccount");
		UncheckedAttributes.Add("InterestEarnedAmount");
		UncheckedAttributes.Add("InterestEarnedDate");
		UncheckedAttributes.Add("IncomeItem");
		
	EndIf;
	
	If Not GetFunctionalOption("UseDefaultTypeOfAccounting") Then
		UncheckedAttributes.Add("ServiceChargeAccount");
		UncheckedAttributes.Add("InterestEarnedAccount");
	EndIf;
	
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, UncheckedAttributes);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;

EndProcedure

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

#EndRegion

#EndIf
