#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables
Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var ErrorsMessages; // Map that contains error messages.
Var ObjectName; // The metadata object name

Var TempExchangeMessageFile; // temporary exchange message file for importing and exporting data.
Var ExchangeMessagesTemporaryDirectory; // Temporary exchange message directory.
Var DataExchangeDirectory; // Network exchange message directory.

Var CatalogID;
#EndRegion

#Region Private

////////////////////////////////////////////////////////////////////////////////
// Internal export procedures and functions.

// Creates a temporary directory in the temporary file directory of the operating system user.
//
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True if the function is executed successfully, False if an error occurred.
// 
Function ExecuteActionsBeforeProcessMessage() Export
	
	InitMessages();
	
	CatalogID = Undefined;
	
	Return CreateTempExchangeMessageDirectory();
	
EndFunction

// Sends the exchange message to the specified resource from the temporary exchange message directory.
//
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True if the function is executed successfully, False if an error occurred.
// 
Function SendMessage() Export
	
	Result = True;
	
	InitMessages();
	
	Try
		
		If UseTempDirectoryToSendAndReceiveMessages Then
			
			Result = SendExchangeMessage();
			
		EndIf;
		
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Gets an exchange message from the specified resource and puts it in the temporary exchange message directory.
//
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True if the function is executed successfully, False if an error occurred.
// 
Function GetMessage(ExistenceCheck = False) Export
	
	InitMessages();
	
	Try
		Result = GetExchangeMessage(ExistenceCheck);
	Except
		Result = False;
	EndTry;
	
	Return Result;
EndFunction

// Deletes the temporary exchange message directory after performing data import and export.
//
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True
//
Function ExecuteActionsAfterProcessMessage() Export
	
	InitMessages();
	
	If UseTempDirectoryToSendAndReceiveMessages Then
		
		DeleteTempExchangeMessageDirectory();
		
	EndIf;
	
	Return True;
EndFunction

// Initializes properties with initial values and constants.
//
// Parameters:
//  No.
// 
Procedure Initializing() Export
	
	DataExchangeDirectory = New File(FILEInformationExchangeDirectory);
	
EndProcedure

// Checking whether the connection to the specified resource can be established.
//
// Parameters:
//  No.
// 
//  Returns:
//  Boolean - True if connection can be established. Otherwise, False.
//
Function ConnectionIsSet() Export
	
	InitMessages();
	
	If IsBlankString(FILEInformationExchangeDirectory) Then
		
		GetErrorMessage(1);
		Return False;
		
	ElsIf Not DataExchangeDirectory.Exist() Then
		
		GetErrorMessage(2);
		Return False;
	EndIf;
	
	CheckFileName = DataExchangeServer.TempConnectionTestFileName();
	
	If Not CreateCheckFile(CheckFileName) Then
		
		GetErrorMessage(8);
		Return False;
		
	ElsIf Not DeleteCheckFiles(CheckFileName) Then
		
		GetErrorMessage(9);
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

// Retrieves the full name of the exchange message file.
//
// Returns:
//  String - the full name of the exchange message file.
//
Function ExchangeMessageFileName() Export
	
	Name = "";
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		Name = TempExchangeMessageFile.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Retrieves the full name of the exchange message directory.
//
// Returns:
//  String - the full name of the exchange message catalog.
//
Function ExchangeMessageCatalogName() Export
	
	Name = "";
	
	If TypeOf(ExchangeMessagesTemporaryDirectory) = Type("File") Then
		
		Name = ExchangeMessagesTemporaryDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Retrieves the full name of the data exchange directory local or network.
//
// Returns:
//  String - the full name of the information exchange directory (local or network).
//
Function DataExchangeDirectoryName() Export
	
	Name = "";
	
	If TypeOf(DataExchangeDirectory) = Type("File") Then
		
		Name = DataExchangeDirectory.FullName;
		
	EndIf;
	
	Return Name;
	
EndFunction

// Function for retrieving property: the time of changing the exchange file message.
//
// Returns:
//  Date - the time of changing the exchange file message.
//
Function ExchangeMessageFileDate() Export
	
	Result = Undefined;
	
	If TypeOf(TempExchangeMessageFile) = Type("File") Then
		
		If TempExchangeMessageFile.Exist() Then
			
			Result = TempExchangeMessageFile.GetModificationTime();
			
		EndIf;
		
	EndIf;
	
	Return Result;
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessageDirectory()
	
	If UseTempDirectoryToSendAndReceiveMessages Then
		
		// Creating the temporary exchange message directory.
		Try
			TempDirectoryName = DataExchangeServer.CreateTempExchangeMessageDirectory(CatalogID);
		Except
			GetErrorMessage(6);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
			Return False;
		EndTry;
		
		ExchangeMessagesTemporaryDirectory = New File(TempDirectoryName);
		
	Else
		
		ExchangeMessagesTemporaryDirectory = New File(DataExchangeDirectoryName());
		
	EndIf;
	
	MessageFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName(), MessageFileNamePattern + ".xml");
	
	TempExchangeMessageFile = New File(MessageFileName);
	
	Return True;
EndFunction

Function DeleteTempExchangeMessageDirectory()
	
	Try
		If Not IsBlankString(ExchangeMessageCatalogName()) Then
			DeleteFiles(ExchangeMessageCatalogName());
			ExchangeMessagesTemporaryDirectory = Undefined;
		EndIf;
		
		If Not CatalogID = Undefined Then
			DataExchangeServer.GetFileFromStorage(CatalogID);
			CatalogID = Undefined;
		EndIf;
	Except
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function SendExchangeMessage()
	
	Result = True;
	
	Extension = ?(CompressOutgoingMessageFile(), "zip", "xml");
	
	OutgoingMessageFileName = CommonClientServer.GetFullFileName(DataExchangeDirectoryName(), MessageFileNamePattern + "." + Extension);
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the temporary archive file name.
		ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName(), MessageFileNamePattern + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ArchivePasswordExchangeMessages, NStr("ru = 'Файл сообщения обмена'; en = 'Exchange message file'; pl = 'Plik komunikatów wymiany';es_ES = 'Archivo de mensaje de intercambio';es_CO = 'Archivo de mensaje de intercambio';tr = 'Alışveriş mesajı dosyası';it = 'File del messaggio di scambio';de = 'Austausch-Nachrichtendatei'"));
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			Result = False;
			GetErrorMessage(5);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Copying the archive file to the data exchange directory.
			If Not ExecuteFileCopying(ArchiveTempFileName, OutgoingMessageFileName) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	Else
		
		// Copying the message file to the data exchange directory.
		If Not ExecuteFileCopying(ExchangeMessageFileName(), OutgoingMessageFileName) Then
			Result = False;
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage(ExistenceCheck)
	
	ExchangeMessageFileTable = New ValueTable;
	ExchangeMessageFileTable.Columns.Add("File", New TypeDescription("File"));
	ExchangeMessageFileTable.Columns.Add("Modified");
	MessageFileNameTemplateForSearch = StrReplace(MessageFileNamePattern, "Message", "Message*");
	
	FoundFileArray = FindFiles(DataExchangeDirectoryName(), MessageFileNameTemplateForSearch + ".*", False);
	
	For Each CurrentFile In FoundFileArray Do
		
		// Checking the required extension.
		If ((Upper(CurrentFile.Extension) <> ".ZIP")
			AND (Upper(CurrentFile.Extension) <> ".XML")) Then
			
			Continue;
			
		// Checking that it is a file, not a directory.
		ElsIf NOT CurrentFile.IsFile() Then
			
			Continue;
			
		// Checking that the file size is greater than 0.
		ElsIf (CurrentFile.Size() = 0) Then
			
			Continue;
			
		EndIf;
		
		// The file is a required exchange message. Adding the file to the table.
		TableRow = ExchangeMessageFileTable.Add();
		TableRow.File           = CurrentFile;
		TableRow.Modified = CurrentFile.GetModificationTime();
	EndDo;
	
	If ExchangeMessageFileTable.Count() = 0 Then
		
		If Not ExistenceCheck Then
			GetErrorMessage(3);
		
			MessageString = NStr("ru = 'Каталог обмена информацией: ""%1""'; en = 'Data exchange directory is %1'; pl = 'Katalog wymiany informacją: ""%1""';es_ES = 'Directorio de intercambio de datos: ""%1""';es_CO = 'Directorio de intercambio de datos: ""%1""';tr = 'Veri alışverişi dizini: ""%1""';it = 'La directory per lo scambio di dati è %1';de = 'Datenaustauschverzeichnis: ""%1""'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, DataExchangeDirectoryName());
			SupplementErrorMessage(MessageString);
			
			MessageString = NStr("ru = 'Имя файла сообщения обмена: ""%1"" или ""%2""'; en = 'Exchange message file name is %1 or %2'; pl = 'Nazwa pliku wiadomości wymiany: ""%1"" lub ""%2""';es_ES = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';es_CO = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';tr = 'Veri alışverişi dosyasının adı: ""%1"" veya ""%2""';it = 'Il nome file del messaggio di scambio è %1 oppure %2';de = 'Name der Austausch-Nachrichtendatei: ""%1"" oder ""%2""'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, MessageFileNameTemplateForSearch + ".xml", MessageFileNameTemplateForSearch + ".zip");
			SupplementErrorMessage(MessageString);
		EndIf;
		
		Return False;
		
	Else
		
		If ExistenceCheck Then
			Return True;
		EndIf;
		
		ExchangeMessageFileTable.Sort("Modified Desc");
		
		// Obtaining the newest exchange message file from the table.
		IncomingMessageFile = ExchangeMessageFileTable[0].File;
		FilePacked = (Upper(IncomingMessageFile.Extension) = ".ZIP");
		If NOT StrStartsWith(IncomingMessageFile.Name, MessageFileNamePattern) Then
			// The fule does not fully match the template. Reassign template for the correct operation.
			FileNameStructure = CommonClientServer.ParseFullFileName(IncomingMessageFile.Name,False);
			MessageFileNamePattern = FileNameStructure.BaseName;
		EndIf;
		
		
		If FilePacked Then
			
			// Getting the temporary archive file name.
			ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName(), MessageFileNamePattern + ".zip");
			
			// Copy the archive file from the network directory to the temporary one.
			If Not ExecuteFileCopying(IncomingMessageFile.FullName, ArchiveTempFileName) Then
				Return False;
			EndIf;
			
			// Unpacking the temporary archive file.
			SuccessfullyUnpacked = DataExchangeServer.UnpackZipFile(ArchiveTempFileName, ExchangeMessageCatalogName(), ArchivePasswordExchangeMessages);
			
			If Not SuccessfullyUnpacked Then
				GetErrorMessage(4);
				Return False;
			EndIf;
			
			// Checking that the message file exists.
			File = New File(ExchangeMessageFileName());
			
			If Not File.Exist() Then
				// The archive name probably does not match name of the file inside.
				ArchiveFileNameStructure = CommonClientServer.ParseFullFileName(IncomingMessageFile.Name,False);
				MessageFileNameStructure = CommonClientServer.ParseFullFileName(ExchangeMessageFileName(),False);

				If ArchiveFileNameStructure.BaseName <> MessageFileNameStructure.BaseName Then
					UnpackedFilesArray = FindFiles(ExchangeMessageCatalogName(), "*.xml", False);
					If UnpackedFilesArray.Count() > 0 Then
						UnpackedFile = UnpackedFilesArray[0];
						MoveFile(UnpackedFile.FullName,ExchangeMessageFileName());
					Else
						GetErrorMessage(7);
						Return False;
					EndIf;
				Else
					GetErrorMessage(7);
					Return False;
				EndIf;
				
			EndIf;
			
		Else
			
			// Copy the file of the incoming message from the exchange directory to the temporary file directory.
			If UseTempDirectoryToSendAndReceiveMessages AND Not ExecuteFileCopying(IncomingMessageFile.FullName, ExchangeMessageFileName()) Then
				
				Return False;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return True;
EndFunction

Function CreateCheckFile(CheckFileName)
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("ru = 'Временный файл проверки'; en = 'Temporary file for checking access to directory'; pl = 'Tymczasowy plik sprawdzenia';es_ES = 'Archivo de revisión temporal';es_CO = 'Archivo de revisión temporal';tr = 'Geçici kontrol dosyası';it = 'File temporaneo per controllare l''accesso alla directory';de = 'Temporäre Prüfdatei'"));
	
	Try
		
		TextDocument.Write(CommonClientServer.GetFullFileName(DataExchangeDirectoryName(), CheckFileName));
		
	Except
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function DeleteCheckFiles(CheckFileName)
	
	Try
		
		DeleteFiles(DataExchangeDirectoryName(), CheckFileName);
		
	Except
		WriteLogEvent(DataExchangeServer.EventLogMessageTextDataExchange(), EventLogLevel.Error,,, DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
EndFunction

Function ExecuteFileCopying(Val SourceFileName, Val DestinationFileName)
	
	Try
		
		DeleteFiles(DestinationFileName);
		FileCopy(SourceFileName, DestinationFileName);
		
	Except
		
		MessageString = NStr("ru = 'Ошибка при копировании файла из %1 в %2. Описание ошибки: %3'; en = 'An error occurred when copying a file from %1 to %2. Error description: %3'; pl = 'Wystąpił błąd podczas kopiowania pliku z %1 na %2. Opis błędu: %3';es_ES = 'Ha ocurrido un error al copiar un archivo desde %1 para %2. Descripción del error: %3';es_CO = 'Ha ocurrido un error al copiar un archivo desde %1 para %2. Descripción del error: %3';tr = 'Bir dosya %1 2''den %2''e kopyalandığında bir hata oluştu. Hata tanımlaması: %3';it = 'Si è registrato un errore copiando i file %1 in %2. Descrizione errore: %3';de = 'Beim Kopieren einer Datei von %1 in %2 ist ein Fehler aufgetreten. Fehlerbeschreibung: %3'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString,
							SourceFileName,
							DestinationFileName,
							BriefErrorDescription(ErrorInfo()));
		SetErrorMessageString(MessageString);
		
		Return False
		
	EndTry;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNumber)
	
	SetErrorMessageString(ErrorsMessages[MessageNumber])
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = NStr("ru = 'Внутренняя ошибка'; en = 'Internal error'; pl = 'Błąd zewnętrzny';es_ES = 'Error interno';es_CO = 'Error interno';tr = 'Dahili hata';it = 'Errore interno';de = 'Interner Fehler'");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = ObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

Function CompressOutgoingMessageFile()
	
	Return FILECompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	ErrorsMessages = New Map;
	ErrorsMessages.Insert(1, NStr("ru = 'Ошибка подключения: Не указан каталог обмена информацией.'; en = 'Connection error: The data exchange directory is not specified.'; pl = 'Błąd połączenia: katalog wymiany informacji nie został określony.';es_ES = 'Error de conexión: Directorio de intercambio de información no está especificado.';es_CO = 'Error de conexión: Directorio de intercambio de información no está especificado.';tr = 'Bağlantı hatası: Veri alışverişi dizini belirtilmedi.';it = 'Errore di connessione: La directory di scambio dati non è specificata.';de = 'Verbindungsfehler: Verzeichnis für den Informationsaustausch wurde nicht angegeben.'"));
	ErrorsMessages.Insert(2, NStr("ru = 'Ошибка подключения: Каталог обмена информацией не существует.'; en = 'Connection error: The data exchange directory does not exist.'; pl = 'Błąd połączenia: katalog wymiany informacji nie istnieje.';es_ES = 'Error de conexión: Directorio de intercambio de información no existe.';es_CO = 'Error de conexión: Directorio de intercambio de información no existe.';tr = 'Bağlantı hatası: Veri alışverişi dizini mevcut değil.';it = 'Errore di connessione: La directory di scambio dati non esiste.';de = 'Verbindungsfehler: Verzeichnis für den Informationsaustausch existiert nicht.'"));
	
	ErrorsMessages.Insert(3, NStr("ru = 'В каталоге обмена информацией не был обнаружен файл сообщения с данными.'; en = 'No message file with data was found in the exchange directory.'; pl = 'W katalogu wymiany informacji nie znaleziono pliku wiadomości z danymi.';es_ES = 'Directorio de intercambio de información no contiene un archivo de mensajes con datos.';es_CO = 'Directorio de intercambio de información no contiene un archivo de mensajes con datos.';tr = 'Veri alışverişi dizininde veri mesajı dosyası bulundu.';it = 'Nessun file di messaggio con dati è stato trovato nella directory di scambio.';de = 'Das Verzeichnis für den Informationsaustausch enthält keine Nachrichtendatei mit Daten.'"));
	ErrorsMessages.Insert(4, NStr("ru = 'Ошибка при распаковке сжатого файла сообщения.'; en = 'Error unpacking the exchange message file.'; pl = 'Podczas rozpakowywania skompresowanego pliku wiadomości wystąpił błąd.';es_ES = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';es_CO = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';tr = 'Sıkıştırılmış mesaj dosyası açılırken bir hata oluştu.';it = 'Errore durante la decompressione del file di scambio messaggio.';de = 'Beim Entpacken einer komprimierten Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(5, NStr("ru = 'Ошибка при сжатии файла сообщения обмена.'; en = 'Error packing the exchange message file.'; pl = 'Błąd podczas kompresji pliku wiadomości wymiany.';es_ES = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';es_CO = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';tr = 'Veri alışverişi mesajı dosyası sıkıştırılırken bir hata oluştu.';it = 'Errore durante la compressione del file di scambio messaggio.';de = 'Beim Komprimieren der Austausch-Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(6, NStr("ru = 'Ошибка при создании временного каталога'; en = 'An error occurred when creating a temporary directory'; pl = 'Wystąpił błąd podczas tworzenia katalogu tymczasowego';es_ES = 'Ha ocurrido un error al crear un directorio temporal';es_CO = 'Ha ocurrido un error al crear un directorio temporal';tr = 'Geçici dizin oluşturulurken bir hata oluştu.';it = 'Si è verificato un errore durante la creazione di una directory temporanea';de = 'Beim Erstellen eines temporären Verzeichnisses ist ein Fehler aufgetreten'"));
	ErrorsMessages.Insert(7, NStr("ru = 'Архив не содержит файл сообщения обмена'; en = 'The archive does not contain the exchange message file'; pl = 'Archiwum nie zawiera pliku wiadomości wymiany';es_ES = 'Archivo con incluye un archivo de mensajes de intercambio';es_CO = 'Archivo con incluye un archivo de mensajes de intercambio';tr = 'Arşiv, veri alışveriş mesajı dosyasını içermiyor.';it = 'L''archivio non contiene il file del messaggio di scambio.';de = 'Das Archiv enthält keine Austauschnachrichtendatei'"));
	
	ErrorsMessages.Insert(8, NStr("ru = 'Ошибка записи файла в каталог обмена информацией. Проверьте права пользователя на доступ к каталогу.'; en = 'An error occurred when writing the file to the information exchange directory. Check if the user is authorized to access the directory.'; pl = 'Wystąpił błąd podczas zapisywania pliku w katalogu wymiany informacji. Sprawdź, czy użytkownik ma uprawnienia dostępu do katalogu.';es_ES = 'Ha ocurrido un error al grabar el archivo en el directorio de intercambio de información. Revisar si el usuario está autorizado para acceder el directorio.';es_CO = 'Ha ocurrido un error al grabar el archivo en el directorio de intercambio de información. Revisar si el usuario está autorizado para acceder el directorio.';tr = 'Dosya veri alışverişi dizinine yazılırken bir hata oluştu. Kullanıcının dizine erişme yetkisi olup olmadığını kontrol edin.';it = 'Si è verificato un errore durante la scrittura di un file nella directory dello scambio di informazioni. Verifica le autorizzazioni dell''utente per accedere alla directory.';de = 'Beim Schreiben der Datei in das Verzeichnis für den Informationsaustausch ist ein Fehler aufgetreten. Überprüfen Sie, ob der Benutzer berechtigt ist, auf das Verzeichnis zuzugreifen.'"));
	ErrorsMessages.Insert(9, NStr("ru = 'Ошибка удаления файла из каталога обмена информацией. Проверьте права пользователя на доступ к каталогу.'; en = 'An error occurred when removing a file from the information exchange directory. Check user access rights to the directory.'; pl = 'Wystąpił błąd podczas usuwania pliku z katalogu wymiany informacji. Sprawdź prawa dostępu użytkownika do katalogu.';es_ES = 'Ha ocurrido un error al sacar un archivo del directorio de intercambio de información. Revisar los derechos de acceso del usuario al directorio.';es_CO = 'Ha ocurrido un error al sacar un archivo del directorio de intercambio de información. Revisar los derechos de acceso del usuario al directorio.';tr = 'Dosya veri alışverişi dizininden kaldırılırken bir hata oluştu. Kullanıcının dizine erişme yetkisi olup olmadığını kontrol edin.';it = 'Si è verificato un errore durante l''eliminazione del file dalla directory dello scambio di informazioni. Verifica le autorizzazioni dell''utente per accedere alla directory.';de = 'Beim Entfernen einer Datei aus dem Verzeichnis für den Informationsaustausch ist ein Fehler aufgetreten. Überprüfen Sie die Benutzerzugriffsrechte für das Verzeichnis.'"));
	
EndProcedure

#EndRegion

#Region Initializing

InitMessages();
ErrorMessageInitialization();

ExchangeMessagesTemporaryDirectory = Undefined;
TempExchangeMessageFile    = Undefined;

ObjectName = NStr("ru = 'Обработка: %1'; en = 'Data processor: %1'; pl = 'Opracowanie: %1';es_ES = 'Procesador de datos: %1';es_CO = 'Procesador de datos: %1';tr = 'Veri işlemcisi: %1';it = 'Elaboratore dati: %1';de = 'Datenprozessor: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersToString(ObjectName, Metadata().Name);

#EndRegion

#EndIf
