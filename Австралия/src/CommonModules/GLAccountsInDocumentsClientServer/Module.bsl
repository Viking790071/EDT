
#Region Public

Function GetCounterpartyGLAccountsStrucutre(DocObject) Export

	CounterpartyGLAccounts = New Structure;
	
	If DocObject.Property("AccountsReceivableGLAccount") Then 
		CounterpartyGLAccounts.Insert("AccountsReceivableGLAccount", DocObject.AccountsReceivableGLAccount);
	EndIf;
	
	If DocObject.Property("AdvancesReceivedGLAccount") Then 
		CounterpartyGLAccounts.Insert("AdvancesReceivedGLAccount", DocObject.AdvancesReceivedGLAccount);
	EndIf;
	
	If DocObject.Property("AccountsPayableGLAccount") Then 
		CounterpartyGLAccounts.Insert("AccountsPayableGLAccount", DocObject.AccountsPayableGLAccount);
	EndIf;
	
	If DocObject.Property("AdvancesPaidGLAccount") Then 
		CounterpartyGLAccounts.Insert("AdvancesPaidGLAccount", DocObject.AdvancesPaidGLAccount);
	EndIf;
	
	If DocObject.Property("DiscountAllowedGLAccount") Then 
		CounterpartyGLAccounts.Insert("DiscountAllowedGLAccount", DocObject.DiscountAllowedGLAccount);
	EndIf;
	
	If DocObject.Property("DiscountReceivedGLAccount") Then 
		CounterpartyGLAccounts.Insert("DiscountReceivedGLAccount", DocObject.DiscountReceivedGLAccount);
	EndIf;
	
	If DocObject.Property("ThirdPartyPayerGLAccount") Then 
		CounterpartyGLAccounts.Insert("ThirdPartyPayerGLAccount", DocObject.ThirdPartyPayerGLAccount);
	EndIf;
	
	Return CounterpartyGLAccounts;
	
EndFunction

Function GetEmptyGLAccountPresentation() Export
	Return "<...>";
EndFunction

Function GetDisabledGLAccountPresentation() Export
	Return NStr("en = '<Inapplicable>'; ru = '<Неприменимо>';pl = '<Nie dotyczy>';es_ES = '<Inaplicable>';es_CO = '<Inaplicable>';tr = '<Uygulanamaz>';it = '<Non applicabile>';de = '<Nicht verwendbar>'");
EndFunction

#EndRegion
