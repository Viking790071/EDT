
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	DocParameters = New Structure;
	DocParameters.Insert("SalesOrder", CommandParameter);
	
	OpenForm("Document.KitOrder.ObjectForm", New Structure("Basis", DocParameters));
	
EndProcedure

#EndRegion

