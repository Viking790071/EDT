#Region Private

// Checks for active infobase connections.
//
// Returns:
//  Boolean       - True if there are connections.
//                 False if there are no connections.
Function HasActiveConnections(MessagesForEventLog = Undefined) Export
	
	VerifyAccessRights("Administration", Metadata);
	
	// Writing accumulated events to the event log.
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	Return IBConnections.InfobaseSessionCount(False, False) > 1;
EndFunction

Procedure WriteUpdateStatus(UpdateAdministratorName, UpdateScheduled, UpdateComplete,
	UpdateResult, ScriptFileName = "", MessagesForEventLog = Undefined) Export
	
	VerifyAccessRights("Administration", Metadata);
	
	ScriptDirectory = "";
	
	If Not IsBlankString(ScriptFileName) Then 
		ScriptDirectory = Left(ScriptFileName, StrLen(ScriptFileName) - 10);
	EndIf;
	
	ConfigurationUpdate.WriteUpdateStatus(
		UpdateAdministratorName,
		UpdateScheduled,
		UpdateComplete,
		UpdateResult,
		ScriptDirectory,
		MessagesForEventLog);
	
EndProcedure

Function TemplatesTexts(InteractiveMode, MessagesForEventLog, ExecuteDeferredHandlers, IsDeferredUpdate) Export
	
	VerifyAccessRights("Administration", Metadata);
	
	TemplatesTexts = New Structure;
	TemplatesTexts.Insert("AdditionalConfigurationUpdateFile");
	TemplatesTexts.Insert(?(InteractiveMode, "ConfigurationUpdateSplash", "NonInteractiveConfigurationUpdate"));
	
	If IsDeferredUpdate Then
		TemplatesTexts.Insert("TaskSchedulerTaskCreationScript");
	EndIf;
	
	TemplatesTexts.Insert("PatchesDeletionScript");
	
	For Each TemplateProperties In TemplatesTexts Do
		TemplatesTexts[TemplateProperties.Key] = DataProcessors.InstallUpdates.GetTemplate(TemplateProperties.Key).GetText();
	EndDo;
	
	// Configuration update file: main.js.
	ScriptTemplate = DataProcessors.InstallUpdates.GetTemplate("TemplateOfConfigurationUpdateFile");
	
	ParametersArea = ScriptTemplate.GetArea("ParametersArea");
	ParametersArea.DeleteLine(1);
	ParametersArea.DeleteLine(ParametersArea.LineCount());
	TemplatesTexts.Insert("ParametersArea", ParametersArea.GetText());
	
	ConfigurationUpdateArea = ScriptTemplate.GetArea("ConfigurationUpdateArea");
	ConfigurationUpdateArea.DeleteLine(1);
	ConfigurationUpdateArea.DeleteLine(ConfigurationUpdateArea.LineCount());
	TemplatesTexts.Insert("ConfigurationUpdateFileTemplate", ConfigurationUpdateArea.GetText());
	
	// Writing accumulated events to the event log.
	EventLogOperations.WriteEventsToEventLog(MessagesForEventLog);
	ExecuteDeferredHandlers = ConfigurationUpdate.ExecuteDeferredHandlers();
	
	Return TemplatesTexts;
	
EndFunction

Procedure SaveConfigurationUpdateSettings(Settings) Export
	VerifyAccessRights("Administration", Metadata);
	ConfigurationUpdate.SaveConfigurationUpdateSettings(Settings);
EndProcedure

#EndRegion
