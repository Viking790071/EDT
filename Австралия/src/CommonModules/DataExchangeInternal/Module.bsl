#Region Internal

Function ImportFilePart(FileID, ImportedFilePartNumber, ImportedFilePart, ErrorMessage) Export
	
	ErrorMessage = "";
	
	If Not ValueIsFilled(FileID) Then
		ErrorMessage = NStr("ru = 'Не указан идентификатор загружаемого файла. Дальнейшее выполнение метода невозможно.
				|Необходимо для загружаемого файла назначить уникальный идентификатор.'; 
				|en = 'ID of the file being imported is not specified. This method can be no longer executed.
				|Unique ID is required for the file being imported.'; 
				|pl = 'Nie jest wskazany identyfikator pobieranego pliku. Dalsze wykonanie metody jest niemożliwe.
				|Należy dla pobieranego pliku wyznaczyć unikalny identyfikator.';
				|es_ES = 'No se ha indicado el identificador del archivo descargado. La siguiente ejecución del método es imposible.
				|Es necesario indicar el identificador único para el archivo descargado.';
				|es_CO = 'No se ha indicado el identificador del archivo descargado. La siguiente ejecución del método es imposible.
				|Es necesario indicar el identificador único para el archivo descargado.';
				|tr = 'İndirilen dosyanın kimliği belirtilmedi. Bir yöntemin daha fazla yürütülmesi mümkün değildir. 
				|İndirilen dosyanın benzersiz bir tanımlayıcı atamanız gerekir.';
				|it = 'ID del file in importazione non indicata. Questo metodo non può più essere eseguito.
				|È richiesta una ID univoca per il file in importazione.';
				|de = 'Die Kennung der heruntergeladenen Datei wird nicht angegeben. Eine weitere Ausführung der Methode ist nicht möglich.
				|Es ist notwendig, der heruntergeladenen Datei eine eindeutige Kennung zuzuweisen.'");
		Raise(ErrorMessage);
	EndIf;
	
	If Not ValueIsFilled(ImportedFilePart)
		AND TypeOf(ImportedFilePart) <> Type("BinaryData") Then
		ErrorMessage = NStr("ru = 'Метод не может быть выполнен, т.к. переданные данные не соответствуют типу для получения данных.'; en = 'The method cannot be executed as the transferred data does not correspond to the type for receiving data.'; pl = 'Metoda nie może być wykonana, ponieważ przekazane dane nie odpowiadają typowi do otrzymania danych.';es_ES = 'El método no puede ser realizado porque los datos pasados no corresponden al tipo para recibir los datos.';es_CO = 'El método no puede ser realizado porque los datos pasados no corresponden al tipo para recibir los datos.';tr = 'Yöntem yürütülemez, çünkü aktarılan veriler veri almak için türe uygun değildir.';it = 'Il metodo non può essere eseguito poiché i dati trasferiti non corrispondono al tipo per i dati di ricezione.';de = 'Die Methode kann nicht ausgeführt werden, da die übertragenen Daten nicht dem Typ des Datenempfangs entsprechen.'");
		Raise(ErrorMessage);
	EndIf;
	
	If Not ValueIsFilled(ImportedFilePartNumber) 
		Or ImportedFilePartNumber = 0 Then
		ImportedFilePartNumber = 1;
	EndIf;
	
	TempFilesDir = TemporaryExportDirectory(FileID);
	
	Directory = New File(TempFilesDir);
	If Not Directory.Exist() Then
		CreateDirectory(TempFilesDir);
	EndIf;
	
	FileName = CommonClientServer.GetFullFileName(TempFilesDir, GetFilePartName(ImportedFilePartNumber));
	ImportedFilePart.Write(FileName);
	
EndFunction

Function ExportFilePart(FileID, ExportedFilePartNumber, ErrorMessage) Export
	
	ErrorMessage      = "";
	FilePartName          = "";
	TempFilesDir = TemporaryExportDirectory(FileID);
	
	For DigitCount = StrLen(Format(ExportedFilePartNumber, "NFD=0; NG=0")) To 5 Do
		
		FormatString = StringFunctionsClientServer.SubstituteParametersToString("ND=%1; NLZ=; NG=0", String(DigitCount));
		
		FileName = StringFunctionsClientServer.SubstituteParametersToString("%1.zip.%2", FileID, Format(ExportedFilePartNumber, FormatString));
		
		FileNames = FindFiles(TempFilesDir, FileName);
		
		If FileNames.Count() > 0 Then
			
			FilePartName = CommonClientServer.GetFullFileName(TempFilesDir, FileName);
			Break;
			
		EndIf;
		
	EndDo;
	
	FilePart = New File(FilePartName);
	
	If FilePart.Exist() Then
		Return New BinaryData(FilePartName);
	Else
		ErrorMessage = NStr("ru = 'Часть файла с указанным номером не найдена.'; en = 'Part of the file with the specified number is not found.'; pl = 'Część pliku ze wskazanym numerem nie jest wyszukana.';es_ES = 'La parte de archivo con el número indicado no se ha encontrado.';es_CO = 'La parte de archivo con el número indicado no se ha encontrado.';tr = 'Belirtilen numaraya sahip dosyanın bir kısmı bulunamadı.';it = 'Parte del file con il numero indicato non è stato trovato.';de = 'Der Teil der Datei mit der angegebenen Nummer wurde nicht gefunden.'");
	EndIf;
	
EndFunction

Function PrepareFileForImport(FileID, ErrorMessage) Export
	
	SetPrivilegedMode(True);
	
	TempStorageFileID = "";
	
	TempFilesDir = TemporaryExportDirectory(FileID);
	ArchiveName              = CommonClientServer.GetFullFileName(TempFilesDir, "datafile.zip");
	
	ReceivedFilesArray = FindFiles(TempFilesDir,"data.zip.*");
	
	If ReceivedFilesArray.Count() > 0 Then
		
		FilesToMerge = New Array();
		FilePartName = CommonClientServer.GetFullFileName(TempFilesDir, "data.zip.%1");
		
		For PartNumber = 1 To ReceivedFilesArray.Count() Do
			FilesToMerge.Add(StringFunctionsClientServer.SubstituteParametersToString(FilePartName, PartNumber));
		EndDo;
		
	Else
		MessageTemplate = NStr("ru = 'Не найден ни один фрагмент сессии передачи с идентификатором %1.
				|Необходимо убедиться, что в настройках программы заданы параметры
				|""Каталог временных файлов для Linux"" и ""Каталог временных файлов для Windows"".'; 
				|en = 'No fragments of the transfer session with ID are found%1.
				|Make sure that parameters 
				|""Directory of temporary files for Windows"" and ""Directory of temporary files for Linux"" are specified in the application settings.'; 
				|pl = 'Nie znaleziono żadnego fragmentu sesji przekazania z identyfikatorem %1.
				|Należy upewnić się, że w ustawieniach programu są określone parametry
				|""Katalog plików tymczasowych Linux"" i ""Katalog plików tymczasowych Windows"".';
				|es_ES = 'No se ha encontrado ningún fragmento de la sesión de traspaso con el identificador %1.
				|Es necesario asegurarse que en los ajustes del programa se han establecido los parámetros
				|""Catálogo de los archivos temporales para Linux"" y ""Catálogo de los archivos temporales para Windows"".';
				|es_CO = 'No se ha encontrado ningún fragmento de la sesión de traspaso con el identificador %1.
				|Es necesario asegurarse que en los ajustes del programa se han establecido los parámetros
				|""Catálogo de los archivos temporales para Linux"" y ""Catálogo de los archivos temporales para Windows"".';
				|tr = '%1Kimlik ile transfer oturumu parçası bulunamadı. 
				|Uygulama ayarlarında ""Linux için geçici dosya dizini"" ve ""Windows için geçici dosya dizini"" 
				|belirtildiğinden emin olmak gerekir.';
				|it = 'Non sono stati trovati frammenti della sessione di trasferimento con ID%1.
				|Accertarsi che i parametri 
				|""Directory dei file temporanei per Windows"" e ""Directory dei file temporanei per Linux"" siano indicati nelle impostazioni dell''applicazione.';
				|de = 'Es wurden keine Fragmente einer Übertragungssitzung mit dem Bezeichner gefunden %1.
				|Es ist darauf zu achten, dass die Programmeinstellungen die Parameter
				|""Temporäres Dateiverzeichnis für Linux"" und ""Temporäres Dateiverzeichnis für Windows"" enthalten.'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(MessageTemplate, String(FileID));
		Raise(ErrorMessage);
	EndIf;
	
	Try 
		MergeFiles(FilesToMerge, ArchiveName);
	Except
		ErrorMessage = BriefErrorDescription(ErrorInfo());
		Raise(ErrorMessage);
	EndTry;
	
	// Unpack.
	Dearchiver = New ZipFileReader(ArchiveName);
	
	If Dearchiver.Items.Count() = 0 Then
		
		Try
			DeleteFiles(TempFilesDir);
		Except
			ErrorMessage = DetailErrorDescription(ErrorInfo());
			WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
				EventLogLevel.Error,,, ErrorMessage);
			Raise(ErrorMessage);
		EndTry;
		
		ErrorMessage = NStr("ru = 'Файл архива не содержит данных.'; en = 'The archive file does not contain data.'; pl = 'Plik archiwum nie zawiera danych.';es_ES = 'Documento del archivo no contiene datos.';es_CO = 'Documento del archivo no contiene datos.';tr = 'Arşiv dosyası veri içermemektedir.';it = 'Il file archivio non contiene dati.';de = 'Die Archivdatei enthält keine Daten.'");
		Raise(ErrorMessage);
		
	EndIf;
	
	FileName = CommonClientServer.GetFullFileName(TempFilesDir, Dearchiver.Items[0].Name);
	Dearchiver.Extract(Dearchiver.Items[0], TempFilesDir);
	Dearchiver.Close();
	
	// Placing the file to the file temporary storage directory.
	ImportDirectory          = DataExchangeCached.TempFilesStorageDirectory();
	NameOfFIleWithData         = CommonClientServer.GetNameWithExtension(FileID, CommonClientServer.GetFileNameExtension(FileName));
	FileNameInImportDirectory = CommonClientServer.GetFullFileName(ImportDirectory, NameOfFIleWithData);
	
	Try
		MoveFile(FileName, FileNameInImportDirectory);
	Except
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, ErrorMessage);
		Raise(ErrorMessage);
	EndTry;
	
	TempStorageFileID = DataExchangeServer.PutFileInStorage(FileNameInImportDirectory);
	
	// Deleting temporary files.
	Try
		DeleteFiles(TempFilesDir);
	Except
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		WriteLogEvent(DataExchangeServer.TempFileDeletionEventLogMessageText(),
			EventLogLevel.Error,,, ErrorMessage);
		Raise(ErrorMessage);
	EndTry;
	
	Return TempStorageFileID;
	
EndFunction

Procedure PrepareDataForExportFromInfobase(ProcedureParameters, StorageAddress) Export
	
	WebServiceParameters = ProcedureParameters["WebServiceParameters"];
	ErrorMessage   = ProcedureParameters["ErrorMessage"];
	
	SetPrivilegedMode(True);
	
	ExchangeComponents = ExchangeComponents("Sending", WebServiceParameters);
	FileName         = String(New UUID()) + ".xml";
	
	TempFilesDir = DataExchangeCached.TempFilesStorageDirectory();
	FullFileName         = CommonClientServer.GetFullFileName(
		TempFilesDir, FileName);
		
	// Opening the exchange file.
	DataExchangeXDTOServer.OpenExportFile(ExchangeComponents, FullFileName);
	
	If ExchangeComponents.ErrorFlag Then
		ExchangeComponents.ExchangeFile = Undefined;
		
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
		Raise ExchangeComponents.ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure = ExchangeSettingsStructure(ExchangeComponents, Enums.ActionsOnExchange.DataExport);
	
	// Data export.
	Try
		DataExchangeXDTOServer.ExecuteDataExport(ExchangeComponents);
	Except
		
		If ExchangeComponents.IsExchangeViaExchangePlan Then
			UnlockDataForEdit(ExchangeComponents.CorrespondentNode);
		EndIf;
		
		ErrorMessage = DetailErrorDescription(ErrorInfo());
		
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorMessage);
		DataExchangeXDTOServer.FinishKeepExchangeProtocol(ExchangeComponents);
		
		ExchangeComponents.ExchangeFile = Undefined;
		
		Raise ErrorMessage;
	EndTry;
	
	ExchangeComponents.ExchangeFile.Close();
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure, ExchangeComponents);
	
	If ExchangeComponents.ErrorFlag Then
		
		ErrorMessage = ExchangeComponents.ErrorMessageString;
		Raise ErrorMessage;
		
	Else
		
		// Put file in temporary storage.
		TempStorageFileID = String(DataExchangeServer.PutFileInStorage(FullFileName));
		
		// Creating the temporary directory for storing data file parts.
		TemporaryDirectory                     = TemporaryExportDirectory(
			TempStorageFileID);
		SharedFileName               = CommonClientServer.GetFullFileName(
			TemporaryDirectory, TempStorageFileID + ?(WebServiceParameters.FilePartSize > 0, ".zip", ".zip.1"));
		SourceFileNameInTemporaryDirectory = CommonClientServer.GetFullFileName(
			TemporaryDirectory, "data.xml");
		
		CreateDirectory(TemporaryDirectory);
		FileCopy(FullFileName, SourceFileNameInTemporaryDirectory);
		
		// Archiving the file.
		Archiver = New ZipFileWriter(SharedFileName);
		Archiver.Add(SourceFileNameInTemporaryDirectory);
		Archiver.Write();
		
		If WebServiceParameters.FilePartSize > 0 Then
			// Splitting file into parts.
			FileNames = SplitFile(SharedFileName, WebServiceParameters.FilePartSize * 1024);
		Else
			FileNames = New Array();
			FileNames.Add(SharedFileName);
		EndIf;
		
		ReturnValue = "{WEBService}$%1$%2";
		ReturnValue = StringFunctionsClientServer.SubstituteParametersToString(ReturnValue, FileNames.Count(), TempStorageFileID);
		
		Message = New UserMessage();
		Message.Text = ReturnValue;
		Message.Message();
		
	EndIf;
	
EndProcedure

Procedure ImportXDTODateToInfobase(ProcedureParameters, StorageAddress) Export
	
	WebServiceParameters = ProcedureParameters["WebServiceParameters"];
	ErrorMessage   = ProcedureParameters["ErrorMessage"];
	
	SetPrivilegedMode(True);
	
	ExchangeComponents = ExchangeComponents("Get", WebServiceParameters);
	
	If ExchangeComponents.ErrorFlag Then
		ErrorMessage = ExchangeComponents.ErrorMessageString;
		Raise ErrorMessage;
	EndIf;
	
	ExchangeSettingsStructure = ExchangeSettingsStructure(ExchangeComponents, Enums.ActionsOnExchange.DataImport);
	
	DisableAccessKeysUpdate(True);
	Try
		DataExchangeXDTOServer.ReadData(ExchangeComponents);
	Except
		Information = ErrorInfo();
		ErrorMessage = NStr("ru = 'Ошибка при загрузке данных: %1'; en = 'Error importing data: %1'; pl = 'Wystąpił błąd podczas importu danych: %1';es_ES = 'Ha ocurrido un error al importar los datos: %1';es_CO = 'Ha ocurrido un error al importar los datos: %1';tr = 'Veri içe aktarılırken bir hata oluştu: %1';it = 'Errore durante l''importazione dati: %1';de = 'Beim Importieren von Daten ist ein Fehler aufgetreten: %1'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorMessage,
			DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorMessage, , , , , True);
		ExchangeComponents.ErrorFlag = True;
	EndTry;
	
	Try
		DataExchangeXDTOServer.DeleteTemporaryObjectsCreatedByRefs(ExchangeComponents);
	Except
		Information = ErrorInfo();
		ErrorMessage = NStr("ru = 'Ошибка при удалении временных объектов, созданных по ссылкам: %1'; en = 'An error occurred when deleting temporary objects created by the links: %1'; pl = 'Błąd podczas usuwania tymczasowych obiektów, utworzonych według linków: %1';es_ES = 'Error al eliminar los objetos temporales creados por enlaces: %1';es_CO = 'Error al eliminar los objetos temporales creados por enlaces: %1';tr = 'Referanslara göre oluşturulan geçici nesneler kaldırılırken bir hata oluştu: %1';it = 'Un errore si è registrato durante l''eliminazione degli oggetti temporanei creati dai collegamenti: %1';de = 'Fehler beim Löschen von temporären Objekten, die durch Links erstellt wurden: %1'");
		ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(
			ErrorMessage,
			DetailErrorDescription(Information));
		DataExchangeXDTOServer.WriteToExecutionProtocol(ExchangeComponents, ErrorMessage, , , , , True);
		ExchangeComponents.ErrorFlag = True;
	EndTry;
	DisableAccessKeysUpdate(False);
	
	ExchangeComponents.ExchangeFile.Close();
	
	AddExchangeFinishEventLogMessage(ExchangeSettingsStructure, ExchangeComponents);
	
	If ExchangeComponents.ErrorFlag Then
		Raise ExchangeComponents.ErrorMessageString;
	EndIf;
	
	If Not ExchangeComponents.ErrorFlag 
		AND ExchangeComponents.IsExchangeViaExchangePlan
		AND ExchangeComponents.UseAcknowledgement Then
		
		// Writing information on the incoming message number.
		NodeObject = ExchangeComponents.CorrespondentNode.GetObject();
		NodeObject.ReceivedNo = ExchangeComponents.IncomingMessageNumber;
		NodeObject.AdditionalProperties.Insert("GettingExchangeMessage");
		NodeObject.Write();
		
	EndIf;
	
EndProcedure

Function TemporaryExportDirectory(Val SessionID) Export
	
	SetPrivilegedMode(True);
	
	TemporaryDirectory = "{SessionID}";
	TemporaryDirectory = StrReplace(TemporaryDirectory, "SessionID", String(SessionID));
	
	Result = CommonClientServer.GetFullFileName(DataExchangeCached.TempFilesStorageDirectory(), TemporaryDirectory);
	
	Return Result;
	
EndFunction

Procedure CheckCanSynchronizeData() Export
	
	If Not AccessRight("View", Metadata.CommonCommands.Synchronize) Then
		
		Raise NStr("ru = 'Недостаточно прав для синхронизации данных.'; en = 'Insufficient rights to perform the data synchronization.'; pl = 'Niewystarczające uprawnienia do synchronizacji danych.';es_ES = 'Insuficientes derechos para sincronizar los datos.';es_CO = 'Insuficientes derechos para sincronizar los datos.';tr = 'Veri senkronizasyonu için yetersiz haklar.';it = 'Permessi insufficienti per eseguire la sincronizzazione dati.';de = 'Unzureichende Rechte für die Datensynchronisierung.'");
		
	ElsIf InfobaseUpdate.InfobaseUpdateRequired()
		AND Not DataExchangeServerCall.DataExchangeMessageImportModeBeforeStart("ImportPermitted") Then
		
		Raise NStr("ru = 'Информационная база находится в состоянии обновления.'; en = 'Current infobase is updating now.'; pl = 'Baza informacyjna została zaktualizowana.';es_ES = 'Infobase se está actualizando.';es_CO = 'Infobase se está actualizando.';tr = 'Veritabanı güncelleniyor.';it = 'L''infobase corrente è in aggiornamento al momento.';de = 'Infobase wird aktualisiert.'");
		
	EndIf;
	
EndProcedure

Procedure CheckInfobaseLockForUpdate() Export
	
	If ValueIsFilled(InfobaseUpdateInternal.InfobaseLockedForUpdate()) Then
		
		Raise NStr("ru = 'Синхронизация данных временно недоступна в связи с обновлением приложения.'; en = 'Data synchronization is temporary unavailable due to the application update.'; pl = 'Synchronizacja danych tymczasowo jest niedostępna w związku z aktualizacją aplikacji.';es_ES = 'La sincronización de datos no está disponible temporalmente debido a la actualización de la aplicación.';es_CO = 'La sincronización de datos no está disponible temporalmente debido a la actualización de la aplicación.';tr = 'Çevrimiçi uygulama güncellemesi nedeniyle veri senkronizasyonu geçici olarak kullanılamıyor.';it = 'La sincronizzazione dati è temporaneamente non disponibile a causa dell''aggiornamento dell''applicazione.';de = 'Die Datensynchronisation ist aufgrund von Anwendungsaktualisierungen vorübergehend nicht möglich.'");
		
	EndIf;
	
EndProcedure

Function GetDataReceiptExecutionStatus(TimeConsumingOperationID, ErrorMessage) Export
	
	ErrorMessage = "";
	
	SetPrivilegedMode(True);
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(TimeConsumingOperationID));
	
	BackgroundJobStates = BackgroundJobsStatuses();
	If BackgroundJob = Undefined Then
		CurrentBackgroundJobStatus = BackgroundJobStates.Get(BackgroundJobState.Canceled);
	Else
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			ErrorMessage = DetailErrorDescription(BackgroundJob.ErrorInfo);
		EndIf;
		CurrentBackgroundJobStatus = BackgroundJobStates.Get(BackgroundJob.State)
		
	EndIf;
	
	Return CurrentBackgroundJobStatus;
	
EndFunction

Function GetExecutionStatusOfPreparingDataForSending(BackgroundJobID, ErrorMessage) Export
	
	ErrorMessage = "";
	
	SetPrivilegedMode(True);
	
	ReturnedStructure = XDTOFactory.Create(
		XDTOFactory.Type("http://v8.1c.ru/SSL/Exchange/EnterpriseDataExchange", "PrepareDataOperationResult"));
	
	BackgroundJob = BackgroundJobs.FindByUUID(New UUID(BackgroundJobID));
	
	If BackgroundJob = Undefined Then
		CurrentBackgroundJobStatus = BackgroundJobsStatuses().Get(BackgroundJobState.Canceled);
	Else
	
		ErrorMessage        = "";
		FilePartsCount    = 0;
		FileID       = "";
		CurrentBackgroundJobStatus = BackgroundJobsStatuses().Get(BackgroundJob.State);
		
		If BackgroundJob.ErrorInfo <> Undefined Then
			ErrorMessage = DetailErrorDescription(BackgroundJob.ErrorInfo);
		Else
			If BackgroundJob.State = BackgroundJobState.Completed Then
				MessagesArray  = BackgroundJob.GetUserMessages(True);
				For Each BackgroundJobMessage In MessagesArray Do
					If StrFind(BackgroundJobMessage.Text, "{WEBService}") > 0 Then
						ResultArray = StrSplit(BackgroundJobMessage.Text, "$", True);
						FilePartsCount = ResultArray[1];
						FileID    = ResultArray[2];
						Break;
					Else
						Continue;
					EndIf;
				EndDo;
			EndIf;
		EndIf;
	EndIf;
	
	ReturnedStructure.ErrorMessage = ErrorMessage;
	ReturnedStructure.FileID       = FileID;
	ReturnedStructure.PartCount    = FilePartsCount;
	ReturnedStructure.Status       = CurrentBackgroundJobStatus;
	
	Return ReturnedStructure;
	
EndFunction

Function InitializeWebServiceParameters() Export
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("ExchangePlanName");
	ParametersStructure.Insert("ExchangePlanNodeCode");
	ParametersStructure.Insert("TempStorageFileID");
	ParametersStructure.Insert("FilePartSize");
	ParametersStructure.Insert("WEBServiceName");

	Return ParametersStructure;
	
EndFunction

Procedure DisableAccessKeysUpdate(Disable, ScheduleUpdate = True) Export
	
	If Common.SubsystemExists("StandardSubsystems.AccessManagement") Then
		ModuleAccessManagement = Common.CommonModule("AccessManagement");
		ModuleAccessManagement.DisableAccessKeysUpdate(Disable, ScheduleUpdate);
	EndIf;
	
EndProcedure

Procedure PutMessageForDataMapping(ExchangeNode, MessageID) Export
	
	// Previous message are deleted to map data.
	Filter = New Structure("InfobaseNode", ExchangeNode);
	CommonSettings = InformationRegisters.CommonInfobasesNodesSettings.Get(Filter);
	
	If ValueIsFilled(CommonSettings.MessageForDataMapping) Then
		TempFileName = DataExchangeServer.GetFileFromStorage(CommonSettings.MessageForDataMapping);
		File = New File(TempFileName);
		If File.Exist() AND File.IsFile() Then
			Try
				DeleteFiles(TempFileName);
			Except
				// Returning file information to the temporary storage for further deletion via the scheduled job.
				// 
				DataExchangeServer.PutFileInStorage(TempFileName, CommonSettings.MessageForDataMapping);
			EndTry;
		EndIf;
	EndIf;
	
	InformationRegisters.CommonInfobasesNodesSettings.PutMessageForDataMapping(
		ExchangeNode, MessageID);
	
EndProcedure

#EndRegion

#Region Private

Function ExchangeComponents(ExchangeDirection, WebServiceParameters)
	
	ExchangeComponents = DataExchangeXDTOServer.InitializeExchangeComponents(ExchangeDirection);
	
	If ValueIsFilled(WebServiceParameters.ExchangePlanName) AND ValueIsFilled(WebServiceParameters.ExchangePlanNodeCode) Then
		ExchangeComponents.CorrespondentNode = ExchangePlans[WebServiceParameters.ExchangePlanName].FindByCode(WebServiceParameters.ExchangePlanNodeCode);
	Else
		ExchangeComponents.IsExchangeViaExchangePlan = False;
	EndIf;
	
	ExchangeComponents.KeepDataProtocol.OutputInfoMessagesToProtocol = False;
	ExchangeComponents.DataExchangeState.StartDate = CurrentSessionDate();
	ExchangeComponents.UseTransactions = False;

	If ExchangeDirection = "Get" Then
		
		ExchangeComponents.EventLogMessageKey = GenerateEventLogMessageKey(ExchangeDirection, WebServiceParameters);
		
		FileName = DataExchangeServer.GetFileFromStorage(WebServiceParameters.TempStorageFileID);
		DataExchangeXDTOServer.OpenImportFile(ExchangeComponents, FileName);
		
	Else
		
		ExchangeComponents.EventLogMessageKey   = GenerateEventLogMessageKey(ExchangeDirection, WebServiceParameters);
		ExchangeComponents.ExchangeFormatVersion               = DataExchangeXDTOServer.ExchangeFormatVersionOnImport(
			ExchangeComponents.CorrespondentNode);
		ExchangeComponents.XMLSchema                          = DataExchangeXDTOServer.ExchangeFormat(
			WebServiceParameters.ExchangePlanName, ExchangeComponents.ExchangeFormatVersion);
		ExchangeComponents.ExchangeManager                    = DataExchangeXDTOServer.FormatVersionExchangeManager(
			ExchangeComponents.ExchangeFormatVersion, ExchangeComponents.CorrespondentNode);
		ExchangeComponents.ObjectsRegistrationRulesTable = DataExchangeXDTOServer.ObjectsRegistrationRules(
			ExchangeComponents.CorrespondentNode);
		ExchangeComponents.ExchangePlanNodeProperties           = DataExchangeXDTOServer.ExchangePlanNodeProperties(
			ExchangeComponents.CorrespondentNode);
		
	EndIf;
	
	If ExchangeComponents.ErrorFlag Then
		Return ExchangeComponents;
	EndIf;
	
	DataExchangeXDTOServer.InitializeExchangeRulesTables(ExchangeComponents);
	
	If ExchangeComponents.IsExchangeViaExchangePlan Then
		DataExchangeXDTOServer.FillXDTOSettingsStructure(ExchangeComponents);
		DataExchangeXDTOServer.FillSupportedXDTODataObjects(ExchangeComponents);
	EndIf;
	
	Return ExchangeComponents;
	
EndFunction

Function GetFilePartName(FilePartNumber, ArchiveName = "")
	
	If Not ValueIsFilled(ArchiveName) Then
		ArchiveName = "data";
	EndIf;
	
	Result = StringFunctionsClientServer.SubstituteParametersToString("%1.zip.%2", ArchiveName, Format(FilePartNumber, "NG=0"));
	
	Return Result;
	
EndFunction

Function BackgroundJobsStatuses()
	
	BackgroundJobStates = New Map;
	BackgroundJobStates.Insert(BackgroundJobState.Active,           "Active");
	BackgroundJobStates.Insert(BackgroundJobState.Completed,         "Completed");
	BackgroundJobStates.Insert(BackgroundJobState.Failed, "Failed");
	BackgroundJobStates.Insert(BackgroundJobState.Canceled,          "Canceled");
	
	Return BackgroundJobStates;
	
EndFunction

Function GenerateEventLogMessageKey(ExchangeDirection, WebServiceParameters)
	
	If ExchangeDirection = "Get" Then
		MessageKeyTemplate = NStr("ru = 'Загрузка данных через Web-сервис %1'; en = 'Data import through web service %1'; pl = 'Pobieranie danych poprzez Web-serwis %1';es_ES = 'Descarga de datos a través el servidor Web %1';es_CO = 'Descarga de datos a través el servidor Web %1';tr = 'Verilerin Web-hizmet üzerinden içe aktarılması%1';it = 'Importazione dati attraverso webservice %1';de = 'Daten-Import über den Webservice %1'", CommonClientServer.DefaultLanguageCode());
	Else
		MessageKeyTemplate = NStr("ru = 'Выгрузка данных через Web-сервис %1'; en = 'Export data through web service %1'; pl = 'Pobieranie danych poprzez Web-serwis %1';es_ES = 'Subida de datos a través el servidor Web %1';es_CO = 'Subida de datos a través el servidor Web %1';tr = 'Verilerin Web-hizmet üzerinden dışa aktarılması%1';it = 'Esportazione dati attraverso webservice %1';de = 'Daten-Export über den Webservice %1'", CommonClientServer.DefaultLanguageCode());
	EndIf;
	
	Return StringFunctionsClientServer.SubstituteParametersToString(MessageKeyTemplate, WebServiceParameters.WEBServiceName);
	
EndFunction

Function ExchangeSettingsStructure(ExchangeComponents, DataExchangeAction)
	
	If Not ExchangeComponents.IsExchangeViaExchangePlan Then
		Return Undefined;
	EndIf;
	
	ExchangeSettingsStructure = DataExchangeCached.ExchangeSettingsOfInfobaseNode(
		ExchangeComponents.CorrespondentNode, DataExchangeAction, Undefined, False);
		
	If ExchangeSettingsStructure.Cancel Then
		ErrorMessageString = NStr("ru = 'Ошибка при инициализации процесса обмена данными.'; en = 'Error initializing data exchange process.'; pl = 'Podczas inicjowania procesu wymiany danych wystąpił błąd.';es_ES = 'Ha ocurrido un error al iniciar el proceso de intercambio de datos.';es_CO = 'Ha ocurrido un error al iniciar el proceso de intercambio de datos.';tr = 'Veri alışverişi sürecini başlatırken bir hata oluştu.';it = 'Errore durante l''inizializzazione del processo di scambio dati.';de = 'Bei der Initialisierung des Datenaustauschprozesses ist ein Fehler aufgetreten.'");
		DataExchangeServer.AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
		Raise ErrorMessageString;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult = Undefined;
	ExchangeSettingsStructure.StartDate = CurrentSessionDate();
	
	MessageString = NStr("ru = 'Начало процесса обмена данными для узла %1'; en = 'Data exchange process started for %1 node'; pl = 'Początek procesu wymiany danych dla węzła %1';es_ES = 'Inicio de proceso de intercambio de datos para el nodo %1';es_CO = 'Inicio de proceso de intercambio de datos para el nodo %1';tr = '%1Ünite için veri değişimi süreci başlatılıyor';it = 'Il processo di scambio dati iniziato per il nodo %1';de = 'Datenaustausch beginnt für Knoten %1'", CommonClientServer.DefaultLanguageCode());
	MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, ExchangeSettingsStructure.InfobaseNodeDescription);
	
	WriteLogEvent(ExchangeSettingsStructure.EventLogMessageKey, 
		EventLogLevel.Information,
		ExchangeSettingsStructure.InfobaseNode.Metadata(),
		ExchangeSettingsStructure.InfobaseNode,
		MessageString);
		
	Return ExchangeSettingsStructure;
	
EndFunction

Procedure AddExchangeFinishEventLogMessage(ExchangeSettingsStructure, ExchangeComponents)
	
	If Not ExchangeComponents.IsExchangeViaExchangePlan Then
		Return;
	EndIf;
	
	ExchangeSettingsStructure.ExchangeExecutionResult    = ExchangeComponents.DataExchangeState.ExchangeExecutionResult;
	
	If ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataExport Then
		ExchangeSettingsStructure.ProcessedObjectsCount = ExchangeComponents.ExportedObjectCounter;
		ExchangeSettingsStructure.MessageOnExchange           = ExchangeSettingsStructure.DataExchangeDataProcessor.CommentOnDataExport;
	ElsIf ExchangeSettingsStructure.ActionOnExchange = Enums.ActionsOnExchange.DataImport Then
		ExchangeSettingsStructure.ProcessedObjectsCount = ExchangeComponents.ImportedObjectCounter;
		ExchangeSettingsStructure.MessageOnExchange           = ExchangeSettingsStructure.DataExchangeDataProcessor.CommentOnDataImport;
	EndIf;
	
	ExchangeSettingsStructure.ErrorMessageString      = ExchangeComponents.ErrorMessageString;
	
	DataExchangeServer.AddExchangeCompletionEventLogMessage(ExchangeSettingsStructure);
	
EndProcedure

#EndRegion