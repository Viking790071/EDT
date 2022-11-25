#Region Public

// Runs a periodic check of current user reminders.
Procedure Enable() Export
	CheckCurrentReminders();
EndProcedure

// Disables periodic check of current user reminders.
Procedure Disable() Export
	DetachIdleHandler("CheckCurrentReminders");
EndProcedure

// Creates a reminder for the specified time.
//
// Parameters:
//  Text - String - a reminder text.
//  Time - Date - a notification date and time.
//  Subject - AnyRef - a reminder subject.
//
Procedure RemindInSpecifiedTime(Text, Time, Subject = Undefined) Export
	
	Reminder = UserRemindersServerCall.AttachReminder(
		Text, Time, , Subject);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Creates a reminder for time calculated relatively to time in the subject.
//
// Parameters:
//  Text - String - a reminder text.
//  Interval - Number - time in seconds, prior to which it is necessary to remind of the date in the subject attribute.
//  Subject - AnyRef - a reminder subject.
//  AttributeName - String - a name of the subject attribute, for which the reminder period is set.
Procedure RemindTillSubjectTime(Text, Interval, Subject, AttributeName) Export
	
	Reminder = UserRemindersServerCall.AttachReminderTillSubjectTime(
		Text, Interval, Subject, AttributeName, False);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Generates a reminder with arbitrary time or execution schedule.
//
// Parameters:
//  Text - String - a reminder text.
//  EventTime - Date - date and time of the event, which needs a reminder.
//               - JobSchedule - a schedule of a periodic event.
//               - String - a name of the Subject attribute that contains time of the event start.
//  IntervalTillEvent - Number - time in seconds, prior to which it is necessary to remind of the event time.
//  Subject - AnyRef - a reminder subject.
//  ID - String - clarifies the reminder subject, for example, Birthday.
//
Procedure Remind(Text, EventTime, IntervalTillEvent = 0, Subject = Undefined, ID = Undefined) Export
	
	Reminder = UserRemindersServerCall.AttachReminder(
		Text, EventTime, IntervalTillEvent, Subject, ID);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

// Creates an annual reminder on the subject date.
//
// Parameters:
//  Text - String - a reminder text.
//  Interval - Number - time in seconds, prior to which it is necessary to remind of the date in the subject attribute.
//  Subject - AnyRef - a reminder subject.
//  AttributeName - String - a name of the subject attribute, for which the reminder period is set.
//
Procedure RemindOfAnnualSubjectEvent(Text, Interval, Subject, AttributeName) Export
	
	Reminder = UserRemindersServerCall.AttachReminderTillSubjectTime(
		Text, Interval, Subject, AttributeName, True);
		
	UpdateRecordInNotificationsCache(Reminder);
	ResetCurrentNotificationsCheckTimer();
	
EndProcedure

#EndRegion

#Region Internal

////////////////////////////////////////////////////////////////////////////////
// Configuration subsystems event handlers.

// See CommonClientOverridable.AfterStart. 
Procedure AfterStart() Export
	
	ClientRunParameters = StandardSubsystemsClient.ClientParametersOnStart();
	If NOT ClientRunParameters.SeparatedDataUsageAvailable Then
		Return;
	EndIf;
	
	If ClientRunParameters.ReminderSettings.UseReminders Then
		AttachIdleHandler("CheckCurrentReminders", 60, True); // 60 seconds after starting the client.
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

// Resets the check timer of current reminders and performs the check immediately.
Procedure ResetCurrentNotificationsCheckTimer() Export
	DetachIdleHandler("CheckCurrentReminders");
	CheckCurrentReminders();
EndProcedure

// Opens the notification form
Procedure OpenNotificationForm() Export
	// Storage of the form in a variable is required to prevent duplicate forms from being opened, as 
	// well as to reduce the number of server calls.
	ParameterName = "StandardSubsystems.NotificationForm";
	If ApplicationParameters[ParameterName] = Undefined Then
		NotificationFormName = "InformationRegister.UserReminders.Form.NotificationForm";
		ApplicationParameters.Insert(ParameterName, GetForm(NotificationFormName));
	EndIf;
	NotificationForm = ApplicationParameters[ParameterName];
	NotificationForm.Open();
EndProcedure

// Returns cached notifications of the current user, except for ones that have not been started yet.
//
// Parameters:
//  TimeOfClosest - Date - this parameter returns time of the closest future reminder. If the 
//                           closest reminder is outside the cache selection, Undefined returns.
Function GetCurrentNotifications(TimeOfClosest = Undefined) Export
	
	NotificationsTable = UserRemindersClientCached.GetCurrentUserReminders();
	Result = New Array;
	
	TimeOfClosest = Undefined;
	
	For Each Notification In NotificationsTable Do
		If Notification.ReminderTime <= CommonClient.SessionDate() Then
			Result.Add(Notification);
		Else                                                           
			If TimeOfClosest = Undefined Then
				TimeOfClosest = Notification.ReminderTime;
			Else
				TimeOfClosest = Min(TimeOfClosest, Notification.ReminderTime);
			EndIf;
		EndIf;
	EndDo;		
	
	Return Result;
	
EndFunction

// Updates record of the GetCurrentUserReminders() function result in cache.
Procedure UpdateRecordInNotificationsCache(NotificationParameters) Export
	NotificationsCache = UserRemindersClientCached.GetCurrentUserReminders();
	Record = FindRecordInNotificationsCache(NotificationsCache, NotificationParameters);
	If Record <> Undefined Then
		FillPropertyValues(Record, NotificationParameters);
	Else
		NotificationsCache.Add(NotificationParameters);
	EndIf;
EndProcedure

// Deletes the record from cache of the GetCurrentUserReminders() function execution result.
Procedure DeleteRecordFromNotificationsCache(NotificationParameters) Export
	NotificationsCache = UserRemindersClientCached.GetCurrentUserReminders();
	Record = FindRecordInNotificationsCache(NotificationsCache, NotificationParameters);
	If Record <> Undefined Then
		NotificationsCache.Delete(NotificationsCache.Find(Record));
	EndIf;
EndProcedure

// Returns the record from cache of the GetCurrentUserReminders() function execution result.
Function FindRecordInNotificationsCache(NotificationsCache, NotificationParameters)
	For Each Record In NotificationsCache Do
		If Record.Source = NotificationParameters.Source
		   AND Record.EventTime = NotificationParameters.EventTime Then
			Return Record;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

#EndRegion
