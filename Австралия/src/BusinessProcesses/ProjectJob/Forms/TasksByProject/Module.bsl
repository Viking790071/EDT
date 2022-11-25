
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	Items.DueDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	Items.CompletionDate.Format = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_PerformerTask" Or EventName = "BusinessProcessStarted" Then
		RefreshTasksListOnServer();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Clone, Parent, Folder)
	
	BusinessProcessesAndTasksClient.TaskListBeforeAddRow(ThisObject, Item, Cancel, Clone, Parent, Folder);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	If Item.CurrentData <> Undefined
		And Item.CurrentData.Property("AcceptedForExecution")
		And Not Item.CurrentData.AcceptedForExecution Then
		Items.AcceptForExecution.Enabled = True;
	Else
		Items.AcceptForExecution.Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure AcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.AcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure CancelAcceptForExecution(Command)
	
	BusinessProcessesAndTasksClient.CancelAcceptTasksForExecution(Items.List.SelectedRows);
	
EndProcedure

&AtClient
Procedure RefreshTasksList(Command)
	
	RefreshTasksListOnServer();
	
EndProcedure

&AtClient
Procedure OpenBusinessProcess(Command)
	
	If Items.List.CurrentData.BusinessProcess = Undefined Then
		CommonClientServer.MessageToUser(NStr("en = 'Business process of the selected task is not specified.'; ru = 'У выбранной задачи не указан бизнес-процесс.';pl = 'Proces biznesowy wybranego zadania nie jest określony.';es_ES = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';es_CO = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';tr = 'Seçilen görevin iş süreci belirtilmedi.';it = 'Nel compito selezionato non è indicato nessun processo aziendale.';de = 'Geschäftsprozess der ausgewählten Aufgabe ist nicht angegeben.'"));
		Return;
	EndIf;
	
	ShowValue(, Items.List.CurrentData.BusinessProcess);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure SetConditionalAppearance()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
EndProcedure

&AtServer
Procedure RefreshTasksListOnServer()
	
	BusinessProcessesAndTasksServer.SetTaskAppearance(List);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion
