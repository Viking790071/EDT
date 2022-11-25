#Region Variables

&AtClient
Var HandlerParameters;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If GetFunctionalOption("DriveTrade") Or Not BaseHasCostLayers() Then
		OnlyProduction = False;
	Else
		OnlyProduction = True;
	EndIf;
	Items.OnlyProduction.Visible = OnlyProduction;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	Items.Pages.CurrentPage = Items.PageDescription;
	SetChangesInForm();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Next(Command)
	
	If Items.Pages.CurrentPage = Items.PageResult Then
		Close();
	Else
		Items.Pages.CurrentPage = Items.PageFilling;
		AttachIdleHandler("Filling", 1, True);
	EndIf;
	
	SetChangesInForm();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	If ValueIsFilled(BackgroundJobID) Then
		TerminateBackgroundJob(BackgroundJobID);
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure InformationTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	If FormattedStringURL = "SetupTask" Then
		OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledAndBackgroundJobs");
	ElsIf FormattedStringURL = "ExecuteTask" Then
		ExecuteScheduledJobManually();
	EndIf;
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure ExecuteScheduledJobManually()
	
	ExecutionParameters = ExecuteScheduledJobManuallyAtServer();
	CalculateFIFOJobID = ExecutionParameters.BackgroundJobID;
	If ExecutionParameters.Started Then
		
		ShowUserNotification(
			NStr("en = 'The scheduled job procedure is running'; ru = 'Запущена процедура регламентного задания';pl = 'Jest uruchomiona procedura zaplanowanego zadania';es_ES = 'Se ha lanzado un tarea programada';es_CO = 'Se ha lanzado un tarea programada';tr = 'Zamanlanmış iş başlatıldı';it = 'La procedura programmata di incarico è in esecuzione';de = 'Geplanter Job wird gestartet'"),
			,
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The procedure is run in background job %1'; ru = 'Процедура запущена в фоновом задании %1';pl = 'Procedura jest uruchamiana w zadaniu działającym w tle %1';es_ES = 'El procedimiento se ejecuta en la tarea de fondo %1';es_CO = 'El procedimiento se ejecuta en la tarea de fondo %1';tr = 'Prosedür, %1 arka plan işinde başlatıldı';it = 'La procedura è eseguita come processo in background %1';de = 'Die Prozedur wird im Hintergrundjob gestartet %1'"),
				String(ExecutionParameters.StartedAt)),
			PictureLib.ExecuteScheduledJobManually);
		
		AttachIdleHandler("Attachable_CheckCalculateFIFOBackgroundJob", 0.1, True);
		
	ElsIf ExecutionParameters.ProcedureAlreadyExecuting Then
		
		ShowUserNotification(
			StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Procedure of scheduled job is already executed in background job ""%1"" started %2.'; ru = 'Процедура регламентного задания уже выполняется в фоновом задании ""%1"", начатом %2.';pl = 'Procedura planowego zadania jest już wykonywana w zadaniu w tle ""%1"", rozpoczętym %2.';es_ES = 'El procedimiento de la tarea programada ya se está ejecutando en la tarea de fondo ""%1"" empezada %2.';es_CO = 'El procedimiento de la tarea programada ya se está ejecutando en la tarea de fondo ""%1"" empezada %2.';tr = 'Zamanlanmış iş prosedürü %2''de başlatılmış ""%1"" arka plan işinde zaten gerçekleştirildi.';it = 'Procedura di incarico pianificato già eseguita nel processo in background ""%1"" avviata %2.';de = 'Die Prozedur des geplanten Jobs wird bereits im Hintergrundjob ""%1"" mit %2 gestartet durchgeführt.'"),
				ExecutionParameters.BackgroundJobPresentation,
				String(ExecutionParameters.StartedAt)));
		
	EndIf;
	
EndProcedure

&AtServerNoContext
Function ExecuteScheduledJobManuallyAtServer()
	
	ScheduledJobID = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.CalculateFIFO).UUID;
	Result = ScheduledJobsInternal.ExecuteScheduledJobManually(ScheduledJobID);
	Return Result;
	
EndFunction

&AtClient
Procedure Attachable_CheckCalculateFIFOBackgroundJob()
	
	If BackgroundJobIsCompleted(CalculateFIFOJobID) Then
		ShowUserNotification(
			NStr("en = 'The scheduled job procedure has been executed'; ru = 'Выполнена процедура регламентного задания';pl = 'Procedura zaplanowanego zadania została wykonana';es_ES = 'Procedimiento de la tarea programada se ha ejecutado';es_CO = 'Procedimiento de la tarea programada se ha ejecutado';tr = 'Zamanlanmış iş prosedürü gerçekleştirildi';it = 'La procedura pianificta di incarico è stata eseguita';de = 'Die Prozedur des geplanten Jobs wird ausgeführt'"),
			,
			,
			PictureLib.ExecuteScheduledJobManually);
	EndIf;
	
EndProcedure

&AtClient
Procedure Filling()
	FillData();
EndProcedure

&AtClient
Procedure FillData()
	
	LoadingParameters = New Map();
	LoadingParameters.Insert("MessageText", "");
	LoadingParameters.Insert("LoadingIsCompleted", False);
	LoadingParameters.Insert("OnlyProduction", OnlyProduction);
	
	Result = RunBackgroundJob(LoadingParameters);
	
	StorageAddress = Result.ResultAddress;
	If Not Result.Status = "Completed" Then
		BackgroundJobID = Result.JobID;
		
		TimeConsumingOperationsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("Attachable_CheckBackgroundJob", 1, True);
	Else
		LoadResult();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChangesInForm()
	
	If Items.Pages.CurrentPage = Items.PageDescription Then
		Items.FormNext.Title = NStr("en = 'Begin posting >>'; ru = 'Начать проведение >>';pl = 'Rozpocznij dekretowanie >>';es_ES = 'Iniciar el envío >>';es_CO = 'Iniciar el envío >>';tr = 'Gönderiliyor >>';it = 'Inizio pubblicazione >>';de = 'Buchung starten>>'");
		Items.FormNext.Enabled = True;
		Items.FormCancel.Enabled = True;
	ElsIf Items.Pages.CurrentPage = Items.PageFilling Then
		Items.FormNext.Visible = False;
		Items.FormCancel.Enabled = True;
	Else
		Items.FormNext.Title = NStr("en = 'Finish'; ru = 'Готово';pl = 'Gotowe';es_ES = 'Finalizar';es_CO = 'Finalizar';tr = 'Bitiş';it = 'Termina';de = 'Beenden'");
		Items.FormNext.Enabled = True;
		Items.FormNext.Visible = True;
		Items.FormCancel.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadResult()
	
	Result = GetFromTempStorage(StorageAddress);
	
	EventName = NStr("en = 'FIFO. Posting documents on the ""Inventory cost layer"" register.'; ru = 'FIFO. Проведение документов по регистру ""Партии товаров на складах"".';pl = 'FIFO. Dekretowanie dokumentów w rejestrze ""Koszt własny zapasów"".';es_ES = 'FIFO. Enviando los documentos al registro""Capa del coste del inventario"".';es_CO = 'FIFO. Enviando los documentos al registro""Capa del coste del inventario"".';tr = 'FIFO. Belgeleri ""Stok maliyet katmanı"" kaydına gönderiyor.';it = 'FIFO. Pubblicazione di documenti sul registro ""Livello costo delle scorte"".';de = 'FIFO. Buchung von Dokumenten im Register ""Bestandskostenebene"".'");
	
	If Result["LoadingIsCompleted"] Then
		EventLogClient.AddMessageForEventLog(EventName,, Result["MessageText"],, True);
		EnableFIFO();
	Else
		EventLogClient.AddMessageForEventLog(EventName, "Error", Result["MessageText"],, True);
	EndIf;
	
	Items.Pages.CurrentPage = Items.PageResult;
	
	SetChangesInForm();
	
EndProcedure

&AtServerNoContext
Procedure EnableFIFO()
	Constants.UseFIFO.Set(True);
EndProcedure

&AtServer
Function BaseHasCostLayers()
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED TOP 1
	|	InventoryCostLayer.CostLayer AS CostLayer
	|FROM
	|	AccumulationRegister.InventoryCostLayer AS InventoryCostLayer";
	
	QueryResult = Query.Execute();
	
	Return Not QueryResult.IsEmpty();
	
EndFunction

#Region BackgroundJob

&AtServer
Function RunBackgroundJob(Parameters)
	
	If Common.FileInfobase() Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		DataProcessors.FillCostLayerRegisters.Posting(Parameters, StorageAddress);
		Result = New Structure("Status, ResultAddress", "Completed", StorageAddress);
	Else
		ExecutionParameters = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
		ExecutionParameters.BackgroundJobDescription = NStr("en = 'The documents is posting on the ""Inventory cost layer"" register.'; ru = 'Проведение документов по регистру ""Партии товаров на складах"".';pl = 'Dokumenty są dekretowane w rejestrze ""Koszt własny zapasów"".';es_ES = 'El documento se está enviando al registro ""Capa del coste del inventario"".';es_CO = 'El documento se está enviando al registro ""Capa del coste del inventario"".';tr = 'Belgeler ""Stok maliyet katmanı"" kaydında gönderiliyor/ kaydediliyor.';it = 'I documenti sono pubblicati sul registro ""Livello costo delle scorte"".';de = 'Die Belege werden im Register ""Bestandskostenebene"" gebucht.'");
		
		Result = TimeConsumingOperations.ExecuteInBackground(
			"DataProcessors.FillCostLayerRegisters.Posting",
			Parameters,
			ExecutionParameters);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure TerminateBackgroundJob(BackgroundJobID)
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJobID);
	If BackgroundJob <> Undefined Then
		BackgroundJob.Cancel();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckBackgroundJob()
	
	If BackgroundJobIsCompleted(BackgroundJobID) Then
		LoadResult();
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckBackgroundJob",
			HandlerParameters.CurrentInterval,
			True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BackgroundJobIsCompleted(BackgroundJobID)
	Return TimeConsumingOperations.JobCompleted(BackgroundJobID);
EndFunction

#EndRegion

#EndRegion