///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Public

////////////////////////////////////////////////////////////////////////////////
// Commands for business processes.

// Marks the specified business process as stopped.
//
// Parameters:
//  CommandParameters - Array, BusinessProcessRef - an array of references to business processes or a business process.
//
Procedure Stop(Val CommandParameter) Export
	
	QuestionText = "";
	TaskCount = 0;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс.'; en = 'No business process is selected.'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio.';es_CO = 'No se ha seleccionado ningún proceso de negocio.';tr = 'Hiçbir iş süreci seçilmedi.';it = 'Non è stato selezionato nemmeno un processo aziendale.';de = 'Kein Geschäftsprozess ausgewählt.'"));
			Return;
		EndIf;
		
		If CommandParameter.Count() = 1 AND TypeOf(CommandParameter[0]) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс.'; en = 'No business process is selected.'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio.';es_CO = 'No se ha seleccionado ningún proceso de negocio.';tr = 'Hiçbir iş süreci seçilmedi.';it = 'Non è stato selezionato nemmeno un processo aziendale.';de = 'Kein Geschäftsprozess ausgewählt.'"));
			Return;
		EndIf;
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			If TaskCount > 0 Then
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Будет выполнена остановка бизнес-процесса ""%1"" и всех его невыполненных задач (%2). Продолжить?'; en = 'Business process ""%1"" and all its unfinished tasks (%2) will be stopped. Continue?'; pl = 'Proces biznesowy ""%1"" i wszystkie jego niezakończone zadania (%2) będą zatrzymane. Kontynuować?';es_ES = 'El proceso de negocio ""%1""y todas sus tareas inconclusas (%2)se detendrán. ¿Continuar?';es_CO = 'El proceso de negocio ""%1""y todas sus tareas inconclusas (%2)se detendrán. ¿Continuar?';tr = ' ""%1"" iş süreci ve tüm tamamlanmamış görevler (%2) durdurulacaktır. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" e tutti i suoi task non conclusi (%2) verranno terminati. Continuare?';de = 'Der Geschäftsprozess ""%1"" und alle nicht abgeschlossenen Aufgaben (%2) werden gestoppt. Fortsetzen?'"), 
					String(CommandParameter[0]), TaskCount);
			Else
				QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Будет выполнена остановка бизнес-процесса ""%1"". Продолжить?'; en = 'Business process ""%1"" will be stopped. Continue?'; pl = 'Proces biznesowy ""%1"" zostanie zatrzymany. Kontynuować?';es_ES = 'El proceso de negocios ""%1"" se detendrá. ¿Continuar?';es_CO = 'El proceso de negocios ""%1"" se detendrá. ¿Continuar?';tr = '""%1"" iş süreci durdurulacaktır. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" verrà terminato. Continuare?';de = 'Der Geschäftsprozess ""%1"" wird gestoppt. Fortsetzen?'"), 
					String(CommandParameter[0]));
			EndIf;
		Else
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Будет выполнена остановка бизнес-процессов (%1) и всех их невыполненных задач (%2). Продолжить?'; en = 'Business processes (%1) and all their unfinished tasks (%2) will be stopped. Continue?'; pl = 'Procesy biznesowe (%1) i wszystkie ich niezakończone zadania (%2) zostaną zatrzymane. Kontynuować?';es_ES = 'Los procesos de negocios (%1) y todas sus tareas inconclusas (%2) se detendrán. ¿Continuar?';es_CO = 'Los procesos de negocios (%1) y todas sus tareas inconclusas (%2) se detendrán. ¿Continuar?';tr = ' (%1) iş süreçleri ve tüm tamamlanmamış görevleri (%2) durdurulacaktır. Devam edilsin mi?';it = 'I processi aziendali ""%1"" e tutti i loro task non conclusi (%2) verranno terminati. Continuare?';de = 'Der Businessprozess (%1) und alle nicht abgeschlossenen Aufgaben (%2) werden gestoppt. Fortsetzen?'"), 
				CommandParameter.Count(), TaskCount);
		EndIf;
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс'; en = 'No business process is selected'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio';es_CO = 'No se ha seleccionado ningún proceso de negocio';tr = 'Hiçbir iş süreci seçilmedi';it = 'Non è stato selezionato nemmeno un processo aziendale';de = 'Kein Geschäftsprozess ausgewählt'"));
			Return;
		EndIf;
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		If TaskCount > 0 Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Будет выполнена остановка бизнес-процесса ""%1"" и всех его невыполненных задач (%2). Продолжить?'; en = 'Business process ""%1"" and all its unfinished tasks (%2) will be stopped. Continue?'; pl = 'Proces biznesowy ""%1"" i wszystkie jego niezakończone zadania (%2) będą zatrzymane. Kontynuować?';es_ES = 'El proceso de negocio ""%1""y todas sus tareas inconclusas (%2)se detendrán. ¿Continuar?';es_CO = 'El proceso de negocio ""%1""y todas sus tareas inconclusas (%2)se detendrán. ¿Continuar?';tr = ' ""%1"" iş süreci ve tüm tamamlanmamış görevler (%2) durdurulacaktır. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" e tutti i suoi task non conclusi (%2) verranno terminati. Continuare?';de = 'Der Geschäftsprozess ""%1"" und alle nicht abgeschlossenen Aufgaben (%2) werden gestoppt. Fortsetzen?'"), 
				String(CommandParameter), TaskCount);
		Else
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Будет выполнена остановка бизнес-процесса ""%1"". Продолжить?'; en = 'Business process ""%1"" will be stopped. Continue?'; pl = 'Proces biznesowy ""%1"" zostanie zatrzymany. Kontynuować?';es_ES = 'El proceso de negocios ""%1"" se detendrá. ¿Continuar?';es_CO = 'El proceso de negocios ""%1"" se detendrá. ¿Continuar?';tr = '""%1"" iş süreci durdurulacaktır. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" verrà terminato. Continuare?';de = 'Der Geschäftsprozess ""%1"" wird gestoppt. Fortsetzen?'"), 
				String(CommandParameter));
		EndIf;
		
	EndIf;
	
	Notification = New NotifyDescription("StopCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("ru = 'Остановка бизнес-процесса'; en = 'Stop business process'; pl = 'Zatrzymaj proces biznesowy';es_ES = 'Detener el proceso de negocio';es_CO = 'Detener el proceso de negocio';tr = 'İş sürecini durdur';it = 'Blocca il processo aziendale';de = 'Geschäftsprozess einhalten'"));
	
EndProcedure

// Marks the specified business process as stopped.
//  The procedure is intended for calling from a business process form.
//
// Parameters:
//  Form - ClientApplicationForm, ManagedFormExtensionForObjects - a business process form, where:
//   * Object - BusinessProcessObject - a business process.
//
Procedure StopBusinessProcessFromObjectForm(Form) Export
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Stopped");
	ClearMessages();
	Form.Write();
	ShowUserNotification(
		NStr("ru = 'Бизнес-процесс остановлен'; en = 'The business process is stopped'; pl = 'Proces biznesowy jest zatrzymany';es_ES = 'El proceso de negocio se ha detenido';es_CO = 'El proceso de negocio se ha detenido';tr = 'İş süreci durduruldu';it = 'Il processo aziendale è stato terminato';de = 'Der Geschäftsprozess ist gestoppt'"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified business processes as active.
//
// Parameters:
//  CommandParameter - Array, DynamicListGroupRow, BusinessProcessesRef - a business process.
//
Procedure Activate(Val CommandParameter) Export
	
	QuestionText = "";
	TaskCount = 0;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() = 0 Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс.'; en = 'No business process is selected.'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio.';es_CO = 'No se ha seleccionado ningún proceso de negocio.';tr = 'Hiçbir iş süreci seçilmedi.';it = 'Non è stato selezionato nemmeno un processo aziendale.';de = 'Kein Geschäftsprozess ausgewählt.'"));
			Return;
		EndIf;
		
		If CommandParameter.Count() = 1 AND TypeOf(CommandParameter[0]) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс.'; en = 'No business process is selected.'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio.';es_CO = 'No se ha seleccionado ningún proceso de negocio.';tr = 'Hiçbir iş süreci seçilmedi.';it = 'Non è stato selezionato nemmeno un processo aziendale.';de = 'Kein Geschäftsprozess ausgewählt.'"));
			Return;
		EndIf;
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessesTasksCount(CommandParameter);
		If CommandParameter.Count() = 1 Then
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Бизнес-процесс ""%1"" и все его задачи (%2) будут сделаны активными. Продолжить?'; en = 'Business process ""%1"" and its tasks (%2) will be active. Continue?'; pl = 'Proces biznesowy ""%1"" i jego zadania (%2) będą aktywowane. Kontynuować?';es_ES = 'El proceso de negocio ""%1""y todas sus tareas (%2) están activas. ¿Continuar?';es_CO = 'El proceso de negocio ""%1""y todas sus tareas (%2) están activas. ¿Continuar?';tr = '""%1"" iş süreci ve görevleri (%2) etkinleştirilecek. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" e tutti i suoi task (%2) verranno resi attivi. Continuare?';de = 'Der Geschäftsprozess ""%1"" und dessen Aufgaben (%2) werden aktiv. Fortsetzen?'"),
				String(CommandParameter[0]), TaskCount);
		Else		
			QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Бизнес-процессы (%1) и их задачи (%2) будут сделаны активными. Продолжить?'; en = 'Business processes (%1) and their tasks (%2) will be active. Continue?'; pl = 'Procesy biznesowe (%1) i ich zadania (%2) będą aktywowane. Kontynuować?';es_ES = 'Los procesos de negocio (%1) y todas sus tareas (%2) están activas. ¿Continuar?';es_CO = 'Los procesos de negocio (%1) y todas sus tareas (%2) están activas. ¿Continuar?';tr = '(%1) iş süreçleri ve görevleri (%2) etkinleştirilecek. Devam edilsin mi?';it = 'I processi aziendali ""%1"" e tutti i loro task (%2) verranno resi attivi. Continuare?';de = 'Die Geschäftsprozesse (%1) und deren Aufgaben (%2) werden aktiv. Fortsetzen?'"),
				CommandParameter.Count(), TaskCount);
		EndIf;
		
	Else
		
		If TypeOf(CommandParameter) = Type("DynamicListGroupRow") Then
			ShowMessageBox(,NStr("ru = 'Не выбран ни один бизнес-процесс.'; en = 'No business process is selected.'; pl = 'Nie wybrano procesu biznesowego';es_ES = 'No se ha seleccionado ningún proceso de negocio.';es_CO = 'No se ha seleccionado ningún proceso de negocio.';tr = 'Hiçbir iş süreci seçilmedi.';it = 'Non è stato selezionato nemmeno un processo aziendale.';de = 'Kein Geschäftsprozess ausgewählt.'"));
			Return;
		EndIf;
		
		TaskCount = BusinessProcessesAndTasksServerCall.UncompletedBusinessProcessTasksCount(CommandParameter);
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Бизнес-процесс ""%1"" и все его задачи (%2) будут сделаны активными. Продолжить?'; en = 'Business process ""%1"" and its tasks (%2) will be active. Continue?'; pl = 'Proces biznesowy ""%1"" i jego zadania (%2) będą aktywowane. Kontynuować?';es_ES = 'El proceso de negocio ""%1""y todas sus tareas (%2) están activas. ¿Continuar?';es_CO = 'El proceso de negocio ""%1""y todas sus tareas (%2) están activas. ¿Continuar?';tr = '""%1"" iş süreci ve görevleri (%2) etkinleştirilecek. Devam edilsin mi?';it = 'Il processo aziendale ""%1"" e tutti i suoi task (%2) verranno resi attivi. Continuare?';de = 'Der Geschäftsprozess ""%1"" und dessen Aufgaben (%2) werden aktiv. Fortsetzen?'"),
			String(CommandParameter), TaskCount);
			
	EndIf;
	
	Notification = New NotifyDescription("ActivateCompletion", ThisObject, CommandParameter);
	ShowQueryBox(Notification, QuestionText, QuestionDialogMode.YesNo, , DialogReturnCode.No, NStr("ru = 'Остановка бизнес-процесса'; en = 'Stop business process'; pl = 'Zatrzymaj proces biznesowy';es_ES = 'Detener el proceso de negocio';es_CO = 'Detener el proceso de negocio';tr = 'İş sürecini durdur';it = 'Blocca il processo aziendale';de = 'Geschäftsprozess einhalten'"));
	
EndProcedure

// Marks the specified business processes as active.
//  The procedure is intended for calling from a business process form.
//
// Parameters:
//  Form - ClientApplicationForm, ManagedFormExtensionForObjects - a business process form, where:
//   * Object - BusinessProcessObject - a business process.
//
Procedure ContinueBusinessProcessFromObjectForm(Form) Export
	
	Form.Object.State = PredefinedValue("Enum.BusinessProcessStates.Running");
	ClearMessages();
	Form.Write();
	ShowUserNotification(
		NStr("ru = 'Бизнес-процесс сделан активным'; en = 'The business process is activated'; pl = 'Proces biznesowy jest aktywowany';es_ES = 'El proceso de negocio está activado';es_CO = 'El proceso de negocio está activado';tr = 'İş süreci etkinleştirildi';it = 'Il processo aziendale è stato reso attivo';de = 'Der Geschäftsprozess ist aktiviert'"),
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified task as accepted for execution.
//
// Parameters:
//  TaskArray - Array - an array of references to tasks.
//
Procedure AcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.AcceptTasksForExecution(TaskArray);
	If TaskArray.Count() = 0 Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	
	TaskValueType = Undefined;
	For each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;
	EndDo;
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;
	
EndProcedure

// Marks the specified task as accepted for execution.
//
// Parameters:
//  Form               - ClientApplicationForm, ManagedFormExtensionForObjects - a task form, where:
//   * Object - TaskObject - a task.
//  CurrentUser - CatalogRef.ExternalUsers, CatalogRef.Users - a reference to the current 
//                                                                                              application user.
//
Procedure AcceptTaskForExecution(Form, CurrentUser) Export
	
	Form.Object.AcceptedForExecution = True;
	
	// Setting empty AcceptForExecutionDate. It is filled in with the current session date before 
	// writing the task.
	Form.Object.AcceptForExecutionDate = Date('00010101');
	If NOT ValueIsFilled(Form.Object.Performer) Then
		Form.Object.Performer = CurrentUser;
	EndIf;
	
	ClearMessages();
	Form.Write();
	UpdateAcceptForExecutionCommandsAvailability(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Marks the specified tasks as not accepted for execution.
//
// Parameters:
//  TaskArray - Array - an array of references to tasks.
//
Procedure CancelAcceptTasksForExecution(Val TaskArray) Export
	
	BusinessProcessesAndTasksServerCall.CancelAcceptTasksForExecution(TaskArray);
	
	If TaskArray.Count() = 0 Then
		ShowMessageBox(, NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	
	TaskValueType = Undefined;
	For each Task In TaskArray Do
		If TypeOf(Task) <> Type("DynamicListGroupRow") Then 
			TaskValueType = TypeOf(Task);
			Break;
		EndIf;
	EndDo;
	
	If TaskValueType <> Undefined Then
		NotifyChanged(TaskValueType);
	EndIf;
	
EndProcedure

// Marks the specified task as not accepted for execution.
//
// Parameters:
//  Form - ClientApplicationForm, ManagedFormExtensionForObjects - a task form, where:
//  * Object - TaskObject - a task.
//
Procedure CancelAcceptTaskForExecution(Form) Export
	
	Form.Object.AcceptedForExecution      = False;
	Form.Object.AcceptForExecutionDate = "00010101000000";
	If Not Form.Object.PerformerRole.IsEmpty() Then
		Form.Object.Performer = PredefinedValue("Catalog.Users.EmptyRef");
	EndIf;
	
	ClearMessages();
	Form.Write();
	UpdateAcceptForExecutionCommandsAvailability(Form);
	NotifyChanged(Form.Object.Ref);
	
EndProcedure

// Sets availability of commands for accepting for execution.
//
// Parameters:
//  Form - ClientApplicationForm - a task form, where:
//   * Items - AllFormItems - form items. Contains:
//     ** FormAcceptForExecution - InputField - a command button on the form.
//     ** FormCancelAcceptForExecution - InputField - a command button on the form.
//
Procedure UpdateAcceptForExecutionCommandsAvailability(Form) Export
	
	If Form.Object.AcceptedForExecution = True Then
		Form.Items.FormAcceptForExecution.Enabled = False;
		
		If Form.Object.Executed Then
			Form.Items.FormCancelAcceptForExecution.Enabled = False;
		Else
			Form.Items.FormCancelAcceptForExecution.Enabled = True;
		EndIf;
		
	Else	
		Form.Items.FormAcceptForExecution.Enabled = True;
		Form.Items.FormCancelAcceptForExecution.Enabled = False;
	EndIf;
		
EndProcedure

// Opens the form to set up deferred start of a business process.
//
// Parameters:
//  BusinessProcess - - BusinessProcessRef - a process, for which a deferred start setting form is 
//                                            to be opened.
//  DueDate - Date                   - a date stating the deadline.
//
Procedure SetUpDeferredStart(BusinessProcess, DueDate) Export
	
	If BusinessProcess.IsEmpty() Then
		WarningText = 
			NStr("ru = 'Невозможно настроить отложенный старт для незаписанного процесса.'; en = 'Cannot set up deferred start for an unsaved process.'; pl = 'Nie można ustawić odroczonego rozpoczęcia dla niezapisanego procesu.';es_ES = 'No se puede configurar el inicio diferido para un proceso no guardado.';es_CO = 'No se puede configurar el inicio diferido para un proceso no guardado.';tr = 'Kaydedilmemiş bir süreç için ertelenmiş başlangıç düzenlenemez.';it = 'Non è possibile configurare un avvio ritardato per un processo non registrato.';de = 'Der verzögerte Start für einen nicht gespeicherten Prozess kann nicht eingegeben werden.'");
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
		
	FormParameters = New Structure;
	FormParameters.Insert("BusinessProcess", BusinessProcess);
	FormParameters.Insert("DueDate", DueDate);
	
	OpenForm(
		"InformationRegister.ProcessesToStart.Form.DeferredProcessStartSetup",
		FormParameters,,,,,,
		FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Additional procedures and functions.

// Standard notification handler for task execution forms.
//  The procedure is intended for calling from the NotificationProcessing form event handler.
//
// Parameters:
//  Form      - ClientApplicationForm - a task execution form, where:
//   * Object - TaskObject - an object task.
//  EventName - String           - an event name.
//  Parameter   - Arbitrary     - an event parameter.
//  Source   - Arbitrary     - an event source.
//
Procedure TaskFormNotificationProcessing(Form, EventName, Parameter, Source) Export
	
	If EventName = "Write_PerformerTask" 
		AND NOT Form.Modified 
		AND (Source = Form.Object.Ref OR (TypeOf(Source) = Type("Array") 
		AND Source.Find(Form.Object.Ref) <> Undefined)) Then
		If Parameter.Property("Forwarded") Then
			Form.Close();
		Else
			Form.Read();
		EndIf;
	EndIf;
	
EndProcedure

// Standard BeforeAddRow handler for task lists.
//  The procedure is intended for calling from the BeforeAddRow form table event handler.
//
// Parameters:
//  Form        - ClientApplicationForm - a task form.
//  Item      - FormTable - form table items.
//  Cancel        - Boolean - shows whether adding objects is cancelled. If the parameter is set to 
//                          True in the handler, the object is not added.
//  Copy  - Boolean - defines the copy mode. If True, the row is copied.
//  Parent     - Undefined, CatalogRef, ChartOfAccountsRef - a reference to the item used as a 
//                                                                    parent on adding.
//  Group       - Boolean - shows whether a group is added. True - a group is added.
//
Procedure TaskListBeforeAddRow(Form, Item, Cancel, Clone, Parent, Folder) Export
	
	If Clone Then
		Task = Item.CurrentRow;
		If NOT ValueIsFilled(Task) Then
			Return;
		EndIf;
		FormParameters = New Structure("Base", Task);
	EndIf;
	CreateJob(Form, FormParameters);
	Cancel = True;
	
EndProcedure

// Writes and closes the task execution form.
//
// Parameters:
//  Form      - ClientApplicationForm - a task execution form, where:
//   * Object - TaskObject - a business process task.
//  ExecuteTask  - Boolean - a task is written in the execution mode.
//  NotificationParameters - Structure - additional notification parameters.
//
// Returns:
//   Boolean   - True if the task is written.
//
Function WriteAndCloseComplete(Form, ExecuteTask = False, NotificationParameters = Undefined) Export
	
	ClearMessages();
	
	NewObject = Form.Object.Ref.IsEmpty();
	NotificationText = "";
	If NotificationParameters = Undefined Then
		NotificationParameters = New Structure;
	EndIf;
	If NOT Form.InitialExecutionFlag AND ExecuteTask Then
		If NOT Form.Write(New Structure("ExecuteTask", True)) Then
			Return False;
		EndIf;
		NotificationText = NStr("ru = 'Задача выполнена'; en = 'The task is completed'; pl = 'Zadanie jest zakończone';es_ES = 'La tarea se ha completado';es_CO = 'La tarea se ha completado';tr = 'Görev tamamlandı';it = 'L''incarico è stato completato';de = 'Die Aufgabe ist erfüllt'");
	Else
		If NOT Form.Write() Then
			Return False;
		EndIf;
		NotificationText = ?(NewObject, NStr("ru = 'Задача создана'; en = 'The task is created'; pl = 'Zadanie zostało utworzone';es_ES = 'La tarea ha sido creada';es_CO = 'La tarea ha sido creada';tr = 'Görev oluşturuldu';it = 'Obiettivo creato';de = 'Die Aufgabe ist erstellt'"), NStr("ru = 'Задача изменена'; en = 'The task is changed'; pl = 'Zadanie zostało zmienione';es_ES = 'La tarea se ha cambiado';es_CO = 'La tarea se ha cambiado';tr = 'Görev değişti';it = 'Obiettivo modificato';de = 'Die Aufgabe ist geändert'"));
	EndIf;
	
	Notify("Write_PerformerTask", NotificationParameters, Form.Object.Ref);
	ShowUserNotification(NotificationText,
		GetURL(Form.Object.Ref),
		String(Form.Object.Ref),
		PictureLib.Information32);
	Form.Close();
	Return True;
	
EndFunction

// Opens a new job form.
//
// Parameters:
//  OwnerForm  - ClientApplicationForm - a form that must be the owner for the form being opened.
//  FormParameters - Structure - parameters of the form being opened.
//
Procedure CreateJob(Val OwnerForm = Undefined, Val FormParameters = Undefined) Export
	
	OpenForm("BusinessProcess.Job.ObjectForm", FormParameters, OwnerForm);
	
EndProcedure	

// Opens a form for forwarding one or several tasks to another assignee.
//
// Parameters:
//  TaskArray  - Array - a list of tasks to be forwarded.
//  OwnerForm - ClientApplicationForm - a form that must be the owner for the task forwarding form 
//                                     being opened.
//
Procedure ForwardTasks(TaskArray, OwnerForm) Export

	If TaskArray = Undefined Then
		ShowMessageBox(,NStr("ru = 'Не выбраны задачи.'; en = 'Tasks are not selected.'; pl = 'Nie wybrano zadań.';es_ES = 'Las tareas no están seleccionadas';es_CO = 'Las tareas no están seleccionadas';tr = 'Görevler seçilmedi.';it = 'Obiettivi non selezionati.';de = 'Aufgaben sind nicht ausgewählt.'"));
		Return;
	EndIf;
		
	TasksCanBeForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks(
		TaskArray, Undefined, True);
	If NOT TasksCanBeForwarded AND TaskArray.Count() = 1 Then
		ShowMessageBox(,NStr("ru = 'Невозможно перенаправить уже выполненную задачу или направленную другому исполнителю.'; en = 'Cannot forward a task that is already completed or was sent to another user.'; pl = 'Nie można przesłać zadanie, które jest już zakończone lub już było wysłane do innego użytkownika.';es_ES = 'No se puede reenviar la tarea que ya está terminada o que se ha enviado a otro usuario.';es_CO = 'No se puede reenviar la tarea que ya está terminada o que se ha enviado a otro usuario.';tr = 'Tamamlanmış veya başka bir kullanıcıya gönderilmiş olan görev iletilemez.';it = 'Non è possibile reindirizzare un obiettivo già completato o indirizzato a un altro esecutore.';de = 'Die bereits abgeschlossene oder an einen anderen Benutzen weitergeleitete Aufgabe kann nicht weitergeleitet werden.'"));
		Return;
	EndIf;
		
	Notification = New NotifyDescription("ForwardTasksCompletion", ThisObject, TaskArray);
	OpenForm("Task.PerformerTask.Form.ForwardTasks",
		New Structure("Task,TaskCount,FormCaption", 
		TaskArray[0], TaskArray.Count(), 
		?(TaskArray.Count() > 1, NStr("ru = 'Перенаправить задачи'; en = 'Forward tasks'; pl = 'Prześlij zadania';es_ES = 'Enviar tareas';es_CO = 'Enviar tareas';tr = 'Görevleri ilet';it = 'Inoltra incarichi';de = 'Aufgaben weiterleiten'"), 
			NStr("ru = 'Перенаправить задачу'; en = 'Forward task'; pl = 'Prześlij zadanie';es_ES = 'Enviar la tarea';es_CO = 'Enviar la tarea';tr = 'Görevi ilet';it = 'Reindirizzare l''obiettivo';de = 'Aufgabe weiterleiten'"))), 
		OwnerForm,,,,Notification);
		
EndProcedure

// Opens the form with additional information about the task.
//
// Parameters:
//  TaskRef - TaskRef - a reference to a task.
// 
// Returns:
//  ClientApplicationForm - a form of the assignee's additional task.
//
Procedure OpenAdditionalTaskInfo(Val TaskRef) Export
	
	OpenForm("Task.PerformerTask.Form.More", 
		New Structure("Key", TaskRef));
	
EndProcedure

#EndRegion

#Region Internal

Procedure OpenRolesAndTaskPerformersList() Export
	
	OpenForm("InformationRegister.TaskPerformers.Form.RolesAndTaskPerformers");
	
EndProcedure

#EndRegion

#Region Private

Procedure OpenBusinessProcess(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	If List.CurrentData.BusinessProcess = Undefined Then
		ShowMessageBox(,NStr("ru = 'У выбранной задачи не указан бизнес-процесс.'; en = 'Business process of the selected task is not specified.'; pl = 'Proces biznesowy wybranego zadania nie jest określony.';es_ES = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';es_CO = 'No se ha especificado el proceso de negocio de la tarea seleccionada.';tr = 'Seçilen görevin iş süreci belirtilmedi.';it = 'Nel processo selezionato non è indicato nessun processo aziendale.';de = 'Geschäftsprozess der ausgewählten Aufgabe nicht angegeben.'"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.BusinessProcess);
EndProcedure

Procedure OpenTaskSubject(List) Export
	If TypeOf(List.CurrentRow) <> Type("TaskRef.PerformerTask") Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	If List.CurrentData.Topic = Undefined Then
		ShowMessageBox(,NStr("ru = 'У выбранной задачи не указан предмет.'; en = 'Subject of the selected task is not specified.'; pl = 'Temat wybranego zadania nie jest określony.';es_ES = 'No se ha especificado el tema de la tarea seleccionada.';es_CO = 'No se ha especificado el tema de la tarea seleccionada.';tr = 'Seçilen görevin konusu belirtilmedi.';it = 'Nel processo selezionato non è indicato un oggetto.';de = 'Thema der ausgewählten Aufgabe nicht angegeben.'"));
		Return;
	EndIf;
	ShowValue(, List.CurrentData.Topic);
EndProcedure

// Standard handler DeletionMark used in the lists of business processes.
// The procedure is intended for calling from the DeletionMark list event handler.
//
// Parameters:
//   List  - FormTable - a form control (form table) with a list of business processes.
//
Procedure BusinessProcessesListDeletionMark(List) Export
	
	SelectedRows = List.SelectedRows;
	If SelectedRows = Undefined OR SelectedRows.Count() <= 0 Then
		ShowMessageBox(,NStr("ru = 'Команда не может быть выполнена для указанного объекта.'; en = 'Cannot run the command for the specified object.'; pl = 'Polecenie nie może być uruchomione dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Belirtilen nesne için komut işletilemez.';it = 'Non è possibile eseguire il comando per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'"));
		Return;
	EndIf;
	Notification = New NotifyDescription("BusinessProcessesListDeletionMarkCompletion", ThisObject, List);
	ShowQueryBox(Notification, NStr("ru = 'Изменить пометку удаления?'; en = 'Change deletion mark?'; pl = 'Zmienić zaznaczenie do usunięcia?';es_ES = '¿Cambiar la marca de borrar?';es_CO = '¿Cambiar la marca de borrar?';tr = 'Silme işareti değiştirilsin mi?';it = 'Modificare contrassegno per la cancellazione?';de = 'Löschzeichen ändern?'"), QuestionDialogMode.YesNo);
	
EndProcedure

// Opens the assignee selection form.
//
// Parameters:
//   PerformerItem - a form item where an assignee is selected. The form item is specified as the 
//      owner of the assignee selection form.
//   PerformerAttribute - a previously selected assignee.
//      Used to set the current row in the assignee selection form.
//   SimpleRolesOnly - Boolean - if True, only roles without addressing objects are used in the 
//      selection.
//   WithoutExternalRoles	- Boolean - if True, only roles without the ExternalRole flag are used in 
//      the selection.
//
Procedure SelectPerformer(PerformerItem, PerformerAttribute, SimpleRolesOnly = False, NoExternalRoles = False) Export 
	
	StandardProcessing = True;
	BusinessProcessesAndTasksClientOverridable.OnPerformerChoice(PerformerItem, PerformerAttribute, 
		SimpleRolesOnly, NoExternalRoles, StandardProcessing);
	If Not StandardProcessing Then
		Return;
	EndIf;
			
	FormParameters = New Structure("Performer, SimpleRolesOnly, NoExternalRoles", 
		PerformerAttribute, SimpleRolesOnly, NoExternalRoles);
	OpenForm("CommonForm.SelectBusinessProcessPerformer", FormParameters, PerformerItem);
	
EndProcedure	

Procedure StopCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		BusinessProcessesAndTasksServerCall.StopBusinessProcesses(CommandParameter);
		
	Else
		
		BusinessProcessesAndTasksServerCall.StopBusinessProcess(CommandParameter);
		
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);
	EndIf;

EndProcedure

Procedure BusinessProcessesListDeletionMarkCompletion(Result, List) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
	
	SelectedRows = List.SelectedRows;
	BusinessProcessRef = BusinessProcessesAndTasksServerCall.MarkBusinessProcessesForDeletion(SelectedRows);
	List.Refresh();
	ShowUserNotification(NStr("ru = 'Пометка удаления изменена.'; en = 'The deletion mark is changed.'; pl = 'Zaznaczenie do usunięcia zostało zmienione.';es_ES = 'La marca de borrar se ha cambiado.';es_CO = 'La marca de borrar se ha cambiado.';tr = 'Silme işareti değiştirildi.';it = 'Contrassegno per la cancellazione modificato.';de = 'Das Löschzeichen ist geändert.'"), 
		?(BusinessProcessRef <> Undefined, GetURL(BusinessProcessRef), ""),
		?(BusinessProcessRef <> Undefined, String(BusinessProcessRef), ""));
	
EndProcedure

Procedure ActivateCompletion(Val Result, Val CommandParameter) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf;
		
	If TypeOf(CommandParameter) = Type("Array") Then
		
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcesses(CommandParameter);
		
	Else
		
		BusinessProcessesAndTasksServerCall.ActivateBusinessProcess(CommandParameter);
		
	EndIf;
	
	If TypeOf(CommandParameter) = Type("Array") Then
		
		If CommandParameter.Count() <> 0 Then
			
			For Each Parameter In CommandParameter Do
				
				If TypeOf(Parameter) <> Type("DynamicListGroupRow") Then
					NotifyChanged(TypeOf(Parameter));
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	Else
		NotifyChanged(CommandParameter);
	EndIf;
	
EndProcedure

Procedure ForwardTasksCompletion(Val Result, Val TaskArray) Export
	
	If TypeOf(Result) <> Type("Structure") Then
		Return;
	EndIf;
	
	ForwardedTaskArray = Undefined;
	TasksAreForwarded = BusinessProcessesAndTasksServerCall.ForwardTasks(
		TaskArray, Result, False, ForwardedTaskArray);
		
	Notify("Write_PerformerTask", New Structure("Forwarded", TasksAreForwarded), TaskArray);
	
EndProcedure

#EndRegion