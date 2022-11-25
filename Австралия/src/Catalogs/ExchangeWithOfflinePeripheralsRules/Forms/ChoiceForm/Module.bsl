
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetFilterItem(List.Filter, "PeripheralsType", Parameters.PeripheralsType, DataCompositionComparisonType.Equal,, ValueIsFilled(Parameters.PeripheralsType));
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion