#Region Internal

// Returns personal settings.
//
Function PersonalFilesOperationsSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FilesOperationsServiceCached.FilesOperationSettings().PersonalSettings;
#Else
	Return FilesOperationsInternalClient.PersonalFilesOperationsSettings();
#EndIf

EndFunction

// Returns common personal settings.
//
Function CommonFilesOperationsSettings() Export

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
	Return FilesOperationsServiceCached.FilesOperationSettings().CommonSettings;
#Else
	Return FilesOperationsInternalClient.CommonFilesOperationsSettings();
#EndIf

EndFunction

// Extracts text from a file and returns it as a string.
Function ExtractText(FullFileName, Cancel = False, Encoding = Undefined) Export
	
	ExtractedText = "";
	
	Try
		File = New File(FullFileName);
		If Not File.Exist() Then
			Cancel = True;
			Return ExtractedText;
		EndIf;
	Except
		Cancel = True;
		Return ExtractedText;
	EndTry;
	
	Stop = False;
	
	CommonSettings = CommonFilesOperationsSettings();
	
#If Not WebClient AND NOT MobileClient Then
	
	FileNameExtension =
		CommonClientServer.GetFileNameExtension(FullFileName);
	
	FileExtensionInList = FileExtensionInList(
		CommonSettings.TestFilesExtensionsList, FileNameExtension);
	
	If FileExtensionInList Then
		Return ExtractTextFromTextFile(FullFileName, Encoding, Cancel);
	EndIf;
	
	Try
		Extracting = New TextExtraction(FullFileName);
		ExtractedText = Extracting.GetText();
	Except
		// If there is no handler to extract the text, this is not an error but a normal scenario. This is a normal case.
		ExtractedText = "";
		Stop = True;
	EndTry;
		
#EndIf
	
	If IsBlankString(ExtractedText) Then
		
		FileNameExtension =
			CommonClientServer.GetFileNameExtension(FullFileName);
		
		FileExtensionInList = FileExtensionInList(
			CommonSettings.FilesExtensionsListOpenDocument, FileNameExtension);
		
		If FileExtensionInList Then
			Return ExtractOpenDocumentText(FullFileName, Cancel);
		EndIf;
		
	EndIf;
	
	If Stop Then
		Cancel = True;
	EndIf;
	
	Return ExtractedText;
	
EndFunction

// Gets a unique file name for using it in the working directory.
//  If there are matches, the name will look like "A1\Order.doc".
//
Function GetUniqueNameWithPath(DirectoryName, FileName) Export
	
	FinalPath = "";
	
	Counter = 0;
	DoNumber = 0;
	Success = False;
	CodeLetterA = CharCode("A", 1);
	
	RandomValueGenerator = Undefined;
	
#If Not WebClient Then
	RandomValueGenerator = New RandomNumberGenerator(CurrentUniversalDateInMilliseconds());
#EndIf

	RandomOptionsCount = 26;
	
	While NOT Success AND DoNumber < 100 Do
		DirectoryNumber = 0;
		
#If Not WebClient Then
		DirectoryNumber = RandomValueGenerator.RandomNumber(0, RandomOptionsCount - 1);
#Else
		DirectoryNumber = CurrentUniversalDateInMilliseconds() % RandomOptionsCount;
#EndIf

		If Counter > 1 AND RandomOptionsCount < 26 * 26 * 26 * 26 * 26 Then
			RandomOptionsCount = RandomOptionsCount * 26;
		EndIf;
		
		DirectoryLetters = "";
		CodeLetterA = CharCode("A", 1);
		
		While True Do
			LetterNumber = DirectoryNumber % 26;
			DirectoryNumber = Int(DirectoryNumber / 26);
			
			DirectoryCode = CodeLetterA + LetterNumber;
			
			DirectoryLetters = DirectoryLetters + Char(DirectoryCode);
			If DirectoryNumber = 0 Then
				Break;
			EndIf;
		EndDo;
		
		SubDirectory = ""; // Partial path.
		
		// Use the root directory by default. If it is impossible, add A, B, ...
		//  Z, .. ZZZZZ, .. AAAAA, .. AAAAAZ and so on.
		If  Counter = 0 Then
			SubDirectory = "";
		Else
			SubDirectory = DirectoryLetters;
			DoNumber = Round(Counter / 26);
			
			If DoNumber <> 0 Then
				DoNumberString = String(DoNumber);
				SubDirectory = SubDirectory + DoNumberString;
			EndIf;
			
			If IsReservedDirectoryName(SubDirectory) Then
				Continue;
			EndIf;
			
			SubDirectory = CommonClientServer.AddLastPathSeparator(SubDirectory);
		EndIf;
		
		FullSubdirectory = DirectoryName + SubDirectory;
		
		// Creating a directory for files.
		DirectoryOnHardDrive = New File(FullSubdirectory);
		If NOT DirectoryOnHardDrive.Exist() Then
			Try
				CreateDirectory(FullSubdirectory);
			Except
				Raise StringFunctionsClientServer.SubstituteParametersToString(
					NStr("ru = 'Ошибка при создании каталога ""%1"":
					           |""%2"".'; 
					           |en = 'An error occurred when creating directory ""%1"":
					           |""%2"".'; 
					           |pl = 'Błąd przy utworzeniu katalogu ""%1"":
					           |""%2"".';
					           |es_ES = 'Error al crear el catálogo ""%1"":
					           |""%2"".';
					           |es_CO = 'Error al crear el catálogo ""%1"":
					           |""%2"".';
					           |tr = '""%1"" dizin oluşturulurken bir hata oluştu: 
					           |""%2"".';
					           |it = 'Si è registrato un errore durante la creazione della directory ""%1"":
					           |""%2"".';
					           |de = 'Fehler beim Erstellen des Verzeichnisses ""%1"":
					           |""%2"".'"),
					FullSubdirectory,
					BriefErrorDescription(ErrorInfo()) );
			EndTry;
		EndIf;
		
		AttemptFile = FullSubdirectory + FileName;
		Counter = Counter + 1;
		
		// Checking whether the file name is unique
		FileOnHardDrive = New File(AttemptFile);
		If NOT FileOnHardDrive.Exist() Then  // There is no such file.
			FinalPath = SubDirectory + FileName;
			Success = True;
		EndIf;
	EndDo;
	
	Return FinalPath;
	
EndFunction

// Returns True if the file with such extension is in the list of extensions.
Function FileExtensionInList(ExtensionList, FileExtention) Export
	
	FileExtentionWithoutDot = CommonClientServer.ExtensionWithoutPoint(FileExtention);
	
	ExtensionArray = StrSplit(
		Lower(ExtensionList), " ", False);
	
	If ExtensionArray.Find(FileExtentionWithoutDot) <> Undefined Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// Checks file extension and size.
Function CheckCanImportFile(File,
                                          RaiseException = True,
                                          ArrayOfFilesNamesWithErrors = Undefined) Export
	
	CommonSettings = CommonFilesOperationsSettings();
	
	// A file size is too big.
	If File.Size() > CommonSettings.MaxFileSize Then
		
		SizeInMB     = File.Size() / (1024 * 1024);
		SizeInMBMax = CommonSettings.MaxFileSize / (1024 * 1024);
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Размер файла ""%1"" (%2 Мб)
			           |превышает максимально допустимый размер файла (%3 Мб).'; 
			           |en = 'Size of file ""%1"" (%2 MB)
			           |exceeds maximum allowed file size (%3 MB).'; 
			           |pl = 'Rozmiar pliku ""%1"" (%2 MB)
			           |przekracza maksymalny dopuszczalny rozmiar pliku (%3 MB).';
			           |es_ES = 'El tamaño del archivo ""%1"" (%2 MB)
			           |supera el tamaño máximo admitido del archivo (%3 MB).';
			           |es_CO = 'El tamaño del archivo ""%1"" (%2 MB)
			           |supera el tamaño máximo admitido del archivo (%3 MB).';
			           |tr = '""%1"" dosyasının boyutu (%2 MB)
			           |izin verilen dosya boyutunu aşıyor (%3 MB).';
			           |it = 'La dimensione del file ""%1"" (%2 Mb)
			           |eccede la dimensione massima concessa per i file (%3 Mb).';
			           |de = 'Die Dateigröße ""%1"" (%2 MB)
			           |überschreitet die maximale Dateigröße (%3 MB).'"),
			File.Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMBMax));
		
		If RaiseException Then
			Raise ErrorDescription;
		EndIf;
		
		Record = New Structure;
		Record.Insert("FileName", File.FullName);
		Record.Insert("Error",   ErrorDescription);
		
		ArrayOfFilesNamesWithErrors.Add(Record);
		Return False;
	EndIf;
	
	// Checking file extension
	If Not CheckExtentionOfFileToDownload(File.Extension, False) Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Загрузка файлов с расширением ""%1"" запрещена.
			           |Обратитесь к администратору.'; 
			           |en = 'Importing files with extension ""%1"" is prohibited.
			           |Contact your administrator.'; 
			           |pl = 'Nie można importować plików z rozszerzeniem ""%1"".
			           |Skontaktuj się z administratorem.';
			           |es_ES = 'No se puede importar archivos con la extensión ""%1"".
			           |Contactar su administrador.';
			           |es_CO = 'No se puede importar archivos con la extensión ""%1"".
			           |Contactar su administrador.';
			           |tr = '""%1"" Uzantılı dosya içe aktarılamıyor. 
			           |Yöneticinize başvurun.';
			           |it = 'Non è consentito importare file con estensione ""%1"".
			           |Contattare amministratore.';
			           |de = 'Dateien mit der Erweiterung ""%1"" können nicht importiert werden.
			           |Kontaktieren Sie Ihren Administrator.'"),
			File.Extension);
		
		If RaiseException Then
			Raise ErrorDescription;
		EndIf;
		
		Record = New Structure;
		Record.Insert("FileName", File.FullName);
		Record.Insert("Error",   ErrorDescription);
		
		ArrayOfFilesNamesWithErrors.Add(Record);
		Return False;
	EndIf;
	
	// Temporary Word files are not imported
	If StrStartsWith(File.Name, "~")
		AND File.GetHidden() Then
		
		Return False;
	EndIf;
	
	Return True;
	
EndFunction

// Returns True if a file with the specified extension can be imported.
Function CheckExtentionOfFileToDownload(FileExtention, RaiseException = True) Export
	
	CommonSettings = CommonFilesOperationsSettings();
	
	If NOT CommonSettings.FilesImportByExtensionDenied Then
		Return True;
	EndIf;
	
	If FileExtensionInList(CommonSettings.DeniedExtensionsList, FileExtention) Then
		
		If RaiseException Then
			Raise StringFunctionsClientServer.SubstituteParametersToString(
				NStr("ru = 'Загрузка файлов с расширением ""%1"" запрещена.
				           |Обратитесь к администратору.'; 
				           |en = 'Importing files with extension ""%1"" is prohibited.
				           |Contact your administrator.'; 
				           |pl = 'Nie można importować plików z rozszerzeniem ""%1"".
				           |Skontaktuj się z administratorem.';
				           |es_ES = 'No se puede importar archivos con la extensión ""%1"".
				           |Contactar su administrador.';
				           |es_CO = 'No se puede importar archivos con la extensión ""%1"".
				           |Contactar su administrador.';
				           |tr = '""%1"" Uzantılı dosya içe aktarılamıyor. 
				           |Yöneticinize başvurun.';
				           |it = 'Non è consentito importare file con estensione ""%1"".
				           |Contattare amministratore.';
				           |de = 'Dateien mit der Erweiterung ""%1"" können nicht importiert werden.
				           |Kontaktieren Sie Ihren Administrator.'"),
				FileExtention);
		Else
			Return False;
		EndIf;
	EndIf;
	
	Return True;
	
EndFunction

// Raises an exception if the file cannot be imported due to exceeding the maximum size.
Procedure CheckFileSizeForImport(File) Export
	
	CommonSettings = CommonFilesOperationsSettings();
	
	If TypeOf(File) = Type("File") Then
		Size = File.Size();
	Else
		Size = File.Size;
	EndIf;
	
	If Size > CommonSettings.MaxFileSize Then
	
		SizeInMB     = Size / (1024 * 1024);
		SizeInMBMax = CommonSettings.MaxFileSize / (1024 * 1024);
		
		If TypeOf(File) = Type("File") Then
			Name = File.Name;
		Else
			Name = CommonClientServer.GetNameWithExtension(
				File.FullDescr, File.Extension);
		EndIf;
		
		Raise StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Размер файла ""%1"" (%2 Мб)
			           |превышает максимально допустимый размер файла (%3 Мб).'; 
			           |en = 'Size of file ""%1"" (%2 MB)
			           |exceeds maximum allowed file size (%3 MB).'; 
			           |pl = 'Rozmiar pliku ""%1"" (%2 MB)
			           |przekracza maksymalny dopuszczalny rozmiar pliku (%3 MB).';
			           |es_ES = 'El tamaño del archivo ""%1"" (%2 MB)
			           |supera el tamaño máximo admitido del archivo (%3 MB).';
			           |es_CO = 'El tamaño del archivo ""%1"" (%2 MB)
			           |supera el tamaño máximo admitido del archivo (%3 MB).';
			           |tr = '""%1"" dosyasının boyutu (%2 MB)
			           |izin verilen dosya boyutunu aşıyor (%3 MB).';
			           |it = 'La dimensione del file ""%1"" (%2 Mb)
			           |eccede la dimensione massima concessa per i file (%3 Mb).';
			           |de = 'Die Dateigröße ""%1"" (%2 MB)
			           |überschreitet die maximale Dateigröße (%3 MB).'"),
			Name,
			GetStringWithFileSize(SizeInMB),
			GetStringWithFileSize(SizeInMBMax));
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// For user interface.

// Returns the row of the message that it is forbidden to sign a locked file.
//
Function FileUsedByAnotherProcessCannotBeSignedMessageString(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("ru = 'Нельзя подписать занятый файл.'; en = 'Cannot sign a locked file.'; pl = 'Nie można podpisać zajętego pliku.';es_ES = 'No se puede firmar el archivo bloqueado.';es_CO = 'No se puede firmar el archivo bloqueado.';tr = 'Kilitli dosya imzalanamıyor';it = 'Non è possibile firmare un file bloccato.';de = 'Gesperrte Datei kann nicht signiert werden.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Нельзя подписать занятый файл: %1.'; en = 'Cannot sign locked file: %1.'; pl = 'Nie można podpisać zajętego pliku: %1.';es_ES = 'No se puede firmar el archivo bloqueado: %1.';es_CO = 'No se puede firmar el archivo bloqueado: %1.';tr = 'Kilitli dosya imzalanamıyor: %1.';it = 'Impossibile accedere file bloccato: %1.';de = 'Gesperrte Datei kann nicht signiert werden: %1.'"),
			String(FileRef) );
	EndIf;
	
EndFunction

// Returns the row of the message that it is forbidden to sign an encrypted file.
//
Function EncryptedFileCannotBeSignedMessageString(FileRef = Undefined) Export
	
	If FileRef = Undefined Then
		Return NStr("ru = 'Нельзя подписать зашифрованный файл.'; en = 'Cannot sign an encrypted file.'; pl = 'Nie można podpisać zaszyfrowanego pliku.';es_ES = 'No se puede firmar el archivo codificado.';es_CO = 'No se puede firmar el archivo codificado.';tr = 'Şifrelenmiş dosya imzalanamıyor.';it = 'Impossibile firmare un file crittografato.';de = 'Verschlüsselte Datei kann nicht signiert werden.'");
	Else
		Return StringFunctionsClientServer.SubstituteParametersToString(
						NStr("ru = 'Нельзя подписать зашифрованный файл: %1.'; en = 'Cannot sign encrypted file: %1.'; pl = 'Nie można podpisać zaszyfrowanego pliku: %1.';es_ES = 'No se puede firmar el archivo codificado: %1.';es_CO = 'No se puede firmar el archivo codificado: %1.';tr = 'Şifrelenmiş dosya imzalanamıyor: %1.';it = 'Impossibile accedere file crittografato: %1.';de = 'Verschlüsselte Datei kann nicht signiert werden: %1.'"),
						String(FileRef) );
	EndIf;
	
EndFunction

// Returns a message informing about a file creation error.
//
// Parameters:
//  ErrorInformation - ErrorInformation.
//
Function ErrorCreatingNewFile(ErrorInformation) Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString(
		NStr("ru = 'Ошибка создания нового файла.
		           |
		           |%1'; 
		           |en = 'An error occurred when creating a new file.
		           |
		           |%1'; 
		           |pl = 'Wystąpił błąd podczas tworzenia nowego pliku.
		           |
		           |%1';
		           |es_ES = 'Ha ocurrido un error al crear un nuevo archivo.
		           |
		           |%1';
		           |es_CO = 'Ha ocurrido un error al crear un nuevo archivo.
		           |
		           |%1';
		           |tr = 'Yeni bir dosya oluşturulurken bir hata oluştu.
		           |
		           |%1';
		           |it = 'Si è verificato un errore durante la creazione di un nuovo file.
		           |
		           |""%1';
		           |de = 'Beim Erstellen einer neuen Datei ist ein Fehler aufgetreten.
		           |
		           |%1'"),
		BriefErrorDescription(ErrorInformation));

EndFunction

// Returns the standard error text.
Function ErrorFileNotFoundInFileStorage(FileName, SearchVolume = True, FileOwner = "") Export
	
	If SearchVolume Then
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось открыть файл:
				|%1
				|который присоединен к:
				|%2
				|по причине: двоичные данные файла были удалены. Возможно, файл очищен как ненужный или удален антивирусной программой.
				|Обратитесь к администратору.'; 
				|en = 'Cannot open the file:
				|%1
				|which is attached to:
				|%2
				|due to: binary file data was deleted. The file may have been cleaned up as unused or deleted by the antivirus application.
				|Contact administrator.'; 
				|pl = 'Nie udało się otworzyć pliku:
				|%1
				|który jest przyłączony do:
				|%2
				|z powodu: dane binarne pliku zostały usunięte. Być może plik został wyczyszczony jak niepotrzebny lub usunięty przez program antywirusowy.
				|Skontaktuj się z administratorem.';
				|es_ES = 'No se ha podido abrir el archivo:
				|%1
				|que ha sido conectado con:
				|%2
				|a causa de: los datos binarios del archivo han sido eliminados. Es posible que el archivo haya sido vaciado como inútil o haya sido eliminado por programa de antivirus.
				|Diríjase al administrador.';
				|es_CO = 'No se ha podido abrir el archivo:
				|%1
				|que ha sido conectado con:
				|%2
				|a causa de: los datos binarios del archivo han sido eliminados. Es posible que el archivo haya sido vaciado como inútil o haya sido eliminado por programa de antivirus.
				|Diríjase al administrador.';
				|tr = '
				|%1
				| ''e ekli 
				|%2
				|dosya aşağıdaki nedenle açılamadı: dosyanın ikili verileri silindi. Dosya gereksiz veya virüsten koruma programı tarafından kaldırılmış olabilir.
				| Lütfen yöneticinize başvurun.';
				|it = 'Impossibile aprire il file:
				|%1
				|allegato a:
				|%2
				|a causa di: i dati binari del file sono stati cancellati. Il file potrebbe essere stato cancellato in quanto non utilizzato o eliminato da un programma antivirus.
				|Contattare amministratore.';
				|de = 'Die Datei konnte nicht geöffnet werden:
				|%1
				|die Datei ist angehängt an:
				|%2
				|weil: die Binärdaten der Datei wurden gelöscht. Die Datei wurde möglicherweise von einem Antivirenprogramm als nicht benötigt bereinigt oder gelöscht.
				|Wenden Sie sich an den Administrator.'"),
			FileName,
			FileOwner);
			
	Else
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удалось открыть файл:
				|%1
				|который присоединен к:
				|%2
				|по причине: двоичные данные файла были удалены. Возможно, файл очищен как ненужный.
				|Обратитесь к администратору.'; 
				|en = 'Cannot open the file:
				|%1
				|which is attached to:
				|%2
				|due to: binary file data was deleted. The file may have been cleaned up as unused.
				|Contact your administrator.'; 
				|pl = 'Nie udało się otworzyć pliku:
				|%1
				|który jest przyłączony do:
				|%2
				|z powodu: dane binarne pliku zostały usunięte. Być może plik został wyczyszczony jak niepotrzebny.
				|Skontaktuj się z administratorem.';
				|es_ES = 'No se ha podido abrir el archivo:
				|%1
				|que ha sido conectado con:
				|%2
				|a causa de: los datos binarios del archivo han sido eliminados. Es posible que el archivo haya sido vaciado como inútil.
				|Diríjase al administrador.';
				|es_CO = 'No se ha podido abrir el archivo:
				|%1
				|que ha sido conectado con:
				|%2
				|a causa de: los datos binarios del archivo han sido eliminados. Es posible que el archivo haya sido vaciado como inútil.
				|Diríjase al administrador.';
				|tr = '
				|%1
				| ''e ekli 
				|%2
				|dosya aşağıdaki nedenle açılamadı: dosyanın ikili verileri silindi. Dosya gereksiz olarak kaldırılmış olabilir.
				| Lütfen yöneticinize başvurun.';
				|it = 'Impossibile aprire il file:
				|%1
				|allegato a:
				|%2
				|a causa di: i dati binari del file sono stati cancellati. Il file potrebbe essere stato cancellato in quanto non utilizzato.
				|Contattare amministratore.';
				|de = 'Die Datei:
				|%1
				|. die der Datei:
				|%2
				| angehängt ist, konnte nicht geöffnet werden, weil die Binärdatei-Daten gelöscht wurden. Die Datei wurde möglicherweise als nicht benötigt bereinigt.
				|Wenden Sie sich an den Administrator.'"),
			FileName,
			FileOwner);
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Receive a row representing the file size, for example, to display in the Status when the file is transferred.
Function GetStringWithFileSize(Val SizeInMB) Export
	
	If SizeInMB < 0.1 Then
		SizeInMB = 0.1;
	EndIf;	
	
	SizeString = ?(SizeInMB >= 1, Format(SizeInMB, "NFD=0"), Format(SizeInMB, "NFD=1; NZ=0"));
	Return SizeString;
	
EndFunction	

// The index of the file icon is being received. It is the index in the FilesIconsCollection picture.
Function GetFileIconIndex(Val FileExtention) Export
	
	If TypeOf(FileExtention) <> Type("String")
		OR IsBlankString(FileExtention) Then
		Return 0;
	EndIf;
	
	FileExtention = CommonClientServer.ExtensionWithoutPoint(FileExtention);
	
	Extension = "." + Lower(FileExtention) + ";";
	
	If StrFind(".dt;.1cd;.cf;.cfu;", Extension) <> 0 Then
		Return 6; // 1C files.
		
	ElsIf Extension = ".mxl;" Then
		Return 8; // Spreadsheet File.
		
	ElsIf StrFind(".txt;.log;.ini;", Extension) <> 0 Then
		Return 10; // Text File.
		
	ElsIf Extension = ".epf;" Then
		Return 12; // External data processors.
		
	ElsIf StrFind(".ico;.wmf;.emf;",Extension) <> 0 Then
		Return 14; // Pictures.
		
	ElsIf StrFind(".htm;.html;.url;.mht;.mhtml;",Extension) <> 0 Then
		Return 16; // HTML.
		
	ElsIf StrFind(".doc;.dot;.rtf;",Extension) <> 0 Then
		Return 18; // Microsoft Word file.
		
	ElsIf StrFind(".xls;.xlw;",Extension) <> 0 Then
		Return 20; // Microsoft Excel file.
		
	ElsIf StrFind(".ppt;.pps;",Extension) <> 0 Then
		Return 22; // Microsoft PowerPoint file.
		
	ElsIf StrFind(".vsd;",Extension) <> 0 Then
		Return 24; // Microsoft Visio file.
		
	ElsIf StrFind(".mpp;",Extension) <> 0 Then
		Return 26; // Microsoft Visio file.
		
	ElsIf StrFind(".mdb;.adp;.mda;.mde;.ade;",Extension) <> 0 Then
		Return 28; // Microsoft Access database.
		
	ElsIf StrFind(".xml;",Extension) <> 0 Then
		Return 30; // xml.
		
	ElsIf StrFind(".msg;.eml;",Extension) <> 0 Then
		Return 32; // Email.
		
	ElsIf StrFind(".zip;.rar;.arj;.cab;.lzh;.ace;",Extension) <> 0 Then
		Return 34; // Archives.
		
	ElsIf StrFind(".exe;.com;.bat;.cmd;",Extension) <> 0 Then
		Return 36; // Files being executed.
		
	ElsIf StrFind(".grs;",Extension) <> 0 Then
		Return 38; // Graphical schema.
		
	ElsIf StrFind(".geo;",Extension) <> 0 Then
		Return 40; // Geographical schema.
		
	ElsIf StrFind(".jpg;.jpeg;.jp2;.jpe;",Extension) <> 0 Then
		Return 42; // jpg.
		
	ElsIf StrFind(".bmp;.dib;",Extension) <> 0 Then
		Return 44; // bmp.
		
	ElsIf StrFind(".tif;.tiff;",Extension) <> 0 Then
		Return 46; // tif.
		
	ElsIf StrFind(".gif;",Extension) <> 0 Then
		Return 48; // gif.
		
	ElsIf StrFind(".png;",Extension) <> 0 Then
		Return 50; // png.
		
	ElsIf StrFind(".pdf;",Extension) <> 0 Then
		Return 52; // pdf.
		
	ElsIf StrFind(".odt;",Extension) <> 0 Then
		Return 54; // Open Office writer.
		
	ElsIf StrFind(".odf;",Extension) <> 0 Then
		Return 56; // Open Office math.
		
	ElsIf StrFind(".odp;",Extension) <> 0 Then
		Return 58; // Open Office Impress.
		
	ElsIf StrFind(".odg;",Extension) <> 0 Then
		Return 60; // Open Office draw.
		
	ElsIf StrFind(".ods;",Extension) <> 0 Then
		Return 62; // Open Office calc.
		
	ElsIf StrFind(".mp3;",Extension) <> 0 Then
		Return 64;
		
	ElsIf StrFind(".erf;",Extension) <> 0 Then
		Return 66; // External reports.
		
	ElsIf StrFind(".docx;",Extension) <> 0 Then
		Return 68; // Microsoft Word docx file.
		
	ElsIf StrFind(".xlsx;",Extension) <> 0 Then
		Return 70; // Microsoft Excel xlsx file.
		
	ElsIf StrFind(".pptx;",Extension) <> 0 Then
		Return 72; // Microsoft PowerPoint pptx file.
		
	ElsIf StrFind(".p7s;",Extension) <> 0 Then
		Return 74; // Signature file
		
	ElsIf StrFind(".p7m;",Extension) <> 0 Then
		Return 76; // encrypted message.
	Else
		Return 4;
	EndIf;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Other

// Removes files after importing
Procedure DeleteFilesAfterAdd(AllFilesStructureArray, AllFoldersArray) Export
	
	For Each Item In AllFilesStructureArray Do
		SelectedFile = New File(Item.FileName);
		SelectedFile.SetReadOnly(False);
		DeleteFiles(SelectedFile.FullName);
	EndDo;
	
EndProcedure

// Returns an array of files, emulating the work of FindFiles, not by file system, but by Map. If 
//  PseudoFileSystem is blank, it works with the file system.
Function FindFilesPseudo(Val PseudoFileSystem, Path) Export
	
	If PseudoFileSystem.Count() = 0 Then
		Files = FindFiles(Path, "*.*");
		Return Files;
	EndIf;
	
	Files = New Array;
	
	ValueFound = PseudoFileSystem.Get(String(Path));
	If ValueFound <> Undefined Then
		For Each FileName In ValueFound Do
			FileFromList = New File(FileName);
			Files.Add(FileFromList);
		EndDo;
	EndIf;
	
	Return Files;
	
EndFunction

// For internal use only.
Procedure FillSignatureStatus(SignatureRow) Export
	
	If Not ValueIsFilled(SignatureRow.SignatureValidationDate) Then
		SignatureRow.Status = "";
		Return;
	EndIf;
	
	If SignatureRow.SignatureCorrect Then
		SignatureRow.Status = NStr("ru = 'Верна'; en = 'Correct'; pl = 'Napraw';es_ES = 'Correcto';es_CO = 'Correcto';tr = 'Düzelt';it = 'Correggere';de = 'Korrigieren'");
	Else
		SignatureRow.Status = NStr("ru = 'Неверна'; en = 'Incorrect'; pl = 'Błędna';es_ES = 'Incorrecto';es_CO = 'Incorrecto';tr = 'Yanlış';it = 'Non corretto';de = 'Falsche'");
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// File synchronization

Function AddressInCloudService(Service, Href) Export
	
	ObjectAddress = Href;
	
	If Not IsBlankString(Service) Then
		If Service = "https://webdav.yandex.ru" Then
			ObjectAddress = StrReplace(Href, "https://webdav.yandex.ru", "https://disk.yandex.ru/client/disk");
		ElsIf Service = "https://webdav.4shared.com" Then
			ObjectAddress = "http://www.4shared.com/folder";
		ElsIf Service = "https://dav.box.com/dav" Then
			ObjectAddress = "https://app.box.com/files/0/";
		ElsIf Service = "https://dav.dropdav.com" Then
			ObjectAddress = "https://www.dropbox.com/home/";
		EndIf;
	EndIf;
	
	Return ObjectAddress;
	
EndFunction

#EndRegion

#Region Private
// Receive scanned file name of the type DM-00000012, where DM is base prefix.
//
// Parameters:
//  FileNumber  - Number - an integer, for example, 12.
//  BasePrefix - String - a base prefix, for example, DM.
//
// Returns:
//  String - the scanned file name, for example, "DM-00000012".
//
Function ScannedFileName(FileNumber, BasePrefix) Export
	
	FileName = "";
	If NOT IsBlankString(BasePrefix) Then
		FileName = BasePrefix + "-";
	EndIf;
	
	FileName = FileName + Format(FileNumber, "ND=9; NLZ=; NG=0");
	Return FileName;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Auxiliary procedures and functions.

// Extracts text in the specified encoding.
// If encoding is not specified, it calculates the encoding itself.
//
Function ExtractTextFromTextFile(FullFileName, Encoding, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient Then
	
	// Determining encoding.
	If Not ValueIsFilled(Encoding) Then
		Encoding = Undefined;
	EndIf;
	
	Try
		EncodingForRead = ?(Encoding = "utf-8_WithoutBOM", "utf-8", Encoding);
		TextReader = New TextReader(FullFileName, EncodingForRead);
		ExtractedText = TextReader.Read();
	Except
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extracts text from an OpenDocument file and returns it as a string.
//
Function ExtractOpenDocumentText(PathToFile, Cancel)
	
	ExtractedText = "";
	
#If Not WebClient AND NOT MobileClient Then
	
	TemporaryFolderForUnzipping = GetTempFileName("");
	TemporaryZIPFile = GetTempFileName("zip"); 
	
	FileCopy(PathToFile, TemporaryZIPFile);
	File = New File(TemporaryZIPFile);
	File.SetReadOnly(False);

	Try
		Archive = New ZipFileReader();
		Archive.Open(TemporaryZIPFile);
		Archive.ExtractAll(TemporaryFolderForUnzipping, ZIPRestoreFilePathsMode.Restore);
		Archive.Close();
		XMLReader = New XMLReader();
		
		XMLReader.OpenFile(TemporaryFolderForUnzipping + "/content.xml");
		ExtractedText = ExtractTextFromXMLContent(XMLReader);
		XMLReader.Close();
	Except
		// This is not an error because the OTF extension, for example, is related both to OpenDocument format and OpenType font format.
		Archive     = Undefined;
		XMLReader = Undefined;
		Cancel = True;
		ExtractedText = "";
	EndTry;
	
	DeleteFiles(TemporaryFolderForUnzipping);
	DeleteFiles(TemporaryZIPFile);
	
#EndIf
	
	Return ExtractedText;
	
EndFunction

// Extract text from the XMLReader object (that was read from an OpenDocument file).
Function ExtractTextFromXMLContent(XMLReader)
	
	ExtractedText = "";
	LastTagName = "";
	
#If Not WebClient Then
	
	While XMLReader.Read() Do
		
		If XMLReader.NodeType = XMLNodeType.StartElement Then
			
			LastTagName = XMLReader.Name;
			
			If XMLReader.Name = "text:p" Then
				If NOT IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:line-break" Then
				If NOT IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.LF;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:tab" Then
				If NOT IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + Chars.Tab;
				EndIf;
			EndIf;
			
			If XMLReader.Name = "text:s" Then
				
				AdditionString = " "; // space
				
				If XMLReader.AttributeCount() > 0 Then
					While XMLReader.ReadAttribute() Do
						If XMLReader.Name = "text:c"  Then
							SpaceCount = Number(XMLReader.Value);
							AdditionString = "";
							For Index = 0 To SpaceCount - 1 Do
								AdditionString = AdditionString + " "; // space
							EndDo;
						EndIf;
					EndDo
				EndIf;
				
				If NOT IsBlankString(ExtractedText) Then
					ExtractedText = ExtractedText + AdditionString;
				EndIf;
			EndIf;
			
		EndIf;
		
		If XMLReader.NodeType = XMLNodeType.Text Then
			
			If StrFind(LastTagName, "text:") <> 0 Then
				ExtractedText = ExtractedText + XMLReader.Value;
			EndIf;
			
		EndIf;
		
	EndDo;
	
#EndIf

	Return ExtractedText;
	
EndFunction

Function IsReservedDirectoryName(SubDirectoryName)
	
	NamesList = New Map();
	NamesList.Insert("CON", True);
	NamesList.Insert("PRN", True);
	NamesList.Insert("AUX", True);
	NamesList.Insert("NUL", True);
	
	Return NamesList[SubDirectoryName] <> Undefined;
	
EndFunction

// Initializes a structure of parameters for adding a file.
// Use this function in FilesOperations.AddToFile and FilesOperationsInternalServerCall.AddFile.
//
Function FileAddingOptions(AdditionalAttributes = Undefined) Export
	
	If TypeOf(AdditionalAttributes) = Type("Structure") Then
		FileAttributes = Undefined;
		AddingOptions = AdditionalAttributes;
	Else
		
		AddingOptions = New Structure;
		FileAttributes = ?(TypeOf(AdditionalAttributes) = Type("Array"),
			AdditionalAttributes,
			StringFunctionsClientServer.SplitStringIntoSubstringsArray(AdditionalAttributes, ",", True, True));
		
	EndIf;
	
	AddProperty(AddingOptions, "Author");
	AddProperty(AddingOptions, "FilesOwner");
	AddProperty(AddingOptions, "BaseName", "");
	AddProperty(AddingOptions, "ExtensionWithoutPoint", "");
	AddProperty(AddingOptions, "ModificationTimeUniversal");
	AddProperty(AddingOptions, "GroupOfFiles");
	AddProperty(AddingOptions, "Internal", False);
	
	If FileAttributes = Undefined Then
		Return AddingOptions;
	EndIf;
	
	For Each AdditionalAttribute In FileAttributes Do
		AddProperty(AddingOptions, AdditionalAttribute);
	EndDo;
	
	Return AddingOptions;
	
EndFunction

Procedure AddProperty(Collection, varKey, Value = Undefined)
	
	If Not Collection.Property(varKey) Then
		Collection.Insert(varKey, Value);
	EndIf;
	
EndProcedure

#EndRegion