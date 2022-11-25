#Region Private

// Sets the setting to backup parameters.
// 
// Parameters:
//	ItemName - String - a parameter name.
// 	ItemValue - Arbitrary type - a parameter value.
//
Procedure SetSettingValue(ItemName, ItemValue) Export
	
	IBBackupServer.SetSettingValue(ItemName, ItemValue);
	
EndProcedure

// Generates a value of the next nearest automatic backup in accordance with the schedule.
//
// Parameters:
//	InitialSetting - Boolean - an initial setting flag.
//
Function NextAutomaticCopyingDate(DeferBackup = False) Export
	
	Result = New Structure;
	BackupSettings = IBBackupServer.BackupSettings();
	
	CurrentDate = CurrentSessionDate();
	
	CopyingSchedule = BackupSettings.CopyingSchedule;
	RepeatPeriodInDay = CopyingSchedule.RepeatPeriodInDay;
	DaysRepeatPeriod = CopyingSchedule.DaysRepeatPeriod;
	
	If DeferBackup Then
		Value = CurrentDate + 60 * 15;
	ElsIf RepeatPeriodInDay <> 0 Then
		Value = CurrentDate + RepeatPeriodInDay;
	ElsIf DaysRepeatPeriod <> 0 Then
		Value = CurrentDate + DaysRepeatPeriod * 3600 * 24;
	Else
		Value = BegOfDay(EndOfDay(CurrentDate) + 1);
	EndIf;
	Result.Insert("MinDateOfNextAutomaticBackup", Value);
	
	FillPropertyValues(BackupSettings, Result);
	IBBackupServer.SetBackupParemeters(BackupSettings);
	
	Return Result;
	
EndFunction

// Sets the last user notification date.
//
// Parameters:
//	NotificationDate - Date - date and time the user was last notified of required backup.
//	                         
//
Procedure SetLastNotificationDate(NotificationDate) Export
	
	IBBackupServer.SetLastNotificationDate(NotificationDate);
	
EndProcedure

#EndRegion
