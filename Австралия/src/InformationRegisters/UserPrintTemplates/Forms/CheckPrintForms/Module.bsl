#Region FormCommandHandlers

&AtClient
Procedure GoToList(Command)
	Close();
	
	FormParameters = New Structure;
	FormParameters.Insert("ShowOnlyUserChanges", True);
	
	OpenForm("InformationRegister.UserPrintTemplates.Form.PrintFormTemplates", FormParameters);
EndProcedure

&AtClient
Procedure CloseForm(Command)
	Close();
EndProcedure

&AtClient
Procedure Verified(Command)
	MarkUserTaskDone();
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure MarkUserTaskDone()
	
	ArrayVersion  = StrSplit(Metadata.Version, ".");
	CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
	CommonSettingsStorage.Save("ToDoList", "PrintForms", CurrentVersion);
	
EndProcedure

#EndRegion