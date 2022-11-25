///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

#Region ForCallsFromOtherSubsystems

// StandardSubsystems.AccessManagement

// See AccessManagement.FillAccessValuesSets. 
//
// Parameters:
//   Table - ValueTable - see AccessManagement.AccessValuesSetsTable. 
//
Procedure FillAccessValuesSets(Table) Export
	
	BusinessProcessesAndTasksOverridable.OnFillingAccessValuesSets(ThisObject, Table);
	
	If Table.Count() > 0 Then
		Return;
	EndIf;
	
	FillDefaultAccessValuesSets(Table);
	
EndProcedure

// End StandardSubsystems.AccessManagement

#EndRegion

#EndRegion

#Region EventHandlers

////////////////////////////////////////////////////////////////////////////////
// Business process event handlers.

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Author <> Undefined AND Not Author.IsEmpty() Then
		AuthorString = String(Author);
	EndIf;
	
	BusinessProcessesAndTasksServer.ValidateRightsToChangeBusinessProcessState(ThisObject);
	
	If ValueIsFilled(MainTask)
		AND Common.ObjectAttributeValue(MainTask, "BusinessProcess") = Ref Then
		
		Raise NStr("ru = 'Собственная задача бизнес-процесса не может быть указана как главная задача.'; en = 'Business process task cannot be specified as the main task.'; pl = 'Zadanie procesu biznesowego nie może być określone jako główne zadanie.';es_ES = 'La tarea del proceso de negocio no puede ser especificada como tarea principal.';es_CO = 'La tarea del proceso de negocio no puede ser especificada como tarea principal.';tr = 'İş süreci görevi ana görev olarak belirlenemez.';it = 'L''incarico di processo aziendale non può essere indicato come incarico principale.';de = 'Die Geschäftsprozessaufgabe kann als Hauptaufgabe nicht identifiziert sein.'");
		
	EndIf;
	
	SetPrivilegedMode(True);
	TaskPerformersGroup = ?(TypeOf(Performer) = Type("CatalogRef.PerformerRoles"),
		BusinessProcessesAndTasksServer.TaskPerformersGroup(Performer, MainAddressingObject, AdditionalAddressingObject),
		Performer);
	TaskPerformersGroupSupervisor = ?(TypeOf(Supervisor) = Type("CatalogRef.PerformerRoles"),
		BusinessProcessesAndTasksServer.TaskPerformersGroup(Supervisor, MainAddressingObjectSupervisor, AdditionalAddressingObjectSupervisor),
		Supervisor);
	SetPrivilegedMode(False);
	
	If NOT IsNew() AND Common.ObjectAttributeValue(Ref, "Topic") <> Topic Then
		ChangeTaskSubject();
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		Author = Users.AuthorizedUser();
		Supervisor = Users.AuthorizedUser();
		If TypeOf(FillingData) = Type("CatalogRef.Users") Then
			Performer = FillingData;
		Else
			// For auto completion in a blank Assignee field.
			Performer = Catalogs.Users.EmptyRef();
		EndIf;
	EndIf;
	
	If FillingData <> Undefined AND TypeOf(FillingData) <> Type("Structure") 
		AND FillingData <> Tasks.PerformerTask.EmptyRef() Then
		
		If TypeOf(FillingData) <> Type("TaskRef.PerformerTask") Then
			Topic = FillingData;
		Else
			Topic = FillingData.Topic;
		EndIf;
		
	EndIf;	
	
	BusinessProcessesAndTasksServer.FillMainTask(ThisObject, FillingData);
	
	If Not ValueIsFilled(DueDate) Then
		DueDate = EndOfDay(CurrentSessionDate());
	EndIf;

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	NotCheckedAttributeArray = New Array();
	If Not OnValidation Then
		NotCheckedAttributeArray.Add("Supervisor");
	EndIf;
	Common.DeleteNotCheckedAttributesFromArray(CheckedAttributes, NotCheckedAttributeArray);
EndProcedure

Procedure OnCopy(CopiedObject)
	
	IterationNumber = 0;
	JobCompleted = False;
	Confirmed = False;
	ExecutionResult = "";
	CompletedOn = '00010101000000';
	State = Enums.BusinessProcessStates.Running;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Flowchart items event handlers.

Procedure ExecuteOnCreateTasks(BusinessProcessRoutePoint, TasksBeingFormed, Cancel)
	
	IterationNumber = IterationNumber + 1;
	Write();
	
	// Setting the addressing attributes and additional attributes for each task.
	For each Task In TasksBeingFormed Do
		
		Task.Author = Author;
		Task.AuthorString = String(Author);
		If TypeOf(Performer) = Type("CatalogRef.PerformerRoles") Then
			Task.PerformerRole = Performer;
			Task.MainAddressingObject = MainAddressingObject;
			Task.AdditionalAddressingObject = AdditionalAddressingObject;
			Task.Performer = Undefined;
		Else	
			Task.Performer = Performer;
		EndIf;
		Task.Description = TaskDescriptionForExecution();
		Task.DueDate = TaskDueDateForExecution();
		Task.Importance = Importance;
		Task.Topic = Topic;
		
	EndDo;
	
EndProcedure

Procedure ExecuteBeforeTasksCreation(BusinessProcessRoutePoint, TasksBeingFormed, StandardProcessing)
	
	If Topic = Undefined Or Topic.IsEmpty() Then
		Return;
	EndIf;
	
EndProcedure

Procedure ExecuteOnExecute(BusinessProcessRoutePoint, Task, Cancel)
	
	ExecutionResult = CompletePointExecutionResult(Task) + ExecutionResult;
	Write();
	
EndProcedure

Procedure CheckOnCreateTasks(BusinessProcessRoutePoint, TasksBeingFormed, Cancel)
	
	If Supervisor.IsEmpty() Then
		Cancel = True;
		Return;
	EndIf;
	
	// Setting the addressing attributes and additional attributes for each task.
	For each Task In TasksBeingFormed Do
		
		Task.Author = Author;
		If TypeOf(Supervisor) = Type("CatalogRef.PerformerRoles") Then
			Task.PerformerRole = Supervisor;
			Task.MainAddressingObject = MainAddressingObjectSupervisor;
			Task.AdditionalAddressingObject = AdditionalAddressingObjectSupervisor;
		Else	
			Task.Performer = Supervisor;
		EndIf;
		
		Task.Description = TaskDescriptionForCheck();
		Task.DueDate = TaskDueDateForCheck();
		Task.Importance = Importance;
		Task.Topic = Topic;
		
	EndDo;
	
EndProcedure

Procedure CheckOnExecute(BusinessProcessRoutePoint, Task, Cancel)

	ExecutionResult = CheckPointExecutionResult(Task) + ExecutionResult;
	Write();
	
EndProcedure

Procedure CheckRequiredConditionCheck(BusinessProcessRoutePoint, Result)
	
	Result = OnValidation;

EndProcedure

Procedure ReturnToPerformerConditionCheck(BusinessProcessRoutePoint, Result)
	
	Result = NOT Confirmed;
	
EndProcedure

Procedure CompletionOnComplete(BusinessProcessRoutePoint, Cancel)
	
	CompletedOn = BusinessProcessesAndTasksServer.BusinessProcessCompletionDate(Ref);
	Write();
	
EndProcedure

#EndRegion

#Region Private

// Updates the values of attributes of uncompleted tasks according to the Job business process 
// attributes:
//   Importance, DueDate, Description, and Author.
//
Procedure ChangeUncompletedTasksAttributes() Export

	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", Ref);
		Lock.Lock();
		
		Query = New Query( 
			"SELECT
			|	Tasks.Ref AS Ref
			|FROM
			|	Task.PerformerTask AS Tasks
			|WHERE
			|	Tasks.BusinessProcess = &BusinessProcess
			|	AND Tasks.DeletionMark = FALSE
			|	AND Tasks.Executed = FALSE");
		Query.SetParameter("BusinessProcess", Ref);
		DetailedRecordsSelection = Query.Execute().Select();
		
		While DetailedRecordsSelection.Next() Do
			TaskObject = DetailedRecordsSelection.Ref.GetObject();
			TaskObject.Importance = Importance;
			TaskObject.DueDate = 
				?(TaskObject.RoutePoint = BusinessProcesses.Job.RoutePoints.Execute, 
				TaskDueDateForExecution(), TaskDueDateForCheck());
			TaskObject.Description = 
				?(TaskObject.RoutePoint = BusinessProcesses.Job.RoutePoints.Execute, 
				TaskDescriptionForExecution(), TaskDescriptionForCheck());
			TaskObject.Author = Author;
			// Data are not locked for editing as
			// This change has a higher priority than the opened task forms.
			TaskObject.Write();
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure 

Procedure ChangeTaskSubject()

	SetPrivilegedMode(True);
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", Ref);
		Lock.Lock();
		
		Query = New Query(
			"SELECT
			|	Tasks.Ref AS Ref
			|FROM
			|	Task.PerformerTask AS Tasks
			|WHERE
			|	Tasks.BusinessProcess = &BusinessProcess");

		Query.SetParameter("BusinessProcess", Ref);
		DetailedRecordsSelection = Query.Execute().Select();
		
		While DetailedRecordsSelection.Next() Do
			TaskObject = DetailedRecordsSelection.Ref.GetObject();
			TaskObject.Topic = Topic;
			// Data are not locked for editing as
			// This change has a higher priority than the opened task forms.
			TaskObject.Write();
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;

EndProcedure 

Function TaskDescriptionForExecution()
	
	Return Description;	
	
EndFunction

Function TaskDueDateForExecution()
	
	Return DueDate;	
	
EndFunction

Function TaskDescriptionForCheck()
	
	Return BusinessProcesses.Job.RoutePoints.Check.TaskDescription + ": " + Description;
	
EndFunction

Function TaskDueDateForCheck()
	
	Return VerificationDueDate;	
	
EndFunction

Function CompletePointExecutionResult(Val TaskRef)
	
	StringFormat = ?(JobCompleted,
		"%1, %2 " + NStr("ru = 'выполнил(а) задачу'; en = 'performed the task'; pl = 'wykonano zadanie';es_ES = 'realizar la tarea';es_CO = 'realizar la tarea';tr = 'görev tamamlandı';it = 'completato l''obiettivo';de = 'die Aufgabe erfüllt'") + ":
		           |%3
		           |",
		"%1, %2 " + NStr("ru = 'отклонил(а) задачу'; en = 'declined the task'; pl = 'odrzucono zadanie';es_ES = 'rechazar la tarea';es_CO = 'rechazar la tarea';tr = 'görev reddedildi';it = 'rifiutato l''obiettivo';de = 'die Aufgabe abgelehnt'") + ":
		           |%3
		           |");
	TaskData = Common.ObjectAttributesValues(TaskRef, 
		"ExecutionResult,CompletionDate,Performer");
	Comment = TrimAll(TaskData.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskData.CompletionDate, TaskData.Performer, Comment);
	Return Result;
	
EndFunction

Function CheckPointExecutionResult(Val TaskRef)
	
	If NOT Confirmed Then
		StringFormat = "%1, %2 " + NStr("ru = 'вернул(а) задачу на доработку'; en = 'sent the task back for revision'; pl = 'wysłano zadanie z powrotem do przeglądu';es_ES = 'enviar la tarea de nuevo para su revisión';es_CO = 'enviar la tarea de nuevo para su revisión';tr = 'görev tekrar revizyona gönderildi';it = 'restituito l''obiettivo per il completamento';de = 'die Aufgabe zurück für die Revision gesendet'") + ":
			|%3
			|";
	Else
		StringFormat = ?(JobCompleted,
			"%1, %2 " + NStr("ru = 'подтвердил(а) выполнение задачи'; en = 'confirmed task completion'; pl = 'potwierdzona realizacja zadania';es_ES = 'la finalización de la tarea se ha confirmado';es_CO = 'la finalización de la tarea se ha confirmado';tr = 'görev tamamlanması onaylandı';it = 'confermato il compimento dell''obiettivo';de = 'Erfüllung bestätigter Aufgabe'") + ":
			           |%3
			           |",
			"%1, %2 " + NStr("ru = 'подтвердил(а) отмену задачи'; en = 'confirmed task cancellation'; pl = 'anulowanie potwierdzonego zadania';es_ES = 'la cancelación de la tarea se ha confirmado';es_CO = 'la cancelación de la tarea se ha confirmado';tr = 'görev iptali onaylandı';it = 'confirmed task cancellation';de = 'Abbrechen bestätigter Aufgabe'") + ":
			           |%3
			           |");
	EndIf;
	
	TaskData = Common.ObjectAttributesValues(TaskRef, 
		"ExecutionResult,CompletionDate,Performer");
	Comment = TrimAll(TaskData.ExecutionResult);
	Comment = ?(IsBlankString(Comment), "", Comment + Chars.LF);
	Result = StringFunctionsClientServer.SubstituteParametersToString(StringFormat, TaskData.CompletionDate, TaskData.Performer, Comment);
	Return Result;

EndFunction

Procedure FillDefaultAccessValuesSets(Table)
	
	// Default restriction logic for
	// - Reading:    Author OR Performer (taking into account addressing) OR Supervisor (taking into account addressing).
	// - Changes: Author.
	
	// If the subject is not specified (the business process is not based on another subject), then the subject is not involved in the restriction logic.
	
	// Read, Update: set #1.
	Row = Table.Add();
	Row.SetNumber     = 1;
	Row.Read          = True;
	Row.Update       = True;
	Row.AccessValue = Author;
	
	// Reading: set No. 2.
	Row = Table.Add();
	Row.SetNumber     = 2;
	Row.Read          = True;
	Row.AccessValue = TaskPerformersGroup;
	
	// Reading: set No. 3.
	Row = Table.Add();
	Row.SetNumber     = 3;
	Row.Read          = True;
	Row.AccessValue = TaskPerformersGroupSupervisor;
	
EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf