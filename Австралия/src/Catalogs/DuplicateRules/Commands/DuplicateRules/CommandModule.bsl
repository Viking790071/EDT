
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	StructureFilter = New Structure();
	If TypeOf(CommandExecuteParameters.Source) = Type("ClientApplicationForm") Then
		CommandFormName = CommandExecuteParameters.Source.FormName;
		StructureFilter.Insert("TypeOfNewObject", TypeOfParameter(CommandFormName));
	EndIf;
	ParameterStructure = New Structure("Filter", StructureFilter);

	OpenForm("Catalog.DuplicateRules.ListForm",
		ParameterStructure,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function TypeOfParameter(CommandFormName)
	
	FilerParameter = Enums.DuplicateObjectsTypes.EmptyRef();
	
	If StrFind(CommandFormName, ".Leads.") Then
		FilerParameter = Enums.DuplicateObjectsTypes.Leads;
	ElsIf StrFind(CommandFormName, ".Counterparties.") Then
		FilerParameter = Enums.DuplicateObjectsTypes.Counterparties;
	ElsIf StrFind(CommandFormName, ".ContactPersons.") Then
		FilerParameter = Enums.DuplicateObjectsTypes.ContactPersons;
	ElsIf StrFind(CommandFormName, ".Products.") Then
		FilerParameter = Enums.DuplicateObjectsTypes.Products;
	EndIf;
	
	Return FilerParameter;
	
EndFunction


#EndRegion


