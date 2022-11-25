#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Checked attributes deletion from structure depending on functional option.
	If Not Constants.UseBudgeting.Get() Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
	If Constants.UseBudgeting.Get()
	   AND TypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ClosingAccount");
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	If Not ValueIsFilled(MethodOfDistribution) Then
		
		If TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses Then
			MethodOfDistribution = Enums.CostAllocationMethod.ProductionVolume;
		ElsIf TypeOfAccount = Enums.GLAccountsTypes.Expenses
			Or TypeOfAccount = Enums.GLAccountsTypes.Revenue
			Or TypeOfAccount = Enums.GLAccountsTypes.OtherIncome
			Or TypeOfAccount = Enums.GLAccountsTypes.OtherExpenses Then
			MethodOfDistribution = Enums.CostAllocationMethod.SalesVolume;
		Else
			MethodOfDistribution = Enums.CostAllocationMethod.DoNotDistribute;
		EndIf;
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If TypeOfAccount <> Enums.GLAccountsTypes.WorkInProgress
		And TypeOfAccount <> Enums.GLAccountsTypes.IndirectExpenses Then
		ClosingAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EndIf;
	
	If Not ValueIsFilled(Order) Then
		Order = 1;
	EndIf;
	
EndProcedure

#EndRegion

#EndIf