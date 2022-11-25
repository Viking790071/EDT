///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TaskWasExecuted = Common.ObjectAttributeValue(Ref, "Executed");
	If Executed AND TaskWasExecuted <> True AND NOT AddressingAttributesAreFilled() Then
		
		CommonClientServer.MessageToUser(
			NStr("ru = 'Необходимо указать исполнителя задачи.'; en = 'Specify task assignee.'; pl = 'Określ wykonawcę zadania.';es_ES = 'Especifique la tarea del ejecutor.';es_CO = 'Especifique la tarea del ejecutor.';tr = 'Göreve atananı belirt.';it = 'È necessario indicare l''esecutore dell''obiettivo.';de = 'Den Bevollmächtiger angeben.'"),,,
			"Object.Performer", Cancel);
		Return;
			
	EndIf;
	
	If DueDate <> '00010101' AND StartDate > DueDate Then
		CommonClientServer.MessageToUser(
			NStr("ru = 'Дата начала исполнения не должна превышать крайний срок.'; en = 'Execution start date cannot be later than the deadline.'; pl = 'Data rozpoczęcia wykonania nie może być późniejsza niż termin.';es_ES = 'La fecha de inicio de la ejecución no puede ser posterior a la fecha límite.';es_CO = 'La fecha de inicio de la ejecución no puede ser posterior a la fecha límite.';tr = 'Uygulama başlangıç tarihi bitiş tarihinden ileri bir tarih olamaz.';it = 'La data di inizio dell''esecuzione non deve superare quella di scadenza.';de = 'Das Startdatum der Erfüllung darf nicht nach dem Fälligkeitstermin liegen.'"),,,
			"Object.StartDate", Cancel);
		Return;
	EndIf;
	
EndProcedure

Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If NOT Ref.IsEmpty() Then
		InitialAttributes = Common.ObjectAttributesValues(Ref, 
			"Executed, DeletionMark, BusinessProcessState");
	Else
		InitialAttributes = New Structure(
			"Executed, DeletionMark, BusinessProcessState",
			False, False, Enums.BusinessProcessStates.EmptyRef());
	EndIf;
		
	If InitialAttributes.DeletionMark <> DeletionMark Then
		BusinessProcessesAndTasksServer.OnMarkTaskForDeletion(Ref, DeletionMark);
	EndIf;
	
	If NOT InitialAttributes.Executed AND Executed Then
		
		If BusinessProcessState = Enums.BusinessProcessStates.Stopped Then
			Raise NStr("ru = 'Нельзя выполнять задачи остановленных бизнес-процессов.'; en = 'Cannot perform tasks of terminated business processes.'; pl = 'Nie można wykonać zadania zakończonych procesów biznesowych.';es_ES = 'No se pueden realizar las tareas de los procesos de negocio terminados.';es_CO = 'No se pueden realizar las tareas de los procesos de negocio terminados.';tr = 'Son verilen iş süreçlerinin görevleri gerçekleştirilemez.';it = 'Gli obiettivi dei processi aziendali interrotti non devono essere eseguiti.';de = 'Kann keine Aufgaben des abgeschlossenen Geschäftsprozess erfüllen.'");
		EndIf;
		
		// If the task is completed, writing the user that actually completed the task to the Performer 
		// attribute. It is needed later for reports.
		//  This action is only required if the task is not completed in the infobase, but it is completed 
		// in the object.
		If NOT ValueIsFilled(Performer) Then
			Performer = Users.AuthorizedUser();
		EndIf;
		If CompletionDate = Date(1, 1, 1) Then
			CompletionDate = CurrentSessionDate();
		EndIf;
		
		If CompletionPercent <> 100 Then
			CompletionPercent = 100;
		EndIf;
		
	ElsIf NOT DeletionMark AND InitialAttributes.Executed AND Executed Then
			CommonClientServer.MessageToUser(
				NStr("ru = 'Эта задача уже была выполнена ранее.'; en = 'This task is already completed.'; pl = 'To zadanie jest już zakończone.';es_ES = 'Esta tarea ya está terminada.';es_CO = 'Esta tarea ya está terminada.';tr = 'Görev zaten tamamlandı.';it = 'Questo obiettivo è stato già eseguito.';de = 'Diese Aufgabe ist bereit erfüllt.'"),,,, Cancel);
			Return;
	EndIf;
	
	If Importance.IsEmpty() Then
		Importance = Enums.TaskImportanceOptions.Normal;
	EndIf;
	
	If NOT ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Running;
	EndIf;
	
	SubjectString = Common.SubjectString(Topic);
	
	If NOT Ref.IsEmpty() AND InitialAttributes.BusinessProcessState <> BusinessProcessState Then
		SetSubordinateBusinessProcessesState(BusinessProcessState);
	EndIf;
	
	If Executed AND Not AcceptedForExecution Then
		AcceptedForExecution = True;
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;
	
	// StandardSubsystems.AccessManagement
	SetPrivilegedMode(True);
	TaskPerformersGroup = BusinessProcessesAndTasksServer.TaskPerformersGroup(PerformerRole, 
		MainAddressingObject, AdditionalAddressingObject);
	SetPrivilegedMode(False);
	// End StandardSubsystems.AccessManagement
	
	// Filling attribute AcceptForExecutionDate.
	If AcceptedForExecution AND AcceptForExecutionDate = Date('00010101') Then
		AcceptForExecutionDate = CurrentSessionDate();
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If TypeOf(FillingData) = Type("TaskObject.PerformerTask") Then
		FillPropertyValues(ThisObject, FillingData, 
			"BusinessProcess,RoutePoint,Description,Performer,PerformerRole,MainAddressingObject," 
			+ "AdditionalAddressingObject,Importance,CompletionDate,Author,Details,DueDate," 
			+ "StartDate,ExecutionResult,Topic,Project,ProjectPhase");
		Date = CurrentSessionDate();
	EndIf;
	If NOT ValueIsFilled(Importance) Then
		Importance = Enums.TaskImportanceOptions.Normal;
	EndIf;
	
	If NOT ValueIsFilled(BusinessProcessState) Then
		BusinessProcessState = Enums.BusinessProcessStates.Running;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure SetSubordinateBusinessProcessesState(NewState)
	
	BeginTransaction();
	Try
		SubordinateBusinessProcesses = BusinessProcessesAndTasksServer.MainTaskBusinessProcesses(Ref, True);
		For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
			BusinessProcessObject = SubordinateBusinessProcess.GetObject();
			BusinessProcessObject.Lock();
			BusinessProcessObject.State = NewState;
			BusinessProcessObject.Write(); // ACC:1327 The lock is set in the BusinessProcessesAndTasksServer.MainTaskBusinessProcesses.
		EndDo;	
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Determines whether addressing attributes are filled in: assignee or assignee role.
// 
// Returns:
//  Boolean - returns True if an assignee or assignee role is specified in the task.
//
Function AddressingAttributesAreFilled()
	
	Return ValueIsFilled(Performer) OR NOT PerformerRole.IsEmpty();

EndFunction

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf