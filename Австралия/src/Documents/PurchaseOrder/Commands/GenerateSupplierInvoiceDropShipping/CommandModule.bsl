#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	Cancel = False;
	
	If CommandParameter.Count() = 0 Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'; ru = 'Команда не может быть выполнена для указанного объекта.';pl = 'Polecenie nie może być wykonane dla określonego obiektu.';es_ES = 'No se puede ejecutar el comando para el objeto especificado.';es_CO = 'No se puede ejecutar el comando para el objeto especificado.';tr = 'Komut, belirtilen nesne için yürütülemiyor.';it = 'Il comando non può essere eseguito per l''oggetto specificato.';de = 'Der Befehl kann für das angegebene Objekt nicht ausgeführt werden.'");
		ShowMessageBox(Undefined, WarningText);
		Cancel = True;
		
	ElsIf CommandParameter.Count() <> 1 Then
		
		DataStructure = Undefined;
		
		CheckOperationKind(CommandParameter, Cancel, DataStructure);
		
		If Not DataStructure = Undefined And DataStructure.CreateMultipleInvoices Then
			
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'The orders have different %1 in document headers. Do you want to split them into several documents?'; ru = 'В заголовках документов различаются %1. Разделить их на несколько документов?';pl = 'Zamówienia mają różne %1 w dokumencie. Czy chcesz podzielić je na kilka dokumentów?';es_ES = 'Los pedidos tienen %1 diferentes en los encabezados del documento. ¿Quiere dividirlos en varios documentos?';es_CO = 'Los pedidos tienen %1 diferentes en los encabezados del documento. ¿Quiere dividirlos en varios documentos?';tr = 'Siparişler belge üst bilgilerinde farklı %1 değerlerine sahip. Bunları birkaç belgeye bölmek ister misiniz?';it = 'Gli ordini hanno diverse %1 nelle intestazioni del documento. Si desidera dividerli in diversi documenti?';de = 'Die Aufträge haben unterschiedliche %1 in den Kopfzeilen der Dokumente. Möchten Sie sie in mehrere Dokumente aufteilen?'"),
				DataStructure.DataPresentation);
			
			ShowQueryBox(
				New NotifyDescription("CreateSuppliersInvoices", 
				ThisObject,
				New Structure("OrdersGroups", DataStructure.OrdersGroups)),
				MessageText, QuestionDialogMode.YesNo, 0);
			
			Cancel = True;
			
		EndIf;
	
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	FillStructure = New Structure("ArrayOfPurchaseOrders, DropShipping", CommandParameter, True);
	
	OpenForm("Document.SupplierInvoice.ObjectForm",
		New Structure("Basis", FillStructure),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window,
		CommandExecuteParameters.URL);
	
EndProcedure

&AtClient
Procedure CreateSuppliersInvoices(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		For Each OrdersArray In AdditionalParameters.OrdersGroups Do
			FillStructure = New Structure("ArrayOfPurchaseOrders, DropShipping", OrdersArray, True);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure), , True);
		EndDo;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure CheckOperationKind(ArrayOfPurchaseOrders, Cancel, DataStructure)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	PurchaseOrder.Presentation AS Presentation
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&ArrayOfPurchaseOrders)
	|	AND NOT PurchaseOrder.OperationKind = VALUE(Enum.OperationTypesPurchaseOrder.OrderForDropShipping)";
	
	Query.SetParameter("ArrayOfPurchaseOrders", ArrayOfPurchaseOrders);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	While SelectionDetailRecords.Next() Do
		
		TextMessage = NStr(
			"en = 'Cannot generate a ""Supplier invoice: Drop shipping"".
			|The %1 does not require drop shipping. 
			|For this Purchase order, generate Supplier invoice.'; 
			|ru = 'Не удалось сформировать «Инвойс поставщика: Дропшиппинг»"".
			|Для %1 не требуется дропшиппинг. 
			|Для этого заказа поставщику создайте инвойс поставщика.';
			|pl = 'Nie można wygenerować ""Faktury zakupu: Dropshipping"".
			| %1 nie wymaga dropshippingu. 
			|Dla tego Zamówienia zakupu wygeneruj Fakturę zakupu.';
			|es_ES = 'No se puede generar una ""factura de proveedor: Envío directo"". 
			|El %1 no requiere envío directo. 
			|Para esta orden de compra, genere la factura de proveedor.';
			|es_CO = 'No se puede generar una ""factura de proveedor: Envío directo"". 
			|El %1 no requiere envío directo. 
			|Para esta orden de compra, genere la factura de proveedor.';
			|tr = '""Satın alma faturası: Stoksuz satış"" oluşturulamıyor.
			|%1, stoksuz sipariş gerektirmiyor. 
			|Bu Satın alma siparişi için Satın alma faturası oluşturun.';
			|it = 'Impossibile generare una ""Fattura del fornitore: Dropshipping"".
			| %1Non richiede dropshipping. 
			|Per questo Ordine di acquisto, generare una Fattura del fornitore.';
			|de = 'Fehler beim Generieren einer ""Lieferantenrechnung: Streckengeschäft"".
			| %1 benötigt kein Streckengeschäft. 
			|Für diese Bestellung an Lieferanten generieren Sie eine Lieferantenrechnung.'");
		
		TextMessage = StringFunctionsClientServer.SubstituteParametersToString(TextMessage,
			SelectionDetailRecords.Presentation);
			
		CommonClientServer.MessageToUser(TextMessage);
		
		Cancel = True;
		Return;
		
	EndDo;
	
	DataStructure = DriveServer.CheckPurchaseOrdersSupplierInvoicesKeyAttributes(ArrayOfPurchaseOrders);
	
EndProcedure


#EndRegion