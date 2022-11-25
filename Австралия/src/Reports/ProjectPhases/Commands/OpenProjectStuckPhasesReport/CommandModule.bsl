#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Filter = New Structure;
	Filter.Insert("Project", CommandParameter);
	
	Company = GetProjectCompany(CommandParameter);
	If ValueIsFilled(Company) Then
		Filter.Insert("Company", Company);
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "StuckPhases");
	FormParameters.Insert("Filter", Filter);
	FormParameters.Insert("GenerateOnOpen", True);
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);
	
	OpenForm("Report.ProjectPhases.Form",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GetProjectCompany(ProjectRef)
	
	If ValueIsFilled(ProjectRef) And TypeOf(ProjectRef) = Type("CatalogRef.Projects") Then
		Return Common.ObjectAttributeValue(ProjectRef, "Company");
	Else
		Return Catalogs.Companies.EmptyRef();
	EndIf;
	
EndFunction

#EndRegion