#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If WIPsAreActive(CommandParameter) Then
		
		FormParameters = New Structure;
		FormParameters.Insert("WIPsArray", CommandParameter);
		
		OpenForm("Document.ProductionTask.Form.GenerateProductionTasksForm", FormParameters);
	
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Function WIPsAreActive(WIPsArray)
	
	Result = True;
	
	For Each WIP In WIPsArray Do
		
		StructuredData = WIPCurrentState(WIP);
		
		If StructuredData.StatusIsCompleted Then
			
			Result = False;
			MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot create a Production task. %1 is completed. Select an active Work-in-progress and try again.'; ru = 'Не удалось создать производственную задачу. %1 завершено. Выберите активный документ ""Незавершенное производство"" и повторите попытку.';pl = 'Nie można zakończyć Zadania produkcyjnego. %1 jest zakończone. Wybierz aktywną Pracę w toku i spróbuj ponownie.';es_ES = 'No se puede crear una tarea de producción. %1 se ha finalizado. Seleccione un trabajo en progreso activo e inténtelo de nuevo.';es_CO = 'No se puede crear una tarea de producción. %1 se ha finalizado. Seleccione un trabajo en progreso activo e inténtelo de nuevo.';tr = 'Üretim görevi oluşturulamıyor. %1 tamamlandı. Aktif bir İşlem bitişi seçip tekrar deneyin.';it = 'Impossibile creare un Incarico di produzione. %1 è stato completato. Selezionare un Lavoro in corso e riprovare.';de = 'Fehler beim Erstellen einer Produktionsaufgabe. %1 ist abgeschlossen. Wählen Sie eine aktive Arbeit in Bearbeitung aus, und versuchen Sie es erneut.'"),
				WIP);
			CommonClientServer.MessageToUser(MessageToUser);
			
		EndIf;
		
		If StructuredData.SubcontractRequired Then
			
			Result = False;
			MessageToUser = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Cannot generate Production tasks for %1. Its Production method is Subcontracting. Select a ""Work-in-progress"" whose Production method is In-house production. Then try again.'; ru = 'Не удалось создать производственную задачу для %1, поскольку его способ производства – ""Переработка"". Выберите документ ""Незавершенное производство"" со способом производства ""Переработка"" и повторите попытку.';pl = 'Nie można wygenerować Zadań produkcyjnych dla %1. Jego sposób produkcji to Podwykonawstwo. Wybierz ""Pracę w toku"", której sposób produkcji to Produkcja wewnętrzna. Następnie spróbuj ponownie.';es_ES = 'No se han podido generar las Tareas de producción para %1. Su Método de producción es Subcontratación. Seleccione un ""Trabajo en progreso"" cuyo Método de producción es Producción propia. Inténtelo de nuevo.';es_CO = 'No se han podido generar las Tareas de producción para %1. Su Método de producción es Subcontratación. Seleccione un ""Trabajo en progreso"" cuyo Método de producción es Producción propia. Inténtelo de nuevo.';tr = '%1 için Üretim görevleri oluşturulamıyor. Üretim yöntemi Taşeronluk. Üretim yöntemi Şirket içi üretim olan bir ""İşlem bitişi"" seçip tekrar deneyin.';it = 'Impossibile generare Incarico di produzione per %1. Il suo Metodo di produzione è Subfornitura. Selezionare un ""Lavoro in corso"" il cui Metodo di produzione è In-house, poi riprovare.';de = 'Fehler beim Generieren von Produktionsaufgaben für %1. Dessen Produktionsmethode ist Subunternehmerbestellung. Wählen Sie eine ""Arbeit in Bearbeitung"" mit der Produktionsmethode Hausinterne Produktion aus. Dann versuchen Sie erneut.'"),
				TrimAll(WIP));
			CommonClientServer.MessageToUser(MessageToUser);
			
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function WIPCurrentState(WIP)
	
	WIPData = Common.ObjectAttributesValues(WIP, "Status, ProductionMethod");
	
	StructuredData = New Structure;
	StructuredData.Insert("StatusIsCompleted", WIPData.Status = Enums.ManufacturingOperationStatuses.Completed);
	StructuredData.Insert("SubcontractRequired", WIPData.ProductionMethod = Enums.ProductionMethods.Subcontracting);
	
	Return StructuredData;
	
EndFunction

#EndRegion