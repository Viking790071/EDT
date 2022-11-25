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
	
	If CommandParameter = Undefined Then
		ShowMessageBox(,NStr("ru = 'Не выбраны задачи.'; en = 'Tasks are not selected.'; pl = 'Nie wybrano zadań.';es_ES = 'Las tareas no están seleccionadas';es_CO = 'Las tareas no están seleccionadas';tr = 'Görevler seçilmedi.';it = 'Obiettivi non selezionati.';de = 'Aufgaben sind nicht ausgewählt.'"));
		Return;
	EndIf;
		
	ClearMessages();
	For Each Task In CommandParameter Do
		BusinessProcessesAndTasksServerCall.ExecuteTask(Task, True);
		ShowUserNotification(
			NStr("ru = 'Задача выполнена'; en = 'The task is completed'; pl = 'Zadanie jest zakończone';es_ES = 'La tarea se ha completado';es_CO = 'La tarea se ha completado';tr = 'Görev tamamlandı';it = 'L''incarico è stato completato';de = 'Die Aufgabe ist erfüllt'"),
			GetURL(Task),
			String(Task));
	EndDo;
	Notify("Write_PerformerTask", New Structure("Executed", True), CommandParameter);
	
EndProcedure

#EndRegion