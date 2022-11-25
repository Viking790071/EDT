
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("ValueList") Then
		ValueList = Parameters.ValueList;		
	EndIf;
	
	If Parameters.Property("Title") Then
		Title = Parameters.Title;		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Select(Command)
	Close(ValueList);
EndProcedure

#EndRegion

