#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Parameters.Property("ArrayOfValues") Then // Return if there are no attributes with the date type.
		Return;
	EndIf;
	
	HasOnlyOneAttribute = Parameters.ArrayOfValues.Count() = 1;
	
	For Each Attribute In Parameters.ArrayOfValues Do
		Items.DateTypeAttribute.ChoiceList.Add(Attribute.Value, Attribute.Presentation);
		If HasOnlyOneAttribute Then
			DateTypeAttribute = Attribute.Value;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OK(Command)
	
	ResultingStructure = New Structure();
	ResultingStructure.Insert("IntervalException", IntervalException);
	ResultingStructure.Insert("DateTypeAttribute", DateTypeAttribute);
	
	NotifyChoice(ResultingStructure);

EndProcedure

#EndRegion