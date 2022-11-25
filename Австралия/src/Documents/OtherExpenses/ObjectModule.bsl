#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Expenses.Total("Amount");
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData); 
	
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
	Documents.OtherExpenses.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

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
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OtherSettlementsAccounting Then
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.AccountsReceivable
			AND Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.AccountsPayable Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			
		EndIf;
		
		For Each CurrentRowExpenses In Expenses Do
			If CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.AccountsReceivable 
				Or CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.AccountsPayable Then
				
				If CurrentRowExpenses.Counterparty.IsEmpty() Then
					MessageText = NStr("en = 'Specify the counterparty in the line %LineNumber% of the list ""Expenses""'; ru = 'Укажите контрагента в строке %LineNumber% списка ""Расходы"".';pl = 'Określ kontrahenta w wierszu %LineNumber% listy ""Koszty""';es_ES = 'Especificar la contraparte en la línea %LineNumber% de la lista ""Gastos""';es_CO = 'Especificar la contraparte en la línea %LineNumber% de la lista ""Gastos""';tr = 'Cari hesabı ""Giderler"" listesinin %LineNumber% satırında belirtin';it = 'Specificare la controparte nella linea %LineNumber% dell''elenco ""Spese""';de = 'Geben Sie den Geschäftspartner in der Zeile %LineNumber% der Liste ""Ausgaben"" an'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Counterparty",
						Cancel
					);
				ElsIf CurrentRowExpenses.Counterparty.DoOperationsByContracts AND CurrentRowExpenses.Contract.IsEmpty() Then
					MessageText = NStr("en = 'Specify the contract in the line %LineNumber% of the list ""Expenses""'; ru = 'Укажите договор в строке %LineNumber% списка ""Расходы"".';pl = 'Określ umowę w wierszu %LineNumber% listy ""Koszty""';es_ES = 'Especificar el contrato en la línea %LineNumber% de la lista ""Gastos""';es_CO = 'Especificar el contrato en la línea %LineNumber% de la lista ""Gastos""';tr = 'Sözleşmeyi ""Giderler"" listesinin %LineNumber% satırında belirtin';it = 'Specificare il contratto in linea %LineNumber% dell''elenco ""Spese""';de = 'Geben Sie den Vertrag in der Zeile %LineNumber% der Liste ""Ausgaben"" an'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Contract",
						Cancel
					);
					
				EndIf;
			EndIf;
		EndDo;
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	// Register expense
	For Each Row In Expenses Do
		
		If Row.RegisterExpense And Not ValueIsFilled(Row.ExpenseItem) Then
			DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'Expense item is required in line #%1 of the Expenses list.'; ru = 'Не заполнена статья расходов в строке %1 списка ""Расходы"".';pl = 'Pozycja rozchodów jest wymagana w wierszu #%1 listy Rozchody.';es_ES = 'Se requiere un artículo de gastos en la línea #%1 de la lista de gastos.';es_CO = 'Se requiere un artículo de gastos en la línea #%1 de la lista de gastos.';tr = 'Giderler listesinin %1 nolu satırında gider kalemi gerekli.';it = 'La voce di uscita è richiesta nella riga #%1 dell''Elenco Uscite.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 der Liste Ausgaben erforderlich.'"),
						Row.LineNumber),
					"Expenses",
					Row.LineNumber,
					"ExpenseItem",
					Cancel);
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

Procedure OnCopy(CopiedObject)
	
	Author = Users.CurrentUser();
	
EndProcedure

#EndRegion

#EndIf