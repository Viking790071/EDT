
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.Key.IsEmpty() Then
		IsNewRecord = True;
		Items.LatestUpdatedItemDate.ReadOnly = True;
		Items.UniqueKey.ReadOnly = True;
		Items.RegisterRecordChangeDate.ReadOnly = True;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Not IsNewRecord Then
		Return;
	EndIf;
	
	CurrentObject.LatestUpdatedItemDate = AccessManagementInternal.MaxDate();
	CurrentObject.UniqueKey = New UUID;
	CurrentObject.RegisterRecordChangeDate = CurrentSessionDate();
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	IsNewRecord = False;
	
	Items.LatestUpdatedItemDate.ReadOnly = False;
	Items.UniqueKey.ReadOnly = False;
	Items.RegisterRecordChangeDate.ReadOnly = False;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure EnableEditing(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion
