
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If PropertyManagerInternal.AdditionalPropertyUsed(Parameters.Ref) Then
		
		Items.UserDialogs.CurrentPage = Items.ObjectUsed;
		
		Items.AllowEditing.DefaultButton = True;
		
		If Parameters.IsAdditionalAttribute = True Then
			Items.Warnings.CurrentPage = Items.AdditionalAttributeWarning;
		Else
			Items.Warnings.CurrentPage = Items.AdditionalInfoWarning;
		EndIf;
		
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "PropertyUsed");
		Items.NoteButtons.Visible = False;
	Else
		Items.UserDialogs.CurrentPage = Items.ObjectNotUsed;
		Items.ObjectUsed.Visible = False; // For compact form display.
		
		Items.OK.DefaultButton = True;
		
		If Parameters.IsAdditionalAttribute = True Then
			Items.Notes.CurrentPage = Items.AdditionalAttributeNote;
		Else
			Items.Notes.CurrentPage = Items.AdditionalInfoNote;
		EndIf;
		
		StandardSubsystemsServer.SetFormAssignmentKey(ThisObject, "PropertyNotUsed");
		Items.WarningButtons.Visible = False;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AllowEditing(Command)
	
	AttributesToUnlock = New Array;
	AttributesToUnlock.Add("ValueType");
	AttributesToUnlock.Add("Name");
	
	Close(AttributesToUnlock);
	
EndProcedure

#EndRegion
