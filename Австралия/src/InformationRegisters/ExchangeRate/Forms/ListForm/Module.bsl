
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Equal 		= DataCompositionComparisonType.Equal;
	ViewMode 	= DataCompositionSettingsItemViewMode.QuickAccess;
	
	If Parameters.Property("Currency") Then
		CommonClientServer.SetDynamicListFilterItem(List, "Currency", Parameters.Currency, Equal,, True, ViewMode);
	EndIf;
	
	If Parameters.Property("Company") Then
		CommonClientServer.SetDynamicListFilterItem(List, "Company", Parameters.Company, Equal,, True, ViewMode);
	EndIf;
	
EndProcedure
