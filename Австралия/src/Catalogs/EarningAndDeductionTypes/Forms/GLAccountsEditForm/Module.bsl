
#Region ServiceProceduresAndFunctions

// Procedure for creating the owner form notification about the change of account
//
&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure("GLExpenseAccount", GLExpenseAccount);
	Notify("AccountsChangedEarningAndDeductionTypes", ParameterStructure);
	
EndProcedure

// Function checks GL account change option.
//
&AtServer
Function CancelGLExpenseAccountChange(EarningAndDeductionType)
	
	Query = New Query(
	"SELECT ALLOWED
	|	EarningsAndDeductions.Period,
	|	EarningsAndDeductions.Recorder,
	|	EarningsAndDeductions.LineNumber,
	|	EarningsAndDeductions.Active,
	|	EarningsAndDeductions.Company,
	|	EarningsAndDeductions.PresentationCurrency,
	|	EarningsAndDeductions.StructuralUnit,
	|	EarningsAndDeductions.Employee,
	|	EarningsAndDeductions.RegistrationPeriod,
	|	EarningsAndDeductions.Currency,
	|	EarningsAndDeductions.EarningAndDeductionType,
	|	EarningsAndDeductions.Amount,
	|	EarningsAndDeductions.AmountCur,
	|	EarningsAndDeductions.StartDate,
	|	EarningsAndDeductions.EndDate,
	|	EarningsAndDeductions.DaysWorked,
	|	EarningsAndDeductions.HoursWorked,
	|	EarningsAndDeductions.Size
	|FROM
	|	AccumulationRegister.EarningsAndDeductions AS EarningsAndDeductions
	|WHERE
	|	EarningsAndDeductions.EarningAndDeductionType = &EarningAndDeductionType");
	
	Query.SetParameter("EarningAndDeductionType", ?(ValueIsFilled(EarningAndDeductionType), EarningAndDeductionType, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

// Procedure fills the data structure for the GL account selection.
//
&AtServer
Procedure ReceiveDataForSelectAccountsSettlements(DataStructure)
	
	GLAccountsAvailableTypes = New Array;
	EarningAndDeductionType = DataStructure.EarningAndDeductionType;
	If Not ValueIsFilled(EarningAndDeductionType) Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProgress);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Earning Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.WorkInProgress);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherFixedAssets);
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Deduction Then
		
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherIncome);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.Expenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.IndirectExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherExpenses);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.AccountsPayable);
		GLAccountsAvailableTypes.Add(Enums.GLAccountsTypes.OtherShorttermObligations);
		
	EndIf;
	
	DataStructure.Insert("GLAccountsAvailableTypes", GLAccountsAvailableTypes);
	
EndProcedure

// Procedure sets the link of selection parameters for the "GL expense account" attribute
//
&AtServer
Procedure SetConnectionSelectAtServerParameters()
	
	DataStructure = New Structure;
	DataStructure.Insert("EarningAndDeductionType", EarningAndDeductionType);
		
	ReceiveDataForSelectAccountsSettlements(DataStructure);
	
	NewArray = New Array;
	NewParameter = New ChoiceParameter("Filter.TypeOfAccount", New FixedArray(DataStructure.GLAccountsAvailableTypes));
	NewArray.Add(NewParameter);
	ChoiceParameters = New FixedArray(NewArray);
	Items.GLExpenseAccount.ChoiceParameters = ChoiceParameters
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

// Procedure - event handler of the OnCreateAtServer form
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLExpenseAccount		= Parameters.GLExpenseAccount;
	EarningAndDeductionType	= Parameters.Ref;
	IsTax					= (EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Tax);
	
	SetConnectionSelectAtServerParameters();
	
	If CancelGLExpenseAccountChange(EarningAndDeductionType) Then
		
		Items.GLAccountsGroup.ToolTip	= NStr("en = 'Records are registered for this type of earning (deduction) in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этому типу начисления (удержания). Изменение счета учета запрещено!';pl = 'W bazie informacyjnej są zarejestrowane zapisy dla tego rodzaju naliczeń (odliczeń) w bazie informacyjnej. Nie można zmienić konta ewidencji.';es_ES = 'Grabaciones se han registrado para este tipo de ingreso (deducción) en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para este tipo de ingreso (deducción) en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Veritabanındaki bu tür gelir (kesinti) için kayıtlar kaydedilir. Muhasebe hesabı değiştirilemez.';it = 'Le registrazioni sono registrate per questa tipologia di compensi (trattenute) nell''infobase. Impossibile modificare il conto mastro.';de = 'Aufzeichnungen werden für diese Art von Bezug (Abzug) in der Infobase registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled	= False;
		Items.Default.Visible			= False;
		
	EndIf;
	
EndProcedure

// Procedure - event handler of the OnCreateAtServer form
//
&AtClient
Procedure OnOpen(Cancel)
	
	If IsTax Then
		
		ShowMessageBox(, NStr("en = 'GL accounts are not edited for the Tax Earning kind.'; ru = 'Для типа вида начисления Налог счета учета не редактируются!';pl = 'Konta księgowe nie są edytowane w związku z naliczaniem dochodu podatkowego.';es_ES = 'Cuentas del libro mayor no se han editado para el tipo de Ingreso Fiscal.';es_CO = 'Cuentas del libro mayor no se han editado para el tipo de Ingreso Fiscal.';tr = 'Vergi tahakkuku için Muhasebe hesapları düzenlenmez.';it = 'I conti mastro non vengono modificati per la tipologia di Imposta per Compensi.';de = 'Hauptbuch-Konten werden nicht für die Arten von Steuerbezügen bearbeitet.'"));
		Cancel = True;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

// Procedure - command handler by default.
//
&AtClient
Procedure Default(Command)
	
	GLExpenseAccount = GetDefaultExpensesAccount();
	NotifyAccountChange();
	
EndProcedure

&AtServerNoContext
Function GetDefaultExpensesAccount()	
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PayrollExpenses");	
EndFunction

#EndRegion

#Region FormAttributesEventsHandlers

&AtClient
Procedure GLExpenseAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLExpenseAccount) Then	
		GLExpenseAccount = GetDefaultExpensesAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion
