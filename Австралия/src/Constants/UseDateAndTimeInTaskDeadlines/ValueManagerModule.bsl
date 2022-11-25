///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	Usage = Constants.UseBusinessProcessesAndTasks.Get();
	
	SearchParameters = New Structure;
	SearchParameters.Insert("Metadata", Metadata.ScheduledJobs.StartDeferredProcesses);
	JobsList = ScheduledJobsServer.FindJobs(SearchParameters);
	
	If JobsList.Count() = 0 Then
		JobParameters = New Structure("Use", Usage);
		JobParameters.Insert("Metadata", Metadata.ScheduledJobs.StartDeferredProcesses);
		SetSchedule(Value, JobParameters);
		ScheduledJobsServer.AddJob(JobParameters);
		Return;
	EndIf;
	
	For Each Job In JobsList Do
		
		JobParameters = New Structure("Use", Usage);
		If Usage Then
			If Value Then
				If Job.Schedule.BeginTime = Date("00010101070000")
					OR Job.Schedule.BeginTime = Date("00010101000000") Then
					SetSchedule(Value, JobParameters);
				EndIf;
			Else
				If Job.Schedule.RepeatPeriodInDay = 900
					OR Job.Schedule.BeginTime = Date("00010101000000") Then
					SetSchedule(Value, JobParameters);
				EndIf;
			EndIf;
		EndIf;
		
		ScheduledJobsServer.ChangeJob(Job, JobParameters);
	EndDo;
	
EndProcedure


#EndRegion

#Region Private

Procedure SetSchedule(UseTimeInTaskDeadlines, JobParameters)
	
	Schedule = New JobSchedule;
	
	If UseTimeInTaskDeadlines Then
		Schedule.RepeatPeriodInDay = 900;
		Schedule.BeginTime              = Date("00000000");
		Schedule.DaysRepeatPeriod        = 1;
	Else
		Schedule.RepeatPeriodInDay = 0;
		Schedule.BeginTime              = Date("00010101070000");
		Schedule.DaysRepeatPeriod        = 1;
	EndIf;
	
	JobParameters.Insert("Schedule", Schedule);

EndProcedure

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf