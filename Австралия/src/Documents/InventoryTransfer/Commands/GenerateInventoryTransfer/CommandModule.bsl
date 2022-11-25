#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("Basis", CommandParameter);
	
	OpenForm("Document.InventoryTransfer.ObjectForm", FormParameters);
	
EndProcedure

#EndRegion
