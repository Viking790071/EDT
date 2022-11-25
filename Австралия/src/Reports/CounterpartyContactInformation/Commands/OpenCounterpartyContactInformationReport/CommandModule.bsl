
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FilterStructure = New Structure("Counterparty", CommandParameter);
	
	FormParameters = New Structure("VariantKey, Filter, GenerateOnOpen", "CounterpartyContactInformation", FilterStructure, True);
	
	If CommandExecuteParameters.Window = Undefined Then
		FormParameters.Insert("OpeningMode", FormWindowOpeningMode.LockOwnerWindow);
	EndIf;
	
	OpenForm("Report.CounterpartyContactInformation.Form", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
	
EndProcedure
