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
	
	If Not ValueIsFilled(Parameters.BusinessProcess) Then
		Cancel = True;
	EndIf;
	
	BusinessProcess = Parameters.BusinessProcess;
	DueDate = Parameters.DueDate;
	
	// Filling settings.
	FillFormAttributes();
	// Specifying setting availability.
	SetFormItemsProperties();
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	RefreshIntervalRepresentation();
	UpdateTimeSelectionList();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure DeferredProcessStartOnChange(Item)
	
	SetDeferredProcessStartState();
	
EndProcedure

&AtClient
Procedure DeferredStartDateOnChange(Item)
	
	OnChangeDateTime();
	
EndProcedure

&AtClient
Procedure DeferredStartDateTimeOnChange(Item)
	
	OnChangeDateTime();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Finish(Command)
	
	If FormIsFilledInCorrectly() Then
		WriteSettingsOnClient();
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Close();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure OnChangeDateTime()

	RefreshIntervalRepresentation();
	UpdateTimeSelectionList();

EndProcedure

// Writes settings.
//
&AtClient
Procedure WriteSettingsOnClient()
	
	SaveSettings();
	Close();
	
	DeferredStartSettings = New Structure;
	DeferredStartSettings.Insert("BusinessProcess", BusinessProcess);
	DeferredStartSettings.Insert("Deferred", PostponedProcessStart);
	DeferredStartSettings.Insert("DeferredStartDate", DeferredStartDate);
	DeferredStartSettings.Insert("State", State);
	
	Notify("DeferredStartSettingsChanged", DeferredStartSettings);
	
	If PostponedProcessStart <> DeferredProcessStartOnOpen Then 
		
		NotificationText = ?(PostponedProcessStart, NStr("ru = 'Отложенный старт:'; en = 'Deferred start:'; pl = 'Odroczone rozpoczęcie:';es_ES = 'Inicio diferido:';es_CO = 'Inicio diferido:';tr = 'Ertelenmiş başlangıç:';it = 'Partenza differita:';de = 'Verzögerter Start:'"), NStr("ru = 'Отложенный старт отменен:'; en = 'Deferred start canceled:'; pl = 'Odroczone rozpoczęcie anulowano:';es_ES = 'Inicio diferido está cancelado:';es_CO = 'Inicio diferido está cancelado:';tr = 'Ertelenmiş başlangıç iptal edildi:';it = 'Partenza differita annullata:';de = 'Verzögerter Start abgebrochen:'"));
		ProcessURL = GetURL(BusinessProcess);
		
		ShowUserNotification(
			NotificationText,
			ProcessURL,
			BusinessProcess,
			PictureLib.Information32);
			
		NotifyChanged(BusinessProcess);
		NotifyChanged(Type("InformationRegisterRecordKey.BusinessProcessesData"));
			
	EndIf;
	
EndProcedure

// Fills in the State form attribute and sets availability of the DeferredStartDate and 
// DeferredStartDateTime fields.
//
&AtServer
Procedure SetDeferredProcessStartState()
	
	If PostponedProcessStart Then
		State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart");
	Else
		State = PredefinedValue("Enum.ProcessesStatesForStart.EmptyRef");
	EndIf;
	
	SetFormItemsProperties();
	
EndProcedure

// Saves deferred start settings in the register.
//
&AtServer
Procedure SaveSettings()
	
	If PostponedProcessStart Then
		BusinessProcessesAndTasksServer.AddProcessForDeferredStart(BusinessProcess, DeferredStartDate);
	Else
		BusinessProcessesAndTasksServer.DisableProcessDeferredStart(BusinessProcess);
	EndIf;
	
EndProcedure

// Fills in the DecorationInterval decoration title.
//
&AtClient
Procedure RefreshIntervalRepresentation()
	
	If NOT ValueIsFilled(DeferredStartDate)
		OR ProcessIsStarted Then
		
		Items.IntervalDecoration.Title = "";
		Return;
		
	EndIf;
	
	CommonClientServer.SetFormItemProperty(
		Items,
		"IntervalDecoration",
		"Title",
		IntevalText(CurrentServerDate, DeferredStartDate));
			
EndProcedure

// Fills in the selection list for the DeferredStartDateTime form item with time values.
// 
//
&AtClient
Procedure UpdateTimeSelectionList()
	
	Items.DeferredStartDateTime.ChoiceList.Clear();
	
	BlankDate = BegOfDay(DeferredStartDate);
	
	For Ind = 1 To 48 Do
		Items.DeferredStartDateTime.ChoiceList.Add(BlankDate, Format(BlankDate, NStr("ru = 'ДФ=ЧЧ:мм'; en = 'DF=hh:mm tt'; pl = 'DF=hh:mm tt';es_ES = 'DF=hh:mm tt';es_CO = 'DF=hh:mm tt';tr = 'DF=hh:mm tt';it = 'DF=hh.mm tt';de = 'DF=hh:mm tt'")));
		BlankDate = BlankDate + 1800;
	EndDo;
	
EndProcedure

&AtClient
Function IntevalText(StartDate, EndDate)

	If StartDate > EndDate Then
		Return NStr("ru = 'Дата запуска задания находится в прошлом.'; en = 'Job start date is in the past.'; pl = 'Dzień rozpoczęcia zadania znajduje się w przesłości.';es_ES = 'La fecha de inicio de la tarea está pasada.';es_CO = 'La fecha de inicio de la tarea está pasada.';tr = 'Görev başlangıç tarihi geçti.';it = 'La data di inizio dell''attività è nel passato.';de = 'Das Arbeitsstartdatum ist in der Vergangenheit.'");
	EndIf;	
	
	If UseDateAndTimeInTaskDeadlines Then
		NumberOfHours = Round((EndDate - StartDate) / (60*60));
		NumberOfDays = Round(NumberOfHours / 24);
		NumberOfHours = NumberOfHours - NumberOfDays * 24;
	Else
		NumberOfHours = 0;
		NumberOfDays = (BegOfDay(EndDate) - BegOfDay(StartDate)) / (60*60*24);
	EndIf;
		
	If NumberOfHours < 0 Then
		NumberOfDays = NumberOfDays - 1;
		NumberOfHours = NumberOfHours + 24;
	EndIf;
	
	DateDiff = "";
	Prefix = NStr("ru = 'Задание будет запущено'; en = 'Job will be started'; pl = 'Zadanie zostanie rozpoczęte';es_ES = 'La tarea se iniciará';es_CO = 'La tarea se iniciará';tr = 'Görev başlayacaktır';it = 'Il processo sarà riavviato';de = 'Die Arbeit beginnt'") + " ";
	Root = NStr("ru = 'через'; en = 'in'; pl = 'w';es_ES = 'en';es_CO = 'en';tr = 'içinde';it = 'in';de = 'im'") + " ";
	If UseDateAndTimeInTaskDeadlines Then
		If NumberOfDays > 0 AND NumberOfHours > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '%1 дн. и %2 ч.'; en = '%1 days and %2 hours'; pl = '%1 dni i %2 godzin';es_ES = '%1 días y  %2 horas';es_CO = '%1 días y  %2 horas';tr = '%1 gün ve %2saat';it = '%1 giorni e %2 ore';de = '%1 Tage und %2 Stunden'"),
				String(NumberOfDays),
				String(NumberOfHours));
		ElsIf NumberOfDays > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 days.'; ru = '%1 дней.'; pl = '%1 dni.';es_ES = '%1 días.';es_CO = '%1 días.';tr = '%1 gün.';it = '%1 giorni.';de = '%1 Tage.'"), String(NumberOfDays));
		ElsIf NumberOfHours > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h.'; ru = '%1 ч.'; pl = '%1 g.';es_ES = '%1 horas';es_CO = '%1 horas';tr = '%1 saat.';it = '%1 h.';de = '%1 Stunden.'"), String(NumberOfHours));
		Else
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'менее чем через час.'; en = 'less than in an hour.'; pl = 'mniej niż za godzinę.';es_ES = 'en menos de una hora.';es_CO = 'en menos de una hora.';tr = 'bir saatten az.';it = 'in meno di un''ora.';de = 'weniger als in einer Stunde.'"), String(NumberOfHours));
		EndIf;
	Else
		If NumberOfDays > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 days.'; ru = '%1 дней.'; pl = '%1 dni.';es_ES = '%1 días.';es_CO = '%1 días.';tr = '%1 gün.';it = '%1 giorni.';de = '%1 Tage.'"), String(NumberOfDays));
		Else
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'менее чем через день.'; en = 'less than in a day.'; pl = 'mniej niż za dzień.';es_ES = 'en menos de un día';es_CO = 'en menos de un día';tr = 'bir günden az.';it = 'in meno di un giorno.';de = 'weniger als in einem Tag.'"), String(NumberOfDays));
		EndIf;
	EndIf;
	
	Return Prefix + DateDiff;
	
EndFunction

&AtServer
Procedure FillFormAttributes()
	
	ProcessAttributes = Common.ObjectAttributesValues(
		Parameters.BusinessProcess, "Started, Completed");
	
	UseDateAndTimeInTaskDeadlines = GetFunctionalOption("UseDateAndTimeInTaskDeadlines");
	CurrentServerDate = CurrentSessionDate();
	
	ProcessIsStarted = ProcessAttributes.Started;
	ProcessCompleted = ProcessAttributes.Completed;
	
	Setting = BusinessProcessesAndTasksServer.DeferredProcessParameters(Parameters.BusinessProcess);
	
	If ValueIsFilled(Setting) Then
		// If the process is already deferred, filling the attributes for it.
		FillPropertyValues(ThisObject, Setting);
		
		PostponedProcessStart = (Setting.State = Enums.ProcessesStatesForStart.ReadyToStart);
		DeferredProcessStartOnOpen = PostponedProcessStart;
		
	ElsIf NOT ProcessIsStarted Then
		// If it is not deferred, filling with default values.
		DeferredProcessStartOnOpen = False;
		PostponedProcessStart = True;
		DeferredStartDate = BegOfDay(CurrentSessionDate() + 86400);
		State = PredefinedValue("Enum.ProcessesStatesForStart.ReadyToStart");
	EndIf;
	
EndProcedure

&AtServer
Procedure SetFormItemsProperties()
	
	CommonClientServer.SetFormItemProperty(
		Items,
		"PostponedProcessStart",
		"ReadOnly",
		ProcessIsStarted);
	CommonClientServer.SetFormItemProperty(
		Items,
		"GroupInfoLabel",
		"Visible",
		ProcessIsStarted);
		
	If ProcessIsStarted Then
		Items.CommandsPages.CurrentPage = Items.ProcessIsStartedPage;
		CommonClientServer.SetFormItemProperty(Items, "Close", "DefaultButton", True);

		If ProcessCompleted Then
			Items.FooterPages.CurrentPage = Items.JobIsCompletedPage;
		Else
			Items.FooterPages.CurrentPage = Items.JobStartedPage;
		EndIf;
	Else
		Items.CommandsPages.CurrentPage = Items.ProcessIsNotStartedPage;
		CommonClientServer.SetFormItemProperty(Items, "Finish", "DefaultButton", True);
		
		If State = PredefinedValue("Enum.ProcessesStatesForStart.StartCanceled") Then
			Items.FooterPages.CurrentPage = Items.CancelStartPage;
		Else
			Items.FooterPages.CurrentPage = Items.EmptyPage;
		EndIf;
	EndIf;
		
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDate",
		"ReadOnly",
		ProcessIsStarted OR NOT PostponedProcessStart);
		
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDateTime",
		"Visible",
		UseDateAndTimeInTaskDeadlines);
	CommonClientServer.SetFormItemProperty(
		Items,
		"DeferredStartDateTime",
		"ReadOnly",
		ProcessIsStarted OR NOT PostponedProcessStart);
		
EndProcedure

&AtClient
Function FormIsFilledInCorrectly()
	
	FilledInCorrectly = True;
	ClearMessages();
	
	If PostponedProcessStart AND DeferredStartDate < CurrentServerDate Then
		CommonClientServer.MessageToUser(NStr("ru = 'Дата и время отложенного старта должны быть больше текущей даты.'; en = 'Date and time of the deferred start must be greater than the current date.'; pl = 'Dzień i czas odroczonego rozpoczęcia powinny być większe niż bieżąca data.';es_ES = 'La fecha y hora del inicio diferido debe ser mayor que la fecha actual.';es_CO = 'La fecha y hora del inicio diferido debe ser mayor que la fecha actual.';tr = 'Ertelenmiş başlangıç tarihi ve saati mevcut tarihten ileri olmalı.';it = 'La data e l''ora dell''avvio ritardato devono essere successive alla data corrente.';de = 'Das Datum und die Uhrzeit des verzögerten Starts sollen nach dem laufenden Tag liegen.'"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
		
	If PostponedProcessStart AND DeferredStartDate > DueDate Then
		CommonClientServer.MessageToUser(NStr("ru = 'Дата и время отложенного старта должны быть меньше срока исполнения задания.'; en = 'Date and time of the deferred start must be less than the job due date.'; pl = 'Dzień i czas odroczonego rozpoczęcia powinni być mniejsze niż termin zakończenia pracy.';es_ES = 'La fecha y hora del inicio diferido debe ser menor que la fecha de vencimiento de la tarea.';es_CO = 'La fecha y hora del inicio diferido debe ser menor que la fecha de vencimiento de la tarea.';tr = 'Ertelenmiş başlangıç tarihi ve saati bitiş tarihinden erken bir tarih olmalı.';it = 'La data e l''ora dell''avvio ritardato devono essere precedenti alla data di esecuzione.';de = 'Das Datum und die Uhrzeit des verzögerten Starts sollen vor dem Arbeitsfälligkeitsdatum liegen.'"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
	
	Return FilledInCorrectly;
	
EndFunction

#EndRegion

