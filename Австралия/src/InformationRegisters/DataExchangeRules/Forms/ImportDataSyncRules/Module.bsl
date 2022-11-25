
#Region Variables

&AtClient
Var ExternalResourcesAllowed;

#EndRegion

#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	ExchangePlanName = Parameters.ExchangePlanName;
	
	If Not ValueIsFilled(ExchangePlanName) Then
		Return;
	EndIf;
	
	Title = StrReplace(Title, "%1", Metadata.ExchangePlans[ExchangePlanName].Synonym);
	
	UpdateRuleInfo();
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.DebugSettingsGroup.Enabled = DebugMode;
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	DataExchangeRuleImportEventLogEvent = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	ApplicationName = Metadata.ExchangePlans[ExchangePlanName].Synonym;
	RuleSetLocation = DataExchangeServer.ExchangePlanSettingValue(ExchangePlanName, 
								"PathToRulesSetFileOnUserSite, PathToRulesSetFileInTemplateDirectory");
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	TooltipPattern = NStr("ru = 'Комплект правил можно скачать с %1
		|или найти в %2'; 
		|en = 'Rule set can be downloaded from %1 
		|or found in %2'; 
		|pl = 'Zestaw zasad można pobrać z %1
		|lub znaleźć w %2';
		|es_ES = 'Conjunto de reglas se puede descargar de %1
		|o encontrar en %2';
		|es_CO = 'Conjunto de reglas se puede descargar de %1
		|o encontrar en %2';
		|tr = 'Kurallar kümesin 
		|den %1 içe aktarılabilir veya %2 ''de bulunabilir';
		|it = 'L''insieme di regole può essere scaricato da %1 
		|o trovato in %2';
		|de = 'Eine Reihe von Regeln kann von %1
		|heruntergeladen oder in %2 gefunden werden'");
	
	UpdateDirectoryPattern = NStr("ru = 'каталоге поставки программы ""%1""'; en = 'the %1 configuration template directory'; pl = 'katalogu ""%1"" obsługi aplikacji';es_ES = 'directorio de la entrega de la aplicación ""%1""';es_CO = 'directorio de la entrega de la aplicación ""%1""';tr = '""%1"" uygulama tesliminin dizini';it = 'directory del modello di configurazione %1';de = 'Verzeichnis der ""%1"" Anwendungsbereitstellung'");
	UpdateDirectoryPattern = StringFunctionsClientServer.SubstituteParametersToString(UpdateDirectoryPattern, ApplicationName);
	
	UserSitePattern = NStr("ru = 'сайта поддержки пользователей системы ""1С:Предприятие 8""'; en = 'support website for users of 1C:Enterprise 8'; pl = 'strony wsparcia użytkowników systemu ""1C:Enterprise 8""';es_ES = 'de la página web de soporte de usuarios del sistema ""1C:Enterprise 8""';es_CO = 'de la página web de soporte de usuarios del sistema ""1C:Enterprise 8""';tr = '1C:Enterprise 8 kullanıcıları için destek sitesi';it = 'sito web di supporto per gli utenti 1C:Enterpise 8';de = '1C:Enterprise 8 System Benutzer-Support-Seite'");
	If Not IsBlankString(RuleSetLocation.PathToRulesSetFileOnUserSite) Then
		UserSitePattern = New FormattedString(UserSitePattern,,,, RuleSetLocation.PathToRulesSetFileOnUserSite);
	EndIf;
	
	AdditionalParameters = New Structure();
	AdditionalParameters.Insert("TooltipPattern",            TooltipPattern);
	AdditionalParameters.Insert("UpdateDirectoryPattern",    UpdateDirectoryPattern);
	AdditionalParameters.Insert("UserSitePattern", UserSitePattern);
	
	If Not IsBlankString(RuleSetLocation.PathToRulesSetFileInTemplateDirectory) Then
		
		AdditionalParameters.Insert("DefaultDirectory",                AppDataDirectory() + "1C\1C8\tmplts\");
		AdditionalParameters.Insert("UserTemplateSettings", AppDataDirectory() + "1C\1CEStart\1CEStart.cfg");
		AdditionalParameters.Insert("FileLocation",                 "");
		
		SuggestionText = NStr("ru = 'Для открытия каталога необходимо необходимо установить расширение работы с файлами.'; en = 'To be able to select directory, install the file system extension.'; pl = 'Aby otworzyć katalog, zainstaluj rozszerzenie operacji na plikach.';es_ES = 'Para abrir el directorio, instalar la extensión de la operación de archivos.';es_CO = 'Para abrir el directorio, instalar la extensión de la operación de archivos.';tr = 'Dizini açmak için, dosyalarla çalışmak için bir uzantı yüklemeniz gerekir.';it = 'Per poter selezionare una directory, installare l''estensione del file di sistema.';de = 'Installieren Sie die Dateioperationserweiterung, um das Verzeichnis zu öffnen.'");
		Notification = New NotifyDescription("AfterCheckFileSystemExtension", ThisObject, AdditionalParameters);
		CommonClient.ShowFileSystemExtensionInstallationQuestion(Notification, SuggestionText);
		
	Else
		SetInformationTitleOnReceive(AdditionalParameters);
	EndIf;
	
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure AfterCheckFileSystemExtension(Result, AdditionalParameters) Export
	
	If Result Then
		File = New File();
		AdditionalParameters.Insert("NextNotification", New NotifyDescription("DetermineFileExists", ThisObject, AdditionalParameters));
		Notification = New NotifyDescription("InitializeFile", ThisObject, AdditionalParameters);
		File.BeginInitialization(Notification, AdditionalParameters.UserTemplateSettings);
	Else
		SetInformationTitleOnReceive(AdditionalParameters);
	EndIf;
	
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure InitializeFile(File, AdditionalParameters) Export
	File.BeginCheckingExistence(AdditionalParameters.NextNotification);
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure DetermineFileExists(Exists, AdditionalParameters) Export

#If WebClient Then
	
	Raise NStr("ru='Операция в веб-клиенте не предусмотрена'; en = 'Operation is not available in web client'; pl = 'Operacja w kliencie sieciowym nie jest przewidziana';es_ES = 'La operación en el cliente web no está prevista';es_CO = 'La operación en el cliente web no está prevista';tr = 'Web istemcide işlem öngörülmedi';it = 'Operazione non disponibile sul web client';de = 'Die Bedienung im Webclient ist nicht vorgesehen'");
	
#Else
	
	FoundDirectory = Undefined;
	
	If Exists Then
		
		Text = New TextReader(AdditionalParameters.UserTemplateSettings, TextEncoding.UTF16);
		Page = "";
		
		While Page <> Undefined Do
			Page = Text.ReadLine();
			If Page = Undefined Then
				Break;
			EndIf;
			If StrFind(Upper(Page), Upper("ConfigurationTemplatesLocation")) = 0 Then
				Continue;
			EndIf;
			SeparatorPosition = StrFind(Page, "=");
			If SeparatorPosition = 0 Then
				Continue;
			EndIf;
			FoundDirectory = CommonClientServer.AddLastPathSeparator(TrimAll(Mid(Page, SeparatorPosition + 1)));
			Break;
		EndDo;
		
	EndIf;
	
	If FoundDirectory <> Undefined Then
		AdditionalParameters.FileLocation = FoundDirectory + RuleSetLocation.PathToRulesSetFileInTemplateDirectory;
	Else
		AdditionalParameters.FileLocation = AdditionalParameters.DefaultDirectory + RuleSetLocation.PathToRulesSetFileInTemplateDirectory
	EndIf;
	
	File = New File();
	AdditionalParameters.NextNotification = New NotifyDescription("DetermineDirectoryExists", ThisObject, AdditionalParameters);
	Notification = New NotifyDescription("InitializeFile", ThisObject, AdditionalParameters);
	File.BeginInitialization(Notification, AdditionalParameters.FileLocation);
	
#EndIf
	
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure DetermineDirectoryExists(Exists, AdditionalParameters) Export
	
	If Exists Then
		AdditionalParameters.UpdateDirectoryPattern = New FormattedString(AdditionalParameters.UpdateDirectoryPattern,,,,
			AdditionalParameters.FileLocation);
	EndIf;
	
	SetInformationTitleOnReceive(AdditionalParameters);
	
EndProcedure

// Continuation of the procedure (see above).
&AtClient
Procedure SetInformationTitleOnReceive(AdditionalParameters)
	TooltipText = SubstituteParametersInFormattedString(AdditionalParameters.TooltipPattern, 
		AdditionalParameters.UserSitePattern,
		AdditionalParameters.UpdateDirectoryPattern);
	Items.RulesImportInfoDecoration.Title = TooltipText;
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If DebugMode Then
		
		If ExportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла внешней обработки.'; en = 'External data processor file name is not specified'; pl = 'Nie określono nazwy zewnętrznego przetwarzania pliku.';es_ES = 'Nombre del archivo del procesador de datos externo no está especificado.';es_CO = 'Nombre del archivo del procesador de datos externo no está especificado.';tr = 'Harici veri işlemcisi dosyasının adı belirtilmedi';it = 'Il nome del file di elaboratore dati esterno non è specificato';de = 'Der Name der externen Datenprozessordatei ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If ImportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла внешней обработки.'; en = 'External data processor file name is not specified'; pl = 'Nie określono nazwy zewnętrznego przetwarzania pliku.';es_ES = 'Nombre del archivo del procesador de datos externo no está especificado.';es_CO = 'Nombre del archivo del procesador de datos externo no está especificado.';tr = 'Harici veri işlemcisi dosyasının adı belirtilmedi';it = 'Il nome del file di elaboratore dati esterno non è specificato';de = 'Der Name der externen Datenprozessordatei ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If DataExchangeLoggingMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла протокола обмена.'; en = 'Exchange protocol file name is not specified'; pl = 'Nie określono nazwy protokołu wymiany plików.';es_ES = 'Nombre del archivo del protocolo de intercambio no está especificado.';es_CO = 'Nombre del archivo del protocolo de intercambio no está especificado.';tr = 'Alışveriş protokolü dosya adı belirtilmemiş.';it = 'Il nome del file del protocollo di scambio non è specificato.';de = 'Der Name des Austausch-Protokolldateinamens ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "ExchangeProtocolFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure RuleSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		
		DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebuggingOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExternalDataProcessorForExportDebug.Enabled = ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Внешняя обработка(*.epf)'; en = 'External data processor (*.epf)'; pl = 'Zewnętrzne przetwarzanie danych (*.epf)';es_ES = 'Procesador de datos externo (*.epf)';es_CO = 'Procesador de datos externo (*.epf)';tr = 'Harici veri işlemcisi (*.epf)';it = 'Elaboratore dati esterno (*.epf)';de = 'Externer Datenprozessor (*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Внешняя обработка(*.epf)'; en = 'External data processor (*.epf)'; pl = 'Zewnętrzne przetwarzanie danych (*.epf)';es_ES = 'Procesador de datos externo (*.epf)';es_CO = 'Procesador de datos externo (*.epf)';tr = 'Harici veri işlemcisi (*.epf)';it = 'Elaboratore dati esterno (*.epf)';de = 'Externer Datenprozessor (*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(ThisObject, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExternalDataProcessorForImportDebug.Enabled = ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeProtocolgingOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.ExchangeProtocolFile.Enabled = DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DebuggingSettingsChanged = True;
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Текстовый документ(*.txt)'; en = 'Text document (*.txt)'; pl = 'Dokument tekstowy (*.txt)';es_ES = 'Documento de texto (*.txt)';es_CO = 'Documento de texto (*.txt)';tr = 'Metin belgesi (*.txt)';it = 'Documento di testo (txt)';de = 'Textdokument (*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	DataExchangeClient.FileSelectionHandler(ThisObject, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(ThisObject, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	DebuggingSettingsChanged = True;
	Items.DebugSettingsGroup.Enabled = DebugMode;
	
EndProcedure

&AtClient
Procedure DoNotStopOnErrorOnChange(Item)
	DebuggingSettingsChanged = True;
EndProcedure

&AtClient
Procedure RuleObtainInfoDecorationURLProcessing(
		Item, FormattedStringURL, StandardProcessing)
	
	AdditionalParameters = New Structure;	
	AdditionalParameters.Insert("FormattedStringURL", FormattedStringURL);
		
	Notification = New NotifyDescription("DecorationRuleReceiptInformationURLProcessingAfterFinish",
		ThisObject, AdditionalParameters);
		
	StandardProcessing = False;
	CommonClient.OpenURL(FormattedStringURL, Notification);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("ru = 'Укажите архив с правилами обмена'; en = 'Select exchange rule archive'; pl = 'Określ archiwum z regułami wymiany';es_ES = 'Especificar un archivo con reglas de intercambio';es_CO = 'Especificar un archivo con reglas de intercambio';tr = 'Değişim kuralları ile bir arşiv belirtin';it = 'Selezionare l''archivio delle regole di scambio';de = 'Geben Sie ein Archiv mit Austauschregeln an'"));
	DialogParameters.Insert("Filter", NStr("ru = 'Архивы ZIP (*.zip)'; en = 'ZIP archive (*.zip)'; pl = 'Archiwum ZIP (*.zip)';es_ES = 'Archivos ZIP (*.zip)';es_CO = 'Archivos ZIP (*.zip)';tr = 'Zip arşivleri(*.zip)';it = 'Archivio ZIP (*.zip)';de = 'ZIP-Archive (*.zip)'") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonClientServer.ParseFullFileName(RulesFileName);

	// Exporting to an archive
	StorageAddress = GetRuleArchiveTempStorageAddressAtServer();
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("ru = 'Правила конвертации'; en = 'Conversion rules'; pl = 'Reguły konwersji';es_ES = 'Reglas de conversión';es_CO = 'Reglas de conversión';tr = 'Dönüşüm kuralları';it = 'Regole di conversioni';de = 'Konvertierungsregeln'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("ru = 'Укажите в какой файл выгрузить правила'; en = 'Specify file to export rules'; pl = 'Określ do jakiego pliku wyeksportować reguły';es_ES = 'Especificar un archivo para el cual las reglas se exportarán';es_CO = 'Especificar un archivo para el cual las reglas se exportarán';tr = 'Kuralların dışa aktarılacağı bir dosya belirtin';it = 'Indicare il file per esportare le regole';de = 'Geben Sie eine Datei an, in die die Regeln exportiert werden'") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NStr("ru = 'Архивы ZIP (*.zip)'; en = 'ZIP archive (*.zip)'; pl = 'Archiwum ZIP (*.zip)';es_ES = 'Archivos ZIP (*.zip)';es_CO = 'Archivos ZIP (*.zip)';tr = 'Zip arşivleri(*.zip)';it = 'Archivio ZIP (*.zip)';de = 'ZIP-Archive (*.zip)'") + "|*.zip");
	
	FileToReceive = New Structure("Name, Location", FullFileName, StorageAddress);
	
	DataExchangeClient.SelectAndSaveFileAtClient(FileToReceive, DialogParameters);
	
EndProcedure

&AtClient
Procedure WriteAndClose(Command)
		
	If RulesSource = "StandardRulesFromConfiguration" Then
		BeforeRuleImport(Undefined, "");
	Else
		If ConversionRuleSource = PredefinedValue("Enum.DataExchangeRulesSources.ConfigurationTemplate") Then
			
			ErrorDescription = NStr("ru = 'Правила из файла не загружены. Закрытие приведет к использованию типовых правил конвертации.
			|Использовать типовые правила конвертации?'; 
			|en = 'Rules were not imported from file. If closing, typical conversion rules will be used.
			|Use typical conversion rules?'; 
			|pl = 'Reguły z pliku nie zostały zaimportowane. Zamknięcie doprowadzi do użycia typowych zasad konwersji.
			|Użyć typowych reguł konwersji?';
			|es_ES = 'Reglas del archivo no se han importado. Cierre causará el uso de las reglas típicas de conversión. 
			|¿Utilizar las reglas típicas de conversión?';
			|es_CO = 'Reglas del archivo no se han importado. Cierre causará el uso de las reglas típicas de conversión. 
			|¿Utilizar las reglas típicas de conversión?';
			|tr = 'Dosyadaki kurallar içe aktarılmaz. Kapatma, tipik dönüşüm kurallarının kullanılmasına yol açacaktır. 
			|Tipik dönüşüm kurallar kullanılsın mı?';
			|it = 'Le regole non sono state importate dal file. La chiusura porterà all''uso delle regole di conversione tipiche.
			|Usare regole di conversione tipiche?';
			|de = 'Regeln aus der Datei werden nicht importiert. Beim Schließen werden die typischen Konvertierungsregeln verwendet.
			|Typische Konvertierungsregeln verwenden?'");
			
			Notification = New NotifyDescription("CloseRuleImportForm", ThisObject);
			
			Buttons = New ValueList;
			Buttons.Add("Use", NStr("ru = 'Использовать'; en = 'Use'; pl = 'Użyć';es_ES = 'Utilizar';es_CO = 'Utilizar';tr = 'Kullan';it = 'Utilizzare';de = 'Anwenden'"));
			Buttons.Add("Cancel", NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
			
			FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
			FormParameters.DefaultButton = "Use";
			FormParameters.SuggestDontAskAgain = False;
			
			StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription, Buttons, FormParameters);
		Else
			If DebuggingSettingsChanged Then
				ImportDebugModeSettingsAtServer();
			EndIf;
			Close();
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure DecorationRuleReceiptInformationURLProcessingAfterFinish(ApplicationStarted, AdditionalParameters) Export
	
	If ApplicationStarted Then
		Return;
	EndIf;
	
	CommonClient.OpenExplorer(AdditionalParameters.FormattedStringURL);
	
EndProcedure

&AtClient
Procedure ImportRulesCompletion(Val PutFilesResult, Val AdditionalParameters) Export
	
	PutFileAddress = PutFilesResult.Location;
	ErrorText           = PutFilesResult.ErrorDescription;
	
	If IsBlankString(ErrorText) AND IsBlankString(PutFileAddress) Then
		ErrorText = NStr("ru = 'Ошибка передачи файла настроек синхронизации данных на сервер'; en = 'An error occurred while sending data synchronization settings to the server.'; pl = 'Podczas przesyłania pliku ustawień synchronizacji danych na serwer wystąpił błąd';es_ES = 'Ha ocurrido un error, al transferir el archivo de las configuraciones de la sincronización de datos al servidor';es_CO = 'Ha ocurrido un error, al transferir el archivo de las configuraciones de la sincronización de datos al servidor';tr = 'Veri senkronizasyon ayarları dosyasını sunucuya aktarırken bir hata oluştu';it = 'Errore durante l''invio delle impostazioni di sincronizzazione dati al server.';de = 'Beim Übertragen der Datei mit den Datensynchronisierungseinstellungen auf den Server ist ein Fehler aufgetreten'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	// The file is successfully transferred, importing the file to the server.
	NameParts = CommonClientServer.ParseFullFileName(PutFilesResult.Name);
	
	If Lower(NameParts.Extension) <> ".zip" Then
		CommonClientServer.MessageToUser(NStr("ru = 'Некорректный формат файла комплекта правил. Ожидается zip архив, содержащий три файла:
			|ExchangeRules.xml - правила конвертации для текущей программы;
			|CorrespondentExchangeRules.xml - правила конвертации для программы-корреспондента;
			|RegistrationRules.xml - правила регистрации для текущей программы.'; 
			|en = 'Incorrect file format of rule set. Zip archive with three files is expected:
			|ExchangeRules.xml - conversion rules for the current application;
			|CorrespondentExchangeRules.xml - conversion rules for the correspondent application;
			|RegistrationRules.xml - registration rules for the current application.'; 
			|pl = 'Nieodpowiedni format pliku zestawu reguł. Spodziewany jest archiwum zip, liczba plików w archiwum – to trzy pliki:
			|ExchangeRules.xml – zasady konwersji do bieżącego programu;
			|CorrespondentExchangeRules.xml – zasady konwersji do programu-korespondenta;
			|RegistrationRules.xml – zasady rejestracji do bieżącego programu.';
			|es_ES = 'Formato incorrecto del archivo de conjuntos de reglas. Se espera un archivo zip que contiene tres archivos:
			|ExchangeRules.xml - reglas de conversión para el programa actual;
			|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
			|RegistrationRules.xml - reglas de registrar para el programa actual.';
			|es_CO = 'Formato incorrecto del archivo de conjuntos de reglas. Se espera un archivo zip que contiene tres archivos:
			|ExchangeRules.xml - reglas de conversión para el programa actual;
			|CorrespondentExchangeRules.xml - reglas de conversión para el programa-correspondiente;
			|RegistrationRules.xml - reglas de registrar para el programa actual.';
			|tr = 'Kural kümesi dosyasının yanlış biçimi. 
			|Üç dosya içeren zip arşivi bekleniyor: ExchangeRules.xml - 
			|geçerli uygulama için dönüşüm kuralları; CorrespondentExchangeRules.xml - 
			|uygulama muhabiri için dönüşüm kuralları; RegistrationRules.xml - mevcut uygulama için kayıt kuralları.';
			|it = 'Formato non corretto dell''insieme di regole. È previsto un archivio zip con tre file:
			|ExchangeRules.xml - regole di conversione per l''applicazione attuale;
			|CorrespondentExchangeRules.xml - regole di conversione per l''applicazione corrispondente;
			|RegistrationRules.xml - regole di registrazione per l''applicazione attuale.';
			|de = 'Falsches Format der Regelsatzdatei. Ein Zip-Archiv sollte drei Dateien enthalten:
			|ExchangeRules.xml - Konvertierungsregeln für das aktuelle Programm;
			|CorrespondentExchangeRules.xml - Konvertierungsregeln für das entsprechende Programm;
			|RegistrationRules.xml - Registrierungsregeln für das aktuelle Programm.'"));
	EndIf;
	
	BeforeRuleImport(PutFileAddress, NameParts.Name);
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val PutFileAddress, Val FileName, ErrorDescription = Undefined)
	
	Cancel = False;
	DebuggingSettingsChanged = False;
	
	ImportRulesAtServer(Cancel, PutFileAddress, FileName, ErrorDescription);
	
	If TypeOf(ErrorDescription) <> Type("Boolean") AND ErrorDescription <> Undefined Then
		
		Buttons = New ValueList;
		
		If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
			Buttons.Add("Cancel", NStr("ru = 'Закрыть'; en = 'Close'; pl = 'Zamknij';es_ES = 'Cerrar';es_CO = 'Cerrar';tr = 'Kapat';it = 'Chiudi';de = 'Schließen'"));
		Else
			Buttons.Add("Continue", NStr("ru = 'Продолжить'; en = 'Continue'; pl = 'Kontynuuj';es_ES = 'Continuar';es_CO = 'Continuar';tr = 'Devam';it = 'Continua';de = 'Weiter'"));
			Buttons.Add("Cancel", NStr("ru = 'Отмена'; en = 'Cancel'; pl = 'Anuluj';es_ES = 'Cancelar';es_CO = 'Cancelar';tr = 'İptal et';it = 'Annulla';de = 'Abbrechen'"));
		EndIf;
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PutFileAddress", PutFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		Notification = New NotifyDescription("AfterConversionRulesCheckForCompatibility", ThisObject, AdditionalParameters);
		
		FormParameters = StandardSubsystemsClient.QuestionToUserParameters();
		FormParameters.DefaultButton = "Cancel";
		FormParameters.Picture = ErrorDescription.Picture;
		FormParameters.SuggestDontAskAgain = False;
		If ErrorDescription.ErrorKind = "InvalidConfiguration" Then
			FormParameters.Title = NStr("ru = 'Правила не могут быть загружены'; en = 'Cannot import rules'; pl = 'Reguły nie zostały zaimportowane';es_ES = 'Reglas no pueden importarse';es_CO = 'Reglas no pueden importarse';tr = 'Kurallar içe aktarılamıyor';it = 'Impossibile importare le regole';de = 'Regeln können nicht importiert werden'");
		Else
			FormParameters.Title = NStr("ru = 'Синхронизация данных может работать некорректно'; en = 'Data synchronization might be performed incorrectly'; pl = 'Synchronizacja danych może działać niepoprawnie';es_ES = 'Sincronización de datos puede trabajar de forma incorrecta';es_CO = 'Sincronización de datos puede trabajar de forma incorrecta';tr = 'Veri senkronizasyonu yanlış yürütülebilir';it = 'La sincronizzazione dei dati potrebbe essere stata eseguita non correttamente';de = 'Die Datensynchronisierung funktioniert möglicherweise nicht ordnungsgemäß'");
		EndIf;
		
		StandardSubsystemsClient.ShowQuestionToUser(Notification, ErrorDescription.ErrorText, Buttons, FormParameters);
		
	ElsIf Cancel Then
		ErrorText = NStr("ru = 'В процессе загрузки правил были обнаружены ошибки.
			|Перейти в журнал регистрации?'; 
			|en = 'Errors occurred when importing the rules.
			|Proceed to the event log?'; 
			|pl = 'Błędy wykryto podczas pobierania reguł.
			|Przejdź do dziennika rejestracji?';
			|es_ES = 'Al descargar las reglas se han encontrado errores.
			|¿Pasar al registro?';
			|es_CO = 'Al descargar las reglas se han encontrado errores.
			|¿Pasar al registro?';
			|tr = 'Kurallar içe aktarılırken hatalar oluştu.
			|Olay günlüğüne gitmek istiyor musunuz?';
			|it = 'Errore durante l''importazione delle regole.
			|Andare al registro eventi?';
			|de = 'Beim Importieren der Regeln wurden Fehler festgestellt.
			|Zum Ereignisprotokoll wechseln?'");
		Notification = New NotifyDescription("ShowEventLogWhenErrorOccurred", ThisObject);
		ShowQueryBox(Notification, ErrorText, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
	Else
		ShowUserNotification(,, NStr("ru = 'Правила успешно загружены в информационную базу.'; en = 'The rules are imported to the infobase.'; pl = 'Import reguł do bazy informacyjnej zakończony pomyślnie.';es_ES = 'Reglas se han importado con éxito a la infobase.';es_CO = 'Reglas se han importado con éxito a la infobase.';tr = 'Kurallar, veritabanına başarıyla aktarıldı.';it = 'Le regole sono state importate nell''infobase.';de = 'Die Regeln wurden erfolgreich in die Infobase importiert.'"));
		Close();
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", DataExchangeRuleImportEventLogEvent);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RulesFileName, ErrorDescription)
	
	SetRuleSource = ?(RulesSource = "StandardRulesFromConfiguration",
		Enums.DataExchangeRulesSources.ConfigurationTemplate, Enums.DataExchangeRulesSources.File);
	
	CovnersionRuleWriting                               = InformationRegisters.DataExchangeRules.CreateRecordManager();
	CovnersionRuleWriting.RulesKind                     = Enums.DataExchangeRulesTypes.ObjectConversionRules;
	CovnersionRuleWriting.RulesTemplateName               = ConversionRuleTemplateName;
	CovnersionRuleWriting.CorrespondentRuleTemplateName = CorrespondentRuleTemplateName;
	CovnersionRuleWriting.RulesInformation           = ConversionRulesInformation;
	
	FillPropertyValues(CovnersionRuleWriting, ThisObject);
	CovnersionRuleWriting.RulesSource = SetRuleSource;
	
	RegistrationRuleWriting                     = InformationRegisters.DataExchangeRules.CreateRecordManager();
	RegistrationRuleWriting.RulesKind           = Enums.DataExchangeRulesTypes.ObjectsRegistrationRules;
	RegistrationRuleWriting.RulesTemplateName     = RegistrationRuleTemplateName;
	RegistrationRuleWriting.RulesInformation = RegistrationRulesInformation;
	RegistrationRuleWriting.RulesFileName      = RulesFileName;
	RegistrationRuleWriting.ExchangePlanName      = ExchangePlanName;
	RegistrationRuleWriting.RulesSource      = SetRuleSource;
	
	RegisterRecordStructure = New Structure();
	RegisterRecordStructure.Insert("CovnersionRuleWriting", CovnersionRuleWriting);
	RegisterRecordStructure.Insert("RegistrationRuleWriting", RegistrationRuleWriting);
	
	InformationRegisters.DataExchangeRules.ImportRulesSet(Cancel, RegisterRecordStructure,
		ErrorDescription, TempStorageAddress, RulesFileName);
	
	If Not Cancel Then
		
		CovnersionRuleWriting.Write();
		RegistrationRuleWriting.Write();
		
		Modified = False;
		
		// Open session cache for registration mechanism has become obsolete.
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
		RefreshReusableValues();
		UpdateRuleInfo();
		
	EndIf;
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Creating the temporary directory at the server and generating file paths.
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	
	PathToFile               = CommonClientServer.AddLastPathSeparator(TempFolderName) + "ExchangeRules";
	CorrespondentFilePath = CommonClientServer.AddLastPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	RegistrationFilePath    = CommonClientServer.AddLastPathSeparator(TempFolderName) + "RegistrationRules";
	
	Query = New Query;
	Query.Text =
		"SELECT
		|	DataExchangeRules.XMLRules,
		|	DataExchangeRules.XMLCorrespondentRules,
		|	DataExchangeRules.RulesKind
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName";
	
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		
		NString = NStr("ru = 'Не удалось получить правила обмена.'; en = 'Cannot read exchange rules.'; pl = 'Nie można pobrać reguł wymiany.';es_ES = 'No se puede recibir las reglas de intercambio.';es_CO = 'No se puede recibir las reglas de intercambio.';tr = 'Değişim kuralları alınamıyor.';it = 'Impossibile leggere le regole di scambio.';de = 'Kann keine Austauschregeln erhalten.'");
		DataExchangeServer.ReportError(NString);
		DeleteFiles(TempFolderName);
		Return "";
		
	Else
		
		Selection = Result.Select();
		
		While Selection.Next() Do
			
			If Selection.RulesKind = Enums.DataExchangeRulesTypes.ObjectConversionRules Then
				
				// Getting, saving, and archiving the conversion rule file to the temporary directory.
				RuleBinaryData = Selection.XMLRules.Get();
				RuleBinaryData.Write(PathToFile + ".xml");
				
				// Getting, saving, and archiving the correspondent conversion rule file to the temporary directory.
				CorrespondentRuleBinaryData = Selection.XMLCorrespondentRules.Get();
				CorrespondentRuleBinaryData.Write(CorrespondentFilePath + ".xml");
				
			Else
				// Getting, saving, and archiving the registration rule file in the temporary directory.
				RegistrationRulesBinaryData = Selection.XMLRules.Get();
				RegistrationRulesBinaryData.Write(RegistrationFilePath + ".xml");
			EndIf;
			
		EndDo;
		
		FilesPackingMask = CommonClientServer.AddLastPathSeparator(TempFolderName) + "*.xml";
		DataExchangeServer.PackIntoZipFile(PathToFile + ".zip", FilesPackingMask);
		
		// Placing the ZIP archive with the rules in the storage.
		RuleArchiveBinaryData = New BinaryData(PathToFile + ".zip");
		TempStorageAddress = PutToTempStorage(RuleArchiveBinaryData);
		DeleteFiles(TempFolderName);
		
		Return TempStorageAddress;
		
	EndIf;
	
EndFunction

&AtServer
Procedure UpdateRuleInfo()
	
	RulesInformation();
	
	RulesSource = ?(RegistrationRuleSource = Enums.DataExchangeRulesSources.File
		OR ConversionRuleSource = Enums.DataExchangeRulesSources.File,
		"RuelsImportedFromFile", "StandardRulesFromConfiguration");
	
	CommonRulesInformation = "[UsageInformation]
		|
		|[RegistrationRulesInformation]
		|
		|[ConversionRulesInformation]";
	
	If RulesSource = "RuelsImportedFromFile" Then
		UsageInformation = NStr("ru = 'Используются правила загруженные из файла.'; en = 'Exchange rules imported from a file are applied.'; pl = 'Użyto reguł zaimportowanych z pliku.';es_ES = 'Se utilizan las reglas importadas del archivo.';es_CO = 'Se utilizan las reglas importadas del archivo.';tr = 'Dosyadan içe aktarılan kurallar kullanıldı.';it = 'Vengono applicate le regole di scambio importate dal file.';de = 'Aus Datei importierte Regeln werden verwendet.'");
	Else
		UsageInformation = NStr("ru = 'Используются типовые правила из состава конфигурации.'; en = 'Default configuration exchange rules are applied.'; pl = 'Użyto standardowych reguł z konfiguracji.';es_ES = 'Se utilizan las reglas estándares de la configuración.';es_CO = 'Se utilizan las reglas estándares de la configuración.';tr = 'Yapılandırmadan standart kurallar kullanıldı.';it = 'Vengono applicate le regole di scambio come da configurazione predefinite.';de = 'Standardregeln aus der Konfiguration werden verwendet.'");
	EndIf;
	
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[UsageInformation]", UsageInformation);
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[ConversionRulesInformation]", ConversionRulesInformation);
	CommonRulesInformation = StrReplace(CommonRulesInformation, "[RegistrationRulesInformation]", RegistrationRulesInformation);
	
EndProcedure

&AtServer
Procedure RulesInformation()
	
	Query = New Query;
	Query.SetParameter("ExchangePlanName", ExchangePlanName);
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS ConversionRuleTemplateName,
		|	DataExchangeRules.CorrespondentRuleTemplateName AS CorrespondentRuleTemplateName,
		|	DataExchangeRules.ExportDebuggingDataProcessorFileName,
		|	DataExchangeRules.ImportDebuggingDataProcessorFileName,
		|	DataExchangeRules.RulesFileName AS ConversionRuleFileName,
		|	DataExchangeRules.ExchangeProtocolFileName,
		|	DataExchangeRules.RulesInformation AS ConversionRulesInformation,
		|	DataExchangeRules.UseSelectiveObjectRegistrationFilter,
		|	DataExchangeRules.RulesSource AS ConversionRuleSource,
		|	DataExchangeRules.DoNotStopOnError,
		|	DataExchangeRules.DebugMode,
		|	DataExchangeRules.ExportDebugMode,
		|	DataExchangeRules.ImportDebugMode,
		|	DataExchangeRules.DataExchangeLoggingMode
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectConversionRules)";
		
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
	Query.Text = "SELECT
		|	DataExchangeRules.RulesTemplateName AS RegistrationRuleTemplateName,
		|	DataExchangeRules.RulesFileName AS RegistrationRuleFileName,
		|	DataExchangeRules.RulesInformation AS RegistrationRulesInformation,
		|	DataExchangeRules.RulesSource AS RegistrationRuleSource
		|FROM
		|	InformationRegister.DataExchangeRules AS DataExchangeRules
		|WHERE
		|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
		|	AND DataExchangeRules.RulesKind = VALUE(Enum.DataExchangeRulesTypes.ObjectsRegistrationRules)";
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then
		FillPropertyValues(ThisObject, Selection);
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeRuleImport(Val PutFileAddress, Val FileName)
	
	If Not CheckFillingAtClient() Then
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("PutFileAddress", PutFileAddress);
		AdditionalParameters.Insert("FileName", FileName);
		ClosingNotification = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, AdditionalParameters);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Queries = CreateRequestToUseExternalResources();
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		Else
			ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
		EndIf;
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	PerformRuleImport(PutFileAddress, FileName);
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		BeforeRuleImport(AdditionalParameters.PutFileAddress, AdditionalParameters.FileName);
	EndIf;
	
EndProcedure

&AtServer
Function CreateRequestToUseExternalResources()
	
	PermissionRequests = New Array;
	RegistrationRulesFromFile = (RulesSource <> "StandardRulesFromConfiguration");
	RecordStructure = New Structure;
	RecordStructure.Insert("ExchangePlanName", ExchangePlanName);
	RecordStructure.Insert("DebugMode", DebugMode);
	RecordStructure.Insert("ExportDebugMode", ExportDebugMode);
	RecordStructure.Insert("ImportDebugMode", ImportDebugMode);
	RecordStructure.Insert("DataExchangeLoggingMode", DataExchangeLoggingMode);
	RecordStructure.Insert("ExportDebuggingDataProcessorFileName", ExportDebuggingDataProcessorFileName);
	RecordStructure.Insert("ImportDebuggingDataProcessorFileName", ImportDebuggingDataProcessorFileName);
	RecordStructure.Insert("ExchangeProtocolFileName", ExchangeProtocolFileName);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionRequests, RecordStructure, True, RegistrationRulesFromFile);
	Return PermissionRequests;
	
EndFunction

&AtClient
// Returns a formatted string based on a template (for example, "%1 moved to %2").
//
// Parameters:
//     Template - String - pattern for generation.
//     String1 - String, FormattedString, Picture, Undefined - the substitute value.
//     String2 - String, FormattedString, Picture, Undefined - the substitute value.
//
// Returns:
//     FormattedString - generated by input parameters.
//
Function SubstituteParametersInFormattedString(Val Template,
	Val String1 = Undefined, Val String2 = Undefined)
	
	StringParts = New Array;
	AllowedTypes = New TypeDescription("String, FormattedString, Picture");
	Start = 1;
	
	While True Do
		
		Particle = Mid(Template, Start);
		
		Position = StrFind(Particle, "%");
		
		If Position = 0 Then
			
			StringParts.Add(Particle);
			
			Break;
			
		EndIf;
		
		Next = Mid(Particle, Position + 1, 1);
		
		If Next = "1" Then
			
			Value = String1;
			
		ElsIf Next = "2" Then
			
			Value = String2;
			
		ElsIf Next = "%" Then
			
			Value = "%";
			
		Else
			
			Value = Undefined;
			
			Position  = Position - 1;
			
		EndIf;
		
		StringParts.Add(Left(Particle, Position - 1));
		
		If Value <> Undefined Then
			
			Value = AllowedTypes.AdjustValue(Value);
			
			If Value <> Undefined Then
				
				StringParts.Add( Value );
				
			EndIf;
			
		EndIf;
		
		Start = Start + Position + 1;
		
	EndDo;
	
	Return New FormattedString(StringParts);
	
EndFunction

// Determining the "My Documents" directory of the current Windows user.
//
&AtClient
Function AppDataDirectory()
	
	App = New COMObject("Shell.Application");
	Folder = App.Namespace(26);
	Result = Folder.Self.Path;
	Return CommonClientServer.AddLastPathSeparator(Result);
	
EndFunction

&AtClient
Procedure AfterConversionRulesCheckForCompatibility(Result, AdditionalParameters) Export
	
	If Result <> Undefined AND Result.Value = "Continue" Then
		
		ErrorDescription = True;
		PerformRuleImport(AdditionalParameters.PutFileAddress, AdditionalParameters.FileName, ErrorDescription);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CloseRuleImportForm(Result, AdditionalParameters) Export
	If Result <> Undefined AND Result.Value = "Use" Then
		Close();
	EndIf;
EndProcedure

&AtServer
Procedure ImportDebugModeSettingsAtServer()
	ConversionRulesRecords = InformationRegisters.DataExchangeRules.CreateRecordSet();
	ConversionRulesRecords.Filter.RulesKind.Set(Enums.DataExchangeRulesTypes.ObjectConversionRules);
	ConversionRulesRecords.Filter.ExchangePlanName.Set(ExchangePlanName);
	ConversionRulesRecords.Read();
	If ConversionRulesRecords.Count() = 0 Then
		Return;
	EndIf;
	RulesRecord = ConversionRulesRecords[0];
	RulesRecord.ExportDebuggingDataProcessorFileName = ExportDebuggingDataProcessorFileName;
	RulesRecord.ImportDebuggingDataProcessorFileName = ImportDebuggingDataProcessorFileName;
	RulesRecord.ExchangeProtocolFileName = ExchangeProtocolFileName;
	RulesRecord.DoNotStopOnError = DoNotStopOnError;
	RulesRecord.DebugMode = DebugMode;
	RulesRecord.ExportDebugMode = ExportDebugMode;
	RulesRecord.ImportDebugMode = ImportDebugMode;
	RulesRecord.DataExchangeLoggingMode = DataExchangeLoggingMode;
	ConversionRulesRecords.Write(True);
EndProcedure

#EndRegion
