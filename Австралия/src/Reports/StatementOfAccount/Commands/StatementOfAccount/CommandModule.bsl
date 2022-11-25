&AtServer
Function GetCounterpartiesArray(DocumentArray)
	
	CounterpartiesArray = New Array;
	For Each ArrayElement In DocumentArray Do
		
		CounterpartiesArray.Add(ArrayElement.Counterparty);
		
	EndDo;
	
	Return CounterpartiesArray;
	
EndFunction

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	CounterpartiesArray = GetCounterpartiesArray(CommandParameter);
	
	FormParameters = New Structure;
	FormParameters.Insert("VariantKey", "StatementBrieflyContext");
	FormParameters.Insert("UserSettingsKey", New UUID);
	FormParameters.Insert("Filter", New Structure("Counterparty", CounterpartiesArray));
	FormParameters.Insert("GenerateOnOpen", True); 
	FormParameters.Insert("ReportOptionsCommandsVisibility", False);

	OpenForm("Report.StatementOfAccount.Form",
		FormParameters,
		,
		"Counterparty=" + CounterpartiesArray,
		CommandExecuteParameters.Window);
	
EndProcedure
