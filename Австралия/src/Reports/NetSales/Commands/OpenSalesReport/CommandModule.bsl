
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructureKey = ?(TypeOf(CommandParameter) = Type("CatalogRef.Products"), "Products", "Counterparty");
	FilterStructure	= New Structure(FilterStructureKey, CommandParameter);
	
	FormParameters = New Structure;
	
	FormParameters.Insert("VariantKey", "SalesContext");
	FormParameters.Insert("PurposeUseKey", FilterStructureKey);
	FormParameters.Insert("Filter", FilterStructure);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);
	
	OpenForm("Report.NetSales.Form",
		FormParameters,
		,
		CommandParameter,
		CommandExecuteParameters.Window);
	
EndProcedure
