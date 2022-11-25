
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure EnableDisableScheduledJob(JobSchedule) Export
	
	
	Job = CurrentJob();
	If UseAutomaticExchange Then
		
		JobParameters = JobProperties(JobSchedule);
		
		If Job = Undefined Then
			
			JobParameters.Insert("Metadata", Metadata.ScheduledJobs.ExchangeWithProManage);
			JobParameters.Insert("Key", String(New UUID));
			JobParameters.Insert("Use", True);
			
			JobID = NewJob(JobParameters);
			ScheduledJobID = JobID;
		Else
			SetJobParameters(Job, JobParameters);
		EndIf;
		
	Else
		
		If Job <> Undefined Then
			DeleteJob(Job);
		EndIf;
		ScheduledJobID = Undefined;
		
	EndIf;

EndProcedure

Function CurrentJob() Export
	
	Filter = New Structure;
	
	If Common.DataSeparationEnabled() Then
		Filter.Insert("Key", ScheduledJobID);
	Иначе
		If ValueIsFilled(ScheduledJobID) Then
			Filter.Insert("ID", New UUID(ScheduledJobID));
		EndIf;
		Filter.Insert("Description", ScheduledJobDescription());
		
	EndIf;

	Filter.Insert("Metadata", Metadata.ScheduledJobs.ExchangeWithProManage);
	
	Found = ScheduledJobsServer.FindJobs(Filter);
	Job = ?(Found.Count() = 0, Undefined, Found[0]);
	
	Return Job;
	
EndFunction

Function JobProperties(JobSchedule = Undefined) Export
	
	Parameters = New Array;
	Parameters.Add(Code);
	
	JobParameters = New Structure;
	If Not JobSchedule = Undefined Then
		JobParameters.Insert("Schedule", JobSchedule);
	EndIf;
	JobParameters.Insert("Parameters", Parameters);
	JobParameters.Insert("MethodName", Metadata.ScheduledJobs.ExchangeWithProManage.MethodName);
	JobParameters.Insert("Description", ScheduledJobDescription());

	Return JobParameters;
	
EndFunction

#EndRegion
	
#Region EventHandlers

Procedure BeforeWrite(Cancel)
		
	If IsBlankString(Code) Then
		SetNewCode();
	EndIf;
	
EndProcedure

Procedure BeforeDelete(Cancel)
	
	// There is no DataExchange.Import property value verification as the code below implements the 
	// logic, which must be executed, including when this property is set to True (on the side of the 
	// code that attempts to record to this exchange plan).
	
	// The exchange plan uses a safe storage, that is why the correspondent record must be deleted from 
	// the storage when deleting an exchange node (according to basic functionality subsystem 
	// documentation).
	
	SetPrivilegedMode(True);
	Common.DeleteDataFromSecureStorage(Ref);
	SetPrivilegedMode(False);
	
EndProcedure

#EndRegion

#Region Private

Function ScheduledJobDescription()
	
	Name = NStr("en = 'Data exchange with ProManage: %1.'; ru = 'Обмен данными с ProManage: %1.';pl = 'Wymiana danych z ProManage: %1.';es_ES = 'Intercambio de datos con ProManage: %1.';es_CO = 'Intercambio de datos con ProManage: %1.';tr = 'ProManage ile veri değişimi: %1.';it = 'Scambio dati con ProManage: %1.';de = 'Datenaustausch mit ProManage: %1.'");
	JobName = StringFunctionsClientServer.SubstituteParametersToString(Name, Code);
	
	Return JobName;
	
EndFunction

Procedure DeleteJob(Job)
	
	ScheduledJobsServer.DeleteJob(Job);
	
EndProcedure

Function NewJob(JobParameters)
	
	ScheduledJob = ScheduledJobsServer.AddJob(JobParameters);
	
	If TypeOf(ScheduledJob) = Type("ValueTableRow") Then
		ID = ScheduledJob.Key;
	Else
		ID = String(ScheduledJob.UUID);
	EndIf;
	
	Return ID;
	
EndFunction

Procedure SetJobParameters(Job, JobProperties)
	
	If Job = Undefined Then
		Return;
	EndIf;
	
	ScheduledJobsServer.ChangeJob(Job, JobProperties);
	SetPrivilegedMode(True);
	
EndProcedure

#EndRegion

#Else
Raise NStr("en = 'Invalid object call on the client.'; ru = 'Недопустимый вызов объекта на клиенте.';pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");
#EndIf