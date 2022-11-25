
#Region FormCommandsHandlers

&AtClient
Procedure ReportPrintingWithoutBlankingExecute()
	
	Context = New Structure("Action", "PrintXReport");
	NotifyDescription = New NotifyDescription("ReportPrintEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
		NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator fiskalny';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore dati fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"), NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
	
EndProcedure

&AtClient
Procedure ReportPrintingWithBlankingExecute()
	
	Context = New Structure("Action", "PrintZReport");
	NotifyDescription = New NotifyDescription("ReportPrintEnd", ThisObject, Context);
	EquipmentManagerClient.OfferSelectDevice(NotifyDescription, "FiscalRegister",
		NStr("en = 'Select a fiscal data recorder'; ru = 'Выберите фискальный регистратор';pl = 'Wybierz rejestrator fiskalny';es_ES = 'Seleccionar un registrador de datos fiscales';es_CO = 'Seleccionar un registrador de datos fiscales';tr = 'Mali veri kaydediciyi seçin';it = 'Selezionare un registratore dati fiscale';de = 'Wählen Sie einen Steuer Datenschreiber'"), NStr("en = 'Fiscal data recorder is not connected.'; ru = 'Фискальный регистратор не подключен.';pl = 'Rejestrator fiskalny nie jest podłączony.';es_ES = 'Registrador de datos fiscales no está conectado.';es_CO = 'Registrador de datos fiscales no está conectado.';tr = 'Mali veri kaydedici bağlı değil.';it = 'Il registratore dati fiscale non è connesso.';de = 'Der Steuerdatenschreiber ist nicht angeschlossen.'"));
	
EndProcedure

&AtClient
Procedure ReportPrintEnd(DeviceIdentifier, Parameters) Export
	
	If Not Parameters.Property("Action") Then
		Return;
	EndIf;
	
	ErrorDescription = "";
	
	Result = EquipmentManagerClient.ConnectEquipmentByID(UUID, DeviceIdentifier, ErrorDescription);
	If Result Then
		InputParameters  = Undefined;
		Output_Parameters = Undefined;
		Result = EquipmentManagerClient.RunCommand(DeviceIdentifier, Parameters.Action, InputParameters, Output_Parameters);
		
		If Not Result Then
			MessageText = NStr("en = 'An error occurred while getting the report from fiscal register.
			                   |%ErrorDescription%
			                   |Report on fiscal register is not formed.'; 
			                   |ru = 'При снятии отчета на фискальном регистраторе произошла ошибка.
			                   |%ErrorDescription%
			                   |Отчет на фискальном регистраторе не сформирован.';
			                   |pl = 'Wystąpił błąd podczas pobierania sprawozdania z rejestratora fiskalnego.
			                   |%ErrorDescription%
			                   |Sprawozdanie nie zostało utworzone na rejestratorze fiskalnym.';
			                   |es_ES = 'Ha ocurrido un error al obtener el informe desde el registrador fiscal.
			                   |%ErrorDescription%
			                   |Informe sobre el registrador fiscal no se ha formado.';
			                   |es_CO = 'Ha ocurrido un error al obtener el informe desde el registrador fiscal.
			                   |%ErrorDescription%
			                   |Informe sobre el registrador fiscal no se ha formado.';
			                   |tr = 'Rapor mali kaydediciden alınırken bir hata oluştu. Mali kayıtla ilgili 
			                   |%ErrorDescription%
			                   | Raporu oluşturulmadı.';
			                   |it = 'Si è verificato un errore durante il recupero del report dal registro fiscale."
"%ErrorDescription%"
"Il report sul registro fiscale non è stato creato.';
			                   |de = 'Beim Abrufen des Berichts aus dem Fiskalspeicher ist ein Fehler aufgetreten.
			                   |%ErrorDescription%
			                   |Der Bericht über den Fiskalspeicher wird nicht erstellt.'");
				MessageText = StrReplace(MessageText, "%ErrorDescription%", Output_Parameters[1]);
			CommonClientServer.MessageToUser(MessageText);
		EndIf;
		
		EquipmentManagerClient.DisableEquipmentById(UUID, DeviceIdentifier);
		
	Else
		MessageText = NStr("en = 'An error occurred when connecting the device.'; ru = 'При подключении устройства произошла ошибка.';pl = 'Wystąpił błąd podczas podłączania urządzenia.';es_ES = 'Ha ocurrido un error al conectar el dispositivo.';es_CO = 'Ha ocurrido un error al conectar el dispositivo.';tr = 'Cihaz bağlanırken hata oluştu.';it = 'Si è verificato un errore durante il collegamento del dispositivo.';de = 'Beim Verbinden des Geräts ist ein Fehler aufgetreten.'") + Chars.LF + ErrorDescription;
		CommonClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

#EndRegion