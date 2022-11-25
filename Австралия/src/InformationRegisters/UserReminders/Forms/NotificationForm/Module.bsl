
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If CommonClientServer.IsWebClient() Then
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	EndIf;
	
	If CommonClientServer.IsMobileClient() Then // This is a temporary solution for mobile client. It will be removed from next versions.
		
		CommandBarLocation = FormCommandBarLabelLocation.Auto;
		
		Items.Move(Items.StopButton, Items.CommandBarForm);
		Items.Move(Items.DeferButton, Items.CommandBarForm);
		
		CommonClientServer.SetFormItemProperty(Items, "OpenButton", "Visible", False);
		CommonClientServer.SetFormItemProperty(Items, "DeferButton", "DefaultButton", True);
		CommonClientServer.SetFormItemProperty(Items, "DeferButton", "DefaultItem", True);
		CommonClientServer.SetFormItemProperty(Items, "StopButton", "OnlyInAllActions", True);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	FillRepeatedReminderPeriod();
	RepeatedNotificationPeriod = NStr("en = '15 minutes'; ru = '15 минут';pl = '15 minut';es_ES = '15 minutos';es_CO = '15 minutos';tr = '15 dakika';it = '15 minuti';de = '15 Minuten'");
	RepeatedNotificationPeriod = UserRemindersClientServer.ApplyAppearanceTime(RepeatedNotificationPeriod);
	UpdateRemindersTable();
	UpdateTimeInRemindersTable();
	Activate();
EndProcedure

&AtClient
Procedure OnReopen()
	UpdateRemindersTable();
	UpdateTimeInRemindersTable();
	ThisObject.CurrentItem = Items.RepeatedNotificationPeriod;
	Activate();
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	DeferActiveReminders();
	UserRemindersClient.ResetCurrentNotificationsCheckTimer();
	
	// Forced disabling of handlers is necessary as the form is not exported from the memory.
	DetachIdleHandler("UpdateRemindersTable");
	DetachIdleHandler("UpdateTimeInRemindersTable");
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RepeatedNotificationPeriodOnChange(Item)
	RepeatedNotificationPeriod = UserRemindersClientServer.ApplyAppearanceTime(RepeatedNotificationPeriod);
EndProcedure

#EndRegion

#Region ReminderFormTableItemsEventHandlers

&AtClient
Procedure RemindersSelection(Item, RowSelected, Field, StandardProcessing)
	OpenReminder();
EndProcedure

&AtClient
Procedure RemindersOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Return;
	EndIf;
		
	Source = Item.CurrentData.Source;
	SourceAsString = Item.CurrentData.SourceAsString;
	
	HasSource = ValueIsFilled(Source);
	Items.RemindersContextMenuOpen.Enabled = HasSource;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Change(Command)
	EditReminder();
EndProcedure

&AtClient
Procedure OpenCommand(Command)
	OpenReminder();
EndProcedure

&AtClient
Procedure Defer(Command)
	DeferActiveReminders();
EndProcedure

&AtClient
Procedure Stop(Command)
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	
	For Each RowIndex In Items.Reminders.SelectedRows Do
		RowData = Reminders.FindByID(RowIndex);
	
		ReminderParameters = UserRemindersClientServer.ReminderDetails(RowData);
		
		DisableReminder(ReminderParameters);
		UserRemindersClient.DeleteRecordFromNotificationsCache(RowData);
	EndDo;
	
	NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
	
	UpdateRemindersTable();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure AttachReminder(ReminderParameters)
	UserRemindersInternal.AttachReminder(ReminderParameters, True);
EndProcedure

&AtServer
Procedure DisableReminder(ReminderParameters)
	UserRemindersInternal.DisableReminder(ReminderParameters);
EndProcedure

&AtClient
Procedure UpdateRemindersTable() 

	DetachIdleHandler("UpdateRemindersTable");
	
	TimeOfClosest = Undefined;
	RemindersTable = UserRemindersClient.GetCurrentNotifications(TimeOfClosest);
	For Each Reminder In RemindersTable Do
		FoundRows = Reminders.FindRows(New Structure("Source,EventTime", Reminder.Source, Reminder.EventTime));
		If FoundRows.Count() > 0 Then
			FillPropertyValues(FoundRows[0], Reminder, , "ReminderTime");
		Else
			NewRow = Reminders.Add();
			FillPropertyValues(NewRow, Reminder);
		EndIf;
	EndDo;
	
	RowsToDelete = New Array;
	For Each Reminder In Reminders Do
		If ValueIsFilled(Reminder.Source) AND IsBlankString(Reminder.SourceAsString) Then
			UpdateSubjectsPresentations();
		EndIf;
			
		RowFound = False;
		For Each CacheRow In RemindersTable Do
			If CacheRow.Source = Reminder.Source AND CacheRow.EventTime = Reminder.EventTime Then
				RowFound = True;
				Break;
			EndIf;
		EndDo;
		If Not RowFound Then 
			RowsToDelete.Add(Reminder);
		EndIf;
	EndDo;
	
	For Each Row In RowsToDelete Do
		Reminders.Delete(Row);
	EndDo;
	
	SetVisibility();
	
	Interval = 15; // Update the table not less than once in 15 seconds.
	If TimeOfClosest <> Undefined Then 
		Interval = Max(Min(Interval, TimeOfClosest - CommonClient.SessionDate()), 1); 
	EndIf;
	
	AttachIdleHandler("UpdateRemindersTable", Interval, True);
	
EndProcedure

&AtServer
Procedure UpdateSubjectsPresentations()
	
	For Each Reminder In Reminders Do
		If ValueIsFilled(Reminder.Source) Then
			Reminder.SourceAsString = Common.SubjectString(Reminder.Source);
		EndIf;
	EndDo;
	
EndProcedure

&AtClient
Function ModuleNumbers(Number)
	If Number >= 0 Then
		Return Number;
	Else
		Return -Number;
	EndIf;
EndFunction

&AtClient
Procedure UpdateTimeInRemindersTable()
	DetachIdleHandler("UpdateTimeInRemindersTable");
	
	For Each TableRow In Reminders Do
		TimePresentation = NStr("ru = 'срок не определен'; en = 'deadline is not defined'; pl = 'nie określono terminu';es_ES = 'fecha límite no está establecida';es_CO = 'fecha límite no está establecida';tr = 'son tarih belirlenmedi';it = 'la scadenza non è definita';de = 'Deadline ist nicht festgelegt'");
		
		If ValueIsFilled(TableRow.EventTime) Then
			CurrentDate = CommonClient.SessionDate();
			Time = CurrentDate - TableRow.EventTime;
			If TableRow.EventTime - BegOfDay(TableRow.EventTime) < 60 // Events for the whole day.
				AND BegOfDay(TableRow.EventTime) = BegOfDay(CurrentDate) Then
					TimePresentation = NStr("ru = 'сегодня'; en = 'today'; pl = 'dzisiaj';es_ES = 'hoy';es_CO = 'hoy';tr = 'bugün';it = 'oggi';de = 'Heute'");
			Else
				If ModuleNumbers(Time) > 60*60*24 Then
					Time = BegOfDay(CommonClient.SessionDate()) - BegOfDay(TableRow.EventTime);
				EndIf;
				TimePresentation = TimeIntervalPresentation(Time);
			EndIf;
		EndIf;
		
		If TableRow.EventTimeString <> TimePresentation Then
			TableRow.EventTimeString = TimePresentation;
		EndIf;
		
	EndDo;
	
	AttachIdleHandler("UpdateTimeInRemindersTable", 5, True);
EndProcedure

&AtClient
Procedure DeferActiveReminders()
	TimeInterval = UserRemindersClientServer.GetTimeIntervalFromString(RepeatedNotificationPeriod);
	If TimeInterval = 0 Then
		TimeInterval = 5*60; // 5 minutes.
	EndIf;
	For Each TableRow In Reminders Do
		TableRow.ReminderTime = CommonClient.SessionDate() + TimeInterval;
		
		ReminderParameters = UserRemindersClientServer.ReminderDetails(TableRow);
		
		AttachReminder(ReminderParameters);
		UserRemindersClient.UpdateRecordInNotificationsCache(TableRow);
	EndDo;
	UpdateRemindersTable();
EndProcedure

&AtClient
Procedure OpenReminder()
	If Items.Reminders.CurrentData = Undefined Then
		Return;
	EndIf;
	Source = Items.Reminders.CurrentData.Source;
	If ValueIsFilled(Source) Then
		ShowValue(, Source);
	Else
		EditReminder();
	EndIf;
EndProcedure

&AtClient
Procedure EditReminder()
	ReminderParameters = New Structure("User,Source,EventTime");
	FillPropertyValues(ReminderParameters, Items.Reminders.CurrentData);
	
	OpenForm("InformationRegister.UserReminders.Form.Reminder", New Structure("Key", GetRecordKey(ReminderParameters)));
EndProcedure

&AtServer
Function GetRecordKey(ReminderParameters)
	Return InformationRegisters.UserReminders.CreateRecordKey(ReminderParameters);
EndFunction

&AtClient
Procedure SetVisibility()
	HasTableData = Reminders.Count() > 0;
	
	If Not HasTableData AND ThisObject.IsOpen() Then
		ThisObject.Close();
	EndIf;
	
	Items.ButtonsPanel.Enabled = HasTableData;
EndProcedure

&AtClient
Procedure FillRepeatedReminderPeriod()
	
	TimeIntervals = UserRemindersClientServer.GetStandardNotificationIntervals();
	Items.RepeatedNotificationPeriod.ChoiceList.Clear();
	For Each Interval In TimeIntervals Do
		Items.RepeatedNotificationPeriod.ChoiceList.Add(Interval);
	EndDo;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "Write_UserReminders" Then 
		UpdateRemindersTable();
	EndIf;
EndProcedure

&AtClient
Function TimeIntervalPresentation(Val TimeCount)
	Result = "";
	
	WeeksPresentation = NStr("ru = ';%1 неделю;;%1 недели;%1 недель;%1 недели'; en = ';%1 week;;%1 weeks;%1 weeks;%1 weeks'; pl = ';%1 tydzień;;%1 tygodnie;%1 tygodnie;%1 tygodnia';es_ES = ';%1 semana;;%1 semanas;%1 semanas;%1 semanas';es_CO = ';%1 semana;;%1 semanas;%1 semanas;%1 semanas';tr = ';%1 hafta;;%1 hafta;%1 hafta;%1 hafta';it = ';%1 settimana;;%1 settimane;%1 settimane;%1 settimane';de = ';%1 Woche;;%1 Wochen;%1 Wochen;%1 Wochen'");
	DaysPresentation   = NStr("ru = ';%1 день;;%1 дня;%1 дней;%1 дня'; en = ';%1 day;;%1 days;%1 days;%1 days'; pl = ';%1 dzień;;%1 dnia;%1 dni;%1 dnia';es_ES = ';%1 día;;%1 días;%1 días;%1 días';es_CO = ';%1 día;;%1 días;%1 días;%1 días';tr = ';%1 gün;;%1 gün;%1 gün;%1 gün';it = ';%1 giorno;%1 giorni;%1 giorni;%1 giorni';de = ';%1 Tag;;%1 Tage;%1 Tage;%1 Tage'");
	HoursPresentation  = NStr("ru = ';%1 час;;%1 часа;%1 часов;%1 часа'; en = ';%1 hour;;%1 hours;%1 hours;%1 hours'; pl = ';%1 godzina;;%1 godziny;%1 godzin;%1 godzin';es_ES = ';%1 hora;;%1 horas;%1 horas;%1 horas';es_CO = ';%1 hora;;%1 horas;%1 horas;%1 horas';tr = ';%1 saat;;%1 saat;%1 saat;%1 saat';it = ';%1 ora;;%1 ore;%1 ore;%1 ore';de = ';%1 Stunde;;%1 Stunden;%1 Stunden;%1 Stunden'");
	MinutesPresentation  = NStr("ru = ';%1 минуту;;%1 минуты;%1 минут;%1 минуты'; en = ';%1 minute;;%1 minutes;%1 minutes;%1 minutes'; pl = ';%1 minutę;;%1 minuty;%1 minut;%1 minuty';es_ES = ';%1 minuto;;%1 minutos;%1 minutos;%1 minutos';es_CO = ';%1 minuto;;%1 minutos;%1 minutos;%1 minutos';tr = ';%1 dakika;;%1 dakika;%1 dakika;%1 dakika';it = ';%1 minuto;;%1 minuti;%1 minuti;%1 minuti';de = ';%1 Minute;;%1 Minuten;%1 Minuten;%1 Minuten'");
	
	TimeCount = Number(TimeCount);
	CurrentDate = CommonClient.SessionDate();
	
	EventCame = True;
	TodayEvent = BegOfDay(CurrentDate - TimeCount) = BegOfDay(CurrentDate);
	PresentationTemplate = NStr("ru = '%1 назад'; en = '%1 back'; pl = '%1 wróć';es_ES = '%1 atrás';es_CO = '%1 atrás';tr = '%1 önce';it = '%1 indietro';de = '%1 zurück'");
	If TimeCount < 0 Then
		PresentationTemplate = NStr("ru = 'через %1'; en = 'in %1'; pl = 'w %1';es_ES = 'en %1';es_CO = 'en %1';tr = '%1'' de';it = 'fra %1';de = 'in %1'");
		TimeCount = -TimeCount;
		EventCame = False;
	EndIf;
	
	WeeksCount = Int(TimeCount / 60/60/24/7);
	DaysCount   = Int(TimeCount / 60/60/24);
	HoursCount  = Int(TimeCount / 60/60);
	MinutesCount  = Int(TimeCount / 60);
	SecondsCount = Int(TimeCount);
	
	SecondsCount = SecondsCount - MinutesCount * 60;
	MinutesCount  = MinutesCount - HoursCount * 60;
	HoursCount  = HoursCount - DaysCount * 24;
	DaysCount   = DaysCount - WeeksCount * 7;
	
	If WeeksCount > 4 Then
		If EventCame Then
			Return NStr("ru = 'очень давно'; en = 'a long time ago'; pl = 'bardzo dawno';es_ES = 'hace mucho tiempo';es_CO = 'hace mucho tiempo';tr = 'uzun süre önce';it = 'molto tempo fa';de = 'vor langer Zeit'");
		Else
			Return NStr("ru = 'еще не скоро'; en = 'not soon'; pl = 'nieprędko';es_ES = 'no pronto';es_CO = 'no pronto';tr = 'yakın değil';it = 'non a breve';de = 'nicht bald'");
		EndIf;
		
	ElsIf WeeksCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(WeeksPresentation, WeeksCount);
	ElsIf WeeksCount > 0 Then
		Result = NStr("ru = 'неделя'; en = 'week'; pl = 'tydzień';es_ES = 'semana';es_CO = 'semana';tr = 'hafta';it = 'settimana';de = 'woche'");
		
	ElsIf DaysCount > 1 Then
		If BegOfDay(CurrentDate) - BegOfDay(CurrentDate - TimeCount) = 60*60*24 * 2 Then
			If EventCame Then
				Return NStr("ru = 'позавчера'; en = 'day before yesterday'; pl = 'przedwczoraj  ';es_ES = 'anteayer';es_CO = 'anteayer';tr = 'dünden önceki gün';it = 'l''altro ieri';de = 'vorgestern'");
			Else
				Return NStr("ru = 'послезавтра'; en = 'day after tomorrow'; pl = 'pojutrze';es_ES = 'pasado mañana';es_CO = 'pasado mañana';tr = 'yarından sonraki gün';it = 'Dopodomani';de = 'übermorgen'");
			EndIf;
		Else
			Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(DaysPresentation, DaysCount);
		EndIf;
	ElsIf HoursCount + DaysCount * 24 > 3 AND Not TodayEvent Then
			If EventCame Then
				Return NStr("ru = 'вчера'; en = 'yesterday'; pl = 'wczoraj';es_ES = 'ayer';es_CO = 'ayer';tr = 'dün';it = 'ieri';de = 'gestern'");
			Else
				Return NStr("ru = 'завтра'; en = 'tomorrow'; pl = 'jutro';es_ES = 'mañana';es_CO = 'mañana';tr = 'yarın';it = 'domani';de = 'morgen'");
			EndIf;
	ElsIf DaysCount > 0 Then
		Result = NStr("ru = 'день'; en = 'day'; pl = 'dzień';es_ES = 'día';es_CO = 'día';tr = 'gün';it = 'giorno';de = 'Tag'");
	ElsIf HoursCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(HoursPresentation, HoursCount);
	ElsIf HoursCount > 0 Then
		Result = NStr("ru = 'час'; en = 'hour'; pl = 'godzina';es_ES = 'hora';es_CO = 'hora';tr = 'saat';it = 'ora';de = 'Stunde'");
		
	ElsIf MinutesCount > 1 Then
		Result = StringFunctionsClientServer.StringWithNumberForAnyLanguage(MinutesPresentation, MinutesCount);
	ElsIf MinutesCount > 0 Then
		Result = NStr("ru = 'минуту'; en = 'minute'; pl = 'minuta';es_ES = 'minuto';es_CO = 'minuto';tr = 'dakika';it = 'minuto';de = 'Minute'");
		
	Else
		Return NStr("ru = 'сейчас'; en = 'now'; pl = 'teraz';es_ES = 'ahora';es_CO = 'ahora';tr = 'şimdi';it = 'adesso';de = 'jetzt'");
	EndIf;
	
	Result = StringFunctionsClientServer.SubstituteParametersToString(PresentationTemplate, Result);
	
	Return Result;
EndFunction

#EndRegion
