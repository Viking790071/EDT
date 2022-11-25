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
	
	UpdateRuleSource();
	
	DataExchangeRuleImportEventLogEvent = DataExchangeServer.DataExchangeRuleImportEventLogEvent();
	
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
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
	
	Items.RulesSourceFile.Enabled = (RulesSource = "RuelsImportedFromFile");
	
	If RulesSource = "StandardRulesFromConfiguration" Then
		
		Record.DebugMode = False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure ImportRules(Command)
	
	ClearMessages();
	
	// Importing from file on the client
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Title", NStr("ru = 'Укажите, из какого файла загрузить правила'; en = 'Specify a file to import the rules from'; pl = 'Określ plik, z którego będą zaimportowane reguły';es_ES = 'Especificar un archivo del cual importar las reglas';es_CO = 'Especificar un archivo del cual importar las reglas';tr = 'Kuralları içe aktarmak için bir dosya belirtin.';it = 'Specificare un file da importare le regole da';de = 'Geben Sie eine Datei an, aus der die Regeln importiert werden sollen'"));
	DialogParameters.Insert("Filter",
		  NStr("ru = 'Файлы правил регистрации (*.xml)'; en = 'Registration rule files (*.xml)'; pl = 'Pliki reguł rejestracji (*.xml)';es_ES = 'Archivo de las reglas de registro (*.xml)';es_CO = 'Archivo de las reglas de registro (*.xml)';tr = 'Kayıt kural dosyaları (* .xml)';it = 'File di regole di registrazione (* .xml)';de = 'Registrierungsregeldateien (*.xml)'") + "|*.xml|"
		+ NStr("ru = 'Архивы ZIP (*.zip)'; en = 'ZIP archive (*.zip)'; pl = 'Archiwum ZIP (*.zip)';es_ES = 'Archivos ZIP (*.zip)';es_CO = 'Archivos ZIP (*.zip)';tr = 'Zip arşivleri(*.zip)';it = 'Archivio ZIP (*.zip)';de = 'ZIP-Archive (*.zip)'")   + "|*.zip");
	
	DialogParameters.Insert("FullFileName", NameParts.FullName);
	DialogParameters.Insert("FilterIndex", ?( Lower(NameParts.Extension) = ".zip", 1, 0) ); 
	
	Notification = New NotifyDescription("ImportRulesCompletion", ThisObject);
	DataExchangeClient.SelectAndSendFileToServer(Notification, DialogParameters, UUID);
EndProcedure

&AtClient
Procedure UnloadRules(Command)
	
	NameParts = CommonClientServer.ParseFullFileName(Record.RulesFileName);
	
	StorageAddress = GetURLAtServer();
	NameFilter = NStr("ru = 'Файлы правил (*.xml)'; en = 'Rule files (*.xml)'; pl = 'Pliki reguł (*.xml)';es_ES = 'Archivos de reglas (*.xml)';es_CO = 'Archivos de reglas (*.xml)';tr = 'Kural dosyaları (* .xml)';it = 'File di regole (* .xml)';de = 'Regeldateien (*.xml)'") + "|*.xml";
	
	If IsBlankString(StorageAddress) Then
		Return;
	EndIf;
	
	If IsBlankString(NameParts.BaseName) Then
		FullFileName = NStr("ru = 'Правила регистрации'; en = 'Registration rules'; pl = 'Reguły rejestracji';es_ES = 'Reglas de Registro';es_CO = 'Reglas de Registro';tr = 'Kayıt Kuralları';it = 'Regole di registrazione';de = 'Registrierungsregeln'");
	Else
		FullFileName = NameParts.BaseName;
	EndIf;
	
	DialogParameters = New Structure;
	DialogParameters.Insert("Mode", FileDialogMode.Save);
	DialogParameters.Insert("Title", NStr("ru = 'Укажите в какой файл выгрузить правила'; en = 'Specify file to export rules'; pl = 'Określ do jakiego pliku wyeksportować reguły';es_ES = 'Especificar un archivo para el cual las reglas se exportarán';es_CO = 'Especificar un archivo para el cual las reglas se exportarán';tr = 'Kuralların dışa aktarılacağı bir dosya belirtin';it = 'Indicare il file per esportare le regole';de = 'Geben Sie eine Datei an, in die die Regeln exportiert werden'") );
	DialogParameters.Insert("FullFileName", FullFileName);
	DialogParameters.Insert("Filter", NameFilter);
	
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

&AtClient
Procedure ShowEventLogWhenErrorOccurred(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogEvent", DataExchangeRuleImportEventLogEvent);
		OpenForm("DataProcessor.EventLog.Form", Filter, ThisObject, , , , , FormWindowOpeningMode.LockOwnerWindow);
		
	EndIf;
	
EndProcedure

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
	
	TemplatesList = DataExchangeCached.RegistrationRulesForExchangePlanFromConfiguration(Record.ExchangePlanName);
	
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
	Items.ExchangePlanGroup.Visible = IsBlankString(Record.ExchangePlanName);
	
EndProcedure

&AtServer
Function GetURLAtServer()
	
	Filter = New Structure;
	Filter.Insert("ExchangePlanName", Record.ExchangePlanName);
	Filter.Insert("RulesKind",      Record.RulesKind);
	
	RecordKey = InformationRegisters.DataExchangeRules.CreateRecordKey(Filter);
	
	Return GetURL(RecordKey, "XMLRules");
	
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
									|uygulamanın yeni bir sürümüne aktarımda bazı sorunlara neden olabilir.
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

&AtServer
Procedure UpdateRuleSource()
	
	RulesSource = ?(Record.RulesSource = Enums.DataExchangeRulesSources.ConfigurationTemplate,
		"StandardRulesFromConfiguration", "RuelsImportedFromFile");
	
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
Procedure ImportRulesCompletion(Val PutFilesResult, Val AdditionalParameters) Export
	
	PutFileAddress = PutFilesResult.Location;
	ErrorText           = PutFilesResult.ErrorDescription;
	
	If IsBlankString(ErrorText) AND IsBlankString(PutFileAddress) Then
		ErrorText = NStr("ru = 'Ошибка передачи файла на сервер'; en = 'An error occurred when transferring the file to the server'; pl = 'Podczas przesyłania pliku na serwer wystąpił błąd';es_ES = 'Ha ocurrido un error al transferir el archivo al servidor';es_CO = 'Ha ocurrido un error al transferir el archivo al servidor';tr = 'Dosya sunucuya aktarılırken bir hata oluştu';it = 'Si è verificato un errore durante il trasferimento del file sul server';de = 'Beim Übertragen der Datei an den Server ist ein Fehler aufgetreten'");
	EndIf;
	
	If Not IsBlankString(ErrorText) Then
		CommonClientServer.MessageToUser(ErrorText);
		Return;
	EndIf;
		
	RulesSource = "RuelsImportedFromFile";
	
	// The file is successfully transferred, importing the file to the server.
	NameParts = CommonClientServer.ParseFullFileName(PutFilesResult.Name);
	
	PerformRuleImport(PutFileAddress, NameParts.Name, Lower(NameParts.Extension) = ".zip");
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
	ConversionRulesFromFile = InformationRegisters.DataExchangeRules.ConversionRulesFromFile(Record.ExchangePlanName);
	HasConvertionRules = (ConversionRulesFromFile <> Undefined);
	RegistrationRulesFromFile = (Record.RulesSource = Enums.DataExchangeRulesSources.File);
	InformationRegisters.DataExchangeRules.RequestToUseExternalResources(PermissionRequests,
		?(HasConvertionRules, ConversionRulesFromFile, Record), HasConvertionRules, RegistrationRulesFromFile);
	Return PermissionRequests;
	
EndFunction

#EndRegion
