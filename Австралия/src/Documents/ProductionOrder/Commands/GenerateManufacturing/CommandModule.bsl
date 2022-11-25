
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If SubcontractingServices(CommandParameter) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot generate Production from this Production order. The order is related to Subcontractor order received. 
				|It is a part of the subcontrating process. For this process, generate Production from Work-in-progress.'; 
				|ru = 'Не удается создать документ ""Производство"" на основании данного заказа на производство. Заказ связан с полученным заказом на переработку.
				|Это часть процесса переработки. Для этого процесса создайте ""Производство"" на основании ""Незавершенного производства"".';
				|pl = 'Nie można wygenerować Produkcji z tego Zlecenia produkcyjnego. Zlecenie jest związane z Otrzymanym zamówieniem podwykonawcy. 
				|To jest część procesu podwykonawstwa. Dla tego procesu, utwórz Produkcję z Pracy w toku.';
				|es_ES = 'No se puede generar Producción de esta orden de Producción. La orden está relacionada con la orden recibida del Subcontratista. 
				|Forma parte del proceso de subcontratación. Para este proceso, genere Producción del Trabajo en progreso.';
				|es_CO = 'No se puede generar Producción de esta orden de Producción. La orden está relacionada con la orden recibida del Subcontratista. 
				|Forma parte del proceso de subcontratación. Para este proceso, genere Producción del Trabajo en progreso.';
				|tr = 'Bu Üretim emrinden Üretim oluşturulamıyor. Emir, Alınan alt yüklenici siparişi ile ilişkili. 
				|Alt yüklenici sürecinin bir parçasıdır. Bu süreç için İşlem bitişinden Üretim oluşturun.';
				|it = 'Impossibile generare Produzione da questo Ordine di produzione. L''ordine è relativo all''Ordine di subfornitura ricevuto. 
				|È parte del contratto di subfornitura. Per questo processo, generare Produzione da Lavori in corso.';
				|de = 'Fehler beim Generieren der Produktion aus diesem Produktionsauftrag. Der Auftrag ist mit Subunternehmerauftrag erhalten verbunden. 
				|Dieser is ein Teil des Prozesses der Subunternehmerbestellung. Für diesen Prozess, generieren Sie die Produktion aus Arbeit in Bearbeitung.'"));
			
	ElsIf OrderHasProductionOperationKind(CommandParameter) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot generate Production from the Production order whose Process type is Production. Such a Production order is a part of the multioperation make-to-order process. For this process, generate Production from Work-in-progress.'; ru = 'Не удалось создать документ ""Производство"" на основании заказа на производство с типом процесса ""Производство"". Такой заказ на производство является частью многооперационного процесса производства под заказ. Для этого процесса создайте ""Производство"" на основании ""Незавершенного производства"".';pl = 'Nie można wygenerować Produkcji ze Zlecenia produkcyjnego, którego Typ procesu jest Produkcja. Takie Zlecenie produkcyjne jest częścią wielooperacyjnego procesu produkcji na zamówienie. Dla tego procesu, Wygeneruj Produkcję z Pracy w toku.';es_ES = 'No se puede generar la Producción desde la Orden de producción cuyo Tipo de proceso es Producción. Dicha orden de producción forma parte del proceso de fabricación por encargo multioperativo. Para este proceso, genere la Producción desde el Trabajo en progreso.';es_CO = 'No se puede generar la Producción desde la Orden de producción cuyo Tipo de proceso es Producción. Dicha orden de producción forma parte del proceso de fabricación por encargo multioperativo. Para este proceso, genere la Producción desde el Trabajo en progreso.';tr = 'Süreç türü Üretim olan Üretim emrinden Üretim oluşturulamaz. Bu tür bir Üretim emri çok işlemli siparişe göre üretim sürecinin bir parçasıdır. Bu süreç için İşlem bitişinden Üretim oluşturun.';it = 'Impossibile generare Produzione dall''Ordine di produzione il cui Tipo processo è Produzione. Questo Ordine di produzione è una parte del processo multioperativo fatto su ordinazione. Per questo processo, generare Produzione da Lavoro in corso.';de = 'Fehler beim Generieren der Produktion aus dem Produktionsauftrag mit dem Prozesstyp Produktion. Solcher Produktionsauftrag ist ein Teil des Mehroperationsprozesses der Auftragsfertigung. Für diesen Prozess, generieren Sie Produktion aus Arbeit in Bearbeitung.'"));
		
	Else
		
		OpenForm("Document.Manufacturing.ObjectForm", New Structure("Basis", CommandParameter));
		
	EndIf;

EndProcedure

#EndRegion

#Region Private

&AtServer
Function OrderHasProductionOperationKind(Order)
	
	Return (Common.ObjectAttributeValue(Order, "OperationKind") = Enums.OperationTypesProductionOrder.Production);
	
EndFunction

&AtServer
Function SubcontractingServices(ProductionOrder)
	
	Return TypeOf(ProductionOrder.SalesOrder) = Type("DocumentRef.SubcontractorOrderReceived");
	
EndFunction

#EndRegion