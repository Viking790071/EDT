#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;

	If NOT Users.IsFullUser(, True) Then
		ReadOnly = True;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		SetSchedulePresentation(ThisObject);
		MethodParameters = Common.ValueToXMLString(New Array);
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ID = Object.Ref.UUID();
	
	Schedule = CurrentObject.Schedule.Get();
	SetSchedulePresentation(ThisObject);
	
	MethodParameters = Common.ValueToXMLString(CurrentObject.Parameters.Get());
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Schedule = New ValueStorage(Schedule);
	CurrentObject.Parameters = New ValueStorage(Common.ValueFromXMLString(MethodParameters));
	
EndProcedure

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	ID = Object.Ref.UUID();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Not Exit Then
		UnlockFormDataForEdit();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormControlItemsEventHandlers

&AtClient
Procedure SchedulePresentationStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	If Schedule = Undefined Then
		ScheduleBeingEdited = New JobSchedule;
	Else
		ScheduleBeingEdited = Schedule;
	EndIf;
	
	Dialog = New ScheduledJobDialog(ScheduleBeingEdited);
	OnCloseNotifyDescription = New NotifyDescription("EditSchedule", ThisObject);
	Dialog.Show(OnCloseNotifyDescription);
	
EndProcedure

&AtClient
Procedure SchedulePresentationClearing(Item, StandardProcessing)
	
	StandardProcessing = False;
	LockFormDataForEdit();
	
	Schedule = Undefined;
	Modified = True;
	SetSchedulePresentation(ThisObject);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure EditSchedule(NewSchedule, AdditionalParameters) Export
	
	If NewSchedule = Undefined Then
		Return;
	EndIf;
	
	Schedule = NewSchedule;
	Modified = True;
	SetSchedulePresentation(ThisObject);
	
	ShowUserNotification(NStr("ru = 'Перепланирование'; en = 'Rescheduling'; pl = 'Ponowne planowanie';es_ES = 'Reprogramación';es_CO = 'Reprogramación';tr = 'Yeniden planlama';it = 'Ripianificazione';de = 'Neuplanung'"), , NStr("ru = 'Новое расписание будет учтено при
		|следующем выполнении задания'; 
		|en = 'The new schedule will take effect
		|next time the job is executed.'; 
		|pl = 'Nowy harmonogram będzie
		|brany pod uwagę przy następnym wykonaniu zadania';
		|es_ES = 'Nuevo horario se
		|considerará durante la realización de la siguiente tarea';
		|es_CO = 'Nuevo horario se
		|considerará durante la realización de la siguiente tarea';
		|tr = 'Yeni program 
		|aşağıdaki görev yerine getirilirken dikkate alınacaktır';
		|it = 'La nuova pianificazione entrerà in vigore
		|la prossima volta che il processo sarà eseguito.';
		|de = 'Der neue Zeitplan wird bei der folgenden Aufgabenausführung
		|berücksichtigt'"));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSchedulePresentation(Val Form)
	
	Schedule = Form.Schedule;
	
	If Schedule <> Undefined Then
		Form.SchedulePresentation = String(Schedule);
	Else
		Form.SchedulePresentation = NStr("ru = '<Не установлено>'; en = '<Not set>'; pl = '<Nieustawione>';es_ES = '<No establecido>';es_CO = '<Not set>';tr = '<Belirlenmedi>';it = '<Non impostato>';de = '<Nicht festgelegt>'");
	EndIf;
	
EndProcedure

#EndRegion


