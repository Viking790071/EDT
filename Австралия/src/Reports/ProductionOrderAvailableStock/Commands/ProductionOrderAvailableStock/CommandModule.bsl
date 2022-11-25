#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ProductionOrderAttributes = ProductionOrderAttributes(CommandParameter);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("ProductionOrder", CommandParameter);
	
	If ProductionOrderAttributes.OperationKind <> PredefinedValue("Enum.OperationTypesProductionOrder.Production") Then
		
		FilterStructure.Insert("ComponentsSourceFilter", "BOM");
		
	EndIf;
	
	FormParameters = New Structure(
		"VariantKey, Filter, GenerateOnOpen, ReportOptionsCommandsVisibility",
		"ProductionOrderAvailableStock",
		FilterStructure,
		True,
		True);
	
	OpenForm("Report.ProductionOrderAvailableStock.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ProductionOrderAttributes(ProductionOrder)
	
	ProductionOrderAttributes = Common.ObjectAttributesValues(ProductionOrder, "OperationKind, Company");
	
	Return ProductionOrderAttributes;
	
EndFunction

#EndRegion