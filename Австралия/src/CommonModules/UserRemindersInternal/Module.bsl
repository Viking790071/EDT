#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonOverridable.OnAddClientParametersOnStart. 
Procedure OnAddClientParametersOnStart(Parameters) Export
	
	Parameters.Insert("ReminderSettings", 
		New FixedStructure("UseReminders", GetRemindersSettings().UseReminders));
		
EndProcedure 

// See CommonOverridable.OnAddClientParameters. 
Procedure OnAddClientParameters(Parameters) Export
	
	Parameters.Insert("ReminderSettings", 
		New FixedStructure(GetRemindersSettings()));
	
EndProcedure

// See CommonOverridable.OnAddMetadataObjectsRenaming. 
Procedure OnAddMetadataObjectsRenaming(Total) Export
	
	Library = "StandardSubsystems";
	
	OldName = "Role.RemindersUsage";
	NewName  = "Role.AddEditNotifications";
	Common.AddRenaming(Total, "2.3.3.11", OldName, NewName, Library);
	
EndProcedure

// See AccessManagementOverridable.OnFillListsWithAccessRestriction. 
Procedure OnFillListsWithAccessRestriction(Lists) Export
	
	Lists.Insert(Metadata.InformationRegisters.UserReminders, True);
	
EndProcedure

#EndRegion

#Region Private

Function SubsystemSettings() Export
	Settings = New Structure;
	Settings.Insert("Schedules", GetStandardSchedulesForReminder());
	Settings.Insert("StandardIntervals", UserRemindersClientServer.GetStandardNotificationIntervals());
	UserRemindersOverridable.OnDefineSettings(Settings);
	
	// For backward compatibility.
	UserRemindersClientServerOverridable.OnGetStandardSchedulesForReminder(Settings.Schedules);
	UserRemindersClientServerOverridable.OnGetStandardNotificationIntervals(Settings.StandardIntervals);
	
	Return Settings;
EndFunction

// Returns standard schedules for periodic reminders.
Function GetStandardSchedulesForReminder()
	
	Result = New Map;
		
	// On Mondays at 9 a.m.
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	WeekDays = New Array;
	WeekDays.Add(1);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("ru = 'по понедельникам, в 9:00'; en = 'on Mondays at 9 a.m.'; pl = 'w poniedziałki o 9 rano';es_ES = 'los lunes a las 09:00';es_CO = 'los lunes a las 09:00';tr = 'Pazartesi günleri, saat 09:00';it = 'il lunedì alle 09:00';de = 'montags um 9:00 Uhr'"), Schedule);
	
	// On Fridays at 3 p.m.
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101150000';
	WeekDays = New Array;
	WeekDays.Add(5);
	Schedule.WeekDays = WeekDays;
	Result.Insert(NStr("ru = 'по пятницам, в 15:00'; en = 'on Fridays at 3 p.m.'; pl = 'w piątki o 3 po południu';es_ES = 'los viernes a las 15:00';es_CO = 'los viernes a las 15:00';tr = 'Cuma günleri, saat 15:00';it = 'il venerdì alle 03:00';de = 'freitags um 15:00 Uhr'"), Schedule);
	
	// Every day at 9:00 a.m.
	Schedule = New JobSchedule;
	Schedule.DaysRepeatPeriod = 1;
	Schedule.WeeksPeriod = 1;
	Schedule.BeginTime = '00010101090000';
	Result.Insert(NStr("ru = 'каждый день, в 9:00'; en = 'every day at 9:00'; pl = 'codziennie o 9:00';es_ES = 'cada día a las 09:00';es_CO = 'cada día a las 09:00';tr = 'her gün, saat 9:00';it = 'tutti i giorni alle 9:00';de = 'täglich um 9:00 Uhr'"), Schedule);
	
	Return Result;
	
EndFunction

// Returns settings structure of user reminders.
Function GetRemindersSettings()
	
	Result = New Structure;
	Result.Insert("UseReminders", HasRightToUseReminders() AND GetFunctionalOption("UseUserReminders"));
	Result.Insert("RemindersCheckInterval", GetRemindersCheckInterval());
	
	Return Result;
	
EndFunction

// Checks if the user has the right to change the UserReminders information register.
//
// Returns:
//  Boolean - True if the user has the right.
Function HasRightToUseReminders()
	Return AccessRight("Update", Metadata.InformationRegisters.UserReminders); 
EndFunction

// Returns the closest date on schedule relative to the date passed in the parameter.
//
// Parameters:
//  Schedule - JobSchedule - a schedule.
//  PreviousDate - Date - date of the previous event according to the schedule.
//
// Returns:
//   Date - date and time of the next event according to the schedule.
//
Function GetClosestEventDateOnSchedule(Schedule, PreviousDate = '000101010000', SearchForFutureDatesOnly = True) Export

	Result = Undefined;
	CurrentSessionDate = CurrentSessionDate();
	
	StartingDate = PreviousDate;
	If Not ValueIsFilled(StartingDate) Then
		StartingDate = CurrentSessionDate;
	EndIf;
	If SearchForFutureDatesOnly Then
		StartingDate = Max(StartingDate, CurrentSessionDate);
	EndIf;
	
	Calendar = GetCalendarForFuture(365*4+1, StartingDate, Schedule.BeginDate, Schedule.DaysRepeatPeriod, Schedule.WeeksPeriod);
	
	WeekDays = Schedule.WeekDays;
	If WeekDays.Count() = 0 Then
		WeekDays = New Array;
		For Day = 1 To 7 Do
			WeekDays.Add(Day);
		EndDo;
	EndIf;
	
	Months = Schedule.Months;
	If Months.Count() = 0 Then
		Months = New Array;
		For Month = 1 To 12 Do
			Months.Add(Month);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = "SELECT * INTO Calendar FROM &Calendar AS Calendar";
	Query.SetParameter("Calendar", Calendar);
	Query.Execute();
	
	Query.SetParameter("StartDate",			Schedule.BeginDate);
	Query.SetParameter("EndDate",			Schedule.EndDate);
	Query.SetParameter("WeekDays",			WeekDays);
	Query.SetParameter("Months",				Months);
	Query.SetParameter("DayInMonth",		Schedule.DayInMonth);
	Query.SetParameter("WeekDayInMonth",	Schedule.WeekDayInMonth);
	Query.SetParameter("DaysRepeatPeriod",	?(Schedule.DaysRepeatPeriod = 0,1,Schedule.DaysRepeatPeriod));
	Query.SetParameter("WeeksPeriod",		?(Schedule.WeeksPeriod = 0,1,Schedule.WeeksPeriod));
	
	Query.Text = 
	"SELECT
	|	Calendar.Date,
	|	Calendar.MonthNumber,
	|	Calendar.WeekDayNumberInMonth,
	|	Calendar.WeekDayNumberFromMonthEnd,
	|	Calendar.DayNumberInMonth,
	|	Calendar.DayNumberInMonthFromMonthEnd,
	|	Calendar.DayNumberInWeek,
	|	Calendar.DayNumberInPeriod,
	|	Calendar.WeekNumberInPeriod
	|FROM
	|	Calendar AS Calendar
	|WHERE
	|	CASE
	|			WHEN &StartDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date >= &StartDate
	|		END
	|	AND CASE
	|			WHEN &EndDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date <= &EndDate
	|		END
	|	AND Calendar.DayNumberInWeek IN(&WeekDays)
	|	AND Calendar.MonthNumber IN(&Months)
	|	AND CASE
	|			WHEN &DayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &DayInMonth > 0
	|						THEN Calendar.DayNumberInMonth = &DayInMonth
	|					ELSE Calendar.DayNumberInMonthFromMonthEnd = -&DayInMonth
	|				END
	|		END
	|	AND CASE
	|			WHEN &WeekDayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &WeekDayInMonth > 0
	|						THEN Calendar.WeekDayNumberInMonth = &WeekDayInMonth
	|					ELSE Calendar.WeekDayNumberFromMonthEnd = -&WeekDayInMonth
	|				END
	|		END
	|	AND Calendar.DayNumberInPeriod = &DaysRepeatPeriod
	|	AND Calendar.WeekNumberInPeriod = &WeeksPeriod";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		NearestDate = Selection.Date;
		StartingTime = '00010101';
		If BegOfDay(NearestDate) = BegOfDay(StartingDate) Then
			StartingTime = StartingTime + (StartingDate-BegOfDay(StartingDate));
		EndIf;
		
		ClosestTime = GetClosestTimeFromSchedule(Schedule, StartingTime);
		If ClosestTime <> Undefined Then
			Result = NearestDate + (ClosestTime - '00010101');
		Else
			If Selection.Next() Then
				Time = GetClosestTimeFromSchedule(Schedule);
				Result = Selection.Date + (Time - '00010101');
			EndIf;
		EndIf;
	EndIf;
	
	Return Result;
	
EndFunction

Function GetCalendarForFuture(CalendarDaysCount, StartingDate, Val PeriodicityStartDate = Undefined, Val PeriodDays = 1, Val PeriodWeeks = 1) 
	
	If PeriodWeeks = 0 Then 
		PeriodWeeks = 1;
	EndIf;
	
	If PeriodDays = 0 Then
		PeriodDays = 1;
	EndIf;
	
	If Not ValueIsFilled(PeriodicityStartDate) Then
		PeriodicityStartDate = StartingDate;
	EndIf;
	
	Calendar = New ValueTable;
	Calendar.Columns.Add("Date", New TypeDescription("Date",,,New DateQualifiers()));
	Calendar.Columns.Add("MonthNumber", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("WeekDayNumberInMonth", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("WeekDayNumberFromMonthEnd", New TypeDescription("Number",New NumberQualifiers(1,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInMonth", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInMonthFromMonthEnd", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));
	Calendar.Columns.Add("DayNumberInWeek", New TypeDescription("Number",New NumberQualifiers(2,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("DayNumberInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));	
	Calendar.Columns.Add("WeekNumberInPeriod", New TypeDescription("Number",New NumberQualifiers(3,0,AllowedSign.Nonnegative)));
	
	Date = BegOfDay(StartingDate);
	PeriodicityStartDate = BegOfDay(PeriodicityStartDate);
	DayNumberInPeriod = 0;
	WeekNumberInPeriod = 0;
	
	If PeriodicityStartDate <= Date Then
		DaysCount = (Date - PeriodicityStartDate)/60/60/24;
		DayNumberInPeriod = DaysCount - Int(DaysCount/PeriodDays)*PeriodDays;
		
		WeeksCount = Int(DaysCount / 7);
		WeekNumberInPeriod = WeeksCount - Int(WeeksCount/PeriodWeeks)*PeriodWeeks;
	EndIf;
	
	If DayNumberInPeriod = 0 Then 
		DayNumberInPeriod = PeriodDays;
	EndIf;
	
	If WeekNumberInPeriod = 0 Then 
		WeekNumberInPeriod = PeriodWeeks;
	EndIf;
	
	For Counter = 0 To CalendarDaysCount - 1 Do
		
		Date = BegOfDay(StartingDate) + Counter * 60*60*24;
		NewRow = Calendar.Add();
		NewRow.Date = Date;
		NewRow.MonthNumber = Month(Date);
		NewRow.WeekDayNumberInMonth = Int((Date - BegOfMonth(Date))/60/60/24/7) + 1;
		NewRow.WeekDayNumberFromMonthEnd = Int((EndOfMonth(BegOfDay(Date)) - Date)/60/60/24/7) + 1;
		NewRow.DayNumberInMonth = Day(Date);
		NewRow.DayNumberInMonthFromMonthEnd = Day(EndOfMonth(BegOfDay(Date))) - Day(Date) + 1;
		NewRow.DayNumberInWeek = WeekDay(Date);
		
		If PeriodicityStartDate <= Date Then
			NewRow.DayNumberInPeriod = DayNumberInPeriod;
			NewRow.WeekNumberInPeriod = WeekNumberInPeriod;
			
			DayNumberInPeriod = ?(DayNumberInPeriod+1 > PeriodDays, 1, DayNumberInPeriod+1);
			
			If NewRow.DayNumberInWeek = 1 Then
				WeekNumberInPeriod = ?(WeekNumberInPeriod+1 > PeriodWeeks, 1, WeekNumberInPeriod+1);
			EndIf;
		EndIf;
		
	EndDo;
	
	Return Calendar;
	
EndFunction

Function GetClosestTimeFromSchedule(Schedule, Val StartingTime = '000101010000')
	
	Result = Undefined;
	
	ValueList = New ValueList;
	
	If Schedule.DetailedDailySchedules.Count() = 0 Then
		ValueList.Add(Schedule.BeginTime);
	Else
		For Each DaySchedule In Schedule.DetailedDailySchedules Do
			ValueList.Add(DaySchedule.BeginTime);
		EndDo;
	EndIf;
	
	ValueList.SortByValue(SortDirection.Asc);
	
	For Each TimeOfDay In ValueList Do
		If StartingTime <= TimeOfDay.Value Then
			Result = TimeOfDay.Value;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function EventSchedule(Schedule, BeginOfPeriod, EndOfPeriod)

	Result = Undefined;
	CurrentSessionDate = CurrentSessionDate();
	
	StartingDate = BeginOfPeriod;
	
	Calendar = GetCalendarForFuture((BegOfDay(EndOfPeriod) - BegOfDay(BeginOfPeriod)) / (60*60*24) + 1, 
		StartingDate, Schedule.BeginDate, Schedule.DaysRepeatPeriod, Schedule.WeeksPeriod);
	
	WeekDays = Schedule.WeekDays;
	If WeekDays.Count() = 0 Then
		WeekDays = New Array;
		For Day = 1 To 7 Do
			WeekDays.Add(Day);
		EndDo;
	EndIf;
	
	Months = Schedule.Months;
	If Months.Count() = 0 Then
		Months = New Array;
		For Month = 1 To 12 Do
			Months.Add(Month);
		EndDo;
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = "SELECT * INTO Calendar FROM &Calendar AS Calendar";
	Query.SetParameter("Calendar", Calendar);
	Query.Execute();
	
	Query.SetParameter("StartDate",			Schedule.BeginDate);
	Query.SetParameter("EndDate",			Schedule.EndDate);
	Query.SetParameter("WeekDays",			WeekDays);
	Query.SetParameter("Months",				Months);
	Query.SetParameter("DayInMonth",		Schedule.DayInMonth);
	Query.SetParameter("WeekDayInMonth",	Schedule.WeekDayInMonth);
	Query.SetParameter("DaysRepeatPeriod",	?(Schedule.DaysRepeatPeriod = 0,1,Schedule.DaysRepeatPeriod));
	Query.SetParameter("WeeksPeriod",		?(Schedule.WeeksPeriod = 0,1,Schedule.WeeksPeriod));
	
	Query.Text = 
	"SELECT
	|	Calendar.Date,
	|	Calendar.MonthNumber,
	|	Calendar.WeekDayNumberInMonth,
	|	Calendar.WeekDayNumberFromMonthEnd,
	|	Calendar.DayNumberInMonth,
	|	Calendar.DayNumberInMonthFromMonthEnd,
	|	Calendar.DayNumberInWeek,
	|	Calendar.DayNumberInPeriod,
	|	Calendar.WeekNumberInPeriod
	|FROM
	|	Calendar AS Calendar
	|WHERE
	|	CASE
	|			WHEN &StartDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date >= &StartDate
	|		END
	|	AND CASE
	|			WHEN &EndDate = DATETIME(1, 1, 1, 0, 0, 0)
	|				THEN TRUE
	|			ELSE Calendar.Date <= &EndDate
	|		END
	|	AND Calendar.DayNumberInWeek IN(&WeekDays)
	|	AND Calendar.MonthNumber IN(&Months)
	|	AND CASE
	|			WHEN &DayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &DayInMonth > 0
	|						THEN Calendar.DayNumberInMonth = &DayInMonth
	|					ELSE Calendar.DayNumberInMonthFromMonthEnd = -&DayInMonth
	|				END
	|		END
	|	AND CASE
	|			WHEN &WeekDayInMonth = 0
	|				THEN TRUE
	|			ELSE CASE
	|					WHEN &WeekDayInMonth > 0
	|						THEN Calendar.WeekDayNumberInMonth = &WeekDayInMonth
	|					ELSE Calendar.WeekDayNumberFromMonthEnd = -&WeekDayInMonth
	|				END
	|		END
	|	AND Calendar.DayNumberInPeriod = &DaysRepeatPeriod
	|	AND Calendar.WeekNumberInPeriod = &WeeksPeriod";
	
	Selection = Query.Execute().Select();
	
	Result = New Array;
	
	While Selection.Next() Do
		NearestDate = Selection.Date;
		StartingTime = '00010101';
		If BegOfDay(NearestDate) = BegOfDay(StartingDate) Then
			StartingTime = StartingTime + (StartingDate-BegOfDay(StartingDate));
		EndIf;
		
		DateAndTime = Undefined;
		ClosestTime = GetClosestTimeFromSchedule(Schedule, StartingTime);
		If ClosestTime <> Undefined Then
			DateAndTime = NearestDate + (ClosestTime - '00010101');
		Else
			If Selection.Next() Then
				Time = GetClosestTimeFromSchedule(Schedule);
				DateAndTime = Selection.Date + (Time - '00010101');
			EndIf;
		EndIf;
		
		If ValueIsFilled(DateAndTime) AND DateAndTime <= EndOfPeriod Then
			Result.Add(DateAndTime);
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Returns a time interval in minutes, after which it is necessary to check for current reminders again.
Function GetRemindersCheckInterval(User = Undefined)
	Interval = Common.CommonSettingsStorageLoad(
									"ReminderSettings", 
									"RemindersCheckInterval", 
									1,
									,
									GetIBUserName(User));
	Return Max(Interval, 1);
EndFunction

Function GetIBUserName(User)
	If Not ValueIsFilled(User) Then
		Return Undefined;
	EndIf;
	
	SetPrivilegedMode(True);
	
	InfobaseUser = InfoBaseUsers.FindByUUID(Common.ObjectAttributeValue(User, "IBUserID"));
	If InfobaseUser = Undefined Then
		Return Undefined;
	EndIf;
	
	Return InfobaseUser.Name;
EndFunction

// Gets an attribute value for each object of the reference type.
Function GetSubjectAttributeValue(ReferenceToSubject, AttributeName) Export
	
	Result = Undefined;
	
	Query = New Query;
	
	QueryText =
	"SELECT 
	|	Table.&Attribute AS Attribute
	|FROM
	|	&TableName AS Table
	|WHERE
	|	Table.Ref = &Ref";

	QueryText = StrReplace(QueryText, "&TableName", ReferenceToSubject.Metadata().FullName());
	QueryText = StrReplace(QueryText, "&Attribute", AttributeName);
	
	Query.Text = QueryText;
	
	Query.SetParameter("Ref", ReferenceToSubject);

	Result = Query.Execute();

	Selection = Result.Select();

	If Selection.Next() Then
		Result = Selection.Attribute;
	EndIf;

	Return Result;
	
EndFunction

// Checks for changes of subject attributes, to which there is a user subscription, and changes 
// reminder time if required.
Procedure CheckForChangesOfDatesInSubject(Subject)
	
	SetPrivilegedMode(True);
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Reminders.User,
	|	Reminders.EventTime,
	|	Reminders.Source,
	|	Reminders.ReminderTime,
	|	Reminders.Details,
	|	Reminders.ReminderTimeSettingMethod,
	|	Reminders.ReminderInterval,
	|	Reminders.SourceAttributeName,
	|	Reminders.Schedule,
	|	FALSE AS RepeatAnnually
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTimeSettingMethod = VALUE(Enum.ReminderTimeSettingMethods.RelativeToSubjectTime)
	|	AND Reminders.Source = &Source";
	
	Query.SetParameter("Source", Subject);
	
	ResultTable = Query.Execute().Unload();
	
	For Each TableRow In ResultTable Do
		SubjectDate = GetSubjectAttributeValue(TableRow.Source, TableRow.SourceAttributeName);
		If (SubjectDate - TableRow.ReminderInterval) <> TableRow.EventTime Then
			DisableReminder(TableRow, False);
			TableRow.ReminderTime = SubjectDate - TableRow.ReminderInterval;
			TableRow.EventTime = SubjectDate;
			If TableRow.Schedule.Get() <> Undefined Then
				TableRow.RepeatAnnually = True;
			EndIf;
			
			ReminderParameters = Common.ValueTableRowToStructure(TableRow);
			ReminderParameters.Schedule = TableRow.Schedule.Get();
			Reminder = CreateReminder(ReminderParameters);
			AttachReminder(Reminder);
		EndIf;
	EndDo;
EndProcedure

// Handler of subscription to event OnWrite object, for which you can create reminders.
Procedure CheckForChangesOfDatesInSubjectOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load Then
		Return;
	EndIf;
	
	If StandardSubsystemsServer.IsMetadataObjectID(Source) Then
		Return;
	EndIf;
	
	If GetFunctionalOption("UseUserReminders") Then
		CheckForChangesOfDatesInSubject(Source.Ref);
	EndIf;
	
EndProcedure

// Creates a user reminder. If an object already has a reminder, the procedure shifts reminder time forward by seconds.
Procedure AttachReminder(ReminderParameters, UpdateReminderPeriod = False) Export
	
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	RecordSet.Filter.User.Set(ReminderParameters.User);
	RecordSet.Filter.Source.Set(ReminderParameters.Source);
	
	If UpdateReminderPeriod Then
		RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
		RecordSet.Read();
		If RecordSet.Count() = 0 Then
			Return;
		EndIf;
		For Each Record In RecordSet Do
			FillPropertyValues(Record, ReminderParameters);
		EndDo;
	Else
		RecordSet.Read();
		If RecordSet.Count() > 0 Then
			BusyTime = RecordSet.Unload(,"EventTime").UnloadColumn("EventTime");
			While BusyTime.Find(ReminderParameters.EventTime) <> Undefined Do
				ReminderParameters.EventTime = ReminderParameters.EventTime + 1;
			EndDo;
		EndIf;
		NewRecord = RecordSet.Add();
		FillPropertyValues(NewRecord, ReminderParameters);
	EndIf;
	
	RecordSet.Write();
	
EndProcedure

// Disables a reminder if any. If the reminder is periodic, the procedure attaches it to the nearest date on the schedule.
Procedure DisableReminder(ReminderParameters, AttachBySchedule = True) Export
	
	// Search for an existing record.
	Query = New Query;
	
	QueryText = 
	"SELECT
	|	UserReminders.User AS User,
	|	UserReminders.EventTime AS EventTime,
	|	UserReminders.Source AS Source,
	|	UserReminders.ReminderTime AS ReminderTime,
	|	UserReminders.Details AS Details,
	|	UserReminders.ReminderTimeSettingMethod AS ReminderTimeSettingMethod,
	|	UserReminders.Schedule AS Schedule,
	|	UserReminders.ReminderInterval AS ReminderInterval,
	|	UserReminders.SourceAttributeName AS SourceAttributeName,
	|	UserReminders.ID AS ID
	|FROM
	|	InformationRegister.UserReminders AS UserReminders
	|WHERE
	|	UserReminders.User = &User
	|	AND UserReminders.EventTime = &EventTime
	|	AND UserReminders.Source = &Source";
	
	Query.SetParameter("User", ReminderParameters.User);
	Query.SetParameter("EventTime", ReminderParameters.EventTime);
	Query.SetParameter("Source", ReminderParameters.Source);
	
	Query.Text = QueryText;
	QueryResult = Query.Execute().Unload();
	Reminder = Undefined;
	If QueryResult.Count() > 0 Then
		Reminder = QueryResult[0];
	EndIf;
	
	// Delete an existing record.
	RecordSet = InformationRegisters.UserReminders.CreateRecordSet();
	RecordSet.Filter.User.Set(ReminderParameters.User);
	RecordSet.Filter.Source.Set(ReminderParameters.Source);
	RecordSet.Filter.EventTime.Set(ReminderParameters.EventTime);
	
	RecordSet.Clear();
	RecordSet.Write();
	
	NextDateOnSchedule = Undefined;
	DefinedNextDateOnSchedule = False;
	
	// Attach the next reminder on the schedule.
	If AttachBySchedule AND Reminder <> Undefined Then
		Schedule = Reminder.Schedule.Get();
		If Schedule <> Undefined Then
			If Schedule.DaysRepeatPeriod > 0 Then
				NextDateOnSchedule = GetClosestEventDateOnSchedule(Schedule, ReminderParameters.EventTime + 1);
			EndIf;
			DefinedNextDateOnSchedule = NextDateOnSchedule <> Undefined;
		EndIf;
		
		If DefinedNextDateOnSchedule Then
			Reminder.EventTime = NextDateOnSchedule;
			Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
			AttachReminder(Reminder);
		EndIf;
	EndIf;
	
EndProcedure

Function AttachArbitraryReminder(Text, EventTime, IntervalTillEvent = 0, Subject = Undefined, ID = Undefined) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Details", Text);
	If TypeOf(EventTime) = Type("JobSchedule") Then
		ReminderParameters.Insert("Schedule", EventTime);
	Else
		ReminderParameters.Insert("EventTime", EventTime);
	EndIf;
	ReminderParameters.Insert("ReminderInterval", IntervalTillEvent);
	ReminderParameters.Insert("Source", Subject);
	ReminderParameters.Insert("ID", ID);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

Function AttachReminderTillSubjectTime(Text, Interval, Subject, AttributeName, RepeatAnnually = False) Export
	ReminderParameters = New Structure;
	ReminderParameters.Insert("Details", Text);
	ReminderParameters.Insert("Source", Subject);
	ReminderParameters.Insert("SourceAttributeName", AttributeName);
	ReminderParameters.Insert("ReminderInterval", Interval);
	ReminderParameters.Insert("RepeatAnnually", RepeatAnnually);
	
	Reminder = CreateReminder(ReminderParameters);
	AttachReminder(Reminder);
	
	Return Reminder;
EndFunction

// Returns structure of a new reminder for further attachment.
Function CreateReminder(ReminderParameters)
	
	Reminder = UserRemindersClientServer.ReminderDetails(ReminderParameters, True);
	
	If Not ValueIsFilled(Reminder.User) Then
		Reminder.User = UsersClientServer.CurrentUser();
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderTimeSettingMethod) Then
		If ValueIsFilled(Reminder.Source) AND Not IsBlankString(Reminder.SourceAttributeName) Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToSubjectTime;
		ElsIf Reminder.Schedule <> Undefined Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.Periodic;
		ElsIf Not ValueIsFilled(Reminder.EventTime) Then
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToCurrentTime;
		Else
			Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime;
		EndIf;
	EndIf;
	
	If Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToSubjectTime Then
		Reminder.EventTime = Common.ObjectAttributeValue(Reminder.Source, Reminder.SourceAttributeName);
		Reminder.ReminderTime = Reminder.EventTime - ?(ValueIsFilled(Reminder.EventTime), Reminder.ReminderInterval, 0);
	ElsIf Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.RelativeToCurrentTime Then
		Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime;
		Reminder.EventTime = CurrentSessionDate() + Reminder.ReminderInterval;
	ElsIf Reminder.ReminderTimeSettingMethod = Enums.ReminderTimeSettingMethods.AtSpecifiedTime Then
		Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
	EndIf;
	
	If Not ValueIsFilled(Reminder.ReminderTime) Then
		Reminder.ReminderTime = Reminder.EventTime;
	EndIf;
	
	If Reminder.RepeatAnnually Then
		If ValueIsFilled(Reminder.EventTime) Then
			Reminder.Schedule = UserRemindersClientServer.AnnualSchedule(Reminder.EventTime);
		EndIf;
	EndIf;
	
	If Reminder.Schedule <> Undefined Then
		Reminder.EventTime = GetClosestEventDateOnSchedule(Reminder.Schedule);
		Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
	EndIf;
	
	Reminder.Schedule = New ValueStorage(Reminder.Schedule, New Deflation(9));
	
	Return Reminder;
	
EndFunction

// Stops overdue periodic reminders.
Procedure UpdateRemindersList()
	
	QueryText =
	"SELECT ALLOWED
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderTime AS ReminderTime,
	|	Reminders.Details AS Details,
	|	Reminders.ReminderTimeSettingMethod AS ReminderTimeSettingMethod,
	|	Reminders.ReminderInterval AS ReminderInterval,
	|	Reminders.SourceAttributeName AS SourceAttributeName,
	|	Reminders.Schedule AS Schedule,
	|	Reminders.SourcePresentation AS SourcePresentation,
	|	Reminders.ID AS ID
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.EventTime <= &CurrentDate
	|	AND Reminders.User = &User";
	
	Query = New Query(QueryText);
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("User", Users.CurrentUser());
	
	SetPrivilegedMode(True);
	RemindersList = Query.Execute().Unload();
	SetPrivilegedMode(False);
	
	For Each Reminder In RemindersList Do
		Schedule = Reminder.Schedule.Get();
		If Schedule = Undefined Then
			Continue;
		EndIf;
		
		EventScheduleForYear = EventSchedule(Schedule, Reminder.EventTime, AddMonth(Reminder.EventTime, 12) - 1);
		ComingEventTime = EventSchedule(Schedule, Reminder.EventTime + 1, CurrentSessionDate());
		
		// - The following event time on the schedule came.
		If ComingEventTime.Count() > 0
			// - Completion time is specified in the job schedule and it is overdue.
			Or ValueIsFilled(Schedule.CompletionTime) AND CurrentSessionDate() > (Reminder.EventTime + (Schedule.CompletionTime - Schedule.BeginTime))
			// - The reminder is annual, but one month has passed since the event.
			Or EventScheduleForYear.Count() = 1 AND CurrentSessionDate() > AddMonth(Reminder.EventTime, 1)
			// - The reminder is monthly, but one week has passed since the event.
			Or EventScheduleForYear.Count() = 12 AND CurrentSessionDate() > Reminder.EventTime + 60*60*24*7 Then
				ClosestEventTime = Undefined;
				If ComingEventTime.Count() > 0 Then
					DisableReminder(Reminder, False);
					
					ReminderParameters = Common.ValueTableRowToStructure(Reminder);
					ReminderParameters.Schedule = Reminder.Schedule.Get();
					Reminder = CreateReminder(ReminderParameters);
					Reminder.EventTime = ComingEventTime[ComingEventTime.UBound()];
					Reminder.ReminderTime = Reminder.EventTime - Reminder.ReminderInterval;
					
					AttachReminder(Reminder);
				EndIf;
				DisableReminder(Reminder, True);
		EndIf;
	EndDo;
	
EndProcedure

Function CurrentUserRemindersList() Export
	
	UpdateRemindersList();
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	Reminders.User AS User,
	|	Reminders.EventTime AS EventTime,
	|	Reminders.Source AS Source,
	|	Reminders.ReminderTime AS ReminderTime,
	|	Reminders.Details AS Details,
	|	2 AS PictureIndex
	|FROM
	|	InformationRegister.UserReminders AS Reminders
	|WHERE
	|	Reminders.ReminderTime <= &CurrentDate
	|	AND Reminders.User = &User
	|
	|ORDER BY
	|	EventTime";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate() + 30*60);// +30 minutes for cache
	Query.SetParameter("User", Users.CurrentUser());
	
	SetPrivilegedMode(True);
	Result = Common.ValueTableToArray(Query.Execute().Unload());
	
	Return Result;
	
EndFunction

#EndRegion
