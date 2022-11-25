#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	FormParameters = New Structure("ImportOnly");
	OpenForm("DataProcessor.ExportImportEnterpriseData.Form",
		FormParameters, ,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
EndProcedure

#EndRegion