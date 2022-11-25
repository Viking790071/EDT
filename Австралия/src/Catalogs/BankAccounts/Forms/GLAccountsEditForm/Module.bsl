
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	Ref = Parameters.Ref;
	CompanyOwner = TypeOf(Ref.Owner) = Type("CatalogRef.Companies");
	
	If CancelGLAccountChange(Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this bank account in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этому банковскому счету! Изменение счета учета запрещено!';pl = 'W bazie informacyjnej są zarejestrowane wpisy dla tego rachunku bankowego. Nie można zmienić konta księgowego.';es_ES = 'Grabaciones están registradas para esta cuenta bancaria en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones están registradas para esta cuenta bancaria en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Bu banka hesabı için Infobase''de kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Nel database ci sono movimenti per questo conto corrente! Non è possibile cambiare i conti mastro!';de = 'Aufzeichnungen werden für dieses Bankkonto in der Infobase registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled = False;
		Items.ByDefault.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If Not CompanyOwner Then
		Cancel = True;
		ShowMessageBox(, NStr("en = 'GL accounts are edited only for company bank accounts.'; ru = 'Счета учетов редактируются только для банковских счетов организаций!';pl = 'Konta księgowe są edytowane tylko dla rachunków bankowych firmy.';es_ES = 'Cuentas del libro mayor están editadas solo para las cuentas bancarias de la empresa.';es_CO = 'Cuentas del libro mayor están editadas solo para las cuentas bancarias de la empresa.';tr = 'Muhasebe hesapları yalnızca iş yerinin banka hesapları için düzeltilir.';it = 'I conti mastro vengono modificati solo per i conti bancari dell''azienda.';de = 'Hauptbuch-Konten werden nur für Firmenbankkonten bearbeitet.'"));
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ByDefault(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

&AtServerNoContext
Function GetDefaultGLAccount()	
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("BankAccount");	
EndFunction

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

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

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount
	);
	
	Notify("AccountsChangedBankAccounts", ParameterStructure);
	
EndProcedure

#EndRegion
