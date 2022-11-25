
&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	If IntraCommunityTransfer(CommandParameter) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'Cannot generate Goods receipt from Goods issue with Operation = Intra-community transfer. Select Goods issue with another operation.'; ru = 'Не удалось создать поступление товаров на основании отпуска товаров с операцией ""Перемещение внутри ЕС"". Выберите отпуск товаров с другой операцией.';pl = 'Nie można wygenerować Przyjęcia zewnętrznego z Wydanie zewnętrzne z Operacją = Przemieszczenie wewnątrz wspólnoty. Wybierz Wydanie zewnętrzne z inną operacją.';es_ES = 'No se puede generar el recibo de mercancías desde la Salida de mercancías con la Operación = Transferencia intracomunitaria. Seleccione la salida de mercancías con otra operación.';es_CO = 'No se puede generar el recibo de mercancías desde la Salida de mercancías con la Operación = Transferencia intracomunitaria. Seleccione la salida de mercancías con otra operación.';tr = 'İşlem = Topluluk içi transfer olan Ambar çıkışından Ambar girişi oluşturulamıyor. İşlemi farklı bir Ambar çıkışı seçin.';it = 'Impossibile generare la ricevuta Merci dal Documento di trasporto con Operazione = Trasferimenti intracomunitari. Selezionare il Documento di trasporto con un''altra operazione.';de = 'Wareneingang aus Warenausgang mit der Operation = EU-interner Transfer kann nicht generiert werden. Wählen Sie Warenausgang mit einer anderen Operation aus.'"));
		
		Return;
		
	EndIf;
	
	OpenForm("Document.GoodsReceipt.ObjectForm", New Structure("Basis", CommandParameter));
	
EndProcedure

&AtServer
Function IntraCommunityTransfer(GoodsIssue)
	
	Return GoodsIssue.OperationType = Enums.OperationTypesGoodsIssue.IntraCommunityTransfer;
	
EndFunction
 
