///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	OpenForm(
		"Task.PerformerTask.ListForm",
		New Structure("FormCaption", NStr("ru = 'Все задачи'; en = 'All tasks'; pl = 'Wszystkie zadania';es_ES = 'Todas las tareas';es_CO = 'Todas las tareas';tr = 'Tüm görevler';it = 'Tutti gli incarichi';de = 'Alle Aufgaben'")),
		CommandExecuteParameters.Source, 
		CommandExecuteParameters.Uniqueness, 
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion