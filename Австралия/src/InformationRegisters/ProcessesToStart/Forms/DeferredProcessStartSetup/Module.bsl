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
		
		NotificationText = ?(PostponedProcessStart, NStr("ru = '???????????????????? ??????????:'; en = 'Deferred start:'; pl = 'Odroczone rozpocz??cie:';es_ES = 'Inicio diferido:';es_CO = 'Inicio diferido:';tr = 'Ertelenmi?? ba??lang????:';it = 'Partenza differita:';de = 'Verz??gerter Start:'"), NStr("ru = '???????????????????? ?????????? ??????????????:'; en = 'Deferred start canceled:'; pl = 'Odroczone rozpocz??cie anulowano:';es_ES = 'Inicio diferido est?? cancelado:';es_CO = 'Inicio diferido est?? cancelado:';tr = 'Ertelenmi?? ba??lang???? iptal edildi:';it = 'Partenza differita annullata:';de = 'Verz??gerter Start abgebrochen:'"));
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
		Items.DeferredStartDateTime.ChoiceList.Add(BlankDate, Format(BlankDate, NStr("ru = '????=????:????'; en = 'DF=hh:mm tt'; pl = 'DF=hh:mm tt';es_ES = 'DF=hh:mm tt';es_CO = 'DF=hh:mm tt';tr = 'DF=hh:mm tt';it = 'DF=hh.mm tt';de = 'DF=hh:mm tt'")));
		BlankDate = BlankDate + 1800;
	EndDo;
	
EndProcedure

&AtClient
Function IntevalText(StartDate, EndDate)

	If StartDate > EndDate Then
		Return NStr("ru = '???????? ?????????????? ?????????????? ?????????????????? ?? ??????????????.'; en = 'Job start date is in the past.'; pl = 'Dzie?? rozpocz??cia zadania znajduje si?? w przes??o??ci.';es_ES = 'La fecha de inicio de la tarea est?? pasada.';es_CO = 'La fecha de inicio de la tarea est?? pasada.';tr = 'G??rev ba??lang???? tarihi ge??ti.';it = 'La data di inizio dell''attivit?? ?? nel passato.';de = 'Das Arbeitsstartdatum ist in der Vergangenheit.'");
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
	Prefix = NStr("ru = '?????????????? ?????????? ????????????????'; en = 'Job will be started'; pl = 'Zadanie zostanie rozpocz??te';es_ES = 'La tarea se iniciar??';es_CO = 'La tarea se iniciar??';tr = 'G??rev ba??layacakt??r';it = 'Il processo sar?? riavviato';de = 'Die Arbeit beginnt'") + " ";
	Root = NStr("ru = '??????????'; en = 'in'; pl = 'w';es_ES = 'en';es_CO = 'en';tr = 'i??inde';it = 'in';de = 'im'") + " ";
	If UseDateAndTimeInTaskDeadlines Then
		If NumberOfDays > 0 AND NumberOfHours > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '%1 ????. ?? %2 ??.'; en = '%1 days and %2 hours'; pl = '%1 dni i %2 godzin';es_ES = '%1 d??as y  %2 horas';es_CO = '%1 d??as y  %2 horas';tr = '%1 g??n ve %2saat';it = '%1 giorni e %2 ore';de = '%1 Tage und %2 Stunden'"),
				String(NumberOfDays),
				String(NumberOfHours));
		ElsIf NumberOfDays > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 days.'; ru = '%1 ????????.'; pl = '%1 dni.';es_ES = '%1 d??as.';es_CO = '%1 d??as.';tr = '%1 g??n.';it = '%1 giorni.';de = '%1 Tage.'"), String(NumberOfDays));
		ElsIf NumberOfHours > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 h.'; ru = '%1 ??.'; pl = '%1 g.';es_ES = '%1 horas';es_CO = '%1 horas';tr = '%1 saat.';it = '%1 h.';de = '%1 Stunden.'"), String(NumberOfHours));
		Else
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????? ?????? ?????????? ??????.'; en = 'less than in an hour.'; pl = 'mniej ni?? za godzin??.';es_ES = 'en menos de una hora.';es_CO = 'en menos de una hora.';tr = 'bir saatten az.';it = 'in meno di un''ora.';de = 'weniger als in einer Stunde.'"), String(NumberOfHours));
		EndIf;
	Else
		If NumberOfDays > 0 Then
			DateDiff = Root + StringFunctionsClientServer.SubstituteParametersToString(NStr("en = '%1 days.'; ru = '%1 ????????.'; pl = '%1 dni.';es_ES = '%1 d??as.';es_CO = '%1 d??as.';tr = '%1 g??n.';it = '%1 giorni.';de = '%1 Tage.'"), String(NumberOfDays));
		Else
			DateDiff = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = '?????????? ?????? ?????????? ????????.'; en = 'less than in a day.'; pl = 'mniej ni?? za dzie??.';es_ES = 'en menos de un d??a';es_CO = 'en menos de un d??a';tr = 'bir g??nden az.';it = 'in meno di un giorno.';de = 'weniger als in einem Tag.'"), String(NumberOfDays));
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
		CommonClientServer.MessageToUser(NStr("ru = '???????? ?? ?????????? ?????????????????????? ???????????? ???????????? ???????? ???????????? ?????????????? ????????.'; en = 'Date and time of the deferred start must be greater than the current date.'; pl = 'Dzie?? i czas odroczonego rozpocz??cia powinny by?? wi??ksze ni?? bie????ca data.';es_ES = 'La fecha y hora del inicio diferido debe ser mayor que la fecha actual.';es_CO = 'La fecha y hora del inicio diferido debe ser mayor que la fecha actual.';tr = 'Ertelenmi?? ba??lang???? tarihi ve saati mevcut tarihten ileri olmal??.';it = 'La data e l''ora dell''avvio ritardato devono essere successive alla data corrente.';de = 'Das Datum und die Uhrzeit des verz??gerten Starts sollen nach dem laufenden Tag liegen.'"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
		
	If PostponedProcessStart AND DeferredStartDate > DueDate Then
		CommonClientServer.MessageToUser(NStr("ru = '???????? ?? ?????????? ?????????????????????? ???????????? ???????????? ???????? ???????????? ?????????? ???????????????????? ??????????????.'; en = 'Date and time of the deferred start must be less than the job due date.'; pl = 'Dzie?? i czas odroczonego rozpocz??cia powinni by?? mniejsze ni?? termin zako??czenia pracy.';es_ES = 'La fecha y hora del inicio diferido debe ser menor que la fecha de vencimiento de la tarea.';es_CO = 'La fecha y hora del inicio diferido debe ser menor que la fecha de vencimiento de la tarea.';tr = 'Ertelenmi?? ba??lang???? tarihi ve saati biti?? tarihinden erken bir tarih olmal??.';it = 'La data e l''ora dell''avvio ritardato devono essere precedenti alla data di esecuzione.';de = 'Das Datum und die Uhrzeit des verz??gerten Starts sollen vor dem Arbeitsf??lligkeitsdatum liegen.'"),,
			"DeferredStartDate");
		FilledInCorrectly = False;
	EndIf;
	
	Return FilledInCorrectly;
	
EndFunction

#EndRegion

