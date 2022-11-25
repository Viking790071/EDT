///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	// Called right before writing the object to the database.
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	// Create a scheduled dummy job (to store its ID in the data).
	SetPrivilegedMode(True);
	Job = ScheduledJobs.FindByUUID(ScheduledJob);
	
	If Job = Undefined Then
		// Due to the performance of an individual scheduled job directly in the required SaaS mode field.
		// The creation of a scheduled job is carried out by a platform method and not through the program 
		// interface of the common ScheduledJobs module.
		
		Job = ScheduledJobs.CreateScheduledJob(Metadata.ScheduledJobs.ReportMailing);
		Job.UserName = ReportMailing.IBUserName(Author);
		Job.Use   = False;
		Job.Description    = JobByMailingPresentation(Description);
		Job.Write();
		
		ScheduledJob = Job.UUID;
	EndIf;

	SetPrivilegedMode(False);
	
	// Mapping of the mailing and job readiness flag to the mailing deletion mark.
	If DeletionMark AND Prepared Then
		Prepared = False;
	EndIf;
	
	// Group to personal mailing mapping.
	// User checks are in the item form.
	// These checks provide tight links.
	PersonalMailingsGroupSelected = (Parent = Catalogs.ReportMailings.PersonalMailings);
	If Personal <> PersonalMailingsGroupSelected Then
		Parent = ?(Personal, Catalogs.ReportMailings.PersonalMailings, Catalogs.ReportMailings.EmptyRef());
	EndIf;
EndProcedure

Procedure BeforeDelete(Cancel)
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	Job = ScheduledJobs.FindByUUID(ScheduledJob);
	If Job <> Undefined Then
		Job.Delete();
	EndIf;
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(Ref);
EndProcedure

Procedure OnCopy(CopiedObject)
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	ScheduledJob = Undefined;
EndProcedure

Procedure OnWrite(Cancel)
	// Called right after writing the object to the database.
	If DataExchange.Load Then
		Return;
	EndIf;
	If IsFolder Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	Job = ScheduledJobs.FindByUUID(ScheduledJob);
	If Job <> Undefined Then
		JobModified = False;
		
		EnableJob = ExecuteOnSchedule AND Prepared;
		If Job.Use <> EnableJob Then
			Job.Use = EnableJob;
			JobModified = True;
		EndIf;
		
		// Schedule is set in the item form.
		If AdditionalProperties.Property("Schedule") 
			AND TypeOf(AdditionalProperties.Schedule) = Type("JobSchedule")
			AND String(AdditionalProperties.Schedule) <> String(Job.Schedule) Then
			Job.Schedule = AdditionalProperties.Schedule;
			JobModified = True;
		EndIf;
		
		Username = ReportMailing.IBUserName(Author);
		If Job.UserName <> Username Then
			Job.UserName = Username;
			JobModified = True;
		EndIf;
		
		JobDescription = JobByMailingPresentation(Description);
		If Job.Description <> JobDescription Then
			Job.Description = JobDescription;
			JobModified = True;
		EndIf;
		
		If Job.Parameters.Count() <> 1 OR Job.Parameters[0] <> Ref Then
			JobParameters = New Array;
			JobParameters.Add(Ref);
			Job.Parameters = JobParameters;
			JobModified = True;
		EndIf;
			
		If JobModified Then
			Job.Write();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

Function JobByMailingPresentation(MailingDescription)
	Return StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Рассылка отчетов: %1'; en = 'Report bulk email: %1'; pl = 'Masowa wysyłka raportów przez e-mail: %1';es_ES = 'Informe del newsletter:%1';es_CO = 'Informe del newsletter:%1';tr = 'Rapor toplu e-postası: %1';it = 'Report email multipla: %1';de = 'Bulk-Mail-Bericht: %1'"), TrimAll(MailingDescription));
EndFunction

#EndRegion

#Else
Raise NStr("ru = 'Недопустимый вызов объекта на клиенте.'; en = 'Invalid object call on the client.'; pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf