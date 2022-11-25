
#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	If Parameters.BackgroundJobProperties = Undefined Then
		
		BackgroundJobProperties = ScheduledJobsInternal
			.GetBackgroundJobProperties(Parameters.ID);
		
		If BackgroundJobProperties = Undefined Then
			Raise(NStr("ru = 'Фоновое задание не найдено.'; en = 'The background job has not been found.'; pl = 'Nie znaleziono zadania w tle.';es_ES = 'Tarea de fondo no encontrada.';es_CO = 'Tarea de fondo no encontrada.';tr = 'Arka plan görevi bulunamadı.';it = 'Il task in background non è stato trovato.';de = 'Hintergrundjob wurde nicht gefunden.'"));
		EndIf;
		
		UserMessagesAndErrorDescription = ScheduledJobsInternal
			.BackgroundJobMessagesAndErrorDescriptions(Parameters.ID);
			
		If ValueIsFilled(BackgroundJobProperties.ScheduledJobID) Then
			
			ScheduledJobID
				= BackgroundJobProperties.ScheduledJobID;
			
			ScheduledJobDescription
				= ScheduledJobsInternal.ScheduledJobPresentation(
					BackgroundJobProperties.ScheduledJobID);
		Else
			ScheduledJobDescription  = ScheduledJobsInternal.TextUndefined();
			ScheduledJobID = ScheduledJobsInternal.TextUndefined();
		EndIf;
	Else
		BackgroundJobProperties = Parameters.BackgroundJobProperties;
		FillPropertyValues(
			ThisObject,
			BackgroundJobProperties,
			"UserMessagesAndErrorDescription,
			|ScheduledJobID,
			|ScheduledJobDescription");
	EndIf;
	
	FillPropertyValues(
		ThisObject,
		BackgroundJobProperties,
		"ID,
		|Key,
		|Description,
		|Begin,
		|End,
		|Location,
		|State,
		|MethodName");
		
	StandardSubsystemsServer.SetGroupTitleRepresentation(ThisObject);
	
EndProcedure

#EndRegion
