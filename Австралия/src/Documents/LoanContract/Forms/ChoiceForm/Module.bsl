#Region FormEventHandlers

// Procedure - handler of the WhenCreatingOnServer event of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CompanyForFilter") AND Not Constants.AccountingBySubsidiaryCompany.Get() Then
		Parameters.Filter.Insert("Company", Parameters.CompanyForFilter);
	EndIf;
	
	If Parameters.Property("CounterpartyForFilter") 
		AND ValueIsFilled(Parameters.CounterpartyForFilter)
		AND ((Parameters.Property("OperationType")
				AND Parameters.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansBorrowed)
			OR Not Parameters.Property("OperationType")) Then
				Parameters.Filter.Insert("Counterparty", Parameters.CounterpartyForFilter);
	EndIf;
	
	If Parameters.Property("BorrowerForFilter") 
		AND ValueIsFilled(Parameters.BorrowerForFilter) 
		AND ((Parameters.Property("OperationType") 
				AND Parameters.OperationType = Enums.LoanAccrualTypes.AccrualsForLoansLent)
		OR Not Parameters.Property("OperationType")) Then
		
		If TypeOf(Parameters.BorrowerForFilter) = Type("CatalogRef.Counterparties") Then
			Parameters.Filter.Insert("Counterparty", Parameters.BorrowerForFilter);
			Parameters.Filter.Insert("LoanKind", Enums.LoanContractTypes.CounterpartyLoanAgreement);
		Else
			Parameters.Filter.Insert("Employee", Parameters.BorrowerForFilter);
			Parameters.Filter.Insert("LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
		EndIf;
		
	EndIf;
	
	If Parameters.Property("ParentDocOperationType") Then
		
		If Parameters.ParentDocOperationType = Enums.OperationTypesPaymentReceipt.LoanRepaymentByCounterparty
			Or Parameters.ParentDocOperationType = Enums.OperationTypesPaymentExpense.IssueLoanToCounterparty Then
			
			Items.Counterparty.Title = NStr("en = 'Borrower'; ru = 'Заемщик';pl = 'Pożyczkobiorca';es_ES = 'Prestatario';es_CO = 'Prestatario';tr = 'Borçlanan';it = 'Mutuatario';de = 'Darlehensnehmer'");
			Items.Employee.Visible = False;
			Parameters.Filter.Insert("LoanKind", Enums.LoanContractTypes.CounterpartyLoanAgreement);
			
		ElsIf Parameters.ParentDocOperationType = Enums.OperationTypesPaymentReceipt.LoanSettlements
			Or Parameters.ParentDocOperationType = Enums.OperationTypesPaymentExpense.LoanSettlements Then
			
			Items.Employee.Visible = False;
			Parameters.Filter.Insert("LoanKind", Enums.LoanContractTypes.Borrowed);
			
		ElsIf Parameters.ParentDocOperationType = Enums.OperationTypesPaymentReceipt.LoanRepaymentByEmployee
			Or Parameters.ParentDocOperationType = Enums.OperationTypesPaymentExpense.IssueLoanToEmployee Then
			
			Items.Counterparty.Visible = False;
			Parameters.Filter.Insert("LoanKind", Enums.LoanContractTypes.EmployeeLoanAgreement);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
