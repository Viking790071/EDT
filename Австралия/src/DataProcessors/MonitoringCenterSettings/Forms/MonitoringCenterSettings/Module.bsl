#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GetIDJobState = "";
	
	If Parameters.Property("JobID") Then
		JobID = Parameters.JobID;
		JobResultAddress = Parameters.JobResultAddress;
		If ValueIsFilled(JobID) Then
			GetIDJobState = JobCompleted(JobID);
		EndIf;
	EndIf;  	
	
	MonitoringCenterID = MonitoringCenterID();
	If Not IsBlankString(MonitoringCenterID) Then
		ID = MonitoringCenterID;
	Else
		Items.IDGroup.CurrentPage = Items.GetIDPage;
	EndIf;
	
	ParametersToGet = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending");
	MonitoringCenterParameters = MonitoringCenterInternal.GetMonitoringCenterParameters(ParametersToGet);
	SendErrorsInformation = MonitoringCenterParameters.SendDumpsFiles;
	If SendErrorsInformation = 2 Then
		Items.SendErrorsInformation.ThreeState = True;
	EndIf;
	RequestConfirmationBeforeSending = MonitoringCenterParameters.RequestConfirmationBeforeSending;
	HintContent = Items.SendErrorsInformationExtendedTooltip.Title;
	If Common.FileInfobase() Then
		Items.SendErrorsInformationExtendedTooltip.Title = StrReplace(HintContent,"%AddlInfo","");
	Else
		Items.SendErrorsInformationExtendedTooltip.Title = StrReplace(HintContent,"%AddlInfo"," " + NStr("en = 'on 1C server'; ru = 'на сервере 1С'; pl = 'na serwerze 1C';es_ES = 'en servidor 1C';es_CO = 'en servidor 1C';tr = '1C sunucusunda';it = 'sul server 1C';de = 'auf dem 1C-Server'"));
	EndIf;
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	VisibilityParameters = New Structure("Status, ResultAddress", GetIDJobState, JobResultAddress);
	If Not IsBlankString(GetIDJobState) And IsBlankString(ID) Then
		SetItemsVisibility(VisibilityParameters);
	EndIf;
EndProcedure

&AtClient
Procedure SendErrorsInformationOnChange(Item)
	Item.ThreeState = False;
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Write(Command)
	NewParameters = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending", 
										SendErrorsInformation, RequestConfirmationBeforeSending);
	SetMonitoringCenterParameters(NewParameters);
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
	NewParameters = New Structure("SendDumpsFiles, RequestConfirmationBeforeSending", 
										SendErrorsInformation, RequestConfirmationBeforeSending);
	SetMonitoringCenterParameters(NewParameters);
	Close();
EndProcedure

&AtClient
Procedure GetID(Command)
	RunResult = DiscoveryPackageSending();
	JobID = RunResult.JobID;
	JobResultAddress = RunResult.ResultAddress;
	GetIDJobState = "Running1";
	Notification = New NotifyDescription("AfterUpdateID", MonitoringCenterClient);
	IdleParameters = TimeConsumingOperationsClient.IdleParameters(ThisObject);
	IdleParameters.OutputIdleWindow = False;
	TimeConsumingOperationsClient.WaitForCompletion(RunResult, Notification, IdleParameters);
	
	VisibilityParameters = New Structure("Status, ResultAddress", GetIDJobState, JobResultAddress);
	SetItemsVisibility(VisibilityParameters);
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	If EventName = "IDUpdateMonitoringCenter" And Parameter <> Undefined Then
		SetItemsVisibility(Parameter);	
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Procedure SetMonitoringCenterParameters(NewParameters)
	MonitoringCenterInternal.SetMonitoringCenterParametersExternalCall(NewParameters);
EndProcedure

&AtServerNoContext
Function MonitoringCenterID()
	Return MonitoringCenter.InfoBaseID();
EndFunction

&AtClient
Procedure UpdateParameters()
	MonitoringCenterID = MonitoringCenterID();
	If Not IsBlankString(MonitoringCenterID) Then
		ID = MonitoringCenterID;
	EndIf;
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	ExecutionResult = "Running1";
	Try
		JobCompleted = TimeConsumingOperations.JobCompleted(JobID);
		If JobCompleted Then 
			ExecutionResult = "Done";
		Else
			ExecutionResult = "Running1";
		EndIf;
	Except
		ExecutionResult = "Error";
	EndTry;
	Return ExecutionResult;
EndFunction

&AtServerNoContext
Function DiscoveryPackageSending()
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(New UUID);
	ExecutionParameters.WaitForCompletion = 0;
	ProcedureParameters = New Structure("Iterator, TestPackageSending, GetID", 0, False, True);
	Return TimeConsumingOperations.ExecuteInBackground("MonitoringCenterInternal.SendTestPackage", ProcedureParameters, ExecutionParameters);
EndFunction

&AtClient
Procedure SetItemsVisibility(VisibilityParameters)
	ExecutionResult = GetFromTempStorage(VisibilityParameters.ResultAddress);
	If VisibilityParameters.Status = "Running1" Then
		Items.ProgressDetails.Title = NStr("ru = 'Выполняется получение идентификатора';
													|en = 'Receiving ID';pl = 'Trwa odbioru identyfikatora';es_ES = 'Recibiendo identificador';es_CO = 'Recibiendo identificador';tr = 'Kimlik alınıyor';it = 'Ricezione ID';de = 'Erhalten von ID läuft'");		
		Items.ProgressDetails.Visible = True;
		Items.Progress.Picture = PictureLib.TimeConsumingOperation16;
		Items.Progress.Visible = True;
		Items.IDGroup.Visible = False;	
	ElsIf VisibilityParameters.Status = "Done" And ExecutionResult.Successfully Then
		Items.ProgressDetails.Title = NStr("ru = 'Идентификатор успешно получен';
													|en = 'ID is received successfully';pl = 'Identyfikator został otrzymany pomyślnie';es_ES = 'Se ha recibido el identificador';es_CO = 'Se ha recibido el identificador';tr = 'Kimlik başarıyla alındı';it = 'ID ricevuta con successo';de = 'ID ist erfolgreich erhalten'");		
		Items.ProgressDetails.Visible = False;
		Items.Progress.Visible = False;
		Items.IDGroup.Visible = True;
		Items.IDGroup.CurrentPage = Items.IDPage;
		UpdateParameters();
	ElsIf VisibilityParameters.Status = "Done" And Not ExecutionResult.Successfully Or VisibilityParameters.Status = "Error" Then
		If VisibilityParameters.Status = "Error" Then
			Explanation = NStr("ru = 'Ошибка при выполнении фонового задания.';
							|en = 'Background job error.';pl = 'Błąd podczas wykonania zadania w tle.';es_ES = 'Error de tarea de fondo.';es_CO = 'Error de tarea de fondo.';tr = 'Arka plan işi hatası.';it = 'Errore processo in background.';de = 'Hintergrundarbeitsfehler.'");
		Else
			Explanation = ExecutionResult.BriefErrorDescription;
		EndIf;
		TitleTemplate1 = NStr("ru = 'Не удалось получить идентификатор. %1 Подробнее см. в журнале регистрации';
								|en = 'Cannot receive ID. %1 For more information, see the event log';pl = 'Nie można otrzymać identyfikatora. %1 Szczegóły można zobaczyć w dzienniku rejestracji';es_ES = 'No se puede recibir el identificador. %1 Para más información, consulte el registro de eventos';es_CO = 'No se puede recibir el identificador. %1 Para más información, consulte el registro de eventos';tr = 'Kimlik alınamıyor. %1 Daha fazla bilgi için olay günlüğüne bakın';it = 'Impossibile ricevere ID.%1 Per ulteriori informazioni, consultare il registro degli eventi';de = 'Fehler beim Erhalten von ID. %1 Weitere Informationen finden Sie im Ereignisprotokoll'");
		Items.ProgressDetails.Title = StringFunctionsClientServer.SubstituteParametersToString(TitleTemplate1, Explanation);		
		Items.ProgressDetails.Visible = True;
		Items.Progress.Picture = PictureLib.Warning;
		Items.Progress.Visible = True;
		Items.IDGroup.Visible = True;
		Items.IDGroup.CurrentPage = Items.GetIDPage;
	EndIf;
EndProcedure

#EndRegion
