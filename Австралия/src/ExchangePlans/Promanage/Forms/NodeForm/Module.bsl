
#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	SetPrivilegedMode(True);
	PasswordFromStorage = Common.ReadDataFromSecureStorage(Object.Ref, "Password");
	SetPrivilegedMode(False);
	Password = ?(ValueIsFilled(PasswordFromStorage), ThisObject.UUID, "");
	
	Job = CurrentObject.CurrentJob();
	
	If Not Job = Undefined Then
		JobSchedule = Job.Schedule;
	EndIf;
	
	SetTitleScheduleExchangeAtServer();
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	DataExchangeServer.NodeFormOnWriteAtServer(CurrentObject, Cancel);
	
	If CurrentObject.UseAutomaticExchange
		And (JobSchedule = Undefined
		Or (Common.DataSeparationEnabled()
		And Not JobSchedule.RepeatPeriodInDay > 0)) Then
		
		CurrentObject.UseAutomaticExchange = False;
	EndIf;
	
	SetPrivilegedMode(True);
	
	CurrentObject.EnableDisableScheduledJob(JobSchedule);
	
	SetPrivilegedMode(False);
	
	If PasswordIsChanged Then
		SetPrivilegedMode(True);
		Common.WriteDataToSecureStorage(CurrentObject.Ref, Password);
		SetPrivilegedMode(False);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure PasswordOnChange(Item)
	
	PasswordIsChanged = True;
	Modified = True;
	
EndProcedure

&AtClient
Procedure UseAutomaticExchangeOnChange(Item)
	Items.SetExchangeSchedule.Enabled = Object.UseAutomaticExchange;
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RunSync(Command)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Data exchange with ProManage started on %1.'; ru = 'Обмен данными с ProManage начался %1.';pl = 'Wymiana danych z ProManage została rozpoczęta %1.';es_ES = 'Intercambio de datos con ProManage comenzado el %1.';es_CO = 'Intercambio de datos con ProManage comenzado el %1.';tr = 'ProManage ile veri değişimi başlangıcı: %1.';it = 'Lo scambio dati con ProManage è iniziato a %1.';de = 'Datenaustausch mit ProManage begann am: %1.'"),
		Format(CommonClient.SessionDate(), "DLF=DT"));
			
	Explanation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'by exchange node ""%1""...'; ru = 'по узлу обмена ""%1""...';pl = 'według węzła wymiany ""%1""...';es_ES = 'por el nodo de intercambio ""%1""...';es_CO = 'por el nodo de intercambio ""%1""...';tr = '""%1"" değişim düğümü ile...';it = 'per nodo di scambio ""%1""...';de = 'durch Exchange-Knoten ""%1""...'"),
		Object.Ref);
	
	Status(MessageText,	, Explanation);
			
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	
	Result = ExchangeCompletedServer(Object.Ref, ParametersStructure);
	
	NotifyChanged(Type("DocumentRef.ManufacturingOperation"));
		
	If Not Result.JobCompleted Then
		
		JobID = Result.JobID;
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		IdleHandlerParameters.IntervalIncreaseCoefficient = 1.2;
		AttachIdleHandler("Attachable_CheckJobCompletion", 1, True);
		
	Else
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Object.Ref);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with ProManage is completed.'; ru = 'Обмен данными с ProManage завершен.';pl = 'Wymiana danych z ProManage została zakończona.';es_ES = 'Se ha finalizado el intercambio de datos con ProManage.';es_CO = 'Se ha finalizado el intercambio de datos con ProManage.';tr = 'ProManage ile veri değişimi tamamlandı.';it = 'Scambio dati con ProManage completato.';de = 'Datenaustausch mit ProManage ist abgeschlossen.'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithProManageCompleted");
		
	EndIf;

EndProcedure

&AtClient
Procedure SetExchangeSchedule(Command)
	
	ExecuteExchangeScheduleSetup();
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ExchangeCompletedServer(ExchangeNode, Parameters)

	If ExchangeNode.DeletionMark
		Or ExchangeNode = ExchangePlans.ProManage.ThisNode() Then
		Return True;
	EndIf;
	
	Parameters.Insert("ExchangeNode", ExchangeNode);
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	JobDescription = NStr("en = 'Sync with ProManage'; ru = 'Синхронизация с ProManage';pl = 'Synchronizuj z ProManage';es_ES = 'Sincronización con ProManage';es_CO = 'Sincronización con ProManage';tr = 'ProManage ile senkronizasyon';it = 'Sincronizzazione con ProManage';de = 'Synchronisieren mit ProManage'");
	
	Result = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		"ExchangeWithProManage.ExecuteExchange",
		Parameters,
		JobDescription);
	
	Return Result;
	
EndFunction

&AtClient
Procedure Attachable_CheckJobCompletion()
	
	If JobCompleted(JobID) Then 
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Object.Ref);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with ProManage is completed.'; ru = 'Обмен данными с ProManage завершен.';pl = 'Wymiana danych z ProManage została zakończona.';es_ES = 'Se ha finalizado el intercambio de datos con ProManage.';es_CO = 'Se ha finalizado el intercambio de datos con ProManage.';tr = 'ProManage ile veri değişimi tamamlandı.';it = 'Scambio dati con ProManage completato.';de = 'Datenaustausch mit ProManage ist abgeschlossen.'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithProManageCompleted");
		
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobCompletion", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServerNoContext 
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure ExecuteExchangeScheduleSetup()

	If JobSchedule = Undefined Then
		JobSchedule = New JobSchedule;
	EndIf;
	
	NotifyDescription = New NotifyDescription("ChangeExchangeSchedule", ThisObject);
	
	Dialog = New ScheduledJobDialog(JobSchedule);
	Dialog.Show(NotifyDescription);

EndProcedure

&AtClient
Procedure ChangeExchangeSchedule(Result, Parameters) Export

	If TypeOf(Result) = Type("JobSchedule") Then
		
		JobSchedule = Result;
		SetTitleScheduleExchange();
		Modified = True;
		
	EndIf;

EndProcedure

&AtClient
Procedure SetTitleScheduleExchange() 

	ClientParameters = StandardSubsystemsClientCached.ClientParametersOnStart();
	If Not ClientParameters.DataSeparationEnabled Then
		
		If JobSchedule = Undefined Then
			TitleText = NStr("en = 'Set exchange schedule'; ru = 'Установить расписание обмена';pl = 'Ustaw harmonogram wymiany';es_ES = 'Establecer horario de intercambio';es_CO = 'Establecer horario de intercambio';tr = 'Değişim programını ayarla';it = 'Impostare grafico di scambio';de = 'Zeitplan für den Austausch festlegen'");
		Else
			TitleText = JobSchedule;
		EndIf;
		
		Items.SetExchangeSchedule.Title = TitleText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
			If PeriodValue = 0 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
				
			ElsIf PeriodValue <= 300 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 5 minutes'; ru = 'Каждые 5 минут';pl = 'Co 5 minut';es_ES = 'Cada 5 minutos';es_CO = 'Cada 5 minutos';tr = '5 dakikada bir';it = 'Ogni 5 minuti';de = 'Alle 5 Minuten'");
				
			ElsIf PeriodValue <= 900 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 15 minutes'; ru = 'Каждые 15 минут';pl = 'Co 15 minut';es_ES = 'Cada 15 minutos';es_CO = 'Cada 15 minutos';tr = '15 dakikada bir';it = 'Ogni 15 minuti';de = 'Alle 15 Minuten'");
				
			ElsIf PeriodValue <= 1800 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
				
			ElsIf PeriodValue <= 3600 Then
				
				ProManageExchangeInterval = NStr("en = 'Once an hour'; ru = 'Раз в час';pl = 'Raz na godzinę';es_ES = 'Una vez cada hora';es_CO = 'Una vez cada hora';tr = 'Saatte bir';it = 'Una volta all''ora';de = 'Jede Stunde'");
				
			ElsIf PeriodValue <= 10800 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 3 hours'; ru = 'Каждые 3 часа';pl = 'Co 3 godziny';es_ES = 'Cada 3 horas';es_CO = 'Cada 3 horas';tr = '3 saatte bir';it = 'Ogni 3 ore';de = 'Alle 3 Stunden'");
				
			ElsIf PeriodValue <= 21600 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 6 hours'; ru = 'Каждые 6 часов';pl = 'Co 6 godzin';es_ES = 'Cada 6 horas';es_CO = 'Cada 6 horas';tr = '6 saatte bir';it = 'Ogni 6 ore';de = 'Alle 6 Stunden'");
				
			ElsIf PeriodValue <= 43200 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 12 hours'; ru = 'Каждые 12 часов';pl = 'Co 12 godzin';es_ES = 'Cada 12 horas';es_CO = 'Cada 12 horas';tr = '12 saatte bir';it = 'Ogni 12 ore';de = 'Alle 12 Stunden'");
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

&AtServer
Procedure SetTitleScheduleExchangeAtServer() 

	If Not Common.DataSeparationEnabled() Then
		
		If JobSchedule = Undefined Then
			TitleText = NStr("en = 'Set exchange schedule'; ru = 'Установить расписание обмена';pl = 'Ustaw harmonogram wymiany';es_ES = 'Establecer horario de intercambio';es_CO = 'Establecer horario de intercambio';tr = 'Değişim programını ayarla';it = 'Impostare grafico di scambio';de = 'Zeitplan für den Austausch festlegen'");
		Else
			TitleText = JobSchedule;
		EndIf;
		
		Items.SetExchangeSchedule.Title = TitleText;
		
	Else
		
		If JobSchedule = Undefined Then
			
			ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
			
		Else
			
			PeriodValue = JobSchedule.RepeatPeriodInDay;
			If PeriodValue = 0 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
				
			ElsIf PeriodValue <= 300 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 5 minutes'; ru = 'Каждые 5 минут';pl = 'Co 5 minut';es_ES = 'Cada 5 minutos';es_CO = 'Cada 5 minutos';tr = '5 dakikada bir';it = 'Ogni 5 minuti';de = 'Alle 5 Minuten'");
				
			ElsIf PeriodValue <= 900 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 15 minutes'; ru = 'Каждые 15 минут';pl = 'Co 15 minut';es_ES = 'Cada 15 minutos';es_CO = 'Cada 15 minutos';tr = '15 dakikada bir';it = 'Ogni 15 minuti';de = 'Alle 15 Minuten'");
				
			ElsIf PeriodValue <= 1800 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 30 minutes'; ru = 'Каждые 30 минут';pl = 'Co 30 minut';es_ES = 'Cada 30 minutos';es_CO = 'Cada 30 minutos';tr = '30 dakikada bir';it = 'Ogni 30 minuti';de = 'Alle 30 Minuten'");
				
			ElsIf PeriodValue <= 3600 Then
				
				ProManageExchangeInterval = NStr("en = 'Once an hour'; ru = 'Раз в час';pl = 'Raz na godzinę';es_ES = 'Una vez cada hora';es_CO = 'Una vez cada hora';tr = 'Saatte bir';it = 'Una volta all''ora';de = 'Jede Stunde'");
				
			ElsIf PeriodValue <= 10800 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 3 hours'; ru = 'Каждые 3 часа';pl = 'Co 3 godziny';es_ES = 'Cada 3 horas';es_CO = 'Cada 3 horas';tr = '3 saatte bir';it = 'Ogni 3 ore';de = 'Alle 3 Stunden'");
				
			ElsIf PeriodValue <= 21600 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 6 hours'; ru = 'Каждые 6 часов';pl = 'Co 6 godzin';es_ES = 'Cada 6 horas';es_CO = 'Cada 6 horas';tr = '6 saatte bir';it = 'Ogni 6 ore';de = 'Alle 6 Stunden'");
				
			ElsIf PeriodValue <= 43200 Then
				
				ProManageExchangeInterval = NStr("en = 'Every 12 hours'; ru = 'Каждые 12 часов';pl = 'Co 12 godzin';es_ES = 'Cada 12 horas';es_CO = 'Cada 12 horas';tr = '12 saatte bir';it = 'Ogni 12 ore';de = 'Alle 12 Stunden'");
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndProcedure

#EndRegion

