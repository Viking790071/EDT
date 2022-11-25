
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	CommonClientServer.SetDynamicListFilterItem(List, "IsFolder", True);
	
EndProcedure

#EndRegion
