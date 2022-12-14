
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UseBudgeting = Constants.UseBudgeting.Get();
	
	If Not ValueIsFilled(Object.Ref) Then
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.FixedAssets")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsReceivable")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CashAndCashEquivalents") 
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Inventory")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LoanInterest")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherFixedAssets")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.CostOfSales") Then
				Object.Type = AccountType.Active;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Depreciation")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LongtermLiabilities")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Capital") 
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.AccountsPayable")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.LoansBorrowed")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ReserveAndAdditionalCapital")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.RetailMarkup") Then
				Object.Type = AccountType.Passive;
		EndIf;
		
		If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.IncomeTax")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.RetainedEarnings")
			OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.ProfitLosses") Then
				Object.Type = AccountType.ActivePassive;
		EndIf;
		
	EndIf;
	
	TypeOfAccount = Object.TypeOfAccount;
	
	Items.Type.ChoiceList.Clear();
	Items.Type.ChoiceList.Add(AccountType.Active,			NStr("en = 'Dr'; ru = '????';pl = 'Wn';es_ES = 'D??bito';es_CO = 'D??bito';tr = 'Bor??';it = 'Deb';de = 'Soll'"));
	Items.Type.ChoiceList.Add(AccountType.Passive,			NStr("en = '(Cr)'; ru = '(????)';pl = '(Ma)';es_ES = '(Cr??dito)';es_CO = '(Cr??dito)';tr = 'Alacak';it = '(Cred.)';de = '(Haben)'"));
	Items.Type.ChoiceList.Add(AccountType.ActivePassive,	NStr("en = 'Dr/(Cr)'; ru = '????/(????)';pl = 'Wn/(Ma)';es_ES = 'D??bito/(Cr??dito)';es_CO = 'D??bito/(Cr??dito)';tr = 'Bor??/Alacak';it = 'Deb/(Cred.)';de = 'Soll/(Haben)'"));
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject, Object);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	FormManagement();
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Write_PrimaryChartOfAccounts", Object.Ref);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Modified And IsBlankString(Object.Code) Then
		CommonClientServer.MessageToUser(NStr("en = '""Code"" is a required field'; ru = '?????????????? ??????';pl = 'Pole ""Kod"" jest wymagana';es_ES = '""C??digo"" es un campo obligatorio.';es_CO = '""C??digo"" es un campo obligatorio.';tr = '""Kod"" zorunlu aland??r.';it = '""Codice"" ?? un campo richiesto';de = '""Code"" ist ein Pflichtfeld.'"), , "Object.Code");
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.BeforeWriteAtServer(CurrentObject);
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)

	NativeLanguagesSupportServer.OnReadPresentationsAtServer(Object);
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

// Procedure - OnChange event handler of the DistributionMethod entry field.
//
&AtClient
Procedure DistributionModeOnChange(Item)
	
	If Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DirectCost") Then
		Items.Filter.Visible = True;
	Else
		Items.Filter.Visible = False;
		Object.GLAccounts.Clear();
	EndIf;

EndProcedure

// Procedure - OnChange event handler of the AccountType entry field.
//
&AtClient
Procedure GLAccountTypeOnChange(Item)
	
	If TypeOfAccount = Object.TypeOfAccount Then
		Return;
	EndIf;
	
	Object.GLAccounts.Clear();
	
	FormManagement();
	
	If Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.WorkInProgress") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DoNotDistribute");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.IndirectExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.ProductionVolume");
	ElsIf Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Expenses")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.Revenue")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherIncome")
		  OR Object.TypeOfAccount = PredefinedValue("Enum.GLAccountsTypes.OtherExpenses") Then
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.SalesVolume");
	Else
		Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DoNotDistribute");
	EndIf;
	
	Items.Filter.Visible = Object.MethodOfDistribution = PredefinedValue("Enum.CostAllocationMethod.DirectCost");
	
	TypeOfAccount = Object.TypeOfAccount;
	
EndProcedure

&AtClient
Procedure Attachable_Open(Item, StandardProcessing)
	NativeLanguagesSupportClient.OnOpen(ThisObject, Object, Item, StandardProcessing);
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - command handler Filter.
//
&AtClient
Procedure Filter(Command)
	
	GLAccountsInStorageAddress = PlaceGLAccountsToStorage();
	
	FormParameters = New Structure(
		"GLAccountsInStorageAddress",
		GLAccountsInStorageAddress
	);
	
	Notification = New NotifyDescription("FilterCompletion",ThisForm,GLAccountsInStorageAddress);
	OpenForm("ChartOfAccounts.PrimaryChartOfAccounts.Form.FilterForm", FormParameters,,,,,Notification);
	
EndProcedure

&AtClient
Procedure FilterCompletion(Result,GLAccountsInStorageAddress) Export
	
	If Result = DialogReturnCode.OK Then
		GetGLAccountsFromStorage(GLAccountsInStorageAddress);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// The function moves the GLAccounts tabular section
// to the temporary storage and returns the address
//
&AtServer
Function PlaceGLAccountsToStorage()
	
	Return PutToTempStorage(
		Object.GLAccounts.Unload(, "GLAccount"),
		UUID);
	
EndFunction

// The function receives the tabular section of GLAccounts from the temporary storage.
//
&AtServer
Procedure GetGLAccountsFromStorage(GLAccountsInStorageAddress)
	
	TableAccountsAccounting = GetFromTempStorage(GLAccountsInStorageAddress);
	Object.GLAccounts.Clear();
	For Each TableRow In TableAccountsAccounting Do
		String = Object.GLAccounts.Add();
		FillPropertyValues(String, TableRow);
	EndDo;
	
EndProcedure

&AtServer
Procedure FormManagement()
	
	UseBudgeting = Constants.UseBudgeting.Get();
	If Object.TypeOfAccount =  Enums.GLAccountsTypes.WorkInProgress Then
		Items.ClosingAccount.Visible = True;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.ProductionVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DirectCost);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute);
		Items.ClosingAccount.ToolTip = ?(
			UseBudgeting,
			NStr("en = 'Auto closing account on month closing and budgeting'; ru = '???????? ?????????????????????????????? ???????????????? ?????? ???????????????? ???????????? ?? ????????????????????????????';pl = 'Automatyczne zamykanie konta przy zamykaniu miesi??ca i bud??etowaniu';es_ES = 'Cuenta de cierre autom??tico al cerrar el mes y la presupuestaci??n';es_CO = 'Cuenta de cierre autom??tico al cerrar el mes y la presupuestaci??n';tr = 'Ay sonunda ve b??t??elemede otomatik kapan???? hesab??';it = 'Chiusura automatica del conto alla chiusura del mese e budgeting';de = 'Automatisches Schlie??en des Kontos f??r Monatsabschluss und Budgetierung'"),
			NStr("en = 'Auto closing account on month closing'; ru = '???????? ?????????????????????????????? ???????????????? ?????? ???????????????? ????????????';pl = 'Automatyczne zamykanie konta przy zamykaniu miesi??ca';es_ES = 'Cuenta de cierre autom??tico al cerrar el mes';es_CO = 'Cuenta de cierre autom??tico al cerrar el mes';tr = 'Ay??n sonunda otomatik kapan???? hesab??';it = 'Chiusura automatica del conto alla chiusura del mese';de = 'Automatisches Schlie??en des Kontos f??r Monatsabschluss'")
		);
	ElsIf (TypeOfAccount <>  Enums.GLAccountsTypes.OtherIncome
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.OtherExpenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Expenses
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.LoanInterest
		   OR TypeOfAccount <>  Enums.GLAccountsTypes.Revenue)
			AND (Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherIncome
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.OtherExpenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Expenses
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.LoanInterest
		   OR Object.TypeOfAccount =  Enums.GLAccountsTypes.Revenue) Then
		Items.ClosingAccount.Visible = False;
		Items.MethodOfDistribution.Visible = True;
		Items.MethodOfDistribution.ChoiceList.Clear();
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesVolume);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.SalesRevenue);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.CostOfGoodsSold);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.GrossProfit);
		Items.MethodOfDistribution.ChoiceList.Add(Enums.CostAllocationMethod.DoNotDistribute);
	Else
		Items.MethodOfDistribution.Visible = False;
		Items.ClosingAccount.Visible = False;
	EndIf;
	
	Items.Currency.Visible = (Object.TypeOfAccount <> Enums.GLAccountsTypes.Inventory);
	Items.Filter.Visible = Object.MethodOfDistribution = Enums.CostAllocationMethod.DirectCost;
	
EndProcedure

#EndRegion
