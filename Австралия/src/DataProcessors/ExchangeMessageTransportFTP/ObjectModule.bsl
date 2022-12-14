#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Variables
Var ErrorMessageString Export;
Var ErrorMessageStringEL Export;

Var ErrorsMessages; // Map that contains predefined error messages.
Var ObjectName;		// The metadata object name
Var FTPServerName;		// FTP server address is a name or address.
Var DirectoryAtFTPServer;// Directory on server for storing and receiving exchange messages.

Var TempExchangeMessageFile; // Temporary exchange message file for importing and exporting data.
Var ExchangeMessagesTemporaryDirectory; // Temporary exchange message directory.

Var SendGetDataTimeout; // Timeout that is used for FTP connection when sending and receiving data.

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
	
	InitMessages();
	
	Try
		Result = SendExchangeMessage();
	Except
		Result = False;
	EndTry;
	
	Return Result;
	
EndFunction

// Gets an exchange message from the specified resource and puts it in the temporary exchange message directory.
//
// Parameters:
//  ExistenceCheck - Boolean - True if it is necessary to check whether exchange messages exist without their import.
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
	
	DeleteTempExchangeMessageDirectory();
	
	Return True;
	
EndFunction

// Initializes properties with initial values and constants.
//
// Parameters:
//  No.
// 
Procedure Initializing() Export
	
	InitMessages();
	
	ServerNameAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	FTPServerName			= ServerNameAndDirectoryAtServer.ServerName;
	DirectoryAtFTPServer	= ServerNameAndDirectoryAtServer.DirectoryName;
	
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
	
	// Function return value.
	Result = True;
	
	InitMessages();
	
	If IsBlankString(FTPConnectionPath) Then
		
		GetErrorMessage(101);
		Return False;
		
	EndIf;
	
	// Creating a file in the temporary directory.
	TempConnectionTestFileName = GetTempFileName("tmp");
	FileNameForDestination = DataExchangeServer.TempConnectionTestFileName();
	
	TextWriter = New TextWriter(TempConnectionTestFileName);
	TextWriter.WriteLine(FileNameForDestination);
	TextWriter.Close();
	
	// Coping the file to the external resource from the temporary directory.
	Result = CopyFileToFTPServer(TempConnectionTestFileName, FileNameForDestination, 10);
	
	// Deleting file from the external resource.
	If Result Then
		
		Result = DeleteFileAtFTPServer(FileNameForDestination, True);
		
	EndIf;
	
	// Deleting file from the temporary directory.
	DeleteFiles(TempConnectionTestFileName);
	
	Return Result;
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

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

///////////////////////////////////////////////////////////////////////////////
// Local internal procedures and functions.

Function CreateTempExchangeMessageDirectory()
	
	// Creating the temporary exchange message directory.
	Try
		TempDirectoryName = DataExchangeServer.CreateTempExchangeMessageDirectory(CatalogID);
	Except
		GetErrorMessage(4);
		SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	ExchangeMessagesTemporaryDirectory = New File(TempDirectoryName);
	
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
	
	Extension = ?(CompressOutgoingMessageFile(), ".zip", ".xml");
	
	OutgoingMessageFileName = MessageFileNamePattern + Extension;
	
	If CompressOutgoingMessageFile() Then
		
		// Getting the temporary archive file name.
		ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName(), MessageFileNamePattern + ".zip");
		
		Try
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ArchivePasswordExchangeMessages, NStr("ru = '???????? ?????????????????? ????????????'; en = 'Exchange message file'; pl = 'Plik komunikat??w wymiany';es_ES = 'Archivo de mensaje de intercambio';es_CO = 'Archivo de mensaje de intercambio';tr = 'Al????veri?? mesaj?? dosyas??';it = 'File del messaggio di scambio';de = 'Austausch-Nachrichtendatei'"));
			Archiver.Add(ExchangeMessageFileName());
			Archiver.Write();
			
		Except
			
			Result = False;
			GetErrorMessage(3);
			SupplementErrorMessage(BriefErrorDescription(ErrorInfo()));
			
		EndTry;
		
		Archiver = Undefined;
		
		If Result Then
			
			// Checking that the exchange message size does not exceed the maximum allowed size.
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ArchiveTempFileName, MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			// Copying the archive file to the FTP server in the data exchange directory.
			If Not CopyFileToFTPServer(ArchiveTempFileName, OutgoingMessageFileName, SendGetDataTimeout) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	Else
		
		If Result Then
			
			// Checking that the exchange message size does not exceed the maximum allowed size.
			If DataExchangeServer.ExchangeMessageSizeExceedsAllowed(ExchangeMessageFileName(), MaxMessageSize()) Then
				GetErrorMessage(108);
				Result = False;
			EndIf;
			
		EndIf;
		
		If Result Then
			
			// Copying the archive file to the FTP server in the data exchange directory.
			If Not CopyFileToFTPServer(ExchangeMessageFileName(), OutgoingMessageFileName, SendGetDataTimeout) Then
				Result = False;
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Result;
	
EndFunction

Function GetExchangeMessage(ExistenceCheck)
	
	ExchangeMessageFileTable = New ValueTable;
	ExchangeMessageFileTable.Columns.Add("File");
	ExchangeMessageFileTable.Columns.Add("Modified");
	
	Try
		FTPConnection = GetFTPConnection(SendGetDataTimeout);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	MessageFileNameTemplateForSearch = StrReplace(MessageFileNamePattern, "Message", "Message*");

	Try
		FoundFileArray = FTPConnection.FindFiles(DirectoryAtFTPServer, MessageFileNameTemplateForSearch + ".*", False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
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
			GetErrorMessage(1);
		
			MessageString = NStr("ru = '?????????????? ???????????? ?????????????????????? ???? ??????????????: ""%1""'; en = 'The data exchange directory on the server is %1.'; pl = 'Katalog wymiany informacji na serwerze: ""%1""';es_ES = 'Directorio de intercambio de datos en el servidor: ""%1""';es_CO = 'Directorio de intercambio de datos en el servidor: ""%1""';tr = 'Sunucunda veri al????veri??i dizini: ""%1""';it = 'La directory di scambio dati sul server ?? %1.';de = 'Verzeichnis f??r den Datenaustausch auf dem Server: ""%1""'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, DirectoryAtFTPServer);
			SupplementErrorMessage(MessageString);
			
			MessageString = NStr("ru = '?????? ?????????? ?????????????????? ????????????: ""%1"" ?????? ""%2""'; en = 'Exchange message file name is %1 or %2'; pl = 'Nazwa pliku wiadomo??ci wymiany: ""%1"" lub ""%2""';es_ES = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';es_CO = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';tr = 'Veri al????veri??i dosyas??n??n ad??: ""%1"" veya ""%2""';it = 'Il nome file del messaggio di scambio ?? %1 oppure %2';de = 'Name der Austausch-Nachrichtendatei: ""%1"" oder ""%2""'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, MessageFileNamePattern + ".xml", MessageFileNamePattern + ".zip");
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
		
		If FilePacked Then
			
			// Getting the temporary archive file name.
			ArchiveTempFileName = CommonClientServer.GetFullFileName(ExchangeMessageCatalogName(), MessageFileNamePattern + ".zip");
			
			Try
				FTPConnection.Get(IncomingMessageFile.FullName, ArchiveTempFileName);
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(105);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
			
			// Unpacking the temporary archive file.
			SuccessfullyUnpacked = DataExchangeServer.UnpackZipFile(ArchiveTempFileName, ExchangeMessageCatalogName(), ArchivePasswordExchangeMessages);
			
			If Not SuccessfullyUnpacked Then
				GetErrorMessage(2);
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
			Try
				FTPConnection.Get(IncomingMessageFile.FullName, ExchangeMessageFileName());
			Except
				ErrorText = DetailErrorDescription(ErrorInfo());
				GetErrorMessage(105);
				SupplementErrorMessage(ErrorText);
				Return False;
			EndTry;
		EndIf;
		
	EndIf;
	
	Return True;
	
EndFunction

Procedure GetErrorMessage(MessageNumber)
	
	SetErrorMessageString(ErrorsMessages[MessageNumber]);
	
EndProcedure

Procedure SetErrorMessageString(Val Message)
	
	If Message = Undefined Then
		Message = NStr("ru = '???????????????????? ????????????'; en = 'Internal error'; pl = 'B????d zewn??trzny';es_ES = 'Error interno';es_CO = 'Error interno';tr = 'Dahili hata';it = 'Errore interno';de = 'Interner Fehler'");
	EndIf;
	
	ErrorMessageString   = Message;
	ErrorMessageStringEL = ObjectName + ": " + Message;
	
EndProcedure

Procedure SupplementErrorMessage(Message)
	
	ErrorMessageStringEL = ErrorMessageStringEL + Chars.LF + Message;
	
EndProcedure

// The overridable function, returns the maximum allowed size of a message to be sent.
// 
// 
Function MaxMessageSize()
	
	Return FTPConnectionMaxMessageSize;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Functions for retrieving properties.

Function CompressOutgoingMessageFile()
	
	Return FTPCompressOutgoingMessageFile;
	
EndFunction

///////////////////////////////////////////////////////////////////////////////
// Initialization

Procedure InitMessages()
	
	ErrorMessageString   = "";
	ErrorMessageStringEL = "";
	
EndProcedure

Procedure ErrorMessageInitialization()
	
	ErrorsMessages = New Map;
	
	// Common error codes
	ErrorsMessages.Insert(001, NStr("ru = '?? ???????????????? ???????????? ?????????????????????? ???? ?????? ?????????????????? ???????? ?????????????????? ?? ??????????????.'; en = 'No message file with data was found in the exchange directory.'; pl = 'W katalogu wymiany informacji nie znaleziono pliku wiadomo??ci z danymi.';es_ES = 'Directorio de intercambio de informaci??n no contiene un archivo de mensajes con datos.';es_CO = 'Directorio de intercambio de informaci??n no contiene un archivo de mensajes con datos.';tr = 'Veri al????veri??i dizininde veri mesaj?? dosyas?? bulundu.';it = 'Nessun file di messaggio con dati ?? stato trovato nella directory di scambio.';de = 'Das Verzeichnis f??r den Informationsaustausch enth??lt keine Nachrichtendatei mit Daten.'"));
	ErrorsMessages.Insert(002, NStr("ru = '???????????? ?????? ???????????????????? ?????????????? ?????????? ??????????????????.'; en = 'Error unpacking the exchange message file.'; pl = 'Podczas rozpakowywania skompresowanego pliku wiadomo??ci wyst??pi?? b????d.';es_ES = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';es_CO = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';tr = 'S??k????t??r??lm???? mesaj dosyas?? a????l??rken bir hata olu??tu.';it = 'Errore durante la decompressione del file di scambio messaggio.';de = 'Beim Entpacken einer komprimierten Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(003, NStr("ru = '???????????? ?????? ???????????? ?????????? ?????????????????? ????????????.'; en = 'Error packing the exchange message file.'; pl = 'B????d podczas kompresji pliku wiadomo??ci wymiany.';es_ES = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';es_CO = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';tr = 'Veri al????veri??i mesaj?? dosyas?? s??k????t??r??l??rken bir hata olu??tu.';it = 'Errore durante la compressione del file di scambio messaggio.';de = 'Beim Komprimieren der Austausch-Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(004, NStr("ru = '???????????? ?????? ???????????????? ???????????????????? ????????????????.'; en = 'An error occurred when creating a temporary directory.'; pl = 'B????d podczas tworzenia katalogu tymczasowego.';es_ES = 'Ha ocurrido un error al crear un directorio temporal.';es_CO = 'Ha ocurrido un error al crear un directorio temporal.';tr = 'Ge??ici bir dizin olu??tururken bir hata olu??tu.';it = 'Si ?? verificato un errore durante la creazione di una directory temporanea.';de = 'Beim Erstellen eines tempor??ren Verzeichnisses ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(005, NStr("ru = '?????????? ???? ???????????????? ???????? ?????????????????? ????????????.'; en = 'The archive does not contain the exchange message file.'; pl = 'Archiwum nie zawiera pliku wiadomo??ci wymiany.';es_ES = 'Archivo no incluye el archivo de mensajes de intercambio.';es_CO = 'Archivo no incluye el archivo de mensajes de intercambio.';tr = 'Ar??iv, veri al????veri?? mesaj?? dosyas??n?? i??ermiyor.';it = 'L''archivio non contiene il file del messaggio di scambio.';de = 'Das Archiv enth??lt keine Austausch-Nachrichtendatei.'"));
	
	// Errors codes that are dependent on the transport kind.
	ErrorsMessages.Insert(101, NStr("ru = '???? ?????????? ???????? ???? ??????????????.'; en = 'Path on the server is not specified.'; pl = 'Nie okre??lono ??cie??ki na serwerze.';es_ES = 'Ruta en el servidor no est?? especificada.';es_CO = 'Ruta en el servidor no est?? especificada.';tr = 'Sunucudaki yol belirtilmemi??.';it = 'Percorso sul server non ?? specificato.';de = 'Pfad auf dem Server ist nicht angegeben.'"));
	ErrorsMessages.Insert(102, NStr("ru = '???????????? ?????????????????????????? ?????????????????????? ?? FTP-??????????????.'; en = 'Error initializing connection to the FTP server.'; pl = 'B????d inicjalizacji po????czenia z serwerem FTP.';es_ES = 'Ha ocurrido un error al iniciar la conexi??n al servidor FTP.';es_CO = 'Ha ocurrido un error al iniciar la conexi??n al servidor FTP.';tr = 'FTP-sunucusuna ba??lant?? ba??latma hatas??.';it = 'Errore nell''inizializzazione della connessione al server FTP.';de = 'Bei der Initialisierung der Verbindung zum FTP-Server ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(103, NStr("ru = '???????????? ?????????????????????? ?? FTP-??????????????, ?????????????????? ???????????????????????? ?????????????? ???????? ?? ?????????? ?????????????? ?? ??????????????.'; en = 'Error establishing connection to the FTP server. Check whether the path is specified correctly and whether access rights are sufficient.'; pl = 'B????d po????czenia z serwerem FTP, sprawd?? poprawno???? ??cie??ki i prawa dost??pu do zasobu.';es_ES = 'Ha ocurrido un error al conectar al servidor FTP, revisar la exactitud de la ruta y los derechos de acceso para el recurso.';es_CO = 'Ha ocurrido un error al conectar al servidor FTP, revisar la exactitud de la ruta y los derechos de acceso para el recurso.';tr = 'FTP-sunucuna ba??lant?? hatas??, yol ve kaynak eri??im hakk??n??n do??ru belirlenip belirlenmedi??ini kontrol edin.';it = 'Errore nello stabilire la connessione al server FTP. Controllare se il percorso ?? specificato correttamente e se si dispone di diritti di accesso sufficienti.';de = 'Beim Herstellen der Verbindung zum FTP-Server ist ein Fehler aufgetreten. ??berpr??fen Sie die Richtigkeit des Pfads und die Zugriffsrechte f??r die Ressource.'"));
	ErrorsMessages.Insert(104, NStr("ru = '???????????? ?????? ???????????? ???????????? ???? FTP-??????????????.'; en = 'Error searching for files on the FTP server.'; pl = 'B????d podczas wyszukiwania plik??w na serwerze FTP.';es_ES = 'Ha ocurrido un error al buscar los archivos en el servidor FTP.';es_CO = 'Ha ocurrido un error al buscar los archivos en el servidor FTP.';tr = 'Dosyalar FTP-sunucuda aran??rken bir hata olu??tu.';it = 'Errore durante la ricerca di file sul server FTP.';de = 'Bei der Suche nach Dateien auf dem FTP-Server ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(105, NStr("ru = '???????????? ?????? ?????????????????? ?????????? ?? FTP-??????????????.'; en = 'Error receiving the file from the FTP server.'; pl = 'B????d podczas pobierania pliku z serwera FTP.';es_ES = 'Ha ocurrido un error al recibir el archivo del servidor FTP.';es_CO = 'Ha ocurrido un error al recibir el archivo del servidor FTP.';tr = 'Dosya FTP-sunucusundan al??n??rken bir hata olu??tu.';it = 'Errore durante la ricezione dei file dal server FTP.';de = 'Beim Empfang der Datei vom FTP-Server ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(106, NStr("ru = '???????????? ???????????????? ?????????? ???? FTP-??????????????, ?????????????????? ?????????? ?????????????? ?? ??????????????.'; en = 'Error deleting the file from the FTP server. Check whether resource access rights are sufficient.'; pl = 'B????d usuni??cia pliku na serwerze FTP, sprawd?? prawa dost??pu do zasobu.';es_ES = 'Ha ocurrido un error al eliminar el archivo del servidor FTP, revisar los derechos de acceso para el recurso.';es_CO = 'Ha ocurrido un error al eliminar el archivo del servidor FTP, revisar los derechos de acceso para el recurso.';tr = 'Dosya FTP-sunucusundan kald??r??l??rken bir hata olu??tu, kayak eri??im haklar??n?? kontrol edin.';it = 'Errore di cancellazione del file dal server FTP. Controllare se si dispone di diritti sufficienti di accesso alla risorsa.';de = 'Beim Entfernen der Datei auf dem FTP-Server ist ein Fehler aufgetreten. ??berpr??fen Sie die Zugriffsrechte f??r die Ressource.'"));
	
	ErrorsMessages.Insert(108, NStr("ru = '???????????????? ???????????????????? ???????????? ?????????????????? ????????????.'; en = 'The maximum allowed exchange message size is exceeded.'; pl = 'Przekroczono dopuszczalny rozmiar wiadomo??ci wymiany.';es_ES = 'Tama??o del mensaje de intercambio supera el l??mite permitido.';es_CO = 'Tama??o del mensaje de intercambio supera el l??mite permitido.';tr = 'Veri al????veri??i mesaj??n??n maksimum boyutu a????ld??.';it = 'La dimensione massima concessa del messaggio di scambio ?? stata superata.';de = 'Die Gr????e der Austausch-Nachricht ??berschreitet das zul??ssige Limit.'"));
	
EndProcedure

///////////////////////////////////////////////////////////////////////////////
// Procedures and functions for working with FTP connection.

Function GetFTPConnection(Timeout)
	
	FTPSettings = DataExchangeServer.FTPConnectionSettings(Timeout);
	FTPSettings.Server               = FTPServerName;
	FTPSettings.Port                 = FTPConnectionPort;
	FTPSettings.UserName      = FTPConnectionUser;
	FTPSettings.UserPassword   = FTPConnectionPassword;
	FTPSettings.PassiveConnection  = FTPConnectionPassiveConnection;
	FTPSettings.SecureConnection = DataExchangeServer.SecureConnection(FTPConnectionPath);
	
	Return DataExchangeServer.FTPConnection(FTPSettings);
	
EndFunction

Function CopyFileToFTPServer(Val SourceFileName, DestinationFileName, Val Timeout)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection(Timeout);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Put(SourceFileName, DirectoryAtServer + DestinationFileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(103);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FilesArray = FTPConnection.FindFiles(DirectoryAtServer, DestinationFileName, False);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(104);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Return FilesArray.Count() > 0;
	
EndFunction

Function DeleteFileAtFTPServer(Val FileName, ConnectionTest = False)
	
	Var DirectoryAtServer;
	
	ServerAndDirectoryAtServer = SplitFTPResourceToServerAndDirectory(TrimAll(FTPConnectionPath));
	DirectoryAtServer = ServerAndDirectoryAtServer.DirectoryName;
	
	Try
		FTPConnection = GetFTPConnection(10);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(102);
		SupplementErrorMessage(ErrorText);
		Return False;
	EndTry;
	
	Try
		FTPConnection.Delete(DirectoryAtServer + FileName);
	Except
		ErrorText = DetailErrorDescription(ErrorInfo());
		GetErrorMessage(106);
		SupplementErrorMessage(ErrorText);
		
		If ConnectionTest Then
			
			ErrorMessage = NStr("ru = '???? ?????????????? ?????????????????? ?????????????????????? ?? ?????????????? ?????????????????? ?????????? ""%1"".
			|????????????????, ???????????????? ?????????????? ???? ???????????????????? ?????? ???? ????????????????.
			|?????????????????????????? ?????????? ???????????????????? ?? ???????????????????????? ???? FTP-?????????????? ?????? ?????????????????? ?????????????????? ???????? ???????????? ?? ????????????????????.'; 
			|en = 'Cannot check connection with test file ""%1"".
			|Maybe, the specified directory does not exist or is unavailable.
			|It is also recommended to address FTP server documentation to configure support of cyrillic file names.'; 
			|pl = 'Nie uda??o si?? sprawdzi?? po????czenia z u??yciem pliku testowego ""%1"".
			|By?? mo??e okre??lony katalog nie istnieje lub nie jest dost??pny.
			|Zaleca si?? tak??e, aby zobaczy?? dokumentacj?? serwera FTP, skonfigurowa?? obs??ug?? plik??w cyrylicy.';
			|es_ES = 'Fallado a revisar la conexi??n por el archivo de prueba ""%1"".
			|Probablemente, el directorio especificado no existe o no est?? disponible.
			|Tambi??n se recomienda ver la documentaci??n del servidor FTP para configurar el soporte de los archivos de nombre Cir??licos.';
			|es_CO = 'Fallado a revisar la conexi??n por el archivo de prueba ""%1"".
			|Probablemente, el directorio especificado no existe o no est?? disponible.
			|Tambi??n se recomienda ver la documentaci??n del servidor FTP para configurar el soporte de los archivos de nombre Cir??licos.';
			|tr = '""%1""Test dosyas??n?? kullanarak ba??lant??y?? test edilemedi. 
			|Belirtilen dizin mevcut olmayabilir ya da eri??ilmeyebilir. 
			| Ayr??ca Kiril alfabesi ile belirlenen dosya adlar??n?? desteklemek i??in FTP sunucu ile ilgili belgelere bakman??z ??nerilir.';
			|it = 'Impossibile controllare la connessione con il file di test ""%1"".
			|La directory specificata potrebbe non esistere o non essere disponibile.
			|Si consiglia inoltre di rivolgersi alla documentazione del server FTP per configurare il supporto dei nomi di file in cirillico.';
			|de = 'Fehler beim ??berpr??fen der Verbindung durch die Testdatei ""%1"".
			|Vielleicht existiert das angegebene Verzeichnis nicht oder ist nicht verf??gbar.
			|Es wird auch empfohlen, die FTP-Server-Dokumentation zu lesen, um die Unterst??tzung der kyrillischen Namensdateien einzurichten.'");
			ErrorMessage = StringFunctionsClientServer.SubstituteParametersToString(ErrorMessage, FileName);
			SupplementErrorMessage(ErrorMessage);
			
		EndIf;
		
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function SplitFTPResourceToServerAndDirectory(Val FullPath)
	
	Result = New Structure("ServerName, DirectoryName");
	
	FTPParameters = DataExchangeServer.FTPServerNameAndPath(FullPath);
	
	Result.ServerName  = FTPParameters.Server;
	Result.DirectoryName = FTPParameters.Path;
	
	Return Result;
EndFunction

#EndRegion

#Region Initializing

InitMessages();
ErrorMessageInitialization();

ExchangeMessagesTemporaryDirectory = Undefined;
TempExchangeMessageFile    = Undefined;

FTPServerName       = Undefined;
DirectoryAtFTPServer = Undefined;

ObjectName = NStr("ru = '??????????????????: %1'; en = 'Data processor: %1'; pl = 'Opracowanie: %1';es_ES = 'Procesador de datos: %1';es_CO = 'Procesador de datos: %1';tr = 'Veri i??lemcisi: %1';it = 'Elaboratore dati: %1';de = 'Datenprozessor: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersToString(ObjectName, Metadata().Name);

SendGetDataTimeout = 12*60*60;

#EndRegion

#EndIf