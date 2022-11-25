
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccount = Parameters.GLAccount;
	
	If CancelGLAccountChange(Parameters.Ref) Then
		Items.GLAccountsGroup.ToolTip = NStr("en = 'Records are registered for this POS terminal in the infobase. Cannot change the GL account.'; ru = 'В базе есть движения по этому эквайринговому терминалу. Изменение счета учета запрещено.';pl = 'W bazie informacyjnej są rejestrowane wpisy dla tego terminala POS. Nie można zmienić konta ewidencji.';es_ES = 'Grabaciones se han registrado para este terminal TPV en la infobase. No se puede cambiar la cuenta del libro mayor.';es_CO = 'Grabaciones se han registrado para este terminal TPV en la infobase. No se puede cambiar la cuenta del libro mayor.';tr = 'Bu POS terminali için Infobase''de kayıtlar mevcut. Muhasebe hesabı değiştirilemez.';it = 'Nel database ci sono movimenti per questo terminale POS. Impossibile modificare il conto mastro.';de = 'Für dieses POS-Terminal sind in der Infobase Aufzeichnungen registriert. Das Hauptbuch-Konto kann nicht geändert werden.'");
		Items.GLAccountsGroup.Enabled = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure Default(Command)
	
	GLAccount = GetDefaultGLAccount();
	NotifyAboutSettlementAccountChange();
	
EndProcedure

&AtClient
Procedure GLAccountOnChange(Item)
	
	If NOT ValueIsFilled(GLAccount) Then
		GLAccount = GetDefaultGLAccount();
	EndIf;
	
	NotifyAboutSettlementAccountChange();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function CancelGLAccountChange(Ref)
	
	If Not ValueIsFilled(Ref) Then
		Return False;
	EndIf;
	
	Query = New Query(
	"SELECT ALLOWED TOP 1
	|	ShiftClosurePaymentWithPaymentCards.Ref AS Ref
	|FROM
	|	Document.ShiftClosure.PaymentWithPaymentCards AS ShiftClosurePaymentWithPaymentCards
	|WHERE
	|	ShiftClosurePaymentWithPaymentCards.Ref.Posted
	|	AND ShiftClosurePaymentWithPaymentCards.POSTerminal = &POSTerminal");
	
	Query.SetParameter("POSTerminal", Ref);
	
	Result = Query.Execute();
	
	Return Not Result.IsEmpty();
	
EndFunction

&AtServerNoContext
Function GetDefaultGLAccount()
	Return Catalogs.DefaultGLAccounts.GetDefaultGLAccount("CreditCardSalesReceivedAtALaterDate");	
EndFunction

&AtClient
Procedure NotifyAboutSettlementAccountChange()
	
	ParameterStructure = New Structure(
		"GLAccount",
		GLAccount);
	
	Notify("GLAccountChangedPOSTerminals", ParameterStructure);
	
EndProcedure

#EndRegion
