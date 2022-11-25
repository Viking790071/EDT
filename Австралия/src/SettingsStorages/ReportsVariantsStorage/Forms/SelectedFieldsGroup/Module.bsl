#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	Parameters.Property("GroupTitle", GroupTitle);
	
	Location = Undefined;
	If Not Parameters.Property("Placement", Location) Then
		Raise NStr("ru = 'Service parameter ""Location"" is not transferred.'; en = 'Service parameter ""Location"" is not transferred.'; pl = 'Service parameter ""Location"" is not transferred.';es_ES = 'Service parameter ""Location"" is not transferred.';es_CO = 'Service parameter ""Location"" is not transferred.';tr = 'Service parameter ""Location"" is not transferred.';it = 'Service parameter ""Location"" is not transferred.';de = 'Service parameter ""Location"" is not transferred.'");
	EndIf;
	If Location = DataCompositionFieldPlacement.Auto Then
		GroupPlacement = "Auto";
	ElsIf Location = DataCompositionFieldPlacement.Vertically Then
		GroupPlacement = "Vertically";
	ElsIf Location = DataCompositionFieldPlacement.Together Then
		GroupPlacement = "Together";
	ElsIf Location = DataCompositionFieldPlacement.Horizontally Then
		GroupPlacement = "Horizontally";
	ElsIf Location = DataCompositionFieldPlacement.SpecialColumn Then
		GroupPlacement = "SpecialColumn";
	Else
		Raise StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Incorrect value of parameter ""Location"": ""%1"".'; en = 'Incorrect value of parameter ""Location"": ""%1"".'; pl = 'Incorrect value of parameter ""Location"": ""%1"".';es_ES = 'Incorrect value of parameter ""Location"": ""%1"".';es_CO = 'Incorrect value of parameter ""Location"": ""%1"".';tr = 'Incorrect value of parameter ""Location"": ""%1"".';it = 'Incorrect value of parameter ""Location"": ""%1"".';de = 'Incorrect value of parameter ""Location"": ""%1"".'"), String(Location));
	EndIf;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	SelectAndClose();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectAndClose()
	SelectionResult = New Structure;
	SelectionResult.Insert("GroupTitle", GroupTitle);
	SelectionResult.Insert("Placement", DataCompositionFieldPlacement[GroupPlacement]);
	NotifyChoice(SelectionResult);
	If IsOpen() Then
		Close(SelectionResult);
	EndIf;
EndProcedure

#EndRegion