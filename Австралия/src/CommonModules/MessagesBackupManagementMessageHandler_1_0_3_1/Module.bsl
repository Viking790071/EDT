#Region Public

// Returns message interface version namespace.
//
// Returns:
//  String - a package description.
//
Function Package() Export
	
	Return "http://www.1c.ru/SaaS/ManageZonesBackup/" + Version();
	
EndFunction

// Returns message interface version supported by the handler.
//
// Returns:
//  String - a package version.
//
Function Version() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the base type for version messages.
//
// Returns:
//  XDTOObjectType - base body type for messages SaaS.
//
Function BaseType() Export
	
	Return MessagesSaaSCached.TypeBody();
	
EndFunction

// Processes incoming SaaS messages.
//
// Parameters:
//  Message - XDTODataObject - an incoming message,
//  Sender - ExchangePlanRef.MessageExchange - exchange plan node that matches the message sender.
//  MessageProcessed - Boolean - flag that shows that processing is successful. The value of this 
//    parameter must be set to True if the message was successfully read in this handler.
//
Procedure ProcessSaaSMessage(Val Message, Val Sender, MessageProcessed) Export
	
	MessageProcessed = True;
	
	Dictionary = MessagesBackupManagementInterface;
	MessageType = Message.Body.Type();
	
	If MessageType = Dictionary.MessageScheduleAreaBackup(Package()) Then
		ScheduleAreaBackup(Message, Sender);
	ElsIf MessageType = Dictionary.MessageUpdatePeriodicBackupSettings(Package()) Then
		UpdatePeriodicBackupSettings(Message, Sender);
	ElsIf MessageType = Dictionary.MessageCancelPeriodicBackup(Package()) Then
		CancelPeriodicBackup(Message, Sender);
	Else
		MessageProcessed = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Procedure ScheduleAreaBackup(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	MessagesBackupManagementImplementation.ScheduleAreaBackingUp(
		MessageBody.Zone,
		MessageBody.BackupId,
		MessageBody.Date,
		True);
	
EndProcedure

Procedure UpdatePeriodicBackupSettings(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	
	Settings = New Structure;
	Settings.Insert("CreateDaily", MessageBody.CreateDailyBackup);
	Settings.Insert("CreateMonthly", MessageBody.CreateMonthlyBackup);
	Settings.Insert("CreateAnnual", MessageBody.CreateYearlyBackup);
	Settings.Insert("WhenUsersActiveOnly", MessageBody.CreateBackupOnlyAfterUsersActivity);
	Settings.Insert("BackupsCreationIntervalStart", MessageBody.BackupCreationBeginTime);
	Settings.Insert("BackupsCreationIntervalEnd", MessageBody.BackupCreationEndTime);
	Settings.Insert("MonthlyBackupCreationDay", MessageBody.MonthlyBackupCreationDay);
	Settings.Insert("MonthOfEarlyBackup", MessageBody.YearlyBackupCreationMonth);
	Settings.Insert("YearlyBackupCreationDay", MessageBody.YearlyBackupCreationDay);
	Settings.Insert("LastDailyBackupCreationDate", MessageBody.LastDailyBackupDate);
	Settings.Insert("LastMonthlyBackupCreationDate", MessageBody.LastMonthlyBackupDate);
	Settings.Insert("LastYearlyBackupCreationDate", MessageBody.LastYearlyBackupDate);
	
	MessagesBackupManagementImplementation.UpdatePeriodicBackupSettings(
		MessageBody.Zone,
		Settings);
	
EndProcedure

Procedure CancelPeriodicBackup(Val Message, Val Sender)
	
	MessageBody = Message.Body;
	
	MessagesBackupManagementImplementation.CancelPeriodicBackup(
		MessageBody.Zone);
	
EndProcedure

#EndRegion
