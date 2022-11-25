
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ForeignExchangeAccounting = GetFunctionalOption("ForeignExchangeAccounting");
	
	FillCompaniesList();
	
	SetConditionalAppearance();
	
EndProcedure

&AtServer
Procedure BeforeLoadDataFromSettingsAtServer(Settings)
	
	Company = Settings.Get("Company");
	BankAccount = Settings.Get("BankAccount");
	Counterparty = Settings.Get("Counterparty");
	
	If ValueIsFilled(Company) Then
		NewParameter = New ChoiceParameter("Filter.Owner", Company);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
	Else
		FixedArrayCompanies = New FixedArray(CompaniesList.UnloadValues());
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
	EndIf;
	
	DriveClientServer.SetListFilterItem(BankStatements, "CompanyForFiltering", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(BankStatements, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(BankStatements, "BankAccount", BankAccount, ValueIsFilled(BankAccount));
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "NotificationAboutChangingDebt" Then
		Attachable_HandleListRowActivation();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BankAccountOnChange(Item)
	
	FilterGroup = CommonClientServer.CreateFilterItemGroup(BankStatements.SettingsComposer.Settings.Filter.Items,
		NStr("en = 'Bank account'; ru = 'Банковский счет';pl = 'Rachunek bankowy';es_ES = 'Cuenta bancaria';es_CO = 'Cuenta bancaria';tr = 'Banka hesabı';it = 'Conto corrente';de = 'Bankkonto'"),
		DataCompositionFilterItemsGroupType.OrGroup);
	
	CommonClientServer.SetFilterItem(FilterGroup,
		"BankAccount",
		BankAccount,
		DataCompositionComparisonType.Equal,
		,
		ValueIsFilled(BankAccount));
	
	CommonClientServer.SetFilterItem(FilterGroup,
		"BankAccountTo",
		BankAccount,
		DataCompositionComparisonType.Equal,
		,
		ValueIsFilled(BankAccount));
	
	AttachIdleHandler("Attachable_HandleListRowActivation", 0.2, True);
	
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(BankStatements, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

&AtClient
Procedure CompanyOnChange(Item)
	
	If ValueIsFilled(Company) Then
		
		NewParameter = New ChoiceParameter("Filter.Owner", Company);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
		
	Else
		
		FixedArrayCompanies = New FixedArray(CompaniesList.UnloadValues());
		NewParameter = New ChoiceParameter("Filter.Owner", FixedArrayCompanies);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.BankAccount.ChoiceParameters = NewParameters;
		
	EndIf;
	
	DriveClientServer.SetListFilterItem(BankStatements, "CompanyForFiltering", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure BankStatementsOnActivateRow(Item)
	
	AttachIdleHandler("Attachable_HandleListRowActivation", 0.2, True);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure StatementGoTo(Command)
	
	OpenForm("Report.CashBalance.Form", New Structure("VariantKey", "Statement"));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillCompaniesList()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Companies.Ref AS Ref
	|FROM
	|	Catalog.Companies AS Companies";
	
	CompaniesList.LoadValues(Query.Execute().Unload().UnloadColumn("Ref"));
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()
	
	// AmountExpense, Currency
	
	ItemAppearance = BankStatements.ConditionalAppearance.Items.Add();
	
	DataFilterItem					= ItemAppearance.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue		= New DataCompositionField("Type");
	DataFilterItem.ComparisonType	= DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue		= Type("DocumentRef.PaymentExpense");
	DataFilterItem.Use				= True;
	
	ItemAppearance.Appearance.SetParameterValue("MarkNegatives", True);
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("AmountExpense");
	FieldAppearance.Use = True;
	
	FieldAppearance = ItemAppearance.Fields.Items.Add();
	FieldAppearance.Field = New DataCompositionField("Currency");
	FieldAppearance.Use = True;
	
EndProcedure

&AtClient
Procedure Attachable_HandleListRowActivation()
	
	CurrentRow = Items.BankStatements.CurrentData;
	If CurrentRow <> Undefined Then
		
		If ValueIsFilled(BankAccount) Then
			
			HideAndClearBankAccountStateTo();
			
			If BankAccount = CurrentRow.BankAccount Then
				StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccount);
			Else
				StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccountTo);
			EndIf;
			
			FillPropertyValues(ThisObject, StructureData);
			
		ElsIf ValueIsFilled(CurrentRow.BankAccount) Then
			
			StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccount);
			FillPropertyValues(ThisObject, StructureData);
			
			If ValueIsFilled(CurrentRow.BankAccountTo) Then
				StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccountTo);
				InformationAmountCurClosingBalanceTo = StructureData.InformationAmountCurClosingBalance;
				InformationAmountCurOpeningBalanceTo = StructureData.InformationAmountCurOpeningBalance;
				InformationAmountCurReceiptTo = StructureData.InformationAmountCurReceipt;
				InformationAmountCurExpenseTo = StructureData.InformationAmountCurExpense;
				Items.BankAccountStateTo.Visible = True;
			Else
				HideAndClearBankAccountStateTo();
			EndIf;
			
		Else
			
			If ValueIsFilled(CurrentRow.BankAccountTo) Then
				StructureData = GetDataOnBankAccount(CurrentRow.Date, CurrentRow.BankAccountTo);
				FillPropertyValues(ThisObject, StructureData);
			Else
				InformationAmountCurClosingBalance = 0;
				InformationAmountCurOpeningBalance = 0;
				InformationAmountCurReceipt = 0;
				InformationAmountCurExpense = 0;
			EndIf;
			
			HideAndClearBankAccountStateTo();
			
		EndIf;
		
		Date = Format(CurrentRow.Date, "DLF=D");
		If ForeignExchangeAccounting Then
			Date = Date + " (" + CurrentRow.Currency + ")";
		EndIf;
	Else
		InformationAmountCurClosingBalance = 0;
		InformationAmountCurOpeningBalance = 0;
		InformationAmountCurReceipt = 0;
		InformationAmountCurExpense = 0;
		InformationAmountCurClosingBalanceTo = 0;
		InformationAmountCurOpeningBalanceTo = 0;
		InformationAmountCurReceiptTo = 0;
		InformationAmountCurExpenseTo = 0;
		Date = "";
	EndIf;
	
EndProcedure

&AtClient
Procedure HideAndClearBankAccountStateTo()
	
	InformationAmountCurClosingBalanceTo = 0;
	InformationAmountCurOpeningBalanceTo = 0;
	InformationAmountCurReceiptTo = 0;
	InformationAmountCurExpenseTo = 0;
	Items.BankAccountStateTo.Visible = False;
	
EndProcedure

&AtServerNoContext
Function GetDataOnBankAccount(Period, BankAccount)
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	CashAssetsBalanceAndTurnovers.AmountCurOpeningBalance AS InformationAmountCurOpeningBalance,
	|	CashAssetsBalanceAndTurnovers.AmountCurReceipt AS InformationAmountCurReceipt,
	|	CashAssetsBalanceAndTurnovers.AmountCurExpense AS InformationAmountCurExpense,
	|	CashAssetsBalanceAndTurnovers.AmountCurClosingBalance AS InformationAmountCurClosingBalance
	|FROM
	|	AccumulationRegister.CashAssets.BalanceAndTurnovers(&BeginOfPeriod, &EndOfPeriod, Day, , BankAccountPettyCash = &BankAccount) AS CashAssetsBalanceAndTurnovers";
	
	Query.SetParameter("BeginOfPeriod", BegOfDay(Period));
	Query.SetParameter("EndOfPeriod", EndOfDay(Period));
	Query.SetParameter("BankAccount", BankAccount);
	ResultSelection = Query.Execute().Select();
	
	ReturnStructure = New Structure;
	ReturnStructure.Insert("InformationAmountCurOpeningBalance", 0);
	ReturnStructure.Insert("InformationAmountCurClosingBalance", 0);
	ReturnStructure.Insert("InformationAmountCurReceipt", 0);
	ReturnStructure.Insert("InformationAmountCurExpense", 0);
	
	If ResultSelection.Next() Then
		FillPropertyValues(ReturnStructure, ResultSelection);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion