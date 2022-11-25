
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	SubsystemSettings = UserRemindersInternal.SubsystemSettings();
	
	Object.User = Users.CurrentUser();
	
	If Parameters.Property("Source") Then 
		Object.Source = Parameters.Source;
		Object.Details = Common.SubjectString(Object.Source);
	EndIf;
	
	If Parameters.Property("Key") Then
		InitialParameters = New Structure("User,EventTime,Source");
		FillPropertyValues(InitialParameters, Parameters.Key);
		InitialParameters = New FixedStructure(InitialParameters);
	EndIf;
	
	If ValueIsFilled(Object.Source) Then
		FillSourceAttributesList();
	EndIf;
	
	FillPeriodicityOptions();
	DetermineSelectedPeriodicityOption();	
	
	IsNew = Not ValueIsFilled(Object.SourceRecordKey);
	Items.Delete.Visible = Not IsNew;
	
	Items.Subject.Visible = ValueIsFilled(Object.Source);
	Items.ReminderSubject.Title = Common.SubjectString(Object.Source);
	If ValueIsFilled(Object.Source) Then
		WindowOptionsKey = "ReminderOnSubject";
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	Schedule = CurrentObject.Schedule.Get();
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToCurrentTime Then
		CurrentObject.EventTime = CurrentSessionDate() + Object.ReminderInterval;
		CurrentObject.ReminderTime = CurrentObject.EventTime;
		CurrentObject.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime;
	ElsIf CurrentObject.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToSubjectTime Then
		DateInSource = UserRemindersInternal.GetSubjectAttributeValue(Object.Source, Object.SourceAttributeName);
		If ValueIsFilled(DateInSource) Then
			DateInSource = CalculateClosestDate(DateInSource);
			CurrentObject.EventTime = DateInSource;
			CurrentObject.ReminderTime = DateInSource - Object.ReminderInterval;
		Else
			CurrentObject.EventTime = '00010101';
		EndIf;
	ElsIf CurrentObject.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime Then
		CurrentObject.ReminderTime = Object.EventTime;
	ElsIf CurrentObject.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.Periodic Then
		ClosestReminderTime = UserRemindersInternal.GetClosestEventDateOnSchedule(Schedule);
		If ClosestReminderTime = Undefined Then
			ClosestReminderTime = CurrentSessionDate();
		EndIf;
		CurrentObject.EventTime = ClosestReminderTime;
		CurrentObject.ReminderTime = CurrentObject.EventTime;
	EndIf;
	
	If CurrentObject.ReminderTimeSettingMethod <> Enums.ReminderTimeSettingMethods.Periodic Then
		Schedule = Undefined;
	EndIf;
	
	CurrentObject.Schedule = New ValueStorage(Schedule, New Deflation(9));
	
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	RecordSet.Filter.User.Set(CurrentObject.User);
	RecordSet.Filter.Source.Set(CurrentObject.Source);
	RecordSet.Read();
	If RecordSet.Count() > 0 Then
		BusyTime = RecordSet.Unload(,"EventTime").UnloadColumn("EventTime");
		While BusyTime.Find(CurrentObject.EventTime) <> Undefined Do
			CurrentObject.EventTime = CurrentObject.EventTime + 1;
		EndDo;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	// If this is a new record.
	If Not ValueIsFilled(Object.SourceRecordKey) Then
		If Items.SourceAttributeName.ChoiceList.Count() > 0 Then
			Object.SourceAttributeName = Items.SourceAttributeName.ChoiceList[0].Value;
			Object.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime");
		EndIf;
		Object.EventTime = CommonClient.SessionDate();
	EndIf;
	
	FillTimeList();
	
	FillNotificationMethods();
	If Items.SourceAttributeName.ChoiceList.Count() = 0 Then
		Items.ReminderTimeSettingMethod.ChoiceList.Delete(Items.ReminderTimeSettingMethod.ChoiceList.FindByValue(GetKeyByValueInMap(GetPredefinedNotificationMethods(),PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime"))));
	EndIf;		
		
	If Object.ReminderInterval > 0 Then
		TimeIntervalString = UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	EndIf;
	
	PredefinedNotificationMethods = GetPredefinedNotificationMethods();
	SelectedMethod = GetKeyByValueInMap(PredefinedNotificationMethods, Object.ReminderTimeSettingMethod);
	
	If Object.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToCurrentTime") Then
		ReminderTimeSettingMethod = NStr("ru = 'через'; en = 'in'; pl = 'w';es_ES = 'en';es_CO = 'en';tr = 'içinde';it = 'in';de = 'im'") + " " + UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	Else
		ReminderTimeSettingMethod = SelectedMethod;
	EndIf;
	
	SetVisibility();
	
	UpdateEstimatedReminderTime();
	AttachIdleHandler("UpdateEstimatedReminderTime", 1);
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	// For cache update
	ParametersStructure = UserRemindersClientServer.ReminderDetails(Object, True);
	ParametersStructure.Insert("PictureIndex", 2);
	
	UserRemindersClient.UpdateRecordInNotificationsCache(ParametersStructure);
	
	UserRemindersClient.ResetCurrentNotificationsCheckTimer();
	
	If ValueIsFilled(Object.Source) Then 
		NotifyChanged(Object.Source);
	EndIf;
	
	Notify("Write_UserReminders", New Structure, ThisObject);
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	If InitialParameters <> Undefined Then 
		UserRemindersClient.DeleteRecordFromNotificationsCache(InitialParameters);
	EndIf;
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ReminderTimeSettingMethodOnChange(Item)
	ClearMessages();
	
	TimeInterval = UserRemindersClientServer.GetTimeIntervalFromString(ReminderTimeSettingMethod);
	If TimeInterval > 0 Then
		TimeIntervalString = UserRemindersClientServer.TimePresentation(TimeInterval);
		ReminderTimeSettingMethod = NStr("ru = 'через'; en = 'in'; pl = 'w';es_ES = 'en';es_CO = 'en';tr = 'içinde';it = 'in';de = 'im'") + " " + TimeIntervalString;
	Else
		If Items.ReminderTimeSettingMethod.ChoiceList.FindByValue(ReminderTimeSettingMethod) = Undefined Then
			CommonClientServer.MessageToUser(NStr("ru = 'Интервал времени не определен.'; en = 'Time interval is not defined.'; pl = 'Nie określono interwału czasowego.';es_ES = 'Intervalo de tiempo no está especificado.';es_CO = 'Intervalo de tiempo no está especificado.';tr = 'Zaman aralığı belirtilmemiş.';it = 'L''intervallo di tempo non è definito.';de = 'Zeitintervall nicht angegeben.'"), , "ReminderTimeSettingMethod");
		EndIf;
	EndIf;
	
	PredefinedNotificationMethods = GetPredefinedNotificationMethods();
	SelectedMethod = PredefinedNotificationMethods.Get(ReminderTimeSettingMethod);
	
	If SelectedMethod = Undefined Then
		Object.ReminderTimeSettingMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToCurrentTime");
	Else
		Object.ReminderTimeSettingMethod = SelectedMethod;
	EndIf;
	
	Object.ReminderInterval = TimeInterval;
	
	SetVisibility();		
EndProcedure

&AtClient
Procedure OnChangeTimeInterval(Item)
	Object.ReminderInterval = UserRemindersClientServer.GetTimeIntervalFromString(TimeIntervalString);
	If Object.ReminderInterval > 0 Then
		TimeIntervalString = UserRemindersClientServer.TimePresentation(Object.ReminderInterval);
	Else
		CommonClientServer.MessageToUser(NStr("ru = 'Интервал времени не определен'; en = 'Time interval not defined'; pl = 'Nie określono interwału czasowego';es_ES = 'Intervalo de tiempo no está especificado';es_CO = 'Intervalo de tiempo no está especificado';tr = 'Zaman aralığı belirtilmemiş.';it = 'L''intervallo di tempo non è definito';de = 'Zeitintervall nicht angegeben'"), , "TimeIntervalString");
	EndIf;
EndProcedure

&AtClient
Procedure OnChange(Item)
	OnChangeSchedule();
EndProcedure

&AtClient
Procedure PeriodicityOptionOpen(Item, StandardProcessing)
	StandardProcessing = False;
	OnChangeSchedule();
EndProcedure

&AtClient
Procedure DateOnChange(Item)
	FillTimeList();
EndProcedure

&AtClient
Procedure TimeOnChange(Item)
	Object.EventTime = BegOfMinute(Object.EventTime);
EndProcedure

&AtClient
Procedure ReminderSubjectClick(Item)
	ShowValue(, Object.Source);
EndProcedure

&AtClient
Procedure SourceAttributeNameClear(Item, StandardProcessing)
	StandardProcessing = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Delete(Command)
	
	DialogButtons = New ValueList;
	DialogButtons.Add(DialogReturnCode.Yes, NStr("ru = 'Удалить'; en = 'Delete'; pl = 'Usuń';es_ES = 'Borrar';es_CO = 'Borrar';tr = 'Sil';it = 'Elimina';de = 'Löschen'"));
	DialogButtons.Add(DialogReturnCode.Cancel, NStr("ru = 'Не удалять'; en = 'Do not delete'; pl = 'Nie usuwaj';es_ES = 'No borrar';es_CO = 'No borrar';tr = 'Silme';it = 'Non cancellare';de = 'Nicht löschen'"));
	
	NotifyDescription = New NotifyDescription("DeleteReminder", ThisObject);
	ShowQueryBox(NotifyDescription, NStr("ru = 'Удалить напоминание?'; en = 'Do you want to delete the reminder?'; pl = 'Usunąć przypomnienie?';es_ES = '¿Descartar el recordatorio?';es_CO = '¿Descartar el recordatorio?';tr = 'Hatırlatıcı silinsin mi?';it = 'Volete eliminare il promemoria?';de = 'Die Erinnerung ablehnen?'"), DialogButtons);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DeleteReminder(QuestionResult, AdditionalParameters) Export
	
	If QuestionResult = DialogReturnCode.Yes Then
		ThisObject.Modified = False;
		If InitialParameters <> Undefined Then 
			DisableReminder();
			UserRemindersClient.DeleteRecordFromNotificationsCache(InitialParameters);
			Notify("Write_UserReminders", New Structure, Object.SourceRecordKey);
			NotifyChanged(Type("InformationRegisterRecordKey.UserReminders"));
		EndIf;
		If ThisObject.IsOpen() Then
			Close();
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Procedure DisableReminder()
	UserRemindersInternal.DisableReminder(InitialParameters, False);
EndProcedure

&AtServerNoContext
Function SourceAttributeExistsAndContainsDateType(SourceMetadata, AttributeName, CheckDate = False)
	Result = False;
	If SourceMetadata.Attributes.Find(AttributeName) <> Undefined
		AND SourceMetadata.Attributes[AttributeName].Type.ContainsType(Type("Date")) Then
			Result = True;
	EndIf;
	Return Result;
EndFunction

&AtClientAtServerNoContext
Function GetKeyByValueInMap(Map, Value)
	Result = Undefined;
	For Each KeyAndValue In Map Do
		If TypeOf(Value) = Type("JobSchedule") Then
			If CommonClientServer.SchedulesAreIdentical(KeyAndValue.Value, Value) Then
		    	Return KeyAndValue.Key;
			EndIf;
		Else
			If KeyAndValue.Value = Value Then
				Return KeyAndValue.Key;
			EndIf;
		EndIf;
	EndDo;
	Return Result;	
EndFunction

&AtClient
Function GetPredefinedNotificationMethods()
	Result = New Map;
	Result.Insert(NStr("ru = 'относительно предмета'; en = 'relative to subject'; pl = 'w odniesieniu do przedmiotu';es_ES = 'relativo al tema';es_CO = 'relativo al tema';tr = 'konuya göre';it = 'Relativo all''argomento';de = 'relativ zum Thema'"), PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime"));
	Result.Insert(NStr("ru = 'в указанное время'; en = 'at specified time'; pl = 'w określonym czasie';es_ES = 'en la hora especificada';es_CO = 'en la hora especificada';tr = 'belirli bir zamanda';it = 'al tempo specifico';de = 'zu einer bestimmten Zeit'"), PredefinedValue("Enum.ReminderTimeSettingMethods.AtSpecifiedTime"));
	Result.Insert(NStr("ru = 'периодический'; en = 'periodic'; pl = 'okresowy';es_ES = 'periódico';es_CO = 'periódico';tr = 'periyodik';it = 'periodico';de = 'periodisch'"), PredefinedValue("Enum.ReminderTimeSettingMethods.Periodic"));
	Return Result;
EndFunction

&AtClient
Procedure FillNotificationMethods()
	NotificationMethods = Items.ReminderTimeSettingMethod.ChoiceList;
	NotificationMethods.Clear();
	For Each Method In GetPredefinedNotificationMethods() Do
		NotificationMethods.Add(Method.Key);
	EndDo;	
	
	Items.TimeIntervalRelativeToSource.ChoiceList.Clear();
	TimeIntervals = SubsystemSettings.StandardIntervals;
	For Each Interval In TimeIntervals Do
		NotificationMethods.Add(NStr("ru = 'через'; en = 'in'; pl = 'w';es_ES = 'en';es_CO = 'en';tr = 'içinde';it = 'in';de = 'im'") + " " + Interval);
		Items.TimeIntervalRelativeToSource.ChoiceList.Add(Interval);
	EndDo;
EndProcedure

&AtClient
Procedure FillTimeList()
	Items.Time.ChoiceList.Clear();
	For Hour = 0 To 23 Do 
		For Period = 0 To 1 Do
			Time = Hour*60*60 + Period*30*60;
			Items.Time.ChoiceList.Add(BegOfDay(Object.EventTime) + Time, "" + Hour + ":" + Format(Period*30,"ND=2; NZ=00"));		
		EndDo;
	EndDo;
EndProcedure

&AtServer
Procedure FillSourceAttributesList()
	
	AttributesWithDates = New Array;
	
	// Fill with default values.
	SourceMetadata = Object.Source.Metadata();	
	For Each Attribute In SourceMetadata.Attributes Do
		If Not StrStartsWith(Lower(Attribute.Name), Lower("Delete"))
			AND SourceAttributeExistsAndContainsDateType(SourceMetadata, Attribute.Name) Then
			AttributesWithDates.Add(Attribute.Name);
		EndIf;
	EndDo;
	
	// Get an overridden array of attributes.
	SSLSubsystemsIntegration.OnFillSourceAttributesListWithReminderDates(Object.Source, AttributesWithDates);
	UserRemindersOverridable.OnFillSourceAttributesListWithReminderDates(Object.Source, AttributesWithDates);
	
	// For backward compatibility.
	UserRemindersClientServerOverridable.OnFillSourceAttributesListWithReminderDates(Object.Source, AttributesWithDates);
	
	Items.SourceAttributeName.ChoiceList.Clear();
	AttributeValues = Common.ObjectAttributesValues(Object.Source, StrConcat(AttributesWithDates, ","));
	
	For Each AttributeName In AttributesWithDates Do
		If SourceAttributeExistsAndContainsDateType(SourceMetadata, AttributeName) Then
			If TypeOf(Object.Source[AttributeName]) = Type("Date") Then
				Attribute = SourceMetadata.Attributes.Find(AttributeName);
				AttributePresentation = Attribute.Presentation();
				DateInAttribute = AttributeValues[Attribute.Name];
				NearestDate = CalculateClosestDate(DateInAttribute);
				If ValueIsFilled(NearestDate) AND DateInAttribute < CurrentSessionDate() Then
					AttributePresentation = AttributePresentation + " (" + Format(NearestDate, "DLF=D") + ")";
				EndIf;
				If Items.SourceAttributeName.ChoiceList.FindByValue(AttributeName) = Undefined Then
					Items.SourceAttributeName.ChoiceList.Add(AttributeName, AttributePresentation);
				EndIf;
			EndIf;
		EndIf;
	EndDo;
	
EndProcedure

&AtServer
Procedure FillPeriodicityOptions()
	Items.FrequencyOption.ChoiceList.Clear();
	SchedulesList = SubsystemSettings.Schedules;
	For Each StandardSchedule In SchedulesList Do
		Items.FrequencyOption.ChoiceList.Add(StandardSchedule.Key, StandardSchedule.Key);
	EndDo;
	Items.FrequencyOption.ChoiceList.SortByPresentation();
	Items.FrequencyOption.ChoiceList.Add("", NStr("ru = 'по заданному расписанию...'; en = 'on set schedule...'; pl = 'zgodnie z określonym harmonogramem...';es_ES = 'en el horario especificado...';es_CO = 'en el horario especificado...';tr = 'belirtilen programda ...';it = 'sulla pianificazione impostata...';de = 'nach dem angegebenen Zeitplan...'"));	
EndProcedure

&AtClient
Procedure SetVisibility()
	
	PredefinedNotificationMethods = GetPredefinedNotificationMethods();
	SelectedMethod = PredefinedNotificationMethods.Get(ReminderTimeSettingMethod);
	
	If SelectedMethod <> Undefined Then
		If SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.AtSpecifiedTime") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.DateTime;
		ElsIf SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.RelativeToSubjectTime") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.SourceSetting;
		ElsIf SelectedMethod = PredefinedValue("Enum.ReminderTimeSettingMethods.Periodic") Then
			Items.DetailedSettingsPanel.CurrentPage = Items.FrequencySetting;
		EndIf;			
	Else
		Items.DetailedSettingsPanel.CurrentPage = Items.NoDetails;
	EndIf;
	
EndProcedure

&AtClient
Procedure OpenScheduleSettingDialog()
	If Schedule = Undefined Then 
		Schedule = New JobSchedule;
		Schedule.DaysRepeatPeriod = 1;
	EndIf;
	ScheduleDialog = New ScheduledJobDialog(Schedule);
	NotifyDescription = New NotifyDescription("OpenScheduleSettingsDialogCompletion", ThisObject);
	ScheduleDialog.Show(NotifyDescription);
EndProcedure

&AtClient
Procedure OpenScheduleSettingsDialogCompletion(SelectedSchedule, AdditionalParameters) Export
	If SelectedSchedule = Undefined Then
		Return;
	EndIf;
	Schedule = SelectedSchedule;
	If Not ScheduleMeetsRequirements(Schedule) Then 
		ShowMessageBox(, NStr("ru = 'Периодичность в течение дня не поддерживается, соответствующие настройки очищены.'; en = 'Periodicity within the day is not supported. The settings are cleared.'; pl = 'Dzienna częstotliwość nie jest obsługiwana. Odpowiednie ustawienia zostały oczyszczone.';es_ES = 'Frecuencia diaria no se admite. Configuraciones correspondientes eliminadas.';es_CO = 'Frecuencia diaria no se admite. Configuraciones correspondientes eliminadas.';tr = 'Günlük sıklık desteklenmiyor. İlgili ayarlar temizlendi.';it = 'La periodicità entro il giorno non è supportata. Le impostazioni vengono cancellate.';de = 'Die tägliche Häufigkeit wird nicht unterstützt. Entsprechende Einstellungen wurden gelöscht.'"));
	EndIf;
	NormalizeSchedule(Schedule);
	DetermineSelectedPeriodicityOption();
EndProcedure

&AtClient
Function ScheduleMeetsRequirements(ScheduleToCheck)
	If ScheduleToCheck.RepeatPeriodInDay > 0 Then
		Return False;
	EndIf;
	
	For Each DaySchedule In ScheduleToCheck.DetailedDailySchedules Do
		If DaySchedule.RepeatPeriodInDay > 0 Then
			Return False;
		EndIf;
	EndDo;
	
	Return True;
EndFunction

&AtClient
Procedure NormalizeSchedule(ScheduleToNormalize);
	ScheduleToNormalize.EndTime = '000101010000';
	ScheduleToNormalize.RepeatPeriodInDay = 0;
	ScheduleToNormalize.RepeatPause = 0;
	ScheduleToNormalize.CompletionInterval = 0;
	For Each DaySchedule In ScheduleToNormalize.DetailedDailySchedules Do
		DaySchedule.EndTime = '000101010000';
		DaySchedule.CompletionTime =  DaySchedule.EndTime;
		DaySchedule.RepeatPeriodInDay = 0;
		DaySchedule.RepeatPause = 0;
		DaySchedule.CompletionInterval = 0;
	EndDo;
EndProcedure

&AtServer
Procedure DetermineSelectedPeriodicityOption()
	StandardSchedules = SubsystemSettings.Schedules;
	
	If Schedule = Undefined Then
		FrequencyOption = Items.FrequencyOption.ChoiceList.Get(0).Value;
		Schedule = StandardSchedules[FrequencyOption];
	Else
		FrequencyOption = GetKeyByValueInMap(StandardSchedules, Schedule);
	EndIf;
	
	Items.FrequencyOption.OpenButton = IsBlankString(FrequencyOption);
	Items.FrequencyOption.ToolTip = Schedule;
EndProcedure

&AtClient
Procedure OnChangeSchedule()
	UserSetting = IsBlankString(FrequencyOption);
	If UserSetting Then
		OpenScheduleSettingDialog();
	Else
		StandardSchedules = SubsystemSettings.Schedules;
		Schedule = StandardSchedules[FrequencyOption];
	EndIf;
	DetermineSelectedPeriodicityOption();
EndProcedure

&AtServer
Function CalculateClosestDate(InitialDate)
	CurrentDate = CurrentSessionDate();
	If Not ValueIsFilled(InitialDate) Or InitialDate > CurrentDate Then
		Return InitialDate;
	EndIf;
	
	Result = AddMonth(InitialDate, 12 * (Year(CurrentDate) - Year(InitialDate)));
	If Result < CurrentDate Then
		Result = AddMonth(Result, 12);
	EndIf;
	
	Return Result;
EndFunction

&AtClient
Function EstimatedTimeAsString()
	
	CurrentDate = CommonClient.SessionDate();
	EstimatedReminderTime = CurrentDate + Object.ReminderInterval;
	
	OutputDate = Day(EstimatedReminderTime) <> Day(CurrentDate);
	
	DateAsString = Format(EstimatedReminderTime,"DLF=DD");
	TimeAsString = Format(EstimatedReminderTime,"DF=H:mm");
	
	Return "(" + ?(OutputDate, DateAsString + " ", "") +  TimeAsString + ")";
	
EndFunction

&AtClient
Procedure UpdateEstimatedReminderTime()
	Items.EstimatedReminderTime.Title = EstimatedTimeAsString();
EndProcedure

#EndRegion
