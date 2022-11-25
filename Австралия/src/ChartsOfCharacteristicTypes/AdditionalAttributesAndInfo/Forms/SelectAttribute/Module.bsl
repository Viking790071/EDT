#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	AttributesTable = GetFromTempStorage(Parameters.ObjectAttributes);
	ValueToFormAttribute(AttributesTable, "ObjectAttributes");
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		CommonClientServer.SetFormItemProperty(Items, "FormCancelCommand", "Visible", False);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure SelectCommand(Command)
	SelectItemAndClose();
EndProcedure

&AtClient
Procedure CancelCommand(Command)
	Close();
EndProcedure

&AtClient
Procedure ObjectAttributesSelection(Item, RowSelected, Field, StandardProcessing)
	SelectItemAndClose();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure SelectItemAndClose()
	SelectedRow = Items.ObjectAttributes.CurrentData;
	ChoiceParameters = New Structure;
	ChoiceParameters.Insert("Attribute", SelectedRow.Attribute);
	ChoiceParameters.Insert("Presentation", SelectedRow.Presentation);
	ChoiceParameters.Insert("ValueType", SelectedRow.ValueType);
	ChoiceParameters.Insert("ChoiceMode", SelectedRow.ChoiceMode);
	
	Notify("Properties_ObjectAttributeSelection", ChoiceParameters);
	
	Close();
EndProcedure

#EndRegion