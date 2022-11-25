#Region Variables

&AtClient
Var IdleHandlerParameters;

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure RunSync(Command)
	
	If Items.List.CurrentData = Undefined Then
		Return;
	EndIf;
	
	MessageText = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'Data exchange with website started on %1.'; ru = 'Обмен данными с веб-сайтом начался %1.';pl = 'Wymiana danych ze stroną internetową została rozpoczęta %1.';es_ES = 'Intercambio de datos con el sitio web comenzado el %1.';es_CO = 'Intercambio de datos con el sitio web comenzado el %1.';tr = 'Web sitesi ile veri değişimi başlangıcı: %1.';it = 'Lo scambio dati con il sito web è iniziato a %1.';de = 'Datenaustausch mit Webseite, began am: %1.'"),
		Format(CommonClient.SessionDate(), "DLF=DT"));
			
	Explanation = StringFunctionsClientServer.SubstituteParametersToString(
		NStr("en = 'by exchange node ""%1""...'; ru = 'по узлу обмена ""%1""...';pl = 'według węzła wymiany ""%1""...';es_ES = 'por el nodo de intercambio ""%1""...';es_CO = 'por el nodo de intercambio ""%1""...';tr = '""%1"" değişim düğümü ile...';it = 'per nodo di scambio ""%1""...';de = 'durch Exchange-Knoten ""%1""...'"),
		Items.List.CurrentRow);
	
	Status(MessageText,	, Explanation);
			
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Refresh", False);
	ParametersStructure.Insert("ExchangeStartMode", NStr("en = 'Interactive exchange'; ru = 'Интерактивный обмен';pl = 'Wymiana interaktywna';es_ES = 'Intercambio interactivo';es_CO = 'Intercambio interactivo';tr = 'İnteraktif değişim';it = 'Scambio interattivo';de = 'Interaktiver Austausch'"));
	
	Result = ExchangeCompletedServer(Items.List.CurrentRow, ParametersStructure);
	
	If ParametersStructure.Refresh Then
		NotifyChanged(Type("DocumentRef.SalesOrder"));
	EndIf;
		
	If Not Result.JobCompleted Then
		
		JobID = Result.JobID;
		TimeConsumingOperationsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		IdleHandlerParameters.IntervalIncreaseCoefficient = 1.2;
		AttachIdleHandler("Attachable_CheckJobCompletion", 1, True);
		
	Else
		
		Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = '%1 ""%2""'; ru = '%1 ""%2""';pl = '%1 ""%2""';es_ES = '%1 ""%2""';es_CO = '%1 ""%2""';tr = '%1 ""%2""';it = '%1 ""%2""';de = '%1 ""%2""'"),
				Format(CommonClient.SessionDate(), "DLF=DT"),
				Items.List.CurrentRow);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Data exchange with the website is completed.'; ru = 'Обмен данными с веб-сайтом завершен.';pl = 'Wymiana danych ze stroną internetową została zakończona.';es_ES = 'Se completa el intercambio de datos con el sitio web.';es_CO = 'Se completa el intercambio de datos con el sitio web.';tr = 'Web sitesi ile veri değişimi tamamlandı.';it = 'Scambio dati con il sito web completato.';de = 'Datenaustausch mit der Webseite ist abgeschlossen.'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithWebsiteCompleted");
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServer
Function ExchangeCompletedServer(ExchangeNode, Parameters)

	If ExchangeWithWebsiteCached.GetThisExchangePlanNode(ExchangeNode)
		Or ExchangeNode.DeletionMark Then
		Return True;
	EndIf;
	
	Parameters.Insert("ExchangeNode", ExchangeNode);
	Parameters.Insert("ExchangeStartMode", NStr("en = 'Interactive data exchange'; ru = 'Интерактивный обмен данными';pl = 'Interaktywna wymiana danych';es_ES = 'Intercambio de datos interactivo';es_CO = 'Intercambio de datos interactivo';tr = 'İnteraktif veri değişimi';it = 'Scambio dati interattivo';de = 'Interaktiver Datenaustausch'"));
	JobDescription = NStr("en = 'Sync with website'; ru = 'Синхронизация с веб-сайтом';pl = 'Synchronizuj ze stroną internetową';es_ES = 'Sincronizar con el sitio web';es_CO = 'Sincronizar con el sitio web';tr = 'Web sitesi ile senkronizasyon';it = 'Sincronizzazione con sito web';de = 'Synchronisieren mit Webseite'");
	
	Result = TimeConsumingOperations.StartBackgroundExecution(
		UUID,
		"ExchangeWithWebsiteEvents.ExecuteExchange",
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
				Items.List.CurrentRow);
		
		ShowUserNotification(Text,
			,
			NStr("en = 'Exchange with website is completed'; ru = 'Обмен с веб-сайтом завершен';pl = 'Wymiana danych ze stroną internetową została zakończona';es_ES = 'Se completa el intercambio con el sitio web';es_CO = 'Se completa el intercambio con el sitio web';tr = 'Web sitesi ile değişim tamamlandı';it = 'Scambio con sito web completato';de = 'Austausch mit Webseite ist abgeschlossen'"),
			PictureLib.Information32);
			
		Notify("ExchangeWithWebsiteCompleted");
		
	Else
		TimeConsumingOperationsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckJobCompletion", IdleHandlerParameters.CurrentInterval, True);
	EndIf;

EndProcedure

&AtServerNoContext 
Function JobCompleted(JobID)
	
	Return TimeConsumingOperations.JobCompleted(JobID);
	
EndFunction

#EndRegion

