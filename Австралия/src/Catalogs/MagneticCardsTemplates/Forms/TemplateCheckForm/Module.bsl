
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	PatternData = Parameters.PatternData;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, SupporTypesVO, ErrorDescription) Then
			MessageText = NStr("en = 'An error occurred while
			                   |connecting peripherals: ""%ErrorDescription%"".'; 
			                   |ru = 'При подключении оборудования
			                   |произошла ошибка: ""%ErrorDescription%"".';
			                   |pl = 'Wystąpił błąd podczas
			                   |podłączania urządzeń peryferyjnych: ""%ErrorDescription%"".';
			                   |es_ES = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDescription%"".';
			                   |es_CO = 'Ha ocurrido un error al
			                   |conectar los periféricos: ""%ErrorDescription%"".';
			                   |tr = 'Çevre birimleri bağlanırken
			                   |hata oluştu: ""%ErrorDescription%"".';
			                   |it = 'Si è registrato un errore durante
			                   |la connessione periferiche: ""%ErrorDescription%"".';
			                   |de = 'Beim Anschluss von
			                   |Peripheriegeräten ist ein Fehler aufgetreten: ""%ErrorDescription%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure OnClose(Exit)
	// Peripherals
	SupporTypesVO = New Array();
	SupporTypesVO.Add("MagneticCardReader");

	EquipmentManagerClient.DisableEquipmentByType(UUID, SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				TracksData = Parameter[0];
			Else
				TracksData = Parameter[1][1];
			EndIf;
			
			ClearMessages();
			If Not EquipmentManagerClient.CodeCorrespondsToMCTemplate(TracksData, PatternData) Then
				CommonClientServer.MessageToUser(NStr("en = 'The card does not match template.'; ru = 'Карта не соответствует шаблону!';pl = 'Karta nie jest zgodna z szablonem.';es_ES = 'La tarjeta no coincide con el modelo.';es_CO = 'La tarjeta no coincide con el modelo.';tr = 'Kart şablonla eşleşmiyor.';it = 'La carta non corrisponde con il modello!';de = 'Die Karte stimmt nicht mit der Vorlage überein.'"));
				Return;
			EndIf;
			
			// Display encrypted fields
			If Parameter[1][3] = Undefined
				OR Parameter[1][3].Count() = 0 Then
				CommonClientServer.MessageToUser(NStr("en = 'Failed to identify any field. Maybe, template fields configured incorrectly.'; ru = 'Не удалось распознать ни одного поля. Возможно, поля шаблона настроены неверно.';pl = 'Nie udało się zidentyfikować żadnego pola. Możliwe, że pola szablonu zostały skonfigurowane niepoprawnie.';es_ES = 'Fallado a identificar cualquier campo. Probablemente los campos de modelo se hayan configurado de forma incorrecta.';es_CO = 'Fallado a identificar cualquier campo. Probablemente los campos de modelo se hayan configurado de forma incorrecta.';tr = 'Herhangi bir alan belirlenemedi. Şablon alanları yanlış yapılandırılmış olabilir.';it = 'Impossibile riconoscere alcun campo. I campi del modello potrebbero non essere configurati correttamente.';de = 'Fehler beim Identifizieren eines Feldes. Vielleicht sind Vorlagenfelder falsch konfiguriert.'"));
			Else
				TemplateFound = Undefined;
				For Each curTemplate In Parameter[1][3] Do
					If curTemplate.Pattern = PatternData.Ref Then
						TemplateFound = curTemplate;
					EndIf;
				EndDo;
				If TemplateFound = Undefined Then
					CommonClientServer.MessageToUser(NStr("en = 'The code does not match this template. Maybe, the template is configured incorrectly.'; ru = 'Код не соответствует данному шаблону. Возможно, шаблон настроен неверно.';pl = 'Kod nie jest zgodny z tym szablonem. Możliwe, że szablon jest nieprawidłowo skonfigurowany.';es_ES = 'El código no coincide con el modelo. Probablemente el modelo esté configurado de forma incorrecta.';es_CO = 'El código no coincide con el modelo. Probablemente el modelo esté configurado de forma incorrecta.';tr = 'Kod bu şablonla eşleşmiyor. Şablon yanlış yapılandırılmış olabilir.';it = 'Il codice non corrisponde a questo modello. Forse il modello non è configurato correttamente.';de = 'Der Code stimmt nicht mit dieser Vorlage überein. Vielleicht ist die Vorlage falsch konfiguriert.'"));
				Else
					MessageText = NStr("en = 'The card matches the template and contains the following fields:'; ru = 'Карта соответствует шаблону и содержит следующие поля:';pl = 'Karta jest zgodna z szablonem i zawiera następujące pola:';es_ES = 'La tarjeta coincide con el modelo, y contiene los siguientes campos:';es_CO = 'La tarjeta coincide con el modelo, y contiene los siguientes campos:';tr = 'Kart, şablonla eşleşti ve aşağıdaki alanları içerir:';it = 'Carta abbina al modello e contiene questi campi:';de = 'Die Karte entspricht der Vorlage und enthält die folgenden Felder:'")+Chars.LF+Chars.LF;
					Iterator = 1;
					For Each curField In TemplateFound.TracksData Do
						MessageText = MessageText + String(Iterator)+". "+?(ValueIsFilled(curField.Field), String(curField.Field), "")+" = "+String(curField.FieldValue)+Chars.LF;
						Iterator = Iterator + 1;
					EndDo;
					ShowMessageBox(,MessageText, , NStr("en = 'Card code decryption result'; ru = 'Результат расшифровки кода карты';pl = 'Odszyfrowanie kodu karty';es_ES = 'Resultado de la descodificación del código de la tarjeta';es_CO = 'Resultado de la descodificación del código de la tarjeta';tr = 'Kart kodu şifre çözme sonucu';it = 'Risultato della decodificazione del codice della carta';de = 'Kartencode-Entschlüsselungsergebnis'"));
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	// End Peripherals
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