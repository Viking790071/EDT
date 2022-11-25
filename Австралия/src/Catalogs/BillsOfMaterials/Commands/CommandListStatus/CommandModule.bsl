#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If DriveClient.ReadAttributeValue_IsFolder(CommandParameter) Then
		Return;
	EndIf;
	
	FormParameters = New Structure("Filter", New Structure("Owner",CommandParameter));
	OpenForm("Catalog.BillsOfMaterials.Form.ListForm", 
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion
