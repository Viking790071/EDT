#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTests") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	CurrentFilter = Parameters.CurrentFilter;
	DataSeparationMap = New Map;
	If CurrentFilter.Count() > 0 Then
		
		For Each SessionSeparator In CurrentFilter Do
			DataSeparationArray = StrSplit(SessionSeparator.Value, "=", False);
			DataSeparationMap.Insert(DataSeparationArray[0], DataSeparationArray[1]);
		EndDo;
		
	EndIf;
	
	For Each CommonAttribute In Metadata.CommonAttributes Do
		TableRow = SessionDataSeparation.Add();
		TableRow.Separator = CommonAttribute.Name;
		TableRow.SeparatorPresentation = CommonAttribute.Synonym;
		SeparatorValue = DataSeparationMap[CommonAttribute.Name];
		If SeparatorValue <> Undefined Then
			TableRow.CheckBox = True;
			TableRow.SeparatorValue = DataSeparationMap[CommonAttribute.Name];
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OkCommand(Command)
	Result = New ValueList;
	For Each TableRow In SessionDataSeparation Do
		If TableRow.CheckBox Then
			SeparatorValue = TableRow.Separator + "=" + TableRow.SeparatorValue;
			SeparatorPresentation = TableRow.SeparatorPresentation + " = " + TableRow.SeparatorValue;
			Result.Add(SeparatorValue, SeparatorPresentation);
		EndIf;
	EndDo;
	
	Notify("EventLogFilterItemValueChoice",
		Result,
		FormOwner);
	
	Close();
EndProcedure

&AtClient
Procedure SelectAll(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = True;
	EndDo;
EndProcedure

&AtClient
Procedure ClearAll(Command)
	For Each ListItem In SessionDataSeparation Do
		ListItem.CheckBox = False;
	EndDo;
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

#EndRegion