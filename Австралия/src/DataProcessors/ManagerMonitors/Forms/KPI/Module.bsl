
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
// Procedure - event  handler OnChange input field Period.
//
Procedure PeriodOnChange(Item)
	
	If Period = '00010101' Then
		Period = CommonClient.SessionDate();
	EndIf;	
		
	RefreshData();
	
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
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	AccountingIncomeAndCosts.Period AS Period,
	|	AccountingIncomeAndCosts.AmountIncomeTurnover AS Income,
	|	0 AS Cost,
	|	0 AS Expenses
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND IncomeAndExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.Revenue)) AS AccountingIncomeAndCosts
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingIncomeAndCosts.Period,
	|	0,
	|	AccountingIncomeAndCosts.AmountExpenseTurnover,
	|	0
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND IncomeAndExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.CostOfSales)) AS AccountingIncomeAndCosts
	|
	|UNION ALL
	|
	|SELECT
	|	AccountingIncomeAndCosts.Period,
	|	0,
	|	0,
	|	AccountingIncomeAndCosts.AmountExpenseTurnover
	|FROM
	|	AccumulationRegister.IncomeAndExpenses.Turnovers(
	|			&FilterDateBeginning,
	|			&FilterDateEnds,
	|			Month,
	|			Company = &Company
	|				AND IncomeAndExpenseItem.IncomeAndExpenseType = VALUE(Catalog.IncomeAndExpenseTypes.AdministrativeExpenses)) AS AccountingIncomeAndCosts
	|
	|ORDER BY
	|	Period
	|TOTALS
	|	SUM(Income),
	|	SUM(Cost),
	|	SUM(Expenses)
	|BY
	|	Period PERIODS(MONTH, &FilterDateBeginning, &FilterDateEnds)";
	
	Query.SetParameter("FilterDateBeginning", AddMonth(EndOfMonth(Period)+1,-12));
	Query.SetParameter("FilterDateEnds", EndOfMonth(Period));
	Query.SetParameter("Company", Company);
	
	QueryResult = Query.Execute();
	
	MaxIncome = 0;
	MaxCost = 0;
	MaxGrossProfit = 0;
	MaxExpenses = 0;
	MaxProfit = 0;
	Selection = QueryResult.Select(QueryResultIteration.ByGroups);
	While Selection.Next() Do
		If Selection.Income > MaxIncome Then
			MaxIncome = Selection.Income;
		EndIf;
		If Selection.Cost > MaxCost Then
			MaxCost = Selection.Cost;
		EndIf;
		If Selection.Income - Selection.Cost > MaxGrossProfit Then
			MaxGrossProfit = Selection.Income - Selection.Cost;
		EndIf;
		If Selection.Expenses > MaxExpenses Then
			MaxExpenses = Selection.Expenses;
		EndIf;
		If Selection.Income - Selection.Cost - Selection.Expenses > MaxProfit Then
			MaxProfit = Selection.Income - Selection.Cost - Selection.Expenses;
		EndIf;
	EndDo;
	
	Selection = Query.Execute().Select(QueryResultIteration.ByGroups, "Period", "All");
	MonthNumber = 0;
	While Selection.Next() Do
		
		MonthNumber = MonthNumber + 1;
		
		Income = ?(ValueIsFilled(Selection.Income), Selection.Income, 0);
		Cost = ?(ValueIsFilled(Selection.Cost), Selection.Cost, 0);
		GrossProfit = Income - Cost;
		Expenses = ?(ValueIsFilled(Selection.Expenses), Selection.Expenses, 0);
		Profit = Income - Cost - Expenses;
		
		Items["Month"+MonthNumber].Title = Format(Selection.Period, "DF='MMMM yyyy'");
		
		Items["Income"+MonthNumber].Title = FormattedStringForChart(Income, MaxIncome, DriveServer.ColorForMonitors("Green"));
		Items["Cost"+MonthNumber].Title = FormattedStringForChart(Cost, MaxCost, DriveServer.ColorForMonitors("Blue"));
		Items["GrossProfit"+MonthNumber].Title = FormattedStringForChart(GrossProfit, MaxGrossProfit, DriveServer.ColorForMonitors("Coral"));
		Items["Expenses"+MonthNumber].Title = FormattedStringForChart(Expenses, MaxExpenses, DriveServer.ColorForMonitors("Orange"));
		Items["Profit"+MonthNumber].Title = FormattedStringForChart(Profit, MaxProfit, DriveServer.ColorForMonitors("Magenta"));
		
	EndDo;
	
EndProcedure

// The function returns a formatted string for the form item as a chart (horizontal stacked chart) with a signature
//
// Parameters:
//  CurrentValue	 - Number	 - series
//  MaxValue value	 - Number	 - maximum value for
//  the ValueColor chart	 - Color	 - Color
// for series Return value:
//  FormattedString
&AtServerNoContext
Function FormattedStringForChart(CurrentValue, MaxValue, ValueColor)
	
	CharactersInChart = 16;
	EmptyValueColor = DriveServer.ColorForMonitors("Light-gray");
	
	RowItems = New Array;
	ItemChartValue = New Structure("String, Font, TextColor");
	ChartLine = "";
	
	If CurrentValue < 0 Or MaxValue <= 0 Then
		CurrentValueCharacters = 0;
	Else
		CurrentValueCharacters = ?(MaxValue = 0, 0, Round(CurrentValue / MaxValue * CharactersInChart));
	EndIf;
	For IndexOf = 1 To CurrentValueCharacters Do
		ChartLine = ChartLine + "▄";
	EndDo;
	ItemChartValue.String = ChartLine;
	ItemChartValue.Font = New Font("@Arial Unicode MS");
	ItemChartValue.TextColor = ValueColor;
	
	RowItems.Add(ItemChartValue);
	
	ItemEmptyValueCharts = New Structure("String, Font, TextColor");
	ChartLine = "";
	
	For IndexOf = CurrentValueCharacters+1 To CharactersInChart Do
		ChartLine = ChartLine + "▄";
	EndDo;
	ChartLine = ChartLine + Chars.LF;
	ItemEmptyValueCharts.String = ChartLine;
	ItemEmptyValueCharts.Font = New Font("@Arial Unicode MS");
	ItemEmptyValueCharts.TextColor = EmptyValueColor;
	RowItems.Add(ItemEmptyValueCharts);
	
	ItemValuePresentation = New Structure("String, Font, TextColor");
	
	ItemValuePresentation.String = Format(CurrentValue, "NFD=2; NGS=' '; NZ=0,00; NG=3,0");
	If CurrentValue < 0 Then
		ItemValuePresentation.TextColor = DriveServer.ColorForMonitors("Red");
	Else
		ItemValuePresentation.TextColor = DriveServer.ColorForMonitors("Gray");
	EndIf;
	RowItems.Add(ItemValuePresentation);
	
	Return DriveServer.BuildFormattedString(RowItems);
	
EndFunction

#EndRegion
