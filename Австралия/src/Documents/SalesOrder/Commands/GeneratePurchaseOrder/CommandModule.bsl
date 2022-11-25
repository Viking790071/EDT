#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillStructure = New Structure("ArrayOfSalesOrders", CommandParameter);
	
	OpenForm("Document.PurchaseOrder.ObjectForm",
		New Structure("Basis", FillStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion
