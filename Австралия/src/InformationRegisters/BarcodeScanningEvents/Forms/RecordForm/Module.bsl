
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	FillPropertyValues(Record, Parameters.FillingValues);
	If Parameters.FillingValues.Property("Action") Then
		Items.Action.Visible = False;
	EndIf;
	If ValueIsFilled(Record.Action) Then
		Record.DocumentType = DocumentType(Record.Action);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ActionOnChange(Item)
	Record.DocumentType = DocumentType(Record.Action);
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function DocumentType(Action)
	Return Common.ObjectAttributeValue(Action, "DocumentType");
EndFunction

#EndRegion