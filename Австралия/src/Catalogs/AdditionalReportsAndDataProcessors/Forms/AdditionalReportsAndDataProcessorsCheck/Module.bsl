#Region FormCommandHandlers

&AtClient
Procedure GoToList(Command)
	Close();
	
	Filters = New Structure;
	Filters.Insert("Publication", PredefinedValue("Enum.AdditionalReportsAndDataProcessorsPublicationOptions.Used"));
	Filters.Insert("DeletionMark", False);
	Filters.Insert("IsFolder", False);
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", Filters);
	FormParameters.Insert("Representation", "List");
	FormParameters.Insert("AdditionalReportsAndDataProcessorsCheck", True);
	
	OpenForm("Catalog.AdditionalReportsAndDataProcessors.Form.ListForm", FormParameters);
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
	
	ArrayVersion  = StrSplit(Metadata.Version, ".", False);
	CurrentVersion = ArrayVersion[0] + ArrayVersion[1] + ArrayVersion[2];
	CommonSettingsStorage.Save("ToDoList", "AdditionalReportsAndDataProcessors", CurrentVersion);
	
EndProcedure

#EndRegion