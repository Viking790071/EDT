
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetVisibleAndEnabled(Record.Ind.IsEmpty());
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetVisibleAndEnabled(NewObject)
	
	CommonClientServer.SetFormItemProperty(Items, "Ind", "Enabled", NewObject);
	
EndProcedure

#EndRegion