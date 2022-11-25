#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure("ArrayOfWorkOrders", CommandParameter);
	
	OpenForm("Document.PurchaseOrder.ObjectForm",
		New Structure("Basis", FillStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion
