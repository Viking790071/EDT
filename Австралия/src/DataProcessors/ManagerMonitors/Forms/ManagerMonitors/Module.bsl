
#Region FormEventsHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetSettings();
	RefreshData();
	
EndProcedure

&AtClient
// Procedure - event handler OnClose form.
//
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	SaveSettings();
	
EndProcedure

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
// Procedure - event handler OnChange of the Company input field.
//
Procedure CompanyOnChange(Item)

    RefreshData();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Period field.
//
Procedure PeriodOnChange(Item)
	
	If Period = '00010101' Then
		Period = CommonClient.SessionDate();
	EndIf;	
		
	RefreshData();	
    	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the CashAssets widget.
//
&AtClient
Procedure CashAssetsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "CashBalance");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "ItmPeriod");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see widget Debitors.
//
&AtClient
Procedure DebitorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsReceivable");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the Creditors widget.
//
&AtClient
Procedure CreditorsDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "AccountsPayable");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the SalesOrders widget.
//
&AtClient
Procedure SalesOrdersDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "SalesOrdersTrend");
	ReportProperties.Insert("VariantKey", "Default");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "EndOfPeriod");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("FilterByShippingState", "NotShipped");
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the PurchaseOrders widget.
//
&AtClient
Procedure PurchaseOrdersDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "PurchaseOrdersOverview");
	ReportProperties.Insert("VariantKey", "Default");
	
	ParametersAndSelections = New Array;
	
	Setting = New Structure;
	Setting.Insert("FieldName", "EndOfPeriod");
	Setting.Insert("RightValue", EndOfDay(Period));
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 			 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings",	 SettingsComposer.UserSettings);
	FormParameters.Insert("FilterByReceiptState", "Outstanding");
	FormParameters.Insert("GenerateOnOpen",		 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the ProfitLoss widget.
//
&AtClient
Procedure ProfitDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "IncomeAndExpenses");
	ReportProperties.Insert("VariantKey", "Statement");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "ItmPeriod");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);
	
EndProcedure

// Procedure - Click hyperlink event handler For more information, see the Sales widget.
//
&AtClient
Procedure SalesDetailsClick(Item)
	
	ReportProperties = New Structure;
	ReportProperties.Insert("ReportName", "NetSales");
	ReportProperties.Insert("VariantKey", "SalesDynamics");
	
	ParametersAndSelections = New Array;
	
	PeriodOfReport = New StandardPeriod;
	PeriodOfReport.StartDate = AddMonth(BegOfDay(Period),-1);
	PeriodOfReport.EndDate = EndOfDay(Period);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Company");
	Setting.Insert("RightValue", Company);
	ParametersAndSelections.Add(Setting);
	
	Setting = New Structure;
	Setting.Insert("FieldName", "Period");
	Setting.Insert("RightValue", PeriodOfReport);
	ParametersAndSelections.Add(Setting);
	
	SettingsComposer = DriveServer.GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey",		 		 ReportProperties.VariantKey);
	FormParameters.Insert("UserSettings", SettingsComposer.UserSettings);
	FormParameters.Insert("GenerateOnOpen",	 True);
	
	OpenForm("Report." + ReportProperties.ReportName + ".Form", FormParameters, Item, UUID);

EndProcedure

// Procedure - event handler Chart selection Petty cash.
//
&AtClient
Procedure ChartPettyCashSelection(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Accounts.
//
&AtClient
Procedure ChartAccountSelection(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Profit.
//
&AtClient
Procedure ProfitChartChoice(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

// Procedure - event handler Chart selection Sales.
//
&AtClient
Procedure SaleDiagramChoice(Item, ChartValue, StandardProcessing)
	
	StandardProcessing = False;
	ShowValue(Undefined, ChartValue.ToolTip);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Refresh(Command)
	
	RefreshData();
	
EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

&AtServer
// The procedure restores common monitor settings.
//
Procedure GetSettings()
	
	If Constants.AccountingBySubsidiaryCompany.Get() Then
		Company = Constants.ParentCompany.Get();
		Items.Company.ReadOnly = True;
	Else
		Company = Common.CommonSettingsStorageLoad("SettingsForMonitors", "Company");
		If Not ValueIsFilled(Company) Then
			Company = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "MainCompany");
			If Not ValueIsFilled(Company) Then
				Company = DriveServer.GetPredefinedCompany();
			EndIf;
		EndIf;
	EndIf;
	
	Period = Common.CommonSettingsStorageLoad("SettingsForMonitors", "Period");
	If Not ValueIsFilled(Period) Then
		Period = CurrentSessionDate();
	EndIf;
	
EndProcedure

&AtServer
// The procedure saves common monitor settings.
//
Procedure SaveSettings()
	
	Common.CommonSettingsStorageSave("SettingsForMonitors", "Company", Company);
	
	If (BegOfDay(CurrentSessionDate()) = BegOfDay(Period)) Then
		Common.CommonSettingsStorageSave("SettingsForMonitors", "Period", '00010101');
	Else
		Common.CommonSettingsStorageSave("SettingsForMonitors", "Period", Period);
	EndIf;

EndProcedure

&AtServer
// The procedure updates the form data.
//
Procedure RefreshData()
		
	PeriodPresentation = Format(AddMonth(Period, -1), "DLF=DD") + " — " + Format(Period, "DLF=DD") + ?(BegOfDay(Period) = BegOfDay(CurrentSessionDate()), " (Today)", "");
	
	RefreshWidgetCashAssets();
	RefreshOrdersWidget();
	RefreshDebitorsWidget();
	RefreshWidgetProfitLoss();
	UpdateSalesWidget();
	RefreshCreditorsWidget();
	
EndProcedure

&AtServer
Procedure RefreshWidgetCashAssets()
	
	// Petty cashes.
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	CashFundsBalanceAndTurnovers.Period AS Period,
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDate,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND PaymentMethod.CashAssetType = &CashAssetType) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance >= 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashAssetType", Enums.CashAssetTypes.Cash);
	
	PettyCashChart.RefreshEnabled = False;
	PettyCashChart.Clear();
	PettyCashChart.AutoTransposition = False;
	PettyCashChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = PettyCashChart.Series.Add("Balance");
	Series.Color = DriveServer.ColorForMonitors("Orange");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	RecNo = 0;
	CurrentBalance = 0;
	BalanceYesterday = 0;
	While Selection.Next() Do
		
		Point = PettyCashChart.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DLF=D");
		Point.Details = Selection.Period;
		ToolTip = "Balance " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DLF=D");
		PettyCashChart.SetValue(Point, Series, Selection.AmountClosingBalance, Point.Details, ToolTip);
		
		RecNo = RecNo + 1;
		If RecNo = Selection.Count()-1 Then
			BalanceYesterday = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		ElsIf RecNo = Selection.Count() Then
			CurrentBalance = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		EndIf;
		
	EndDo;
	
	PettyCashChart.AutoTransposition = True;
	PettyCashChart.RefreshEnabled = True;
	
	Items.DecorationPettyCashBalance.Title = ?(CurrentBalance = 0, "—", DriveServer.GenerateTitle(CurrentBalance));
	ChangePercent = ?(BalanceYesterday = 0, 0, Round((CurrentBalance - BalanceYesterday) / BalanceYesterday * 100));
	If ChangePercent = 0 Then
		Items.DecorationPettyCashPercent.Visible = False;
	ElsIf ChangePercent < 0 Then
		Items.DecorationPettyCashPercent.Visible = True;
		Items.DecorationPettyCashPercent.Title = "" + Format(ChangePercent, "NFD=") + "%";
		Items.DecorationPettyCashPercent.TextColor = DriveServer.ColorForMonitors("Red");
	ElsIf ChangePercent > 0 Then
		Items.DecorationPettyCashPercent.Visible = True;
		Items.DecorationPettyCashPercent.Title = "+" + Format(ChangePercent, "NFD=") + "%";
		Items.DecorationPettyCashPercent.TextColor = DriveServer.ColorForMonitors("Green");
	EndIf;
	
	
	// Accounts.
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	CashFundsBalanceAndTurnovers.Period AS Period,
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance AS AmountClosingBalance
		|FROM
		|	AccumulationRegister.CashAssets.BalanceAndTurnovers(
		|			&FilterDateBeginning,
		|			&FilterDate,
		|			Day,
		|			RegisterRecordsAndPeriodBoundaries,
		|			Company = &Company
		|				AND PaymentMethod.CashAssetType = &CashAssetType) AS CashFundsBalanceAndTurnovers
		|WHERE
		|	CashFundsBalanceAndTurnovers.AmountClosingBalance >= 0
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(AmountClosingBalance)
		|BY
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashAssetType", Enums.CashAssetTypes.Noncash);
	
	AccountChart.RefreshEnabled = False;
	AccountChart.Clear();
	AccountChart.AutoTransposition = False;
	AccountChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = AccountChart.Series.Add("Balance");
	Series.Color = DriveServer.ColorForMonitors("Orange");
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	RecNo = 0;
	CurrentBalance = 0;
	BalanceYesterday = 0;
	While Selection.Next() Do
		
		Point = AccountChart.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DLF=D");
		Point.Details = Selection.Period;
		ToolTip = "Balance " + Selection.AmountClosingBalance + " on " + Format(Selection.Period, "DLF=D");
		AccountChart.SetValue(Point, Series, Selection.AmountClosingBalance, Point.Details, ToolTip);
		
		RecNo = RecNo + 1;
		If RecNo = Selection.Count()-1 Then
			BalanceYesterday = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		ElsIf RecNo = Selection.Count() Then
			CurrentBalance = ?(Selection.AmountClosingBalance = Null, 0, Selection.AmountClosingBalance);
		EndIf;
		
	EndDo;
	
	AccountChart.AutoTransposition = True;
	AccountChart.RefreshEnabled = True;
	
	Items.DecorationAccountsBalance.Title = ?(CurrentBalance = 0, "—", DriveServer.GenerateTitle(CurrentBalance));
	ChangePercent = ?(BalanceYesterday = 0, 0, Round((CurrentBalance - BalanceYesterday) / BalanceYesterday * 100));
	If ChangePercent = 0 Then
		Items.AccountDecorationPercent.Visible = False;
	ElsIf ChangePercent < 0 Then
		Items.AccountDecorationPercent.Visible = True;
		Items.AccountDecorationPercent.Title = "" + Format(ChangePercent, "NFD=") + "%";
		Items.AccountDecorationPercent.TextColor = DriveServer.ColorForMonitors("Red");
	ElsIf ChangePercent > 0 Then
		Items.AccountDecorationPercent.Visible = True;
		Items.AccountDecorationPercent.Title = "+" + Format(ChangePercent, "NFD=") + "%";
		Items.AccountDecorationPercent.TextColor = DriveServer.ColorForMonitors("Green");
	EndIf;
	
EndProcedure

&AtServer
Procedure RefreshWidgetProfitLoss()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	IncomeAndExpencesTurnOvers.Period AS Period,
		|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover AS Incomings,
		|	IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS Expenses,
		|	IncomeAndExpencesTurnOvers.AmountIncomeTurnover - IncomeAndExpencesTurnOvers.AmountExpenseTurnover AS Profit
		|FROM
		|	AccumulationRegister.IncomeAndExpenses.Turnovers(
		|			&FilterDateBeginning,
		|			&FilterDateEnds,
		|			Day,
		|			Company = &Company) AS IncomeAndExpencesTurnOvers
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(Incomings),
		|	SUM(Expenses),
		|	SUM(Profit)
		|BY
		|	OVERALL,
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDateEnds)";

	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("FilterDateEnds", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	Query.SetParameter("EmptyAccount", ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef());

	SelectionTotal = Query.Execute().Select(QueryResultIteration.ByGroups);
	If SelectionTotal.Next() Then
		Items.DecorationTotalIncomings.Title = DriveServer.GenerateTitle(SelectionTotal.Incomings);
		Items.DecorationExpensesTotal.Title = DriveServer.GenerateTitle(SelectionTotal.Expenses);
		Items.DecorationProfitTotal.Title = DriveServer.GenerateTitle(SelectionTotal.Profit);
	Else
		Items.DecorationTotalIncomings.Title = "—";
		Items.DecorationExpensesTotal.Title = "—";
		Items.DecorationProfitTotal.Title = "—";
	EndIf;
	
	ProfitChart.RefreshEnabled = False;
	ProfitChart.Clear();
	ProfitChart.AutoTransposition = False;
	ProfitChart.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = ProfitChart.Series.Add("Profit (Loss)");
	Series.Color = DriveServer.ColorForMonitors("Blue");
	Series.Line = New Line(ChartLineType.Solid, 2);
	Series.Marker = ChartMarkerType.None;
	
	MaxValue = 0;
	MinValue = 0;
	Selection = SelectionTotal.Select(QueryResultIteration.ByGroups, "Period", "All");
	While Selection.Next() Do
		
		Point = ProfitChart.Points.Add(Selection.Period);
		If Selection.Profit = Null Then
			ProfitLoss = 0;
		Else
			ProfitLoss = Selection.Profit;
		EndIf;
		Point.Text = Format(Selection.Period, "DLF=D");
		Point.Details = Selection.Period;
		ToolTip = ?(ProfitLoss < 0, "Loss " + -ProfitLoss, "Profit " + ProfitLoss) + " on " + Format(Selection.Period, "DLF=D");
		ProfitChart.SetValue(Point, Series, Selection.Profit, Point.Details, ToolTip);
		
		If ProfitLoss > MaxValue Then
			MaxValue = ProfitLoss;
		ElsIf ProfitLoss < MinValue Then
			MinValue = ProfitLoss;
		EndIf;
		 
	EndDo;
	
	ProfitChart.MaxValue = Max(Max(MaxValue, -MaxValue), Max(MinValue, -MinValue));
	ProfitChart.MinValue = -ProfitChart.MaxValue;
	
	ProfitChart.AutoTransposition = True;
	ProfitChart.RefreshEnabled = True;
	
EndProcedure

&AtServer
Procedure RefreshDebitorsWidget()
	
	CounterpartyWidth = 28;
	WidthDebt = 9;
	WidthOverdue = 9;
	WidthAdvance = 9;
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountsReceivableBalancesOverdue.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalancesOverdue.Counterparty AS Counterparty,
	|	AccountsReceivableBalancesOverdue.AmountBalance AS AmountBalance
	|INTO vtOverdue
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			&FilterDate,
	|			Company = &Company
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalancesOverdue
	|
	|INDEX BY
	|	SettlementsType,
	|	Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Counterparty.Presentation AS CounterpartyPresentation,
	|	SUM(CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|				THEN AccountsReceivableBalances.AmountBalance
	|			ELSE 0
	|		END) AS DebtAmount,
	|	SUM(CASE
	|			WHEN AccountsReceivableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsReceivableBalances.AmountBalance
	|			ELSE 0
	|		END) AS AdvanceAmount,
	|	SUM(ISNULL(vtOverdue.AmountBalance, 0)) AS AmountOverdue
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(&FilterDate, Company = &Company) AS AccountsReceivableBalances
	|		LEFT JOIN vtOverdue AS vtOverdue
	|		ON AccountsReceivableBalances.SettlementsType = vtOverdue.SettlementsType
	|			AND AccountsReceivableBalances.Counterparty = vtOverdue.Counterparty
	|
	|GROUP BY
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Counterparty.Presentation
	|
	|ORDER BY
	|	DebtAmount DESC
	|TOTALS
	|	COUNT(DISTINCT Counterparty),
	|	SUM(DebtAmount),
	|	SUM(AdvanceAmount),
	|	SUM(AmountOverdue)
	|BY
	|	OVERALL";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotals.Next() Then
		Items.DecorationDebitorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationDebitorsDebtTotal.Title = DriveServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationDebitorsArrearTotal.Title = DriveServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationDebitorsQuantity.Title = "—";
		Items.DecorationDebitorsDebtTotal.Title = "—";
		Items.DecorationDebitorsArrearTotal.Title = "—";
	EndIf;
	
	Items.DebitorsCounterparty.Title = "";
	Items.DebitorsCounterparty.ToolTip = "";
	Items.DebitorsDebt.Title = "";
	Items.DebitorsDebt.ToolTip = "";
	Items.OverdueDebitors.Title = "";
	Items.OverdueDebitors.ToolTip = "";
	Items.DebitorsAdvance.Title = "";
	Items.DebitorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 5 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AdvanceAmountPresentation = Format(Selection.AdvanceAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.DebitorsCounterparty.Title = Items.DebitorsCounterparty.Title + ?(IsBlankString(Items.DebitorsCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.DebitorsCounterparty.ToolTip = Items.DebitorsCounterparty.ToolTip + ?(IsBlankString(Items.DebitorsCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.DebitorsDebt.Title = Items.DebitorsDebt.Title + ?(IsBlankString(Items.DebitorsDebt.Title),"", Chars.LF) 
				+ Left(DebtAmountPresentation, WidthDebt) + ?(StrLen(DebtAmountPresentation) > WidthDebt, "...", "");
			Items.DebitorsDebt.ToolTip = Items.DebitorsDebt.ToolTip + ?(IsBlankString(Items.DebitorsDebt.ToolTip),"", Chars.LF) 
				+ DebtAmountPresentation;
				
			Items.OverdueDebitors.Title = Items.OverdueDebitors.Title + ?(IsBlankString(Items.OverdueDebitors.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.OverdueDebitors.ToolTip = Items.OverdueDebitors.ToolTip + ?(IsBlankString(Items.OverdueDebitors.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
			Items.DebitorsAdvance.Title = Items.DebitorsAdvance.Title + ?(IsBlankString(Items.DebitorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.DebitorsAdvance.ToolTip = Items.DebitorsAdvance.ToolTip + ?(IsBlankString(Items.DebitorsAdvance.ToolTip),"", Chars.LF) 
				+ AdvanceAmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshCreditorsWidget()
	
	CounterpartyWidth = 28;
	WidthDebt = 9;
	WidthOverdue = 9;
	WidthAdvance = 9;
	
	Query = New Query;
	Query.Text =
		"SELECT ALLOWED
		|	AccountsPayableOverdueBalances.SettlementsType,
		|	AccountsPayableOverdueBalances.Counterparty,
		|	AccountsPayableOverdueBalances.AmountBalance
		|INTO vtOverdue
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(
		|			&FilterDate,
		|			Company = &Company
		|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableOverdueBalances
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	AccountsPayableBalances.Counterparty AS Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation,
		|	SUM(CASE
		|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|				THEN AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS DebtAmount,
		|	SUM(CASE
		|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|				THEN -AccountsPayableBalances.AmountBalance
		|			ELSE 0
		|		END) AS AdvanceAmount,
		|	SUM(ISNULL(vtOverdue.AmountBalance, 0)) AS AmountOverdue
		|FROM
		|	AccumulationRegister.AccountsPayable.Balance(&FilterDate, Company = &Company) AS AccountsPayableBalances
		|		LEFT JOIN vtOverdue AS vtOverdue
		|		ON AccountsPayableBalances.SettlementsType = vtOverdue.SettlementsType
		|			AND AccountsPayableBalances.Counterparty = vtOverdue.Counterparty
		|
		|GROUP BY
		|	AccountsPayableBalances.Counterparty,
		|	AccountsPayableBalances.Counterparty.Presentation
		|
		|ORDER BY
		|	DebtAmount DESC
		|TOTALS
		|	COUNT(DISTINCT Counterparty),
		|	SUM(DebtAmount),
		|	SUM(AdvanceAmount),
		|	SUM(AmountOverdue)
		|BY
		|	OVERALL";
	
	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("Company", Company);
	
	SelectionTotals = Query.Execute().Select(QueryResultIteration.ByGroups);
	
	If SelectionTotals.Next() Then
		Items.DecorationCreditorsQuantity.Title = SelectionTotals.Counterparty;
		Items.DecorationCreditorsDebtTotal.Title = DriveServer.GenerateTitle(SelectionTotals.DebtAmount);
		Items.DecorationCreditorsOverdueTotal.Title = DriveServer.GenerateTitle(SelectionTotals.AmountOverdue);
	Else
		Items.DecorationCreditorsQuantity.Title = "—";
		Items.DecorationCreditorsDebtTotal.Title = "—";
		Items.DecorationCreditorsOverdueTotal.Title = "—";
	EndIf;
	
	Items.CreditorsCounterparty.Title = "";
	Items.CreditorsCounterparty.ToolTip = "";
	Items.CreditorsDebt.Title = "";
	Items.CreditorsDebt.ToolTip = "";
	Items.CreditorsOverdue.Title = "";
	Items.CreditorsOverdue.ToolTip = "";
	Items.CreditorsAdvance.Title = "";
	Items.CreditorsAdvance.ToolTip = "";
	
	Selection = SelectionTotals.Select();
	For IndexOf = 1 To 5 Do
		If Selection.Next() Then
			
			DebtAmountPresentation = Format(Selection.DebtAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AmountOverduePresentation = Format(Selection.AmountOverdue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			AdvanceAmountPresentation = Format(Selection.AdvanceAmount, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
			
			TitleCounterparty = StrReplace(Selection.CounterpartyPresentation, " ", Chars.NBSp);
			Items.CreditorsCounterparty.Title = Items.CreditorsCounterparty.Title + ?(IsBlankString(Items.CreditorsCounterparty.Title),"", Chars.LF) 
				+ Left(TitleCounterparty, CounterpartyWidth) + ?(StrLen(TitleCounterparty) > CounterpartyWidth, "...", "");
			Items.CreditorsCounterparty.ToolTip = Items.CreditorsCounterparty.ToolTip + ?(IsBlankString(Items.CreditorsCounterparty.ToolTip),"", Chars.LF) 
				+ TitleCounterparty;
				
			Items.CreditorsDebt.Title = Items.CreditorsDebt.Title + ?(IsBlankString(Items.CreditorsDebt.Title),"", Chars.LF) 
				+ Left(DebtAmountPresentation, WidthDebt) + ?(StrLen(DebtAmountPresentation) > WidthDebt, "...", "");
			Items.CreditorsDebt.ToolTip = Items.CreditorsDebt.ToolTip + ?(IsBlankString(Items.CreditorsDebt.ToolTip),"", Chars.LF) 
				+ DebtAmountPresentation;
				
			Items.CreditorsOverdue.Title = Items.CreditorsOverdue.Title + ?(IsBlankString(Items.CreditorsOverdue.Title),"", Chars.LF) 
				+ Left(AmountOverduePresentation, WidthOverdue) + ?(StrLen(AmountOverduePresentation) > WidthOverdue, "...", "");
			Items.CreditorsOverdue.ToolTip = Items.CreditorsOverdue.ToolTip + ?(IsBlankString(Items.CreditorsOverdue.ToolTip),"", Chars.LF) 
				+ AmountOverduePresentation;
				
			Items.CreditorsAdvance.Title = Items.CreditorsAdvance.Title + ?(IsBlankString(Items.CreditorsAdvance.Title),"", Chars.LF) 
				+ Left(AdvanceAmountPresentation, WidthAdvance) + ?(StrLen(AdvanceAmountPresentation) > WidthAdvance, "...", "");
			Items.CreditorsAdvance.ToolTip = Items.CreditorsAdvance.ToolTip + ?(IsBlankString(Items.CreditorsAdvance.ToolTip),"", Chars.LF) 
				+ AdvanceAmountPresentation;
				
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure RefreshOrdersWidget()
	
	AccountingBySubsidiaryCompany = Constants.AccountingBySubsidiaryCompany.Get();
	
	// SALES ORDERS
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN DocSalesOrder.Posted
		|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period < &DayStartFilterDate
		|				THEN DocSalesOrder.Ref
		|		END) AS BuyersOrdersExecutionExpired,
		|	COUNT(DISTINCT CASE
		|			WHEN DocSalesOrder.Posted
		|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period = &DayStartFilterDate
		|				THEN DocSalesOrder.Ref
		|			WHEN DocSalesOrder.Posted
		|					AND DocSalesOrder.SetPaymentTerms
		|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not PaymentSchedule.Quote IS NULL 
		|					AND PaymentSchedule.Period = &DayStartFilterDate
		|				THEN DocSalesOrder.Ref
		|		END) AS SalesOrdersForToday,
		|	COUNT(DISTINCT CASE
		|			WHEN DocSalesOrder.Posted
		|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|				THEN DocSalesOrder.Ref
		|		END) AS BuyersOrdersInWork
		|FROM
		|	Document.SalesOrder AS DocSalesOrder
		|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
		|		ON DocSalesOrder.Ref = RunSchedule.Order
		|			AND (RunSchedule.Period <= &DayStartFilterDate)
		|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
		|		ON DocSalesOrder.Ref = PaymentSchedule.Quote
		|			AND (PaymentSchedule.Period <= &DayStartFilterDate)},
		|	Constant.UseSalesOrderStatuses AS UseSalesOrderStatuses
		|WHERE
		|	Not DocSalesOrder.Closed
		|	AND Not DocSalesOrder.DeletionMark
		|	AND CASE
		|			WHEN &AccountingBySubsidiaryCompany = FALSE
		|				THEN DocSalesOrder.Company = &Company
		|			ELSE TRUE
		|		END";

	Query.SetParameter("DayStartFilterDate", BegOfDay(Period));
	Query.SetParameter("AccountingBySubsidiaryCompany", AccountingBySubsidiaryCompany);
	Query.SetParameter("Company", Company);

	Selection = Query.Execute().Select();

	If Selection.Next() Then
		Items.DecorationForShipmentQuantity.Title = ?(Selection.BuyersOrdersInWork = 0, "—", Selection.BuyersOrdersInWork);
		Items.DecorationForShipmentTodayQuantity.Title = ?(Selection.SalesOrdersForToday = 0, "—", Selection.SalesOrdersForToday);
		Items.DecorationForShipmentArrearQuantity.Title = ?(Selection.BuyersOrdersExecutionExpired = 0, "—", Selection.BuyersOrdersExecutionExpired);
	EndIf;
	
	// Purchase orders status
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period < &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersExecutionExpired,
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not RunSchedule.Order IS NULL 
		|					AND RunSchedule.Period = &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|			WHEN DocPurchaseOrder.SetPaymentTerms
		|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|					AND Not PaymentSchedule.Quote IS NULL 
		|					AND PaymentSchedule.Period = &DayStartFilterDate
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersForToday,
		|	COUNT(DISTINCT CASE
		|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
		|				THEN DocPurchaseOrder.Ref
		|		END) AS SupplierOrdersInWork
		|FROM
		|	Document.PurchaseOrder AS DocPurchaseOrder
		|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
		|		ON DocPurchaseOrder.Ref = RunSchedule.Order
		|			AND (RunSchedule.Period <= &DayStartFilterDate)
		|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
		|		ON DocPurchaseOrder.Ref = PaymentSchedule.Quote
		|			AND (PaymentSchedule.Period <= &DayStartFilterDate)}
		|WHERE
		|	DocPurchaseOrder.Posted
		|	AND Not DocPurchaseOrder.Closed
		|	AND CASE
		|			WHEN &AccountingBySubsidiaryCompany = FALSE
		|				THEN DocPurchaseOrder.Company = &Company
		|			ELSE TRUE
		|		END";

	Query.SetParameter("DayStartFilterDate", BegOfDay(Period));
	Query.SetParameter("AccountingBySubsidiaryCompany", AccountingBySubsidiaryCompany);
	Query.SetParameter("Company", Company);
	
	Selection = Query.Execute().Select();

	If Selection.Next() Then
		Items.DecorationForEntryQuantity.Title = ?(Selection.SupplierOrdersInWork = 0, "—", Selection.SupplierOrdersInWork);
		Items.DecorationForEntryTodayQuantity.Title = ?(Selection.SupplierOrdersForToday = 0, "—", Selection.SupplierOrdersForToday);
		Items.DecorationForEntryArrearQuantity.Title = ?(Selection.SupplierOrdersExecutionExpired = 0, "—", Selection.SupplierOrdersExecutionExpired);
	EndIf;
	
EndProcedure

&AtServer
Procedure UpdateSalesWidget()
	
	Query = New Query;
	Query.Text = 
		"SELECT ALLOWED
		|	COUNT(DISTINCT CASE
		|			WHEN SalesTurnovers.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
		|				THEN SalesTurnovers.Products
		|		END) AS Products,
		|	COUNT(DISTINCT CASE
		|			WHEN SalesTurnovers.Products.ProductsType = VALUE(Enum.ProductsTypes.Service)
		|				THEN SalesTurnovers.Products
		|		END) AS Services
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&FilterDateBeginning, &FilterDate, , Company = &Company) AS SalesTurnovers
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT ALLOWED
		|	SalesTurnovers.Period AS Period,
		|	SalesTurnovers.AmountTurnover AS Amount
		|FROM
		|	AccumulationRegister.Sales.Turnovers(&FilterDateBeginning, &FilterDate, Day, Company = &Company) AS SalesTurnovers
		|
		|ORDER BY
		|	Period
		|TOTALS
		|	SUM(Amount)
		|BY
		|	OVERALL,
		|	Period PERIODS(Day, &FilterDateBeginning, &FilterDate)";

	Query.SetParameter("FilterDate", EndOfDay(Period));
	Query.SetParameter("FilterDateBeginning", AddMonth(BegOfDay(Period),-1));
	Query.SetParameter("Company", Company);
	
	ResultsArray = Query.ExecuteBatch();
	
	Selection = ResultsArray[0].Select();
	Selection.Next();
	Items.DecorationGoodsQuantity.Title = ?(Selection.Products = 0, "—", Selection.Products);
	Items.DecorationServicesQuantity.Title = ?(Selection.Services = 0, "—", Selection.Services);
	
	SelectionTotal = ResultsArray[1].Select(QueryResultIteration.ByGroups);
	If SelectionTotal.Next() Then
		Items.DecorationSalesTotal.Title = DriveServer.GenerateTitle(SelectionTotal.Amount);
	Else
		Items.DecorationSalesTotal.Title = "—";
	EndIf;
	
	SaleDiagram.RefreshEnabled = False;
	SaleDiagram.Clear();
	SaleDiagram.AutoTransposition = False;
	SaleDiagram.Border = New Border(ControlBorderType.WithoutBorder, -1);
	
	Series = SaleDiagram.Series.Add("Sales amount");
	Series.Color = DriveServer.ColorForMonitors("Dark-green");
	
	Selection = SelectionTotal.Select(QueryResultIteration.ByGroups, "Period", "All");

	While Selection.Next() Do
		
		Point = SaleDiagram.Points.Add(Selection.Period);
		Point.Text = Format(Selection.Period, "DLF=D");
		Point.Details = Selection.Period;
		ToolTip = "Sales amount " + Selection.Amount + " on " + Format(Selection.Period, "DLF=D");
		SaleDiagram.SetValue(Point, Series, Selection.Amount, Point.Details, ToolTip);
		 
	EndDo;
	
	SaleDiagram.AutoTransposition = True;
	SaleDiagram.RefreshEnabled = True;
	
EndProcedure

#EndRegion
