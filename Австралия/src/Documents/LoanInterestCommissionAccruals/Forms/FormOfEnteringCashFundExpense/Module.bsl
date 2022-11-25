#Region GeneralPurposeProceduresAndFunctions

// Procedure fills in the contract table with data from the Document Accruals LoanInterestCommissionAccruals TS.
//
&AtServer
Procedure FillInContractTable()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	AccrualsForLoansAccruals.Borrower,
	|	AccrualsForLoansAccruals.Lender,
	|	AccrualsForLoansAccruals.LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency,
	|	SUM(CASE
	|			WHEN AccrualsForLoansAccruals.AmountType = &AmountTypeInterest
	|				THEN AccrualsForLoansAccruals.Total
	|			ELSE 0
	|		END) AS Interest,
	|	SUM(CASE
	|			WHEN AccrualsForLoansAccruals.AmountType = &AmountTypeInterest
	|				THEN 0
	|			ELSE AccrualsForLoansAccruals.Total
	|		END) AS Commission,
	|	TRUE AS Mark
	|FROM
	|	Document.LoanInterestCommissionAccruals.Accruals AS AccrualsForLoansAccruals
	|WHERE
	|	AccrualsForLoansAccruals.Ref = &DocumentAccruals
	|
	|GROUP BY
	|	AccrualsForLoansAccruals.LoanContract,
	|	AccrualsForLoansAccruals.SettlementsCurrency,
	|	AccrualsForLoansAccruals.Lender,
	|	AccrualsForLoansAccruals.Borrower";
	
	Query.SetParameter("DocumentAccruals",		DocumentAccruals);
	Query.SetParameter("AmountTypeInterest",	Enums.LoanScheduleAmountTypes.Interest);
	
	RequestResult = Query.Execute();
	
	ContractsOfLoan.Load(RequestResult.Unload());
	
EndProcedure

#EndRegion

#Region ProceduresEventHandlersForms

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DocumentAccruals = Parameters.DocumentAccruals;
	If Not ValueIsFilled(DocumentAccruals) Then
		Cancel = True;
		Return;
	EndIf;
	
	If DocumentAccruals.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed Then
		
		Items.GroupCashExpenseButtons.Visible			= True;
		Items.FormEnterExpenseFromAccount.DefaultButton	= True;
		
		Items.GroupCashReceiptButtons.Visible			= False;
		Items.FormEnterReceiptToCashFund.DefaultButton	= False;
		
	Else
		
		Items.GroupCashExpenseButtons.Visible			= False;
		Items.FormEnterExpenseFromAccount.DefaultButton = False;
		
		Items.GroupCashReceiptButtons.Visible			= True;
		Items.FormEnterReceiptToCashFund.DefaultButton	= True;
	EndIf;
	
	FillInContractTable();
	
EndProcedure

#EndRegion

#Region CommandActionProcedures

// Procedure - handler of the EnterActualPayment command.
//
&AtClient
Procedure EnterActualPayment(DocumentKind)
	
	IsMark = False;
	
	For Each CurrentRow In ContractsOfLoan Do
		If CurrentRow.Mark Then
			IsMark = True;
			
			ParametersOfLoans = New Structure("Document, LoanContract, SettlementsCurrency, Borrower, Lender", 
				DocumentAccruals, 
				CurrentRow.LoanContract,
				CurrentRow.SettlementsCurrency,
				CurrentRow.Borrower,
				CurrentRow.Lender
			);
			FillingParameters = New Structure("Basis", ParametersOfLoans);
			
			OpenForm("Document." + DocumentKind + ".ObjectForm", FillingParameters, , CurrentRow.LoanContract);
		EndIf;
	EndDo;
	
	If Not IsMark Then
		ShowMessageBox(Undefined, 
			NStr("en = 'No line selected. Mark check boxes and try again.'; ru = 'Строка не выбрана. Выставите флаг в первой колонке и попробуйте снова';pl = 'Nie zaznaczono wiersza. Zaznacz pole wyboru i spróbuj ponownie.';es_ES = 'No hay una línea seleccionada. Marcar las casillas de verificación e intentar de nuevo.';es_CO = 'No hay una línea seleccionada. Marcar las casillas de verificación e intentar de nuevo.';tr = 'Satır seçilmedi. Onay kutularını işaretleyip tekrar deneyin.';it = 'Nessuna linea è selezionata. Contrassegnate le caselle di controllo e provate nuovamente.';de = 'Keine Zeile ausgewählt. Markieren Sie die Kontrollkästchen und versuchen Sie es erneut.'"));
	EndIf;
	
EndProcedure

// Procedure - handler of the EnterCashFundExpense command.
//
&AtClient
Procedure EnterCashFundExpense(Command)
	
	EnterActualPayment("CashVoucher");
	Close();
	
EndProcedure

// Procedure - handler of the EnterCashFundReceipt command.
//
&AtClient
Procedure EnterCashFundReceipt(Command)
	
	EnterActualPayment("CashReceipt");
	Close();
	
EndProcedure

// Procedure - handler of the EnterExpenseFromAccount command.
//
&AtClient
Procedure EnterExpenseFromAccount(Command)
	
	EnterActualPayment("PaymentExpense");
	Close();
	
EndProcedure

// Procedure - handler of the ReceiptToAccount command.
//
&AtClient
Procedure EnterReceiptToAccount(Command)
	
	EnterActualPayment("PaymentReceipt");
	Close();
	
EndProcedure

#EndRegion
