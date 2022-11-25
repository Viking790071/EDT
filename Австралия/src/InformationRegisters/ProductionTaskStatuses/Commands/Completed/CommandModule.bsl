#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	NotChanged = ChangeStatusAtServer(CommandParameter);
	
	If NotChanged > 0 Then
		ShowUserNotification(NStr("en = 'Not all tasks were changed.'; ru = 'Изменены не все задачи.';pl = 'Nie wszystkie zadania zostały zmienione.';es_ES = 'No se han modificado todas las tareas.';es_CO = 'No se han modificado todas las tareas.';tr = 'Tüm görevler değiştirilmedi.';it = 'Non tutti gli incarichi sono stati modificati.';de = 'Nicht alle Aufgaben sind geändert.'"));
	EndIf;
	
	Notify("ProductionTaskStatuseChanged", CommandParameter);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ChangeStatusAtServer(ProductionTasks)
	
	Quantity = ProductionTasks.Count();
	
	For Each ProductionTask In ProductionTasks Do
		
		Changed = InformationRegisters.ProductionTaskStatuses.SetProductionTaskStatus(
			ProductionTask,
			Enums.ProductionTaskStatuses.Completed);
		
		If Changed Then
			Quantity = Quantity - 1;
		EndIf;
		
	EndDo;
	
	Return Quantity;
	
EndFunction

#EndRegion