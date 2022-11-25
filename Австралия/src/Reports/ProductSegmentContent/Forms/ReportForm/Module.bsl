
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
	TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
	ClearMessages();
	
	ExecutionResult = GenerateProductSegmentsAtServer();
	If ExecutionResult.Status = "Completed" Then
		ComposeResult(ResultCompositionMode.Background);
		Items.Pages.CurrentPage = Items.ResultPage;
	Else
		AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
	EndIf;
	
EndProcedure

#Region BackgroundJobs

&AtServer
Function GenerateProductSegmentsAtServer()
	
	JobID = Undefined;
	
	ProcedureName = "SegmentsServer.ExecuteProductSegmentsGeneration";
	StartSettings = TimeConsumingOperations.BackgroundExecutionParameters(UUID);
	StartSettings.BackgroundJobDescription = NStr("en = 'Product segments generation'; ru = 'Генерирование сегментов номенклатуры';pl = 'Generacja segmentów produktu';es_ES = 'Generación de segmentos de productos';es_CO = 'Generación de segmentos de productos';tr = 'Ürün segmenti oluşturma';it = 'Generazione segmenti articolo';de = 'Generierung von Produktsegmenten'");
	
	ExecutionResult = TimeConsumingOperations.ExecuteInBackground(
		ProcedureName,
		?(ValueIsFilled(Segment), New Structure("Segment", Segment), Undefined),
		StartSettings);
	
	StorageAddress = ExecutionResult.ResultAddress;
	JobID = ExecutionResult.JobID;
	
	If ExecutionResult.Status = "Completed" Then
		MessageText = NStr("en = 'Product segments have been updated successfully.'; ru = 'Сегменты номенклатуры успешно обновлены.';pl = 'Segmenty produktu zostali zaktualizowani pomyślnie.';es_ES = 'Se han actualizado con éxito los segmentos del producto.';es_CO = 'Se han actualizado con éxito los segmentos del producto.';tr = 'Ürün segmentleri başarıyla güncellendi.';it = 'I segmenti articolo sono stati aggiornati con successo.';de = 'Die Produktsegmente wurden erfolgreich aktualisiert.'");
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
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
