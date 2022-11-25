#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Ref = CommandParameter[0];
	
	ParametersStructure	= New Structure("VariantKey, PurposeUseKey, GenerateOnOpen", "Default", Ref, True);
	FilterStructure		= New Structure("SupplierInvoice", Ref);
	
	ParametersStructure.Insert("Filter", FilterStructure);
	
	OpenForm("Report.GoodsInvoicedNotReceived.Form",
		ParametersStructure,
		,
		"SupplierInvoice=" + Ref,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion