#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function calculates the document amount.
//
Function GetDocumentAmount() Export

	TableEarnings = New ValueTable;
    Array = New Array;
	ReturnStructure = New Structure("AmountAccrued, AmountWithheld, DocumentAmount, AmountCharged", 0, 0, 0, 0);
	
	Array.Add(Type("CatalogRef.EarningAndDeductionTypes"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableEarnings.Columns.Add("EarningAndDeductionType", TypeDescription);

	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableEarnings.Columns.Add("Amount", TypeDescription);
	
	For Each TSRow In EarningsDeductions Do
		NewRow = TableEarnings.Add();
        NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	For Each TSRow In IncomeTaxes Do
		NewRow = TableEarnings.Add();
        NewRow.EarningAndDeductionType = TSRow.EarningAndDeductionType;
        NewRow.Amount = TSRow.Amount;
	EndDo;
	
	Query = New Query(
	"SELECT
	|	TableEarningsDeductions.EarningAndDeductionType,
	|	TableEarningsDeductions.Amount
	|INTO TableEarningsDeductions
	|FROM
	|	&TableEarningsDeductions AS TableEarningsDeductions
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN PayrollEarningRetention.Amount
	|			ELSE 0
	|		END) AS AmountAccrued,
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN 0
	|			ELSE PayrollEarningRetention.Amount
	|		END) AS AmountWithheld,
	|	SUM(CASE
	|			WHEN PayrollEarningRetention.EarningAndDeductionType.Type = VALUE(Enum.EarningAndDeductionTypes.Earning)
	|				THEN PayrollEarningRetention.Amount
	|			ELSE -1 * PayrollEarningRetention.Amount
	|		END) AS DocumentAmount
	|FROM
	|	TableEarningsDeductions AS PayrollEarningRetention");
	
	Query.SetParameter("TableEarningsDeductions", TableEarnings);
	QueryResult = Query.ExecuteBatch();
	
	ReturnStructure.Insert("AmountCharged", LoanRepayment.Total("PrincipalCharged") + LoanRepayment.Total("InterestCharged"));
	
	If QueryResult[1].IsEmpty() Then
		ReturnStructure.DocumentAmount = ReturnStructure.DocumentAmount - ReturnStructure.AmountCharged;
		Return ReturnStructure;	
	Else
		FillPropertyValues(ReturnStructure, QueryResult[1].Unload()[0]);
		
		If ValueIsFilled(ReturnStructure.DocumentAmount) Then
			ReturnStructure.DocumentAmount = ReturnStructure.DocumentAmount - ReturnStructure.AmountCharged;
		Else 
			ReturnStructure.DocumentAmount = -ReturnStructure.AmountCharged;
		EndIf;
		
		Return ReturnStructure;	
	EndIf; 

EndFunction

#EndRegion

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = GetDocumentAmount().DocumentAmount;
	AdministrativeExpenses = Catalogs.IncomeAndExpenseTypes.AdministrativeExpenses;
	
	If GetFunctionalOption("UseDefaultTypeOfAccounting") And Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each EarningDetentionRow In EarningsDeductions Do
			
			IncomeAndExpenseType = Common.ObjectAttributeValue(EarningDetentionRow.ExpenseItem, "IncomeAndExpenseType");
			If IncomeAndExpenseType = AdministrativeExpenses Then
				
				EarningDetentionRow.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Change of approved documents
	AccountingApprovalServer.BeforeWriteAtServer(ThisObject, Cancel);
	// End Change of approved documents
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	AdditionalProperties.Insert("Posted", Posted);
	
EndProcedure

// Procedure - event handler Posting object.
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
	Documents.Payroll.InitializeDocumentData(Ref, AdditionalProperties);
	
	AccountingTemplatesPosting.CheckEntriesAccounts(AdditionalProperties, Cancel);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectEarningsAndDeductions(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	
	// Accounting
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesSimple(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntriesCompound(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingEntriesData(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectDocumentAccountingEntriesStatuses(ThisObject, AdditionalProperties, RegisterRecords, Cancel);
	
	// Account for loans to employees
	DriveServer.ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel);	

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.Payroll.RunControl(Ref, AdditionalProperties, Cancel, True);
	
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

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Row In EarningsDeductions Do
		
		If Row.RegisterExpense And Not ValueIsFilled(Row.ExpenseItem) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""Expense item"" attribute must be filled in for the ""%1"" employee specified in the %2 line of the ""Earnings and deductions"" list.'; ru = 'Для сотрудника ""%1"" указанного в строке %2 списка ""Статья расходов"", должен быть заполнен реквизит ""Начисления и удержания"".';pl = 'Atrybut ""Pozycja rozchodów"" powinna być wypełniona dla pracownika ""%1"", określonego w wierszu %2 listy ""Zarobki i potrącenia"".';es_ES = 'El atributo ""Artículo de gastos"" tiene que rellenarse para el empleado ""%1"" especificado en la línea %2 de la lista ""Ingresos y deducciones"".';es_CO = 'El atributo ""Artículo de gastos"" tiene que rellenarse para el empleado ""%1"" especificado en la línea %2 de la lista ""Ingresos y deducciones"".';tr = '""Kazançlar ve kesintiler"" listesinin %2 satırında belirtilen ""%1"" çalışanı için ""Gider kalemi"" özniteliği doldurulmalı.';it = 'L''attributo ""Voce di uscita"" deve essere compilato per il dipendente ""%1"" indicato nella riga %2 dell''elenco ""Compensi e trattenute"".';de = 'Für den in der %2 Zeile der Liste ""Bezüge und Abzüge"" angegebenen Mitarbeiter ""%1"" muss das Attribut ""Position von Ausgaben"" ausgefüllt werden.'"),
				TrimAll(String(Row.Employee)),
				String(Row.LineNumber));
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				Row.LineNumber,
				"ExpenseItem",
				Cancel);
		ElsIf Row.RegisterIncome And Not ValueIsFilled(Row.IncomeItem) Then
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The ""Income item"" attribute must be filled in for the ""%1"" employee specified in the %2 line of the ""Earnings and deductions"" list.'; ru = 'Для сотрудника ""%1"" указанного в строке %2 списка ""Статья доходов"", должен быть заполнен реквизит ""Начисления и удержания"".';pl = 'Atrybut ""Pozycja dochodów"" powinna być wypełniona dla pracownika ""%1"", określonego w wierszu %2 listy ""Zarobki i potrącenia"".';es_ES = 'El atributo ""Artículo de ingresos"" tiene que rellenarse para el empleado ""%1"" especificado en la línea %2 de la lista ""Ingresos y deducciones"".';es_CO = 'El atributo ""Artículo de ingresos"" tiene que rellenarse para el empleado ""%1"" especificado en la línea %2 de la lista ""Ingresos y deducciones"".';tr = '""Kazançlar ve kesintiler"" listesinin %2 satırında belirtilen ""%1"" çalışanı için ""Gelir kalemi"" özniteliği doldurulmalı.';it = 'L''attributo ""Voce di entrata"" deve essere compilata per il dipendente ""%1"" indicato nella riga %2 dell''elenco ""Compensi e trattenute"".';de = 'Für den in der %2 Zeile der Liste ""Bezüge und Abzüge"" angegebenen Mitarbeiter ""%1"" muss das Attribut ""Position von Einnahme"" ausgefüllt werden.'"),
				TrimAll(String(Row.Employee)),
				String(Row.LineNumber));
			
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"EarningsDeductions",
				Row.LineNumber,
				"IncomeItem",
				Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndIf