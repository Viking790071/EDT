#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CommandParameter = Undefined Then 
		Return;
	EndIf;
	
	FormParameters = New Structure("ObjectRef", CommandParameter);
	OpenForm("CommonForm.ObjectsRightsSettings", FormParameters, CommandExecuteParameters.Source);
	
EndProcedure

#EndRegion
