
#Region GeneralPurposeProceduresAndFunctions

// Function checks account change option.
//
&AtServer
Function DenialChangeGLAccounts(BusinessLine)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	IncomeAndExpenses.Period,
	|	IncomeAndExpenses.Recorder,
	|	IncomeAndExpenses.LineNumber,
	|	IncomeAndExpenses.Active,
	|	IncomeAndExpenses.Company,
	|	IncomeAndExpenses.StructuralUnit,
	|	IncomeAndExpenses.BusinessLine,
	|	IncomeAndExpenses.SalesOrder,
	|	IncomeAndExpenses.GLAccount,
	|	IncomeAndExpenses.AmountIncome,
	|	IncomeAndExpenses.AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses
	|WHERE
	|	IncomeAndExpenses.BusinessLine = &BusinessLine");
	
	Query.SetParameter("BusinessLine", BusinessLine);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProfitGLAccount = Undefined;
	BusinessLine = Parameters.Ref;
	
	If Parameters.Property("ProfitGLAccount") Then
		ProfitGLAccount = Parameters.ProfitGLAccount;
	EndIf;
	
	If DenialChangeGLAccounts(BusinessLine) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'There is income or expenses for this area in the infobase. Cannot change GL accounts of sales revenue.'; ru = 'В базе есть доходы или расходы по этому направлению деятельности! Изменение счета учета выручки от продаж запрещено!';pl = 'W bazie informacyjnej istnieje dochód lub rozchód dla tego obszaru w bazie informacyjnej. Nie można zmienić konta księgowego z dochodów ze sprzedaży.';es_ES = 'Hay ingresos y gastos para esta área en la infobase. No se puede cambiar las cuentas del libro mayor de los ingresos por ventas.';es_CO = 'Hay ingresos y gastos para esta área en la infobase. No se puede cambiar las cuentas del libro mayor de los ingresos por ventas.';tr = 'Infobase''de bu alan için gelir veya giderler mevcut. Satış gelirlerinin Muhasebe hesapları değiştirilemez.';it = 'Nel database ci sono entrate o uscite in quest''area di attività! È vietato modificare il conto mastro delle entrate di vendita!';de = 'Für diesen Bereich gibt es in der Infobase Einnahmen oder Ausgaben. Die Hauptbuch-Konten des Umsatzerlöses können nicht geändert werden.'");
		
		Items.ProfitGLAccount.Enabled					= Not ValueIsFilled(ProfitGLAccount);
		
		Items.Default.Visible = False;
		
	EndIf;
	
	If Parameters.Ref = Catalogs.LinesOfBusiness.Other Then
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.OtherIncome);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.OtherExpenses);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
	Else
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.Revenue);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
		NewParameter = New ChoiceParameter("Filter.TypeOfAccount", Enums.GLAccountsTypes.CostOfSales);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	DefaultAtServer();
	NotifyAccountChange();
EndProcedure

&AtServer
Procedure DefaultAtServer()
	
	ProfitGLAccount = GetDefaultGLAccount("IncomeSummary");
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount(Account)
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount(Account);
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure;
	ParameterStructure.Insert("ProfitGLAccount",					ProfitGLAccount);
	
	Notify("ActivityAccountsChanged", ParameterStructure);
	
EndProcedure

&AtClient
Procedure ProfitGLAccountOnChange(Item)
	
	If NOT ValueIsFilled(ProfitGLAccount) Then
		ProfitGLAccount = GetDefaultGLAccount("IncomeSummary");
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
