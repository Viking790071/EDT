
#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Generate(Command)
	GenerateImmediately();
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure GenerateImmediately()
	
	Items.Pages.CurrentPage = Items.InProgressPage;
	ClearMessages();
	
	ExecutionResult = GenerateCounterpartySegmentsAtServer();
	If ExecutionResult.Status = "Completed" Then
		ComposeResult(ResultCompositionMode.Background);
		Items.Pages.CurrentPage = Items.ResultPage;
	Else
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

#Region BackgroundJobs

&AtServer
Function GenerateCounterpartySegmentsAtServer()
	
	JobID = Undefined;
	
	CounterpartySegmentsJobID = Undefined;
	
	ProcedureName = "ContactsClassification.ExecuteCounterpartySegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Counterparty segments generation'; ru = 'Создание сегментов контрагента';pl = 'Generacja segmentów kontrahenta';es_ES = 'Generación de segmentos de contrapartida';es_CO = 'Generación de segmentos de contrapartida';tr = 'Cari hesap segmentleri oluşturma';it = 'Generazione segmenti controparti';de = 'Generierung von Geschäftspartnersegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(
		ProcedureName,
		?(ValueIsFilled(Segment), New Structure("Segment", Segment), Undefined),
		StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	JobID = ExecutionResult.JobID;
	
	Return ExecutionResult;

EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			ComposeResult(ResultCompositionMode.Background);
			Items.Pages.CurrentPage = Items.ResultPage;
		Else
			TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution",
				IdleHandlerParameters.CurrentInterval,
				True);
		EndIf;
	Except
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure OnOpen(Cancel)
	AttachIdleHandler("GenerateImmediately", 1, True);
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.VariantKey = Undefined Then
		Parameters.VariantKey = "Default";	
	EndIf;
		
	If Parameters.Filter.Property("Segment") Then
		Segment = Parameters.Filter.Segment;	
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion
