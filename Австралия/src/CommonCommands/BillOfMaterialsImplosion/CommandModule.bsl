#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If DriveClient.ReadAttributeValue_IsFolder(CommandParameter) Then
		Return;
	EndIf;

	FormParameters = New Structure("Products", CommandParameter);
	OpenForm(
		"Catalog.BillsOfMaterials.Form.BillsOfMaterialsImplosion",
		FormParameters,
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

#EndRegion
