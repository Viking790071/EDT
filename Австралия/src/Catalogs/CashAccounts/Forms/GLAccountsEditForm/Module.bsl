
#Region FormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this cash fund in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этой кассе! Изменение счета учета запрещено!';pl = 'W bazie informacyjnej są zarejestrowane wpisy dla tej kasy. Nie można zmienić konta ewidencji.';es_ES = 'Grabaciones se han registrado para este fondo de efectivo en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para este fondo de efectivo en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Bu nakit fonu için Infobase''de kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Nel database ci sono movimenti per questa cassa! Non è possibile cambiare i conti mastro!';de = 'In der Infobase sind Aufzeichnungen zu diesem Kassenbestand registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.Default.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	
	StructureFilter = New Structure("TypeOfAccount", PredefinedValue("Enum.GLAccountsTypes.CashAndCashEquivalents"));
	
	ParametersForm = New Structure("Filter, CurrentRow, ChoiceMode", 
		StructureFilter, 
		PredefinedValue("ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef"),
		True);
	
	ChoiceHandler = New NotifyDescription("GLAccountStartChoiceEnd", ThisObject);
	
	OpenForm("ChartOfAccounts.PrimaryChartOfAccounts.ChoiceForm", ParametersForm, ThisObject, , , , ChoiceHandler);
	
EndProcedure

&AtClient
Procedure GLAccountStartChoiceEnd(ResultValue, AdditionalParameters) Export
	
	If ResultValue = Undefined Then
		Return;
	EndIf;
	
	GLAccount = ResultValue;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

// Procedure - command click handler Default.
//
&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount");	
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount
	);
	
	Notify("PettyCashAccountsChanged", ParameterStructure);
	
EndProcedure

#EndRegion

#Region Private

// Function checks GL account change option.
//
&AtServer
Function CancelGLAccountChange(Ref)
	
	Query = New Query(
	"SELECT ALLOWED
	|	CashAssets.Period AS Period,
	|	CashAssets.Recorder AS Recorder,
	|	CashAssets.LineNumber AS LineNumber,
	|	CashAssets.Active AS Active,
	|	CashAssets.RecordType AS RecordType,
	|	CashAssets.Company AS Company,
	|	CashAssets.PaymentMethod AS PaymentMethod,
	|	CashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	CashAssets.Currency AS Currency,
	|	CashAssets.Amount AS Amount,
	|	CashAssets.AmountCur AS AmountCur,
	|	CashAssets.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	CashAssets.Item AS Item
	|FROM
	|	AccumulationRegister.CashAssets AS CashAssets
	|WHERE
	|	CashAssets.BankAccountPettyCash = &BankAccountPettyCash");
	
	Query.SetParameter("BankAccountPettyCash", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

#EndRegion