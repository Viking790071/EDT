
#Region FormCommandsHandlers

&AtClient
Procedure PreliminaryOperationAuthorizationEnd(Result, Parameters) Export
	 
	FormParameters = New Structure;
	If Parameters.Property("SpecifyAdditionalInformation") Then
		FormParameters.Insert("SpecifyAdditionalInformation", True);
	EndIf;
	
	If Parameters.Property("AmountEditingProhibition") Then
		FormParameters.Insert("AmountEditingProhibition", Parameters.AmountEditingProhibition);
	EndIf;
	
	If Parameters.Property("OperationKind") Then
		Result.Insert("OperationKind", Parameters.OperationKind);
	EndIf;
	
	If Parameters.Property("WithoutReturnedParameters") Then
		Result.Insert("WithoutReturnedParameters", Parameters.WithoutReturnedParameters);
	EndIf;
	
	If Parameters.Property("SpecifyRefNo") Then
		Result.Insert("SpecifyRefNo", Parameters.SpecifyRefNo);
	EndIf;
	
	NotifyDescription = New NotifyDescription(Parameters.DataProcessorAlert, ThisObject, Result);
	OpenForm("Catalog.Peripherals.Form.POSTerminalAuthorizationForm", FormParameters,,,  ,, NotifyDescription, FormWindowOpeningMode.LockWholeInterface);
	
EndProcedure

&AtClient
Procedure ExecuteOperationByPaymentCardEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Structure") Then
		
		If Not Parameters.Property("OperationKind") Then
			MessageText = NStr("en = 'Transaction type is not specified.'; ru = 'Не указан тип транзакции.';pl = 'Typ transakcji nie został określony.';es_ES = 'Tipo de transacción no está especificado.';es_CO = 'Tipo de transacción no está especificado.';tr = 'İşlem tipi belirtilmedi.';it = 'Tipo di transazione non specificato.';de = 'Transaktionstyp ist nicht angegeben.'");
			CommonClientServer.MessageToUser(MessageText);
			Return;
		EndIf;
		
		InputParameters  = New Array();
		Output_Parameters = Undefined;
		
		SlipReceiptText  = "";
		AmountOfOperations  = Result.Amount;
		ReceiptNumber      = Result.ReceiptNumber;
		CardData    = Result.CardData;
		RefNo = Result.RefNo;
		
		InputParameters.Add(AmountOfOperations);
		InputParameters.Add(CardData);
		If Parameters.Property("SpecifyRefNo") Then
			InputParameters.Add(RefNo);
			InputParameters.Add(ReceiptNumber);
		Else
			InputParameters.Add(ReceiptNumber);
			InputParameters.Add(RefNo);
		EndIf;
		
		// Executing the operation on POS terminal.
		ResultET = EquipmentManagerClient.RunCommand(Parameters.EnabledDeviceIdentifierET, Parameters.OperationKind, InputParameters, Output_Parameters);
		
		If Not ResultET Then
			MessageText = NStr("en = 'When operation execution there
			                   |was error: ""%ErrorDescription%"".
			                   |Operation by card was not made.'; 
			                   |ru = 'При выполнении операции возникла ошибка:
			                   |""%ErrorDescription%"".
			                   |Отмена по карте не была произведена';
			                   |pl = 'Podczas wykonywania operacji
			                   |wystąpił błąd: ""%ErrorDescription%"".
			                   |Operacja kartą nie została wykonana.';
			                   |es_ES = 'Al ejecutar la operación, había
			                   |un error: ""%ErrorDescription%"".
			                   |Operación con tarjeta no se ha realizado.';
			                   |es_CO = 'Al ejecutar la operación, había
			                   |un error: ""%ErrorDescription%"".
			                   |Operación con tarjeta no se ha realizado.';
			                   |tr = 'İşlem esnasında bir 
			                   |hata oluştu: ""%ErrorDescription%"". 
			                   |Kartla işlem yapılmadı.';
			                   |it = 'Durante l''esecuzione dell''operazione"
"si è registrato un errore: ""%ErrorDescription%""."
"L''operazione con carta non può essere eseguita.';
			                   |de = 'Bei der Ausführung der Operation ist
			                   |ein Fehler aufgetreten: ""%ErrorDescription%"".
			                   |Eine Bedienung per Karte wurde nicht durchgeführt.'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		Else
			
			If Parameters.Property("WithoutReturnedParameters") Then
				CardNumber          = "";
				OperationRefNumber = "";
				ReceiptNumber           = "";
				SlipReceiptText       = Output_Parameters[0][1];
			Else
				CardNumber            = Output_Parameters[0];
				OperationRefNumber    = Output_Parameters[1];
				ReceiptNumber         = Output_Parameters[2];
				SlipReceiptText       = Output_Parameters[3][1];
			EndIf;
			
			If Not IsBlankString(SlipReceiptText) Then
				glPeripherals.Insert("LastSlipReceipt", SlipReceiptText);
			EndIf;
			
			ResultFR = True;
			
			If Not Parameters.ReceiptsPrintOnTerminal AND Not Parameters.FREnableDeviceID = Undefined Then
				If Not IsBlankString(SlipReceiptText) Then
					InputParameters = New Array();
					InputParameters.Add(SlipReceiptText);
					Output_Parameters = Undefined;
					ResultFR = EquipmentManagerClient.RunCommand(Parameters.FREnableDeviceID, "PrintText", InputParameters, Output_Parameters);
				EndIf;
			EndIf;
			
			If ResultET AND Not ResultFR Then
				ErrorDescriptionFR  = Output_Parameters[1];
				InputParameters  = New Array();
				
				Output_Parameters = Undefined;
				InputParameters.Add(AmountOfOperations);
				InputParameters.Add(OperationRefNumber);
				InputParameters.Add(ReceiptNumber);
				// Executing the operation on POS terminal
				EquipmentManagerClient.RunCommand(Parameters.EnabledDeviceIdentifierET, "EmergencyVoid", InputParameters, Output_Parameters);
				
				MessageText = NStr("en = 'An error occurred while printing
				                   |a slip receipt: ""%ErrorDescription%"".
				                   |Operation by card has been cancelled.'; 
				                   |ru = 'При печати слип чека
				                   |возникла ошибка: ""%ErrorDescription%"".
				                   |Операция по карте была отменена.';
				                   |pl = 'Wystąpił błąd podczas drukowania
				                   |paragonu fiskalnego: ""%ErrorDescription%"".
				                   |Operacja kartą została anulowana.';
				                   |es_ES = 'Ha ocurrido un error al imprimir
				                   |un recibo de comprobante: ""%ErrorDescription%"".
				                   |Operación con tarjeta se ha cancelado.';
				                   |es_CO = 'Ha ocurrido un error al imprimir
				                   |un recibo de comprobante: ""%ErrorDescription%"".
				                   |Operación con tarjeta se ha cancelado.';
				                   |tr = 'Fiş yazdırılırken 
				                   |bir hata oluştu: ""%ErrorDescription%"". 
				                   |Kartla işlem yapılamadı.';
				                   |it = 'Si è verificato un errore durante la stampa
				                   |dello scontrino: ""%ErrorDescription%""."
"L''operazione con carta è stata annullata.';
				                   |de = 'Beim Drucken
				                   |eines Belegs ist ein Fehler aufgetreten: ""%ErrorDescription%"".
				                   |Die Bedienung mit der Karte wurde abgebrochen.'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescriptionFR);
				CommonClientServer.MessageToUser(MessageText);
			Else
				MessageText = NStr("en = 'Operation is performed successfully.'; ru = 'Операция выполнена успешно.';pl = 'Operacja została wykonana pomyślnie.';es_ES = 'Operación se ha realizado con éxito.';es_CO = 'Operación se ha realizado con éxito.';tr = 'İşlem başarıyla yapıldı.';it = 'Operazione eseguita con successo.';de = 'Die Operation wurde erfolgreich ausgeführt.'");
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	EquipmentManagerClient.DisablePOSTerminal(UUID, Parameters);
	
EndProcedure

&AtClient
Procedure PayByPaymentCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"         , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"               , "AuthorizeSales");
	Context.Insert("SpecifyAdditionalInformation" , True);

	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);

EndProcedure

&AtClient
Procedure ReturnPaymentByCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeRefund");
	Context.Insert("SpecifyAdditionalInformation" , True);
	Context.Insert("SpecifyRefNo"                 , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure CancelPaymentByCard(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeVoid");
	Context.Insert("SpecifyAdditionalInformation" , True);
	Context.Insert("WithoutReturnedParameters"    , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure RunTotalsRevision(Command)
	
	ClearMessages();
	
	EquipmentManagerClient.RunTotalsOnPOSTerminalRevision(UUID);
	
EndProcedure

&AtClient
Procedure RunPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"  , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"       , "AuthorizePreSales");
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure FinishPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"           , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeCompletion");
	Context.Insert("WithoutReturnedParameters"    , "WithoutReturnedParameters"); 
	Context.Insert("SpecifyAdditionalInformation" , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure CancelPreauthorization(Command)
	
	ClearMessages();
	
	Context = New Structure;
	Context.Insert("DataProcessorAlert"          , "ExecuteOperationByPaymentCardEnd");
	Context.Insert("OperationKind"                , "AuthorizeVoidPreSales");
	Context.Insert("WithoutReturnedParameters"    , "WithoutReturnedParameters");
	Context.Insert("SpecifyAdditionalInformation" , True);
	NotifyDescription = New NotifyDescription("PreliminaryOperationAuthorizationEnd", ThisObject, Context);
	EquipmentManagerClient.StartEnablePOSTerminal(NotifyDescription, UUID);
	
EndProcedure

&AtClient
Procedure PrintLastSlipReceiptEnd(DeviceIdentifier, Parameters) Export
	
	ErrorDescription = "";
	
	// FR device connection
	ResultFR = EquipmentManagerClient.ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	
	If ResultFR Then
		
		If Not IsBlankString(glPeripherals.LastSlipReceipt) Then
			InputParameters = New Array();
			InputParameters.Add(glPeripherals.LastSlipReceipt);
			Output_Parameters = Undefined;
			
			ResultFR = EquipmentManagerClient.RunCommand(DeviceIdentifier, "PrintText", InputParameters, Output_Parameters);
			If Not ResultFR Then
				MessageText = NStr("en = 'When document printing there is error: ""%ErrorDescription%.""'; ru = 'При печати документа произошла ошибка: ""%ErrorDescription%"".';pl = 'Podczas drukowania dokumentu wystąpił błąd: ""%ErrorDescription%"".';es_ES = 'Al imprimir el documento, ha salido un error: ""%ErrorDescription%.""';es_CO = 'Al imprimir el documento, ha salido un error: ""%ErrorDescription%.""';tr = 'Belge yazdırılırken hata oluştu: ""%ErrorDescription%""';it = 'Durante la stampa di documenti c''è un errore: ""%ErrorDescription%.""';de = 'Beim Drucken eines Dokuments tritt ein Fehler auf: ""%ErrorDescription%.""'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
				CommonClientServer.MessageToUser(MessageText);
			EndIf;
		Else
			MessageText = NStr("en = 'There is no last sales slip.'; ru = 'Отсутствует последний кассовый чек.';pl = 'Brak ostatniego paragonu fiskalnego.';es_ES = 'No hay la última nómina.';es_CO = 'No hay la última nómina.';tr = 'Son satışın fişi yok.';it = 'Non c''è l''ultimo scontrino.';de = 'Es gibt keinen letzten Verkaufsbeleg.'");
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		// FR device disconnect
		EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred while connecting
		                   |the fiscal register: ""%ErrorDescription%.""'; 
		                   |ru = 'При подключении фискального регистратора
		                   |произошла ошибка: ""%ErrorDescription%"".';
		                   |pl = 'Wystąpił błąd podczas podłączenia
		                   |rejestratora fiskalnego: ""%ErrorDescription%.""';
		                   |es_ES = 'Ha ocurrido un error al conectar
		                   |el registro fiscal: ""%ErrorDescription%.""';
		                   |es_CO = 'Ha ocurrido un error al conectar
		                   |el registro fiscal: ""%ErrorDescription%.""';
		                   |tr = 'Mali kayıt bağlanırken
		                   |hata oluştu: ""%ErrorDescription%""';
		                   |it = 'Si è verificato un errore durante la connessione"
"al registratore fiscale: ""%ErrorDescription%"".';
		                   |de = 'Beim Verbinden
		                   |des Steuerregisters ist ein Fehler aufgetreten: ""%ErrorDescription%.""'");
		MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

&AtClient
Procedure PrintLastSlipReceipt(Command)
	
	ClearMessages();
	
	NotifyDescription = New NotifyDescription("PrintLastSlipReceiptEnd", ThisObject, Parameters);
	EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
			NStr("en = 'Select a fiscal data recorder to print POS receipts.'; ru = 'Выберите фискальный регистратор для печати эквайринговых чеков';pl = 'Wybierz rejestrator fiskalny, w celu wydruku pokwitowania z terminala POS.';es_ES = 'Seleccionar un registrador de datos fiscal para imprimir los recibos del TPV.';es_CO = 'Seleccionar un registrador de datos fiscal para imprimir los recibos del TPV.';tr = 'POS fişlerini yazdırmak için mali kaydediciyi seçin.';it = 'Selezionare un registrare fiscale per la stampa delle ricevute POS';de = 'Wählen Sie einen Fiskaldatenschreiber, um Kassenbons zu drucken.'"), 
			NStr("en = 'Fiscal data recorder for printing acquiring receipts is not connected.'; ru = 'Фискальный регистратор для печати эквайринговых чеков не подключен.';pl = 'Rejestrator fiskalny do drukowania potwierdzeń płatności kartą nie jest podłączony.';es_ES = 'Registrador de datos fiscal para imprimir los recibos de adquisición no está conectado.';es_CO = 'Registrador de datos fiscal para imprimir los recibos de adquisición no está conectado.';tr = 'Alınan fişlerin yazdırılması için mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale per la stampa e acquisizione di ricevute non è connesso.';de = 'Fiskaldatenschreiber zum Drucken von Kassenbons ist nicht verbunden.'"));
			
EndProcedure

#EndRegion