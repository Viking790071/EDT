
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
	
	UpdateExchangePlanChoiceList();
	
	UpdateRuleTemplateChoiceList();
	
	UpdateRuleInfo();
	
	RulesSource = ?(Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate,
		"StandardRulesFromConfiguration", "RuelsImportedFromFile");
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.DebugSettingsGroup.Enabled = Record.DebugMode;
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	DataExchangeRuleImportEventLogEvent = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	If Not CheckFillingAtClient() Then
		Cancel = True;
		Return;
	EndIf;
	
	If ExternalResourcesAllowed <> True Then
		
		ClosingNotification = New NotifyDescription("AllowExternalResourceCompletion", ThisObject, WriteParameters);
		If CommonClient.SubsystemExists("StandardSubsystems.SecurityProfiles") Then
			Queries = CreateRequestToUseExternalResources(Record);
			ModuleSafeModeManagerClient = CommonClient.CommonModule("SafeModeManagerClient");
			ModuleSafeModeManagerClient.ApplyExternalResourceRequests(Queries, ThisObject, ClosingNotification);
		Else
			ExecuteNotifyProcessing(ClosingNotification, DialogReturnCode.OK);
		EndIf;
		
		Cancel = True;
		Return;
		
	EndIf;
	ExternalResourcesAllowed = False;
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		// Importing rules from configuration
		PerformRuleImport(Undefined, "", False);
	EndIf;
	
EndProcedure

&AtClient
Function CheckFillingAtClient()
	
	HasBlankFields = False;
	
	If RulesSource = "RuelsImportedFromFile" AND IsBlankString(Record.RulesFileName) Then
		
		MessageString = NStr("ru = 'Не задан файл правил обмена.'; en = 'Exchange rule file name  is not specified.'; pl = 'Nie określono pliku reguł wymiany.';es_ES = 'Archivo de las reglas de intercambio no está especificado.';es_CO = 'Archivo de las reglas de intercambio no está especificado.';tr = 'Değişim kuralları dosyası belirlenmedi.';it = 'Non è specificato il nome del file con regole di scambio (Nome file delle regole).';de = 'Datei der Austauschregeln ist nicht angegeben.'");
		CommonClientServer.MessageToUser(MessageString,,,, HasBlankFields);
		
	EndIf;
	
	If Record.DebugMode Then
		
		If Record.ExportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла внешней обработки.'; en = 'External data processor file name is not specified'; pl = 'Nie określono nazwy zewnętrznego przetwarzania pliku.';es_ES = 'Nombre del archivo del procesador de datos externo no está especificado.';es_CO = 'Nombre del archivo del procesador de datos externo no está especificado.';tr = 'Harici veri işlemci dosyasının adı belirtilmemiş.';it = 'Il nome del file di elaboratore dati esterno non è specificato';de = 'Der Name der externen Datenprozessordatei ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "Record.ExportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.ImportDebugMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ImportDebuggingDataProcessorFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла внешней обработки.'; en = 'External data processor file name is not specified'; pl = 'Nie określono nazwy zewnętrznego przetwarzania pliku.';es_ES = 'Nombre del archivo del procesador de datos externo no está especificado.';es_CO = 'Nombre del archivo del procesador de datos externo no está especificado.';tr = 'Harici veri işlemci dosyasının adı belirtilmemiş.';it = 'Il nome del file di elaboratore dati esterno non è specificato';de = 'Der Name der externen Datenprozessordatei ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "Record.ImportDebuggingDataProcessorFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
		If Record.DataExchangeLoggingMode Then
			
			FileNameStructure = CommonClientServer.ParseFullFileName(Record.ExchangeProtocolFileName);
			FileName = FileNameStructure.BaseName;
			
			If Not ValueIsFilled(FileName) Then
				
				MessageString = NStr("ru = 'Не задано имя файла протокола обмена.'; en = 'Exchange protocol file name is not specified'; pl = 'Nie określono nazwy protokołu wymiany plików.';es_ES = 'Nombre del archivo del protocolo de intercambio no está especificado.';es_CO = 'Nombre del archivo del protocolo de intercambio no está especificado.';tr = 'Alışveriş protokolü dosya adı belirtilmemiş.';it = 'Il nome del file del protocollo di scambio non è specificato.';de = 'Der Name des Austausch-Protokolldateinamens ist nicht angegeben.'");
				CommonClientServer.MessageToUser(MessageString,, "Record.ExchangeProtocolFileName",, HasBlankFields);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Not HasBlankFields;
	
EndFunction

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If WriteParameters.Property("WriteAndClose") Then
		Close();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure ExchangePlanNameOnChange(Item)
	
	Record.RulesTemplateName = "";
	
	// server call
	UpdateRuleTemplateChoiceList();
	
EndProcedure

&AtClient
Procedure RuleSourceOnChange(Item)
	
	Items.DebugGroup.Enabled = (RulesSource = "RuelsImportedFromFile");
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		
		Record.DebugMode = False;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EnableExportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForExportDebug.Enabled = Record.ExportDebugMode;
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForExportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Внешняя обработка(*.epf)'; en = 'External data processor (*.epf)'; pl = 'Zewnętrzne przetwarzanie danych (*.epf)';es_ES = 'Procesador de datos externo (*.epf)';es_CO = 'Procesador de datos externo (*.epf)';tr = 'Harici veri işlemcisi (*.epf)';it = 'Elaboratore dati esterno (*.epf)';de = 'Externer Datenprozessor (*.epf)'") + "|*.epf" );
	
	DataExchangeClient.FileSelectionHandler(Record, "ExportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExternalDataProcessorForImportDebugStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Внешняя обработка(*.epf)'; en = 'External data processor (*.epf)'; pl = 'Zewnętrzne przetwarzanie danych (*.epf)';es_ES = 'Procesador de datos externo (*.epf)';es_CO = 'Procesador de datos externo (*.epf)';tr = 'Harici veri işlemcisi (*.epf)';it = 'Elaboratore dati esterno (*.epf)';de = 'Externer Datenprozessor (*.epf)'") + "|*.epf" );
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(Record, "ImportDebuggingDataProcessorFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure EnableImportDebuggingOnChange(Item)
	
	Items.ExternalDataProcessorForImportDebug.Enabled = Record.ImportDebugMode;
	
EndProcedure

&AtClient
Procedure EnableDataExchangeProtocolgingOnChange(Item)
	
	Items.ExchangeProtocolFile.Enabled = Record.DataExchangeLoggingMode;
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileStartChoice(Item, ChoiceData, StandardProcessing)
	
	DialogSettings = New Structure;
	DialogSettings.Insert("Filter", NStr("ru = 'Текстовый документ(*.txt)'; en = 'Text document (*.txt)'; pl = 'Dokument tekstowy (*.txt)';es_ES = 'Documento de texto (*.txt)';es_CO = 'Documento de texto (*.txt)';tr = 'Metin belgesi (*.txt)';it = 'Documento di testo (txt)';de = 'Textdokument (*.txt)'")+ "|*.txt" );
	DialogSettings.Insert("CheckFileExist", False);
	
	StandardProcessing = False;
	DataExchangeClient.FileSelectionHandler(Record, "ExchangeProtocolFileName", StandardProcessing, DialogSettings);
	
EndProcedure

&AtClient
Procedure ExchangeProtocolFileOpening(Item, StandardProcessing)
	
	DataExchangeClient.FileOrDirectoryOpenHandler(Record, "ExchangeProtocolFileName", StandardProcessing);
	
EndProcedure

&AtClient
Procedure RuleTemplateNameOnChange(Item)
	Record.CorrespondentRuleTemplateName = Record.RulesTemplateName + "Correspondent";
EndProcedure

&AtClient
Procedure EnableDebugModeOnChange(Item)
	
	Items.DebugSettingsGroup.Enabled = Record.DebugMode;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("ru = 'Укажите архив с правилами обмена'; en = 'Select exchange rule archive'; pl = 'Określ archiwum z regułami wymiany';es_ES = 'Especificar un archivo con reglas de intercambio';es_CO = 'Especificar un archivo con reglas de intercambio';tr = 'Değişim kuralları ile bir arşiv belirtin';it = 'Selezionare l''archivio delle regole di scambio';de = 'Geben Sie ein Archiv mit Austauschregeln an'"));
	DialogParameters.Insert("Filter", NStr("ru = 'Архивы ZIP (*.zip)'; en = 'ZIP archive (*.zip)'; pl = 'Archiwum ZIP (*.zip)';es_ES = 'Archivos ZIP (*.zip)';es_CO = 'Archivos ZIP (*.zip)';tr = 'Zip arşivleri(*.zip)';it = 'Archivio ZIP (*.zip)';de = 'ZIP-Archive (*.zip)'") + "|*.zip");
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
	
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);

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
	
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteAndClose");
	Write(WriteParameters);
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure UpdateExchangePlanChoiceList()
	
	ExchangePlanList = DataExchangeCached.SSLExchangePlansList();
	
	FillList(ExchangePlanList, Items.ExchangePlanName.ChoiceList);
	
EndProcedure

&AtServer
Procedure UpdateRuleTemplateChoiceList()
	
	If IsBlankString(Record.ExchangePlanName) Then
		
		Items.MainGroup.Title = NStr("ru = 'Правила конвертации'; en = 'Conversion rules'; pl = 'Reguły konwersji';es_ES = 'Reglas de conversión';es_CO = 'Reglas de conversión';tr = 'Dönüşüm kuralları';it = 'Regole di conversioni';de = 'Konvertierungsregeln'");
		
	Else
		
		Items.MainGroup.Title = StringFunctionsClientServer.SubstituteParametersToString(
			Items.MainGroup.Title, Metadata.ExchangePlans[Record.ExchangePlanName].Synonym);
		
	EndIf;
	
	TemplatesList = DataExchangeCached.ConversionRulesForExchangePlanFromConfiguration(Record.ExchangePlanName);
	
	ChoiceList = Items.RulesTemplateName.ChoiceList;
	ChoiceList.Clear();
	
	FillList(TemplatesList, ChoiceList);
	
	Items.SourceConfigurationTemplate.CurrentPage = ?(TemplatesList.Count() = 1,
		Items.SingleTemplatePage, Items.SeveralTemplatesPage);
	
EndProcedure

&AtServer
Procedure FillList(SourceList, DestinationList)
	
	For Each Item In SourceList Do
		
		FillPropertyValues(DestinationList.Add(), Item);
		
	EndDo;
	
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
	
	PerformRuleImport(PutFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
	
EndProcedure

&AtClient
Procedure PerformRuleImport(Val PutFileAddress, Val FileName, Val IsArchive)
	Cancel = False;
	
	ImportRulesAtServer(Cancel, PutFileAddress, FileName, IsArchive);
	
	If Not Cancel Then
		ShowUserNotification(,, NStr("ru = 'Правила успешно загружены в информационную базу.'; en = 'The rules are imported to the infobase.'; pl = 'Import reguł do bazy informacyjnej zakończony pomyślnie.';es_ES = 'Reglas se han importado con éxito a la infobase.';es_CO = 'Reglas se han importado con éxito a la infobase.';tr = 'Kurallar, veritabanına başarıyla aktarıldı.';it = 'Le regole sono state importate nell''infobase.';de = 'Die Regeln wurden erfolgreich in die Infobase importiert.'"));
		Return;
	EndIf;
	
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
Procedure ImportRulesAtServer(Cancel, TempStorageAddress, RulesFileName, IsArchive)
	
	Record.RulesSource = ?(RulesSource = "StandardRulesFromConfiguration",
		Enums.DataExchangeRulesSources.ConfigurationTemplate, Enums.DataExchangeRulesSources.File);
	
	Object = FormAttributeToValue("Record");
	
	InformationRegisters.DataExchangeRules.ImportRules(Cancel, Object, TempStorageAddress, RulesFileName, IsArchive);
	
	If Not Cancel Then
		
		Object.Write();
		
		Modified = False;
		
		// Open session cache for registration mechanism has become obsolete.
		DataExchangeServerCall.ResetObjectsRegistrationMechanismCache();
		RefreshReusableValues();
	EndIf;
	
	ValueToFormAttribute(Object, "Record");
	
	UpdateRuleInfo();
	
EndProcedure

&AtServer
Function GetRuleArchiveTempStorageAddressAtServer()
	
	// Creating the temporary directory at the server and generating file paths.
	TempFolderName = GetTempFileName("");
	CreateDirectory(TempFolderName);
	PathToFile = CommonClientServer.AddLastPathSeparator(TempFolderName) + "ExchangeRules";
	CorrespondentFilePath = CommonClientServer.AddLastPathSeparator(TempFolderName) + "CorrespondentExchangeRules";
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataExchangeRules.XMLRules,
	|	DataExchangeRules.XMLCorrespondentRules
	|FROM
	|	InformationRegister.DataExchangeRules AS DataExchangeRules
	|WHERE
	|	DataExchangeRules.ExchangePlanName = &ExchangePlanName
	|	AND DataExchangeRules.RulesKind = &RulesKind";
	Query.SetParameter("ExchangePlanName", Record.ExchangePlanName); 
	Query.SetParameter("RulesKind", Record.RulesKind);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		
		NString = NStr("ru = 'Не удалось получить правила обмена.'; en = 'Cannot read exchange rules.'; pl = 'Nie można pobrać reguł wymiany.';es_ES = 'No se puede recibir las reglas de intercambio.';es_CO = 'No se puede recibir las reglas de intercambio.';tr = 'Değişim kuralları alınamıyor.';it = 'Impossibile leggere le regole di scambio.';de = 'Kann keine Austauschregeln erhalten.'");
		DataExchangeServer.ReportError(NString);
		DeleteFiles(TempFolderName);
		Return "";
		
	Else
		
		Selection = Result.Select();
		Selection.Next();
		
		// Getting, saving, and archiving the rule file in the temporary directory.
		RuleBinaryData = Selection.XMLRules.Get();
		RuleBinaryData.Write(PathToFile + ".xml");
		
		CorrespondentRuleBinaryData = Selection.XMLCorrespondentRules.Get();
		CorrespondentRuleBinaryData.Write(CorrespondentFilePath + ".xml");
		
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
	
	If Record.RulesSource = Enums.DataExchangeRulesSources.File Then
		
		RulesInformation = NStr("ru = 'Использование правил, загруженных из файла,
		|может привести к ошибкам при переходе на новую версию программы.
		|
		|[RulesInformation]'; 
		|en = 'Using rules imported from the file
		|may cause some problems when transferring to a new version of the application.
		|
		|[RulesInformation]'; 
		|pl = 'Używanie reguł, pobranych z pliku,
		|może prowadzić do błędów podczas aktualizacji do nowej wersji programu.
		|
		|[RulesInformation]';
		|es_ES = 'El uso de reglas descargadas del archivos
		|puede llevar a errores al pasar a la versión nueva del programa.
		|
		|[RulesInformation]';
		|es_CO = 'El uso de reglas descargadas del archivos
		|puede llevar a errores al pasar a la versión nueva del programa.
		|
		|[RulesInformation]';
		|tr = 'Dosyadan içe aktarılan kuralları kullanmak, 
		|uygulamanın yeni bir sürümüne aktarırken bazı sorunlara neden olur. 
		| 
		|[RulesInformation]';
		|it = 'L''uso delle regole importate dal file
		|può causare problemi durante il trasferimento alla nuova versione dell''applicazione.
		|
		|[RulesInformation]';
		|de = 'Die Verwendung von Regeln, die aus der Datei
		|importiert wurden, kann zu Problemen bei der Übertragung auf eine neue Version der Anwendung führen.
		|
		|[RulesInformation]'");
		
		RulesInformation = StrReplace(RulesInformation, "[RulesInformation]", Record.RulesInformation);
		
	Else
		
		RulesInformation = Record.RulesInformation;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure AllowExternalResourceCompletion(Result, WriteParameters) Export
	
	If Result = DialogReturnCode.OK Then
		ExternalResourcesAllowed = True;
		Write(WriteParameters);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function CreateRequestToUseExternalResources(Val Record)
	
	PermissionRequests = New Array;
	RegistrationRulesFromFile = InformationRegisters.DataExchangeRules.RegistrationRulesFromFile(Record.ExchangePlanName);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionRequests, Record, True, RegistrationRulesFromFile);
	Return PermissionRequests;
	
EndFunction

#EndRegion
