#Region FormCommandHandlers

&AtClient
Procedure GoToList(Command)
	FormParameters = New Structure;
	FormParameters.Insert("ExchangePlansWithRulesFromFile", True);
	
	OpenForm("InformationRegister.DataExchangeRules.Form.ListForm", FormParameters);
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
	CommonSettingsStorage.Save("ToDoList", "ExchangePlans", CurrentVersion);
	
EndProcedure

#EndRegion