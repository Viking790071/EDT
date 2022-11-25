///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If ValueIsFilled(Parameters.BusinessProcess) Then
		BusinessProcess = Parameters.BusinessProcess;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	UpdateFlowchart();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure BusinessProcessOnChange(Item)
	UpdateFlowchart();
EndProcedure

&AtClient
Procedure FlowchartChoice(Item)
	OpenRoutePointTasksList();
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RefreshExecute(Command)
	UpdateFlowchart();   
EndProcedure

&AtClient
Procedure TasksComplete(Command)
	OpenRoutePointTasksList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateFlowchart()
	
	If ValueIsFilled(BusinessProcess) Then
		Flowchart = BusinessProcess.GetObject().GetFlowchart();
	ElsIf BusinessProcess <> Undefined Then
		Flowchart = BusinessProcesses[BusinessProcess.Metadata().Name].GetFlowchart();
		Return;
	Else
		Flowchart = New GraphicalSchema;
		Return;
	EndIf;
	
	HasState = BusinessProcess.Metadata().Attributes.Find("State") <> Undefined;
	BusinessProcessProperties = Common.ObjectAttributesValues(
		BusinessProcess, "Author,Date,CompletedOn,Completed,Started" 
		+ ?(HasState, ",State", ""));
	FillPropertyValues(ThisObject, BusinessProcessProperties);
	If BusinessProcessProperties.Completed Then
		Status = NStr("ru = 'Завершенные'; en = 'Completed'; pl = 'Zakończono';es_ES = 'Finalizado';es_CO = 'Finalizado';tr = 'Tamamlandı';it = 'Completato';de = 'Abgeschlossen'");
		Items.StatusGroup.CurrentPage = Items.CompletedGroup;
	ElsIf BusinessProcessProperties.Started Then
		Status = NStr("ru = 'Начат'; en = 'Started'; pl = 'Rozpoczęto';es_ES = 'Inició';es_CO = 'Inició';tr = 'Başlatıldı';it = 'Iniziato';de = 'Begann'");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	Else	
		Status = NStr("ru = 'Не запускался'; en = 'Not started'; pl = 'Nie było wykonywane';es_ES = 'No se lanzaba';es_CO = 'No se lanzaba';tr = 'Başlatılmadı';it = 'Non avviato';de = 'Nicht gestartet'");
		Items.StatusGroup.CurrentPage = Items.NotCompletedGroup;
	EndIf;
	If HasState Then
		Status = Status + ", " + Lower(State);
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenRoutePointTasksList()

#If WebClient OR MobileClient Then
	ShowMessageBox(,NStr("ru = 'Для корректной работы необходим режим тонкого или толстого клиента.'; en = 'Thin or thick client mode is required.'; pl = 'Aby wszystko działało poprawnie, potrzebujesz cienkiego lub grubego trybu klienta.';es_ES = 'Para el funcionamiento correcto es necesario el modo del cliente ligero o grueso.';es_CO = 'Para el funcionamiento correcto es necesario el modo del cliente ligero o grueso.';tr = 'Doğu çalışma için ince veya kalın istemci modu gerekmektedir.';it = 'È richiesta la modalità thin o thick client.';de = 'Für den korrekten Betrieb ist der Thin- oder Thick-Client-Modus erforderlich.'"));
	Return;
#EndIf
	ClearMessages();
	CurItem = Items.Flowchart.CurrentItem;

	If Not ValueIsFilled(BusinessProcess) Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Необходимо указать бизнес-процесс.'; en = 'Specify the business process.'; pl = 'Określ proces biznesowy.';es_ES = 'Especificar el proceso de negocio.';es_CO = 'Especificar el proceso de negocio.';tr = 'İş sürecini belirtin.';it = 'È necessario specificare un processo aziendale.';de = 'Geschäftsprozess angeben.'"),,
			"BusinessProcess");
		Return;
	EndIf;
	
	If CurItem = Undefined 
		Or	NOT (TypeOf(CurItem) = Type("GraphicalSchemaItemActivity")
		Or TypeOf(CurItem) = Type("GraphicalSchemaItemSubBusinessProcess")) Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Для просмотра списка задач необходимо выбрать точку действия или вложенный бизнес-процесс карты маршрута.'; en = 'To view the task list, select an action point or a nested business process of the flowchart.'; pl = 'Aby obejrzeć listę zadań, wybierz punkt działania lub zagnieżdżony proces biznesowy schematu blokowego.';es_ES = 'Para ver la lista de tareas, seleccione un punto de acción o un proceso de negocio anidado en el diagrama de flujo.';es_CO = 'Para ver la lista de tareas, seleccione un punto de acción o un proceso de negocio anidado en el diagrama de flujo.';tr = 'Görev listesini görebilmek için, bir hareket noktası veya akış çizelgesinden gömülü bir iş süreci seçin.';it = 'Per visualizzare l''elenco dei task, è necessario selezionare una tappa d''azione o un processo aziendale incorporato della scheda di lavorazione.';de = 'Um die Aufgabenliste anzusehen, wählen Sie Aktion zur Erfüllung oder den nächsten Geschäftsprozess der Vorgangskarte aus.'"),,
			"Flowchart");
		Return;
	EndIf;

	FormHeader = NStr("ru = 'Задачи по точке маршрута бизнес-процесса'; en = 'Business process route point tasks'; pl = 'Zadania punktu trasy procesu biznesowego';es_ES = 'Tareas de puntos de ruta de procesos de negocios';es_CO = 'Tareas de puntos de ruta de procesos de negocios';tr = 'İş akışının rota noktalarına göre görevler';it = 'I task per la tappa di percorso del processo aziendale';de = 'Route-Point-Aufgaben des Geschäftsprozesses'");
	
	FormParameters = New Structure;
	FormParameters.Insert("Filter", New Structure("BusinessProcess,RoutePoint", BusinessProcess, CurItem.Value));
	FormParameters.Insert("FormCaption", FormHeader);
	FormParameters.Insert("ShowTasks", 0);
	FormParameters.Insert("FiltersVisibility", False);
	FormParameters.Insert("OwnerWindowLock", FormWindowOpeningMode.LockOwnerWindow);
	FormParameters.Insert("Task", String(CurItem.Value));
	FormParameters.Insert("BusinessProcess", String(BusinessProcess));
	OpenForm("Task.PerformerTask.ListForm", FormParameters, ThisObject, BusinessProcess);

EndProcedure

#EndRegion
