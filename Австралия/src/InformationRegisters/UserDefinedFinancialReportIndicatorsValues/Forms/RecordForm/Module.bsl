
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Record.SourceRecordKey.IsEmpty() Then
		Record.Author = Users.CurrentUser();
	EndIf;
	
EndProcedure

#EndRegion
