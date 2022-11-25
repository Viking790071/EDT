
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CallParameters = New Structure("Source, Window, URL");
	FillPropertyValues(CallParameters, CommandExecuteParameters);
	CallParameters.Insert("Uniqueness", "Panel_Purchases");
	ReportsOptionsClient.ShowReportBar("Purchases", CallParameters);
	
EndProcedure
