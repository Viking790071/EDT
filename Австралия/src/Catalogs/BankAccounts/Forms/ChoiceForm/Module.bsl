#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExcludeCurrency") Then
		
		DriveClientServer.SetListFilterItem(List, "Owner", Parameters.Owner);
		DriveClientServer.SetListFilterItem(List, "CashCurrency", Parameters.ExcludeCurrency, True, DataCompositionComparisonType.NotEqual);
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion