
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(List, 
		"Recipient", MessageExchangeInternal.ThisNode() );
EndProcedure

#EndRegion
