&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	Filter = New Structure("ObjectDestination", CommandParameter);
	FormParameters = New Structure("Filter, OpenFromFormMode", Filter, True);
	OpenForm("InformationRegister.AdditionalDataProcessorsPurposes.ListForm", FormParameters, CommandExecuteParameters.Source, CommandExecuteParameters.Uniqueness, CommandExecuteParameters.Window);
EndProcedure
