#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get() Then
		
		For Each RowTaxes In Taxes Do
			
			If RowTaxes.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads
				Or RowTaxes.IncomeItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.Revenue
				Or RowTaxes.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				
				RowTaxes.Department = Catalogs.BusinessUnits.MainDepartment;
			EndIf;
			
		EndDo;
		
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowTaxes In Taxes Do
			If RowTaxes.IncomeItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.Revenue
				Or RowTaxes.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses Then
				RowTaxes.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
			EndIf;
		EndDo;
			
	EndIf;
	
	DocumentAmount = Taxes.Total("Amount");
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Constants.UseSeveralDepartments.Get() Then
	
		For Each RowTaxes In Taxes Do
			
			If (RowTaxes.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.ManufacturingOverheads
				Or RowTaxes.IncomeItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.Revenue
				Or RowTaxes.ExpenseItem.IncomeAndExpenseType = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses)
					And Not ValueIsFilled(RowTaxes.Department) Then
			
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("en = 'The ""Department"" attribute should be filled in for the %1 costs account specified in the %2 line of the ""Taxes"" list.'; ru = 'Для счета затрат %1 указанного в строке %2 списка ""Налоги"", должен быть заполнен реквизит ""Подразделение"".';pl = 'Dla rachunku kosztów %1 określonego w wierszu %2 listy ""Podatki"" należy wypełnić atrybut ""Dział"".';es_ES = 'El atributo ""Departamento"" tiene que estar rellenado para la cuenta de costes %1 especificada en la línea %2 de la lista ""Impuestos"".';es_CO = 'El atributo ""Departamento"" tiene que estar rellenado para la cuenta de costes %1 especificada en la línea %2 de la lista ""Impuestos"".';tr = '""Vergiler"" listesinin %2 satırında belirtilen ""%1"" maliyet hesabı için ""Bölüm"" özniteliği doldurulmalı.';it = 'L''attributo ""Reparto"" dovrebbe essere compilato il costo %1 specificato nella linea %2 dell''elenco ""Tasse"".';de = 'Das Attribut ""Abteilung"" sollte für das in der %2 Zeile der Liste ""Steuern"" angegebene %1 Kostenkonto ausgefüllt werden.'"),
					RowTaxes.Correspondence,
					RowTaxes.LineNumber);
					
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Taxes",
					RowTaxes.LineNumber,
					"Department",
					Cancel);
				
			EndIf;
			
		EndDo;
	
	EndIf;
	
	IsAccrual = OperationKind = Enums.OperationTypesTaxAccrual.Accrual;
	
	For Each RowTaxes In Taxes Do
		
		If IsAccrual Then
			If RowTaxes.RegisterExpense And Not ValueIsFilled(RowTaxes.ExpenseItem) Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the Taxes tab, in line #%1, an expense item is required.'; ru = 'На вкладке ""Налоги"" в строке %1 требуется указать статью расходов.';pl = 'Na karcie Podatki, w wierszu nr %1, pozycja rozchodów jest wymagana.';es_ES = 'En la pestaña Impuestos, en la línea #%1, se requiere un artículo de gastos.';es_CO = 'En la pestaña Impuestos, en la línea #%1, se requiere un artículo de gastos.';tr = 'Vergiler sekmesinin %1 nolu satırında gider kalemi gerekli.';it = 'Nella scheda Imposte, nella riga #%1, è richiesta una voce di uscita.';de = 'Eine Position von Ausgaben ist in der Zeile Nr. %1 auf der Registerkarte Steuern erforderlich.'"),
						RowTaxes.LineNumber),
					"Taxes",
					RowTaxes.LineNumber,
					"ExpenseItem",
					Cancel);
			EndIf;
		Else
			If RowTaxes.RegisterIncome And Not ValueIsFilled(RowTaxes.IncomeItem) Then
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'On the Taxes tab, in line #%1, an income item is required.'; ru = 'На вкладке ""Налоги"" в строке %1 требуется указать статью доходов.';pl = 'Na karcie Podatki, w wierszu nr %1, pozycja dochodów jest wymagana.';es_ES = 'En la pestaña Impuestos, en la línea #%1, se requiere un artículo de ingresos.';es_CO = 'En la pestaña Impuestos, en la línea #%1, se requiere un artículo de ingresos.';tr = 'Vergiler sekmesinin %1 nolu satırında gelir kalemi gerekli.';it = 'Nella scheda Imposte, nella riga #%1, è richiesta una voce di entrata.';de = 'Eine Position von Einnahme ist in der Zeile Nr. %1 auf der Registerkarte Steuern erforderlich.'"),
						RowTaxes.LineNumber),
					"Taxes",
					RowTaxes.LineNumber,
					"IncomeItem",
					Cancel);
			EndIf;
		EndIf;
		
	EndDo;
	
	If Not WorkWithVATServerCall.CompanyIsRegisteredForVAT(Company, Date) Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "CompanyVATNumber");
	EndIf;
	
EndProcedure

// Procedure - event handler Posting(). Creates
// a document movement by accumulation registers and accounting register.
//
// 1. Delete the existing document transactions.
// 2. Generation document header structure with
// fields used in document post algorithms.
// 3. header value filling check and tabular document sections.
// 4. Creation temporary table by document which
// is necessary for transaction generating.
// 5. Creating the document records in accumulation register.
// 6. Creating the document records in accounting register.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Accounting templates properties initialization.
	AccountingTemplatesPosting.InitializeAccountingTemplatesProperties(Ref, AdditionalProperties, Cancel);
	If AdditionalProperties.ForPosting.AccountingTemplatesPostingUnavailable Then
		Return;
	EndIf;
	
	// Document data initialization.
	Documents.TaxAccrual.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
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
	
	// Initialization of additional properties to undo document posting
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

#EndIf