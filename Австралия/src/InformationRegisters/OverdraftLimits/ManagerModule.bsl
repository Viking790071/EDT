#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Function GetCurrentOvedraftLimit(BankAccount, Company) Export
	
	Limit = 0;
	
	If BankAccount.IsEmpty() Then
		Return Limit;
	EndIf;
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	OverdraftLimitsSliceLast.Limit AS Limit
	|FROM
	|	InformationRegister.OverdraftLimits.SliceLast(
	|			,
	|			BankAccount = &BankAccount
	|				AND Company = &Company
	|				AND StartDate <= &CurDate
	|				AND (EndDate >= &CurDate
	|					OR EndDate = DATETIME(1, 1, 1))) AS OverdraftLimitsSliceLast";
	
	Query.SetParameter("BankAccount", BankAccount);
	Query.SetParameter("Company", Company);
	Query.SetParameter("CurDate", CurrentSessionDate());
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Limit = Selection.Limit;
	EndIf;
	
	Return Limit;
	
EndFunction

Function IsOverdraftUsedInPayments(Parameters, CheckLimit = False) Export
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED TOP 1
	|	CashAssetsBalanceAndTurnovers.BankAccountPettyCash AS BankAccountPettyCash
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
	|			&StartDate,
	|			&EndDate,
	|			Recorder,
	|			,
	|			Company = &Company
	|				AND BankAccountPettyCash = &BankAccount) AS CashAssetsBalanceAndTurnovers
	|WHERE
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance < 0
	|	AND CashAssetsBalanceAndTurnovers.AmountCurTurnover <> 0
	|	AND &CheckLimit";
	
	Query.SetParameter("Company", 		Parameters.Company);
	Query.SetParameter("BankAccount", 	Parameters.BankAccount);
	Query.SetParameter("StartDate", 	Parameters.StartDate);
	Query.SetParameter("EndDate", 		?(Parameters.EndDate=Date(1,1,1), Date(3999,12,31,23,59,59), Parameters.EndDate));
	
	If CheckLimit Then
		Query.Text = StrReplace(Query.Text, "&CheckLimit", "-CashAssetsBalanceAndTurnovers.AmountCurClosingBalance > &Limit");
		Query.SetParameter("Limit", Parameters.Limit);
	Else
		Query.SetParameter("CheckLimit", True);
	EndIf;
	
	QueryResult = Query.Execute();
	Return Not QueryResult.IsEmpty();
	
EndFunction

#EndRegion

#EndIf