#Region Internal

// For internal use only.
Function ThisNode() Export
	
	Return ExchangePlans.MessageExchange.ThisNode();
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Data exchange subsystem event handlers.

// See DataExchangeOverridable.OnDataExport. 
Procedure OnDataExport(StandardProcessing,
								Recipient,
								MessageFileName,
								MessageData,
								TransactionItemsCount,
								LogEventName,
								SentObjectsCount) Export
	
	If TypeOf(Recipient) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	MessageCatalogs = MessagesExchangeCached.GetMessageCatalogs();
	
	StandardProcessing = False;
	
	DataSelectionTable = New ValueTable;
	DataSelectionTable.Columns.Add("Data");
	DataSelectionTable.Columns.Add("Order", New TypeDescription("Number"));
	
	WriteToFile = Not IsBlankString(MessageFileName);
	
	XMLWriter = New XMLWriter;
	
	If WriteToFile Then
		XMLWriter.OpenFile(MessageFileName);
	Else
		XMLWriter.SetString();
	EndIf;
	
	XMLWriter.WriteXMLDeclaration();
	
	// Creating a new message.
	WriteMessage = ExchangePlans.CreateMessageWriter();
	
	WriteMessage.BeginWrite(XMLWriter, Recipient);
	
	// Counting the number of written objects.
	SentObjectsCount = 0;
	
	// Getting changed data selection.
	ChangesSelection = DataExchangeServer.SelectChanges(WriteMessage.Recipient, WriteMessage.MessageNo);
	
	Try
		
		While ChangesSelection.Next() Do
			
			TableRow = DataSelectionTable.Add();
			TableRow.Data = ChangesSelection.Get();
			
			TableRow.Order = 0;
			For Each CatalogMessage In MessageCatalogs Do
				If TypeOf(TableRow.Data) = TypeOf(CatalogMessage.EmptyRef()) Then
					TableRow.Order = TableRow.Data.Code;
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
		DataSelectionTable.Sort("Order Asc");
		
		For Each TableRow In DataSelectionTable Do
			
			SendingMessageNow = False;
			
			For Each CatalogMessage In MessageCatalogs Do
				
				If TypeOf(TableRow.Data) = TypeOf(CatalogMessage.CreateItem()) Then
					SendingMessageNow = True;
					Break;
				EndIf;
				
			EndDo;
			
			If SendingMessageNow Then
				
				TableRow.Data.Code = 0;
				
				// {Event handler: OnSendMessage} Start.
				MessageBody = TableRow.Data.MessageBody.Get();
				
				OnSendMessage(TableRow.Data.Description, MessageBody, TableRow.Data);
				
				TableRow.Data.MessageBody = New ValueStorage(MessageBody);
				// {Event handler: OnSendMessage} End.
				
			EndIf;
			
			If TypeOf(TableRow.Data) = Type("ObjectDeletion") Then
				
				If TypeOf(TableRow.Data.Ref) <> Type("CatalogRef.SystemMessages") Then
					
					TableRow.Data = New ObjectDeletion(Catalogs.SystemMessages.GetRef(
						TableRow.Data.Ref.UUID()));
					
				EndIf;
				
			EndIf;
			
			// Writing data to the message.
			WriteXML(XMLWriter, TableRow.Data);
			
			SentObjectsCount = SentObjectsCount + 1;
			
		EndDo;
		
		// Finishing writing the message.
		WriteMessage.EndWrite();
		MessageData = XMLWriter.Close();
		
	Except
		
		WriteMessage.CancelWrite();
		XMLWriter.Close();
		Raise;
		
	EndTry;
	
EndProcedure

// See DataExchangeOverridable.OnDataImport. 
Procedure OnDataImport(StandardProcessing,
								Sender,
								MessageFileName,
								MessageData,
								TransactionItemsCount,
								LogEventName,
								ReceivedObjectsCount) Export
	
	If TypeOf(Sender) <> Type("ExchangePlanRef.MessageExchange") Then
		Return;
	EndIf;
	
	ModuleSaaS = Undefined;
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleSaaS = Common.CommonModule("SaaS");
	EndIf;
	
	MessageCatalogs = MessagesExchangeCached.GetMessageCatalogs();
	
	StandardProcessing = False;
	
	XMLReader = New XMLReader;
	
	If Not IsBlankString(MessageData) Then
		XMLReader.SetString(MessageData);
	Else
		XMLReader.OpenFile(MessageFileName);
	EndIf;
	
	MessageReader = ExchangePlans.CreateMessageReader();
	MessageReader.BeginRead(XMLReader, AllowedMessageNo.Greater);
	
	BackupParameters = DataExchangeServer.BackupParameters(MessageReader.Sender, MessageReader.ReceivedNo);
	
	DeleteChangesRegistration = Not BackupParameters.BackupRestored;
	
	If DeleteChangesRegistration Then
		
		// Deleting changes registration for the sender node.
		ExchangePlans.DeleteChangeRecords(MessageReader.Sender, MessageReader.ReceivedNo);
		
	EndIf;
	
	// Counting the number of read objects.
	ReceivedObjectsCount = 0;
	
	Try
		
		ExchangeMessageCanBePartiallyReceived = CorrespondentSupportsPartiallyReceivingExchangeMessages(Sender);
		ExchangeMessagePartiallyReceived = False;
		
		// Reading data from the message.
		While CanReadXML(XMLReader) Do
			
			// Reading the next value.
			Data = ReadXML(XMLReader);
			
			ReceivedObjectsCount = ReceivedObjectsCount + 1;
			
			ReceivingMessageNow = False;
			For Each CatalogMessage In MessageCatalogs Do
				If TypeOf(Data) = TypeOf(CatalogMessage.CreateItem()) Then
					ReceivingMessageNow = True;
					Break;
				EndIf;
			EndDo;
			
			If ReceivingMessageNow Then
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only.
				EndIf;
				
				// {Handler: OnReceiveMessage} Start
				MessageBody = Data.MessageBody.Get();
				
				OnReceiveMessage(Data.Description, MessageBody, Data);
				
				Data.MessageBody = New ValueStorage(MessageBody);
				// {Handler: OnReceiveMessage} End
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only.
				EndIf;
				
				Data.SetNewCode();
				Data.Sender = MessageReader.Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("SkipPeriodClosingCheck");
				
			ElsIf TypeOf(Data) = Type("InformationRegisterRecordSet.RecipientSubscriptions") Then
				
				Data.Filter["Recipient"].Value = MessageReader.Sender;
				
				For Each RecordSetRow In Data Do
					
					RecordSetRow.Recipient = MessageReader.Sender;
					
				EndDo;
				
			ElsIf TypeOf(Data) = Type("ObjectDeletion") Then
				
				If TypeOf(Data.Ref) = Type("CatalogRef.SystemMessages") Then
					
					For Each CatalogMessage In MessageCatalogs Do
						
						RefSubstitution = CatalogMessage.GetRef(Data.Ref.UUID());
						If Common.RefExists(RefSubstitution) Then
							
							Data = New ObjectDeletion(RefSubstitution);
							Break;
							
						EndIf;
						
					EndDo;
					
				EndIf;
				
			EndIf;
			
			DataArea = -1;
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Ref = Data.Ref;
				If Not Common.RefExists(Ref) Then
					Continue;
				EndIf;
				If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(Ref.Metadata(), SaaS.AuxiliaryDataSeparator()) Then
					DataArea = Common.ObjectAttributeValue(Data.Ref, SaaS.AuxiliaryDataSeparator());
				EndIf;
				
			Else
				
				If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(Data.Metadata(), SaaS.AuxiliaryDataSeparator()) Then
					DataArea = Data[SaaS.AuxiliaryDataSeparator()];
				EndIf;
				
			EndIf;
			
			MustRestoreSeparation = False;
			If DataArea <> -1 AND NOT ReceivingMessageNow Then
				
				If ModuleSaaS.DataAreaLocked(DataArea) Then
					// Message for a locked area cannot be accepted.
					If ExchangeMessageCanBePartiallyReceived Then
						ExchangeMessagePartiallyReceived = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'Не удалось выполнить обмен сообщениями по причине: область данных %1 заблокирована.'; en = 'Cannot execute message exchange due to: the %1 data area is locked.'; pl = 'Nie udało się wykonać wymiany komunikatów z powodu: obszar danych %1 jest zablokowany.';es_ES = 'No se puede realizar un intercambio de correos electrónicos debido a: el área de datos %1 está bloqueada.';es_CO = 'No se puede realizar un intercambio de correos electrónicos debido a: el área de datos %1 está bloqueada.';tr = 'Aşağıdakiler nedeniyle bir e-posta değişimi yapılamıyor: veri alanı %1 kilitlendi.';it = 'Impossibile eseguire lo scambio di messaggio a causa di: l''area dati %1 è bloccata.';de = 'Der Nachrichtenaustausch konnte aus folgendem Grund nicht ausgeführt werden: Der Datenbereich %1 ist gesperrt.'"),
							DataArea);
					EndIf;
				EndIf;
				
				MustRestoreSeparation = True;
				SaaS.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// In case of conflicting changes, the current infobase takes precedence (with the exception of 
			// incoming ObjectDeletion from messages sent to the correspondent infobase.
			// 
			If TypeOf(Data) <> Type("ObjectDeletion") AND ExchangePlans.IsChangeRecorded(MessageReader.Sender, Data) Then
				If MustRestoreSeparation Then
					SaaS.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = MessageReader.Sender;
			Data.DataExchange.Load = True;
			Data.Write();
			
			If MustRestoreSeparation Then
				SaaS.SetSessionSeparation(False);
			EndIf;
			
		EndDo;
		
		If ExchangeMessagePartiallyReceived Then
			// If the data exchange message contains any rejected messages the sender must keep attempting to 
			// resend them whenever further exchange messages are generated.
			// 
			MessageReader.CancelRead();
		Else
			MessageReader.EndRead();
		EndIf;
		
		DataExchangeServer.OnRestoreFromBackup(BackupParameters);
		
		XMLReader.Close();
		
	Except
		MessageReader.CancelRead();
		XMLReader.Close();
		Raise;
	EndTry;
	
EndProcedure

// See InfobaseUpdateSSL.OnAddUpdateHandlers. 
Procedure OnAddUpdateHandlers(Handlers) Export
	
	Handler = Handlers.Add();
	Handler.Version = "*";
	Handler.SharedData = True;
	Handler.ExclusiveMode = False;
	Handler.Procedure = "MessageExchangeInternal.SetThisEndpointCode";
	
	Handler = Handlers.Add();
	Handler.Version = "3.0.1.78";
	Handler.SharedData = True;
	Handler.ExecutionMode = "Seamless";
	Handler.Procedure = "MessageExchangeInternal.MoveMessageExchangeTransportSettings";
	
EndProcedure

// See BatchObjectModificationOverridable.OnDetermineObjectsWithEditableAttributes. 
Procedure OnDefineObjectsWithEditableAttributes(Objects) Export
	Objects.Insert(Metadata.Catalogs.SystemMessages.FullName(), "AttributesToSkipInBatchProcessing");
EndProcedure

// See ExportImportDataOverridable.OnFillTypesExcludedFromExportImport. 
Procedure OnFillTypesExcludedFromExportImport(Types) Export
	
	CatalogArray = MessagesExchangeCached.GetMessageCatalogs();
	For Each CatalogMessage In CatalogArray Do
		Types.Add(CatalogMessage.EmptyRef().Metadata());
	EndDo;
	
EndProcedure

// See CommonOverridable.OnDefineSupportedInterfaceVersions. 
Procedure OnDefineSupportedInterfaceVersions(Val SupportedVersionStructure) Export
	
	VersionsArray = New Array;
	VersionsArray.Add("2.0.1.6");
	VersionsArray.Add("2.1.1.7");
	VersionsArray.Add("2.1.1.8");
	SupportedVersionStructure.Insert("MessageExchange", VersionsArray);
	
EndProcedure

#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Updating an infobase.

// Sets code for this setpoint if it is not yet set.
// 
Procedure SetThisEndpointCode() Export
	
	If IsBlankString(ThisNodeCode()) Then
		
		ThisEndpoint = ThisNode().GetObject();
		ThisEndpoint.Code = String(New UUID());
		ThisEndpoint.Write();
		
	EndIf;
	
EndProcedure

// Transfers message exchange transport settings to the new register.
//
Procedure MoveMessageExchangeTransportSettings() Export
	
	If Common.DataSeparationEnabled()
		AND Common.SeparatedDataUsageAvailable() Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	TransportSettings.InfobaseNode AS Endpoint,
	|	TransportSettings.WSWebServiceURL AS WebServiceAddress,
	|	TransportSettings.WSUsername AS UserName,
	|	TransportSettings.WSRememberPassword AS RememberPassword
	|FROM
	|	InformationRegister.DeleteExchangeTransportSettings AS TransportSettings
	|		INNER JOIN ExchangePlan.MessageExchange AS MessageExchange
	|		ON (MessageExchange.Ref = TransportSettings.InfobaseNode)
	|WHERE
	|	(CAST(TransportSettings.WSWebServiceURL AS STRING(100))) <> """"");
	
	SettingsTable = Query.Execute().Unload();
	
	BeginTransaction();
	Try
		For Each SettingsString In SettingsTable Do
			RecordSetNew = InformationRegisters.MessageExchangeTransportSettings.CreateRecordSet();
			RecordSetNew.Filter.Endpoint.Set(SettingsString.Endpoint);
			
			SettingsRecord = RecordSetNew.Add();
			FillPropertyValues(SettingsRecord, SettingsString);
			
			RecordSetNew.Write(True);
			
			RecordManagerOld = InformationRegisters.DeleteExchangeTransportSettings.CreateRecordManager();
			RecordManagerOld.InfobaseNode = SettingsString.Endpoint;
			RecordManagerOld.Read();
			
			RecordManagerOld.WSWebServiceURL   = "";
			RecordManagerOld.WSRememberPassword = False;
			RecordManagerOld.WSUsername = "";
			
			RecordManagerOld.Write(True);
		EndDo;
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Handler of a scheduled job used to send and receive system messages.
//
Procedure SendReceiveMessagesByScheduledJob() Export
	
	Common.OnStartExecuteScheduledJob(Metadata.ScheduledJobs.SendReceiveSystemMessages);
	
	SendAndReceiveMessages(False);
	
EndProcedure

// Sends and receives system messages.
//
// Parameters:
//  Cancel - Boolean. A cancellation flag. Appears on errors during operations.
//
Procedure SendAndReceiveMessages(Cancel) Export
	
	SetPrivilegedMode(True);
	
	SendReceiveMessagesViaWebServiceExecute(Cancel);
	
	ProcessSystemMessageQueue();
	
EndProcedure

// For internal use only.
Procedure ProcessSystemMessageQueue(Filter = Undefined) Export

    SetPrivilegedMode(True);

    If SaaS.DataSeparationEnabled() AND SaaS.SeparatedDataUsageAvailable() Then

        WriteLogEvent(ThisSubsystemEventLogMessageText(),
                EventLogLevel.Information,,,
                NStr("ru = 'Обработка очереди сообщений системы запущена из сеанса с установленными
                      |значениями разделителей. Обработка будет производиться только для сообщений,
                      |сохраненных в разделенном справочнике, в элементах со значениями разделителей,
                      |совпадающих со значениями разделителей сеанса.'; 
                      |en = 'Message queue processing was started from the session with specified
                      |separator values. Only system messages
                      |saved in a divided catalog in elements with separator values
                      |matching those of the session will be processed.'; 
                      |pl = 'Przetwarzanie kolejki komunikatów systemu jest uruchomione z sesji z określonymi
                      |wartościami separatorów. Przetwarzanie będzie dokonywane tylko dla komunikatów,
                      |zachowanych w podzielonym katalogu, w elementach z wartościami separatorów,
                      |zgodnych z wartościami separatorów sesji.';
                      |es_ES = 'El procesamiento de la cola de mensajes del sistema se ha iniciado desde la sesión con
                      |los valores establecidos de separadores. Procesamiento se realizará solo para los mensajes
                      |guardados en un directorio dividido, en los artículos cuyos valores del separador 
                      |corresponden a los valores del separador de la sesión.';
                      |es_CO = 'El procesamiento de la cola de mensajes del sistema se ha iniciado desde la sesión con
                      |los valores establecidos de separadores. Procesamiento se realizará solo para los mensajes
                      |guardados en un directorio dividido, en los artículos cuyos valores del separador 
                      |corresponden a los valores del separador de la sesión.';
                      |tr = 'Sistem mesajları sıra veri işlemcisi, oturumda belirlenmiş 
                      |ayırıcı değerleri ile başlatıldı. Veri işleme, yalnızca bölünmüş bir dizinde
                      | kaydedilen mesajlar, ayırma değerlerinin oturumun ayırıcı değerleriyle eşleştiği öğeler 
                      |için yapılacaktır.';
                      |it = 'L''elaborazione di messaggi in coda è stata avviata dalla sessione con valori
                      |di separatori specificati. Solo i messaggi
                      |di sistema salvati in un catalogo separato in elementi con valori
                      |di separatore che corrispondono a quelli della sessione saranno processati.';
                      |de = 'Die Bearbeitung der Warteschlange für Systemnachrichten wird aus der Sitzung heraus mit den eingestellten
                      |Werten von Trennzeichen gestartet. Die Bearbeitung wird nur für Nachrichten durchgeführt,
                      |die in einem geteilten Verzeichnis in Elementen mit Trennzeichenwerten gespeichert sind,
                      |die mit den Werten der Sitzungs-Trennzeichen übereinstimmen.'"));

        ProcessMessagesInSharedData = False;

    Else

        ProcessMessagesInSharedData = True;

    EndIf;

    ModuleSaaS = Undefined;
    If SaaSCached.IsSeparatedConfiguration() Then
        ModuleSaaS = Common.CommonModule("SaaS");
    EndIf;

    MessageHandlers = MessageHandlers();

    QueryText = "";
    MessageCatalogs = MessagesExchangeCached.GetMessageCatalogs();
    For Each CatalogMessage In MessageCatalogs Do

        FullCatalogName = CatalogMessage.EmptyRef().Metadata().FullName();
        IsSharedCatalog = Not SaaSCached.IsSeparatedConfiguration()
			OR Not SaaS.IsSeparatedMetadataObject(FullCatalogName, SaaS.AuxiliaryDataSeparator());

        If IsSharedCatalog AND Not ProcessMessagesInSharedData Then
            Continue;
        EndIf;

        If Not IsBlankString(QueryText) Then

            QueryText = QueryText + "
            |
            |UNION ALL
            |"

        EndIf;

        Subquery =  StringFunctionsClientServer.SubstituteParametersToString(
            "SELECT
            |    MessagesTable.DataAreaAuxiliaryData AS DataArea,
            |    MessagesTable.Ref AS Ref,
            |    MessagesTable.Code AS Code,
            |    MessagesTable.Sender.Locked AS EndpointLocked
            |FROM
            |    %1 AS MessagesTable
            |WHERE
            |    MessagesTable.Recipient = &Recipient
            |    AND (NOT MessagesTable.Locked)
            |    [Filter]"
            , FullCatalogName);

        If IsSharedCatalog Then
            Subquery = StrReplace(Subquery, "MessagesTable.DataAreaAuxiliaryData AS DataArea", "-1 AS DataArea");
        EndIf;

        QueryText = QueryText + Subquery;

    EndDo;

    FIlterRow = ?(Filter = Undefined, "", "AND MessagesTable.Ref IN(&Filter)");

    QueryText = StrReplace(QueryText, "[Filter]", FIlterRow);

    QueryText = "SELECT TOP 100
    |    NestedQuery.DataArea,
    |    NestedQuery.Ref,
    |    NestedQuery.Code,
    |    NestedQuery.EndpointLocked
    |FROM
    |    (" +  QueryText + ") AS NestedQuery
    |
    |ORDER BY
    |    Code";

    Query = New Query;
    Query.SetParameter("Recipient", ThisNode());
    Query.SetParameter("Filter", Filter);
    Query.Text = QueryText;

    QueryResult = SaaS.ExecuteQueryOutsideTransaction(Query);

    Selection = QueryResult.Select();

    While Selection.Next() Do

        Try
            LockDataForEdit(Selection.Ref);
        Except
            Continue; // moving on
        EndTry;

        // Checking for data area lock.
        If ModuleSaaS <> Undefined
                AND Selection.DataArea <> -1
                AND ModuleSaaS.DataAreaLocked(Selection.DataArea) Then

            // The area is locked, proceeding to the next record.
            UnlockDataForEdit(Selection.Ref);
            Continue;
        EndIf;

        Try

            BeginTransaction();
            Try
                MessageObject = Selection.Ref.GetObject();
                AttemptsCounter = MessageObject.MessageProccesAttemptCount + 1;
                If AttemptsCounter > 3 Then
                    If NOT ValueIsFilled(MessageObject.DetailedErrorPresentation) Then
                        MessageObject.DetailedErrorPresentation = NStr("ru = 'Исчерпано количество попыток обработки сообщения.'; en = 'Number of attempts to process the message is exceeded.'; pl = 'Została wyczerpana ilość prób przetwarzania komunikatu.';es_ES = 'Número de intentos para procesar el mensaje está superado.';es_CO = 'Número de intentos para procesar el mensaje está superado.';tr = 'İletiyi işlemek için deneme sayısı limitine ulaşıldı.';it = 'Superato numero di tentativi consentiti di elaborare il messaggio.';de = 'Die Anzahl der Versuche, eine Nachricht zu verarbeiten, ist erschöpft.'");
                    EndIf;
                    MessageObject.Locked = True;
                Else
                    MessageObject.MessageProccesAttemptCount = AttemptsCounter;
                EndIf;
                SaaS.WriteAuxiliaryData(MessageObject);
                MessageObject.Read();
                CommitTransaction();
            Except
                RollbackTransaction();
                Raise;
            EndTry;

            If MessageObject.Locked Then
                UnlockDataForEdit(Selection.Ref);

                WriteLogEvent(ThisSubsystemEventLogMessageText(),
                        EventLogLevel.Error,,,
                        StringFunctionsClientServer.SubstituteParametersToString(
                            NStr("ru = 'Исчерпано количество попыток обработки сообщения %1'; en = 'Number of attempts to process message %1 is exceeded'; pl = 'Została wyczerpana ilość prób przetwarzania komunikatu %1';es_ES = 'Número de intentos para procesar el mensaje está superado %1';es_CO = 'Número de intentos para procesar el mensaje está superado %1';tr = '%1İletiyi işlemek için deneme sayısı limitine ulaşıldı.';it = 'Superato numero di tentativi consentiti di elaborare il messaggio %1';de = 'Die Anzahl der Versuche, eine Nachricht %1 zu verarbeiten, ist erschöpft'"),
                            MessageObject.Description));

                Continue;
            EndIf;

            MessageTitle = New Structure("MessagesChannel, Sender", MessageObject.Description, MessageObject.Sender);

            FoundRows = MessageHandlers.FindRows(New Structure("Canal", MessageTitle.MessagesChannel));

            MessageProcessed = True;

            // Processing message
            Try

                If Selection.EndpointLocked Then
                    MessageObject.Locked = True;
                    Raise NStr("ru = 'Попытка обработки сообщения, полученного от заблокированной конечной точки.'; en = 'Attempting to process a message received from a locked endpoint.'; pl = 'Próba przetworzenia wiadomości otrzymanej z zablokowanego punktu końcowego.';es_ES = 'Intentando procesar el mensaje recibido desde el punto extremo bloqueado.';es_CO = 'Intentando procesar el mensaje recibido desde el punto extremo bloqueado.';tr = 'Kilitli uç noktadan alınan mesajı işlemeye çalışılıyor.';it = 'Tentativo di elaborare il messaggio ricevuto da un endpoint bloccato.';de = 'Versuch, die vom gesperrten Endpunkt empfangene Nachricht zu verarbeiten.'");
                EndIf;

                If FoundRows.Count() = 0 Then
                    MessageObject.Locked = True;
                    Raise NStr("ru = 'Не назначен обработчик для сообщения.'; en = 'No handlers are assigned for this message.'; pl = 'Nie ustawiono modułu obsługi wiadomości.';es_ES = 'Manipulador de mensajes no está establecido.';es_CO = 'Manipulador de mensajes no está establecido.';tr = 'Mesaj işleyici ayarlanmamış.';it = 'Nessun gestore è assegnato per questo messaggio.';de = 'Nachrichten-Handler ist nicht festgelegt.'");
                EndIf;

                For Each TableRow In FoundRows Do

                    TableRow.Handler.ProcessMessage(MessageTitle.MessagesChannel, MessageObject.MessageBody.Get(), MessageTitle.Sender);

                    If TransactionActive() Then
                        While TransactionActive() Do
                            RollbackTransaction();
                        EndDo;
                        MessageObject.Locked = True;
                        Raise NStr("ru = 'В обработчике сообщения не была зафиксирована транзакция.'; en = 'No transactions are registered in the message handler.'; pl = 'Transakcja nie została zapisana w module obsługi wiadomości.';es_ES = 'La transacción no se ha grabado en el manipulador de mensajes.';es_CO = 'La transacción no se ha grabado en el manipulador de mensajes.';tr = 'İşlem, mesaj işleyicisine kaydedilmedi.';it = 'Nessuna transazione è stata registrata nel gestore messaggio.';de = 'Die Transaktion wurde nicht im Nachrichtenhandler aufgezeichnet.'");
                    EndIf;

                EndDo;
            Except

                While TransactionActive() Do
                    RollbackTransaction();
                EndDo;

                MessageProcessed = False;

                DetailedErrorPresentation = DetailErrorDescription(ErrorInfo());
                WriteLogEvent(ThisSubsystemEventLogMessageText(),
                        EventLogLevel.Error,,,
                        StringFunctionsClientServer.SubstituteParametersToString(
                            NStr("ru = 'Ошибка обработки сообщения %1: %2'; en = 'Error while processing message %1: %2.'; pl = 'Podczas przetwarzania wiadomości %1 wystąpił błąd: %2';es_ES = 'Ha ocurrido un error al procesar el mensaje %1: %2';es_CO = 'Ha ocurrido un error al procesar el mensaje %1: %2';tr = '%1 mesajı işlenirken hata oluştu: %2.';it = 'Errore durante l''elaborazione del messaggio %1: %2.';de = 'Bei der Verarbeitung der Nachricht ist ein Fehler aufgetreten %1: %2'"),
                            MessageTitle.MessagesChannel, DetailedErrorPresentation));
            EndTry;

            If MessageProcessed Then

                // Deleting message
                If ValueIsFilled(MessageObject.Sender)
                    AND MessageObject.Sender <> ThisNode() Then

                    MessageObject.DataExchange.Recipients.Add(MessageObject.Sender);
                    MessageObject.DataExchange.Recipients.AutoFill = False;

                EndIf;

                // Presence of catalog references must not prevent or slow down deletion of catalog items.
                MessageObject.DataExchange.Load = True;
                SaaS.DeleteAuxiliaryData(MessageObject);
				
			Else
				
				MessageObject.DetailedErrorPresentation = DetailedErrorPresentation;
				SaaS.WriteAuxiliaryData(MessageObject);

            EndIf;

            If ProcessMessagesInSharedData AND SaaS.DataSeparationEnabled() AND SaaS.SeparatedDataUsageAvailable() Then

                ErrorMessageText = StringFunctionsClientServer.SubstituteParametersToString(
                    NStr("ru = 'После обработки сообщения канала %1 не было выключено разделение сеанса.'; en = 'Session separation was not disabled after processing the %1 channel message.'; pl = 'Po przetwarzaniu komunikatu kanału %1 nie był wyłączony podział sesji.';es_ES = 'Después de que el procesador de datos de %1 la separación de la sesión de mensajes del canal no se ha desactivado.';es_CO = 'Después de que el procesador de datos de %1 la separación de la sesión de mensajes del canal no se ha desactivado.';tr = 'Kanal mesajı oturumunun veri işlemcisi ayrıldıktan sonra %1 devre dışı bırakıldı.';it = 'La separazione di sessione non è stata disabilitata dopo l''elaborazione del messaggio del canale %1.';de = 'Nach der Verarbeitung der Nachricht des Kanals %1 wurde die Sitzungsfreigabe nicht deaktiviert.'"),
                    MessageTitle.MessagesChannel);

                WriteLogEvent(
                    ThisSubsystemEventLogMessageText(),
                    EventLogLevel.Error,
                    ,
                    ,
                    ErrorMessageText);

                SaaS.SetSessionSeparation(False);

            EndIf;

        Except
            WriteLogEvent(ThisSubsystemEventLogMessageText(),
                    EventLogLevel.Error,,,
                    DetailErrorDescription(ErrorInfo()));
        EndTry;

        UnlockDataForEdit(Selection.Ref);

    EndDo;

EndProcedure

// For internal use only.
Procedure ProcessSystemMessageQueueInBackground(ProcedureParameters, StorageAddress) Export
	
	ProcessSystemMessageQueue(ProcedureParameters["ImportedMessages"]);
	
EndProcedure

// For internal use only.
Procedure SetLeadingEndpointAtSender(Cancel, SenderConnectionSettings, Endpoint) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(LeadingEndpointSettingEventLogMessage(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndpointObject = Endpoint.GetObject();
		EndpointObject.Leading = False;
		EndpointObject.Write();
		
		// Updating connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Endpoint", Endpoint);
		
		RecordStructure.Insert("WebServiceAddress", SenderConnectionSettings.WSWebServiceURL);
		RecordStructure.Insert("UserName", SenderConnectionSettings.WSUsername);
		RecordStructure.Insert("Password",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("RememberPassword", True);
		
		// Adding information register record
		InformationRegisters.MessageExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting the leading endpoint at recipient side.
		WSProxy.SetLeadingEndPoint(EndpointObject.Code, ThisNodeCode());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(LeadingEndpointSettingEventLogMessage(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
Procedure SetLeadingEndpointAtRecipient(ThisEndpointCode, LeadingEndpointCode) Export
	
	SetPrivilegedMode(True);
	
	If ExchangePlans.MessageExchange.FindByCode(ThisEndpointCode) <> ThisNode() Then
		ErrorMessageString = NStr("ru = 'Заданы неверные параметры подключения к конечной точке. Параметры подключения указывают на другую конечную точку.'; en = 'Invalid endpoint connection parameters. The connection parameters refer to another endpoint.'; pl = 'Określono nieprawidłowe parametry połączenia z punktem końcowym. Parametry połączenia wskazują inny punkt końcowy.';es_ES = 'Parámetros incorrectos de la conexión al punto extremo se han establecido. Parámetros de conexión indican otro punto extremo.';es_CO = 'Parámetros incorrectos de la conexión al punto extremo se han establecido. Parámetros de conexión indican otro punto extremo.';tr = 'Uç noktasına yanlış bağlantı parametreleri ayarlandı. Bağlantı parametreleri başka bir uç noktasını gösterir.';it = 'Parametri errati di connessione a endpoint. I parametri di connessione indicati si riferiscono a un altro endpoint.';de = 'Falsche Parameter der Verbindung zum Endpunkt wurden festgelegt. Verbindungsparameter zeigen einen anderen Endpunkt an.'");
		ErrorMessageStringForEventLog = NStr("ru = 'Заданы неверные параметры подключения к конечной точке.
			|Параметры подключения указывают на другую конечную точку.'; 
			|en = 'Invalid endpoint connection parameters.
			|The connection parameters refer to another endpoint.'; 
			|pl = 'Określono nieprawidłowe parametry połączenia z punktem końcowym.
			|Parametry połączenia wskazują inny punkt końcowy.';
			|es_ES = 'Parámetros incorrectos de la conexión al punto extremo se han establecido.
			|Parámetros de conexión indican otro punto extremo.';
			|es_CO = 'Parámetros incorrectos de la conexión al punto extremo se han establecido.
			|Parámetros de conexión indican otro punto extremo.';
			|tr = 'Uç noktasına yanlış bağlantı parametreleri ayarlandı. 
			|Bağlantı parametreleri başka bir uç noktasını gösterir.';
			|it = 'Parametri errati di connessione a endpoint.
			|I parametri di connessione indicati si riferiscono a un altro endpoint.';
			|de = 'Falsche Parameter der Verbindung zum Endpunkt wurden gesetzt.
			|Verbindungsparameter zeigen einen anderen Endpunkt an.'", CommonClientServer.DefaultLanguageCode());
		WriteLogEvent(LeadingEndpointSettingEventLogMessage(),
				EventLogLevel.Error,,, ErrorMessageStringForEventLog);
		Raise ErrorMessageString;
	EndIf;
	
	BeginTransaction();
	Try
		
		EndpointNode = ExchangePlans.MessageExchange.FindByCode(LeadingEndpointCode);
		
		If EndpointNode.IsEmpty() Then
			
			Raise NStr("ru = 'Конечная точка в базе-корреспонденте не обнаружена.'; en = 'The endpoint is not found in the correspondent infobase.'; pl = 'Nie znaleziono punktu końcowego w bazie korespondencie.';es_ES = 'Punto extremo no se ha encontrado en la base correspondiente.';es_CO = 'Punto extremo no se ha encontrado en la base correspondiente.';tr = 'Uç noktası çalışma dizininde bulunamadı.';it = 'Endpoint non trovato nell''infobase corrispondente.';de = 'Endpunkt wird nicht in der Korrespondenzbasis gefunden.'");
			
		EndIf;
		EndpointNodeObject = EndpointNode.GetObject();
		EndpointNodeObject.Leading = True;
		EndpointNodeObject.Write();
		
		CommitTransaction();
	Except
		RollbackTransaction();
		WriteLogEvent(LeadingEndpointSettingEventLogMessage(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use only.
Procedure ConnectEndpointAtRecipient(Cancel, Code, Description, RecipientConnectionSettings) Export
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	SetPrivilegedMode(True);
	
	BeginTransaction();
	Try
		
		// Creating or updating an exchange plan node matching the endpoint to be connected.
		EndpointNode = ExchangePlans.MessageExchange.FindByCode(Code);
		If EndpointNode.IsEmpty() Then
			EndpointNodeObject = ExchangePlans.MessageExchange.CreateNode();
			EndpointNodeObject.Code = Code;
		Else
			EndpointNodeObject = EndpointNode.GetObject();
			EndpointNodeObject.ReceivedNo = 0;
		EndIf;
		EndpointNodeObject.Description = Description;
		EndpointNodeObject.Leading = True;
		EndpointNodeObject.Write();
		
		// Updating connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Endpoint", EndpointNodeObject.Ref);
		
		RecordStructure.Insert("WebServiceAddress", RecipientConnectionSettings.WSWebServiceURL);
		RecordStructure.Insert("UserName", RecipientConnectionSettings.WSUsername);
		RecordStructure.Insert("Password",          RecipientConnectionSettings.WSPassword);
		RecordStructure.Insert("RememberPassword", True);
		
		// Adding information register record
		InformationRegisters.MessageExchangeTransportSettings.AddRecord(RecordStructure);
		
		// Setting the scheduled job usage flag.
		ScheduledJobsServer.SetScheduledJobUsage(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Raise;
	EndTry;
	
EndProcedure

// For internal use only.
Procedure UpdateEndpointConnectionParameters(Cancel, Endpoint, SenderConnectionSettings, RecipientConnectionSettings) Export
	
	SetPrivilegedMode(True);
	
	ErrorMessageString = "";
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.TestConnectionRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.TestConnectionRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
	Except
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	BeginTransaction();
	Try
		
		// Updating connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Endpoint", Endpoint);
		
		RecordStructure.Insert("WebServiceAddress", SenderConnectionSettings.WSWebServiceURL);
		RecordStructure.Insert("UserName", SenderConnectionSettings.WSUsername);
		RecordStructure.Insert("Password",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("RememberPassword", True);
		
		// Adding information register record
		InformationRegisters.MessageExchangeTransportSettings.UpdateRecord(RecordStructure);
		
		If Not Endpoint = ExchangePlans.MessageExchange.ThisNode() Then
			If CorrespondentVersion_2_0_1_6 Then
				WSProxy.UpdateConnectionSettings(ThisNodeCode(), XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
			Else
				WSProxy.UpdateConnectionSettings(ThisNodeCode(), ValueToStringInternal(RecipientConnectionSettings));
			EndIf;
		EndIf;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
Function ThisNodeCode() Export
	
	Return Common.ObjectAttributeValue(ThisNode(), "Code");
	
EndFunction

// For internal use only.
Function ThisNodeDescription() Export
	
	Return Common.ObjectAttributeValue(ThisNode(), "Description");
	
EndFunction

// For internal use only.
Function AllRecipients() Export
	
	QueryText =
	"SELECT
	|	MessageExchange.Ref AS Recipient
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|WHERE
	|	MessageExchange.Ref <> &ThisNode";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	Return Query.Execute().Unload().UnloadColumn("Recipient");
EndFunction

// For internal use only.
Procedure SerializeDataToStream(DataSelection, Thread) Export
	
	XMLWriter = New XMLWriter;
	XMLWriter.SetString();
	XMLWriter.WriteXMLDeclaration();
	XMLWriter.WriteStartElement("Root");
	
	For Each Ref In DataSelection Do
		
		Data = Ref.GetObject();
		Data.Code = 0;
		
		// {Event handler: OnSendMessage} Start.
		MessageBody = Data.MessageBody.Get();
		
		OnSendMessage(Data.Description, MessageBody, Data);
		
		Data.MessageBody = New ValueStorage(MessageBody);
		// {Event handler: OnSendMessage} End.
		
		WriteXML(XMLWriter, Data);
		
	EndDo;
	XMLWriter.WriteEndElement();
	
	Thread = XMLWriter.Close();
	
EndProcedure

// For internal use only.
Procedure SerializeDataFromStream(Sender, Thread, ImportedObjects, DataReadPartially) Export
	
	ModuleSaaS = Undefined;
	If SaaSCached.IsSeparatedConfiguration() Then
		ModuleSaaS = Common.CommonModule("SaaS");
	EndIf;
	
	DataCanBeReadPartially = CorrespondentSupportsPartiallyReceivingExchangeMessages(Sender);
	
	ImportedObjects = New Array;
	
	XMLReader = New XMLReader;
	Try
		XMLReader.SetString(Thread);
		XMLReader.Read(); // Root node
		XMLReader.Read(); // object node
	Except
		XMLReader.Close();
		Raise;
	EndTry;
	
	BeginTransaction();
	Try
		While CanReadXML(XMLReader) Do
			
			Data = ReadXML(XMLReader);
			
			If TypeOf(Data) = Type("ObjectDeletion") Then
				
				Raise NStr("ru = 'Передача объекта ObjectDeletion через механизм быстрых сообщений не поддерживается.'; en = 'Cannot transfer the ObjectDeletion object using the instant message tool.'; pl = 'Przekazanie obiektu ObjectDeletion poprzez mechanizm szybkich komunikatów nie jest obsługiwane.';es_ES = 'Paso del objeto ObjectDeletion a través de la herramienta de mensaje instantáneo no de admite.';es_CO = 'Paso del objeto ObjectDeletion a través de la herramienta de mensaje instantáneo no de admite.';tr = 'ObjectDeletion nesnesi anlık ileti aracı kullanılarak iletilemiyor.';it = 'Impossibile trasferire oggetto ObjectDeletion tramite strumento di messaggistica istantanea.';de = 'Das Objekt ObjectDeletion kann nicht mit dem Instant-Message-Tool übertragen werden.'");
				
			Else
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only.
				EndIf;
				
				// {Handler: OnReceiveMessage} Start
				MessageBody = Data.MessageBody.Get();
				
				OnReceiveMessage(Data.Description, MessageBody, Data);
				
				Data.MessageBody = New ValueStorage(MessageBody);
				// {Handler: OnReceiveMessage} End
				
				If Not Data.IsNew() Then
					Continue; // Importing new messages only.
				EndIf;
				
				Data.Sender = Sender;
				Data.Recipient = ThisNode();
				Data.AdditionalProperties.Insert("SkipPeriodClosingCheck");
				
			EndIf;
			
			MustRestoreSeparation = False;
			If SaaSCached.IsSeparatedConfiguration() AND SaaS.IsSeparatedMetadataObject(Data.Metadata(), SaaS.AuxiliaryDataSeparator()) Then
				
				DataArea = Data[SaaS.AuxiliaryDataSeparator()];
				
				If ModuleSaaS.DataAreaLocked(DataArea) Then
					// Message for a locked area cannot be accepted.
					If DataCanBeReadPartially Then
						DataReadPartially = True;
						Continue;
					Else
						Raise StringFunctionsClientServer.SubstituteParametersToString(
							NStr("ru = 'Не удалось выполнить обмен сообщениями по причине: область данных %1 заблокирована.'; en = 'Cannot execute message exchange due to: the %1 data area is locked.'; pl = 'Nie udało się wykonać wymiany komunikatów z powodu: obszar danych %1 jest zablokowany.';es_ES = 'No se puede realizar un intercambio de correos electrónicos debido a: el área de datos %1 está bloqueada.';es_CO = 'No se puede realizar un intercambio de correos electrónicos debido a: el área de datos %1 está bloqueada.';tr = 'Aşağıdakiler nedeniyle bir e-posta değişimi yapılamıyor: veri alanı %1 kilitlendi.';it = 'Impossibile eseguire lo scambio di messaggio a causa di: l''area dati %1 è bloccata.';de = 'Der Nachrichtenaustausch konnte aus folgendem Grund nicht ausgeführt werden: Der Datenbereich %1 ist gesperrt.'"),
							DataArea);
					EndIf;
				EndIf;
				
				MustRestoreSeparation = True;
				SaaS.SetSessionSeparation(True, DataArea);
				
			EndIf;
			
			// In case of conflicting changes, the current infobase takes precedence.
			If ExchangePlans.IsChangeRecorded(Sender, Data) Then
				If MustRestoreSeparation Then
					SaaS.SetSessionSeparation(False);
				EndIf;
				Continue;
			EndIf;
			
			Data.DataExchange.Sender = Sender;
			Data.DataExchange.Load = True;
			
			Data.SetNewCode();
			Data.Write();
			
			If MustRestoreSeparation Then
				SaaS.SetSessionSeparation(False);
			EndIf;
			
			ImportedObjects.Add(Data.Ref);
			
		EndDo;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		XMLReader.Close();
		Raise;
	EndTry;
	
	XMLReader.Close();
	
EndProcedure

// For internal use only.
Function GetWSProxy(SettingsStructure, ErrorMessageString = "", Timeout = 60) Export
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/MessageExchange");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// For internal use only.
Function GetWSProxy_2_0_1_6(SettingsStructure, ErrorMessageString = "", Timeout = 60)
	
	SettingsStructure.Insert("WSServiceNamespaceURL", "http://www.1c.ru/SSL/MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSServiceName",                 "MessageExchange_2_0_1_6");
	SettingsStructure.Insert("WSTimeout", Timeout);
	
	Return DataExchangeServer.GetWSProxyByConnectionParameters(SettingsStructure, ErrorMessageString);
EndFunction

// Validates correspondent infobase support for partial delivery of data exchange messages during 
//  message exchange (if not supported partial delivery of exchange messages on the infobase side 
//  must not be used).
//
// Parameters:
//  Sender - ExchangePlanRef.MessageExchange.
//
// Returns: Boolean.
//
Function CorrespondentSupportsPartiallyReceivingExchangeMessages(Val Correspondent)
	
	CorrespondentVersions = CorrespondentVersions(Correspondent);
	Return (CorrespondentVersions.Find("2.1.1.8") <> Undefined);
	
EndFunction

// Returns an array containing numbers of versions supported by the MessageExchange subsystem correspondent interface.
// 
// Parameters:
// Correspondent - Structure, ExchangePlanRef. Exchange plan node that corresponds the correspondent 
//                 infobase.
//
// Returns:
// Array of version numbers that are supported by correspondent API.
//
Function CorrespondentVersions(Val Correspondent)
	
	If TypeOf(Correspondent) = Type("Structure") Then
		SettingsStructure = Correspondent;
	Else
		SettingsStructure = InformationRegisters.MessageExchangeTransportSettings.TransportSettingsWS(Correspondent);
	EndIf;
	
	ConnectionParameters = New Structure;
	ConnectionParameters.Insert("URL",      SettingsStructure.WSWebServiceURL);
	ConnectionParameters.Insert("UserName", SettingsStructure.WSUsername);
	ConnectionParameters.Insert("Password", SettingsStructure.WSPassword);
	
	Return Common.GetInterfaceVersions(ConnectionParameters, "MessageExchange");
	
EndFunction

// For internal use only.
Function EndpointConnectionEventLogEvent() Export
	
	Return NStr("ru = 'Обмен сообщениями.Подключение конечной точки'; en = 'Message exchange. Connecting the endpoint'; pl = 'Wymiana wiadomości. Podłączenie punktu końcowego';es_ES = 'Intercambio de mensajes.Conexión del punto extremo';es_CO = 'Intercambio de mensajes.Conexión del punto extremo';tr = 'Mesaj alışverişi. Uç noktası bağlantısı';it = 'Scambio di messaggi. Connessione a endpoint';de = 'Nachrichtenaustausch. Endpunktverbindung'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only.
Function LeadingEndpointSettingEventLogMessage() Export
	
	Return NStr("ru = 'Обмен сообщениями.Установка ведущей конечной точки'; en = 'Message exchange. Setting the leading endpoint'; pl = 'Wymiana wiadomości. Ustawienia wiodącego punktu końcowego';es_ES = 'Intercambio de mensajes.Estableciendo el punto extremo principal';es_CO = 'Intercambio de mensajes.Estableciendo el punto extremo principal';tr = 'Mesaj alışverişi. Ana uç noktayı belirleme';it = 'Scambio di messaggi. Impostazione dell''endpoint principale';de = 'Nachrichtenaustausch. Festlegen des führenden Endpunkts'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only.
Function ThisSubsystemEventLogMessageText() Export
	
	Return NStr("ru = 'Обмен сообщениями'; en = 'Message exchange'; pl = 'Wymiana wiadomości';es_ES = 'Intercambio de mensajes';es_CO = 'Intercambio de mensajes';tr = 'Mesaj alışverişi';it = 'Scambio di messaggi';de = 'Nachrichtenaustausch'", CommonClientServer.DefaultLanguageCode());
	
EndFunction

// For internal use only.
Function ThisNodeDefaultDescription() Export
	
	Return ?(SaaS.DataSeparationEnabled(), Metadata.Synonym, DataExchangeCached.ThisInfobaseName());
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

// For internal use only.
Procedure SendReceiveMessagesViaWebServiceExecute(Cancel)
	
	QueryText =
	"SELECT DISTINCT
	|	MessageExchange.Ref AS Ref
	|FROM
	|	ExchangePlan.MessageExchange AS MessageExchange
	|		INNER JOIN InformationRegister.MessageExchangeTransportSettings AS TransportSettings
	|		ON MessageExchange.Ref = TransportSettings.Endpoint
	|WHERE
	|	MessageExchange.Ref <> &ThisNode
	|	AND NOT MessageExchange.Leading
	|	AND NOT MessageExchange.DeletionMark
	|	AND NOT MessageExchange.Locked";
	
	Query = New Query;
	Query.SetParameter("ThisNode", ThisNode());
	Query.Text = QueryText;
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	NodesArray = QueryResult.Unload().UnloadColumn("Ref");
	
	// Importing data from all endpoints.
	For Each Recipient In NodesArray Do
		
		Cancel1 = False;
		
		ExchangeParameters = DataExchangeServer.ExchangeParameters();
		ExchangeParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS;
		ExchangeParameters.ExecuteImport = True;
		ExchangeParameters.ExecuteExport = False;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Recipient, ExchangeParameters, Cancel1);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
	// Exporting data to all endpoints.
	For Each Recipient In NodesArray Do
		
		Cancel1 = False;
		
		ExchangeParameters = DataExchangeServer.ExchangeParameters();
		ExchangeParameters.ExchangeMessagesTransportKind = Enums.ExchangeMessagesTransportTypes.WS;
		ExchangeParameters.ExecuteImport = False;
		ExchangeParameters.ExecuteExport = True;
		
		DataExchangeServer.ExecuteDataExchangeForInfobaseNode(Recipient, ExchangeParameters, Cancel1);
		
		Cancel = Cancel OR Cancel1;
		
	EndDo;
	
EndProcedure

// For internal use only.
Procedure ConnectEndpointAtSender(Cancel,
														SenderConnectionSettings,
														RecipientConnectionSettings,
														Endpoint,
														RecipientEndpointDescription,
														SenderEndpointDescription) Export
	
	DataExchangeServer.CheckDataExchangeUsage();
	
	ErrorMessageString = "";
	
	SetPrivilegedMode(True);
	
	CorrespondentVersions = CorrespondentVersions(SenderConnectionSettings);
	CorrespondentVersion_2_0_1_6 = (CorrespondentVersions.Find("2.0.1.6") <> Undefined);
	
	If CorrespondentVersion_2_0_1_6 Then
		WSProxy = GetWSProxy_2_0_1_6(SenderConnectionSettings, ErrorMessageString);
	Else
		WSProxy = GetWSProxy(SenderConnectionSettings, ErrorMessageString);
	EndIf;
	
	If WSProxy = Undefined Then
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	Try
		
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.TestConnectionRecipient(XDTOSerializer.WriteXDTO(RecipientConnectionSettings), ThisNodeCode());
		Else
			WSProxy.TestConnectionRecipient(ValueToStringInternal(RecipientConnectionSettings), ThisNodeCode());
		EndIf;
		
	Except
		Cancel = True;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	If CorrespondentVersion_2_0_1_6 Then
		EndpointParameters = XDTOSerializer.ReadXDTO(WSProxy.GetIBParameters(RecipientEndpointDescription));
	Else
		EndpointParameters = ValueFromStringInternal(WSProxy.GetIBParameters(RecipientEndpointDescription));
	EndIf;
	
	EndpointNode = ExchangePlans.MessageExchange.FindByCode(EndpointParameters.Code);
	
	If Not EndpointNode.IsEmpty() Then
		Cancel = True;
		ErrorMessageString = NStr("ru = 'Конечная точка уже подключена к информационной базе; наименование точки: %1'; en = 'The endpoint is already connected to the infobase. Endpoint name: %1'; pl = 'Punkt końcowy jest już połączony do bazy informacyjnej; nazwa punktu: %1';es_ES = 'Punto extremo ya se ha conectado a la infobase; nombre del punto: %1';es_CO = 'Punto extremo ya se ha conectado a la infobase; nombre del punto: %1';tr = 'Uç noktası zaten veritabanına bağlandı; nokta adı: %1';it = 'Endpoint già connesso all''infobase. Nome endpoint: %1';de = 'Der Endpunkt ist bereits mit der Infobase verbunden. Punktname: %1'", CommonClientServer.DefaultLanguageCode());
		ErrorMessageString = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessageString, Common.ObjectAttributeValue(EndpointNode, "Description"));
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,, ErrorMessageString);
		Return;
	EndIf;
	
	BeginTransaction();
	Try
		
		// Assigning description to this endpoint if necessary.
		If IsBlankString(ThisNodeDescription()) Then
			
			ThisNodeObject = ThisNode().GetObject();
			ThisNodeObject.Description = ?(IsBlankString(SenderEndpointDescription), ThisNodeDefaultDescription(), SenderEndpointDescription);
			ThisNodeObject.Write();
			
		EndIf;
		
		// Creating an exchange plan node matching the endpoint to be connected.
		EndpointNodeObject = ExchangePlans.MessageExchange.CreateNode();
		EndpointNodeObject.Code = EndpointParameters.Code;
		EndpointNodeObject.Description = EndpointParameters.Description;
		EndpointNodeObject.Write();
		
		// Updating connection settings.
		RecordStructure = New Structure;
		RecordStructure.Insert("Endpoint", EndpointNodeObject.Ref);
		
		RecordStructure.Insert("WebServiceAddress", SenderConnectionSettings.WSWebServiceURL);
		RecordStructure.Insert("UserName", SenderConnectionSettings.WSUsername);
		RecordStructure.Insert("Password",          SenderConnectionSettings.WSPassword);
		RecordStructure.Insert("RememberPassword", True);
		
		// Adding information register record
		InformationRegisters.MessageExchangeTransportSettings.AddRecord(RecordStructure);
		
		ThisPointParameters = Common.ObjectAttributesValues(ThisNode(), "Code, Description");
		
		// Establishing the endpoint connection on recipient side.
		If CorrespondentVersion_2_0_1_6 Then
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, XDTOSerializer.WriteXDTO(RecipientConnectionSettings));
		Else
			WSProxy.ConnectEndPoint(ThisPointParameters.Code, ThisPointParameters.Description, ValueToStringInternal(RecipientConnectionSettings));
		EndIf;
		
		// Setting the scheduled job usage flag.
		ScheduledJobsServer.SetScheduledJobUsage(
			Metadata.ScheduledJobs.SendReceiveSystemMessages, True);
		
		Endpoint = EndpointNodeObject.Ref;
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		Endpoint = Undefined;
		WriteLogEvent(EndpointConnectionEventLogEvent(), EventLogLevel.Error,,,
				DetailErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
EndProcedure

// For internal use only.
Function MessageHandlers()
	
	Result = NewMessageHandlerTable();
	
	SSLSubsystemsIntegration.MessageChannelHandlersOnDefine(Result);
	
	MessagesExchangeOverridable.GetMessageChannelHandlers(Result);
	
	Return Result;
	
EndFunction

// For internal use only.
Function NewMessageHandlerTable()
	
	Handlers = New ValueTable;
	Handlers.Columns.Add("Canal");
	Handlers.Columns.Add("Handler");
	
	Return Handlers;
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Message sending/receiving event handlers.

Procedure OnSendMessage(Val MessagesChannel, MessageBody, MessageObject)
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageSaaS = Common.CommonModule("MessagesSaaS");
		ModuleMessageSaaS.OnSendMessage(MessagesChannel, MessageBody, MessageObject);
	EndIf;
	
	MessagesExchangeOverridable.OnSendMessage(MessagesChannel, MessageBody);
	
EndProcedure

Procedure OnReceiveMessage(Val MessagesChannel, MessageBody, MessageObject)
	
	If Common.SubsystemExists("StandardSubsystems.SaaS.MessageExchange") Then
		ModuleMessageSaaS = Common.CommonModule("MessagesSaaS");
		ModuleMessageSaaS.OnReceiveMessage(MessagesChannel, MessageBody, MessageObject);
	EndIf;
	
	MessagesExchangeOverridable.OnReceiveMessage(MessagesChannel, MessageBody);
	
EndProcedure

#EndRegion
