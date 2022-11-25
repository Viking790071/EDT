#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PresentationCurrency = DriveServer.GetPresentationCurrency(Company);
	
	DoNotCheckER = NOT BankCharge.ChargeType = Enums.ChargeMethod.SpecialExchangeRate;
	
	If DoNotCheckER OR FromAccountCurrency = PresentationCurrency Then 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "FromAccountExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "FromAccountMultiplicity");
	EndIf;
	
	If DoNotCheckER OR ToAccountCurrency = PresentationCurrency Then 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ToAccountExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ToAccountMultiplicity");
	EndIf;
	
	If FromAccountCurrency = ToAccountCurrency Then
		CommonClientServer.MessageToUser(
			NStr("en = 'Please, select accounts of different currencies'; ru = 'Укажите счета с разными валютами';pl = 'Proszę wybrać konta w różnych walutach';es_ES = 'Por favor, seleccione las cuentas de las monedas diferentes';es_CO = 'Por favor, seleccione las cuentas de las monedas diferentes';tr = 'Lütfen farklı para birimlerinde olan hesapları seçin';it = 'Per piacere, selezionare conti di valute differenti';de = 'Bitte wählen Sie Konten in verschiedenen Währungen aus.'"),
			Ref,
			"ToAccount",
			"Object",
			Cancel);
	EndIf;
	
	If Not GetFunctionalOption("UseBankCharges") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankCharge");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeItem");
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	// Initialization of document data
	Documents.ForeignCurrencyExchange.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBankReconciliation(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.ForeignCurrencyExchange.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Posting, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.ForeignCurrencyExchange.RunControl(Ref, AdditionalProperties, Cancel);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		
		If Not ValueIsFilled(FromAccount) Then
			FromAccount = Company.BankAccountByDefault;
		EndIf;
		
		If Not ValueIsFilled(ToAccount) Then
			ToAccount = Company.BankAccountByDefault;
		EndIf;
		
		Item = Catalogs.CashFlowItems.Other;
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
	If IsNew() Then
		
		BankAccountsType = Type("CatalogRef.BankAccounts");
		If ValueIsFilled(FromAccount) And TypeOf(FromAccount) = BankAccountsType Then
			FromAccountCurrency = Common.ObjectAttributeValue(FromAccount, "CashCurrency");
		EndIf;
		
		If ValueIsFilled(ToAccount) And TypeOf(ToAccount) = BankAccountsType Then
			ToAccountCurrency = Common.ObjectAttributeValue(ToAccount, "CashCurrency");
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
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
