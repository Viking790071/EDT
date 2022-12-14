#Region Public

// Returns the translation source version number.
// 
// Returns:
//   String - a source version.
//
Function SourceVersion() Export
	
	Return "1.0.3.1";
	
EndFunction

// Returns the translation source version namespace.
// 
// Returns:
//   String - a source version package.
//
Function SourceVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.3.1";
	
EndFunction

// Returns the translation destination version number.
// 
// Returns:
//   String - a resulting┬áversion.
//
Function ResultingVersion() Export
	
	Return "1.0.2.1";
	
EndFunction

// Returns the translation destination version namespace.
// 
// Returns:
//   String - a resulting version package.
//
Function ResultingVersionPackage() Export
	
	Return "http://www.1c.ru/SaaS/ControlZonesBackup/1.0.2.1";
	
EndFunction

// Standard translation processing execution check handler.
//
// Parameters:
//  SourceMessage - XDTODataObject - translated message,
//  StandardProcessing - Boolean - set this parameter to False within this procedure to cancel 
//    standard translation processing.
//    In that case, function is called instead of the standard translation processing.
//    MessageTranslation() of the translation handler.
//
Procedure BeforeTranslate(Val SourceMessage, StandardProcessing) Export
	
	BodyType = SourceMessage.Type();
	
	If BodyType = Interface().AreaBackupCreatedMessage(SourceVersionPackage()) Then
		StandardProcessing = False;
	ElsIf BodyType = Interface().AreaBackupErrorMessage(SourceVersionPackage()) Then
		StandardProcessing = False;
	EndIf;
	
EndProcedure

// Execution handler of any message translation. It is only called if the StandardProcessing 
//  parameter of the BeforeTranslation procedure was set to False.
//  
//
// Parameters:
//  SourceMessage - XDTODataObject - translated message.
//
// Returns:
//  XDTODataObject - result of arbitrary message translation.
//
Function MessageTranslation(Val SourceMessage) Export
	
	BodyType = SourceMessage.Type();
	
	If BodyType = Interface().AreaBackupCreatedMessage(SourceVersionPackage()) Then
		Return TranslateAreaBackupCreated(SourceMessage);
	ElsIf BodyType = Interface().AreaBackupErrorMessage(SourceVersionPackage()) Then
		Return TranslateAreaBackupError(SourceMessage);
	ElsIf BodyType = Interface().AreaBackupSkippedMessage(SourceVersionPackage()) Then
		Return TranslateAreaBackupSkipped(SourceMessage);
	EndIf;
	
EndFunction

#EndRegion

#Region Private

Function Interface()
	
	Return MessagesBackupControlInterface;
	
EndFunction

Function TranslateAreaBackupCreated(Val SourceMessage)
	
	Result = XDTOFactory.Create(
		Interface().AreaBackupCreatedMessage(ResultingVersionPackage()));
		
	Result.Zone = SourceMessage.Zone;
	Result.BackupId = SourceMessage.BackupId;
	Result.Date = SourceMessage.Date;
	Result.FileId = SourceMessage.FileId;
	
	Return Result;
	
EndFunction

Function TranslateAreaBackupError(Val SourceMessage)
	
	Result = XDTOFactory.Create(
		Interface().AreaBackupErrorMessage(ResultingVersionPackage()));
		
	Result.Zone = SourceMessage.Zone;
	Result.BackupId = SourceMessage.BackupId;
	
	Return Result;
	
EndFunction

Function TranslateAreaBackupSkipped(Val SourceMessage)
	
	Result = XDTOFactory.Create(
		Interface().AreaBackupSkippedMessage(ResultingVersionPackage()));
		
	Result.Zone = SourceMessage.Zone;
	Result.BackupId = SourceMessage.BackupId;
	
	Return Result;
	
EndFunction

#EndRegion
