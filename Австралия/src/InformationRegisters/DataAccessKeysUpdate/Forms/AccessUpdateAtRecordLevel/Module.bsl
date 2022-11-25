#Region Variables

&AtClient
Var ResultAddress, StoredDataAddress, ProgressUpdateJobID, ScheduledJobCompletionErrorText;

#EndRegion


#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	URL = "e1cib/app/InformationRegister.DataAccessKeysUpdate.Form.AccessUpdateAtRecordLevel";
	
	ProgressUpdatePeriod = 3;
	ProgressAutoUpdate = Not Parameters.DisableProgressAutoupdate;
	SortFields.Add("List", "Asc");
	
	If Not AccessManagement.LimitAccessAtRecordLevel() Then
		Items.WarningRestrictionDisabledGroup.Visible = True;
	EndIf;
	
	If Not AccessManagementInternal.LimitAccessAtRecordLevelUniversally(True) Then
		Items.WarningUniversalRestrictionDisabledGroup.Visible = True;
		Items.StartScheduledJobNow.Enabled = False;
		Items.EnableScheduledJob.Enabled = False;
	EndIf;
	
	If Parameters.ShowProgressBySeparateLists Then
		Items.BriefDetailed.Show();
	EndIf;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	OnReopen();
	
EndProcedure

&AtClient
Procedure OnReopen()
	
	UpdateAccessUpdateJobState();
	UpdateAccessUpdateJobStateInThreeSeconds();
	
	StartProgressUpdate(True);
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	If ValueIsFilled(ProgressUpdateJobID) Then
		CancelProgressUpdateAtServer(ProgressUpdateJobID);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Write_UpdateDataAccessKeys"
	 Or EventName = "Write_UpdateUserAccessKeys" Then
		
		StartProgressUpdate(True);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure CalculateByDataCountOnChange(Item)
	
	IsRepeatedProgressUpdate = False;
	StartProgressUpdate(True);
	
EndProcedure

&AtClient
Procedure ProgressAutoupdateOnChange(Item)
	
	StartProgressUpdate();
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure StartScheduledJobNow(Command)
	
	AccessUpdateJobState = Undefined;
	
	WarningText = StartScheduledJobNowAtServer(AccessUpdateJobState);
	
	If ValueIsFilled(WarningText) Then
		ShowMessageBox(, WarningText);
		Return;
	EndIf;
	
	UpdateAccessUpdateJobState(AccessUpdateJobState);
	
EndProcedure

&AtClient
Procedure EnableScheduledJob(Command)
	
	EnableScheduledJobAtServer();
	Items.ScheduledJobDisabled.Visible = False;
	
	StartProgressUpdate(True);
	
EndProcedure

&AtClient
Procedure CancelAndDisableAccessUpdate(Command)
	
	CancelAndDisableAccessUpdateAtServer();
	
	StartProgressUpdate(True);
	
EndProcedure

&AtClient
Procedure UpdateProgress(Command)
	
	StartProgressUpdate(True);
	
EndProcedure

&AtClient
Procedure CancelProgressUpdate(Command)
	
	If ValueIsFilled(ProgressUpdateJobID) Then
		CancelProgressUpdateAtServer(ProgressUpdateJobID);
		If ProgressAutoUpdate Then
			ProgressAutoUpdate = False;
			Note = NStr("ru = 'Автообновление прогресса отключено'; en = 'Progress autoupdate disabled'; pl = 'Automatyczna aktualizacja postępu wyłączona';es_ES = 'Autoactualización del progreso desactivada';es_CO = 'Autoactualización del progreso desactivada';tr = 'Otomatik ilerleme güncellemesi devre dışı bırakıldı';it = 'Aggiornamento automatico del progresso è disattivato';de = 'Automatische Aktualisierung des Fortschritts deaktiviert'");
		Else
			Note = "";
		EndIf;
		ShowUserNotification(NStr("ru = 'Обновление прогресса отменено'; en = 'Progress update canceled'; pl = 'Aktualizacja postępu anulowana';es_ES = 'Actualización de progreso cancelada';es_CO = 'Actualización de progreso cancelada';tr = 'İlerlemenin güncellenmesi iptal edildi';it = 'Aggiornamento automatico del progresso è annullato';de = 'Aktualisierung des Fortschritts abgebrochen'"),,
			Note);
	EndIf;
	
	Items.ProgressUpdate.CurrentPage = Items.UpdateCompleted;
	Items.CancelProgressUpdate.Enabled = False;
	
EndProcedure

&AtClient
Procedure ShowScheduledJobCompletionErrorText(Command)
	
	ShowMessageBox(, ScheduledJobCompletionErrorText);
	
EndProcedure

&AtClient
Procedure ManualControl(Command)
	
	OpenForm("InformationRegister.DataAccessKeysUpdate.Form.AccessUpdateManualControl");
	
EndProcedure

&AtClient
Procedure SortListAsc(Command)
	
	SortList();
	
EndProcedure

&AtClient
Procedure SortListDesc(Command)
	
	SortList(True);
	
EndProcedure

&AtClient
Procedure ShowProcessedLists(Command)
	
	Items.FormShowProcessedLists.Check =
		Not Items.FormShowProcessedLists.Check;
	
	StartProgressUpdate(True);
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure UpdateAccessUpdateJobStateInThreeSeconds()
	
	DetachIdleHandler("UpdateAccessUpdateJobStateIdleHandler");
	AttachIdleHandler("UpdateAccessUpdateJobStateIdleHandler", 3);
	
EndProcedure

&AtClient
Procedure UpdateAccessUpdateJobStateIdleHandler()
	
	UpdateAccessUpdateJobState();
	
EndProcedure

&AtClient
Procedure UpdateAccessUpdateJobState(State = Undefined)
	
	If State = Undefined Then
		State = AccessUpdateJobState();
	EndIf;
	
	If Not ValueIsFilled(State.ScheduledJobLastCompletion) Then
		Items.ScheduledJobLastCompletion.Format =
			StringFunctionsClientServer.SubstituteParametersToString("DLF=DT; DE='%1'",
				?(State.ScheduledJobRunning,
					NStr("ru = 'Не завершалось'; en = 'Have not been completed'; pl = 'Nie było ukończone';es_ES = 'No terminaba';es_CO = 'No terminaba';tr = 'Tamamlanmadı';it = 'Non è stato completato';de = 'Nicht abgeschlossen'"), NStr("ru = 'Не запускалось'; en = 'Have not been started'; pl = 'Nie było uruchamiane';es_ES = 'No se lanzaba';es_CO = 'No se lanzaba';tr = 'Başlatılmadı';it = 'Non è stato avviato';de = 'Nicht gestartet'")));
	EndIf;
	
	JobExecutionCompleted = ValueIsFilled(ScheduledJobLastCompletion)
		AND ValueIsFilled(State.ScheduledJobLastCompletion)
		AND ScheduledJobLastCompletion <> State.ScheduledJobLastCompletion;
	
	ScheduledJobLastCompletion      = State.ScheduledJobLastCompletion;
	ScheduledJobLastCompletionTime = State.ScheduledJobLastCompletion;
	LastCompletionDuration         = State.LastCompletionDuration;
	ScheduledJobCompletionErrorText    = State.ScheduledJobCompletionErrorText;
	
	Items.ScheduledJobLastCompletion.Visible      = Not State.LastCompletionToday;
	Items.ScheduledJobLastCompletionTime.Visible =    State.LastCompletionToday;
	
	Items.ScheduledJobCompletedWithError.Visible =
		ValueIsFilled(ScheduledJobCompletionErrorText);
	
	Items.ScheduledJobRunning.Visible   =    State.ScheduledJobRunning;
	Items.ScheduledJobNotRunning.Visible = Not State.ScheduledJobRunning;
	
	Items.PictureScheduledJobInProgress.Visible       =    State.BackgroundJobRunning;
	Items.PictureScheduledJobReadyToRun.Visible = Not State.BackgroundJobRunning;
	
	If Not State.ScheduledJobRunning Then
		Items.ScheduledJob1ExecutionTime.Title = "";
		Items.ScheduledJob2ExecutionTime.Title = "";
		If JobExecutionCompleted AND Not ProgressAutoUpdate Then
			StartProgressUpdate(True);
		EndIf;
		Return;
	EndIf;
	
	TitleText = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Выполняется %1'; en = 'In progress %1'; pl = 'W trakcie wykonywania %1';es_ES = 'Se está ejecutando %1';es_CO = 'Se está ejecutando %1';tr = 'Yürütülüyor %1';it = 'In lavorazione %1';de = 'Ausgeführt %1'"),
		ExecutionTimeAsString(State.RunningInSeconds));
	
	Items.ScheduledJob1ExecutionTime.Title = TitleText;
	Items.ScheduledJob2ExecutionTime.Title = TitleText;
	
	FirstJobVisibility = Items.ScheduledJob1ExecutionTime.Visible;
	FirstJobVisibility = Not FirstJobVisibility;
	
	Items.ScheduledJob1ExecutionTime.Visible =    FirstJobVisibility;
	Items.ScheduledJob2ExecutionTime.Visible = Not FirstJobVisibility;
	
EndProcedure

&AtClientAtServerNoContext
Function ExecutionTimeAsString(TimeInSeconds)
	
	MinutesTotal = Int(TimeInSeconds / 60);
	Seconds = TimeInSeconds - MinutesTotal * 60;
	HoursTotal = Int(MinutesTotal / 60);
	Minutes = MinutesTotal - HoursTotal * 60;
	
	If HoursTotal > 0 Then
		Template = NStr("ru = '%3 ч %2 мин %1 сек'; en = '%3 h %2 min %1 sec'; pl = '%3 g %2 min %1 sek';es_ES = '%3 h %2 min %1 seg';es_CO = '%3 h %2 min %1 seg';tr = '%3 %2 dak %1 san';it = '%3 h %2 min %1 sec';de = '%3 h %2 min %1 s'");
		
	ElsIf Minutes > 0 Then
		Template = NStr("ru = '%2 мин %1 сек'; en = '%2 min %1 sec'; pl = '%2 min %1 sek';es_ES = '%2 min %1 seg';es_CO = '%2 min %1 seg';tr = '%2 dak %1 san';it = '%2 min %1 sec';de = '%2 min %1 s'");
	Else
		Template = NStr("ru = '%1 сек'; en = '%1 sec'; pl = '%1 sek.';es_ES = '%1 segundo';es_CO = '%1 segundo';tr = 'saniye%1';it = '%1 sec';de = '%1 s'");
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(Template,
		Format(Seconds, "NZ=0; NG="), Format(Minutes, "NZ=0; NG="), Format(HoursTotal, "NG="));
	
EndFunction

&AtServerNoContext
Function AccessUpdateJobState()
	
	LastAccessUpdate = AccessManagementInternal.LastAccessUpdate();
	CurrentDateAtServer = AccessManagementInternal.CurrentDateAtServer();
	
	State = New Structure;
	
	State.Insert("ScheduledJobLastCompletion",
		LastAccessUpdate.EndDateAtServer);
	
	State.Insert("LastCompletionDuration",
		ExecutionTimeAsString(LastAccessUpdate.LastRunSeconds));
	
	State.Insert("LastCompletionToday",
		IsCurrentDate(CurrentDateAtServer, State.ScheduledJobLastCompletion));
	
	State.Insert("ScheduledJobCompletionErrorText",
		LastAccessUpdate.CompletionErrorText);
	
	State.Insert("RunningInSeconds", 0);
	
	Performer = AccessManagementInternal.AccessUpdateAssignee(LastAccessUpdate);
	
	If Performer = Undefined Then
		State.Insert("ScheduledJobRunning", False);
		State.Insert("BackgroundJobRunning", False);
		
	ElsIf TypeOf(Performer) = Type("BackgroundJob")
	        AND Performer.UUID <> LastAccessUpdate.BackgroundJobID Then
		
		State.Insert("ScheduledJobRunning", True);
		WaitsForSecondsExecution = CurrentDateAtServer - Performer.Begin;
		WaitsForSecondsExecution =  ?(WaitsForSecondsExecution < 0, 0, WaitsForSecondsExecution);
		State.Insert("BackgroundJobRunning", WaitsForSecondsExecution < 2);
	Else
		State.Insert("ScheduledJobRunning", True);
		State.Insert("BackgroundJobRunning", True);
		RunningInSeconds = CurrentDateAtServer - LastAccessUpdate.RunDateAtServer;
		State.Insert("RunningInSeconds", ?(RunningInSeconds < 0, 0, RunningInSeconds));
	EndIf;
	
	Return State;
	
EndFunction

&AtServerNoContext
Function IsCurrentDate(CurrentDate, Date)
	
	Return CurrentDate < Date + 12 * 60 * 6;
	
EndFunction

&AtServerNoContext
Function StartScheduledJobNowAtServer(AccessUpdateJobState)
	
	Result = AccessManagementInternal.StartAccessUpdateAtRecordLevel(True);
	
	If Result.AlreadyRunning Then
		WarningText = Result.WarningText;
	Else
		WarningText = "";
	EndIf;
	
	AccessUpdateJobState = AccessUpdateJobState();
	
	Return WarningText;
	
EndFunction

&AtClient
Procedure StartProgressUpdate(RunManually = False)
	
	If RunManually AND ValueIsFilled(ProgressUpdateJobID) Then
		CancelProgressUpdateAtServer(ProgressUpdateJobID);
		
	ElsIf Not ProgressAutoUpdate AND Not RunManually
	 Or Items.ProgressUpdate.CurrentPage = Items.UpdateInProgress Then
		
		Return;
	EndIf;
	
	AttachIdleHandler("UpdateProgressIdleHandler", 0.1, True);
	Items.ProgressUpdate.CurrentPage = Items.UpdateInProgress;
	Items.CancelProgressUpdate.Enabled = False;
	Items.ProgressUpdatePicture.Visible = True;
	Items.WaitForProgressUpdatePicture.Visible = False;
	
EndProcedure

&AtClient
Procedure StartProgressUpdateIdleHandler()
	
	StartProgressUpdate();
	
EndProcedure

&AtClient
Procedure UpdateProgressIdleHandler()
	
	Context = New Structure;
	Context.Insert("CalculateByDataAmount",  CalculateByDataAmount);
	Context.Insert("ShowProcessedLists",    Items.FormShowProcessedLists.Check);
	Context.Insert("IsRepeatedProgressUpdate", IsRepeatedProgressUpdate);
	Context.Insert("UpdatedTotal",                  UpdatedTotal);
	Context.Insert("ProgressUpdatePeriod",       ProgressUpdatePeriod);
	Context.Insert("ProgressAutoUpdate",         ProgressAutoUpdate);
	Context.Insert("AddedRows",               New Array);
	Context.Insert("DeletedRows",                 New Map);
	Context.Insert("ModifiedRows",                New Map);
	
	Try
		Status = StartProgressUpdateAtServer(Context, ResultAddress, StoredDataAddress,
			UUID, ProgressUpdateJobID);
	Except
		Items.CancelProgressUpdate.Enabled = True;
		Raise;
	EndTry;
	Items.CancelProgressUpdate.Enabled = True;
	
	If Status = "Completed" Then
		UpdateProgressAfterReceiveData(Context);
		
	ElsIf Status = "Running" Then
		ProgressUpdateRunning = False;
		AttachIdleHandler("CompleteProgressUpdateIdleHandler", 1, True);
		Return;
	EndIf;
	
EndProcedure

&AtClient
Procedure CompleteProgressUpdateIdleHandler()
	
	If Not ValueIsFilled(ProgressUpdateJobID) Then
		Return;
	EndIf;
	
	Context = Undefined;
	JobCompleted = EndProgressUpdateAtServer(Context, ResultAddress,
		StoredDataAddress, ProgressUpdateJobID);
	
	If Not JobCompleted Then
		If Context.ProgressUpdateRunning Then
			ProgressUpdateRunning = True;
		EndIf;
		Items.ProgressUpdatePicture.Visible         =    ProgressUpdateRunning;
		Items.WaitForProgressUpdatePicture.Visible = Not ProgressUpdateRunning;
		AttachIdleHandler("CompleteProgressUpdateIdleHandler", 1, True);
		Return;
	EndIf;
	
	UpdateProgressAfterReceiveData(Context);
	
EndProcedure

&AtClient
Procedure UpdateProgressAfterReceiveData(Context)
	
	UpdatedTotal = Context.UpdatedTotal;
	If Context.Property("ProgressUpdatePeriod") Then
		ProgressUpdatePeriod = Context.ProgressUpdatePeriod;
	EndIf;
	If Context.Property("ProgressAutoUpdate") Then
		ProgressAutoUpdate = Context.ProgressAutoUpdate;
	EndIf;
	
	Items.ScheduledJobDisabled.Visible = Context.Property("ScheduledJobDisabled");
	
	Index = Lists.Count() - 1;
	While Index >= 0 Do
		Row = Lists.Get(Index);
		If Context.DeletedRows.Get(Row.List) <> Undefined Then
			Lists.Delete(Index);
		Else
			ChangedRow = Context.ModifiedRows.Get(Row.List);
			If ChangedRow <> Undefined Then
				FillPropertyValues(Row, ChangedRow);
			EndIf;
		EndIf;
		Index = Index - 1;
	EndDo;
	For Each AddedRow In Context.AddedRows Do
		FillPropertyValues(Lists.Add(), AddedRow);
	EndDo;
	
	If Context.AddedRows.Count() > 0 Then
		SortListByFields();
	EndIf;
	
	If ProgressAutoUpdate Then
		AttachIdleHandler("StartProgressUpdateIdleHandler",
			ProgressUpdatePeriod, True);
	EndIf;
	
	Items.ProgressUpdate.CurrentPage = Items.UpdateCompleted;
	IsRepeatedProgressUpdate = True;
	
	UpdateAccessUpdateJobState(Context.AccessUpdateJobState);
	UpdateAccessUpdateJobStateInThreeSeconds();
	
EndProcedure

&AtServerNoContext
Function StartProgressUpdateAtServer(Context, ResultAddress, StoredDataAddress,
			FormID, ProgressUpdateJobID)
	
	If ValueIsFilled(StoredDataAddress) Then
		StoredData = GetFromTempStorage(StoredDataAddress);
	Else
		StoredData = New Structure;
		StoredData.Insert("ListsRows",    New Map);
		StoredData.Insert("ListsProperties",  New Map);
		StoredData.Insert("KeysCount", 0);
		StoredData.Insert("LatestUpdateDate", '00010101');
		StoredDataAddress = PutToTempStorage(StoredData, FormID);
	EndIf;
	
	FixedContext = New FixedStructure(Context);
	ProcedureParameters = New Structure(FixedContext);
	
	ResultAddress = PutToTempStorage(Undefined, FormID);
	ProcedureParameters.Insert("StoredData", StoredData);
	
	ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(FormID);
	ExecutionParameters.WaitForCompletion = 0;
	ExecutionParameters.ResultAddress = ResultAddress;
	ExecutionParameters.BackgroundJobDescription =
		NStr("ru = 'Управление доступом: Получение прогресса обновления доступа'; en = 'Access management: Receiving access update progress'; pl = 'Kontrola dostępu: Uzyskiwanie dostępu do postępu aktualizacji';es_ES = 'Gestión de acceso: Recepción de progreso de actualización de acceso';es_CO = 'Gestión de acceso: Recepción de progreso de actualización de acceso';tr = 'Erişim yönetimi: Erişim güncelleme ilerlemesini elde etmek';it = 'Controllo dell''accesso: acquisizione del progresso di aggiornamento dell''accesso';de = 'Zugriffskontrolle: Erreichen des Fortschritts bei der Aktualisierung der Zugriffsrechte'");
	
	RunResult = TimeConsumingOperations.ExecuteInBackground("AccessManagementInternal.UpdateProgressInBackground",
		ProcedureParameters, ExecutionParameters);
	
	ProgressUpdateJobID = Undefined;
	
	If RunResult.Status = "Completed" Then
		EndProgressUpdateAtServer(Context, ResultAddress,
			StoredDataAddress, Undefined);
		
	ElsIf RunResult.Status = "Running" Then
		ProgressUpdateJobID = RunResult.JobID;
		
	ElsIf RunResult.Status = "Error" Then
		Raise RunResult.DetailedErrorPresentation;
	EndIf;
	
	Return RunResult.Status;
	
EndFunction

&AtServerNoContext
Procedure CancelProgressUpdateAtServer(JobID)
	
	TimeConsumingOperations.CancelJobExecution(JobID);
	JobID = Undefined;
	
EndProcedure

&AtServerNoContext
Function EndProgressUpdateAtServer(Context, Val ResultAddress, Val StoredDataAddress,
			Val ProgressUpdateJobID)
	
	If ProgressUpdateJobID <> Undefined
	   AND Not TimeConsumingOperations.JobCompleted(ProgressUpdateJobID) Then
		
		Context = New Structure("ProgressUpdateRunning",
			TimeConsumingOperations.ReadProgress(ProgressUpdateJobID) <> Undefined);
		Return False;
	EndIf;
	
	Context = GetFromTempStorage(ResultAddress);
	PutToTempStorage(Context.StoredData, StoredDataAddress);
	Context.Delete("StoredData");
	
	Context.Insert("AccessUpdateJobState", AccessUpdateJobState());
	
	Return True;
	
EndFunction

&AtClient
Procedure SortList(Descending = False)
	
	CurrentColumn = Items.Lists.CurrentItem;
	
	If CurrentColumn = Undefined
	 Or Not StrStartsWith(CurrentColumn.Name, "Lists") Then
		
		ShowMessageBox(,
			NStr("ru = 'Выберите колонку для сортировки'; en = 'Select a column to sort'; pl = 'Wybierz kolumnę do sortowania';es_ES = 'Seleccione una columna para ordenar';es_CO = 'Seleccione una columna para ordenar';tr = 'Sıralamak için bir sütun seçin';it = 'Selezionare una colonna da ordinare';de = 'Wählen Sie die Spalte aus, die Sie sortieren möchten'"));
		Return;
	EndIf;
	
	SortFields.Clear();
	
	Field = Mid(Items.Lists.CurrentItem.Name, StrLen("Lists") + 1);
	SortFields.Add(Field, ?(Descending, "Desc", "Asc"));
	If Field <> "ListPresentation" Then
		SortFields.Add("ListPresentation", "Asc");
	EndIf;
	
	SortListByFields();
	
EndProcedure

&AtClient
Procedure SortListByFields(SortFieldIndex = 0, ListRows = Undefined)
	
	If SortFieldIndex >= SortFields.Count() Then
		Return;
	EndIf;
	
	SortField = SortFields[SortFieldIndex].Value;
	If ListRows = Undefined Then
		ListRows = New ValueList;
		For Each Row In Lists Do
			ListRows.Add(Row,
				PresentationForSort(Row[SortField]));
		EndDo;
	ElsIf ListRows.Count() < 2 Then
		Return;
	Else
		For Each ListItem In ListRows Do
			ListItem.Presentation =
				PresentationForSort(ListItem.Value[SortField]);
		EndDo;
	EndIf;
	
	InitialIndex = Lists.IndexOf(ListRows[0].Value);
	ListRows.SortByPresentation(
		SortDirection[SortFields[SortFieldIndex].Presentation]);
	
	CurrentPresentation = Undefined;
	Substrings = Undefined;
	NewIndex = InitialIndex;
	For Each ListItem In ListRows Do
		CurrentIndex = Lists.IndexOf(ListItem.Value);
		If CurrentIndex <> NewIndex Then
			Lists.Move(CurrentIndex, NewIndex - CurrentIndex);
		EndIf;
		If CurrentPresentation <> ListItem.Presentation Then
			If Substrings <> Undefined Then
				SortListByFields(SortFieldIndex + 1, Substrings);
			EndIf;
			Substrings = New ValueList;
			CurrentPresentation = ListItem.Presentation;
		EndIf;
		Substrings.Add(ListItem.Value);
		NewIndex = NewIndex + 1;
	EndDo;
	
	If Substrings <> Undefined Then
		SortListByFields(SortFieldIndex + 1, Substrings);
	EndIf;
	
EndProcedure

&AtClient
Function PresentationForSort(Value)
	
	Return Format(Value, "ND=15; NFD=4; NZ=00000000000,0000; NLZ=; NG=");
	
EndFunction

&AtServerNoContext
Procedure EnableScheduledJobAtServer()
	
	AccessManagementInternal.SetAccessUpdate(True);
	
EndProcedure

&AtServerNoContext
Procedure CancelAndDisableAccessUpdateAtServer()
	
	AccessManagementInternal.SetAccessUpdate(False);
	AccessManagementInternal.CancelAccessUpdateAtRecordLevel();
	
EndProcedure

#EndRegion
