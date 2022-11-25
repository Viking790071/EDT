#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ArrayOfSalesOrders = New Array;
	ArrayOfSalesOrders.Add(CommandParameter);
	
	FillStructure = New Structure("ArrayOfSalesOrders, DropShipping", ArrayOfSalesOrders, True);
	
	OpenForm(
		"Document.GoodsIssue.ObjectForm",
		New Structure("Basis", FillStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion