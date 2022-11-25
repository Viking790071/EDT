#Region Private

// Opens the form of current user reminders.
//
Procedure CheckCurrentReminders() Export

	ClientRunParameters = StandardSubsystemsClient.ClientRunParameters();
	
	If Not ClientRunParameters.SeparatedDataUsageAvailable Then
		Return;
	EndIf;
	
	RemindersCheckInterval = ClientRunParameters.ReminderSettings.RemindersCheckInterval;
	
	// Open the form of current notifications.
	TimeOfClosest = Undefined;
	NextCheckInterval = RemindersCheckInterval * 60;
	
	If UserRemindersClient.GetCurrentNotifications(TimeOfClosest).Count() > 0 Then
		UserRemindersClient.OpenNotificationForm();
	ElsIf ValueIsFilled(TimeOfClosest) Then
		NextCheckInterval = Max(Min(TimeOfClosest - CommonClient.SessionDate(), NextCheckInterval), 1);
	EndIf;
	
	AttachIdleHandler("CheckCurrentReminders", NextCheckInterval, True);
	
EndProcedure

#EndRegion
