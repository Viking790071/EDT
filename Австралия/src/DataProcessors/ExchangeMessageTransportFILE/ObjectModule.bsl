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
			
			Archiver = New ZipFileWriter(ArchiveTempFileName, ArchivePasswordExchangeMessages, NStr("ru = '???????? ?????????????????? ????????????'; en = 'Exchange message file'; pl = 'Plik komunikat??w wymiany';es_ES = 'Archivo de mensaje de intercambio';es_CO = 'Archivo de mensaje de intercambio';tr = 'Al????veri?? mesaj?? dosyas??';it = 'File del messaggio di scambio';de = 'Austausch-Nachrichtendatei'"));
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
		
			MessageString = NStr("ru = '?????????????? ???????????? ??????????????????????: ""%1""'; en = 'Data exchange directory is %1'; pl = 'Katalog wymiany informacj??: ""%1""';es_ES = 'Directorio de intercambio de datos: ""%1""';es_CO = 'Directorio de intercambio de datos: ""%1""';tr = 'Veri al????veri??i dizini: ""%1""';it = 'La directory per lo scambio di dati ?? %1';de = 'Datenaustauschverzeichnis: ""%1""'");
			MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, DataExchangeDirectoryName());
			SupplementErrorMessage(MessageString);
			
			MessageString = NStr("ru = '?????? ?????????? ?????????????????? ????????????: ""%1"" ?????? ""%2""'; en = 'Exchange message file name is %1 or %2'; pl = 'Nazwa pliku wiadomo??ci wymiany: ""%1"" lub ""%2""';es_ES = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';es_CO = 'Nombre del archivo de mensajes de intercambio: ""%1"" o ""%2""';tr = 'Veri al????veri??i dosyas??n??n ad??: ""%1"" veya ""%2""';it = 'Il nome file del messaggio di scambio ?? %1 oppure %2';de = 'Name der Austausch-Nachrichtendatei: ""%1"" oder ""%2""'");
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
	TextDocument.AddLine(NStr("ru = '?????????????????? ???????? ????????????????'; en = 'Temporary file for checking access to directory'; pl = 'Tymczasowy plik sprawdzenia';es_ES = 'Archivo de revisi??n temporal';es_CO = 'Archivo de revisi??n temporal';tr = 'Ge??ici kontrol dosyas??';it = 'File temporaneo per controllare l''accesso alla directory';de = 'Tempor??re Pr??fdatei'"));
	
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
		
		MessageString = NStr("ru = '???????????? ?????? ?????????????????????? ?????????? ???? %1 ?? %2. ???????????????? ????????????: %3'; en = 'An error occurred when copying a file from %1 to %2. Error description: %3'; pl = 'Wyst??pi?? b????d podczas kopiowania pliku z %1 na %2. Opis b????du: %3';es_ES = 'Ha ocurrido un error al copiar un archivo desde %1 para %2. Descripci??n del error: %3';es_CO = 'Ha ocurrido un error al copiar un archivo desde %1 para %2. Descripci??n del error: %3';tr = 'Bir dosya %1 2''den %2''e kopyaland??????nda bir hata olu??tu. Hata tan??mlamas??: %3';it = 'Si ?? registrato un errore copiando i file %1 in %2. Descrizione errore: %3';de = 'Beim Kopieren einer Datei von %1 in %2 ist ein Fehler aufgetreten. Fehlerbeschreibung: %3'");
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
		Message = NStr("ru = '???????????????????? ????????????'; en = 'Internal error'; pl = 'B????d zewn??trzny';es_ES = 'Error interno';es_CO = 'Error interno';tr = 'Dahili hata';it = 'Errore interno';de = 'Interner Fehler'");
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
	ErrorsMessages.Insert(1, NStr("ru = '???????????? ??????????????????????: ???? ???????????? ?????????????? ???????????? ??????????????????????.'; en = 'Connection error: The data exchange directory is not specified.'; pl = 'B????d po????czenia: katalog wymiany informacji nie zosta?? okre??lony.';es_ES = 'Error de conexi??n: Directorio de intercambio de informaci??n no est?? especificado.';es_CO = 'Error de conexi??n: Directorio de intercambio de informaci??n no est?? especificado.';tr = 'Ba??lant?? hatas??: Veri al????veri??i dizini belirtilmedi.';it = 'Errore di connessione: La directory di scambio dati non ?? specificata.';de = 'Verbindungsfehler: Verzeichnis f??r den Informationsaustausch wurde nicht angegeben.'"));
	ErrorsMessages.Insert(2, NStr("ru = '???????????? ??????????????????????: ?????????????? ???????????? ?????????????????????? ???? ????????????????????.'; en = 'Connection error: The data exchange directory does not exist.'; pl = 'B????d po????czenia: katalog wymiany informacji nie istnieje.';es_ES = 'Error de conexi??n: Directorio de intercambio de informaci??n no existe.';es_CO = 'Error de conexi??n: Directorio de intercambio de informaci??n no existe.';tr = 'Ba??lant?? hatas??: Veri al????veri??i dizini mevcut de??il.';it = 'Errore di connessione: La directory di scambio dati non esiste.';de = 'Verbindungsfehler: Verzeichnis f??r den Informationsaustausch existiert nicht.'"));
	
	ErrorsMessages.Insert(3, NStr("ru = '?? ???????????????? ???????????? ?????????????????????? ???? ?????? ?????????????????? ???????? ?????????????????? ?? ??????????????.'; en = 'No message file with data was found in the exchange directory.'; pl = 'W katalogu wymiany informacji nie znaleziono pliku wiadomo??ci z danymi.';es_ES = 'Directorio de intercambio de informaci??n no contiene un archivo de mensajes con datos.';es_CO = 'Directorio de intercambio de informaci??n no contiene un archivo de mensajes con datos.';tr = 'Veri al????veri??i dizininde veri mesaj?? dosyas?? bulundu.';it = 'Nessun file di messaggio con dati ?? stato trovato nella directory di scambio.';de = 'Das Verzeichnis f??r den Informationsaustausch enth??lt keine Nachrichtendatei mit Daten.'"));
	ErrorsMessages.Insert(4, NStr("ru = '???????????? ?????? ???????????????????? ?????????????? ?????????? ??????????????????.'; en = 'Error unpacking the exchange message file.'; pl = 'Podczas rozpakowywania skompresowanego pliku wiadomo??ci wyst??pi?? b????d.';es_ES = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';es_CO = 'Ha ocurrido un error al desembalar un archivo de mensajes comprimido.';tr = 'S??k????t??r??lm???? mesaj dosyas?? a????l??rken bir hata olu??tu.';it = 'Errore durante la decompressione del file di scambio messaggio.';de = 'Beim Entpacken einer komprimierten Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(5, NStr("ru = '???????????? ?????? ???????????? ?????????? ?????????????????? ????????????.'; en = 'Error packing the exchange message file.'; pl = 'B????d podczas kompresji pliku wiadomo??ci wymiany.';es_ES = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';es_CO = 'Ha ocurrido un error al comprimir el archivo de mensajes de intercambio.';tr = 'Veri al????veri??i mesaj?? dosyas?? s??k????t??r??l??rken bir hata olu??tu.';it = 'Errore durante la compressione del file di scambio messaggio.';de = 'Beim Komprimieren der Austausch-Nachrichtendatei ist ein Fehler aufgetreten.'"));
	ErrorsMessages.Insert(6, NStr("ru = '???????????? ?????? ???????????????? ???????????????????? ????????????????'; en = 'An error occurred when creating a temporary directory'; pl = 'Wyst??pi?? b????d podczas tworzenia katalogu tymczasowego';es_ES = 'Ha ocurrido un error al crear un directorio temporal';es_CO = 'Ha ocurrido un error al crear un directorio temporal';tr = 'Ge??ici dizin olu??turulurken bir hata olu??tu.';it = 'Si ?? verificato un errore durante la creazione di una directory temporanea';de = 'Beim Erstellen eines tempor??ren Verzeichnisses ist ein Fehler aufgetreten'"));
	ErrorsMessages.Insert(7, NStr("ru = '?????????? ???? ???????????????? ???????? ?????????????????? ????????????'; en = 'The archive does not contain the exchange message file'; pl = 'Archiwum nie zawiera pliku wiadomo??ci wymiany';es_ES = 'Archivo con incluye un archivo de mensajes de intercambio';es_CO = 'Archivo con incluye un archivo de mensajes de intercambio';tr = 'Ar??iv, veri al????veri?? mesaj?? dosyas??n?? i??ermiyor.';it = 'L''archivio non contiene il file del messaggio di scambio.';de = 'Das Archiv enth??lt keine Austauschnachrichtendatei'"));
	
	ErrorsMessages.Insert(8, NStr("ru = '???????????? ???????????? ?????????? ?? ?????????????? ???????????? ??????????????????????. ?????????????????? ?????????? ???????????????????????? ???? ???????????? ?? ????????????????.'; en = 'An error occurred when writing the file to the information exchange directory. Check if the user is authorized to access the directory.'; pl = 'Wyst??pi?? b????d podczas zapisywania pliku w katalogu wymiany informacji. Sprawd??, czy u??ytkownik ma uprawnienia dost??pu do katalogu.';es_ES = 'Ha ocurrido un error al grabar el archivo en el directorio de intercambio de informaci??n. Revisar si el usuario est?? autorizado para acceder el directorio.';es_CO = 'Ha ocurrido un error al grabar el archivo en el directorio de intercambio de informaci??n. Revisar si el usuario est?? autorizado para acceder el directorio.';tr = 'Dosya veri al????veri??i dizinine yaz??l??rken bir hata olu??tu. Kullan??c??n??n dizine eri??me yetkisi olup olmad??????n?? kontrol edin.';it = 'Si ?? verificato un errore durante la scrittura di un file nella directory dello scambio di informazioni. Verifica le autorizzazioni dell''utente per accedere alla directory.';de = 'Beim Schreiben der Datei in das Verzeichnis f??r den Informationsaustausch ist ein Fehler aufgetreten. ??berpr??fen Sie, ob der Benutzer berechtigt ist, auf das Verzeichnis zuzugreifen.'"));
	ErrorsMessages.Insert(9, NStr("ru = '???????????? ???????????????? ?????????? ???? ???????????????? ???????????? ??????????????????????. ?????????????????? ?????????? ???????????????????????? ???? ???????????? ?? ????????????????.'; en = 'An error occurred when removing a file from the information exchange directory. Check user access rights to the directory.'; pl = 'Wyst??pi?? b????d podczas usuwania pliku z katalogu wymiany informacji. Sprawd?? prawa dost??pu u??ytkownika do katalogu.';es_ES = 'Ha ocurrido un error al sacar un archivo del directorio de intercambio de informaci??n. Revisar los derechos de acceso del usuario al directorio.';es_CO = 'Ha ocurrido un error al sacar un archivo del directorio de intercambio de informaci??n. Revisar los derechos de acceso del usuario al directorio.';tr = 'Dosya veri al????veri??i dizininden kald??r??l??rken bir hata olu??tu. Kullan??c??n??n dizine eri??me yetkisi olup olmad??????n?? kontrol edin.';it = 'Si ?? verificato un errore durante l''eliminazione del file dalla directory dello scambio di informazioni. Verifica le autorizzazioni dell''utente per accedere alla directory.';de = 'Beim Entfernen einer Datei aus dem Verzeichnis f??r den Informationsaustausch ist ein Fehler aufgetreten. ??berpr??fen Sie die Benutzerzugriffsrechte f??r das Verzeichnis.'"));
	
EndProcedure

#EndRegion

#Region Initializing

InitMessages();
ErrorMessageInitialization();

ExchangeMessagesTemporaryDirectory = Undefined;
TempExchangeMessageFile    = Undefined;

ObjectName = NStr("ru = '??????????????????: %1'; en = 'Data processor: %1'; pl = 'Opracowanie: %1';es_ES = 'Procesador de datos: %1';es_CO = 'Procesador de datos: %1';tr = 'Veri i??lemcisi: %1';it = 'Elaboratore dati: %1';de = 'Datenprozessor: %1'");
ObjectName = StringFunctionsClientServer.SubstituteParametersToString(ObjectName, Metadata().Name);

#EndRegion

#EndIf
