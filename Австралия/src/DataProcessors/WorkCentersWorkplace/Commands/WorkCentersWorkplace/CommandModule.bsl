#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If UseProductionPlanning() Then
		
		OpenForm("DataProcessor.WorkCentersWorkplace.Form",
			,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	Else
		
		OpenForm("Catalog.CompanyResources.ListForm",
			,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function UseProductionPlanning()
	
	Return Constants.UseProductionPlanning.Get();
	
EndFunction

#EndRegion
