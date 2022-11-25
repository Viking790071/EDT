#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then 
		Return;
	EndIf;
	
	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	
	If ClientRunParameters.SimplifiedAccessRightsSetupInterface Then
		FormName = "CommonForm.AccessRightsSimplified";
	Else
		FormName = "CommonForm.AccessRights";
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("User", CommandParameter);
	
	OpenForm(
		FormName,
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion
