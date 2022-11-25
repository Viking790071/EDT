///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

// Initializes common parameters of the task execution form.
//
// Parameters:
//  TaskForm            - ClientApplicationForm - a task execution form.
//  TaskObject           - TaskObject     - a task object.
//  StateGroupItem - FormGroup      -a group with information on the task state.
//  CompletionDateItem  - FormField        - a field with the task completion date.
//
Procedure TaskFormOnCreateAtServer(BusinessProcessTaskForm, TaskObject, 
	StateGroupItem, CompletionDateItem) Export
	
	BusinessProcessTaskForm.ReadOnly = TaskObject.Executed;

	If TaskObject.Executed Then
		If StateGroupItem <> Undefined Then
			StateGroupItem.Visible = True;
		EndIf;
		Parent = ?(StateGroupItem <> Undefined, StateGroupItem, BusinessProcessTaskForm);
		Item = BusinessProcessTaskForm.Items.Find("__TaskStatePicture");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__TaskStatePicture", Type("FormDecoration"), Parent);
			Item.Type = FormDecorationType.Picture;
			Item.Picture = PictureLib.Information;
		EndIf;
		
		Item = BusinessProcessTaskForm.Items.Find("__TaskState");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__TaskState", Type("FormDecoration"), Parent);
			Item.Type = FormDecorationType.Label;
			Item.Height = 0; // Auto height
			Item.AutoMaxWidth = False;
		EndIf;
		UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
		CompletionDateAsString = ?(UseDateAndTimeInTaskDeadlines, 
			Format(TaskObject.CompletionDate, "DLF=DT"), Format(TaskObject.CompletionDate, "DLF=D"));
		Item.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Задача выполнена %1 пользователем %2.'; en = 'The task is completed on %1 by user %2.'; pl = 'Zadanie jest wykonano na %1 przez użytkownika %2.';es_ES = 'La tarea ha sido completada %1 por el usuario %2.';es_CO = 'La tarea ha sido completada %1 por el usuario %2.';tr = 'Görev %1''de %2 kullanıcısı tarafından tamamlandı.';it = 'L''obiettivo %1 è stato completato dall''utente %2.';de = 'Die Aufgabe ist am %1 vom Benutzer %2 erfüllt.'"),
			CompletionDateAsString, 
			PerformerString(TaskObject.Performer, TaskObject.PerformerRole,
			TaskObject.MainAddressingObject, TaskObject.AdditionalAddressingObject));
	EndIf;
	
	If BusinessProcessesAndTasksServerCall.IsHeadTask(TaskObject.Ref) Then
		If StateGroupItem <> Undefined Then
			StateGroupItem.Visible = True;
		EndIf;
		Parent = ?(StateGroupItem <> Undefined, StateGroupItem, BusinessProcessTaskForm);
		Item = BusinessProcessTaskForm.Items.Find("__HeadTaskPicture");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__HeadTaskPicture", Type("FormDecoration"), Parent);
			Item.Type = FormDecorationType.Picture;
			Item.Picture = PictureLib.Information;
		EndIf;
		
		Item = BusinessProcessTaskForm.Items.Find("__HeadTask");
		If Item = Undefined Then
			Item = BusinessProcessTaskForm.Items.Add("__HeadTask", Type("FormDecoration"), Parent);
			Item.Type = FormDecorationType.Label;
			Item.Title = NStr("ru = 'Это ведущая задача для вложенных бизнес-процессов. Она будет выполнена автоматически при их завершении.'; en = 'This is a leading task for nested business processes. It will be completed automatically upon their completion.'; pl = 'Jest to wiodące zadanie dla zagnieżdżonych procesów biznesowych. Ono zostanie zakończone automatycznie po jego zakończeniu.';es_ES = 'Esta es una de las principales tareas de los procesos de negocio anidados. Se completará automáticamente cuando se completen.';es_CO = 'Esta es una de las principales tareas de los procesos de negocio anidados. Se completará automáticamente cuando se completen.';tr = 'Bu, gömülü iş süreçlerinin başlıca görevidir. Tamamlanmaları üzerine otomatik olarak tamamlanacaktır.';it = 'Questo è l''obiettivo principale dei processi aziendali nidificati. Sarà eseguito automaticamente quando saranno completati.';de = 'Diese ist die Hauptaufgabe für den verschachtelten Geschäftsprozess. Diese wird nach deren Erfüllung automatisch erfüllt.'");
			Item.Height = 0; // Auto height
			Item.AutoMaxWidth = False;
		EndIf;
	EndIf;
	
EndProcedure

// The procedure is called when creating a task list form on the server.
//
// Parameters:
//  TaskListOrItsConditionalAppearance - DynamicList, DataCompositionConditionalAppearance - 
//   conditional appearance of a task list.
//
Procedure SetTaskAppearance(Val TaskListOrItsConditionalAppearance) Export
	
	If TypeOf(TaskListOrItsConditionalAppearance) = Type("DynamicList") Then
		ConditionalTaskListAppearance = TaskListOrItsConditionalAppearance.SettingsComposer.Settings.ConditionalAppearance;
		ConditionalTaskListAppearance.UserSettingID = "MainAppearance";
	Else
		ConditionalTaskListAppearance = TaskListOrItsConditionalAppearance;
	EndIf;
	
	// Deleting preset appearance items.
	PresetAppearanceItems = New Array;
	Items = ConditionalTaskListAppearance.Items;
	For each ConditionalAppearanceItem In Items Do
		If ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible Then
			PresetAppearanceItems.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For each ConditionalAppearanceItem In PresetAppearanceItems Do
		Items.Delete(ConditionalAppearanceItem);
	EndDo;
		
	// Setting appearance for overdue tasks.
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Filled;
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Less;
	DataFilterItem.RightValue = CurrentSessionDate();
	DataFilterItem.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Executed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value =  Metadata.StyleItems.OverdueDataColor.Value;   
	AppearanceColorItem.Use = True;
	
	// Setting appearance for completed tasks.
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Executed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.ExecutedTask.Value; 
	AppearanceColorItem.Use = True;
	
	// Setting appearance for tasks that are not accepted for execution.
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("AcceptedForExecution");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = False;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Font");
	AppearanceColorItem.Value = Metadata.StyleItems.NotAcceptedForExecutionTasks.Value; 
	AppearanceColorItem.Use = True;
	
	// Setting appearance for tasks with unfilled Deadline.
	ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("DueDate");
	FormattedField.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("DueDate");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	DataFilterItem.RightValue = True;
	DataFilterItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("TextColor");
	AppearanceColorItem.Value = Metadata.StyleItems.InaccessibleCellTextColor.Value;
	AppearanceColorItem.Use = True;
	
	AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
	AppearanceColorItem.Value = NStr("ru = 'Срок не указан'; en = 'Due date is not specified'; pl = 'Nie określono terminu';es_ES = 'No se ha especificado la fecha de vencimiento';es_CO = 'No se ha especificado la fecha de vencimiento';tr = 'Bitiş tarihi belirtilmedi';it = 'Termine non indicato';de = 'Fälligkeitsdatum nicht angegeben'");
	AppearanceColorItem.Use = True;
	
	// Setting appearance for external users. The Author field is empty.
	If UsersClientServer.IsExternalUserSession() Then
			ConditionalAppearanceItem = ConditionalTaskListAppearance.Items.Add();
			ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;

			FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
			FormattedField.Field = New DataCompositionField("Author");
			FormattedField.Use = True;
			
			DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
			DataFilterItem.LeftValue = New DataCompositionField("Author");
			DataFilterItem.ComparisonType = DataCompositionComparisonType.NotEqual;
			DataFilterItem.RightValue = Users.AuthorizedUser();
			DataFilterItem.Use = True;

			AppearanceColorItem = ConditionalAppearanceItem.Appearance.Items.Find("Text");
			AppearanceColorItem.Value = NStr("ru = 'Представитель организации'; en = 'Company representative'; pl = 'Przedstawiciel firmy';es_ES = 'Representante de la empresa';es_CO = 'Representante de la empresa';tr = 'Şirket temsilcisi';it = 'Rappresentante dell''organizzazione';de = 'Gesellschaftsvertreter'");
			AppearanceColorItem.Use = True;
	EndIf;
	
EndProcedure

// The procedure is called when creating business processes list form on the server.
//
// Parameters:
//  BusinessProcessesConditionalAppearance - ConditionalAppearance - conditional appearance of a business process list.
//
Procedure SetBusinessProcessesAppearance(Val BusinessProcessesConditionalAppearance) Export
	
	// Description is not specified.
	ConditionalAppearanceItem = BusinessProcessesConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	FormattedField = ConditionalAppearanceItem.Fields.Items.Add();
	FormattedField.Field = New DataCompositionField("Description");
	FormattedField.Use = True;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Description");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.NotFilled;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	ConditionalAppearanceItem.Appearance.SetParameterValue("Text", NStr("ru = 'Без описания'; en = 'No description'; pl = 'Brak opisu';es_ES = 'Sin descripción';es_CO = 'Sin descripción';tr = 'Açıklama yok';it = 'Senza descrizione';de = 'Keine Beschreibung'"));
	
	// Completed business process.
	ConditionalAppearanceItem = BusinessProcessesConditionalAppearance.Items.Add();
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	
	DataFilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	DataFilterItem.LeftValue = New DataCompositionField("Completed");
	DataFilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	DataFilterItem.RightValue = True;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", StyleColors.CompletedBusinessProcess);
	
EndProcedure

// Returns the string representation of the task  assignee Performer or the values specified in 
// parameters PerformerRole, MainAddressingObject, and AdditionalAddressingObject.
//
// Parameters:
//  Performer                   - UserRef  - a task assignee.
//  PerformerRole               - Catalogs.PerformerRoles - a role.
//  MainAddressingObject       - AnyRef - a reference to the main addressing object.
//  AdditionalAddressingObject - AnyRef - a reference to an additional addressing object.
//
// Returns:
//  String -  a string representation of the task assignee, for example:
//           "John Smith" - assignee as specified in the Performer parameter.
//           "Chief Accountant" - an assignee role specified in the PerformerRole parameter.
//           "Chief Accountant (Sun LLC)" - if a role is specified along with the main addressing object.
//           "Chief Accountant (Sun LLC, New York branch)" - if a role is specified along with both 
//                                                                   addressing objects.
//
Function PerformerString(Val Performer, Val PerformerRole,
	Val MainAddressingObject = Undefined, Val AdditionalAddressingObject = Undefined) Export
	
	If ValueIsFilled(Performer) Then
		Return String(Performer)
	ElsIf NOT PerformerRole.IsEmpty() Then
		Return RoleString(PerformerRole, MainAddressingObject, AdditionalAddressingObject);
	EndIf;
	Return NStr("ru = 'Не указан'; en = 'Not specified'; pl = 'Nie określono metody płatności';es_ES = 'No especificado';es_CO = 'No especificado';tr = 'Belirtilmedi';it = 'Non specificato';de = 'Keine Angabe'");

EndFunction

// Returns a string representation of the PerformerRole role and its addressing objects if they are specified.
//
// Parameters:
//  PerformerRole               - Catalogs.PerformerRoles  - a role.
//  MainAddressingObject       - AnyRef - a reference to the main addressing object.
//  AdditionalAddressingObject - AnyRef - a reference to an additional addressing object.
// 
// Returns:
//  String - a string representation of a role. For example:
//            "Chief Accountant" - an assignee role specified in the PerformerRole parameter.
//            "Chief Accountant (Sun LLC)" - if a role is specified along with the main addressing object.
//            "Chief Accountant (Sun LLC, New York branch)" - if a role is specified along with both 
//                                                                    addressing objects.
//
Function RoleString(Val PerformerRole,
	Val MainAddressingObject = Undefined, Val AdditionalAddressingObject = Undefined) Export
	
	If NOT PerformerRole.IsEmpty() Then
		Result = String(PerformerRole);
		If MainAddressingObject <> Undefined Then
			Result = Result + " (" + String(MainAddressingObject);
			If AdditionalAddressingObject <> Undefined Then
				Result = Result + " ," + String(AdditionalAddressingObject);
			EndIf;
			Result = Result + ")";
		EndIf;
		Return Result;
	EndIf;
	Return "";

EndFunction

// Marks for deletion all the specified business process tasks (or clears the mark).
//
// Parameters:
//  BusinessProcessRef - BusinessProcessRef - a business process whose tasks are to be marked for deletion.
//  DeletionMark     - Boolean - the DeletionMark property value for tasks.
//
Procedure MarkTasksForDeletion(BusinessProcessRef, DeletionMark) Export
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("BusinessProcess", BusinessProcessRef);
		Lock.Lock();
		
		Query = New Query("SELECT
			|	Tasks.Ref AS Ref 
			|FROM
			|	Task.PerformerTask AS Tasks
			|WHERE
			|	Tasks.BusinessProcess = &BusinessProcess");
		Query.SetParameter("BusinessProcess", BusinessProcessRef);
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			TaskObject = Selection.Ref.GetObject();
			TaskObject.SetDeletionMark(DeletionMark);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(EventLogEvent(), EventLogLevel.Error, 
			BusinessProcessRef.Metadata(), BusinessProcessRef, DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure	

// Sets display and edit format for a form field of the Date type based on the subsystem settings.
//  
//
// Parameters:
//  DateField - FormField - a form control, a field with a value of the Date type.
//
Procedure SetDateFormat(DateField) Export
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	FormatLine = ?(UseDateAndTimeInTaskDeadlines, "DLF=DT", "DLF=D");
	If DateField.Type = FormFieldType.InputField Then
		DateField.EditFormat = FormatLine;
	Else	
		DateField.Format               = FormatLine;
	EndIf;
	DateField.Width                   = ?(UseDateAndTimeInTaskDeadlines, 0, 9);
	
EndProcedure

// Gets the business processes of the TaskRef head task.
//
// Parameters:
//   TaskRef - TaskRef.PerformerTask - a head task.
//   ForChange - Boolean - if True, sets an exclusive managed lock for all business processes of the 
//                           specified head task. The default value is False.
// Returns:
//    Array - references to business processes (BusinessProcessRef.<Business process name>.)
// 
Function HeadTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Result = SelectHeadTaskBusinessProcesses(TaskRef, ForChange);
	Return Result.Unload().UnloadColumn("Ref");
		
EndFunction

// Returns the business process completion date which is the maximum completion date of the business 
//  process tasks.
//
// Parameters:
//  BusinessProcessRef - BusinessProcessRef - a reference to a business process.
// 
// Returns:
//  Date - a completion date of the specified business process.
//
Function BusinessProcessCompletionDate(BusinessProcessRef) Export
	
	VerifyAccessRights("Read", BusinessProcessRef.Metadata());
	SetPrivilegedMode(True);
	Query = New Query;
	Query.Text = 
		"SELECT
		|	MAX(PerformerTask.CompletionDate) AS MaxCompletionDate
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.BusinessProcess = &BusinessProcess
		|	AND PerformerTask.Executed = TRUE";
	Query.SetParameter("BusinessProcess", BusinessProcessRef);
	
	Result = Query.Execute();
	If Result.IsEmpty() Then 
		Return CurrentSessionDate();
	EndIf;	
	
	Selection = Result.Select();
	Selection.Next();
	Return Selection.MaxCompletionDate;
	
EndFunction	

// Returns an array of business processes subordinate to the specified task.
//
// Parameters:
//  TaskRef  - TaskRef.PerformerTask - a task.
//  ForChange  - Boolean - if True, sets an exclusive managed lock for all business processes of the 
//                           specified head task. The default value is False.
//
// Returns:
//   Array - references to business processes (BusinessProcessRef.<Business process name>.)
//
Function MainTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Result = New Array;
	If ForChange Then
		Lock = New DataLock;
		For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
			
			// Business processes are not required to have a main task.
			MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
			If MainTaskAttribute = Undefined Then
				Continue;
			EndIf;	
				
			LockItem = Lock.Add(BusinessProcessMetadata.FullName());
			LockItem.SetValue("MainTask", TaskRef);
			
		EndDo;	
		Lock.Lock();
	EndIf;
	
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// Business processes are not required to have a main task.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
			
		QueryText = StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT ALLOWED
			|	%1.Ref AS Ref
			|FROM
			|	%2 AS %1
			|WHERE
			|	%1.MainTask = &MainTask", 
			BusinessProcessMetadata.Name, BusinessProcessMetadata.FullName());
		Query = New Query(QueryText);
		Query.SetParameter("MainTask", TaskRef);
		
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		While Selection.Next() Do
			Result.Add(Selection.Ref);
		EndDo;
			
	EndDo;	
	
	Return Result;
		
EndFunction	

// Checks if the current user has sufficient rights to change the business process state.
//
// Parameters:
//  BusinessProcessObject - BusinessProcessObject - a business process object.
//
Procedure ValidateRightsToChangeBusinessProcessState(BusinessProcessObject) Export
	
	If Not ValueIsFilled(BusinessProcessObject.State) Then 
		BusinessProcessObject.State = Enums.BusinessProcessStates.Running;
	EndIf;
	
	If BusinessProcessObject.IsNew() Then
		PreviousState = Enums.BusinessProcessStates.Running;
	Else
		PreviousState = Common.ObjectAttributeValue(BusinessProcessObject.Ref, "State");
	EndIf;
	
	If PreviousState <> BusinessProcessObject.State Then
		
		If Not HasRightsToStopBusinessProcess(BusinessProcessObject) Then 
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Недостаточно прав для остановки бизнес-процесса ""%1"".'; en = 'Insufficient rights to stop business process ""%1"".'; pl = 'Niewystarczające prawa do zatrzymania procesu biznesowego ""%1"".';es_ES = 'Derechos insuficientes para detener el proceso de negocio ""%1"".';es_CO = 'Derechos insuficientes para detener el proceso de negocio ""%1"".';tr = '""%1"" sürecini durdurmak için yetersiz yetki.';it = 'Permessi insufficienti per terminare il processo aziendale ""%1"".';de = 'Ungenügende Rechte um den Geschäftsprozess ""%1"" einzuhalten.'"),
				String(BusinessProcessObject));
			Raise MessageText;
		EndIf;
		
		If PreviousState = Enums.BusinessProcessStates.Running Then
			
			If BusinessProcessObject.Completed Then
				Raise NStr("ru = 'Невозможно остановить завершенные бизнес-процессы.'; en = 'Cannot stop the completed business processes.'; pl = 'Nie można zatrzymać zakończonych procesów biznesowych.';es_ES = 'No se pueden detener los procesos de negocio completados.';es_CO = 'No se pueden detener los procesos de negocio completados.';tr = 'Tamamlanmış iş süreçleri durdurulamaz.';it = 'È impossibile terminare dei processi aziendali terminati.';de = 'Kann nicht den erfüllten Geschäftsprozess einhalten.'");
			EndIf;
				
			If Not BusinessProcessObject.Started Then
				Raise NStr("ru = 'Невозможно остановить не стартовавшие бизнес-процессы.'; en = 'Cannot stop the business processes that are not started yet.'; pl = 'Nie można zatrzymać procesów biznesowych, które nie są jeszcze rozpoczęte.';es_ES = 'No se pueden detener los procesos de negocio que aún no se han iniciado.';es_CO = 'No se pueden detener los procesos de negocio que aún no se han iniciado.';tr = 'Başlamamış olan iş süreçleri durdurulamaz.';it = 'È impossibile terminare dei processi aziendali non avviati.';de = 'Kann nicht die noch nicht gestarteten Geschäftsprozesse einhalten.'");
			EndIf;
			
		ElsIf PreviousState = Enums.BusinessProcessStates.Stopped Then
			
			If BusinessProcessObject.Completed Then
				Raise NStr("ru = 'Невозможно сделать активными завершенные бизнес-процессы.'; en = 'Cannot activate the completed business processes.'; pl = 'Nie można aktywować zakończonych procesów biznesowych.';es_ES = 'No se pueden activar los procesos de negocio completados.';es_CO = 'No se pueden activar los procesos de negocio completados.';tr = 'Tamamlanmış iş süreçleri etkinleştirilemez.';it = 'È impossibile rendere attivi dei processi aziendali terminati.';de = 'Kann nicht den erfüllten Geschäftsprozess aktivieren.'");
			EndIf;
				
			If Not BusinessProcessObject.Started Then
				Raise NStr("ru = 'Невозможно сделать активными не стартовавшие бизнес-процессы.'; en = 'Cannot activate the business processes that are not started yet.'; pl = 'Nie można aktywować procesów biznesowych, które nie są jeszcze rozpoczęte.';es_ES = 'No se pueden activar los procesos de negocio que aún no se han iniciado.';es_CO = 'No se pueden activar los procesos de negocio que aún no se han iniciado.';tr = 'Başlamamış olan iş süreçleri etkinleştirilemez.';it = 'È impossibile rendere attivi dei processi aziendali non avviati.';de = 'Kann nicht die noch nicht gestarteten Geschäftsprozesse aktivieren.'");
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Sets an exclusive managed lock for the specified business process.
// For calling commands in dynamic lists from handlers.
// Rows of dynamic list grouping are ignored.
//
// Parameters:
//   BusinessProcesses - Array - references to business processes (BusinessProcessRef.<Business 
//                             process name>) or a single business process reference.
//
Procedure LockBusinessProcesses(BusinessProcesses) Export
	
	Lock = New DataLock;
	If TypeOf(BusinessProcesses) = Type("Array") Then
		For each BusinessProcess In BusinessProcesses Do
			
			If TypeOf(BusinessProcess) = Type("DynamicListGroupRow") Then
				Continue;
			EndIf;	
			
			LockItem = Lock.Add(BusinessProcess.Metadata().FullName());
			LockItem.SetValue("Ref", BusinessProcess);
		EndDo;
	Else	
		If TypeOf(BusinessProcesses) = Type("DynamicListGroupRow") Then
			Return;
		EndIf;	
		LockItem = Lock.Add(BusinessProcesses.Metadata().FullName());
		LockItem.SetValue("Ref", BusinessProcesses);
	EndIf;
	Lock.Lock();
	
EndProcedure	

// Sets an exclusive managed lock for the specified tasks.
// For calling commands in dynamic lists from handlers.
// Rows of dynamic list grouping are ignored.
//
// Parameters:
//   Tasks - Array, TaskRef.PerformerTask - references  to tasks or a single reference.
//
Procedure LockTasks(Tasks) Export
	
	Lock = New DataLock;
	If TypeOf(Tasks) = Type("Array") Then
		For each Task In Tasks Do
			
			If TypeOf(Task) = Type("DynamicListGroupRow") Then 
				Continue;
			EndIf;
			
			LockItem = Lock.Add("Task.PerformerTask");
			LockItem.SetValue("Ref", Task);
		EndDo;
	Else	
		If TypeOf(BusinessProcesses) = Type("DynamicListGroupRow") Then
			Return;
		EndIf;	
		LockItem = Lock.Add("Task.PerformerTask");
		LockItem.SetValue("Ref", Tasks);
	EndIf;
	Lock.Lock();
	
EndProcedure

// Fills MainTask attribute when creating a business process based on another business process.
// See also BusinessProcessesAndTasksOverridable.OnFillMainBusinessProcessTask.
//
// Parameters:
//  BusinessProcessObject	 - BusinessProcessObject        - a business process to be filled in.
//  FillingData	 - TaskRef, Arbitrary - filling data that is passed to the filling handler.
//
Procedure FillMainTask(BusinessProcessObject, FillingData) Export
	
	StandardProcessing = True;
	BusinessProcessesAndTasksOverridable.OnFillMainBusinessProcessTask(BusinessProcessObject, FillingData, StandardProcessing);
	If Not StandardProcessing Then
		Return;
	EndIf;
	
	If FillingData = Undefined Then 
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("TaskRef.PerformerTask") Then
		BusinessProcessObject.MainTask = FillingData;
	EndIf;
	
EndProcedure

// Gets a task assignees group that matches the addressing attributes.
//  If the group does not exist yet, it is created and returned.
//
// Parameters:
//  PerformerRole               - CatalogRef.PerformerRoles - an assignee role.
//  MainAddressingObject       - AnyRef - a reference to the main addressing object.
//  AdditionalAddressingObject - AnyRef - a reference to an additional addressing object.
// 
// Returns:
//  CatalogRef.TaskPerformersGroups - a task assignees group found by role.
//
Function TaskPerformersGroup(PerformerRole, MainAddressingObject, AdditionalAddressingObject) Export
	
	BeginTransaction();
	Try
		Lock = New DataLock;
		LockItem = Lock.Add("Catalog.TaskPerformersGroups");
		LockItem.SetValue("PerformerRole", PerformerRole);
		LockItem.SetValue("MainAddressingObject", MainAddressingObject);
		LockItem.SetValue("AdditionalAddressingObject", AdditionalAddressingObject);
		Lock.Lock();
		
		Query = New Query(
			"SELECT
			|	TaskPerformersGroups.Ref AS Ref
			|FROM
			|	Catalog.TaskPerformersGroups AS TaskPerformersGroups
			|WHERE
			|	TaskPerformersGroups.PerformerRole = &PerformerRole
			|	AND TaskPerformersGroups.MainAddressingObject = &MainAddressingObject
			|	AND TaskPerformersGroups.AdditionalAddressingObject = &AdditionalAddressingObject");
		Query.SetParameter("PerformerRole",               PerformerRole);
		Query.SetParameter("MainAddressingObject",       MainAddressingObject);
		Query.SetParameter("AdditionalAddressingObject", AdditionalAddressingObject);
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			PerformersGroup = Selection.Ref;
		Else
			// It is necessary to add a new task assignees group.
			PerformersGroupObject = Catalogs.TaskPerformersGroups.CreateItem();
			PerformersGroupObject.PerformerRole               = PerformerRole;
			PerformersGroupObject.MainAddressingObject       = MainAddressingObject;
			PerformersGroupObject.AdditionalAddressingObject = AdditionalAddressingObject;
			PerformersGroupObject.Write();
			PerformersGroup = PerformersGroupObject.Ref;
		EndIf;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;	
	Return PerformersGroup;
	
EndFunction 

////////////////////////////////////////////////////////////////////////////////
// Deferred start of business processes.

// Adds a process for deferred start.
//
// Parameters:
//  Process    -  BusinessProcessRef - a business process for deferred start.
//  StartDate - Date - a deferred start date.
//
Procedure AddProcessForDeferredStart(Process, StartDate) Export
	
	If Not ValueIsFilled(StartDate) OR Not ValueIsFilled(Process) Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.ProcessesToStart.CreateRecordSet();
	RecordSet.Filter.Owner.Set(Process);
	
	Record = RecordSet.Add();
	Record.Owner = Process;
	Record.DeferredStartDate = StartDate;
	Record.State = Enums.ProcessesStatesForStart.ReadyToStart;
	
	RecordSet.Write();
	
EndProcedure

// Disables deferred process start.
//
// Parameters:
//  Process - BusinessProcessRef - a business process to disable a deferred start for.
//
Procedure DisableProcessDeferredStart(Process) Export
	
	StartSettings = DeferredProcessParameters(Process);
	
	If StartSettings = Undefined Then // The process does not wait for start.
		Return;
	EndIf;
	
	If StartSettings.State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart") Then
		RecordSet = InformationRegisters.ProcessesToStart.CreateRecordSet();
		RecordSet.Filter.Owner.Set(Process);
		RecordSet.Write();
	EndIf;
	
EndProcedure

// Starts the deferred business process and sets the start flag.
//
// Parameters:
//   - BusinessProcess - BusinessProcessObject - a process to be started in deferred mode.
//
Procedure StartDeferredProcess(BusinessProcess) Export
	
	BeginTransaction();
	
	Try
		
		LockDataForEdit(BusinessProcess);
		
		BusinessProcessObject = BusinessProcess.GetObject();
		// Starting a business process and registering it in the register.
		BusinessProcessObject.Start();
		InformationRegisters.ProcessesToStart.RegisterProcessStart(BusinessProcess);
		
		UnlockDataForEdit(BusinessProcess);
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		
		ErrorDescription = DetailErrorDescription(ErrorInfo());
		
		ErrorText = NStr("ru = 'Во время отложенного старта этого процесса произошла ошибка:
			|%1
			|Попробуйте запустить процесс вручную, а не отложенно.'; 
			|en = 'An error occurred during the deferred start of this process:
			|%1
			|Try to start the process manually, not automatically.'; 
			|pl = 'Zaistniał błąd podczas odroczonego rozpoczęcia tego procesu:
			|%1
			|Spróbuj rozpocząć proces ręcznie, nie automatycznie.';
			|es_ES = 'Se produjo un error durante el inicio diferido de este proceso: 
			|%1
			|Intente iniciar el proceso manualmente, no automáticamente.';
			|es_CO = 'Se produjo un error durante el inicio diferido de este proceso: 
			|%1
			|Intente iniciar el proceso manualmente, no automáticamente.';
			|tr = 'Bu sürecin ertelenmiş başlangıcı sırasında bir hata oluştu:
			|%1
			|Süreci otomatik değil, manuel olarak başlatmaya çalışın.';
			|it = 'Durante l''avvio rimandato di questo processo si è verificato un errore:
			|%1
			|Provate ad avviare il processo manualmente, non rimandandolo.';
			|de = 'Fehler auftreten beim verzögerten Start von diesem Prozess:
			|%1
			|Versuchen Sie den Prozess nicht automatisch sondern manuell zu starten.'");
			
		Details = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorText,
			ErrorDescription);
		
		InformationRegisters.ProcessesToStart.RegisterStartCancellation(BusinessProcess, Details);
			
	EndTry;
	
EndProcedure

// Returns information on the business process start.
//
// Parameters:
//  Process - BusinessProcessRef - a business process to obtain start information from.
// 
// Returns:
//  - Undefined - returned if there is no info.
//  - Structure - if the following is available:
//     * BusinessProcess - BusinessProcessRef.
//     * DeferredStartDate - DateAndTime.
//     * State - EnumRef.ProcessesStatesForStart.
//     * StartCancelReason - String - a reason for canceling the start.
//
Function DeferredProcessParameters(Process) Export
	
	Result = Undefined;
	
	If Not ValueIsFilled(Process) Then
		Return Result;
	EndIf;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ProcessesToStart.Owner,
		|	ProcessesToStart.DeferredStartDate,
		|	ProcessesToStart.State,
		|	ProcessesToStart.StartCancelReason
		|FROM
		|	InformationRegister.ProcessesToStart AS ProcessesToStart
		|WHERE
		|	ProcessesToStart.Owner = &BusinessProcess";
	Query.SetParameter("BusinessProcess", Process);
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		Result = New Structure;
		Result.Insert("BusinessProcess", Selection.Owner);
		Result.Insert("DeferredStartDate", Selection.DeferredStartDate);
		Result.Insert("State", Selection.State);
		Result.Insert("StartCancelReason", Selection.StartCancelReason);
	EndIf;
	
	Return Result;
	
EndFunction

// Returns the start date of a deferred business process if BusinessProcess waits for deferred start.
//  Otherwise returns an empty date.
//
// Parameters:
//  BusinessProcess - BusinessProcessRef - a business process to get a deferred start date for.
// 
// Returns:
//  Date - a deferred start date.
//
Function ProcessDeferredStartDate(BusinessProcess) Export

	DeferredStartDate = '00010101';
	
	Setting = DeferredProcessParameters(BusinessProcess);
	
	If Setting = Undefined Then
		Return DeferredStartDate;
	EndIf;
	
	If Setting.State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart") Then
		DeferredStartDate = Setting.DeferredStartDate;
	EndIf;
	
	Return DeferredStartDate;

EndFunction

////////////////////////////////////////////////////////////////////////////////
// Scheduled job handlers.

// Runs notification mailing to assignees on new tasks received since the date of previous mailing.
// Notifications are sent using email on behalf of the system account.
// Also it is the NewPerformerTaskNotifications scheduled job handler.
//
Procedure NotifyPerformersOnNewTasks() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.NewPerformerTaskNotifications);
	
	ErrorDescription = "";
	MessageKind = NStr("ru = 'Бизнес-процессы и задачи.Уведомление о новых задачах'; en = 'Business processes and tasks.New task notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o nowym zadaniu';es_ES = 'Procesos de negocio y tareas. Notificación de nuevas tareas';es_CO = 'Procesos de negocio y tareas. Notificación de nuevas tareas';tr = 'İş süreçleri ve görevler. Yeni görev bildirimi';it = 'Processi aziendali e obiettivi. Notifica sui nuovi obiettivi';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die neue Aufgabe'", CommonClientServer.DefaultLanguageCode());

	If NOT SystemEmailAccountIsSetUp(ErrorDescription) Then
		WriteLogEvent(MessageKind, EventLogLevel.Error,
			Metadata.ScheduledJobs.NewPerformerTaskNotifications,, ErrorDescription);
		Return;
	EndIf;
	
	NotificationDate = CurrentSessionDate();
	LatestNotificationDate = Constants.NewTasksNotificationDate.Get();
	
	// If no notifications were sent earlier or the last notification was sent more than one day ago, 
	// selecting new tasks for the last 24 hours.
	If (LatestNotificationDate = '00010101000000') 
		Or (NotificationDate - LatestNotificationDate > 24*60*60) Then
		LatestNotificationDate = NotificationDate - 24*60*60;
	EndIf;
	
	WriteLogEvent(MessageKind, EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Начато регламентное уведомление о новых задачах за период %1 - %2'; en = 'Scheduled notification of new tasks for the period %1–%2 is started'; pl = 'Zaplanowane powiadomienie o nowych zadaniach dla okresu %1–%2 jest rozpoczęte';es_ES = 'Se ha iniciado la notificación programada de nuevas tareas para el período %1-%2';es_CO = 'Se ha iniciado la notificación programada de nuevas tareas para el período %1-%2';tr = '%1–%2 dönemi için yeni görevlerin planlanmış bildirimi başladı';it = 'Iniziata una notifica di routine sui nuovi obiettivi per il periodo %1 - %2';de = 'Geplante Benachrichtigung über die neuen Aufgaben für den Zeitraum von %1–%2 ist gestartet'"),
		LatestNotificationDate, NotificationDate));
	
	TasksByPerformers = SelectNewTasksByPerformers(LatestNotificationDate, NotificationDate);
	For Each PerformerRow In TasksByPerformers.Rows Do
		SendNotificationOnNewTasks(PerformerRow.Performer, PerformerRow);
	EndDo;
	
	SetPrivilegedMode(True);
	Constants.NewTasksNotificationDate.Set(NotificationDate);
	SetPrivilegedMode(False);
	
	WriteLogEvent(MessageKind, EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Завершено регламентное уведомление о новых задачах (уведомлено исполнителей: %1)'; en = 'Scheduled notification of new tasks is completed (notified assignees: %1)'; pl = 'Zaplanowane powiadomienie o nowych zadaniach jest zakończone (powiadomieni wykonawcy: %1)';es_ES = 'Se ha completado la notificación programada de las nuevas tareas (ejecutores notificados:%1 )';es_CO = 'Se ha completado la notificación programada de las nuevas tareas (ejecutores notificados:%1 )';tr = 'Yeni görevlerin planlanmış bildirimi tamamlandı (bildirilen atanan: %1)';it = 'Notifica di routine sui nuovi compiti terminata (esecutori informati: %1)';de = 'Geplante Benachrichtigung über die neuen Aufgaben ist erfüllt (informierte Aufgabenempfänger: %1)'"),
		TasksByPerformers.Rows.Count()));
	
EndProcedure

// Runs notification mailing to task assignees and authors on overdue tasks.
// Notifications are sent using email on behalf of the system account.
// If a task is sent to a role with no assignee, a new task to the persons responsible for role 
// setting is created.
//
// Also it is the TaskMonitoring scheduled job handler.
//
Procedure CheckTasks() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.TaskMonitoring);
	ErrorDetails = "";
	
	If NOT SystemEmailAccountIsSetUp(ErrorDetails) Then
		MessageKind = NStr("ru = 'Бизнес-процессы и задачи. Мониторинг задач.'; en = 'Business processes and tasks. Task monitoring.'; pl = 'Procesy biznesowe i zadania. Monitorowanie zadań.';es_ES = 'Procesos de negocio y tareas. Control de tareas';es_CO = 'Procesos de negocio y tareas. Control de tareas';tr = 'İş süreçleri ve görevler. Görev takibi.';it = 'Processi e obiettivi aziendali. Monitoraggio degli obiettivi.';de = 'Geschäftsprozesse und Aufgaben. Aufgabenüberwachung.'", CommonClientServer.DefaultLanguageCode());
		WriteLogEvent(MessageKind, EventLogLevel.Error,
			Metadata.ScheduledJobs.TaskMonitoring,, ErrorDetails);
			Return;
	EndIf;

	OverdueTasks = SelectOverdueTasks();
	If OverdueTasks.Count() = 0 Then
		Return;
	EndIf;
		
	MessageSetByAddressees = SelectOverdueTasksPerformers(OverdueTasks);
	For Each EmailFromSet In MessageSetByAddressees Do
		SendNotificationAboutOverdueTasks(EmailFromSet);
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Updates infobase.

// Prepares the first portion of objects for deferred access rights processing.
// It is intended to call from deferred update handlers on changing the logic of generating access value sets.
//
// Parameters:
//   Parameters     - Structure - structure of deferred update handler parameters.
//   BusinessProcess - MetadataObject.BusinessProcess - business process metadata whose access value 
//                   sets are to be updated.
//   ProcedureName  - String - a name of procedure of deferred update handler for the event log.
//   PortionSize  - Number  - a number of objects processed in one call.
//
Procedure StartUpdateAccessValuesSetsPortion(Parameters, BusinessProcess, ProcedureName, BatchSize = 1000) Export
	
	If Parameters.ExecutionProgress.TotalObjectCount = 0 Then
		Query = New Query;
		Query.Text =
			"SELECT
			|	COUNT(TableWithAccessValueSets.Ref) AS Count,
			|	MAX(TableWithAccessValueSets.Date) AS Date
			|FROM
			|	%1 AS TableWithAccessValueSets";
		
		Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, BusinessProcess.FullName());
		QueryResult = Query.Execute().Unload();
		Parameters.ExecutionProgress.TotalObjectCount = QueryResult[0].Count;
		
		If Not Parameters.Property("InitialDataForProcessing") Then
			Parameters.Insert("InitialDataForProcessing", QueryResult[0].Date);
		EndIf;
		
	EndIf;
	
	If Not Parameters.Property("ObjectsWithIssues") Then
		Parameters.Insert("ObjectsWithIssues", New Array);
	EndIf;
	
	If Not Parameters.Property("InitialRefForProcessing") Then
		Parameters.Insert("InitialRefForProcessing", Common.ObjectManagerByFullName(BusinessProcess.FullName()).EmptyRef());
	EndIf;
	
	Query = New Query;
	Query.Text =
		"SELECT TOP %1
		|	TableWithAccessValueSets.Ref AS Ref,
		|	TableWithAccessValueSets.Date AS Date
		|FROM
		|	%2 AS TableWithAccessValueSets
		|WHERE TableWithAccessValueSets.Date <= &InitialDataForProcessing
		|   AND TableWithAccessValueSets.Ref > &InitialRefForProcessing
		|ORDER BY 
		|   Date DESC,
		|   Ref";
	
	Query.Text = StringFunctionsClientServer.SubstituteParametersToString(Query.Text, Format(BatchSize, "NG=0"), BusinessProcess.FullName());
	Query.SetParameter("InitialDataForProcessing", Parameters.InitialDataForProcessing);
	Query.SetParameter("InitialRefForProcessing", Parameters.InitialRefForProcessing);
	
	QueryResult = Query.Execute().Unload();
	ObjectsToProcess = QueryResult.UnloadColumn("Ref");
	Parameters.Insert("ObjectsToProcess", ObjectsToProcess);
	
	CommonClientServer.SupplementArray(Parameters.ObjectsToProcess, Parameters.ObjectsWithIssues);
	Parameters.ObjectsWithIssues.Clear();
	
	Parameters.ProcessingCompleted = ObjectsToProcess.Count() = 0 
		Or QueryResult[0].Ref = Parameters.InitialRefForProcessing;
	If Not Parameters.ProcessingCompleted Then
		
		If Not Parameters.Property("BusinessProcess") Then
			Parameters.Insert("BusinessProcess", BusinessProcess);
		EndIf;
		
		If Not Parameters.Property("ObjectsProcessed") Then
			Parameters.Insert("ObjectsProcessed", 0);
		EndIf;
		
		If Not Parameters.Property("ProcedureName") Then
			Parameters.Insert("ProcedureName", ProcedureName);
		EndIf;
		
		Parameters.InitialDataForProcessing = QueryResult[QueryResult.Count() - 1].Date;
		Parameters.InitialRefForProcessing = QueryResult[QueryResult.Count() - 1].Ref;
	EndIf;
	
EndProcedure

// Complete processing of the first portion of objects for deferred access right processing.
// It is intended to call from deferred update handlers on changing the logic of generating access value sets.
//
// Parameters:
//   Parameters     - Structure - structure of deferred update handler parameters.
//
Procedure FinishUpdateAccessValuesSetsPortions(Parameters) Export
	
	Parameters.ExecutionProgress.ProcessedObjectsCount = Parameters.ExecutionProgress.ProcessedObjectsCount + Parameters.ObjectsProcessed;
	If Parameters.ObjectsProcessed = 0 Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Процедуре ""%1"" не удалось обновить права доступа для некоторых объектов (пропущены): %1'; en = 'Procedure ""%1"" cannot update access rights for some objects (skipped): %1'; pl = 'Procedura ""%1"" nie może zaktualizować praw dostępu dla kilku obiektów (pominięto): %1';es_ES = 'El procedimiento ""%1"" no puede actualizar los derechos de acceso de algunos objetos (saltados): %1';es_CO = 'El procedimiento ""%1"" no puede actualizar los derechos de acceso de algunos objetos (saltados): %1';tr = '""%1"" prosedürü bazı nesneler için erişim haklarını güncelleyemiyor (atlandı): %1';it = 'Alla procedura ""%1"" non è stato possibile aggiornare i permessi di accesso per alcuni oggetti (ignorati): %1';de = 'Der Vorgang ""%1"" kann die Zugriffsrechte zu mehreren Objekten nicht aktualisieren (übersprungen): %1'"), 
				Parameters.ProcedureName, Parameters.ObjectsWithIssues.Count());
		Raise MessageText;
	EndIf;
	
	WriteLogEvent(InfobaseUpdate.EventLogEvent(), EventLogLevel.Information,
		Parameters.BusinessProcess,, 
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Процедура ""%1"" обновила права доступа для очередной порции объектов: %2'; en = 'The ""%1"" procedure has updated access rights for objects: %2'; pl = 'Procedura ""%1"" zaktualizowała prawa dostępu dla obiektów: %2';es_ES = 'El procedimiento ""%1"" ha actualizado los derechos de acceso a los objetos: %2';es_CO = 'El procedimiento ""%1"" ha actualizado los derechos de acceso a los objetos: %2';tr = '""%1"" Prosedürü nesneler için erişim haklarını güncelledi: %2';it = 'La procedura ""%1"" ha aggiornato i permessi d''accesso per un altro gruppo di oggetti: %2';de = 'Der Vorgang ""%1"" hat die Zugriffsrechte für die folgenden Objekte aktualisiert: %2'"), 
			Parameters.ProcedureName, Parameters.ObjectsProcessed));
	
	// Clearing temporary parameters which are not required to save between the sessions.
	Parameters.Delete("ObjectsToProcess");
	Parameters.Delete("ProcedureName");
	Parameters.Delete("BusinessProcess");
	Parameters.Delete("ObjectsProcessed");
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "1.0.2.2";
	Handler.InitialFilling = True;
	Handler.Procedure = "BusinessProcessesAndTasksServer.FillEmployeeResponsibleForCompletionControl";
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.Version              = "2.3.3.70";
	Handler.Procedure           = "BusinessProcessesAndTasksServer.UpdateScheduledJobUsage";
	Handler.SharedData         = False;
	Handler.ExecutionMode     = "Seamless";
	
	Handler = Handlers.Add();
	Handler.InitialFilling = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "BusinessProcessesAndTasksServer.FillPredefinedItemDescriptionAllAddressingObjects";
	
EndProcedure

// See SSLSubsystemsIntegration.OnDeterminePerformersGroups. 
Procedure OnDeterminePerformersGroups(TempTablesManager, ParameterContent, ParameterValue, NoPerformerGroups) Export
	
	NoPerformerGroups = False;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	If ParameterContent = "PerformersGroups" Then
		
		Query.SetParameter("PerformersGroups", ParameterValue);
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformersGroup AS PerformersGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupsTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TaskPerformers.TaskPerformersGroup IN(&PerformersGroups)";
		
	ElsIf ParameterContent = "Performers" Then
		
		Query.SetParameter("Performers", ParameterValue);
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformersGroup AS PerformersGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupsTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TaskPerformers.Performer IN(&Performers)";
		
	Else
		Query.Text =
		"SELECT DISTINCT
		|	TaskPerformers.TaskPerformersGroup AS PerformersGroup,
		|	TaskPerformers.Performer AS User
		|INTO PerformerGroupsTable
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers";
	EndIf;
	
	Query.Execute();
	
EndProcedure

// See ImportDataFromFileOverridable.OnDefineCatalogsForDataImport. 
Procedure OnDefineCatalogsForDataImport(CatalogsToImport) Export
	
	// Cannot import to the TaskPerformersGroups catalog.
	TableRow = CatalogsToImport.Find(Metadata.Catalogs.TaskPerformersGroups.FullName(), "FullName");
	If TableRow <> Undefined Then 
		CatalogsToImport.Delete(TableRow);
	EndIf;
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.BusinessProcesses.Job.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.Tasks.PerformerTask.FullName(), "AttributesToEditInBatchProcessing");
	Objects.Insert(Metadata.ChartsOfCharacteristicTypes.TaskAddressingObjects.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.TaskPerformersGroups.FullName(), "AttributesToSkipInBatchProcessing");
	Objects.Insert(Metadata.Catalogs.PerformerRoles.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See ScheduledJobsOverridable.OnDefineScheduledJobsSettings. 
Procedure OnDefineScheduledJobSettings(Settings) Export
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.TaskMonitoring;
	Setting.FunctionalOption = Metadata.FunctionalOptions.UseBusinessProcessesAndTasks;
	Setting.UseExternalResources = True;
	
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.NewPerformerTaskNotifications;
	Setting.FunctionalOption = Metadata.FunctionalOptions.UseBusinessProcessesAndTasks;
	Setting.UseExternalResources = True;
	
	Setting = Settings.Add();
	Setting.ScheduledJob = Metadata.ScheduledJobs.StartDeferredProcesses;
	Setting.FunctionalOption = Metadata.FunctionalOptions.UseBusinessProcessesAndTasks;

EndProcedure

// See CommonOverridable.OnAddRefsSearchExceptions. 
Procedure OnAddReferenceSearchExceptions(RefSearchExclusions) Export
	
	RefSearchExclusions.Add(Metadata.InformationRegisters.TaskPerformers.FullName());
	RefSearchExclusions.Add(Metadata.InformationRegisters.BusinessProcessesData.FullName());
	
EndProcedure

// See JobsQueueOverridable.OnGetTemplatesList. 
Procedure OnGetTemplateList(JobTemplates) Export
	
	JobTemplates.Add("TaskMonitoring");
	JobTemplates.Add("NewPerformerTaskNotifications");
	
EndProcedure

// See UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates. 
Procedure OnFillSourceAttributesListWithReminderDates(Source, AttributesWithDates) Export
	
	If TypeOf(Source) = Type("TaskRef.PerformerTask") Then
		AttributesWithDates.Clear();
		AttributesWithDates.Add("DueDate"); 
		AttributesWithDates.Add("StartDate"); 
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessRightsDependencies. 
Procedure OnFillAccessRightsDependencies(RightsDependencies) Export
	
	// An assignee task can be changed when a business process is read-only. That is why it is not 
	// required to check edit rights or editing restrictions. Check read rights and reading restrictions.
	// 
	
	Row = RightsDependencies.Add();
	Row.SubordinateTable = "Task.PerformerTask";
	Row.LeadingTable     = "BusinessProcess.Job";
	
EndProcedure

// See AccessManagementOverridable.OnFillMetadataObjectsAccessRestrictionsKinds. 
Procedure OnFillMetadataObjectsAccessRestrictionKinds(Details) Export
	
	Details = Details 
		+ "
		|BusinessProcess.Job.Read.Users
		|BusinessProcess.Job.Update.Users
		|Task.PerformerTask.Read.Object.BusinessProcess.Job
		|Task.PerformerTask.Read.Users
		|Task.PerformerTask.Update.Users
		|InformationRegister.BusinessProcessesData.Read.Object.BusinessProcess.Job
		|";
	
EndProcedure

// See AccessManagementOverridable.OnFillAccessKinds. 
Procedure OnFillAccessKinds(AccessKinds) Export
	
	AccessKind = AccessKinds.Find("Users", "Name");
	If AccessKind <> Undefined Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.AddExtraAccessKindTypes(AccessKind,
			Type("CatalogRef.TaskPerformersGroups"));
	EndIf;
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.InformationRegisters.BusinessProcessesData, True);
	Lists.Insert(Metadata.InformationRegisters.TaskPerformers, True);
	Lists.Insert(Metadata.BusinessProcesses.Job, True);
	Lists.Insert(Metadata.Tasks.PerformerTask, True);
	
EndProcedure

// See ReportsOptionsOverridable.CustomizeReportsOptions. 
Procedure OnSetUpReportsOptions(Settings) Export
	ModuleReportsOptions = Common.CommonModule("ReportsOptions");
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.BusinessProcesses);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.HungTasks);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.Jobs);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.Tasks);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.ExpiringTasksOnDate);
	ModuleReportsOptions.CustomizeReportInManagerModule(Settings, Metadata.Reports.OverdueTasks);
EndProcedure

// See ToDoListOverridable.OnDetermineToDoListHandlers 
Procedure OnFillToDoList(ToDoList) Export
	
	ModuleToDoListServer = Common.CommonModule("ToDoListServer");
	If Not AccessRight("Edit", Metadata.Tasks.PerformerTask)
		Or ModuleToDoListServer.UserTaskDisabled("PerformerTasks") Then
		Return;
	EndIf;
	
	If Not GetFunctionalOption("UseBusinessProcessesAndTasks") Then
		Return;
	EndIf;
	
	PerformerTaskQuantity = PerformerTaskQuantity();
	
	// This procedure is only called when To-do list subsystem is available. Therefore, the subsystem 
	// availability check is redundant.
	Sections = ModuleToDoListServer.SectionsForObject(Metadata.Tasks.PerformerTask.FullName());
	
	If UsersClientServer.IsExternalUserSession()
		AND Sections.Count() = 0 Then
		Sections.Add(Metadata.Tasks.PerformerTask);
	EndIf;
	
	For Each Section In Sections Do
		
		MyTasksID = "PerformerTasks" + StrReplace(Section.FullName(), ".", "");
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = MyTasksID;
		ToDoItem.HasUserTasks       = PerformerTaskQuantity.Total > 0;
		ToDoItem.Presentation  = NStr("ru = 'Мои задачи'; en = 'My tasks'; pl = 'Moje zadania';es_ES = 'Mis tareas';es_CO = 'Mis tareas';tr = 'Görevlerim';it = 'I miei incarichi';de = 'Meine Aufgaben'");
		ToDoItem.Count     = PerformerTaskQuantity.Total;
		ToDoItem.Form          = "Task.PerformerTask.Form.MyTasks";
		FilterValue		= New Structure("Executed", False);
		ToDoItem.FormParameters = New Structure("Filter", FilterValue);
		ToDoItem.Owner       = Section;
		
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "PerformerTasksOverdue";
		ToDoItem.HasUserTasks       = PerformerTaskQuantity.Overdue > 0;
		ToDoItem.Presentation  = NStr("ru = 'не в срок'; en = 'overdue'; pl = 'zaległe';es_ES = 'vencido';es_CO = 'vencido';tr = 'vadesi geçmiş';it = 'In ritardo';de = 'überfällig'");
		ToDoItem.Count     = PerformerTaskQuantity.Overdue;
		ToDoItem.Important         = True;
		ToDoItem.Owner       = MyTasksID; 
		
		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "PerformerTasksForToday";
		ToDoItem.HasUserTasks       = PerformerTaskQuantity.ForToday > 0;
		ToDoItem.Presentation  = NStr("ru = 'сегодня'; en = 'today'; pl = 'dzisiaj';es_ES = 'hoy';es_CO = 'hoy';tr = 'bugün';it = 'oggi';de = 'Heute'");
		ToDoItem.Count     = PerformerTaskQuantity.ForToday;
		ToDoItem.Owner       = MyTasksID; 

		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "PerformerTasksForWeek";
		ToDoItem.HasUserTasks       = PerformerTaskQuantity.ForWeek > 0;
		ToDoItem.Presentation  = NStr("ru = 'на этой неделе'; en = 'this week'; pl = 'w bieżącym tygodniu';es_ES = 'esta semana';es_CO = 'esta semana';tr = 'bu hafta';it = 'questa settimana';de = 'Diese Woche'");
		ToDoItem.Count     = PerformerTaskQuantity.ForWeek;
		ToDoItem.Owner       = MyTasksID; 

		ToDoItem = ToDoList.Add();
		ToDoItem.ID  = "PerformerTasksForNextWeek";
		ToDoItem.HasUserTasks       = PerformerTaskQuantity.ForNextWeek > 0;
		ToDoItem.Presentation  = NStr("ru = 'на следующей неделе'; en = 'next week'; pl = 'w następnym tygodniu';es_ES = 'próxima semana';es_CO = 'próxima semana';tr = 'gelecek hafta';it = 'settimana successiva';de = 'Nächste Woche'");
		ToDoItem.Count     = PerformerTaskQuantity.ForNextWeek > 0;
		ToDoItem.Owner       = MyTasksID; 
	EndDo;
	
EndProcedure

// See JobsQueueOverridable.OnDefineHandlersAliases. 
Procedure OnDefineHandlerAliases(NameAndAliasMap) Export
	
	NameAndAliasMap.Insert("BusinessProcessesAndTasksEvents.StartDeferredProcesses");
	
EndProcedure

// See InfobaseUpdateOverridable.OnDefineSettings 
Procedure OnDefineObjectsWithInitialFilling(Objects) Export
	
	Objects.Add(Metadata.Catalogs.PerformerRoles);
	Objects.Add(Metadata.ChartsOfCharacteristicTypes.TaskAddressingObjects);
	
EndProcedure

// See GenerationOverridable.OnDefineObjectsWithCreateOnBasisCommands. 
Procedure OnDefineObjectsWithCreationBasedOnCommands(Objects) Export
	
	Objects.Add(Metadata.BusinessProcesses.Job);
	Objects.Add(Metadata.Tasks.PerformerTask);
	
EndProcedure

// See GenerationOverridable.OnAddGenerateCommands. 
Procedure OnAddGenerationCommands(Object, GenerationCommands, Parameters, StandardProcessing) Export
	
	If Object = Metadata.Catalogs["Users"] Then
		BusinessProcesses.Job.AddGenerateCommand(GenerationCommands);
	EndIf;
	
	If Common.SubsystemExists("StandardSubsystems.FilesOperations") Then
		If Object = Metadata.Catalogs["Files"] Then
			BusinessProcesses.Job.AddGenerateCommand(GenerationCommands);
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Monitoring and management control of task completion.

Function ExportPerformers(QueryText, MainAddressingObjectRef, AdditionalAddressingObjectRef)
	
	Query = New Query(QueryText);
	
	If ValueIsFilled(AdditionalAddressingObjectRef) Then
		Query.SetParameter("AAO", AdditionalAddressingObjectRef);
	EndIf;
	
	If ValueIsFilled(MainAddressingObjectRef) Then
		Query.SetParameter("MAO", MainAddressingObjectRef);
	EndIf;
	
	Return Query.Execute().Unload();
	
EndFunction

Function FindPerformersByRoles(Val Task, Val BaseQueryText)
	
	UsersList = New Array;
	
	MAO = Task.MainAddressingObject;
	AAO = Task.AdditionalAddressingObject;
	
	If ValueIsFilled(AAO) Then
		QueryText = BaseQueryText + " AND TaskPerformers.MainAddressingObject = &MAO
		                                     |AND TaskPerformers.AdditionalAddressingObject = &AAO";
	ElsIf ValueIsFilled(MAO) Then
		QueryText = BaseQueryText 
			+ " AND TaskPerformers.MainAddressingObject = &MAO
		    |AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
	Else
		QueryText = BaseQueryText 
			+ " AND (TaskPerformers.MainAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|    OR TaskPerformers.MainAddressingObject = Undefined)
		    |AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
	EndIf;
	
	RetrievedPerformerData = ExportPerformers(QueryText, MAO, AAO);
	
	// If the main and additional addressing objects are not specified in the task.
	If Not ValueIsFilled(AAO) AND Not ValueIsFilled(MAO) Then
		For Each RetrievedDataItem In RetrievedPerformerData Do
			UsersList.Add(RetrievedDataItem.Performer);
		EndDo;
		
		Return UsersList;
	EndIf;
	
	If RetrievedPerformerData.Count() = 0 AND ValueIsFilled(AAO) Then
		QueryText = BaseQueryText + " AND TaskPerformers.MainAddressingObject = &MAO
			|AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
		RetrievedPerformerData = ExportPerformers(QueryText, MAO, Undefined);
	EndIf;
	
	If RetrievedPerformerData.Count() = 0 Then
		QueryText = BaseQueryText + " AND (TaskPerformers.MainAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|    OR TaskPerformers.MainAddressingObject = Undefined)
			|AND (TaskPerformers.AdditionalAddressingObject = VALUE(ChartOfCharacteristicTypes.TaskAddressingObjects.EmptyRef)
			|   OR TaskPerformers.AdditionalAddressingObject = Undefined)";
		RetrievedPerformerData = ExportPerformers(QueryText, Undefined, Undefined);
	EndIf;
	
	For Each RetrievedDataItem In RetrievedPerformerData Do
		UsersList.Add(RetrievedDataItem.Performer);
	EndDo;
	
	Return UsersList;
	
EndFunction

Function FindPersonsResponsibleForRolesAssignment(Val Task)
	
	BaseQueryText = "SELECT DISTINCT ALLOWED TaskPerformers.Performer
	                      |FROM
	                      |	InformationRegister.TaskPerformers AS TaskPerformers, Catalog.PerformerRoles AS PerformerRoles
	                      |WHERE
	                      |	TaskPerformers.PerformerRole = PerformerRoles.Ref
	                      |AND
	                      |	PerformerRoles.Ref = VALUE(Catalog.PerformerRoles.EmployeeResponsibleForTasksManagement)";
						  
	ResponsiblePersons = FindPerformersByRoles(Task, BaseQueryText);
	Return ResponsiblePersons;
	
EndFunction

Function SelectTasksPerformers(Val Task)
	
	QueryText = "SELECT DISTINCT ALLOWED
				  |	TaskPerformers.Performer AS Performer
				  |FROM
				  |	InformationRegister.TaskPerformers AS TaskPerformers
				  |WHERE
				  |	TaskPerformers.PerformerRole = &PerformerRole
				  |	AND TaskPerformers.MainAddressingObject = &MainAddressingObject
				  |	AND TaskPerformers.AdditionalAddressingObject = &AdditionalAddressingObject";
				  
	Query = New Query(QueryText);
	Query.Parameters.Insert("PerformerRole", Task.PerformerRole);
	Query.Parameters.Insert("MainAddressingObject", Task.MainAddressingObject);
	Query.Parameters.Insert("AdditionalAddressingObject", Task.AdditionalAddressingObject);
	Performers = Query.Execute().Unload();
	Return Performers;
	
EndFunction

Procedure FindMessageAndAddText(Val MessageSetByAddressees,
                                  Val EmailRecipient,
                                  Val MessageRecipientPresentation,
                                  Val EmailText,
                                  Val EmailType)
	
	FilterParameters = New Structure("EmailType, MailAddress", EmailType, EmailRecipient);
	EmailParametersRow = MessageSetByAddressees.FindRows(FilterParameters);
	If EmailParametersRow.Count() = 0 Then
		EmailParametersRow = Undefined;
	Else
		EmailParametersRow = EmailParametersRow[0];
	EndIf;
	
	If EmailParametersRow = Undefined Then
		EmailParametersRow = MessageSetByAddressees.Add();
		EmailParametersRow.MailAddress = EmailRecipient;
		EmailParametersRow.EmailText = "";
		EmailParametersRow.TaskCount = 0;
		EmailParametersRow.EmailType = EmailType;
		EmailParametersRow.Recipient = MessageRecipientPresentation;
	EndIf;
	
	If ValueIsFilled(EmailParametersRow.EmailText) Then
		EmailParametersRow.EmailText =
		        EmailParametersRow.EmailText + Chars.LF
		        + "------------------------------------"  + Chars.LF;
	EndIf;
	
	EmailParametersRow.TaskCount = EmailParametersRow.TaskCount + 1;
	EmailParametersRow.EmailText = EmailParametersRow.EmailText + EmailText;
	
EndProcedure

Function SelectOverdueTasks()
	
	QueryText = 
		"SELECT ALLOWED
		|	PerformerTask.Ref AS Ref,
		|	PerformerTask.DueDate AS DueDate,
		|	PerformerTask.Performer AS Performer,
		|	PerformerTask.PerformerRole AS PerformerRole,
		|	PerformerTask.MainAddressingObject AS MainAddressingObject,
		|	PerformerTask.AdditionalAddressingObject AS AdditionalAddressingObject,
		|	PerformerTask.Author AS Author,
		|	PerformerTask.Details AS Details
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.DeletionMark = FALSE
		|	AND PerformerTask.Executed = FALSE
		|	AND PerformerTask.DueDate <= &Date
		|	AND PerformerTask.BusinessProcessState <> VALUE(Enum.BusinessProcessStates.Stopped)";
	
	DueDate = EndOfDay(CurrentSessionDate());

	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("Date", DueDate);
	
	OverdueTasks = Query.Execute().Unload();
	
	Index = OverdueTasks.Count() - 1;
	While Index > 0 Do
		OverdueTask = OverdueTasks[Index];
		If NOT ValueIsFilled(OverdueTask.Performer) AND BusinessProcessesAndTasksServerCall.IsHeadTask(OverdueTask.Ref) Then
			OverdueTasks.Delete(OverdueTask);
		EndIf;
		Index = Index - 1;
	EndDo;
	
	Return OverdueTasks;
	
EndFunction

Function SelectOverdueTasksPerformers(OverdueTasks)
	
	MessageSetByAddressees = New ValueTable;
	MessageSetByAddressees.Columns.Add("MailAddress");
	MessageSetByAddressees.Columns.Add("EmailText");
	MessageSetByAddressees.Columns.Add("TaskCount");
	MessageSetByAddressees.Columns.Add("EmailType");
	MessageSetByAddressees.Columns.Add("Recipient");
	MessageSetByAddressees.Indexes.Add("EmailType, MailAddress");
	
	For Each OverdueTasksItem In OverdueTasks Do
		OverdueTask = OverdueTasksItem.Ref;
		
		EmailText = GenerateTaskPresentation(OverdueTasksItem);
		// Is the task addressed to the assignee personally?
		If ValueIsFilled(OverdueTask.Performer) Then
			EmailRecipient = EmailAddress(OverdueTask.Performer);
			FindMessageAndAddText(MessageSetByAddressees, EmailRecipient, OverdueTask.Performer, EmailText, "ToPerformer");
			EmailRecipient = EmailAddress(OverdueTask.Author);
			FindMessageAndAddText(MessageSetByAddressees, EmailRecipient, OverdueTask.Author, EmailText, "ToAuthor");
		Else
			Performers = SelectTasksPerformers(OverdueTask);
			Coordinators = FindPersonsResponsibleForRolesAssignment(OverdueTask);
			// Is there at least one assignee for the task role addressing dimensions?
			If Performers.Count() > 0 Then
				// The assignee does not execute the tasks.
				For Each Performer In Performers Do
					EmailRecipient = EmailAddress(Performer.Performer);
					FindMessageAndAddText(MessageSetByAddressees, EmailRecipient, Performer.Performer, EmailText, "ToPerformer");
				EndDo;
			Else	// There is no assignee to execute the task.
				CreateTaskForSettingRoles(OverdueTask, Coordinators);
			EndIf;
			
			For Each Coordinator In Coordinators Do
				EmailRecipient = EmailAddress(Coordinator);
				FindMessageAndAddText(MessageSetByAddressees, EmailRecipient, Coordinator, EmailText, "ToCoordinator");
			EndDo;
		EndIf;
	EndDo;
	
	Return MessageSetByAddressees;
	
EndFunction

Procedure SendNotificationAboutOverdueTasks(EmailFromSet)
	
	If IsBlankString(EmailFromSet.MailAddress) Then
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Уведомление не было отправлено, так как у пользователя %1 не задан адрес электронной почты.'; en = 'Cannot send the notification as user %1 does not have email address specified.'; pl = 'Nie można wysłać powiadomienia ponieważ użytkownik%1 nie ma określonego adresu email.';es_ES = 'No se puede enviar la notificación porque el usuario%1 no tiene una dirección de correo electrónico especificada.';es_CO = 'No se puede enviar la notificación porque el usuario%1 no tiene una dirección de correo electrónico especificada.';tr = 'Bildirim gönderilemiyor çünkü %1 kullanıcısı e-posta adresini belirtmedi.';it = 'La notifica non è stata inviata perché l''utente %1 non aveva un indirizzo email indicato.';de = 'Kann keine Nachricht senden denn der Benutzer %1 hat keine E-Mail-Adresse angegeben.'"), 
			EmailFromSet.Recipient);
		WriteLogEvent(NStr("ru = 'Бизнес-процессы и задачи. Уведомление о просроченных задачах'; en = 'Business processes and tasks.Overdue tasks notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o zaległych zadaniach';es_ES = 'Procesos de negocio y tareas. Notificación de tareas atrasadas';es_CO = 'Procesos de negocio y tareas. Notificación de tareas atrasadas';tr = 'İş süreçleri ve görevler. Vadesi geçmiş görev bildirimi';it = 'Processi aziendali e compiti. Notifica sui compiti scaduti';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die überfälligen Aufgaben'", 
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Information,,, MessageText);
		Return;
	EndIf;
	
	EmailParameters = New Structure;
	EmailParameters.Insert("SendTo", EmailFromSet.MailAddress);
	If EmailFromSet.EmailType = "Performer" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не выполненные в срок задачи:
			| 
			|%1'; 
			|en = 'Overdue tasks:
			|
			|%1'; 
			|pl = 'Zaległe zadania:
			|
			|%1';
			|es_ES = 'Tareas atrasadas: 
			|
			|%1';
			|es_CO = 'Tareas atrasadas: 
			|
			|%1';
			|tr = 'Vadesi geçmiş görevler: 
			|
			|%1';
			|it = 'Obiettivi non completati in tempo:
			| 
			|%1';
			|de = 'Überfällige Aufgaben:
			|
			|%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		EmailSubjectText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Не выполненные в срок задачи (%1)'; en = 'Overdue tasks (%1)'; pl = 'Zaległe zadania (%1)';es_ES = 'Tareas atrasadas (%1)';es_CO = 'Tareas atrasadas (%1)';tr = 'Vadesi geçmiş görevler (%1)';it = 'Obiettivi non completati in tempo (%1)';de = 'Überfällige Aufgaben (%1)'"),
			String(EmailFromSet.TaskCount ));
		EmailParameters.Insert("Subject", EmailSubjectText);
	ElsIf EmailFromSet.EmailType = "ToAuthor" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'По введенным задачам прошел крайний срок:
			| 
			|%1'; 
			|en = 'Deadline for specified tasks expired:
			|
			|%1'; 
			|pl = 'Upłynął termin dla określonych zadań:
			|
			|%1';
			|es_ES = 'Ha vencido la fecha de entrega de las tareas especificadas:
			|
			|%1';
			|es_CO = 'Ha vencido la fecha de entrega de las tareas especificadas:
			|
			|%1';
			|tr = 'Belirtilen görevlerin bitiş tarihi geçti: 
			|
			|%1';
			|it = 'Il termine massimo dei obiettivi immessi è stato superato:
			| 
			|%1';
			|de = 'Frist für die angegebenen Aufgaben verfallen:
			|
			|%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		EmailSubjectText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'По задачам истек контрольный срок (%1)'; en = 'Task deadline expired (%1)'; pl = 'Upłynął termin zadania (%1)';es_ES = 'La fecha de entrega de la tarea expiró (%1)';es_CO = 'La fecha de entrega de la tarea expiró (%1)';tr = 'Görevin bitiş tarihi geçti (%1)';it = 'Il termine massimo degli obiettivi è scaduto (%1)';de = 'Aufgabenfrist verfallen (%1)'"),
			String(EmailFromSet.TaskCount));
		EmailParameters.Insert("Subject", EmailSubjectText);
	ElsIf EmailFromSet.EmailType = "ToCoordinator" Then
		MessageBodyText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Прошел крайний срок по задачам:
			| 
			|%1'; 
			|en = 'Deadline for tasks has passed:
			| 
			|%1'; 
			|pl = 'Termin dla zadania minął:
			| 
			|%1';
			|es_ES = 'Ha pasado la fecha límite para las tareas:
			|
			|%1';
			|es_CO = 'Ha pasado la fecha límite para las tareas:
			|
			|%1';
			|tr = 'Görevlerin bitiş tarihi geçti: 
			| 
			|%1';
			|it = 'È stato superato il termine massimo degli obiettivi:
			| 
			|%1';
			|de = 'Die Frist für die Aufgaben ist vorbei:
			|
			|%1'"), EmailFromSet.EmailText);
		EmailParameters.Insert("Body", MessageBodyText);
		
		EmailSubjectText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Истек контрольный срок задач (%1)'; en = 'Expired deadline for the task (%1)'; pl = 'Upłyną termin dla zadania (%1)';es_ES = 'La fecha límite para la tarea ha expirado (%1)';es_CO = 'La fecha límite para la tarea ha expirado (%1)';tr = 'Görevin bitiş tarihi geçti (%1)';it = 'Deadline scaduta per l''incarico (%1)';de = 'Verfallene Frist für die Aufgabe (%1)'"),
			String(EmailFromSet.TaskCount));
		EmailParameters.Insert("Subject", EmailSubjectText);
	EndIf;
	
	MessageText = "";
	
	ModuleEmail = Common.CommonModule("EmailOperations");
	Try
		ModuleEmail.SendEmailMessage(
			ModuleEmail.SystemAccount(), EmailParameters);
	Except
		ErrorDetails = DetailErrorDescription(ErrorInfo());
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка при отправке уведомления о просроченных задачах: %1.'; en = 'Error sending overdue task notification: %1.'; pl = 'Błąd podczas wysyłania powiadomienia o zaległym zadaniu: %1.';es_ES = 'Error al enviar la notificación de la tarea atrasada:%1.';es_CO = 'Error al enviar la notificación de la tarea atrasada:%1.';tr = 'Vadesi geçmiş görev bildirimi gönderirken hata oluştu: %1.';it = 'Errore di invio di notifica dell''incarico scaduta: %1.';de = 'Fehler beim Senden der Benachrichtigung über überfällige Aufgabe: %1.'"),
			ErrorDetails);
		EventImportanceLevel = EventLogLevel.Error;
	EndTry;
	
	If IsBlankString(MessageText) Then
		If EmailParameters.SendTo.Count() > 0 Then
			SendTo = ? (IsBlankString(EmailParameters.SendTo[0].Presentation),
						EmailParameters.SendTo[0].Address,
						EmailParameters.SendTo[0].Presentation + " <" + EmailParameters.SendTo[0].Address + ">");
		EndIf;
		
		MessageText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Уведомление о просроченных задачах успешно отправлено на адрес %1.'; en = 'Overdue task notification sent to %1.'; pl = 'Powiadomienie o zaległym zadaniu wysłano do %1.';es_ES = 'La notificación de la tarea atrasada se envió a%1.';es_CO = 'La notificación de la tarea atrasada se envió a%1.';tr = 'Vadesi geçmiş görev bildirimi %1''e gönderildi.';it = 'Notifica sugli obiettivi scaduti inviata correttamente all''indirizzo %1.';de = 'Benachrichtigung über überfällige Aufgabe gesendet an %1.'"), SendTo);
		EventImportanceLevel = EventLogLevel.Information;
	EndIf;
	
	WriteLogEvent(NStr("ru = 'Бизнес-процессы и задачи. Уведомление о просроченных задачах'; en = 'Business processes and tasks.Overdue tasks notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o zaległych zadaniach';es_ES = 'Procesos de negocio y tareas. Notificación de tareas atrasadas';es_CO = 'Procesos de negocio y tareas. Notificación de tareas atrasadas';tr = 'İş süreçleri ve görevler. Vadesi geçmiş görev bildirimi';it = 'Processi aziendali e compiti. Notifica sui compiti scaduti';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die überfälligen Aufgaben'",
		CommonClientServer.DefaultLanguageCode()), 
		EventImportanceLevel,,, MessageText);
		
EndProcedure

Procedure CreateTaskForSettingRoles(TaskRef, EmployeesResponsible)
	
	For Each EmployeeResponsible In EmployeesResponsible Do
		TaskObject = Tasks.PerformerTask.CreateTask();
		TaskObject.Date = CurrentSessionDate();
		TaskObject.Importance = Enums.TaskImportanceOptions.High;
		TaskObject.Performer = EmployeeResponsible;
		TaskObject.Topic = TaskRef;

		TaskObject.Details = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Задача не может быть исполнена, так как у роли не задано ни одного исполнителя:
		    |%1'; 
		    |en = 'The task cannot be completed as no assignees are assigned for the role:
		    |%1'; 
		    |pl = 'Zadanie nie będzie zakończone ponieważ nie przypisano wykonawców dla roli:
		    |%1';
		    |es_ES = 'La tarea no puede ser completada ya que no se han asignado ejecutores para el rol:
		    |%1';
		    |es_CO = 'La tarea no puede ser completada ya que no se han asignado ejecutores para el rol:
		    |%1';
		    |tr = 'Görev tamamlanamaz çünkü göreve atanan olmadı: 
		    |%1';
		    |it = 'L''obiettivo non può essere eseguito, poiché il ruolo non ha alcun esecutore:
		    |%1';
		    |de = 'Die Aufgabe kann nicht erfüllt werden, denn keine Aufgabenempfänger zur Rolle zugeordnet sind:
		    |%1'"), String(TaskRef));
		TaskObject.Description = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Назначить исполнителей: задача не может быть исполнена %1'; en = 'Set assignees: task %1 cannot be executed'; pl = 'Ustaw wykonawców: zadanie %1 nie może być wykonane';es_ES = 'Conjunto de ejecutores: la tarea%1 no puede ser ejecutada';es_CO = 'Conjunto de ejecutores: la tarea%1 no puede ser ejecutada';tr = 'Atanan belirle: %1 görevi gerçekleştirilemez';it = 'Indicare degli esecutori: l''obiettivo non può essere eseguito %1';de = 'Aufgabenempfänger einsetzen: die Aufgabe %1 kann nicht ausgeführt sein'"), String(TaskRef));
		TaskObject.Write();
	EndDo;
	
EndProcedure

Function SelectNewTasksByPerformers(Val DateTimeFrom, Val DateTimeTo)
	
	Query = New Query(
		"SELECT ALLOWED
		|	PerformerTask.Ref AS Ref,
		|	PerformerTask.Number AS Number,
		|	PerformerTask.Date AS Date,
		|	PerformerTask.Description AS Description,
		|	PerformerTask.DueDate AS DueDate,
		|	PerformerTask.Author AS Author,
		|	PerformerTask.Details AS Details,
		|	CASE
		|		WHEN PerformerTask.Performer <> UNDEFINED
		|			THEN PerformerTask.Performer
		|		ELSE TaskPerformers.Performer
		|	END AS Performer,
		|	PerformerTask.PerformerRole AS PerformerRole,
		|	PerformerTask.MainAddressingObject AS MainAddressingObject,
		|	PerformerTask.AdditionalAddressingObject AS AdditionalAddressingObject
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
		|		ON PerformerTask.PerformerRole = TaskPerformers.PerformerRole
		|			AND PerformerTask.MainAddressingObject = TaskPerformers.MainAddressingObject
		|			AND PerformerTask.AdditionalAddressingObject = TaskPerformers.AdditionalAddressingObject
		|WHERE
		|	PerformerTask.Executed = FALSE
		|	AND PerformerTask.Date BETWEEN &DateTimeFrom AND &DateTimeTo
		|	AND PerformerTask.DeletionMark = FALSE
		|	AND (PerformerTask.Performer <> VALUE(Catalog.Users.EmptyRef)
		|			OR TaskPerformers.Performer IS NOT NULL 
		|		AND TaskPerformers.Performer <> VALUE(Catalog.Users.EmptyRef))
		|
		|ORDER BY
		|	Performer,
		|	DueDate DESC
		|TOTALS BY
		|	Performer");
	Query.Parameters.Insert("DateTimeFrom", DateTimeFrom + 1);
	Query.Parameters.Insert("DateTimeTo", DateTimeTo);
	Result = Query.Execute().Unload(QueryResultIteration.ByGroups);
	
	Return Result;
	
EndFunction

Function SendNotificationOnNewTasks(Performer, TasksByPerformer)
	
	RecipientEmailAddress = EmailAddress(Performer);
	If IsBlankString(RecipientEmailAddress) Then
		WriteLogEvent(NStr("ru = 'Бизнес-процессы и задачи.Уведомление о новых задачах'; en = 'Business processes and tasks.New task notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o nowym zadaniu';es_ES = 'Procesos de negocio y tareas. Notificación de nuevas tareas';es_CO = 'Procesos de negocio y tareas. Notificación de nuevas tareas';tr = 'İş süreçleri ve görevler. Yeni görev bildirimi';it = 'Processi aziendali e obiettivi. Notifica sui nuovi obiettivi';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die neue Aufgabe'",
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information,,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Уведомление не отправлено, так как не указан почтовый адрес у пользователя %1.'; en = 'Cannot send a notification as user %1 does not have email address specified.'; pl = 'Nie można wysłać powiadomienia ponieważ użytkownik %1 nie ma określonego adresu email.';es_ES = 'No se puede enviar la notificación porque el usuario%1 no tiene una dirección de correo electrónico especificada.';es_CO = 'No se puede enviar la notificación porque el usuario%1 no tiene una dirección de correo electrónico especificada.';tr = 'Bildirim gönderilemiyor çünkü %1kullanıcısı e-posta adresini belirtmedi.';it = 'La notifica non è stata inviata perché l''utente %1 non aveva un indirizzo email indicato.';de = 'Kann nicht die Benachrichtigung senden, denn der Benutzer %1 hat keine E-Mail-Adresse angegeben.'"), String(Performer)));
		Return False;
	EndIf;
	
	EmailText = "";
	For Each Task In TasksByPerformer.Rows Do
		EmailText = EmailText + GenerateTaskPresentation(Task);
	EndDo;
	EmailSubject = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Направлены задачи - %1'; en = 'Tasks sent- %1'; pl = 'Wysłano zadania- %1';es_ES = 'Tareas enviadas - %1';es_CO = 'Tareas enviadas - %1';tr = 'Görev gönderildi- %1';it = 'Obiettivi indirizzati - %1';de = 'Aufgabe gesendet- %1'"), Metadata.BriefInformation);
	
	EmailParameters = New Structure;
	EmailParameters.Insert("Subject", EmailSubject);
	EmailParameters.Insert("Body", EmailText);
	EmailParameters.Insert("SendTo", RecipientEmailAddress);
	
	ModuleEmail = Common.CommonModule("EmailOperations");
	Try 
		ModuleEmail.SendEmailMessage(
			ModuleEmail.SystemAccount(), EmailParameters);
	Except
		WriteLogEvent(NStr("ru = 'Бизнес-процессы и задачи.Уведомление о новых задачах'; en = 'Business processes and tasks.New task notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o nowym zadaniu';es_ES = 'Procesos de negocio y tareas. Notificación de nuevas tareas';es_CO = 'Procesos de negocio y tareas. Notificación de nuevas tareas';tr = 'İş süreçleri ve görevler. Yeni görev bildirimi';it = 'Processi aziendali e obiettivi. Notifica sui nuovi obiettivi';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die neue Aufgabe'",
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error,,,
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Ошибка при отправке уведомления о новых задачах: %1'; en = 'Error sending new task notifications: %1'; pl = 'Błąd podczas wysyłania powiadomień o nowym zadaniu: %1.';es_ES = 'Error al enviar la notificación de nuevas tareas:%1.';es_CO = 'Error al enviar la notificación de nuevas tareas:%1.';tr = 'Yeni görev bildirimleri gönderirken hata oluştu: %1';it = 'Errore di invio di notifiche del nuovo incarico: %1';de = 'Fehler beim Senden der Benachrichtigung über die neue Aufgabe: %1.'"), 
			   DetailErrorDescription(ErrorInfo())));
		Return False;
	EndTry;

	WriteLogEvent(NStr("ru = 'Бизнес-процессы и задачи.Уведомление о новых задачах'; en = 'Business processes and tasks.New task notification'; pl = 'Procesy biznesowe i zadania . Powiadomienie o nowym zadaniu';es_ES = 'Procesos de negocio y tareas. Notificación de nuevas tareas';es_CO = 'Procesos de negocio y tareas. Notificación de nuevas tareas';tr = 'İş süreçleri ve görevler. Yeni görev bildirimi';it = 'Processi aziendali e obiettivi. Notifica sui nuovi obiettivi';de = 'Geschäftsprozesse und -aufgaben. Benachrichtigung über die neue Aufgabe'",
		CommonClientServer.DefaultLanguageCode()),
		EventLogLevel.Information,,,
		StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Уведомления успешно отправлены на адрес %1.'; en = 'Notifications sent to %1.'; pl = 'Powiadomienia wysłano do %1.';es_ES = 'Notificaciones enviadas a %1.';es_CO = 'Notificaciones enviadas a %1.';tr = '%1''e bildirimler gönderildi.';it = 'Notifiche inviate correttamente all''indirizzo %1.';de = 'Benachrichtigung gesendet an %1.'"), RecipientEmailAddress));
	Return True;	
		
EndFunction

Function GenerateTaskPresentation(TaskStructure)
	
	Result = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1
		|
		|Крайний срок: %2'; 
		|en = '%1
		|
		|Deadline: %2'; 
		|pl = '%1
		|
		|Termin: %2';
		|es_ES = '%1
		|
		|Fecha límite: %2';
		|es_CO = '%1
		|
		|Fecha límite: %2';
		|tr = '%1
		|
		|Bitiş tarihi: %2';
		|it = '%1
		|
		|Termine massimo: %2';
		|de = '%1
		|
		|Frist: %2'") + Chars.LF,
		TaskStructure.Ref, 
		Format(TaskStructure.DueDate, NStr("ru = 'ДЛФ=ДД; ДП=''не указан'''; en = 'DLF=DD; DE=''not specified'''; pl = 'DLF=DD; DE=''not specified''';es_ES = 'DLF=DD; DE=''no especificado''';es_CO = 'DLF=DD; DE=''no especificado''';tr = 'DLF=DD; DE=''belirtilmedi''';it = 'DLF=DD; DE=''non specificato''';de = 'DLF=DD; DE=''nicht angegeben'''")));
	If ValueIsFilled(TaskStructure.Performer) Then
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Исполнитель: %1'; en = 'Assignee: %1'; pl = 'Wykonawca: %1';es_ES = 'Ejecutor: %1';es_CO = 'Ejecutor: %1';tr = 'Atanan: %1';it = 'Esecutore: %1';de = 'Bevollmächtiger: %1'"), TaskStructure.Performer) + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.PerformerRole) Then
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Роль: %1'; en = 'Role: %1'; pl = 'Rola: %1';es_ES = 'Rol: %1';es_CO = 'Rol: %1';tr = 'Rol: %1';it = 'Role: %1';de = 'Rolle: %1'"), TaskStructure.PerformerRole) + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.MainAddressingObject) Then
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Основной объект адресации: %1'; en = 'Main addressing object: %1'; pl = 'Główny obiekt adresacji: %1';es_ES = 'Objeto principal de direccionamiento:%1';es_CO = 'Objeto principal de direccionamiento:%1';tr = 'Ana gönderim hedefi: %1';it = 'Oggetto di indirizzamento principale: %1';de = 'Hauptobjekt von Adressierung: %1'"), TaskStructure.MainAddressingObject) + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.AdditionalAddressingObject) Then
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Доп. объект адресации: %1'; en = 'Additional addressing object: %1'; pl = 'Dodatkowy obiekt adresacji: %1';es_ES = 'Objeto adicional de direccionamiento: %1';es_CO = 'Objeto adicional de direccionamiento: %1';tr = 'Ek gönderim hedefi: %1';it = 'Oggetto di indirizzamento secondario: %1';de = 'Weiteres Objekt von Adressierung: %1'"), TaskStructure.AdditionalAddressingObject) + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.Author) Then
		Result = Result + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Автор: %1'; en = 'Author: %1'; pl = 'Autor: %1';es_ES = 'Autor:%1';es_CO = 'Autor:%1';tr = 'Yazar: %1';it = 'Autore: %1';de = 'Autor: %1'"), TaskStructure.Author) + Chars.LF;
	EndIf;
	If ValueIsFilled(TaskStructure.Details) Then
		Result = Result + Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = '%1'; en = '%1'; pl = '%1';es_ES = '%1';es_CO = '%1';tr = '%1';it = '%1';de = '%1'"), TaskStructure.Details) + Chars.LF;
	EndIf;
	Return Result + Chars.LF;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// The function is used to select the roles that can be assigned to MainAddressingObject and count 
// the list of assignments.
//
Function SelectRolesWithPerformerCount(MainAddressingObject) Export
	If MainAddressingObject <> Undefined Then
		QueryText = 
			"SELECT ALLOWED
			|	PerformerRoles.Ref AS RoleRef,
			|	PerformerRoles.Description AS Role,
			|	PerformerRoles.ExternalRole AS ExternalRole,
			|	PerformerRoles.MainAddressingObjectTypes AS MainAddressingObjectTypes,
			|	SUM(CASE
			|			WHEN TaskPerformers.PerformerRole <> VALUE(Catalog.PerformerRoles.EmptyRef) 
			|				AND TaskPerformers.PerformerRole IS NOT NULL 
			|				AND TaskPerformers.MainAddressingObject = &MainAddressingObject
			|				THEN 1
			|			ELSE 0
			|		END) AS Performers
			|FROM
			|	Catalog.PerformerRoles AS PerformerRoles
			|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
			|		ON (TaskPerformers.PerformerRole = PerformerRoles.Ref)
			|WHERE
			|	PerformerRoles.DeletionMark = FALSE
			|	AND PerformerRoles.UsedByAddressingObjects = TRUE
			| GROUP BY
			|	PerformerRoles.Ref,
			|	TaskPerformers.PerformerRole, 
			|	PerformerRoles.ExternalRole,
			|	PerformerRoles.Description,
			|	PerformerRoles.MainAddressingObjectTypes";
	Else
		QueryText = 
			"SELECT ALLOWED
			|	PerformerRoles.Ref AS RoleRef,
			|	PerformerRoles.Description AS Role,
			|	PerformerRoles.ExternalRole AS ExternalRole,
			|	PerformerRoles.MainAddressingObjectTypes AS MainAddressingObjectTypes,
			|	SUM(CASE
			|			WHEN TaskPerformers.PerformerRole <> VALUE(Catalog.PerformerRoles.EmptyRef) 
			|				AND TaskPerformers.PerformerRole IS NOT NULL 
			|				AND (TaskPerformers.MainAddressingObject IS NULL 
			|					OR TaskPerformers.MainAddressingObject = Undefined)
			|				THEN 1
			|			ELSE 0
			|		END) AS Performers
			|FROM
			|	Catalog.PerformerRoles AS PerformerRoles
			|		LEFT JOIN InformationRegister.TaskPerformers AS TaskPerformers
			|		ON (TaskPerformers.PerformerRole = PerformerRoles.Ref)
			|WHERE
			|	PerformerRoles.DeletionMark = FALSE
			|	AND PerformerRoles.UsedWithoutAddressingObjects = TRUE
			| GROUP BY
			|	PerformerRoles.Ref,
			|	TaskPerformers.PerformerRole, 
			|	PerformerRoles.ExternalRole,
			|	PerformerRoles.Description, 
			|	PerformerRoles.MainAddressingObjectTypes";
	EndIf;		
	Query = New Query(QueryText);
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	QuerySelection = Query.Execute().Select();
	Return QuerySelection;
	
EndFunction

// Checks if there is at least one assignee for the specified role.
//
// Result:
//   Boolean
//
Function HasRolePerformers(RoleReference, MainAddressingObject = Undefined,
	AdditionalAddressingObject = Undefined) Export
	
	QueryResult = ChooseRolePerformers(RoleReference, MainAddressingObject,
		AdditionalAddressingObject);
	Return NOT QueryResult.IsEmpty();	
	
EndFunction

Function ChooseRolePerformers(RoleReference, MainAddressingObject = Undefined,
	AdditionalAddressingObject = Undefined)
	
	QueryText = 
		"SELECT
	   |	TaskPerformers.Performer
	   |FROM
	   |	InformationRegister.TaskPerformers AS TaskPerformers
	   |WHERE
	   |	TaskPerformers.PerformerRole = &PerformerRole";
	If MainAddressingObject <> Undefined Then  
		QueryText = QueryText 
			+ "	AND TaskPerformers.MainAddressingObject = &MainAddressingObject";
	EndIf;		
	If AdditionalAddressingObject <> Undefined Then  
		QueryText = QueryText 
			+ "	AND TaskPerformers.AdditionalAddressingObject = &AdditionalAddressingObject";
	EndIf;		
	
	Query = New Query(QueryText);
	Query.Parameters.Insert("PerformerRole", RoleReference);
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	Query.Parameters.Insert("AdditionalAddressingObject", AdditionalAddressingObject);
	QueryResult = Query.Execute();
	Return QueryResult;
	
EndFunction

// Selects any single assignee of PerformerRole in MainAddressingObject.
// 
Function SelectPerformer(MainAddressingObject, PerformerRole) Export
	
	Query = New Query(
		"SELECT ALLOWED TOP 1
		|	TaskPerformers.Performer AS Performer
		|FROM
		|	InformationRegister.TaskPerformers AS TaskPerformers
		|WHERE
		|	TaskPerformers.PerformerRole = &PerformerRole
		|	AND TaskPerformers.MainAddressingObject = &MainAddressingObject");
	Query.Parameters.Insert("MainAddressingObject", MainAddressingObject);
	Query.Parameters.Insert("PerformerRole", PerformerRole);
	QuerySelection = Query.Execute().Unload();
	Return ?(QuerySelection.Count() > 0, QuerySelection[0].Performer, Catalogs.Users.EmptyRef());
	
EndFunction	

Function SelectHeadTaskBusinessProcesses(TaskRef, ForChange = False) Export
	
	Iteration = 1;
	QueryText = "";
	For Each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		If ForChange Then
			Lock = New DataLock;
			LockItem = Lock.Add(BusinessProcessMetadata.FullName());
			LockItem.SetValue("HeadTask", TaskRef);
			Lock.Lock();
		EndIf;
		
		If NOT IsBlankString(QueryText) Then
			QueryText = QueryText + "
				|
				|UNION ALL
				|";
				
		EndIf;
		QueryFragment = StringFunctionsClientServer.SubstituteParametersToString(
			"SELECT %3
			|	%1.Ref AS Ref
			|FROM
			|	%2 AS %1
			|WHERE
			|	%1.HeadTask = &HeadTask", 
			BusinessProcessMetadata.Name, BusinessProcessMetadata.FullName(),
			?(Iteration = 1, "ALLOWED", ""));
		QueryText = QueryText + QueryFragment;
		Iteration = Iteration + 1;
	EndDo;	
	
	Query = New Query(QueryText);
	Query.SetParameter("HeadTask", TaskRef);
	Result = Query.Execute();
	Return Result;
		
EndFunction	

// Returns the entry kind of the subsystem event log.
//
Function EventLogEvent() Export
	Return NStr("ru = 'Бизнес-процессы и задачи'; en = 'Business processes and tasks'; pl = 'Procesy biznesowe i zadania';es_ES = 'Procesos de negocio y tareas';es_CO = 'Procesos de negocio y tareas';tr = 'İş süreçleri ve görevler';it = 'Processi aziendali e incarichi';de = 'Geschäftsprozesse und Aufgaben'", CommonClientServer.DefaultLanguageCode());
EndFunction

// The procedure is called when changing state of a business process. It is used to propagate the 
// state change to the uncompleted tasks of the business process.
// 
//
Procedure OnChangeBusinessProcessState(BusinessProcessObject, OldState) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PerformerTask.Ref AS Ref
		|FROM
		|	Task.PerformerTask AS PerformerTask
		|WHERE
		|	PerformerTask.BusinessProcess = &BusinessProcess
		|	AND PerformerTask.Executed = FALSE";

	Query.SetParameter("BusinessProcess", BusinessProcessObject.Ref);

	Lock = New DataLock;
	LockItem = Lock.Add("Task.PerformerTask");
	LockItem.SetValue("BusinessProcess", BusinessProcessObject.Ref);
	Lock.Lock();
	
	DetailedRecordsSelection = Query.Execute().Select();
	While DetailedRecordsSelection.Next() Do
		
		Task = DetailedRecordsSelection.Ref.GetObject();
		Task.Lock();
		Task.BusinessProcessState = BusinessProcessObject.State;
		Task.Write();
		
		OnChangeTaskState(Task.Ref, OldState, BusinessProcessObject.State);
	EndDo;

EndProcedure

Procedure OnChangeTaskState(TaskRef, OldState, NewState)
	
	// Locking nested and subordinate business processes.
	Lock = New DataLock;
	For each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		If Not AccessRight("Update", BusinessProcessMetadata) Then
			Continue;
		EndIf;
		
		LockItem = Lock.Add(BusinessProcessMetadata.FullName());
		LockItem.SetValue("HeadTask", TaskRef);
		
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute <> Undefined Then
			LockItem = Lock.Add(BusinessProcessMetadata.FullName());
			LockItem.SetValue("MainTask", TaskRef);
		EndIf;
		
	EndDo;
	Lock.Lock();
	
	// Changing state of nested and subordinate business processes.
	For each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		If NOT AccessRight("Update", BusinessProcessMetadata) Then
		    Continue;
		EndIf;
		
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref AS Ref
			|FROM
			|	&BusinessProcesses AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.HeadTask = &HeadTask
			|   AND BusinessProcesses.DeletionMark = FALSE
			| 	AND BusinessProcesses.Completed = FALSE";
			
		Query.Text = StrReplace(Query.Text, "&BusinessProcesses", BusinessProcessMetadata.FullName());
		Query.SetParameter("HeadTask", TaskRef);

		DetailedRecordsSelection = Query.Execute().Select();
		While DetailedRecordsSelection.Next() Do
			BusinessProcess = DetailedRecordsSelection.Ref.GetObject();
			BusinessProcess.State = NewState;
			BusinessProcess.Write();
		EndDo;
		
	EndDo;	
	
	// Changing state of subordinate business processes.
	For each BusinessProcessMetadata In Metadata.BusinessProcesses Do
		
		// A main task is not required in business process.
		MainTaskAttribute = BusinessProcessMetadata.Attributes.Find("MainTask");
		If MainTaskAttribute = Undefined Then
			Continue;
		EndIf;	
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED
			|	BusinessProcesses.Ref AS Ref
			|FROM
			|	&BusinessProcesses AS BusinessProcesses
			|WHERE
			|   BusinessProcesses.MainTask = &MainTask
			|   AND BusinessProcesses.DeletionMark = FALSE
			| 	AND BusinessProcesses.Completed = FALSE";
			
		Query.Text = StrReplace(Query.Text, "&BusinessProcesses", BusinessProcessMetadata.FullName());
		Query.SetParameter("MainTask", TaskRef);

		DetailedRecordsSelection = Query.Execute().Select();
		While DetailedRecordsSelection.Next() Do
			BusinessProcess = DetailedRecordsSelection.Ref.GetObject();
			BusinessProcess.State = NewState;
			BusinessProcess.Write();
		EndDo;
		
	EndDo;	
	
EndProcedure

// Gets task assignee groups according to the new task assignee records.
//
// Parameters:
//  NewTasksPerformers  - ValueTable - data retrieved from the TaskPerformers information register 
//                           record set.
//
// Returns:
//   Array - with elements of the CatalogRef.TaskPerformersGroups type.
//
Function TaskPerformersGroups(NewTasksPerformers) Export
	
	FieldsNames = "PerformerRole, MainAddressingObject, AdditionalAddressingObject";
	
	Query = New Query;
	Query.SetParameter("NewRecords", NewTasksPerformers.Copy( , FieldsNames));
	Query.Text =
	"SELECT DISTINCT
	|	NewRecords.PerformerRole AS PerformerRole,
	|	NewRecords.MainAddressingObject AS MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject AS AdditionalAddressingObject
	|INTO NewRecords
	|FROM
	|	&NewRecords AS NewRecords
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ISNULL(TaskPerformersGroups.Ref, VALUE(Catalog.TaskPerformersGroups.EmptyRef)) AS Ref,
	|	NewRecords.PerformerRole AS PerformerRole,
	|	NewRecords.MainAddressingObject AS MainAddressingObject,
	|	NewRecords.AdditionalAddressingObject AS AdditionalAddressingObject
	|FROM
	|	NewRecords AS NewRecords
	|		LEFT JOIN Catalog.TaskPerformersGroups AS TaskPerformersGroups
	|		ON NewRecords.PerformerRole = TaskPerformersGroups.PerformerRole
	|			AND NewRecords.MainAddressingObject = TaskPerformersGroups.MainAddressingObject
	|			AND NewRecords.AdditionalAddressingObject = TaskPerformersGroups.AdditionalAddressingObject";
	
	PerformersGroups = Query.Execute().Unload();
	
	PerformersGroupsFilter = New Structure(FieldsNames);
	TaskPerformersGroups = New Array;
	
	For each Record In NewTasksPerformers Do
		FillPropertyValues(PerformersGroupsFilter, Record);
		PerformersGroup = PerformersGroups.FindRows(PerformersGroupsFilter)[0];
		// It is necessary to update the reference in the found row.
		If NOT ValueIsFilled(PerformersGroup.Ref) Then
			// It is necessary to add a new assignee group.
			PerformersGroupObject = Catalogs.TaskPerformersGroups.CreateItem();
			FillPropertyValues(PerformersGroupObject, PerformersGroupsFilter);
			PerformersGroupObject.Write();
			PerformersGroup.Ref = PerformersGroupObject.Ref;
		EndIf;
		TaskPerformersGroups.Add(PerformersGroup.Ref);
	EndDo;
	
	Return TaskPerformersGroups;
	
EndFunction

// The procedure marks nested and subordinate business processes of TaskRef for deletion.
//
// Parameters:
//  TaskRef                 - TaskRef.PerformerTask.
//  DeletionMarkNewValue - Boolean.
//
Procedure OnMarkTaskForDeletion(TaskRef, DeletionMarkNewValue) Export
	
	TaskObject = TaskRef.Metadata();
	If DeletionMarkNewValue Then
		VerifyAccessRights("InteractiveSetDeletionMark", TaskObject);
	EndIf;
	If Not DeletionMarkNewValue Then
		VerifyAccessRights("InteractiveClearDeletionMark", TaskObject);
	EndIf;
	If TaskRef.IsEmpty() Then
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		// Marking nested business processes.
		SetPrivilegedMode(True);
		SubBusinessProcesses = HeadTaskBusinessProcesses(TaskRef, True);
		SetPrivilegedMode(False);
		// Without privileged mode, with rights check.
		For Each SubBusinessProcess In SubBusinessProcesses Do
			BusinessProcessObject = SubBusinessProcess.GetObject();
			BusinessProcessObject.SetDeletionMark(DeletionMarkNewValue);
		EndDo;
		
		// Marking subordinate business processes.
		SubordinateBusinessProcesses = MainTaskBusinessProcesses(TaskRef, True);
		For Each SubordinateBusinessProcess In SubordinateBusinessProcesses Do
			BusinessProcessObject = SubordinateBusinessProcess.GetObject();
			BusinessProcessObject.Lock();
			BusinessProcessObject.SetDeletionMark(DeletionMarkNewValue);
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

// Checks whether the user has sufficient rights to mark a business process as stopped or active.
// 
// 
// Parameters:
//  BusinessProcess - a reference to a business process.
//
// ReturnValue
//  True, if user has the rights, otherwise False.
//
Function HasRightsToStopBusinessProcess(BusinessProcess)
	
	HasRights = False;
	StandardProcessing = True;
	BusinessProcessesAndTasksOverridable.OnCheckStopBusinessProcessRights(BusinessProcess, HasRights, StandardProcessing);
	If Not StandardProcessing Then
		Return HasRights;
	EndIf;
	
	If Users.IsFullUser() Then
		Return True;
	EndIf;
	
	If BusinessProcess.Author = Users.CurrentUser() Then
		Return True;
	EndIf;
	
	Return HasRights;
	
EndFunction

Procedure SetMyTasksListParameters(List) Export
	
	CurrentSessionDate = CurrentSessionDate();
	Today = New StandardPeriod(StandardPeriodVariant.Today);
	ThisWeek = New StandardPeriod(StandardPeriodVariant.ThisWeek);
	NextWeek = New StandardPeriod(StandardPeriodVariant.NextWeek);
	
	List.Parameters.SetParameterValue("CurrentDate", CurrentSessionDate);
	List.Parameters.SetParameterValue("EndOfDay", Today.EndDate);
	List.Parameters.SetParameterValue("EndOfWeek", ThisWeek.EndDate);
	List.Parameters.SetParameterValue("EndOfNextWeek", NextWeek.EndDate);
	List.Parameters.SetParameterValue("Overdue", " " + NStr("ru = 'Просрочено'; en = 'Overdue'; pl = 'Zaległe';es_ES = 'Vencido';es_CO = 'Vencido';tr = 'Vadesi geçmiş';it = 'In ritardo';de = 'Überfällig'")); // Inserting space for sorting.
	List.Parameters.SetParameterValue("Today", NStr("ru = 'Сегодня'; en = 'Today'; pl = 'Dzisiaj';es_ES = 'Hoy';es_CO = 'Hoy';tr = 'Bugün';it = 'Oggi';de = 'Heute'"));
	List.Parameters.SetParameterValue("ThisWeek", NStr("ru = 'До конца недели'; en = 'Till the end of the week'; pl = 'Do końca tygodnia';es_ES = 'Hasta el fin de semana';es_CO = 'Hasta el fin de semana';tr = 'Hafta sonuna kadar';it = 'Fino alla fine di questa settimana';de = 'Bis zum Ende der Woche'"));
	List.Parameters.SetParameterValue("NextWeek", NStr("ru = 'На следующей неделе'; en = 'Next week'; pl = 'W następnym tygodniu';es_ES = 'Próxima semana';es_CO = 'Próxima semana';tr = 'Gelecek hafta';it = 'Settimana successiva';de = 'Nächste Woche'"));
	List.Parameters.SetParameterValue("Later", NStr("ru = 'Позднее'; en = 'Later'; pl = 'Później';es_ES = 'Más tarde';es_CO = 'Más tarde';tr = 'Sonra';it = 'Più tardi...';de = 'Später'"));
	List.Parameters.SetParameterValue("BegOfDay", BegOfDay(CurrentSessionDate));
	List.Parameters.SetParameterValue("BlankDate", Date(1,1,1));
	
EndProcedure

Function PerformerTaskQuantity()
	
	Query = New Query;
	Query.Text = "SELECT ALLOWED
	|	TasksByExecutive.Ref AS Ref,
	|	TasksByExecutive.DueDate AS DueDate
	|INTO UserBusinessProcesses
	|FROM
	|	Task.PerformerTask.TasksByExecutive AS TasksByExecutive
	|WHERE
	|	NOT TasksByExecutive.DeletionMark
	|	AND NOT TasksByExecutive.Executed
	|	AND TasksByExecutive.BusinessProcessState = VALUE(Enum.BusinessProcessStates.Running)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(UserBusinessProcesses.Ref) AS Count
	|FROM
	|	UserBusinessProcesses AS UserBusinessProcesses
	|
	|UNION ALL
	|
	|SELECT
	|	COUNT(UserBusinessProcesses.Ref)
	|FROM
	|	UserBusinessProcesses AS UserBusinessProcesses
	|WHERE
	|	UserBusinessProcesses.DueDate <> DATETIME(1, 1, 1)
	|	AND UserBusinessProcesses.DueDate <= &CurrentDate
	|
	|UNION ALL
	|
	|SELECT
	|	COUNT(UserBusinessProcesses.Ref)
	|FROM
	|	UserBusinessProcesses AS UserBusinessProcesses
	|WHERE
	|	UserBusinessProcesses.DueDate > &CurrentDate
	|	AND UserBusinessProcesses.DueDate <= &Today
	|
	|UNION ALL
	|
	|SELECT
	|	COUNT(UserBusinessProcesses.Ref)
	|FROM
	|	UserBusinessProcesses AS UserBusinessProcesses
	|WHERE
	|	UserBusinessProcesses.DueDate > &Today
	|	AND UserBusinessProcesses.DueDate <= &EndOfWeek
	|
	|UNION ALL
	|
	|SELECT
	|	COUNT(UserBusinessProcesses.Ref)
	|FROM
	|	UserBusinessProcesses AS UserBusinessProcesses
	|WHERE
	|	UserBusinessProcesses.DueDate > &EndOfWeek
	|	AND UserBusinessProcesses.DueDate <= &EndOfNextWeek";
	
	Today = New StandardPeriod(StandardPeriodVariant.Today);
	ThisWeek = New StandardPeriod(StandardPeriodVariant.ThisWeek);
	NextWeek = New StandardPeriod(StandardPeriodVariant.NextWeek);
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Today", Today.EndDate);
	Query.SetParameter("EndOfWeek", ThisWeek.EndDate);
	Query.SetParameter("EndOfNextWeek", NextWeek.EndDate);
	QueryResult = Query.Execute().Unload();
	
	Result = New Structure("Total,Overdue,ForToday,ForWeek,ForNextWeek");
	Result.Total = QueryResult[0].Count;
	Result.Overdue = QueryResult[1].Count;
	Result.ForToday = QueryResult[2].Count;
	Result.ForWeek = QueryResult[3].Count;
	Result.ForNextWeek = QueryResult[4].Count;
	
	Return Result;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Initializes EmployeeResponsibleForTasksManagement predefined assignee role.
// 
Procedure FillEmployeeResponsibleForCompletionControl() Export
	
	AllAddressingObjects = ChartsOfCharacteristicTypes.TaskAddressingObjects.AllAddressingObjects;
	
	RoleObject = Catalogs.PerformerRoles.EmployeeResponsibleForTasksManagement.GetObject();
	LockDataForEdit(RoleObject.Ref);
	RoleObject.Description = NStr("ru = 'Координатор выполнения задач'; en = 'Task control manager'; pl = 'Kierownik kontroli zadań';es_ES = 'Gerente de control de tareas';es_CO = 'Gerente de control de tareas';tr = 'Görev kontrolü yöneticisi';it = 'Gestore controllo incarico';de = 'Manager für Aufgabenüberwachung'");
	RoleObject.UsedWithoutAddressingObjects = True;
	RoleObject.UsedByAddressingObjects = True;
	RoleObject.MainAddressingObjectTypes = AllAddressingObjects;
	InfobaseUpdate.WriteObject(RoleObject);
	
EndProcedure

// Returns the Recipient user email address for mailing task notifications.
//
// Parameters:
//  Recipient  - CatalogRef.Users, CatalogRef.ExternalUsers - a task assignee.
//  Address       - String - email address to be returned.
//
//
Function EmailAddress(Recipient)
	
	Address = "";
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		If TypeOf(Recipient) = Type("CatalogRef.Users") Then
			Address = ModuleContactsManager.ObjectContactInformation(
				Recipient, Catalogs.ContactInformationKinds.UserEmail);
		ElsIf TypeOf(Recipient) = Type("CatalogRef.ExternalUsers") Then
			Address = ExternalUserEmail(Recipient);
		EndIf;
	EndIf;
	
	Return Address;
	
EndFunction

Function ExternalUserEmail(Recipient)
	
	If Common.SubsystemExists("StandardSubsystems.ContactInformation") Then
		
		ModuleContactsManagerInternal = Common.CommonModule("ContactsManagerInternal");
		ModuleContactsManager = Common.CommonModule("ContactsManager");
		ContactInformationType = ModuleContactsManager.ContactInformationTypeByDescription("EmailAddress");
		
		Return ModuleContactsManagerInternal.FirstValueOfObjectContactsByType(
			Recipient.AuthorizationObject, ContactInformationType, CurrentSessionDate());
			
	EndIf;
	
	Return "";
	
EndFunction

Function SystemEmailAccountIsSetUp(ErrorDescription)
	
	If Not Common.SubsystemExists("StandardSubsystems.EmailOperations") Then
		ErrorDescription = NStr("ru = 'Отправка почты не предусмотрена в программе.'; en = 'Email sending is not available in the application.'; pl = 'Wysyłanie wiadomości Email nie jest dostępne w aplikacji.';es_ES = 'El envío por correo electrónico no está disponible en la aplicación.';es_CO = 'El envío por correo electrónico no está disponible en la aplicación.';tr = 'Uygulamada e-posta gönderimi mevcut değil.';it = 'L''invio della posta non è supportato dal programma.';de = 'E-Mail-Senden nicht erlaubt in der Anwendung.'");
	Else
		ModuleEmailOperations = Common.CommonModule("EmailOperations");
		If ModuleEmailOperations.AccountSetUp(ModuleEmailOperations.SystemAccount(), True, False) Then
			Return True;
		EndIf;
		ErrorDescription = NStr("ru = 'Системная учетная запись электронной почты не настроена для отправки.'; en = 'System email account is not configured for sending.'; pl = 'Konto systemowego email nie jest skonfigurowane do wysyłania.';es_ES = 'La cuenta de correo electrónico del sistema no está configurada para el envío.';es_CO = 'La cuenta de correo electrónico del sistema no está configurada para el envío.';tr = 'Sistem e-posta hesabı gönderim için yapılandırılmadı.';it = 'L''account di posta elettronica di sistema non è configurato per l''invio.';de = 'Das E-Mail-Konto des Systems ist für Senden nicht konfiguriert.'");
	EndIf;
	
	Return False;
EndFunction

// [2.3.3.70] Updates the DeferredProcessesStart scheduled job.
Procedure UpdateScheduledJobUsage() Export
	
	SearchParameters = New Structure;
	SearchParameters.Insert("Metadata", Metadata.ScheduledJobs.StartDeferredProcesses);
	JobsList = ScheduledJobsServer.FindJobs(SearchParameters);
	
	JobParameters = New Structure("Use", GetFunctionalOption("UseBusinessProcessesAndTasks"));
	For Each Job In JobsList Do
		ScheduledJobsServer.ChangeJob(Job, JobParameters);
	EndDo;
	
EndProcedure

// Called upon migration to configuration version 3.0.2.131 and initial filling.
// 
Procedure FillPredefinedItemDescriptionAllAddressingObjects() Export
	
	AllAddressingObjects = ChartsOfCharacteristicTypes.TaskAddressingObjects.AllAddressingObjects.GetObject();
	AllAddressingObjects.Description = NStr("ru = 'Все объекты адресации'; en = 'All addressing objects'; pl = 'Wszystkie obiekty adresacji';es_ES = 'Todos los objetos de direccionamiento';es_CO = 'Todos los objetos de direccionamiento';tr = 'Tüm gönderim hedefleri';it = 'Tutti gli oggetti dell''indirizzamento';de = 'Alle Objekte von Adressierung'");
	InfobaseUpdate.WriteObject(AllAddressingObjects);
	
EndProcedure

#EndRegion
