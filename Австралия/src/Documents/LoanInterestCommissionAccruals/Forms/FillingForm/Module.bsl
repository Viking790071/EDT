
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Autotest") Then // Skipping the initialization to guarantee that the form will be received if the Autotest parameter is passed.
		Return;
	EndIf;

	Company					= Parameters.Company;
	AccrualAddressInStorage	= Parameters.AccrualAddressInStorage;
	OperationType			= Parameters.OperationKind;
	StartDate				= Parameters.StartDate;
	EndDate					= Parameters.EndDate;
	Recorder				= Parameters.Recorder;
	
	SetContractSelectionParameters();
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		Items.Borrower.Visible = False;
	Else
		Items.Counterparty.Visible = False;
		Items.Borrower.AutoMarkIncomplete = True;
	EndIf;
	
	NewArray = New Array();
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		NewParameter = New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.Borrowed);
		Items.FillInByContractsWithRepaymentFromSalary.Visible = False;
	Else
		NewParameter = New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
		Items.FillInByContractsWithRepaymentFromSalary.Visible = True;
	EndIf;
	
	NewArray.Add(NewParameter);
	NewParameters = New FixedArray(NewArray);
	Items.LoanContract.ChoiceParameters = NewParameters;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure CounterpartyOnChange(Item)
	SetContractSelectionParameters();
EndProcedure

&AtClient
Procedure EmployeeOnChange(Item)	
	SetContractSelectionParameters();	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Fill(Command)
	
	If IsErrorBeforeFill() Then
		Return;
	EndIf;
	
	AccrualsServer();
	
	Structure = New Structure("AccrualAddressInStorage", AccrualAddressInStorage);
	NotifyChoice(Structure);

EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#Region Others

&AtServer
Function SetContractSelectionParameters()

	ParameterArray = New Array;
	ParameterArray.Add(New ChoiceParameter("Filter.Company", Company));
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		ParameterArray.Add(New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.Borrowed));
		
		If Not Counterparty.IsEmpty() Then
			ParameterArray.Add(New ChoiceParameter("Filter.Lender", Counterparty));
		EndIf;
		
	ElsIf OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent Then
		
		If Not Borrower = Undefined And Not Borrower.IsEmpty() Then
			
			If TypeOf(Borrower) = Type("CatalogRef.Counterparties") Then
				ParameterArray.Add(New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.CounterpartyLoanAgreement));
			ElsIf TypeOf(Borrower) = Type("CatalogRef.Employees") Then
				ParameterArray.Add(New ChoiceParameter("Filter.LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement));
			EndIf;
			
			ParameterArray.Add(New ChoiceParameter("Filter.Borrower", Borrower));
			
		EndIf;
		
	EndIf;
	
	ParameterArray.Add(New ChoiceParameter("Filter.DeletionMark", False));
	
	Items.LoanContract.ChoiceParameters = New FixedArray(ParameterArray);
	
EndFunction

&AtServer
Function QueryTextByAccruals()
	
	Return 
	"SELECT ALLOWED
	|	LoanRepaymentSchedule.Period AS Period,
	|	LoanRepaymentSchedule.LoanContract AS LoanContract,
	|	LoanRepaymentSchedule.LoanContract.BusinessArea AS BusinessArea,
	|	LoanRepaymentSchedule.LoanContract.Order AS Order,
	|	LoanRepaymentSchedule.LoanContract.StructuralUnit AS StructuralUnit,
	|	SUM(LoanRepaymentSchedule.Interest) AS Interest,
	|	SUM(LoanRepaymentSchedule.Commission) AS Commission,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				OR LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN LoanRepaymentSchedule.LoanContract.Counterparty
	|		ELSE LoanRepaymentSchedule.LoanContract.Employee
	|	END AS Lender,
	|	LoanRepaymentSchedule.LoanContract.Company AS Company,
	|	LoanRepaymentSchedule.LoanContract.LoanKind AS LoanKind,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency AS SettlementsCurrency,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.InterestExpenseItem
	|		ELSE LoanRepaymentSchedule.LoanContract.InterestIncomeItem
	|	END AS InterestItem,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.CommissionExpenseItem
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN LoanRepaymentSchedule.LoanContract.CommissionIncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END AS CommissionItem
	|INTO CurrentAccruals
	|FROM
	|	InformationRegister.LoanRepaymentSchedule AS LoanRepaymentSchedule
	|WHERE
	|	LoanRepaymentSchedule.Active
	|	AND LoanRepaymentSchedule.Period BETWEEN &StartDate AND &EndDate
	|	AND LoanRepaymentSchedule.LoanContract.Company = &Company
	|	AND LoanRepaymentSchedule.LoanContract.LoanKind = &LoanKind
	|
	|GROUP BY
	|	LoanRepaymentSchedule.Period,
	|	LoanRepaymentSchedule.LoanContract,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|				OR LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN LoanRepaymentSchedule.LoanContract.Counterparty
	|		ELSE LoanRepaymentSchedule.LoanContract.Employee
	|	END,
	|	LoanRepaymentSchedule.LoanContract.LoanKind,
	|	LoanRepaymentSchedule.LoanContract.Company,
	|	LoanRepaymentSchedule.LoanContract.SettlementsCurrency,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.InterestExpenseItem
	|		ELSE LoanRepaymentSchedule.LoanContract.InterestIncomeItem
	|	END,
	|	CASE
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanRepaymentSchedule.LoanContract.CommissionExpenseItem
	|		WHEN LoanRepaymentSchedule.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN LoanRepaymentSchedule.LoanContract.CommissionIncomeItem
	|		ELSE VALUE(Catalog.IncomeAndExpenseItems.EmptyRef)
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	LoanSettlements.Period AS Period,
	|	LoanSettlements.LoanKind AS LoanKind,
	|	LoanSettlements.Counterparty AS Counterparty,
	|	LoanSettlements.LoanContract AS LoanContract,
	|	LoanSettlements.Company AS Company,
	|	SUM(LoanSettlements.InterestCur) AS InterestCur,
	|	SUM(LoanSettlements.CommissionCur) AS CommissionCur,
	|	LoanSettlements.LoanContract.SettlementsCurrency AS SettlementsCurrency
	|INTO PreviousAccruals
	|FROM
	|	AccumulationRegister.LoanSettlements AS LoanSettlements
	|WHERE
	|	LoanSettlements.Period BETWEEN &StartDate AND &EndDate
	|	AND LoanSettlements.Recorder <> &Recorder
	|	AND LoanSettlements.LoanKind = &LoanKind
	|	AND LoanSettlements.Company = &Company
	|	AND LoanSettlements.Active
	|
	|GROUP BY
	|	LoanSettlements.LoanContract,
	|	LoanSettlements.Period,
	|	LoanSettlements.LoanKind,
	|	LoanSettlements.Company,
	|	LoanSettlements.Counterparty,
	|	LoanSettlements.LoanContract.SettlementsCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CurrentAccruals.Period AS Date,
	|	CurrentAccruals.LoanContract AS LoanContract,
	|	CurrentAccruals.BusinessArea AS BusinessArea,
	|	CurrentAccruals.Order AS Order,
	|	CurrentAccruals.StructuralUnit AS StructuralUnit,
	|	CurrentAccruals.Interest AS Interest,
	|	CurrentAccruals.Commission AS Commission,
	|	CAST(CurrentAccruals.Lender AS Catalog.Counterparties) AS Lender,
	|	CASE
	|		WHEN CurrentAccruals.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|			THEN CAST(CurrentAccruals.Lender AS Catalog.Counterparties)
	|		ELSE CAST(CurrentAccruals.Lender AS Catalog.Employees)
	|	END AS Borrower,
	|	CurrentAccruals.Company AS Company,
	|	CurrentAccruals.LoanKind AS LoanKind,
	|	CurrentAccruals.SettlementsCurrency AS SettlementsCurrency,
	|	CurrentAccruals.InterestItem AS InterestItem,
	|	CurrentAccruals.CommissionItem AS CommissionItem,
	|	0 AS Total,
	|	CurrentAccruals.LoanContract.ChargeFromSalary AS ChargeFromSalary
	|FROM
	|	CurrentAccruals AS CurrentAccruals
	|		LEFT JOIN PreviousAccruals AS PreviousAccruals
	|		ON CurrentAccruals.Period = PreviousAccruals.Period
	|			AND CurrentAccruals.LoanContract = PreviousAccruals.LoanContract
	|			AND CurrentAccruals.Lender = PreviousAccruals.LoanKind
	|			AND CurrentAccruals.SettlementsCurrency = PreviousAccruals.SettlementsCurrency
	|WHERE
	|	PreviousAccruals.Period IS NULL
	|{WHERE
	|	(CAST(CurrentAccruals.Lender AS Catalog.Counterparties)).* AS Lender,
	|	CurrentAccruals.LoanContract.*,
	|	CurrentAccruals.LoanContract.ChargeFromSalary AS ChargeFromSalary,
	|	(CASE
	|			WHEN CurrentAccruals.LoanContract.LoanKind = VALUE(Enum.LoanContractTypes.CounterpartyLoanAgreement)
	|				THEN CAST(CurrentAccruals.Lender AS Catalog.Counterparties)
	|			ELSE CAST(CurrentAccruals.Lender AS Catalog.Employees)
	|		END).* AS Employee}
	|
	|ORDER BY
	|	Date,
	|	LoanContract
	|AUTOORDER";
	
EndFunction

&AtServer
Procedure AccrualsServer()
	
	// receive Accrual table on schedule
	QueryBuilder = New QueryBuilder(QueryTextByAccruals());
	QueryBuilder.Parameters.Insert("StartDate", StartDate);
	QueryBuilder.Parameters.Insert("EndDate",	EndDate);
	QueryBuilder.Parameters.Insert("Company",	Company);
	QueryBuilder.Parameters.Insert("Recorder",	Recorder);
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		QueryBuilder.Parameters.Insert("LoanKind", Enums.LoanContractTypes.Borrowed);
	Else
		If Not Borrower = Undefined And Not Borrower.IsEmpty() Then
			
			If TypeOf(Borrower) = Type("CatalogRef.Counterparties") Then
				QueryBuilder.Parameters.Insert("LoanKind", Enums.LoanContractTypes.CounterpartyLoanAgreement);
			ElsIf TypeOf(Borrower) = Type("CatalogRef.Employees") Then
				QueryBuilder.Parameters.Insert("LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(Counterparty) Then
		NewFilter = QueryBuilder.Filter.Add("Lender");
		NewFilter.Set(Counterparty);
	EndIf;
	
	If ValueIsFilled(Borrower) Then
		NewFilter = QueryBuilder.Filter.Add("Employee");
		NewFilter.Set(Borrower);
	EndIf;
	
	If ValueIsFilled(LoanContract) Then
		NewFilter = QueryBuilder.Filter.Add("LoanContract");
		NewFilter.Set(LoanContract);
	EndIf;
	
	If OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent AND 
		Not FillInByContractsWithRepaymentFromSalary Then
		NewFilter = QueryBuilder.Filter.Add("ChargeFromSalary");
		NewFilter.Set(False);
	EndIf;
	
	QueryBuilder.Execute();
	ScheduleAccruals = QueryBuilder.Result.Unload();
	
	Accruals = ScheduleAccruals.CopyColumns();
	Accruals.Columns.Add("AmountType", New TypeDescription("EnumRef.LoanScheduleAmountTypes"));
	Accruals.Columns.Add("ExpenseItem", New TypeDescription("CatalogRef.IncomeAndExpenseItems"));
	Accruals.Columns.Add("IncomeItem", New TypeDescription("CatalogRef.IncomeAndExpenseItems"));
	
	For Each CurrentAccrual In ScheduleAccruals Do
	
		If CurrentAccrual.Interest <> 0 Then
			
			NewAccrualLine = Accruals.Add();
			FillPropertyValues(NewAccrualLine, CurrentAccrual);
			NewAccrualLine.Total = CurrentAccrual.Interest;
			NewAccrualLine.AmountType = Enums.LoanScheduleAmountTypes.Interest;
			
			If CurrentAccrual.LoanKind = Enums.LoanContractTypes.Borrowed Then
				NewAccrualLine.ExpenseItem = CurrentAccrual.InterestItem;
			Else
				NewAccrualLine.IncomeItem = CurrentAccrual.InterestItem;
			EndIf;
			
		EndIf;
		
		If CurrentAccrual.Commission <> 0 Then
			
			NewAccrualLine = Accruals.Add();
			FillPropertyValues(NewAccrualLine, CurrentAccrual);
			NewAccrualLine.Total = CurrentAccrual.Commission;
			NewAccrualLine.AmountType = Enums.LoanScheduleAmountTypes.Commission;
			
			If CurrentAccrual.LoanKind = Enums.LoanContractTypes.Borrowed Then
				NewAccrualLine.ExpenseItem = CurrentAccrual.CommissionItem;
			Else
				NewAccrualLine.IncomeItem = CurrentAccrual.CommissionItem;
			EndIf;
			
		EndIf;

	EndDo;
	
	AccrualAddressInStorage = PutToTempStorage(Accruals, UUID);
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

&AtClient
Function IsErrorBeforeFill()
	
	Result = False;
	
	If Items.Borrower.Visible 
		And Not ValueIsFilled(Borrower) Then
		
		TextMessage = NStr("en = 'Please specify a borrower.'; ru = 'Укажите заемщика.';pl = 'Określ pożyczkobiorcę.';es_ES = 'Por favor, especifique el prestatario.';es_CO = 'Por favor, especifique el prestatario.';tr = 'Lütfen, borçlananı belirtin.';it = 'Specificare un debitore.';de = 'Bitte geben Sie den Darlehensnehmer an.'");
		CommonClientServer.MessageToUser(TextMessage, , "Borrower");
		
		Result = True;
		Return Result;
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion
