#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

// Returns a group for to-dos not included in commanded interface sections.
//
Function FullName() Export
	
	Settings = New Structure;
	Settings.Insert("OtherUserTasksTitle");
	ToDoListOverridable.OnDefineSettings(Settings);
	If ValueIsFilled(Settings.OtherUserTasksTitle) Then
		OtherUserTasksTitle = Settings.OtherUserTasksTitle;
	Else
		OtherUserTasksTitle = NStr("ru = 'Прочие дела'; en = 'Other to-dos'; pl = 'Inne zadania';es_ES = 'Otros asuntos';es_CO = 'Otros asuntos';tr = 'Diğer yapılacak işler';it = 'Altri impegni';de = 'Sonstige Aufgaben'");
	EndIf;
	
	Return OtherUserTasksTitle;
EndFunction

#EndRegion

#EndIf