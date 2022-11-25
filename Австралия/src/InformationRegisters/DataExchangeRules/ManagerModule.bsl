#Region EventHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormType = "RecordForm" Then
		
		StandardProcessing = False;
		
		If Parameters.Key.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectConversionRules";
			
		ElsIf Parameters.Key.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules Then
			
			SelectedForm = "InformationRegister.DataExchangeRules.Form.ObjectsRegistrationRules";
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Internal

Function ConversionRulesCompatibleWithCurrentVersion(ExchangePlanName, ErrorDescription, RulesData) Export
	
	If Not DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, "WarnAboutExchangeRuleVersionMismatch") Then
		Return True;
	EndIf;
	
	NameOfConfigurationFormRules = Upper(RulesData.ConfigurationName);
	InfobaseConfigurationName = StrReplace(Upper(Metadata.Name), "BASE", "");
	If NameOfConfigurationFormRules <> InfobaseConfigurationName Then
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorKind", "InvalidConfiguration");
		ErrorDescription.Insert("Picture",  PictureLib.Error32);
		
		ErrorDescription.Insert("ErrorText",
			NStr("ru = 'Правила не могут быть загружены, так как они предназначены для программы ""%1"".
			|Следует использовать правила из конфигурации или загрузить корректный комплект правил из файла.'; 
			|en = 'Rules cannot be imported as they are intended for %1 application . 
			|Use rules from the configuration, or import a correct set of rules from file.'; 
			|pl = 'Nie można wczytać reguł, ponieważ są one przeznaczone dla programu ""%1"".
			| Należy użyć reguł z konfiguracji lub załadować poprawny zestaw reguł z pliku.';
			|es_ES = 'Las reglas no puede ser descargadas porque no están destinadas para el programa ""%1"".
			|Hay que usar las reglas de la configuración o descargar un conjunto correcto de reglas del archivo.';
			|es_CO = 'Las reglas no puede ser descargadas porque no están destinadas para el programa ""%1"".
			|Hay que usar las reglas de la configuración o descargar un conjunto correcto de reglas del archivo.';
			|tr = 'Kurallar, ""%1"" uygulaması için tasarlandıklarından içe aktarılamaz. 
			|Kuralları yapılandırmadan kullanmalı veya dosyadan ayarlanmış doğru kuralları içe aktarılmalıdır.';
			|it = 'Le regole non possono essere importate perché sono destinate all''applicazione %1. 
			|Utilizza le regole dalla configurazione o importa da dile un insieme di regole corretto.';
			|de = 'Regeln können nicht geladen werden, da sie für das Programm ""%1"" bestimmt sind.
			|Sie sollten die Regeln aus der Konfiguration verwenden oder das richtige Regelwerk aus der Datei herunterladen.'"));
		ErrorDescription.ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorDescription.ErrorText,
			RulesData.ConfigurationSynonymInRules);
		
		Return False;
		
	EndIf;
	
	VersionInRules    = CommonClientServer.ConfigurationVersionWithoutBuildNumber(RulesData.ConfigurationVersion);
	ConfigurationVersion = CommonClientServer.ConfigurationVersionWithoutBuildNumber(Metadata.Version);
	ComparisonResult = CommonClientServer.CompareVersionsWithoutBuildNumber(VersionInRules, ConfigurationVersion);
	
	If ComparisonResult <> 0 Then
		
		If ComparisonResult < 0 Then
			
			ErrorText = NStr("ru = 'Синхронизация данных может работать некорректно, так как загружаемые правила предназначены для предыдущей версии программы ""%1"" (%2).
			|Рекомендуется использовать правила из конфигурации или загрузить комплект правил, предназначенный для текущей версии программы (%3).'; 
			|en = 'Data may be synced incorrectly because rules you want to import are designed for the previous version of %1 application (%2).
			| Use the rules designed for the configuration, or import a set of rules designed for the current application version (%3).'; 
			|pl = 'Synchronizacja danych może nie działać poprawnie, ponieważ załadowane reguły są przeznaczone dla poprzedniej wersji programu ""%1"" (%2). 
			|Zalecane jest użycie reguł z konfiguracji lub załadowanie zestawu reguł przeznaczonych dla bieżącej wersji programu (%3).';
			|es_ES = 'La sincronización de datos puede funcionar incorrectamente porque las reglas descargadas están destinadas para la versión anterior del programa ""%1"" (%2).
			|Se recomienda usar las reglas de la configuración o descargar un conjunto de reglas destinado para la versión actual del programa (%3).';
			|es_CO = 'La sincronización de datos puede funcionar incorrectamente porque las reglas descargadas están destinadas para la versión anterior del programa ""%1"" (%2).
			|Se recomienda usar las reglas de la configuración o descargar un conjunto de reglas destinado para la versión actual del programa (%3).';
			|tr = 'Veriler, ""%1"" (%2) uygulamasının önceki sürümü için tasarlanmış kuralları kullandığınız için yanlış senkronize edilebilir. 
			|Yapılandırma için tasarlanmış kuralları kullanın veya geçerli uygulama sürümü (%3) için tasarlanmış kural kümesini içe aktarın.';
			|it = 'I dati potrebbero essere sincronizzati non correttamente perché le regole che vuoi importare sono destinate alla versione precedente dell''applicazione %1 (%2).
			|Utilizza le regole di questa configurazione o importa un insieme di regole destinate alla versione attuale dell''applicazione (%3).';
			|de = 'Die Synchronisation von Daten funktioniert möglicherweise nicht korrekt, da die herunterladbaren Regeln für die vorherige Version des Programms ""%1"" (%2) bestimmt sind.
			|Es wird empfohlen, die Regeln aus der Konfiguration zu verwenden oder das Regelwerk für die aktuelle Version des Programms herunterzuladen (%3).'");
			ErrorKind = "ObsoleteRules";
			
		Else
			
			ErrorText = NStr("ru = 'Синхронизация данных может работать некорректно, так как загружаемые правила предназначены для более новой версии программы ""%1"" (%2).
			|Рекомендуется обновить версию программы или использовать комплект правил, предназначенный для текущей версии программы (%3).'; 
			|en = 'Data may be synced incorrectly because rules you want to import are designed for a newer version of %1 application (%2).
			| Update version of the application, or use a set of rules designed for the current application version (%3).'; 
			|pl = 'Synchronizacja danych może nie działać poprawnie, ponieważ załadowane reguły dotyczą nowszej wersji programu ""%1"" (%2). 
			| Zaleca się aktualizację wersji programu lub użycie zestawu reguł przeznaczonych dla bieżącej wersji programu (%3).';
			|es_ES = 'La sincronización de datos puede funcionar incorrectamente porque las reglas descargadas están destinadas para la versión más nueva del programa ""%1"" (%2).
			|Se recomienda actualizar la versión del programa o usar un conjunto de reglas destinado para la versión actual del programa (%3).';
			|es_CO = 'La sincronización de datos puede funcionar incorrectamente porque las reglas descargadas están destinadas para la versión más nueva del programa ""%1"" (%2).
			|Se recomienda actualizar la versión del programa o usar un conjunto de reglas destinado para la versión actual del programa (%3).';
			|tr = 'Veriler, ""%1"" (%2) uygulamasının daha yeni sürümü için tasarlanmış kuralları kullandığınız için yanlış senkronize edilebilir. 
			|Uygulamanın sürümünü güncelleyin veya geçerli uygulama sürümü (%3) için tasarlanmış kural kümesini kullanın.';
			|it = 'I dati potrebbero essere sincronizzati non correttamente perché le regole che vuoi importare sono destinate alla versione più recente dell''applicazione %1 (%2).
			| Aggiorna la versione dell''applicazione o utilizza l''insieme di regole destinate alla versione attuale dell''applicazione (%3).';
			|de = 'Die Synchronisation von Daten funktioniert möglicherweise nicht korrekt, da die herunterladbaren Regeln für eine neuere Version des Programms ""%1"" (%2) bestimmt sind.
			|Es wird empfohlen, die Version des Programms zu aktualisieren oder ein Regelwerk zu verwenden, das für die aktuelle Version des Programms ausgelegt ist (%3).'");
			ErrorKind = "ObsoleteConfigurationVersion";
			
		EndIf;
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersToString(ErrorText,
			Metadata.Synonym, VersionInRules, ConfigurationVersion);
		
		ErrorDescription = New Structure;
		ErrorDescription.Insert("ErrorText", ErrorText);
		ErrorDescription.Insert("ErrorKind",   ErrorKind);
		ErrorDescription.Insert("Picture",    PictureLib.Warning32);
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

#EndRegion
	
#Region Private

// Imports supplied rules for the exchange plan.
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//	RulesFileName - String - a full name of exchange rules file (ZIP).
//
Procedure ImportSuppliedRules(ExchangePlanName, RulesFileName) Export
	
	File = New File(RulesFileName);
	FileName = File.Name;
	
	// Extracting data from the archive
	TempFolderName = GetTempFileName("");
	If DataExchangeServer.UnpackZipFile(RulesFileName, TempFolderName) Then
		
		UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
		
		// Canceling import if the archive contains no files.
		If UnpackedFileList.Count() = 0 Then
			Raise NStr("ru = 'При распаковке архива не найден файл с правилами.'; en = 'There is no rule file in the archive.'; pl = 'Podczas rozpakowywania archiwum nie znaleziono pliku z regułami.';es_ES = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';es_CO = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';tr = 'Arşiv açılırken, kural dosyası bulunamadı.';it = 'Nessun file di regole nell''archivio.';de = 'Beim Entpacken des Archivs wurde keine Datei mit Regeln gefunden.'");
		EndIf;
		
		// Canceling import if number of files in the archive does not match the expected number.
		If UnpackedFileList.Count() <> 3 Then
			Raise NStr("ru = 'Не верный формат комплекта правил. Ожидаемое количество файлов в архиве - три. Ожидаются файлы:
			|ExchangeRules.xml - правила конвертации для текущей программы;
			|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
			|RegistrationRules.xml - правила регистрации для текущей программы.'; 
			|en = 'Incorrect format of rule set. Expected number of files in the archive is three. Expected files:
			|ExchangeRules.xml - conversion rules for the current application;
			|CorrespondentExchangeRules.xml - conversion rules for the correspondent application;
			|RegistrationRules.xml - registration rules of for the current application.'; 
			|pl = 'Błędny format zestawu reguł. Spodziewana liczba plików w archiwum – to trzy. Oczekiwane są następujące pliki:
			|ExchangeRules.xml – zasady konwersji do bieżącego programu;
			|CorrespondentExchangeRules.xml – zasady konwersji do programu-korespondenta;
			|RegistrationRules.xml – zasady rejestracji do bieżącego programu.';
			|es_ES = 'Formato del conjunto de reglas incorrecto. Cantidad de los documentos esperada en el archivo - tres. Documentos esperados:
			|ExchangeRules.xml - reglas de conversión para el programa actual; 
			|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
			| RegistrationRules.xml - reglas de registro para el programa actual.';
			|es_CO = 'Formato del conjunto de reglas incorrecto. Cantidad de los documentos esperada en el archivo - tres. Documentos esperados:
			|ExchangeRules.xml - reglas de conversión para el programa actual; 
			|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
			| RegistrationRules.xml - reglas de registro para el programa actual.';
			|tr = 'Yanlış kurallar kümesinin biçimi. Arşivde beklenen dosya sayısı - üç. 
			|Beklenen dosyalar: ExchangeRules.xml - geçerli uygulama için 
			|dönüşüm kuralları; CorrespondentExchangeRules.xml - uygulama muhabiri için dönüşüm 
			|kuralları; RegistrationRules.xml - mevcut uygulama için kayıt kuralları.';
			|it = 'Formato non coretto dell''insieme di regole. Il numero previsto di file nell''archivio è tre. File attesi: 
			|ExchangeRules.xml - regole di conversione per l''applicazione attuale; 
			|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente; 
			|RegistrationRules.xml - regole di registrazione dell''applicazione attuale.';
			|de = 'Falsches Format des Regelsatzes. Die erwartete Anzahl der Dateien im Archiv beträgt drei. Es werden Dateien erwartet:
			|ExchangeRules.xml - Konvertierungsregeln für das aktuelle Programm;
			|CorrespondentExchangeRules.xml - Konvertierungsregeln für das entsprechende Programm;
			|RegistrationRules.xml - Registrierungsregeln für das aktuelle Programm.'");
		EndIf;
		
		// Saving received file to the binary data.
		For Each ReceivedFile In UnpackedFileList Do
			
			If ReceivedFile.Name = "ExchangeRules.xml" Then
				BinaryData = New BinaryData(ReceivedFile.FullName);
			ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
				CorrespondentBinaryData = New BinaryData(ReceivedFile.FullName);
			ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
				RegistrationBinaryData = New BinaryData(ReceivedFile.FullName);
			Else
				Raise NStr("ru = 'Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
				|ExchangeRules.xml - правила конвертации для текущей программы;
				|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
				|RegistrationRules.xml - правила регистрации для текущей программы.'; 
				|en = 'File names in the archive are not as expected. Expected files:
				|ExchangeRules.xml - conversion rules for the current application;
				|CorrespondentExchangeRules.xml - conversion rules for the correspondent application;
				|RegistrationRules.xml - registration rules for the current application.'; 
				|pl = 'Nazwy plików w archiwum różnią się od oczekiwanych. Oczekiwane pliki
				|: ExchangeRules.xml - reguły konwersji dla
				|bieżącej aplikacji; CorrespondentExchangeRules.xml - reguły konwersji
				|dla aplikacji korespondenta; RegistrationRules.xml - reguły rejestracji dla bieżącej aplikacji.';
				|es_ES = 'Nombres de documentos en el archivo no corresponden a los esperados. Documentos esperados: 
				|ExchangeRules.xml - reglas de conversión para la aplicación actual;
				|CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal;
				|RegistrationRules.xml - reglas de registro para la aplicación actual.';
				|es_CO = 'Nombres de documentos en el archivo no corresponden a los esperados. Documentos esperados: 
				|ExchangeRules.xml - reglas de conversión para la aplicación actual;
				|CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal;
				|RegistrationRules.xml - reglas de registro para la aplicación actual.';
				|tr = 'Arşivdeki dosya adları beklenen değerlerle uyuşmuyor. Dosyalar bekleniyor: 
				| ExchangeRules.xml - mevcut uygulama için dönüşüm kuralları; 
				| CorrespondentExchangeRules.xml - uygulama muhabiri için dönüşüm kuralları; 
				| RegistrationRules.xml - mevcut uygulama için kayıt kuralları.';
				|it = 'I nomi dei file nell''archivio non corrispondono a quelli previsti. File previsti:
				|ExchangeRules.xml - regole di conversione per l''applicazione attuale;
				|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente;
				|RegistrationRules.xml - regole di registrazione per l''applicazione attuale.';
				|de = 'Dateinamen im Archiv entsprechen nicht den erwarteten. Dateien werden erwartet:
				|ExchangeRules.xml - Konvertierungsregeln für die aktuelle Anwendung.
				|CorrespondentExchangeRules.xml - Konvertierungsregeln für Anwendungskorrespondent.
				|RegistrationRules.xml - Registrierungsregeln für die aktuelle Anwendung.'");
			EndIf;
			
		EndDo;
		
	Else
		// Canceling import if unpacking the file failed.
		Raise NStr("ru = 'Не удалось распаковать архив с правилами.'; en = 'Failed unpacking the file.'; pl = 'Nie można rozpakować archiwum z regułami.';es_ES = 'No se puede desembalar un archivo con reglas.';es_CO = 'No se puede desembalar un archivo con reglas.';tr = 'Bir arşiv kurallar ile açılamıyor.';it = 'Estrazione file non riuscita.';de = 'Ein Archiv mit Regeln kann nicht entpackt werden.'");
	EndIf;
	
	// Deleting the temporary archive and the temporary directory where the archive was unpacked.
	DeleteTempFile(TempFolderName);
	
	ConversionRulesInformation = "[SourceRulesInformation]
		|
		|[CorrespondentRulesInformation]";
		
	// Getting the temporary conversion file name in the local file system at server.
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file.
	BinaryData.Write(TempFileName);
	
	// Reading conversion rules.
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "DataExported";
	InfobaseObjectConversion.ExchangePlanNameSOR = ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, ExchangePlanName, False);
	
	RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
	
	SourceRulesInformation = InfobaseObjectConversion.RulesInformation(False);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	// Getting name of the temporary correspondent conversion file in the local file system on the server.
	CorrespondentTempFileName = GetTempFileName("xml");
	// Getting the conversion rule file.
	CorrespondentBinaryData.Write(CorrespondentTempFileName);
	
	// Reading conversion rules.
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "Load";
	InfobaseObjectConversion.ExchangePlanNameSOR = ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	// Data processor methods
	ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
	
	CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", CorrespondentRulesInformation);
	
	// Getting the temporary registration file name in the local file system on the server.
	TempRegistrationFileName = GetTempFileName("xml");
	// Getting the conversion rule file.
	RegistrationBinaryData.Write(TempRegistrationFileName);
	
	// Reading registration rules.
	ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
	
	// Data processor properties
	ChangeRecordRuleImport.ExchangePlanNameForImport = ExchangePlanName;
	
	// Data processor methods
	ChangeRecordRuleImport.ImportRules(TempRegistrationFileName);
	ReadRegistrationRules   = ChangeRecordRuleImport.ObjectsRegistrationRules;
	RegistrationRulesInformation = ChangeRecordRuleImport.RulesInformation();
	
	If ChangeRecordRuleImport.ErrorFlag Then
		Raise NStr("ru = 'Ошибка при загрузке правил регистрации.'; en = 'An error occurred when importing registration rules.'; pl = 'Podczas importu reguł rejestracji wystąpił błąd.';es_ES = 'Ha ocurrido un error al importar las reglas del registro de la importación.';es_CO = 'Ha ocurrido un error al importar las reglas del registro de la importación.';tr = 'Kayıt kuralları içe aktarılırken bir hata oluştu';it = 'Si è verificato un errore durante l''importazione regole di registrazione.';de = 'Beim Importieren der Registrierungsregeln ist ein Fehler aufgetreten.'");
	EndIf;
	
	// Deleting temporary rule files.
	DeleteTempFile(TempFileName);
	DeleteTempFile(CorrespondentTempFileName);
	DeleteTempFile(TempRegistrationFileName);
	
	// Writing conversion rules.
	CovnersionRuleWriting = CreateRecordManager();
	CovnersionRuleWriting.ExchangePlanName = ExchangePlanName;
	CovnersionRuleWriting.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules;
	CovnersionRuleWriting.RulesTemplateName = "ExchangeRules";
	CovnersionRuleWriting.CorrespondentRuleTemplateName = "CorrespondentExchangeRules";
	CovnersionRuleWriting.ExchangePlanNameFromRules = ExchangePlanName;
	CovnersionRuleWriting.RulesFileName = FileName;
	CovnersionRuleWriting.RulesInformation = ConversionRulesInformation;
	CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File;
	CovnersionRuleWriting.XMLRules = New ValueStorage(BinaryData, New Deflation());
	CovnersionRuleWriting.XMLCorrespondentRules = New ValueStorage(CorrespondentBinaryData, New Deflation());
	CovnersionRuleWriting.RulesAreRead = New ValueStorage(RulesAreRead);
	CovnersionRuleWriting.CorrespondentRulesAreRead = New ValueStorage(ReadCorrespondentRules);
	CovnersionRuleWriting.DebugMode = False;
	CovnersionRuleWriting.UseSelectiveObjectRegistrationFilter = True;
	CovnersionRuleWriting.RulesAreImported = True;
	CovnersionRuleWriting.Write();
	
	// Writing registration rules.
	RegistrationRuleWriting = CreateRecordManager();
	RegistrationRuleWriting.ExchangePlanName = ExchangePlanName;
	RegistrationRuleWriting.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	RegistrationRuleWriting.RulesTemplateName = "RecordRules";
	RegistrationRuleWriting.ExchangePlanNameFromRules = ExchangePlanName;
	RegistrationRuleWriting.RulesFileName = FileName;
	RegistrationRuleWriting.RulesInformation = RegistrationRulesInformation;
	RegistrationRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File;
	RegistrationRuleWriting.XMLRules = New ValueStorage(RegistrationBinaryData, New Deflation());
	RegistrationRuleWriting.RulesAreRead = New ValueStorage(ReadRegistrationRules);
	RegistrationRuleWriting.RulesAreImported = True;
	RegistrationRuleWriting.Write();
	
EndProcedure

// Deletes supplied rules for the exchange plan (clears data in the register).
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being deleted.
//
Procedure DeleteSuppliedRules(ExchangePlanName) Export
	
	For Each RulesKind In Enums.DataExchangeRulesTypes Do
		
		RecordManager = CreateRecordManager();
		RecordManager.RulesKind = RulesKind;
		RecordManager.ExchangePlanName = ExchangePlanName;
		RecordManager.Read();
		RecordManager.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate;
		HasErrors = False;
		ImportRules(HasErrors, RecordManager);
		If HasErrors Then
			Raise NStr("ru = 'Ошибка при загрузке правил из конфигурации.'; en = 'An error occurred when importing rules from configuration.'; pl = 'Podczas importu reguł z konfiguracji wystąpił błąd.';es_ES = 'Ha ocurrido un error al importar las reglas de la configuración.';es_CO = 'Ha ocurrido un error al importar las reglas de la configuración.';tr = 'Kurallar yapılandırmadan içe aktarılırken bir hata oluştu';it = 'Si è verificato un errore durante l''importazione regole dalla configurazione.';de = 'Beim Importieren von Regeln aus der Konfiguration ist ein Fehler aufgetreten.'");
		Else
			RecordManager.Write();
		EndIf;
		
	EndDo;
	
EndProcedure

// Determines whether standard conversion rules are used for the exchange plan.
//
// Parameters:
//	ExchangePlanName - String - a name of the exchange plan for which the rules are being imported.
//
// Returns:
//   Boolean - if True, the rules are used. Otherwise, False.
//
Function StandardRulesUsed(ExchangePlanName) Export
	QueryText = "
	|SELECT
	|	DataExchangeRules.XMLRules AS XMLRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind      = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.RulesAreImported
	|";
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return False;
	EndIf;
	Selection = Result.Select();
	Selection.Next();
	
	RuleBinaryData = Selection.XMLRules.Get();
	TempFileName = GetTempFileName("xml");
	RuleBinaryData.Write(TempFileName);
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(TempFileName);
	StandardRules = False;
	While ExchangeRules.Read() Do
		NodeName = ExchangeRules.LocalName;
		If NodeName = "FormatVersion" Then
			While ExchangeRules.ReadAttribute() Do
				If ExchangeRules.LocalName = "Standard" Then
					StandardRules = True;
					Break;
				EndIf;
			EndDo;
			Break;
		EndIf;
	EndDo;
	ExchangeRules.Close();
	DeleteFiles(TempFileName);
	
	Return StandardRules;
EndFunction

// Imports rules to the register.
//
// Parameters:
//	Cancel - Boolean - cancel recording.
//	Record - InformationRegisterRecord.DataExchangeRules - register record where data will be placed.
//	TempStorageAddress - String - an address of temporary storage, from which XML rules are imported.
//	RulesFileName - String - a name of the file, from which the files are imported (it is also written to the register).
//	BinaryData - BinaryData - data that will store the XML file (including XML files unpacked from a ZIP archive).
//	IsArchive - Boolean - indicates that rules are imported from a ZIP archive, not from an XML file.
//
Procedure ImportRules(Cancel, Record, TempStorageAddress = "", RulesFileName = "", IsArchive = False) Export
	
	// Checking if the exchange plan exists.
	ExchangePlanList = DataExchangeCached.SSLExchangePlans();
	If ExchangePlanList.Find(Record.ExchangePlanName) = Undefined Then
		NString = NStr("ru = 'План обмена %1 не используется для синхронизации данных, правила не обновлены.'; en = 'Exchange plan %1 is not used for data synchronization, the rules are not updated.'; pl = 'Plan wymiany %1 nie jest używany do synchronizacji danych, reguły nie są aktualizowane.';es_ES = 'Plan de cambio %1 no se usa para sincronizar los datos, reglas no actualizadas.';es_CO = 'Plan de cambio %1 no se usa para sincronizar los datos, reglas no actualizadas.';tr = 'Alışveriş planı %1 veri eşleşmesi için kullanılmıyor, kurallar güncellenmedi.';it = 'Il piano di scambio %1 non è usato per la sincronizzazione dati, le regole non sono aggiornate.';de = 'Der Austauschplan %1 wird nicht zur Datensynchronisation verwendet, die Regeln werden nicht aktualisiert.'");
		NString = StringFunctionsClientServer.SubstituteParametersToString(NString, Record.ExchangePlanName);
		DataExchangeServer.ReportError(NString, Cancel);
	Else
		// Checking whether record mandatory fields are filled.
		CheckFieldsFilled(Cancel, Record);
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	IsConversionRules = (Record.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules);
	
	// Getting rule binary data from file or configuration template.
	If Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate Then
		
		BinaryData = BinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.RulesTemplateName);
		
		If IsConversionRules Then
			
			If IsBlankString(Record.CorrespondentRuleTemplateName) Then
				Record.CorrespondentRuleTemplateName = Record.RulesTemplateName + "Correspondent";
			EndIf;
			CorrespondentBinaryData = BinaryDataFromConfigurationTemplate(Cancel, Record.ExchangePlanName, Record.CorrespondentRuleTemplateName);
			
		EndIf;
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	// If rules are packed into an archive, unpacking the archive and converting the rules data to binary.
	If IsArchive Then
		
		// Getting the archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extracting data from the archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// Canceling import if the archive contains no files.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("ru = 'При распаковке архива не найден файл с правилами.'; en = 'There is no rule file in the archive.'; pl = 'Podczas rozpakowywania archiwum nie znaleziono pliku z regułami.';es_ES = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';es_CO = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';tr = 'Arşiv açılırken, kural dosyası bulunamadı.';it = 'Nessun file di regole nell''archivio.';de = 'Beim Entpacken des Archivs wurde keine Datei mit Regeln gefunden.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			If IsConversionRules Then
				
				// Saving received file to the binary data.
				If UnpackedFileList.Count() = 2 Then
					
					If UnpackedFileList[0].Name = "ExchangeRules.xml" 
						AND UnpackedFileList[1].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[0].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[1].FullName);
						
					ElsIf UnpackedFileList[1].Name = "ExchangeRules.xml" 
						AND UnpackedFileList[0].Name ="CorrespondentExchangeRules.xml" Then
						
						BinaryData = New BinaryData(UnpackedFileList[1].FullName);
						CorrespondentBinaryData = New BinaryData(UnpackedFileList[0].FullName);
						
					Else
						
						NString = NStr("ru = 'Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
							|ExchangeRules.xml - правила конвертации для текущей программы;
							|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента.'; 
							|en = 'File names in the archive are not as expected. Expected files:
							|ExchangeRules.xml - conversion rules for the current application;
							|CorrespondentExchangeRules.xml - conversion rules for the correspondent application.'; 
							|pl = 'Nazwy plików w archiwum różnią się od oczekiwanych. Oczekiwane pliki
							|: ExchangeRules.xml - reguły konwersji dla
							|bieżącej aplikacji; CorrespondentExchangeRules.xml - reguły konwersji dla aplikacji korespondenta.';
							|es_ES = 'Nombres de documentos en el archivo no corresponden a los esperados. Archivos
							|esperados: ExchangeRules.xml - reglas de conversión para
							|la aplicación actual; CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal.';
							|es_CO = 'Nombres de documentos en el archivo no corresponden a los esperados. Archivos
							|esperados: ExchangeRules.xml - reglas de conversión para
							|la aplicación actual; CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal.';
							|tr = 'Arşivdeki dosya adları beklenen değerlerle uyuşmuyor. 
							|Dosyalar bekleniyor: ExchangeRules.xml - geçerli uygulama 
							|için dönüşüm kuralları; CorrespondentExchangeRules.xml - uygulama muhabiri için dönüşüm kuralları.';
							|it = 'I nomi dei file nell''archivio non corrispondono a quelli previsti. File previsti:
							|ExchangeRules.xml - regole di conversione per l''applicazione attuale;
							|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente.';
							|de = 'Dateinamen im Archiv entsprechen nicht den erwarteten. Dateien
							|werden erwartet: ExchangeRules.xml - Konvertierungsregeln für
							|die aktuelle Anwendung; CorrespondentExchangeRules.xml - Konvertierungsregeln für Anwendungskorrespondent.'");
						DataExchangeServer.ReportError(NString, Cancel);
						
					EndIf;
					
				// Obsolete format
				ElsIf UnpackedFileList.Count() = 1 Then
					NString = NStr("ru = 'В архиве найден один файл правил конвертации. Ожидаемое количество файлов в архиве - два. Ожидаются файлы:
						|ExchangeRules.xml - правила конвертации для текущей программы;
						|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента.'; 
						|en = 'Archive contains one file with conversion rules. Expected number of files in the archive is two. Expected files:
						|ExchangeRules.xml - rules for the current application conversion;  
						|CorrespondentExchangeRules.xml - rules for the correspondent application conversion.'; 
						|pl = 'Jeden plik reguł konwersji został znaleziony w archiwum. Spodziewana liczba plików w archiwum – to dwa. Oczekiwane są następujące pliki:
						|ExchangeRules.xml – reguły konwersji dla bieżącego programu;
						|CorrespondentExchangeRules.xml – reguły konwersji dla programu-korespondenta.';
						|es_ES = 'En el archivo se ha encontrado un archivo de reglas de conversión. Cantidad de archivos esperada en el archivo - dos. Se esperan los archivos:
						|ExchangeRules.xml - reglas de conversión para el programa actual;
						|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente.';
						|es_CO = 'En el archivo se ha encontrado un archivo de reglas de conversión. Cantidad de archivos esperada en el archivo - dos. Se esperan los archivos:
						|ExchangeRules.xml - reglas de conversión para el programa actual;
						|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente.';
						|tr = 'Arşiv, dönüşüm kurallarına sahip bir dosya içeriyor. Arşivdeki beklenen dosya sayısı iki. Beklenen dosyalar: 
						|ExchangeRules.xml - geçerli uygulama dönüşümü kuralları; 
						|CorrespondentExchangeRules.xml - muhabir uygulama dönüşümü kuralları.';
						|it = 'L''archivio contiene un file con le regole di conversione. Il numero di file previsto nell''archivio è due. File previsti:
						|ExchangeRules.xml - regole di conversione per l''applicazione attuale;  
						|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente.';
						|de = 'Eine Konvertierungsregeldatei wurde im Archiv gefunden. Die erwartete Anzahl der Dateien im Archiv ist zwei. Es werden Dateien erwartet:
						|ExchangeRules.xml - Konvertierungsregeln für das aktuelle Programm;
						|CorrespondentExchangeRules.xml - Konvertierungsregeln für das entsprechende Programm.'");
					DataExchangeServer.ReportError(NString, Cancel);
				// Canceling import if there are several files in the archive, but a single file is expected.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("ru = 'При распаковке архива найдено несколько файлов. Должен быть только один файл с правилами.'; en = 'When unzipping archive, multiple files were found. There should be only one file with rules.'; pl = 'Podczas rozpakowywania archiwum znaleziono kilka plików. Powinien być tylko jeden plik z regułami.';es_ES = 'Al descomprimir el archivo, documentos múltiples se han encontrado. Tiene que haber solo un documento con reglas.';es_CO = 'Al descomprimir el archivo, documentos múltiples se han encontrado. Tiene que haber solo un documento con reglas.';tr = 'Arşivin çıkarılması sırasında birden fazla dosya bulundu. Kurallara sahip tek bir dosya olmalı.';it = 'Quando la decompressione archivio, sono stati trovati più file. Ci dovrebbe essere un solo file con le regole.';de = 'Beim Entpacken des Archivs wurden mehrere Dateien gefunden. Es sollte nur eine Datei mit Regeln geben.'");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			Else
				
				// Saving received file to the binary data.
				If UnpackedFileList.Count() = 1 Then
					BinaryData = New BinaryData(UnpackedFileList[0].FullName);
					
				// Canceling import if there are several files in the archive, but a single file is expected.
				ElsIf UnpackedFileList.Count() > 1 Then
					NString = NStr("ru = 'При распаковке архива найдено несколько файлов. Должен быть только один файл с правилами.'; en = 'When unzipping archive, multiple files were found. There should be only one file with rules.'; pl = 'Podczas rozpakowywania archiwum znaleziono kilka plików. Powinien być tylko jeden plik z regułami.';es_ES = 'Al descomprimir el archivo, documentos múltiples se han encontrado. Tiene que haber solo un documento con reglas.';es_CO = 'Al descomprimir el archivo, documentos múltiples se han encontrado. Tiene que haber solo un documento con reglas.';tr = 'Arşivin çıkarılması sırasında birden fazla dosya bulundu. Kurallara sahip tek bir dosya olmalı.';it = 'Quando la decompressione archivio, sono stati trovati più file. Ci dovrebbe essere un solo file con le regole.';de = 'Beim Entpacken des Archivs wurden mehrere Dateien gefunden. Es sollte nur eine Datei mit Regeln geben.'");
					DataExchangeServer.ReportError(NString, Cancel);
				EndIf;
				
			EndIf;
			
		Else // Canceling import if unpacking the file failed.
			NString = NStr("ru = 'Не удалось распаковать архив с правилами.'; en = 'Failed unpacking the file.'; pl = 'Nie można rozpakować archiwum z regułami.';es_ES = 'No se puede desembalar un archivo con reglas.';es_CO = 'No se puede desembalar un archivo con reglas.';tr = 'Bir arşiv kurallar ile açılamıyor.';it = 'Estrazione file non riuscita.';de = 'Ein Archiv mit Regeln kann nicht entpackt werden.'");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// Deleting the temporary archive and the temporary directory where the archive was unpacked.
		DeleteTempFile(TempFolderName);
		DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	// Getting the temporary file name in the local file system on the server.
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file.
	BinaryData.Write(TempFileName);
	
	If IsConversionRules Then
		
		// Reading conversion rules.
		InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
		
		// Data processor properties
		InfobaseObjectConversion.ExchangeMode = "DataExported";
		InfobaseObjectConversion.ExchangePlanNameSOR = Record.ExchangePlanName;
		InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
		
		DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, Record.ExchangePlanName, Record.DebugMode);
		
		// Data processor methods
		RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
		
		RulesInformation = InfobaseObjectConversion.RulesInformation(False);
		
		If InfobaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
		// Getting the temporary file name in the local file system on the server.
		CorrespondentTempFileName = GetTempFileName("xml");
		// Getting the conversion rule file.
		CorrespondentBinaryData.Write(CorrespondentTempFileName);
		
		// Reading conversion rules.
		InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
		
		// Data processor properties
		InfobaseObjectConversion.ExchangeMode = "Load";
		InfobaseObjectConversion.ExchangePlanNameSOR = Record.ExchangePlanName;
		InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
		
		// Data processor methods
		ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
		
		DeleteFiles(CorrespondentTempFileName);
		
		CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
		
		If InfobaseObjectConversion.ErrorFlag() Then
			Cancel = True;
		EndIf;
		
 		RulesInformation = RulesInformation + Chars.LF + Chars.LF + CorrespondentRulesInformation;
		
	Else // ObjectsRegistrationRules
		
		// Reading registration rules.
		ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
		
		// Data processor properties
		ChangeRecordRuleImport.ExchangePlanNameForImport = Record.ExchangePlanName;
		
		// Data processor methods
		ChangeRecordRuleImport.ImportRules(TempFileName);
		
		RulesAreRead = ChangeRecordRuleImport.ObjectsRegistrationRules;
		
		RulesInformation = ChangeRecordRuleImport.RulesInformation();
		
		If ChangeRecordRuleImport.ErrorFlag Then
			Cancel = True;
		EndIf;
		
	EndIf;
	
	// Deleting the temporary rule file.
	DeleteTempFile(TempFileName);
	
	If Not Cancel Then
		
		Record.XMLRules          = New ValueStorage(BinaryData, New Deflation());
		Record.RulesAreRead   = New ValueStorage(RulesAreRead);
		
		If IsConversionRules Then
			
			Record.XMLCorrespondentRules = New ValueStorage(CorrespondentBinaryData, New Deflation());
			Record.CorrespondentRulesAreRead = New ValueStorage(ReadCorrespondentRules);
			
		EndIf;
		
		Record.RulesInformation = RulesInformation;
		Record.RulesFileName = RulesFileName;
		Record.RulesAreImported = True;
		Record.ExchangePlanNameFromRules = Record.ExchangePlanName;
		
	EndIf;
	
EndProcedure

Procedure ImportRulesSet(Cancel, DataToWrite, ErrorDescription, TempStorageAddress = "", RulesFileName = "") Export
	
	CovnersionRuleWriting = DataToWrite.CovnersionRuleWriting;
	RegistrationRuleWriting = DataToWrite.RegistrationRuleWriting;
	
	// Getting rule binary data from file or configuration template.
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate Then
		
		BinaryData               = BinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.RulesTemplateName);
		CorrespondentBinaryData = BinaryDataFromConfigurationTemplate(Cancel, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.CorrespondentRuleTemplateName);
		RegistrationBinaryData    = BinaryDataFromConfigurationTemplate(Cancel, RegistrationRuleWriting.ExchangePlanName, RegistrationRuleWriting.RulesTemplateName);
		
	Else
		
		BinaryData = GetFromTempStorage(TempStorageAddress);
		
	EndIf;
	
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File Then
		
		// Getting the archive file from binary data.
		TemporaryArchiveName = GetTempFileName("zip");
		BinaryData.Write(TemporaryArchiveName);
		
		// Extracting data from the archive
		TempFolderName = GetTempFileName("");
		If DataExchangeServer.UnpackZipFile(TemporaryArchiveName, TempFolderName) Then
			
			UnpackedFileList = FindFiles(TempFolderName, "*.*", True);
			
			// Canceling import if the archive contains no files.
			If UnpackedFileList.Count() = 0 Then
				NString = NStr("ru = 'При распаковке архива не найден файл с правилами.'; en = 'There is no rule file in the archive.'; pl = 'Podczas rozpakowywania archiwum nie znaleziono pliku z regułami.';es_ES = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';es_CO = 'Al descomprimir el archivo, el documentos con reglas no se ha encontrado.';tr = 'Arşiv açılırken, kural dosyası bulunamadı.';it = 'Nessun file di regole nell''archivio.';de = 'Beim Entpacken des Archivs wurde keine Datei mit Regeln gefunden.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
			
			// Canceling import if number of files in the archive does not match the expected number.
			If UnpackedFileList.Count() <> 3 Then
				NString = NStr("ru = 'Не верный формат комплекта правил. Ожидаемое количество файлов в архиве - три. Ожидаются файлы:
					|ExchangeRules.xml - правила конвертации для текущей программы;
					|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
					|RegistrationRules.xml - правила регистрации для текущей программы.'; 
					|en = 'Incorrect format of rule set. Expected number of files in the archive is three. Expected files:
					|ExchangeRules.xml - conversion rules for the current application;
					|CorrespondentExchangeRules.xml - conversion rules for the correspondent application;
					|RegistrationRules.xml - registration rules of for the current application.'; 
					|pl = 'Błędny format zestawu reguł. Spodziewana liczba plików w archiwum – to trzy. Oczekiwane są następujące pliki:
					|ExchangeRules.xml – zasady konwersji do bieżącego programu;
					|CorrespondentExchangeRules.xml – zasady konwersji do programu-korespondenta;
					|RegistrationRules.xml – zasady rejestracji do bieżącego programu.';
					|es_ES = 'Formato del conjunto de reglas incorrecto. Cantidad de los documentos esperada en el archivo - tres. Documentos esperados:
					|ExchangeRules.xml - reglas de conversión para el programa actual; 
					|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
					| RegistrationRules.xml - reglas de registro para el programa actual.';
					|es_CO = 'Formato del conjunto de reglas incorrecto. Cantidad de los documentos esperada en el archivo - tres. Documentos esperados:
					|ExchangeRules.xml - reglas de conversión para el programa actual; 
					|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
					| RegistrationRules.xml - reglas de registro para el programa actual.';
					|tr = 'Yanlış kurallar kümesinin biçimi. Arşivde beklenen dosya sayısı - üç. 
					|Beklenen dosyalar: ExchangeRules.xml - geçerli uygulama için 
					|dönüşüm kuralları; CorrespondentExchangeRules.xml - uygulama muhabiri için dönüşüm 
					|kuralları; RegistrationRules.xml - mevcut uygulama için kayıt kuralları.';
					|it = 'Formato non coretto dell''insieme di regole. Il numero previsto di file nell''archivio è tre. File attesi: 
					|ExchangeRules.xml - regole di conversione per l''applicazione attuale; 
					|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente; 
					|RegistrationRules.xml - regole di registrazione dell''applicazione attuale.';
					|de = 'Falsches Format des Regelsatzes. Die erwartete Anzahl der Dateien im Archiv beträgt drei. Es werden Dateien erwartet:
					|ExchangeRules.xml - Konvertierungsregeln für das aktuelle Programm;
					|CorrespondentExchangeRules.xml - Konvertierungsregeln für das entsprechende Programm;
					|RegistrationRules.xml - Registrierungsregeln für das aktuelle Programm.'");
				DataExchangeServer.ReportError(NString, Cancel);
			EndIf;
				
			// Saving received file to the binary data.
			For Each ReceivedFile In UnpackedFileList Do
				
				If ReceivedFile.Name = "ExchangeRules.xml" Then
					BinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="CorrespondentExchangeRules.xml" Then
					CorrespondentBinaryData = New BinaryData(ReceivedFile.FullName);
				ElsIf ReceivedFile.Name ="RegistrationRules.xml" Then
					RegistrationBinaryData = New BinaryData(ReceivedFile.FullName);
				Else
					NString = NStr("ru = 'Имена файлов в архиве не соответствуют ожидаемым. Ожидаются файлы:
						|ExchangeRules.xml - правила конвертации для текущей программы;
					|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
					|RegistrationRules.xml - правила регистрации для текущей программы.'; 
						|en = 'File names in the archive are not as expected. Expected files:
						|ExchangeRules.xml - conversion rules for the current application;
						|CorrespondentExchangeRules.xml - conversion rules for the correspondent application;
						|RegistrationRules.xml - registration rules for the current application.'; 
						|pl = 'Nazwy plików w archiwum różnią się od oczekiwanych. Oczekiwane pliki
						|: ExchangeRules.xml - reguły konwersji dla
						|bieżącej aplikacji; CorrespondentExchangeRules.xml - reguły konwersji
						|dla aplikacji korespondenta; RegistrationRules.xml - reguły rejestracji dla bieżącej aplikacji.';
						|es_ES = 'Nombres de documentos en el archivo no corresponden a los esperados. Documentos esperados: 
						|ExchangeRules.xml - reglas de conversión para la aplicación actual;
						|CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal;
						|RegistrationRules.xml - reglas de registro para la aplicación actual.';
						|es_CO = 'Nombres de documentos en el archivo no corresponden a los esperados. Documentos esperados: 
						|ExchangeRules.xml - reglas de conversión para la aplicación actual;
						|CorrespondentExchangeRules.xml - reglas de conversión para la aplicación-corresponsal;
						|RegistrationRules.xml - reglas de registro para la aplicación actual.';
						|tr = 'Arşivdeki dosya adları beklenen değerlerle uyuşmuyor. Dosyalar bekleniyor: 
						| ExchangeRules.xml - mevcut uygulama için dönüşüm kuralları; 
						| CorrespondentExchangeRules.xml - uygulama muhabiri için dönüşüm kuralları; 
						| RegistrationRules.xml - mevcut uygulama için kayıt kuralları.';
						|it = 'I nomi dei file nell''archivio non corrispondono a quelli previsti. File previsti:
						|ExchangeRules.xml - regole di conversione per l''applicazione attuale;
						|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente;
						|RegistrationRules.xml - regole di registrazione per l''applicazione attuale.';
						|de = 'Dateinamen im Archiv entsprechen nicht den erwarteten. Dateien werden erwartet:
						|ExchangeRules.xml - Konvertierungsregeln für die aktuelle Anwendung.
						|CorrespondentExchangeRules.xml - Konvertierungsregeln für Anwendungskorrespondent.
						|RegistrationRules.xml - Registrierungsregeln für die aktuelle Anwendung.'");
					DataExchangeServer.ReportError(NString, Cancel);
					Break;
				EndIf;
				
			EndDo;
			
		Else 
			// Canceling import if unpacking the file failed.
			NString = NStr("ru = 'Не удалось распаковать архив с правилами.'; en = 'Failed unpacking the file.'; pl = 'Nie można rozpakować archiwum z regułami.';es_ES = 'No se puede desembalar un archivo con reglas.';es_CO = 'No se puede desembalar un archivo con reglas.';tr = 'Bir arşiv kurallar ile açılamıyor.';it = 'Estrazione file non riuscita.';de = 'Ein Archiv mit Regeln kann nicht entpackt werden.'");
			DataExchangeServer.ReportError(NString, Cancel);
		EndIf;
		
		// Deleting the temporary archive and the temporary directory where the archive was unpacked.
		DeleteTempFile(TempFolderName);
		DeleteTempFile(TemporaryArchiveName);
		
	EndIf;
	
	If Cancel Then
		Return;
	EndIf;
	
	ConversionRulesInformation = "[SourceRulesInformation]
		|
		|[CorrespondentRulesInformation]";
		
	// Getting the temporary conversion file name in the local file system at server.
	TempFileName = GetTempFileName("xml");
	
	// Getting the conversion rule file.
	BinaryData.Write(TempFileName);
	
	// Reading conversion rules.
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "DataExported";
	InfobaseObjectConversion.ExchangePlanNameSOR = CovnersionRuleWriting.ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	DataExchangeServer.SetExportDebugSettingsForExchangeRules(InfobaseObjectConversion, CovnersionRuleWriting.ExchangePlanName, CovnersionRuleWriting.DebugMode);
	
	// Data processor methods
	If CovnersionRuleWriting.RulesSource = Enums.DataExchangeRulesSources.File AND ErrorDescription = Undefined
		AND Not ConversionRulesCompatibleWithCurrentVersion(CovnersionRuleWriting.ExchangePlanName, ErrorDescription, RulesInformationFromFile(TempFileName)) Then
		
		Cancel = True;
		Return;
		
	EndIf;
	
	RulesAreRead = InfobaseObjectConversion.ExchangeRules(TempFileName);
	
	SourceRulesInformation = InfobaseObjectConversion.RulesInformation(False);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	// Getting name of the temporary correspondent conversion file in the local file system on the server.
	CorrespondentTempFileName = GetTempFileName("xml");
	// Getting the conversion rule file.
	CorrespondentBinaryData.Write(CorrespondentTempFileName);
	
	// Reading conversion rules.
	InfobaseObjectConversion = DataProcessors.InfobaseObjectConversion.Create();
	
	// Data processor properties
	InfobaseObjectConversion.ExchangeMode = "Load";
	InfobaseObjectConversion.ExchangePlanNameSOR = CovnersionRuleWriting.ExchangePlanName;
	InfobaseObjectConversion.EventLogMessageKey = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	// Data processor methods
	ReadCorrespondentRules = InfobaseObjectConversion.ExchangeRules(CorrespondentTempFileName);
	
	CorrespondentRulesInformation = InfobaseObjectConversion.RulesInformation(True);
	
	If InfobaseObjectConversion.ErrorFlag() Then
		Cancel = True;
	EndIf;
	
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[SourceRulesInformation]", SourceRulesInformation);
	ConversionRulesInformation = StrReplace(ConversionRulesInformation, "[CorrespondentRulesInformation]", CorrespondentRulesInformation);
	
	// Getting the temporary registration file name in the local file system on the server.
	TempRegistrationFileName = GetTempFileName("xml");
	// Getting the conversion rule file.
	RegistrationBinaryData.Write(TempRegistrationFileName);

	
	// Reading registration rules.
	ChangeRecordRuleImport = DataProcessors.ObjectsRegistrationRulesImport.Create();
	
	// Data processor properties
	ChangeRecordRuleImport.ExchangePlanNameForImport = RegistrationRuleWriting.ExchangePlanName;
	
	// Data processor methods
	ChangeRecordRuleImport.ImportRules(TempRegistrationFileName);
	ReadRegistrationRules   = ChangeRecordRuleImport.ObjectsRegistrationRules;
	RegistrationRulesInformation = ChangeRecordRuleImport.RulesInformation();
	
	If ChangeRecordRuleImport.ErrorFlag Then
		Cancel = True;
	EndIf;
	
	// Deleting temporary rule files.
	DeleteTempFile(TempFileName);
	DeleteTempFile(CorrespondentTempFileName);
	DeleteTempFile(TempRegistrationFileName);
	
	If Not Cancel Then
		
		// Writing conversion rules.
		CovnersionRuleWriting.XMLRules                      = New ValueStorage(BinaryData, New Deflation());
		CovnersionRuleWriting.RulesAreRead               = New ValueStorage(RulesAreRead);
		CovnersionRuleWriting.XMLCorrespondentRules        = New ValueStorage(CorrespondentBinaryData, New Deflation());
		CovnersionRuleWriting.CorrespondentRulesAreRead = New ValueStorage(ReadCorrespondentRules);
		CovnersionRuleWriting.RulesInformation             = ConversionRulesInformation;
		CovnersionRuleWriting.RulesFileName                  = RulesFileName;
		CovnersionRuleWriting.RulesAreImported                = True;
		CovnersionRuleWriting.ExchangePlanNameFromRules          = CovnersionRuleWriting.ExchangePlanName;
		
		// Writing registration rules.
		RegistrationRuleWriting.XMLRules             = New ValueStorage(RegistrationBinaryData, New Deflation());
		RegistrationRuleWriting.RulesAreRead      = New ValueStorage(ReadRegistrationRules);
		RegistrationRuleWriting.RulesInformation    = RegistrationRulesInformation;
		RegistrationRuleWriting.RulesFileName         = RulesFileName;
		RegistrationRuleWriting.RulesAreImported       = True;
		RegistrationRuleWriting.ExchangePlanNameFromRules = RegistrationRuleWriting.ExchangePlanName;
		
	EndIf;
	
EndProcedure

// Gets read object conversion rules from the infobase for an exchange plan.
//
// Parameters:
//  ExchangePlanName - String - a name of the exchange plan as a metadata object.
// 
// Returns:
//  RulesAreRead - ValueStorage - read object conversion rules.
//  Undefined - if conversion rules were not imported to the base for an exchange plan.
//
Function ParsedRulesOfObjectConversion(Val ExchangePlanName, GetCorrespondentRules = False) Export
	
	// Function return value.
	RulesAreRead = Undefined;
	
	QueryText = "
	|SELECT
	|	DataExchangeRules.%1 AS RulesAreRead
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	  DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind      = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.RulesAreImported
	|";
	
	QueryText = StringFunctionsClientServer.SubstituteParametersToString(QueryText,
		?(GetCorrespondentRules, "CorrespondentRulesAreRead", "RulesAreRead"));
	
	Query = New Query;
	Query.Text = QueryText;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		Selection.Next();
		
		RulesAreRead = Selection.RulesAreRead;
		
	EndIf;
	
	Return RulesAreRead;
	
EndFunction

Function RulesFromFileUsed(ExchangePlanName, DetailedResult = False) Export
	
	Query = New Query(
	"SELECT DISTINCT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.RulesKind AS RulesKind
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.RulesAreImported
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If DetailedResult Then
		
		RulesFromFile = New Structure("RecordRules, ConversionRules", False, False);
		
		Selection = Result.Select();
		While Selection.Next() Do
			If Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules Then
				RulesFromFile.ConversionRules = True;
			ElsIf Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules Then
				RulesFromFile.RecordRules = True;
			EndIf;
		EndDo;
		
		Return RulesFromFile;
		
	Else
		Return Not Result.IsEmpty();
	EndIf;
	
EndFunction

Function BinaryDataFromConfigurationTemplate(Cancel, ExchangePlanName, TemplateName)
	
	// Getting the temporary file name in the local file system on the server.
	TempFileName = GetTempFileName("xml");
	
	ExchangePlanManager = DataExchangeCached.GetExchangePlanManagerByName(ExchangePlanName);
	
	// Getting the template of the standard rules.
	Try
		RuleTemplate = ExchangePlanManager.GetTemplate(TemplateName);
	Except
		
		MessageString = NStr("ru = 'Ошибка получения макета конфигурации %1 для плана обмена %2'; en = 'Error retrieving the template of the %1 configuration for the %2 exchange plan.'; pl = 'Podczas odbierania szablonu konfiguracji%1 dla planu wymiany %2 wystąpił błąd';es_ES = 'Ha ocurrido un error al recibir un modelo de la configuración %1 para el plan de intercambio %2';es_CO = 'Ha ocurrido un error al recibir un modelo de la configuración %1 para el plan de intercambio %2';tr = '%1Değişim planı için %2 yapılandırma şablonu alınırken bir hata oluştu';it = 'Errore nell''acquisizione del modello della configurazione %1 per il piano di scambio %2.';de = 'Beim Empfangen einer Vorlage der Konfiguration %1 für den Austauschplan %2 ist ein Fehler aufgetreten'");
		MessageString = StringFunctionsClientServer.SubstituteParametersToString(MessageString, TemplateName, ExchangePlanName);
		DataExchangeServer.ReportError(MessageString, Cancel);
		Return Undefined;
		
	EndTry;
	
	RuleTemplate.Write(TempFileName);
	
	BinaryData = New BinaryData(TempFileName);
	
	// Deleting the temporary rule file.
	DeleteTempFile(TempFileName);
	
	Return BinaryData;
EndFunction

Procedure DeleteTempFile(TempFileName)
	
	If Not IsBlankString(TempFileName) Then
		DeleteFiles(TempFileName);
	EndIf;
	
EndProcedure

Procedure CheckFieldsFilled(Cancel, Record)
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		NString = NStr("ru = 'Укажите план обмена.'; en = 'Specify the exchange plan.'; pl = 'Określ plan wymiany.';es_ES = 'Especificar una plan de intercambio.';es_CO = 'Especificar una plan de intercambio.';tr = 'Değişim planını belirtin.';it = 'Specificare il piano di scambio.';de = 'Geben Sie den Austauschplan an.'");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	ElsIf Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate
		    AND IsBlankString(Record.RulesTemplateName) Then
		
		NString = NStr("ru = 'Укажите типовые правила.'; en = 'Specify standard rules.'; pl = 'Określ standardowe reguły.';es_ES = 'Especificar las reglas estándares.';es_CO = 'Especificar las reglas estándares.';tr = 'Standart kuralları belirtin.';it = 'Specificare le regole tipiche.';de = 'Geben Sie Standardregeln an.'");
		
		DataExchangeServer.ReportError(NString, Cancel);
		
	EndIf;
	
EndProcedure

Function RulesInformationFromFile(RulesFileName)
	
	ExchangeRules = New XMLReader();
	ExchangeRules.OpenFile(RulesFileName);
	ExchangeRules.Read();
	
	If Not ((ExchangeRules.LocalName = "ExchangeRules") AND (ExchangeRules.NodeType = XMLNodeType.StartElement)) Then
		Raise NStr("ru = 'Ошибка формата правил обмена'; en = 'Exchange rule format error'; pl = 'Błąd formatu reguł wymiany';es_ES = 'Error en el formato de la regla de intercambio';es_CO = 'Error en el formato de la regla de intercambio';tr = 'Değişim kuralı biçiminde hata';it = 'Errore nel formato delle regole di scambio';de = 'Fehler beim Format der Austauschregeln'");
	EndIf;
	
	While ExchangeRules.Read() Do
		
		NodeName = ExchangeRules.LocalName;
		
		If NodeName = "Source" AND ExchangeRules.NodeType = XMLNodeType.StartElement Then
			
			RulesInformation = New Structure;
			RulesInformation.Insert("ConfigurationVersion", ExchangeRules.GetAttribute("ConfigurationVersion"));
			RulesInformation.Insert("ConfigurationSynonymInRules", ExchangeRules.GetAttribute("ConfigurationSynonym"));
			ExchangeRules.Read();
			RulesInformation.Insert("ConfigurationName", ExchangeRules.Value);
			
		ElsIf (NodeName = "Source") AND (ExchangeRules.NodeType = XMLNodeType.EndElement) Then
			
			ExchangeRules.Close();
			Return RulesInformation;
			
		EndIf;
		
	EndDo;
	
	Raise NStr("ru = 'Ошибка формата правил обмена'; en = 'Exchange rule format error'; pl = 'Błąd formatu reguł wymiany';es_ES = 'Error en el formato de la regla de intercambio';es_CO = 'Error en el formato de la regla de intercambio';tr = 'Değişim kuralı biçiminde hata';it = 'Errore nel formato delle regole di scambio';de = 'Fehler beim Format der Austauschregeln'");
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// Security profiles

// See SafeModeManagerOverridable.OnFillPermissionsToAccessExternalResources. 
Procedure OnFillPermissionsToAccessExternalResources(PermissionRequests) Export
	
	ImportedRules = ImportedRules();
	
	While ImportedRules.Next() Do
		
		RequestToUseExternalResources(PermissionRequests, ImportedRules);
		
	EndDo;
	
EndProcedure

Function RegistrationRulesFromFile(ExchangePlanName) Export
	
	Query = New Query(
	"SELECT TOP 1
	|	TRUE
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

Function ConversionRulesFromFile(ExchangePlanName) Export
	
	Query = New Query(
	"SELECT
	|	DataExchangeRules.ExchangePlanName AS ExchangePlanName,
	|	DataExchangeRules.DebugMode AS DebugMode,
	|	DataExchangeRules.ExportDebugMode AS ExportDebugMode,
	|	DataExchangeRules.ImportDebugMode AS ImportDebugMode,
	|	DataExchangeRules.DataExchangeLoggingMode AS DataExchangeLoggingMode,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName AS ExportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName AS ImportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ExchangeProtocolFileName AS ExchangeProtocolFileName
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|	AND DataExchangeRules.ExchangePlanName = &ExchangePlanName");
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection;
	EndIf;
	
	Return Undefined;
	
EndFunction

Function ImportedRules()
	
	Query = New Query;
	Query.Text = "SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	DataExchangeRules.DebugMode,
	|	DataExchangeRules.ExportDebugMode,
	|	DataExchangeRules.ImportDebugMode,
	|	DataExchangeRules.DataExchangeLoggingMode,
	|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
	|	DataExchangeRules.ExchangeProtocolFileName,
	|	TRUE AS HasConvertionRules
	|INTO ConversionRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)
	|	AND DataExchangeRules.RulesAreImported = TRUE
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DataExchangeRules.ExchangePlanName,
	|	TRUE AS RegistrationRulesFromFile
	|INTO RecordRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.RulesAreImported = TRUE
	|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)
	|	AND DataExchangeRules.RulesSource = VALUE(Enum.DataExchangeRulesSources.File)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN RecordRules.RegistrationRulesFromFile
	|			THEN RecordRules.ExchangePlanName
	|		ELSE ConversionRules.ExchangePlanName
	|	END AS ExchangePlanName,
	|	ConversionRules.DebugMode,
	|	ConversionRules.ExportDebugMode,
	|	ConversionRules.ImportDebugMode,
	|	ConversionRules.DataExchangeLoggingMode,
	|	ConversionRules.ExportDebuggingDataProcessorFileName,
	|	ConversionRules.ImportDebuggingDataProcessorFileName,
	|	ConversionRules.ExchangeProtocolFileName,
	|	ISNULL(RecordRules.RegistrationRulesFromFile, FALSE) AS RegistrationRulesFromFile,
	|	ISNULL(ConversionRules.HasConvertionRules, FALSE) AS HasConvertionRules
	|FROM
	|	ConversionRules AS ConversionRules
	|		FULL JOIN RecordRules AS RecordRules
	|		ON ConversionRules.ExchangePlanName = RecordRules.ExchangePlanName";
	
	Return Query.Execute().Select();
	
EndFunction

Procedure RequestToUseExternalResources(PermissionRequests, Record, HasConvertionRules = Undefined, RegistrationRulesFromFile = Undefined) Export
	
	Permissions = New Array;
	ModuleSafeModeManager = Common.CommonModule("SafeModeManager");
	
	If RegistrationRulesFromFile = Undefined Then
		RegistrationRulesFromFile = Record.RegistrationRulesFromFile;
	EndIf;
	
	If HasConvertionRules = Undefined Then
		HasConvertionRules = Record.HasConvertionRules;
	EndIf;
	
	If RegistrationRulesFromFile Then
		Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
	EndIf;
	
	If HasConvertionRules Then
		
		If Not Record.DebugMode Then
			// Requesting the personal profile is not required.
		Else
			
			If Not RegistrationRulesFromFile Then
				Permissions.Add(ModuleSafeModeManager.PermissionToUsePrivilegedMode());
			EndIf;
			
			If Record.DebugMode Then
				
				If Record.ExportDebugMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.ImportDebugMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, False));
					
				EndIf;
				
				If Record.DataExchangeLoggingMode Then
					
					FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
					Permissions.Add(ModuleSafeModeManager.PermissionToUseFileSystemDirectory(
					FileNameStructure.Path, True, True));
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	ExchangePlanID = Common.MetadataObjectID(Metadata.ExchangePlans[Record.ExchangePlanName]);
	
	ModuleSafeModeManagerInternal = Common.CommonModule("SafeModeManagerInternal");
	CommonClientServer.SupplementArray(PermissionRequests,
		ModuleSafeModeManagerInternal.PermissionRequestForExternalModule(ExchangePlanID, Permissions));
	
EndProcedure

#EndRegion

#EndIf