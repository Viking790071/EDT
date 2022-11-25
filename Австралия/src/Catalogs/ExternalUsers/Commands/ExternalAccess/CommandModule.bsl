#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FormParameters = New Structure;
	FormParameters.Insert("AuthorizationObject", CommandParameter);
	
	Try
		OpenForm(
			"Catalog.ExternalUsers.ObjectForm",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window);
	Except
		ErrorInformation = ErrorInfo();
		If StrFind(DetailErrorDescription(ErrorInformation),
		         "Raise" + " " + "ErrorAsWarningDetails") > 0 Then
			
			ShowMessageBox(, BriefErrorDescription(ErrorInformation));
		Else
			Raise;
		EndIf;
	EndTry;
	
EndProcedure

#EndRegion
