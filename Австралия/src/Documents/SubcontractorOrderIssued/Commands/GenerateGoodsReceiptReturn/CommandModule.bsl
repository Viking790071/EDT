#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	BasisStructure = New Structure;
	BasisStructure.Insert("SubcontractorOrderRef", CommandParameter);
	BasisStructure.Insert("OperationType", PredefinedValue("Enum.OperationTypesGoodsReceipt.ReturnFromSubcontractor"));
	
	OpenForm("Document.GoodsReceipt.ObjectForm",
		New Structure("Basis", BasisStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion
