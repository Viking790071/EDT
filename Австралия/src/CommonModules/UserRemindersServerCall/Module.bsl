#Region Private

// Executes a query on reminders for the current user at the time CurrentSessionDate() + 30 minutes.
// The point in time is offset from the current moment to use the module function with reusable 
// return values.
// Consider this feature upon processing the function execution result.
//
// Parameters:
//	No
//
// Returns
//  Array - a value table converted into an array of structures containing data of table rows.
Function GetCurrentUserReminders() Export
	
	Return UserRemindersInternal.CurrentUserRemindersList();
	
EndFunction

// Creates a reminder for time calculated relatively to time in the subject.
Function AttachReminderTillSubjectTime(Text, Interval, Subject, AttributeName, RepeatAnnually = False) Export
	
	Return UserRemindersInternal.AttachReminderTillSubjectTime(
		Text, Interval, Subject, AttributeName, RepeatAnnually);
	
EndFunction

Function AttachReminder(Text, EventTime, IntervalTillEvent = 0, Subject = Undefined, ID = Undefined) Export
	
	Return UserRemindersInternal.AttachArbitraryReminder(
		Text, EventTime, IntervalTillEvent, Subject, ID);
	
EndFunction

#EndRegion
