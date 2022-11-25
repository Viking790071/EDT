
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount	= Parameters.GLAccount;
	Ref			= Parameters.Ref;
	
	If IsAnyUsesThisCR(Ref) Then
		Items.GLAccountsGroup.ToolTip	= NStr("en = 'Records are registered for this cash register in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этой кассе ККМ! Изменение счета учета запрещено!';pl = 'W bazie informacyjnej istnieją zarejestrowane wpisy dla tej kasy fiskalnej. Nie można zmienić konta księgowego.';es_ES = 'Grabaciones se han registrado para esta caja registradora en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para esta caja registradora en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Bu yazar kasa için Infobase''de kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Nel database ci sono movimenti per questo registratore di cassa! Non è possibile cambiare i conti mastro!';de = 'Aufzeichnungen werden für diese Kasse in der Infobase registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled	= False;
		Items.Default.Visible			= False;
	EndIf;
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function IsAnyUsesThisCR(Ref)
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	CashInCashRegistersTurnovers.CashCR AS CashCR
	|FROM
	|	AccumulationRegister.CashInCashRegisters.Turnovers(, , Recorder, CashCR = &CashCR) AS CashInCashRegistersTurnovers");
	
	Query.SetParameter("CashCR", ?(ValueIsFilled(Ref), Ref, Undefined));
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("PettyCashAccount");
EndFunction

&AtClient
Procedure NotifyAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount);
	
	Notify("CashRegisterAccountsChanged", ParameterStructure);
	
EndProcedure

#EndRegion
