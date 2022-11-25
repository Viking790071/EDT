
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	SourceOfParameters = CommandExecuteParameters.Source;
	
	If Not ValueIsFilled(SourceOfParameters.Company) Then
	
		Return;
	
	EndIf;
	
	StructureFilter = New Structure("Currency, Company", CommandParameter, SourceOfParameters.Company);
	OpenForm("InformationRegister.ExchangeRate.ListForm",
		StructureFilter,
		SourceOfParameters,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

