#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

#Region DocumentFilling

// Procedure of document filling based on the settlement reconciliation
//
Procedure FillByReconciliationStatement(DocumentReconciliationStatement)
	
	BasisDocument			= DocumentReconciliationStatement;
	Company					= DocumentReconciliationStatement.Company;
	CounterpartyContract	= DocumentReconciliationStatement.Contract;
		
	If ValueIsFilled(CounterpartyContract) Then
		
		If CounterpartyContract.ContractKind = Enums.ContractType.WithCustomer
			Or CounterpartyContract.ContractKind = Enums.ContractType.WithAgent Then
			
			OperationKind		= Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment;
			CounterpartySource	= DocumentReconciliationStatement.Counterparty;
			
		ElsIf CounterpartyContract.ContractKind = Enums.ContractType.WithVendor 
			Or CounterpartyContract.ContractKind = Enums.ContractType.FromPrincipal
			Or CounterpartyContract.ContractKind = Enums.ContractType.SubcontractingServicesReceived Then
			
			OperationKind	= Enums.OperationTypesArApAdjustments.VendorDebtAdjustment;
			Counterparty	= DocumentReconciliationStatement.Counterparty;
			
		EndIf;
		
		BalanceByCompanyData	= DocumentReconciliationStatement.CompanyData.Total("ClientDebtAmount") - DocumentReconciliationStatement.CompanyData.Total("CompanyDebtAmount");
		BalanceByCounterpartyData	= DocumentReconciliationStatement.CounterpartyData.Total("CompanyDebtAmount") - DocumentReconciliationStatement.CounterpartyData.Total("ClientDebtAmount");
		Discrepancy					= BalanceByCompanyData - BalanceByCounterpartyData;
		
		If GetFunctionalOption("UseDefaultTypeOfAccounting") Then
			Correspondence = ?(Discrepancy < 0, 
				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome"), 
				Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses"));
		EndIf;
		
		IncomeAndExpenseItem = ?(Discrepancy < 0,
			Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherIncome"),
			Catalogs.DefaultIncomeAndExpenseItems.GetItem("OtherExpenses"));
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(AccountsDocument) Then
		AccountsDocument = Undefined;
	EndIf;
	
	For Each CurRow In Debitor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	For Each CurRow In Creditor Do
		If Not ValueIsFilled(CurRow.Document) Then
			CurRow.Document = Undefined;
		EndIf;
	EndDo;
	
	If Not ValueIsFilled(Order) Then
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
			Order = Documents.SalesOrder.EmptyRef();
		ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
			Order = Documents.PurchaseOrder.EmptyRef();
		EndIf;
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ForOpeningBalancesOnly Then
		CheckedAttributes.Clear();
		Return;
	EndIf;
	
	If OperationKind = Enums.OperationTypesArApAdjustments.ArApAdjustments 
		Or OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing 
		Or OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.IncomeItem");
		
		If DebitorSumOfAccounting <> CreditorAccountingSum Then
			
			MessageText = NStr("en = 'The amount of the receivables tabular section is not equal to the amount of payables tabular section.'; ru = 'Сумма в табличной части задолженности покупателей не совпадает с суммой в табличной части задолженности поставщикам.';pl = 'Wartość sekcji tabelarycznej należności nie jest równa wartości sekcji tabelarycznej należności.';es_ES = 'El importe la sección de tabla a cobrar no equivale al importe de tabla a pagar.';es_CO = 'El importe la sección de tabla a cobrar no equivale al importe de tabla a pagar.';tr = 'Alacaklar tablo bölümünün tutarı, borçlar tablo bölümünün tutarına eşit değil.';it = 'L''importo della sezione tabellare crediti da ricevere non è uguale all''importo della sezione tabellare debiti da pagare.';de = 'Der Betrag des Tabellenabschnitts Forderungen ist nicht gleich dem Betrag des Tabellenabschnitts Verbindlichkeiten.'");
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Debitor",
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeAndExpenseItem");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, CounterpartySource, Company, OperationKind, "Debitor");
			
			For Each TSRow In Debitor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, Counterparty, Company, OperationKind, "Creditor");
			
			For Each TSRow In Creditor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
		
		If OperationKind = Enums.OperationTypesArApAdjustments.CustomerAdvanceClearing 
			Or OperationKind = Enums.OperationTypesArApAdjustments.SupplierAdvanceClearing Then

			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
			
			For Each TSRow In Debitor Do
				If Not TSRow.AdvanceFlag Then
					
					MessageText = NStr("en = 'Select only the documents with the ""Advance payment"" mark.'; ru = 'Выберите только те документы, у которых есть отметка ""Авансовый платеж"".';pl = 'Wybierz tylko dokumenty ze znakiem ""Zaliczka”.';es_ES = 'Seleccione sólo los documentos con la marca ""Pago de anticipo"".';es_CO = 'Seleccione sólo los documentos con la marca ""Pago Anticipado"".';tr = 'Sadece ""Avans ödeme"" işareti olan belgeleri seçin.';it = 'Selezionare solo i documenti con il contrassegno ""Pagamento anticipato"".';de = 'Wählen Sie nur die Dokumente mit der Markierung „Vorauszahlung“ aus.'");
					CommonClientServer.MessageToUser(
						MessageText,,
						"Object.Debitor[" + Debitor.IndexOf(TSRow) + "].AdvanceFlag",,
						Cancel);
					
				EndIf;
			EndDo;
			
			For Each TSRow In Creditor Do
				If TSRow.AdvanceFlag Then
					
					MessageText = NStr("en = 'Select only the documents without the ""Advance payment"" mark.'; ru = 'Выберите только те документы, у которых нет отметки ""Авансовый платеж"".';pl = 'Wybierz tylko dokumenty bez znaku ""Zaliczka”.';es_ES = 'Seleccione sólo los documentos sin la marca ""Pago de anticipo"".';es_CO = 'Seleccione sólo los documentos sin la marca ""Pago Anticipado"".';tr = 'Sadece ""Avans ödeme"" işareti olmayan belgeleri seçin.';it = 'Selezionare solo i documenti senza il contrassegno ""Pagamento anticipato"".';de = 'Wählen Sie nur die Dokumente ohne Markierung „Vorauszahlung“ aus.'");
					CommonClientServer.MessageToUser(
						MessageText,,
						"Object.Creditor[" + Creditor.IndexOf(TSRow) + "].AdvanceFlag",,
						Cancel);
					
				EndIf;
			EndDo;
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
		
		DebitorSumOfAccounting = Debitor.Total("AccountingAmount");
		MessageText = NStr("en = 'The amount is not equal to the amount in the receivables tabular section.'; ru = 'Сумма не равна сумме табличной части ""Задолженность покупателей""!';pl = 'Wartość nie jest równa wartości w sekcji tabelarycznej należności.';es_ES = 'El importe no es igual al importe en la sección tabular a cobrar.';es_CO = 'El importe no es igual al importe en la sección tabular a cobrar.';tr = 'Tutar, alacakların tablo bölümündeki tutar ile aynı değil.';it = 'L''import non è uguale all''importo nella sezione tabellare crediti da ricevere.';de = 'Der Betrag entspricht nicht dem Betrag im Tabellenbereich der Forderungen.'");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.IncomeItem");
		
		If DebitorSumOfAccounting <> AccountingAmount Then
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeAndExpenseItem");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, CounterpartySource, Company, OperationKind, "Debitor");
			
			For Each TSRow In Debitor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, Counterparty, Company, OperationKind);
			
			Contract = ContractByDefault;
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.DebtAssignmentToVendor Then
		
		CreditorAccountingSum = Creditor.Total("AccountingAmount");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.IncomeItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.IncomeItem");
		
		If CreditorAccountingSum <> AccountingAmount Then
			MessageText = NStr("en = 'Account amount is not equal to amount in the tabular section ""Payables"".'; ru = 'Сумма по счету не равна сумме в табличной части ""Кредиторская задолженность"".';pl = 'Wartość konta nie odpowiada wartości w sekcji tabelarycznej ""Zobowiązania"".';es_ES = 'Importe de la cuenta no es igual al importe en la sección tabular ""A pagar"".';es_CO = 'Importe de la cuenta no es igual al importe en la sección tabular ""A pagar"".';tr = 'Hesap tutarı ""Borçlar"" sekmeli bölümündeki tutarlara eşit değildir.';it = 'L''importo del conto non corrisponde all''importo nella sezione tabellare ""Importi da versare"".';de = 'Der Kontobetrag entspricht nicht dem Betrag im tabellarischen Abschnitt ""Fällig"".'");
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				Undefined,
				1,
				"AccountingAmount",
				Cancel
			);
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Correspondence");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "IncomeAndExpenseItem");
		
		If Not CounterpartySource.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, CounterpartySource, Company, OperationKind, "Creditor");
			
			For Each TSRow In Creditor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, Counterparty, Company, OperationKind);
			
			Contract = ContractByDefault;
			
		EndIf;
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAdjustment Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.IncomeItem");
		
		If Not RegisterExpense Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.ExpenseItem");
		EndIf;
		
		If Not RegisterIncome Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.IncomeItem");
		EndIf;
		
		If Not CounterpartySource.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, CounterpartySource, Company, OperationKind, "Debitor");
			
			For Each TSRow In Debitor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.Document");
		
	ElsIf OperationKind = Enums.OperationTypesArApAdjustments.VendorDebtAdjustment Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CounterpartySource");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "SettlementsAmount");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Multiplicity");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AccountingAmount");
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.ExpenseItem");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Debitor.IncomeItem");
		
		If Not RegisterExpense Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.ExpenseItem");
		EndIf;
		
		If Not RegisterIncome Then
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.IncomeItem");
		EndIf;
		
		If Not Counterparty.DoOperationsByContracts Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Contract");
			ContractByDefault = DriveServer.GetContractByDefault(Ref, Counterparty, Company, OperationKind, "Creditor");
			
			For Each TSRow In Creditor Do
				TSRow.Contract = ContractByDefault;
			EndDo;
			
		EndIf;
			
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Creditor.Document");
		
	EndIf
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.ArApAdjustments.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ArApAdjustments.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	If ForOpeningBalancesOnly Then
		Return;
	EndIf;
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ArApAdjustments.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	AccountingTemplatesPosting.CheckForDuplicateAccountingEntries(Ref, Company, Date, Cancel);
	
	// Subordinate documents
	If Not Cancel Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.UndoPosting, DeletionMark, Company, Date, AdditionalProperties);
			
		DriveServer.ReflectDeletionAccountingTransactionDocuments(Ref);
		
	EndIf;
		
EndProcedure

// Procedure - handler of item event Filling
//
Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.ReconciliationStatement") Then
		
		FillByReconciliationStatement(FillingData);
		
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.CheckDocumentsReposting(Ref, AdditionalProperties.Posted, Cancel);
	
	If Not Cancel And AdditionalProperties.WriteMode = DocumentWriteMode.Write Then
		
		AccountingTemplatesPosting.CreateRefreshTransactionDocumentsByMode(
			Ref, DocumentWriteMode.Write, DeletionMark, Company, Date, AdditionalProperties);
		
	EndIf;
		
EndProcedure

Procedure OnCopy(CopiedObject)
	
	ForOpeningBalancesOnly = False;
	
EndProcedure

#EndRegion

#EndIf
