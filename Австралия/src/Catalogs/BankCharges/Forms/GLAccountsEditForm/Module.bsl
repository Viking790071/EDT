
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	GLAccount			= Parameters.GLAccount;
	GLExpenseAccount	= Parameters.GLExpenseAccount;
	Ref					= Parameters.Ref;
	
	If CancelEditGLAccounts(Ref) Then
		Items.GroupGLAccounts.ToolTip	= NStr("en = 'Records are registered for these products in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этой номенклатуре! Изменение счета учета запрещено!';pl = 'W bazie informacyjnej są zarejestrowane wpisy dla tych towarów. Nie można zmienić konta ewidencji.';es_ES = 'Grabaciones se han registrado para estos productos en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para estos productos en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Bu ürünler için Infobase''de kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Ci sono registrazioni per questi articoli nel database. Non è possibile cambiare il conto mastro.';de = 'Für diese Produkte sind in der Infobase Datensätze registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GroupGLAccounts.Enabled	= False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemEventHandlers

&AtClient
Procedure GLAccountOnChange(Item)

	NotifyAboutChangingGLAccount();
	
EndProcedure

&AtClient
Procedure GLExpenseAccountOnChange(Item)

	NotifyAboutChangingGLAccount();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function CancelEditGLAccounts(Ref)
	
	Query = New Query(
	"SELECT ALLOWED
	|	BankCharges.Period,
	|	BankCharges.Recorder,
	|	BankCharges.LineNumber,
	|	BankCharges.Active,
	|	BankCharges.Company,
	|	BankCharges.BankAccount,
	|	BankCharges.Currency,
	|	BankCharges.BankCharge,
	|	BankCharges.Item,
	|	BankCharges.Amount
	|FROM
	|	AccumulationRegister.BankCharges AS BankCharges
	|WHERE
	|	BankCharges.BankCharge = &BankCharge");
	
	Query.SetParameter("BankCharge", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtClient
Procedure NotifyAboutChangingGLAccount()
	
	ParametersStructure = New Structure(
		"GLAccount, GLExpenseAccount",
		GLAccount, GLExpenseAccount
	);
	
	Notify("GLAccountsChanged", ParametersStructure);
	
EndProcedure

#EndRegion

