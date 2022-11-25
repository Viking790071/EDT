#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	ScheduledJobUUID = New UUID();
EndProcedure

Procedure BeforeDelete(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsFolder Then
		Return;
	EndIf;
	
	Job = ScheduledJobs.FindByUUID(ScheduledJobUUID);
	If Job <> Undefined Then
		Job.Delete();
	EndIf;
		
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If TypeOfDocument = "SalesInvoice" Then
		CheckedAttributes.Add("EmailAccount");
	Else
		
		For Each InventoryLine In Inventory Do
			
			BatchRequired = Common.ObjectAttributeValue(InventoryLine.Products, "UseBatches");
			
			If BatchRequired = True Then
				
				If Not ValueIsFilled(InventoryLine.Batch) Then
					
					MessageText = NStr("en = 'The ""Batch"" field is required.'; ru = 'Заполните поле ""Партия"".';pl = 'Pole ""Partia"" jest wymagane.';es_ES = 'El campo ""Lote"" es obligatorio.';es_CO = 'El campo ""Lote"" es obligatorio.';tr = '""Parti"" alanı gerekli.';it = 'Il campo ""Lotto"" è richiesto.';de = 'Das ""Charge""-Feld ist erforderlich.'");
						CommonClientServer.MessageToUser(MessageText,
						ThisObject,
						CommonClientServer.PathToTabularSection("Inventory", InventoryLine.LineNumber, "Batch"),
						,
						Cancel);
					
				EndIf;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

#EndRegion

#Else

	Raise NStr("en = 'Invalid object call on the client.'; ru = 'Недопустимый вызов объекта на клиенте.';pl = 'Niepoprawne wywołanie obiektu w kliencie.';es_ES = 'Invalidar la llamada de objeto al cliente.';es_CO = 'Invalidar la llamada de objeto al cliente.';tr = 'İstemcide geçersiz nesne çağrısı.';it = 'Chiamata oggetto non valida per il client.';de = 'Ungültiger Objektabruf beim Kunden.'");

#EndIf

