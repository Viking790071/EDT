#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If CheckTask(CommandParameter) Then
		
		FormParameters = New Structure("ProductionTask", CommandParameter);
		OpenForm("Document.ProductionTask.Form.SplitForm",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function CheckTask(ProductionTask)
	
	Result = False;
	
	TaskAttributes = Common.ObjectAttributesValues(ProductionTask, "Status, Posted");
	
	If TaskAttributes.Posted Then
		
		If TaskAttributes.Status = Enums.ProductionTaskStatuses.Open
			Or TaskAttributes.Status = Enums.ProductionTaskStatuses.Suspended Then
			
			Result = True;
			
		Else
			
			CommonClientServer.MessageToUser(NStr("en = 'Cannot split this Production task. Select a Production task with status ""Open"" or ""Suspended"" and try again.'; ru = 'Не удается разделить эту производственную задачу. Выберите производственную задачу со статусом ""Открыта"" или ""Приостановлена"" и повторите попытку.';pl = 'Nie można rozdzielić zadania produkcyjnego. Wybierz Zadanie produkcyjne o statusie ""Otwarte"" lub ""Zawieszone"" i spróbuj ponownie.';es_ES = 'No se puede dividir esta tarea de producción. Seleccione una tarea de Producción en estado ""Abrir"" o ""Suspendido"" e inténtelo de nuevo.';es_CO = 'No se puede dividir esta tarea de producción. Seleccione una tarea de Producción en estado ""Abrir"" o ""Suspendido"" e inténtelo de nuevo.';tr = 'Bu Üretim görevi bölünemiyor. Durumu ""Açık"" veya ""Askıya alındı"" olan bir Üretim görevi seçip tekrar deneyin.';it = 'Impossibile dividere questo Incarico di produzione. Selezionare un Incarico di produzione con stato ""Aperto"" o ""Sospeso"" e riprovare.';de = 'Dieser Produktionsauftrag kann nicht aufgeteilt werden. Wählen Sie eine Produktionsaufgabe mit dem Status „Offen“ oder „Suspendiert“ aus und versuchen Sie es erneut.'"));
			
		EndIf;
		
	Else
		
		CommonClientServer.MessageToUser(NStr("en = 'Cannot split this Production task. First, post this document.'; ru = 'Не удается разделить эту производственную задачу. Сначала проведите этот документ.';pl = 'Nie można rozdzielić Zadania produkcyjnego. Najpierw zatwierdź ten dokument.';es_ES = 'No se puede dividir esta tarea de producción. Primero, envíe este documento.';es_CO = 'No se puede dividir esta tarea de producción. Primero, envíe este documento.';tr = 'Bu Üretim görevi bölünemiyor. İlk olarak, bu belgeyi yayınlayın.';it = 'Impossibile dividere l''Incarico di produzione. Pubblicare prima questo documento.';de = 'Diese Produktionsaufgabe kann nicht aufgeteilt werden. Zuerst buchen Sie dieses Dokument.'"));
		
	EndIf;
	
	Return Result;
	
EndFunction

#EndRegion