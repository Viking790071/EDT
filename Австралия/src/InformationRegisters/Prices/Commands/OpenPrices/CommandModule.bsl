#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure	= New Structure("Products", CommandParameter);
	FormParameters	= New Structure("Filter", FilterStructure);
	
	OpenForm("InformationRegister.Prices.Form.ProductsForm",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion