
#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, 
			SupporTypesVO, ErrorDescription) Then
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

	EquipmentManagerClient.DisableEquipmentByType(UUID, 
	 	SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			                  
			// Open the matching templates.
			ClearMessages();
			If Parameter[1][3] = Undefined
				OR Parameter[1][3].Count() = 0 Then
				CommonClientServer.MessageToUser(NStr("en = 'It was not succeeded to read fields. 
				                                         |Perhaps, template has been configured incorrectly.'; 
				                                         |ru = 'Не удалось прочитать поля. 
				                                         |Возможно, шаблон настроен неверно.';
				                                         |pl = 'Nie udało się odczytać pól. 
				                                         |Możliwe, że szablon został nieprawidłowo skonfigurowany.';
				                                         |es_ES = 'No se ha podido leer los campos. 
				                                         |Probablemente, el modelo se haya configurado de forma incorrecta.';
				                                         |es_CO = 'No se ha podido leer los campos. 
				                                         |Probablemente, el modelo se haya configurado de forma incorrecta.';
				                                         |tr = 'Alanlar okunamadı. 
				                                         | Şablon yanlış yapılandırılmış olabilir.';
				                                         |it = 'Impossibile leggere i campi.
				                                         |Forse il modello non è configurato correttamente.';
				                                         |de = 'Es ist nicht gelungen, Felder zu lesen.
				                                         |Vielleicht wurde die Vorlage falsch konfiguriert.'"));
			Else
				TemplateFound = False;
				For Each curTemplate In Parameter[1][3] Do
					TemplateFound = True;
					OpenForm("Catalog.MagneticCardsTemplates.ObjectForm", New Structure("Key", curTemplate.Pattern));
				EndDo;
				If Not TemplateFound Then
					CommonClientServer.MessageToUser(NStr("en = 'Code does not match this template. 
					                                         |Perhaps, template has been configured incorrectly.'; 
					                                         |ru = 'Код не соответствует данному шаблону. 
					                                         |Возможно, шаблон настроен неверно.';
					                                         |pl = 'Kod nie jest zgodny z tym szablonem
					                                         |Możliwe, że szablon został nieprawidłowo skonfigurowany.';
					                                         |es_ES = 'Código no coincide con este modelo. 
					                                         |Probablemente, el modelo se haya configurado de forma incorrecta.';
					                                         |es_CO = 'Código no coincide con este modelo. 
					                                         |Probablemente, el modelo se haya configurado de forma incorrecta.';
					                                         |tr = 'Kod bu şablonla eşleşmiyor. 
					                                         |Şablon yanlış yapılandırılmış olabilir.';
					                                         |it = 'Il codice non corrisponde a questo modello. 
					                                         |Forse il modello non è stato configurato correttamente.';
					                                         |de = 'Code stimmt nicht mit dieser Vorlage überein.
					                                         |Vielleicht wurde die Vorlage falsch konfiguriert.'"));
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

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	NativeLanguagesSupportServer.OnCreateAtServer(ThisObject);
	
EndProcedure

#EndRegion
