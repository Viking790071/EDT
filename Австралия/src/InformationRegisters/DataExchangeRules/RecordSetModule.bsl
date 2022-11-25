#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each Record In ThisObject Do
		
		If Record.DebugMode Then
			
			ExchangePlanID = Common.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
			ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
			SecurityProfileName = ModuleSafeModeManagerInternal.ExternalModuleAttachmentMode(ExchangePlanID);
			
			If SecurityProfileName <> Undefined Then
				SetSafeMode(SecurityProfileName);
			EndIf;
			
			IsFileInfobase = Common.FileInfobase();
			
			If Record.ExportDebugMode Then
				
				CheckExternalDataProcessorFileExistence(Record.ExportDebuggingDataProcessorFileName, IsFileInfobase, Cancel);
				
			EndIf;
			
			If Record.ImportDebugMode Then
				
				CheckExternalDataProcessorFileExistence(Record.ImportDebuggingDataProcessorFileName, IsFileInfobase, Cancel);
				
			EndIf;
			
			If Record.DataExchangeLoggingMode Then
				
				CheckExchangeProtocolFileAvailability(Record.ExchangeProtocolFileName, Cancel);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Procedure CheckExternalDataProcessorFileExistence(NameOfCheckedFile, IsFileInfobase, Cancel)
	
	FileNameStructure = CommonClientServer.ParseFullFileName(NameOfCheckedFile);
	FileName = FileNameStructure.BaseName;
	CheckDirectoryName	 = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	FileOnHardDrive = New File(NameOfCheckedFile);
	DirectoryLocation = ? (IsFileInfobase, NStr("ru = 'на клиенте'; en = 'on client'; pl = 'na kliencie';es_ES = 'en el cliente';es_CO = 'en el cliente';tr = 'istemcide';it = 'su client';de = 'auf Kunde'"), NStr("ru = 'на сервере'; en = 'on the server'; pl = 'na serwerze';es_ES = 'en servidor';es_CO = 'en servidor';tr = 'sunucuda';it = 'sul server';de = 'auf dem server'"));
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("ru = 'Каталог ""%1"" не найден %2.'; en = 'Directory %1 not found %2.'; pl = 'Nie znaleziono %2 katalogu %1.';es_ES = 'El  directorio ""%1"" no se ha encontrado %2.';es_CO = 'El  directorio ""%1"" no se ha encontrado %2.';tr = '""%1"" dizini bulunamadı%2.';it = 'Directory %1 non trovata %2.';de = 'Das Verzeichnis ""%1"" wurde nicht gefunden %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, CheckDirectoryName, DirectoryLocation);
		Cancel = True;
		
	ElsIf Not FileOnHardDrive.Exist() Then 
		
		MessageString = NStr("ru = 'Файл внешней обработки ""%1"" не найден %2.'; en = 'File of external data processor %1 not found %2.'; pl = 'Nie znaleziono %2 pliku ""%1"" zewnętrznego przetwarzania danych.';es_ES = 'Archivo del procesador de datos externo ""%1"" no se ha encontrado %2.';es_CO = 'Archivo del procesador de datos externo ""%1"" no se ha encontrado %2.';tr = 'Harici veri işlemci dosyası ""%1"" bulunamadı%2.';it = 'File di elaboratore dati esterno %1 non trovato %2.';de = 'Externe Datenprozessordatei ""%1"" wurde nicht gefunden %2.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, NameOfCheckedFile, DirectoryLocation);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Procedure CheckExchangeProtocolFileAvailability(ExchangeProtocolFileName, Cancel)
	
	FileNameStructure = CommonClientServer.ParseFullFileName(ExchangeProtocolFileName);
	CheckDirectoryName = FileNameStructure.Path;
	CheckDirectory = New File(CheckDirectoryName);
	CheckFileName = "test.tmp";
	
	If Not CheckDirectory.Exist() Then
		
		MessageString = NStr("ru = 'Каталог файла протокола обмена ""%1"" не найден.'; en = 'Exchange protocol file directory %1 not found.'; pl = 'Nie znaleziono katalogu pliku protokołu wymiany ""%1"".';es_ES = 'El directorio de archivos del protocolo de intercambio ""%1"" no se ha encontrado.';es_CO = 'El directorio de archivos del protocolo de intercambio ""%1"" no se ha encontrado.';tr = '""%1"" alışveriş protokolü dosya dizini bulunamadı.';it = 'Directory del file del protocollo di scambio %1 non trovata.';de = 'Das ""%1"" Austauschprotokoll Dateiverzeichnis wird nicht gefunden.'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not CreateCheckFile(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("ru = 'Не удалось создать файл в папке протокола обмена: ""%1"".'; en = 'Cannot create a file in the exchange protocol folder: ""%1"".'; pl = 'Nie można utworzyć pliku w katalogu protokołu wymiany: ""%1"".';es_ES = 'No se puede crear un archivo en la carpeta del protocolo de intercambio: ""%1"".';es_CO = 'No se puede crear un archivo en la carpeta del protocolo de intercambio: ""%1"".';tr = 'Değişim protokolü klasöründe bir dosya oluşturulamıyor: ""%1"".';it = 'Non è possibile creare un file nella cartella protocollo di scambio: ""%1"".';de = 'Kann eine Datei nicht im Austausch-Protokollordner erstellen: ""%1"".'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	ElsIf Not DeleteCheckFiles(CheckDirectoryName, CheckFileName) Then
		
		MessageString = NStr("ru = 'Не удалось удалить файл в папке протокола обмена: ""%1"".'; en = 'Cannot delete file from the exchange protocol folder: ""%1"".'; pl = 'Nie można usunąć pliku z katalogu protokołu wymiany: ""%1"".';es_ES = 'No se puede borrar el archivo de la carpeta del protocolo de intercambio: ""%1"".';es_CO = 'No se puede borrar el archivo de la carpeta del protocolo de intercambio: ""%1"".';tr = 'Değişim protokolü klasöründen dosya silinemiyor: ""%1"".';it = 'Impossibile eliminare il file dalla cartella protocollo di scambio: ""%1"".';de = 'Datei kann nicht aus dem Austausch-Protokollordner gelöscht werden: ""%1"".'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, CheckDirectoryName);
		Cancel = True;
		
	Else
		
		Return;
		
	EndIf;
	
	CommonClientServer.MessageToUser(MessageString,,,, Cancel);
	
EndProcedure

Function CreateCheckFile(CheckDirectoryName, CheckFileName)
	
	TextDocument = New TextDocument;
	TextDocument.AddLine(NStr("ru = 'Временный файл проверки'; en = 'Temporary file for checking access to directory'; pl = 'Tymczasowy plik sprawdzenia';es_ES = 'Archivo de revisión temporal';es_CO = 'Archivo de revisión temporal';tr = 'Geçici kontrol dosyası';it = 'File temporaneo per controllare l''accesso alla directory';de = 'Temporäre Prüfdatei'"));
	
	Try
		TextDocument.Write(CheckDirectoryName + "/" + CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

Function DeleteCheckFiles(CheckDirectoryName, CheckFileName)
	
	Try
		DeleteFiles(CheckDirectoryName, CheckFileName);
	Except
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#EndIf