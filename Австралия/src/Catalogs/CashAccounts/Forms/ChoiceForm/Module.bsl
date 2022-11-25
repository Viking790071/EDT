#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ExcludeCurrency") Then
		
		DriveClientServer.SetListFilterItem(List, "CurrencyByDefault", Parameters.ExcludeCurrency, True, DataCompositionComparisonType.NotEqual);
		
	EndIf;
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
