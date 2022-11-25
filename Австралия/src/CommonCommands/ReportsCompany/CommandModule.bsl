
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window, URL");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Enterprise");
	ReportsOptionsClient.ShowReportBar("Enterprise", CallParameters);
	
EndProcedure
