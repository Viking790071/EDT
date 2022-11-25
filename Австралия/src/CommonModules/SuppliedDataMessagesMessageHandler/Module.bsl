#Region Public

// Schedule data import correspondent to the descriptor.
//
// Parameters:
//   Descriptor - XDTODataObject - Descriptor.
//
Procedure ScheduleDataImport(Val Descriptor) Export
	Var XMLDescriptor, MethodParameters;
	
	If Descriptor.RecommendedUpdateDate = Undefined Then
		Descriptor.RecommendedUpdateDate = CurrentUniversalDate();
	EndIf;
	
	XMLDescriptor = SerializeXDTO(Descriptor);
	
	MethodParameters = New Array;
	MethodParameters.Add(XMLDescriptor);

	JobParameters = New Structure;
	JobParameters.Insert("MethodName"    , "SuppliedDataMessagesMessageHandler.ImportData");
	JobParameters.Insert("Parameters"    , MethodParameters);
	JobParameters.Insert("DataArea", -1);
	JobParameters.Insert("ScheduledStartTime", Descriptor.RecommendedUpdateDate);
	JobParameters.Insert("RestartCountOnFailure", 3);
	
	SetPrivilegedMode(True);
	JobQueue.AddJob(JobParameters);

EndProcedure

#EndRegion

#Region Private

// Generates the list of handlers that are supported by the current subsystem.
// 
// Parameters:
//  Handlers - ValueTable - see the field structure in MessageExchange.NewMessageHandlerTable.
// 
Procedure GetMessageChannelHandlers(Val Handlers) Export
	
	AddMessageChannelHandler("SuppliedData\Update", SuppliedDataMessagesMessageHandler, Handlers);
	
EndProcedure

// Processes message body from the channel according to the algorithm of the current message channel.
//
// Parameters:
//  MessageChannel - String - an ID of a message channel used to receive the message.
//  MessageBody - Arbitrary - the body of the message received from the channel to be processed.
//  Sender - ExchangePlanRef.MessageExchange - the endpoint that is the sender of the message.
//
Procedure ProcessMessage(Val MessagesChannel, Val MessageBody, Val Sender) Export
	
	Try
		Descriptor = DeserializeXDTO(MessageBody);
		
		If MessagesChannel = "SuppliedData\Update" Then
			
			HandleNewDescriptor(Descriptor);
			
		EndIf;
	Except
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка обработки сообщения'; en = 'Supplied data.Message processing error'; pl = 'Dostarczone dane.Błąd przetwarzania komunikatów';es_ES = 'Datos proporcionado.Error de procesamiento de mensajes';es_CO = 'Datos proporcionado.Error de procesamiento de mensajes';tr = 'Sağlanan veri. Mesaj işleme hatası';it = 'Dati forniti. Errore nell''elaborazione messaggi';de = 'Gelieferte Daten. Nachrichtenverarbeitungsfehler'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, SuppliedData.GetDataDescription(Descriptor) + Chars.LF + DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// Processes new data. Is called from ProcessMessage and from SuppliedData.ImportAndProcessData.
//
// Parameters:
//  Descriptor - XDTODataObject Descriptor.
Procedure HandleNewDescriptor(Val Descriptor) Export
	
	Import = False;
	RecordSet = InformationRegisters.SuppliedDataRequiringProcessing.CreateRecordSet();
	RecordSet.Filter.FileID.Set(Descriptor.FileGUID);
	
	For each Handler In GetHandlers(Descriptor.DataType) Do
		
		ImportHandler = False;
		
		Handler.Handler.NewDataAvailable(Descriptor, ImportHandler);
		
		If ImportHandler Then
			RawData = RecordSet.Add();
			RawData.FileID = Descriptor.FileGUID;
			RawData.HandlerCode = Handler.HandlerCode;
			Import = True;
		EndIf;
		
	EndDo; 
	
	If Import Then
		SetPrivilegedMode(True);
		RecordSet.Write();
		SetPrivilegedMode(False);
		
		ScheduleDataImport(Descriptor);
	EndIf;
	
	WriteLogEvent(NStr("ru = 'Поставляемые данные.Доступны новые данные'; en = 'Supplied data.New data is available'; pl = 'Dostarczone dane. Dostępne są nowe dane';es_ES = 'Datos proporcionado.Nuevos datos están disponibles';es_CO = 'Datos proporcionado.Nuevos datos están disponibles';tr = 'Sağlanan veri. Yeni veri mevcut';it = 'Dati forniti. Nuovi dati disponibili';de = 'Gelieferte Daten. Neue Daten sind verfügbar'", 
		CommonClientServer.DefaultLanguageCode()), 
		EventLogLevel.Information, ,
		, ?(Import, NStr("ru = 'В очередь добавлено задание на загрузку.'; en = 'Import job is added to the queue.'; pl = 'Do kolejki dodano zadanie importu.';es_ES = 'Tarea de importación se ha añadido a la cola.';es_CO = 'Tarea de importación se ha añadido a la cola.';tr = 'İçe aktarma işi kuyruğa eklendi.';it = 'Task di importazione aggiunto alla coda.';de = 'Der Importjob wurde zur Warteschlange hinzugefügt.'"), NStr("ru = 'Загрузка данных не требуется.'; en = 'Data import is not required.'; pl = 'Import danych nie jest wymagany.';es_ES = 'Importación de datos no está requerida.';es_CO = 'Importación de datos no está requerida.';tr = 'Veri içe aktarımı gerekmez.';it = 'L''importazione dei dati non è necessaria.';de = 'Der Datenimport ist nicht erforderlich.'"))
		+ Chars.LF + SuppliedData.GetDataDescription(Descriptor));

EndProcedure

// Import data correspondent to the descriptor .
//
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//
// Import data correspondent to the descriptor .
//
// Parameters:
//   Descriptor - XDTODataObject Descriptor.
//
Procedure ImportData(Val XMLDescriptor) Export
	Var Descriptor, ExportFileName;
	
	Try
		Descriptor = DeserializeXDTO(XMLDescriptor);
	Except
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка работы с XML'; en = 'Supplied data.Work with XML error'; pl = 'Dostarczone dane. Podczas pracy z XML wystąpił błąd';es_ES = 'Datos proporcionados.Ha ocurrido un error al trabajar con XML';es_CO = 'Datos proporcionados.Ha ocurrido un error al trabajar con XML';tr = 'Sağlanan veri. XML ile çalışırken bir hata oluştu';it = 'Dati forniti. Errore nella lavorazione con XML';de = 'Gelieferte Daten. Beim Arbeiten mit XML ist ein Fehler aufgetreten'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ XMLDescriptor);
		Return;
	EndTry;

	WriteLogEvent(NStr("ru = 'Поставляемые данные.Загрузка данных'; en = 'Supplied data.Data import'; pl = 'Dostarczone dane. Import danych';es_ES = 'Datos proporcionado. Importación de datos';es_CO = 'Datos proporcionado. Importación de datos';tr = 'Sağlanan veri. Veri içe aktarma';it = 'Dati forniti. Importazione dati';de = 'Gelieferte Daten. Daten importieren'", 
		CommonClientServer.DefaultLanguageCode()), 
		EventLogLevel.Information, ,
		, NStr("ru = 'Загрузка начата'; en = 'Import started'; pl = 'Import został rozpoczęty';es_ES = 'Se ha iniciado la importación';es_CO = 'Se ha iniciado la importación';tr = 'İçe aktarım başladı';it = 'Importazione avviata';de = 'Der Import wird gestartet'") + Chars.LF + SuppliedData.GetDataDescription(Descriptor));

	If ValueIsFilled(Descriptor.FileGUID) Then
		ExportFileName = GetFileFromStorage(Descriptor);
	
		If ExportFileName = Undefined Then
			WriteLogEvent(NStr("ru = 'Поставляемые данные.Загрузка данных'; en = 'Supplied data.Data import'; pl = 'Dostarczone dane. Import danych';es_ES = 'Datos proporcionado. Importación de datos';es_CO = 'Datos proporcionado. Importación de datos';tr = 'Sağlanan veri. Veri içe aktarma';it = 'Dati forniti. Importazione dati';de = 'Gelieferte Daten. Daten importieren'", 
				CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Information, ,
				, NStr("ru = 'Файл не может быть загружен'; en = 'The file can not be imported'; pl = 'Plik nie może zostać zaimportowany';es_ES = 'El archivo no puede importarse';es_CO = 'El archivo no puede importarse';tr = 'Dosya içe aktarılamıyor';it = 'Il file non può essere importato';de = 'Die Datei kann nicht importiert werden'") + Chars.LF 
				+ SuppliedData.GetDataDescription(Descriptor));
			Return;
		EndIf;
	EndIf;
	
	WriteLogEvent(NStr("ru = 'Поставляемые данные.Загрузка данных'; en = 'Supplied data.Data import'; pl = 'Dostarczone dane. Import danych';es_ES = 'Datos proporcionado. Importación de datos';es_CO = 'Datos proporcionado. Importación de datos';tr = 'Sağlanan veri. Veri içe aktarma';it = 'Dati forniti. Importazione dati';de = 'Gelieferte Daten. Daten importieren'", 
		CommonClientServer.DefaultLanguageCode()), 
		EventLogLevel.Note, ,
		, NStr("ru = 'Загрузка успешно выполнена'; en = 'Load executed successfully'; pl = 'Import zakończony pomyślnie';es_ES = 'Importación se ha finalizado con éxito';es_CO = 'Importación se ha finalizado con éxito';tr = 'İçe aktarım başarıyla tamamlandı';it = 'Caricamento avvenuto con successo';de = 'Der Import wurde erfolgreich abgeschlossen'") + Chars.LF + SuppliedData.GetDataDescription(Descriptor));

	// InformationRegister.RequireProcessingSuppliedData is used in that case if the loop was 
	// interrupted by rebooting the server.
	// In this case the only way to keep information about emission handlers (if there are more than 1) 
	// quickly record them in the specified register.
	RawDataSet = InformationRegisters.SuppliedDataRequiringProcessing.CreateRecordSet();
	RawDataSet.Filter.FileID.Set(Descriptor.FileGUID);
	RawDataSet.Read();
	HadErrors = False;
	
	For each Handler In GetHandlers(Descriptor.DataType) Do
		RecordFound = False;
		For each RawDataRecord In RawDataSet Do
			If RawDataRecord.HandlerCode = Handler.HandlerCode Then
				RecordFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not RecordFound Then 
			Continue;
		EndIf;
			
		Try
			Handler.Handler.ProcessNewData(Descriptor, ExportFileName);
			RawDataSet.Delete(RawDataRecord);
			RawDataSet.Write();			
		Except
			WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка обработки'; en = 'Supplied data.Processing error'; pl = 'Dostarczone dane. Błąd przetwarzania';es_ES = 'Datos proporcionados. Error del procesador de datos';es_CO = 'Datos proporcionados. Error del procesador de datos';tr = 'Sağlanan veri. Veri işlemcisi hatası';it = 'Dati forniti. Errore di elaborazione';de = 'Gelieferte Daten. Datenverarbeitungsfehler'", 
				CommonClientServer.DefaultLanguageCode()), 
				EventLogLevel.Error, ,
				, DetailErrorDescription(ErrorInfo())
				+ Chars.LF + SuppliedData.GetDataDescription(Descriptor)
				+ Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Код обработчика: %1'; en = 'Handler code: %1'; pl = 'Kod obsługi: %1';es_ES = 'Código del manipulador: %1';es_CO = 'Código del manipulador: %1';tr = 'İşleyici kodu: %1';it = 'Codice del gestore: %1';de = 'Handlercode: %1'"), Handler.HandlerCode));
				
			RawDataRecord.AttemptCount = RawDataRecord.AttemptCount + 1;
			If RawDataRecord.AttemptCount > 3 Then
				NotifyAboutProcessingCancellation(Handler, Descriptor);
				RawDataSet.Delete(RawDataRecord);
			Else
				HadErrors = True;
			EndIf;
			RawDataSet.Write();			
			
		EndTry;
	EndDo; 
	
	If ExportFileName <> Undefined Then
		
		TemporaryFile = New File(ExportFileName);
		
		If TemporaryFile.Exist() Then
			
			Try
				
				TemporaryFile.SetReadOnly(False);
				DeleteFiles(ExportFileName);
				
			Except
				
				WriteLogEvent(NStr("ru = 'Поставляемые данные.Загрузка данных'; en = 'Supplied data.Data import'; pl = 'Dostarczone dane. Import danych';es_ES = 'Datos proporcionado. Importación de datos';es_CO = 'Datos proporcionado. Importación de datos';tr = 'Sağlanan veri. Veri içe aktarma';it = 'Dati forniti. Importazione dati';de = 'Gelieferte Daten. Daten importieren'", CommonClientServer.DefaultLanguageCode()), 
					EventLogLevel.Error, , , DetailErrorDescription(ErrorInfo()));
					
			EndTry;
			
		EndIf;
		
	EndIf;
	
	If TransactionActive() Then
			
		While TransactionActive() Do
				
			RollbackTransaction();
				
		EndDo;
			
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка обработки'; en = 'Supplied data.Processing error'; pl = 'Dostarczone dane. Błąd przetwarzania';es_ES = 'Datos proporcionados. Error del procesador de datos';es_CO = 'Datos proporcionados. Error del procesador de datos';tr = 'Sağlanan veri. Veri işlemcisi hatası';it = 'Dati forniti. Errore di elaborazione';de = 'Gelieferte Daten. Datenverarbeitungsfehler'", 
			CommonClientServer.DefaultLanguageCode()),
			EventLogLevel.Error, 
			,
			, 
			NStr("ru = 'По завершении выполнения обработчика не была закрыта транзакция'; en = 'Upon completion of handler execution Transaction was not closed when the handler finished'; pl = 'Po zakończeniu wykonywania obsługi transakcji, Transakcja nie została zamknięta';es_ES = 'Al finalizar la ejecución del manipulador Transacción no se ha cerrado cuando se ha finalizado el manipulador';es_CO = 'Al finalizar la ejecución del manipulador Transacción no se ha cerrado cuando se ha finalizado el manipulador';tr = 'İşleyici yürütmesinin tamamlanması üzerine İşleyici işlendiğinde İşlem kapatılmadı';it = 'Alla fine del gestore, la transazione non è stata chiusa';de = 'Nach Abschluss der Ausführung des Handlers wurde die Transaktion beim Beenden des Handlers nicht beendet'")
				 + Chars.LF + SuppliedData.GetDataDescription(Descriptor));
			
	EndIf;
	
	If HadErrors Then
		// Download delayed for 5 minutes.
		Descriptor.RecommendedUpdateDate = CurrentUniversalDate() + 5 * 60;
		ScheduleDataImport(Descriptor);
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка обработки'; en = 'Supplied data.Processing error'; pl = 'Dostarczone dane. Błąd przetwarzania';es_ES = 'Datos proporcionados. Error del procesador de datos';es_CO = 'Datos proporcionados. Error del procesador de datos';tr = 'Sağlanan veri. Veri işlemcisi hatası';it = 'Dati forniti. Errore di elaborazione';de = 'Gelieferte Daten. Datenverarbeitungsfehler'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, , ,
			NStr("ru = 'Обработка данных будет запущена повторно из-за ошибки обработчика.'; en = 'Data processor will be run due to an error handler.'; pl = 'Przetwarzanie danych zostanie uruchomione ponownie z powodu błędu obsługi.';es_ES = 'Procesamiento de datos se reiniciará debido al error del manipulador.';es_CO = 'Procesamiento de datos se reiniciará debido al error del manipulador.';tr = 'Veri işleme, işleyici hatası nedeniyle yeniden başlatılacak.';it = 'L''elaborazione dati verrà riavviata a causa di un errore di gestore.';de = 'Die Datenverarbeitung wird aufgrund eines Handler-Fehlers neu gestartet.'")
			 + Chars.LF + SuppliedData.GetDataDescription(Descriptor));
	Else
		RawDataSet.Clear();
		RawDataSet.Write();
		
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Загрузка данных'; en = 'Supplied data.Data import'; pl = 'Dostarczone dane. Import danych';es_ES = 'Datos proporcionado. Importación de datos';es_CO = 'Datos proporcionado. Importación de datos';tr = 'Sağlanan veri. Veri içe aktarma';it = 'Dati forniti. Importazione dati';de = 'Gelieferte Daten. Daten importieren'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, ,
			, NStr("ru = 'Новые данные обработаны'; en = 'New data is processed'; pl = 'Przetwarzanie nowych danych';es_ES = 'Nuevos datos se ha procesado';es_CO = 'Nuevos datos se ha procesado';tr = 'Yeni veri işlendi';it = 'I nuovi dati vengono elaborati';de = 'Neue Daten werden verarbeitet'") + Chars.LF + SuppliedData.GetDataDescription(Descriptor));

	EndIf;
	
EndProcedure

Procedure DeleteUnprocessedDataInfo(Val Descriptor)
	
	RawDataSet = InformationRegisters.SuppliedDataRequiringProcessing.CreateRecordSet();
	RawDataSet.Filter.FileID.Set(Descriptor.FileGUID);
	RawDataSet.Read();
	
	For each Handler In GetHandlers(Descriptor.DataType) Do
		RecordFound = False;
		
		For each RawDataRecord In RawDataSet Do
			If RawDataRecord.HandlerCode = Handler.HandlerCode Then
				RecordFound = True;
				Break;
			EndIf;
		EndDo; 
		
		If Not RecordFound Then 
			Continue;
		EndIf;
			
		NotifyAboutProcessingCancellation(Handler, Descriptor);
		
	EndDo; 
	RawDataSet.Clear();
	RawDataSet.Write();
	
EndProcedure

Procedure NotifyAboutProcessingCancellation(Val Handler, Val Descriptor)
	
	Try
		Handler.Handler.DataProcessingCanceled(Descriptor);
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Отмена обработки'; en = 'Supplied data.Processing cancel'; pl = 'Dostarczone dane. Anuluj przetwarzanie';es_ES = 'Datos proporcionados. Cancelar el procesador';es_CO = 'Datos proporcionados. Cancelar el procesador';tr = 'Sağlanan veri. İşlem iptali';it = 'Dati forniti. Elaborazione annullata';de = 'Gelieferte Daten. Prozessor abbrechen'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Information, ,
			, SuppliedData.GetDataDescription(Descriptor)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Код обработчика: %1'; en = 'Handler code: %1'; pl = 'Kod obsługi: %1';es_ES = 'Código del manipulador: %1';es_CO = 'Código del manipulador: %1';tr = 'İşleyici kodu: %1';it = 'Codice del gestore: %1';de = 'Handlercode: %1'"), Handler.HandlerCode));
	
	Except
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Отмена обработки'; en = 'Supplied data.Processing cancel'; pl = 'Dostarczone dane. Anuluj przetwarzanie';es_ES = 'Datos proporcionados. Cancelar el procesador';es_CO = 'Datos proporcionados. Cancelar el procesador';tr = 'Sağlanan veri. İşlem iptali';it = 'Dati forniti. Elaborazione annullata';de = 'Gelieferte Daten. Prozessor abbrechen'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Descriptor)
			+ Chars.LF + StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Код обработчика: %1'; en = 'Handler code: %1'; pl = 'Kod obsługi: %1';es_ES = 'Código del manipulador: %1';es_CO = 'Código del manipulador: %1';tr = 'İşleyici kodu: %1';it = 'Codice del gestore: %1';de = 'Handlercode: %1'"), Handler.HandlerCode));
	EndTry;

EndProcedure

Function GetFileFromStorage(Val Descriptor)
	
	Try
		ExportFileName = SaaS.GetFileFromServiceManagerStorage(Descriptor.FileGUID);
	Except
		WriteLogEvent(NStr("ru = 'Поставляемые данные.Ошибка хранилища'; en = 'Supplied data.Storage error'; pl = 'Dostarczone dane. Błąd pamięci';es_ES = 'Datos proporcionados. Error de almacenamiento';es_CO = 'Datos proporcionados. Error de almacenamiento';tr = 'Sağlanan veri. Depolama alanı hatası';it = 'Dati forniti. Errore di archiviazione';de = 'Gelieferte Daten. Speicherfehler'", 
			CommonClientServer.DefaultLanguageCode()), 
			EventLogLevel.Error, ,
			, DetailErrorDescription(ErrorInfo())
			+ Chars.LF + SuppliedData.GetDataDescription(Descriptor));
				
		// Import is deferred for one hour.
		Descriptor.RecommendedUpdateDate = Descriptor.RecommendedUpdateDate + 60 * 60;
		ScheduleDataImport(Descriptor);
		Return Undefined;
	EndTry;
	
	// If the file was replaced or deleted between function restarts, delete the old update plan.
	// 
	If ExportFileName = Undefined Then
		DeleteUnprocessedDataInfo(Descriptor);
	EndIf;
	
	Return ExportFileName;

EndFunction

Function GetHandlers(Val DataKind)
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("DataKind");
	Handlers.Columns.Add("Handler");
	Handlers.Columns.Add("HandlerCode");
	
	SSLSubsystemsIntegration.OnDefineSuppliedDataHandlers(Handlers);
	SuppliedDataOverridable.GetSuppliedDataHandlers(Handlers);
	
	Return Handlers.Copy(New Structure("DataKind", DataKind), "Handler, HandlerCode");
	
EndFunction	

Function SerializeXDTO(Val XDTOObject)
	Record = New XMLWriter;
	Record.SetString();
	XDTOFactory.WriteXML(Record, XDTOObject, , , , XMLTypeAssignment.Explicit);
	Return Record.Close();
EndFunction

Function DeserializeXDTO(Val XMLString)
	Read = New XMLReader;
	Read.SetString(XMLString);
	XDTOObject = XDTOFactory.ReadXML(Read);
	Read.Close();
	Return XDTOObject;
EndFunction

// AUXILIARY PROCEDURES AND FUNCTIONS

Procedure AddMessageChannelHandler(Val Canal, Val ChannelHandler, Val Handlers)
	
	Handler = Handlers.Add();
	Handler.Canal = Canal;
	Handler.Handler = ChannelHandler;
	
EndProcedure

#EndRegion