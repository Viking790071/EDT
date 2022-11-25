#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	ProductionTasksArray = New Array;
	Parameters.Property("ProductionTasks", ProductionTasksArray);
	
	If TypeOf(ProductionTasksArray) = Type("Array") Then
		ProductionTasks.LoadValues(ProductionTasksArray);
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If ProductionTasks.Count() = 0 Then
		Close();
	EndIf;
	
	If NoTasksCanBeSuspended(ProductionTasks) Then
		
		Raise NStr("en = 'Cannot set status ""Suspended"" for production tasks.  The status can be changed to ""Suspended"" only for posted production tasks with status ""In progress"".'; ru = 'Невозможно установить статус ""Приостановлена"" для производственных задач. Статус может быть изменен на ""Приостановлена"" только для проведенных производственных задач со статусом ""В работе"".';pl = 'Nie można zmienić statusu ""Zawieszone"" dla zadań produkcyjnych.  Status można zmienić na ""Zawieszone"" tylko dla zatwierdzonych zadań produkcyjnych o statusie ""W toku"".';es_ES = 'No se puede establecer el estado ""Suspendido"" para las tareas de producción.  El estado se puede cambiar a ""Suspendido"" sólo para las tareas de producción enviadas con el estado ""En progreso"".';es_CO = 'No se puede establecer el estado ""Suspendido"" para las tareas de producción.  El estado se puede cambiar a ""Suspendido"" sólo para las tareas de producción enviadas con el estado ""En progreso"".';tr = 'Üretim görevi  için durum ""Ertelendi"" olarak ayarlanamıyor. Sadece durumu ""İşlemde"" olan ve kaydedilen üretim görevlerinin durumu ""Ertelendi"" olarak değiştirilebilir.';it = 'Impossibile impostare lo stato ""Sospeso"" per gli incarichi di produzione. È possibile modificare lo stato in ""Sospeso"" solo per gli incarichi di produzione pubblicati con stato ""In lavorazione"".';de = 'Der Status ""Suspendiert"" für die Produktionsaufgaben kann nicht gesetzt werden. Der Status kann nur bei gebuchten Produktionsaufgaben mit dem Status ""In Bearbeitung"" geändert werden.'");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ChangeStatus(Command)
	
	If ValueIsFilled(SuspendReason) Then
		
		ProductionTasksArray = ProductionTasks.UnloadValues();
		
		NotChanged = ChangeStatusAtServer(ProductionTasksArray, SuspendReason, Comment);
		
		If NotChanged > 0 Then
			ShowUserNotification(NStr("en = 'Not all tasks were changed.'; ru = 'Изменены не все задачи.';pl = 'Nie wszystkie zadania zostały zmienione.';es_ES = 'No se han modificado todas las tareas.';es_CO = 'No se han modificado todas las tareas.';tr = 'Tüm görevler değiştirilmedi.';it = 'Non tutti gli incarichi sono stati modificati.';de = 'Nicht alle Aufgaben sind geändert.'"));
		EndIf;
		
		Notify("ProductionTaskStatuseChanged", ProductionTasksArray);
		
		If NotChanged = 0 Then
			Close();
		EndIf;
		
	Else
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot change this status. The suspension reason is required.'; ru = 'Не удается изменить этот статус. Требуется указать причину приостановки.';pl = 'Nie można zmienić statusu. Wymagany jest powód zawieszenia.';es_ES = 'No se puede cambiar este estado. Se requiere la razón de la suspensión.';es_CO = 'No se puede cambiar este estado. Se requiere la razón de la suspensión.';tr = 'Bu durum değiştirilemiyor. Erteleme sebebi gerekli.';it = 'Impossibile modificare questo stato. È richiesto il motivo di sospensione.';de = 'Dieser Status kann nicht geändert werden. Der Grund der Suspendierung ist erforderlich.'"),,
			"SuspendReason");
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function ChangeStatusAtServer(ProductionTasks, SuspendReason, Comment)
	
	Quantity = ProductionTasks.Count();
	
	For Each ProductionTask In ProductionTasks Do
		
		Changed = InformationRegisters.ProductionTaskStatuses.SetProductionTaskStatus(
			ProductionTask,
			Enums.ProductionTaskStatuses.Suspended,
			SuspendReason,
			Comment);
		
		If Changed Then
			Quantity = Quantity - 1;
		EndIf;
		
	EndDo;
	
	Return Quantity;
	
EndFunction

&AtServerNoContext
Function NoTasksCanBeSuspended(ProductionTasks)
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProductionTask.Ref AS Ref
		|FROM
		|	Document.ProductionTask AS ProductionTask
		|WHERE
		|	ProductionTask.Ref IN(&ProductionTasks)
		|	AND (NOT ProductionTask.Posted
		|			OR ProductionTask.Status <> VALUE(Enum.ProductionTaskStatuses.InProgress))";
	
	Query.SetParameter("ProductionTasks", ProductionTasks);
	
	QueryResult = Query.Execute().Unload();
	
	Return (QueryResult.Count() = ProductionTasks.Count());
	
EndFunction

#EndRegion





