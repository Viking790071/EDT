#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If OrderHasProductionOperationKind(CommandParameter) Then
			
		FormParameters = New Structure("ProductionOrder", CommandParameter);
		OpenForm("Document.ProductionOrder.Form.PassingForExecution",
			FormParameters,
			CommandExecuteParameters.Source,
			CommandExecuteParameters.Uniqueness,
			CommandExecuteParameters.Window,
			CommandExecuteParameters.URL);
		
	Else
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot generate Work-in-progress from this Production order. You can generate Work-in-progress from Production orders whose Process type is Production.'; ru = 'Не удается создать документ ""Незавершенное производство"" на основании этого заказа на производство. ""Незавершенное производство"" можно создать на основании заказа на производство с типом процесса ""Производство"".';pl = 'Nie można wygenerować Pracy w toku z tego Zlecenia produkcyjnego. Możesz wygenerować Pracę w toku, w której typem procesu jest Produkcja.';es_ES = 'No se puede generar Trabajo en progreso desde esta Orden de producción. Se puede generar Trabajo en progreso a partir de Órdenes de producción cuyo tipo de Proceso es Producción.';es_CO = 'No se puede generar Trabajo en progreso desde esta Orden de producción. Se puede generar Trabajo en progreso a partir de Órdenes de producción cuyo tipo de Proceso es Producción.';tr = 'Bu Üretim emrinden İşlem bitişi oluşturulamıyor. İşlem bitişini, Süreç türü Üretim olan Üretim emirlerinden oluşturulabilirsiniz.';it = 'Impossibile creare Lavoro in corso da questo Ordine di produzione. È possibile creare Lavori in corso dagli Ordini di produzione il cui tipo di Processo è Produzione.';de = 'Fehler beim Generieren der Arbeit in Bearbeitung aus diesem Produktionsauftrag. Sie können Arbeit in Bearbeitung aus Produktionsaufträgen mit dem Prozesstyp Produktion generieren.'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function OrderHasProductionOperationKind(Order)
	
	Return (Common.ObjectAttributeValue(Order, "OperationKind") = Enums.OperationTypesProductionOrder.Production);
	
EndFunction

#EndRegion

