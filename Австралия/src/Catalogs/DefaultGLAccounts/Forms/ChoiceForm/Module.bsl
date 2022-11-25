
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetListFilter();
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetListFilter()
	
	// Inactive functionality
	
	ListGLAccounts = New ValueList;
	ListGLAccounts.Add(Catalogs.DefaultGLAccounts.BankFeesCreditAccount);
	ListGLAccounts.Add(Catalogs.DefaultGLAccounts.CapitalIntroduction);
	
	CommonClientServer.SetDynamicListFilterItem(
		List,
		"Ref",
		ListGLAccounts,
		DataCompositionComparisonType.NotInList,
		,
		True);
	
EndProcedure

#EndRegion