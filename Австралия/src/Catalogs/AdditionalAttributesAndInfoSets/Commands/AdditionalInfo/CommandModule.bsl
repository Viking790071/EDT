#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure;
	FormParameters.Insert("ShowAdditionalInfo");
	OpenForm("Catalog.AdditionalAttributesAndInfoSets.ListForm",
		FormParameters,
		CommandExecuteParameters.Source,
		"AdditionalInfo",
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
EndProcedure

#EndRegion