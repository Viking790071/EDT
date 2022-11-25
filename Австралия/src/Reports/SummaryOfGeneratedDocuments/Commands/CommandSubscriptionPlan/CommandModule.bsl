
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = GetFormParameters(CommandParameter);
	
	FormParameters.Insert("PurposeUseKey", "SummaryOfGeneratedDocumentsBySubscriptionPlan");
	
	ValueListPlan = New ValueList;
	
	ValueListPlan.Add(CommandParameter);
	
	StructureFilter = New Structure("SubscriptionPlan", ValueListPlan);
	
	FormParameters.Insert("Filter", StructureFilter);
		
	OpenForm("Report.SummaryOfGeneratedDocuments.Form", 
		FormParameters, 
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
		
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetFormParameters(CommandParameter)
	
	Return New Structure("VariantKey", GetVariantKey(CommandParameter));
	
EndFunction

&AtServer
Function GetVariantKey(CommandParameter)
	
	Result = "Customer";
		
	StringTypeOfDocument = Common.ObjectAttributeValue(CommandParameter, "TypeOfDocument");
		
	If StringTypeOfDocument = "SupplierInvoice"
		Or StringTypeOfDocument = "PurchaseOrder"  Then
		
		Result = "Supplier";
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion

