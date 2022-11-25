
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;

	ListOfCardTypes = Undefined;

	tempAmount = 0;
	If Parameters.Property("Amount", tempAmount)
	   AND tempAmount > 0 Then
		Amount = tempAmount;
	Else
		Amount = 0;
	EndIf;

	tempTimeLimit = 0;
	If Parameters.Property("LimitAmount", tempTimeLimit)
	   AND tempTimeLimit > 0 Then
		Items.Amount.MaxValue = tempTimeLimit;
	Else
		Items.Amount.MaxValue = Undefined;
	EndIf;
	
	If Parameters.Property("AmountEditingProhibition") Then
		Items.Amount.ReadOnly = Parameters.AmountEditingProhibition;
	EndIf;
	
	If Parameters.Property("ListOfCardTypes", ListOfCardTypes)
	   AND TypeOf(ListOfCardTypes) = Type("ValueList")
	   AND ListOfCardTypes. Count() > 0 Then
		For Each ListRow In ListOfCardTypes Do
			Items.CardType.ChoiceList.Add(ListRow.Value, ListRow.Presentation);
		EndDo;
		Items.CardType.Visible = True;
	EndIf;
	
	Items.CardNumber.Visible  = False;
	Items.CardNumber.ReadOnly = True;
	Items.CardNumber.TextEdit = False;

	If Parameters.Property("ShowCardNumber", ShowCardNumber) Then
		If ShowCardNumber Then
			Items.CardNumber.Visible  = True;
			Items.CardNumber.ReadOnly = False;
			Items.CardNumber.TextEdit = True;
		EndIf;
	EndIf;
	
	If Items.Amount.ReadOnly Then
		Items.Amount.DefaultControl = False;
		If Items.CardType.Visible AND Items.CardType.ChoiceList.Count() > 1 Then
			Items.CardType.DefaultControl = True;
		ElsIf Items.CardNumber.Visible Then
			Items.CardNumber.DefaultControl = True;
		Else
			Items.RunOperation.DefaultControl = True;
		EndIf;
	EndIf;
	
	If Parameters.Property("SpecifyAdditionalInformation") Then
		SpecifyAdditionalInformation = True;
	EndIf;
	
	TypesOfPeripheral = EquipmentManagerServerReUse.TypesOfPeripheral();
	
	AvailableReadingOnMCR = ShowCardNumber AND (TypesOfPeripheral <> Undefined)
		AND (TypesOfPeripheral.Find(Enums.PeripheralTypes.MagneticCardReader) <> Undefined);
		
	Items.GroupManualDataInput.Visible = SpecifyAdditionalInformation;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If AvailableReadingOnMCR Then
		// Check and connect MC readers.
		SupportedTypesOfPeripherals = New Array();
		SupportedTypesOfPeripherals.Add("MagneticCardReader");
		If EquipmentManagerClient.ConnectEquipmentByType(UUID, SupportedTypesOfPeripherals) Then
			Items.LabelAvailableReadingOnMCR.Visible = True;
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If AvailableReadingOnMCR Then
		// MC reader exit
		SupportedTypesOfPeripherals = New Array();
		SupportedTypesOfPeripherals.Add("MagneticCardReader");
		EquipmentManagerClient.DisableEquipmentByType(UUID, SupportedTypesOfPeripherals);
	EndIf;
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)

	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				CardCodeReceived(Parameter[0], Parameter[0]);
			Else
				CardCodeReceived(Parameter[0], Parameter[1][1]);
			EndIf;
		EndIf;
	EndIf;

EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en = 'An error occurred during the processing of external event from the device:'; ru = 'При обработке внешнего события от устройства произошла ошибка:';pl = 'Wystąpił błąd podczas przetwarzania wydarzenia zewnętrznego z urządzenia:';es_ES = 'Ha ocurrido un error durante el procesamiento del evento externo desde el dispositivo:';es_CO = 'Ha ocurrido un error durante el procesamiento del evento externo desde el dispositivo:';tr = 'Harici olayın cihazdan işlenmesi sırasında bir hata oluştu:';it = 'Si è verificato un errore durante l''elaborazione dell''evento esterno dal dispositivo:';de = 'Bei der Verarbeitung eines externen Ereignisses vom Gerät ist ein Fehler aufgetreten:'")
								+ Chars.LF + ErrorDescription;
			CommonClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure SpecifyAdditionalInformationOnChange(Item)

	Items.GroupManualDataInput.Visible = SpecifyAdditionalInformation;

EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure RunOperation(Command)
	
	Errors = "";
	
	ClearMessages();
	
	If Amount = 0 Then
		Errors = NStr("en = 'Payment cannot be made for the amount equals to zero.'; ru = 'Платеж не может быть осуществлен на нулевую сумму.';pl = 'Płatność nie może zostać zrealizowana, ponieważ kwota wynosi zero.';es_ES = 'Pago no puede realizarse para el importe igual a cero.';es_CO = 'Pago no puede realizarse para el importe igual a cero.';tr = 'Ödeme tutarı sıfır olamaz.';it = 'Il pagamento non può essere effettuato poiché l''importo è uguale a zero.';de = 'Die Zahlung kann nicht für den Betrag gleich Null erfolgen.'");
	EndIf;
	
	If ShowCardNumber AND Not ValueIsFilled(CardNumber) Then
		Errors = Errors + ?(IsBlankString(Errors),"",Chars.LF) + NStr("en = 'Payment cannot be made without a card number.'; ru = 'Платеж не может быть осуществлен без номера карты.';pl = 'Płatność nie może zostać zrealizowana bez numeru karty.';es_ES = 'Pago no puede realizarse sin un número de tarjeta.';es_CO = 'Pago no puede realizarse sin un número de tarjeta.';tr = 'Ödeme, kart numarası olmadan yapılamaz.';it = 'Il pagamento non può essere effettuato senza un numero di carta.';de = 'Die Zahlung kann nicht ohne eine Kartennummer erfolgen.'");
	EndIf;
	
	If IsBlankString(Errors) Then
		If Not SpecifyAdditionalInformation Then
			RefNo = "";
			ReceiptNumber      = "";
		EndIf;
		
		ReturnStructure = New Structure("Amount, CardData, RefNo, ReceiptNumber, CardType, CardNumber",
											Amount, CardData, RefNo, ReceiptNumber, CardType, CardNumber);
		ClearMessages();
		Close(ReturnStructure);
		
	Else
		CommonClientServer.MessageToUser(Errors,,"CardNumber");
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function CardCodeReceived(CardCode, TracksData)

	If TypeOf(TracksData) = Type("Array")
	   AND TracksData.Count() > 1
	   AND TracksData[1] <> Undefined
	   AND Not IsBlankString(TracksData[1]) Then
		CardData = TracksData[1];

		SeparatorPosition = Find(CardData, "=");
		If SeparatorPosition > 16 Then
			CardNumber = Left(CardData, SeparatorPosition - 1);
			Items.CardNumber.Visible = True;
		Else
			CommonClientServer.MessageToUser(NStr("en = 'Invalid card is specified or an error occurred while reading the card.
			                                         |Repeat reading or read another card'; 
			                                         |ru = 'Указана неверная карта или произошла ошибка при считывании карты.
			                                         |Повторите считывание или считайте другую карту';
			                                         |pl = 'Podano nieprawidłową kartę lub wystąpił błąd podczas odczytu karty.
			                                         |Powtórz odczyt lub odczytaj kolejną kartę';
			                                         |es_ES = 'Tarjeta inválida está especificada, o ha ocurrido un error durante la lectura de la tarjeta.
			                                         |Repetir la lectura o leer otra tarjeta';
			                                         |es_CO = 'Tarjeta inválida está especificada, o ha ocurrido un error durante la lectura de la tarjeta.
			                                         |Repetir la lectura o leer otra tarjeta';
			                                         |tr = 'Geçersiz bir kart belirtildi veya kart okunurken bir hata oluştu.
			                                         |Okumayı tekrarlayın veya başka bir kart okuyun';
			                                         |it = 'Carta non valida specificata o si è verificato un errore durante la lettura della carta.
			                                         |Ripetere la lettura o leggere un''altra carta';
			                                         |de = 'Ungültige Karte wird angegeben, oder beim Lesen der Karte ist ein Fehler aufgetreten.
			                                         |Wiederholen Sie das Lesen oder lesen Sie eine andere Karte'"));
		EndIf;
	Else
		CommonClientServer.MessageToUser(NStr("en = 'Invalid card is specified or an error occurred while reading the card.
		                                         |Repeat reading or read another card'; 
		                                         |ru = 'Указана неверная карта или произошла ошибка при считывании карты.
		                                         |Повторите считывание или считайте другую карту';
		                                         |pl = 'Podano nieprawidłową kartę lub wystąpił błąd podczas odczytu karty.
		                                         |Powtórz odczyt lub odczytaj kolejną kartę';
		                                         |es_ES = 'Tarjeta inválida está especificada, o ha ocurrido un error durante la lectura de la tarjeta.
		                                         |Repetir la lectura o leer otra tarjeta';
		                                         |es_CO = 'Tarjeta inválida está especificada, o ha ocurrido un error durante la lectura de la tarjeta.
		                                         |Repetir la lectura o leer otra tarjeta';
		                                         |tr = 'Geçersiz bir kart belirtildi veya kart okunurken bir hata oluştu.
		                                         |Okumayı tekrarlayın veya başka bir kart okuyun';
		                                         |it = 'Carta non valida specificata o si è verificato un errore durante la lettura della carta.
		                                         |Ripetere la lettura o leggere un''altra carta';
		                                         |de = 'Ungültige Karte wird angegeben, oder beim Lesen der Karte ist ein Fehler aufgetreten.
		                                         |Wiederholen Sie das Lesen oder lesen Sie eine andere Karte'"));
	EndIf;
	
	RefreshDataRepresentation();
	
	Return True;
	
EndFunction

&AtClient
Procedure AmountTextEditEnd(Item, Text, ChoiceData, StandardProcessing)

	If Items.Amount.MaxValue <> Undefined
	   AND Items.Amount.MaxValue < Number(Text) Then
	   
		StandardProcessing = False;
		StructureValues = New Structure;
		StructureValues.Insert("Warning", NStr("en = 'Payment amount by card exceeds required non cash payment.
		                                       |Value will be changed to the maximum.'; 
		                                       |ru = 'Сумма оплаты по карте превышает необходимую безналичную оплату.
		                                       |Значение будет изменено на максимально возможное.';
		                                       |pl = 'Kwota płatności kartą przekracza wymaganą płatność bezgotówkową.
		                                       |Wartość zostanie zmieniona na maksymalną.';
		                                       |es_ES = 'Importe de pago con tarjeta excede el pago requerido no en efectivo.
		                                       | Valor se cambiará para el máximo.';
		                                       |es_CO = 'Importe de pago con tarjeta excede el pago requerido no en efectivo.
		                                       | Valor se cambiará para el máximo.';
		                                       |tr = 'Karttaki ödeme tutarı, gereken gayri nakdi ödeme tutarını aşıyor.
		                                       |Değer mümkün olan maksimum değere değiştirilecektir.';
		                                       |it = 'L''importo del pagamento con carta supera il pagamento richiesto non in contanti."
"Il valore sarà cambiato al massimo.';
		                                       |de = 'Der Zahlungsbetrag per Karte übersteigt die erforderliche Barzahlung.
		                                       |Der Wert wird auf das Maximum geändert.'"));
		StructureValues.Insert("Value", Format(Items.Amount.MaxValue, "ND=15; NFD=2; NZ=0; NG=0; NN=1"));
		
		ValueList = New ValueList;
		ValueList.Add(StructureValues);
		ChoiceData = ValueList;
		
	EndIf;

EndProcedure

#EndRegion
